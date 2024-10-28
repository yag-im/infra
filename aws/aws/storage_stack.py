import typing as t

from aws_cdk import (
    Duration,
    NestedStack,
    RemovalPolicy,
)
from aws_cdk import aws_s3
from constructs import Construct

class StorageStack(NestedStack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        **kwargs: dict[str, t.Any],
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.bucket = aws_s3.Bucket(
            self,
            id=f"bucket-yag-im-ports",
            bucket_name="yag-im-ports",
            removal_policy=RemovalPolicy.RETAIN,
            public_read_access=False,
            versioned=True,
            block_public_access=aws_s3.BlockPublicAccess.BLOCK_ALL,
            lifecycle_rules=[
                aws_s3.LifecycleRule(
                    transitions=[
                        aws_s3.Transition(
                            storage_class=aws_s3.StorageClass.DEEP_ARCHIVE,
                            transition_after=Duration.days(1),
                        )
                    ]
                )
            ],
        )
