import typing as t

from aws.dns_stack import DnsStack
from aws_cdk import Stack
from constructs import Construct

from aws.cdn_stack import CdnStack
from aws.conf import HOSTED_ZONE
from aws.storage_stack import StorageStack

class AwsStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, dns: DnsStack, **kwargs: dict[str, t.Any]) -> None:
        super().__init__(scope, construct_id, **kwargs)

        env = self.node.try_get_context("env")
        if env is None:
            raise RuntimeError()

        if env == "prod":
            cdn_stack = CdnStack(self, "CdnStack", main_zone=dns.main_zone, env=env, prefix="cdn")
            storage_stack = StorageStack(self, "StorageStack")
