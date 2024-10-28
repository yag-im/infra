import typing as t

from aws_cdk import (
    NestedStack,
    RemovalPolicy,
)
from aws_cdk import aws_certificatemanager as aws_cm
from aws_cdk import aws_cloudfront as aws_cf
from aws_cdk import aws_cloudfront_origins as aws_cfo
from aws_cdk import aws_route53 as aws_r53
from aws_cdk import aws_route53_targets as aws_r53t
from aws_cdk import aws_s3
from constructs import Construct

from aws.conf import HOSTED_ZONE
from aws.misc import get_fqdn


class CdnStack(NestedStack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        main_zone: aws_r53.PublicHostedZone,
        env: str,
        prefix: str,
        domain: t.Optional[str] = None,
        cert: t.Optional[aws_cm.Certificate] = None,
        **kwargs: dict[str, t.Any],
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.domain = domain or get_fqdn(HOSTED_ZONE, env, prefix)

        self.bucket = aws_s3.Bucket(
            self,
            id=f"bucket-{prefix}",
            bucket_name=self.domain,
            removal_policy=RemovalPolicy.RETAIN,
            versioned=False,
            block_public_access=aws_s3.BlockPublicAccess.BLOCK_ALL,
            access_control = aws_s3.BucketAccessControl.PRIVATE,
        )

        oai = aws_cf.OriginAccessIdentity(self, id=f"oai-{prefix}", comment=f"OAI for {prefix}")

        self.bucket.grant_read(oai)

        cf_cert = cert or aws_cm.DnsValidatedCertificate(
            self,
            f"cert-{prefix}",
            domain_name=self.domain,
            hosted_zone=main_zone,
            region="us-east-1",  # do not parametrize region, it must be hardcoded as us-east-1 for CloudFront
        )

        cf_distr = aws_cf.Distribution(
            self,
            f"cf-distr-{prefix}",
            certificate=cf_cert,
            default_root_object="",
            domain_names=[self.domain],
            default_behavior=aws_cf.BehaviorOptions(
                origin=aws_cfo.S3Origin(
                    bucket=self.bucket,
                    origin_access_identity=oai,
                ),
                allowed_methods=aws_cf.AllowedMethods.ALLOW_GET_HEAD,
                cached_methods=aws_cf.CachedMethods.CACHE_GET_HEAD,
                viewer_protocol_policy=aws_cf.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
            ),
            price_class=aws_cf.PriceClass.PRICE_CLASS_100,
        )

        # A record: fqdn -> xyz.cloudfront.net
        aws_r53.ARecord(
            self,
            id=f"a-rec-{prefix}",
            target=aws_r53.RecordTarget.from_alias(aws_r53t.CloudFrontTarget(cf_distr)),
            zone=main_zone,
            record_name=self.domain,
        )
