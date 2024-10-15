# AWS Native Backend

## Overview

This configuration sends OpenTelemetry data to AWS native observability services:

- **AWS X-Ray** - Distributed tracing
- **Amazon CloudWatch Logs** - Log management
- **Amazon CloudWatch Metrics (EMF)** - Metrics via Embedded Metric Format

## Prerequisites

1. An AWS account with appropriate IAM permissions
2. AWS credentials configured (via environment variables, IAM role, or shared credentials file)
3. The OpenTelemetry Collector Contrib distribution (includes AWS exporters)

## IAM Permissions

### Minimal Policy (Export Only)

The following IAM policy grants the minimum permissions for exporting traces, logs, and metrics:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OTelExporters",
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```

### Full Policy (Export + CloudWatch Receiver for All AWS Services)

If you're using the CloudWatch receiver fragments to pull metrics from AWS services (DynamoDB, RDS, Lambda, S3, etc.), add these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OTelExporters",
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    },
    {
      "Sid": "OTelCloudWatchReceivers",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "OTelResourceDetection",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

## Available CloudWatch Receiver Fragments

Each fragment pulls metrics for a specific AWS service from CloudWatch. Compose only the fragments you need:

| Fragment | AWS Service | Key Metrics |
|----------|------------|-------------|
| `awscloudwatch.yaml` | EC2, RDS (basic), ALB (basic) | CPU, memory, connections, request count |
| `awscloudwatch-dynamodb.yaml` | DynamoDB | Consumed RCU/WCU, throttles, latency, errors, table size, replication |
| `awscloudwatch-rds-aurora.yaml` | RDS & Aurora | IOPS, replication lag, deadlocks, storage, Aurora cluster, Serverless v2 ACU |
| `awscloudwatch-apigateway.yaml` | API Gateway | Request count, latency (p50/p90/p99), 4xx/5xx, cache hit/miss, WebSocket |
| `awscloudwatch-s3.yaml` | S3 | Bucket size, request counts, first byte latency, errors, replication |
| `awscloudwatch-elasticache.yaml` | ElastiCache | Cache hit/miss, evictions, replication lag, Redis commands, Memcached ops |
| `awscloudwatch-msk.yaml` | MSK (Managed Kafka) | Broker CPU/memory, consumer lag, throughput, partitions, replication |
| `awscloudwatch-sqs.yaml` | SQS | Queue depth, message age, send/receive/delete rates, DLQ |
| `awscloudwatch-sns.yaml` | SNS | Publish count, delivery success/failure, DLQ, SMS |
| `awscloudwatch-kinesis.yaml` | Kinesis Data Streams & Firehose | Iterator age, throughput, put/get records, throttling, EFO |
| `awscloudwatch-stepfunctions.yaml` | Step Functions | Executions (started/succeeded/failed/timed out), duration, activities, Express |
| `awscloudwatch-eventbridge.yaml` | EventBridge | Matched events, invocations, failures, throttled rules, Pipes |
| `awscloudwatch-elb.yaml` | ALB & NLB (full) | All HTTP codes, latency percentiles, target health, connections, TLS, gRPC |
| `awscloudwatch-cloudfront.yaml` | CloudFront | Requests, data transfer, error rates, cache hit ratio, origin latency, Functions |
| `awscloudwatch-lambda.yaml` | Lambda | Invocations, errors, duration (p50/p90/p99), throttles, concurrency, cold starts, Insights |

### Example: Composing Fragments

```bash
otelcol --config=collector/base/otel-gateway-base.yaml \
        --config=collector/fragments/receivers/awscloudwatch.yaml \
        --config=collector/fragments/receivers/awscloudwatch-dynamodb.yaml \
        --config=collector/fragments/receivers/awscloudwatch-rds-aurora.yaml \
        --config=collector/fragments/receivers/awscloudwatch-sqs.yaml \
        --config=collector/fragments/receivers/awscloudwatch-lambda.yaml \
        --config=collector/fragments/processors/batch.yaml \
        --config=collector/fragments/exporters/otlp-grpc.yaml
```

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `AWS_REGION` | AWS region for all services | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | AWS access key (if not using IAM role) | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key (if not using IAM role) | `wJal...` |
| `AWS_CW_LOG_GROUP` | CloudWatch Logs log group name | `/otel/collector/logs` |
| `AWS_CW_LOG_STREAM` | CloudWatch Logs log stream name | `otel-logs` |
| `AWS_CW_NAMESPACE` | CloudWatch Metrics namespace | `OTel/Application` |
| `CLOUDWATCH_POLL_INTERVAL` | How often to poll CloudWatch (default: 5m) | `5m` |
| `CLOUDWATCH_PERIOD` | CloudWatch metric period (default: 300s) | `300s` |

## Usage

1. Set the required environment variables:

```bash
export AWS_REGION="us-east-1"
# If not using IAM roles:
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Authentication

AWS exporters support the standard AWS credential chain:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Shared credentials file (`~/.aws/credentials`)
3. IAM role for Amazon EC2 / ECS / EKS
4. IAM Roles Anywhere (for hybrid environments)

**Recommendation**: Use IAM roles when running on AWS infrastructure.

## Verifying Data

- **Traces**: Navigate to AWS Console > CloudWatch > X-Ray > Traces
- **Logs**: Navigate to AWS Console > CloudWatch > Logs > Log Groups
- **Metrics**: Navigate to AWS Console > CloudWatch > Metrics > Custom Namespaces

## Notes

- AWS X-Ray exporter converts OTLP spans to X-Ray segment format
- CloudWatch EMF exporter publishes metrics as embedded metric format log events
- The log group and log stream are created automatically if they do not exist
- For EKS workloads, use IAM Roles for Service Accounts (IRSA) for authentication
- All AWS exporters require the Collector Contrib distribution
- CloudFront metrics are **only** available in `us-east-1` regardless of edge location
- S3 request metrics require opt-in per bucket (daily storage metrics are always available)
- MSK enhanced monitoring (per-broker, per-topic) requires opt-in in cluster configuration
- Lambda Insights requires adding the Lambda Insights extension layer
