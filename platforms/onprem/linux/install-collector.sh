#!/usr/bin/env bash
# =============================================================================
# OpenTelemetry Collector Contrib - Linux Install Script
# =============================================================================
# Installs the OpenTelemetry Collector Contrib distribution on Linux.
# Supports Ubuntu/Debian (deb) and RHEL/CentOS (rpm) based distributions.
#
# Usage:
#   sudo ./install-collector.sh [OPTIONS]
#
# Options:
#   --version VERSION     Collector version to install (default: 0.96.0)
#   --mode MODE           Install mode: agent or gateway (default: agent)
#   --config PATH         Path to config file to copy (optional)
#   --gateway-endpoint EP Gateway endpoint for agent mode
#   --backend-endpoint EP Backend endpoint for gateway mode
#   --environment ENV     Deployment environment name
#   --team TEAM           Team name
#   --uninstall           Uninstall the collector
#   --help                Show this help message
#
# Examples:
#   sudo ./install-collector.sh --mode agent --gateway-endpoint gateway:4317
#   sudo ./install-collector.sh --mode gateway --backend-endpoint tempo:4317
#   sudo ./install-collector.sh --uninstall
# =============================================================================

set -euo pipefail

# ---- Configuration defaults ----
COLLECTOR_VERSION="${COLLECTOR_VERSION:-0.96.0}"
INSTALL_DIR="/opt/otel-collector"
CONFIG_DIR="/etc/otel-collector"
LOG_DIR="/var/log/otel-collector"
STORAGE_DIR="/var/lib/otel-collector"
OTEL_USER="otel"
OTEL_GROUP="otel"
MODE="agent"
CONFIG_SOURCE=""
GATEWAY_ENDPOINT=""
BACKEND_ENDPOINT=""
ENVIRONMENT="production"
TEAM="platform"
UNINSTALL=false
BASE_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download"

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- Logging helpers ----
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }

# ---- Parse arguments ----
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                COLLECTOR_VERSION="$2"
                shift 2
                ;;
            --mode)
                MODE="$2"
                if [[ "$MODE" != "agent" && "$MODE" != "gateway" ]]; then
                    log_error "Invalid mode: $MODE. Must be 'agent' or 'gateway'."
                    exit 1
                fi
                shift 2
                ;;
            --config)
                CONFIG_SOURCE="$2"
                shift 2
                ;;
            --gateway-endpoint)
                GATEWAY_ENDPOINT="$2"
                shift 2
                ;;
            --backend-endpoint)
                BACKEND_ENDPOINT="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --team)
                TEAM="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --help)
                head -30 "$0" | tail -25
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# ---- Check root ----
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)."
        exit 1
    fi
}

# ---- Detect OS and package manager ----
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID:-unknown}"
        OS_NAME="${PRETTY_NAME:-$ID}"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian)
            PKG_TYPE="deb"
            PKG_MANAGER="dpkg"
            ;;
        rhel|centos|rocky|alma|fedora|ol)
            PKG_TYPE="rpm"
            PKG_MANAGER="rpm"
            ;;
        *)
            log_warn "Unsupported OS: $OS_ID. Attempting binary installation."
            PKG_TYPE="tar"
            PKG_MANAGER="tar"
            ;;
    esac

    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_SUFFIX="amd64" ;;
        aarch64) ARCH_SUFFIX="arm64" ;;
        armv7l)  ARCH_SUFFIX="armhf" ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    log_info "Detected OS: $OS_NAME ($OS_ID $OS_VERSION)"
    log_info "Architecture: $ARCH ($ARCH_SUFFIX)"
    log_info "Package type: $PKG_TYPE"
}

# ---- Detect download tool ----
detect_downloader() {
    if command -v curl &>/dev/null; then
        DOWNLOADER="curl"
    elif command -v wget &>/dev/null; then
        DOWNLOADER="wget"
    else
        log_error "Neither curl nor wget found. Please install one."
        exit 1
    fi
}

# ---- Download file ----
download_file() {
    local url="$1"
    local dest="$2"

    log_info "Downloading: $url"
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL -o "$dest" "$url"
    else
        wget -q -O "$dest" "$url"
    fi
}

