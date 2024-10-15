# Networking and Service Mesh Observability Deep Dive

> Comprehensive consulting knowledge base covering network observability fundamentals, flow-based analysis (NetFlow/IPFIX/sFlow), DNS observability, load balancer and proxy monitoring, TCP/UDP transport layer, network performance monitoring, service mesh observability (Istio, Linkerd, Cilium/Hubble, Consul Connect), eBPF-based networking tools, mTLS security, Kubernetes networking, CNI plugins, cloud networking (AWS/Azure/GCP), API gateways, distributed tracing for networks, troubleshooting patterns, architecture, and emerging trends.

---

## Table of Contents

### Part I: Network Observability Fundamentals
1. [Network Observability Fundamentals](#1-network-observability-fundamentals)
2. [Flow-Based Network Observability](#2-flow-based-network-observability)
3. [DNS Observability](#3-dns-observability)
4. [Load Balancer and Proxy Observability](#4-load-balancer-and-proxy-observability)
5. [TCP/UDP Transport Layer Observability](#5-tcpudp-transport-layer-observability)
6. [Network Performance Monitoring](#6-network-performance-monitoring)

### Part II: Service Mesh Observability
7. [Service Mesh Fundamentals and Observability](#1-service-mesh-fundamentals-and-observability)
8. [Istio Observability](#2-istio-observability)
9. [Linkerd Observability](#3-linkerd-observability)
10. [Cilium Service Mesh and Hubble](#4-cilium-service-mesh-and-hubble)
11. [Consul Connect Service Mesh](#5-consul-connect-service-mesh)
12. [eBPF-Based Networking Observability](#6-ebpf-based-networking-observability)
13. [mTLS and Security Observability](#7-mtls-and-security-observability-in-service-meshes)

### Part III: Kubernetes, Cloud, and Advanced Networking
14. [Kubernetes Networking Observability](#1-kubernetes-networking-observability)
15. [CNI Plugin Observability](#2-cni-plugin-observability)
16. [Cloud Networking Observability](#3-cloud-networking-observability)
17. [API Gateway Observability](#4-api-gateway-observability)
18. [Distributed Tracing for Network Operations](#5-distributed-tracing-for-network-operations)
19. [Network Troubleshooting Observability](#6-network-troubleshooting-observability)
20. [Network Observability Architecture](#7-network-observability-architecture)
21. [Emerging Trends](#8-emerging-trends)

---


# Part I: Network Observability Fundamentals

---

## 1. Network Observability Fundamentals

### 1.1 Network Observability vs Network Monitoring

Network monitoring and network observability represent fundamentally different paradigms:

| Dimension | Network Monitoring | Network Observability |
|-----------|-------------------|----------------------|
| **Philosophy** | "Is it up?" — known-unknowns | "Why is it slow?" — unknown-unknowns |
| **Data Model** | Predefined metrics, thresholds, alerts | High-cardinality telemetry, ad-hoc querying |
| **Approach** | Poll devices on intervals (60s-300s) | Stream telemetry in real-time (sub-second) |
| **Coverage** | Device-centric (interfaces, CPU, memory) | Flow-centric (conversations, paths, dependencies) |
| **Analysis** | Threshold-based alerting | Correlation, anomaly detection, topology inference |
| **Tools** | Nagios, Zabbix, PRTG, SolarWinds | Kentik, Cilium/Hubble, Elastic, ntopng, OTel |
| **Question** | "Is interface Gi0/1 above 80% utilization?" | "Why did checkout latency spike for EU users?" |
| **Topology** | Static, manually maintained | Dynamic, auto-discovered from telemetry |
| **Granularity** | Per-device, per-interface | Per-flow, per-connection, per-packet |

**The Observability Shift**: Traditional monitoring tells you **that** a link is saturated. Network observability tells you **which** application flows are consuming bandwidth, **where** packets are being dropped, **why** retransmissions are increasing, and **how** the issue correlates with upstream deployments.

### 1.2 The Four Pillars of Network Observability

```
┌──────────────────────────────────────────────────────────────────┐
│                 NETWORK OBSERVABILITY PILLARS                     │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  ┌─────────┐  │
│  │   FLOW        │  │   PACKET     │  │  METRICS │  │TOPOLOGY │  │
│  │   TELEMETRY   │  │   CAPTURE    │  │          │  │         │  │
│  ├──────────────┤  ├──────────────┤  ├──────────┤  ├─────────┤  │
│  │ NetFlow v5/v9│  │ Full PCAP    │  │ SNMP     │  │ L2 (MAC)│  │
│  │ IPFIX        │  │ Filtered     │  │ gNMI     │  │ L3 (IP) │  │
│  │ sFlow        │  │ Rolling      │  │ Streaming│  │ L4 (TCP)│  │
│  │ VPC Flow Logs│  │ Triggered    │  │ OTel     │  │ L7 (App)│  │
│  │              │  │              │  │ WMI/WBEM │  │ BGP     │  │
│  ├──────────────┤  ├──────────────┤  ├──────────┤  ├─────────┤  │
│  │ Who talked to│  │ What was     │  │ How much │  │ How is  │  │
│  │ whom, when,  │  │ said? Deep   │  │ traffic? │  │ traffic │  │
│  │ how much?    │  │ inspection   │  │ How fast?│  │ flowing?│  │
│  └──────────────┘  └──────────────┘  └──────────┘  └─────────┘  │
│                                                                  │
│  Volume: Medium     Volume: Very High  Volume: Low  Volume: Low  │
│  Retention: Weeks   Retention: Hours   Retention:   Retention:   │
│  Use: Forensics     Use: Deep debug    Months       Months       │
│                                        Use: Trend   Use: Path    │
│                                        analysis     analysis     │
└──────────────────────────────────────────────────────────────────┘
```

#### Pillar 1: Flow Telemetry

Flow records summarize network conversations (5-tuple: src IP, dst IP, src port, dst port, protocol) with metadata:

- **NetFlow v5**: Fixed 48-byte records, IPv4 only, sampled, Cisco-proprietary
- **NetFlow v9**: Template-based, extensible, IPv6 support
- **IPFIX** (RFC 7011): Standards-based evolution of NetFlow v9, enterprise information elements
- **sFlow** (RFC 3176): Packet sampling + counter polling, multi-vendor, real-time
- **VPC Flow Logs**: Cloud-native (AWS/Azure/GCP), L3-L4 metadata, no payload

#### Pillar 2: Packet Capture

Full or filtered packet capture provides complete visibility but generates enormous data volumes:

- **Full PCAP**: Every byte captured, 1Gbps link = ~450GB/hour
- **Filtered PCAP**: BPF expressions reduce volume (e.g., `tcp port 443 and host 10.0.1.5`)
- **Rolling Capture**: Circular buffer (e.g., 100GB), overwrite oldest, trigger-based export
- **Triggered Capture**: Start capture on alert/anomaly, stop after N seconds or packets

#### Pillar 3: Network Metrics

Time-series metrics from devices, hosts, and virtual infrastructure:

- **SNMP**: Pull-based, MIB-defined OIDs, v2c/v3, 60-300s polling intervals
- **gNMI/gRPC**: Push-based streaming telemetry, sub-second updates, structured data (YANG models)
- **Prometheus/OTel**: Scrape or push metrics from network exporters, node_exporter, SNMP exporter
- **WMI/WBEM**: Windows-based network metrics collection

#### Pillar 4: Network Topology

Understanding how traffic flows through the network:

- **L2 Topology**: MAC address tables, LLDP/CDP neighbors, spanning tree state
- **L3 Topology**: Routing tables, BGP peering, OSPF adjacencies, traceroute paths
- **L4 Topology**: Connection tables, conntrack entries, NAT mappings
- **L7 Topology**: Service mesh maps, application dependency graphs, DNS resolution chains

### 1.3 OSI Layer Observability Map

Each OSI layer presents unique observability challenges and opportunities:

| OSI Layer | What to Observe | Key Metrics | Tools |
|-----------|----------------|-------------|-------|
| **L1 Physical** | Cable/fiber health, optical power, CRC errors | `ifInErrors`, `ifOutErrors`, optical dBm | SNMP, DOM (Digital Optical Monitoring) |
| **L2 Data Link** | MAC flapping, STP changes, VLAN misconfig, broadcast storms | `dot1dStpTopChanges`, broadcast %, MAC table size | SNMP, LLDP, sFlow |
| **L3 Network** | Routing convergence, BGP flaps, IP fragmentation, TTL exceeded | BGP prefix count, OSPF SPF runs, ICMP unreachable | BGP Exporter, SNMP, traceroute |
| **L4 Transport** | TCP retransmissions, RST floods, conntrack exhaustion, window scaling | `node_netstat_Tcp_RetransSegs`, conntrack count | node_exporter, ss, conntrack |
| **L5 Session** | TLS handshake failures, certificate expiry, session timeouts | TLS error rate, cert days remaining | blackbox_exporter, cert-manager |
| **L6 Presentation** | Compression ratios, encoding errors, serialization failures | Content-Encoding stats, gRPC serialization errors | Application metrics, Envoy stats |
| **L7 Application** | HTTP status codes, DNS resolution, gRPC codes, WebSocket frames | Request rate, error rate, duration, response size | Envoy, nginx, HAProxy, OTel |

### 1.4 Golden Signals for Networking

Adapted from the Google SRE "Four Golden Signals" for network infrastructure:

```
┌──────────────────────────────────────────────────────────────────┐
│              NETWORK GOLDEN SIGNALS                               │
│                                                                  │
│  ┌──────────────────────┐    ┌──────────────────────┐            │
│  │      LATENCY          │    │       LOSS            │           │
│  │                       │    │                       │           │
│  │ • Round-trip time     │    │ • Packet loss %       │           │
│  │ • One-way delay       │    │ • TCP retransmissions │           │
│  │ • DNS resolution time │    │ • Queue drops         │           │
│  │ • TCP handshake time  │    │ • Interface errors    │           │
│  │ • TLS handshake time  │    │ • CRC/FCS errors      │           │
│  │                       │    │ • Black hole routes   │           │
│  │ Target: <1ms LAN      │    │ Target: <0.01% LAN   │           │
│  │         <50ms WAN     │    │         <0.1% WAN    │           │
│  │         <100ms global │    │         <1% cellular │           │
│  └──────────────────────┘    └──────────────────────┘            │
│                                                                  │
│  ┌──────────────────────┐    ┌──────────────────────┐            │
│  │     THROUGHPUT        │    │       JITTER          │           │
│  │                       │    │                       │           │
│  │ • Bits/sec (bps)     │    │ • Packet delay var.   │           │
│  │ • Packets/sec (pps)  │    │ • Inter-packet gap    │           │
│  │ • Flows/sec          │    │ • Reordering rate     │           │
│  │ • Connections/sec    │    │ • Buffer bloat (BBE)  │           │
│  │ • Goodput vs         │    │ • OWD variation       │           │
│  │   throughput ratio   │    │                       │           │
│  │                       │    │ Target: <1ms VoIP    │           │
│  │ Target: ≥80% link    │    │         <5ms video   │           │
│  │ capacity utilization │    │         <30ms general│           │
│  └──────────────────────┘    └──────────────────────┘            │
└──────────────────────────────────────────────────────────────────┘
```

#### PromQL: Golden Signal Queries

```promql
# --- LATENCY ---
# Average TCP round-trip time (from node_exporter or eBPF)
avg(node_tcp_rtt_seconds) by (instance)

# DNS resolution latency (from CoreDNS or blackbox_exporter)
histogram_quantile(0.99,
  sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, server)
)

# TCP SYN-ACK latency (handshake time) from blackbox_exporter
probe_duration_seconds{phase="connect"}

# --- LOSS ---
# TCP retransmission rate
rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) * 100

# Interface packet drops (input + output)
rate(node_network_receive_drop_total[5m]) + rate(node_network_transmit_drop_total[5m])

# Interface errors
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])

# --- THROUGHPUT ---
# Interface utilization percentage (requires knowing link speed)
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8
  / node_network_speed_bytes{device="eth0"} / 8 * 100

# Packets per second
rate(node_network_receive_packets_total[5m]) + rate(node_network_transmit_packets_total[5m])

# --- JITTER ---
# TCP RTT variance (from eBPF or tcp_info)
stddev_over_time(node_tcp_rtt_seconds[5m])

# Blackbox exporter probe duration variance
stddev_over_time(probe_duration_seconds{job="blackbox"}[1h])
```

### 1.5 Network SLIs and SLOs

Define measurable service level indicators for network infrastructure:

| SLI | Measurement Method | Good Threshold | SLO Target |
|-----|-------------------|----------------|------------|
| **Availability** | Synthetic probe success rate | probe_success == 1 | 99.99% (4.3 min/month downtime) |
| **Latency** | TCP connect + TLS handshake | < 50ms intra-region | 99.9% of probes < 50ms |
| **Packet Loss** | ICMP echo or TCP retrans ratio | < 0.01% | 99.95% of intervals < 0.01% |
| **Throughput** | Interface utilization vs capacity | < 80% sustained | 99.9% of intervals < 80% |
| **DNS Resolution** | CoreDNS/resolver query latency | < 5ms internal | 99.99% of queries < 5ms |
| **Certificate Validity** | Days until expiry | > 30 days | 100% certs > 30 days from expiry |
| **BGP Stability** | Prefix count delta, flap rate | 0 unexpected changes | 99.99% stable intervals |
| **Conntrack Utilization** | nf_conntrack_count / max | < 75% | 99.9% of intervals < 75% |

#### SLO Error Budget Calculation

```promql
# Availability SLO: 99.99% over 30 days
# Error budget: 0.01% * 30 * 24 * 60 = 4.32 minutes

# Remaining error budget
1 - (
  sum(probe_success{job="network-slo"} == 0)
  / sum(probe_success{job="network-slo"})
) / 0.0001

# Burn rate alert (consuming budget 14.4x faster than allowed)
(
  1 - avg_over_time(probe_success{job="network-slo"}[1h])
) > 14.4 * 0.0001
```

### 1.6 Network Telemetry Data Types

#### SNMP (Simple Network Management Protocol)

```yaml
# Prometheus SNMP Exporter configuration (snmp.yml)
modules:
  if_mib:
    walk:
      - 1.3.6.1.2.1.2.2.1     # ifTable
      - 1.3.6.1.2.1.31.1.1    # ifXTable (64-bit counters)
    metrics:
      - name: ifHCInOctets
        oid: 1.3.6.1.2.1.31.1.1.1.6
        type: counter
        help: Total number of octets received (64-bit)
        indexes:
          - labelname: ifIndex
            type: Integer
        lookups:
          - labels: [ifIndex]
            labelname: ifDescr
            oid: 1.3.6.1.2.1.2.2.1.2
            type: DisplayString
      - name: ifHCOutOctets
        oid: 1.3.6.1.2.1.31.1.1.1.10
        type: counter
        help: Total number of octets transmitted (64-bit)
      - name: ifOperStatus
        oid: 1.3.6.1.2.1.2.2.1.8
        type: gauge
        help: Current operational status (1=up, 2=down, 3=testing)
      - name: ifSpeed
        oid: 1.3.6.1.2.1.2.2.1.5
        type: gauge
        help: Interface speed in bits/sec
```

#### gNMI (gRPC Network Management Interface)

```yaml
# OpenTelemetry Collector gNMI receiver (experimental)
receivers:
  gnmi:
    targets:
      - address: "switch01.example.com:6030"
        credentials:
          username: "${GNMI_USER}"
          password: "${GNMI_PASS}"
        tls:
          insecure: false
          ca_file: /etc/ssl/certs/ca.pem
    subscriptions:
      - name: interface_counters
        path: "/interfaces/interface/state/counters"
        mode: sample
        sample_interval: 10s
      - name: bgp_neighbors
        path: "/network-instances/network-instance/protocols/protocol/bgp/neighbors"
        mode: on_change
      - name: cpu_utilization
        path: "/components/component/cpu/utilization"
        mode: sample
        sample_interval: 30s
```

#### Streaming Telemetry Evolution

```
Timeline of Network Telemetry:

1988 ──► SNMP v1         Pull-based, community strings, no encryption
1993 ──► SNMP v2c        64-bit counters, bulk operations
1998 ──► NetFlow v5      Fixed format, sampled flow records
2002 ──► SNMP v3         Authentication, encryption, USM
2004 ──► NetFlow v9      Template-based, extensible
2004 ──► sFlow v5        Packet sampling + counters, multi-vendor
2013 ──► IPFIX           IETF standard, enterprise information elements
2017 ──► gNMI            gRPC streaming, YANG models, sub-second
2020 ──► OpenTelemetry   Unified signals (metrics/traces/logs), network expanding
2023 ──► OTel Network    Network-specific semantic conventions emerging
2024 ──► eBPF telemetry  Kernel-level, zero-config, per-connection visibility
```

### 1.7 OpenTelemetry for Network Observability

OpenTelemetry is expanding into network observability with dedicated semantic conventions and receivers:

#### OTel Collector Network-Related Receivers

```yaml
# Comprehensive OTel Collector for network observability
receivers:
  # SNMP polling
  snmp:
    collection_interval: 60s
    endpoint: udp://0.0.0.0:161
    version: v2c
    community: "${SNMP_COMMUNITY}"
    metrics:
      interface.bytes.received:
        unit: By
        gauge:
          value_type: int
        column_oids:
          - oid: "1.3.6.1.2.1.31.1.1.1.6"
            attributes:
              - name: interface
                oid: "1.3.6.1.2.1.2.2.1.2"

  # NetFlow/IPFIX collection
  netflow:
    protocols:
      - netflow_v5
      - netflow_v9
      - ipfix
      - sflow
    endpoint: 0.0.0.0:2055

  # Host network metrics
  hostmetrics:
    collection_interval: 15s
    scrapers:
      network:
        include:
          interfaces: ["eth.*", "ens.*", "bond.*"]
          match_type: regexp

  # Syslog from network devices
  syslog:
    udp:
      listen_address: "0.0.0.0:514"
    protocol: rfc5424

  # Synthetic probing
  httpcheck:
    targets:
      - endpoint: "https://api.example.com/health"
        method: GET
      - endpoint: "https://cdn.example.com"
        method: HEAD
    collection_interval: 30s

processors:
  # Enrich with network context
  attributes:
    actions:
      - key: network.region
        value: "us-east-1"
        action: upsert
      - key: network.environment
        value: "production"
        action: upsert

  # Reduce cardinality on flow data
  transform:
    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["src.ip.masked"], replace_pattern(attributes["src.ip"], "\\.(\\d+)$", ".0"))

exporters:
  otlp:
    endpoint: "otel-gateway:4317"
    tls:
      insecure: false

service:
  pipelines:
    metrics:
      receivers: [snmp, hostmetrics, netflow, httpcheck]
      processors: [attributes, transform]
      exporters: [otlp]
    logs:
      receivers: [syslog]
      processors: [attributes]
      exporters: [otlp]
```

#### OTel Network Semantic Conventions

```yaml
# Semantic conventions for network observability (emerging standard)
# Resource attributes
resource:
  network.device.name: "core-sw01"
  network.device.vendor: "Arista"
  network.device.model: "7280R3"
  network.device.os: "EOS-4.31.2"
  network.device.serial: "JPE12345678"
  network.site: "us-east-1a"
  network.role: "core-switch"

# Metric semantic conventions
metrics:
  # Interface metrics
  - network.io.transmit          # bytes transmitted
  - network.io.receive           # bytes received
  - network.packets.transmit     # packets transmitted
  - network.packets.receive      # packets received
  - network.errors.transmit      # transmit errors
  - network.errors.receive       # receive errors
  - network.drops.transmit       # transmit drops
  - network.drops.receive        # receive drops

  # Connection metrics
  - network.connections.active   # current active connections
  - network.connections.new      # new connections/sec

  # DNS metrics
  - dns.query.duration           # DNS query response time
  - dns.query.count              # DNS queries count
  - dns.response.rcode           # DNS response codes
```

---

## 2. Flow-Based Network Observability

### 2.1 Flow Protocol Comparison

| Feature | NetFlow v5 | NetFlow v9 | IPFIX | sFlow |
|---------|-----------|-----------|-------|-------|
| **Standard** | Cisco proprietary | Cisco proprietary | IETF RFC 7011 | RFC 3176 |
| **Record Format** | Fixed (48 bytes) | Template-based | Template-based | Datagram-based |
| **IPv6 Support** | No | Yes | Yes | Yes |
| **MPLS Support** | No | Yes | Yes | Yes |
| **VXLAN/Overlay** | No | Yes | Yes | Yes |
| **Sampling** | 1:N per-flow | 1:N configurable | 1:N configurable | 1:N per-packet |
| **Latency** | Flow cache timeout | Flow cache timeout | Flow cache timeout | Real-time |
| **Multi-vendor** | Cisco only | Cisco primarily | All major vendors | All major vendors |
| **Template ID** | None | 16-bit | 16-bit | None |
| **Enterprise Fields** | No | No | Yes (PEN) | Yes (enterprise) |
| **Transport** | UDP | UDP/SCTP | UDP/SCTP/TCP | UDP |
| **Typical Use** | Legacy networks | Cisco shops | Standard deployments | Real-time analysis |

### 2.2 NetFlow v5 Record Structure

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source IP Address (32 bits)                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       Destination IP Address (32 bits)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Next Hop IP Address (32 bits)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Input SNMP (16)    |     Output SNMP (16)               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|             Packets (32 bits)                                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|             Octets (32 bits)                                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      First Timestamp (32)      |     Last Timestamp (32)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Src Port (16)  |  Dst Port (16) | Pad | TCP Flags | Proto |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   ToS (8)  |  Src AS (16)  |  Dst AS (16)  |  Src Mask (8) |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Dst Mask (8)  |         Padding (16)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 2.3 IPFIX Information Elements (Common)

```yaml
# Key IPFIX Information Elements for network observability
information_elements:
  # Standard (IANA)
  - id: 1    # octetDeltaCount        - bytes in this flow
  - id: 2    # packetDeltaCount       - packets in this flow
  - id: 4    # protocolIdentifier     - IP protocol (6=TCP, 17=UDP)
  - id: 5    # ipClassOfService       - ToS/DSCP
  - id: 7    # sourceTransportPort
  - id: 8    # sourceIPv4Address
  - id: 11   # destinationTransportPort
  - id: 12   # destinationIPv4Address
  - id: 21   # flowEndSysUpTime
  - id: 22   # flowStartSysUpTime
  - id: 27   # sourceIPv6Address
  - id: 28   # destinationIPv6Address
  - id: 32   # icmpTypeCodeIPv4
  - id: 56   # sourceMacAddress
  - id: 80   # destinationMacAddress
  - id: 136  # flowEndReason           # 1=idle, 2=active, 3=end, 4=forced, 5=lack
  - id: 148  # flowId
  - id: 150  # flowStartSeconds
  - id: 151  # flowEndSeconds
  - id: 152  # flowStartMilliseconds
  - id: 153  # flowEndMilliseconds
  - id: 176  # icmpTypeIPv4
  - id: 177  # icmpCodeIPv4
  - id: 210  # paddingOctets
  - id: 225  # postNATSourceIPv4Address
  - id: 226  # postNATDestIPv4Address
  - id: 227  # postNAPTSourceTransportPort
  - id: 228  # postNAPTDestTransportPort

  # Enterprise-specific (Private Enterprise Number)
  # Cisco PEN: 9
  - pen: 9
    id: 12232  # Cisco Application ID
  - pen: 9
    id: 12233  # Cisco Application Name

  # VMware PEN: 6876
  - pen: 6876
    id: 880    # Virtual Machine Name
  - pen: 6876
    id: 881    # Virtual Machine UUID
```

### 2.4 sFlow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    sFlow ARCHITECTURE                     │
│                                                          │
│  ┌──────────────────────────────────┐                    │
│  │        Network Switch             │                   │
│  │                                   │                   │
│  │  ┌────────────┐  ┌────────────┐  │                   │
│  │  │ Packet     │  │ Counter    │  │                   │
│  │  │ Sampling   │  │ Polling    │  │                   │
│  │  │ Agent      │  │ Agent      │  │                   │
│  │  │            │  │            │  │                   │
│  │  │ Rate: 1:N  │  │ Interval:  │  │                   │
│  │  │ (1:1000-   │  │ 20-30s     │  │                   │
│  │  │  1:10000)  │  │            │  │                   │
│  │  └─────┬──────┘  └─────┬──────┘  │                   │
│  │        │               │          │                   │
│  └────────┼───────────────┼──────────┘                   │
│           │               │                              │
│           ▼               ▼                              │
│  ┌──────────────────────────────────┐                    │
│  │     sFlow Datagram (UDP)         │                    │
│  │  ┌────────────────────────────┐  │                    │
│  │  │ Header:                    │  │                    │
│  │  │  - Agent IP                │  │                    │
│  │  │  - Sub-agent ID            │  │                    │
│  │  │  - Sequence Number         │  │                    │
│  │  │  - Uptime                  │  │                    │
│  │  │  - Num Samples             │  │                    │
│  │  ├────────────────────────────┤  │                    │
│  │  │ Flow Samples:              │  │                    │
│  │  │  - Input/Output ifIndex    │  │                    │
│  │  │  - Sampling Rate           │  │                    │
│  │  │  - Raw Packet Header       │  │                    │
│  │  │    (first 128 bytes)       │  │                    │
│  │  ├────────────────────────────┤  │                    │
│  │  │ Counter Samples:           │  │                    │
│  │  │  - ifInOctets              │  │                    │
│  │  │  - ifOutOctets             │  │                    │
│  │  │  - ifInErrors              │  │                    │
│  │  │  - ifOutErrors             │  │                    │
│  │  │  - ifInDiscards            │  │                    │
│  │  └────────────────────────────┘  │                    │
│  └──────────────────────────────────┘                    │
│           │                                              │
│           ▼                                              │
│  ┌──────────────────────────────────┐                    │
│  │     sFlow Collector              │                    │
│  │  (sflowtool, ntopng, GoFlow2,   │                    │
│  │   pmacct, OTel Collector)        │                    │
│  └──────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

### 2.5 Flow Collection Architecture

#### GoFlow2 (Open Source, High Performance)

```yaml
# GoFlow2 deployment for flow collection
# docker-compose.yml
version: "3.8"
services:
  goflow2:
    image: netsampler/goflow2:latest
    ports:
      - "2055:2055/udp"   # NetFlow
      - "6343:6343/udp"   # sFlow
      - "4739:4739/udp"   # IPFIX
    command: >
      -transport.kafka=true
      -transport.kafka.brokers=kafka:9092
      -transport.kafka.topic=flows
      -format.type=protobuf
    environment:
      - GOFLOW2_WORKERS=4

  # Alternative: direct Prometheus export
  goflow2-prom:
    image: netsampler/goflow2:latest
    ports:
      - "2055:2055/udp"
      - "8080:8080"      # Prometheus metrics
    command: >
      -transport.type=prometheus
      -metrics.addr=:8080
```

#### OTel Collector NetFlow Receiver

```yaml
# OpenTelemetry Collector with NetFlow/IPFIX receiver
receivers:
  netflow:
    endpoint: 0.0.0.0:2055
    protocols:
      - netflow_v5
      - netflow_v9
      - ipfix
      - sflow
    workers: 4
    queue_size: 10000
    # Cache for template tracking (NetFlow v9/IPFIX)
    template_cache_size: 1000

processors:
  # Enrich flows with geo-IP data
  geoip:
    context: resource
    providers:
      maxmind:
        database_path: /etc/otel/GeoLite2-City.mmdb

  # Filter internal-only flows
  filter:
    metrics:
      exclude:
        match_type: expr
        expressions:
          - 'attributes["src.ip"] matches "^10\\." && attributes["dst.ip"] matches "^10\\."'

  # Aggregate to reduce cardinality
  groupbyattrs:
    keys:
      - src.ip
      - dst.ip
      - dst.port
      - protocol

  batch:
    send_batch_size: 5000
    timeout: 10s

exporters:
  kafka:
    brokers:
      - kafka-01:9092
      - kafka-02:9092
    topic: network-flows
    encoding: otlp_proto

  prometheusremotewrite:
    endpoint: "http://mimir:9009/api/v1/push"

service:
  pipelines:
    metrics:
      receivers: [netflow]
      processors: [geoip, filter, groupbyattrs, batch]
      exporters: [prometheusremotewrite, kafka]
```

### 2.6 Flow Analysis Tools Comparison

| Tool | Type | Strengths | Scale | Cost |
|------|------|-----------|-------|------|
| **ntopng** | Open source | Real-time DPI, web UI, flow DB | Single box, 10Gbps+ | Community/Enterprise |
| **ElastiFlow** | Open source + commercial | ELK integration, dashboards | Cluster, 100K+ fps | Free/Pro |
| **GoFlow2** | Open source | Lightweight, Kafka/Prometheus output | High, 500K+ fps | Free |
| **Kentik** | SaaS | ML anomaly detection, BGP correlation | Unlimited | $$$ |
| **pmacct** | Open source | Flexible, SQL/Kafka/AMQP backends | Medium | Free |
| **nfdump/nfsen** | Open source | CLI analysis, historical queries | Medium | Free |
| **Akvorado** | Open source (Free) | Modern, ClickHouse backend, rich UI | High | Free |
| **Plixer Scrutinizer** | Commercial | Enterprise, compliance, forensics | Large | $$$ |

### 2.7 Flow Metrics and PromQL

```promql
# --- Flow-Derived Metrics ---

# Top talkers by bytes (using flow-exported metrics)
topk(10,
  sum(rate(network_flow_bytes_total[5m])) by (src_ip, dst_ip)
)

# Traffic by protocol
sum(rate(network_flow_bytes_total[5m])) by (protocol)

# Traffic by destination port (service identification)
topk(20,
  sum(rate(network_flow_bytes_total[5m])) by (dst_port)
)

# Flows per second by exporter
sum(rate(network_flow_count_total[5m])) by (exporter)

# East-West vs North-South traffic ratio
sum(rate(network_flow_bytes_total{direction="internal"}[5m]))
  /
sum(rate(network_flow_bytes_total[5m]))
```

### 2.8 Flow-Based Anomaly Detection

#### DDoS Detection

```promql
# Sudden spike in flows per second (potential DDoS)
rate(network_flow_count_total[1m]) > 5 * avg_over_time(rate(network_flow_count_total[1m])[1h:1m])

# SYN flood: high SYN rate with low SYN-ACK ratio
rate(network_flow_tcp_flags_syn_total[1m])
  /
rate(network_flow_tcp_flags_synack_total[1m])
  > 10

# UDP amplification: disproportionate response size
sum(rate(network_flow_bytes_total{protocol="17",direction="inbound"}[1m])) by (dst_port)
  /
sum(rate(network_flow_bytes_total{protocol="17",direction="outbound"}[1m])) by (src_port)
  > 100

# DNS amplification specifically (port 53 response >> request)
sum(rate(network_flow_bytes_total{protocol="17",dst_port="53",direction="outbound"}[1m]))
  * 50 <
sum(rate(network_flow_bytes_total{protocol="17",src_port="53",direction="inbound"}[1m]))
```

#### Network Scanning Detection

```promql
# Port scan: single source hitting many destination ports
count(
  count(network_flow_bytes_total) by (src_ip, dst_port)
) by (src_ip) > 100

# Host scan: single source hitting many destination IPs on same port
count(
  count(network_flow_bytes_total) by (src_ip, dst_ip)
) by (src_ip) > 50
```

#### Data Exfiltration Detection

```promql
# Unusual outbound data volume from a single host
topk(5,
  sum(rate(network_flow_bytes_total{direction="outbound"}[1h])) by (src_ip)
) > 1e9  # More than 1GB/hour outbound

# DNS exfiltration: high volume of unique DNS queries
rate(coredns_dns_requests_total{type="A"}[5m]) by (client) > 100

# Large uploads to external IPs (non-RFC1918)
sum(rate(network_flow_bytes_total{
  direction="outbound",
  dst_ip!~"^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)"
}[5m])) by (src_ip, dst_ip)
> 100e6  # 100 MB/s to external
```

### 2.9 Cloud VPC Flow Logs Comparison

| Feature | AWS VPC Flow Logs | Azure NSG Flow Logs | GCP VPC Flow Logs |
|---------|-------------------|---------------------|-------------------|
| **Granularity** | ENI (per-interface) | NSG rule level | VPC subnet/VM |
| **Fields** | 14 default + 15 custom | 13+ fields | 20+ fields |
| **Sampling** | All or nothing | All or nothing | Configurable 0.0-1.0 |
| **Aggregation** | 1-min or 10-min windows | 1-min windows | 5s, 30s, 1m, 5m, 15m |
| **Storage** | S3, CloudWatch Logs | Blob Storage | Cloud Storage, BigQuery |
| **Latency** | ~10 minutes | ~1-5 minutes | ~5 seconds (!) |
| **Cost Driver** | Per-GB ingested | Per-flow log enabled | Per-GB generated |
| **Max Fields** | 29 (v5 format) | ~15 | ~25 |
| **Direction** | Ingress + Egress | Inbound + Outbound | Ingress + Egress |
| **TCP Flags** | Yes (v3+) | No | Yes |
| **VPC Peering** | Yes | Yes (VNet) | Yes |
| **Transit Gateway** | Yes (separate) | No | No |
| **Reject Reason** | ACCEPT/REJECT | Allow/Deny + rule | ALLOWED/DENIED |
| **Packet Bytes** | Yes | Yes | Yes |

#### AWS VPC Flow Log Format (v5)

```
# Default fields:
# version account-id interface-id srcaddr dstaddr srcport dstport
# protocol packets bytes start end action log-status

# Custom format (recommended):
${version} ${vpc-id} ${subnet-id} ${instance-id} ${interface-id}
${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol}
${packets} ${bytes} ${start} ${end} ${action} ${log-status}
${tcp-flags} ${type} ${pkt-srcaddr} ${pkt-dstaddr}
${region} ${az-id} ${sublocation-type} ${sublocation-id}
${pkt-src-aws-service} ${pkt-dst-aws-service} ${flow-direction}
${traffic-path}
```

#### GCP VPC Flow Log Schema

```json
{
  "connection": {
    "src_ip": "10.0.0.5",
    "src_port": 54321,
    "dest_ip": "10.0.1.10",
    "dest_port": 443,
    "protocol": 6
  },
  "src_instance": {
    "project_id": "my-project",
    "vm_name": "web-server-01",
    "zone": "us-central1-a",
    "region": "us-central1"
  },
  "dest_instance": {
    "project_id": "my-project",
    "vm_name": "api-server-01",
    "zone": "us-central1-b",
    "region": "us-central1"
  },
  "src_vpc": {
    "vpc_name": "prod-vpc",
    "subnetwork_name": "web-subnet",
    "project_id": "my-project"
  },
  "bytes_sent": 150000,
  "packets_sent": 1200,
  "start_time": "2024-01-15T10:00:00Z",
  "end_time": "2024-01-15T10:00:05Z",
  "reporter": "SRC",
  "rtt_msec": 1.2
}
```

---

## 3. DNS Observability

### 3.1 DNS as a Critical Observability Signal

DNS is the **first network transaction** for virtually every application request. DNS failures or slowness cascade into application-level errors that are often misdiagnosed as service failures:

```
User Request Flow:
  Browser/App → DNS Lookup → TCP Connect → TLS Handshake → HTTP Request → Response

If DNS fails:
  Browser/App → DNS Lookup [TIMEOUT 5s] → Retry → DNS Lookup [TIMEOUT 5s] → Error
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                10 seconds invisible to APM tools unless DNS is instrumented

If DNS is slow:
  DNS adds latency to EVERY new connection, EVERY service discovery call,
  EVERY external API call. A 50ms DNS regression affects millions of requests.
```

**Why DNS Observability Matters:**

- **98%+ of outages involve DNS** in some capacity (source: various post-mortems)
- DNS caching masks problems until TTL expires, then failures cascade
- DNS is the primary vector for data exfiltration (DNS tunneling)
- Service mesh and Kubernetes depend on DNS for service discovery
- CDN, load balancer, and failover mechanisms rely on DNS

### 3.2 DNS Query/Response Monitoring

#### Key DNS Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| **Query Rate** | Queries per second by type (A, AAAA, CNAME, SRV, PTR) | Anomaly: >3x baseline |
| **Response Latency** | Time to resolve, by upstream | P99 > 100ms internal, >500ms external |
| **Response Code** | NOERROR, NXDOMAIN, SERVFAIL, REFUSED | SERVFAIL rate > 1% |
| **Cache Hit Ratio** | % of queries served from cache | < 70% indicates TTL or cardinality issue |
| **Upstream Health** | Success rate per upstream resolver | < 99% per upstream |
| **DNSSEC Validation** | Signature verification success/failure | Any failure is critical |
| **Query Type Distribution** | Mix of A/AAAA/SRV/TXT/MX | TXT spike = possible tunneling |
| **NXDOMAIN Rate** | Non-existent domain queries | Spike = DGA malware or misconfiguration |

### 3.3 CoreDNS in Kubernetes

CoreDNS is the default DNS server in Kubernetes, handling all internal service discovery:

#### CoreDNS Architecture in Kubernetes

```
┌──────────────────────────────────────────────────────────────────┐
│                 Kubernetes DNS Architecture                       │
│                                                                  │
│  ┌────────┐  DNS Query   ┌─────────────────────────────────┐    │
│  │  Pod   │─────────────►│         CoreDNS                  │    │
│  │        │  (UDP/TCP    │  ┌─────────────────────────┐     │    │
│  │  /etc/ │   port 53)   │  │      Corefile            │    │    │
│  │resolv. │              │  │                           │    │    │
│  │conf    │              │  │  .:53 {                   │    │    │
│  │        │              │  │    errors                 │    │    │
│  │nameser-│              │  │    health :8080           │    │    │
│  │ver     │              │  │    ready :8181            │    │    │
│  │10.96.  │              │  │    kubernetes cluster.    │    │    │
│  │0.10    │              │  │      local in-addr.arpa  │    │    │
│  └────────┘              │  │      ip6.arpa {          │    │    │
│                          │  │        pods insecure     │    │    │
│                          │  │        fallthrough in-   │    │    │
│                          │  │          addr.arpa       │    │    │
│                          │  │          ip6.arpa        │    │    │
│                          │  │      }                   │    │    │
│  svc.namespace.svc.      │  │    prometheus :9153      │    │    │
│  cluster.local           │  │    forward . /etc/       │    │    │
│     │                    │  │      resolv.conf         │    │    │
│     ▼                    │  │    cache 30              │    │    │
│  10.96.X.Y (ClusterIP)  │  │    loop                  │    │    │
│                          │  │    reload                │    │    │
│                          │  │    loadbalance           │    │    │
│                          │  │  }                       │    │    │
│                          │  └─────────────────────────┘    │    │
│                          └─────────────────────────────────┘    │
│                                                                  │
│  DNS Resolution Chain:                                           │
│  1. svc-name → svc-name.namespace.svc.cluster.local             │
│  2. If not found: → svc-name.svc.cluster.local                  │
│  3. If not found: → svc-name.cluster.local                      │
│  4. If not found: → forward to upstream (/etc/resolv.conf)      │
│                                                                  │
│  ndots:5 means short names generate 5 queries before trying     │
│  the name as-is. This is the #1 source of DNS amplification!    │
└──────────────────────────────────────────────────────────────────┘
```

#### CoreDNS Prometheus Metrics

```yaml
# CoreDNS exposes metrics on :9153/metrics
# Key metrics for observability:

# ServiceMonitor for CoreDNS
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: coredns
  namespace: kube-system
  labels:
    app: coredns
spec:
  selector:
    matchLabels:
      k8s-app: kube-dns
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
```

#### CoreDNS PromQL Queries

```promql
# --- CoreDNS Performance ---

# Query rate by type
sum(rate(coredns_dns_requests_total[5m])) by (type)

# Response latency P99
histogram_quantile(0.99,
  sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)
)

# Response latency P50, P95, P99 by server zone
histogram_quantile(0.50, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, zone))
histogram_quantile(0.95, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, zone))
histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le, zone))

# Response code distribution
sum(rate(coredns_dns_responses_total[5m])) by (rcode)

# SERVFAIL rate (should be near zero)
sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
  /
sum(rate(coredns_dns_responses_total[5m]))

# NXDOMAIN rate (high rate may indicate misconfiguration or DGA)
sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[5m]))
  /
sum(rate(coredns_dns_responses_total[5m]))

# Cache hit ratio
sum(rate(coredns_cache_hits_total[5m]))
  /
(sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))

# Cache size
coredns_cache_entries{type="success"} + coredns_cache_entries{type="denial"}

# Forward request rate and latency (upstream resolvers)
sum(rate(coredns_forward_requests_total[5m])) by (to)

histogram_quantile(0.99,
  sum(rate(coredns_forward_request_duration_seconds_bucket[5m])) by (le, to)
)

# Forward health check failures
sum(rate(coredns_forward_healthcheck_failures_total[5m])) by (to)

# Panics (should always be 0)
coredns_panics_total

# --- CoreDNS Alerting Rules ---
# Alert: High SERVFAIL rate
# expr: sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
#         / sum(rate(coredns_dns_responses_total[5m])) > 0.01
# for: 5m
# severity: warning

# Alert: CoreDNS latency high
# expr: histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)) > 0.1
# for: 10m
# severity: warning

# Alert: CoreDNS forward errors
# expr: sum(rate(coredns_forward_responses_total{rcode=~"SERVFAIL|REFUSED"}[5m])) by (to) > 0
# for: 5m
# severity: warning
```

#### CoreDNS Logging Plugin for Deep Observability

```
# Corefile with DNS query logging
.:53 {
    errors
    health :8080
    ready :8181

    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
    }

    # Log all queries (WARNING: high volume in production)
    # Use only for debugging or pipe to sampling
    log . {
        class denial error   # Only log NXDOMAIN and errors
        format combined       # Apache combined format
    }

    # Alternative: dnstap for structured logging
    dnstap tcp://dnstap-collector:6000 full

    prometheus :9153
    forward . /etc/resolv.conf {
        max_concurrent 1000
        health_check 5s
    }
    cache 30 {
        success 9984 30   # Cache success for 30s, max 9984 entries
        denial 9984 5     # Cache NXDOMAIN for 5s
        prefetch 10 60s   # Prefetch if >10 QPS and within 60s of expiry
    }
    loop
    reload
    loadbalance
}
```

### 3.4 Kubernetes DNS Performance Optimization

```yaml
# ndots optimization: reduce DNS query amplification
# Default ndots:5 means "api.external.com" generates:
#   1. api.external.com.namespace.svc.cluster.local
#   2. api.external.com.svc.cluster.local
#   3. api.external.com.cluster.local
#   4. api.external.com.us-east-1.compute.internal  (cloud search domain)
#   5. api.external.com.                             (finally!)
# = 5 queries instead of 1!

# Fix 1: Use FQDNs with trailing dot in code
# "api.external.com."  <-- trailing dot = absolute, no search

# Fix 2: Reduce ndots in pod spec
apiVersion: v1
kind: Pod
metadata:
  name: optimized-dns
spec:
  dnsConfig:
    options:
      - name: ndots
        value: "2"     # Reduce from 5 to 2
      - name: timeout
        value: "2"     # Reduce timeout from 5s to 2s
      - name: attempts
        value: "3"     # Limit retry attempts
      - name: single-request-reopen
                       # Avoid port reuse issues
  containers:
    - name: app
      image: myapp:latest

# Fix 3: NodeLocal DNSCache (recommended for large clusters)
# Runs a DNS cache on each node, reducing CoreDNS load by 80%+
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-local-dns
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: node-local-dns
  template:
    metadata:
      labels:
        k8s-app: node-local-dns
    spec:
      hostNetwork: true
      dnsPolicy: Default
      containers:
        - name: node-cache
          image: registry.k8s.io/dns/k8s-dns-node-cache:1.23.1
          args:
            - "-localip"
            - "169.254.20.10,10.96.0.10"
            - "-conf"
            - "/etc/Corefile"
            - "-upstreamsvc"
            - "kube-dns"
            - "-health-port"
            - "8080"
            - "-metrics-listen-address"
            - "0.0.0.0:9253"
          ports:
            - containerPort: 53
              name: dns
              protocol: UDP
            - containerPort: 53
              name: dns-tcp
              protocol: TCP
            - containerPort: 9253
              name: metrics
              protocol: TCP
```

### 3.5 DNS Threat Detection

#### DNS Tunneling Detection

DNS tunneling encodes data in DNS queries/responses, typically using TXT records or long subdomain labels:

```
Normal DNS query:  www.example.com                     (15 chars)
Tunneling query:   aGVsbG8gd29ybGQ.t.evil.com         (27 chars)
                   cXVlcnkgZXhmaWx0cmF0aW9u.t.evil.com  (37 chars)

Detection signals:
1. Query length > 50 characters
2. High entropy in subdomain labels (base64/hex encoded)
3. Unusual record types (TXT, NULL, CNAME with long values)
4. High query volume to a single domain
5. Unusual query patterns (regular intervals, sequential)
```

```promql
# DNS tunneling detection queries

# Unusually long DNS queries (potential tunneling)
# Requires custom metric from CoreDNS log analysis or eBPF
dns_query_name_length_bytes > 50

# High TXT record query rate from single client
sum(rate(coredns_dns_requests_total{type="TXT"}[5m])) by (client) > 10

# High query rate to a single external domain
# (requires custom metric from DNS log analysis)
topk(10, sum(rate(dns_queries_by_domain_total[5m])) by (domain))

# NXDOMAIN spike (DGA indicator)
sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[1m]))
  > 3 * avg_over_time(sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[1m]))[1h:1m])
```

#### Domain Generation Algorithm (DGA) Detection

```yaml
# Characteristics of DGA domains:
# - Random-looking labels: xk4r9p2m.biz, h7y3q9w.net
# - High entropy (Shannon entropy > 3.5)
# - Uncommon TLDs (.biz, .info, .xyz, .top)
# - Short TTL responses
# - Many NXDOMAIN responses (most generated domains aren't registered)

# OTel Collector processor for DGA detection
processors:
  transform:
    log_statements:
      - context: log
        statements:
          # Flag high NXDOMAIN rates
          - set(attributes["dns.threat.indicator"], "high_nxdomain")
            where attributes["dns.rcode"] == "NXDOMAIN" and
                  IsMatch(attributes["dns.question.name"], "^[a-z0-9]{8,}\\.(biz|info|xyz|top|tk|ml)$")
```

#### Fast-Flux Detection

```yaml
# Fast-flux: domains that rapidly change IP addresses
# Indicators:
# - Very low TTL (< 300 seconds, often 60s or less)
# - Many different IP addresses for same domain over time
# - IP addresses in different /24 networks (dispersed hosting)
# - IPs often in residential/compromised IP ranges

# Detection: track unique IPs per domain over time
# If domain resolves to >10 unique IPs in 1 hour with TTL < 300, flag it
```

### 3.6 DoH (DNS over HTTPS) and DoT (DNS over TLS) Monitoring

```yaml
# Challenge: Encrypted DNS makes traditional DNS monitoring blind
# DoH (port 443) is indistinguishable from HTTPS traffic
# DoT (port 853) is identifiable by port but content is encrypted

# Monitoring strategies:
# 1. Deploy internal DoH/DoT resolvers and monitor there
# 2. Block external DoH/DoT and force internal resolvers
# 3. Use endpoint agents for DNS visibility
# 4. Monitor DoH/DoT server metrics

# CoreDNS with DoT and DoH support
tls://.:853 {
    tls /etc/coredns/certs/tls.crt /etc/coredns/certs/tls.key
    kubernetes cluster.local in-addr.arpa ip6.arpa
    forward . tls://8.8.8.8 tls://8.8.4.4 {
        tls_servername dns.google
        health_check 5s
    }
    prometheus :9153
    cache 30
    log
}

https://.:443 {
    tls /etc/coredns/certs/tls.crt /etc/coredns/certs/tls.key
    kubernetes cluster.local in-addr.arpa ip6.arpa
    forward . tls://8.8.8.8 tls://8.8.4.4 {
        tls_servername dns.google
    }
    prometheus :9153
    cache 30
    log
}

# Monitoring DoT/DoH usage in the network
# PromQL: detect traffic to known DoH providers
# Requires flow data or firewall logs

# Known DoH endpoints to monitor/block:
# - dns.google (8.8.8.8, 8.8.4.4)
# - cloudflare-dns.com (1.1.1.1, 1.0.0.1)
# - dns.quad9.net (9.9.9.9)
# - doh.opendns.com (208.67.222.222)
# - dns.nextdns.io
```

### 3.7 External DNS Monitoring (Cloud Providers)

#### AWS Route 53

```yaml
# Route 53 metrics via CloudWatch
# Available in awscloudwatch receiver

# Key Route 53 metrics:
# - DNSQueries: Number of DNS queries for a hosted zone
# - HealthCheckStatus: 1 (healthy) or 0 (unhealthy)
# - HealthCheckPercentageHealthy: % of health checkers reporting healthy
# - ChildHealthCheckHealthyCount: For calculated health checks
# - ConnectionTime: Time to establish TCP connection (health check)
# - SSLHandshakeTime: Time to complete TLS handshake (health check)
# - TimeToFirstByte: Time from connection to first response byte

# OTel Collector - Route 53 health check monitoring
receivers:
  awscloudwatch:
    region: us-east-1
    metrics:
      named:
        - namespace: AWS/Route53
          metric_name: HealthCheckStatus
          period: 60s
          statistics: [Minimum]
          dimensions:
            - name: HealthCheckId
              value: "*"
        - namespace: AWS/Route53
          metric_name: HealthCheckPercentageHealthy
          period: 60s
          statistics: [Average]
          dimensions:
            - name: HealthCheckId
              value: "*"
        - namespace: AWS/Route53
          metric_name: ConnectionTime
          period: 60s
          statistics: [Average, p99]
          dimensions:
            - name: HealthCheckId
              value: "*"
```

#### Azure DNS

```yaml
# Azure DNS metrics via Azure Monitor
# Key metrics:
# - QueryVolume: Number of queries served
# - RecordSetCount: Number of record sets in zone
# - RecordSetCapacityUtilization: % of record set limit used

# Azure Private DNS:
# - VirtualNetworkLinkCount
# - VirtualNetworkWithRegistrationLinkCount
# - QueryVolume (per virtual network link)
```

#### GCP Cloud DNS

```yaml
# GCP Cloud DNS metrics via Cloud Monitoring
# Key metrics:
# - dns.googleapis.com/query/count: DNS queries by response code
# - dns.googleapis.com/query/latencies: Query response latency distribution

# Cloud DNS logging
# Provides structured logs for every DNS query:
# {
#   "queryName": "api.example.com.",
#   "queryType": "A",
#   "responseCode": "NOERROR",
#   "protocol": "UDP",
#   "sourceIP": "10.128.0.5",
#   "vmInstanceId": "1234567890",
#   "vmInstanceName": "web-server-01"
# }
```

### 3.8 DNS Observability Dashboard Panels

```yaml
# Grafana dashboard panels for DNS observability
panels:
  - title: "DNS Query Rate by Type"
    type: timeseries
    query: 'sum(rate(coredns_dns_requests_total[5m])) by (type)'

  - title: "DNS Response Latency (P50/P95/P99)"
    type: timeseries
    queries:
      - 'histogram_quantile(0.50, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le))'
      - 'histogram_quantile(0.95, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le))'
      - 'histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le))'

  - title: "DNS Response Codes"
    type: piechart
    query: 'sum(rate(coredns_dns_responses_total[5m])) by (rcode)'

  - title: "Cache Hit Ratio"
    type: gauge
    query: |
      sum(rate(coredns_cache_hits_total[5m]))
      / (sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))
    thresholds: [0.5, 0.7, 0.9]  # red, yellow, green

  - title: "Forward Request Latency by Upstream"
    type: timeseries
    query: |
      histogram_quantile(0.99,
        sum(rate(coredns_forward_request_duration_seconds_bucket[5m])) by (le, to))

  - title: "NXDOMAIN Rate (DGA Indicator)"
    type: stat
    query: |
      sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[5m]))
      / sum(rate(coredns_dns_responses_total[5m])) * 100
    unit: percent
    thresholds: [5, 15, 30]

  - title: "CoreDNS Pod Resource Usage"
    type: timeseries
    queries:
      - 'sum(rate(container_cpu_usage_seconds_total{container="coredns"}[5m])) by (pod)'
      - 'sum(container_memory_working_set_bytes{container="coredns"}) by (pod)'
```

---

## 4. Load Balancer and Proxy Observability

### 4.1 L4 vs L7 Load Balancing Observability

Understanding the observability differences between L4 (transport) and L7 (application) load balancers is critical for choosing the right metrics and debugging approach:

```
┌──────────────────────────────────────────────────────────────────┐
│              L4 vs L7 LOAD BALANCER OBSERVABILITY                │
│                                                                  │
│  ┌──────────────────────────┐  ┌──────────────────────────┐     │
│  │    L4 (Transport)         │  │    L7 (Application)       │    │
│  │                           │  │                           │    │
│  │  Sees:                    │  │  Sees:                    │    │
│  │  ✓ IP addresses           │  │  ✓ Everything L4 sees     │    │
│  │  ✓ Port numbers           │  │  ✓ HTTP methods/paths     │    │
│  │  ✓ TCP/UDP protocol       │  │  ✓ HTTP status codes      │    │
│  │  ✓ Connection count       │  │  ✓ Headers (Host, UA)     │    │
│  │  ✓ Bytes transferred      │  │  ✓ Request/response body  │    │
│  │  ✓ Connection duration    │  │  ✓ Cookies/sessions       │    │
│  │                           │  │  ✓ gRPC methods/codes     │    │
│  │  Cannot see:              │  │  ✓ WebSocket frames       │    │
│  │  ✗ HTTP status codes      │  │  ✓ TLS certificate info   │    │
│  │  ✗ URL paths              │  │                           │    │
│  │  ✗ Request methods        │  │  Trade-offs:              │    │
│  │  ✗ Response times (L7)    │  │  - Higher latency (parse) │    │
│  │  ✗ Content type           │  │  - More resource usage    │    │
│  │                           │  │  - TLS termination req'd  │    │
│  │  Examples:                │  │                           │    │
│  │  - AWS NLB                │  │  Examples:                │    │
│  │  - Azure LB               │  │  - AWS ALB                │    │
│  │  - GCP Network LB         │  │  - Azure App Gateway      │    │
│  │  - HAProxy TCP mode       │  │  - GCP HTTP(S) LB         │    │
│  │  - IPVS/LVS              │  │  - HAProxy HTTP mode       │    │
│  │  - MetalLB               │  │  - NGINX/Envoy/Traefik    │    │
│  └──────────────────────────┘  └──────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 HAProxy Observability

HAProxy exposes extensive metrics through its stats socket and Prometheus endpoint:

#### HAProxy Key Metrics

```yaml
# HAProxy metrics categories and key indicators

# Frontend metrics (client-facing)
frontend_metrics:
  - haproxy_frontend_current_sessions        # Active connections
  - haproxy_frontend_max_sessions            # Peak concurrent connections
  - haproxy_frontend_limit_sessions          # Configured session limit
  - haproxy_frontend_sessions_total          # Cumulative sessions
  - haproxy_frontend_bytes_in_total          # Total bytes received
  - haproxy_frontend_bytes_out_total         # Total bytes sent
  - haproxy_frontend_request_errors_total    # Request parse errors
  - haproxy_frontend_denied_connections_total # Connections denied by ACL
  - haproxy_frontend_http_requests_total     # Total HTTP requests
  - haproxy_frontend_http_responses_total    # Responses by status code class
  - haproxy_frontend_connections_rate_max    # Peak connection rate

# Backend metrics (server pool)
backend_metrics:
  - haproxy_backend_current_sessions         # Active backend connections
  - haproxy_backend_connection_errors_total  # Failed backend connections
  - haproxy_backend_response_errors_total    # Backend response errors
  - haproxy_backend_http_responses_total     # Backend responses by code
  - haproxy_backend_queue_current            # Requests waiting in queue
  - haproxy_backend_queue_time_average_seconds  # Avg time in queue
  - haproxy_backend_connect_time_average_seconds # Avg TCP connect time
  - haproxy_backend_response_time_average_seconds # Avg response time
  - haproxy_backend_active_servers           # Healthy servers
  - haproxy_backend_backup_servers           # Backup servers
  - haproxy_backend_redispatch_warnings_total # Redispatched requests
  - haproxy_backend_retry_warnings_total     # Retried requests

# Server metrics (individual backend server)
server_metrics:
  - haproxy_server_current_sessions          # Active sessions to server
  - haproxy_server_max_sessions              # Peak sessions
  - haproxy_server_weight                    # Server weight
  - haproxy_server_status                    # UP/DOWN/MAINT/DRAIN
  - haproxy_server_check_failures_total      # Health check failures
  - haproxy_server_check_duration_seconds    # Health check latency
  - haproxy_server_downtime_seconds_total    # Cumulative downtime
  - haproxy_server_connection_errors_total   # Connection failures
  - haproxy_server_response_time_average_seconds # Server response time
  - haproxy_server_idle_connections_current  # Idle keepalive connections
```

#### HAProxy Prometheus Configuration

```
# haproxy.cfg - Enable Prometheus endpoint
frontend stats
    bind *:8404
    http-request use-service prometheus-exporter if { path /metrics }
    stats enable
    stats uri /stats
    stats refresh 10s

frontend http-in
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    default_backend webservers

    # Capture custom headers for observability
    http-request capture req.hdr(X-Request-ID) len 36
    http-request capture req.hdr(X-Forwarded-For) len 50

    # Log format with timing information
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
    # TR = request time, Tw = queue wait, Tc = connect time,
    # Tr = response time, Ta = total active time

backend webservers
    balance roundrobin
    option httpchk GET /health HTTP/1.1\r\nHost:\ localhost
    http-check expect status 200

    server web01 10.0.1.10:8080 check inter 3s fall 3 rise 2 weight 100
    server web02 10.0.1.11:8080 check inter 3s fall 3 rise 2 weight 100
    server web03 10.0.1.12:8080 check inter 3s fall 3 rise 2 weight 50 backup
```

#### HAProxy PromQL Queries

```promql
# --- HAProxy Performance ---

# Request rate by frontend
sum(rate(haproxy_frontend_http_requests_total[5m])) by (proxy)

# Error rate by backend (4xx + 5xx)
(
  sum(rate(haproxy_backend_http_responses_total{code="4xx"}[5m])) by (proxy)
  +
  sum(rate(haproxy_backend_http_responses_total{code="5xx"}[5m])) by (proxy)
) / sum(rate(haproxy_backend_http_responses_total[5m])) by (proxy)

# Backend response time
haproxy_backend_response_time_average_seconds

# Connection queue depth (backends overloaded)
haproxy_backend_queue_current > 0

# Session utilization (approaching limits)
haproxy_frontend_current_sessions / haproxy_frontend_limit_sessions > 0.8

# Backend server health
haproxy_server_status{state="UP"} == 0  # Server is DOWN

# Server connection errors rate
sum(rate(haproxy_server_connection_errors_total[5m])) by (proxy, server)

# Retry and redispatch rate (backend instability)
sum(rate(haproxy_backend_retry_warnings_total[5m])) by (proxy)
sum(rate(haproxy_backend_redispatch_warnings_total[5m])) by (proxy)

# Session exhaustion alert
haproxy_frontend_current_sessions / haproxy_frontend_limit_sessions > 0.9

# Backend health: active vs total servers
haproxy_backend_active_servers / (haproxy_backend_active_servers + haproxy_backend_backup_servers)
```

### 4.3 NGINX Observability

#### NGINX Open Source (stub_status)

```nginx
# NGINX open source provides limited metrics via stub_status
server {
    listen 8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }

    # Custom log format with timing
    log_format observability '$remote_addr - $remote_user [$time_local] '
        '"$request" $status $body_bytes_sent '
        '"$http_referer" "$http_user_agent" '
        'rt=$request_time uct=$upstream_connect_time '
        'uht=$upstream_header_time urt=$upstream_response_time '
        'cs=$upstream_cache_status us=$upstream_status '
        'rid=$request_id';

    access_log /var/log/nginx/access.log observability;
}

# stub_status output:
# Active connections: 291
# server accepts handled requests
#  7368 7368 10993
# Reading: 6 Writing: 179 Waiting: 106
```

#### NGINX Prometheus Exporter Metrics

```yaml
# Key metrics from nginx-prometheus-exporter
nginx_metrics:
  - nginx_connections_active      # Current active connections
  - nginx_connections_accepted    # Total accepted connections
  - nginx_connections_handled     # Total handled connections (should = accepted)
  - nginx_connections_reading     # Connections reading request header
  - nginx_connections_writing     # Connections writing response
  - nginx_connections_waiting     # Keep-alive connections (idle)
  - nginx_http_requests_total     # Total requests processed
  - nginx_up                      # Is NGINX responding (1/0)
```

#### NGINX Plus API (Commercial)

```yaml
# NGINX Plus provides much richer metrics via its API
# Endpoint: http://nginx-plus:8080/api/9/

# Server zones (virtual servers)
nginx_plus_metrics:
  - nginxplus_server_zone_requests           # Requests by server zone
  - nginxplus_server_zone_responses          # Responses by code class (1xx-5xx)
  - nginxplus_server_zone_discarded          # Discarded requests
  - nginxplus_server_zone_received_bytes     # Bytes received
  - nginxplus_server_zone_sent_bytes         # Bytes sent
  - nginxplus_server_zone_processing         # Currently processing

  # Upstream metrics (backend pools)
  - nginxplus_upstream_server_active         # Active connections
  - nginxplus_upstream_server_requests       # Requests sent to upstream
  - nginxplus_upstream_server_responses      # Responses by code
  - nginxplus_upstream_server_health_checks_fails  # Health check failures
  - nginxplus_upstream_server_health_checks_unhealthy  # Unhealthy count
  - nginxplus_upstream_server_state          # up/down/draining/unavail
  - nginxplus_upstream_server_response_time  # Response time (ms)
  - nginxplus_upstream_server_connect_time   # Connect time (ms)
  - nginxplus_upstream_server_header_time    # Time to first header byte

  # Stream (TCP/UDP) metrics
  - nginxplus_stream_server_zone_connections # TCP/UDP connections
  - nginxplus_stream_server_zone_sessions    # Sessions by status (2xx/4xx/5xx)

  # Cache metrics
  - nginxplus_cache_size                     # Current cache size
  - nginxplus_cache_max_size                 # Configured max cache
  - nginxplus_cache_hit_responses            # Cache hits
  - nginxplus_cache_miss_responses           # Cache misses
  - nginxplus_cache_bypass_responses         # Cache bypasses

  # SSL metrics
  - nginxplus_ssl_handshakes                 # Successful TLS handshakes
  - nginxplus_ssl_handshakes_failed          # Failed TLS handshakes
  - nginxplus_ssl_session_reuses             # TLS session resumptions

  # Resolver (DNS) metrics
  - nginxplus_resolver_queries               # DNS queries by type
  - nginxplus_resolver_responses             # DNS responses by type
```

#### NGINX PromQL Queries

```promql
# --- NGINX Performance ---

# Request rate
rate(nginx_http_requests_total[5m])

# Connection utilization (active / worker_connections)
nginx_connections_active / nginx_connections_accepted * 100

# Request processing rate vs capacity
nginx_connections_writing / nginx_connections_active

# Dropped connections (accepted - handled should be 0)
nginx_connections_accepted - nginx_connections_handled

# NGINX Plus: Error rate by server zone
sum(rate(nginxplus_server_zone_responses{code="5xx"}[5m])) by (server_zone)
  /
sum(rate(nginxplus_server_zone_requests[5m])) by (server_zone)

# NGINX Plus: Upstream response time
nginxplus_upstream_server_response_time{state="up"}

# NGINX Plus: Cache hit ratio
sum(rate(nginxplus_cache_hit_responses[5m])) by (cache_zone)
  /
(
  sum(rate(nginxplus_cache_hit_responses[5m])) by (cache_zone) +
  sum(rate(nginxplus_cache_miss_responses[5m])) by (cache_zone) +
  sum(rate(nginxplus_cache_bypass_responses[5m])) by (cache_zone)
)

# NGINX Plus: TLS handshake failure rate
rate(nginxplus_ssl_handshakes_failed[5m])
  /
(rate(nginxplus_ssl_handshakes[5m]) + rate(nginxplus_ssl_handshakes_failed[5m]))
```

### 4.4 Envoy Proxy Observability

Envoy is the most observable proxy in the ecosystem, exposing thousands of metrics organized by subsystem:

#### Envoy Statistics Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                 ENVOY STATISTICS HIERARCHY                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ DOWNSTREAM (Client → Envoy)                                │  │
│  │  http.ingress.downstream_cx_total                          │  │
│  │  http.ingress.downstream_cx_active                         │  │
│  │  http.ingress.downstream_cx_ssl_total                      │  │
│  │  http.ingress.downstream_rq_total                          │  │
│  │  http.ingress.downstream_rq_active                         │  │
│  │  http.ingress.downstream_rq_xx (1xx/2xx/3xx/4xx/5xx)      │  │
│  │  http.ingress.downstream_rq_time (histogram)               │  │
│  │  http.ingress.downstream_cx_rx_bytes_total                 │  │
│  │  http.ingress.downstream_cx_tx_bytes_total                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ UPSTREAM (Envoy → Backend)                                 │  │
│  │  cluster.{name}.upstream_cx_total                          │  │
│  │  cluster.{name}.upstream_cx_active                         │  │
│  │  cluster.{name}.upstream_cx_connect_fail                   │  │
│  │  cluster.{name}.upstream_cx_connect_timeout                │  │
│  │  cluster.{name}.upstream_rq_total                          │  │
│  │  cluster.{name}.upstream_rq_timeout                        │  │
│  │  cluster.{name}.upstream_rq_retry                          │  │
│  │  cluster.{name}.upstream_rq_retry_success                  │  │
│  │  cluster.{name}.upstream_rq_rx_reset                       │  │
│  │  cluster.{name}.upstream_rq_pending_active                 │  │
│  │  cluster.{name}.upstream_rq_time (histogram)               │  │
│  └────────────────────────────────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ CIRCUIT BREAKER                                            │  │
│  │  cluster.{name}.circuit_breakers.default.cx_open           │  │
│  │  cluster.{name}.circuit_breakers.default.cx_pool_open      │  │
│  │  cluster.{name}.circuit_breakers.default.rq_pending_open   │  │
│  │  cluster.{name}.circuit_breakers.default.rq_retry_open     │  │
│  │  cluster.{name}.circuit_breakers.high.cx_open              │  │
│  │  cluster.{name}.upstream_cx_overflow                       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ OUTLIER DETECTION (Ejection)                               │  │
│  │  cluster.{name}.outlier_detection.ejections_active         │  │
│  │  cluster.{name}.outlier_detection.ejections_total          │  │
│  │  cluster.{name}.outlier_detection.ejections_consecutive_5xx│  │
│  │  cluster.{name}.outlier_detection.ejections_enforced_total │  │
│  │  cluster.{name}.outlier_detection.ejections_detected_total │  │
│  │  cluster.{name}.outlier_detection.ejections_overflow       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ RETRY                                                      │  │
│  │  cluster.{name}.upstream_rq_retry                          │  │
│  │  cluster.{name}.upstream_rq_retry_success                  │  │
│  │  cluster.{name}.upstream_rq_retry_overflow                 │  │
│  │  cluster.{name}.upstream_rq_retry_backoff_exponential      │  │
│  │  cluster.{name}.upstream_rq_retry_backoff_ratelimited      │  │
│  │  cluster.{name}.retry_budget.budget_available              │  │
│  │  cluster.{name}.retry_budget.budget_consumed               │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ ADDITIONAL SUBSYSTEMS                                      │  │
│  │                                                            │  │
│  │  Health Check:                                             │  │
│  │    cluster.{name}.health_check.attempt                     │  │
│  │    cluster.{name}.health_check.success                     │  │
│  │    cluster.{name}.health_check.failure                     │  │
│  │    cluster.{name}.health_check.degraded                    │  │
│  │                                                            │  │
│  │  Rate Limiting:                                            │  │
│  │    cluster.{name}.ratelimit.ok/error/over_limit/failure    │  │
│  │                                                            │  │
│  │  DNS Resolution:                                           │  │
│  │    cluster.{name}.update_success/failure/empty             │  │
│  │    cluster.{name}.assignment_stale                         │  │
│  │                                                            │  │
│  │  TLS:                                                      │  │
│  │    listener.{name}.ssl.connection_error                    │  │
│  │    listener.{name}.ssl.handshake                           │  │
│  │    listener.{name}.ssl.no_certificate                      │  │
│  │    listener.{name}.ssl.fail_verify_cert_hash               │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

#### Envoy PromQL Queries

```promql
# --- Envoy Downstream (Client-facing) ---

# Request rate by response code
sum(rate(envoy_http_downstream_rq_xx{envoy_response_code_class=~"[2345]xx"}[5m])) by (envoy_response_code_class)

# P99 request latency
histogram_quantile(0.99,
  sum(rate(envoy_http_downstream_rq_time_bucket[5m])) by (le, envoy_cluster_name)
)

# Error rate (5xx / total)
sum(rate(envoy_http_downstream_rq_xx{envoy_response_code_class="5xx"}[5m]))
  /
sum(rate(envoy_http_downstream_rq_total[5m]))

# Active connections
envoy_http_downstream_cx_active

# --- Envoy Upstream (Backend) ---

# Upstream connection failures
sum(rate(envoy_cluster_upstream_cx_connect_fail[5m])) by (envoy_cluster_name)

# Upstream request timeout rate
sum(rate(envoy_cluster_upstream_rq_timeout[5m])) by (envoy_cluster_name)

# Upstream P99 latency
histogram_quantile(0.99,
  sum(rate(envoy_cluster_upstream_rq_time_bucket[5m])) by (le, envoy_cluster_name)
)

# Pending requests (queue pressure)
envoy_cluster_upstream_rq_pending_active

# --- Circuit Breaker ---

# Circuit breaker tripped (connection pool)
envoy_cluster_circuit_breakers_default_cx_open > 0

# Circuit breaker tripped (pending requests)
envoy_cluster_circuit_breakers_default_rq_pending_open > 0

# Connection pool overflow (circuit breaker rejections)
rate(envoy_cluster_upstream_cx_overflow[5m]) > 0

# --- Outlier Detection ---

# Active ejections (hosts removed from load balancing)
envoy_cluster_outlier_detection_ejections_active > 0

# Ejection rate
rate(envoy_cluster_outlier_detection_ejections_total[5m]) > 0

# --- Retry ---

# Retry rate (indicates backend instability)
sum(rate(envoy_cluster_upstream_rq_retry[5m])) by (envoy_cluster_name)
  /
sum(rate(envoy_cluster_upstream_rq_total[5m])) by (envoy_cluster_name)

# Retry success rate (are retries helping?)
sum(rate(envoy_cluster_upstream_rq_retry_success[5m])) by (envoy_cluster_name)
  /
sum(rate(envoy_cluster_upstream_rq_retry[5m])) by (envoy_cluster_name)

# Retry budget exhaustion
envoy_cluster_retry_budget_budget_available == 0
```

### 4.5 Cloud Load Balancer Observability

#### AWS Application Load Balancer (ALB)

```yaml
# Key ALB metrics from CloudWatch
alb_metrics:
  - RequestCount                    # Total requests
  - ActiveConnectionCount           # Concurrent TCP connections
  - NewConnectionCount              # New connections/period
  - TargetResponseTime              # Backend response time (seconds)
  - HTTPCode_Target_2XX_Count       # Successful backend responses
  - HTTPCode_Target_4XX_Count       # Client errors from backend
  - HTTPCode_Target_5XX_Count       # Server errors from backend
  - HTTPCode_ELB_5XX_Count          # Errors generated BY the ALB itself
  - HTTPCode_ELB_502_Count          # Bad Gateway (backend unreachable)
  - HTTPCode_ELB_503_Count          # Service Unavailable (no healthy targets)
  - HTTPCode_ELB_504_Count          # Gateway Timeout
  - HealthyHostCount                # Healthy targets
  - UnHealthyHostCount              # Unhealthy targets
  - RejectedConnectionCount        # Connections rejected (max limit)
  - TargetConnectionErrorCount     # Failed connections to targets
  - TargetTLSNegotiationErrorCount # TLS errors with targets
  - ConsumedLCUs                    # Load Balancer Capacity Units (cost)
  - ProcessedBytes                  # Total bytes processed
  - RuleEvaluations                 # Listener rule evaluations
  - IPv6ProcessedBytes              # IPv6 traffic
  - ClientTLSNegotiationErrorCount # Client TLS handshake failures

# OTel Collector for ALB metrics
receivers:
  awscloudwatch/alb:
    region: us-east-1
    metrics:
      named:
        - namespace: AWS/ApplicationELB
          metric_name: TargetResponseTime
          period: 60s
          statistics: [Average, p99]
          dimensions:
            - name: LoadBalancer
              value: "app/my-alb/1234567890"
        - namespace: AWS/ApplicationELB
          metric_name: HTTPCode_ELB_5XX_Count
          period: 60s
          statistics: [Sum]
```

#### AWS Network Load Balancer (NLB)

```yaml
# Key NLB metrics (L4 only - no HTTP status codes)
nlb_metrics:
  - ActiveFlowCount                 # Current TCP/UDP flows
  - NewFlowCount                    # New flows/period
  - ProcessedBytes                  # Total bytes
  - ProcessedPackets                # Total packets
  - TCP_Client_Reset_Count          # Resets from client
  - TCP_Target_Reset_Count          # Resets from target
  - TCP_ELB_Reset_Count             # Resets from NLB
  - HealthyHostCount                # Healthy targets
  - UnHealthyHostCount              # Unhealthy targets
  - ConsumedLCUs                    # LCU consumption (cost)
  - TargetTLSNegotiationErrorCount # TLS errors
  - PortAllocationErrorCount       # NAT port exhaustion (critical!)
```

#### Azure Application Gateway and Front Door

```yaml
# Azure Application Gateway metrics
app_gateway_metrics:
  - TotalRequests                   # Total requests by backend
  - FailedRequests                  # 4xx + 5xx responses
  - ResponseStatus                  # Responses by HTTP status code
  - HealthyHostCount                # Healthy backends per pool
  - UnhealthyHostCount              # Unhealthy backends
  - BackendResponseLatency          # Time from request to backend to response
  - BackendConnectTime              # Time to establish backend TCP connection
  - BackendFirstByteResponseTime    # TTFB from backend
  - BackendLastByteResponseTime     # Time to receive full response
  - CurrentConnections              # Active connections
  - Throughput                      # Bytes per second
  - CapacityUnits                   # Consumed capacity units (cost)
  - ComputeUnits                    # Compute consumption
  - ClientRtt                       # Client round-trip time (v2 only)
  - TlsProtocol                     # TLS version distribution

# Azure Front Door metrics
front_door_metrics:
  - RequestCount                    # Total requests
  - RequestSize                     # Request bytes
  - ResponseSize                    # Response bytes
  - TotalLatency                    # End-to-end latency (client → backend → client)
  - BackendRequestLatency           # Backend-only latency
  - BackendHealthPercentage         # % of healthy backends
  - WebApplicationFirewallRequestCount  # WAF processed requests
  - BackendRequestCount             # Requests sent to backends
  - BillableResponseSize            # Billable bytes
```

#### GCP Load Balancer Metrics

```yaml
# GCP HTTP(S) Load Balancer metrics
gcp_lb_metrics:
  - loadbalancing.googleapis.com/https/request_count                # Requests
  - loadbalancing.googleapis.com/https/total_latencies              # End-to-end latency
  - loadbalancing.googleapis.com/https/backend_latencies            # Backend latency
  - loadbalancing.googleapis.com/https/request_bytes_count          # Request size
  - loadbalancing.googleapis.com/https/response_bytes_count         # Response size
  - loadbalancing.googleapis.com/https/backend_request_count        # Backend requests
  - loadbalancing.googleapis.com/https/backend_request_bytes_count  # Backend request bytes
  - loadbalancing.googleapis.com/https/internal/backend_connection_error_count
  - loadbalancing.googleapis.com/https/internal/backend_timeout_count

# Labels available for filtering:
# - response_code, response_code_class
# - backend_target_name, backend_scope
# - client_country, client_region
# - cache_result (HIT, MISS, DISABLED)
# - protocol (HTTP/1.1, HTTP/2, HTTP/3)
# - proxy_continent
```

### 4.6 Traefik Observability

```yaml
# Traefik exposes Prometheus metrics natively
# Configuration (traefik.yml)
metrics:
  prometheus:
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    buckets:
      - 0.01
      - 0.025
      - 0.05
      - 0.1
      - 0.25
      - 0.5
      - 1.0
      - 2.5
      - 5.0
      - 10.0
    headerLabels:
      X-Custom-Header: ""

tracing:
  otlp:
    grpc:
      endpoint: "otel-collector:4317"
      insecure: true

accessLog:
  format: json
  fields:
    headers:
      names:
        X-Request-ID: keep
        X-Forwarded-For: keep
    defaultMode: keep

# Key Traefik metrics
traefik_metrics:
  - traefik_entrypoint_requests_total           # Requests by entrypoint
  - traefik_entrypoint_request_duration_seconds  # Latency histogram
  - traefik_entrypoint_requests_bytes_total      # Request size
  - traefik_entrypoint_responses_bytes_total     # Response size
  - traefik_entrypoint_open_connections          # Active connections
  - traefik_router_requests_total                # Requests by router
  - traefik_router_request_duration_seconds      # Router latency
  - traefik_service_requests_total               # Requests by service
  - traefik_service_request_duration_seconds     # Service latency
  - traefik_service_open_connections             # Backend connections
  - traefik_service_server_up                    # Backend server health (1/0)
  - traefik_tls_certs_not_after                  # Certificate expiry epoch
  - traefik_config_reloads_total                 # Config reload count
  - traefik_config_reloads_failure_total         # Failed reloads
```

#### Traefik PromQL Queries

```promql
# Request rate by entrypoint
sum(rate(traefik_entrypoint_requests_total[5m])) by (entrypoint, code)

# P99 latency by service
histogram_quantile(0.99,
  sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service)
)

# Error rate by router
sum(rate(traefik_router_requests_total{code=~"5.."}[5m])) by (router)
  /
sum(rate(traefik_router_requests_total[5m])) by (router)

# Certificate expiry (days remaining)
(traefik_tls_certs_not_after - time()) / 86400

# Backend health
traefik_service_server_up == 0
```

### 4.7 Health Check Patterns

```yaml
# Health check observability patterns across LB/proxy types

# Pattern 1: Simple HTTP health check
health_check:
  type: http
  path: /health
  interval: 5s
  timeout: 3s
  healthy_threshold: 2     # 2 consecutive successes = healthy
  unhealthy_threshold: 3   # 3 consecutive failures = unhealthy
  expected_status: 200
  expected_body: '"status":"ok"'

# Pattern 2: gRPC health check (standard protocol)
health_check:
  type: grpc
  service: "grpc.health.v1.Health"
  interval: 10s
  timeout: 5s

# Pattern 3: TCP health check (L4 only)
health_check:
  type: tcp
  interval: 10s
  timeout: 5s
  # Only checks TCP connection establishment

# Pattern 4: Composite health check (deep)
health_check:
  type: http
  path: /health/deep
  interval: 30s       # Less frequent due to cost
  timeout: 10s        # Longer timeout for DB checks
  # Checks: DB connectivity, cache connectivity,
  # downstream service health, disk space, etc.

# Health Check Metrics to Monitor:
health_check_metrics:
  - check_duration_seconds    # How long health checks take
  - check_failures_total      # Cumulative failures
  - check_transitions_total   # State transitions (UP→DOWN, DOWN→UP)
  - backend_active_count      # Currently healthy backends
  - backend_total_count       # Total configured backends
  - last_check_timestamp      # Freshness of health data

# Alert: Health check flapping (toggling UP/DOWN frequently)
# rate(health_check_transitions_total[1h]) > 5
```

### 4.8 Load Balancer Alerting Rules

```yaml
# PrometheusRule for load balancer/proxy alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: lb-proxy-alerts
  namespace: monitoring
spec:
  groups:
    - name: load-balancer-health
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: |
            (
              sum(rate(haproxy_backend_http_responses_total{code="5xx"}[5m])) by (proxy)
              / sum(rate(haproxy_backend_http_responses_total[5m])) by (proxy)
            ) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Backend {{ $labels.proxy }} has >5% error rate"
            description: "Error rate: {{ $value | humanizePercentage }}"

        - alert: HighLatency
          expr: |
            histogram_quantile(0.99,
              sum(rate(envoy_http_downstream_rq_time_bucket[5m])) by (le, envoy_cluster_name)
            ) > 1.0
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "P99 latency >1s for {{ $labels.envoy_cluster_name }}"

        - alert: BackendDown
          expr: haproxy_server_status{state!="UP"} == 1
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Backend server {{ $labels.server }} in {{ $labels.proxy }} is DOWN"

        - alert: NoHealthyBackends
          expr: haproxy_backend_active_servers == 0
          for: 0m
          labels:
            severity: critical
          annotations:
            summary: "No healthy backends for {{ $labels.proxy }}"

        - alert: CircuitBreakerTripped
          expr: envoy_cluster_circuit_breakers_default_cx_open > 0
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Circuit breaker open for {{ $labels.envoy_cluster_name }}"

        - alert: SessionLimitApproaching
          expr: |
            haproxy_frontend_current_sessions
            / haproxy_frontend_limit_sessions > 0.85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Session limit 85%+ for {{ $labels.proxy }}"

        - alert: CertificateExpiringSoon
          expr: (traefik_tls_certs_not_after - time()) / 86400 < 14
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "TLS cert expires in {{ $value | humanize }} days"

---

## 5. TCP/UDP Transport Layer Observability

### 5.1 TCP State Machine Monitoring

Understanding TCP connection states is essential for diagnosing network issues. Each state reveals specific information about connection health:

```
┌──────────────────────────────────────────────────────────────────┐
│               TCP STATE MACHINE (Simplified)                      │
│                                                                  │
│   Client                                         Server          │
│                                                                  │
│   ┌────────┐  SYN        ┌───────────┐                          │
│   │ CLOSED │────────────►│ SYN_SENT  │                          │
│   └────────┘             └─────┬─────┘                          │
│                                │ SYN+ACK                        │
│                                ▼                                │
│   ┌────────────┐         ┌───────────────┐                      │
│   │ESTABLISHED │◄────────│ ESTABLISHED   │                      │
│   └─────┬──────┘  ACK    └───────────────┘                      │
│         │                                                        │
│   Data transfer (bidirectional)                                  │
│         │                                                        │
│   ┌─────▼──────┐  FIN    ┌───────────┐                          │
│   │  FIN_WAIT_1│────────►│ CLOSE_WAIT│  ◄── Server has data    │
│   └─────┬──────┘         └─────┬─────┘      from client but    │
│         │ ACK                  │            hasn't closed yet    │
│         ▼                      │ FIN                             │
│   ┌───────────┐          ┌─────▼─────┐                          │
│   │ FIN_WAIT_2│          │ LAST_ACK  │                          │
│   └─────┬─────┘          └───────────┘                          │
│         │ FIN                  │ ACK                             │
│         ▼                      ▼                                │
│   ┌───────────┐          ┌────────┐                              │
│   │ TIME_WAIT │          │ CLOSED │                              │
│   │ (2*MSL=   │          └────────┘                              │
│   │  60-120s) │                                                  │
│   └───────────┘                                                  │
│                                                                  │
│   PROBLEM STATES TO WATCH:                                       │
│   ┌────────────────────────────────────────────────────────┐    │
│   │ TIME_WAIT (>5000)  → Port exhaustion, connection churn │    │
│   │ CLOSE_WAIT (>100)  → Application bug (not closing conn)│    │
│   │ SYN_RECV (>1000)   → SYN flood attack or SYN backlog  │    │
│   │ FIN_WAIT_2 (>100)  → Remote not completing close       │    │
│   └────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

#### TCP State Monitoring with node_exporter

```promql
# --- TCP State Counts ---

# All TCP connections by state
node_netstat_Tcp_CurrEstab                     # ESTABLISHED connections
node_sockstat_TCP_tw                           # TIME_WAIT sockets

# Using node_exporter with --collector.tcpstat
node_tcp_connection_states{state="established"}
node_tcp_connection_states{state="time_wait"}
node_tcp_connection_states{state="close_wait"}
node_tcp_connection_states{state="syn_recv"}
node_tcp_connection_states{state="fin_wait1"}
node_tcp_connection_states{state="fin_wait2"}
node_tcp_connection_states{state="last_ack"}
node_tcp_connection_states{state="listen"}

# Alert: CLOSE_WAIT accumulation (application bug)
node_tcp_connection_states{state="close_wait"} > 100

# Alert: TIME_WAIT exhaustion risk
node_tcp_connection_states{state="time_wait"} > 10000

# Alert: SYN_RECV accumulation (SYN flood or backlog)
node_tcp_connection_states{state="syn_recv"} > 256

# Connection churn rate (new + closed connections per second)
rate(node_netstat_Tcp_ActiveOpens[5m])    # Outgoing connections/sec
rate(node_netstat_Tcp_PassiveOpens[5m])   # Incoming connections/sec

# Total socket count vs ulimit
node_sockstat_sockets_used / node_filefd_maximum * 100
```

#### Diagnosing TCP State Issues

```yaml
# CLOSE_WAIT Diagnosis:
# CLOSE_WAIT means: remote side sent FIN, local app hasn't called close()
# Root causes:
#   1. Application bug: connection object not being closed/disposed
#   2. Connection pool leak: borrowed connections not returned
#   3. Deadlocked thread: app thread blocked, can't close connection
#   4. Missing finally/defer block: close() not called on error path
#
# Investigation:
#   ss -tan state close-wait | awk '{print $4}' | sort | uniq -c | sort -rn
#   # Shows which local ports/services have CLOSE_WAIT accumulation
#
#   lsof -i -n | grep CLOSE_WAIT | awk '{print $1}' | sort | uniq -c | sort -rn
#   # Shows which processes are accumulating CLOSE_WAIT

# TIME_WAIT Diagnosis:
# TIME_WAIT means: connection closed, waiting 2*MSL (60-120s) for stale packets
# Root causes:
#   1. High connection churn (many short-lived connections)
#   2. Not using connection pooling / keep-alive
#   3. Aggressive connection closing (close() instead of graceful shutdown)
#
# Tuning (Linux):
#   net.ipv4.tcp_tw_reuse = 1        # Reuse TIME_WAIT for outgoing
#   net.ipv4.tcp_fin_timeout = 30    # Reduce FIN_WAIT_2 timeout
#   net.ipv4.ip_local_port_range = 1024 65535  # More ephemeral ports
#   net.ipv4.tcp_max_tw_buckets = 65536        # Max TIME_WAIT sockets
```

### 5.2 TCP Retransmission Monitoring

Retransmissions are the most important TCP health metric -- they indicate packet loss, congestion, or path problems:

```promql
# --- TCP Retransmission Metrics ---

# Retransmission rate (% of segments retransmitted)
rate(node_netstat_Tcp_RetransSegs[5m])
  / rate(node_netstat_Tcp_OutSegs[5m]) * 100

# Absolute retransmission rate
rate(node_netstat_Tcp_RetransSegs[5m])

# Retransmission thresholds:
# < 0.1%   = Healthy
# 0.1-1%   = Moderate (investigate)
# 1-5%     = Significant (causes latency)
# > 5%     = Severe (causes timeouts/failures)

# Spurious retransmissions (TCPSpuriousRTOs)
# These indicate the RTO timer is too aggressive
rate(node_netstat_TcpExt_TCPSpuriousRTOs[5m])

# Fast retransmits (triggered by duplicate ACKs, faster recovery)
rate(node_netstat_TcpExt_TCPFastRetrans[5m])

# Slow start retransmits (loss during slow start = severe)
rate(node_netstat_TcpExt_TCPSlowStartRetrans[5m])

# SYN retransmits (connection establishment failures)
rate(node_netstat_TcpExt_TCPSynRetrans[5m])

# Retransmit alert
rate(node_netstat_Tcp_RetransSegs[5m])
  / rate(node_netstat_Tcp_OutSegs[5m]) > 0.01
```

#### Types of Retransmissions

```
┌──────────────────────────────────────────────────────────────────┐
│                 TCP RETRANSMISSION TYPES                          │
│                                                                  │
│  ┌────────────────────────┐  ┌────────────────────────┐         │
│  │ RTO Retransmit          │  │ Fast Retransmit         │        │
│  │                         │  │                         │        │
│  │ Trigger: Timer expires  │  │ Trigger: 3 duplicate   │        │
│  │ (no ACK received)      │  │ ACKs received          │        │
│  │                         │  │                         │        │
│  │ Latency: High (200ms-  │  │ Latency: Lower (RTT-   │        │
│  │ 120s exponential)      │  │ based detection)       │        │
│  │                         │  │                         │        │
│  │ Indicates: Severe loss  │  │ Indicates: Single      │        │
│  │ or black hole          │  │ packet drop             │        │
│  │                         │  │                         │        │
│  │ Metric:                 │  │ Metric:                 │        │
│  │ TCPTimeouts             │  │ TCPFastRetrans          │        │
│  └────────────────────────┘  └────────────────────────┘         │
│                                                                  │
│  ┌────────────────────────┐  ┌────────────────────────┐         │
│  │ Tail Loss Probe (TLP)   │  │ RACK (Recent ACK)       │       │
│  │                         │  │                         │        │
│  │ Trigger: Timer (1-2    │  │ Trigger: Time-based     │        │
│  │ RTTs after last data)  │  │ reordering detection   │        │
│  │                         │  │                         │        │
│  │ Sends probe to elicit  │  │ Modern replacement for  │        │
│  │ ACK, detects tail loss │  │ DUPACK-based detection │        │
│  │                         │  │                         │        │
│  │ Metric:                 │  │ Metric:                 │        │
│  │ TCPLossProbes           │  │ TCPRACKReclaimSACK      │       │
│  └────────────────────────┘  └────────────────────────┘         │
└──────────────────────────────────────────────────────────────────┘
```

### 5.3 TCP Congestion and Window Monitoring

```promql
# --- TCP Congestion Indicators ---

# Receive window zero (receiver overwhelmed)
rate(node_netstat_TcpExt_TCPWantZeroWindowAdv[5m])

# Zero window sent (local receiver full)
rate(node_netstat_TcpExt_TCPToZeroWindowAdv[5m])

# Zero window received from remote (remote receiver full)
rate(node_netstat_TcpExt_TCPFromZeroWindowAdv[5m])

# Abort on memory pressure
rate(node_netstat_TcpExt_TCPAbortOnMemory[5m])

# Connections reset due to unexpected data
rate(node_netstat_TcpExt_TCPAbortOnData[5m])

# Listen queue overflows (connections dropped at SYN)
rate(node_netstat_TcpExt_ListenOverflows[5m])

# Listen drops (SYN dropped because queue full)
rate(node_netstat_TcpExt_ListenDrops[5m])

# SYN cookies sent (SYN queue overflow, using cookies as fallback)
rate(node_netstat_TcpExt_SyncookiesSent[5m])

# ECN (Explicit Congestion Notification) received
rate(node_netstat_TcpExt_TCPECNFallback[5m])
```

### 5.4 Connection Tracking (conntrack) Monitoring

The Linux connection tracking (conntrack) table is critical for NAT, firewalling, and load balancing. Exhaustion causes silent packet drops:

```promql
# --- Conntrack Metrics ---

# Current entries vs maximum
node_nf_conntrack_entries / node_nf_conntrack_entries_limit * 100

# Alert: conntrack table approaching full (>75%)
node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.75

# Rate of new entries (connection creation rate)
rate(node_nf_conntrack_entries[5m])

# Conntrack table drops (CRITICAL - packets silently dropped)
rate(node_nf_conntrack_stat_drop[5m]) > 0

# Early conntrack drops (table full or hash collision)
rate(node_nf_conntrack_stat_early_drop[5m]) > 0

# Conntrack insert failures
rate(node_nf_conntrack_stat_insert_failed[5m]) > 0

# Entries found (cache hit rate)
rate(node_nf_conntrack_stat_found[5m])

# Search restarts (lock contention)
rate(node_nf_conntrack_stat_search_restart[5m])
```

#### Conntrack Tuning for High-Scale Environments

```yaml
# Linux kernel parameters for conntrack
# /etc/sysctl.d/99-conntrack.conf

# Maximum entries (default: 65536, set based on memory)
# Each entry uses ~300 bytes, so 1M entries ≈ 300MB
net.nf_conntrack_max: 1048576

# Hash table size (buckets = max / 4 is a good starting point)
net.netfilter.nf_conntrack_buckets: 262144

# Timeout tuning (reduce for high-churn environments)
net.netfilter.nf_conntrack_tcp_timeout_established: 86400  # Default: 432000 (5 days)
net.netfilter.nf_conntrack_tcp_timeout_time_wait: 30       # Default: 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait: 60      # Default: 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait: 30        # Default: 120
net.netfilter.nf_conntrack_udp_timeout: 30                 # Default: 30
net.netfilter.nf_conntrack_udp_timeout_stream: 120         # Default: 180
net.netfilter.nf_conntrack_icmp_timeout: 10                # Default: 30

# Kubernetes/Calico: conntrack is critical for kube-proxy IPVS/iptables
# Each service connection creates a conntrack entry
# Formula: max_entries = max_pods * avg_connections_per_pod * 2 (bidirectional)
```

### 5.5 Socket Buffer Monitoring

Socket buffer (send/receive) sizes directly impact throughput and memory usage:

```promql
# --- Socket Buffer Metrics ---

# TCP memory usage (pages)
node_netstat_TcpExt_TCPMemoryPressures  # Times TCP entered memory pressure

# Socket memory statistics
node_sockstat_TCP_mem_bytes     # Total TCP socket memory usage
node_sockstat_TCP_alloc         # Allocated TCP sockets
node_sockstat_TCP_inuse         # TCP sockets in use
node_sockstat_TCP_orphan        # Orphaned TCP sockets (no process)
node_sockstat_TCP_tw            # TIME_WAIT sockets
node_sockstat_UDP_inuse         # UDP sockets in use
node_sockstat_UDP_mem_bytes     # UDP socket memory
node_sockstat_sockets_used      # Total sockets used (all protocols)

# Alert: Orphan sockets accumulating (resource leak)
node_sockstat_TCP_orphan > 1000

# Alert: TCP memory pressure
rate(node_netstat_TcpExt_TCPMemoryPressures[5m]) > 0

# Socket buffer size settings
# Check /proc/sys/net/core/rmem_max   (max receive buffer)
# Check /proc/sys/net/core/wmem_max   (max send buffer)
# Check /proc/sys/net/ipv4/tcp_rmem   (min, default, max receive)
# Check /proc/sys/net/ipv4/tcp_wmem   (min, default, max send)
```

#### Socket Buffer Tuning

```yaml
# High-throughput socket buffer settings
# /etc/sysctl.d/99-network-buffers.conf

# Core buffer sizes
net.core.rmem_max: 16777216          # 16MB max receive buffer
net.core.wmem_max: 16777216          # 16MB max send buffer
net.core.rmem_default: 1048576       # 1MB default receive
net.core.wmem_default: 1048576       # 1MB default send

# TCP-specific buffer sizes (min, default, max in bytes)
net.ipv4.tcp_rmem: "4096 1048576 16777216"   # 4KB min, 1MB default, 16MB max
net.ipv4.tcp_wmem: "4096 1048576 16777216"

# Network device backlog
net.core.netdev_max_backlog: 65536   # Default: 1000
net.core.somaxconn: 65535            # Default: 128 (listen backlog)

# TCP memory limits (pages: low, pressure, high)
net.ipv4.tcp_mem: "786432 1048576 1572864"
# low: 3GB, pressure: 4GB, high: 6GB (assumes 4KB pages)

# Bandwidth-Delay Product (BDP) calculation:
# Buffer size = Bandwidth (bytes/sec) * RTT (seconds)
# Example: 10Gbps link, 50ms RTT
# BDP = 1.25 GB/s * 0.05s = 62.5 MB
# Set tcp_rmem/wmem max to at least BDP
```

### 5.6 UDP Monitoring

UDP lacks built-in retransmission, making loss detection dependent on application-layer or OS-level metrics:

```promql
# --- UDP Metrics ---

# UDP datagrams received
rate(node_netstat_Udp_InDatagrams[5m])

# UDP datagrams sent
rate(node_netstat_Udp_OutDatagrams[5m])

# UDP receive errors (CRITICAL: silent data loss)
rate(node_netstat_Udp_InErrors[5m])

# UDP buffer overflow (socket buffer too small)
rate(node_netstat_Udp_RcvbufErrors[5m])

# UDP send buffer errors
rate(node_netstat_Udp_SndbufErrors[5m])

# UDP "no port" errors (no process listening)
rate(node_netstat_Udp_NoPorts[5m])

# UDP CSUM errors (checksum failures)
rate(node_netstat_Udp_InCsumErrors[5m])

# Combined UDP loss indicator
(
  rate(node_netstat_Udp_InErrors[5m])
  + rate(node_netstat_Udp_RcvbufErrors[5m])
)
/ rate(node_netstat_Udp_InDatagrams[5m]) * 100

# Alert: UDP receive buffer overflow
rate(node_netstat_Udp_RcvbufErrors[5m]) > 0
```

### 5.7 QUIC and HTTP/3 Observability

QUIC (Quick UDP Internet Connections) replaces TCP+TLS with a single encrypted UDP-based protocol, used by HTTP/3:

```yaml
# QUIC presents unique observability challenges:
# 1. All traffic is encrypted (including headers) - no passive monitoring
# 2. Runs over UDP - traditional TCP tools are useless
# 3. Connection migration - client IP may change mid-connection
# 4. Multiplexed streams - no head-of-line blocking

# QUIC metrics to monitor:
quic_metrics:
  # Connection metrics
  - quic_connections_active           # Active QUIC connections
  - quic_connections_total            # Total connections (counter)
  - quic_handshake_duration_seconds   # 0-RTT vs 1-RTT handshake time
  - quic_connection_duration_seconds  # Connection lifetime
  - quic_connection_migration_total   # Connection migrations (IP change)

  # Stream metrics
  - quic_streams_active               # Active streams per connection
  - quic_streams_total                # Total streams opened
  - quic_stream_bytes_sent            # Bytes sent per stream
  - quic_stream_bytes_received        # Bytes received per stream

  # Loss and congestion
  - quic_packets_lost_total           # Packets declared lost
  - quic_packets_sent_total           # Total packets sent
  - quic_packets_received_total       # Total packets received
  - quic_congestion_window_bytes      # Current congestion window
  - quic_bytes_in_flight              # Unacknowledged bytes
  - quic_smoothed_rtt_microseconds    # Smoothed RTT
  - quic_min_rtt_microseconds         # Minimum observed RTT
  - quic_rtt_variance_microseconds    # RTT variance

  # Retry and flow control
  - quic_retry_total                  # Connection retries
  - quic_stateless_reset_total        # Stateless resets sent/received
  - quic_flow_control_blocked_total   # Times blocked by flow control

# NGINX QUIC (HTTP/3) configuration
server {
    listen 443 quic reuseport;
    listen 443 ssl;
    http3 on;

    # QUIC-specific logging
    # $http3 = "h3" for HTTP/3, "" otherwise
    # $quic = "quic" for QUIC connections
    log_format quic_log '$remote_addr [$time_local] '
        '"$request" $status $body_bytes_sent '
        'h3=$http3 quic=$quic rt=$request_time';
}

# Envoy QUIC metrics (when using HTTP/3 upstream/downstream)
# envoy.http3.downstream.rx.*
# envoy.http3.downstream.tx.*
# envoy.quic.connection.*
# envoy.quic.stream.*
```

### 5.8 Linux Network Stack Metrics

#### /proc/net/snmp and nstat

```yaml
# Key metrics from /proc/net/snmp and /proc/net/netstat
# node_exporter reads these automatically

# /proc/net/snmp metrics (node_netstat_*)
ip_metrics:
  - node_netstat_Ip_InReceives       # IP datagrams received
  - node_netstat_Ip_InDiscards       # Discarded (no route, etc.)
  - node_netstat_Ip_OutRequests      # IP datagrams sent
  - node_netstat_Ip_ForwDatagrams    # Forwarded datagrams (router mode)
  - node_netstat_Ip_InAddrErrors     # Invalid address errors
  - node_netstat_Ip_InNoRoutes       # No route to destination
  - node_netstat_Ip_ReasmTimeout     # Reassembly timeouts (fragmentation)

icmp_metrics:
  - node_netstat_Icmp_InMsgs         # ICMP messages received
  - node_netstat_Icmp_InErrors       # ICMP errors received
  - node_netstat_Icmp_OutMsgs        # ICMP messages sent
  - node_netstat_Icmp_InDestUnreachs # Destination unreachable received
  - node_netstat_Icmp_OutDestUnreachs # Destination unreachable sent
  - node_netstat_Icmp_InTimeExcds    # TTL exceeded received

tcp_metrics:
  - node_netstat_Tcp_ActiveOpens     # SYN sent (outgoing connections)
  - node_netstat_Tcp_PassiveOpens    # SYN received (incoming connections)
  - node_netstat_Tcp_AttemptFails    # Failed connection attempts
  - node_netstat_Tcp_EstabResets     # Established connections reset
  - node_netstat_Tcp_CurrEstab       # Current ESTABLISHED count
  - node_netstat_Tcp_InSegs          # Segments received
  - node_netstat_Tcp_OutSegs         # Segments sent
  - node_netstat_Tcp_RetransSegs     # Segments retransmitted
  - node_netstat_Tcp_InErrs          # Segments with errors
  - node_netstat_Tcp_OutRsts         # RST segments sent

# /proc/net/netstat extended metrics (node_netstat_TcpExt_*)
tcp_ext_metrics:
  - node_netstat_TcpExt_SyncookiesSent       # SYN cookies sent (queue overflow)
  - node_netstat_TcpExt_SyncookiesRecv       # SYN cookies received
  - node_netstat_TcpExt_SyncookiesFailed     # SYN cookie validation failures
  - node_netstat_TcpExt_ListenOverflows      # Listen queue overflow
  - node_netstat_TcpExt_ListenDrops          # Connections dropped from listen
  - node_netstat_TcpExt_TCPFastRetrans       # Fast retransmissions
  - node_netstat_TcpExt_TCPSlowStartRetrans  # Loss during slow start
  - node_netstat_TcpExt_TCPTimeouts          # RTO-based timeouts
  - node_netstat_TcpExt_TCPSpuriousRTOs      # Spurious RTO detected
  - node_netstat_TcpExt_TCPLossProbes        # Tail loss probes sent
  - node_netstat_TcpExt_TCPLossProbeRecovery # Loss recovered by TLP
  - node_netstat_TcpExt_TCPSackRecovery      # SACK-based recovery
  - node_netstat_TcpExt_TCPSACKReneging      # SACK reneging (broken stacks)
  - node_netstat_TcpExt_TCPAbortOnMemory     # Aborted due to memory pressure
  - node_netstat_TcpExt_TCPAbortOnTimeout    # Aborted due to timeout
  - node_netstat_TcpExt_TCPAbortOnData       # Aborted on unexpected data
  - node_netstat_TcpExt_TCPAbortOnClose      # Aborted on close
  - node_netstat_TcpExt_TCPBacklogDrop       # Dropped from backlog queue
  - node_netstat_TcpExt_TCPOFOQueue          # Out-of-order segments queued
  - node_netstat_TcpExt_TCPOFODrop           # Out-of-order segments dropped
  - node_netstat_TcpExt_TCPMemoryPressures   # Entered memory pressure state
```

#### Comprehensive TCP Health Dashboard PromQL

```promql
# --- TCP Health Dashboard ---

# Connection establishment success rate
1 - (
  rate(node_netstat_Tcp_AttemptFails[5m])
  / (rate(node_netstat_Tcp_ActiveOpens[5m]) + rate(node_netstat_Tcp_PassiveOpens[5m]))
)

# Listen queue health (overflow should be 0)
rate(node_netstat_TcpExt_ListenOverflows[5m])
rate(node_netstat_TcpExt_ListenDrops[5m])

# Retransmission breakdown
rate(node_netstat_TcpExt_TCPTimeouts[5m])          # Worst: RTO timeouts
rate(node_netstat_TcpExt_TCPFastRetrans[5m])        # Better: fast retransmit
rate(node_netstat_TcpExt_TCPLossProbes[5m])         # Best: tail loss probes
rate(node_netstat_TcpExt_TCPSlowStartRetrans[5m])   # Bad: loss in slow start

# Connection abort reasons
rate(node_netstat_TcpExt_TCPAbortOnMemory[5m])     # Memory issue
rate(node_netstat_TcpExt_TCPAbortOnTimeout[5m])    # Timeout
rate(node_netstat_TcpExt_TCPAbortOnData[5m])       # Unexpected data
rate(node_netstat_TcpExt_TCPAbortOnClose[5m])      # Close race condition

# Out-of-order delivery (reordering on network path)
rate(node_netstat_TcpExt_TCPOFOQueue[5m])

# RST rate (forced connection termination)
rate(node_netstat_Tcp_OutRsts[5m])
```

### 5.9 Transport Layer Alerting Rules

```yaml
# PrometheusRule for transport layer alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: transport-layer-alerts
  namespace: monitoring
spec:
  groups:
    - name: tcp-health
      interval: 30s
      rules:
        - alert: HighTCPRetransmissionRate
          expr: |
            rate(node_netstat_Tcp_RetransSegs[5m])
            / rate(node_netstat_Tcp_OutSegs[5m]) > 0.01
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "TCP retransmission rate >1% on {{ $labels.instance }}"
            description: "Current rate: {{ $value | humanizePercentage }}. Check for network congestion or packet loss."

        - alert: ConntrackTableNearFull
          expr: |
            node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Conntrack table >80% full on {{ $labels.instance }}"
            description: "{{ $value | humanizePercentage }} utilized. New connections will be dropped when full."

        - alert: ConntrackTableDrops
          expr: rate(node_nf_conntrack_stat_drop[5m]) > 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Conntrack entries being dropped on {{ $labels.instance }}"

        - alert: TCPListenOverflow
          expr: rate(node_netstat_TcpExt_ListenOverflows[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "TCP listen queue overflowing on {{ $labels.instance }}"
            description: "Incoming connections being dropped. Increase somaxconn or reduce backlog."

        - alert: HighCloseWaitConnections
          expr: node_tcp_connection_states{state="close_wait"} > 500
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "{{ $value }} CLOSE_WAIT connections on {{ $labels.instance }}"
            description: "Application may have a connection leak. Check for unclosed sockets."

        - alert: UDPReceiveBufferOverflow
          expr: rate(node_netstat_Udp_RcvbufErrors[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "UDP receive buffer overflow on {{ $labels.instance }}"
            description: "UDP datagrams being dropped due to full receive buffers."

        - alert: TCPMemoryPressure
          expr: rate(node_netstat_TcpExt_TCPMemoryPressures[5m]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "TCP stack under memory pressure on {{ $labels.instance }}"

        - alert: HighTimeWaitSockets
          expr: node_tcp_connection_states{state="time_wait"} > 20000
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "{{ $value }} TIME_WAIT sockets on {{ $labels.instance }}"
            description: "May cause ephemeral port exhaustion. Enable tcp_tw_reuse or use connection pooling."

        - alert: SYNCookiesActivated
          expr: rate(node_netstat_TcpExt_SyncookiesSent[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "SYN cookies activated on {{ $labels.instance }}"
            description: "SYN queue overflow. Possible SYN flood attack or increase tcp_max_syn_backlog."

---

## 6. Network Performance Monitoring

### 6.1 Synthetic Monitoring

Synthetic monitoring probes network endpoints from known locations to measure availability, latency, and correctness without depending on real user traffic:

```
┌──────────────────────────────────────────────────────────────────┐
│               SYNTHETIC MONITORING ARCHITECTURE                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Probe Types                            │    │
│  │                                                          │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌───────────┐  │    │
│  │  │  ICMP   │  │  TCP    │  │  HTTP   │  │Traceroute │  │    │
│  │  │  Ping   │  │  Connect│  │  GET/   │  │ (ICMP/    │  │    │
│  │  │         │  │         │  │  HEAD   │  │  TCP/UDP) │  │    │
│  │  │ Measures│  │ Measures│  │ Measures│  │ Measures  │  │    │
│  │  │ RTT,    │  │ connect │  │ TTFB,   │  │ per-hop   │  │    │
│  │  │ loss,   │  │ time,   │  │ TLS,    │  │ latency,  │  │    │
│  │  │ jitter  │  │ port    │  │ status, │  │ path      │  │    │
│  │  │         │  │ state   │  │ content │  │ changes   │  │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └───────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Probe Locations                        │    │
│  │                                                          │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │    │
│  │  │ Internal │  │ Regional │  │ Cloud    │  │ Global │  │    │
│  │  │ (DC/K8s) │  │ Offices  │  │ Regions  │  │ PoPs   │  │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            Metrics Pipeline                              │    │
│  │                                                          │    │
│  │  blackbox_exporter → Prometheus → Grafana                │    │
│  │  Synthetic Monitor → OTel Collector → Backend            │    │
│  │  Smokeping → RRD → Web UI                                │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### 6.2 Prometheus Blackbox Exporter Configuration

The blackbox_exporter is the standard tool for synthetic monitoring in the Prometheus ecosystem:

```yaml
# blackbox.yml - Module definitions
modules:
  # ICMP ping probe
  icmp_probe:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: ip4
      ip_protocol_fallback: false
      payload_size: 56           # Standard ping size
      dont_fragment: true        # Detect MTU issues

  # TCP connection probe
  tcp_connect:
    prober: tcp
    timeout: 5s
    tcp:
      preferred_ip_protocol: ip4
      tls: false

  # TCP with TLS
  tcp_tls:
    prober: tcp
    timeout: 10s
    tcp:
      preferred_ip_protocol: ip4
      tls: true
      tls_config:
        insecure_skip_verify: false

  # HTTP probe (comprehensive)
  http_2xx:
    prober: http
    timeout: 10s
    http:
      method: GET
      preferred_ip_protocol: ip4
      ip_protocol_fallback: false
      follow_redirects: true
      fail_if_ssl: false
      fail_if_not_ssl: true
      tls_config:
        insecure_skip_verify: false
      valid_http_versions:
        - "HTTP/1.1"
        - "HTTP/2.0"
      valid_status_codes: [200, 201, 204]
      no_follow_redirects: false
      fail_if_body_matches_regexp:
        - "error"
        - "maintenance"
      fail_if_body_not_matches_regexp:
        - '"status"\s*:\s*"(ok|healthy)"'
      headers:
        Accept: "application/json"
        User-Agent: "Prometheus-Blackbox-Exporter"

  # HTTP POST probe (API health check)
  http_post_api:
    prober: http
    timeout: 10s
    http:
      method: POST
      headers:
        Content-Type: "application/json"
      body: '{"query": "health"}'
      valid_status_codes: [200]

  # DNS probe
  dns_resolve:
    prober: dns
    timeout: 5s
    dns:
      preferred_ip_protocol: ip4
      query_name: "kubernetes.default.svc.cluster.local"
      query_type: "A"
      valid_rcodes:
        - NOERROR
      validate_answer_rrs:
        fail_if_matches_regexp: []
        fail_if_not_matches_regexp:
          - ".*\\d+\\.\\d+\\.\\d+\\.\\d+.*"

  # gRPC health check probe
  grpc_health:
    prober: grpc
    timeout: 5s
    grpc:
      preferred_ip_protocol: ip4
      tls: true
      service: "grpc.health.v1.Health"
```

#### Blackbox Exporter Prometheus Configuration

```yaml
# prometheus.yml - Scrape configuration for blackbox_exporter
scrape_configs:
  # ICMP probes
  - job_name: 'blackbox-icmp'
    metrics_path: /probe
    params:
      module: [icmp_probe]
    static_configs:
      - targets:
          - 10.0.1.1           # Core router
          - 10.0.2.1           # Distribution switch
          - 8.8.8.8            # External DNS
          - 1.1.1.1            # Cloudflare DNS
        labels:
          probe_type: icmp
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # HTTP probes
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    scrape_interval: 30s
    static_configs:
      - targets:
          - https://api.example.com/health
          - https://www.example.com
          - https://admin.example.com/login
          - https://cdn.example.com/test.txt
        labels:
          probe_type: http
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # TCP probes (database, cache, message queue ports)
  - job_name: 'blackbox-tcp'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
          - postgres-primary:5432
          - redis-master:6379
          - kafka-01:9092
          - kafka-02:9092
          - elasticsearch:9200
        labels:
          probe_type: tcp
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # DNS probes
  - job_name: 'blackbox-dns'
    metrics_path: /probe
    params:
      module: [dns_resolve]
    static_configs:
      - targets:
          - 10.96.0.10:53       # CoreDNS ClusterIP
          - 8.8.8.8:53          # Google DNS
          - 1.1.1.1:53          # Cloudflare DNS
        labels:
          probe_type: dns
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

#### Blackbox Exporter PromQL Queries

```promql
# --- Synthetic Monitoring PromQL ---

# Probe success rate by target
avg_over_time(probe_success{job="blackbox-http"}[1h])

# Probe duration breakdown (connection phases)
probe_duration_seconds{phase="resolve"}   # DNS resolution
probe_duration_seconds{phase="connect"}   # TCP connection
probe_duration_seconds{phase="tls"}       # TLS handshake
probe_duration_seconds{phase="processing"} # Server processing (TTFB)
probe_duration_seconds{phase="transfer"}  # Content transfer

# Total probe duration
probe_duration_seconds{phase="transfer"} # Usually the last phase = total

# HTTP-specific metrics
probe_http_status_code                    # Response status code
probe_http_content_length                 # Response body size
probe_http_version                        # HTTP version (1=HTTP/1.1, 2=HTTP/2)
probe_http_ssl                           # 1 if TLS used, 0 otherwise
probe_http_redirects                     # Number of redirects followed
probe_http_uncompressed_body_length      # Uncompressed response size

# TLS certificate expiry
probe_ssl_earliest_cert_expiry - time()  # Seconds until cert expiry

# Certificate expiry in days
(probe_ssl_earliest_cert_expiry - time()) / 86400

# ICMP metrics
probe_icmp_duration_seconds{phase="setup"}  # ICMP socket setup
probe_icmp_duration_seconds{phase="rtt"}    # Round-trip time

# DNS probe metrics
probe_dns_lookup_time_seconds              # DNS resolution time

# --- Alerting on Synthetic Probes ---

# Target down (probe failing)
probe_success == 0

# Slow response (TTFB > 500ms)
probe_duration_seconds{phase="processing"} > 0.5

# Certificate expires in < 14 days
(probe_ssl_earliest_cert_expiry - time()) / 86400 < 14

# Certificate expires in < 7 days (critical)
(probe_ssl_earliest_cert_expiry - time()) / 86400 < 7

# HTTP status code is not 2xx
probe_http_status_code < 200 or probe_http_status_code >= 300

# DNS resolution slow (> 100ms)
probe_dns_lookup_time_seconds > 0.1

# TCP connection time high (> 50ms for internal)
probe_duration_seconds{phase="connect"} > 0.05

# TLS handshake slow (> 200ms)
probe_duration_seconds{phase="tls"} > 0.2
```

### 6.3 Smokeping (Long-term Latency Tracking)

```yaml
# Smokeping provides long-term latency and packet loss visualization
# using multi-ping measurements that show latency distribution

# Smokeping configuration (/etc/smokeping/config)
# *** General ***
# owner    = Network Operations
# contact  = noc@example.com
# cgiurl   = http://smokeping.example.com/cgi-bin/smokeping.cgi

# *** Targets ***
# + Infrastructure
# menu = Infrastructure
# title = Core Infrastructure

# ++ CoreRouter
# host = 10.0.1.1
# menu = Core Router
# title = Core Router (10.0.1.1)

# ++ DNS
# host = 10.96.0.10
# menu = CoreDNS
# title = Kubernetes CoreDNS

# + Internet
# menu = Internet Connectivity
# title = Internet Path Quality

# ++ Google
# host = 8.8.8.8
# title = Google DNS

# ++ Cloudflare
# host = 1.1.1.1
# title = Cloudflare DNS

# Smokeping measurement:
# Sends 20 ICMP pings every 300 seconds
# Records: median, loss %, distribution (min/max/percentiles)
# Stored in RRD (Round Robin Database) for years of data

# Alternative: Use Prometheus + blackbox_exporter with recording rules
# to achieve similar long-term latency tracking:

# Recording rules for Smokeping-equivalent data
groups:
  - name: network-latency-recording
    interval: 60s
    rules:
      # 1-minute average RTT
      - record: network:probe_rtt:avg1m
        expr: avg_over_time(probe_icmp_duration_seconds{phase="rtt"}[1m])

      # 5-minute P95 RTT
      - record: network:probe_rtt:p95_5m
        expr: quantile_over_time(0.95, probe_icmp_duration_seconds{phase="rtt"}[5m])

      # 1-hour packet loss rate
      - record: network:probe_loss:rate1h
        expr: 1 - avg_over_time(probe_success{job="blackbox-icmp"}[1h])

      # 24-hour availability
      - record: network:probe_availability:24h
        expr: avg_over_time(probe_success{job="blackbox-icmp"}[24h])
```

### 6.4 MTU (Maximum Transmission Unit) Discovery and Monitoring

```yaml
# MTU mismatches cause silent packet drops, fragmentation, or PMTUD black holes

# Common MTU values:
# Ethernet:        1500 bytes
# Jumbo frames:    9000 bytes
# VXLAN overlay:   1450 bytes (1500 - 50 byte VXLAN header)
# WireGuard:       1420 bytes (1500 - 80 byte overhead)
# IPsec ESP:       1400-1438 bytes (depends on cipher)
# GRE:             1476 bytes (1500 - 24 byte GRE header)
# PPPoE:           1492 bytes (1500 - 8 byte PPPoE header)
# Azure VM:        1500 (external), 9000 (internal accelerated networking)
# AWS:             9001 bytes (jumbo within VPC), 1500 (internet)
# GCP:             1460 bytes (default), custom MTU up to 8896

# PMTUD (Path MTU Discovery) monitoring
# Uses DF (Don't Fragment) bit + ICMP "Fragmentation Needed" messages
# If ICMP is blocked, PMTUD fails = "black hole"

# Detection with blackbox_exporter
modules:
  icmp_mtu_1500:
    prober: icmp
    timeout: 5s
    icmp:
      payload_size: 1472      # 1500 - 20 (IP) - 8 (ICMP) = 1472
      dont_fragment: true
  icmp_mtu_9000:
    prober: icmp
    timeout: 5s
    icmp:
      payload_size: 8972      # 9000 - 20 - 8 = 8972
      dont_fragment: true

# If icmp_mtu_1500 succeeds but icmp_mtu_9000 fails,
# the path doesn't support jumbo frames

# Fragmentation monitoring (should be zero in modern networks)
# node_netstat_Ip_ReasmReqds    - fragments needing reassembly
# node_netstat_Ip_FragCreates   - fragments created
# node_netstat_Ip_ReasmFails    - reassembly failures
# node_netstat_Ip_FragFails     - fragmentation failures (DF set)

# PromQL: detect fragmentation
rate(node_netstat_Ip_FragCreates[5m]) > 0      # Any fragmentation occurring
rate(node_netstat_Ip_ReasmFails[5m]) > 0       # Reassembly failures
rate(node_netstat_Ip_FragFails[5m]) > 0        # DF bit preventing fragmentation
```

### 6.5 Bandwidth Monitoring and 95th Percentile

```yaml
# 95th percentile billing is standard for transit and colocation:
# Throw out top 5% of samples, bill on next highest = 95th percentile
#
# With 5-minute samples over 30 days:
# 30 * 24 * 12 = 8,640 samples
# Discard top 432 samples (5%)
# Bill on sample #433 from top

# PromQL for interface bandwidth
# Bits per second (transmit)
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8

# Bits per second (receive)
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8

# 95th percentile over 30 days (for billing estimation)
quantile_over_time(0.95,
  rate(node_network_transmit_bytes_total{device="eth0"}[5m])[30d:5m]
) * 8

# Interface utilization percentage
(rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8)
  /
(node_network_speed_bytes{device="eth0"} * 8) * 100

# Combined utilization (max of in/out)
max(
  rate(node_network_transmit_bytes_total{device="eth0"}[5m]),
  rate(node_network_receive_bytes_total{device="eth0"}[5m])
) * 8 / (node_network_speed_bytes{device="eth0"} * 8) * 100

# Bandwidth anomaly: sudden spike
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8
  > 2 * avg_over_time(
    rate(node_network_transmit_bytes_total{device="eth0"}[5m])[1d:5m]
  ) * 8

# Recording rules for efficient 95th percentile queries
groups:
  - name: bandwidth-recording
    interval: 60s
    rules:
      - record: network:interface_bits_per_second:transmit
        expr: rate(node_network_transmit_bytes_total[5m]) * 8
        labels:
          direction: transmit

      - record: network:interface_bits_per_second:receive
        expr: rate(node_network_receive_bytes_total[5m]) * 8
        labels:
          direction: receive

      - record: network:interface_utilization:percent
        expr: |
          max(
            rate(node_network_transmit_bytes_total[5m]),
            rate(node_network_receive_bytes_total[5m])
          ) * 8 / (node_network_speed_bytes * 8) * 100
```

### 6.6 Packet Capture for Deep Debugging

#### tcpdump Examples

```bash
# Capture packets on specific interface
tcpdump -i eth0 -nn -w /tmp/capture.pcap

# Capture only TCP SYN packets (connection attempts)
tcpdump -i any 'tcp[tcpflags] & tcp-syn != 0'

# Capture TCP retransmissions (requires kernel tracepoint or tshark)
# tcpdump can't directly filter retransmissions

# Capture DNS traffic
tcpdump -i any port 53 -nn

# Capture traffic to/from specific host, port range
tcpdump -i eth0 host 10.0.1.5 and portrange 8080-8089

# Capture ICMP (ping, unreachable, TTL exceeded)
tcpdump -i any icmp -nn

# Capture with rotation (10 files of 100MB each)
tcpdump -i eth0 -w /var/captures/trace.pcap -C 100 -W 10

# Capture with time-limited rotation
tcpdump -i eth0 -w /var/captures/trace.pcap -G 3600 -W 24

# BPF filter: capture only RST packets (connection resets)
tcpdump -i any 'tcp[tcpflags] & tcp-rst != 0' -nn

# BPF filter: capture only packets with ECN CE (congestion)
tcpdump -i any 'ip[1] & 0x03 = 0x03' -nn
```

#### tshark (Wireshark CLI) Examples

```bash
# Analyze TCP retransmissions from capture file
tshark -r capture.pcap -Y "tcp.analysis.retransmission" \
  -T fields -e frame.time -e ip.src -e ip.dst \
  -e tcp.srcport -e tcp.dstport -e tcp.len

# Extract TCP RTT from handshake
tshark -r capture.pcap -Y "tcp.analysis.ack_rtt" \
  -T fields -e ip.src -e ip.dst -e tcp.analysis.ack_rtt

# Count HTTP response codes
tshark -r capture.pcap -Y "http.response" \
  -T fields -e http.response.code | sort | uniq -c | sort -rn

# DNS query analysis
tshark -r capture.pcap -Y "dns.flags.response == 0" \
  -T fields -e frame.time -e ip.src -e dns.qry.name -e dns.qry.type

# TLS certificate information
tshark -r capture.pcap -Y "tls.handshake.type == 11" \
  -T fields -e tls.handshake.certificate \
  -e x509ce.dNSName

# Extract flow statistics
tshark -r capture.pcap -q -z conv,tcp
# Shows: Address A  Port A  Address B  Port B  Frames  Bytes  Frames  Bytes

# Detect TCP zero windows
tshark -r capture.pcap -Y "tcp.window_size == 0"
```

#### TAPs vs SPAN Ports

```yaml
# Network TAPs (Test Access Points) vs SPAN (Port Mirroring)
comparison:
  TAP:
    pros:
      - Full-duplex capture (no drops)
      - No performance impact on network
      - Passive (undetectable)
      - Copies ALL traffic including errors
      - Hardware-based, no configuration
    cons:
      - Physical hardware required
      - Single point of capture
      - Cost ($500-$5000 per TAP)
      - Requires physical access
    types:
      - Passive copper TAP (100M/1G)
      - Passive fiber TAP (1G/10G/40G/100G)
      - Active/regeneration TAP (multiple outputs)
      - Virtual TAP (cloud environments)
    vendors:
      - Gigamon
      - Keysight (Ixia)
      - Garland Technology
      - Datacom Systems
      - Profitap

  SPAN:
    pros:
      - No additional hardware
      - Remote configuration
      - Multiple source ports to one destination
      - Can filter by VLAN
    cons:
      - Can drop packets under load
      - Consumes switch resources (CPU/backplane)
      - May not capture errored frames
      - Limited destination ports
      - Half-duplex merging may cause drops
    types:
      - Local SPAN (same switch)
      - Remote SPAN (RSPAN, different switch)
      - Encapsulated RSPAN (ERSPAN, over IP/GRE)
    configuration:
      # Cisco IOS example
      # monitor session 1 source interface Gi0/1 both
      # monitor session 1 destination interface Gi0/24

  cloud_alternatives:
    AWS:
      - VPC Traffic Mirroring (TAP-like for ENIs)
      - Packet capture via CloudWatch
    Azure:
      - Network Watcher packet capture
      - Virtual network TAP (preview)
    GCP:
      - Packet Mirroring
      - VPC Flow Logs (not full capture)
```

### 6.7 NTP (Network Time Protocol) Monitoring

Accurate time synchronization is critical for log correlation, distributed tracing, certificate validation, and financial transactions:

```promql
# --- NTP/Chrony Metrics ---

# Clock offset from NTP source (should be < 10ms)
node_ntp_offset_seconds

# NTP stratum (distance from reference clock)
# Stratum 1 = atomic/GPS clock, Stratum 2 = synced to Stratum 1, etc.
node_ntp_stratum

# NTP round-trip delay to server
node_ntp_rtt_seconds

# NTP reference time (last successful sync)
node_ntp_reference_timestamp_seconds

# NTP sanity (0 = OK, 1 = clock not synchronized)
node_ntp_sanity

# Chrony-specific metrics (chrony_exporter)
chrony_tracking_last_offset_seconds       # Last measured offset
chrony_tracking_rms_offset_seconds        # RMS offset
chrony_tracking_system_time_offset_seconds # System clock offset
chrony_tracking_root_delay_seconds         # Total root delay
chrony_tracking_root_dispersion_seconds    # Total root dispersion
chrony_tracking_stratum                    # Current stratum
chrony_tracking_leap_status                # Leap second status (0=normal)

# Alert: Clock offset too large
abs(node_ntp_offset_seconds) > 0.05    # >50ms offset

# Alert: Clock not synchronized
node_ntp_sanity != 0

# Alert: NTP stratum too high (unreliable source)
node_ntp_stratum > 4

# Alert: Clock drift rate (changing offset over time)
abs(deriv(node_ntp_offset_seconds[1h])) > 0.001  # >1ms/hour drift
```

#### NTP Configuration Best Practices for Observability

```yaml
# /etc/chrony.conf for Kubernetes nodes
# Use cloud-provider NTP sources for lowest latency:

# AWS
# server 169.254.169.123 prefer iburst  # AWS Time Sync Service

# Azure
# server time.windows.com prefer iburst

# GCP
# server metadata.google.internal prefer iburst

# Fallback public NTP pools
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Allow Chrony to step clock if offset > 1 second (first 3 updates only)
makestep 1.0 3

# Record tracking statistics for monitoring
logdir /var/log/chrony
log tracking measurements statistics

# Maximum allowed offset before alarm
maxupdateskew 100.0

# Kubernetes consideration:
# All nodes in a cluster MUST be within 1 second of each other
# for certificate validation and distributed systems to work.
# Recommended: < 10ms offset across all nodes
```

### 6.8 BGP (Border Gateway Protocol) Monitoring

#### BGP Route Change Monitoring

```yaml
# BGP monitoring is critical for:
# 1. Detecting route leaks and hijacking
# 2. Monitoring prefix announcements
# 3. Tracking AS path changes
# 4. Alerting on BGP session flaps
# 5. RPKI validation status

# BGP Exporter (bgp_exporter or custom SNMP/gNMI)
bgp_metrics:
  # Session metrics
  - bgp_session_state                    # 1=Established, 0=Down
  - bgp_session_uptime_seconds           # How long session has been up
  - bgp_session_prefix_count_received    # Prefixes received from peer
  - bgp_session_prefix_count_sent        # Prefixes sent to peer
  - bgp_session_prefix_count_accepted    # Prefixes accepted (after filtering)
  - bgp_session_messages_received_total  # Total messages received
  - bgp_session_messages_sent_total      # Total messages sent
  - bgp_session_updates_received_total   # UPDATE messages received
  - bgp_session_updates_sent_total       # UPDATE messages sent
  - bgp_session_notifications_total      # NOTIFICATION messages (errors)
  - bgp_session_flaps_total              # Session flap counter

  # Route metrics
  - bgp_route_count_total                # Total routes in RIB
  - bgp_route_count_by_origin            # Routes by origin (IGP/EGP/incomplete)
  - bgp_route_as_path_length             # Average AS path length

# BGP PromQL Queries
```

```promql
# --- BGP Health ---

# BGP session state (should always be 1 = Established)
bgp_session_state{peer=~".*"} != 1

# BGP session flap rate
rate(bgp_session_flaps_total[1h]) > 0

# Prefix count change (route leak/hijack indicator)
abs(delta(bgp_session_prefix_count_received[5m])) > 100

# NOTIFICATION rate (BGP errors)
rate(bgp_session_notifications_total[5m]) > 0

# Session uptime (detect recent flaps)
bgp_session_uptime_seconds < 3600  # Session up less than 1 hour

# Prefix count deviation from baseline
abs(bgp_session_prefix_count_received - bgp_session_prefix_count_received offset 1d)
  / bgp_session_prefix_count_received offset 1d > 0.1
# More than 10% change from yesterday = investigate
```

#### BGP Prefix Hijacking Detection

```yaml
# BGP prefix hijacking: someone else announces YOUR prefixes
# or more-specific prefixes of your address space

# Detection methods:
detection_methods:
  # 1. RPKI (Resource Public Key Infrastructure)
  rpki:
    description: |
      Cryptographic validation of route origins.
      ROAs (Route Origin Authorizations) specify which AS
      is authorized to announce each prefix.
    states:
      - VALID: Origin AS matches ROA
      - INVALID: Origin AS does not match any ROA (ALERT!)
      - NOT_FOUND: No ROA exists for this prefix
    monitoring:
      # RPKI validator metrics (Routinator, FORT, OctoRPKI)
      - rpki_vrps_total                # Total Validated ROA Payloads
      - rpki_vrps_valid                # Valid VRPs
      - rpki_vrps_invalid              # Invalid VRPs
      - rpki_vrps_not_found            # Unknown VRPs
      - rpki_rtr_sessions_active       # Active RTR sessions to routers

  # 2. BGP Stream / RIPE RIS / RouteViews
  bgp_monitoring_services:
    - name: RIPE RIS Live
      url: https://ris-live.ripe.net/
      description: Real-time BGP message stream from RIPE collectors
    - name: RouteViews
      url: http://www.routeviews.org/
      description: BGP route collection from global vantage points
    - name: BGPStream (CAIDA)
      url: https://bgpstream.caida.org/
      description: Real-time and historical BGP data
    - name: Cloudflare Radar
      url: https://radar.cloudflare.com/
      description: BGP route leak and hijack detection

  # 3. Custom monitoring
  custom:
    description: |
      Monitor your own prefixes from external vantage points.
      Alert if:
      - Your prefix appears with unexpected origin AS
      - More-specific prefix of yours appears
      - AS path changes unexpectedly
      - Your prefix disappears from global routing table

# BGP alerting rules
alerts:
  - alert: BGPSessionDown
    expr: bgp_session_state != 1
    for: 2m
    severity: critical

  - alert: BGPSessionFlapping
    expr: rate(bgp_session_flaps_total[1h]) > 2
    for: 30m
    severity: warning

  - alert: BGPPrefixCountAnomaly
    expr: |
      abs(delta(bgp_session_prefix_count_received[10m])) > 500
    for: 5m
    severity: warning

  - alert: RPKIInvalidRoutes
    expr: rpki_vrps_invalid > 0
    for: 0m
    severity: critical
```

### 6.9 Network Performance Alerting Rules (Comprehensive)

```yaml
# PrometheusRule for comprehensive network performance monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-performance-alerts
  namespace: monitoring
spec:
  groups:
    - name: synthetic-monitoring
      interval: 30s
      rules:
        - alert: EndpointDown
          expr: probe_success == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.instance }} is unreachable"
            runbook_url: "https://wiki.example.com/runbooks/endpoint-down"

        - alert: HighLatency
          expr: probe_duration_seconds > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "{{ $labels.instance }} probe latency >1s ({{ $value }}s)"

        - alert: SSLCertExpiringSoon
          expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 14
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "SSL cert for {{ $labels.instance }} expires in {{ $value | humanize }} days"

        - alert: SSLCertExpiryCritical
          expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 3
          for: 0m
          labels:
            severity: critical
          annotations:
            summary: "SSL cert for {{ $labels.instance }} expires in {{ $value | humanize }} days"

    - name: interface-health
      interval: 30s
      rules:
        - alert: InterfaceHighUtilization
          expr: |
            (rate(node_network_transmit_bytes_total[5m]) * 8)
            / (node_network_speed_bytes * 8) > 0.85
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "{{ $labels.device }} on {{ $labels.instance }} >85% utilized"

        - alert: InterfaceErrors
          expr: |
            rate(node_network_receive_errs_total[5m])
            + rate(node_network_transmit_errs_total[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Interface errors on {{ $labels.device }} ({{ $labels.instance }})"

        - alert: InterfacePacketDrops
          expr: |
            rate(node_network_receive_drop_total[5m])
            + rate(node_network_transmit_drop_total[5m]) > 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: ">10 packet drops/sec on {{ $labels.device }}"

    - name: ntp-health
      interval: 60s
      rules:
        - alert: ClockOffsetHigh
          expr: abs(node_ntp_offset_seconds) > 0.05
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Clock offset >50ms on {{ $labels.instance }}"

        - alert: ClockNotSynced
          expr: node_ntp_sanity != 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "NTP not synchronized on {{ $labels.instance }}"

    - name: bgp-health
      interval: 30s
      rules:
        - alert: BGPSessionDown
          expr: bgp_session_state != 1
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "BGP session to {{ $labels.peer }} is DOWN"

        - alert: BGPPrefixAnomaly
          expr: |
            abs(delta(bgp_session_prefix_count_received[10m]))
            / bgp_session_prefix_count_received > 0.1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "BGP prefix count changed >10% for peer {{ $labels.peer }}"

    - name: dns-health
      interval: 30s
      rules:
        - alert: CoreDNSLatencyHigh
          expr: |
            histogram_quantile(0.99,
              sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)
            ) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "CoreDNS P99 latency >100ms"

        - alert: CoreDNSSERVFAILHigh
          expr: |
            sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
            / sum(rate(coredns_dns_responses_total[5m])) > 0.01
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "CoreDNS SERVFAIL rate >1%"

        - alert: CoreDNSDown
          expr: up{job="coredns"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "CoreDNS instance down"

---

## Summary and Quick Reference

### Network Observability Tool Selection Matrix

| Use Case | Recommended Tool | Alternative |
|----------|-----------------|-------------|
| **ICMP/TCP/HTTP probing** | blackbox_exporter | Synthetics (Grafana Cloud, Datadog) |
| **Interface metrics** | SNMP Exporter + node_exporter | gNMI receiver |
| **Flow analysis** | GoFlow2 + Kafka + ClickHouse | Akvorado, ntopng, ElastiFlow |
| **DNS monitoring** | CoreDNS metrics + dnstap | Passive DNS (Zeek) |
| **Packet capture** | tcpdump/tshark + TAPs | Cloud packet mirroring |
| **Load balancer metrics** | Native Prometheus endpoints | OTel Collector CloudWatch/Azure Monitor |
| **TCP/transport metrics** | node_exporter (netstat collector) | eBPF (Pixie, Beyla) |
| **BGP monitoring** | BGP exporter + RPKI validator | RIPE RIS, BGPStream |
| **Service mesh** | Istio/Linkerd/Cilium native | See Part 2 |
| **Network topology** | Cilium Hubble, Weave Scope | NetBox + LibreNMS |

### Critical Alerts Checklist

```yaml
# Minimum network alerts every organization should have:
critical_alerts:
  - name: "Endpoint unreachable"
    metric: probe_success == 0
    for: 2m

  - name: "SSL certificate expiring"
    metric: "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 14"
    for: 1h

  - name: "TCP retransmission rate high"
    metric: "rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) > 0.01"
    for: 10m

  - name: "Conntrack table near full"
    metric: "node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8"
    for: 5m

  - name: "DNS SERVFAIL rate high"
    metric: "sum(rate(coredns_dns_responses_total{rcode='SERVFAIL'}[5m])) / sum(rate(coredns_dns_responses_total[5m])) > 0.01"
    for: 5m

  - name: "Interface errors"
    metric: "rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 0"
    for: 5m

  - name: "BGP session down"
    metric: "bgp_session_state != 1"
    for: 2m

  - name: "NTP clock offset"
    metric: "abs(node_ntp_offset_seconds) > 0.05"
    for: 10m

  - name: "Load balancer 5xx rate"
    metric: "rate(haproxy_backend_http_responses_total{code='5xx'}[5m]) / rate(haproxy_backend_http_responses_total[5m]) > 0.05"
    for: 5m

  - name: "UDP receive buffer overflow"
    metric: "rate(node_netstat_Udp_RcvbufErrors[5m]) > 0"
    for: 5m
```

### Network Observability Maturity Model

```
Level 0 — Blind
  "We don't know when the network is down until users complain."
  → No monitoring, no metrics, no alerts

Level 1 — Reactive
  "We know when devices are up or down."
  → SNMP polling, ping monitoring, basic interface counters
  → Tools: Nagios, PRTG, basic SNMP

Level 2 — Proactive
  "We can detect problems before users notice."
  → Synthetic monitoring, threshold-based alerts, log analysis
  → Tools: blackbox_exporter, Prometheus, Grafana, syslog

Level 3 — Analytical
  "We understand traffic patterns and can debug complex issues."
  → Flow analysis, DNS observability, TCP metrics, conntrack
  → Tools: GoFlow2, CoreDNS metrics, node_exporter, eBPF

Level 4 — Predictive
  "We can predict failures and optimize proactively."
  → ML anomaly detection, capacity planning, SLO-driven
  → Tools: Kentik, Cilium Hubble, BGP monitoring, RPKI

Level 5 — Autonomous
  "The network self-heals and auto-optimizes."
  → Intent-based networking, closed-loop automation
  → Tools: Service mesh + GitOps, auto-scaling, self-healing
```


---

# Part II: Service Mesh Observability

---

## 1. Service Mesh Fundamentals and Observability

### 1.1 What Service Meshes Solve

Service meshes address four critical concerns in microservice architectures:

| Concern | What It Solves | Without Mesh | With Mesh |
|---------|---------------|--------------|-----------|
| **Traffic Management** | Load balancing, routing, retries, timeouts, circuit breaking | Library-specific (Hystrix, Polly) per language | Uniform infrastructure-level policy |
| **Security (mTLS)** | Encryption in transit, mutual authentication, authorization | Manual cert management, app-level TLS | Automatic mTLS, zero-trust networking |
| **Observability** | Metrics, traces, access logs, topology visualization | Manual instrumentation per service | Automatic golden signals for all traffic |
| **Resilience** | Retry budgets, circuit breakers, rate limiting, fault injection | Per-service implementation | Mesh-wide policy enforcement |

### 1.2 Data Plane vs Control Plane Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTROL PLANE                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Configuration│  │   Identity   │  │  Service Discovery   │   │
│  │  Management  │  │  (CA/Certs)  │  │  (Endpoints, Routes) │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│                          xDS API / gRPC                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                         DATA PLANE                               │
│                                                                  │
│  ┌─────────┐  Proxy  ┌─────────┐  Proxy  ┌─────────┐           │
│  │Service A│◄──────►│Service B│◄──────►│Service C│            │
│  └─────────┘         └─────────┘         └─────────┘           │
│                                                                  │
│  Every request flows through the proxy (sidecar or per-node)    │
│  Proxies emit: metrics, traces, access logs, topology data      │
└──────────────────────────────────────────────────────────────────┘
```

**Control Plane responsibilities:**
- Push configuration to proxies (routes, policies, certificates)
- Issue and rotate mTLS certificates
- Maintain service discovery information
- Aggregate telemetry (optionally)

**Data Plane responsibilities:**
- Intercept all inbound/outbound traffic
- Enforce mTLS, authorization policies
- Emit L7 metrics (request count, duration, size, response codes)
- Propagate trace context headers
- Generate structured access logs

### 1.3 Sidecar Proxy vs Sidecar-Less Architectures

#### Traditional Sidecar Pattern
Every application pod gets an injected proxy container (typically Envoy) that intercepts all traffic via iptables rules:

```yaml
# Pod with sidecar proxy injected
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    sidecar.istio.io/inject: "true"
spec:
  containers:
  - name: my-app
    image: my-app:v1
    ports:
    - containerPort: 8080
  # Injected automatically by the mesh:
  - name: istio-proxy          # Sidecar proxy
    image: envoyproxy/envoy:v1.31
    ports:
    - containerPort: 15090     # Prometheus metrics
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
  initContainers:
  - name: istio-init            # Sets up iptables rules
    image: istio/proxyv2:1.24
```

**Pros:** Full L7 visibility, per-pod isolation, mature ecosystem
**Cons:** Resource overhead (100-200m CPU, 128-256Mi memory per pod), increased latency (~1-3ms per hop), scaling complexity

#### Ambient Mesh (Istio Sidecar-Less)
Istio ambient mode splits functionality into two layers:

```
┌──────────────────────────────────────────────────────────────┐
│  L7 Processing Layer (optional, per-service)                  │
│  ┌────────────────────────────────────┐                      │
│  │        Waypoint Proxy (Envoy)      │  ← HTTP routing,     │
│  │  Deployed as separate Deployment   │    L7 auth, retries  │
│  └────────────────────────────────────┘                      │
├──────────────────────────────────────────────────────────────┤
│  L4 Secure Overlay (always-on, per-node)                     │
│  ┌────────────────────────────────────┐                      │
│  │     ztunnel (Rust, DaemonSet)      │  ← mTLS, L4 auth,   │
│  │  HBONE tunneling (HTTP CONNECT)    │    L4 telemetry      │
│  └────────────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────┘
```

- **ztunnel**: Rust-based, per-node DaemonSet handling L3/L4: mTLS, L4 authorization, TCP telemetry
- **Waypoint Proxy**: Optional Envoy deployment for L7 features (HTTP routing, retries, L7 metrics)
- **Benefits**: Up to 70% reduction in CPU/memory, no sidecar injection complexity

#### eBPF-Based (Cilium Service Mesh)
No sidecar proxies at all. eBPF programs in the kernel handle networking:

```
┌──────────────────────────────────────────────────────────────┐
│                    Application Pods                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │ Service A │  │ Service B │  │ Service C │  ← No sidecars   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                   │
│       │              │              │                          │
├───────▼──────────────▼──────────────▼────────────────────────┤
│            Linux Kernel (eBPF Programs)                       │
│  ┌─────────────────────────────────────────────────┐         │
│  │  XDP hooks │ TC hooks │ Socket hooks │ Cgroup   │         │
│  │  L3/L4 processing, mTLS, load balancing         │         │
│  │  L7 parsing (HTTP, gRPC, Kafka, DNS)            │         │
│  │  Flow visibility via Hubble                      │         │
│  └─────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────┘
```

### 1.4 The Automatic Observability Advantage

Service meshes provide **golden signal metrics without any application code changes**:

| Signal | What Is Measured | How It Is Captured |
|--------|-----------------|-------------------|
| **Request Rate** | Requests per second per service | Proxy counts every L7 request |
| **Error Rate** | Percentage of 4xx/5xx responses | Proxy inspects response codes |
| **Latency** | Request duration distribution (P50/P95/P99) | Proxy measures time between request/response |
| **Saturation** | Connection pool usage, queue depths | Proxy tracks internal resource consumption |

**Additional signals provided automatically:**
- **Service topology**: Which services communicate with which
- **Traffic volume**: Bytes sent/received per connection
- **Protocol breakdown**: HTTP vs gRPC vs TCP traffic
- **mTLS status**: Whether connections are encrypted
- **Response size distribution**: Payload sizes per endpoint

### 1.5 Service Mesh Observability Signals

#### L7 Metrics
```
Request ──► [Proxy A] ──► [Proxy B] ──► Response
               │              │
               ▼              ▼
          Source Metrics  Destination Metrics
          - request_count  - request_count
          - request_size   - request_size
          - response_size  - response_size
          - duration       - duration
          - response_code  - response_code
```

#### Distributed Traces
Service meshes automatically generate trace spans for each proxy hop. Applications must propagate trace context headers (B3, W3C Trace Context) for traces to be correlated:

```
Headers to propagate:
- x-request-id
- x-b3-traceid / x-b3-spanid / x-b3-parentspanid / x-b3-sampled  (B3)
- traceparent / tracestate                                          (W3C)
```

#### Access Logs
Structured JSON logs for every request with source/destination metadata, timing, response codes, and security context.

#### Topology Maps
Real-time service dependency graphs derived from traffic flow, showing request rates, error rates, and latency on each edge.

### 1.6 Service Mesh Market Landscape (2025)

| Mesh | Architecture | Proxy | Language | CNCF Status | Best For |
|------|-------------|-------|----------|-------------|----------|
| **Istio** | Sidecar + Ambient | Envoy | Go/C++ | Graduated | Feature-rich enterprise deployments |
| **Linkerd** | Sidecar | linkerd2-proxy | Rust | Graduated | Simplicity-first, low resource overhead |
| **Cilium** | eBPF (no sidecar) | Kernel eBPF | Go/C | Graduated | High-performance networking + observability |
| **Consul Connect** | Sidecar | Envoy | Go | HashiCorp | Multi-platform (K8s + VMs + Nomad) |
| **Kuma** | Sidecar | Envoy | Go | Graduated | Multi-zone, universal (K8s + VMs) |
| **Open Service Mesh** | Sidecar | Envoy | Go | Archived | Deprecated in favor of Istio |

**Market trends (2025):**
- Gateway API becoming the standard for ingress and traffic management across all meshes
- eBPF adoption accelerating, potentially making sidecar proxies obsolete for some use cases
- Convergence of CNI and service mesh functionality (pioneered by Cilium)
- Ambient mesh (sidecar-less) gaining traction for reducing resource overhead
- AI-aware traffic management emerging (Istio Gateway API Inference Extension)

---

## 2. Istio Observability

### 2.1 Istio Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Plane (istiod)                     │
│  ┌────────────┐  ┌────────────┐  ┌───────────────────────┐  │
│  │   Pilot    │  │   Citadel  │  │    Galley (removed)   │  │
│  │ (xDS API)  │  │  (CA/mTLS) │  │  Config now in Pilot  │  │
│  └────────────┘  └────────────┘  └───────────────────────┘  │
│                                                              │
│  Single binary: istiod (consolidates all control plane)      │
└──────────────────────────┬──────────────────────────────────┘
                           │ xDS (LDS, RDS, CDS, EDS, SDS)
┌──────────────────────────▼──────────────────────────────────┐
│                      Data Plane                              │
│                                                              │
│  Pod A                    Pod B                              │
│  ┌──────────┐            ┌──────────┐                       │
│  │ App      │            │ App      │                       │
│  │Container │            │Container │                       │
│  └────┬─────┘            └────┬─────┘                       │
│       │ localhost              │ localhost                    │
│  ┌────▼─────┐            ┌────▼─────┐                       │
│  │  Envoy   │◄──────────►│  Envoy   │                       │
│  │ Sidecar  │   mTLS     │ Sidecar  │                       │
│  └──────────┘            └──────────┘                       │
│                                                              │
│  Telemetry V2: Wasm-based stats filter in Envoy             │
│  Metrics exposed on :15090/stats/prometheus                  │
└──────────────────────────────────────────────────────────────┘
```

**Telemetry V2 (Wasm-based):**
- Replaced Mixer (removed in Istio 1.8) with in-proxy Wasm extensions
- Stats filter runs as a WebAssembly module inside each Envoy proxy
- Generates service-level metrics directly in the data plane
- Dramatically lower latency and resource consumption vs Mixer

### 2.2 Istio Standard Metrics

#### HTTP/gRPC Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `istio_requests_total` | Counter | Total requests handled by the proxy |
| `istio_request_duration_milliseconds` | Distribution | Request duration in milliseconds |
| `istio_request_bytes` | Distribution | Request body sizes |
| `istio_response_bytes` | Distribution | Response body sizes |
| `istio_request_messages_total` | Counter | gRPC messages sent per request |
| `istio_response_messages_total` | Counter | gRPC messages received per response |

#### TCP Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `istio_tcp_sent_bytes_total` | Counter | Total bytes sent during TCP connections |
| `istio_tcp_received_bytes_total` | Counter | Total bytes received during TCP connections |
| `istio_tcp_connections_opened_total` | Counter | Total TCP connections opened |
| `istio_tcp_connections_closed_total` | Counter | Total TCP connections closed |

#### Standard Labels (Dimensions)

Every Istio metric includes these labels:

```
# Source labels
source_workload              # e.g., "frontend"
source_workload_namespace    # e.g., "production"
source_principal             # e.g., "spiffe://cluster.local/ns/prod/sa/frontend"
source_app                   # from pod label app=""
source_version               # from pod label version=""
source_cluster               # cluster name (multi-cluster)

# Destination labels
destination_workload         # e.g., "api-server"
destination_workload_namespace # e.g., "production"
destination_principal        # SPIFFE identity
destination_app              # from pod label app=""
destination_version          # from pod label version=""
destination_service          # e.g., "api-server.production.svc.cluster.local"
destination_service_name     # e.g., "api-server"
destination_service_namespace # e.g., "production"
destination_cluster          # cluster name (multi-cluster)

# Request labels
request_protocol             # "http", "grpc", "tcp"
response_code                # HTTP status code (e.g., 200, 503)
grpc_response_status         # gRPC status code
response_flags               # Envoy response flags (e.g., "NR" = no route)
connection_security_policy   # "mutual_tls", "none"

# Reporter
reporter                     # "source" or "destination"
```

### 2.3 PromQL Examples for Istio Metrics

#### Request Rate (Traffic)
```promql
# Total request rate across the mesh
sum(rate(istio_requests_total[5m]))

# Request rate per service
sum(rate(istio_requests_total{reporter="destination"}[5m])) by (destination_service_name)

# Request rate for a specific service
sum(rate(istio_requests_total{
  reporter="destination",
  destination_service_name="api-server"
}[5m]))

# Request rate by source and destination (service graph edges)
sum(rate(istio_requests_total{reporter="destination"}[5m]))
  by (source_workload, destination_service_name)
```

#### Error Rate
```promql
# 5xx error rate per service (percentage)
sum(rate(istio_requests_total{
  reporter="destination",
  response_code=~"5.."
}[5m])) by (destination_service_name)
/
sum(rate(istio_requests_total{
  reporter="destination"
}[5m])) by (destination_service_name)
* 100

# 4xx + 5xx error rate
sum(rate(istio_requests_total{
  reporter="destination",
  response_code=~"[45].."
}[5m])) by (destination_service_name)
/
sum(rate(istio_requests_total{reporter="destination"}[5m])) by (destination_service_name)

# gRPC error rate (non-OK status)
sum(rate(istio_requests_total{
  reporter="destination",
  grpc_response_status!="0",
  request_protocol="grpc"
}[5m])) by (destination_service_name)
/
sum(rate(istio_requests_total{
  reporter="destination",
  request_protocol="grpc"
}[5m])) by (destination_service_name)
```

#### Latency
```promql
# P50 latency per service
histogram_quantile(0.50,
  sum(rate(istio_request_duration_milliseconds_bucket{
    reporter="destination"
  }[5m])) by (destination_service_name, le)
)

# P95 latency per service
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{
    reporter="destination"
  }[5m])) by (destination_service_name, le)
)

# P99 latency per service
histogram_quantile(0.99,
  sum(rate(istio_request_duration_milliseconds_bucket{
    reporter="destination"
  }[5m])) by (destination_service_name, le)
)

# Average request duration
sum(rate(istio_request_duration_milliseconds_sum{reporter="destination"}[5m]))
  by (destination_service_name)
/
sum(rate(istio_request_duration_milliseconds_count{reporter="destination"}[5m]))
  by (destination_service_name)
```

#### TCP Metrics
```promql
# TCP bytes sent rate per service
sum(rate(istio_tcp_sent_bytes_total{reporter="destination"}[5m]))
  by (destination_service_name)

# TCP bytes received rate per service
sum(rate(istio_tcp_received_bytes_total{reporter="destination"}[5m]))
  by (destination_service_name)

# Active TCP connections (opened minus closed)
sum(istio_tcp_connections_opened_total{destination_service_name="redis"})
-
sum(istio_tcp_connections_closed_total{destination_service_name="redis"})

# TCP connection open rate
sum(rate(istio_tcp_connections_opened_total{reporter="destination"}[5m]))
  by (destination_service_name)
```

#### mTLS Coverage
```promql
# Percentage of requests using mTLS
sum(rate(istio_requests_total{
  connection_security_policy="mutual_tls"
}[5m]))
/
sum(rate(istio_requests_total[5m]))
* 100

# Services NOT using mTLS (potential security gap)
sum(rate(istio_requests_total{
  connection_security_policy!="mutual_tls"
}[5m])) by (source_workload, destination_service_name)
```

### 2.4 Istio Alerting Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: istio-mesh-alerts
  namespace: istio-system
spec:
  groups:
  - name: istio.mesh.alerts
    rules:
    # High error rate alert
    - alert: IstioHighErrorRate
      expr: |
        sum(rate(istio_requests_total{
          reporter="destination",
          response_code=~"5.."
        }[5m])) by (destination_service_name, destination_workload_namespace)
        /
        sum(rate(istio_requests_total{
          reporter="destination"
        }[5m])) by (destination_service_name, destination_workload_namespace)
        > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High 5xx error rate for {{ $labels.destination_service_name }}"
        description: "Service {{ $labels.destination_service_name }} in {{ $labels.destination_workload_namespace }} has >5% 5xx error rate (current: {{ $value | humanizePercentage }})"

    # High latency alert (P99 > 1 second)
    - alert: IstioHighP99Latency
      expr: |
        histogram_quantile(0.99,
          sum(rate(istio_request_duration_milliseconds_bucket{
            reporter="destination"
          }[5m])) by (destination_service_name, le)
        ) > 1000
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High P99 latency for {{ $labels.destination_service_name }}"
        description: "P99 latency is {{ $value }}ms (threshold: 1000ms)"

    # Low request rate (potential service down)
    - alert: IstioServiceRequestDrop
      expr: |
        sum(rate(istio_requests_total{reporter="destination"}[5m]))
          by (destination_service_name) == 0
        and
        sum(rate(istio_requests_total{reporter="destination"}[1h] offset 1h))
          by (destination_service_name) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "No traffic to {{ $labels.destination_service_name }}"
        description: "Service received traffic in the past but none in the last 5 minutes"

    # mTLS not enabled
    - alert: IstioMTLSNotEnabled
      expr: |
        sum(rate(istio_requests_total{
          connection_security_policy!="mutual_tls",
          reporter="destination"
        }[5m])) by (source_workload, destination_service_name) > 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Non-mTLS traffic detected"
        description: "Traffic from {{ $labels.source_workload }} to {{ $labels.destination_service_name }} is not using mTLS"

    # Proxy convergence issues
    - alert: IstioPilotProxyConvergenceDelay
      expr: |
        histogram_quantile(0.99,
          sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le)
        ) > 30
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Istio proxy configuration convergence is slow"
        description: "P99 convergence time is {{ $value }}s (threshold: 30s)"
```

### 2.5 Istio Access Logging Configuration

#### Enable Structured JSON Access Logs (Mesh-Wide)

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-access-logging
  namespace: istio-system    # mesh-wide when in istio-system
spec:
  accessLogging:
  - providers:
    - name: envoy
    filter:
      expression: "response.code >= 400 || connection.mtls == false"
```

#### Custom JSON Format (Namespace-Level)

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: json-access-logs
  namespace: production
spec:
  accessLogging:
  - providers:
    - name: envoy
    filter:
      expression: "response.code >= 400"
  - providers:
    - name: otel-collector
```

#### MeshConfig Access Log Format

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    accessLogFile: /dev/stdout
    accessLogEncoding: JSON
    accessLogFormat: |
      {
        "timestamp": "%START_TIME%",
        "method": "%REQ(:METHOD)%",
        "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
        "protocol": "%PROTOCOL%",
        "response_code": "%RESPONSE_CODE%",
        "response_flags": "%RESPONSE_FLAGS%",
        "bytes_received": "%BYTES_RECEIVED%",
        "bytes_sent": "%BYTES_SENT%",
        "duration": "%DURATION%",
        "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
        "upstream_host": "%UPSTREAM_HOST%",
        "upstream_cluster": "%UPSTREAM_CLUSTER%",
        "source_workload": "%REQ(X-ENVOY-PEER-METADATA:NAME)%",
        "destination_service": "%REQ(:AUTHORITY)%",
        "request_id": "%REQ(X-REQUEST-ID)%",
        "trace_id": "%REQ(X-B3-TRACEID)%",
        "span_id": "%REQ(X-B3-SPANID)%",
        "user_agent": "%REQ(USER-AGENT)%",
        "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",
        "connection_security_policy": "%DOWNSTREAM_TLS_VERSION%"
      }
    defaultConfig:
      holdApplicationUntilProxyStarts: true
```

### 2.6 Istio Distributed Tracing Configuration

#### Configure Tracing with OpenTelemetry Collector

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
    extensionProviders:
    - name: otel-tracing
      opentelemetry:
        port: 4317
        service: otel-collector.observability.svc.cluster.local
        resource_detectors:
          environment: {}
    defaultConfig:
      tracing:
        sampling: 100.0    # 1% default; 100% for debugging only
```

#### Telemetry API Tracing Configuration

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-tracing
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: otel-tracing
    randomSamplingPercentage: 1.0
    customTags:
      environment:
        literal:
          value: "production"
      cluster_name:
        environment:
          name: CLUSTER_NAME
          defaultValue: "unknown"
```

#### Per-Service Sampling Override

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: payment-tracing
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-service
  tracing:
  - providers:
    - name: otel-tracing
    randomSamplingPercentage: 100.0    # 100% sampling for critical service
```

#### Headers Applications Must Propagate

```
# B3 format (Zipkin/Jaeger compatible)
x-b3-traceid
x-b3-spanid
x-b3-parentspanid
x-b3-sampled
x-b3-flags

# W3C Trace Context
traceparent
tracestate

# Istio-specific
x-request-id
x-ot-span-context

# Custom baggage
baggage
```

### 2.7 Kiali: Service Topology Visualization

Kiali is the official observability console for Istio, providing:

**Key Features:**
- **Service topology graph**: Real-time visualization of service communication
- **Traffic animation**: Circles for successful requests, red diamonds for errors; density = request rate, speed = response time
- **Health assessment**: Color-coded node/edge health (green = healthy, orange = degraded, red = failing)
- **Configuration validation**: Detects misconfigurations in VirtualServices, DestinationRules, AuthorizationPolicies
- **Distributed tracing integration**: Links to Jaeger/Tempo traces for specific requests
- **Grafana integration**: Deep links to service-specific dashboards

#### Install Kiali

```bash
# Install Kiali with Istio addons
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml

# Access Kiali dashboard
istioctl dashboard kiali

# Or port-forward
kubectl port-forward svc/kiali -n istio-system 20001:20001
```

#### Kiali Configuration

```yaml
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: istio-system
spec:
  auth:
    strategy: openid          # or token, anonymous
  external_services:
    prometheus:
      url: http://prometheus.monitoring:9090
    grafana:
      enabled: true
      url: http://grafana.monitoring:3000
      dashboards:
      - name: "Istio Service Dashboard"
    tracing:
      enabled: true
      provider: tempo          # or jaeger
      in_cluster_url: http://tempo.observability:16685
      use_grpc: true
  server:
    web_root: /kiali
  deployment:
    discovery_selectors:       # Control which namespaces Kiali monitors
      default:
      - matchLabels:
          istio-injection: enabled
    gateway_api_classes:       # Which GatewayClasses to validate
    - className: istio
```

### 2.8 Istio Telemetry API: Customizing Metrics

#### Add Custom Dimensions to Existing Metrics

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: custom-metrics
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    # Add request_host dimension to istio_requests_total
    - match:
        metric: REQUEST_COUNT
        mode: CLIENT_AND_SERVER
      tagOverrides:
        request_host:
          operation: UPSERT
          value: "request.host"
        request_url_path:
          operation: UPSERT
          value: "request.url_path"
    # Add custom dimension to latency metric
    - match:
        metric: REQUEST_DURATION
        mode: SERVER
      tagOverrides:
        upstream_peer:
          operation: UPSERT
          value: "upstream_peer_id.name"
```

#### Remove High-Cardinality Labels to Reduce Metrics Volume

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: reduce-cardinality
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
        mode: CLIENT_AND_SERVER
      tagOverrides:
        source_version:
          operation: REMOVE
        destination_version:
          operation: REMOVE
        source_principal:
          operation: REMOVE
        destination_principal:
          operation: REMOVE
```

#### Disable Specific Metrics

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: disable-tcp-metrics
  namespace: production
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: TCP_SENT_BYTES
      disabled: true
    - match:
        metric: TCP_RECEIVED_BYTES
      disabled: true
```

### 2.9 Istio WasmPlugin for Custom Telemetry

```yaml
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: custom-telemetry
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-server
  url: oci://registry.example.com/wasm/custom-telemetry:v1.0
  imagePullPolicy: IfNotPresent
  phase: STATS                  # Execute during stats phase
  pluginConfig:
    metrics:
    - name: "custom_business_metric"
      type: "counter"
      match:
        request_path: "/api/v1/orders"
    - name: "custom_payload_size"
      type: "histogram"
      match:
        request_method: "POST"
  vmConfig:
    env:
    - name: LOG_LEVEL
      value: info
```

### 2.10 Gateway API Observability in Istio

Istio's Gateway API implementation exposes the same golden signal metrics as sidecar proxies. Kiali provides unified observability across Gateway API resources:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
  namespace: istio-system
  annotations:
    # Enable additional observability
    proxy.istio.io/config: |
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*upstream_rq_.*"
        - ".*downstream_cx_.*"
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-routes
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: istio-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    backendRefs:
    - name: api-server
      port: 8080
```

**Gateway-specific metrics to monitor:**
```promql
# Gateway request rate
sum(rate(istio_requests_total{
  source_workload="production-gateway-istio"
}[5m])) by (destination_service_name)

# Gateway error rate
sum(rate(istio_requests_total{
  source_workload="production-gateway-istio",
  response_code=~"5.."
}[5m]))
/
sum(rate(istio_requests_total{
  source_workload="production-gateway-istio"
}[5m]))

# Gateway latency P95
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{
    source_workload="production-gateway-istio"
  }[5m])) by (le, destination_service_name)
)
```

### 2.11 Istio Multi-Cluster Observability

#### Hierarchical Prometheus Federation

```yaml
# Per-cluster Prometheus (deployed in each cluster)
# Scrapes local Istio metrics
# -----------------------------------------------
# Mesh-wide Prometheus (central aggregator)
# Federates from per-cluster Prometheus instances

# Central Prometheus federation config
scrape_configs:
- job_name: 'istio-mesh-federation'
  honor_labels: true
  metrics_path: '/federate'
  params:
    'match[]':
    - '{__name__=~"istio_.*"}'
    - '{__name__=~"pilot_.*"}'
    - '{__name__=~"galley_.*"}'
    - '{__name__=~"citadel_.*"}'
  static_configs:
  - targets:
    - 'prometheus-cluster-east.monitoring:9090'
    - 'prometheus-cluster-west.monitoring:9090'
    - 'prometheus-cluster-eu.monitoring:9090'
  relabel_configs:
  - source_labels: [__address__]
    regex: 'prometheus-(.+)\.monitoring.*'
    target_label: cluster
    replacement: '${1}'
```

#### Recording Rules for Multi-Cluster Aggregation

```yaml
groups:
- name: istio.multicluster.recording
  rules:
  # Aggregate request rate across clusters
  - record: istio:mesh:request_rate:5m
    expr: |
      sum(rate(istio_requests_total{reporter="destination"}[5m]))
        by (destination_service_name, cluster)

  # Aggregate error rate across clusters
  - record: istio:mesh:error_rate:5m
    expr: |
      sum(rate(istio_requests_total{
        reporter="destination", response_code=~"5.."
      }[5m])) by (destination_service_name, cluster)
      /
      sum(rate(istio_requests_total{
        reporter="destination"
      }[5m])) by (destination_service_name, cluster)

  # Cross-cluster traffic volume
  - record: istio:mesh:cross_cluster_requests:5m
    expr: |
      sum(rate(istio_requests_total{
        source_cluster!="",
        destination_cluster!="",
        source_cluster!=destination_cluster
      }[5m])) by (source_cluster, destination_cluster)
```

### 2.12 Istio Debugging Commands

```bash
# Check proxy sync status across all pods
istioctl proxy-status

# Analyze configuration for issues
istioctl analyze --all-namespaces

# Analyze a specific namespace
istioctl analyze -n production

# Inspect proxy configuration for a specific pod
istioctl proxy-config all <pod-name>.<namespace> -o json

# Check listener configuration
istioctl proxy-config listeners <pod-name>.<namespace>

# Check route configuration
istioctl proxy-config routes <pod-name>.<namespace>

# Check cluster (upstream) configuration
istioctl proxy-config clusters <pod-name>.<namespace>

# Check endpoint configuration
istioctl proxy-config endpoints <pod-name>.<namespace>

# Check secrets (certificates) configuration
istioctl proxy-config secret <pod-name>.<namespace>

# Describe a pod's mesh configuration
istioctl x describe pod <pod-name>.<namespace>

# Enable debug logging on a proxy
istioctl proxy-config log <pod-name>.<namespace> --level=debug

# Reset to default logging
istioctl proxy-config log <pod-name>.<namespace> --level=warning

# Check Envoy stats directly
kubectl exec <pod-name> -c istio-proxy -- \
  curl -s localhost:15000/stats/prometheus | grep istio_requests

# Check Envoy config dump
kubectl exec <pod-name> -c istio-proxy -- \
  curl -s localhost:15000/config_dump > config_dump.json

# Verify mTLS status between services
istioctl x authz check <pod-name>.<namespace>
```

---

## 3. Linkerd Observability

### 3.1 Linkerd Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Control Plane                                │
│  ┌───────────────┐  ┌───────────┐  ┌──────────────────────┐    │
│  │  Destination   │  │ Identity  │  │  Proxy Injector      │    │
│  │   Service      │  │ Service   │  │  (Admission Webhook) │    │
│  │ (svc discovery,│  │ (mTLS CA, │  │  Injects sidecar on  │    │
│  │  service       │  │  cert     │  │  annotated pods      │    │
│  │  profiles,     │  │  signing) │  │                      │    │
│  │  policy)       │  │           │  │                      │    │
│  └───────────────┘  └───────────┘  └──────────────────────┘    │
└──────────────────────────┬─────────────────────────────────────┘
                           │ gRPC (Destination API)
┌──────────────────────────▼─────────────────────────────────────┐
│                       Data Plane                                │
│                                                                 │
│  Pod A                      Pod B                               │
│  ┌──────────────┐          ┌──────────────┐                    │
│  │ Application  │          │ Application  │                    │
│  └──────┬───────┘          └──────┬───────┘                    │
│  ┌──────▼───────┐          ┌──────▼───────┐                    │
│  │ linkerd2-    │◄────────►│ linkerd2-    │                    │
│  │ proxy (Rust) │  mTLS    │ proxy (Rust) │                    │
│  │ ~10MB memory │          │ ~10MB memory │                    │
│  └──────────────┘          └──────────────┘                    │
│                                                                 │
│  Ultralight micro-proxy: purpose-built in Rust                 │
│  ~10MB memory footprint vs Envoy's ~50-100MB                   │
│  Transparent TCP interception via iptables / CNI plugin        │
└─────────────────────────────────────────────────────────────────┘
```

**Key architectural differences from Istio:**
- **Rust-based proxy**: linkerd2-proxy is purpose-built, not a general-purpose proxy like Envoy
- **10x smaller footprint**: ~10MB memory per proxy vs 50-100MB for Envoy
- **No Wasm extensibility**: Simpler but less customizable
- **Automatic protocol detection**: HTTP/1.1, HTTP/2, gRPC detected without configuration
- **Gateway API native**: Service profiles being supplanted by Gateway API types (since Linkerd 2.16)

### 3.2 Linkerd Core Metrics

Linkerd automatically collects golden signal metrics for all meshed traffic:

| Metric | Description | Labels |
|--------|-------------|--------|
| `request_total` | Total request count | deployment, namespace, direction, tls, status_code |
| `response_latency_ms` | Request duration histogram | deployment, namespace, direction, status_code |
| `tcp_open_total` | TCP connections opened | deployment, namespace, peer, tls |
| `tcp_close_total` | TCP connections closed | deployment, namespace, peer, tls, errno |
| `tcp_read_bytes_total` | Bytes read from TCP connections | deployment, namespace, peer, tls |
| `tcp_write_bytes_total` | Bytes written to TCP connections | deployment, namespace, peer, tls |
| `inbound_http_authz_allow_total` | Authorized inbound requests | deployment, namespace, server_authorization |
| `inbound_http_authz_deny_total` | Denied inbound requests | deployment, namespace, server_authorization |

### 3.3 Linkerd CLI Observability Commands

#### `linkerd stat` -- Aggregate Metrics

```bash
# Show golden metrics for all deployments in a namespace
linkerd viz stat deploy -n production

# Output:
# NAME          MESHED   SUCCESS   RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
# api-server    3/3      99.85%    145   3ms           12ms          45ms          24
# frontend      2/2      100.00%   89    1ms           5ms           18ms          12
# payment-svc   2/2      98.50%    34    8ms           45ms          120ms         8
# redis         1/1      100.00%   200   0ms           1ms           2ms           15

# Show metrics for traffic FROM a specific source
linkerd viz stat deploy -n production --from deploy/frontend

# Show metrics for traffic TO a specific destination
linkerd viz stat deploy -n production --to deploy/api-server

# Show route-level metrics (requires ServiceProfile or HTTPRoute)
linkerd viz stat-outbound deploy/frontend -n production

# Show authority-based metrics
linkerd viz stat authority -n production
```

#### `linkerd top` -- Real-Time Top-Like Traffic View

```bash
# Live traffic view for a deployment
linkerd viz top deploy/api-server -n production

# Output (updated in real-time):
# Source                Destination           Method   Path               Count   Best   Worst   Last   Success
# frontend-abc123      api-server-def456     GET      /api/v1/users      145     1ms    89ms    3ms    100.00%
# frontend-abc123      api-server-def456     POST     /api/v1/orders     34      5ms    234ms   12ms   97.06%
# payment-svc-ghi789   api-server-def456     GET      /api/v1/inventory  89      2ms    45ms    4ms    100.00%

# Filter by path
linkerd viz top deploy/api-server -n production --path /api/v1/orders
```

#### `linkerd tap` -- Real-Time Request Inspection

```bash
# Tap all requests to a deployment
linkerd viz tap deploy/api-server -n production

# Output:
# req id=0:0 proxy=in  src=10.244.1.5:38920 dst=10.244.2.8:8080 tls=true :method=GET :authority=api-server.production:8080 :path=/api/v1/users
# rsp id=0:0 proxy=in  src=10.244.1.5:38920 dst=10.244.2.8:8080 tls=true :status=200 latency=3142µs
# end id=0:0 proxy=in  src=10.244.1.5:38920 dst=10.244.2.8:8080 tls=true duration=45µs response-length=1234B

# Tap only failing requests
linkerd viz tap deploy/api-server -n production \
  --method GET --path /api/v1/orders \
  --to-resource deploy/payment-svc

# Tap requests with specific authority
linkerd viz tap ns/production --authority api-server.production.svc.cluster.local

# Output as JSON for programmatic consumption
linkerd viz tap deploy/api-server -n production -o json
```

### 3.4 Linkerd-Viz Extension

```bash
# Install linkerd-viz extension
linkerd viz install | kubectl apply -f -

# Access the dashboard
linkerd viz dashboard

# Components installed:
# - metrics-api: Serves aggregated metrics from Prometheus
# - tap: Real-time request introspection API
# - tap-injector: Injects tap capability into meshed pods
# - web: Dashboard UI
# - prometheus: Metrics collection (can be replaced with external)
```

#### External Prometheus Configuration

```yaml
# values.yaml for linkerd-viz with external Prometheus
prometheus:
  enabled: false               # Disable built-in Prometheus
prometheusUrl: http://prometheus.monitoring.svc.cluster.local:9090

# If Prometheus requires authentication
# prometheusUrl: http://user:password@prometheus.monitoring:9090
```

#### Linkerd Grafana Dashboards

```bash
# Import Linkerd dashboards from Grafana.com
# Dashboard IDs:
# - 15474: Linkerd Top Line
# - 15475: Linkerd Health
# - 15476: Linkerd Deployment
# - 15477: Linkerd Pod
# - 15478: Linkerd Service
# - 15479: Linkerd Route
# - 15480: Linkerd Authority
# - 15481: Linkerd Multicluster

# Configure Grafana access for Linkerd dashboard integration
kubectl create configmap linkerd-grafana-config -n linkerd-viz \
  --from-literal=grafana.url=http://grafana.monitoring:3000
```

### 3.5 Linkerd-Jaeger Extension (Distributed Tracing)

```bash
# Install linkerd-jaeger extension
linkerd jaeger install | kubectl apply -f -

# Configure OpenTelemetry Collector as trace backend
linkerd jaeger install \
  --set collector.config.exporters.otlp.endpoint=otel-collector.observability:4317 \
  | kubectl apply -f -
```

### 3.6 Linkerd Service Profiles (Per-Route Metrics)

```yaml
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: api-server.production.svc.cluster.local
  namespace: production
spec:
  routes:
  - name: GET /api/v1/users
    condition:
      method: GET
      pathRegex: /api/v1/users
    responseClasses:
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
  - name: POST /api/v1/orders
    condition:
      method: POST
      pathRegex: /api/v1/orders
    isRetryable: true
    timeout: 5s
    responseClasses:
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
```

**Note**: As of Linkerd 2.16+, ServiceProfiles are being supplanted by Gateway API types (HTTPRoute), though they remain supported for backward compatibility.

### 3.7 Linkerd Multi-Cluster Observability

```bash
# Install multi-cluster extension
linkerd multicluster install | kubectl apply -f -

# Link two clusters
linkerd multicluster link --cluster-name=cluster-west | \
  kubectl apply -f -

# View multi-cluster gateway metrics
linkerd viz stat deploy -n linkerd-multicluster

# Output includes:
# - gateway_alive: Whether the gateway is reachable
# - gateway_latency_ms: Latency to the remote gateway
# - mirror_service_count: Number of mirrored services
```

**Multi-cluster communication modes:**
- **Hierarchical**: Traffic flows through a gateway; works on any network topology
- **Flat**: Direct pod-to-pod communication; requires flat network between clusters
- **Federated**: Services discoverable across clusters with locality-aware routing

### 3.8 Linkerd vs Istio Observability Comparison

| Capability | Linkerd | Istio |
|-----------|---------|-------|
| **Golden signal metrics** | Automatic (request rate, success rate, latency) | Automatic (request count, duration, size) |
| **Metric customization** | Limited (Prometheus relabeling) | Extensive (Telemetry API, Wasm) |
| **Access logging** | Not built-in (use OTel Collector) | Built-in (Telemetry API, Envoy format) |
| **Distributed tracing** | Via linkerd-jaeger extension | Built-in, multiple backends |
| **Live traffic inspection** | `linkerd tap` (real-time, no storage) | Envoy access logs + Kiali |
| **Service topology** | linkerd-viz dashboard | Kiali (richer visualization) |
| **Per-route metrics** | ServiceProfile / HTTPRoute | VirtualService + Telemetry API |
| **Resource overhead** | ~10MB / proxy, ~10ms CPU | ~50-100MB / proxy, ~100ms CPU |
| **Configuration complexity** | Minimal (opinionated defaults) | Extensive (highly configurable) |
| **Multi-cluster** | Service mirror + gateway metrics | Federation + cross-cluster tracing |
| **OpenTelemetry integration** | Native (since 2025) | Native (extension providers) |

---

## 4. Cilium Service Mesh and Hubble

### 4.1 Cilium Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Cilium Architecture                          │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    Cilium Operator                        │    │
│  │  Manages CiliumNetworkPolicy CRDs, IPAM, node discovery  │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Cilium Agent (DaemonSet per node)            │    │
│  │                                                           │    │
│  │  ┌─────────────────────────────────────────────────┐     │    │
│  │  │            eBPF Programs (in kernel)             │     │    │
│  │  │                                                  │     │    │
│  │  │  XDP ──► TC ingress ──► Socket ──► TC egress    │     │    │
│  │  │   │         │            │            │          │     │    │
│  │  │   ▼         ▼            ▼            ▼          │     │    │
│  │  │ Packet   Network      Connect     Packet        │     │    │
│  │  │ filter   Policy       tracking    redirect      │     │    │
│  │  │          enforce      (L7 parse)                │     │    │
│  │  └─────────────────────────────────────────────────┘     │    │
│  │                                                           │    │
│  │  ┌──────────────────┐  ┌───────────────────────────┐    │    │
│  │  │  Hubble Server   │  │  Envoy Proxy (optional)   │    │    │
│  │  │  (flow observer) │  │  For L7 policy only       │    │    │
│  │  └──────────────────┘  └───────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    Hubble Relay                            │    │
│  │  Cluster-wide flow aggregation from all Hubble servers    │    │
│  │  Provides gRPC API for CLI and UI                         │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                     Hubble UI                             │    │
│  │  Service map visualization, flow inspection               │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

**Key differentiators:**
- **No sidecar proxies**: eBPF programs in the kernel handle networking
- **Kernel-level processing**: Lower latency, higher throughput than userspace proxies
- **Combined CNI + Service Mesh**: Single component for networking, security, and observability
- **L7 parsing in eBPF**: HTTP, gRPC, Kafka, DNS protocol visibility without proxies
- **Optional Envoy**: Only deployed when L7 policy enforcement is needed

### 4.2 Hubble: Network Observability Platform

Hubble is Cilium's built-in observability layer that provides:
- **Flow visibility**: Every network connection, with identity and label metadata
- **Service map**: Real-time topology of service communication
- **DNS awareness**: DNS query/response monitoring and correlation
- **Protocol parsing**: L7 visibility for HTTP, gRPC, Kafka, DNS
- **Policy verdicts**: Which policies allowed/denied each flow

#### Enable Hubble

```bash
# Enable Hubble via Helm
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}" \
  --set hubble.metrics.enableOpenMetrics=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true
```

### 4.3 Hubble Metrics

#### HTTP Metrics (httpV2)

| Metric Name | Type | Description |
|-------------|------|-------------|
| `hubble_http_requests_total` | Counter | Total HTTP requests observed |
| `hubble_http_responses_total` | Counter | Total HTTP responses observed |
| `hubble_http_request_duration_seconds` | Histogram | HTTP request duration |

#### DNS Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `hubble_dns_queries_total` | Counter | Total DNS queries observed |
| `hubble_dns_responses_total` | Counter | Total DNS responses observed |
| `hubble_dns_response_types_total` | Counter | DNS response types (A, AAAA, CNAME, etc.) |

#### TCP Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `hubble_tcp_flags_total` | Counter | TCP flags observed (SYN, FIN, RST) |

#### Flow and Drop Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `hubble_flows_processed_total` | Counter | Total flows processed by Hubble |
| `hubble_drop_total` | Counter | Packets dropped, with reason label |
| `hubble_drop_bytes_total` | Counter | Bytes dropped |

#### ICMP Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `hubble_icmp_total` | Counter | ICMP messages observed |

#### Cilium Agent Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `cilium_datapath_errors_total` | Counter | Datapath errors by type |
| `cilium_drop_count_total` | Counter | Packets dropped by Cilium |
| `cilium_drop_bytes_total` | Counter | Bytes dropped by Cilium |
| `cilium_forward_count_total` | Counter | Packets forwarded |
| `cilium_forward_bytes_total` | Counter | Bytes forwarded |
| `cilium_policy_import_errors_total` | Counter | Policy import errors |
| `cilium_endpoint_count` | Gauge | Number of managed endpoints |
| `cilium_endpoint_regeneration_time_stats_seconds` | Histogram | Endpoint regeneration time |
| `cilium_bpf_map_pressure` | Gauge | BPF map utilization |

### 4.4 PromQL Examples for Cilium/Hubble

```promql
# HTTP request rate per workload
sum(rate(hubble_http_requests_total[5m]))
  by (source_workload, destination_workload)

# HTTP error rate (5xx) per destination
sum(rate(hubble_http_responses_total{status_code=~"5.."}[5m]))
  by (destination_workload)
/
sum(rate(hubble_http_responses_total[5m]))
  by (destination_workload)

# HTTP P95 latency per destination workload
histogram_quantile(0.95,
  sum(rate(hubble_http_request_duration_seconds_bucket[5m]))
    by (destination_workload, le)
)

# DNS query rate per source workload
sum(rate(hubble_dns_queries_total[5m])) by (source_workload)

# DNS NXDOMAIN rate (potential misconfigurations)
sum(rate(hubble_dns_responses_total{rcode="Non-Existent Domain"}[5m]))
  by (source_workload)

# Packet drop rate by reason
sum(rate(hubble_drop_total[5m])) by (reason)

# Top packet drop reasons
topk(5, sum(rate(hubble_drop_total[5m])) by (reason))

# Policy denied flows
sum(rate(hubble_drop_total{reason="POLICY_DENIED"}[5m]))
  by (source_workload, destination_workload)

# TCP RST rate (connection problems)
sum(rate(hubble_tcp_flags_total{flag="RST"}[5m]))
  by (source_workload, destination_workload)

# Cilium agent endpoint count
cilium_endpoint_count

# BPF map pressure (approaching limits)
cilium_bpf_map_pressure > 0.9

# Cilium datapath errors
sum(rate(cilium_datapath_errors_total[5m])) by (reason)
```

### 4.5 Hubble CLI Commands

```bash
# Install Hubble CLI
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all \
  https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-darwin-amd64.tar.gz
tar xzf hubble-darwin-amd64.tar.gz
mv hubble /usr/local/bin/

# Port-forward to Hubble Relay
cilium hubble port-forward &

# Observe all flows
hubble observe

# Filter by namespace
hubble observe --namespace production

# Filter by pod
hubble observe --pod production/api-server-abc123

# Filter by protocol
hubble observe --protocol http
hubble observe --protocol dns
hubble observe --protocol tcp

# Filter by verdict (allowed/denied)
hubble observe --verdict DROPPED
hubble observe --verdict FORWARDED
hubble observe --verdict AUDIT

# Filter by HTTP status code
hubble observe --http-status 500-599

# Filter by HTTP method and path
hubble observe --http-method GET --http-path "/api/v1/users"

# Filter by source and destination
hubble observe \
  --from-pod production/frontend \
  --to-pod production/api-server

# Filter by traffic direction
hubble observe --traffic-direction ingress
hubble observe --traffic-direction egress

# Show DNS queries only
hubble observe --protocol dns --namespace production

# Show only dropped packets
hubble observe --verdict DROPPED --namespace production

# Output as JSON for processing
hubble observe --namespace production -o json

# Output as compact table
hubble observe --namespace production -o table

# Follow mode (streaming)
hubble observe --follow --namespace production

# Show flows from the last 5 minutes
hubble observe --since 5m --namespace production

# Combine multiple filters
hubble observe \
  --namespace production \
  --from-label app=frontend \
  --to-label app=api-server \
  --protocol http \
  --http-status 500-599 \
  --follow

# Get flow statistics
hubble observe --namespace production -o json | \
  jq -r '.flow.verdict' | sort | uniq -c | sort -rn
```

### 4.6 Hubble UI: Service Map Visualization

```bash
# Access Hubble UI
cilium hubble ui

# Or port-forward manually
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Features:
# - Real-time service map with request flows
# - Namespace filtering
# - Protocol breakdown per edge (HTTP, gRPC, DNS, TCP)
# - Flow table with detailed inspection
# - Policy verdict visualization (allowed/denied)
# - Latency and error rate overlays
```

### 4.7 Cilium NetworkPolicy Observability

#### Policy Audit Mode (Test Without Enforcement)

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-ingress-audit
  namespace: production
  annotations:
    # Enable audit mode - log but don't enforce
    policy.cilium.io/audit-mode: "enabled"
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

```bash
# Observe policy verdicts in audit mode
hubble observe --verdict AUDIT --namespace production

# Observe denied flows (when policy is enforced)
hubble observe --verdict DROPPED --namespace production

# Monitor policy verdicts for specific pods
hubble observe \
  --to-pod production/api-server \
  --verdict DROPPED \
  --follow
```

### 4.8 Cilium L7 Visibility

```yaml
# Enable L7 visibility for HTTP, gRPC, and Kafka
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-visibility
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:                    # Enables HTTP L7 parsing
        - method: "GET"
          path: "/api/v1/.*"
        - method: "POST"
          path: "/api/v1/orders"
---
# Kafka L7 visibility
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: kafka-l7-visibility
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: kafka-consumer
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: order-processor
    toPorts:
    - ports:
      - port: "9092"
        protocol: TCP
      rules:
        kafka:                   # Enables Kafka L7 parsing
        - role: "consume"
          topic: "orders"
```

### 4.9 GKE Dataplane V2 Integration (Cilium-Based)

Google Kubernetes Engine (GKE) uses Cilium as the default dataplane (Dataplane V2):

```bash
# Create GKE cluster with Dataplane V2 (Cilium)
gcloud container clusters create my-cluster \
  --enable-dataplane-v2 \
  --zone us-central1-a

# Dataplane V2 includes:
# - Cilium CNI for networking
# - Network policy enforcement via eBPF
# - Built-in logging for network policy decisions
# - GKE-specific Hubble integration

# Enable Hubble observability on GKE Dataplane V2
gcloud container clusters update my-cluster \
  --zone us-central1-a \
  --enable-dataplane-v2-flow-observability

# Access Hubble CLI on GKE
kubectl exec -it -n kube-system ds/anetd -- hubble observe
```

### 4.10 Cilium/Hubble Alerting Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cilium-hubble-alerts
  namespace: kube-system
spec:
  groups:
  - name: cilium.alerts
    rules:
    # High packet drop rate
    - alert: CiliumHighDropRate
      expr: |
        sum(rate(hubble_drop_total[5m])) by (reason) > 100
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High packet drop rate: {{ $labels.reason }}"
        description: "Cilium is dropping {{ $value }} packets/sec due to {{ $labels.reason }}"

    # Policy denied flows spike
    - alert: CiliumPolicyDeniedSpike
      expr: |
        sum(rate(hubble_drop_total{reason="POLICY_DENIED"}[5m]))
          by (source_workload, destination_workload) > 10
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Policy denied traffic spike"
        description: "{{ $labels.source_workload }} to {{ $labels.destination_workload }}: {{ $value }} denied flows/sec"

    # BPF map near capacity
    - alert: CiliumBPFMapPressure
      expr: cilium_bpf_map_pressure > 0.9
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Cilium BPF map near capacity"
        description: "BPF map pressure is {{ $value | humanizePercentage }} on {{ $labels.instance }}"

    # DNS NXDOMAIN spike
    - alert: CiliumDNSNXDomainSpike
      expr: |
        sum(rate(hubble_dns_responses_total{rcode="Non-Existent Domain"}[5m]))
          by (source_workload) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High DNS NXDOMAIN rate from {{ $labels.source_workload }}"

    # Endpoint regeneration slow
    - alert: CiliumSlowEndpointRegeneration
      expr: |
        histogram_quantile(0.99,
          rate(cilium_endpoint_regeneration_time_stats_seconds_bucket[5m])
        ) > 30
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Cilium endpoint regeneration is slow (P99: {{ $value }}s)"
```

---

## 5. Consul Connect Service Mesh

### 5.1 Consul Connect Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Consul Server Cluster                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  Server 1  │  │  Server 2  │  │  Server 3  │            │
│  │  (Leader)  │──│ (Follower) │──│ (Follower) │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  Features:                                                   │
│  - Service catalog & discovery                               │
│  - Intentions (authorization rules)                          │
│  - Certificate Authority (Connect CA)                        │
│  - Key-value store                                           │
│  - Health checking                                           │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                  Consul Client Agents                         │
│                                                              │
│  Node A                       Node B                         │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │ Service A        │        │ Service B        │           │
│  │ ┌──────────────┐ │        │ ┌──────────────┐ │           │
│  │ │ App Container│ │        │ │ App Container│ │           │
│  │ └──────┬───────┘ │        │ └──────┬───────┘ │           │
│  │ ┌──────▼───────┐ │        │ ┌──────▼───────┐ │           │
│  │ │ Envoy Sidecar│◄┼────────┼►│ Envoy Sidecar│ │           │
│  │ │ (Connect     │ │  mTLS  │ │ (Connect     │ │           │
│  │ │  Proxy)      │ │        │ │  Proxy)      │ │           │
│  │ └──────────────┘ │        │ └──────────────┘ │           │
│  └──────────────────┘        └──────────────────┘           │
│                                                              │
│  Consul Agent (per node):                                    │
│  - Registers services with server                            │
│  - Manages sidecar proxy lifecycle                           │
│  - Performs health checks                                    │
│  - Distributes certificates                                  │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 Consul Telemetry Configuration

#### Enable Prometheus Metrics (Helm)

```yaml
# Consul Helm values.yaml
global:
  metrics:
    enabled: true
    enableGatewayMetrics: true
    enableAgentMetrics: true

connectInject:
  enabled: true
  metrics:
    defaultEnabled: true
    defaultEnableMerging: true    # Merge app + Envoy metrics
    defaultMergedMetricsPort: 20100
    defaultPrometheusScrapePort: 20200
    defaultPrometheusScrapePath: /metrics

server:
  extraConfig: |
    {
      "telemetry": {
        "prometheus_retention_time": "60s",
        "disable_hostname": true
      }
    }

ui:
  enabled: true
  metrics:
    enabled: true
    provider: "prometheus"
    baseURL: http://prometheus.monitoring.svc.cluster.local:9090
```

### 5.3 Consul Connect Key Metrics

#### Server Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `consul_raft_leader_lastContact` | Timer | Time since leader last contacted followers |
| `consul_raft_commitTime` | Timer | Time to commit a new entry to Raft log |
| `consul_catalog_service_count` | Gauge | Number of registered services |
| `consul_catalog_service_not_found` | Counter | Service lookup failures |
| `consul_server_isLeader` | Gauge | Whether this server is the leader (1 or 0) |

#### Agent Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `consul_client_rpc` | Counter | RPC requests to Consul server |
| `consul_client_rpc_failed` | Counter | Failed RPC requests |
| `consul_dns_domain_query` | Timer | DNS query response time |
| `consul_agent_checks_passing` | Gauge | Health checks passing |
| `consul_agent_checks_critical` | Gauge | Health checks in critical state |

#### Connect Proxy (Envoy) Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `envoy_cluster_upstream_cx_active` | Gauge | Active connections to upstream |
| `envoy_cluster_upstream_cx_connect_fail` | Counter | Failed connection attempts |
| `envoy_cluster_upstream_rq_total` | Counter | Total requests to upstream |
| `envoy_cluster_upstream_rq_xx` | Counter | Requests by response code class (2xx, 4xx, 5xx) |
| `envoy_cluster_upstream_rq_time` | Histogram | Request duration to upstream |
| `envoy_listener_downstream_cx_active` | Gauge | Active downstream connections |
| `envoy_listener_downstream_cx_total` | Counter | Total downstream connections |
| `envoy_http_downstream_rq_total` | Counter | Total downstream HTTP requests |
| `envoy_http_downstream_rq_xx` | Counter | Downstream requests by response code class |

### 5.4 Consul UI: Service Topology

The Consul UI (since v1.9) provides built-in topology visualization:

```bash
# Access Consul UI
kubectl port-forward svc/consul-ui -n consul 8500:443

# Features:
# - Service topology tab: upstream/downstream visualization
# - Metrics overlay: error rates, request rates, latency (from Prometheus)
# - Intention visualization: allow/deny lines between services
# - Health check status per service instance
# - Configuration drift detection
```

#### Configure Dashboard URL Templates

```hcl
# Consul agent configuration
ui_config {
  enabled = true
  metrics_provider = "prometheus"
  metrics_proxy {
    base_url = "http://prometheus.monitoring:9090"
  }
  dashboard_url_templates {
    service = "https://grafana.example.com/d/consul-svc?var-service={{Service.Name}}&var-dc={{Datacenter}}"
  }
}
```

### 5.5 Consul Intentions (Authorization) Observability

```yaml
# Define service intentions
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: api-server-intentions
spec:
  destination:
    name: api-server
  sources:
  - name: frontend
    action: allow
    permissions:
    - http:
        pathPrefix: /api/v1
        methods: ["GET", "POST"]
      action: allow
  - name: "*"
    action: deny
```

**Monitoring intention enforcement:**
```promql
# Denied connections due to intentions
sum(rate(envoy_cluster_upstream_cx_connect_fail{
  consul_service="api-server"
}[5m])) by (consul_source_service)

# Request rate by intention source
sum(rate(envoy_http_downstream_rq_total{
  consul_service="api-server"
}[5m])) by (consul_source_service)
```

### 5.6 Consul + HashiCorp Ecosystem Integration

#### Consul + Vault (Certificate Management)

```hcl
# Configure Consul to use Vault as the Connect CA
connect {
  ca_provider = "vault"
  ca_config {
    address = "https://vault.example.com:8200"
    token = "s.xxxxxxxx"
    root_pki_path = "connect-root"
    intermediate_pki_path = "connect-intermediate"
    leaf_cert_ttl = "72h"
    rotation_period = "2160h"
    intermediate_cert_ttl = "8760h"
    private_key_type = "ec"
    private_key_bits = 256
  }
}
```

#### Consul + Nomad (Service Mesh on Nomad)

```hcl
# Nomad job with Consul Connect sidecar
job "api-server" {
  group "api" {
    network {
      mode = "bridge"
      port "http" { to = 8080 }
    }

    service {
      name = "api-server"
      port = "http"

      connect {
        sidecar_service {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9102"
            }
          }
        }
      }

      meta {
        envoy_metrics_port = "${NOMAD_HOST_PORT_http}"
      }
    }

    task "api" {
      driver = "docker"
      config {
        image = "api-server:v1"
      }
    }
  }
}
```

---

## 6. eBPF-Based Networking Observability

### 6.1 eBPF Fundamentals for Networking

```
┌────────────────────────────────────────────────────────────────┐
│                    Linux Kernel Networking Stack                 │
│                                                                 │
│  NIC Driver                                                     │
│  ┌──────────────────┐                                          │
│  │  XDP (eXpress    │ ← Earliest hook point, before sk_buff    │
│  │  Data Path)      │   allocation. 3 modes:                   │
│  │                  │   - Native (NIC driver)                   │
│  │                  │   - Generic (kernel fallback)             │
│  │                  │   - Offload (NIC hardware)                │
│  └────────┬─────────┘                                          │
│           ▼                                                     │
│  ┌──────────────────┐                                          │
│  │  TC (Traffic      │ ← After sk_buff allocation               │
│  │  Control) hooks   │   - tc ingress: incoming packets         │
│  │                  │   - tc egress: outgoing packets            │
│  │                  │   Full skb access, conntrack integration   │
│  └────────┬─────────┘                                          │
│           ▼                                                     │
│  ┌──────────────────┐                                          │
│  │  Socket hooks     │ ← Application-level interception         │
│  │  - sock_ops      │   Connect/accept tracking                 │
│  │  - sk_msg        │   Message-level redirection               │
│  │  - cgroup/sock   │   Per-cgroup filtering                    │
│  │  - sk_lookup     │   Socket dispatch                         │
│  └────────┬─────────┘                                          │
│           ▼                                                     │
│  ┌──────────────────┐                                          │
│  │  Kernel probes    │ ← Function-level instrumentation         │
│  │  - kprobe/kretprobe│  Hook any kernel function              │
│  │  - tracepoint     │  Stable kernel trace points              │
│  │  - uprobe/uretprobe│ Hook userspace functions               │
│  │  - USDT           │  User-level static tracepoints           │
│  └──────────────────┘                                          │
└────────────────────────────────────────────────────────────────┘
```

**eBPF advantages for observability:**
- Zero application changes required
- Kernel-level visibility (cannot be bypassed)
- Negligible overhead (eBPF programs are JIT-compiled)
- Protocol parsing without proxies (HTTP, DNS, MySQL, PostgreSQL, Redis, Kafka)
- Works with any language or runtime

### 6.2 Pixie (CNCF Sandbox)

Pixie provides instant Kubernetes-native application observability using eBPF, with no instrumentation required.

#### Supported Protocols (Auto-Traced)

| Protocol | Request Types | Response Types |
|----------|--------------|----------------|
| **HTTP/1.x** | GET, POST, PUT, DELETE, etc. | Status codes, headers, body |
| **HTTP/2 / gRPC** | Unary, streaming | Status codes, trailers |
| **MySQL** | COM_QUERY, COM_STMT_PREPARE | Result sets, errors |
| **PostgreSQL** | Simple/Extended query | Row data, errors |
| **Cassandra (CQL)** | QUERY, EXECUTE, PREPARE | RESULT, ERROR |
| **Redis** | All commands | Responses |
| **Kafka** | Produce, Fetch, Metadata | Responses |
| **DNS** | A, AAAA, CNAME, MX, etc. | Answers, NXDOMAIN |
| **AMQP** | Basic.Publish, Basic.Deliver | Acks |
| **NATS** | PUB, SUB, MSG | Responses |

#### Install Pixie

```bash
# Install Pixie CLI
bash -c "$(curl -fsSL https://withpixie.ai/install.sh)"

# Deploy Pixie to Kubernetes cluster
px deploy

# Or with Helm
helm repo add pixie https://pixie-operator-charts.storage.googleapis.com
helm install pixie pixie/pixie-operator-chart \
  --set clusterName=my-cluster \
  --set deployKey=<deploy-key> \
  --namespace pl \
  --create-namespace
```

#### Pixie PxL Scripts (Query Language)

```python
# HTTP service metrics
import px

# Get HTTP request statistics per service
df = px.DataFrame(table='http_events', start_time='-5m')
df.service = df.ctx['service']
df.latency_ms = df.latency / 1000000  # ns to ms
df = df.groupby('service').agg(
    request_count=('latency', px.count),
    error_count=('resp_status', lambda x: px.sum(x >= 400)),
    avg_latency_ms=('latency_ms', px.mean),
    p50_latency_ms=('latency_ms', px.quantiles, 0.5),
    p99_latency_ms=('latency_ms', px.quantiles, 0.99),
)
df.error_rate = df.error_count / df.request_count
px.display(df, 'service_metrics')
```

```python
# MySQL query analysis
import px

df = px.DataFrame(table='mysql_events', start_time='-5m')
df.service = df.ctx['service']
df.latency_ms = df.latency / 1000000
df = df.groupby(['service', 'req_body']).agg(
    count=('latency', px.count),
    avg_latency_ms=('latency_ms', px.mean),
    p99_latency_ms=('latency_ms', px.quantiles, 0.99),
)
df = df[df.count > 10]  # Only queries with 10+ executions
px.display(df.head(20), 'slow_queries')
```

```python
# DNS error analysis
import px

df = px.DataFrame(table='dns_events', start_time='-15m')
df.service = df.ctx['service']
# Filter for DNS failures
df = df[df.resp_header.rcode != 0]  # Non-zero rcode = error
df = df.groupby(['service', 'req_body']).agg(
    error_count=('latency', px.count),
    avg_latency_ms=('latency', lambda x: px.mean(x) / 1000000),
)
px.display(df, 'dns_errors')
```

#### Pixie Features

- **Live UI**: Real-time dashboard with cluster map, service stats, flamegraphs
- **Continuous profiling**: CPU flamegraphs without any code changes
- **Network traffic map**: Auto-generated service topology
- **Data stays in-cluster**: No data sent to external cloud by default
- **New Relic integration**: Export Pixie data to New Relic for long-term storage

### 6.3 Grafana Beyla

Beyla is Grafana's eBPF-based auto-instrumentation tool that captures RED (Rate, Error, Duration) metrics and trace spans for HTTP/gRPC services without any code changes.

#### How Beyla Works

```
Application Process
  │
  ├── uprobes on HTTP/gRPC library functions
  │   (Go net/http, Java Servlet, Python Flask, Node.js http, etc.)
  │
  ├── kprobes on kernel syscalls
  │   (connect, accept, read, write, close)
  │
  └── Beyla eBPF programs capture:
      - Request method, path, status code
      - Request/response timing
      - Connection metadata (source/dest IP, port)

  Exported as:
  ├── OpenTelemetry metrics (OTLP)
  ├── OpenTelemetry traces (OTLP)
  └── Prometheus metrics (native)
```

#### Beyla Configuration

```yaml
# beyla-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: beyla-config
  namespace: observability
data:
  beyla-config.yml: |
    # Discovery configuration
    open_port: 8080                  # Watch processes listening on port 8080
    # Or use executable name:
    # executable_name: "api-server"

    # OTEL exporter configuration
    otel_metrics_export:
      endpoint: http://otel-collector.observability:4318/v1/metrics
      protocol: http/protobuf
      interval: 15s

    otel_traces_export:
      endpoint: http://otel-collector.observability:4318/v1/traces
      protocol: http/protobuf
      sampler:
        name: parentbased_traceidratio
        arg: "0.1"                   # 10% sampling

    # Prometheus metrics exporter
    prometheus_export:
      port: 9090
      path: /metrics

    # Attributes
    attributes:
      kubernetes:
        enable: true                 # Enrich with K8s metadata
      select:
        # Include specific attributes
        http.request.method: true
        http.response.status_code: true
        url.path: true
        server.port: true
        k8s.namespace.name: true
        k8s.pod.name: true
        k8s.deployment.name: true
        service.name: true

    # Routes: Group URL paths to reduce cardinality
    routes:
      patterns:
      - /api/v1/users/{id}
      - /api/v1/orders/{id}
      - /api/v1/products/{id}
      unmatch: heuristic            # Auto-detect patterns for unmatched paths
```

#### Deploy Beyla as DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: beyla
  namespace: observability
spec:
  selector:
    matchLabels:
      app: beyla
  template:
    metadata:
      labels:
        app: beyla
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      serviceAccountName: beyla
      hostPID: true                  # Required: access host processes
      containers:
      - name: beyla
        image: grafana/beyla:latest
        securityContext:
          privileged: true           # Required: load eBPF programs
          runAsUser: 0
        volumeMounts:
        - name: config
          mountPath: /config
        env:
        - name: BEYLA_CONFIG_PATH
          value: /config/beyla-config.yml
        - name: BEYLA_PRINT_TRACES
          value: "true"
        ports:
        - containerPort: 9090
          name: prometheus
      volumes:
      - name: config
        configMap:
          name: beyla-config
```

#### Beyla Metrics Exported

| Metric | Type | Description |
|--------|------|-------------|
| `http_server_request_duration_seconds` | Histogram | Server-side HTTP request duration |
| `http_server_request_body_size_bytes` | Histogram | Request body size |
| `http_client_request_duration_seconds` | Histogram | Client-side HTTP request duration |
| `rpc_server_duration_seconds` | Histogram | gRPC server request duration |
| `rpc_client_duration_seconds` | Histogram | gRPC client request duration |
| `db_client_operation_duration_seconds` | Histogram | Database client operation duration |
| `dns_client_request_duration_seconds` | Histogram | DNS client request duration |

**Supported languages:** Go, Java, Python, Ruby, Node.js, .NET, Rust, C/C++
**Minimum kernel:** 5.8+

### 6.4 Kepler (Kubernetes Energy Efficiency)

Kepler (Kubernetes-based Efficient Power Level Exporter) uses eBPF to attribute energy consumption to containers, pods, and nodes.

#### Install Kepler

```bash
# Install via Helm
helm repo add kepler https://sustainable-computing-io.github.io/kepler-helm-chart
helm install kepler kepler/kepler \
  --namespace kepler \
  --create-namespace \
  --set serviceMonitor.enabled=true
```

#### Kepler Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `kepler_container_joules_total` | Counter | Total energy consumed by container (joules) |
| `kepler_container_core_joules_total` | Counter | CPU core energy per container |
| `kepler_container_dram_joules_total` | Counter | DRAM energy per container |
| `kepler_container_gpu_joules_total` | Counter | GPU energy per container |
| `kepler_container_package_joules_total` | Counter | CPU package energy per container |
| `kepler_node_core_joules_total` | Counter | Total CPU core energy per node |
| `kepler_node_dram_joules_total` | Counter | Total DRAM energy per node |
| `kepler_node_platform_joules_total` | Counter | Total platform energy per node |

#### Kepler PromQL Examples

```promql
# Energy consumption rate per namespace (watts)
sum(rate(kepler_container_joules_total[5m]))
  by (container_namespace) * 1000

# Top 10 energy-consuming pods
topk(10,
  sum(rate(kepler_container_joules_total[1h]))
    by (pod_name, container_namespace)
)

# CPU energy vs DRAM energy per namespace
sum(rate(kepler_container_core_joules_total[5m])) by (container_namespace)
/
sum(rate(kepler_container_dram_joules_total[5m])) by (container_namespace)

# Energy cost estimation (assuming $0.12/kWh)
sum(rate(kepler_container_joules_total[24h]))
  by (container_namespace) / 3600000 * 0.12
```

### 6.5 Inspektor Gadget

Inspektor Gadget is a collection of eBPF-based tools for debugging and inspecting Kubernetes clusters.

#### Install Inspektor Gadget

```bash
# Install kubectl-gadget plugin
kubectl krew install gadget

# Deploy Inspektor Gadget to cluster
kubectl gadget deploy

# Or via Helm
helm repo add gadget https://inspektor-gadget.github.io/charts
helm install gadget gadget/gadget \
  --namespace gadget \
  --create-namespace
```

#### Key Gadgets for Network Observability

```bash
# Trace DNS queries from a specific namespace
kubectl gadget trace dns -n production

# Output:
# NODE          NAMESPACE    POD                COMM    QR  QTYPE  NAME                           RCODE    LATENCY
# node1         production   frontend-abc123    curl    Q   A      api-server.production.svc...
# node1         production   frontend-abc123    curl    R   A      api-server.production.svc...   NoError  1.2ms

# Trace TCP connections
kubectl gadget trace tcp -n production

# Output:
# NODE    NAMESPACE    POD              COMM     IP   SADDR         DADDR         SPORT   DPORT   TYPE
# node1   production   frontend-abc123  python   4    10.244.1.5    10.244.2.8    38920   8080    connect
# node1   production   frontend-abc123  python   4    10.244.1.5    10.244.2.8    38920   8080    close

# Trace network connections with process info
kubectl gadget trace network -n production

# Capture packets (tcpdump equivalent with K8s enrichment)
kubectl gadget trace tcpdump -n production \
  --podname api-server \
  --iface eth0 \
  --output /tmp/capture.pcap

# Monitor bind operations (services starting to listen)
kubectl gadget trace bind -n production

# Snapshot open sockets
kubectl gadget snapshot socket -n production

# Top TCP connections by bandwidth
kubectl gadget top tcp -n production

# Top DNS queries
kubectl gadget top dns -n production

# Profile CPU (flamegraph generation)
kubectl gadget profile cpu -n production --podname api-server -K
```

### 6.6 Comparison of eBPF Networking Observability Tools

| Feature | Cilium/Hubble | Pixie | Beyla | Kepler | Inspektor Gadget |
|---------|--------------|-------|-------|--------|-----------------|
| **Primary purpose** | CNI + Service Mesh | Full-stack observability | RED metrics + traces | Energy monitoring | Debugging toolkit |
| **CNCF status** | Graduated | Sandbox | N/A (Grafana) | Sandbox | Sandbox |
| **Protocol parsing** | HTTP, gRPC, Kafka, DNS | HTTP, MySQL, PostgreSQL, Redis, Kafka, Cassandra, DNS, gRPC, AMQP, NATS | HTTP, gRPC | N/A | DNS, TCP, HTTP |
| **Metrics export** | Prometheus | Pixie API, New Relic | OTLP, Prometheus | Prometheus | Stdout, JSON |
| **Distributed tracing** | No (flow-level) | Request-level | Yes (OTLP) | No | No |
| **Flamegraphs** | No | Yes (CPU profiling) | No | No | Yes (CPU profiling) |
| **Service map** | Hubble UI | Pixie Live UI | No | No | No |
| **Network policy** | Yes (CiliumNetworkPolicy) | No | No | No | No |
| **Data residency** | In-cluster | In-cluster (default) | Configurable | In-cluster | In-cluster |
| **Resource overhead** | Low (eBPF in kernel) | Medium (per-node agents) | Low (per-node) | Low (per-node) | On-demand |
| **Best for** | Production networking + observability | Dev/debug deep inspection | Adding metrics to any app | Green IT, cost optimization | Troubleshooting |

---

## 7. mTLS and Security Observability in Service Meshes

### 7.1 mTLS Certificate Lifecycle Monitoring

```
Certificate Lifecycle:
┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐
│Issue │───►│Active│───►│ Near │───►│Rotate│───►│ New  │
│      │    │      │    │Expiry│    │      │    │ Cert │
└──────┘    └──────┘    └──────┘    └──────┘    └──────┘
                           │
                           ▼
                    ┌──────────┐
                    │  Alert   │
                    │ if not   │
                    │ rotated  │
                    └──────────┘
```

#### Istio Certificate Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `citadel_server_csr_count` | Counter | CSR requests processed by Citadel CA |
| `citadel_server_success_cert_issuance_count` | Counter | Successful certificate issuances |
| `citadel_server_csr_parsing_err_count` | Counter | CSR parsing errors |
| `citadel_server_id_extraction_err_count` | Counter | Identity extraction errors |
| `citadel_server_authentication_failure_count` | Counter | Authentication failures |
| `pilot_proxy_convergence_time` | Histogram | Time for proxy to receive new config (including certs) |

#### Certificate Expiry Monitoring

```yaml
# Using cert-manager with Prometheus metrics
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-alerts
  namespace: cert-manager
spec:
  groups:
  - name: certificates
    rules:
    # Certificate expiring within 7 days
    - alert: CertificateExpiringSoon
      expr: |
        certmanager_certificate_expiration_timestamp_seconds
        - time() < 7 * 24 * 3600
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Certificate {{ $labels.name }} expiring in less than 7 days"

    # Certificate expired
    - alert: CertificateExpired
      expr: |
        certmanager_certificate_expiration_timestamp_seconds
        - time() < 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Certificate {{ $labels.name }} has expired"

    # Certificate renewal failing
    - alert: CertificateRenewalFailing
      expr: |
        certmanager_certificate_ready_status{condition="False"} == 1
      for: 30m
      labels:
        severity: critical
      annotations:
        summary: "Certificate {{ $labels.name }} renewal is failing"
```

#### Istio mTLS Certificate Inspection

```bash
# Check certificate details for a specific proxy
istioctl proxy-config secret <pod-name>.<namespace>

# Output includes:
# - Certificate chain (root CA, intermediate, leaf)
# - SPIFFE ID (e.g., spiffe://cluster.local/ns/production/sa/api-server)
# - Certificate validity period (NotBefore, NotAfter)
# - Serial number

# Verify mTLS configuration for a workload
istioctl x authz check <pod-name>.<namespace>

# Check PeerAuthentication policies
kubectl get peerauthentication --all-namespaces
```

### 7.2 SPIFFE/SPIRE Identity Monitoring

SPIFFE (Secure Production Identity Framework for Everyone) and SPIRE (SPIFFE Runtime Environment) provide workload identity for service meshes.

#### SPIRE Architecture for Service Mesh

```
┌──────────────────────────────────────────────────────────┐
│                    SPIRE Server                           │
│  - Workload registration                                  │
│  - SVID issuance (X.509 or JWT)                          │
│  - CA operations (signing, rotation)                      │
│  - Attestation policy management                          │
│                                                           │
│  Metrics:                                                 │
│  - spire_server_svid_issued_total                        │
│  - spire_server_attestation_success_total                │
│  - spire_server_attestation_failure_total                │
│  - spire_server_ca_expiry_seconds                        │
│  - spire_server_bundle_propagation_time                  │
└─────────────────────┬────────────────────────────────────┘
                      │ Attestation API
┌─────────────────────▼────────────────────────────────────┐
│                    SPIRE Agent (per node)                  │
│  - Node attestation (proof of identity)                   │
│  - Workload attestation (match pod to registration)       │
│  - SVID rotation and caching                             │
│  - Workload API (Unix domain socket)                      │
│                                                           │
│  Metrics:                                                 │
│  - spire_agent_svid_rotation_total                       │
│  - spire_agent_svid_rotation_error_total                 │
│  - spire_agent_workload_attestation_total                │
│  - spire_agent_workload_attestation_error_total          │
│  - spire_agent_connection_count                          │
└──────────────────────────────────────────────────────────┘
```

#### SPIRE Monitoring Configuration

```yaml
# SPIRE Server with Prometheus telemetry
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-server-config
  namespace: spire
data:
  server.conf: |
    server {
      bind_address = "0.0.0.0"
      bind_port = "8081"
      trust_domain = "example.com"
      data_dir = "/run/spire/data"
      log_level = "INFO"

      ca_ttl = "168h"              # 7 days for intermediate CA
      default_x509_svid_ttl = "4h" # 4 hours for workload SVIDs

      # Telemetry configuration
      telemetry {
        Prometheus {
          host = "0.0.0.0"
          port = 9988
        }
      }
    }
```

#### SPIRE Alerting Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: spire-alerts
  namespace: spire
spec:
  groups:
  - name: spire.identity
    rules:
    # SPIRE server CA certificate expiring
    - alert: SPIREServerCAExpiring
      expr: |
        spire_server_ca_expiry_seconds - time() < 48 * 3600
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "SPIRE server CA certificate expiring in less than 48 hours"

    # SVID rotation failures
    - alert: SPIRESVIDRotationFailures
      expr: |
        rate(spire_agent_svid_rotation_error_total[5m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "SPIRE SVID rotation errors on {{ $labels.instance }}"

    # Workload attestation failures
    - alert: SPIREAttestationFailures
      expr: |
        rate(spire_server_attestation_failure_total[5m]) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "SPIRE attestation failures: {{ $value }}/sec"

    # No SVID issuances (possible connectivity issue)
    - alert: SPIRENoSVIDIssuance
      expr: |
        rate(spire_server_svid_issued_total[30m]) == 0
        and spire_server_svid_issued_total > 0
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "No SPIRE SVIDs issued in the last 30 minutes"
```

### 7.3 TLS Handshake Metrics

#### Envoy TLS Metrics (Istio/Consul)

| Metric | Type | Description |
|--------|------|-------------|
| `envoy_listener_ssl_handshake` | Counter | Successful TLS handshakes |
| `envoy_listener_ssl_connection_error` | Counter | TLS connection errors |
| `envoy_listener_ssl_versions` | Counter | TLS versions negotiated (TLS 1.2, 1.3) |
| `envoy_listener_ssl_ciphers` | Counter | TLS cipher suites negotiated |
| `envoy_listener_ssl_curves` | Counter | TLS curves negotiated |
| `envoy_cluster_ssl_handshake` | Counter | Upstream TLS handshakes |
| `envoy_cluster_ssl_connection_error` | Counter | Upstream TLS errors |

#### TLS Handshake PromQL

```promql
# TLS handshake success rate
sum(rate(envoy_listener_ssl_handshake[5m]))
/
(sum(rate(envoy_listener_ssl_handshake[5m]))
 + sum(rate(envoy_listener_ssl_connection_error[5m])))

# TLS version distribution
sum(rate(envoy_listener_ssl_versions{tag=~"TLSv.*"}[5m])) by (tag)

# TLS connection errors per workload
sum(rate(envoy_listener_ssl_connection_error[5m])) by (pod)

# Handshake error rate alert threshold
sum(rate(envoy_listener_ssl_connection_error[5m]))
/
(sum(rate(envoy_listener_ssl_handshake[5m]))
 + sum(rate(envoy_listener_ssl_connection_error[5m])))
> 0.01  # Alert if > 1% failure rate
```

### 7.4 Authorization Policy Monitoring

#### Istio Authorization Metrics

```promql
# Denied requests by authorization policy
sum(rate(istio_requests_total{
  response_code="403",
  reporter="destination"
}[5m])) by (destination_service_name, source_workload)

# Authorization policy evaluation (via Envoy)
sum(rate(envoy_http_rbac_allowed[5m])) by (pod)
sum(rate(envoy_http_rbac_denied[5m])) by (pod)

# Authorization deny rate per service
sum(rate(envoy_http_rbac_denied[5m])) by (destination_service_name)
/
(sum(rate(envoy_http_rbac_allowed[5m])) by (destination_service_name)
 + sum(rate(envoy_http_rbac_denied[5m])) by (destination_service_name))
```

#### Istio AuthorizationPolicy Example with Observability

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: api-server-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-server
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/api/v1/users*"]
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/admin-panel"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
        paths: ["/api/v1/*"]
---
# Deny-all for unmatched requests (logged as 403)
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-server
  action: DENY
  rules:
  - from:
    - source:
        notPrincipals:
        - "cluster.local/ns/production/sa/frontend"
        - "cluster.local/ns/production/sa/admin-panel"
```

#### Linkerd Authorization Metrics

```promql
# Authorized requests rate
sum(rate(inbound_http_authz_allow_total[5m]))
  by (deployment, server_authorization)

# Denied requests rate
sum(rate(inbound_http_authz_deny_total[5m]))
  by (deployment, server_authorization)

# Authorization deny percentage
sum(rate(inbound_http_authz_deny_total[5m])) by (deployment)
/
(sum(rate(inbound_http_authz_allow_total[5m])) by (deployment)
 + sum(rate(inbound_http_authz_deny_total[5m])) by (deployment))
```

### 7.5 Service-to-Service Authentication Observability

#### Comprehensive mTLS Dashboard Queries

```promql
# === mTLS Coverage Dashboard ===

# Overall mTLS adoption rate
sum(rate(istio_requests_total{connection_security_policy="mutual_tls"}[5m]))
/
sum(rate(istio_requests_total[5m])) * 100

# Services with plaintext (non-mTLS) traffic
sum(rate(istio_requests_total{
  connection_security_policy!="mutual_tls",
  reporter="destination"
}[5m])) by (destination_service_name, source_workload) > 0

# SPIFFE identity usage per service
count(count by (source_principal) (
  rate(istio_requests_total{source_principal!=""}[5m]) > 0
))

# Certificate rotation rate
sum(rate(citadel_server_success_cert_issuance_count[1h]))

# Average certificate age (if using cert-manager)
time() - certmanager_certificate_expiration_timestamp_seconds
  + certmanager_certificate_renewal_time_seconds

# === Security Posture Summary ===

# Services with STRICT mTLS enforcement
count(
  kube_customresource_peerauthentication_info{
    mtls_mode="STRICT"
  }
)

# Services with PERMISSIVE mTLS (accepting plaintext)
count(
  kube_customresource_peerauthentication_info{
    mtls_mode="PERMISSIVE"
  }
)
```

#### Security Observability Alert Summary

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: mesh-security-alerts
  namespace: istio-system
spec:
  groups:
  - name: mesh.security
    rules:
    # Non-mTLS traffic detected in production
    - alert: PlaintextTrafficInProduction
      expr: |
        sum(rate(istio_requests_total{
          connection_security_policy!="mutual_tls",
          destination_workload_namespace="production",
          reporter="destination"
        }[5m])) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Plaintext (non-mTLS) traffic detected in production namespace"

    # TLS handshake failures spike
    - alert: TLSHandshakeFailureSpike
      expr: |
        sum(rate(envoy_listener_ssl_connection_error[5m]))
        /
        (sum(rate(envoy_listener_ssl_handshake[5m]))
         + sum(rate(envoy_listener_ssl_connection_error[5m])))
        > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "TLS handshake failure rate > 5%"

    # Authorization policy violations
    - alert: HighAuthorizationDenyRate
      expr: |
        sum(rate(envoy_http_rbac_denied[5m])) by (pod)
        / (sum(rate(envoy_http_rbac_allowed[5m])) by (pod)
           + sum(rate(envoy_http_rbac_denied[5m])) by (pod))
        > 0.10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High authorization deny rate (>10%) on {{ $labels.pod }}"
```

---

## 8. Comparison Matrix and Selection Guide

### 8.1 Service Mesh Observability Feature Matrix

| Feature | Istio | Linkerd | Cilium/Hubble | Consul Connect |
|---------|-------|---------|---------------|----------------|
| **L7 metrics (HTTP/gRPC)** | Full (Envoy stats) | Full (Rust proxy) | eBPF-based | Envoy-based |
| **TCP metrics** | Full | Full | Full | Full |
| **Distributed tracing** | Built-in (multiple backends) | Extension (linkerd-jaeger) | Not built-in | Via Envoy |
| **Access logging** | Telemetry API (rich) | Not built-in | Hubble flows | Envoy access logs |
| **Service topology** | Kiali (comprehensive) | linkerd-viz dashboard | Hubble UI | Consul UI |
| **Live traffic inspection** | Envoy admin + Kiali | `linkerd tap` (unique) | `hubble observe` | Envoy admin |
| **Metric customization** | Telemetry API + Wasm | Limited | Hubble metric config | Envoy stats |
| **Network policy observability** | N/A (use K8s NetworkPolicy) | N/A | Policy verdicts (native) | Intentions visualization |
| **DNS observability** | Via Envoy | Via proxy | Native (eBPF) | Via Consul DNS |
| **Multi-cluster** | Federation + Thanos | Service mirror + gateway | Cluster Mesh | WAN federation |
| **Resource overhead per proxy** | 50-100MB / 100m CPU | ~10MB / ~10m CPU | 0 (no proxy) | 50-100MB / 100m CPU |
| **Configuration complexity** | High (very flexible) | Low (opinionated) | Medium | Medium |

### 8.2 When to Choose Which

**Choose Istio when:**
- Enterprise environment requiring rich traffic management
- Need extensive metric customization (Telemetry API, WasmPlugin)
- Kiali-level visualization is required
- Multi-cluster with advanced routing needed
- Team has capacity to manage complexity

**Choose Linkerd when:**
- Simplicity and low resource overhead are priorities
- Rust proxy's security profile is valued
- `linkerd tap` for live debugging is needed
- Team prefers opinionated defaults over configuration
- Resource-constrained environments

**Choose Cilium/Hubble when:**
- Already using Cilium as CNI (combine CNI + mesh)
- eBPF performance is critical (no sidecar overhead)
- Deep network visibility (DNS, packet drops, policy verdicts) is needed
- GKE Dataplane V2 environment
- Network policy observability is a primary concern

**Choose Consul Connect when:**
- Multi-platform environments (Kubernetes + VMs + Nomad)
- HashiCorp ecosystem (Vault for certs, Nomad for orchestration)
- Service discovery across multiple datacenters
- Gradual mesh adoption (per-service enrollment)

### 8.3 Consulting Engagement Recommendations

| Client Profile | Recommended Stack | Observability Focus |
|---------------|-------------------|-------------------|
| **Large enterprise, complex routing** | Istio + Kiali + Tempo | Full Telemetry API customization, Kiali dashboards |
| **Startup, resource-conscious** | Linkerd + Grafana | linkerd-viz + external Prometheus, minimal overhead |
| **Platform team, CNI standardization** | Cilium + Hubble + Grafana | Hubble metrics + flows, policy verdicts |
| **Multi-platform (K8s + VMs)** | Consul + Vault + Prometheus | Consul UI topology, Envoy metrics, intention monitoring |
| **Deep debugging, development** | Any mesh + Pixie | Protocol-level inspection, flamegraphs, SQL analysis |
| **Green IT, sustainability** | Any mesh + Kepler | Energy attribution per service, carbon footprint |
| **Zero-trust security audit** | Istio/Linkerd + SPIRE | mTLS coverage, certificate lifecycle, authorization metrics |

---

## References

- [Istio Standard Metrics Reference](https://istio.io/latest/docs/reference/config/metrics/)
- [Istio Telemetry API](https://istio.io/latest/docs/reference/config/telemetry/)
- [Istio Observability Best Practices](https://istio.io/latest/docs/ops/best-practices/observability/)
- [Istio Distributed Tracing](https://istio.io/latest/docs/tasks/observability/distributed-tracing/)
- [Istio Access Logs with Telemetry API](https://istio.io/latest/docs/tasks/observability/logs/telemetry-api/)
- [Istio Multi-Cluster Prometheus Monitoring](https://istio.io/latest/docs/ops/configuration/telemetry/monitoring-multicluster-prometheus/)
- [Istio Ambient Mesh Overview](https://istio.io/latest/docs/ambient/overview/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Linkerd Architecture](https://linkerd.io/2-edge/reference/architecture/)
- [Linkerd Telemetry and Monitoring](https://linkerd.io/2-edge/features/telemetry/)
- [Linkerd with OpenTelemetry](https://linkerd.io/2025/09/09/linkerd-with-opentelemetry/)
- [Linkerd Multi-Cluster Communication](https://linkerd.io/2-edge/features/multicluster/)
- [Cilium Monitoring and Metrics](https://docs.cilium.io/en/stable/observability/metrics/)
- [Hubble Network Observability](https://docs.cilium.io/en/stable/observability/hubble/index.html)
- [Cilium Hubble GitHub](https://github.com/cilium/hubble)
- [Consul Service Mesh Observability](https://developer.hashicorp.com/consul/docs/connect/observability)
- [Consul UI Visualization](https://developer.hashicorp.com/consul/docs/connect/observability/ui-visualization)
- [Pixie GitHub](https://github.com/pixie-io/pixie)
- [Grafana Beyla Documentation](https://grafana.com/docs/beyla/latest/)
- [Kepler GitHub](https://github.com/sustainable-computing-io/kepler)
- [Inspektor Gadget GitHub](https://github.com/inspektor-gadget/inspektor-gadget)
- [SPIFFE/SPIRE Documentation](https://spiffe.io/docs/latest/spire-about/spire-concepts/)
- [eBPF.io - What is eBPF?](https://ebpf.io/what-is-ebpf/)
- [Linkerd vs Istio Comparison](https://www.buoyant.io/linkerd-vs-istio)
- [Service Mesh Comparison 2026](https://reintech.io/blog/kubernetes-service-mesh-comparison-2026-istio-linkerd-cilium)


---

# Part III: Kubernetes, Cloud, and Advanced Networking

---

## 1. Kubernetes Networking Observability

### 1.1 Kubernetes Networking Model Fundamentals

Kubernetes networking is built on four foundational requirements:

1. **Pod-to-Pod**: Every pod gets its own IP address; pods can communicate without NAT
2. **Pod-to-Service**: Services provide stable virtual IPs (ClusterIP) with load balancing
3. **External-to-Service**: NodePort, LoadBalancer, and Ingress expose services externally
4. **Pod-to-External**: Pods can reach external endpoints (with optional NetworkPolicy restrictions)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Networking Layers                       │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  L7: Ingress / Gateway API / Service Mesh                     │    │
│  │  - HTTP routing, TLS termination, path-based routing          │    │
│  │  - Metrics: request_count, request_duration, response_codes   │    │
│  └──────────────────────────────┬───────────────────────────────┘    │
│  ┌──────────────────────────────▼───────────────────────────────┐    │
│  │  L4: Service (ClusterIP / NodePort / LoadBalancer)            │    │
│  │  - kube-proxy: iptables or IPVS rules for VIP → endpoint     │    │
│  │  - Metrics: service_endpoint_count, proxy_sync_latency        │    │
│  └──────────────────────────────┬───────────────────────────────┘    │
│  ┌──────────────────────────────▼───────────────────────────────┐    │
│  │  L3: CNI Plugin (Pod Networking)                              │    │
│  │  - Calico, Cilium, Flannel, AWS VPC CNI, Azure CNI           │    │
│  │  - IP allocation, routing, NetworkPolicy enforcement          │    │
│  └──────────────────────────────┬───────────────────────────────┘    │
│  ┌──────────────────────────────▼───────────────────────────────┐    │
│  │  L2/L1: Node Network (Host, NIC, Switch)                     │    │
│  │  - Node-to-node overlay (VXLAN, GENEVE, WireGuard)            │    │
│  │  - Metrics: node_network_*, conntrack_entries                 │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 kube-proxy Observability

kube-proxy implements Kubernetes Service semantics by programming iptables rules or IPVS virtual servers on each node.

#### 1.2.1 kube-proxy Metrics (iptables mode)

kube-proxy exposes Prometheus metrics on port 10249 by default:

```yaml
# kube-proxy ConfigMap to enable metrics
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    metricsBindAddress: "0.0.0.0:10249"
    mode: "iptables"  # or "ipvs"
    iptables:
      syncPeriod: "30s"
      minSyncPeriod: "1s"
    conntrack:
      maxPerCore: 32768
      min: 131072
```

**Key kube-proxy metrics (iptables mode):**

| Metric | Type | Description |
|--------|------|-------------|
| `kubeproxy_sync_proxy_rules_duration_seconds` | Histogram | Time to sync all iptables rules |
| `kubeproxy_sync_proxy_rules_last_timestamp_seconds` | Gauge | Timestamp of last successful sync |
| `kubeproxy_sync_proxy_rules_iptables_total` | Counter | Number of iptables rules programmed |
| `kubeproxy_sync_proxy_rules_endpoint_changes_total` | Counter | Cumulative endpoint changes processed |
| `kubeproxy_sync_proxy_rules_service_changes_total` | Counter | Cumulative service changes processed |
| `kubeproxy_sync_proxy_rules_no_local_endpoints_total` | Counter | Services with traffic policy=Local but no local endpoints |
| `kubeproxy_network_programming_duration_seconds` | Histogram | Time from API event to iptables rule programmed |

**Critical PromQL queries for kube-proxy:**

```promql
# Rule sync latency (p99) - should be < 5s for iptables, < 1s for IPVS
histogram_quantile(0.99,
  rate(kubeproxy_sync_proxy_rules_duration_seconds_bucket[5m])
)

# Total iptables rules per node - at scale this can reach 20,000+
kubeproxy_sync_proxy_rules_iptables_total

# Network programming delay (time from API change to rule installed)
histogram_quantile(0.99,
  rate(kubeproxy_network_programming_duration_seconds_bucket[5m])
)

# Services with externalTrafficPolicy=Local but no local endpoints
# (causes connection refused for external traffic)
kubeproxy_sync_proxy_rules_no_local_endpoints_total > 0

# Sync failures (proxy rules not being updated)
time() - kubeproxy_sync_proxy_rules_last_timestamp_seconds > 60
```

#### 1.2.2 kube-proxy IPVS Mode Metrics

IPVS mode is recommended for clusters with >1,000 services due to O(1) lookup vs O(n) with iptables:

```yaml
# Switch to IPVS mode
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  scheduler: "rr"  # rr, lc, dh, sh, sed, nq
  syncPeriod: "30s"
  minSyncPeriod: "2s"
  tcpTimeout: "0s"
  tcpFinTimeout: "0s"
  udpTimeout: "0s"
```

**Additional IPVS-specific metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `kubeproxy_sync_proxy_rules_ipvs_services_total` | Gauge | Number of IPVS virtual servers |
| `kubeproxy_sync_proxy_rules_ipvs_destinations_total` | Gauge | Number of IPVS real servers (backends) |

```promql
# IPVS virtual servers count (1:1 with Kubernetes Services)
kubeproxy_sync_proxy_rules_ipvs_services_total

# IPVS backends (should match total endpoint count)
kubeproxy_sync_proxy_rules_ipvs_destinations_total

# Node-level IPVS connection stats (from node_exporter)
node_ipvs_connections_total
node_ipvs_incoming_bytes_total
node_ipvs_outgoing_bytes_total
node_ipvs_incoming_packets_total
```

#### 1.2.3 Conntrack Monitoring

Connection tracking (conntrack) is critical for kube-proxy. Exhaustion causes packet drops:

```promql
# Conntrack table utilization - CRITICAL: alert at 80%
node_nf_conntrack_entries / node_nf_conntrack_entries_limit * 100

# Alert rule for conntrack exhaustion
# Fires when conntrack table is > 80% full
(node_nf_conntrack_entries / node_nf_conntrack_entries_limit) > 0.8

# Conntrack insert failures (packets dropped due to full table)
rate(node_nf_conntrack_stat_insert_failed[5m]) > 0

# Conntrack drops
rate(node_nf_conntrack_stat_drop[5m]) > 0

# Conntrack early drops (table full, dropping oldest)
rate(node_nf_conntrack_stat_early_drop[5m]) > 0
```

**Conntrack tuning for high-traffic clusters:**

```bash
# Check current conntrack limits
sysctl net.netfilter.nf_conntrack_max
sysctl net.netfilter.nf_conntrack_count

# Increase conntrack table (per-node DaemonSet approach)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: sysctl-tuner
spec:
  template:
    spec:
      initContainers:
      - name: sysctl
        image: busybox:1.36
        securityContext:
          privileged: true
        command:
        - sh
        - -c
        - |
          sysctl -w net.netfilter.nf_conntrack_max=524288
          sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=86400
          sysctl -w net.netfilter.nf_conntrack_tcp_timeout_close_wait=3600
```

### 1.3 CoreDNS Observability

CoreDNS is the default DNS server in Kubernetes. DNS failures are the #1 cause of intermittent pod communication issues.

#### 1.3.1 CoreDNS Metrics

CoreDNS exposes Prometheus metrics via the `prometheus` plugin (enabled by default):

```yaml
# CoreDNS Corefile with prometheus plugin
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
        log . {
            class denial error
        }
    }
```

**Key CoreDNS metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `coredns_dns_requests_total` | Counter | Total DNS requests by server, zone, protocol (tcp/udp), family (1=IPv4/2=IPv6), type (A/AAAA/SRV/etc) |
| `coredns_dns_responses_total` | Counter | Responses by server, zone, rcode (NOERROR, NXDOMAIN, SERVFAIL, REFUSED) |
| `coredns_dns_request_duration_seconds` | Histogram | Latency of DNS request processing |
| `coredns_dns_request_size_bytes` | Histogram | Size of DNS requests |
| `coredns_dns_response_size_bytes` | Histogram | Size of DNS responses |
| `coredns_forward_requests_total` | Counter | Requests forwarded to upstream resolvers |
| `coredns_forward_responses_total` | Counter | Responses from upstream, by rcode |
| `coredns_forward_request_duration_seconds` | Histogram | Latency to upstream resolvers |
| `coredns_forward_healthcheck_failures_total` | Counter | Health check failures for upstream resolvers |
| `coredns_cache_hits_total` | Counter | Cache hits by server and type (success, denial) |
| `coredns_cache_misses_total` | Counter | Cache misses |
| `coredns_cache_entries` | Gauge | Current cache entries by type |
| `coredns_panics_total` | Counter | Total panics (should always be 0) |
| `coredns_kubernetes_dns_programming_duration_seconds` | Histogram | Time to program DNS records after K8s API changes |

**Critical PromQL queries for CoreDNS:**

```promql
# DNS request rate per second
sum(rate(coredns_dns_requests_total[5m]))

# SERVFAIL rate (upstream failures) - alert if > 1%
sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
  /
sum(rate(coredns_dns_responses_total[5m]))

# NXDOMAIN rate (nonexistent domains - may indicate misconfigured services)
sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[5m]))

# DNS latency p99 - should be < 10ms for cluster-internal, < 100ms for external
histogram_quantile(0.99,
  sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)
)

# Forward (upstream) latency p99
histogram_quantile(0.99,
  sum(rate(coredns_forward_request_duration_seconds_bucket[5m])) by (le, to)
)

# Cache hit ratio - should be > 80% for internal DNS
sum(rate(coredns_cache_hits_total[5m]))
  /
(sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))

# DNS programming delay after K8s API changes
histogram_quantile(0.99,
  rate(coredns_kubernetes_dns_programming_duration_seconds_bucket[5m])
)

# Upstream health check failures
sum(rate(coredns_forward_healthcheck_failures_total[5m])) by (to) > 0
```

#### 1.3.2 CoreDNS Scaling and ndots Issue

The `ndots:5` default in Kubernetes causes excessive DNS queries (up to 10 lookups per external name):

```yaml
# Pod DNS config to reduce ndots (from 5 to 2)
apiVersion: v1
kind: Pod
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
    - name: single-request-reopen
    - name: timeout
      value: "2"
    - name: attempts
      value: "3"
  dnsPolicy: ClusterFirst
```

**DNS amplification monitoring:**

```promql
# Ratio of external forwards to total requests
# High ratio with ndots:5 indicates unnecessary lookups
sum(rate(coredns_forward_requests_total[5m]))
  /
sum(rate(coredns_dns_requests_total[5m]))

# If this is > 0.5, ndots optimization is needed
```

#### 1.3.3 NodeLocal DNSCache Observability

NodeLocal DNSCache reduces CoreDNS load by caching DNS on each node:

```yaml
# Deploy NodeLocal DNSCache
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-local-dns
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: node-cache
        image: registry.k8s.io/dns/k8s-dns-node-cache:1.23.1
        args:
        - -localip
        - "169.254.20.10"
        - -conf
        - /etc/Corefile
        - -upstreamsvc
        - kube-dns
        - -metrics-listen-address
        - "0.0.0.0:9253"
        ports:
        - containerPort: 9253
          name: metrics
          protocol: TCP
```

```promql
# NodeLocal DNS cache hit rate (should be very high, > 90%)
sum(rate(coredns_cache_hits_total{instance=~".*:9253"}[5m])) by (node)
  /
sum(rate(coredns_dns_requests_total{instance=~".*:9253"}[5m])) by (node)

# Requests served locally vs forwarded to cluster CoreDNS
sum(rate(coredns_forward_requests_total{instance=~".*:9253"}[5m])) by (node)
```

### 1.4 Service and Endpoint Observability

#### 1.4.1 Kubernetes API Server Service Metrics

The API server tracks service and endpoint changes:

```promql
# Endpoint slice changes
rate(apiserver_request_total{resource="endpointslices",verb=~"CREATE|UPDATE|DELETE"}[5m])

# Service changes
rate(apiserver_request_total{resource="services",verb=~"CREATE|UPDATE|DELETE"}[5m])

# Watch events for endpoints (high values indicate endpoint churn)
rate(apiserver_watch_events_total{resource="endpointslices"}[5m])
```

#### 1.4.2 Endpoint Health Monitoring

```promql
# Services with zero ready endpoints (completely broken)
kube_endpoint_address_available == 0

# Services with not-ready endpoints (partially degraded)
kube_endpoint_address_not_ready > 0

# EndpointSlice counts (Kubernetes 1.21+)
kube_endpointslice_endpoints{ready="true"}
kube_endpointslice_endpoints{ready="false"}

# Services where desired replicas != ready endpoints
kube_deployment_spec_replicas
  -
kube_endpoint_address_available
```

### 1.5 Ingress Controller Observability

#### 1.5.1 NGINX Ingress Controller

The NGINX Ingress Controller is the most widely deployed ingress controller (used in ~40% of Kubernetes clusters).

**Enable Prometheus metrics:**

```yaml
# NGINX Ingress Controller Helm values
controller:
  metrics:
    enabled: true
    port: 10254
    serviceMonitor:
      enabled: true
      namespace: monitoring
      additionalLabels:
        release: prometheus
  config:
    # Enable request metrics with detailed labels
    enable-opentelemetry: "true"
    otlp-collector-host: "otel-collector.observability.svc"
    otlp-collector-port: "4317"
    otel-service-name: "nginx-ingress"
    otel-sampler: "AlwaysOn"
    otel-sampler-ratio: "0.1"
    # Access log format with trace context
    log-format-upstream: >-
      $remote_addr - $remote_user [$time_local]
      "$request" $status $body_bytes_sent
      "$http_referer" "$http_user_agent"
      $request_length $request_time
      [$proxy_upstream_name] [$proxy_alternative_upstream_name]
      $upstream_addr $upstream_response_length
      $upstream_response_time $upstream_status
      $req_id $trace_id $span_id
```

**Key NGINX Ingress Controller metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `nginx_ingress_controller_requests` | Counter | Total requests by ingress, namespace, service, status, method |
| `nginx_ingress_controller_request_duration_seconds` | Histogram | Request latency by ingress, namespace, service |
| `nginx_ingress_controller_request_size` | Histogram | Request body size |
| `nginx_ingress_controller_response_size` | Histogram | Response body size |
| `nginx_ingress_controller_bytes_sent` | Histogram | Total bytes sent to clients |
| `nginx_ingress_controller_upstream_latency_seconds` | Summary | Upstream (backend) response time |
| `nginx_ingress_controller_ssl_expire_time_seconds` | Gauge | TLS certificate expiry time (Unix timestamp) |
| `nginx_ingress_controller_success` | Counter | Successfully reloaded NGINX configs |
| `nginx_ingress_controller_config_hash` | Gauge | Current config hash (changes = reload) |
| `nginx_ingress_controller_nginx_process_connections` | Gauge | Current NGINX connections by state (active, reading, writing, waiting) |
| `nginx_ingress_controller_nginx_process_connections_total` | Counter | Total connections (accepted, handled) |

**Critical PromQL queries for NGINX Ingress:**

```promql
# Request rate by ingress
sum(rate(nginx_ingress_controller_requests[5m])) by (ingress, namespace)

# Error rate (5xx) by ingress - alert if > 1%
sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) by (ingress)
  /
sum(rate(nginx_ingress_controller_requests[5m])) by (ingress)

# P99 latency by ingress
histogram_quantile(0.99,
  sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m]))
  by (le, ingress, namespace)
)

# Upstream latency (time NGINX spends waiting for backend)
# Compare with request_duration to identify NGINX overhead vs backend slowness
histogram_quantile(0.99,
  sum(rate(nginx_ingress_controller_upstream_latency_seconds{quantile="0.99"}[5m]))
  by (ingress)
)

# TLS certificate expiry (alert 30 days before expiry)
(nginx_ingress_controller_ssl_expire_time_seconds - time()) / 86400 < 30

# NGINX connection saturation
nginx_ingress_controller_nginx_process_connections{state="active"}
  /
nginx_ingress_controller_nginx_process_connections_total * 100

# Config reload failures (indicates bad Ingress resource)
rate(nginx_ingress_controller_success{result="false"}[5m]) > 0

# Request volume by backend service (identify hot services)
topk(10,
  sum(rate(nginx_ingress_controller_requests[5m])) by (service, namespace)
)
```

#### 1.5.2 Traefik Ingress Controller

Traefik provides built-in Prometheus metrics and OpenTelemetry tracing:

```yaml
# Traefik Helm values for observability
additionalArguments:
  - "--metrics.prometheus=true"
  - "--metrics.prometheus.addEntryPointsLabels=true"
  - "--metrics.prometheus.addRoutersLabels=true"
  - "--metrics.prometheus.addServicesLabels=true"
  - "--metrics.prometheus.buckets=0.005,0.01,0.025,0.05,0.1,0.25,0.5,1.0,2.5,5.0,10.0"
  - "--tracing.otlp=true"
  - "--tracing.otlp.grpc.endpoint=otel-collector.observability.svc:4317"
  - "--tracing.otlp.grpc.insecure=true"
  - "--accesslog=true"
  - "--accesslog.format=json"
  - "--accesslog.fields.headers.defaultmode=keep"
```

**Key Traefik metrics:**

```promql
# Request rate by router and service
sum(rate(traefik_service_requests_total[5m])) by (service)

# Error rate by service
sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) by (service)
  /
sum(rate(traefik_service_requests_total[5m])) by (service)

# Request duration by service
histogram_quantile(0.99,
  sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service)
)

# Open connections by entrypoint
traefik_entrypoint_open_connections

# TLS certificate expiry
(traefik_tls_certs_not_after - time()) / 86400 < 30

# Entrypoint request rate
sum(rate(traefik_entrypoint_requests_total[5m])) by (entrypoint, code)

# Retry count (indicates backend instability)
sum(rate(traefik_service_retries_total[5m])) by (service)
```

#### 1.5.3 Kong Ingress Controller

```yaml
# Kong Helm values for observability
env:
  KONG_STATUS_LISTEN: "0.0.0.0:8100"
  KONG_VITALS: "on"
  KONG_VITALS_STRATEGY: "prometheus"
  KONG_NGINX_HTTP_PROMETHEUS_SERVER_TOKENS: "off"
plugins:
  - name: prometheus
    config:
      per_consumer: true
      status_code_metrics: true
      latency_metrics: true
      bandwidth_metrics: true
      upstream_health_metrics: true
  - name: opentelemetry
    config:
      endpoint: "http://otel-collector.observability.svc:4318/v1/traces"
      resource_attributes:
        service.name: "kong-gateway"
      header_type: "w3c"
```

**Key Kong metrics:**

```promql
# Request rate by service and route
sum(rate(kong_http_requests_total[5m])) by (service, route)

# Latency by service
histogram_quantile(0.99,
  sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service)
)

# Upstream (backend) latency
histogram_quantile(0.99,
  sum(rate(kong_upstream_latency_ms_bucket[5m])) by (le, service)
)

# Kong processing latency (Kong overhead itself)
histogram_quantile(0.99,
  sum(rate(kong_kong_latency_ms_bucket[5m])) by (le, service)
)

# Bandwidth by service
sum(rate(kong_bandwidth_bytes{direction="egress"}[5m])) by (service)

# Upstream health
kong_upstream_target_health{state="healthy"}
kong_upstream_target_health{state="unhealthy"}

# Rate limiting hits
sum(rate(kong_http_requests_total{code="429"}[5m])) by (service, consumer)
```

#### 1.5.4 AWS Load Balancer Controller

The AWS LB Controller provisions ALB/NLB for Kubernetes Ingress/Service resources:

```yaml
# AWS ALB Ingress with enhanced observability
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-attributes: >-
      access_logs.s3.enabled=true,
      access_logs.s3.bucket=my-alb-logs,
      access_logs.s3.prefix=ingress
    # Enable WAF
    alb.ingress.kubernetes.io/wafv2-acl-arn: "arn:aws:wafv2:..."
    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"
```

**AWS ALB metrics available via CloudWatch:**

```promql
# These are available via awscloudwatch receiver in OTel Collector
# See aws-cloudwatch exporter configuration for ALB
# Key CloudWatch metrics:
# - AWS/ApplicationELB:RequestCount
# - AWS/ApplicationELB:TargetResponseTime (p50, p90, p99)
# - AWS/ApplicationELB:HTTPCode_Target_5XX_Count
# - AWS/ApplicationELB:HTTPCode_ELB_5XX_Count
# - AWS/ApplicationELB:HealthyHostCount
# - AWS/ApplicationELB:UnHealthyHostCount
# - AWS/ApplicationELB:ActiveConnectionCount
# - AWS/ApplicationELB:NewConnectionCount
# - AWS/ApplicationELB:RejectedConnectionCount
# - AWS/ApplicationELB:TargetTLSNegotiationErrorCount
```

### 1.6 Gateway API Observability

The Gateway API is the next-generation Kubernetes networking API (graduated to GA for HTTP routing in Kubernetes 1.29):

```yaml
# Gateway API with observability annotations
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
  annotations:
    # Implementation-specific observability settings
    gateway.envoyproxy.io/enable-prometheus: "true"
    gateway.envoyproxy.io/enable-otel: "true"
spec:
  gatewayClassName: envoy
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: production-tls
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
  - name: production-gateway
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-Request-Start
          value: "t=${msec}"
    backendRefs:
    - name: api-service
      port: 8080
      weight: 90
    - name: api-service-canary
      port: 8080
      weight: 10
```

**Gateway API standard metrics (from GEP-1709):**

The Gateway API community is standardizing metrics across implementations:

```promql
# Standard Gateway API metrics (implementation-dependent naming)
# Envoy Gateway example:
envoy_http_downstream_rq_total
envoy_http_downstream_rq_xx{envoy_response_code_class="5"}
envoy_http_downstream_cx_active
envoy_http_downstream_cx_ssl_handshake_total
envoy_cluster_upstream_rq_total
envoy_cluster_upstream_rq_time_bucket

# Gateway resource status conditions for monitoring
# Check via kube-state-metrics custom resource state:
# gateway_status_conditions{type="Accepted",status="True"}
# gateway_status_conditions{type="Programmed",status="True"}
# httproute_status_parents_conditions{type="Accepted",status="True"}
```

### 1.7 Network Policy Monitoring

Kubernetes NetworkPolicy restricts pod-to-pod communication. Monitoring denied connections is critical for security and troubleshooting:

#### 1.7.1 Detecting Blocked Traffic

Most CNIs provide metrics for NetworkPolicy enforcement:

```promql
# Calico - denied packets by policy
sum(rate(calico_denied_packets[5m])) by (policy, srcNamespace, dstNamespace)

# Cilium - dropped packets due to policy
sum(rate(cilium_drop_count_total{reason="POLICY_DENIED"}[5m])) by (direction)

# Cilium - forwarded vs dropped breakdown
sum(rate(cilium_forward_count_total[5m]))  # forwarded
sum(rate(cilium_drop_count_total[5m]))     # dropped (all reasons)
```

#### 1.7.2 Network Policy Auditing

```yaml
# Calico GlobalNetworkPolicy with logging
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: audit-dns
spec:
  tier: security
  order: 100
  selector: all()
  types:
  - Egress
  egress:
  - action: Log
    protocol: UDP
    destination:
      ports:
      - 53
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
---
# Cilium Network Policy with monitoring
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: monitor-frontend
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
  - toEndpoints:
    - matchLabels:
        app: api-server
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
  # All other egress is denied by default
  # Denied connections appear in cilium_drop_count_total
```

### 1.8 Pod Network Troubleshooting Toolkit

#### 1.8.1 Network Debug Pod

```yaml
# Ephemeral debug container (Kubernetes 1.25+)
# Attach to running pod without restarting it
apiVersion: v1
kind: Pod
metadata:
  name: netshoot
  namespace: default
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot:v0.13
    command: ["sleep", "infinity"]
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
        - SYS_PTRACE
```

```bash
# Debug DNS resolution from within a pod
kubectl exec -it netshoot -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it netshoot -- dig +short @10.96.0.10 my-service.my-namespace.svc.cluster.local

# Check connectivity to a service
kubectl exec -it netshoot -- curl -v http://my-service.my-namespace.svc.cluster.local:8080/health

# Check iptables rules (service routing)
kubectl exec -it netshoot -- iptables -t nat -L KUBE-SERVICES -n | head -50

# Trace route to another pod
kubectl exec -it netshoot -- traceroute -n 10.244.2.15

# Capture packets (needs NET_RAW capability)
kubectl exec -it netshoot -- tcpdump -i eth0 -nn port 8080 -c 100

# Check conntrack table
kubectl exec -it netshoot -- conntrack -L | wc -l

# MTU discovery
kubectl exec -it netshoot -- ping -M do -s 1472 10.244.2.15

# Ephemeral debug container (no restart needed, K8s 1.25+)
kubectl debug -it my-pod --image=nicolaka/netshoot --target=my-container -- bash
```

---

## 2. CNI Plugin Observability

### 2.1 Calico Observability

Calico is the most widely deployed CNI plugin, used in approximately 35% of Kubernetes clusters. It supports both overlay (VXLAN, IPIP) and non-overlay (BGP peering) networking modes.

#### 2.1.1 Calico Architecture and Components

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Calico Architecture                            │
│                                                                        │
│  Control Plane:                                                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────┐    │
│  │  calico-kube-     │  │  calico-typha    │  │  calico-apiserver │    │
│  │  controllers      │  │  (K8s datastore  │  │  (CRD management) │    │
│  │  (IP pools, BGP,  │  │   fan-out proxy) │  │                   │    │
│  │   policy sync)    │  │                  │  │                   │    │
│  └──────────────────┘  └────────┬─────────┘  └───────────────────┘    │
│                                 │                                      │
│  Data Plane (per-node DaemonSet):                                      │
│  ┌──────────────────────────────▼─────────────────────────────────┐    │
│  │  calico-node                                                    │    │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌───────────┐  │    │
│  │  │  Felix   │  │  BIRD    │  │  confd       │  │ WireGuard │  │    │
│  │  │  (policy │  │  (BGP    │  │  (template   │  │ (optional │  │    │
│  │  │   agent) │  │   daemon)│  │   rendering) │  │  encrypt) │  │    │
│  │  └──────────┘  └──────────┘  └─────────────┘  └───────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

#### 2.1.2 Felix Metrics

Felix is the core Calico agent running on every node. It programs routes, ACLs, and manages the data plane:

```yaml
# Enable Felix metrics
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  prometheusMetricsEnabled: true
  prometheusMetricsPort: 9091
  prometheusGoMetricsEnabled: true
  prometheusProcessMetricsEnabled: true
  # Dataplane diagnostics
  dataplaneDriver: "auto"  # iptables, nftables, or bpf
  bpfEnabled: false         # Enable eBPF dataplane
  wireguardEnabled: false   # Enable WireGuard encryption
```

**Key Felix metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `felix_active_local_endpoints` | Gauge | Number of active local endpoints (pods) on this node |
| `felix_active_local_policies` | Gauge | Number of active network policies on this node |
| `felix_iptables_save_time_seconds` | Summary | Time to save iptables state |
| `felix_iptables_restore_time_seconds` | Summary | Time to restore iptables rules |
| `felix_iptables_lines_executed` | Counter | Number of iptables rules programmed |
| `felix_ipsets_calico` | Gauge | Number of active Calico IP sets |
| `felix_ipset_calls` | Counter | Number of ipset operations |
| `felix_int_dataplane_apply_time_seconds` | Summary | Time to apply dataplane updates |
| `felix_int_dataplane_failures` | Counter | Dataplane programming failures |
| `felix_route_table_list_seconds` | Summary | Time to list kernel route table |
| `felix_resync_state` | Gauge | Current resync state (0=wait-for-ready, 1=in-sync, 2=resync) |
| `felix_denied_packets` | Counter | Packets denied by Calico policy (by policy name, direction) |
| `felix_calc_graph_update_time_seconds` | Summary | Time to recalculate policy graph |

**Critical PromQL queries for Calico Felix:**

```promql
# Pod count per node (capacity planning)
felix_active_local_endpoints

# Policy count per node
felix_active_local_policies

# Dataplane programming latency (should be < 1s)
histogram_quantile(0.99,
  rate(felix_int_dataplane_apply_time_seconds_bucket[5m])
)

# Dataplane programming failures (should be 0)
rate(felix_int_dataplane_failures[5m]) > 0

# iptables rule count per node (high counts = performance risk)
felix_iptables_lines_executed

# Policy denied packets (security monitoring)
sum(rate(felix_denied_packets[5m])) by (policy)

# Felix resync state (should be 1 = in-sync)
felix_resync_state != 1

# IP set operations rate (high rate = frequent endpoint changes)
rate(felix_ipset_calls[5m])
```

#### 2.1.3 BGP Peering Metrics

When Calico uses BGP (non-overlay mode), BIRD metrics are critical:

```yaml
# Calico BGP configuration
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: 64512
---
# BGP peer for ToR switch
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: tor-switch-peer
spec:
  peerIP: 192.168.1.1
  asNumber: 64513
  node: worker-node-01
```

**BGP monitoring:**

```promql
# BIRD/BGP session state (via calicoctl or custom exporter)
# bird_protocol_up{proto="BGP"} - 1 = established, 0 = down

# Number of BGP routes received
# bird_protocol_routes_imported{proto="BGP"}

# Number of BGP routes advertised
# bird_protocol_routes_exported{proto="BGP"}

# BGP session uptime
# bird_protocol_uptime_seconds{proto="BGP"}
```

```bash
# CLI-based BGP monitoring
# Check BGP peer status
calicoctl node status

# Expected output:
# IPv4 BGP status
# +--------------+-------------------+-------+----------+-------------+
# | PEER ADDRESS |     PEER TYPE     | STATE |  SINCE   |    INFO     |
# +--------------+-------------------+-------+----------+-------------+
# | 10.0.0.2     | node-to-node mesh | up    | 03:01:00 | Established |
# | 10.0.0.3     | node-to-node mesh | up    | 03:01:00 | Established |
# | 192.168.1.1  | global            | up    | 03:01:00 | Established |
# +--------------+-------------------+-------+----------+-------------+
```

#### 2.1.4 Calico WireGuard Encryption Metrics

```yaml
# Enable WireGuard encryption
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  wireguardEnabled: true
  wireguardEnabledV6: true
  wireguardListeningPort: 51820
```

```promql
# WireGuard tunnel metrics (from node_exporter wireguard collector)
node_wireguard_peer_last_handshake_seconds
node_wireguard_peer_receive_bytes_total
node_wireguard_peer_transmit_bytes_total

# WireGuard handshake freshness (alert if > 180s since last handshake)
time() - node_wireguard_peer_last_handshake_seconds > 180
```

### 2.2 Cilium Observability

Cilium is the leading eBPF-based CNI, providing L3/L4/L7 network visibility without sidecar proxies. It is used in approximately 20% of Kubernetes clusters and is the default CNI in GKE Dataplane V2, AKS, and EKS Anywhere.

#### 2.2.1 Cilium Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Cilium Architecture                            │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐      │
│  │  cilium-operator (cluster-scoped)                          │      │
│  │  - IPAM management (cluster-pool, AWS ENI, Azure)          │      │
│  │  - CiliumIdentity garbage collection                       │      │
│  │  - CES (CiliumEndpointSlice) management                   │      │
│  └───────────────────────────┬────────────────────────────────┘      │
│                              │                                       │
│  Per-Node DaemonSet:                                                 │
│  ┌───────────────────────────▼────────────────────────────────┐      │
│  │  cilium-agent                                               │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐   │      │
│  │  │  eBPF        │  │  Hubble      │  │  Envoy (L7     │   │      │
│  │  │  Dataplane   │  │  Observer    │  │   proxy, only   │   │      │
│  │  │  (XDP, TC,   │  │  (flow logs, │  │   for L7 policy)│   │      │
│  │  │   sock_ops)  │  │   DNS, HTTP) │  │                 │   │      │
│  │  └──────────────┘  └──────────────┘  └────────────────┘   │      │
│  └────────────────────────────────────────────────────────────┘      │
│                                                                      │
│  Observability Stack:                                                │
│  ┌──────────────────┐  ┌──────────────────┐                         │
│  │  Hubble Relay    │  │  Hubble UI       │                         │
│  │  (aggregates     │  │  (service map,   │                         │
│  │   flows from     │  │   flow table,    │                         │
│  │   all agents)    │  │   policy viz)    │                         │
│  └──────────────────┘  └──────────────────┘                         │
└─────────────────────────────────────────────────────────────────────┘
```

#### 2.2.2 Cilium Agent Metrics

```yaml
# Enable Cilium metrics via Helm
cilium:
  prometheus:
    enabled: true
    port: 9962
    serviceMonitor:
      enabled: true
  hubble:
    enabled: true
    relay:
      enabled: true
    ui:
      enabled: true
    metrics:
      enabled:
      - dns:query;ignoreAAAA
      - drop
      - tcp
      - flow
      - icmp
      - httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction
      - port-distribution
      dashboards:
        enabled: true
      serviceMonitor:
        enabled: true
    tls:
      auto:
        enabled: true
        method: cronJob
```

**Key Cilium agent metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `cilium_endpoint_count` | Gauge | Number of endpoints (pods) managed |
| `cilium_endpoint_state` | Gauge | Endpoints by state (creating, waiting-for-identity, not-ready, disconnecting, invalid, ready, restoring) |
| `cilium_policy_count` | Gauge | Number of active network policies |
| `cilium_policy_import_errors_total` | Counter | Policy import failures |
| `cilium_policy_l7_total` | Counter | L7 policy verdict by type (HTTP, Kafka, DNS) |
| `cilium_drop_count_total` | Counter | Packets dropped by reason and direction |
| `cilium_drop_bytes_total` | Counter | Bytes dropped |
| `cilium_forward_count_total` | Counter | Packets forwarded by direction |
| `cilium_forward_bytes_total` | Counter | Bytes forwarded |
| `cilium_ip_addresses` | Gauge | IP addresses allocated by family |
| `cilium_bpf_map_pressure` | Gauge | BPF map utilization (0-1) per map name |
| `cilium_datapath_errors_total` | Counter | Datapath errors by area, name, family |
| `cilium_identity_count` | Gauge | Number of security identities |
| `cilium_unreachable_nodes` | Gauge | Nodes that cannot be reached |
| `cilium_controllers_failing` | Gauge | Number of failing internal controllers |
| `cilium_api_limiter_wait_duration_seconds` | Histogram | API rate limiter wait times |
| `cilium_k8s_client_api_calls_total` | Counter | K8s API calls by method and status |

**Critical PromQL queries for Cilium:**

```promql
# Endpoint health (should all be "ready")
cilium_endpoint_state{endpoint_state!="ready"} > 0

# Packet drop rate by reason
topk(10, sum(rate(cilium_drop_count_total[5m])) by (reason))

# Drop reasons breakdown (key reasons to watch):
# POLICY_DENIED - NetworkPolicy blocking traffic
# CT_MAP_INSERTION_FAILED - conntrack table full
# INVALID_PACKET - malformed packets
# NO_TUNNEL_ENDPOINT - missing tunnel endpoint
# STALE_OR_UNROUTABLE - routing issues

# Policy denied traffic (security audit)
sum(rate(cilium_drop_count_total{reason="POLICY_DENIED"}[5m])) by (direction)

# BPF map pressure (alert if > 0.9 for any map)
cilium_bpf_map_pressure > 0.9

# Controller failures (should be 0)
cilium_controllers_failing > 0

# Unreachable nodes (cluster connectivity issues)
cilium_unreachable_nodes > 0

# IP address exhaustion
cilium_ip_addresses{family="ipv4"} /
  on(node) cilium_ipam_available{family="ipv4"} * 100

# K8s API call errors
rate(cilium_k8s_client_api_calls_total{return_code!~"2.."}[5m])

# Datapath errors
rate(cilium_datapath_errors_total[5m]) > 0
```

#### 2.2.3 Hubble Flow Metrics

Hubble provides L3/L4/L7 flow visibility:

```promql
# HTTP request rate by source and destination workload
sum(rate(hubble_http_requests_total[5m])) by (
  source_workload, destination_workload, reporter
)

# HTTP error rate
sum(rate(hubble_http_requests_total{status=~"5.."}[5m])) by (destination_workload)
  /
sum(rate(hubble_http_requests_total[5m])) by (destination_workload)

# HTTP latency
histogram_quantile(0.99,
  sum(rate(hubble_http_request_duration_seconds_bucket[5m]))
  by (le, destination_workload)
)

# DNS query rate and errors
sum(rate(hubble_dns_queries_total[5m])) by (query, qtypes)
sum(rate(hubble_dns_responses_total{rcode!="No Error"}[5m])) by (query, rcode)

# TCP connection stats
sum(rate(hubble_tcp_flags_total{flag="SYN"}[5m])) by (destination_workload)
sum(rate(hubble_tcp_flags_total{flag="RST"}[5m])) by (destination_workload)

# Flow verdict breakdown
sum(rate(hubble_flows_processed_total[5m])) by (verdict)
# verdict: FORWARDED, DROPPED, AUDIT, REDIRECTED, ERROR, TRACED

# Port distribution (identify unexpected ports)
sum(rate(hubble_port_distribution_total[5m])) by (destination_port, protocol)
```

#### 2.2.4 Cilium Operator Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `cilium_operator_ipam_ips` | Gauge | IPs allocated/available by subnet, type |
| `cilium_operator_ipam_allocation_ops` | Counter | IPAM allocation operations |
| `cilium_operator_ipam_interface_creation_ops` | Counter | Network interface creation operations (AWS ENI, Azure) |
| `cilium_operator_eni_available` | Gauge | Available ENIs (AWS) |
| `cilium_operator_eni_deficit` | Gauge | ENI deficit (need more ENIs than available) |
| `cilium_operator_ces_queueing_delay_seconds` | Histogram | CiliumEndpointSlice queueing delay |

### 2.3 Flannel Observability

Flannel is the simplest CNI, providing basic L3 overlay networking. It has minimal built-in metrics:

```yaml
# Flannel configuration with VXLAN backend
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
data:
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI": 1,
        "Port": 8472,
        "DirectRouting": false
      }
    }
```

**Flannel monitoring (primarily via node_exporter and kube metrics):**

```promql
# VXLAN interface statistics
node_network_receive_bytes_total{device="flannel.1"}
node_network_transmit_bytes_total{device="flannel.1"}
node_network_receive_errs_total{device="flannel.1"}
node_network_transmit_errs_total{device="flannel.1"}
node_network_receive_drop_total{device="flannel.1"}

# Flannel pod health
kube_pod_status_ready{namespace="kube-flannel", pod=~"kube-flannel-.*"}

# VXLAN packet overhead (compare flannel.1 vs eth0)
rate(node_network_transmit_bytes_total{device="flannel.1"}[5m])
  /
rate(node_network_transmit_bytes_total{device="eth0"}[5m])
```

### 2.4 AWS VPC CNI Observability

The AWS VPC CNI assigns VPC IP addresses directly to pods, providing native VPC networking without overlay.

#### 2.4.1 Architecture and IP Management

```
┌──────────────────────────────────────────────────────────────────┐
│  AWS VPC CNI Architecture                                         │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  aws-node DaemonSet (per node)                            │    │
│  │  ┌──────────────┐  ┌────────────────────────────────┐    │    │
│  │  │  ipamd        │  │  CNI binary                     │    │    │
│  │  │  (IP Address  │  │  (called by kubelet on pod      │    │    │
│  │  │   Management  │  │   creation/deletion to assign   │    │    │
│  │  │   Daemon)     │  │   IP from warm pool)            │    │    │
│  │  │               │  │                                  │    │    │
│  │  │  Manages:     │  │  Calls ipamd gRPC API:          │    │    │
│  │  │  - ENI attach │  │  - AddNetwork (assign IP)        │    │    │
│  │  │  - IP alloc   │  │  - DelNetwork (release IP)       │    │    │
│  │  │  - Warm pool  │  │                                  │    │    │
│  │  └──────────────┘  └────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ENI Layout (example: m5.xlarge, max 4 ENIs, 15 IPs each):      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │  ENI-0   │  │  ENI-1   │  │  ENI-2   │  │  ENI-3   │        │
│  │  (primary)│  │  (warm)  │  │  (warm)  │  │  (max)   │        │
│  │  14 IPs  │  │  15 IPs  │  │  15 IPs  │  │  15 IPs  │        │
│  │  for pods │  │  for pods│  │  for pods│  │  for pods│        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│  Total: 59 pod IPs per node (minus 1 primary per ENI = 55)      │
└──────────────────────────────────────────────────────────────────┘
```

#### 2.4.2 VPC CNI Metrics

The aws-node DaemonSet exposes metrics on port 61678:

```yaml
# Enable metrics in aws-node
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: aws-node
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: aws-node
        env:
        - name: DISABLE_METRICS
          value: "false"
        - name: ENABLE_POD_ENI
          value: "true"
        - name: WARM_ENI_TARGET
          value: "1"
        - name: WARM_IP_TARGET
          value: "5"
        - name: MINIMUM_IP_TARGET
          value: "2"
        - name: MAX_ENI
          value: "4"
        ports:
        - containerPort: 61678
          name: metrics
```

**Key AWS VPC CNI metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `awscni_total_ip_addresses` | Gauge | Total IPs assigned to ENIs on this node |
| `awscni_assigned_ip_addresses` | Gauge | IPs currently assigned to pods |
| `awscni_eni_allocated` | Gauge | Number of ENIs attached to this node |
| `awscni_eni_max` | Gauge | Maximum ENIs for this instance type |
| `awscni_ip_max` | Gauge | Maximum IPs across all ENIs |
| `awscni_add_ip_req_count` | Counter | IP allocation requests |
| `awscni_del_ip_req_count` | Counter | IP deallocation requests |
| `awscni_aws_api_latency_ms` | Summary | AWS EC2 API call latency |
| `awscni_aws_api_error_count` | Counter | AWS API errors |
| `awscni_ipamd_action_inprogress` | Gauge | In-progress IPAMD actions |
| `awscni_force_removed_enis` | Counter | ENIs forcibly removed |
| `awscni_force_removed_ips` | Counter | IPs forcibly removed |

**Critical PromQL queries for AWS VPC CNI:**

```promql
# IP address utilization per node (CRITICAL: alert at 80%)
awscni_assigned_ip_addresses / awscni_total_ip_addresses * 100

# IP exhaustion: assigned IPs approaching maximum
awscni_assigned_ip_addresses / awscni_ip_max * 100 > 80

# ENI utilization
awscni_eni_allocated / awscni_eni_max * 100

# Warm pool depletion (no spare IPs = slow pod startup)
awscni_total_ip_addresses - awscni_assigned_ip_addresses < 2

# AWS API errors (throttling, permission issues)
rate(awscni_aws_api_error_count[5m]) > 0

# AWS API latency (high latency = slow ENI attachment)
awscni_aws_api_latency_ms{api="AttachNetworkInterface",quantile="0.99"} > 5000

# Force removed ENIs/IPs (indicates problems)
rate(awscni_force_removed_enis[5m]) > 0
rate(awscni_force_removed_ips[5m]) > 0
```

#### 2.4.3 Instance Type IP Limits

A critical operational concern: pod density is limited by instance type:

| Instance Type | Max ENIs | IPs per ENI | Max Pods (IPv4) | Max Pods (Prefix Delegation) |
|---------------|----------|-------------|-----------------|------------------------------|
| t3.medium | 3 | 6 | 17 | 110 |
| m5.large | 3 | 10 | 29 | 110 |
| m5.xlarge | 4 | 15 | 58 | 110 |
| m5.2xlarge | 4 | 15 | 58 | 110 |
| m5.4xlarge | 8 | 30 | 234 | 250 |
| c5.9xlarge | 8 | 30 | 234 | 250 |
| m5.metal | 15 | 50 | 737 | 737 |

### 2.5 Azure CNI Observability

Azure CNI assigns Azure VNet IPs directly to pods:

```yaml
# Azure CNI configuration (AKS)
# In AKS, Azure CNI is configured at cluster creation
# Key metrics are available via Azure Monitor / Container Insights

# Azure CNI Overlay (newer, more IP-efficient)
# Pods get IPs from an overlay network, not VNet directly
# Supports up to 250 pods per node regardless of instance size
```

**Azure CNI monitoring via Azure Monitor:**

```kusto
// KQL query for Azure CNI pod networking issues
ContainerLog
| where LogEntry contains "azure-cni" or LogEntry contains "azure-vnet"
| where LogEntry contains "error" or LogEntry contains "failed"
| project TimeGenerated, Computer, LogEntry
| order by TimeGenerated desc

// IP allocation failures
AzureDiagnostics
| where Category == "kube-controller-manager"
| where log_s contains "failed to allocate" or log_s contains "IP address exhaustion"
```

### 2.6 CNI Comparison Matrix

| Feature | Calico | Cilium | Flannel | AWS VPC CNI | Azure CNI |
|---------|--------|--------|---------|-------------|-----------|
| **Dataplane** | iptables/nftables/eBPF | eBPF | VXLAN/host-gw | Native VPC | Native VNet |
| **Network Policy** | Full (L3/L4 + DNS) | Full (L3/L4/L7 + DNS) | None | Basic (via Calico addon) | Basic (Azure NPM) |
| **Encryption** | WireGuard, IPsec | WireGuard, IPsec | None | VPC encryption (transit) | VNet encryption |
| **Observability** | Felix metrics, flow logs | Hubble (L3-L7 flows), rich metrics | Minimal (node_exporter) | ipamd metrics, CloudWatch | Azure Monitor |
| **BGP Support** | Full (BIRD) | Partial (MetalLB integration) | None | None | None |
| **Multi-cluster** | Federation, Typha | ClusterMesh | None | VPC peering | VNet peering |
| **Performance** | Good (eBPF mode: excellent) | Excellent (native eBPF) | Good | Excellent (no overlay) | Excellent (no overlay) |
| **IP Management** | IPAM pools (Calico IPAM) | Cluster-pool / AWS ENI / Azure | Host-local (/24 per node) | ENI-based (instance limits) | VNet subnet |
| **Max Scale** | 5,000+ nodes | 5,000+ nodes | 500 nodes | Instance-limited | Subnet-limited |
| **Prometheus Metrics** | ~100 metrics | ~200 metrics | ~10 (via node_exporter) | ~15 metrics | Via Azure Monitor |
| **Flow Logging** | Calico Enterprise | Hubble (built-in) | None | VPC Flow Logs | VNet Flow Logs |
| **Grafana Dashboards** | Official | Official (via Hubble) | Community | Community | Azure Workbooks |

---

## 3. Cloud Networking Observability

### 3.1 AWS Networking Observability

#### 3.1.1 VPC Flow Logs (v2 and v5)

VPC Flow Logs capture network traffic metadata for VPC network interfaces:

**Flow Log v2 (default) fields:**

```
version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
```

**Flow Log v5 (enhanced) additional fields:**

```
vpc-id subnet-id instance-id tcp-flags type pkt-srcaddr pkt-dstaddr region az-id sublocation-type sublocation-id pkt-src-aws-service pkt-dst-aws-service flow-direction traffic-path ecs-cluster-arn ecs-cluster-name ecs-container-id ecs-second-container-id ecs-service-name ecs-task-arn ecs-task-definition-arn ecs-task-definition-family ecs-task-definition-revision
```

**Enable VPC Flow Logs with maximum fields (v5):**

```json
{
  "DeliverLogsPermissionArn": "arn:aws:iam::role/VPCFlowLogsRole",
  "LogGroupName": "/aws/vpc/flowlogs",
  "ResourceId": "vpc-1234567890abcdef0",
  "ResourceType": "VPC",
  "TrafficType": "ALL",
  "LogFormat": "${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status} ${vpc-id} ${subnet-id} ${instance-id} ${tcp-flags} ${type} ${pkt-srcaddr} ${pkt-dstaddr} ${region} ${az-id} ${flow-direction} ${traffic-path} ${pkt-src-aws-service} ${pkt-dst-aws-service}",
  "MaxAggregationInterval": 60,
  "DestinationOptions": {
    "FileFormat": "parquet",
    "HiveCompatiblePartitions": true,
    "PerHourPartition": true
  },
  "LogDestinationType": "s3",
  "LogDestination": "arn:aws:s3:::vpc-flow-logs-bucket"
}
```

**OTel Collector configuration for VPC Flow Logs (from S3):**

```yaml
# OTel Collector receiving VPC Flow Logs from S3
receivers:
  awss3:
    s3downloader:
      region: us-east-1
      s3_bucket: vpc-flow-logs-bucket
      s3_prefix: "AWSLogs/"
      start_after: ""
    notification:
      sqs:
        queue_url: https://sqs.us-east-1.amazonaws.com/123456789012/vpc-flow-logs-queue

processors:
  transform/vpc_flowlogs:
    log_statements:
    - context: log
      statements:
      # Parse VPC Flow Log format
      - set(attributes["vpc.flow.version"], Split(body, " ")[0])
      - set(attributes["vpc.flow.account_id"], Split(body, " ")[1])
      - set(attributes["vpc.flow.interface_id"], Split(body, " ")[2])
      - set(attributes["src.address"], Split(body, " ")[3])
      - set(attributes["dst.address"], Split(body, " ")[4])
      - set(attributes["src.port"], Split(body, " ")[5])
      - set(attributes["dst.port"], Split(body, " ")[6])
      - set(attributes["network.protocol"], Split(body, " ")[7])
      - set(attributes["vpc.flow.packets"], Split(body, " ")[8])
      - set(attributes["vpc.flow.bytes"], Split(body, " ")[9])
      - set(attributes["vpc.flow.action"], Split(body, " ")[12])

  filter/vpc_flowlogs:
    logs:
      include:
        match_type: strict
        record_attributes:
        - key: vpc.flow.action
          value: "REJECT"  # Only keep rejected flows for security analysis

exporters:
  opensearch:
    endpoints: ["https://vpc-flowlogs-es.us-east-1.es.amazonaws.com"]
    logs_index: vpc-flow-logs
```

**Athena queries for VPC Flow Log analysis:**

```sql
-- Top rejected source IPs (potential port scanning)
SELECT srcaddr, COUNT(*) as reject_count,
       array_agg(DISTINCT CAST(dstport AS VARCHAR)) as targeted_ports
FROM vpc_flow_logs
WHERE action = 'REJECT'
  AND start >= current_timestamp - interval '1' hour
GROUP BY srcaddr
ORDER BY reject_count DESC
LIMIT 20;

-- Traffic between AZs (cross-AZ data transfer costs)
SELECT az_id,
       SUM(bytes) / 1073741824.0 as gb_transferred,
       COUNT(*) as flow_count
FROM vpc_flow_logs
WHERE flow_direction = 'egress'
  AND start >= current_timestamp - interval '24' hour
GROUP BY az_id
ORDER BY gb_transferred DESC;

-- Identify traffic paths (1=same VPC, 2=same region, 3=inter-region, etc.)
SELECT traffic_path,
       SUM(bytes) / 1073741824.0 as gb_transferred,
       COUNT(*) as flow_count
FROM vpc_flow_logs
WHERE start >= current_timestamp - interval '24' hour
GROUP BY traffic_path;

-- AWS service traffic identification
SELECT pkt_dst_aws_service,
       SUM(bytes) / 1073741824.0 as gb_sent
FROM vpc_flow_logs
WHERE pkt_dst_aws_service != '-'
  AND start >= current_timestamp - interval '24' hour
GROUP BY pkt_dst_aws_service
ORDER BY gb_sent DESC;
```

#### 3.1.2 AWS Transit Gateway Monitoring

Transit Gateway is the central hub for VPC-to-VPC and VPC-to-on-premises connectivity:

```yaml
# OTel Collector for Transit Gateway CloudWatch metrics
receivers:
  awscloudwatch/transit_gateway:
    region: us-east-1
    poll_interval: 60s
    metrics:
      named:
        transit_gateway:
          namespace: AWS/TransitGateway
          period: 300s
          metrics:
          - name: BytesIn
            statistics: [Sum]
          - name: BytesOut
            statistics: [Sum]
          - name: PacketsIn
            statistics: [Sum]
          - name: PacketsOut
            statistics: [Sum]
          - name: PacketDropCountBlackhole
            statistics: [Sum]
          - name: PacketDropCountNoRoute
            statistics: [Sum]
          - name: BytesDropCountBlackhole
            statistics: [Sum]
          - name: BytesDropCountNoRoute
            statistics: [Sum]
          dimensions:
          - name: TransitGateway
            value: tgw-1234567890abcdef0
          - name: TransitGatewayAttachment
            value: "*"
```

**Key Transit Gateway alerts:**

```promql
# Blackhole drops (routing misconfiguration)
aws_transitgateway_packet_drop_count_blackhole_sum > 0

# No-route drops
aws_transitgateway_packet_drop_count_no_route_sum > 0

# Bandwidth utilization by attachment
sum(rate(aws_transitgateway_bytes_in_sum[5m])) by (TransitGatewayAttachment)
```

#### 3.1.3 AWS Direct Connect Monitoring

```yaml
# Direct Connect CloudWatch metrics
receivers:
  awscloudwatch/direct_connect:
    region: us-east-1
    metrics:
      named:
        dx_connection:
          namespace: AWS/DX
          metrics:
          - name: ConnectionState
            statistics: [Maximum]  # 1 = up, 0 = down
          - name: ConnectionBpsEgress
            statistics: [Average, Maximum]
          - name: ConnectionBpsIngress
            statistics: [Average, Maximum]
          - name: ConnectionPpsEgress
            statistics: [Average]
          - name: ConnectionPpsIngress
            statistics: [Average]
          - name: ConnectionCRCErrorCount
            statistics: [Sum]
          - name: ConnectionLightLevelTx
            statistics: [Average]  # dBm
          - name: ConnectionLightLevelRx
            statistics: [Average]  # dBm
          dimensions:
          - name: ConnectionId
            value: dxcon-1234abcd
```

**Direct Connect alerting:**

```promql
# Connection down
aws_dx_connection_state_maximum == 0

# CRC errors (physical layer issue)
rate(aws_dx_connection_crc_error_count_sum[5m]) > 0

# Bandwidth utilization > 80% (1Gbps = 1000000000 bps)
aws_dx_connection_bps_egress_maximum / 1000000000 * 100 > 80

# Optical power degradation (Tx or Rx dropping below threshold)
# Normal range: -14 to +2.5 dBm
aws_dx_connection_light_level_rx_average < -14
```

#### 3.1.4 Route 53 and DNS Observability

```yaml
# Route 53 health check monitoring
receivers:
  awscloudwatch/route53:
    region: us-east-1
    metrics:
      named:
        route53_healthchecks:
          namespace: AWS/Route53
          metrics:
          - name: HealthCheckStatus
            statistics: [Minimum]  # 1 = healthy, 0 = unhealthy
          - name: ConnectionTime
            statistics: [Average, p99]
          - name: SSLHandshakeTime
            statistics: [Average, p99]
          - name: TimeToFirstByte
            statistics: [Average, p99]
          - name: ChildHealthCheckHealthyCount
            statistics: [Minimum]
          dimensions:
          - name: HealthCheckId
            value: "*"
        route53_resolver:
          namespace: AWS/Route53Resolver
          metrics:
          - name: InboundQueryVolume
            statistics: [Sum]
          - name: OutboundQueryVolume
            statistics: [Sum]
          - name: FirewallRuleGroupQueryVolume
            statistics: [Sum]
          - name: FirewallRuleGroupBlockedQueryVolume
            statistics: [Sum]
```

#### 3.1.5 CloudFront Observability

```yaml
# CloudFront real-time monitoring
receivers:
  awscloudwatch/cloudfront:
    region: us-east-1  # CloudFront metrics are in us-east-1
    metrics:
      named:
        cloudfront:
          namespace: AWS/CloudFront
          metrics:
          - name: Requests
            statistics: [Sum]
          - name: BytesDownloaded
            statistics: [Sum]
          - name: BytesUploaded
            statistics: [Sum]
          - name: TotalErrorRate
            statistics: [Average]
          - name: 4xxErrorRate
            statistics: [Average]
          - name: 5xxErrorRate
            statistics: [Average]
          - name: CacheHitRate
            statistics: [Average]
          - name: OriginLatency
            statistics: [Average, p50, p90, p99]
          - name: LambdaExecutionError
            statistics: [Sum]
          - name: LambdaValidationError
            statistics: [Sum]
          dimensions:
          - name: DistributionId
            value: "*"
          - name: Region
            value: Global
```

#### 3.1.6 AWS Network Firewall Monitoring

```yaml
# Network Firewall metrics
receivers:
  awscloudwatch/network_firewall:
    region: us-east-1
    metrics:
      named:
        network_firewall:
          namespace: AWS/NetworkFirewall
          metrics:
          - name: DroppedPackets
            statistics: [Sum]
          - name: PassedPackets
            statistics: [Sum]
          - name: ReceivedPackets
            statistics: [Sum]
          - name: Packets
            statistics: [Sum]
          - name: StreamExceptionPolicyPackets
            statistics: [Sum]
          - name: TLSDroppedPackets
            statistics: [Sum]
          - name: TLSPassedPackets
            statistics: [Sum]
          - name: TLSErrors
            statistics: [Sum]
          - name: TLSRevocationStatusOKConnections
            statistics: [Sum]
          - name: TLSRevocationStatusRevokedConnections
            statistics: [Sum]
          dimensions:
          - name: FirewallName
            value: production-firewall
          - name: AvailabilityZone
            value: "*"
```

#### 3.1.7 AWS Global Accelerator Monitoring

```yaml
receivers:
  awscloudwatch/global_accelerator:
    region: us-west-2
    metrics:
      named:
        global_accelerator:
          namespace: AWS/GlobalAccelerator
          metrics:
          - name: NewFlowCount
            statistics: [Sum]
          - name: ProcessedBytesIn
            statistics: [Sum]
          - name: ProcessedBytesOut
            statistics: [Sum]
          - name: UnhealthyEndpointCount
            statistics: [Maximum]
          dimensions:
          - name: Accelerator
            value: "*"
          - name: Listener
            value: "*"
          - name: EndpointGroup
            value: "*"
```

### 3.2 Azure Networking Observability

#### 3.2.1 Azure VNet Flow Logs (NSG Flow Logs v2)

NSG Flow Logs provide network traffic metadata for Azure Virtual Networks:

```json
// NSG Flow Log v2 format
{
  "records": [
    {
      "time": "2025-01-15T10:00:00.000Z",
      "systemId": "...",
      "macAddress": "00224800A1B2",
      "category": "NetworkSecurityGroupFlowEvent",
      "resourceId": "/SUBSCRIPTIONS/.../NETWORKSECURITYGROUPS/myNSG",
      "operationName": "NetworkSecurityGroupFlowEvents",
      "properties": {
        "Version": 2,
        "flows": [
          {
            "rule": "DefaultRule_AllowInternetOutBound",
            "flows": [
              {
                "mac": "00224800A1B2",
                "flowTuples": [
                  "1673780400,10.0.0.4,13.107.42.14,49152,443,T,O,A,B,1024,2048,10,20"
                ]
              }
            ]
          }
        ]
      }
    }
  ]
}
// v2 flow tuple format:
// timestamp,srcIP,dstIP,srcPort,dstPort,protocol,direction,action,flowState,
// packetsStoD,bytesStoD,packetsDtoS,bytesDtoS
// flowState: B=Begin, C=Continue, E=End
```

**Azure VNet Flow Logs (newer, replacing NSG Flow Logs):**

```bash
# Enable VNet Flow Logs via Azure CLI
az network watcher flow-log create \
  --name myVNetFlowLog \
  --resource-group myRG \
  --vnet myVNet \
  --storage-account myStorageAccount \
  --workspace myLogAnalyticsWorkspace \
  --interval 10 \
  --traffic-analytics true \
  --format JSON \
  --log-version 2
```

**KQL queries for Azure flow log analysis:**

```kusto
// Top denied flows (security investigation)
AzureNetworkAnalytics_CL
| where FlowStatus_s == "D"  // Denied
| summarize DeniedCount = count() by SrcIP_s, DestIP_s, DestPort_d, L7Protocol_s
| order by DeniedCount desc
| take 20

// Cross-region traffic (cost analysis)
AzureNetworkAnalytics_CL
| where SrcRegion_s != DestRegion_s
| summarize BytesTransferred = sum(BytesSentFromSource_d + BytesSentFromDestination_d),
            FlowCount = count()
  by SrcRegion_s, DestRegion_s
| order by BytesTransferred desc

// Traffic analytics - application protocol breakdown
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| summarize TotalBytes = sum(BytesSentFromSource_d), FlowCount = count()
  by L7Protocol_s
| order by TotalBytes desc

// Identify public IP communication
AzureNetworkAnalytics_CL
| where FlowType_s == "ExternalPublic"
| summarize BytesOut = sum(BytesSentFromSource_d),
            BytesIn = sum(BytesSentFromDestination_d),
            Count = count()
  by DestIP_s
| order by BytesOut desc
```

#### 3.2.2 Azure ExpressRoute Monitoring

```yaml
# Azure ExpressRoute metrics via azuremonitor receiver
receivers:
  azuremonitor/expressroute:
    subscription_id: "${AZURE_SUBSCRIPTION_ID}"
    tenant_id: "${AZURE_TENANT_ID}"
    client_id: "${AZURE_CLIENT_ID}"
    client_secret: "${AZURE_CLIENT_SECRET}"
    resource_groups:
    - "networking-rg"
    services:
    - "Microsoft.Network/expressRouteCircuits"
    metrics:
    - name: "ArpAvailability"      # ARP availability percentage
    - name: "BgpAvailability"      # BGP availability percentage
    - name: "BitsInPerSecond"      # Ingress bits per second
    - name: "BitsOutPerSecond"     # Egress bits per second
    - name: "DroppedInBitsPerSecond"
    - name: "DroppedOutBitsPerSecond"
    - name: "GlobalReachBitsInPerSecond"
    - name: "GlobalReachBitsOutPerSecond"
    collection_interval: 60s
```

**ExpressRoute alerting:**

```kusto
// ExpressRoute BGP session drops
AzureMetrics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where ResourceType == "EXPRESSROUTECIRCUITS"
| where MetricName == "BgpAvailability"
| where Average < 100
| project TimeGenerated, Resource, Average
| order by TimeGenerated desc

// ExpressRoute circuit utilization
AzureMetrics
| where MetricName == "BitsInPerSecond" or MetricName == "BitsOutPerSecond"
| where ResourceType == "EXPRESSROUTECIRCUITS"
| extend UtilizationPct = Average / (1000000000.0) * 100  // Assuming 1Gbps circuit
| where UtilizationPct > 80
```

#### 3.2.3 Azure Front Door Monitoring

```kusto
// Azure Front Door latency analysis
AzureDiagnostics
| where ResourceType == "FRONTDOORS"
| where Category == "FrontdoorAccessLog"
| extend BackendLatency = todouble(timeTaken_d) * 1000
| summarize
    P50 = percentile(BackendLatency, 50),
    P90 = percentile(BackendLatency, 90),
    P99 = percentile(BackendLatency, 99),
    ErrorRate = countif(httpStatusCode_d >= 500) * 100.0 / count(),
    RequestCount = count()
  by bin(TimeGenerated, 5m), routingRuleName_s
| order by TimeGenerated desc

// WAF block analysis
AzureDiagnostics
| where ResourceType == "FRONTDOORS"
| where Category == "FrontdoorWebApplicationFirewallLog"
| where action_s == "Block"
| summarize BlockCount = count() by ruleName_s, clientIP_s, requestUri_s
| order by BlockCount desc
```

#### 3.2.4 Azure Firewall Monitoring

```kusto
// Azure Firewall denied flows
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule" or Category == "AzureFirewallApplicationRule"
| where msg_s contains "Deny"
| parse msg_s with Protocol " request from " SourceIP ":" SourcePort " to " DestIP ":" DestPort ". Action: " Action "." *
| summarize DenyCount = count() by SourceIP, DestIP, DestPort, Protocol
| order by DenyCount desc

// Azure Firewall throughput
AzureMetrics
| where ResourceType == "AZUREFIREWALLS"
| where MetricName == "Throughput"
| summarize AvgThroughput = avg(Average), MaxThroughput = max(Maximum)
  by bin(TimeGenerated, 5m), Resource
```

#### 3.2.5 Azure Network Watcher

Network Watcher provides NSG diagnostics, connection troubleshooting, and packet capture:

```bash
# Connection troubleshooting
az network watcher test-connectivity \
  --source-resource myVM \
  --dest-resource myTargetVM \
  --dest-port 443 \
  --protocol TCP

# IP flow verify (check if NSG allows/denies traffic)
az network watcher test-ip-flow \
  --vm myVM \
  --direction Inbound \
  --local 10.0.0.4:* \
  --remote 10.1.0.4:443 \
  --protocol TCP

# Next hop (routing diagnostics)
az network watcher show-next-hop \
  --vm myVM \
  --source-ip 10.0.0.4 \
  --dest-ip 10.1.0.4

# Packet capture (for deep diagnosis)
az network watcher packet-capture create \
  --resource-group myRG \
  --vm myVM \
  --name myCapture \
  --duration-in-seconds 300 \
  --storage-account myStorageAccount \
  --filters '[{"protocol":"TCP", "remoteIPAddress":"10.1.0.0/24", "localPort":"443"}]'
```

### 3.3 GCP Networking Observability

#### 3.3.1 VPC Flow Logs

```yaml
# Enable VPC Flow Logs for a subnet
resource "google_compute_subnetwork" "production" {
  name          = "production-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.production.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"  # 5s, 10s, 30s, 1min, 5min, 10min, 15min
    flow_sampling        = 0.5               # 50% sampling (cost control)
    metadata             = "INCLUDE_ALL_METADATA"
    metadata_fields      = []                # Empty = all fields
    filter_expr          = "true"            # Can filter: "inIpRange(connection.src_ip, '10.0.0.0/8')"
  }
}
```

**BigQuery analysis of GCP VPC Flow Logs:**

```sql
-- Top talkers by bytes transferred
SELECT
  connection.src_ip,
  connection.dest_ip,
  connection.dest_port,
  connection.protocol,
  SUM(bytes_sent) as total_bytes,
  COUNT(*) as flow_count
FROM `project.dataset.compute_googleapis_com_vpc_flows_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1, 2, 3, 4
ORDER BY total_bytes DESC
LIMIT 20;

-- Denied traffic (requires Firewall Rules Logging)
SELECT
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  jsonPayload.connection.dest_port,
  jsonPayload.disposition,
  COUNT(*) as deny_count
FROM `project.dataset.compute_googleapis_com_firewall_*`
WHERE jsonPayload.disposition = 'DENIED'
  AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1, 2, 3, 4
ORDER BY deny_count DESC;

-- Inter-region traffic (cost analysis)
SELECT
  src_location.region as src_region,
  dest_location.region as dest_region,
  SUM(bytes_sent) / 1073741824 as gb_transferred,
  COUNT(*) as flow_count
FROM `project.dataset.compute_googleapis_com_vpc_flows_*`
WHERE src_location.region != dest_location.region
  AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY 1, 2
ORDER BY gb_transferred DESC;
```

#### 3.3.2 Cloud Interconnect Monitoring

```yaml
# GCP Cloud Interconnect monitoring via googlecloudmonitoring receiver
receivers:
  googlecloudmonitoring/interconnect:
    project_id: my-project
    metrics_list:
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/operational_status"
    - metric_name: "interconnect.googleapis.com/network/interconnect/receive_power"
    - metric_name: "interconnect.googleapis.com/network/interconnect/send_power"
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/rx_bytes_count"
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/tx_bytes_count"
    - metric_name: "interconnect.googleapis.com/network/interconnect/attachment/received_bytes_count"
    - metric_name: "interconnect.googleapis.com/network/interconnect/attachment/sent_bytes_count"
    - metric_name: "interconnect.googleapis.com/network/interconnect/attachment/capacity"
    collection_interval: 60s
```

#### 3.3.3 Cloud CDN Monitoring

```yaml
receivers:
  googlecloudmonitoring/cdn:
    project_id: my-project
    metrics_list:
    - metric_name: "loadbalancing.googleapis.com/https/request_count"
    - metric_name: "loadbalancing.googleapis.com/https/total_latencies"
    - metric_name: "loadbalancing.googleapis.com/https/backend_latencies"
    - metric_name: "loadbalancing.googleapis.com/https/request_bytes_count"
    - metric_name: "loadbalancing.googleapis.com/https/response_bytes_count"
    - metric_name: "loadbalancing.googleapis.com/https/backend_request_count"
    # CDN-specific
    - metric_name: "loadbalancing.googleapis.com/https/cdn/cache_hit_count"
    - metric_name: "loadbalancing.googleapis.com/https/cdn/cache_miss_count"
    - metric_name: "loadbalancing.googleapis.com/https/cdn/origin_latencies"
    collection_interval: 60s
```

#### 3.3.4 Cloud NAT Monitoring

```yaml
receivers:
  googlecloudmonitoring/nat:
    project_id: my-project
    metrics_list:
    # NAT gateway metrics
    - metric_name: "router.googleapis.com/nat/new_connections_count"
    - metric_name: "router.googleapis.com/nat/closed_connections_count"
    - metric_name: "router.googleapis.com/nat/dropped_sent_packets_count"
    - metric_name: "router.googleapis.com/nat/dropped_received_packets_count"
    - metric_name: "router.googleapis.com/nat/port_usage"
    - metric_name: "router.googleapis.com/nat/nat_allocation_failed"
    - metric_name: "router.googleapis.com/nat/sent_bytes_count"
    - metric_name: "router.googleapis.com/nat/received_bytes_count"
    # VM-level NAT metrics
    - metric_name: "compute.googleapis.com/nat/allocated_ports"
    - metric_name: "compute.googleapis.com/nat/port_usage"
    collection_interval: 60s
```

**Cloud NAT alerting (port exhaustion is the #1 issue):**

```
# MQL alert for NAT port exhaustion
fetch nat_gateway
| metric 'router.googleapis.com/nat/port_usage'
| group_by [resource.router_id, resource.nat_gateway_name]
| align rate(5m)
| condition val() > 0.8 * 64512  # 80% of max ports per IP
```

#### 3.3.5 Cloud Armor (WAF) Monitoring

```yaml
receivers:
  googlecloudmonitoring/armor:
    project_id: my-project
    metrics_list:
    - metric_name: "networksecurity.googleapis.com/https/request_count"
    # Log-based metrics for Cloud Armor
    - metric_name: "logging.googleapis.com/user/cloud_armor_blocked_requests"
    collection_interval: 60s
```

```sql
-- Cloud Armor log analysis in BigQuery
SELECT
  httpRequest.remoteIp,
  jsonPayload.enforcedSecurityPolicy.name as policy_name,
  jsonPayload.enforcedSecurityPolicy.outcome as outcome,
  jsonPayload.statusDetails as status_details,
  COUNT(*) as request_count
FROM `project.dataset.requests`
WHERE jsonPayload.enforcedSecurityPolicy.outcome = 'DENY'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY 1, 2, 3, 4
ORDER BY request_count DESC;
```

#### 3.3.6 Network Intelligence Center

GCP Network Intelligence Center provides:

- **Network Topology**: Visual map of VPC resources and traffic flows
- **Connectivity Tests**: Automated path analysis between resources
- **Performance Dashboard**: Packet loss and latency between zones/regions
- **Firewall Insights**: Overly permissive rules, shadowed rules, hit counts

```bash
# Create a connectivity test
gcloud network-management connectivity-tests create my-test \
  --source-instance=projects/my-project/zones/us-central1-a/instances/source-vm \
  --destination-instance=projects/my-project/zones/us-central1-b/instances/dest-vm \
  --destination-port=443 \
  --protocol=TCP

# Get test results
gcloud network-management connectivity-tests describe my-test --format=json

# Firewall insights
gcloud recommender insights list \
  --project=my-project \
  --location=global \
  --insight-type=google.compute.firewall.Insight
```

### 3.4 Multi-Cloud Connectivity Monitoring

For enterprises with multi-cloud architectures, monitoring cross-cloud connectivity is critical:

```yaml
# OTel Collector configuration for multi-cloud network monitoring
receivers:
  # AWS Transit Gateway metrics
  awscloudwatch/tgw:
    region: us-east-1
    metrics:
      named:
        tgw:
          namespace: AWS/TransitGateway
          metrics:
          - name: BytesIn
            statistics: [Sum]
          - name: BytesOut
            statistics: [Sum]
          - name: PacketDropCountBlackhole
            statistics: [Sum]

  # Azure ExpressRoute metrics
  azuremonitor/expressroute:
    subscription_id: "${AZURE_SUBSCRIPTION_ID}"
    services:
    - "Microsoft.Network/expressRouteCircuits"
    metrics:
    - name: "BgpAvailability"
    - name: "BitsInPerSecond"
    - name: "BitsOutPerSecond"

  # GCP Cloud Interconnect metrics
  googlecloudmonitoring/interconnect:
    project_id: my-project
    metrics_list:
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/operational_status"
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/rx_bytes_count"
    - metric_name: "interconnect.googleapis.com/network/interconnect/link/tx_bytes_count"

  # Synthetic checks for cross-cloud connectivity
  # (ping/HTTP checks between clouds)
  httpcheck/aws_to_azure:
    targets:
    - endpoint: https://azure-app.internal.example.com/health
    collection_interval: 30s
  httpcheck/aws_to_gcp:
    targets:
    - endpoint: https://gcp-app.internal.example.com/health
    collection_interval: 30s

processors:
  attributes/cloud_provider:
    actions:
    - key: cloud.provider
      action: upsert
      value: multi-cloud
    - key: environment
      action: upsert
      value: production

exporters:
  prometheusremotewrite:
    endpoint: https://prometheus.monitoring.internal:9090/api/v1/write
    resource_to_telemetry_conversion:
      enabled: true
```

### 3.5 SD-WAN Observability

SD-WAN (Software-Defined Wide Area Network) monitoring is critical for enterprises with branch office connectivity:

**Key SD-WAN metrics to monitor:**

| Metric Category | Metrics | Source |
|-----------------|---------|--------|
| **Tunnel Health** | Tunnel state, uptime, failover count | SD-WAN controller API |
| **Performance** | Latency (per tunnel), jitter, packet loss | SNMP, API, synthetic probes |
| **Bandwidth** | Utilization per tunnel, per application class | NetFlow/sFlow, SNMP |
| **Application Performance** | Per-app latency, throughput, path selection | SD-WAN analytics API |
| **SLA Compliance** | SLA violation count, time in violation | SD-WAN controller |
| **Path Selection** | Active path per application, failover events | SD-WAN controller API |

```yaml
# OTel Collector for SD-WAN monitoring (Cisco Viptela/Catalyst SD-WAN example)
receivers:
  # SNMP for tunnel metrics
  snmp/sdwan:
    collection_interval: 30s
    endpoint: udp://sdwan-vedge01:161
    version: v3
    security_level: authPriv
    user: monitoring
    auth_type: SHA
    auth_password: "${SNMP_AUTH_PASS}"
    privacy_type: AES
    privacy_password: "${SNMP_PRIV_PASS}"
    metrics:
      # Tunnel interface metrics
      sdwan.tunnel.tx_octets:
        unit: By
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.4.1.41916.11.1.2.1.7"
      sdwan.tunnel.rx_octets:
        unit: By
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.4.1.41916.11.1.2.1.8"

  # Syslog for SD-WAN events
  syslog/sdwan:
    udp:
      listen_address: "0.0.0.0:5514"
    protocol: rfc5424

  # REST API polling for SD-WAN controller
  # (typically via custom receiver or script)
  filelog/sdwan_api:
    include:
    - /var/log/sdwan-api-poll/*.json
    operators:
    - type: json_parser
```

---

## 4. API Gateway Observability

### 4.1 API Gateway Metrics Framework

API gateways are the front door for all external (and often internal) API traffic. Comprehensive observability requires tracking the RED method (Rate, Errors, Duration) plus gateway-specific signals:

#### 4.1.1 The API Gateway Golden Signals

| Signal | Metrics | Why It Matters |
|--------|---------|----------------|
| **Rate** | Requests/sec by route, method, consumer | Capacity planning, anomaly detection |
| **Errors** | 4xx/5xx by route, error codes | Reliability, client issues vs server issues |
| **Duration** | Latency percentiles (p50, p90, p99) | User experience, SLA compliance |
| **Auth Failures** | 401/403 by consumer, API key, route | Security monitoring, misconfigured clients |
| **Rate Limiting** | 429s by consumer, route, policy | Abuse detection, quota management |
| **Payload Size** | Request/response body size | Bandwidth costs, performance impact |
| **Upstream Health** | Backend health check pass/fail | Availability, circuit breaking |
| **TLS** | Handshake errors, cert expiry, protocol versions | Security compliance |

#### 4.1.2 Universal API Gateway PromQL Queries

These queries work across most gateway implementations that expose Prometheus metrics:

```promql
# Request rate by route (global view)
sum(rate(gateway_requests_total[5m])) by (route, method)

# Error rate by route (should be < 1% for 5xx)
sum(rate(gateway_requests_total{status=~"5.."}[5m])) by (route)
  /
sum(rate(gateway_requests_total[5m])) by (route) * 100

# Client error rate (4xx - may indicate bad API design or docs)
sum(rate(gateway_requests_total{status=~"4.."}[5m])) by (route, status)

# P99 latency by route
histogram_quantile(0.99,
  sum(rate(gateway_request_duration_seconds_bucket[5m])) by (le, route)
)

# Auth failure rate
sum(rate(gateway_requests_total{status=~"401|403"}[5m])) by (consumer, route)

# Rate limiting hits
sum(rate(gateway_requests_total{status="429"}[5m])) by (consumer, route)

# Request size (large payloads)
histogram_quantile(0.99,
  sum(rate(gateway_request_size_bytes_bucket[5m])) by (le, route)
)

# Gateway overhead (total latency - upstream latency)
histogram_quantile(0.99,
  sum(rate(gateway_request_duration_seconds_bucket[5m])) by (le, route)
)
-
histogram_quantile(0.99,
  sum(rate(gateway_upstream_duration_seconds_bucket[5m])) by (le, route)
)
```

### 4.2 Kong Gateway Observability

Kong is the most widely deployed open-source API gateway, with enterprise features via Kong Enterprise (now called Kong Konnect).

#### 4.2.1 Kong Prometheus Plugin Configuration

```yaml
# Kong plugin configuration (declarative)
plugins:
- name: prometheus
  config:
    per_consumer: true
    status_code_metrics: true
    latency_metrics: true
    bandwidth_metrics: true
    upstream_health_metrics: true

- name: opentelemetry
  config:
    endpoint: "http://otel-collector.observability.svc:4318/v1/traces"
    resource_attributes:
      service.name: "kong-gateway"
      deployment.environment: "production"
    header_type: "w3c"
    propagation:
    - w3c
    - b3

- name: file-log
  config:
    path: /dev/stdout
    custom_fields_by_lua:
      trace_id: "return kong.ctx.plugin.trace_id"

# Per-service rate limiting with observability
- name: rate-limiting-advanced
  service: payment-api
  config:
    limit:
    - 100
    window_size:
    - 60
    sync_rate: 10
    strategy: redis
    redis:
      host: redis.infrastructure.svc
      port: 6379
    hide_client_headers: false  # Expose X-RateLimit-* headers
```

#### 4.2.2 Kong Vitals Metrics (Enterprise)

Kong Vitals provides detailed analytics in Kong Enterprise:

```promql
# Kong request rate by service and route
sum(rate(kong_http_requests_total[5m])) by (service, route, code)

# Kong latency breakdown
# Total request latency
histogram_quantile(0.99,
  sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service)
)

# Kong processing latency (gateway overhead)
histogram_quantile(0.99,
  sum(rate(kong_kong_latency_ms_bucket[5m])) by (le, service)
)

# Upstream (backend) latency
histogram_quantile(0.99,
  sum(rate(kong_upstream_latency_ms_bucket[5m])) by (le, service)
)

# Bandwidth consumed by service
sum(rate(kong_bandwidth_bytes{direction="egress"}[5m])) by (service) / 1048576
# Result in MB/s

# Consumer-level metrics
sum(rate(kong_http_requests_total[5m])) by (consumer, service)

# Rate limiting effectiveness
sum(rate(kong_http_requests_total{code="429"}[5m])) by (consumer, service)

# Upstream health status
kong_upstream_target_health{state="healthy"} == 0
# Alert when any upstream target is unhealthy

# Connection pool utilization
kong_nginx_connections_total{state="active"}

# DB reachability (important for Kong with PostgreSQL)
kong_datastore_reachable == 0
```

#### 4.2.3 Kong Custom Dashboards

```json
{
  "dashboard": {
    "title": "Kong API Gateway",
    "panels": [
      {
        "title": "Request Rate by Service",
        "type": "timeseries",
        "targets": [{
          "expr": "sum(rate(kong_http_requests_total[5m])) by (service)",
          "legendFormat": "{{service}}"
        }]
      },
      {
        "title": "Error Rate by Service",
        "type": "stat",
        "targets": [{
          "expr": "sum(rate(kong_http_requests_total{code=~\"5..\"}[5m])) by (service) / sum(rate(kong_http_requests_total[5m])) by (service) * 100",
          "legendFormat": "{{service}}"
        }],
        "thresholds": {
          "steps": [
            {"value": 0, "color": "green"},
            {"value": 1, "color": "yellow"},
            {"value": 5, "color": "red"}
          ]
        }
      },
      {
        "title": "Latency Breakdown",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service))",
            "legendFormat": "Total p99 - {{service}}"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(kong_kong_latency_ms_bucket[5m])) by (le, service))",
            "legendFormat": "Kong p99 - {{service}}"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(kong_upstream_latency_ms_bucket[5m])) by (le, service))",
            "legendFormat": "Upstream p99 - {{service}}"
          }
        ]
      },
      {
        "title": "Rate Limited Requests",
        "type": "timeseries",
        "targets": [{
          "expr": "sum(rate(kong_http_requests_total{code=\"429\"}[5m])) by (consumer)",
          "legendFormat": "{{consumer}}"
        }]
      }
    ]
  }
}
```

### 4.3 AWS API Gateway Observability

#### 4.3.1 REST API and HTTP API Metrics

```yaml
# OTel Collector for AWS API Gateway CloudWatch metrics
receivers:
  awscloudwatch/apigateway:
    region: us-east-1
    poll_interval: 60s
    metrics:
      named:
        apigateway_rest:
          namespace: AWS/ApiGateway
          period: 60s
          metrics:
          - name: Count
            statistics: [Sum]
          - name: 4XXError
            statistics: [Sum, Average]
          - name: 5XXError
            statistics: [Sum, Average]
          - name: Latency
            statistics: [Average, p50, p90, p99]
          - name: IntegrationLatency
            statistics: [Average, p50, p90, p99]
          - name: CacheHitCount
            statistics: [Sum]
          - name: CacheMissCount
            statistics: [Sum]
          dimensions:
          - name: ApiName
            value: "*"
          - name: Stage
            value: "prod"
```

**Key AWS API Gateway metrics:**

```promql
# API Gateway request count
aws_apigateway_count_sum

# Error rates
aws_apigateway_4xxerror_sum / aws_apigateway_count_sum * 100
aws_apigateway_5xxerror_sum / aws_apigateway_count_sum * 100

# Latency vs Integration Latency
# (difference = API Gateway overhead including auth, throttling, mapping)
aws_apigateway_latency_p99 - aws_apigateway_integration_latency_p99

# Cache effectiveness
aws_apigateway_cache_hit_count_sum /
  (aws_apigateway_cache_hit_count_sum + aws_apigateway_cache_miss_count_sum) * 100
```

#### 4.3.2 AWS API Gateway Access Logging

```json
{
  "requestId": "$context.requestId",
  "ip": "$context.identity.sourceIp",
  "caller": "$context.identity.caller",
  "user": "$context.identity.user",
  "requestTime": "$context.requestTimeEpoch",
  "httpMethod": "$context.httpMethod",
  "resourcePath": "$context.resourcePath",
  "status": "$context.status",
  "protocol": "$context.protocol",
  "responseLength": "$context.responseLength",
  "integrationLatency": "$context.integrationLatency",
  "requestLatency": "$context.responseLatency",
  "errorMessage": "$context.error.message",
  "authorizerError": "$context.authorizer.error",
  "integrationError": "$context.integrationErrorMessage",
  "wafResponse": "$context.wafResponseCode",
  "xrayTraceId": "$context.xrayTraceId",
  "apiKey": "$context.identity.apiKey",
  "userAgent": "$context.identity.userAgent"
}
```

### 4.4 Azure API Management Observability

```yaml
# Azure APIM diagnostics configuration
receivers:
  azuremonitor/apim:
    subscription_id: "${AZURE_SUBSCRIPTION_ID}"
    services:
    - "Microsoft.ApiManagement/service"
    metrics:
    - name: "Requests"
    - name: "TotalRequests"
    - name: "SuccessfulRequests"
    - name: "UnauthorizedRequests"
    - name: "FailedRequests"
    - name: "OtherRequests"
    - name: "Duration"
    - name: "BackendDuration"
    - name: "Capacity"          # CPU/memory utilization percentage
    - name: "EventHubTotalEvents"
    - name: "EventHubSuccessfulEvents"
    - name: "EventHubTotalFailedEvents"
    collection_interval: 60s
```

**Azure APIM KQL queries:**

```kusto
// Request latency analysis
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| summarize
    P50 = percentile(TotalTime, 50),
    P90 = percentile(TotalTime, 90),
    P99 = percentile(TotalTime, 99),
    AvgBackendTime = avg(BackendTime),
    AvgClientTime = avg(ClientTime),
    Count = count()
  by bin(TimeGenerated, 5m), OperationId
| order by TimeGenerated desc

// Failed authentication attempts
ApiManagementGatewayLogs
| where ResponseCode == 401 or ResponseCode == 403
| summarize FailedCount = count() by CallerIpAddress, ApiId, OperationId
| order by FailedCount desc

// Rate limited requests
ApiManagementGatewayLogs
| where ResponseCode == 429
| summarize ThrottledCount = count() by CallerIpAddress, ProductId, ApiId
| order by ThrottledCount desc

// Backend errors breakdown
ApiManagementGatewayLogs
| where ResponseCode >= 500
| summarize ErrorCount = count() by BackendUrl, ResponseCode, LastError
| order by ErrorCount desc

// APIM capacity utilization (alert at 80%)
AzureMetrics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT"
| where MetricName == "Capacity"
| where Average > 80
| project TimeGenerated, Resource, Average
```

### 4.5 GCP Apigee Observability

```yaml
# Apigee metrics via Google Cloud Monitoring
receivers:
  googlecloudmonitoring/apigee:
    project_id: my-project
    metrics_list:
    - metric_name: "apigee.googleapis.com/proxyv2/request_count"
    - metric_name: "apigee.googleapis.com/proxyv2/latencies"
    - metric_name: "apigee.googleapis.com/proxyv2/request_processing_latencies"
    - metric_name: "apigee.googleapis.com/proxyv2/target_latencies"
    - metric_name: "apigee.googleapis.com/proxyv2/error_count"
    - metric_name: "apigee.googleapis.com/proxyv2/policy_latencies"
    - metric_name: "apigee.googleapis.com/environment/anomaly_count"
    collection_interval: 60s
```

### 4.6 Envoy as API Gateway

Envoy provides extremely rich observability when used as an API gateway (e.g., with Envoy Gateway, Ambassador/Emissary, or standalone):

```yaml
# Envoy Gateway observability configuration
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: observability-config
spec:
  telemetry:
    metrics:
      prometheus:
        enable: true
      sinks:
      - type: OpenTelemetry
        openTelemetry:
          host: otel-collector.observability.svc
          port: 4317
    tracing:
      provider:
        type: OpenTelemetry
        url: otel-collector.observability.svc:4317
      customTags:
        environment:
          type: Literal
          literal:
            value: "production"
    accessLog:
      settings:
      - format:
          type: JSON
          json:
            start_time: "%START_TIME%"
            method: "%REQ(:METHOD)%"
            path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
            protocol: "%PROTOCOL%"
            response_code: "%RESPONSE_CODE%"
            response_flags: "%RESPONSE_FLAGS%"
            bytes_received: "%BYTES_RECEIVED%"
            bytes_sent: "%BYTES_SENT%"
            duration: "%DURATION%"
            upstream_service_time: "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%"
            upstream_cluster: "%UPSTREAM_CLUSTER%"
            upstream_host: "%UPSTREAM_HOST%"
            x_request_id: "%REQ(X-REQUEST-ID)%"
            trace_id: "%REQ(X-B3-TRACEID)%"
            authority: "%REQ(:AUTHORITY)%"
            downstream_remote_address: "%DOWNSTREAM_REMOTE_ADDRESS%"
            user_agent: "%REQ(USER-AGENT)%"
```

**Key Envoy metrics for API gateway use:**

```promql
# Downstream (client-facing) metrics
sum(rate(envoy_http_downstream_rq_total[5m])) by (envoy_http_conn_manager_prefix)
sum(rate(envoy_http_downstream_rq_xx{envoy_response_code_class="5"}[5m]))
  /
sum(rate(envoy_http_downstream_rq_total[5m])) * 100

# Upstream (backend) metrics
sum(rate(envoy_cluster_upstream_rq_total[5m])) by (envoy_cluster_name)
sum(rate(envoy_cluster_upstream_rq_xx{envoy_response_code_class="5"}[5m])) by (envoy_cluster_name)

# Request duration
histogram_quantile(0.99,
  sum(rate(envoy_http_downstream_rq_time_bucket[5m])) by (le)
)

# Connection pool health
envoy_cluster_upstream_cx_active
envoy_cluster_upstream_cx_overflow  # Connection pool overflow (needs more connections)
envoy_cluster_upstream_rq_pending_active  # Pending requests (queue building)

# Circuit breaker metrics
envoy_cluster_upstream_rq_pending_overflow  # CB triggered - pending queue full
envoy_cluster_circuit_breakers_default_cx_open  # CB open - too many connections
envoy_cluster_circuit_breakers_default_rq_open  # CB open - too many requests

# Rate limiting
envoy_http_local_rate_limit_enabled
envoy_http_local_rate_limit_enforced
envoy_http_local_rate_limit_ok
envoy_http_local_rate_limit_rate_limited

# TLS metrics
envoy_http_downstream_cx_ssl_handshake
envoy_listener_ssl_handshake_error
envoy_cluster_ssl_handshake  # Upstream TLS
```

### 4.7 GraphQL Observability

GraphQL presents unique observability challenges due to its single-endpoint nature. Traditional HTTP metrics (request count, status codes) are insufficient because all requests go to POST /graphql and almost all return 200 even with errors.

#### 4.7.1 GraphQL-Specific Metrics

| Metric | Why It Matters |
|--------|----------------|
| **Query complexity score** | Prevents expensive queries from DoS-ing backends |
| **Query depth** | Deep queries can cause N+1 database problems |
| **Resolver execution time** | Per-field performance (where time is actually spent) |
| **Resolver error count** | Partial failures (some fields succeed, others fail) |
| **Query parsing/validation time** | GraphQL overhead before execution |
| **Operation name** | Group metrics by logical operation (query/mutation/subscription name) |
| **Field usage** | Schema analytics - which fields are actually used |
| **Deprecation tracking** | How often deprecated fields are still queried |
| **Persisted query hit rate** | Cache effectiveness for APQ (Automatic Persisted Queries) |
| **Subscription count** | Active WebSocket subscriptions (resource consumption) |

#### 4.7.2 Apollo Server / Apollo Router Observability

```yaml
# Apollo Router (Rust-based GraphQL gateway) OTel configuration
# router.yaml
telemetry:
  instrumentation:
    spans:
      mode: spec_compliant
      router:
        attributes:
          http.request.method: true
          http.response.status_code: true
          url.path: true
          graphql.operation.name:
            request_header: "x-operation-name"
      supergraph:
        attributes:
          graphql.operation.name: true
          graphql.operation.type: true
      subgraph:
        attributes:
          subgraph.name: true
          graphql.operation.name: true
    instruments:
      router:
        http.server.request.duration:
          attributes:
            http.response.status_code: true
            graphql.operation.name:
              request_header: "x-operation-name"
      supergraph:
        cost.estimated:
          type: histogram
          value:
            cost: estimated
          description: "Estimated query cost"
          unit: "units"
        cost.actual:
          type: histogram
          value:
            cost: actual
          description: "Actual query cost"
          unit: "units"
  exporters:
    tracing:
      otlp:
        enabled: true
        endpoint: http://otel-collector.observability.svc:4317
        protocol: grpc
    metrics:
      prometheus:
        enabled: true
        listen: 0.0.0.0:9090
        path: /metrics
      otlp:
        enabled: true
        endpoint: http://otel-collector.observability.svc:4317
        protocol: grpc

  # Demand control (query cost analysis)
  demand_control:
    mode: measure  # or "enforce" to reject expensive queries
    strategy:
      static_estimated:
        list_size: 10
        max: 1000
```

**GraphQL PromQL queries:**

```promql
# Request rate by operation name and type
sum(rate(apollo_router_http_requests_total[5m])) by (
  graphql_operation_name, graphql_operation_type
)

# Error rate by operation
sum(rate(apollo_router_http_requests_total{status=~"5.."}[5m])) by (graphql_operation_name)
  /
sum(rate(apollo_router_http_requests_total[5m])) by (graphql_operation_name)

# Query cost distribution
histogram_quantile(0.99,
  sum(rate(apollo_router_cost_estimated_bucket[5m])) by (le)
)

# Subgraph latency (which backend service is slow)
histogram_quantile(0.99,
  sum(rate(apollo_router_http_request_duration_seconds_bucket{subgraph_name!=""}[5m]))
  by (le, subgraph_name)
)

# Subgraph error rate
sum(rate(apollo_router_http_requests_total{subgraph_name!="",status=~"5.."}[5m])) by (subgraph_name)
```

### 4.8 gRPC Observability

gRPC requires specific observability instrumentation due to its binary protocol, streaming capabilities, and deadline propagation.

#### 4.8.1 gRPC Server Metrics (OpenTelemetry)

```yaml
# OTel Collector gRPC metrics (from instrumented services)
# Standard OTel gRPC metrics (otel semantic conventions):
# rpc.server.duration - server-side RPC duration
# rpc.server.request.size - request message size
# rpc.server.response.size - response message size
# rpc.server.requests_per_rpc - messages per RPC (streaming)
# rpc.server.responses_per_rpc - messages per RPC (streaming)
# rpc.client.duration - client-side RPC duration
# rpc.client.request.size - client request size
# rpc.client.response.size - client response size
```

**Key gRPC PromQL queries:**

```promql
# gRPC request rate by service and method
sum(rate(grpc_server_handled_total[5m])) by (grpc_service, grpc_method)

# gRPC error rate by status code
sum(rate(grpc_server_handled_total{grpc_code!="OK"}[5m])) by (grpc_service, grpc_method, grpc_code)
  /
sum(rate(grpc_server_handled_total[5m])) by (grpc_service, grpc_method)

# Specific gRPC codes to alert on:
# DEADLINE_EXCEEDED - timeout issues
# UNAVAILABLE - backend down or overloaded
# RESOURCE_EXHAUSTED - rate limiting or memory
# INTERNAL - server bugs

# gRPC latency by method
histogram_quantile(0.99,
  sum(rate(grpc_server_handling_seconds_bucket[5m])) by (le, grpc_service, grpc_method)
)

# Streaming: messages per RPC (detect streaming inefficiency)
sum(rate(grpc_server_msg_sent_total[5m])) by (grpc_service, grpc_method)
  /
sum(rate(grpc_server_started_total[5m])) by (grpc_service, grpc_method)

# gRPC message size
histogram_quantile(0.99,
  sum(rate(grpc_server_msg_received_bytes_bucket[5m])) by (le, grpc_service, grpc_method)
)

# Deadline exceeded rate (timeout propagation issues)
sum(rate(grpc_server_handled_total{grpc_code="DeadlineExceeded"}[5m])) by (grpc_service, grpc_method)

# In-flight streams (connection pressure)
grpc_server_started_total - grpc_server_handled_total

# Client-side: retry metrics
sum(rate(grpc_client_handled_total{grpc_code!="OK"}[5m])) by (grpc_service, grpc_method, grpc_code)
```

#### 4.8.2 gRPC Health Check Protocol

```protobuf
// Standard gRPC health check service
syntax = "proto3";
package grpc.health.v1;

service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
  rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}

message HealthCheckResponse {
  enum ServingStatus {
    UNKNOWN = 0;
    SERVING = 1;
    NOT_SERVING = 2;
    SERVICE_UNKNOWN = 3;
  }
  ServingStatus status = 1;
}
```

```yaml
# Kubernetes gRPC health checks
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: grpc-service
    ports:
    - containerPort: 50051
    readinessProbe:
      grpc:
        port: 50051
        service: "my.package.MyService"
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:
      grpc:
        port: 50051
      initialDelaySeconds: 15
      periodSeconds: 20
```

---

## 5. Distributed Tracing for Network Operations

### 5.1 Trace Context Propagation Standards

#### 5.1.1 W3C Trace Context (Recommended Standard)

W3C Trace Context is the industry standard for trace propagation, supported by all major observability platforms:

```
# HTTP Headers
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
tracestate: congo=t61rcWkgMzE,rojo=00f067aa0ba902b7

# Format: version-trace_id-parent_id-trace_flags
# version:     00 (always)
# trace_id:    32 hex chars (128-bit)
# parent_id:   16 hex chars (64-bit)
# trace_flags: 01 = sampled, 00 = not sampled
```

**W3C Baggage (additional context propagation):**

```
# Propagate arbitrary key-value pairs across services
baggage: userId=alice,requestPriority=high,region=us-east-1
```

#### 5.1.2 B3 Propagation (Zipkin Format)

B3 is still widely used, especially in Istio/Envoy and older systems:

```
# B3 multi-header format
X-B3-TraceId: 4bf92f3577b34da6a3ce929d0e0e4736
X-B3-SpanId: 00f067aa0ba902b7
X-B3-ParentSpanId: d7aa0ba902b700f0
X-B3-Sampled: 1

# B3 single-header format (more efficient)
b3: 4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-1-d7aa0ba902b700f0
```

#### 5.1.3 Propagation Configuration in OTel Collector

```yaml
# OTel Collector propagation configuration
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

# SDK-level configuration for applications
# Environment variables:
# OTEL_PROPAGATORS=tracecontext,baggage,b3multi
# This enables W3C Trace Context + Baggage + B3 multi-header
```

### 5.2 Header Propagation Challenges

#### 5.2.1 Common Propagation Failures

```
┌──────────────────────────────────────────────────────────────────────┐
│           Trace Context Propagation Failure Scenarios                 │
│                                                                      │
│  1. Header Stripping                                                 │
│     Client ──traceparent──► Proxy ──(no header)──► Backend           │
│     Cause: Proxy/LB/CDN strips unknown headers                      │
│     Fix: Whitelist traceparent, tracestate in proxy config           │
│                                                                      │
│  2. Missing Instrumentation                                          │
│     Service A ──traceparent──► Service B ──(new trace)──► Service C  │
│     Cause: Service B doesn't extract/inject trace context            │
│     Fix: Add OTel SDK or auto-instrumentation to Service B           │
│                                                                      │
│  3. Protocol Translation                                             │
│     HTTP Service ──traceparent──► Message Queue ──???──► Consumer    │
│     Cause: Message queues don't natively support HTTP headers        │
│     Fix: Map trace context to message attributes/headers             │
│                                                                      │
│  4. Format Mismatch                                                  │
│     Zipkin App ──X-B3-*──► W3C App ──traceparent──► Jaeger App      │
│     Cause: Services use different propagation formats                │
│     Fix: Configure multi-format propagation in OTel SDK              │
│                                                                      │
│  5. Async Boundaries                                                 │
│     Request ──trace──► Queue ──(minutes later)──► Worker             │
│     Cause: Trace context lost across async boundaries                │
│     Fix: Store trace context as message metadata, create links       │
└──────────────────────────────────────────────────────────────────────┘
```

#### 5.2.2 Proxy/LB Header Propagation Configuration

```nginx
# NGINX - ensure trace headers are forwarded
proxy_set_header traceparent $http_traceparent;
proxy_set_header tracestate $http_tracestate;
proxy_set_header baggage $http_baggage;
# B3 compatibility
proxy_set_header X-B3-TraceId $http_x_b3_traceid;
proxy_set_header X-B3-SpanId $http_x_b3_spanid;
proxy_set_header X-B3-ParentSpanId $http_x_b3_parentspanid;
proxy_set_header X-B3-Sampled $http_x_b3_sampled;
proxy_set_header b3 $http_b3;
```

```yaml
# HAProxy - forward trace headers
frontend http-in
    bind *:80
    # Forward all trace-related headers
    http-request set-header X-Forwarded-For %[src]
    # HAProxy 2.4+ passes unknown headers by default
    # For older versions, use:
    # option http-forward-unsafe-compliant-headers

backend my-backend
    server app1 10.0.0.1:8080
    # Ensure headers are not stripped
    http-response del-header Server
```

### 5.3 Tracing Through Message Queues

#### 5.3.1 Kafka Trace Propagation

```java
// Producer: inject trace context into Kafka headers
import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.context.propagation.TextMapSetter;

TextMapSetter<Headers> setter = (headers, key, value) ->
    headers.add(key, value.getBytes(StandardCharsets.UTF_8));

// Before sending message
Span span = tracer.spanBuilder("kafka-publish")
    .setSpanKind(SpanKind.PRODUCER)
    .setAttribute("messaging.system", "kafka")
    .setAttribute("messaging.destination.name", topic)
    .setAttribute("messaging.operation", "publish")
    .startSpan();

try (Scope scope = span.makeCurrent()) {
    // Inject trace context into Kafka headers
    GlobalOpenTelemetry.getPropagators().getTextMapPropagator()
        .inject(Context.current(), record.headers(), setter);
    producer.send(record);
} finally {
    span.end();
}
```

```python
# Consumer: extract trace context from Kafka headers
from opentelemetry import trace, context
from opentelemetry.propagate import extract

def process_message(message):
    # Extract trace context from Kafka message headers
    headers_dict = {h.key: h.value.decode() for h in message.headers() or []}
    ctx = extract(headers_dict)

    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span(
        "kafka-consume",
        context=ctx,
        kind=trace.SpanKind.CONSUMER,
        attributes={
            "messaging.system": "kafka",
            "messaging.destination.name": message.topic(),
            "messaging.operation": "process",
            "messaging.kafka.partition": message.partition(),
            "messaging.kafka.offset": message.offset(),
            "messaging.kafka.consumer.group": "my-group",
        }
    ) as span:
        # Process the message...
        process_business_logic(message.value())
```

#### 5.3.2 RabbitMQ Trace Propagation

```python
# RabbitMQ producer with trace context
import pika
from opentelemetry.propagate import inject

def publish_message(channel, exchange, routing_key, body):
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span(
        "rabbitmq-publish",
        kind=trace.SpanKind.PRODUCER,
        attributes={
            "messaging.system": "rabbitmq",
            "messaging.destination.name": exchange,
            "messaging.rabbitmq.routing_key": routing_key,
            "messaging.operation": "publish",
        }
    ):
        headers = {}
        inject(headers)  # Inject trace context into headers dict

        properties = pika.BasicProperties(
            headers=headers,
            content_type='application/json',
            delivery_mode=2,  # persistent
        )
        channel.basic_publish(
            exchange=exchange,
            routing_key=routing_key,
            body=body,
            properties=properties
        )
```

#### 5.3.3 AWS SQS Trace Propagation

```python
# SQS producer with trace context
import boto3
from opentelemetry.propagate import inject

sqs = boto3.client('sqs')

def send_to_sqs(queue_url, message_body):
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span(
        "sqs-send",
        kind=trace.SpanKind.PRODUCER,
        attributes={
            "messaging.system": "aws_sqs",
            "messaging.destination.name": queue_url.split("/")[-1],
            "messaging.operation": "publish",
        }
    ):
        # SQS supports up to 10 message attributes
        carrier = {}
        inject(carrier)

        message_attributes = {}
        for key, value in carrier.items():
            message_attributes[key] = {
                'DataType': 'String',
                'StringValue': value
            }

        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=message_body,
            MessageAttributes=message_attributes
        )
        return response

# SQS consumer with trace context extraction
def process_sqs_message(message):
    # Extract trace context from message attributes
    carrier = {}
    for key, attr in message.get('MessageAttributes', {}).items():
        carrier[key] = attr['StringValue']

    ctx = extract(carrier)

    with tracer.start_as_current_span(
        "sqs-receive",
        context=ctx,
        kind=trace.SpanKind.CONSUMER,
        attributes={
            "messaging.system": "aws_sqs",
            "messaging.operation": "process",
            "messaging.message.id": message['MessageId'],
        },
        links=[trace.Link(trace.get_current_span(ctx).get_span_context())]
    ):
        process_business_logic(message['Body'])
```

### 5.4 Tracing Through Load Balancers and Gateways

#### 5.4.1 Envoy Native Tracing

Envoy (used in Istio, Consul Connect, Ambassador, Gloo) has built-in tracing support:

```yaml
# Envoy tracing configuration
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          tracing:
            provider:
              name: envoy.tracers.opentelemetry
              typed_config:
                "@type": type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig
                grpc_service:
                  envoy_grpc:
                    cluster_name: otel_collector
                  timeout: 0.250s
                service_name: envoy-gateway
            spawn_upstream_span: true  # Create child span for upstream call
            custom_tags:
            - tag: "env"
              literal:
                value: "production"
            - tag: "request.path"
              request_header:
                name: ":path"
          # Generate x-request-id if not present
          request_id_extension:
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.request_id.uuid.v3.UuidRequestIdConfig
              pack_trace_reason: true
```

#### 5.4.2 NGINX OpenTelemetry Module

```nginx
# NGINX with OpenTelemetry module (ngx_otel_module)
load_module modules/ngx_otel_module.so;

http {
    otel_exporter {
        endpoint otel-collector.observability.svc:4317;
    }

    otel_trace on;
    otel_trace_context propagate;  # propagate, inject, extract, ignore
    otel_service_name "nginx-gateway";

    otel_span_attr deployment.environment "production";

    server {
        listen 443 ssl;
        server_name api.example.com;

        location /api/ {
            otel_trace on;
            otel_span_name "api-proxy";
            otel_span_attr http.route "/api/*";

            proxy_pass http://backend-service:8080;

            # Ensure trace headers are forwarded
            proxy_set_header traceparent $http_traceparent;
            proxy_set_header tracestate $http_tracestate;
        }
    }
}
```

#### 5.4.3 HAProxy Tracing (OpenTracing/OTel)

```
# HAProxy 2.6+ with OpenTelemetry
global
    # Load OTel filter
    module-path /usr/lib/haproxy
    module-load mod_ot.so

frontend http-in
    bind *:80
    filter opentracing config /etc/haproxy/otel.cfg id otel
    http-request set-var(txn.ot_span_id) uuid()
    default_backend servers

backend servers
    filter opentracing config /etc/haproxy/otel.cfg id otel
    server app1 10.0.0.1:8080
```

### 5.5 Network-Level Trace Injection

#### 5.5.1 Correlating Network Flows with Application Traces

The gap between network-level observability (flows, packets) and application-level observability (traces, spans) is one of the hardest problems in networking observability:

```
┌──────────────────────────────────────────────────────────────────────┐
│          Span-to-Flow Correlation Architecture                       │
│                                                                      │
│  Application Layer:                                                  │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐               │
│  │Service A │──trace──│Service B │──trace──│Service C │              │
│  │trace_id: │         │trace_id: │         │trace_id: │              │
│  │ abc123   │         │ abc123   │         │ abc123   │              │
│  │src:10.0.1│         │src:10.0.2│         │src:10.0.3│              │
│  │  .5:49152│         │  .8:8080 │         │  .12:5432│              │
│  └─────────┘         └─────────┘         └─────────┘               │
│       │                    │                    │                     │
│  Network Layer:            │                    │                     │
│  ┌─────────────────────────▼────────────────────▼───────────────┐   │
│  │  Flow Records (VPC Flow Logs / Cilium Hubble / Calico)        │   │
│  │  flow1: 10.0.1.5:49152 → 10.0.2.8:8080  TCP 1024B 15ms      │   │
│  │  flow2: 10.0.2.8:32768 → 10.0.3.12:5432 TCP 512B  8ms       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Correlation Key: (src_ip, dst_ip, src_port, dst_port, timestamp)   │
│  Join spans with flows using 5-tuple + time window                   │
└──────────────────────────────────────────────────────────────────────┘
```

#### 5.5.2 Cilium Hubble Trace Correlation

Cilium Hubble can correlate L3/L4 flows with application trace IDs:

```yaml
# Cilium Hubble configuration with trace ID extraction
hubble:
  enabled: true
  relay:
    enabled: true
  metrics:
    enabled:
    - httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction
    # exemplars=true links metrics to trace IDs via exemplars
  ui:
    enabled: true
```

```bash
# Hubble CLI: observe flows with trace context
hubble observe --protocol http \
  --http-header traceparent \
  -o json | jq '.flow.l7.http.headers["traceparent"]'

# Filter flows by specific trace ID
hubble observe --protocol http \
  --http-header "traceparent=00-4bf92f3577b34da6a3ce929d0e0e4736-*" \
  -o compact
```

### 5.6 Trace-Based Network Diagnostics

```yaml
# OTel Collector pipeline for correlating traces with network data
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
  # Receive Hubble flows as logs
  otlp/hubble:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4318

processors:
  # Enrich spans with network metadata
  transform/network_correlation:
    trace_statements:
    - context: span
      statements:
      # Add network metadata to spans
      - set(attributes["network.src.ip"], resource.attributes["net.host.ip"])
      - set(attributes["network.transport"], "tcp") where attributes["rpc.system"] != nil
      - set(attributes["network.peer.ip"], attributes["net.peer.ip"])

  # Group spans by trace ID for analysis
  groupbytrace:
    wait_duration: 10s
    num_traces: 1000

exporters:
  otlp/traces:
    endpoint: tempo.observability.svc:4317
  loki/network_events:
    endpoint: http://loki.observability.svc:3100/loki/api/v1/push
    labels:
      resource:
        service.name: "service_name"
      attributes:
        network.src.ip: "src_ip"
        network.peer.ip: "dst_ip"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [transform/network_correlation, groupbytrace]
      exporters: [otlp/traces]
    logs/network:
      receivers: [otlp/hubble]
      processors: []
      exporters: [loki/network_events]
```

---

## 6. Network Troubleshooting Observability

### 6.1 Common Network Issues and Detection

#### 6.1.1 DNS Failures

DNS failures are the most common cause of intermittent connectivity issues in Kubernetes and cloud environments.

**Detection patterns:**

```promql
# CoreDNS SERVFAIL spike (upstream resolver issues)
sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
  /
sum(rate(coredns_dns_responses_total[5m])) > 0.01

# DNS latency spike (CoreDNS overloaded or upstream slow)
histogram_quantile(0.99,
  sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)
) > 0.1

# DNS resolution failures (application-level)
sum(rate(dns_lookup_errors_total[5m])) by (service, domain) > 0

# NXDOMAIN for expected services (service discovery broken)
sum(rate(coredns_dns_responses_total{
  rcode="NXDOMAIN",
  zone="cluster.local."
}[5m])) > 0
```

**Common root causes and resolution:**

| Symptom | Root Cause | Detection | Resolution |
|---------|-----------|-----------|------------|
| SERVFAIL spikes | Upstream resolver down | `coredns_forward_healthcheck_failures_total` | Add secondary upstream, check /etc/resolv.conf |
| High NXDOMAIN | ndots:5 amplification | Forward/total ratio > 0.5 | Set ndots:2 in pod DNS config |
| DNS timeout | CoreDNS pods overloaded | DNS latency p99 > 100ms | Scale CoreDNS replicas, add NodeLocal DNS |
| Intermittent failures | UDP conntrack race condition (Linux < 5.0) | `conntrack_stat_insert_failed` | `single-request-reopen` in resolv.conf, upgrade kernel |
| NXDOMAIN for valid names | Headless service with no endpoints | `kube_endpoint_address_available == 0` | Check service selectors, pod readiness |

**DNS troubleshooting runbook:**

```bash
# Step 1: Check CoreDNS health
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Step 2: Test DNS resolution from a pod
kubectl run dnstest --rm -it --image=nicolaka/netshoot -- \
  nslookup kubernetes.default.svc.cluster.local

# Step 3: Test external resolution
kubectl run dnstest --rm -it --image=nicolaka/netshoot -- \
  nslookup google.com

# Step 4: Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Step 5: Check for DNS policy issues
kubectl get networkpolicies --all-namespaces | grep -i dns

# Step 6: Verify CoreDNS service endpoint
kubectl get endpoints kube-dns -n kube-system

# Step 7: Check ndots configuration in a pod
kubectl exec -it my-pod -- cat /etc/resolv.conf
# Expected: nameserver 10.96.0.10 (kube-dns ClusterIP)
#           search default.svc.cluster.local svc.cluster.local cluster.local
#           options ndots:5
```

#### 6.1.2 Connection Timeouts

```promql
# TCP connection timeout rate (from application metrics)
sum(rate(http_client_request_duration_seconds_count{status="timeout"}[5m])) by (target_service)

# Connection refused (service not listening or NetworkPolicy blocking)
sum(rate(http_client_errors_total{error="connection_refused"}[5m])) by (target_service)

# TCP retransmits (network congestion or packet loss)
rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) * 100

# Established connections timing out
rate(node_netstat_TcpExt_TCPTimeouts[5m])

# SYN packets without response (firewall/NP blocking or host unreachable)
rate(node_netstat_TcpExt_TCPSynRetrans[5m])

# Envoy/service mesh connection timeouts
sum(rate(envoy_cluster_upstream_cx_connect_timeout[5m])) by (envoy_cluster_name)

# gRPC deadline exceeded
sum(rate(grpc_server_handled_total{grpc_code="DeadlineExceeded"}[5m])) by (grpc_service)
```

**Connection timeout diagnostic flow:**

```
Client Timeout
    │
    ├── Can client resolve DNS?
    │   ├── No → DNS issue (see 6.1.1)
    │   └── Yes ↓
    │
    ├── Can client reach server IP? (ICMP/TCP SYN)
    │   ├── No → Network path issue
    │   │   ├── Check NetworkPolicy
    │   │   ├── Check security groups / NSG
    │   │   ├── Check route tables
    │   │   └── Check MTU (fragmentation)
    │   └── Yes ↓
    │
    ├── Does server accept connections? (TCP handshake)
    │   ├── RST → Server not listening (wrong port, crashed)
    │   ├── No response → Firewall DROP rule
    │   └── SYN-ACK ↓
    │
    ├── Does server respond in time? (application processing)
    │   ├── No → Server overloaded, check CPU/memory/threads
    │   └── Yes → Client timeout too aggressive, increase timeout
    │
    └── Is response received intact? (no truncation/corruption)
        ├── No → MTU issue, packet corruption
        └── Yes → Intermittent issue, check conntrack/NAT
```

#### 6.1.3 TLS Handshake Failures

```promql
# TLS handshake errors (NGINX Ingress)
rate(nginx_ingress_controller_ssl_handshake_errors_total[5m])

# TLS handshake errors (Envoy)
rate(envoy_listener_ssl_handshake_error[5m])

# Certificate expiry approaching
(nginx_ingress_controller_ssl_expire_time_seconds - time()) / 86400 < 30

# TLS version distribution (identify legacy TLS 1.0/1.1)
sum(rate(envoy_listener_ssl_versions_total[5m])) by (ssl_version)

# TLS cipher suite usage
sum(rate(envoy_listener_ssl_ciphers_total[5m])) by (ssl_cipher)

# mTLS failures in service mesh
sum(rate(envoy_cluster_ssl_connection_error[5m])) by (envoy_cluster_name)
```

**Common TLS failure causes:**

| Error | Cause | Resolution |
|-------|-------|------------|
| `SSL_ERROR_CERTIFICATE_UNKNOWN` | Untrusted CA | Add CA to trust store |
| `SSL_ERROR_CERTIFICATE_EXPIRED` | Cert expired | Renew certificate, check cert-manager |
| `SSL_ERROR_HANDSHAKE_FAILURE` | Protocol/cipher mismatch | Align TLS versions, update cipher suites |
| `SSL_ERROR_BAD_CERT` | Client cert invalid (mTLS) | Re-issue client certificate |
| `SSL_ERROR_INTERNAL` | Memory exhaustion during handshake | Scale resources, check connection limits |
| `certificate verify failed` | Hostname mismatch | Check SAN/CN matches requested hostname |

#### 6.1.4 MTU and Fragmentation Issues

MTU mismatches cause silent packet drops, especially in overlay networks (VXLAN adds 50 bytes, WireGuard adds 60 bytes):

```promql
# IP fragmentation metrics
rate(node_netstat_Ip_FragCreates[5m]) > 0   # Fragments created
rate(node_netstat_Ip_FragFails[5m]) > 0     # Fragmentation failures (DF bit set)
rate(node_netstat_Ip_ReasmFails[5m]) > 0    # Reassembly failures

# ICMP "fragmentation needed" messages
rate(node_netstat_Icmp_OutMsgs{type="3"}[5m])  # Destination unreachable
```

**MTU diagnostic commands:**

```bash
# Test MTU from pod (find maximum non-fragmented size)
# Ethernet MTU 1500, minus 20 IP + 8 ICMP = 1472
kubectl exec -it netshoot -- ping -M do -s 1472 target-pod-ip
# If this fails, try smaller sizes:
kubectl exec -it netshoot -- ping -M do -s 1422 target-pod-ip  # VXLAN
kubectl exec -it netshoot -- ping -M do -s 1362 target-pod-ip  # VXLAN + WireGuard

# Check interface MTU on node
kubectl exec -it netshoot -- ip link show

# Expected MTU values:
# eth0 (pod interface): 1500 (or lower for overlay)
# flannel.1 (VXLAN): 1450
# cali* (Calico IPIP): 1440
# cilium_vxlan: 1450
# wg0 (WireGuard): 1420
```

#### 6.1.5 NAT Exhaustion

NAT exhaustion occurs when too many outbound connections from a single IP exhaust available source ports (ephemeral port range is typically 32768-60999):

```promql
# Linux conntrack as NAT proxy
# Conntrack table utilization
node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8

# AWS NAT Gateway: ErrorPortAllocation
# Indicates source port exhaustion
aws_natgateway_error_port_allocation_sum > 0

# AWS NAT Gateway: packets dropped
aws_natgateway_packets_drop_count_sum > 0

# GCP Cloud NAT: port allocation failures
# router.googleapis.com/nat/nat_allocation_failed > 0

# Azure NAT Gateway: SNAT connection failures
# AzureMetrics where MetricName == "SNATConnectionCount" and status == "Failed"
```

**NAT exhaustion solutions:**

| Platform | Solution |
|----------|----------|
| **Kubernetes** | Increase conntrack max, reduce TIME_WAIT timeout |
| **AWS NAT Gateway** | Use multiple NAT Gateways, allocate more EIPs, use VPC endpoints for AWS services |
| **GCP Cloud NAT** | Increase min-ports-per-vm, enable Dynamic Port Allocation, add more NAT IPs |
| **Azure NAT Gateway** | Add more public IPs (up to 16), increase idle timeout |
| **General** | Use connection pooling, enable keepalive, reduce idle connection timeout |

#### 6.1.6 Split-Brain and Partition Detection

Network partitions cause split-brain in distributed systems. Detecting them early prevents data corruption:

```promql
# Node NotReady events (potential network partition)
kube_node_status_condition{condition="Ready",status="false"} == 1

# etcd: leader changes (possible split-brain)
rate(etcd_server_leader_changes_seen_total[5m]) > 0

# etcd: network latency between peers
histogram_quantile(0.99, rate(etcd_network_peer_round_trip_time_seconds_bucket[5m]))

# Raft proposal failures (split-brain indicator)
rate(etcd_server_proposals_failed_total[5m]) > 0

# Cross-zone/cross-region latency spikes
histogram_quantile(0.99,
  rate(http_client_request_duration_seconds_bucket{
    target_zone!="$source_zone"
  }[5m])
) > 1.0  # > 1s cross-zone = potential partition

# Cilium unreachable nodes (cluster partition indicator)
cilium_unreachable_nodes > 0

# Consul: server health (if using Consul for service discovery)
consul_health_node_status{status!="passing"}
```

### 6.2 Kubernetes-Specific Network Debugging

#### 6.2.1 Pod DNS Troubleshooting

```bash
# Quick DNS health check script
cat <<'SCRIPT' > /tmp/dns-check.sh
#!/bin/bash
echo "=== DNS Configuration ==="
cat /etc/resolv.conf

echo -e "\n=== Cluster DNS Test ==="
nslookup kubernetes.default.svc.cluster.local 2>&1

echo -e "\n=== External DNS Test ==="
nslookup google.com 2>&1

echo -e "\n=== Service Discovery Test ==="
nslookup kube-dns.kube-system.svc.cluster.local 2>&1

echo -e "\n=== DNS Latency Test ==="
for i in {1..10}; do
  start=$(date +%s%N)
  nslookup kubernetes.default.svc.cluster.local > /dev/null 2>&1
  end=$(date +%s%N)
  echo "Query $i: $(( (end - start) / 1000000 ))ms"
done

echo -e "\n=== CoreDNS Pods ==="
# Check if CoreDNS pods are running
wget -qO- http://kube-dns.kube-system.svc.cluster.local:9153/metrics 2>&1 | head -5
SCRIPT

kubectl run dns-debug --rm -it --image=nicolaka/netshoot -- bash /tmp/dns-check.sh
```

#### 6.2.2 Service Discovery Troubleshooting

```bash
# Check service exists and has endpoints
kubectl get svc my-service -n my-namespace -o wide
kubectl get endpoints my-service -n my-namespace
kubectl get endpointslices -l kubernetes.io/service-name=my-service -n my-namespace

# Verify kube-proxy is syncing rules for this service
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
# On the relevant node:
kubectl exec -it kube-proxy-xxxxx -n kube-system -- iptables -t nat -L KUBE-SERVICES -n | grep my-service

# For IPVS mode:
kubectl exec -it kube-proxy-xxxxx -n kube-system -- ipvsadm -Ln | grep -A5 "ClusterIP"

# Check for stale endpoints
kubectl get endpoints --all-namespaces -o json | \
  jq '.items[] | select(.subsets == null or .subsets == []) | .metadata.name'
```

#### 6.2.3 CNI Troubleshooting

```bash
# Check CNI plugin status
kubectl get pods -n kube-system -l k8s-app=calico-node  # Calico
kubectl get pods -n kube-system -l k8s-app=cilium        # Cilium
kubectl get pods -n kube-flannel                          # Flannel

# Calico diagnostics
kubectl exec -it calico-node-xxxxx -n kube-system -- calico-node -bird-live
kubectl exec -it calico-node-xxxxx -n kube-system -- calico-node -felix-live

# Cilium diagnostics
kubectl exec -it cilium-xxxxx -n kube-system -- cilium status --verbose
kubectl exec -it cilium-xxxxx -n kube-system -- cilium endpoint list
kubectl exec -it cilium-xxxxx -n kube-system -- cilium bpf ct list global | head -20
kubectl exec -it cilium-xxxxx -n kube-system -- cilium connectivity test

# Check pod network namespace
kubectl exec -it my-pod -- ip addr show
kubectl exec -it my-pod -- ip route show
kubectl exec -it my-pod -- ss -tlnp  # Listening sockets
kubectl exec -it my-pod -- ss -tnp   # Active connections
```

### 6.3 Network Dashboard Best Practices

#### 6.3.1 Dashboard Hierarchy

```
┌────────────────────────────────────────────────────────────────┐
│  Level 1: Executive Network Health (single pane of glass)      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │  Overall      │ │  Error Rate  │ │  Active Incidents    │  │
│  │  Availability │ │  (5xx/total) │ │  (NetworkPolicy      │  │
│  │  99.97%       │ │  0.02%       │ │   denials, DNS fail) │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
├────────────────────────────────────────────────────────────────┤
│  Level 2: Component Health (per network layer)                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │  Ingress/LB  │ │  Service Mesh│ │  DNS                 │  │
│  │  Dashboards  │ │  Dashboard   │ │  Dashboard           │  │
│  ├──────────────┤ ├──────────────┤ ├──────────────────────┤  │
│  │  CNI Plugin  │ │  Cloud       │ │  API Gateway         │  │
│  │  Dashboard   │ │  Networking  │ │  Dashboard           │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
├────────────────────────────────────────────────────────────────┤
│  Level 3: Deep Dive (per incident)                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │  Flow Logs   │ │  Packet      │ │  Trace Waterfall     │  │
│  │  Explorer    │ │  Captures    │ │  (per request)       │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

#### 6.3.2 Essential Network Dashboard Panels

**Grafana dashboard JSON structure for network health:**

```json
{
  "dashboard": {
    "title": "Network Health Overview",
    "tags": ["networking", "infrastructure"],
    "panels": [
      {
        "title": "DNS Health",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
        "targets": [{
          "expr": "1 - (sum(rate(coredns_dns_responses_total{rcode=\"SERVFAIL\"}[5m])) / sum(rate(coredns_dns_responses_total[5m])))",
          "legendFormat": "DNS Success Rate"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "thresholds": {
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 0.99, "color": "yellow"},
                {"value": 0.999, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "title": "Conntrack Utilization",
        "type": "gauge",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
        "targets": [{
          "expr": "max(node_nf_conntrack_entries / node_nf_conntrack_entries_limit) * 100"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "max": 100,
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 70, "color": "yellow"},
                {"value": 85, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "title": "Ingress Error Rate",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
        "targets": [{
          "expr": "sum(rate(nginx_ingress_controller_requests{status=~\"5..\"}[5m])) by (ingress) / sum(rate(nginx_ingress_controller_requests[5m])) by (ingress) * 100",
          "legendFormat": "{{ingress}}"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "custom": {
              "drawStyle": "line",
              "fillOpacity": 10
            }
          }
        }
      },
      {
        "title": "Network Policy Denials",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
        "targets": [{
          "expr": "sum(rate(cilium_drop_count_total{reason=\"POLICY_DENIED\"}[5m])) by (direction)",
          "legendFormat": "{{direction}}"
        }]
      },
      {
        "title": "TCP Retransmission Rate",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
        "targets": [{
          "expr": "rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) * 100",
          "legendFormat": "{{instance}}"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        }
      },
      {
        "title": "Cross-AZ Traffic (Cost)",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 12},
        "targets": [{
          "expr": "sum(rate(istio_tcp_sent_bytes_total{destination_az!~\"$source_az\"}[24h])) * 86400 / 1073741824",
          "legendFormat": "GB/day cross-AZ"
        }],
        "fieldConfig": {
          "defaults": {
            "unit": "decgbytes"
          }
        }
      }
    ]
  }
}
```

### 6.4 Network Alerting Strategy

#### 6.4.1 Alert Severity Tiers

```yaml
# PrometheusRule for network alerting
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-alerts
  namespace: monitoring
spec:
  groups:
  - name: network.critical
    rules:
    # P1: DNS completely broken
    - alert: DNSCompletelyDown
      expr: |
        sum(rate(coredns_dns_responses_total[5m])) == 0
      for: 2m
      labels:
        severity: critical
        team: platform
      annotations:
        summary: "CoreDNS is not responding to any queries"
        runbook_url: "https://runbooks.example.com/dns-down"

    # P1: Conntrack table exhausted
    - alert: ConntrackTableExhausted
      expr: |
        node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.95
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Conntrack table at {{ $value | humanizePercentage }} on {{ $labels.instance }}"
        description: "New connections will be dropped. Immediate action required."

    # P1: All ingress endpoints unhealthy
    - alert: IngressAllEndpointsDown
      expr: |
        kube_endpoint_address_available{namespace="ingress-nginx"} == 0
      for: 1m
      labels:
        severity: critical

    # P1: CNI plugin down on node
    - alert: CNIPluginDown
      expr: |
        kube_pod_status_ready{namespace="kube-system",pod=~"calico-node.*|cilium.*"} == 0
      for: 3m
      labels:
        severity: critical
      annotations:
        summary: "CNI plugin not ready on node"
        description: "Pods will not be able to get network connectivity on affected node"

  - name: network.warning
    rules:
    # P2: DNS error rate elevated
    - alert: DNSErrorRateHigh
      expr: |
        sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))
          /
        sum(rate(coredns_dns_responses_total[5m]))
          > 0.01
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "DNS SERVFAIL rate at {{ $value | humanizePercentage }}"

    # P2: Ingress 5xx error rate > 1%
    - alert: IngressHighErrorRate
      expr: |
        sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) by (ingress)
          /
        sum(rate(nginx_ingress_controller_requests[5m])) by (ingress)
          > 0.01
      for: 5m
      labels:
        severity: warning

    # P2: Network policy blocking expected traffic
    - alert: UnexpectedNetworkPolicyDenials
      expr: |
        sum(rate(cilium_drop_count_total{reason="POLICY_DENIED"}[5m])) by (direction) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Network policy denying {{ $value }} packets/sec ({{ $labels.direction }})"

    # P2: High TCP retransmission rate
    - alert: HighTCPRetransmissions
      expr: |
        rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) > 0.02
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "TCP retransmission rate at {{ $value | humanizePercentage }} on {{ $labels.instance }}"

    # P2: Certificate expiring within 14 days
    - alert: TLSCertificateExpiringSoon
      expr: |
        (nginx_ingress_controller_ssl_expire_time_seconds - time()) / 86400 < 14
      for: 1h
      labels:
        severity: warning

    # P2: IP address exhaustion (AWS VPC CNI)
    - alert: PodIPAddressExhaustion
      expr: |
        awscni_assigned_ip_addresses / awscni_ip_max > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Pod IP utilization at {{ $value | humanizePercentage }} on {{ $labels.instance }}"

  - name: network.info
    rules:
    # P3: Conntrack approaching limit
    - alert: ConntrackTableHigh
      expr: |
        node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.7
      for: 15m
      labels:
        severity: info

    # P3: BGP peer down (Calico)
    - alert: BGPPeerDown
      expr: |
        calico_bgp_peer_state != 1
      for: 5m
      labels:
        severity: info
      annotations:
        summary: "BGP peer {{ $labels.peer }} is down on {{ $labels.instance }}"

    # P3: DNS cache hit rate low (performance degradation)
    - alert: DNSCacheHitRateLow
      expr: |
        sum(rate(coredns_cache_hits_total[5m]))
          /
        (sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))
          < 0.5
      for: 15m
      labels:
        severity: info
```

---

## 7. Network Observability Architecture

### 7.1 Reference Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                 Network Observability Reference Architecture                  │
│                                                                              │
│  ┌─────────────────────── Collection Layer ──────────────────────────┐       │
│  │                                                                    │       │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │       │
│  │  │ SNMP     │ │ NetFlow/ │ │ Syslog   │ │ VPC/VNet │            │       │
│  │  │ Traps    │ │ IPFIX/   │ │ (RFC5424)│ │ Flow Logs│            │       │
│  │  │ & Polls  │ │ sFlow    │ │          │ │          │            │       │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘            │       │
│  │       │             │            │             │                   │       │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │       │
│  │  │ Prom     │ │ Hubble   │ │ eBPF     │ │ API      │            │       │
│  │  │ Metrics  │ │ Flows    │ │ (Cilium, │ │ Gateway  │            │       │
│  │  │ (scrape) │ │ (L3-L7)  │ │  Beyla)  │ │ Logs     │            │       │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘            │       │
│  │       │             │            │             │                   │       │
│  └───────┼─────────────┼────────────┼─────────────┼──────────────────┘       │
│          │             │            │             │                           │
│  ┌───────▼─────────────▼────────────▼─────────────▼──────────────────┐       │
│  │                    OTel Collector (Gateway)                         │       │
│  │                                                                    │       │
│  │  Receivers:    snmp, syslog, netflow, filelog, otlp, prometheus    │       │
│  │  Processors:   filter, transform, batch, attributes, tail_sample  │       │
│  │  Exporters:    otlp, prometheus, loki, opensearch, s3             │       │
│  └───────┬──────────────┬──────────────┬─────────────┬───────────────┘       │
│          │              │              │             │                        │
│  ┌───────▼──────┐ ┌─────▼──────┐ ┌────▼──────┐ ┌───▼──────────┐            │
│  │  Prometheus   │ │  Loki      │ │  Tempo    │ │  OpenSearch/ │            │
│  │  (metrics)    │ │  (logs)    │ │  (traces) │ │  ClickHouse  │            │
│  │  15d hot      │ │  30d hot   │ │  7d hot   │ │  (flow logs) │            │
│  │  → Thanos     │ │  → S3      │ │  → S3     │ │  90d warm    │            │
│  │    13mo cold  │ │    12mo    │ │    30d    │ │  → S3 cold   │            │
│  └───────┬───────┘ └─────┬──────┘ └────┬──────┘ └──────┬───────┘            │
│          │               │             │               │                     │
│  ┌───────▼───────────────▼─────────────▼───────────────▼───────────┐        │
│  │                      Grafana (Visualization)                      │        │
│  │  - Network Health Overview    - Flow Log Explorer                 │        │
│  │  - DNS Dashboard              - API Gateway Dashboard             │        │
│  │  - CNI Dashboard              - Trace Waterfall (Tempo)           │        │
│  │  - Ingress Dashboard          - Cloud Networking Dashboard        │        │
│  └──────────────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 OTel Collector for Network Telemetry

#### 7.2.1 SNMP Receiver Configuration

```yaml
# OTel Collector SNMP receiver for network devices
receivers:
  snmp:
    collection_interval: 60s
    endpoint: udp://0.0.0.0:162  # For SNMP traps
    version: v3
    security_level: authPriv
    user: otel_monitor
    auth_type: SHA256
    auth_password: "${SNMP_AUTH_PASSWORD}"
    privacy_type: AES256
    privacy_password: "${SNMP_PRIV_PASSWORD}"

    # Scalar OIDs (single values)
    resource_attributes:
      device.name:
        oid: "1.3.6.1.2.1.1.5.0"  # sysName
        type: string
      device.uptime:
        oid: "1.3.6.1.2.1.1.3.0"  # sysUpTime
        type: int

    # Tabular metrics (per-interface)
    metrics:
      # Interface traffic
      network.interface.bytes.received:
        unit: By
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.2.1.31.1.1.1.6"  # ifHCInOctets
          resource_attributes:
          - interface.name:
              oid: "1.3.6.1.2.1.31.1.1.1.1"  # ifName
              type: string

      network.interface.bytes.transmitted:
        unit: By
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.2.1.31.1.1.1.10"  # ifHCOutOctets
          resource_attributes:
          - interface.name:
              oid: "1.3.6.1.2.1.31.1.1.1.1"
              type: string

      network.interface.errors.received:
        unit: "{errors}"
        sum:
          value_type: int
          monotonic: true
          aggregation_temporality: cumulative
        column_oids:
        - oid: "1.3.6.1.2.1.2.2.1.14"  # ifInErrors

      network.interface.errors.transmitted:
        unit: "{errors}"
        sum:
          value_type: int
          monotonic: true
          aggregation_temporality: cumulative
        column_oids:
        - oid: "1.3.6.1.2.1.2.2.1.20"  # ifOutErrors

      network.interface.operational_status:
        unit: ""
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.2.1.2.2.1.8"  # ifOperStatus (1=up, 2=down)

      # BGP peer metrics (for routers)
      network.bgp.peer.state:
        unit: ""
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.2.1.15.3.1.2"  # bgpPeerState
          resource_attributes:
          - bgp.peer.address:
              oid: "1.3.6.1.2.1.15.3.1.7"
              type: string

      network.bgp.peer.routes_received:
        unit: "{routes}"
        gauge:
          value_type: int
        column_oids:
        - oid: "1.3.6.1.2.1.15.3.1.17"  # bgpPeerInTotalMessages
```

#### 7.2.2 NetFlow/IPFIX Receiver

```yaml
# OTel Collector NetFlow receiver
receivers:
  netflow:
    endpoint: "0.0.0.0:2055"  # Standard NetFlow port
    protocols:
    - netflow_v5
    - netflow_v9
    - ipfix
    - sflow
    workers: 4
    queue_size: 100000

processors:
  # Enrich flow data with K8s metadata
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    extract:
      metadata:
      - k8s.pod.name
      - k8s.namespace.name
      - k8s.node.name
      - k8s.deployment.name
    pod_association:
    - sources:
      - from: resource_attribute
        name: k8s.pod.ip

  # Filter out high-volume low-value flows
  filter/netflow:
    logs:
      exclude:
        match_type: strict
        record_attributes:
        # Exclude health check traffic
        - key: dst_port
          value: "10250"  # kubelet health
        - key: dst_port
          value: "10256"  # kube-proxy health

  # Aggregate flows to reduce cardinality
  transform/netflow_aggregate:
    log_statements:
    - context: log
      statements:
      # Normalize source port to reduce cardinality (ephemeral ports are noise)
      - set(attributes["src_port_category"], "ephemeral") where attributes["src_port"] > 32767
      - set(attributes["src_port_category"], "well-known") where attributes["src_port"] <= 1023
      - set(attributes["src_port_category"], "registered") where attributes["src_port"] > 1023 and attributes["src_port"] <= 32767
```

#### 7.2.3 Syslog Receiver for Network Devices

```yaml
# OTel Collector syslog receiver
receivers:
  syslog/network_devices:
    udp:
      listen_address: "0.0.0.0:5514"
    tcp:
      listen_address: "0.0.0.0:5514"
      tls:
        cert_file: /etc/otel/tls/cert.pem
        key_file: /etc/otel/tls/key.pem
    protocol: rfc5424
    operators:
    # Parse Cisco IOS syslog format
    - type: regex_parser
      regex: '%(?P<facility>[A-Z_]+)-(?P<severity>\d)-(?P<mnemonic>[A-Z_]+): (?P<message>.*)'
      parse_from: body
      parse_to: attributes

    # Parse Juniper syslog format
    - type: regex_parser
      regex: '(?P<process>[a-z]+)\[(?P<pid>\d+)\]: (?P<event_id>[A-Z_]+): (?P<message>.*)'
      parse_from: body
      parse_to: attributes
      if: 'attributes["facility"] == nil'

processors:
  # Route by severity
  filter/syslog_critical:
    logs:
      include:
        match_type: regexp
        record_attributes:
        - key: severity
          value: "^[0-3]$"  # Emergency, Alert, Critical, Error

  # Add device metadata
  attributes/device_enrichment:
    actions:
    - key: device.type
      action: upsert
      from_attribute: hostname
      # Map hostnames to device types
    - key: network.region
      action: upsert
      value: "us-east-1"

exporters:
  loki/network_syslog:
    endpoint: http://loki.observability.svc:3100/loki/api/v1/push
    labels:
      resource:
        device.type: "device_type"
      attributes:
        severity: "severity"
        facility: "facility"
        mnemonic: "mnemonic"
```

### 7.3 Cost Optimization for Network Telemetry

Network observability generates enormous data volumes. Cost optimization is essential:

#### 7.3.1 Data Volume Estimates

| Data Source | Volume per Node/Device | 100 Nodes / 50 Devices |
|-------------|----------------------|------------------------|
| VPC Flow Logs (sampled 10%) | 50 MB/day | 5 GB/day |
| VPC Flow Logs (100%) | 500 MB/day | 50 GB/day |
| SNMP metrics (60s interval) | 2 MB/day | 100 MB/day |
| NetFlow/IPFIX | 100 MB/day | 5 GB/day |
| Syslog | 20 MB/day | 1 GB/day |
| Hubble flows (L3-L7) | 200 MB/day | 20 GB/day |
| Prometheus metrics (CNI+kube-proxy) | 5 MB/day | 500 MB/day |
| API Gateway access logs | 50 MB/day per 1M reqs | Variable |
| **Total (conservative)** | | **~30-80 GB/day** |

#### 7.3.2 Cost Optimization Strategies

```yaml
# 1. Sampling: Reduce flow log volume by 80-90%
# AWS VPC Flow Logs
MaxAggregationInterval: 600  # 10 minutes instead of 1 minute (10x reduction)

# GCP VPC Flow Logs
log_config {
  flow_sampling = 0.1  # 10% sampling (90% reduction)
  aggregation_interval = "INTERVAL_10_MIN"
}

# Hubble flows: sample non-error flows
# 2. Filtering: Drop known-good traffic
processors:
  filter/drop_health_checks:
    logs:
      exclude:
        match_type: regexp
        record_attributes:
        - key: dst_port
          value: "^(10250|10256|10257|10259|9090|9091|9153)$"
        - key: http.path
          value: "^/(health|ready|live|metrics|ping)$"

  # 3. Aggregation: Reduce metric cardinality
  metricstransform:
    transforms:
    - include: ".*"
      match_type: regexp
      action: update
      operations:
      # Drop high-cardinality labels
      - action: delete_label_value
        label: pod_ip
      - action: delete_label_value
        label: instance_id
      - action: aggregate_labels
        label_set: [service, namespace, status_code_class]
        aggregation_type: sum

# 4. Tiered retention
# Hot tier (SSD/memory): 7 days - for active troubleshooting
# Warm tier (HDD/block storage): 30 days - for trend analysis
# Cold tier (S3/GCS/Blob): 12 months - for compliance
# Archive: 7 years - for regulated industries
```

#### 7.3.3 Cost Optimization by Data Type

| Data Type | Hot Retention | Warm Retention | Cold Retention | Optimization |
|-----------|--------------|----------------|----------------|-------------|
| Flow Logs | 7 days | 30 days (sampled) | 12 months (Parquet in S3) | Sample 10%, aggregate to 10min, Parquet format |
| SNMP Metrics | 15 days (full res) | 90 days (5min avg) | 12 months (1h avg) | Downsample with Thanos/VictoriaMetrics |
| Network Syslog | 7 days | 30 days (errors only) | 12 months (critical only) | Severity filter, structured parsing |
| API Gateway Logs | 7 days | 30 days | 12 months | Sample 10% of 2xx, keep all errors |
| Hubble L7 Flows | 3 days | 14 days (errors + slow) | 90 days (aggregated) | Tail sampling (errors + p99 latency) |
| Trace Data | 7 days | 30 days (sampled) | None | Head sampling 10%, keep all errors |

### 7.4 Capacity Planning

#### 7.4.1 OTel Collector Sizing for Network Telemetry

```yaml
# OTel Collector resource requirements
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-network
spec:
  replicas: 3  # Minimum for HA
  template:
    spec:
      containers:
      - name: otel-collector
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
        env:
        # Tune Go garbage collector for throughput
        - name: GOGC
          value: "80"
        - name: GOMEMLIMIT
          value: "7GiB"
```

**Sizing guidelines:**

| Workload | CPU | Memory | Throughput |
|----------|-----|--------|------------|
| SNMP (100 devices, 60s) | 0.5 CPU | 512 MB | ~1,000 metrics/sec |
| Syslog (50 devices) | 0.5 CPU | 1 GB | ~5,000 events/sec |
| NetFlow (10 exporters) | 1 CPU | 2 GB | ~50,000 flows/sec |
| VPC Flow Logs (from S3) | 1 CPU | 2 GB | ~100,000 records/sec |
| Hubble (100 nodes) | 2 CPU | 4 GB | ~200,000 flows/sec |
| **Combined gateway** | **4 CPU** | **8 GB** | **~400,000 events/sec** |

---

## 8. Emerging Trends

### 8.1 eBPF Revolution in Network Observability

eBPF (extended Berkeley Packet Filter) is fundamentally changing network observability by allowing kernel-level programmable monitoring without kernel modifications or sidecar proxies.

#### 8.1.1 eBPF Observability Capabilities

```
┌──────────────────────────────────────────────────────────────────────┐
│                   eBPF Networking Observability                       │
│                                                                      │
│  Hook Points:                                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  XDP (eXpress Data Path)          - Before kernel networking  │   │
│  │  ├── Packet filtering (DDoS)      - Wire speed (10M+ pps)    │   │
│  │  ├── Load balancing               - Bypass iptables entirely  │   │
│  │  └── Flow sampling                - Zero-copy packet access   │   │
│  │                                                                │   │
│  │  TC (Traffic Control)             - After L2, before L3       │   │
│  │  ├── Policy enforcement           - Full packet access        │   │
│  │  ├── NAT                          - Connection tracking       │   │
│  │  └── Flow logging                 - L3/L4 flow records        │   │
│  │                                                                │   │
│  │  Socket Operations (sock_ops)     - At socket layer           │   │
│  │  ├── Connection tracking          - TCP state machine events  │   │
│  │  ├── TCP metrics                  - RTT, retransmits, cwnd    │   │
│  │  └── Socket redirect             - Bypass kernel stack        │   │
│  │                                                                │   │
│  │  Kprobes/Tracepoints             - Kernel function hooks      │   │
│  │  ├── DNS resolution tracking      - Hook dns_resolve          │   │
│  │  ├── TLS handshake monitoring    - Hook SSL_do_handshake      │   │
│  │  └── syscall tracing             - connect, accept, sendmsg  │   │
│  │                                                                │   │
│  │  Uprobes                          - User-space function hooks │   │
│  │  ├── HTTP/2 frame parsing         - Hook nghttp2 library     │   │
│  │  ├── gRPC method extraction       - Hook grpc library         │   │
│  │  └── TLS plaintext capture        - Hook OpenSSL/BoringSSL   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Advantages over traditional approaches:                             │
│  - No application changes required                                   │
│  - No sidecar proxy overhead (Cilium: 0-3% vs Envoy: 5-15%)        │
│  - Kernel-level visibility (sees everything, not just user-space)    │
│  - Dynamic: load/unload programs without restart                     │
│  - Safe: eBPF verifier prevents crashes and infinite loops           │
│  - Fast: JIT compiled to native code, runs at near wire speed        │
└──────────────────────────────────────────────────────────────────────┘
```

#### 8.1.2 eBPF Tools Ecosystem for Network Observability

| Tool | Vendor | Focus | Key Capabilities |
|------|--------|-------|-----------------|
| **Cilium** | Isovalent (Cisco) | CNI + Mesh | L3-L7 policy, Hubble flows, service mesh |
| **Pixie** | New Relic (CNCF) | Auto-observability | No-instrumentation HTTP/gRPC/DNS/MySQL tracing |
| **Beyla** | Grafana Labs | Auto-instrumentation | HTTP/gRPC metrics + traces without SDK |
| **Kepler** | Red Hat (CNCF) | Energy monitoring | Per-pod power consumption via eBPF |
| **Inspektor Gadget** | Microsoft (CNCF) | K8s debugging | Network tracing, DNS monitoring, TCP analysis |
| **Tetragon** | Isovalent (Cisco) | Security observability | Process lifecycle, network connections, file access |
| **Falco** | Sysdig (CNCF) | Runtime security | Syscall monitoring, network policy violations |
| **Retina** | Microsoft | K8s networking | Network health, DNS, packet capture |
| **Coroot** | Coroot | Auto-instrumentation | eBPF-based service map and golden signals |
| **Groundcover** | Groundcover | Full-stack APM | eBPF-first APM with network visibility |

#### 8.1.3 Grafana Beyla for Network Observability

```yaml
# Beyla deployment for auto-instrumentation
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: beyla
  namespace: observability
spec:
  template:
    spec:
      hostPID: true  # Required for eBPF access
      containers:
      - name: beyla
        image: grafana/beyla:1.8
        securityContext:
          privileged: true
        env:
        - name: BEYLA_OPEN_PORT
          value: "80,443,8080,3000,5000,8443,9090"
        - name: BEYLA_SERVICE_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector.observability.svc:4318"
        - name: BEYLA_METRICS_FEATURES
          value: "application,application_service_graph,application_span"
        - name: BEYLA_NETWORK_METRICS
          value: "true"
        - name: BEYLA_KUBE_METADATA_ENABLE
          value: "autodetect"
        volumeMounts:
        - name: bpf-fs
          mountPath: /sys/fs/bpf
        - name: cgroup
          mountPath: /sys/fs/cgroup
      volumes:
      - name: bpf-fs
        hostPath:
          path: /sys/fs/bpf
      - name: cgroup
        hostPath:
          path: /sys/fs/cgroup
```

**Beyla auto-discovered metrics:**

```promql
# HTTP request rate (auto-discovered, no SDK needed)
sum(rate(http_server_request_duration_seconds_count[5m])) by (
  service_name, http_request_method, url_path
)

# HTTP latency
histogram_quantile(0.99,
  sum(rate(http_server_request_duration_seconds_bucket[5m]))
  by (le, service_name)
)

# gRPC method latency (auto-discovered)
histogram_quantile(0.99,
  sum(rate(rpc_server_duration_seconds_bucket[5m]))
  by (le, service_name, rpc_method)
)

# Network-level metrics (Beyla network feature)
sum(rate(beyla_network_flow_bytes_total[5m])) by (
  src_name, dst_name, direction
)
```

### 8.2 Ambient Mesh (Istio ztunnel and Waypoint Proxies)

Istio Ambient Mesh eliminates sidecar proxies in favor of a two-layer architecture:

```
┌──────────────────────────────────────────────────────────────────────┐
│              Istio Ambient Mesh Architecture                          │
│                                                                      │
│  Traditional Sidecar:                                                │
│  [Pod] ↔ [Envoy Sidecar] ↔ [Network] ↔ [Envoy Sidecar] ↔ [Pod]   │
│  - Memory: ~50-100MB per pod                                         │
│  - Latency: +0.5-2ms per hop (2 proxies per request)                │
│  - CPU: 5-15% overhead                                               │
│                                                                      │
│  Ambient Mesh (L4 only - ztunnel):                                   │
│  [Pod] ↔ [ztunnel (per-node)] ↔ [Network] ↔ [ztunnel] ↔ [Pod]     │
│  - Memory: ~20MB per node (not per pod!)                             │
│  - Latency: +0.1-0.3ms (Rust-based, optimized)                      │
│  - CPU: 1-3% overhead                                                │
│  - Provides: mTLS, L4 authorization, L4 telemetry                   │
│                                                                      │
│  Ambient Mesh (L4 + L7 - ztunnel + waypoint):                       │
│  [Pod] ↔ [ztunnel] ↔ [Waypoint Proxy] ↔ [ztunnel] ↔ [Pod]         │
│  - Waypoint only deployed for services that need L7 features         │
│  - Memory: ~50MB per waypoint (shared by namespace/service)          │
│  - Provides: HTTP routing, retries, L7 policies, L7 telemetry       │
└──────────────────────────────────────────────────────────────────────┘
```

#### 8.2.1 ztunnel Observability

```yaml
# ztunnel metrics (available on port 15020)
# ztunnel is a Rust-based L4 proxy running as a DaemonSet
```

```promql
# ztunnel connection metrics
sum(rate(ztunnel_tcp_connections_opened_total[5m])) by (
  reporter, source_workload, destination_workload
)

# ztunnel bytes transferred
sum(rate(ztunnel_tcp_sent_bytes_total[5m])) by (
  source_workload, destination_workload
)

# ztunnel connection errors
sum(rate(ztunnel_tcp_connections_close_total{error!=""}[5m])) by (error)

# mTLS status (all connections should be mTLS in ambient)
sum(rate(ztunnel_tcp_connections_opened_total{security_policy="mutual_tls"}[5m]))
  /
sum(rate(ztunnel_tcp_connections_opened_total[5m]))
```

#### 8.2.2 Waypoint Proxy Observability

Waypoint proxies provide L7 metrics when deployed:

```yaml
# Deploy a waypoint proxy for a namespace
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-namespace-waypoint
  namespace: my-namespace
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

```promql
# Waypoint L7 metrics (same as sidecar Envoy metrics)
sum(rate(istio_requests_total[5m])) by (
  source_workload, destination_workload, response_code
)

# Waypoint-specific: distinguish L4-only vs L7 traffic
sum(rate(istio_requests_total[5m])) by (reporter)
# reporter="waypoint" indicates L7 processing
# reporter="ztunnel" indicates L4-only path
```

### 8.3 Gateway API Standards Evolution

The Kubernetes Gateway API is becoming the standard for all ingress and mesh traffic management:

#### 8.3.1 Gateway API Observability Extensions (GEP-1709)

```yaml
# Proposed standard metrics for Gateway API implementations
# GEP-1709: Gateway API Metrics
# These metrics will be consistent across all implementations:
# - Envoy Gateway
# - Istio
# - Kong
# - Traefik
# - HAProxy
# - Cilium Gateway

# Standard metric names (proposed):
# gateway_api_http_route_request_total
# gateway_api_http_route_request_duration_seconds
# gateway_api_http_route_request_size_bytes
# gateway_api_http_route_response_size_bytes
# gateway_api_gateway_listener_connections_total
# gateway_api_gateway_listener_tls_handshake_duration_seconds
```

#### 8.3.2 Gateway API Policy Attachments for Observability

```yaml
# Policy attachment for access logging (future standard)
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: BackendTrafficPolicy
metadata:
  name: observability-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-route
  # Implementation-specific observability config
  rateLimit:
    type: local
    local:
      rules:
      - limit:
          requests: 100
          unit: second
  timeout:
    request: "30s"
    backendRequest: "25s"
  retries:
    numRetries: 3
    perRetry:
      timeout: "5s"
    retryOn:
    - "5xx"
    - "reset"
    - "connect-failure"
```

### 8.4 Network Digital Twin

Network digital twins create a virtual replica of the production network for simulation, testing, and anomaly detection:

```
┌──────────────────────────────────────────────────────────────────────┐
│              Network Digital Twin Architecture                        │
│                                                                      │
│  Production Network                    Digital Twin                   │
│  ┌──────────────────┐                 ┌──────────────────┐          │
│  │  Routers         │  ──telemetry──► │  Virtual Routers │          │
│  │  Switches        │                 │  Virtual Switches│          │
│  │  Firewalls       │                 │  Virtual Firewalls│         │
│  │  Load Balancers  │                 │  Virtual LBs     │          │
│  └──────────────────┘                 └──────────────────┘          │
│                                              │                       │
│  Use Cases:                                  ▼                       │
│  1. "What-if" analysis     ┌──────────────────────┐                 │
│  2. Change validation      │  Simulation Engine   │                 │
│  3. Capacity planning      │  (Forward Defender,  │                 │
│  4. Failure simulation     │   Batfish, NetBox +  │                 │
│  5. Compliance checking    │   network models)    │                 │
│  6. Training/education     └──────────────────────┘                 │
└──────────────────────────────────────────────────────────────────────┘
```

**Tools for network digital twins:**

| Tool | Function | Use Case |
|------|----------|----------|
| **Batfish** | Network configuration analysis | Validate changes before deployment |
| **Forward Networks** | Enterprise network verification | Compliance, "what-if" analysis |
| **NetBox** | Network source of truth (DCIM/IPAM) | Topology modeling, IP management |
| **GNS3/EVE-NG** | Network simulation | Lab environments, training |
| **Containerlab** | Container-based network lab | CI/CD testing of network configs |
| **Cisco Modeling Labs** | Enterprise network simulation | Complex topology testing |

### 8.5 AI/ML for Network Anomaly Detection

#### 8.5.1 ML-Based Network Anomaly Detection Patterns

```python
# Conceptual: ML anomaly detection for network metrics
# Using Prophet for time-series anomaly detection

from prophet import Prophet
import pandas as pd

# 1. Baseline normal behavior
def detect_traffic_anomalies(metric_name, prometheus_url):
    """
    Detect anomalies in network traffic patterns.
    Trains on 2 weeks of data, detects deviations from expected patterns.
    """
    # Query historical data
    query = f'sum(rate({metric_name}[5m]))'
    df = query_prometheus_range(prometheus_url, query, days=14)

    # Fit Prophet model (handles seasonality: daily, weekly)
    model = Prophet(
        changepoint_prior_scale=0.05,
        seasonality_prior_scale=10,
        interval_width=0.99  # 99% confidence interval
    )
    model.add_seasonality(name='hourly', period=1/24, fourier_order=5)
    model.fit(df)

    # Forecast and compare
    future = model.make_future_dataframe(periods=24, freq='H')
    forecast = model.predict(future)

    # Anomalies: actual value outside confidence interval
    anomalies = df.merge(forecast[['ds', 'yhat_lower', 'yhat_upper']], on='ds')
    anomalies['is_anomaly'] = (
        (anomalies['y'] < anomalies['yhat_lower']) |
        (anomalies['y'] > anomalies['yhat_upper'])
    )

    return anomalies[anomalies['is_anomaly']]

# 2. Specific network anomaly patterns to detect:
anomaly_patterns = {
    "traffic_spike": {
        "metric": "sum(rate(nginx_ingress_controller_requests[5m]))",
        "description": "Sudden increase in traffic (DDoS, viral content, misconfigured client)",
        "threshold": "3x standard deviation from 7-day baseline"
    },
    "latency_degradation": {
        "metric": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])))",
        "description": "Gradual latency increase (resource exhaustion, network congestion)",
        "threshold": "2x baseline p99 sustained for > 10 minutes"
    },
    "dns_failure_pattern": {
        "metric": "sum(rate(coredns_dns_responses_total{rcode='SERVFAIL'}[5m]))",
        "description": "DNS failure spike correlating with upstream issues",
        "threshold": "Any sustained increase from zero baseline"
    },
    "connection_leak": {
        "metric": "node_nf_conntrack_entries",
        "description": "Monotonically increasing conntrack count (connection leak)",
        "threshold": "Linear increase without corresponding traffic increase"
    },
    "asymmetric_traffic": {
        "metric": "rate(node_network_transmit_bytes_total[5m]) / rate(node_network_receive_bytes_total[5m])",
        "description": "Abnormal tx/rx ratio (data exfiltration, misconfigured routing)",
        "threshold": "Ratio deviation > 2x from 30-day baseline"
    }
}
```

#### 8.5.2 AIOps Platforms for Network Observability

| Platform | Network-Specific Features |
|----------|--------------------------|
| **Moogsoft** | Network event correlation, topology-aware alerting, noise reduction |
| **BigPanda** | Cross-domain correlation (network + app + infra), root cause analysis |
| **Datadog NPM** | ML-powered network map anomaly detection, DNS analytics |
| **Kentik** | Network-first ML: DDoS detection, capacity forecasting, peering analytics |
| **ThousandEyes (Cisco)** | Internet path intelligence, ML for routing anomalies |
| **Auvik** | Network device discovery, automated topology mapping, alert ML |
| **LogicMonitor** | Adaptive thresholds for network metrics, forecasting |

### 8.6 Intent-Based Networking (IBN)

Intent-based networking translates high-level business intent into network configurations and continuously validates compliance:

```yaml
# Conceptual: Intent-based network policy
# "Production frontend can only talk to production API, nothing else"
apiVersion: intent.networking.k8s.io/v1alpha1  # hypothetical
kind: NetworkIntent
metadata:
  name: frontend-isolation
spec:
  description: "Frontend services should only reach API tier"
  intent:
    source:
      selector:
        matchLabels:
          tier: frontend
          env: production
    allowed_destinations:
    - selector:
        matchLabels:
          tier: api
          env: production
      ports: [8080, 8443]
    denied_destinations:
    - all_other: true

  # Continuous validation
  compliance:
    monitoring:
      alert_on_violation: true
      log_all_connections: true
    drift_detection:
      interval: 5m
      action: alert  # or "enforce" (auto-remediate)
```

**Current IBN-like tools:**

| Tool | Approach |
|------|----------|
| **Cilium Network Policies** | Kubernetes-native, identity-aware L3-L7 policies |
| **Calico Enterprise** | Tier-based policy model with audit logging |
| **NSX-T (VMware)** | Micro-segmentation with intent-based firewall rules |
| **Cisco ACI** | Application-centric networking with contract-based policies |
| **Apstra (Juniper)** | Intent-based data center networking with continuous validation |

### 8.7 IPv6 Observability

As Kubernetes and cloud providers adopt dual-stack and IPv6-only networking, observability must adapt:

```yaml
# Kubernetes dual-stack configuration
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ipFamilies:
  - IPv4
  - IPv6
  ipFamilyPolicy: PreferDualStack
  selector:
    app: my-app
  ports:
  - port: 80
```

**IPv6-specific monitoring considerations:**

```promql
# IPv6 traffic ratio (track migration progress)
sum(rate(node_network_receive_bytes_total{device="eth0"}[5m])) by (instance)
# Need to differentiate IPv4 vs IPv6 at the flow level

# DNS AAAA record queries (IPv6 name resolution)
sum(rate(coredns_dns_requests_total{type="AAAA"}[5m]))
  /
sum(rate(coredns_dns_requests_total[5m]))

# IPv6 neighbor discovery issues
rate(node_netstat_Icmp6_InNeighborSolicits[5m])
rate(node_netstat_Icmp6_OutNeighborAdvertisements[5m])

# IPv6 fragmentation (should be minimal - PMTUD)
rate(node_netstat_Ip6_FragCreates[5m])
```

### 8.8 5G and Edge Networking Observability

As 5G enables edge computing, network observability extends to multi-access edge computing (MEC):

**Key 5G/Edge observability challenges:**

| Challenge | Impact | Observability Approach |
|-----------|--------|----------------------|
| **Variable latency** | 1-10ms (5G) vs 20-100ms (4G) vs 50-300ms (WiFi) | Per-connection latency histograms by access type |
| **Network slicing** | Different SLAs per slice | Metrics labeled by slice ID, per-slice SLA dashboards |
| **Edge-to-cloud** | Data must traverse edge→regional→central | End-to-end trace context across all tiers |
| **Mobility** | Devices move between cells/edges | Session continuity monitoring, handover metrics |
| **Scale** | Millions of IoT devices | Aggregated metrics (not per-device), sampling |
| **Intermittent connectivity** | Edge sites may disconnect | Store-and-forward telemetry, local buffering |

```yaml
# OTel Collector at the edge (resource-constrained)
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 4

processors:
  # Aggressive filtering at edge to reduce bandwidth
  filter/edge:
    logs:
      include:
        severity_number:
          min: "WARN"  # Only send WARN+ from edge
    metrics:
      include:
        match_type: regexp
        metric_names:
        - "http_.*"
        - "system_.*"
        # Drop verbose metrics at edge

  # Batch aggressively (reduce connection frequency)
  batch:
    send_batch_size: 10000
    send_batch_max_size: 15000
    timeout: 30s  # Longer batch window at edge

exporters:
  otlp:
    endpoint: regional-collector.example.com:4317
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 300s
      max_elapsed_time: 3600s  # Retry for up to 1 hour
    sending_queue:
      enabled: true
      num_consumers: 2
      queue_size: 10000
      storage: file_storage  # Persist queue to disk
    compression: zstd        # Best compression ratio

extensions:
  file_storage:
    directory: /var/lib/otel/queue
    timeout: 10s
    compaction:
      on_start: true
      directory: /var/lib/otel/queue/compaction
```

---

## Summary and Recommendations

### Key Takeaways for Consulting Engagements

1. **Start with DNS and conntrack**: These two areas account for 60%+ of Kubernetes network issues. Ensure CoreDNS metrics, conntrack monitoring, and ndots optimization are in place before anything else.

2. **Choose CNI based on observability needs**: Cilium provides the richest out-of-box observability (Hubble L3-L7 flows), followed by Calico (Felix metrics + Enterprise flow logs). Flannel requires external tooling for any meaningful network visibility.

3. **Layer your monitoring**: L7 (Ingress/Gateway) → L4 (Service/kube-proxy) → L3 (CNI) → L2 (Node network). Each layer catches different failure modes.

4. **Instrument API gateways deeply**: Track the latency breakdown (gateway overhead vs upstream latency), auth failures, rate limiting, and per-consumer metrics. These are critical for API-first businesses.

5. **Flow logs are expensive**: Always sample in production (10-50%), use Parquet format for storage, and implement tiered retention. Full flow logging should be reserved for security investigations.

6. **eBPF is the future**: For new deployments, prefer Cilium (CNI) + Beyla (auto-instrumentation) + Tetragon (security). This stack provides L3-L7 visibility without sidecars or application changes.

7. **Multi-cloud requires unified collection**: Use OTel Collector as the universal collection layer across AWS, Azure, and GCP. Normalize metrics into a common schema for cross-cloud dashboards.

8. **Trace context propagation is fragile**: Audit every proxy, load balancer, message queue, and gateway in the request path to ensure W3C Trace Context headers are preserved. A single broken link fragments your traces.

### Maturity Model

| Level | Capabilities | Tools |
|-------|-------------|-------|
| **L1: Basic** | Node metrics, ping/uptime, basic SNMP | node_exporter, Prometheus, SNMP |
| **L2: Intermediate** | DNS metrics, kube-proxy metrics, ingress metrics, conntrack | CoreDNS prometheus, NGINX Ingress metrics |
| **L3: Advanced** | CNI-level flow logs, NetworkPolicy monitoring, API gateway deep metrics | Cilium Hubble, Calico Felix, Kong Vitals |
| **L4: Expert** | Cross-layer correlation (flows ↔ traces), cloud networking integration, eBPF | eBPF tools, OTel Collector, multi-cloud dashboards |
| **L5: Autonomous** | ML anomaly detection, intent-based policies, network digital twin, self-healing | AIOps platforms, Batfish, custom ML models |

---

*This document is Part 3 of the Networking Observability series for the OllyStack consulting knowledge base. Part 1 covers foundational network monitoring (SNMP, NetFlow, DNS, TLS). Part 2 covers service mesh observability (Istio, Linkerd, Cilium mesh, Consul Connect) and eBPF-based networking tools.*
