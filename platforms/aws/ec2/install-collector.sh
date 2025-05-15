#!/usr/bin/env bash
# install-collector.sh
# Downloads and installs the OpenTelemetry Collector Contrib on an EC2 instance.
# Creates a dedicated user, installs to /opt/otel-collector/, and configures systemd.
#
# Usage:
#   sudo bash install-collector.sh
#
# Environment variables (optional):
#   OTEL_COLLECTOR_VERSION - Collector version to install (default: 0.98.0)
#   OTEL_CONFIG_URL        - URL to download the collector config from
#   OTEL_GATEWAY_ENDPOINT  - Gateway endpoint for the collector

set -euo pipefail
IFS=$'\n\t'

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
COLLECTOR_VERSION="${OTEL_COLLECTOR_VERSION:-0.98.0}"
INSTALL_DIR="/opt/otel-collector"
CONFIG_DIR="/etc/otel-collector"
LOG_DIR="/var/log/otel-collector"
BINARY_NAME="otelcol-contrib"
SERVICE_USER="otel"
SERVICE_GROUP="otel"
SYSTEMD_UNIT="/etc/systemd/system/otel-collector.service"

# Detect architecture
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    echo "ERROR: Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "${OS}" != "linux" ]]; then
  echo "ERROR: This script only supports Linux. Detected: ${OS}" >&2
  exit 1
fi

DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${COLLECTOR_VERSION}/otelcol-contrib_${COLLECTOR_VERSION}_linux_${ARCH}.tar.gz"

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------
log_info()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }

check_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)."
    exit 1
  fi
}

cleanup() {
  local exit_code=$?
  if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Installation failed with exit code ${exit_code}."
    log_error "Check the output above for details."
  fi
  exit ${exit_code}
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
trap cleanup EXIT

check_root

log_info "Installing OpenTelemetry Collector Contrib v${COLLECTOR_VERSION} (${ARCH})"

# Check for required tools
for cmd in curl tar id systemctl; do
  if ! command -v "${cmd}" &>/dev/null; then
    log_error "Required command not found: ${cmd}"
    exit 1
  fi
done

# Create service user
if ! id "${SERVICE_USER}" &>/dev/null; then
  log_info "Creating service user: ${SERVICE_USER}"
  useradd --system --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
else
  log_info "Service user '${SERVICE_USER}' already exists."
fi

# Create directories
log_info "Creating directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${LOG_DIR}"

# Download collector
TEMP_DIR=$(mktemp -d)
log_info "Downloading collector from: ${DOWNLOAD_URL}"

if ! curl -fsSL --retry 3 --retry-delay 5 -o "${TEMP_DIR}/otelcol-contrib.tar.gz" "${DOWNLOAD_URL}"; then
  log_error "Failed to download collector. Check the version and your network connection."
  exit 1
fi

# Verify download
if [[ ! -s "${TEMP_DIR}/otelcol-contrib.tar.gz" ]]; then
  log_error "Downloaded file is empty."
  exit 1
fi

# Extract
log_info "Extracting collector..."
tar -xzf "${TEMP_DIR}/otelcol-contrib.tar.gz" -C "${TEMP_DIR}"

if [[ ! -f "${TEMP_DIR}/${BINARY_NAME}" ]]; then
  log_error "Binary '${BINARY_NAME}' not found in archive."
  exit 1
fi

# Install binary
log_info "Installing binary to ${INSTALL_DIR}/${BINARY_NAME}"
if [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
  log_warn "Existing binary found, creating backup."
  mv "${INSTALL_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}.bak.$(date +%s)"
fi
cp "${TEMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"

# Install config file (only if not already present)
if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
  if [[ -n "${OTEL_CONFIG_URL:-}" ]]; then
    log_info "Downloading config from: ${OTEL_CONFIG_URL}"
    curl -fsSL --retry 3 -o "${CONFIG_DIR}/config.yaml" "${OTEL_CONFIG_URL}"
  elif [[ -f "$(dirname "$0")/otel-agent.yaml" ]]; then
    log_info "Copying local config file."
    cp "$(dirname "$0")/otel-agent.yaml" "${CONFIG_DIR}/config.yaml"
  else
    log_warn "No config file found. You must place a config at ${CONFIG_DIR}/config.yaml"
  fi
else
  log_info "Config file already exists at ${CONFIG_DIR}/config.yaml (not overwriting)."
fi

# Create environment file
if [[ ! -f "${CONFIG_DIR}/otel-collector.env" ]]; then
  log_info "Creating environment file at ${CONFIG_DIR}/otel-collector.env"
  cat > "${CONFIG_DIR}/otel-collector.env" <<'ENVEOF'
# OpenTelemetry Collector environment variables
# Uncomment and set values as needed.

# OTEL_GATEWAY_ENDPOINT=gateway.example.com:4317
# OTEL_SERVICE_NAME=ec2-host-agent
# OTEL_LOG_LEVEL=info
# AWS_REGION=us-east-1
# ENVIRONMENT=production
# OTEL_EXPORTER_TLS_INSECURE=false
ENVEOF
else
  log_info "Environment file already exists (not overwriting)."
fi

# Set ownership
log_info "Setting ownership..."
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${CONFIG_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${LOG_DIR}"

# Grant read access to log files the collector needs to read
# Add otel user to adm group for /var/log access
if getent group adm &>/dev/null; then
  usermod -aG adm "${SERVICE_USER}" 2>/dev/null || true
fi
if getent group systemd-journal &>/dev/null; then
  usermod -aG systemd-journal "${SERVICE_USER}" 2>/dev/null || true
fi

# Install systemd service
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${SCRIPT_DIR}/systemd/otel-collector.service" ]]; then
  log_info "Installing systemd service from local file."
  cp "${SCRIPT_DIR}/systemd/otel-collector.service" "${SYSTEMD_UNIT}"
else
  log_info "Creating systemd service file."
  cat > "${SYSTEMD_UNIT}" <<SVCEOF
[Unit]
Description=OpenTelemetry Collector Contrib
Documentation=https://opentelemetry.io/docs/collector/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
EnvironmentFile=-${CONFIG_DIR}/otel-collector.env
ExecStart=${INSTALL_DIR}/${BINARY_NAME} --config=${CONFIG_DIR}/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=512
MemoryMax=1G
CPUQuota=100%
StandardOutput=append:${LOG_DIR}/otel-collector.log
StandardError=append:${LOG_DIR}/otel-collector-error.log

[Install]
WantedBy=multi-user.target
SVCEOF
fi

# Reload systemd, enable and start
log_info "Reloading systemd daemon..."
systemctl daemon-reload

log_info "Enabling otel-collector service..."
systemctl enable otel-collector

log_info "Starting otel-collector service..."
systemctl start otel-collector

# Verify
sleep 2
if systemctl is-active --quiet otel-collector; then
  log_info "OpenTelemetry Collector is running."
  log_info "  Binary:  ${INSTALL_DIR}/${BINARY_NAME}"
  log_info "  Config:  ${CONFIG_DIR}/config.yaml"
  log_info "  Env:     ${CONFIG_DIR}/otel-collector.env"
  log_info "  Logs:    ${LOG_DIR}/"
  log_info "  Service: systemctl status otel-collector"
  log_info ""
  log_info "Installation complete."
else
  log_error "Service failed to start. Check logs with: journalctl -u otel-collector -n 50"
  exit 1
fi