# ---- Verify checksum ----
verify_checksum() {
    local file="$1"
    local checksums_file="$2"
    local filename
    filename=$(basename "$file")

    log_step "Verifying checksum for $filename..."

    if ! command -v sha256sum &>/dev/null; then
        if command -v shasum &>/dev/null; then
            SHA_CMD="shasum -a 256"
        else
            log_warn "sha256sum/shasum not found. Skipping checksum verification."
            return 0
        fi
    else
        SHA_CMD="sha256sum"
    fi

    # Extract expected checksum
    local expected
    expected=$(grep "$filename" "$checksums_file" | awk '{print $1}')

    if [[ -z "$expected" ]]; then
        log_warn "Checksum not found for $filename in checksums file. Skipping."
        return 0
    fi

    # Compute actual checksum
    local actual
    actual=$($SHA_CMD "$file" | awk '{print $1}')

    if [[ "$expected" == "$actual" ]]; then
        log_info "Checksum verified: $actual"
        return 0
    else
        log_error "Checksum mismatch!"
        log_error "  Expected: $expected"
        log_error "  Actual:   $actual"
        return 1
    fi
}

# ---- Create otel user and group ----
create_user() {
    log_step "Creating user and group: $OTEL_USER"

    if ! getent group "$OTEL_GROUP" &>/dev/null; then
        groupadd --system "$OTEL_GROUP"
        log_info "Created group: $OTEL_GROUP"
    else
        log_info "Group already exists: $OTEL_GROUP"
    fi

    if ! id "$OTEL_USER" &>/dev/null; then
        useradd --system \
            --gid "$OTEL_GROUP" \
            --no-create-home \
            --shell /usr/sbin/nologin \
            --comment "OpenTelemetry Collector" \
            "$OTEL_USER"
        log_info "Created user: $OTEL_USER"
    else
        log_info "User already exists: $OTEL_USER"
    fi
}

# ---- Create directories ----
create_directories() {
    log_step "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$STORAGE_DIR/storage"

    chown -R "$OTEL_USER:$OTEL_GROUP" "$LOG_DIR"
    chown -R "$OTEL_USER:$OTEL_GROUP" "$STORAGE_DIR"

    log_info "Directories created."
}

# ---- Download and install collector ----
install_collector() {
    log_step "Downloading OpenTelemetry Collector Contrib v${COLLECTOR_VERSION}..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local checksums_url="${BASE_URL}/v${COLLECTOR_VERSION}/otelcol-contrib_${COLLECTOR_VERSION}_checksums.txt"
    local checksums_file="${tmp_dir}/checksums.txt"

    # Download checksums file
    download_file "$checksums_url" "$checksums_file" || {
        log_warn "Could not download checksums file. Continuing without verification."
        checksums_file=""
    }

    case "$PKG_TYPE" in
        deb)
            local pkg_name="otelcol-contrib_${COLLECTOR_VERSION}_linux_${ARCH_SUFFIX}.deb"
            local pkg_url="${BASE_URL}/v${COLLECTOR_VERSION}/${pkg_name}"
            local pkg_file="${tmp_dir}/${pkg_name}"

            download_file "$pkg_url" "$pkg_file"

            if [[ -n "$checksums_file" ]]; then
                verify_checksum "$pkg_file" "$checksums_file"
            fi

            log_step "Installing deb package..."
            dpkg -i "$pkg_file" || {
                log_warn "dpkg reported issues, attempting to fix dependencies..."
                apt-get install -f -y
            }
            # Copy binary to our install dir
            cp /usr/bin/otelcol-contrib "$INSTALL_DIR/otelcol-contrib" 2>/dev/null || true
            ;;
        rpm)
            local pkg_name="otelcol-contrib_${COLLECTOR_VERSION}_linux_${ARCH_SUFFIX}.rpm"
            local pkg_url="${BASE_URL}/v${COLLECTOR_VERSION}/${pkg_name}"
            local pkg_file="${tmp_dir}/${pkg_name}"

            download_file "$pkg_url" "$pkg_file"

            if [[ -n "$checksums_file" ]]; then
                verify_checksum "$pkg_file" "$checksums_file"
            fi

            log_step "Installing rpm package..."
            rpm -Uvh --force "$pkg_file"
            # Copy binary to our install dir
            cp /usr/bin/otelcol-contrib "$INSTALL_DIR/otelcol-contrib" 2>/dev/null || true
            ;;
        tar)
            local pkg_name="otelcol-contrib_${COLLECTOR_VERSION}_linux_${ARCH_SUFFIX}.tar.gz"
            local pkg_url="${BASE_URL}/v${COLLECTOR_VERSION}/${pkg_name}"
            local pkg_file="${tmp_dir}/${pkg_name}"

            download_file "$pkg_url" "$pkg_file"

            if [[ -n "$checksums_file" ]]; then
                verify_checksum "$pkg_file" "$checksums_file"
            fi

            log_step "Extracting binary..."
            tar -xzf "$pkg_file" -C "$tmp_dir"
            cp "${tmp_dir}/otelcol-contrib" "$INSTALL_DIR/otelcol-contrib"
            ;;
    esac

    chmod 755 "$INSTALL_DIR/otelcol-contrib"
    chown "$OTEL_USER:$OTEL_GROUP" "$INSTALL_DIR/otelcol-contrib"

    log_info "Collector installed to $INSTALL_DIR/otelcol-contrib"
    "$INSTALL_DIR/otelcol-contrib" --version
}

