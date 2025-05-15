#!/usr/bin/env bash
# install-collector-linux.sh
# Installs the OpenTelemetry Collector on Azure Linux VMs.
# Downloads the collector binary, configures systemd, and sets up Managed Identity.
#
# Usage:
#   sudo bash install-collector-linux.sh \
#     --otlp-endpoint "https://gateway.example.com:4317" \
#     --environment "production" \
#     --version "0.96.0"

set -euo pipefail

# -------------------------------------------------------------------
# Default configuration
# -------------------------------------------------------------------
OTEL_VERSION="${OTEL_VERSION:-0.96.0}"
OTEL_ARCH="${OTEL_ARCH:-amd64}"
OTEL_USER="otelcol"
OTEL_GROUP="otelcol"
OTEL_HOME="/opt/otelcol"
OTEL_CONFIG_DIR="/etc/otelcol"
OTEL_LOG_DIR="/var/log/otelcol"
OTEL_STORAGE_DIR="/var/lib/otelcol/storage"
OTLP_ENDPOINT="${OTLP_ENDPOINT:-}"
ENVIRONMENT="${ENVIRONMENT:-production}"
SERVICE_NAME="${SERVICE_NAME:-linux-vm-agent}"

# -------------------------------------------------------------------
# Parse command-line arguments
# -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --otlp-endpoint)
      OTLP_ENDPOINT="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --version)
      OTEL_VERSION="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --arch)
      OTEL_ARCH="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --otlp-endpoint  OTLP exporter endpoint (required)"
      echo "  --environment    Deployment environment (default: production)"
      echo "  --version        Collector version (default: 0.96.0)"
      echo "  --service-name   Service name attribute (default: linux-vm-agent)"
      echo "  --arch           Architecture: amd64, arm64 (default: amd64)"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      exit 1
      ;;
  esac
done

# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------
if [[ -z "${OTLP_ENDPOINT}" ]]; then
  echo "ERROR: --otlp-endpoint is required."
  echo "Usage: $0 --otlp-endpoint <endpoint>"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (sudo)."
  exit 1
fi

echo "============================================"
echo " OpenTelemetry Collector Installer"
echo " Azure Linux VM"
echo "============================================"
echo " Version:     ${OTEL_VERSION}"
echo " Arch:        ${OTEL_ARCH}"
echo " Endpoint:    ${OTLP_ENDPOINT}"
echo " Environment: ${ENVIRONMENT}"
echo "============================================"

# -------------------------------------------------------------------
# Step 1: Create user and directories
# -------------------------------------------------------------------
echo "[1/7] Creating user and directories..."

if ! id "${OTEL_USER}" &>/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "${OTEL_USER}"
fi

mkdir -p "${OTEL_HOME}" "${OTEL_CONFIG_DIR}" "${OTEL_LOG_DIR}" "${OTEL_STORAGE_DIR}"
chown -R "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_HOME}" "${OTEL_LOG_DIR}" "${OTEL_STORAGE_DIR}"

# -------------------------------------------------------------------
# Step 2: Download and install the collector
# -------------------------------------------------------------------
echo "[2/7] Downloading OpenTelemetry Collector Contrib v${OTEL_VERSION}..."

DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_${OTEL_ARCH}.tar.gz"
TEMP_DIR=$(mktemp -d)

curl -fSL "${DOWNLOAD_URL}" -o "${TEMP_DIR}/otelcol-contrib.tar.gz"
tar -xzf "${TEMP_DIR}/otelcol-contrib.tar.gz" -C "${TEMP_DIR}"
mv "${TEMP_DIR}/otelcol-contrib" "${OTEL_HOME}/otelcol-contrib"
chmod +x "${OTEL_HOME}/otelcol-contrib"
rm -rf "${TEMP_DIR}"

echo "  Installed to: ${OTEL_HOME}/otelcol-contrib"

# -------------------------------------------------------------------
# Step 3: Retrieve Azure Managed Identity token (validation)
# -------------------------------------------------------------------
echo "[3/7] Validating Azure Managed Identity..."

