#!/usr/bin/env bash
# install-collector.sh
# Installs and configures the OpenTelemetry Collector on a GCE instance
# Usage: sudo ./install-collector.sh
#
# Prerequisites:
#   - GCE instance with a service account attached that has the following roles:
#     - roles/monitoring.metricWriter
#     - roles/cloudtrace.agent
#     - roles/logging.logWriter
#   - curl and systemctl available

set -euo pipefail

# --- Configuration ---
OTEL_VERSION="${OTEL_COLLECTOR_VERSION:-0.96.0}"
OTEL_USER="${OTEL_USER:-otelcol}"
OTEL_GROUP="${OTEL_GROUP:-otelcol}"
OTEL_HOME="${OTEL_HOME:-/opt/otel-collector}"
OTEL_CONFIG_DIR="${OTEL_CONFIG_DIR:-/etc/otel-collector}"
OTEL_LOG_DIR="${OTEL_LOG_DIR:-/var/log}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
ARCH="${ARCH:-$(uname -m)}"

# Map architecture
case "${ARCH}" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_${ARCH}.tar.gz"

echo "============================================"
echo "OpenTelemetry Collector Installer for GCE"
echo "============================================"
echo "Version:  ${OTEL_VERSION}"
echo "Arch:     ${ARCH}"
echo "User:     ${OTEL_USER}"
echo "Config:   ${OTEL_CONFIG_DIR}"
echo "============================================"

# --- Pre-flight checks ---
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo "Installing curl..."
  apt-get update -qq && apt-get install -y -qq curl
fi

if ! command -v systemctl &> /dev/null; then
  echo "ERROR: systemctl is required. This script supports systemd-based systems only."
  exit 1
fi

# --- Verify GCP metadata service (confirms running on GCE) ---
echo "Verifying GCE metadata service..."
if ! curl -sf -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" > /dev/null 2>&1; then
  echo "WARNING: GCE metadata service not reachable. This may not be a GCE instance."
  echo "Continuing anyway..."
fi

# --- Retrieve instance metadata ---
GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(curl -sf -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/project/project-id' 2>/dev/null || echo 'unknown')}"
INSTANCE_NAME="${INSTANCE_NAME:-$(curl -sf -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/name' 2>/dev/null || echo 'unknown')}"
INSTANCE_ZONE="${INSTANCE_ZONE:-$(curl -sf -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/zone' 2>/dev/null | awk -F'/' '{print $NF}' || echo 'unknown')}"

echo "GCP Project:   ${GCP_PROJECT_ID}"
echo "Instance Name: ${INSTANCE_NAME}"
echo "Instance Zone: ${INSTANCE_ZONE}"

# --- Create user and group ---
echo "Creating service user and group..."
if ! getent group "${OTEL_GROUP}" > /dev/null 2>&1; then
  groupadd --system "${OTEL_GROUP}"
fi

if ! getent passwd "${OTEL_USER}" > /dev/null 2>&1; then
  useradd --system \
    --gid "${OTEL_GROUP}" \
    --home-dir "${OTEL_HOME}" \
    --no-create-home \
    --shell /usr/sbin/nologin \
    "${OTEL_USER}"
fi

# --- Create directories ---
echo "Creating directories..."
mkdir -p "${OTEL_HOME}"
mkdir -p "${OTEL_CONFIG_DIR}"
mkdir -p "${OTEL_LOG_DIR}"

# --- Download and install binary ---
echo "Downloading OpenTelemetry Collector v${OTEL_VERSION}..."
TEMP_DIR=$(mktemp -d)
curl -fSL "${DOWNLOAD_URL}" -o "${TEMP_DIR}/otelcol-contrib.tar.gz"

echo "Extracting..."
tar -xzf "${TEMP_DIR}/otelcol-contrib.tar.gz" -C "${TEMP_DIR}"

echo "Installing binary..."
if systemctl is-active --quiet otel-collector 2>/dev/null; then
  echo "Stopping existing collector service..."
  systemctl stop otel-collector
fi

cp "${TEMP_DIR}/otelcol-contrib" "${INSTALL_DIR}/otelcol-contrib"
chmod 755 "${INSTALL_DIR}/otelcol-contrib"
rm -rf "${TEMP_DIR}"

# --- Copy configuration ---
echo "Setting up configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/otel-agent.yaml" ]]; then
  cp "${SCRIPT_DIR}/otel-agent.yaml" "${OTEL_CONFIG_DIR}/otel-agent.yaml"
  echo "Copied otel-agent.yaml to ${OTEL_CONFIG_DIR}/"
else
  echo "WARNING: otel-agent.yaml not found in ${SCRIPT_DIR}. Copy it manually to ${OTEL_CONFIG_DIR}/"