# ---- Install config ----
install_config() {
    log_step "Installing configuration for mode: $MODE"

    local config_dest="${CONFIG_DIR}/config.yaml"

    if [[ -n "$CONFIG_SOURCE" ]]; then
        if [[ -f "$CONFIG_SOURCE" ]]; then
            cp "$CONFIG_SOURCE" "$config_dest"
            log_info "Copied config from: $CONFIG_SOURCE"
        else
            log_error "Config source not found: $CONFIG_SOURCE"
            exit 1
        fi
    else
        # Look for bundled config in same directory as script
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local bundled_config="${script_dir}/otel-${MODE}.yaml"

        if [[ -f "$bundled_config" ]]; then
            cp "$bundled_config" "$config_dest"
            log_info "Copied bundled ${MODE} config."
        else
            log_warn "No config file provided or found. You must place a config at: $config_dest"
        fi
    fi

    # Install environment file
    local env_file="${CONFIG_DIR}/env"
    if [[ ! -f "$env_file" ]]; then
        log_step "Creating environment file: $env_file"
        cat > "$env_file" <<ENVEOF
# OpenTelemetry Collector Environment Variables
# Mode: ${MODE}

ENVIRONMENT=${ENVIRONMENT}
TEAM=${TEAM}
NODE_NAME=$(hostname -f)
ENVEOF

        if [[ "$MODE" == "agent" ]]; then
            cat >> "$env_file" <<ENVEOF

# Gateway endpoint (required for agent mode)
GATEWAY_ENDPOINT=${GATEWAY_ENDPOINT:-gateway.internal:4317}

# Agent resource limits
MEMORY_LIMIT_MIB=400
MEMORY_SPIKE_MIB=100

# Receiver ports
OTLP_GRPC_PORT=4317
OTLP_HTTP_PORT=4318
SYSLOG_TCP_PORT=514

# TLS
OTLP_INSECURE=true
ENVEOF
        else
            cat >> "$env_file" <<ENVEOF

# Backend endpoint (required for gateway mode)
BACKEND_OTLP_ENDPOINT=${BACKEND_ENDPOINT:-backend.internal:4317}

# Gateway resource limits
MEMORY_LIMIT_MIB=2048
MEMORY_SPIKE_MIB=512

# Sampling rate (percentage, 0-100)
SAMPLING_RATE=10

# Batch settings
BATCH_TIMEOUT=10s
BATCH_SIZE=16384

# Receiver ports
GATEWAY_OTLP_GRPC_PORT=4317
GATEWAY_OTLP_HTTP_PORT=4318

# TLS
OTLP_INSECURE=true
ENVEOF
        fi

        log_info "Environment file created at: $env_file"
    else
        log_warn "Environment file already exists: $env_file (not overwriting)"
    fi

    chown -R "$OTEL_USER:$OTEL_GROUP" "$CONFIG_DIR"
    chmod 640 "$config_dest" 2>/dev/null || true
    chmod 640 "$env_file"
}