IMDS_TOKEN=$(curl -s -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" \
  --connect-timeout 5 || true)

if echo "${IMDS_TOKEN}" | grep -q "access_token"; then
  echo "  Managed Identity: Available"
else
  echo "  WARNING: Managed Identity token not available."
  echo "  Ensure the VM has a system-assigned or user-assigned managed identity."
fi

# Retrieve VM metadata for resource attributes
VM_METADATA=$(curl -s -H "Metadata:true" \
  "http://169.254.169.254/metadata/instance?api-version=2021-02-01" \
  --connect-timeout 5 || echo '{}')

VM_NAME=$(echo "${VM_METADATA}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compute',{}).get('name','unknown'))" 2>/dev/null || echo "unknown")
VM_REGION=$(echo "${VM_METADATA}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compute',{}).get('location','unknown'))" 2>/dev/null || echo "unknown")
VM_RG=$(echo "${VM_METADATA}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compute',{}).get('resourceGroupName','unknown'))" 2>/dev/null || echo "unknown")
VM_SUB=$(echo "${VM_METADATA}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compute',{}).get('subscriptionId','unknown'))" 2>/dev/null || echo "unknown")

echo "  VM Name:     ${VM_NAME}"
echo "  Region:      ${VM_REGION}"
echo "  RG:          ${VM_RG}"
echo "  Subscription:${VM_SUB}"

# -------------------------------------------------------------------
# Step 4: Copy config file
# -------------------------------------------------------------------
echo "[4/7] Deploying collector configuration..."

CONFIG_SOURCE="$(dirname "$0")/otel-agent-linux.yaml"

if [[ -f "${CONFIG_SOURCE}" ]]; then
  cp "${CONFIG_SOURCE}" "${OTEL_CONFIG_DIR}/config.yaml"
else
  echo "  WARNING: ${CONFIG_SOURCE} not found. Using default configuration path."
  echo "  Please copy otel-agent-linux.yaml to ${OTEL_CONFIG_DIR}/config.yaml"
fi

chown "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_CONFIG_DIR}/config.yaml" 2>/dev/null || true

# -------------------------------------------------------------------
# Step 5: Create environment file
# -------------------------------------------------------------------
echo "[5/7] Creating environment file..."

cat > "${OTEL_CONFIG_DIR}/otelcol.env" <<ENVEOF
# OpenTelemetry Collector Environment Variables
# Auto-generated by install-collector-linux.sh

# Exporter configuration
OTLP_ENDPOINT=${OTLP_ENDPOINT}
OTLP_TLS_INSECURE=false

# Resource attributes
ENVIRONMENT=${ENVIRONMENT}
SERVICE_NAME=${SERVICE_NAME}
SERVICE_NAMESPACE=azure-vm

# Collector tuning
HOST_METRICS_INTERVAL=15s
BATCH_SIZE=512
BATCH_TIMEOUT=5s
MEMORY_LIMIT_MIB=512
MEMORY_SPIKE_LIMIT_MIB=128

# Logging
OTEL_LOG_LEVEL=info

# Application log paths (customize as needed)
APP_LOG_PATH=/var/log/app/*.log
ENVEOF

chown "${OTEL_USER}:${OTEL_GROUP}" "${OTEL_CONFIG_DIR}/otelcol.env"
chmod 600 "${OTEL_CONFIG_DIR}/otelcol.env"

# -------------------------------------------------------------------
# Step 6: Create systemd service
# -------------------------------------------------------------------
echo "[6/7] Creating systemd service..."

cat > /etc/systemd/system/otelcol-contrib.service <<SERVICEEOF
[Unit]
Description=OpenTelemetry Collector Contrib
Documentation=https://opentelemetry.io/docs/collector/
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=simple
User=${OTEL_USER}
Group=${OTEL_GROUP}
EnvironmentFile=${OTEL_CONFIG_DIR}/otelcol.env
ExecStart=${OTEL_HOME}/otelcol-contrib --config=${OTEL_CONFIG_DIR}/config.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
TimeoutStopSec=30

# Security hardening
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ReadOnlyDirectories=/
ReadWriteDirectories=${OTEL_LOG_DIR} ${OTEL_STORAGE_DIR}

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=768M
CPUQuota=50%

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=otelcol-contrib

[Install]
WantedBy=multi-user.target
SERVICEEOF

# -------------------------------------------------------------------
# Step 7: Enable and start the service
# -------------------------------------------------------------------
echo "[7/7] Enabling and starting the collector service..."

# Grant read access to log files
usermod -aG adm "${OTEL_USER}" 2>/dev/null || true
usermod -aG systemd-journal "${OTEL_USER}" 2>/dev/null || true

systemctl daemon-reload
systemctl enable otelcol-contrib.service
systemctl start otelcol-contrib.service

# Verify service is running
sleep 3
if systemctl is-active --quiet otelcol-contrib.service; then
  echo ""
  echo "============================================"
  echo " Installation Complete!"
  echo "============================================"
  echo " Service Status: RUNNING"
  echo " Config:         ${OTEL_CONFIG_DIR}/config.yaml"
  echo " Env File:       ${OTEL_CONFIG_DIR}/otelcol.env"
  echo " Logs:           journalctl -u otelcol-contrib -f"
  echo " Health Check:   curl http://localhost:13133"
  echo "============================================"
else
  echo ""
  echo "============================================"
  echo " WARNING: Service failed to start!"
  echo "============================================"
  echo " Check logs:     journalctl -u otelcol-contrib -n 50"
  echo " Config:         ${OTEL_CONFIG_DIR}/config.yaml"
  echo "============================================"
  exit 1
fi
