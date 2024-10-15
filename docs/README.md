# OllyStack Documentation

## Tuning & Optimization

| Guide | What It Covers |
|-------|---------------|
| [Tuning Guide](tuning-guide.md) | Collector sizing, batch/queue/memory tuning, processor CPU costs, sampling strategies, exporter optimization, cost-per-signal math, topology decision tree |

## Operational Runbooks

Step-by-step guides for common OTel Collector operational issues.

| Runbook | When to Use |
|---------|-------------|
| [Collector High Memory](runbooks/collector-high-memory.md) | OOMKilled, memory pressure |
| [Collector Dropping Data](runbooks/collector-dropping-data.md) | Queue full, send failures |
| [Collector High CPU](runbooks/collector-high-cpu.md) | CPU throttling, latency spikes |
| [Pipeline Latency](runbooks/pipeline-latency.md) | Delayed traces, slow exports |
| [Exporter Auth Failures](runbooks/exporter-auth-failures.md) | 401/403 errors, token expiry |
| [Scaling Collectors](runbooks/scaling-collectors.md) | Capacity planning, horizontal scaling |
| [Upgrade Collector](runbooks/upgrade-collector.md) | Version upgrades, rollback |

## Secret Management

Guides for securely managing API keys, tokens, and certificates.

| Guide | Platform |
|-------|----------|
| [Kubernetes Secrets](secrets/kubernetes-secrets.md) | Any K8s cluster |
| [Vault Integration](secrets/vault-integration.md) | HashiCorp Vault |
| [AWS Secrets](secrets/aws-secrets.md) | AWS EKS |
| [Azure Key Vault](secrets/azure-keyvault.md) | Azure AKS |