# ---- Setup systemd service ----
setup_systemd() {
    log_step "Setting up systemd service..."

    local service_name="otel-collector-${MODE}"
    local service_file="/etc/systemd/system/${service_name}.service"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check for bundled systemd unit file
    local bundled_service="${script_dir}/systemd/${service_name}.service"
    if [[ -f "$bundled_service" ]]; then
        cp "$bundled_service" "$service_file"
        log_info "Copied bundled systemd unit: $bundled_service"
    else
        # Generate service file
        local memory_max="512M"
        [[ "$MODE" == "gateway" ]] && memory_max="4G"

        cat > "$service_file" <<SVCEOF
[Unit]
Description=OpenTelemetry Collector (${MODE})
Documentation=https://opentelemetry.io/docs/collector/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${OTEL_USER}
Group=${OTEL_GROUP}
EnvironmentFile=${CONFIG_DIR}/env
ExecStart=${INSTALL_DIR}/otelcol-contrib --config=${CONFIG_DIR}/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=65536
MemoryMax=${memory_max}
StandardOutput=journal
StandardError=journal
SyslogIdentifier=otel-collector

[Install]
WantedBy=multi-user.target
SVCEOF
        log_info "Generated systemd unit file."
    fi

    systemctl daemon-reload
    systemctl enable "${service_name}.service"
    systemctl start "${service_name}.service"

    log_info "Service ${service_name} enabled and started."
    systemctl status "${service_name}.service" --no-pager || true
}

# ---- Uninstall ----
uninstall() {
    log_step "Uninstalling OpenTelemetry Collector..."

    # Stop and disable services
    for mode in agent gateway; do
        local service_name="otel-collector-${mode}"
        if systemctl is-active --quiet "${service_name}.service" 2>/dev/null; then
            log_info "Stopping ${service_name}..."
            systemctl stop "${service_name}.service"
        fi
        if systemctl is-enabled --quiet "${service_name}.service" 2>/dev/null; then
            systemctl disable "${service_name}.service"
        fi
        rm -f "/etc/systemd/system/${service_name}.service"
    done

    systemctl daemon-reload

    # Remove files
    log_info "Removing installation directory: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"

    log_info "Removing log directory: $LOG_DIR"
    rm -rf "$LOG_DIR"

    log_info "Removing storage directory: $STORAGE_DIR"
    rm -rf "$STORAGE_DIR"

    # Ask before removing config
    if [[ -d "$CONFIG_DIR" ]]; then
        read -rp "Remove configuration directory ${CONFIG_DIR}? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            log_info "Configuration removed."
        else
            log_info "Configuration preserved at: $CONFIG_DIR"
        fi
    fi

    # Remove user (optional)
    if id "$OTEL_USER" &>/dev/null; then
        read -rp "Remove user ${OTEL_USER}? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            userdel "$OTEL_USER"
            log_info "User removed: $OTEL_USER"
        fi
    fi

    # Remove package if installed via package manager
    if command -v dpkg &>/dev/null && dpkg -l otelcol-contrib &>/dev/null 2>&1; then
        apt-get remove -y otelcol-contrib 2>/dev/null || true
    elif command -v rpm &>/dev/null && rpm -q otelcol-contrib &>/dev/null 2>&1; then
        rpm -e otelcol-contrib 2>/dev/null || true
    fi

    log_info "Uninstallation complete."
}

# ---- Main ----
main() {
    parse_args "$@"
    check_root

    echo ""
    echo "======================================================"
    echo "  OpenTelemetry Collector Installer"
    echo "======================================================"
    echo ""

    if [[ "$UNINSTALL" == true ]]; then
        detect_os
        uninstall
        exit 0
    fi

    log_info "Mode: $MODE"
    log_info "Version: $COLLECTOR_VERSION"
    echo ""

    detect_os
    detect_downloader
    create_user
    create_directories
    install_collector
    install_config
    setup_systemd

    echo ""
    echo "======================================================"
    log_info "Installation complete!"
    echo "======================================================"
    echo ""
    echo "  Binary:  $INSTALL_DIR/otelcol-contrib"
    echo "  Config:  $CONFIG_DIR/config.yaml"
    echo "  Env:     $CONFIG_DIR/env"
    echo "  Logs:    $LOG_DIR/"
    echo "  Service: otel-collector-${MODE}"
    echo ""
    echo "  Useful commands:"
    echo "    systemctl status otel-collector-${MODE}"
    echo "    systemctl restart otel-collector-${MODE}"
    echo "    journalctl -u otel-collector-${MODE} -f"
    echo ""
}

main "$@"
