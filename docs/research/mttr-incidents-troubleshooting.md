# MTTR, Incident Management, Events, Profiles & Troubleshooting

> **OllyStack Research Document** | February 2026
>
> Comprehensive guide covering incident lifecycle, MTTR reduction strategies, the five observability signals (with deep dives on events and profiles), and systematic troubleshooting methodologies.

---

## Table of Contents

1. [MTTR Breakdown and DORA Metrics](#1-mttr-breakdown-and-dora-metrics)
2. [Incident Management](#2-incident-management)
3. [How to Reduce MTTR](#3-how-to-reduce-mttr)
4. [Incident Reduction](#4-incident-reduction)
5. [Events as an Observability Signal](#5-events-as-an-observability-signal)
6. [Continuous Profiling Deep Dive](#6-continuous-profiling-deep-dive)
7. [Troubleshooting Methodologies](#7-troubleshooting-methodologies)
8. [Cross-Signal Correlation](#8-cross-signal-correlation)
9. [Common Troubleshooting Scenarios](#9-common-troubleshooting-scenarios)
10. [AI-Assisted Troubleshooting](#10-ai-assisted-troubleshooting)
11. [Building Effective Runbooks](#11-building-effective-runbooks)

---

## 1. MTTR Breakdown and DORA Metrics

### 1.1 The MTTR Equation

MTTR (Mean Time to Resolve) is not a single metric -- it's a composite of multiple phases:

```
MTTR = MTTD + MTTA + MTTI + Time-to-Fix + Time-to-Verify
```

| Phase | Metric | Definition |
|-------|--------|------------|
| Detection | MTTD (Mean Time to Detect) | Time from failure occurrence to first alert firing |
| Acknowledgment | MTTA (Mean Time to Acknowledge) | Time from alert to human response |
| Investigation | MTTI (Mean Time to Investigate) | Time from acknowledgment to root cause identification |
| Repair | Time-to-Fix | Time to implement the fix or mitigation |
| Verification | Time-to-Verify | Time to confirm service restoration |

DORA refined this metric in 2023 to focus specifically on failures caused by **software changes** rather than external infrastructure outages. In 2024, DORA further reclassified time-to-restore as a **throughput** measure rather than a stability measure.

### 1.2 DORA 2024 Metrics and Benchmarks

The 2024 Accelerate State of DevOps report introduced the **fifth metric** (rework rate) and reclassified the four-metric model into a five-metric model of "Software Delivery Throughput and Instability."

**Performance Cluster Benchmarks (2024):**

| Metric | Elite | High | Medium | Low |
|--------|-------|------|--------|-----|
| Deployment Frequency | Multiple times/day | Daily to weekly | Weekly to monthly | Less than monthly |
| Lead Time for Changes | Less than 1 hour | 1 day to 1 week | 1 week to 1 month | More than 1 month |
| Time to Restore Service | Less than 1 hour | Less than 1 day | Less than 1 week | More than 1 week |
| Change Failure Rate | 0-5% | 0-15% | 16-30% | 46-60% |

**Cluster Distribution (2024):**
- Elite: ~18-19% of respondents (stable year-over-year)
- High: 22% (shrunk from 31% in 2023)
- Medium: ~34%
- Low: 25% (increased from 17% in 2023)

Key finding: Elite performers deploy **182x more frequently** and recover **2,293x faster** than low performers. Only 19% of teams achieved elite status in 2024.

### 1.3 Industry MTTR Benchmarks by Sector

| Sector | Target MTTR | Context |
|--------|-------------|---------|
| Financial services | < 30 minutes | Regulatory and revenue pressure |
| Healthcare (life-critical) | < 15 minutes | Life-support equipment |
| SaaS providers | < 1 hour | Customer-facing, revenue-critical |
| E-commerce | < 1 hour | Revenue loss $25K-$100K/hour |
| General enterprise | < 4 hours | Varies by criticality |
| Manufacturing/facilities | 4-6 hours | Physical systems, planned windows |

Enterprise organizations with dedicated security teams achieve **30-40% faster MTTR** than mid-market companies (2024 Ponemon Institute).

### 1.4 MTTR Evolution (2019-2024)

- **2019-2020**: DORA framework solidified the four key metrics. MTTR defined broadly as "time to restore service."
- **2021**: DORA expanded "availability" to "reliability," incorporating latency, performance, and scalability.
- **2022-2023**: MTTR renamed/refined to focus on software-change failures. Average MTTR improved 26% YoY for high-business-impact outages (New Relic 2023).
- **2024**: Time-to-restore reclassified as throughput metric. "Rework rate" added as new stability metric. Industry average MTTR dropped only 12% since 2020 despite 3x increase in monitoring spend -- indicating tooling alone is insufficient without process improvements.

**The cost of downtime**: Average unplanned downtime costs **$5,600 to $9,000 per minute**. For mid-market SaaS, one hour costs **$25,000-$100,000**.

---

## 2. Incident Management

### 2.1 Incident Severity Levels

| Level | Name | Definition | Response Time | Resolution Target | Who Gets Involved |
|-------|------|------------|---------------|-------------------|-------------------|
| SEV1 | Critical | Core services unavailable, all/most users blocked, data at risk, no workaround | Immediate (< 5 min) | < 1 hour | All hands, wake people up, executive comms, status page |
| SEV2 | Major | Key feature broken, large user group affected, limited workarounds | < 15-30 min | < 4 hours | On-call team, paging after-hours, customer comms likely |
| SEV3 | Moderate | Non-critical feature degraded, users can continue working | 1-2 hours (business hours) | 48-72 hours | On-call acknowledges, scheduled fix |
| SEV4 | Minor | Cosmetic bugs, edge cases, small user subset | Next business day | 1-2 weeks | Ticket filed, addressed in sprint |
| SEV5 | Informational | Feature requests, backlog items, negligible impact | No immediate response | Backlog | Product/engineering review |

**Classification factors**: scope of impact (1% = SEV3/4, 50%+ = SEV1/2), criticality of service, business/revenue implications, data integrity risk.

### 2.2 Incident Lifecycle Stages

**Stage 1: Detection**
- Monitoring tools (Grafana, Datadog, Prometheus) detect anomalies
- Alerts fire based on threshold breaches or SLO burn rate
- Customer reports or synthetic monitoring failures trigger escalation
- Goal: minimize MTTD

**Stage 2: Triage & Acknowledgment**
- On-call engineer receives notification, acknowledges alert
- Severity classification applied (SEV1-5)
- Incident channel created (Slack/Teams)
- Incident commander assigned for SEV1/2
- Goal: minimize MTTA

**Stage 3: Investigation & Diagnosis**
- Root cause analysis begins
- Logs, metrics, traces correlated
- Affected services and blast radius identified
- Subject matter experts pulled in as needed
- Goal: minimize MTTI

**Stage 4: Containment & Resolution**
- Immediate mitigation (rollback, feature flag toggle, traffic rerouting)
- Permanent fix identified and implemented
- Service restoration verified
- Customer communications updated

**Stage 5: Recovery & Verification**
- Full service restoration confirmed
- Performance baselines re-established
- Monitoring confirms stability
- Status page updated to "resolved"

**Stage 6: Postmortem & Learning**
- Blameless postmortem conducted within 24-72 hours
- Root cause documented with "Five Whys" technique
- Action items assigned with owners and deadlines
- Learnings shared across organization

### 2.3 Incident Management Tools Comparison

#### PagerDuty
- **Pricing**: Free (5 users), Professional ($21/user/mo), Business ($41/user/mo), Digital Operations ($99/user/mo). AIOps is a paid add-on licensed per accepted event.
- **Strengths**: 700+ integrations, mature alerting engine, industry standard for 10+ years, advanced escalation policies
- **Weaknesses**: Expensive with add-ons (20-person Business plan = ~$10K/year before add-ons), legacy UI/UX, AIOps costs extra
- **Best for**: Large enterprises (500+ employees) with complex incident response processes

#### Grafana IRM (Incident Response & Management)
- **Pricing**: Free for up to 3 active IRM users (Grafana Cloud Free). Paid tiers billed per monthly active IRM user. Sift AI diagnostics included free.
- **Strengths**: Native Grafana ecosystem integration (Loki, Mimir, Tempo), on-call scheduling with Terraform/iCal, AI-powered Sift diagnostics, open-source OnCall component
- **Weaknesses**: Best value only in Grafana ecosystem, less mature than dedicated tools, smaller integration catalog
- **Best for**: Teams already using Grafana for observability

#### Rootly
- **Pricing**: Essentials (~$20/user/mo, $12K/year for 50 users), Scale (~$35/user/mo, $42K/year for 100 users). 14-day free trial.
- **Strengths**: AI-native platform, deep Slack/Teams integration, powerful no-code workflow automation, auto-generated postmortems, claims up to 70% MTTR reduction, ~half the cost of PagerDuty
- **Weaknesses**: Newer platform, requires Slack/Teams dependency, smaller integration catalog
- **Best for**: Mid-to-large engineering teams (50-500 engineers) wanting automation

#### FireHydrant
- **Pricing**: Starter ($20/user/mo), Advanced ($44/user/mo), custom Enterprise tier
- **Strengths**: Strong service catalog and runbook automation, structured incident response, AI insights, combined alerting + on-call + incidents + status pages
- **Weaknesses**: Higher learning curve, annual billing for some plans
- **Best for**: Large enterprises with complex microservice architectures

#### incident.io
- **Pricing**: Team plan ($25/user/mo) includes on-call, status pages, postmortem generation
- **Strengths**: Slack-native design, AI-driven workflows, inclusive pricing (bundled features), intuitive UX
- **Weaknesses**: Newer entrant, primarily Slack-focused
- **Best for**: Engineering-centric teams that live in Slack

**Cost savings note**: Teams switching from PagerDuty to Slack-native alternatives save **30-60% on TCO** and reduce coordination overhead by ~15 minutes per incident.

### 2.4 On-Call Best Practices

**Rotation Patterns:**

| Pattern | Description | Best For |
|---------|-------------|----------|
| Weekly | One engineer on-call for 7 days | Small teams, simple services |
| Follow-the-sun | 3-4 shifts across global time zones | Distributed teams, no night shifts |
| Primary/Secondary | Two engineers always on-call (primary + shadow) | Training, high-severity services |
| Round-robin | Alerts rotate through a pool of responders | Even load distribution |

**Key Practices:**
- Target no more than **2 incidents per 12-hour shift** (Google SRE guidance)
- Mandatory handover process with context transfer at shift boundaries
- Compensate on-call with additional pay or time off
- Track on-call burden metrics (pages per shift, hours engaged, after-hours pages)
- Fine-tune alerts to minimize false positives and alert fatigue
- Minimum 8 engineers needed for a single-site primary/secondary rotation

### 2.5 Blameless Postmortem Template

**Core Philosophy**: Focus on contributing causes without indicting individuals. "Blameless does not mean consequence-free -- it means assigning ownership of the fix, not the fault."

**Template Components:**
1. **Incident metadata**: ID, severity, date/time, duration, services affected
2. **Summary**: 2-3 sentences on what happened and impact
3. **Timeline**: Chronological sequence from detection to resolution
4. **Root cause analysis**: "Five Whys" technique to drill to systemic cause
5. **Impact assessment**: Users affected, revenue impact, SLA/SLO impact, error budget consumed
6. **What went well**: Celebrate effective responses
7. **What went wrong**: System and process failures (not people failures)
8. **Where we got lucky**: Things that could have been worse
9. **Action items**: Each with owner, priority, and deadline
10. **Lessons learned**: Systemic improvements for prevention

**Timing**: Sweet spot is **24-72 hours** after resolution. Never skip postmortems for SEV1/2 incidents.

---

## 3. How to Reduce MTTR

### 3.1 Top 10 Strategies with Specific Numbers

| # | Strategy | Impact |
|---|----------|--------|
| 1 | Implement comprehensive observability (metrics, logs, traces) | Cuts diagnostic time by **60%** |
| 2 | Deploy AIOps for alert correlation and noise reduction | Reduces alert noise by **80-93%**, MTTR by **25-50%** within 90 days |
| 3 | Adopt SLO-based burn-rate alerting | Eliminates threshold-based noise, focuses on user impact |
| 4 | Standardize runbooks and response procedures | Ensures consistent response regardless of who is on-call |
| 5 | Automate common remediation actions | MTTR from hours to **under 2 minutes** (Torq HyperSOC) |
| 6 | Implement Slack/Teams-native incident management | Median P1 MTTR drops from 48 min to **< 30 min** |
| 7 | Build service dependency maps and topology awareness | Faster blast radius identification |
| 8 | Conduct regular chaos engineering and game days | Proactively discovers failure modes, **245% ROI** |
| 9 | Enable AI-generated incident timelines and postmortems | Reduces post-incident analysis time by **50-70%** |
| 10 | Deploy canary deployments and feature flags | Reduces deployment failure rates by **68%**, cuts MTTR by **85%** |

### 3.2 SLO-Based Burn Rate Alerting

The multi-window, multi-burn-rate technique from Google SRE Workbook is the gold standard:

**Burn rate** = actual error rate / error budget consumption rate. A burn rate of 1 means the error budget is consumed exactly at the end of the compliance period.

| Window | Burn Rate | Detection Speed | Use Case |
|--------|-----------|-----------------|----------|
| 1-hour | 14.4x | ~5 min | Acute crises (bad deployments) |
| 6-hour | 6x | ~30 min | Significant issues |
| 3-day | 1x | Hours | Chronic degradation |

Each window uses a short check window alongside the longer lookback to reduce false positives.

**Error Budget Policy Thresholds:**
- \> 50% budget remaining: normal development velocity
- 25-50% remaining: increased review, additional testing
- < 25% remaining: reliability-focused sprint, reduced deployments
- 0% remaining: **feature freeze** until budget recovers

### 3.3 AI/ML Impact on MTTR

| Vendor | Product | Key Claims |
|--------|---------|------------|
| **Grafana** | Sift AI | ML-driven anomaly detection across metrics/logs/traces. Auto-checks for log anomalies, HTTP error patterns. Included free in all Grafana Cloud tiers |
| **Datadog** | Watchdog + Intelligent Correlation | AI anomaly detection and alert correlation. 27% less alert noise. Auto event grouping/deduplication |
| **PagerDuty** | AIOps (Intelligent Alert Grouping) | ML-based alert grouping. Licensed per accepted event (add-on cost) |
| **BigPanda** | AIOps Platform | 80% noise reduction in 8 weeks, 90%+ over time. 25% MTTR reduction in 90 days. One customer: 69% fewer incidents, 85% MTTR reduction |
| **Dynatrace** | Davis AI | 56% faster MTTR for critical incidents. Auto-remediation via Workflows |
| **IBM** | Instana Intelligent Remediation | 70% MTTR reduction, 90% less troubleshooting time, 75% faster incident response |
| **New Relic** | AI Observability | 27% less alert noise, 25% faster fixes, up to 5x higher deployment rates |

Overall industry: AIOps can reduce MTTR by **up to 40%** on average.

### 3.4 Correlation Engines and Noise Reduction

Raw event volumes vs. actionable incidents show dramatic ratios:

| Metric | Value |
|--------|-------|
| Effective filtering reduction | **60-80%** without losing actionable data |
| WEC Energy Group deduplication | **98.8%** deduplication, 53.9% alert-to-incident correlation |
| Hierarchical correlation models | **87% reduction** in alert data |
| Typical raw-to-actionable ratio | 1,700 events → 29 alerts |

Correlation techniques: topology-based grouping, time-based grouping, content-based grouping, ML-based learned patterns.

### 3.5 Auto-Remediation Patterns

**Common Actions:**
- Pod restart (delete CrashLoopBackOff pods to trigger recreation)
- Horizontal scaling (scale replicas when CPU/memory exceeded)
- Node drain (move workloads off failing nodes)
- Rollback (automated when canary metrics degrade)
- Cache clearing (flush when hit-rate drops below threshold)
- Traffic rerouting (shift away from degraded regions/AZs)
- Certificate renewal (auto-renew before expiration)

**Required Safeguards:**
- Human approval gates for high-risk actions
- Blackout windows during sensitive periods
- Blast radius limiting (affect only N% of fleet)
- Rate limiting (max N auto-remediations per hour)
- Dry-run mode before enabling
- Circuit breaker patterns with failure rate thresholds
- Audit logging for all automated actions

### 3.6 Case Studies

| Company | Approach | Results |
|---------|----------|---------|
| HCL Technologies | Moogsoft AIOps | 33% MTTR reduction, 85% event consolidation, 62% fewer help-desk tickets |
| CMC Networks (62 countries) | BigPanda + NetBrain | 38% MTTR reduction via AI event correlation |
| Gamma (European telco) | BigPanda AIOps | 93% alert noise reduction |
| Torq HyperSOC | Full automation | MTTR from hours to under 2 minutes |
| WEC Energy Group | Event correlation | 98.8% deduplication, 53.9% correlation |

---

## 4. Incident Reduction

### 4.1 Proactive Monitoring Patterns

- **Anomaly detection**: ML-based baseline learning that alerts on deviations, not static thresholds
- **Predictive alerting**: Forecasting threshold breaches before they happen (e.g., disk filling in 4 hours)
- **SLO monitoring**: Track error budget burn rate to catch degradation pre-incident
- **Dependency health checks**: Monitor third-party API latency, error rates, availability
- **Infrastructure drift detection**: Alert when configs diverge from desired state
- **Capacity planning alerts**: Proactive scaling before resource exhaustion
- **Synthetic monitoring**: Simulate user journeys at regular intervals to detect issues before real users

### 4.2 Chaos Engineering and Game Days

**Major Tools:**

| Tool | Type | Best For |
|------|------|----------|
| Netflix Chaos Monkey / Simian Army | OSS | Origin of chaos engineering, EC2 instance termination |
| Gremlin | Commercial | Enterprise-grade with guardrails |
| LitmusChaos | OSS (K8s-native) | Large library of pre-built fault experiments |
| AWS Fault Injection Simulator | AWS Service | Native fault injection for EC2, RDS, EKS |
| Steadybit | Commercial | Automated, continuous chaos testing |

**Results:**
- Chaos engineering delivers **245% ROI** (Forrester Consulting)
- Netflix survived the 2015 DynamoDB outage with less downtime than competitors due to Chaos Kong experiments
- Common outcomes: increased availability, lower MTTR/MTTD, fewer bugs shipped, reduced on-call burden

**Game Day Best Practices:**
- Run like a real unplanned incident
- Assign a scribe to document gaps in monitoring and troubleshooting
- Start with tabletop exercises before live fault injection
- Never target production without proper safeguards
- Conduct at least quarterly (AWS Well-Architected recommendation)
- Follow up with action items like a real postmortem

### 4.3 Progressive Delivery

**Canary Deployments:**
- Roll out to 1-5% of users/instances
- Monitor error rate, latency, saturation against baseline
- Gradually increase if metrics healthy, automated rollback if degraded
- AI-powered monitoring reduces failure rates by **68%**

**Feature Flags:**
- Decouple deployment from release -- code ships but stays inactive
- Enable progressive rollout (1% → 10% → 50% → 100%)
- Instant kill switch without rollback
- Market growing from $1.45B (2024) to $5.19B (2033)
- Providers: LaunchDarkly, Split.io, Unleash, Flagsmith, ConfigCat

**Combined Pattern:**
1. Deploy with feature flag off
2. Enable canary for small percentage
3. Monitor SLOs and error budget impact
4. Expand or rollback based on data
5. Result: dramatically fewer production incidents from bad deployments

---

## 5. Events as an Observability Signal

### 5.1 Events vs Logs vs Traces

Events are **discrete occurrences** that represent something that happened at a specific point in time. While they share characteristics with logs, they are semantically distinct:

| Signal | Purpose | Cardinality | Example |
|--------|---------|-------------|---------|
| **Logs** | Continuous stream of application output | Very high | `INFO: Processing request for user 12345` |
| **Events** | Discrete, meaningful occurrences with metadata | Low-medium | `deployment.completed: v2.3.1 to production` |
| **Traces** | Request flow across distributed services | Medium-high | Span tree showing request path |

Events have **business/operational meaning** -- they're not just text output but structured records of significant occurrences.

### 5.2 Types of Events

| Type | Description | Examples |
|------|-------------|---------|
| **Deployment events** | Code/config releases | CI/CD pipeline completions, container image updates, Helm chart upgrades |
| **Change events** | Infrastructure/config modifications | Kubernetes scaling events, config map updates, DNS changes, security group modifications |
| **Alert events** | Monitoring system notifications | Threshold breaches, SLO burn rate alerts, anomaly detections |
| **Business events** | Revenue/user-impacting occurrences | Payment processing milestones, user signup spikes, cart abandonment patterns |
| **Infrastructure events** | Platform-level occurrences | Node additions/removals, AZ failovers, certificate rotations, maintenance windows |

### 5.3 OTel Events

In OpenTelemetry, events are implemented as **LogRecords with an `event.name` attribute**:

- The `event.name` attribute identifies the class/type of event
- The `event.domain` attribute provides namespace scoping (e.g., `browser`, `device`, `k8s`)
- Event body contains structured data specific to the event type
- Events follow OTel Semantic Conventions for standardized schemas
- The Events API is designed for instrumenting applications, while the Logs API handles log appender integrations

### 5.4 Change Intelligence

Change intelligence automatically correlates changes with performance regressions -- one of the highest-value applications of events:

1. **Ingest** all change events (CI/CD webhooks, config management, cloud API changes)
2. **Maintain** a timeline of changes per service/environment
3. **Detect** when a performance regression occurs
4. **Correlate** with recent changes, ranking by likelihood (temporal proximity, scope, blast radius)

**Platform Capabilities:**
- **Datadog Change Overlays**: Automatically overlay change events on dashboard graphs (100+ integrations)
- **Dynatrace Causal Intelligence**: Davis AI uses causal (not just temporal) correlation
- **New Relic Change Tracking**: Correlates deployments with error rates, throughput, response time
- **Honeycomb BubbleUp**: Automatically identifies which attributes differ in anomalous groups

### 5.5 Event-Driven Observability Patterns

| Pattern | Description |
|---------|-------------|
| **Change Overlay** | Overlay deployment/config events on metric dashboards for instant correlation |
| **Event-Driven Alerting** | Correlate metric anomalies with recent events for context-rich alerts |
| **Event Sourcing** | Treat event sequence as authoritative record, replay to reconstruct state |
| **Business Signal Correlation** | Connect business events (revenue drop) with technical signals |
| **Event-Driven Remediation** | Deployment + error spike → automatic rollback |

### 5.6 Tools for Event Management

| Tool | Key Features |
|------|-------------|
| **PagerDuty Events API v2** | Asynchronous event ingestion, routing to services, dedup_key support, trigger/acknowledge/resolve actions, 700+ integrations |
| **Datadog Events** | Events Explorer for search/filter/analyze, custom events via Agent/DogStatsD/API, Event Monitors for alerting, Change Overlays |
| **Grafana Annotations** | Mark time-series visualizations with event data, Annotations HTTP API, tag support, point-in-time or region annotations |
| **Honeycomb Markers** | Indicate deploy/outage/incident points on graphs, Marker Settings for grouping, environment-scoped markers |

---

## 6. Continuous Profiling Deep Dive

### 6.1 Why Continuous Profiling Matters

Continuous profiling is the practice of collecting runtime performance data (CPU, memory, lock contention) from production applications continuously, with low overhead. It's called the **"5th pillar"** of observability:

| Signal | Question Answered |
|--------|-------------------|
| Metrics | Is something wrong? |
| Logs | What error occurred? |
| Traces | Which service/endpoint is the bottleneck? |
| **Profiles** | **Which function/line of code is the bottleneck?** |
| Events | What changed that caused this? |

Development profiles don't reflect production behavior. Many organizations waste **20-30% of cloud resources** on inefficient code paths that continuous profiling can identify.

### 6.2 Profile Types

| Type | What It Measures | Key Insight |
|------|-----------------|-------------|
| **CPU** | Call stack samples at ~100Hz | Which functions consume CPU cycles |
| **Memory/Heap** | Object allocations and live heap | Memory leaks and excessive GC |
| **Wall Clock** | Elapsed real time (all threads) | Where time is spent including I/O waits |
| **Goroutine** (Go) | Number and state of goroutines | Goroutine leaks, concurrency bottlenecks |
| **Mutex/Lock** | Time waiting to acquire locks | Contention points and lock holders |
| **Off-CPU** | Thread sleep/wake events | I/O bottlenecks, blocking operations |
| **Block** | Time blocked on sync primitives | Channel/mutex/condvar blocking |

### 6.3 eBPF-Based Profiling

eBPF (extended Berkeley Packet Filter) enables profiling with **< 1% overhead**:

**How it works:**
1. eBPF program attaches to `perf_events` in kernel space
2. Hardware performance counters trigger sampling at configurable intervals
3. On each sample, the kernel captures the stack trace
4. Stack traces aggregated in eBPF maps (hash maps in kernel memory)
5. User-space component periodically reads accumulated results
6. Symbols resolved (addresses → function names)
7. Data sent to profiling backend for storage and visualization

**Key advantages:**
- No instrumentation required -- no code changes, no recompilation, no restart
- Stack capture happens entirely in kernel space (no context switches)
- eBPF bytecode verified by kernel for safety and bounded execution
- Typical overhead: 0.5-1% CPU, < 50MB memory per node
- For N replicas, only one profiled at a time → effective overhead = 1/N

### 6.4 Profiling Tools Comparison

| Tool | eBPF | Languages | Overhead | Cost | Storage |
|------|------|-----------|----------|------|---------|
| **Grafana Pyroscope** | Yes (+ agents) | Go, Java, Python, Ruby, Node, .NET, Rust, PHP | 1-3% | OSS (AGPLv3) / Grafana Cloud | Parquet + symdb |
| **Parca** | Yes (primary) | C/C++, Go, Rust + interpreted via eBPF | < 1% | OSS (Apache 2.0) / Polar Signals Cloud | FrostDB (columnar) |
| **Elastic Universal Profiling** | Yes (primary) | 10+ languages incl. PHP, Perl, Zig | < 1% | Elastic subscription | Elasticsearch |
| **Datadog Profiler** | No (agent) | Java, .NET, Go, Python, Ruby, Node, PHP | 2-3% | $19/host/mo standalone, $40/host/mo with APM | Proprietary |
| **Google Cloud Profiler** | No (agent) | Go, Java, Node.js, Python | ~5% | **Free** | Google Cloud |
| **AWS CodeGuru Profiler** | No (agent) | Java, Python only | Low | $0.005/sampling-hr | AWS |

**Grafana Pyroscope**: Microservices-based architecture (distributor, ingester, query-frontend, querier, store-gateway, compactor). Uses Parquet tables for profile data. FlameQL query language. Deep Grafana ecosystem integration.

**Parca**: Single-binary or distributed. Purpose-built FrostDB columnar database. Symbolization at 1M+ addresses/sec/core. Kubernetes-native. eBPF agent donated to OpenTelemetry.

**Elastic Universal Profiling**: Whole-system, always-on. Mixed-language stack traces. eBPF agent donated to OpenTelemetry as `opentelemetry-ebpf-profiler`.

### 6.5 OTel Profiling Signal Status (2026)

| Component | Status |
|-----------|--------|
| Data model (pprofextended) | **Stable** |
| OTLP transport | Experimental (`/v1development/profiles`) |
| Collector receiver/exporter | Experimental |
| Language SDKs | Early stages |
| eBPF agent (`opentelemetry-ebpf-profiler`) | Active development |

The pprofextended format is backward compatible with original pprof, adds shared call stacks, OTel semantic conventions, trace_id/span_id linking for cross-signal correlation, and first-class timestamp support.

### 6.6 Flame Graphs

Invented by **Brendan Gregg** in 2011. The standard visualization for profiling data.

**How to read:**
- **Y-axis**: Stack depth (bottom = root/main, top = leaf function)
- **X-axis**: NOT time. Width = proportion of samples. Wider = more time.
- **Left-to-right**: Alphabetical (for frame merging), NOT chronological
- **Finding bottlenecks**: Look for **wide plateaus at the top** -- functions directly consuming CPU with no children

**Icicle charts** (root at top, inverted) are often preferred because the root is always visible without scrolling.

**Differential flame graphs**: Compare two profiles (before/after). Red = takes MORE time, Blue = takes LESS time, White = no change.

### 6.7 Real-World Profiling Wins

| Company | Finding | Savings |
|---------|---------|---------|
| **Datadog** | Profile-guided optimization for Go services (single CI change) | $250K/year |
| **Datadog** | Full optimization campaign over 2 months | **$17.5M/year** in cloud costs |
| **Uber** | Found `runtime.morestack` regression via pprof flame graphs | Halved metrics ingestion latency |
| **Shopify** | Continuous profiling for Black Friday zero-downtime | ~$3M/min downtime avoided |
| **Elastic** | Found single function costing $6K/year in QA environment | Dramatic CPU reduction |

General industry: Continuous profiling typically reveals **10-40% compute cost optimization** opportunities.

### 6.8 Language-Specific Profiling

| Language | Recommended Tool | Key Notes |
|----------|-----------------|-----------|
| **Go** | Built-in `runtime/pprof` | Zero-dependency, CPU/heap/goroutine/mutex/block types |
| **Java** | async-profiler | Avoids safepoint bias problem. CPU/allocation/wall/lock profiling |
| **Python** | py-spy | Attaches to running processes without code changes |
| **Node.js** | V8 Inspector + clinic.js | `.cpuprofile` format, event loop blocking detection |
| **.NET** | dotnet-trace | EventPipe-based, cross-platform, CPU/GC/memory/contention |

---

## 7. Troubleshooting Methodologies

### 7.1 USE Method (Brendan Gregg)

For **every resource** (CPU, memory, disk, network), check:
- **U**tilization: Percentage of time the resource is busy
- **S**aturation: Queue depth or work waiting
- **E**rrors: Count of error events

**USE Method Checklist:**

| Resource | Utilization | Saturation | Errors |
|----------|-------------|------------|--------|
| **CPU** | `node_cpu_seconds_total` (idle vs total) | Load average, run queue length | Machine check exceptions |
| **Memory** | `node_memory_MemTotal - MemAvailable` | Swap usage, OOM events | ECC errors, SEGFAULT |
| **Disk I/O** | `node_disk_io_time_seconds_total` | Disk queue depth, await | Device errors in dmesg |
| **Network** | Interface throughput vs capacity | TCP retransmits, listen queue drops | CRC errors, link errors |
| **Storage capacity** | Filesystem usage % | Inode exhaustion | Filesystem read-only errors |

**Best for**: Infrastructure-level troubleshooting. Ask USE for every hardware/software resource before looking at application code.

### 7.2 RED Method (Tom Wilkie)

For **every service**, monitor:
- **R**ate: Requests per second
- **E**rrors: Failed requests per second
- **D**uration: Latency distribution (histograms, not averages)

```promql
# Rate
sum(rate(http_requests_total{service="payment"}[5m]))

# Errors (error ratio)
sum(rate(http_requests_total{service="payment",status=~"5.."}[5m]))
/ sum(rate(http_requests_total{service="payment"}[5m]))

# Duration (p99)
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="payment"}[5m])) by (le))
```

**Best for**: Application/service-level troubleshooting. Maps directly to Google's Four Golden Signals.

### 7.3 Four Golden Signals (Google SRE)

| Signal | Definition | Measurement |
|--------|------------|-------------|
| **Latency** | Time to serve a request | Histogram (p50, p95, p99). **Separate successful vs failed latency** |
| **Traffic** | Demand on the system | Requests/sec, transactions/sec, network I/O |
| **Errors** | Rate of failed requests | Explicit (5xx) + implicit (wrong content, slow responses) |
| **Saturation** | How "full" the service is | Memory usage, CPU, connection pools, queue depths |

**How they complement each other:**
- USE Method → **infrastructure** problems (is the hardware/OS the bottleneck?)
- RED Method → **service** problems (is the application behaving correctly?)
- Golden Signals → **user-impact** problems (are users affected?)

### 7.4 Exemplars: Bridging Metrics and Traces

Exemplars are **specific trace IDs attached to metric samples**, providing a direct link from an aggregated metric to a concrete request trace.

**How they work:**
1. Application instruments a histogram (e.g., request duration)
2. For interesting samples (high latency, errors), the trace_id is attached as an exemplar
3. Prometheus stores exemplars alongside metric data
4. Grafana renders exemplar dots on metric graphs
5. Clicking an exemplar opens the corresponding trace in Tempo/Jaeger

**Implementation in OTel Collector:**
```yaml
processors:
  spanmetrics:
    dimensions:
      - name: service.name
      - name: http.method
    exemplars:
      enabled: true
```

---

## 8. Cross-Signal Correlation

### 8.1 Signal Correlation Workflow

The complete investigation path across all five signals:

```
Metric alert fires (Golden Signals / RED)
    │
    ├─→ Check exemplars on the metric → Link to specific trace
    │       │
    │       └─→ Trace waterfall shows slow/failing span
    │               │
    │               ├─→ Span attributes → Filter logs for same trace_id
    │               │       │
    │               │       └─→ Logs reveal error details / stack trace
    │               │
    │               └─→ Attach profile to span → See which function is slow
    │
    └─→ Check annotations/events → Identify recent deployments/changes
```

### 8.2 Correlation Keys

| Key | Purpose |
|-----|---------|
| **trace_id** | Links metrics → traces → logs → profiles |
| **span_id** | Links specific span to logs and profiles within that operation |
| **service.name** | Groups all signals for a specific service |
| **Resource attributes** | Shared context (k8s.pod.name, cloud.region, deployment.environment) across all signals |
| **Exemplars** | Attaches specific trace_ids to metric samples |

### 8.3 Practical Investigation: "I See a Latency Spike"

**Step 1: Confirm with metrics (< 2 min)**
```promql
# Check p99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

# Check error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
/ sum(rate(http_requests_total[5m])) by (service)
```

**Step 2: Find a specific trace (< 3 min)**
- Click exemplar on the latency graph
- Or search traces: `service.name="payment" AND duration>2s AND status=ERROR`

**Step 3: Analyze the trace (< 5 min)**
- Identify the slow span in the waterfall
- Check span attributes (db.statement, http.url, rpc.method)
- Note the trace_id and span_id

**Step 4: Correlate with logs (< 3 min)**
```logql
{service="payment"} | json | trace_id="abc123def456"
```

**Step 5: Check profiles (< 5 min)**
- Open Pyroscope/profiler for the service during the time window
- Compare flame graph with baseline from before the spike
- Identify new/wider function calls

**Step 6: Check events (< 2 min)**
- Look at Grafana annotations for recent deployments
- Check change intelligence for correlated config changes

**Total time**: ~15-20 minutes for systematic root cause identification.

### 8.4 Tools That Excel at Cross-Signal Correlation

| Tool | Strength |
|------|----------|
| **Grafana (Explore)** | Best open-source cross-signal navigation. Click from metrics → traces → logs → profiles via links and exemplars |
| **Datadog** | Tight integration across all products. Code Hotspots link traces to profiles inline |
| **Honeycomb** | BubbleUp automatically identifies differentiating attributes in anomalous groups |
| **Dynatrace** | Davis AI provides causal correlation across full topology |
| **ServiceNow (Lightstep)** | Strong trace-to-metric correlation, Change Intelligence |

---

## 9. Common Troubleshooting Scenarios

### 9.1 Latency Spike Investigation

**Symptoms**: p99 latency doubles or triples, user complaints, SLO burn rate accelerating

**Investigation:**
1. **Scope**: Which services? Which endpoints? Which regions?
2. **Check RED**: Is traffic (rate) also spiking? → Could be load-related
3. **Check dependencies**: Use trace waterfall to identify slow downstream service
4. **Check infrastructure (USE)**: CPU saturation? Memory pressure? Network retransmits?
5. **Check database**: Slow queries? Connection pool exhaustion? Lock contention?
6. **Check recent changes**: Any deployments in the last hour?

**Common root causes**: Database query regression (missing index), downstream service degradation, GC pressure, connection pool exhaustion, DNS resolution delays, bad deployment.

### 9.2 Memory Leak Detection

**Symptoms**: Gradual memory growth over hours/days, periodic OOMKills, increasing GC frequency

**Investigation:**
1. Graph `container_memory_working_set_bytes` over 24-48 hours -- is it monotonically increasing?
2. Capture heap profile: compare allocations at T=0 vs T+6h
3. Look for objects that are being allocated but never freed
4. Check for growing caches, event listeners not removed, connection objects not closed

**Resolution**: Fix the leak in code. As a temporary measure, implement periodic restarts with PodDisruptionBudget to maintain availability.

**Predictive alert:**
```promql
predict_linear(container_memory_working_set_bytes[6h], 4*3600)
  > container_spec_memory_limit_bytes
```

### 9.3 CPU Saturation Diagnosis

**Symptoms**: Request latency increases linearly with load, CPU throttling in cgroups, load average >> CPU count

**Investigation:**
1. Check `node_cpu_seconds_total` -- which CPU mode? (user, system, iowait, steal)
2. If **user** high: application code consuming CPU → use CPU profiler (flame graph)
3. If **iowait** high: disk I/O bottleneck → check disk saturation
4. If **system** high: kernel overhead (syscalls, context switches) → check network or filesystem
5. If **steal** high: noisy neighbor on shared hardware → resize or migrate

**Resolution**: CPU profiling to identify hot functions, optimize algorithms, add caching, scale horizontally.

### 9.4 Cascading Failure Analysis

**Symptoms**: Multiple services failing simultaneously, circuit breakers tripping, error rates climbing across the board

**Investigation:**
1. Identify the **first** service that started failing (timeline analysis)
2. Map service dependencies to understand propagation path
3. Check if a shared dependency (database, message queue, DNS, auth service) is the root cause
4. Look for retry storms amplifying the failure

**Resolution**: Implement circuit breakers, retry budgets with exponential backoff + jitter, bulkhead isolation (separate thread pools per dependency), load shedding for critical paths.

### 9.5 Database Connection Pool Exhaustion

**Symptoms**: `Cannot get a connection, pool error`, response times spike from ms to seconds, threads in WAITING state

**Investigation:**
1. Confirm pool exhaustion: active connections = max pool size, wait queue growing
2. Check for slow queries holding connections
3. Check for connection leaks (missing `close()` calls)
4. Check if pool size is appropriate for traffic level

**Key metrics to instrument (HikariCP example):**
```yaml
hikaricp_connections_active
hikaricp_connections_idle
hikaricp_connections_pending
hikaricp_connections_timeout_total
hikaricp_connections_usage_seconds
hikaricp_connections_max
```

### 9.6 Network Partition / DNS Resolution Failures

**Symptoms**: Intermittent connection failures, `SERVFAIL`/`NXDOMAIN` DNS errors, `connection refused`/`timeout`

**Investigation:**
1. Verify DNS: `kubectl exec dnsutils -- nslookup <service>.<namespace>.svc.cluster.local`
2. Check CoreDNS health: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
3. Check NetworkPolicies blocking UDP port 53
4. Check for `ndots:5` causing excessive DNS queries for external domains
5. Check conntrack table exhaustion (`nf_conntrack_max`)
6. Check CNI plugin health

**Common fixes**: Scale CoreDNS, fix `ndots` (add FQDN dots or set `ndots:2`), increase conntrack table, deploy NodeLocal DNSCache.

### 9.7 OOM Kills and Container Restarts

**Symptoms**: `OOMKilled` in pod status, Exit Code 137, restart count incrementing

**Investigation:**
1. Confirm: `kubectl describe pod <name> | grep -A 10 "Last State"`
2. Determine if container-level (exceeded limit) or node-level (kernel OOM killer)
3. Graph memory over time: sudden spike vs gradual growth
4. Check memory requests vs limits alignment
5. Capture heap profile before next OOM

**Resolution**: Set limits to 1.5-2x expected working set. For JVM: set `-Xmx` to ~75% of container limit. Always set `memory_limiter` as first processor in OTel Collector pipelines. Use VPA for right-sizing.

---

## 10. AI-Assisted Troubleshooting

### 10.1 Vendor AI Features

| Vendor | Product | Capabilities |
|--------|---------|-------------|
| **Datadog** | Watchdog + Bits AI | Unsupervised anomaly detection, AI SRE agent for on-call triage, Dev Agent for code fixes, natural language querying. 60% pager volume reduction. |
| **Grafana** | Sift + Assistant | Auto-investigation of alerts (checks related signals, deployments, anomalies). Context-aware AI co-pilot for PromQL/LogQL. |
| **Dynatrace** | Davis AI (Causal + CoPilot) | Deterministic causal traversal via Smartscape topology. Groups hundreds of alerts into single problems. 56% faster MTTR. |
| **Splunk** | ITSI | Adaptive thresholds, anomaly detection, 60% less downtime, 95% less alert noise, 30-min advance predictions. |
| **New Relic** | AI Observability | Natural language NRQL querying, automated RCA suggestions, 2x correlation rate for AI-enabled accounts. |

### 10.2 Causal AI vs Correlation-Based

| Aspect | Correlation-Based | Causal AI |
|--------|-------------------|-----------|
| Mechanism | "X and Y happen together" | "X caused Y because of dependency chain" |
| False positives | High | Low |
| Explainability | Low | High (shows causal chain) |
| Novel failures | Poor (not in training data) | Good (topology traversal works) |
| Requirements | Sufficient historical data | Accurate topology/dependency map |
| Examples | Most ML AIOps | Dynatrace Davis, Causely |

### 10.3 LLM-Based Troubleshooting (Current State)

- **Natural language querying**: "What caused the latency spike at 2pm?" → translated to PromQL/LogQL
- **Automated RCA**: LLM agents query Prometheus, OpenSearch, Tempo → prioritized root causes
- **Runbook generation**: LLMs generate draft runbooks from alert + historical data
- **Code-level diagnosis**: Fine-tuned LLMs analyze stack traces + code repos

**Benchmark reality check**: OpenRCA benchmark (ICLR 2025) -- best model (Claude 3.5) solved only **11.34%** of 335 real failures. LLM-based RCA is promising but far from standalone production-ready.

### 10.4 Limitations and Risks

1. **Hallucination risk**: Plausible but incorrect root cause explanations without human verification
2. **Data quality dependency**: Incomplete instrumentation → wrong conclusions
3. **Novelty blindness**: ML models fail on never-seen failure modes
4. **Alert fatigue vs trust**: Too many false positives → operators stop trusting AI
5. **Architectural lock-in**: Davis AI's strength requires Dynatrace's proprietary data model
6. **Automation risk**: Auto-remediation masking root causes (restarting pods during memory leak)
7. **Cost**: Enterprise AI features often require most expensive tier
8. **Privacy**: Telemetry data sent to cloud LLMs may contain PII or internal architecture details

---

## 11. Building Effective Runbooks

### 11.1 Recommended Structure

Based on the existing OllyStack runbook pattern (Symptoms → Diagnosis → Resolution → Prevention):

```
# Runbook: [Descriptive Title]

## Symptoms
- Observable indicator 1 (alert name, metric condition, log pattern)
- Observable indicator 2
- Related Kubernetes events or error messages

## Severity Assessment
- P1 (customer-impacting): [criteria]
- P2 (degraded but functional): [criteria]
- P3 (potential issue, not yet impacting): [criteria]

## Diagnosis

### Step 1: Quick triage (< 2 minutes)
[Fastest checks to narrow down the category]

### Step 2: Identify specific cause (< 10 minutes)
[Targeted queries and commands]

### Step 3: Confirm root cause (< 15 minutes)
[Validation steps]

## Resolution

### Option A: [Most common fix]
### Option B: [Second most common fix]
### Emergency: [Break-glass procedure]

## Verification
- How to confirm the fix
- What metrics/alerts should normalize
- Expected recovery time

## Prevention
- Config changes to prevent recurrence
- Monitoring improvements
- Architectural changes for long-term fix

## Escalation
- When to escalate and to whom
- What information to include
```

### 11.2 Decision Trees

Enable rapid triage without deep domain knowledge:

```
Alert: High Memory Usage on Collector
                │
                ▼
        Is the collector OOMKilled?
        ┌──yes──┤──no──┐
        │               │
        ▼               ▼
  Is it recurring?    Is memory_limiter
  (>3 in 1 hour)     dropping data?
  ┌─yes─┤─no─┐    ┌─yes─┤──no──┐
  │           │    │             │
  ▼           ▼    ▼             ▼
Likely       Single Go to      Monitor
memory       spike  Queue      and investigate
leak         check  Section    gradually
```

### 11.3 Automation Levels (Gradual Spectrum)

| Level | Name | Description | Value |
|-------|------|-------------|-------|
| 0 | Pure Documentation | Markdown runbook, manual steps | Consistent procedure, knowledge transfer |
| 1 | Do-Nothing Script | Prints instructions, waits for confirmation | Lowers activation energy for automation |
| 2 | Semi-Automated (Diagnostic) | Runs diagnostic commands, human decides | Faster triage, consistent data collection |
| 3 | Semi-Automated (Remediation) | Proposes action, asks for approval | Safe automation with human oversight |
| 4 | Fully Automated | Alert triggers automation directly | Fastest MTTR, 24/7, eliminates toil |

Inspired by Dan Slimmon's "Do-Nothing Scripting" -- start at Level 0/1 and progressively automate individual steps.

### 11.4 Runbook-as-Code

**Braintree Runbook (Ruby DSL):**
```ruby
Runbook.book "Restart Collector" do
  section "Pre-checks" do
    step "Verify no active incidents" do
      ask "Are there any active P1/P2 incidents?", into: :active_incidents
    end
    step "Check current health" do
      command "kubectl get pods -l app=otel-collector"
      confirm "Does the output look healthy?"
    end
  end
  section "Restart" do
    step "Rolling restart" do
      command "kubectl rollout restart deployment/otel-collector"
    end
  end
end
```

**Terraform-based (Shoreline pattern):**
```hcl
module "pod_restart_monitoring" {
  source              = "terraform-shoreline-modules/kubernetes-pod-restarting/shoreline"
  restart_threshold   = 3
  time_window         = "1h"
  remediation_action  = "kubectl delete pod ${pod_name}"
}
```

### 11.5 Auto-Attaching Runbooks to Alerts

```yaml
# Prometheus/Alertmanager
groups:
  - name: collector-alerts
    rules:
      - alert: CollectorHighMemory
        expr: otelcol_process_memory_rss > 0.85 * otelcol_process_memory_limit
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Collector {{ $labels.pod }} memory at {{ $value | humanize }}"
          runbook_url: "https://wiki.example.com/runbooks/collector-high-memory"
          dashboard_url: "https://grafana.example.com/d/collector-health"
```

### 11.6 Runbook Automation Tools

| Tool | Type | Key Feature |
|------|------|-------------|
| **Rundeck / PagerDuty Runbook Automation** | Commercial / OSS | Self-service operations, job scheduling, PagerDuty integration |
| **Shoreline.io** | Commercial | Fleet-wide operations, 120+ pre-built runbooks, DaemonSet agents |
| **Grafana OnCall** | OSS / Cloud | Alert routing, escalation chains, template-based notifications |
| **Robusta.dev** | OSS / Commercial | K8s-native, enriches alerts with diagnostics before reaching on-call |
| **StackStorm** | OSS | Event-driven automation with rules (trigger → action) |

---

## Summary: Organizational Maturity Model

| Level | Description | Capabilities |
|-------|-------------|-------------|
| **1** | Reactive | Golden signals monitored, manual investigation, documented runbooks |
| **2** | Proactive | Cross-signal correlation configured (exemplars, trace-to-logs), semi-automated runbooks |
| **3** | AI-Assisted | Anomaly detection, natural language querying, automated diagnostic runbooks |
| **4** | Intelligent | Causal AI for root cause, fully automated remediation with human oversight, runbook-as-code |
| **5** | Autonomous | AI detects, diagnoses, remediates, and learns. Humans handle only novel situations |

**Most organizations in 2025 are between Level 1 and Level 2, with aspirations toward Level 3.**

---

## Key References

- [DORA 2024 State of DevOps Report](https://dora.dev/research/2024/dora-report/)
- [Google SRE Book: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Google SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [Brendan Gregg: USE Method](https://www.brendangregg.com/usemethod.html)
- [Brendan Gregg: Flame Graphs](https://www.brendangregg.com/flamegraphs.html)
- [Brendan Gregg: Off-CPU Analysis](https://www.brendangregg.com/offcpuanalysis.html)
- [OpenTelemetry Profiling Signal](https://opentelemetry.io/blog/2024/profiling/)
- [OpenTelemetry Events Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/events/)
- [Grafana Pyroscope Documentation](https://grafana.com/docs/pyroscope/latest/)
- [Datadog: How We Saved $17.5M](https://www.datadoghq.com/blog/how-datadog-saved-17-million-dollars/)
- [PagerDuty Pricing](https://www.pagerduty.com/pricing/incident-management/)
- [Rootly Pricing](https://rootly.com/pricing)
- [incident.io Blog](https://incident.io/blog/)
- [Dan Slimmon: Do-Nothing Scripting](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/)
- [BigPanda AIOps](https://www.bigpanda.io/our-product/event-correlation/)
- [Dynatrace Davis AI](https://www.dynatrace.com/platform/artificial-intelligence/)
