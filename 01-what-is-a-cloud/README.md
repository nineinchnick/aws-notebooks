What is a Cloud?
================

After finishing this course, you should know:
* what are most common services offered by Cloud providers
* the main advantages of deploying apps in the Cloud vs on-premise

## Overview

There are three dominant Cloud providers, any each one has some explanation of what is the Cloud:
* [Azure](https://azure.microsoft.com/en-us/overview/what-is-the-cloud/)
* [AWS](https://aws.amazon.com/what-is-cloud-computing/?nc1=f_cc)
* [Google Cloud Platform](https://cloud.google.com/learn/what-is-cloud-computing)

This course will not attemt to compare them, but will focus on AWS.
AWS provides [a large number of different services](https://docs.aws.amazon.com/),
grouped into categories, like:
* Compute
* Storage
* Databases
* Networking

## Excercise

Log in to [the AWS Web Console](https://console.aws.amazon.com/) using credentials
provided by the trainer, or register a new account, if you have a credit card you can use.

Create an S3 Bucket, upload any file, make it publicly available, and add a link to it here.

Install [the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).

[Configure it](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-config)
using credentials provided by the trainer. If you created your own account earlier,
create a new IAM user to get the access and secret keys.

Download the file from the bucket created previously, using the `aws s3 cp` command.

Delete the bucket.

## Test

1. When you'd use the CLI instead of the web console?
1. What type of service S3 belongs to?
1. How much your credit card be charged if a 1000 different users downloaded your file 100 times?