fi

# --- Create environment file ---
echo "Creating environment file..."
cat > "${OTEL_CONFIG_DIR}/otel-collector.env" <<ENVEOF
# OpenTelemetry Collector environment variables for GCE
GCP_PROJECT_ID=${GCP_PROJECT_ID}
INSTANCE_NAME=${INSTANCE_NAME}
ENVIRONMENT=${ENVIRONMENT:-production}
SERVICE_NAME=${SERVICE_NAME:-gce-service}
SERVICE_VERSION=${SERVICE_VERSION:-1.0.0}

# Receiver ports
OTLP_GRPC_PORT=${OTLP_GRPC_PORT:-4317}
OTLP_HTTP_PORT=${OTLP_HTTP_PORT:-4318}

# Host metrics
HOST_METRICS_INTERVAL=${HOST_METRICS_INTERVAL:-30s}

# File log
FILELOG_START_AT=${FILELOG_START_AT:-end}
APP_LOG_PATH=${APP_LOG_PATH:-/var/log/app/*.log}
APP_SYSTEMD_UNIT=${APP_SYSTEMD_UNIT:-myapp}

# Batch processor
BATCH_SIZE=${BATCH_SIZE:-8192}
BATCH_MAX_SIZE=${BATCH_MAX_SIZE:-16384}
BATCH_TIMEOUT=${BATCH_TIMEOUT:-5s}

# Memory limiter
MEMORY_LIMITER_CHECK_INTERVAL=${MEMORY_LIMITER_CHECK_INTERVAL:-5s}
MEMORY_LIMITER_LIMIT_MIB=${MEMORY_LIMITER_LIMIT_MIB:-512}
MEMORY_LIMITER_SPIKE_MIB=${MEMORY_LIMITER_SPIKE_MIB:-128}

# Gateway
GATEWAY_ENDPOINT=${GATEWAY_ENDPOINT:-localhost:4317}
GATEWAY_TLS_INSECURE=${GATEWAY_TLS_INSECURE:-true}

# Google Cloud
GCP_LOG_NAME=${GCP_LOG_NAME:-otel-collector}
GCP_METRIC_PREFIX=${GCP_METRIC_PREFIX:-custom.googleapis.com/otel}

# Health and telemetry
HEALTH_CHECK_PORT=${HEALTH_CHECK_PORT:-13133}
OTEL_LOG_LEVEL=${OTEL_LOG_LEVEL:-info}
TELEMETRY_METRICS_PORT=${TELEMETRY_METRICS_PORT:-8888}
ENVEOF

# --- Set permissions ---
echo "Setting permissions..."
chown -R "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_HOME}"
chown -R "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_CONFIG_DIR}"
touch "${OTEL_LOG_DIR}/otel-collector.log"
chown "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_LOG_DIR}/otel-collector.log"

# Allow reading system logs
usermod -aG adm "${OTEL_USER}" 2>/dev/null || true
usermod -aG systemd-journal "${OTEL_USER}" 2>/dev/null || true

# --- Install systemd service ---
echo "Installing systemd service..."
if [[ -f "${SCRIPT_DIR}/systemd/otel-collector.service" ]]; then
  cp "${SCRIPT_DIR}/systemd/otel-collector.service" /etc/systemd/system/otel-collector.service
else
  cat > /etc/systemd/system/otel-collector.service <<SVCEOF
[Unit]
Description=OpenTelemetry Collector
Documentation=https://opentelemetry.io/docs/collector/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${OTEL_USER}
Group=${OTEL_GROUP}
EnvironmentFile=${OTEL_CONFIG_DIR}/otel-collector.env
ExecStart=${INSTALL_DIR}/otelcol-contrib --config=${OTEL_CONFIG_DIR}/otel-agent.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=65536
LimitNPROC=512
MemoryMax=${MEMORY_LIMITER_LIMIT_MIB:-512}M

[Install]
WantedBy=multi-user.target
SVCEOF
fi

# --- Enable and start service ---
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable otel-collector
systemctl start otel-collector

# --- Verify ---
sleep 3
if systemctl is-active --quiet otel-collector; then
  echo ""
  echo "============================================"
  echo "OpenTelemetry Collector installed and running"
  echo "============================================"
  echo "Status: $(systemctl is-active otel-collector)"
  echo "Config: ${OTEL_CONFIG_DIR}/otel-agent.yaml"
  echo "Env:    ${OTEL_CONFIG_DIR}/otel-collector.env"
  echo "Logs:   journalctl -u otel-collector -f"
  echo "============================================"
else
  echo ""
  echo "ERROR: Service failed to start. Check logs with:"
  echo "  journalctl -u otel-collector --no-pager -l"
  exit 1
fi
