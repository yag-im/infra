#!/usr/bin/env python3

import aws_cdk as cdk

from aws.aws_stack import AwsStack
from aws.dns_stack import DnsStack


app = cdk.App()
dns = DnsStack(app, "DnsStack")
AwsStack(app, "AwsStack", dns=dns)

app.synth()
