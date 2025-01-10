import typing as t

from aws_cdk import (
    Duration,
    Stack,
    aws_iam,
)
from aws_cdk import aws_route53 as aws_r53
from constructs import Construct

from aws.conf import (
    ACCOUNT_ID,
    TLD_ZONE_ID,  # must be modified after yag-prod dns stack is set up
    HOSTED_ZONE,
    PUBLIC_IP, # sync with `kubectl get svc -n istio-gw-public istio-gw-public` output
)
from aws.misc import get_fqdn


class DnsStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs: dict[str, t.Any]) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        env = self.node.try_get_context("env")

        if env == "prod":
            # create public yag.im hosted zone

            # policy to allow sub-accounts to make changes in TLD
            dns_policy = aws_iam.ManagedPolicy(
                self,
                id="dns-delegation-allow-policy",
                statements=[
                    aws_iam.PolicyStatement(
                        effect=aws_iam.Effect.ALLOW,
                        actions=["route53:ChangeResourceRecordSets"],
                        resources=["*"],
                    )
                ],
            )
            deleg_role = aws_iam.Role(
                self,
                id="dns-delegation-role",
                role_name="DnsDelegationRole",
                assumed_by=aws_iam.CompositePrincipal(
                    aws_iam.AccountPrincipal(str(ACCOUNT_ID["dev"])),
                ),
            )
            dns_policy.attach_to_role(deleg_role)
            self.main_zone = aws_r53.PublicHostedZone(
                self,
                id="tld-public-zone",
                zone_name=HOSTED_ZONE,
            )
            self.main_zone.grant_delegation(deleg_role)

            aws_r53.TxtRecord(
                self,
                id="yag-gmail-verification-rec",
                zone=self.main_zone,
                record_name="yag.im",
                values=["google-site-verification=TWWcXxwWFb1p5-eT9mG70o4GAwHepA5plqmIBrDEWxw"],
                ttl=Duration.seconds(300),
            )

            aws_r53.MxRecord(
                self,
                id="yag-gmail-mx-rec",
                zone=self.main_zone,
                values=[
                    aws_r53.MxRecordValue(priority=1, host_name="ASPMX.L.GOOGLE.COM."),
                    aws_r53.MxRecordValue(priority=5, host_name="ALT1.ASPMX.L.GOOGLE.COM."),
                    aws_r53.MxRecordValue(priority=5, host_name="ALT2.ASPMX.L.GOOGLE.COM."),
                    aws_r53.MxRecordValue(priority=10, host_name="ALT3.ASPMX.L.GOOGLE.COM."),
                    aws_r53.MxRecordValue(priority=10, host_name="ALT4.ASPMX.L.GOOGLE.COM."),
                ],
            )

            aws_r53.TxtRecord(
                self,
                id="github-domain-verification-rec",
                zone=self.main_zone,
                record_name="_gh-yag-im-o",
                values=["ce1e203728"],
                ttl=Duration.seconds(300),
            )
        else:
            # create {env}.yag.im record in yag prod account
            self.main_zone = aws_r53.PublicHostedZone(
                self,
                id="main-zone",
                zone_name=get_fqdn(HOSTED_ZONE, env),
            )
            aws_r53.CrossAccountZoneDelegationRecord(
                self,
                "cross-acc-zone-delegation-rec",
                delegated_zone=self.main_zone,
                parent_hosted_zone_id=TLD_ZONE_ID,
                delegation_role=aws_iam.Role.from_role_arn(
                    self, id="Role", role_arn=f'arn:aws:iam::{ACCOUNT_ID["prod"]}:role/DnsDelegationRole'
                ),
            )

        for hostname in {'', 'bastion', 'grafana'}:
            aws_r53.RecordSet(
                self, 
                id=f"record-set-{hostname}",
                zone=self.main_zone,
                record_name=hostname,
                record_type = aws_r53.RecordType.A,
                target=aws_r53.RecordTarget.from_ip_addresses(PUBLIC_IP[env]),
                ttl=Duration.seconds(300)
            )
