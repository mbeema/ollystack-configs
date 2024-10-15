# Cloud Provider Observability Deep Dive

> Comprehensive analysis of observability services across AWS, Azure, and GCP — architecture, capabilities, pricing, and OpenTelemetry integration for enterprise consulting engagements.

---

## Table of Contents

1. [Cross-Cloud Observability Overview](#1-cross-cloud-observability-overview)
2. [AWS CloudWatch](#2-aws-cloudwatch)
3. [AWS X-Ray and Distributed Tracing](#3-aws-x-ray-and-distributed-tracing)
4. [Amazon Managed Service for Prometheus (AMP)](#4-amazon-managed-service-for-prometheus-amp)
5. [Amazon Managed Grafana (AMG)](#5-amazon-managed-grafana-amg)
6. [AWS Distro for OpenTelemetry (ADOT)](#6-aws-distro-for-opentelemetry-adot)
7. [Amazon OpenSearch Service](#7-amazon-opensearch-service)
8. [AWS Service-Specific Observability](#8-aws-service-specific-observability)
9. [Azure Monitor](#9-azure-monitor)
10. [Azure Application Insights](#10-azure-application-insights)
11. [Azure Log Analytics and KQL](#11-azure-log-analytics-and-kql)
12. [Azure Managed Prometheus and Grafana](#12-azure-managed-prometheus-and-grafana)
13. [Azure OpenTelemetry Integration](#13-azure-opentelemetry-integration)
14. [Azure Service-Specific Observability](#14-azure-service-specific-observability)
15. [Azure Network and Security Observability](#15-azure-network-and-security-observability)
16. [Microsoft Sentinel (SIEM + SOAR)](#16-microsoft-sentinel-siem--soar)
17. [Google Cloud Operations Suite](#17-google-cloud-operations-suite)
18. [Google Cloud Monitoring](#18-google-cloud-monitoring)
19. [Google Cloud Logging](#19-google-cloud-logging)
20. [Google Cloud Trace and Profiler](#20-google-cloud-trace-and-profiler)
21. [Google Managed Prometheus (GMP)](#21-google-managed-prometheus-gmp)
22. [GKE Observability](#22-gke-observability)
23. [GCP Service-Specific Observability](#23-gcp-service-specific-observability)
24. [GCP OpenTelemetry Integration](#24-gcp-opentelemetry-integration)
25. [GCP Security Observability](#25-gcp-security-observability)
26. [Cross-Cloud Pricing Comparison](#26-cross-cloud-pricing-comparison)
27. [Cross-Cloud Architecture Comparison](#27-cross-cloud-architecture-comparison)
28. [Multi-Cloud Observability Strategies](#28-multi-cloud-observability-strategies)
29. [Key Dates and Timelines](#29-key-dates-and-timelines)

---

## 1. Cross-Cloud Observability Overview

### The Convergence Toward OpenTelemetry

All three major cloud providers have embraced OpenTelemetry as the standard for telemetry collection:

| Capability | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| **OTel Distribution** | ADOT (AWS Distro for OTel) | Azure Monitor OTel Distro | Google-Built OTel Collector |
| **Managed Prometheus** | AMP (Cortex-backed) | Azure Managed Prometheus (Thanos-backed) | GMP (Monarch-backed) |
| **Managed Grafana** | Amazon Managed Grafana | Azure Managed Grafana | Partner via GMP + Grafana |
| **Native OTLP Ingestion** | Via ADOT Collector | Via Azure Monitor Agent | Cloud Trace OTLP endpoint (2025) |
| **Auto-Instrumentation** | ADOT SDKs + Lambda Layers | App Insights OTel Distros | Google Cloud OTel Exporters |
| **Kubernetes Integration** | EKS Add-on (CloudWatch Observability) | AKS Container Insights + Prometheus | GKE Managed Collection |
| **SIEM** | OpenSearch + Security Lake | Microsoft Sentinel | Chronicle SIEM |
| **Query Language** | CloudWatch Logs Insights | KQL (Kusto Query Language) | MQL→PromQL (MQL deprecated Oct 2024) |

### Market Context (2025)

- **AWS**: 31% cloud market share, most mature observability ecosystem
- **Azure**: 25% cloud market share, tightest Microsoft 365/Active Directory integration
- **GCP**: 11% cloud market share, strongest in data analytics and ML, free Cloud Profiler and Error Reporting
- **Multi-cloud reality**: 87% of enterprises use 2+ cloud providers (Flexera 2025)

---

## 2. AWS CloudWatch

### Architecture Overview

CloudWatch is the foundational monitoring service for all AWS resources, consisting of:

- **Metrics**: Time-series data points (standard: 5-min, detailed: 1-min, custom: up to 1-sec)
- **Logs**: Log groups → log streams → log events, with Insights query engine
- **Alarms**: Static threshold, anomaly detection, composite, metric math
- **Dashboards**: Cross-account, cross-region visualization
- **ServiceLens**: Unified view combining X-Ray traces, CloudWatch metrics, and logs
- **Application Signals** (GA 2024): SLO monitoring with automatic service maps
- **Synthetics**: Canary-based endpoint monitoring
- **RUM**: Real user monitoring for web applications
- **Evidently**: Feature flags and A/B testing with metric analysis
- **Internet Monitor**: Internet path performance monitoring
- **Contributor Insights**: Top-N analysis on log/metric data

### Metric Types

| Type | Resolution | Cost | Use Case |
|------|-----------|------|----------|
| Basic monitoring | 5-minute | Free | Default EC2, EBS, ELB |
| Detailed monitoring | 1-minute | $0.30/metric/month | EC2 (opt-in) |
| Custom metrics | 1-minute default | $0.30/metric/month | Application metrics |
| High-resolution | 1-second | $0.30/metric/month | Real-time monitoring |
| Embedded Metric Format | 1-second capable | Log ingestion cost | High-cardinality metrics |

### Embedded Metric Format (EMF)

EMF allows publishing high-cardinality metrics through CloudWatch Logs at log ingestion cost rather than custom metric cost:

```json
{
  "_aws": {
    "Timestamp": 1234567890,
    "CloudWatchMetrics": [{
      "Namespace": "MyApp",
      "Dimensions": [["Service", "Environment"]],
      "Metrics": [
        {"Name": "Latency", "Unit": "Milliseconds"},
        {"Name": "ErrorCount", "Unit": "Count"}
      ]
    }]
  },
  "Service": "PaymentService",
  "Environment": "Production",
  "Latency": 125,
  "ErrorCount": 0,
  "RequestId": "abc-123",
  "CustomerId": "cust-456"
}
```

Properties (like `RequestId`, `CustomerId`) are queryable via Logs Insights but don't create separate metric dimensions, avoiding cardinality explosion.

### CloudWatch Logs Insights

Query syntax with practical examples:

```
# Find top 10 slowest requests
fields @timestamp, @message
| filter @message like /latency/
| stats avg(latency) as avgLatency, max(latency) as maxLatency by service
| sort maxLatency desc
| limit 10

# Error rate by service over time
filter @message like /ERROR/
| stats count() as errorCount by bin(5m) as timeWindow, service
| sort timeWindow desc

# P99 latency calculation
fields @timestamp, latency
| stats percentile(latency, 99) as p99, percentile(latency, 95) as p95,
        percentile(latency, 50) as p50 by bin(1h)
```

### CloudWatch Application Signals (GA 2024)

Automatic SLO monitoring without instrumentation changes:

- **Service Maps**: Auto-discovered topology from X-Ray/OTel traces
- **SLO Definitions**: Availability and latency SLOs with burn rate alerting
- **Pre-built Dashboards**: Request rate, error rate, latency (p50/p99) per service
- **Integration**: Works with ADOT auto-instrumentation (Java, Python, Node.js, .NET)
- **Pricing**: Included with CloudWatch; underlying metrics/traces billed at standard rates

### CloudWatch Synthetics

Canary scripts for proactive monitoring:

```javascript
// Node.js canary example
const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');

const apiCanaryBlueprint = async function () {
    const requestOptions = {
        hostname: 'api.example.com',
        method: 'GET',
        path: '/health',
        port: 443,
        protocol: 'https:'
    };
    const step = new synthetics.ApiCanary();
    await step.executeHttpStep('Health Check', requestOptions, null, (res) => {
        return new Promise((resolve, reject) => {
            if (res.statusCode !== 200) reject('Status: ' + res.statusCode);
            resolve();
        });
    });
};
exports.handler = async () => await apiCanaryBlueprint();
```

### Cross-Account Observability

- **Observability Access Manager (OAM)**: Link source accounts to a central monitoring account
- Shared: metrics, logs, traces, Application Signals data
- Single-pane-of-glass dashboards across 100+ accounts
- No data copying — queries fan out to source accounts

---

## 3. AWS X-Ray and Distributed Tracing

### Architecture

```
Application → X-Ray SDK/OTel SDK → X-Ray Daemon/OTel Collector → X-Ray Service
                                                                     ↓
                                                              Service Graph
                                                              Trace Map
                                                              Analytics
                                                              Insights
```

### Sampling Rules

| Rule Type | Configuration | Use Case |
|-----------|--------------|----------|
| Default | 1 req/sec + 5% additional | General baseline |
| Reservoir | Fixed N per second per service | Guaranteed minimum |
| Rate-based | Percentage of requests | Volume control |
| Adaptive (Sep 2025) | Auto-adjusts based on traffic | Cost/coverage balance |

### X-Ray SDK Deprecation Timeline

| Date | Event |
|------|-------|
| September 2024 | X-Ray SDK enters maintenance mode |
| February 2026 | End of support for X-Ray SDK |
| Ongoing | **Migrate to OpenTelemetry SDK** (recommended path) |

**Migration path**: Replace X-Ray SDK with OTel SDK + ADOT Collector configured with `awsxray` exporter. OTel traces are fully compatible with X-Ray service graph, analytics, and insights.

### X-Ray Insights

Automated anomaly detection on traces:
- Detects fault rate increases and latency anomalies
- Root cause identification: which service/API/client caused the anomaly
- Impact analysis: affected users and requests
- Pricing: $1.00/million traces processed

### X-Ray Filter Expressions

```
# Find errors in payment service
service("payment-service") { fault = true }

# Slow requests over 5 seconds
responsetime > 5

# Filter by annotation
annotation.customer_tier = "premium" AND http.status = 500

# Complex filter
service("api-gateway") {
  responsetime > 3 AND fault = true
} AND annotation.region = "us-east-1"
```

---

## 4. Amazon Managed Service for Prometheus (AMP)

### Architecture

- **Backend**: Based on Cortex (CNCF project), fully serverless
- **Ingestion**: Prometheus `remote_write` API (Sigv4 authenticated)
- **Querying**: Full PromQL via Prometheus-compatible query API
- **Storage**: Automatic, S3-backed, replicated across 3 AZs
- **Retention**: 150 days (default), data automatically managed

### Integration Options

1. **Self-managed Prometheus**: Configure `remote_write` to AMP endpoint
2. **ADOT Collector**: `awsprometheusremotewrite` exporter
3. **AMP Managed Collector**: Serverless Prometheus scraping (no self-managed Prometheus needed)
4. **Grafana Agent / Alloy**: Lightweight alternative to full Prometheus server

### EKS Configuration

```yaml
# ADOT Collector sending to AMP
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod

exporters:
  awsprometheusremotewrite:
    endpoint: "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-xxx/api/v1/remote_write"
    aws_auth:
      region: "us-east-1"
      service: "aps"

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [awsprometheusremotewrite]
```

### Alert Manager and Ruler

- **Recording rules**: Pre-compute frequently queried expressions
- **Alerting rules**: PromQL-based alert conditions
- **Alert Manager**: Routes alerts to Amazon SNS topics with grouping, inhibition, silencing
- **Configuration**: YAML format compatible with standalone Prometheus

### AMP Pricing (US East)

| Component | Price |
|-----------|-------|
| Ingestion: first 2B samples | $0.90 / 10M samples |
| Ingestion: next 250B samples | $0.35 / 10M samples |
| Ingestion: over 252B samples | $0.16 / 10M samples |
| Storage | $0.03 / GB-month |
| Query Samples Processed | $0.10 / 1B samples |
| Data Transfer IN | Free |

### AMP vs Self-Hosted Prometheus

| Dimension | AMP | Self-Hosted (Thanos/Mimir) |
|-----------|-----|---------------------------|
| Operational overhead | Zero (serverless) | Significant (10-20 hrs/month SRE time) |
| Scalability | Automatic horizontal | Manual configuration |
| Cost at 50K samples/sec | ~$11K-15K/month | ~$2.5K-5K/month (compute + S3) |
| Cost at low volume | Very cost-effective | Minimum ~$200-500/month infra |
| HA/DR | Multi-AZ automatic | Manual replicas |
| Lock-in | AWS API (Prometheus-compatible) | Fully open source |

**Recommendation**: AMP for teams wanting zero ops at moderate scale. Self-hosted Mimir/Thanos for high-volume environments (>500K samples/sec) where 4-5x cost savings justifies operational investment.

---

## 5. Amazon Managed Grafana (AMG)

### Workspace Features

- Fully managed Grafana server (supports versions 9.x and 10.x)
- SSO via IAM Identity Center (AWS SSO) or SAML 2.0
- Role mapping: Editor and Viewer roles per user/group

### Native Data Source Integrations

- Amazon Managed Service for Prometheus (AMP)
- Amazon CloudWatch (metrics and logs)
- AWS X-Ray (traces and service map)
- Amazon Timestream, OpenSearch, Athena, Redshift
- 100+ community/enterprise plugins

### AMG Pricing

| License Type | Price |
|-------------|-------|
| Editor/Admin | $9.00 / active user / workspace / month |
| Viewer | $5.00 / active user / workspace / month |
| Enterprise Plugins | +$45.00 / active user / workspace / month |
| Free trial | 90 days, up to 5 users per account |

---

## 6. AWS Distro for OpenTelemetry (ADOT)

### Components

**ADOT Collector** — AWS-supported distribution of the OTel Collector including:
- All core OTel Collector components
- AWS-specific exporters: X-Ray, EMF, Prometheus Remote Write
- AWS-specific receivers: ECS Container Metrics, X-Ray
- AWS-specific extensions: ECS Observer, Sigv4 Authenticator
- AWS-specific processors: Resource detection (EC2, ECS, EKS metadata)

**ADOT SDKs**: OpenTelemetry SDKs with AWS auto-instrumentation for Java, Python, Node.js, .NET, Go.

### EKS Add-on

```bash
aws eks create-addon \
  --cluster-name my-cluster \
  --addon-name amazon-cloudwatch-observability \
  --addon-version v2.5.0-eksbuild.1
```

Deploys ADOT Collector + OTel Operator + CloudWatch Agent + Fluent Bit.

### Lambda Layer

| Language | Layer Name Pattern | Version (2025) |
|----------|-------------------|----------------|
| Python | aws-otel-python-{arch}-ver-1-32-0 | 1.32.0 |
| Node.js | aws-otel-nodejs-{arch}-ver-1-30-0 | 1.30.0 |
| Java (Wrapper) | aws-otel-java-wrapper-{arch}-ver-1-32-0 | 1.32.0 |
| Java (Agent) | aws-otel-java-agent-{arch}-ver-1-32-0 | 1.32.0 |
| Collector-only | aws-otel-collector-{arch}-ver-0-117-0 | 0.117.0 |

### ADOT vs Community OTel Collector

| Aspect | ADOT | Upstream OTel Collector (contrib) |
|--------|------|----------------------------------|
| AWS support | Full AWS Support plan coverage | Community support only |
| Component set | Curated subset (~50 components) | All contrib (~200+ components) |
| Container image | public.ecr.aws/aws-observability/aws-otel-collector | otel/opentelemetry-collector-contrib |
| Switching cost | Change container image only | Change container image only |

### EKS Configuration Example

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: adot-collector
spec:
  mode: daemonset
  serviceAccount: adot-collector
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
            - job_name: 'k8s-pods'
              kubernetes_sd_configs:
                - role: pod
    processors:
      batch:
        timeout: 30s
        send_batch_size: 8192
      resourcedetection:
        detectors: [env, eks]
      memory_limiter:
        check_interval: 5s
        limit_mib: 512
    exporters:
      awsxray:
        region: us-east-1
      awsemf:
        region: us-east-1
        namespace: MyApp
      awsprometheusremotewrite:
        endpoint: https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-xxx/api/v1/remote_write
        aws_auth:
          region: us-east-1
          service: aps
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [awsxray]
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [awsprometheusremotewrite]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [awsemf]
```

---

## 7. Amazon OpenSearch Service

### Log Analytics

**Ingestion Patterns**:
- **Amazon OpenSearch Ingestion (OSI)**: Serverless, fully managed pipeline
- **Kinesis Data Firehose**: Buffered delivery with optional Lambda transformation
- **CloudWatch Logs subscription filters**: Real-time streaming
- **Fluent Bit / Logstash**: Direct ingestion from compute workloads
- **ADOT Collector**: OpenSearch exporter for OTel logs

**Index State Management (ISM)**:
- Hot tier: Active writes/queries (SSD-backed)
- Warm tier (UltraWarm): Read-only, S3-backed, ~$0.024/GB-month
- Cold tier: S3-backed, detached from cluster, cheapest

### Trace Analytics

OpenSearch supports distributed trace analytics compatible with:
- **OpenTelemetry**: Native OTLP ingestion via Data Prepper or OpenSearch Ingestion
- **Jaeger**: Full compatibility when OpenSearch is Jaeger backend
- Service map, trace waterfall view, trace-to-log correlation, span-level search

### Anomaly Detection

Uses **Random Cut Forest (RCF)** algorithm:
- Real-time anomaly detection on time-series data
- Configurable detection intervals (1-120 minutes)
- Multi-feature detectors (e.g., CPU + memory simultaneously)
- Integration with OpenSearch alerting

### OpenSearch Pricing

| Model | Compute | Storage | Best For |
|-------|---------|---------|----------|
| On-Demand | r6g.large ~$0.167/hr | EBS GP3: $0.08/GB-month | Variable workloads |
| Reserved (1yr) | ~35% discount | Same | Steady-state |
| Reserved (3yr) | ~52% discount | Same | Long-term |
| UltraWarm | Included | $0.024/GB-month | Warm/read-heavy data |
| Serverless | $0.24/OCU-hour | ~$0.024/GB-month | Unpredictable workloads |

---

## 8. AWS Service-Specific Observability

### EKS Observability

**Container Insights with Enhanced Observability**:
- Deployed via CloudWatch Observability EKS Add-on
- Infrastructure metrics: CPU, memory, network, disk per pod/node/cluster/namespace/service
- Control plane metrics: API server, etcd, scheduler, controller manager
- **Observation-based pricing**: Unified per-observation cost
  - 1,720 observations per cluster/minute
  - 68 observations per node/minute
  - 138 observations per pod/minute
- **Limitation**: Not supported on Fargate; use ADOT for Fargate

### ECS Observability

**FireLens (Fluent Bit Sidecar)**:
- Log router automatically injected into ECS tasks
- Automatic ECS metadata enrichment: cluster name, task ARN, container name
- Route logs to: CloudWatch Logs, S3, Kinesis, OpenSearch, Datadog, Splunk, Sumo Logic, New Relic

```json
{
  "containerDefinitions": [
    {
      "name": "log_router",
      "image": "amazon/aws-for-fluent-bit:latest",
      "firelensConfiguration": {
        "type": "fluentbit"
      }
    },
    {
      "name": "app",
      "logConfiguration": {
        "logDriver": "awsfirelens",
        "options": {
          "Name": "cloudwatch_logs",
          "region": "us-east-1",
          "log_group_name": "/ecs/my-app",
          "log_stream_prefix": "ecs-"
        }
      }
    }
  ]
}
```

### Lambda Observability

- **X-Ray Integration**: Automatic invocation segments + downstream subsegments
- **Powertools for AWS Lambda**: Structured logging, custom metrics via EMF, tracing (Python, TypeScript, Java, .NET)
- **Lambda Insights**: System-level metrics (CPU, memory, network, cold start detection)
- **ADOT Lambda Layer**: OTel auto-instrumentation for multi-backend export
- **Free metrics**: Invocations, Errors, Duration, Throttles, ConcurrentExecutions

### API Gateway Observability

- **Access Logs**: Customizable JSON/CLF format with `$context.*` variables
- **Execution Logs**: Detailed request/response payloads and integration timings
- **X-Ray Tracing**: API Gateway overhead + integration latency per stage
- **Metrics**: Count, 4XXError, 5XXError, IntegrationLatency, Latency

### RDS/Aurora Observability

**CloudWatch Database Insights** (replacing Performance Insights, 2025):
- Fleet-level monitoring across all database instances
- Database load visualization (AAS - Average Active Sessions)
- Wait event analysis (CPU, I/O, Lock, Network)
- Top SQL identification
- Cross-account and cross-region monitoring (November 2025)
- **Timeline**: Performance Insights console deprecated June 30, 2026

### DynamoDB/SQS/SNS Observability

**DynamoDB**:
- ConsumedReadCapacityUnits, ThrottledRequests, SuccessfulRequestLatency
- Contributor Insights: Top partition keys, most throttled items

**SQS**:
- ApproximateNumberOfMessagesVisible (queue depth)
- ApproximateAgeOfOldestMessage (critical for dead letter detection)

**SNS**:
- NumberOfMessagesPublished, NumberOfNotificationsDelivered/Failed
- Delivery status logging per subscription

### VPC Flow Logs

- **Custom format**: 30+ fields including vpc-id, subnet-id, tcp-flags, flow-direction, traffic-path
- **Destinations**: CloudWatch Logs, S3 (Athena queryable), Kinesis Data Firehose
- **VPC Traffic Mirroring**: Full packet capture (Layer 3-7) for deep inspection

### AWS Fault Injection Service (FIS)

- Pre-built experiment templates for EC2, ECS, EKS, Lambda, RDS, VPC
- Lambda support (October 2024): Inject latency, errors, invocation failures
- ECS Fargate (2025): Network fault injection
- CloudWatch alarms as guardrails: Auto-stop experiments when alarms fire

---

## 9. Azure Monitor

### Architecture Overview

Azure Monitor is the comprehensive monitoring platform for Azure:

```
Data Sources → Data Collection Rules (DCR) → Azure Monitor Pipeline
                                                    ↓
                                     ┌──────────────┼──────────────┐
                                     ↓              ↓              ↓
                              Log Analytics    Metrics Store    Managed
                              (Workspace)      (Azure Metrics)  Prometheus
                                     ↓              ↓              ↓
                              KQL Queries      Alerts/Dash    Grafana/PromQL
```

### Core Components

- **Azure Metrics**: Platform metrics (free) + custom metrics ($0.16/10M samples)
- **Log Analytics**: KQL-based log storage and querying (3 table plans: Analytics, Basic, Auxiliary)
- **Alerts**: Metric, log search, activity log, Prometheus, smart detection
- **Workbooks**: Interactive data-driven reports
- **Change Analysis**: Detects resource configuration changes correlated with incidents
- **Network Insights**: Pre-built dashboards for network resources

### Data Collection Rules (DCR)

DCRs are the unified pipeline for all data flowing into Azure Monitor:

- **Transformations**: KQL-based filtering before ingestion (30-70% cost reduction potential)
- **Multiple destinations**: Route different data to different Log Analytics tables
- **Agent configuration**: Replace legacy config for Azure Monitor Agent (AMA)

```kql
-- DCR transformation example: filter out noise before ingestion
source
| where severity != "DEBUG"
| where message !contains "health"
| where message !contains "/readyz"
| extend parsed = parse_json(message)
| project TimeGenerated, severity, parsed.service, parsed.message
```

### Table Plans

| Plan | Ingestion Cost | Query Cost | Interactive Retention | Use Case |
|------|---------------|------------|----------------------|----------|
| Analytics | $2.30/GB | Included | 31 days (configurable to 2 years) | Active monitoring |
| Basic | $0.50/GB | $0.006/GB queried | 8 days | High-volume, low-query |
| Auxiliary | $0.05/GB | $0.006/GB queried | 30 days | Compliance/audit |

### Alert Types and Pricing

| Alert Type | Price | Notes |
|------------|-------|-------|
| Metric Alert | $0.10/time series/month | First 10 free |
| Dynamic Threshold | Included with metric alert | ML-based anomaly detection |
| Log Alert | $0.50/month + $0.05/additional series | Based on evaluation frequency |
| Activity Log Alert | Free | Includes Service Health |
| Smart Detection | Free | ML-based (Application Insights) |

---

## 10. Azure Application Insights

### Workspace-Based Architecture

All new Application Insights resources are workspace-based (data stored in Log Analytics):

- **Application Map**: Auto-discovered service topology with health indicators
- **Live Metrics Stream**: Real-time metrics with <1 second latency
- **Transaction Search**: Full-text search across traces, exceptions, events
- **Failures and Performance**: Pre-built diagnostic views
- **Usage Analytics**: Users, Sessions, Events, Funnels, Cohorts, Impact, Retention
- **Availability Tests**: URL ping tests, standard tests (multi-step), custom TrackAvailability tests
- **Profiler**: Production profiling for .NET applications
- **Snapshot Debugger**: Automatic exception snapshots with local variable values

### Sampling Configuration

```json
{
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20,
        "excludedTypes": "Request;Exception"
      }
    }
  }
}
```

Three sampling types:
- **Adaptive**: Automatically adjusts to target volume (recommended)
- **Fixed-rate**: Consistent percentage across all instances
- **Ingestion**: Server-side sampling (last resort, wastes bandwidth)

### Connection String Migration

- **March 31, 2025**: Instrumentation key ingestion support ended
- All resources must use connection strings (format: `InstrumentationKey=...;IngestionEndpoint=...`)
- Connection strings support regional endpoints and custom ingestion URLs

---

## 11. Azure Log Analytics and KQL

### KQL Query Examples

```kql
// Application error analysis
AppExceptions
| where TimeGenerated > ago(24h)
| summarize ErrorCount = count() by ProblemId, OuterMessage
| order by ErrorCount desc
| take 20

// Service latency percentiles
AppRequests
| where TimeGenerated > ago(1h)
| summarize
    p50 = percentile(DurationMs, 50),
    p95 = percentile(DurationMs, 95),
    p99 = percentile(DurationMs, 99),
    requestCount = count()
  by bin(TimeGenerated, 5m), AppRoleName
| render timechart

// Dependency failure analysis
AppDependencies
| where TimeGenerated > ago(4h)
| where Success == false
| summarize FailCount = count() by Target, DependencyType, ResultCode
| order by FailCount desc

// Cross-table correlation: slow requests with their dependencies
AppRequests
| where TimeGenerated > ago(1h)
| where DurationMs > 5000
| join kind=inner (
    AppDependencies
    | where TimeGenerated > ago(1h)
  ) on OperationId
| project TimeGenerated, RequestName = Name, RequestDuration = DurationMs,
    DependencyName = Name1, DependencyDuration = DurationMs1, DependencyTarget = Target
| order by RequestDuration desc

// Container Insights: OOMKilled pods
KubeEvents
| where TimeGenerated > ago(24h)
| where Reason == "OOMKilling"
| summarize count() by Name, Namespace = Namespace_s
| order by count_ desc

// Azure SQL slow queries
AzureDiagnostics
| where ResourceType == "SERVERS/DATABASES"
| where Category == "QueryStoreRuntimeStatistics"
| where duration_d > 5000
| summarize avg(duration_d), count() by query_hash_s
| order by avg_duration_d desc

// Cosmos DB high-RU queries
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| where todouble(requestCharge_s) > 100
| summarize avg(todouble(requestCharge_s)), count() by OperationName, Resource
| order by avg_ desc

// Traffic Analytics: top talkers
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| where FlowType_s == "ExternalPublic"
| summarize TotalBytes = sum(todouble(InboundBytes_d) + todouble(OutboundBytes_d)) by SrcIP_s
| top 10 by TotalBytes desc

// Audit: resource deletions in last 7 days
AzureActivity
| where TimeGenerated > ago(7d)
| where OperationNameValue contains "delete"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, ResourceGroup,
    Resource = tostring(parse_json(Properties).resource), OperationNameValue
| order by TimeGenerated desc
```

---

## 12. Azure Managed Prometheus and Grafana

### Azure Managed Prometheus

- Based on Thanos architecture (open source CNCF project)
- Data stored in Azure Monitor Workspace
- 18-month retention included
- Native AKS integration via metrics add-on
- PromQL query support in Azure Monitor and Grafana

### AKS Integration

Default scrape targets when AKS Prometheus is enabled:
- kubelet, cAdvisor, kube-state-metrics, node-exporter
- Custom scrape configs via ConfigMap
- Istio metrics collection with pod annotation scraping

### Azure Managed Prometheus Pricing

| Component | Price | Notes |
|-----------|-------|-------|
| Metric samples ingested | ~$0.18/10M samples (first 50B) | Decreasing at higher volumes |
| Query samples processed | ~$0.006/10M samples | PromQL queries |
| Storage | Included | 18-month retention |

### Azure Managed Grafana Pricing

| Component | Price | Notes |
|-----------|-------|-------|
| Standard X1 instance | ~$0.043/hour (~$31/month) | Single zone |
| Zone-redundant | ~$0.051/hour (~$37/month) | Multi-zone HA |
| Active users | ~$6/user/month | Per user accessing in billing period |

---

## 13. Azure OpenTelemetry Integration

### Azure Monitor OpenTelemetry Distro

Azure provides OpenTelemetry-based SDKs (the recommended path for new projects):

| Language | Package | Status |
|----------|---------|--------|
| .NET | `Azure.Monitor.OpenTelemetry.AspNetCore` | GA |
| Java | `applicationinsights-agent-3.x.x.jar` | GA (OTel-based internally) |
| Node.js | `@azure/monitor-opentelemetry` | GA |
| Python | `azure-monitor-opentelemetry` | GA |

### OTel Collector Azure Monitor Exporter

```yaml
exporters:
  azuremonitor:
    connection_string: "InstrumentationKey=...;IngestionEndpoint=..."
    maxbatchsize: 100
    maxbatchinterval: 10s
```

### AKS Auto-Instrumentation

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: azure-monitor-otel
spec:
  exporter:
    endpoint: "http://otel-collector:4317"
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
```

Then annotate pods: `instrumentation.opentelemetry.io/inject-java: "azure-monitor-otel"`

### SDK Comparison

| Dimension | Classic App Insights SDK | Azure Monitor OTel Distro | Auto-Instrumentation |
|-----------|------------------------|--------------------------|---------------------|
| Code changes | Moderate | Minimal | None |
| Vendor lock-in | High (proprietary API) | Low (OTel standard) | Low |
| Profiler | Yes (.NET) | Not yet | Yes (.NET App Service) |
| Snapshot Debugger | Yes (.NET) | Not yet | Yes (.NET App Service) |
| Future direction | Maintenance mode | **Recommended path** | Recommended for simplicity |

---

## 14. Azure Service-Specific Observability

### AKS (Azure Kubernetes Service)

**Container Insights**:
- Container logs (`stdout`/`stderr`), performance metrics, Kubernetes events
- Deployed via Azure Monitor Agent (containerized)
- Data in Log Analytics: `ContainerLogV2`, `Perf`, `KubeEvents`, `KubePodInventory`
- Control plane metrics (2025): API server, etcd, scheduler, controller-manager via Managed Prometheus

**Cost Analysis Add-on**:
- Built on OpenCost (CNCF project)
- Available at no additional cost for Standard and Premium tier
- Cost allocation by namespace, deployment, node pool

### Azure App Service

- **App Service Diagnostics**: AI-powered diagnostic engine (CPU, memory, requests, networking)
- **Health Checks**: Pings specified path every 1 minute; removes instance after 10 consecutive failures
- **Auto-Heal**: Rules-based automatic mitigation (triggers: request count, slow requests, memory, HTTP status)
- **Proactive Auto-Heal**: Automatic restart when in unrecoverable state

### Azure Functions

- Native Application Insights integration (enabled by default)
- Durable Functions orchestration tracking via `traces` table
- Sampling configuration via `host.json`

### Azure SQL / Cosmos DB

**Azure SQL**:
- Intelligent Insights: AI-driven performance analysis (query duration regression, timeout increases)
- Query Performance Insight: Top CPU-consuming and wait-time queries
- Automatic index recommendations

**Cosmos DB**:
- Azure Cosmos DB Insights workbook
- Diagnostic Settings: DataPlaneRequests, QueryRuntimeStatistics, PartitionKeyStatistics
- Every response includes RU charge for cost attribution

### Azure Storage

- Storage Analytics metrics retired January 9, 2024
- Use Azure Monitor platform metrics: transaction counts, latency, availability, capacity
- Storage Insights workbook for cross-account views

### Azure Virtual Machines

**VM Insights**:
- Performance charts: CPU, memory, disk, network across all VMs
- Map view: Dependencies between VMs and external services
- Fleet-level analysis workbooks

**Performance Diagnostics (PerfInsights)**:
- Continuous mode: 5-second sampling, reports every 5 minutes
- On-demand mode: Deep-dive diagnosis of current issues

---

## 15. Azure Network and Security Observability

### Network Watcher

- **Topology view** of virtual network resources
- **Connection troubleshoot**: Test connectivity between resources
- **NSG Flow Logs** (being retired — no new logs after June 30, 2025; full retirement September 30, 2027)
- **VNet Flow Logs** (replacement — GA 2024): Logs traffic at virtual network level, broader coverage

**Traffic Analytics**:
- Enriches flow logs with geographic, ASN, Azure metadata
- Processing interval: 10 minutes or 1 hour
- Security insights: communication to open ports, known malicious IPs

### Azure Firewall

- Application Rule, Network Rule, DNS Proxy, Threat Intel logs
- Structured logs for KQL analysis:

```kql
AZFWNetworkRule
| where TimeGenerated > ago(1h)
| where Action == "Deny"
| summarize count() by SourceIP, DestinationIP, DestinationPort, Protocol
| order by count_ desc
```

### Microsoft Defender for Cloud

**Security Posture Management (CSPM)**:
- Secure Score across all Azure resources
- Regulatory compliance dashboards (CIS, NIST, PCI-DSS, ISO 27001)
- Attack path analysis

**Threat Detection**:
- Defender for Containers: Runtime threat detection for AKS
- Defender for Storage: Unusual access patterns, malware uploads
- Defender for SQL: SQL injection, anomalous queries, brute force
- Defender for Servers: Endpoint detection, vulnerability assessment
- Defender for Key Vault: Suspicious access patterns

---

## 16. Microsoft Sentinel (SIEM + SOAR)

### Architecture

- Built on Log Analytics workspace (KQL-based)
- Cloud-native SIEM with built-in AI/ML for threat detection
- 200+ data connectors (Microsoft, third-party, custom)
- Free data sources: Azure Activity Logs, Office 365 Audit Logs

### Analytics Rules

- **Scheduled rules**: KQL queries running at 5-minute to 24-hour intervals
- **Microsoft Security rules**: Auto-create incidents from Defender alerts
- **Fusion rules**: ML-based multi-stage attack detection
- **Near Real-Time (NRT) rules**: Run every minute for critical detections

```kql
// Detect brute force attempts
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType == "50126"  // Invalid username or password
| summarize FailureCount = count() by UserPrincipalName, IPAddress
| where FailureCount > 10
```

### SOAR (Playbooks)

Logic Apps-based automated response:
- Block IP in firewall, disable user account, create ServiceNow ticket
- Trigger on incident creation or alert

### Platform Evolution

- Sentinel being unified into Microsoft Defender portal (XDR + SIEM)
- **July 2025**: New customers auto-onboarded to Defender portal
- **March 31, 2027**: Sentinel leaves Azure portal; Defender portal only

### Sentinel Pricing

| Model | Price | Notes |
|-------|-------|-------|
| Pay-as-you-go | ~$5.20/GB | Ingestion + analysis |
| Commitment (100 GB/day) | ~$3.50/GB effective | Significant discount |
| Free data sources | $0 | Azure Activity Logs, Office 365 Audit Logs |

---

## 17. Google Cloud Operations Suite

### Architecture Overview

Google Cloud Observability (formerly Stackdriver) provides:

```
Data Sources → Cloud Ops API → Monarch (metrics) / Bonsai (logs) / Cloud Trace
                                        ↓
                              Cloud Monitoring Dashboard
                              Cloud Logging Explorer
                              Error Reporting
                              Cloud Profiler
                              PromQL / Log Analytics (BigQuery)
```

### Key Differentiators

- **Cloud Profiler**: **Free** — continuous production profiling (CPU, heap, contention)
- **Error Reporting**: **Free** — automatic error grouping and alerting
- **Alerting policies**: **Free** — unlimited alerting rules at no charge
- **GCP system metrics**: **Free** — all platform metrics for GCP resources (24-month retention)
- **MQL deprecated** (October 2024): PromQL is now the standard query language
- **Native OTLP support** (2025): Cloud Trace accepts OTLP directly via `telemetry.googleapis.com`

---

## 18. Google Cloud Monitoring

### Metrics Architecture

| Metric Type | Source | Cost | Retention |
|-------------|--------|------|-----------|
| GCP system metrics | Auto-collected | Free | 24 months |
| Custom metrics | SDK / OTel | $0.258/MiB (first 100K MiB) | 24 months |
| Prometheus metrics (GMP) | Prometheus scraping | $0.06/million samples | 24 months |
| External metrics | OTel / API | Custom metric pricing | 24 months |

### PromQL in Cloud Monitoring

Since MQL deprecation (October 2024), PromQL is the recommended query language:

```promql
# CPU utilization across GCE instances
avg by (instance_name)(
  rate(compute.googleapis.com:instance/cpu/utilization[5m])
)

# Error rate for Cloud Run service
sum(rate(run.googleapis.com:request_count{response_code_class="5xx"}[5m]))
/
sum(rate(run.googleapis.com:request_count[5m]))
```

### Alerting

- **Metric-based**: Static threshold, absence conditions
- **PromQL-based**: Full PromQL conditions in alerting policies
- **Forecast-based**: Alert when metric is predicted to cross threshold
- **Log-based**: Alert on log entry patterns
- **SLO burn rate**: Alert when error budget consumption exceeds threshold
- **Pricing**: All alerting is **free** (no per-alert charges)

### Uptime Checks

- HTTP, HTTPS, TCP protocols from 6+ global regions
- Content matching and SSL certificate expiration
- First 1M executions/month free; $0.30/1,000 executions after

### Monitoring Scopes

- Add up to **375 projects** to a single metrics scope for unified monitoring
- Cross-project dashboards and alerting policies
- Observability scopes for aggregated views

---

## 19. Google Cloud Logging

### Architecture

```
Log Sources → Cloud Logging API → Log Router → Destinations
                                      ↓
                              ┌───────┼────────┐
                              ↓       ↓        ↓
                        _Required   _Default   Custom
                        bucket     bucket     sinks
                        (400d)     (30d)      (BigQuery, GCS,
                                              Pub/Sub, Splunk,
                                              Log Buckets)
```

### Log Buckets

| Bucket | Retention | Cost | Contents |
|--------|-----------|------|----------|
| `_Required` | 400 days (fixed) | Free | Admin Activity, System Event audit logs |
| `_Default` | 30 days (configurable) | Standard pricing | All other logs |
| Custom | 1-3,650 days | Standard pricing | User-defined routing |

### Log Analytics

- Upgrade log buckets to use **BigQuery-compatible SQL** queries
- Query logs using standard SQL alongside BigQuery datasets
- Create linked BigQuery datasets for cross-log/business-data joins

### Logs-Based Metrics

Two types:
- **Counter metrics**: Count log entries matching a filter
- **Distribution metrics**: Extract numeric values from log entries into histograms

```
# Log exclusion filter (save 30-70% on ingestion)
resource.type="cloud_run_revision"
httpRequest.requestUrl="/healthz" OR httpRequest.requestUrl="/readyz"
```

### Cloud Logging Pricing

| Component | Free Tier | Price |
|-----------|-----------|-------|
| Ingestion | 50 GiB/project/month | $0.50/GiB |
| `_Required` bucket | Unlimited | Free |
| Retention beyond default | N/A | $0.01/GiB/month |
| Log Analytics queries | Included with bucket upgrade | No additional charge |

---

## 20. Google Cloud Trace and Profiler

### Cloud Trace

- Distributed tracing service compatible with OpenTelemetry, Zipkin
- **Native OTLP support** (2025): Direct ingestion via `telemetry.googleapis.com`
- Automatic trace generation for GCP services (Cloud Run, App Engine)
- Latency distribution analysis and trace waterfall view

### Cloud Trace Pricing

| Component | Free Tier | Price |
|-----------|-----------|-------|
| Ingestion | 2.5M spans/billing account/month | $0.20/million spans |
| Scanning | N/A | $0.02/million spans scanned |

### Cloud Profiler

**Completely free** — no additional charges:
- Continuous production profiling with minimal overhead (~0.5% CPU)
- Supported profiles: CPU, heap, contention (threads), wall-clock time
- Languages: Go, Java, Node.js, Python, .NET (preview)
- Compare profiles across versions/time periods
- Flame graph visualization

### Error Reporting

**Completely free** — no additional charges:
- Automatic error grouping across languages
- Stack trace deduplication
- Error count trends, affected user count
- Real-time alerting on new errors
- Languages: Go, Java, .NET, Node.js, PHP, Python, Ruby

---

## 21. Google Managed Prometheus (GMP)

### Architecture

- **Backend**: Monarch (Google's internal time-series database)
- **Ingestion**: Prometheus `remote_write` or GKE managed collection (PodMonitoring/ClusterPodMonitoring CRDs)
- **Querying**: Full PromQL via Prometheus-compatible API
- **Storage**: 24 months retention, free storage, sub-second query latency
- **Automatic geographic redundancy**

### GKE Integration

```bash
# Enable managed collection on GKE
gcloud container clusters update CLUSTER_NAME \
  --location=LOCATION \
  --enable-managed-prometheus
```

**Autopilot clusters**: GMP managed collection available; some metrics enabled by default
**Standard clusters**: Enable with cluster update

### Grafana Integration

```yaml
apiVersion: 1
datasources:
- name: GMP
  type: prometheus
  url: https://monitoring.googleapis.com/v1/projects/MY_PROJECT/location/global/prometheus
  access: proxy
  jsonData:
    authenticationType: gce
```

### GMP Pricing

| Tier | Samples/Month | Price per Million Samples |
|------|---------------|--------------------------|
| Tier 1 | 0 - 50B | $0.06 |
| Tier 2 | 50B - 250B | Lower (tiered) |
| Tier 3 | 250B+ | Lower (tiered) |

- **Storage**: Free (24-month retention included)
- **Queries**: Included (no separate query charges)
- **60% price reduction** applied August 2023

---

## 22. GKE Observability

### GKE System Metrics

- **Autopilot**: Always enabled
- **Standard**: Enabled by default
- Includes: container CPU/memory/network, pod status, node conditions
- Free for GCP system metrics

### GKE Control Plane Metrics

```bash
gcloud container clusters update CLUSTER_NAME \
  --location=LOCATION \
  --monitoring=SYSTEM,API_SERVER,SCHEDULER,CONTROLLER_MANAGER
```

Available metrics packages:
- **API Server**: `apiserver_request_total`, `apiserver_admission_webhook_admission_duration_seconds`
- **Scheduler**: `scheduler_e2e_scheduling_duration_seconds`, `scheduler_pending_pods`
- **Controller Manager**: `workqueue_depth`, `workqueue_adds_total`
- **Note**: Control plane metrics NOT available for Autopilot clusters

### GKE Dataplane V2 Observability (Cilium-Based)

- **Default for new Autopilot clusters** (GKE 1.28+)
- eBPF-based: kernel-level visibility without sidecar overhead
- Deploys Hubble Relay (telemetry collector), Hubble CLI (live traffic), optionally Hubble UI
- Captures: connection tracking, DNS, L7 HTTP metrics, packet drops
- Metrics exported to Cloud Monitoring and GMP

```bash
gcloud container clusters update CLUSTER_NAME \
  --location=LOCATION \
  --enable-dataplane-v2-flow-observability
```

### Autopilot vs Standard Observability

| Feature | Autopilot | Standard |
|---------|-----------|----------|
| System metrics | Always enabled | Default enabled |
| Control plane metrics | Not available | Opt-in |
| Managed Prometheus | Available | Available |
| Dataplane V2 metrics | Default (1.28+) | Opt-in |
| Custom DaemonSets | Restricted | Unrestricted |
| Node-level SSH | Not available | Available |

### Cloud Service Mesh (Istio)

- Automatic telemetry from Envoy sidecar proxies
- Golden signals: Latency, traffic (req/sec), errors (error rate)
- Service topology graph across clusters
- Integration: Cloud Monitoring, Cloud Logging, Cloud Trace

---

## 23. GCP Service-Specific Observability

### Cloud Run

- Request metrics: `request_count`, `request_latencies`
- Instance metrics: `container/instance_count` (active/idle), CPU/memory per instance
- Built-in tracing: Automatic trace generation for all requests (free)
- OTel sidecar: Deploy OTel Collector as sidecar for custom metrics

### Cloud Functions (2nd Gen)

- Invocation metrics: `execution_count` (by status: ok/error/timeout)
- Execution time distribution
- Memory usage: Peak memory per invocation
- 2nd gen built on Cloud Run: concurrent requests, better cold starts

### Cloud SQL

- **Query Insights**: Database load graph (CPU, IO wait, lock wait)
- Normalized query analysis with total execution time
- Application-level tracing (model, view, controller, route, user, host)
- Enterprise Plus: Wait event analysis, query plan capture

### Spanner

- **Query statistics**: `SPANNER_SYS.QUERY_STATS_*` tables (1/10/60-minute intervals)
- **Transaction statistics**: `SPANNER_SYS.TXN_STATS_*` tables (latency, lock wait)
- **Lock statistics**: `SPANNER_SYS.LOCK_STATS_*` tables
- **Key Visualizer**: Heatmap of data access patterns (identify hotspots and schema design issues)

### BigQuery

- **INFORMATION_SCHEMA views**: Job-level data, per-second slot utilization, 180-day retention
- **Slot utilization**: `total_slot_ms / (1000 * 60 * 60 * 24)` = average daily slots
- **Admin Resource Charts**: Built-in UI for slot usage, job concurrency, error rates

### Pub/Sub

- **Critical**: `oldest_unacked_message_age` (max pipeline delay indicator)
- `num_undelivered_messages` (backlog size)
- Alert when oldest unacked message age approaches retention period (default 7 days)

### Memorystore (Redis/Memcached)

- CPU utilization: Alert at 75%
- Memory usage ratio: Alert at 80%
- Connected clients: Alert at 80% of `maxclients`
- Eviction metrics: Any non-zero indicates under-provisioning

### Cloud Load Balancing

- Request/latency metrics: E2E and backend-only latencies
- Backend health: Automatic health check metrics
- Cloud Armor/WAF logs: DDoS protection and WAF rule evaluation

### VPC Flow Logs

- Two-stage sampling: primary (dynamic) + secondary (configurable, default 50%)
- Metadata annotations: Source/destination names, geographic region
- Cost optimization: Reduce sampling rate and filter by subnet

---

## 24. GCP OpenTelemetry Integration

### Google Cloud OpenTelemetry Exporters

Two main exporters in `opentelemetry-collector-contrib`:

1. **`googlecloud` exporter**: Metrics → Cloud Monitoring, traces → Cloud Trace, logs → Cloud Logging
2. **`googlemanagedprometheus` exporter**: Metrics → GMP/Monarch (Prometheus-compatible)

### OTel Collector Configuration for GKE

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_max_size: 200
    send_batch_size: 200
    timeout: 5s
  memory_limiter:
    check_interval: 1s
    limit_percentage: 65
    spike_limit_percentage: 20
  resourcedetection:
    detectors: [env, gcp]
    timeout: 10s
    override: false
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    extract:
      metadata:
        - k8s.pod.name
        - k8s.namespace.name
        - k8s.deployment.name

exporters:
  googlecloud:
    project: my-gcp-project
    log:
      default_log_name: otel-collector
  googlemanagedprometheus:
    project: my-gcp-project

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [googlecloud]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [googlemanagedprometheus]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [googlecloud]
```

### GCP Resource Detector

The `resourcedetection` processor with `gcp` detector automatically populates:
- `cloud.provider: gcp`, `cloud.platform: gcp_kubernetes_engine`
- `cloud.account.id: PROJECT_ID`, `cloud.region`, `cloud.availability_zone`
- `k8s.cluster.name`, `k8s.namespace.name`, `k8s.pod.name` (for GKE)

### IAM Requirements

```bash
# Grant OTel Collector service account required roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:otel-collector@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:otel-collector@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudtrace.agent"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:otel-collector@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

### Google-Built OTel Collector

Google provides a custom-built distribution (v0.143.0 as of 2025):
- Pre-configured with GCP exporters and resource detectors
- Available as container image for GKE, Cloud Run, Container-Optimized OS
- Includes `googlemanagedprometheus` exporter by default

### GCP Client Libraries vs OTel SDK

| Aspect | GCP Client Libraries | OpenTelemetry SDK |
|--------|---------------------|-------------------|
| Portability | GCP-only | Multi-cloud, vendor-neutral |
| Community | Google-maintained | CNCF community + vendors |
| Auto-instrumentation | Limited | Extensive |
| **Recommendation** | Legacy, still supported | **Preferred path forward** |

---

## 25. GCP Security Observability

### Security Command Center (SCC)

- **Tiers**: Standard (free), Premium (paid), Enterprise
- **Findings**: Security vulnerabilities, misconfigurations, threats
- **Threat Detection**: Event Threat Detection (log-based), Container Threat Detection (runtime), VM Threat Detection
- **Container Threat Detection**: Detects suspicious binaries, reverse shells, crypto mining, privilege escalation

### Chronicle SIEM (Google Security Operations)

- Cloud-native SIEM backed by Google infrastructure
- **YARA-L 2.0**: Detection rule language

```
rule suspicious_login {
  meta:
    description = "Detect login from unusual country"
  events:
    $login.metadata.event_type = "USER_LOGIN"
    $login.principal.ip_geo_artifact.location.country_or_region != "US"
    $login.target.user.userid = $user
  condition:
    $login
}
```

- **Composite detections** (2025 GA): Multi-stage threat detection
- 800+ log parsers, 300+ SOAR integrations
- 12 months hot data retention

### Cloud Audit Logs

| Log Type | Always On | Free | Retention | Use Case |
|----------|-----------|------|-----------|----------|
| Admin Activity | Yes | Yes | 400 days | Who modified resources |
| Data Access | No (enable per service) | No | 30 days | Who read data |
| System Event | Yes | Yes | 400 days | Google-initiated changes |
| Policy Denied | Configurable | No | 30 days | Security policy violations |

### Binary Authorization

- Deploy-time security control for container images
- Block deployment of unsigned/unattested images
- Continuous validation (CV): Periodically verify running pods conform to policy
- Audit logging of all admission decisions

---

## 26. Cross-Cloud Pricing Comparison

### Metrics Pricing

| Provider | Free Tier | Custom Metrics | Managed Prometheus |
|----------|-----------|---------------|-------------------|
| **AWS** | 10 custom metrics | $0.30/metric/month | $0.90/10M samples (first 2B) |
| **Azure** | Platform metrics free | $0.16/10M samples | ~$0.18/10M samples (first 50B) |
| **GCP** | All system metrics free | $0.258/MiB | $0.06/million samples |

### Log Pricing

| Provider | Free Tier | Ingestion | Storage | Query |
|----------|-----------|-----------|---------|-------|
| **AWS** | 5 GB/month | $0.50/GB | $0.03/GB-month | $0.005/GB scanned |
| **Azure** (Analytics) | 5 GB/month | $2.30/GB | $0.10/GB-month (>31d) | Included |
| **Azure** (Basic) | — | $0.50/GB | — | $0.006/GB queried |
| **GCP** | 50 GiB/project/month | $0.50/GiB | $0.01/GiB-month | Included |

### Trace Pricing

| Provider | Free Tier | Ingestion | Scanning |
|----------|-----------|-----------|----------|
| **AWS** (X-Ray) | 100K traces/month | $5.00/M traces | $0.50/M scanned |
| **Azure** | Per Log Analytics pricing | Per Log Analytics pricing | Per Log Analytics pricing |
| **GCP** | 2.5M spans/month | $0.20/M spans | $0.02/M scanned |

### Free Services Comparison

| Service | AWS | Azure | GCP |
|---------|-----|-------|-----|
| **Profiling** | — | Included (App Insights) | **Free** (Cloud Profiler) |
| **Error Tracking** | — | Smart Detection (free) | **Free** (Error Reporting) |
| **Alerting** | $0.10-0.30/alarm/month | $0.10-0.50/alert/month | **Free** (unlimited) |
| **System Metrics** | Basic monitoring free | Platform metrics free | **All free** (24mo retention) |

### Managed Prometheus Comparison

| Dimension | AWS AMP | Azure Managed Prom | GCP GMP |
|-----------|---------|-------------------|---------|
| Backend | Cortex | Thanos | Monarch |
| Retention | 150 days | 18 months | 24 months |
| Storage cost | $0.03/GB-month | Included | **Free** |
| Query cost | $0.10/1B samples | ~$0.006/10M | **Free** |
| Price per 10M samples | $0.90 (first 2B) | ~$0.18 (first 50B) | **$0.06** |
| Price reduction | — | — | 60% cut (Aug 2023) |

**Winner**: GCP GMP is significantly cheaper with free storage, free queries, and lowest ingestion cost.

---

## 27. Cross-Cloud Architecture Comparison

### Monitoring Stack

| Component | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| **Metrics Store** | CloudWatch Metrics / AMP | Azure Metrics / Managed Prometheus | Cloud Monitoring / GMP |
| **Log Store** | CloudWatch Logs / OpenSearch | Log Analytics | Cloud Logging / BigQuery |
| **Trace Store** | X-Ray | Application Insights | Cloud Trace |
| **Dashboarding** | CloudWatch Dashboards / AMG | Azure Workbooks / Managed Grafana | Cloud Monitoring Dashboards / Grafana |
| **Alerting** | CloudWatch Alarms | Azure Monitor Alerts | Cloud Monitoring Alerts |
| **APM** | Application Signals | Application Insights | Cloud Trace + Profiler + Error Reporting |
| **Synthetic Monitoring** | CloudWatch Synthetics | App Insights Availability Tests | Uptime Checks |
| **SIEM** | OpenSearch / Security Lake | Microsoft Sentinel | Chronicle SIEM |
| **Query Language** | Logs Insights / PromQL | KQL / PromQL | PromQL (MQL deprecated) |

### Kubernetes Observability

| Feature | AWS (EKS) | Azure (AKS) | GCP (GKE) |
|---------|-----------|-------------|-----------|
| **Container Metrics** | Container Insights (Add-on) | Container Insights (AMA) | System Metrics (default) |
| **Managed Prometheus** | AMP + ADOT | AKS Metrics Add-on | GMP Managed Collection |
| **Control Plane Metrics** | Via Container Insights | Via Managed Prometheus | Opt-in (Standard only) |
| **Cost Analysis** | — | OpenCost-based add-on | GKE cost optimization |
| **Network Observability** | VPC Flow Logs | VNet Flow Logs | Dataplane V2 (Cilium/Hubble) |
| **Service Mesh** | App Mesh (deprecated) / Istio | Istio / Open Service Mesh | Cloud Service Mesh (Istio) |

### OTel Integration Maturity

| Aspect | AWS | Azure | GCP |
|--------|-----|-------|-----|
| **OTel Distribution** | ADOT (curated ~50 components) | Azure Monitor OTel Distro | Google-Built OTel Collector |
| **Auto-Instrumentation** | Java, Python, Node.js, .NET, Go | .NET, Java, Node.js, Python | Via OTel Operator |
| **K8s Operator** | Via EKS Add-on | Via OTel Operator | Via OTel Operator |
| **Serverless** | Lambda Layers | Functions binding | Cloud Run sidecar |
| **Resource Detection** | EC2, ECS, EKS | Azure VM, AKS | GCE, GKE |
| **Native OTLP** | Via ADOT Collector | Via AMA/Exporter | Cloud Trace direct (2025) |

---

## 28. Multi-Cloud Observability Strategies

### Strategy 1: Cloud-Native Per Provider

Use each provider's native tools within their environment.

**Pros**: Deepest integration, lowest latency, free tiers
**Cons**: Multiple UIs, no unified view, different query languages
**Best for**: Teams with single-cloud primary and minimal multi-cloud

### Strategy 2: Centralized Open Source

Use Grafana + Prometheus + Loki + Tempo across all clouds.

**Pros**: Unified experience, no vendor lock-in, consistent queries
**Cons**: Operational overhead, no native integration depth
**Best for**: Platform engineering teams with SRE capacity

### Strategy 3: Hybrid with OTel

OpenTelemetry for collection, cloud-native for storage/analysis.

```
All Clouds → OTel Collector → Cloud-specific exporters → Native backends
                            → Central Grafana for unified dashboards
```

**Pros**: Vendor-neutral collection, deep native analysis, portability
**Cons**: Complexity of managing OTel configurations per cloud
**Best for**: Most enterprise environments (recommended approach)

### Strategy 4: Third-Party Platform

Use Datadog, Splunk, New Relic, Dynatrace, or Grafana Cloud across all environments.

**Pros**: Single pane of glass, unified alerting, managed service
**Cons**: Cost (typically 2-5x cloud-native), potential data sovereignty issues
**Best for**: Teams prioritizing simplicity over cost optimization

### BigQuery as Observability Data Lake (GCP)

- Route all Cloud Logging data to BigQuery for long-term analysis
- Ingest AWS CloudTrail, Azure Activity Logs via Pub/Sub to BigQuery
- SQL analytics: Join observability data with business data
- Connected Sheets: Analyze billions of log rows in Google Sheets

### Multi-Cloud with Ops Agent

GCP Ops Agent supports multi-cloud collection:
- Platforms: GCE VMs, AWS EC2, Azure VMs, on-premises servers
- Unified agent: Logs (Fluent Bit), metrics (OTel), traces
- OTLP support: Accept OTLP metrics and traces on configurable endpoints

---

## 29. Key Dates and Timelines

### AWS

| Date | Event |
|------|-------|
| 2024 | CloudWatch Application Signals GA |
| September 2024 | X-Ray SDK enters maintenance mode |
| October 2024 | FIS Lambda support |
| December 2024 | Container Insights enhanced observability for ECS GA |
| 2025 | CloudWatch Database Insights replacing Performance Insights |
| 2025 | X-Ray adaptive sampling |
| 2025 | CloudWatch Logs tiered pricing for Lambda |
| February 2026 | X-Ray SDK end of support |
| June 2026 | Performance Insights console deprecated |

### Azure

| Date | Event |
|------|-------|
| January 9, 2024 | Storage Analytics metrics retired |
| August 31, 2024 | Log Analytics agent (MMA) officially retired |
| March 31, 2025 | Instrumentation key ingestion support ended |
| June 30, 2025 | No new NSG flow log creation allowed |
| July 2025 | Sentinel auto-onboards new customers to Defender portal |
| September 30, 2026 | URL ping tests retire |
| March 31, 2027 | Sentinel leaves Azure portal (Defender portal only) |
| September 30, 2027 | NSG flow logs fully retired |

### GCP

| Date | Event |
|------|-------|
| August 2023 | GMP 60% price reduction |
| October 2024 | MQL deprecated; PromQL is standard |
| October 2025 | Monitoring API read pricing change (per-time-series-returned) |
| 2025 | Native OTLP support in Cloud Trace |
| 2025 | Google-Built OTel Collector v0.143.0 |
| 2025 | Chronicle composite detections GA |
| January 2026 | Firebase Crashlytics export to Cloud Logging |

---

## AWS Complete Pricing Reference

| Service | Charge Dimension | Price (US East) | Free Tier |
|---------|-----------------|-----------------|-----------|
| **CloudWatch Metrics** | Custom metrics (first 10K) | $0.30/metric/month | 10 metrics |
| **CloudWatch Logs** | Standard ingestion | $0.50/GB | 5 GB |
| | Infrequent Access ingestion | $0.25/GB | — |
| | Storage | $0.03/GB-month | 5 GB |
| | Logs Insights queries | $0.005/GB scanned | 5 GB |
| | Live Tail | $0.01/minute | 1,800 min |
| **CloudWatch Alarms** | Standard resolution | $0.10/alarm/month | 10 alarms |
| | High resolution | $0.30/alarm/month | — |
| **CloudWatch Dashboards** | Custom dashboards | $3.00/dashboard/month | 3 dashboards |
| **CloudWatch Synthetics** | Canary runs | $0.0012/run | 100 runs |
| **CloudWatch RUM** | RUM events | $1.00/100K events | 1M events |
| **X-Ray** | Traces recorded | $5.00/M traces | 100K traces |
| | Traces retrieved/scanned | $0.50/M traces | 1M traces |
| | X-Ray Insights | $1.00/M traces processed | — |
| **AMP** | Ingestion (first 2B) | $0.90/10M samples | — |
| | Storage | $0.03/GB-month | — |
| | Query | $0.10/1B samples | — |
| **AMG** | Editor/Admin license | $9.00/user/workspace/month | 90-day trial |
| | Viewer license | $5.00/user/workspace/month | — |

## Azure Complete Pricing Reference

| Service | Charge Dimension | Price | Free Tier |
|---------|-----------------|-------|-----------|
| **Platform Metrics** | Auto-collected | Free | All |
| **Custom Metrics** | Ingestion | $0.16/10M samples | — |
| **Analytics Logs (PAYG)** | Ingestion | $2.30/GB | 5 GB/month |
| **Analytics Logs (100 GB/day)** | Committed | ~$1.96/GB | — |
| **Basic Logs** | Ingestion + Query | $0.50/GB + $0.006/GB queried | — |
| **Auxiliary Logs** | Ingestion + Query | $0.05/GB + $0.006/GB queried | — |
| **Data Retention (>31d)** | Storage | ~$0.10/GB/month | — |
| **Archive** | Storage | ~$0.02/GB/month | — |
| **Metric Alert** | Per time series | $0.10/month | First 10 free |
| **Log Alert** | Per rule | $0.50/month | — |
| **Activity Log Alert** | Per rule | Free | All |
| **Managed Prometheus** | Ingestion | ~$0.18/10M samples | — |
| **Managed Grafana** | Instance | ~$31/month | — |
| **Sentinel (PAYG)** | Ingestion + Analysis | ~$5.20/GB | Free data sources |

## GCP Complete Pricing Reference

| Service | Charge Dimension | Price | Free Tier |
|---------|-----------------|-------|-----------|
| **Cloud Monitoring (system)** | Auto-collected | Free | All (24mo retention) |
| **Cloud Monitoring (custom)** | Ingestion | $0.258/MiB | 150 MiB/account/month |
| **Cloud Monitoring (GMP)** | Ingestion | $0.06/million samples | Included in above |
| **API reads** | Time series returned | $0.50/million | 1M/month |
| **Uptime checks** | Executions | $0.30/1,000 | 1M/month |
| **Cloud Logging** | Ingestion | $0.50/GiB | 50 GiB/project/month |
| **Cloud Logging** | `_Required` bucket | Free | Unlimited |
| **Cloud Logging** | Extended retention | $0.01/GiB/month | — |
| **Cloud Trace** | Ingestion | $0.20/million spans | 2.5M spans/account/month |
| **Cloud Trace** | Scanning | $0.02/million spans | — |
| **Cloud Profiler** | All usage | **Free** | Unlimited |
| **Error Reporting** | All usage | **Free** | Unlimited |
| **Alerting policies** | All | **Free** | Unlimited |

---

## Cost Optimization Strategies by Provider

### AWS Cost Optimization

1. **Log Cost Reduction** (typically 40-70% of CloudWatch spend):
   - Use Infrequent Access log class (50% ingestion savings)
   - Aggressive retention: 7d dev, 30d staging, 90d production
   - Archive to S3 via Firehose ($0.023/GB-month vs $0.50/GB ingestion + $0.03/GB storage)
   - Filter health check logs at source
   - Use metric filters instead of Logs Insights for known patterns

2. **Metric Cost Reduction**:
   - Audit custom metrics (each dimension combination = separate metric)
   - Use EMF instead of PutMetricData for high-cardinality data

3. **Trace Cost Reduction**:
   - X-Ray sampling rules (1-5% fixed rate + reservoir of 1-5/sec)
   - Tail-based sampling via OTel Collector

4. **AMP Cost Reduction**:
   - Recording rules to pre-aggregate frequently queried expressions
   - Drop unnecessary metrics at collector level
   - Reduce scrape frequency for non-critical metrics

### Azure Cost Optimization

1. **DCR Transformations** for filtering (30-70% ingestion reduction):
   ```kql
   source | where severity != "DEBUG" | where message !contains "health"
   ```

2. **Table Plan Strategy**:
   - Move high-volume, low-query tables to Basic Logs ($0.50 vs $2.30/GB)
   - Move compliance/audit to Auxiliary Logs ($0.05/GB)

3. **Commitment Tiers**: 15-45% savings on Analytics Logs

4. **Application Insights Sampling**: Adaptive sampling reduces 50-90% automatically

5. **Container Insights**: Switch to `ContainerLogV2`, filter namespaces, use Basic Logs

### GCP Cost Optimization

1. **Log exclusion filters** (drop health checks, debug logs):
   ```
   resource.type="cloud_run_revision"
   httpRequest.requestUrl="/healthz" OR httpRequest.requestUrl="/readyz"
   ```

2. **Log routing to Cloud Storage** ($0.020/GB-month vs $0.50/GiB ingestion)

3. **GMP metric filtering**:
   ```yaml
   metricRelabeling:
   - sourceLabels: [__name__]
     regex: "go_gc_.*|process_.*"
     action: drop
   ```

4. **Trace sampling**: Head sampling (10-20%) or tail sampling via OTel Collector

5. **Leverage free services**: Cloud Profiler, Error Reporting, all alerting, system metrics

---

## Monthly Cost Estimate: Moderate Production Environment

| Component | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| 50 VMs/instances monitoring | $105 (detailed) | Free (platform) | Free (system) |
| 100 custom metrics | $30 | $0.16 | $0.26 |
| 50 alarms/alerts | $5 | $5 | **Free** |
| 100 GB logs/day (30d retention) | $1,545 | $6,900 (Analytics) / $1,500 (Basic) | $1,500 |
| 10M traces/month | $50 | Per log pricing | $1.50 |
| 5 dashboards | $15 | Free (Workbooks) | Free |
| 5 synthetic checks (5-min) | $52 | ~$5 | Free (under 1M) |
| **Estimated Total** | **~$1,800/month** | **~$7,000 (Analytics) / ~$1,500 (Basic)** | **~$1,500/month** |

**Key insight**: Log ingestion dominates cost across all providers. GCP offers the best value with free profiling, alerting, and system metrics. Azure Analytics Logs are expensive but Basic Logs compete well. AWS is middle-ground.

---

*This document reflects the state of cloud provider observability services as of early 2026, incorporating all major 2024-2025 launches and pricing changes across AWS, Azure, and GCP.*
