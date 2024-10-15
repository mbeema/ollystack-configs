# Full-Stack Observability on AWS EKS

Complete deployment guide for running the OllyStack OpenTelemetry stack on Amazon Elastic Kubernetes Service (EKS).

## Architecture

```
+------------------+     +------------------+     +-------------------+
|  Application     |     |  OTel Agent      |     |  OTel Gateway     |
|  Pods            +---->+  (DaemonSet)     +---->+  (Deployment)     |
|  (instrumented)  |     |  per node        |     |  centralized      |
+------------------+     +------------------+     +--------+----------+
                                                           |
                         +------------------+              |
                         |  Cluster         |              |
                         |  Receiver        +--------------+
                         |  (Deployment)    |              |
                         +------------------+              v
                                                  +--------+----------+
                                                  |  AWS Backends      |
                                                  |  - CloudWatch      |
                                                  |  - X-Ray           |
                                                  |  - AMP (Prometheus)|
                                                  +-------------------+
```

## Prerequisites

- **AWS CLI** v2+ configured with appropriate credentials
- **kubectl** v1.28+
- **eksctl** v0.170+ or Terraform
- **Helm** v3.12+
- **kustomize** v5+ (or use `kubectl -k`)
- An existing EKS cluster (v1.28+) or permissions to create one
- IAM permissions for:
  - CloudWatch Logs and Metrics
  - AWS X-Ray
  - Amazon Managed Prometheus (AMP)
  - EKS cluster management

## Deployment Steps

### 1. Configure AWS Environment

```bash
# Set your AWS region and cluster name
export AWS_REGION=us-west-2
export CLUSTER_NAME=my-observability-cluster
export AMP_WORKSPACE_ID=ws-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Verify cluster access
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl cluster-info
```

### 2. Create IAM Roles for Service Accounts (IRSA)

```bash
# Create OIDC provider for the cluster (if not already done)
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --approve

# Create IAM role for the OTel Collector
eksctl create iamserviceaccount \
  --name otel-collector \
  --namespace observability \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --attach-policy-arn arn:aws:iam::policy/CloudWatchAgentServerPolicy \
  --attach-policy-arn arn:aws:iam::policy/AWSXRayDaemonWriteAccess \
  --attach-policy-arn arn:aws:iam::policy/AmazonPrometheusRemoteWriteAccess \
  --approve
```

### 3. Deploy the OTel Stack

```bash
# Create the namespace
kubectl create namespace observability

# Deploy using Kustomize
kubectl apply -k examples/full-stack-aws-eks/

# Or deploy using Helm with the provided values
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Deploy the Agent (DaemonSet)
helm install otel-agent open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-aws-eks/values.yaml \
  --set mode=daemonset

# Deploy the Gateway (Deployment)
helm install otel-gateway open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-aws-eks/values.yaml \
  --set mode=deployment

# Deploy the Cluster Receiver
helm install otel-cluster open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-aws-eks/values.yaml \
  --set mode=deployment \
  --set clusterReceiver.enabled=true
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n observability

# Verify the agent is running on all nodes
kubectl get daemonset -n observability

# Check collector logs for errors
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# Verify health endpoint
kubectl port-forward -n observability svc/otel-agent 13133:13133 &
curl http://localhost:13133/health
```

### 5. Verify Telemetry Flow

```bash
# Check traces in X-Ray
aws xray get-trace-summaries \
  --start-time $(date -d '5 minutes ago' -u +%s) \
  --end-time $(date -u +%s) \
  --region $AWS_REGION

# Check metrics in AMP
awscurl --service aps \
  "https://aps-workspaces.${AWS_REGION}.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/api/v1/query?query=up"

# Check logs in CloudWatch
aws logs describe-log-groups \
  --log-group-name-prefix /ollystack \
  --region $AWS_REGION
```

## Configuration Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomize overlay referencing base manifests with AWS patches |
| `values.yaml` | Helm values for full EKS deployment |

## Troubleshooting

### Collector pods in CrashLoopBackOff

1. Check logs: `kubectl logs -n observability <pod-name>`
2. Verify IAM role is correctly attached: `kubectl describe sa otel-collector -n observability`
3. Ensure the config is valid: `./scripts/validate-configs.sh`

### No traces appearing in X-Ray

1. Verify IRSA is configured correctly
2. Check the collector's debug exporter output
3. Ensure the `awsxray` exporter is properly configured
4. Verify security group rules allow outbound HTTPS

### High memory usage

1. Adjust `memory_limiter` processor settings
2. Reduce batch size in `batch` processor
3. Check for cardinality explosion in metrics

## Cleanup

```bash
# Remove the OTel stack
kubectl delete -k examples/full-stack-aws-eks/

# Or if using Helm
helm uninstall otel-agent otel-gateway otel-cluster -n observability

# Delete namespace
kubectl delete namespace observability

# Remove IRSA
eksctl delete iamserviceaccount \
  --name otel-collector \
  --namespace observability \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION
```
