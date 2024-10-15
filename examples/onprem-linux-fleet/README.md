# On-Premises Linux Fleet Deployment

Guide for deploying the OllyStack OpenTelemetry Collector to a fleet of Linux servers using Ansible.

## Architecture

```
+-------------------+     +-------------------+
|  Linux Server 1   |     |  Linux Server 2   |
|  +--------------+ |     |  +--------------+ |
|  | OTel Agent   | |     |  | OTel Agent   | |
|  | (systemd)    +-+--+--+--+ (systemd)    | |
|  +--------------+ |  |  |  +--------------+ |
+-------------------+  |  +-------------------+
                        |
+-------------------+   |  +-------------------+
|  Linux Server 3   |   |  |  Gateway Server   |
|  +--------------+ |   |  |  +--------------+ |
|  | OTel Agent   | |   +--+->| OTel Gateway | |
|  | (systemd)    +-+---+  |  | (systemd)    | |
|  +--------------+ |      |  +------+-------+ |
+-------------------+      +---------|----------+
                                      |
                              +-------v--------+
                              |  Backends       |
                              |  - Jaeger       |
                              |  - Prometheus   |
                              |  - Loki         |
                              +----------------+
```

## Prerequisites

- **Ansible** v2.14+ installed on the control machine
- **SSH access** to all target servers (key-based recommended)
- **Python 3.8+** on target servers
- **systemd** on all target servers
- Target servers running a supported Linux distribution:
  - Ubuntu 20.04+, Debian 11+
  - RHEL 8+, CentOS Stream 8+, Rocky Linux 8+, AlmaLinux 8+
  - Amazon Linux 2023

## Directory Structure

```
onprem-linux-fleet/
  README.md              # This file
  inventory.ini          # Ansible inventory with host groups
  deploy.sh              # Wrapper script for deployment
```

## Quick Start

### 1. Edit Inventory

Update `inventory.ini` with your actual server hostnames/IPs:

```bash
vim examples/onprem-linux-fleet/inventory.ini
```

### 2. Configure Variables

Edit the deployment variables in the inventory file or create a `group_vars/` directory:

```bash
# Key variables to set:
# - gateway_endpoint: Where agents send telemetry
# - otel_version: Collector version to install
# - backend_*: Backend endpoints for the gateway
```

### 3. Run Deployment

```bash
# Deploy everything (agents + gateway)
./examples/onprem-linux-fleet/deploy.sh

# Deploy agents only
./examples/onprem-linux-fleet/deploy.sh --tags agents

# Deploy gateway only
./examples/onprem-linux-fleet/deploy.sh --tags gateway

# Dry run (check mode)
./examples/onprem-linux-fleet/deploy.sh --check

# Limit to specific hosts
./examples/onprem-linux-fleet/deploy.sh --limit "web-servers"
```

## Verification

### Check Agent Status

```bash
# On each server
sudo systemctl status otelcol-contrib
sudo journalctl -u otelcol-contrib -f --no-pager -n 50

# Verify health endpoint
curl http://localhost:13133/health

# Check agent is sending data
curl http://localhost:8888/metrics | grep otelcol_exporter_sent
```

### Check Gateway Status

```bash
# On gateway server
sudo systemctl status otelcol-contrib
curl http://gateway-host:13133/health

# Verify data reception
curl http://gateway-host:8888/metrics | grep otelcol_receiver_accepted
```

## Configuration

### Agent Configuration

Agents are configured to:
- Collect host metrics (CPU, memory, disk, network, filesystem, load)
- Receive OTLP telemetry from local applications (gRPC :4317, HTTP :4318)
- Collect system logs via journald and syslog
- Forward all telemetry to the gateway via OTLP gRPC

### Gateway Configuration

The gateway is configured to:
- Receive OTLP telemetry from all agents
- Process, batch, and enrich data
- Export traces to Jaeger
- Export metrics to Prometheus (remote write)
- Export logs to Loki

## Updating the Collector

```bash
# Update to a new version
./examples/onprem-linux-fleet/deploy.sh -e "otel_version=0.96.0"

# Rolling restart (one host at a time)
./examples/onprem-linux-fleet/deploy.sh --tags restart -f 1
```

## Uninstalling

```bash
# Stop and disable the service
ansible all -i examples/onprem-linux-fleet/inventory.ini \
  -m systemd -a "name=otelcol-contrib state=stopped enabled=no" -b

# Remove the package
ansible all -i examples/onprem-linux-fleet/inventory.ini \
  -m package -a "name=otelcol-contrib state=absent" -b
```

## Troubleshooting

### Agent not starting

1. Check systemd logs: `journalctl -u otelcol-contrib -n 100 --no-pager`
2. Validate config: `otelcol-contrib validate --config=/etc/otelcol-contrib/config.yaml`
3. Check permissions on config file: `ls -la /etc/otelcol-contrib/`

### Agent not reaching gateway

1. Verify network connectivity: `nc -zv gateway-host 4317`
2. Check firewall rules: `sudo iptables -L` or `sudo firewall-cmd --list-all`
3. Verify gateway is listening: `ss -tlnp | grep 4317`

### High resource usage

1. Reduce scrape frequency in hostmetrics receiver
2. Enable memory_limiter processor
3. Increase batch timeout to reduce export frequency
