#!/bin/bash

# This script creates AWS IAM accounts for every member of the Gitlab group,
# assigns them a selected IAM policy and emails the credentials.
# Requirements:
# * util-linux (getopt)
# * curl
# * jq
# * awscli
# * msmtp with the following config at ~/.msmtprc (remember to chown 600 this file! more at https://wiki.archlinux.org/title/msmtp)

# account gmail
# tls on
# auth on
# host smtp.gmail.com
# port 587
# user jwas@infotech.edu.pl
# from jwas@infotech.edu.pl
# password ******

# exit on error
# error on unset variables
# fail whole pipeline if any command fails
set -euo pipefail

usage() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF
Usage: $0 [-hVnr] --apiKey <string> [--groupId <string>] [--userIds <string[, ...]] --policies <string>[, ...]

Create AWS IAM account for every member of the Gitlab group,
assign them a selected IAM policy and email the credentials.

-h, --help       Display help
-V, --verbose    Enable verbose mode
-n, --dryRun     Dry run - create IAM users but don't send the email with credentials
-r, --reset      Reset password for existing users
-a, --apiKey     Gitlab API key (required)
-g, --groupId    Gitlab group ID or URL encoded path
-u, --userIds    Gitlab user IDs or URL encoded paths
-p, --policies   Comma separated list of policy ARNs (required)
EOF
    # EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

# $@ is all command line parameters passed to the script.
# -l is for long options with double dash like --version
# the comma separates different long options
# -o is for short options like -v
options=$(getopt -l "help,verbose,apiKey:,groupId:,userIds:,policies:,dryRun,reset" -o "hVa:g:u:p:nr" -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

# defaults and constants
curlOpts=(-fLsS)
gitlabApi="https://gitlab.com/api/v4"
dryRun=false
reset=false

while true; do
    case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        -V | --verbose)
            curlOpts+=(-vvv)
            set -xv # Set xtrace and verbose mode.
            ;;
        -a | --apiKey)
            shift
            apiKey=$1
            ;;
        -g | --groupId)
            shift
            groupId=$1
            ;;
        -u | --userIds)
            shift
            userIds=$1
            ;;
        -p | --policies)
            shift
            policies=$1
            ;;
        -n | --dryRun)
            dryRun=true
            ;;
        -r | --reset)
            reset=true
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

if [ -z "${apiKey:-}" ] || [ -z "${policies:-}" ]; then
    usage
    exit 1
fi

if [ -z "${groupId:-}" ] && [ -z "${userIds:-}" ]; then
    usage
    exit 1
fi

policies=$(tr ',' '\n' <<<"$policies" | LC_ALL=C sort)
if [ -n "$userIds" ]; then
    mapfile -t userIds < <(tr ',' '\n' <<<"$userIds")
else
    members=$(curl "${curlOpts[@]}" --header "PRIVATE-TOKEN: $apiKey" "$gitlabApi/groups/$groupId/members")
    mapfile -t userIds < <(jq -ecr ".[] | .id" <<<"$members")
fi
for id in "${userIds[@]}"; do
    fullMember=$(curl "${curlOpts[@]}" --header "PRIVATE-TOKEN: $apiKey" "$gitlabApi/groups/$groupId/members/$id")
    username=$(jq -er ".username" <<<"$fullMember")
    email=$(jq -er ".email" <<<"$fullMember")
    password=$(openssl rand -base64 12)
    if user=$(aws iam get-user --user-name "$username"); then
        echo "User $username already exists, was created at $(jq -er '.User.CreateDate' <<< "$user")"
        existingPolicies=$(aws iam list-user-policies --user-name "$username" | jq -er '.PolicyNames[]' | LC_ALL=C sort)
        mapfile -t detach < <(comm -13 <(echo "$policies") <(echo "$existingPolicies"))
        mapfile -t attach < <(comm -23 <(echo "$policies") <(echo "$existingPolicies"))
        for policy in "${detach[@]}"; do
            aws iam detach-user-policy --user-name "$username" --policy-arn "$policy"
        done
        for policy in "${attach[@]}"; do
            aws iam attach-user-policy --user-name "$username" --policy-arn "$policy"
        done
        if [ "$reset" != true ]; then
            continue
        fi
        aws iam update-login-profile --user-name "$username" --password "$password" --no-password-reset-required
    else
        echo "Creating IAM account for $username"
        aws iam create-user --user-name "$username" --tags "Key=groupId,Value=$groupId"
        aws iam create-login-profile --user-name "$username" --password "$password" --no-password-reset-required
        while IFS= read -r policy; do
            aws iam attach-user-policy --user-name "$username" --policy-arn "$policy"
        done <<< "$policies"
    fi

    accessKey=$(aws iam create-access-key --user-name "$username")

    echo "Emailing credentials to $email"
    # shellcheck disable=SC2030
    read -r -d '' message <<SMTP || true
Subject: AWS IAM user
To: $email

Log in at https://jwas-infotech.signin.aws.amazon.com/console
Account: jwas-infotech
IAM user: $username
Web console password: $password
Access key ID: $(jq -er ".AccessKey.AccessKeyId" <<<"$accessKey")
Secret access key: $(jq -er ".AccessKey.SecretAccessKey" <<<"$accessKey")
SMTP
    if [ "$dryRun" != false ]; then
        continue
    fi
    msmtp -a gmail "$email" <<<"$message"
done
