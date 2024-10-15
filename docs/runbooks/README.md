# Operational Runbooks

This directory contains step-by-step runbooks for diagnosing and resolving common OpenTelemetry Collector operational issues. Each runbook follows a consistent format:

1. **Symptoms** -- Observable indicators that trigger the runbook
2. **Diagnosis** -- Commands and queries to identify root cause
3. **Resolution** -- Actionable steps with real config snippets and commands
4. **Prevention** -- Proactive measures to avoid recurrence

## Runbook Index

### Resource Issues
- [Collector High Memory](collector-high-memory.md) -- OOMKilled pods, memory_limiter dropping data
- [Collector High CPU](collector-high-cpu.md) -- CPU throttling, regex overhead, slow processing
- [Scaling Collectors](scaling-collectors.md) -- Capacity planning, HPA, three-tier architecture

### Data Flow Issues
- [Collector Dropping Data](collector-dropping-data.md) -- Queue full, exporter send failures, data gaps
- [Pipeline Latency](pipeline-latency.md) -- Delayed telemetry, batch timeout tuning, network optimization

### Security and Authentication
- [Exporter Auth Failures](exporter-auth-failures.md) -- 401/403 errors, token rotation, certificate renewal

### Lifecycle
- [Upgrade Collector](upgrade-collector.md) -- Version upgrades, canary deployment, rollback procedures

## How to Use These Runbooks

1. Identify the symptom from your monitoring alerts or user reports
2. Open the matching runbook from the index above
3. Follow the Diagnosis section to confirm root cause
4. Apply the Resolution steps appropriate to your situation
5. Implement the Prevention measures to avoid future incidents

## Related Documentation

- [Secret Management Guides](../secrets/) -- Managing API keys, tokens, and certificates
