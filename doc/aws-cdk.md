# AWS CDK

## Activate and install deps
    
    python -m venv .venv
    source .venv/bin/activate

    pip install -r requirements.txt

## Bootstrap

    cdk bootstrap --profile yag-dev -c env=dev
    cdk bootstrap --profile yag-prod -c env=prod

Manual steps to bootstrap DNS:

    cdk deploy DnsStack --profile yag-prod -c env=prod

    - Update NS records: 
        AWS -> "infra" account -> Route 53 -> Registered Domains -> yag.im -> Action: edit name servers
    - Update aws/conf.py: TLD_ZONE_ID value, get from:
        AWS -> "yag-prod" account -> Route 53 -> Hosted Zones -> yag.im -> Check zone ID
    - Wait 24 hours?

## Deploy

    cdk deploy --all --profile yag-dev -c env=dev
    cdk deploy --all --profile yag-prod -c env=prod

## Destroy

    cdk destroy AwsStack --profile yag-dev -c env=dev
    cdk destroy AwsStack --profile yag-prod -c env=prod
