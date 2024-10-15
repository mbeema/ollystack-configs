# SLO, SLI, and SLA: A Comprehensive Guide

> Enterprise observability consulting reference for understanding, implementing, and operationalizing Service Level Indicators, Objectives, and Agreements.

---

## Table of Contents

1. [The SLI → SLO → SLA Hierarchy](#1-the-sli--slo--sla-hierarchy)
2. [SLI (Service Level Indicators) Deep Dive](#2-sli-service-level-indicators-deep-dive)
3. [SLO (Service Level Objectives) Deep Dive](#3-slo-service-level-objectives-deep-dive)
4. [Error Budgets and Burn Rates](#4-error-budgets-and-burn-rates)
5. [Multi-Window Multi-Burn-Rate Alerting](#5-multi-window-multi-burn-rate-alerting)
6. [SLA (Service Level Agreements) Deep Dive](#6-sla-service-level-agreements-deep-dive)
7. [Cloud Provider SLA Reference](#7-cloud-provider-sla-reference)
8. [Composite SLA Math](#8-composite-sla-math)
9. [OpenTelemetry and SLI Measurement](#9-opentelemetry-and-sli-measurement)
10. [SLO Tooling Comparison](#10-slo-tooling-comparison)
11. [SLO Culture and Organization](#11-slo-culture-and-organization)
12. [Real-World SLO Examples by Service Type](#12-real-world-slo-examples-by-service-type)
13. [SLOs for Different Architectures](#13-slos-for-different-architectures)
14. [Error Budget Policy Template](#14-error-budget-policy-template)
15. [Common Mistakes and Anti-Patterns](#15-common-mistakes-and-anti-patterns)

---

## 1. The SLI → SLO → SLA Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Happiness                           │
│                             ↑                                   │
│                         measured by                              │
│                             │                                   │
│              ┌──────────────┴──────────────┐                    │
│              │     SLI (Indicator)          │                    │
│              │  good events / total events  │                    │
│              └──────────────┬──────────────┘                    │
│                             │                                   │
│                      target applied                             │
│                             │                                   │
│              ┌──────────────┴──────────────┐                    │
│              │     SLO (Objective)          │                    │
│              │  SLI >= 99.9% over 30 days  │                    │
│              │  → error budget = 0.1%      │                    │
│              └──────────────┬──────────────┘                    │
│                             │                                   │
│                 contractual commitment                           │
│                             │                                   │
│              ┌──────────────┴──────────────┐                    │
│              │     SLA (Agreement)          │                    │
│              │  SLO + consequences          │                    │
│              │  (credits, penalties, legal) │                    │
│              └─────────────────────────────┘                    │
│                                                                 │
│  Actual perf (99.97%) > SLO (99.95%) > SLA (99.9%)            │
│  ← engineering margin →  ← business margin →                   │
└─────────────────────────────────────────────────────────────────┘
```

| Concept | Definition | Audience | Consequence of Miss |
|---------|-----------|----------|-------------------|
| **SLI** | A quantitative measure of service quality | Engineering | None (it's a measurement) |
| **SLO** | A target value for an SLI over a time window | Engineering + Product | Error budget policy (feature freeze, reliability sprint) |
| **SLA** | An SLO with contractual/legal consequences | Customers + Legal | Financial penalties, service credits, termination rights |

**Key formula:**
```
SLA target < SLO target < actual performance
```

Example: If your service runs at 99.97% availability:
- SLO: 99.95% (internal target, gives engineering a small margin)
- SLA: 99.9% (external commitment, gives the business a larger margin above the SLO)

---

## 2. SLI (Service Level Indicators) Deep Dive

### Definition

A Service Level Indicator is a carefully defined quantitative measure of some aspect of the level of service that is provided:

```
SLI = (good events / total events) × 100%
```

SLIs provide an objective, measurable proxy for user experience. They answer: **"Is the service behaving well from the user's perspective?"**

### Types of SLIs

| SLI Type | Formula | Applies To | Example |
|----------|---------|-----------|---------|
| **Availability** | successful requests / total requests | All services | 99.95% of HTTP requests return non-5xx |
| **Latency** | requests faster than threshold / total requests | Request-driven services | 95% of API calls < 200ms |
| **Throughput** | minutes above min rate / total minutes | Pipelines, streaming | 99% of windows >= 10K events/sec |
| **Error Rate** | error requests / total requests | All services | < 0.1% of requests return 5xx |
| **Correctness** | correct responses / total responses | Calculations, search | 99.99% match reference oracle |
| **Freshness** | records updated within threshold / total | Caches, replicas, warehouses | 99% of data < 5 min old |
| **Durability** | objects successfully read / objects expected | Storage, backups | 99.999999999% retrievable |

### Choosing SLIs by Service Type

| Service Type | Primary SLIs | Secondary SLIs |
|-------------|-------------|----------------|
| **User-facing APIs** | Availability, Latency | Error rate, Throughput |
| **Storage systems** | Availability, Latency, Durability | Throughput, Correctness |
| **Data pipelines** | Freshness, Correctness, Throughput | Availability |
| **Batch/scheduled jobs** | Freshness (on-time completion), Correctness | Throughput |
| **Message queues** | Delivery success rate, End-to-end latency | Consumer lag, Ordering |
| **CDN/static content** | Availability, TTFB latency | Cache hit ratio |

### SLI Specification vs. Implementation (Google SRE)

| Concept | Description | Example |
|---------|------------|---------|
| **SLI Specification** | High-level description of what to measure | "Proportion of home page requests that load in under 1 second as experienced by the user" |
| **SLI Implementation** | Concrete technical measurement mechanism | "Proportion of requests where server-side latency (from LB access logs) is < 800ms" |

The distinction matters because you can have multiple implementations for the same specification, each with different accuracy/coverage/cost trade-offs.

### Good SLI Properties

1. **Measurable** — Can be computed from actual system data
2. **Meaningful to users** — Correlates with user happiness (not CPU usage or queue depth)
3. **Controllable** — The team can influence it through engineering effort
4. **Ratio-based** — Expressed as good events / total events (0%–100%)
5. **Aggregatable** — Can be computed over any time window

### SLI Measurement Methods

| Method | Pros | Cons |
|--------|------|------|
| **Server-side request logs** | Complete coverage, rich detail, reprocessable | Higher latency, storage cost, misses client issues |
| **Application metrics (Prometheus, OTel)** | Real-time, low overhead, easy alerting | Can miss edge cases, pre-aggregated |
| **Load balancer / proxy metrics** | Captures all traffic including app failures | Less application-level detail |
| **Synthetic probes** | Measures real user path, catches infra issues | Low volume, only tests known paths |
| **Client-side instrumentation (RUM)** | Truest user experience measure | Noisy, sampling needed, privacy concerns |

### SLI Examples with PromQL

#### HTTP Services — Availability

```promql
# Proportion of successful HTTP requests (non-5xx)
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

#### HTTP Services — Latency

```promql
# Proportion of requests faster than 250ms (using histogram buckets)
sum(rate(http_request_duration_seconds_bucket{le="0.25"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

#### gRPC Services — Availability

```promql
# Proportion of gRPC calls with non-error codes
# (NotFound is not an error for lookup services)
sum(rate(grpc_server_handled_total{grpc_code!~"Internal|Unavailable|DataLoss|DeadlineExceeded"}[5m]))
/
sum(rate(grpc_server_handled_total[5m]))
```

#### gRPC Services — Latency

```promql
# Proportion of gRPC calls completing within 100ms
sum(rate(grpc_server_handling_seconds_bucket{le="0.1"}[5m]))
/
sum(rate(grpc_server_handling_seconds_count[5m]))
```

#### Database — Availability + Latency

```promql
# Availability: proportion of successful queries
sum(rate(db_query_total{status="success"}[5m]))
/
sum(rate(db_query_total[5m]))

# Latency: proportion of queries faster than 50ms
sum(rate(db_query_duration_seconds_bucket{le="0.05"}[5m]))
/
sum(rate(db_query_duration_seconds_count[5m]))
```

#### Message Queues — Freshness

```promql
# Proportion of messages consumed within 30 seconds
sum(rate(message_consume_lag_seconds_bucket{le="30"}[5m]))
/
sum(rate(message_consume_lag_seconds_count[5m]))
```

#### Batch Jobs — Freshness

```promql
# Did the job complete within its SLA window?
(time() - batch_job_last_success_timestamp_seconds) < 86400
```

---

## 3. SLO (Service Level Objectives) Deep Dive

### Definition

An SLO is a target value or range for a service level measured by an SLI, applied over a time window:

```
SLO = SLI >= target over time_window
```

Example: *"99.9% of HTTP requests will return successfully over a rolling 30-day window."*

Components:
- **SLI**: The metric (e.g., availability ratio)
- **Target**: The threshold (e.g., 99.9%)
- **Time window**: The measurement period (e.g., 30 days rolling)

### The Nines Table

| Target | Name | Allowed Downtime (30 days) | Allowed Downtime (365 days) | Budget per 1M Requests |
|--------|------|---------------------------|----------------------------|----------------------|
| 99% | Two 9s | 7.2 hours | 3.65 days | 10,000 |
| 99.5% | Two and a half 9s | 3.6 hours | 1.83 days | 5,000 |
| 99.9% | Three 9s | 43.2 minutes | 8.77 hours | 1,000 |
| 99.95% | Three and a half 9s | 21.6 minutes | 4.38 hours | 500 |
| 99.99% | Four 9s | 4.32 minutes | 52.6 minutes | 100 |
| 99.999% | Five 9s | 25.9 seconds | 5.26 minutes | 10 |

### Setting Appropriate SLO Targets

**The cardinal rule: Never set an SLO of 100%.** This is because:
1. It is unachievable for any distributed system
2. It leaves zero room for deployments, maintenance, or experimentation
3. It implies infinite investment in reliability

**Practical guidance:**

1. **Start with user expectations**, not technical capability — "At what point do users notice or complain?"
2. **Examine historical performance** — If running at 99.95% for 6 months without complaints, 99.9% is reasonable
3. **Consider dependencies** — Your SLO cannot exceed your weakest critical dependency
4. **Leave a margin** — If SLA is 99.9%, internal SLO should be 99.95%
5. **Start loose, tighten over time** — It is much easier to tighten an SLO than loosen one

**Google's Recommended Targets by Service Tier:**

| Tier | Description | Typical Availability SLO | Error Budget (30 days) |
|------|-----------|------------------------|----------------------|
| Tier 1 (Critical) | Revenue-generating, user-facing | 99.99% | 4.32 minutes |
| Tier 2 (High) | Important but not revenue-critical | 99.9% | 43.2 minutes |
| Tier 3 (Medium) | Internal tools, non-critical | 99.5% | 3.6 hours |
| Tier 4 (Low) | Development, experimental | 99% | 7.2 hours |

### Rolling Windows vs. Calendar Windows

| Aspect | Rolling Window | Calendar Window |
|--------|---------------|----------------|
| **Definition** | "The last 30 days from now" | "January 1 – January 31" |
| **User alignment** | Better (users don't reset expectations monthly) | Worse |
| **Budget smoothing** | Smoother consumption | Perverse incentives at boundaries |
| **Business reporting** | Harder to align | Natural alignment with quarters |
| **Incident recovery** | Bad incident haunts for exactly N days | Reset allows fresh start |
| **Google's recommendation** | Use for operational alerting | Use for business reporting |

**Best practice:** Use rolling windows for burn-rate alerting (operational), calendar windows for error budget policies (business decision-making).

### Iterating on SLOs (4-Phase Approach)

| Phase | Timeline | Activities |
|-------|---------|-----------|
| **Phase 1: Measure** | Weeks 1–4 | Instrument SLIs. No targets yet. Observe natural reliability. Refine noisy metrics. |
| **Phase 2: Propose** | Weeks 5–8 | Set targets slightly below observed performance. Document SLOs. Track error budget without enforcement. |
| **Phase 3: Alert** | Weeks 9–12 | Implement multi-burn-rate alerts. Run in shadow mode (no paging). Tune thresholds. |
| **Phase 4: Enforce** | Month 4+ | Activate paging. Enforce error budget policies. Quarterly SLO review. |

### SLO-Based Alerting vs. Threshold-Based Alerting

| Aspect | Threshold-Based | SLO-Based |
|--------|----------------|-----------|
| **Rule** | "Alert if error rate > 1% for 5min" | "Alert if error budget burn rate threatens exhaustion" |
| **Context** | None (1% for 5min ≠ 1% for 5hours) | Full (burn rate quantifies impact) |
| **Tuning** | Constant manual tuning | Self-adjusting to service importance |
| **Alert fatigue** | High (transient spikes page) | Low (brief spikes ignored if budget healthy) |
| **User impact** | No connection | Directly tied |
| **Escalation** | Manual severity assignment | Burn rate determines severity |

### SLO Documentation Template

```
Service: [service name]
Owner: [team name]
Last reviewed: [date]
Next review: [date, typically quarterly]

SLI Specification:
  [Human-readable description of what is being measured]

SLI Implementation:
  [Technical description: data source, metric names, filters]

SLO Target: [percentage] over [time window]
  Window type: [rolling / calendar]

Error Budget: [calculated amount in time and/or requests]

Error Budget Policy:
  >50% remaining: [action]
  25-50% remaining: [action]
  <25% remaining: [action]
  Exhausted: [action]

Alerting:
  Page: [burn rate and windows]
  Ticket: [burn rate and windows]

Rationale:
  [Why this target was chosen, what user research or historical data supports it]

Dependencies:
  [Upstream services whose reliability affects this SLO]

Exclusions:
  [What is NOT covered: planned maintenance, specific error codes, etc.]
```

---

## 4. Error Budgets and Burn Rates

### Error Budget Calculation

```
Error Budget = 1 - SLO target
Error Budget (time) = SLO Period × (1 - SLO)
Error Budget (requests) = Total Requests × (1 - SLO)
```

| SLO | Error Budget (%) | Budget per 30 Days (minutes) | Budget per 1M Requests |
|-----|-----------------|------------------------------|----------------------|
| 99% | 1.0% | 432 min (7.2 hours) | 10,000 |
| 99.5% | 0.5% | 216 min (3.6 hours) | 5,000 |
| 99.9% | 0.1% | 43.2 min | 1,000 |
| 99.95% | 0.05% | 21.6 min | 500 |
| 99.99% | 0.01% | 4.32 min | 100 |
| 99.999% | 0.001% | 0.432 min (26 sec) | 10 |

**PromQL — Error budget remaining:**

```promql
# Error budget remaining (as fraction of total budget)
1 - (
  sum(increase(http_requests_total{status=~"5.."}[30d]))
  /
  (sum(increase(http_requests_total[30d])) * (1 - 0.999))
)
```

### Error Budget Policies

| Budget Remaining | Status | Actions |
|-----------------|--------|---------|
| **>50%** | Green / Normal | Ship features at normal velocity. Error budget available for experiments. |
| **25–50%** | Yellow / Cautious | Increased monitoring. Mandatory canary + staged rollouts for all changes. |
| **10–25%** | Orange / Reliability Focus | Feature freeze except critical business needs. 50% engineering time on reliability. |
| **<10%** | Red / Critical | Full feature freeze. Only P0 bugs and security fixes. Executive notification. |
| **Exhausted (≤0%)** | Exhausted | Complete freeze. Rollback recent changes. Formal postmortem required. Service may be "handed back" to development. |

### Burn Rate Math

**Definition:** Burn rate = rate of error budget consumption relative to ideal rate.

```
Burn Rate = Observed Error Rate / Allowed Error Rate
Burn Rate = (1 - Observed Availability) / (1 - SLO)
```

**For 99.9% SLO (allowed error rate = 0.1%):**

| Observed Error Rate | Burn Rate | Budget Exhaustion Time |
|--------------------|-----------|----------------------|
| 0.01% | 0.1x | 300 days (well within budget) |
| 0.1% | 1.0x | 30 days (exactly on target) |
| 0.2% | 2.0x | 15 days |
| 0.5% | 5.0x | 6 days |
| 1.0% | 10.0x | 3 days |
| 1.44% | 14.4x | ~50 hours |
| 5.0% | 50.0x | ~14.4 hours |
| 10.0% | 100.0x | ~7.2 hours |
| 100% (total outage) | 1000x | ~43 minutes |

**Budget consumption formula:**
```
% Budget Consumed = Burn Rate × (Alert Window / SLO Period) × 100

Example: 14.4x burn rate over 1h with 30-day SLO:
% Consumed = 14.4 × (60 / 43200) × 100 = 2%
```

### Error Budget Depletion Scenarios

**Scenario 1: Single Major Outage**
- SLO: 99.9%, budget = 43.2 minutes
- Day 5: 30-minute total outage → 69.4% budget consumed
- Remaining: 13.2 minutes for rest of month
- Impact: Extreme caution required for remaining 25 days

**Scenario 2: Chronic Low-Level Degradation**
- Steady 0.2% error rate (2x burn rate)
- Day 15: 1x burn rate alert fires (3-day window detects the trend)
- Day 30: 86.4% budget consumed — barely survives

**Scenario 3: Deployment-Caused Spikes**
- 4 deployments/month, each causes 5-minute spike at 50% error rate
- Per deployment: 2.5 minutes effective downtime
- Total: 10 minutes consumed = 23.1% of budget
- Healthy pattern: 25% for deployments, 75% for unexpected issues

**Scenario 4: Cascading Failure**
- Day 12: Database failover (8 min) → 18.5% consumed
- Day 12: Cache stampede post-recovery (3 min at 80% errors) → 5.6% consumed
- Day 18: Repeat (12 min) → 27.8% consumed
- Total by Day 18: 51.9% consumed — only 20.8 minutes remaining

---

## 5. Multi-Window Multi-Burn-Rate Alerting

This is the state-of-the-art SLO alerting methodology from the **Google SRE Workbook** (Chapter: "Alerting on SLOs"). The key insight: alert on the **rate** at which you're consuming error budget, not just whether you've exceeded a static threshold.

### The 4 Recommended Alert Conditions

For a 99.9% SLO, 30-day window:

| Severity | Burn Rate | Long Window | Short Window | Budget Consumed at Alert | Action |
|----------|-----------|-------------|-------------|------------------------|--------|
| **Page (Critical)** | 14.4x | 1 hour | 5 minutes | 2% | Wake someone up |
| **Page (Critical)** | 6x | 6 hours | 30 minutes | 5% | Wake someone up |
| **Ticket (Warning)** | 3x | 1 day | 2 hours | 10% | File a ticket |
| **Ticket (Warning)** | 1x | 3 days | 6 hours | 10% | File a ticket |

### How Burn Rates Are Derived

- **14.4x**: Budget exhausted in `30/14.4 = 2.08 days`. The 1h window catches 2% consumption — fast, severe incidents
- **6x**: Budget exhausted in `30/6 = 5 days`. The 6h window catches 5% — moderate-severity incidents over hours
- **3x**: Budget exhausted in `30/3 = 10 days`. The 1d window catches slow degradations consuming 10%
- **1x**: Budget exhausted in exactly 30 days. The 3d window catches very slow, persistent issues

### Why Two Windows (Long + Short)?

The **long window** detects that a significant burn has occurred. The **short window** confirms the problem is still ongoing. Without the short window, a brief spike 55 minutes ago would still trigger a 1h alert even though the problem resolved. The short window acts as a "still happening?" check.

**Rule of thumb:** Short window = Long window / 12.

### Complete Prometheus Recording and Alerting Rules

```yaml
# =============================================================
# Recording Rules: Pre-compute error ratios at multiple windows
# =============================================================
groups:
  - name: slo-recording-rules
    rules:
      # 5-minute window (short)
      - record: slo:http_errors:ratio_rate5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))

      # 30-minute window (short)
      - record: slo:http_errors:ratio_rate30m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[30m]))
          /
          sum(rate(http_requests_total[30m]))

      # 1-hour window (long)
      - record: slo:http_errors:ratio_rate1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum(rate(http_requests_total[1h]))

      # 2-hour window (short)
      - record: slo:http_errors:ratio_rate2h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[2h]))
          /
          sum(rate(http_requests_total[2h]))

      # 6-hour window (long + short)
      - record: slo:http_errors:ratio_rate6h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[6h]))
          /
          sum(rate(http_requests_total[6h]))

      # 1-day window (long)
      - record: slo:http_errors:ratio_rate1d
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1d]))
          /
          sum(rate(http_requests_total[1d]))

      # 3-day window (long)
      - record: slo:http_errors:ratio_rate3d
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[3d]))
          /
          sum(rate(http_requests_total[3d]))

# =============================================================
# Alerting Rules: Multi-window multi-burn-rate
# For a 99.9% SLO (error budget = 0.001)
# =============================================================
  - name: slo-alerts
    rules:
      # PAGE: 14.4x burn rate — 1h/5m windows — 2% budget consumed
      - alert: SLOBurnRateCritical
        expr: |
          slo:http_errors:ratio_rate1h > (14.4 * 0.001)
          and
          slo:http_errors:ratio_rate5m > (14.4 * 0.001)
        labels:
          severity: page
        annotations:
          summary: >-
            High error burn rate: {{ $value | humanizePercentage }}
            (14.4x budget burn)
          description: >-
            Error budget will be exhausted in ~2 days at current rate.
            Immediate investigation required.

      # PAGE: 6x burn rate — 6h/30m windows — 5% budget consumed
      - alert: SLOBurnRateHigh
        expr: |
          slo:http_errors:ratio_rate6h > (6 * 0.001)
          and
          slo:http_errors:ratio_rate30m > (6 * 0.001)
        labels:
          severity: page
        annotations:
          summary: "Sustained error burn rate: 6x budget consumption"
          description: >-
            Error budget will be exhausted in ~5 days. Sustained
            elevated error rate over 6 hours.

      # TICKET: 3x burn rate — 1d/2h windows — 10% budget consumed
      - alert: SLOBurnRateWarning
        expr: |
          slo:http_errors:ratio_rate1d > (3 * 0.001)
          and
          slo:http_errors:ratio_rate2h > (3 * 0.001)
        labels:
          severity: ticket
        annotations:
          summary: "Elevated error rate: 3x budget burn over 24h"
          description: >-
            10% of error budget consumed in 24 hours. Investigate
            during business hours.

      # TICKET: 1x burn rate — 3d/6h windows — 10% budget consumed
      - alert: SLOBurnRateSlow
        expr: |
          slo:http_errors:ratio_rate3d > (1 * 0.001)
          and
          slo:http_errors:ratio_rate6h > (1 * 0.001)
        labels:
          severity: ticket
        annotations:
          summary: "Slow error budget drain: 1x burn rate over 3 days"
          description: >-
            Persistent low-level degradation detected. Error budget
            on track for exhaustion within 30 days.
```

### Latency SLO Alerting (Complementary)

```yaml
groups:
  - name: slo-latency-alerts
    rules:
      # Recording rule: proportion of fast requests (< 250ms)
      - record: slo:http_latency:good_ratio_rate1h
        expr: |
          sum(rate(http_request_duration_seconds_bucket{le="0.25"}[1h]))
          /
          sum(rate(http_request_duration_seconds_count[1h]))

      - record: slo:http_latency:good_ratio_rate5m
        expr: |
          sum(rate(http_request_duration_seconds_bucket{le="0.25"}[5m]))
          /
          sum(rate(http_request_duration_seconds_count[5m]))

      # Page: latency SLO burning at 14.4x
      # For 99% latency SLO (budget = 0.01), threshold = 1 - 14.4 * 0.01
      - alert: SLOLatencyBurnCritical
        expr: |
          slo:http_latency:good_ratio_rate1h < (1 - 14.4 * 0.01)
          and
          slo:http_latency:good_ratio_rate5m < (1 - 14.4 * 0.01)
        labels:
          severity: page
        annotations:
          summary: "Latency SLO burning budget at 14.4x rate"
```

---

## 6. SLA (Service Level Agreements) Deep Dive

### Definition and Legal/Business Context

A **Service Level Agreement** is a formal (usually contractual, often legally binding) commitment between a service provider and a customer specifying:
- What level of service the customer can expect
- How that level will be measured
- What remedies or penalties apply if the provider fails

SLAs are negotiated between sales/legal teams, part of Master Service Agreements (MSAs), subject to legal interpretation, and tied to financial consequences.

### SLO vs. SLA Comparison

| Aspect | SLO | SLA |
|--------|-----|-----|
| **Audience** | Engineering teams internally | Customers externally |
| **Consequence** | Error budget policy (freeze, sprint) | Financial penalty, credits, termination |
| **Stringency** | Stricter (internal buffer) | Looser (must be achievable) |
| **Flexibility** | Adjusted quarterly | Requires contract renegotiation |
| **Measurement** | Internal metrics | Customer-verifiable |
| **Legal force** | None (internal policy) | Contractual / legally binding |

### The SLA-SLO Gap

The gap is a deliberate safety margin:
1. **Measurement buffer** — Customers may measure differently
2. **Business protection** — SLO violation → internal remediation; SLA violation → financial loss
3. **Negotiation room** — Tighten toward (not beyond) the SLO
4. **Operational breathing room** — Fix SLO violations before they become SLA violations

**Recommended gaps:**
- SLA 99.9% → SLO 99.95% (buffer = 50% of SLA's error budget)
- SLA 99.99% → SLO 99.995%
- General rule: SLO gives ~50% of the SLA's error budget as buffer

### Common SLA Structures

**1. Uptime/Availability Guarantees** (most common)
- "The service will be available 99.9% of the time each calendar month"
- Usually excludes: scheduled maintenance, force majeure, customer-caused outages

**2. Response Time / Performance Guarantees**
- "95th percentile API response time under 500ms"
- Often qualified: "under normal load conditions" with defined ceiling

**3. Support Response Time Guarantees**

| Severity | Response Time | Availability |
|----------|-------------|-------------|
| SEV 1 (Critical) | 15 minutes | 24/7 |
| SEV 2 (High) | 1 hour | Business hours |
| SEV 3 (Medium) | 4 business hours | Business hours |
| SEV 4 (Low) | 1 business day | Business hours |

Note: SLAs guarantee *response* time, rarely *resolution* time.

**4. Data Durability Guarantees**
- "99.999999999% (11 nines) of objects will not be lost"
- Extremely high because losing customer data is catastrophic

**5. RTO/RPO Guarantees**
- "Service restored within 4 hours (RTO) with no more than 1 hour of data loss (RPO)"

### SLA Credit/Penalty Models

| Model | Description | Common In |
|-------|-----------|----------|
| **Service Credits** | Credits against future invoices (capped at 30–100% monthly fee) | Cloud providers, SaaS |
| **Financial Penalties** | Actual monetary payments | Enterprise contracts, government |
| **Termination Rights** | Customer can exit without penalty after repeated misses | Enterprise contracts |

### How to Negotiate SLAs

**Before negotiation:**
1. Calculate your cost of downtime: `hourly_revenue × hours_of_downtime = business_impact`
2. Read the standard SLA thoroughly, especially exclusions
3. Benchmark competitor offerings

**Negotiation tactics:**
1. **Push for meaningful credits** — Standard 10% is inadequate for real losses
2. **Reduce exclusions** — Narrow "scheduled maintenance" windows
3. **Negotiate measurement** — Insist on customer-verifiable metrics
4. **Add latency SLAs** — Most only cover availability
5. **Get composite SLAs** — For multi-service stacks, not just individual
6. **Include escalation procedures** — Dedicated contacts, resolution commitments
7. **Termination rights** — After 2–3 consecutive months of misses
8. **Audit rights** — Right to verify uptime calculations

**Red flags in SLA language:**
- "Commercially reasonable efforts" (not enforceable)
- Credit-only remedies with low caps
- Provider-sole-discretion measurement
- Broad force majeure clauses
- "Up to" language in performance guarantees

---

## 7. Cloud Provider SLA Reference

### AWS SLA Summary

| Service | SLA Target | Configuration Required | Credit Tiers |
|---------|-----------|----------------------|-------------|
| **EC2** | 99.99% | Multi-AZ | <99.99%→10%, <99%→30%, <95%→100% |
| **S3** | 99.9% | Standard | <99.9%→10%, <99%→25%, <95%→100% |
| **S3 Durability** | 99.999999999% | — | Design target (no credits) |
| **RDS Multi-AZ** | 99.95% | Multi-AZ | <99.95%→10%, <99%→25%, <95%→100% |
| **DynamoDB** | 99.99% | Global Tables | <99.99%→10%, <99%→25%, <95%→100% |
| **Lambda** | 99.95% | — | <99.95%→10%, <99%→25%, <95%→100% |
| **EKS** | 99.95% | Standard tier | <99.95%→10%, <99%→25%, <95%→100% |
| **CloudFront** | 99.9% | — | <99.9%→10%, <99%→25%, <95%→100% |
| **Route 53** | 100% | — | <100%→10%, <99.99%→25%, <99%→100% |

### Azure SLA Summary

| Service | SLA Target | Configuration Required | Credit Tiers |
|---------|-----------|----------------------|-------------|
| **VMs (single, Premium SSD)** | 99.9% | Premium SSD | <99.9%→10%, <99%→25%, <95%→100% |
| **VMs (Availability Set)** | 99.95% | 2+ VMs in set | Same tiers |
| **VMs (Availability Zones)** | 99.99% | Cross-zone | Same tiers |
| **SQL Database (Business Critical)** | 99.995% | Business Critical tier | <99.995%→10%, <99%→25%, <95%→100% |
| **SQL Database (General Purpose)** | 99.99% | General Purpose tier | Same tiers |
| **Cosmos DB (multi-region writes)** | 99.999% | Multi-region writes | Covers availability, throughput, consistency, latency |
| **Cosmos DB (single region)** | 99.99% | — | Same structure |
| **AKS (Standard tier)** | 99.95% | Standard tier | <99.95%→10%, <99%→25%, <95%→100% |
| **AKS (Premium tier)** | 99.99% | Premium tier + AZs | Same tiers |
| **Functions (Premium)** | 99.95% | Premium plan | Same tiers |
| **Storage (RA-GRS)** | 99.99% | RA-GRS | Same tiers |

### GCP SLA Summary

| Service | SLA Target | Configuration Required | Credit Tiers |
|---------|-----------|----------------------|-------------|
| **Compute Engine** | 99.99% | Multi-zone | <99.99%→10%, <99%→25%, <95%→50% |
| **Cloud Storage (multi-region)** | 99.95% | Multi-region | <99.95%→10%, <99%→25%, <95%→50% |
| **Cloud Storage (single region)** | 99.9% | Single region | Same tiers |
| **Cloud SQL** | 99.95% | HA configuration | <99.95%→10%, <99%→25%, <95%→50% |
| **Cloud Spanner** | 99.999% | Multi-region | <99.999%→10%, <99.99%→25%, <99.9%→50% |
| **BigQuery** | 99.99% | — | <99.99%→10%, <99%→25%, <95%→50% |
| **GKE** | 99.95% | Standard mode | <99.95%→10%, <99%→25%, <95%→50% |
| **Cloud Functions** | 99.95% | — | Same tiers |

### Observability Platform SLAs

| Platform | SLA Target | Scope | Credit Structure |
|----------|-----------|-------|-----------------|
| **Datadog** (Enterprise) | 99.9% | Data ingestion + web app | <99.9%→10%, <99%→25%, <95%→prorated |
| **Grafana Cloud** | 99.9% | Platform availability | <99.9%→10%, <99%→25%, <95%→50% |
| **PagerDuty** | 99.9% | Alerting delivery | Credits per SLA doc |
| **New Relic** | 99.9% | Data ingest + query | Standard credit tiers |

### Common Patterns Across Providers

1. All use **monthly calendar windows** (not rolling)
2. Credits are **capped** (never more than 100% of that month's spend)
3. Customer **must request credits** — they are not automatic
4. **Exclusions are extensive**: scheduled maintenance, alpha/beta features, customer misconfiguration, force majeure
5. **Measurement is provider-controlled**: the provider defines how uptime is calculated
6. **Credits, not refunds**: money off future bills, not money back
7. **Architecture requirements**: higher SLA tiers require multi-AZ, redundancy, paid tiers
8. **Claim deadlines**: 30 days (AWS, GCP) vs. 60 days (Azure) vs. 10 days (Grafana)

---

## 8. Composite SLA Math

### Serial Dependencies (ALL Must Be Up)

```
Composite SLA = SLA_A × SLA_B × SLA_C × ...
```

Example: Web app → Compute (99.99%) → Database (99.95%) → Cache (99.9%):
```
Composite = 0.9999 × 0.9995 × 0.999 = 0.9984 = 99.84%
```

Each additional serial dependency degrades the composite SLA.

### Parallel / Redundant Dependencies (ANY ONE Must Be Up)

```
Composite unavailability = (1 - SLA_A) × (1 - SLA_B)
Composite SLA = 1 - composite unavailability
```

Example: Two database replicas, each 99.9%:
```
Unavailability = 0.001 × 0.001 = 0.000001
Composite SLA = 1 - 0.000001 = 99.9999%
```

### Active-Passive Failover

```
A = A_primary + (1 - A_primary) × A_secondary × A_failover
```

Example: Two regions at 99.95%, failover mechanism at 99.9%:
```
A = 0.9995 + (0.0005 × 0.9995 × 0.999) = 0.999999 ≈ 99.9999%
```

Realistic: If failover takes 10 minutes, those count as downtime → typically ~99.99%.

### Active-Active Multi-Region

```
A = 1 - (1 - A_region1) × (1 - A_region2)
```

Example: Two regions at 99.95%:
```
A = 1 - (0.0005)² = 1 - 0.00000025 = 99.999975%
```

### Practical Example: 3-Tier AWS Web Application

```
Route 53 (100%) → CloudFront (99.9%) → ALB (99.99%)
  → EC2 Multi-AZ (99.99%) → RDS Multi-AZ (99.95%)
  → S3 (99.9%) [static assets]
  → DynamoDB (99.99%) [session store]
  → Lambda (99.95%) [background tasks]
```

**Critical path (user request):**
```
Route 53 × CloudFront × ALB × EC2 × RDS
= 1.0 × 0.999 × 0.9999 × 0.9999 × 0.9995
= 0.9983 = 99.83%
```

≈ 14.9 hours of allowed downtime per year from critical path alone.

**Key insight:** CloudFront (99.9%) and RDS (99.95%) are the weakest links. The 99.99% SLAs of EC2 and ALB are masked by weaker components. Improving availability requires focusing on lowest-SLA components first.

### Mixed Architecture Calculation

```
              [Load Balancer: 99.99%]
                     |
        [App Server Cluster: 99.95%]  ← 3 redundant instances
                     |
      ┌──────────────┼──────────────┐
[Primary DB: 99.95%]    [Cache: 99.9%]
[Replica DB: 99.95%]    (optional, degraded mode OK)
```

- App servers (3 redundant): `1 - (1-0.9995)³ ≈ 99.9999999%`
- Database (primary + replica): `1 - (1-0.9995)² = 99.999975%`
- Cache is optional → excluded from critical path
- Serial: `0.9999 × 0.999999999 × 0.99999975 ≈ 99.99%`

### Architectural Implications

1. **Minimize serial dependencies** in the critical path
2. **Add redundancy to least-reliable components first** (greatest marginal improvement)
3. **Design for graceful degradation** so non-critical failures don't cause total unavailability
4. **Consider blast radius** — does a dependency failure affect all users or a subset?
5. **Track composite SLAs explicitly** — don't assume individual SLAs are sufficient

---

## 9. OpenTelemetry and SLI Measurement

### OTel Metrics to SLI Mapping

| OTel Metric Kind | SLI Use | Example |
|-----------------|---------|---------|
| `Counter` (monotonic) | Total events, good events (ratio SLIs) | `http.server.request.count` |
| `Histogram` | Latency distribution SLIs | `http.server.request.duration` |
| `UpDownCounter` | Gauge-like SLIs (queue depth) | `messaging.consumer.lag` |
| `Gauge` | Point-in-time checks (freshness) | `data.last_updated_timestamp` |

### OTel Semantic Conventions for SLIs

| Convention | Type | SLI Use |
|-----------|------|---------|
| `http.server.request.duration` | Histogram | Server-side latency SLI |
| `http.server.active_requests` | UpDownCounter | Concurrency monitoring |
| `rpc.server.duration` | Histogram | gRPC/RPC latency SLI |
| `db.client.operation.duration` | Histogram | Database client latency SLI |
| `messaging.process.duration` | Histogram | Message processing latency SLI |

### OTel Collector's Role in SLI Pipelines

- **Filter processor**: Shape raw telemetry into SLI-ready metrics
- **Metrics transform processor**: Rename and restructure metrics for SLI computation
- **Attributes processor**: Add/remove labels for proper SLI aggregation
- **Spanmetrics connector**: Derive RED (Rate, Error, Duration) metrics from traces → directly maps to availability and latency SLIs
- **Servicegraph connector**: Compute inter-service latency SLIs

### Spanmetrics Connector Configuration

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s]
    dimensions:
      - name: http.method
      - name: http.status_code
      - name: http.route
    namespace: sli

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/traces, spanmetrics]
    metrics:
      receivers: [spanmetrics]
      processors: [batch]
      exporters: [prometheus]
```

**SLO queries from spanmetrics output:**

```promql
# Availability SLI (from traces via spanmetrics)
1 - (
  sum(rate(otel_sli_calls_total{status_code="STATUS_CODE_ERROR",service_name="checkout"}[5m]))
  /
  sum(rate(otel_sli_calls_total{service_name="checkout"}[5m]))
)

# Latency SLI (% under 300ms)
sum(rate(otel_sli_duration_milliseconds_bucket{service_name="checkout",le="300"}[5m]))
/
sum(rate(otel_sli_duration_milliseconds_count{service_name="checkout"}[5m]))
```

### Full OTel → SLO Pipeline Architecture

```
Applications (OTel SDK / auto-instrumentation)
    |
    v
OTel Collector (Gateway)
    |-- spanmetrics connector --> Prometheus (metrics)
    |-- traces pipeline -------> Tempo/Jaeger (traces)
    |-- logs pipeline ---------> Loki (logs)
    |
    v
Prometheus
    |-- Recording rules (SLI pre-computation)
    |-- Alerting rules (multi-window burn-rate)
    |
    v
Grafana
    |-- SLO dashboards (error budget, burn rate)
    |-- Exemplar links (metrics → traces)
    |-- Alert integration (PagerDuty, Slack)
```

### Exemplars: Linking SLO Violations to Traces

Exemplars attach trace references (trace_id, span_id) to specific metric data points, enabling drill-down from an SLO violation to the exact trace that caused it.

1. OTel SDK records exemplars on histogram/counter measurements with active trace context
2. Prometheus stores exemplars alongside metric samples (requires Prometheus >= 2.26)
3. Grafana shows exemplar dots on panels; clicking opens linked trace in Tempo/Jaeger

```yaml
# Grafana datasource configuration for exemplars
datasources:
  - name: Prometheus
    type: prometheus
    jsonData:
      exemplarTraceIdDestinations:
        - name: trace_id
          datasourceUid: tempo-datasource
          urlDisplayLabel: "View Trace"
```

---

## 10. SLO Tooling Comparison

### Open-Source Tools

| Feature | Sloth | Pyrra | OpenSLO |
|---------|-------|-------|---------|
| **Type** | SLO generator (CLI/controller) | SLO operator + web UI | Specification (not a tool) |
| **Output** | Prometheus recording + alert rules | PrometheusRule CRDs | YAML spec consumed by tools |
| **UI** | None (rules only) | Built-in web dashboard | N/A |
| **Kubernetes** | CRD support + controller | Native CRD operator | N/A |
| **SLO types** | Availability, latency | Ratio, latency, bool_gauge | Any (spec only) |
| **Alerting** | Generates MWMBR alerts | Generates recording rules + alerts | Defines AlertPolicy/Condition |
| **Plugin system** | SLI plugins for reusable defs | No | N/A |
| **Best for** | Teams wanting rule generation only | Full K8s-native solution with UI | Vendor-neutral SLO definitions |

### Sloth Configuration Example

```yaml
# sloth.yaml
version: "prometheus/v1"
service: "checkout-api"
labels:
  owner: "checkout-team"
slos:
  - name: "availability"
    objective: 99.9
    description: "Checkout API availability"
    sli:
      events:
        error_query: sum(rate(http_requests_total{job="checkout",code=~"5.."}[{{.window}}]))
        total_query: sum(rate(http_requests_total{job="checkout"}[{{.window}}]))
    alerting:
      name: CheckoutAvailability
      labels:
        team: checkout
      annotations:
        runbook: "https://runbooks.example.com/checkout/availability"
      page_alert:
        labels:
          severity: critical
      ticket_alert:
        labels:
          severity: warning
```

Running `sloth generate -i sloth.yaml` produces all recording rules and multi-window multi-burn-rate alert rules automatically.

### Vendor SLO Features

| Platform | SLO Types | Key Features | Pricing |
|----------|----------|-------------|---------|
| **Datadog** | Monitor-based, Metric-based | SLO widget, burn rate alerts, 15-month history, Terraform | Included with infra monitoring |
| **New Relic** | Event-based, Metric-based (NRQL) | Auto-discovery, 1/7/14/28/30d windows, NerdGraph API | Included with all plans |
| **Dynatrace** | DQL-based (any data type) | Davis AI recommendations, next-gen SLO UI (2025) | Consumption-based ($0.08/GiB-hour) |
| **Honeycomb** | Event-driven (derived columns) | Exhaustion time + budget rate alerts, trace debugging | Included with plans |
| **Nobl9** | Multi-source aggregation | Composite SLOs 2.0, 24+ data sources, OpenSLO import | Free tier / $850/mo (50 SLOs) / Enterprise |
| **Grafana Cloud** | Native SLO plugin | Error budget dashboards, burn rate alerts, IRM integration | Included with Cloud |

### When to Use Which Tool

| Scenario | Recommended Tool |
|----------|-----------------|
| Just starting with SLOs on Prometheus | **Sloth** — simplest path to correct MWMBR alerts |
| Kubernetes-native with built-in UI | **Pyrra** — CRDs + web dashboard in one package |
| Grafana Cloud users | **Grafana SLO plugin** — native integration |
| Multi-vendor environment | **Nobl9** — aggregates SLOs from 24+ sources |
| Single vendor (DD/NR/DT) | Built-in SLO features — zero extra tooling |
| Enterprise standardization | **OpenSLO** format → generate tooling-specific configs |
| Chaos + SLO validation | **Reliably** alongside another SLO tool |
| Event-driven debugging | **Honeycomb** — best trace-to-SLO connection |

---

## 11. SLO Culture and Organization

### How Tech Giants Implement SLOs

**Google:**
- Error budget policies signed by VP of Engineering and VP of SRE
- SLOs are contractual between development and SRE teams
- Error budget is the primary mechanism for balancing feature velocity and reliability
- SRE teams can "hand back" a service if SLOs are consistently violated
- Budget thresholds: >75% normal, 50–75% cautious, 25–50% reliability focus, <25% freeze, 0% only P0/security

**Netflix:**
- User-centric SLIs: "time until video starts playing" (not internal DB latency) — predicts user churn
- SLOs tied to business outcomes (conversion, retention, revenue)
- Chaos engineering (Chaos Monkey, Chaos Kong) validates SLO resilience continuously
- Regional failover SLOs measure traffic shift speed

**Uber:**
- Multi-window burn rate: 1h/6h catch fast burns, 24h/72h catch slow degradation
- 1h burn rate exceeding 14.4x pages on-call immediately
- **Result: 73% reduction in major outages year-over-year** after adoption
- SLOs eliminated subjective arguments: PMs see reliability cost, SREs prove data-backed needs

### SLO Ownership Models

**Service Owner Model (most common):**
- Team owning the service owns its SLOs
- They choose SLIs, set targets, respond to budget exhaustion
- SRE provides guidance, tooling, review

**Shared Ownership Model:**
- Product teams define *what* (user expectations)
- Engineering teams define *how* (SLI implementation)
- SRE/platform teams provide *infrastructure* (monitoring, alerting, dashboards)

**Key principle:** SLO targets must be owned by someone empowered to make tradeoffs between feature velocity and reliability (typically engineering manager or tech lead).

### SLO Review Cadences

| Cadence | Duration | Activities |
|---------|---------|-----------|
| **Weekly** (Tactical) | 15 min | SLO pulse check, current burn rate, active alerts, SLO-impacting incidents |
| **Monthly** (Operational) | 30–60 min | SLI trends, budget consumption patterns, target appropriateness, plan reliability work |
| **Quarterly** (Strategic) | 1–2 hours | SLOs reflect user experience? Adjust targets. Review error budget policy. Set reliability OKRs. Cross-team alignment. |

### SLOs and Incident Management

| Phase | SLO Role |
|-------|---------|
| **Detection** | Multi-window burn-rate alerts trigger incident creation (PagerDuty, OpsGenie) |
| **Severity mapping** | 14.4x burn = SEV1, 6x burn = SEV2, 3x burn = SEV3 |
| **During incident** | Error budget consumption rate provides objective impact measure |
| **Postmortem** | Every incident consuming >X% budget requires formal postmortem |
| **Prevention** | Action items prioritized by projected error budget impact |
| **Automation** | Systems trigger automated rollbacks when burn rate exceeds thresholds |

### SLOs Drive Prioritization

Error budgets transform subjective reliability debates into data-driven decisions:

| Budget Status | Engineering Focus |
|--------------|------------------|
| Budget available | Ship features, run experiments, take calculated risks |
| Budget declining | Prioritize technical debt, improve test coverage |
| Budget exhausted | Full reliability focus until budget recovers |

Teams with surplus budget can experiment with riskier features; teams with exhausted budget shift to stability work.

---

## 12. Real-World SLO Examples by Service Type

### E-Commerce Checkout Flow

**SLIs:**
- Availability: % checkout attempts completing successfully
- Latency: End-to-end "Place Order" to confirmation
- Correctness: % orders with correct pricing, tax, inventory

**SLO Targets:**
- Availability: 99.95% (21.6 min/month budget)
- Latency: 95% within 2s, 99% within 5s
- Correctness: 99.99%

**Composite SLO (weighted):**

| Service | SLO | Weight |
|---------|-----|--------|
| Product catalog | 99.9% | 0.15 |
| Cart service | 99.9% | 0.20 |
| Payment gateway | 99.95% | 0.35 |
| Order service | 99.9% | 0.20 |
| Notification | 99.0% | 0.10 |

**Error Budget:** 10M checkout attempts/month × 0.0005 = **5,000 failed checkouts/month** (~167/day)

```yaml
- alert: CheckoutSLOFastBurn
  expr: |
    checkout:error_ratio:rate1h > (14.4 * 0.0005)
    and
    checkout:error_ratio:rate5m > (14.4 * 0.0005)
  labels:
    severity: page
    team: checkout
```

### API Gateway / Load Balancer

| SLI | Target | Notes |
|-----|--------|-------|
| Availability | 99.99% (4.3 min/month) | Non-5xx responses |
| Latency | P99 proxy overhead < 5ms | Excludes backend latency |
| Throughput | No shedding below 50K RPS | — |

**Key:** Distinguish gateway errors (502/503/504) from backend pass-through errors (500). Only count errors the gateway introduces.

### Database Service

| SLI | Target | Notes |
|-----|--------|-------|
| Availability (reads) | 99.99% | Non-timeout, non-refused |
| Availability (writes) | 99.95% | — |
| Latency (reads) | P99 < 10ms | OLTP workloads |
| Latency (writes) | P99 < 50ms | — |
| Durability/RPO | < 1 second | Synchronous replication |
| Replication lag | < 100ms at P99.9 | — |

```yaml
- alert: DatabaseSLOLatencyBurn
  expr: |
    histogram_quantile(0.99, sum(rate(db_query_duration_seconds_bucket{type="read"}[1h])) by (le)) > 0.010
    and
    histogram_quantile(0.99, sum(rate(db_query_duration_seconds_bucket{type="read"}[5m])) by (le)) > 0.010
  labels:
    severity: page
```

### Message Queue / Event Streaming

| SLI | Target |
|-----|--------|
| Delivery success rate | 99.99% within retention window |
| Latency (real-time topics) | P99 < 500ms end-to-end |
| Latency (batch topics) | P99 < 5 minutes |
| Consumer lag (real-time) | < 1,000 messages |
| Consumer lag (batch) | < 100,000 messages |
| Ordering | 100% within partition (correctness invariant) |
| DLQ rate | < 0.01% per day |

### Batch Processing / Data Pipeline

| SLI | Target | Notes |
|-----|--------|-------|
| Freshness (daily) | Data within 4 hours of source | Time-based, not request-based |
| Freshness (streaming) | Data within 15 minutes | — |
| Completeness | 99.9% source records in destination | — |
| Correctness | 99.99% match expected output | — |
| Throughput | Processing rate >= 1.5× ingestion rate | Headroom for catch-up |

### Payment Processing

| SLI | Target | Notes |
|-----|--------|-------|
| Availability | 99.95% | Definitive response (success or decline, not timeout) |
| Latency | P95 < 1s, P99 < 3s | Includes external gateway round-trip |
| Correctness | 99.999% | Zero double-charges (idempotency) |

**Revenue impact:** 500K payments/day at $50 avg × 0.05% failure = 250 failures = **$12,500/day potential lost revenue**

```yaml
- alert: PaymentSLOCritical
  expr: |
    payment:error_ratio:rate1h > (14.4 * 0.0005)
    and
    payment:error_ratio:rate5m > (14.4 * 0.0005)
  labels:
    severity: page
    escalation: "payments-oncall AND engineering-manager"
  annotations:
    revenue_impact: "Estimated ${{ $value | humanize }} lost per hour"
    runbook: "https://runbooks.example.com/payments/slo-violation"
```

### Authentication / Identity Service

| SLI | Target | Notes |
|-----|--------|-------|
| Availability | 99.99% | Auth is critical-path for all services |
| Latency (login) | P99 < 500ms | — |
| Latency (token validation) | P99 < 10ms | High-frequency operation |
| Error rate | < 0.01% infrastructure errors | Excludes wrong-password (user errors) |

### Search Service

| SLI | Target | Notes |
|-----|--------|-------|
| Availability | 99.9% | Non-empty response required |
| Latency | P95 < 200ms, P99 < 500ms | — |
| Relevance | Not an SLO (KPI) | Measured via click-through rate |

### CDN / Static Content

| SLI | Target | Notes |
|-----|--------|-------|
| Availability | 99.99% | Non-5xx at edge |
| Latency (TTFB) | P95 < 50ms, P99 < 200ms | Edge-served |
| Cache hit ratio | > 95% | Operational target, not user-facing SLO |

---

## 13. SLOs for Different Architectures

### Microservices: The Chain Problem

If a request traverses 10 services in series, each at 99.9%:
```
Composite = 0.999^10 = 99.004% (two nines!)
```

Internal three-nines services deliver only two nines to the user.

**Strategy 1: Budget Allocation (Top-Down)**
```
Target: 99.9% user-facing
Chain: 8 services
Required per-service: 0.999^(1/8) = 99.9875%
```

**Strategy 2: Journey-Based SLOs (Google's Recommendation)**
- Set SLOs per user journey, not per service
- "Checkout journey: 99.95% complete successfully within 3s"
- Measure at the edge; use tracing to attribute failures to services

**Strategy 3: Criticality Tiers**
```
Tier 1 (Critical): Payment, Auth → 99.99%
Tier 2 (Important): Search, Catalog → 99.95%
Tier 3 (Nice-to-Have): Recommendations, Analytics → 99.9%
```
Design Tier 3 for graceful degradation (not in critical path).

**Strategy 4: Reduce Serial Dependencies**
- **Caching**: Effective availability = `1 - (1-A_cache) × (1-A_service)`
- **Circuit breakers**: Return cached/default response on failure
- **Async processing**: Move non-critical work to queues
- **BFF pattern**: Parallel fan-out instead of serial chain

**Practical Example — E-Commerce Checkout:**
```
User → API Gateway → Checkout Service
  Checkout calls (in parallel):
    → Inventory (check stock)
    → Pricing (calculate total)
    → User Service (cached address)
  Then serially:
    → Payment (charge card)
    → Order (create order)
  Then async:
    → Notification (email)    ← not in critical path
    → Analytics (log event)   ← not in critical path

Effective chain: 4 (not 8) — parallel calls take max, not product
Composite: 0.9999 × 0.9999 × 0.999 × 0.9999 × 0.9999 ≈ 99.86%
```

### Serverless: Lambda/Cloud Functions

**Unique challenges:**

| Challenge | Impact | Recommendation |
|-----------|--------|---------------|
| Cold start latency (100ms–2s) | Affects P99/P99.9 | Use P95/P99 targets OR Provisioned Concurrency |
| Concurrency limits (1000 default) | Throttling = 429 errors | Separate SLO for throttle rate (< 0.1%) |
| Duration limits (15 min) | Long-running failure | SLO: "99.9% complete before timeout" |

**Cold start by runtime:**
- Go: 50–100ms
- Node.js: 100–250ms
- Python: 100–300ms
- Java/JVM: 500ms–2s

**Serverless SLO Example:**
```
API Lambda Function:
  Availability: 99.95% non-5xx
  Latency P99: < 1 second (including cold start)
  Latency P50: < 200ms
  Throttle rate: < 0.01%
  Window: 7-day rolling
```

### Event-Driven: Kafka Consumers

**Key SLIs:**

| SLI | SLO | Priority |
|-----|-----|----------|
| Processing lag | P99 < 30 seconds | Highest |
| Processing success rate | 99.9% | High |
| End-to-end latency | 99% within 60 seconds | High |
| Throughput | Consumption >= 95% production rate | Medium |
| DLQ rate | < 0.01% per day | Medium |

**Kafka-specific considerations:**
- Consumer rebalancing (10–30s pauses) → exclude from lag SLOs or set generous targets
- Partition skew → measure lag per partition, alert on max
- Exactly-once semantics add latency → factor into SLOs

**Pipeline SLO Example:**
```
Order Processing Pipeline:
  Inventory consumer lag: P99 < 5 seconds
  Payment consumer lag: P99 < 10 seconds
  Notification consumer lag: P99 < 60 seconds
  Processing success: 99.99%
  End-to-end (order → confirmation): P95 < 120 seconds
  DLQ rate: < 0.001% per day
```

### Multi-Region: Globally Distributed Services

**Availability calculations:**

| Pattern | Formula | Example (2 regions at 99.95%) |
|---------|---------|------------------------------|
| Active-Passive | `A_p + (1-A_p) × A_s × A_failover` | 99.9999% (theoretical), ~99.99% (realistic) |
| Active-Active | `1 - (1-A_1) × (1-A_2)` | 99.999975% |

**Multi-region SLO considerations:**

1. **Region-aware latency SLOs:**
   ```
   US users: P99 < 200ms (us-east-1)
   EU users: P99 < 200ms (eu-west-1)
   APAC users: P99 < 300ms (ap-southeast-1)
   ```

2. **Consistency SLOs:**
   ```
   Replication lag: P99 < 1 second
   Eventual consistency: P99 < 5 seconds
   ```

3. **Failover SLOs:**
   ```
   Detection: < 30 seconds
   Execution: < 60 seconds
   Total RTO: < 2 minutes
   RPO: < 1 second (sync) or < 5 minutes (async)
   ```

4. Set **both** global and regional SLOs — global for business, regional for ops.

### SLO for the OpenTelemetry Collector Itself

The Collector sits in the data path for all telemetry — its reliability impacts your ability to detect and respond to incidents.

| SLI | SLO | Metric |
|-----|-----|--------|
| Availability | 99.99% | `otelcol_process_uptime`, health check |
| Data loss rate | < 0.1% | `otelcol_exporter_sent_spans` vs `otelcol_receiver_accepted_spans` |
| Pipeline latency | P99 < 5s | `otelcol_exporter_queue_size` (proxy) |
| Queue saturation | < 80% at P95 | `otelcol_exporter_queue_size / queue_capacity` |
| Resource usage | CPU < 70%, Memory < 80% | `otelcol_process_memory_rss`, `otelcol_process_cpu_seconds` |
| Receiver refusal rate | < 0.01% | `otelcol_receiver_refused_spans / accepted_spans` |

**Collector deployment patterns:**

| Pattern | Target | Architecture |
|---------|--------|-------------|
| Single per host | 99.9% | Agent mode, restarts on failure |
| Pool behind LB | 99.99% | Gateway mode, multiple instances |
| Agent + Gateway (tiered) | 99.99%+ | Agents buffer, gateways export |
| Agent + Kafka + Gateway | 99.999% | Kafka provides durable buffering |

**Critical:** Monitor the Collector via a separate, minimal path (e.g., node_exporter + Prometheus direct scrape) — otherwise a Collector failure hides itself.

---

## 14. Error Budget Policy Template

Based on the Google SRE Workbook's recommended structure:

```
ERROR BUDGET POLICY

Service: [Service Name]
Authors: [Names]
Reviewers: [Names — technical accuracy]
Approvers: [Names — business decision-makers]
Approved: [Date]
Next Review: [Date — typically quarterly]

1. SERVICE OVERVIEW
   Brief description, users, and criticality.

2. SLO DEFINITIONS
   SLI: [e.g., "Proportion of HTTP requests returning 2xx within 500ms"]
   SLO: [e.g., "99.9% over 30-day rolling window"]
   Error Budget: [e.g., "43.2 minutes/month or 1,000 per 1,000,000 requests"]

3. ERROR BUDGET CALCULATION
   Measurement method: [time-based vs. event-based]
   "Bad" definition: [5xx errors, latency > threshold, etc.]
   Exclusions: [planned maintenance, load testing, etc.]

4. POLICY TRIGGERS AND ACTIONS

   4a. Budget Remaining > 50%:
       - Normal release velocity
       - Feature work prioritized
       - Experimentation encouraged

   4b. Budget Remaining 25%–50%:
       - Releases require additional review
       - Stability improvements prioritized in next sprint
       - Post-mortems required for incidents consuming > 5% budget

   4c. Budget Remaining 5%–25%:
       - Release cadence reduced (weekly → biweekly)
       - All changes require explicit SRE approval
       - 50% engineering time on reliability

   4d. Budget Remaining < 5% (or Exhausted):
       - Feature releases frozen
       - Only P0 bugs and security patches
       - 100% engineering focus on reliability
       - Escalation to VP/Director level
       - Remains until budget recovers above 25%

   4e. Single Incident Consumes > 20% of Quarterly Budget:
       - Mandatory post-mortem within 48 hours
       - P0 item on next quarter's planning
       - Architecture review scheduled

5. ESCALATION PATH
   Step 1: SRE lead and Service owner discuss
   Step 2: Escalate to Engineering Director
   Step 3: Escalate to VP Engineering

6. REVIEW CADENCE
   - Weekly: SLO dashboard in team standup
   - Monthly: Error budget in engineering leadership review
   - Quarterly: Full policy review and target re-evaluation
```

---

## 15. Common Mistakes and Anti-Patterns

| # | Anti-Pattern | Why It's Wrong | Fix |
|---|-------------|---------------|-----|
| 1 | **Setting SLOs at 100%** | Eliminates error budget, prevents all releases | Start at 99.9% or lower |
| 2 | **Too many SLOs** | Overwhelms teams, dilutes focus | Google recommends 3–5 per user journey |
| 3 | **SLOs without baselines** | Unrealistic targets | Always measure first (Phase 1), then set targets |
| 4 | **Measuring internal metrics** | CPU/memory don't correlate with user experience | SLOs should reflect what users experience |
| 5 | **SLOs without error budget policies** | SLOs become decorative dashboards | Document consequences at every threshold |
| 6 | **Treating SLOs as SLAs** | Too tight → constant firefighting; too loose → SLA breaches | SLO = internal (stricter), SLA = external (looser) |
| 7 | **Set-and-forget SLOs** | Requirements change over time | Quarterly reviews, adjust based on data |
| 8 | **No action on violations** | Alert fatigue, meaningless SLOs | Clear escalation path and ownership |
| 9 | **Percentiles via Prometheus summaries** | Cannot aggregate across instances | Use histograms instead |
| 10 | **SLOs on uncontrollable dependencies** | Can't improve third-party availability | Set SLOs on what you control; track dependencies separately |

---

## Sources and References

### Google SRE
- [Google SRE Workbook: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) — canonical multi-window multi-burn-rate alerting
- [Google SRE Workbook: Error Budget Policy](https://sre.google/workbook/error-budget-policy/) — error budget policy structure
- [Google SRE Workbook: SLO Document Template](https://sre.google/workbook/slo-document/) — documentation templates
- [Google SRE Workbook: Implementing SLOs](https://sre.google/workbook/implementing-slos/) — organizational guidance
- [Google: Composite Cloud Availability](https://cloud.google.com/blog/products/devops-sre/composite-cloud-availability) — composite SLA math

### SLO Tooling
- [Sloth](https://github.com/slok/sloth) — SLO generator for Prometheus
- [Pyrra](https://github.com/pyrra-dev/pyrra) — Kubernetes-native SLO operator
- [OpenSLO](https://openslo.com/) — vendor-agnostic SLO specification
- [Nobl9](https://www.nobl9.com/) — dedicated SLO management platform
- [Grafana SLO](https://grafana.com/docs/grafana-cloud/alerting-and-irm/slo/) — Grafana Cloud native SLO feature

### Cloud Provider SLAs
- [AWS SLA Index](https://aws.amazon.com/legal/service-level-agreements/)
- [Azure SLA Summary](https://azurecharts.com/sla)
- [GCP SLA Index](https://cloud.google.com/terms/sla)
- [Datadog MSA](https://www.datadoghq.com/legal/msa/)
- [Grafana Cloud SLA](https://grafana.com/legal/grafana-cloud-sla/)

### OpenTelemetry
- [Spanmetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/spanmetricsconnector/README.md) — trace-to-metrics conversion
- [OTel Collector Resiliency](https://opentelemetry.io/docs/collector/resiliency/) — collector reliability patterns

### Industry Practices
- [SRE Workbook Templates (GitHub)](https://github.com/dastergon/sreworkbook-templates-md) — error budget and SLO templates
- [SoundCloud: Alerting on SLOs](https://developers.soundcloud.com/blog/alerting-on-slos/) — production implementation
- [Datadog: Burn Rate is a Better Error Rate](https://www.datadoghq.com/blog/burn-rate-is-better-error-rate/)
- [Google prometheus-slo-burn-example](https://github.com/google/prometheus-slo-burn-example) — reference Grafana dashboard JSON
- [Calculating Composite SLA](https://alexewerlof.medium.com/calculating-composite-sla-d855eaf2c655) — composite SLA math guide
