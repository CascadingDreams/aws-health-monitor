import json
import os
import logging
import boto3


# Env variables - bucket name and SNS topic
BUCKET_NAME = os.environ.get('BUCKET_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC')

# AWS clients - created before handler once
s3 = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

def check_s3_health():
    '''
    Checks if S3 bucket responds and returns true, else false if 
    doesn't exist, network issue, no permission or other.
    returns: true or false
    '''
    try:
        s3.head_bucket(
            Bucket=BUCKET_NAME
            )
        return True
    except Exception as e:
        logging.error(f"S3 health check failed: {e}")
        return False

def publish_metric(value):
    '''
    Pushes 1 or 0 (true or false from check_s3_health) to Cloudwatch as a custom metric
    arg: value - either 1 (healthy) or 0 (unhealthy)
    returns: None 
    '''
    cloudwatch.put_metric_data(
        Namespace='HealthMonitor',
        MetricData=[{
         'MetricName': 'S3BucketHealth',
         'Value': value,
         'Unit': 'None'   
        }]
    )

def handler(event, context):
    '''
    Entry point - 
    args: event (trigger), context (runtime info)
    returns: dict with status code and a body
    '''
    healthy = check_s3_health()
    publish_metric(1 if healthy else 0)
    if not healthy:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='AWS Health monitor alert',
            Message=f'S3 bucket {BUCKET_NAME} is unhealthy - check in on it!'
        )
    return {
        'statusCode': 200,
        'body': 'healthy' if healthy else 'unhealthy'
    }
