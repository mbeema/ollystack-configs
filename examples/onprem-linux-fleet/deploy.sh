#!/usr/bin/env bash
# =============================================================================
# OllyStack - On-Premises Linux Fleet Deployment Script
# =============================================================================
# Wrapper script that runs the Ansible playbook with proper variables
# for deploying OTel Collector agents and gateways to Linux servers.
#
# Usage:
#   ./deploy.sh                         # Deploy everything
#   ./deploy.sh --tags agents           # Deploy agents only
#   ./deploy.sh --tags gateway          # Deploy gateway only
#   ./deploy.sh --check                 # Dry run
#   ./deploy.sh --limit "web_servers"   # Limit to a group
#   ./deploy.sh -e "otel_version=0.96.0"  # Override variables
#
# Environment Variables:
#   ANSIBLE_INVENTORY   Override inventory file path
#   ANSIBLE_PLAYBOOK    Override playbook file path
#   ANSIBLE_VAULT_PASS  Path to Ansible vault password file
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Defaults (can be overridden by environment variables)
INVENTORY="${ANSIBLE_INVENTORY:-${SCRIPT_DIR}/inventory.ini}"
PLAYBOOK="${ANSIBLE_PLAYBOOK:-${PROJECT_ROOT}/platforms/linux/ansible/playbook.yaml}"
VAULT_PASS="${ANSIBLE_VAULT_PASS:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ANSIBLE_ARGS...]

Deploy OTel Collector to on-premises Linux servers using Ansible.

Options:
  --tags TAGS         Only run plays/tasks tagged with these values
                      Examples: agents, gateway, config, restart
  --limit HOSTS       Limit execution to specific hosts or groups
  --check             Dry run (no changes made)
  --diff              Show file changes
  --verbose, -v       Increase Ansible verbosity (repeat for more: -vvv)
  -e, --extra-vars    Set additional variables (key=value)
  --list-hosts        List matched hosts and exit
  --list-tags         List available tags and exit
  --help              Show this help message

Environment Variables:
  ANSIBLE_INVENTORY   Path to inventory file (default: ./inventory.ini)
  ANSIBLE_PLAYBOOK    Path to playbook (default: platforms/linux/ansible/playbook.yaml)
  ANSIBLE_VAULT_PASS  Path to vault password file

Examples:
  $(basename "$0")                              # Full deployment
  $(basename "$0") --tags agents                # Deploy agents only
  $(basename "$0") --tags gateway               # Deploy gateway only
  $(basename "$0") --check                      # Dry run
  $(basename "$0") --limit "web_servers"        # Web servers only
  $(basename "$0") -e "otel_version=0.96.0"    # Upgrade version
  $(basename "$0") --tags restart -f 1          # Rolling restart
EOF
  exit 0
}

# Check prerequisites
check_prerequisites() {
  local missing=false

  if ! command -v ansible-playbook &>/dev/null; then
    log_error "ansible-playbook not found. Install Ansible:"
    echo "  pip install ansible"
    echo "  brew install ansible  (macOS)"
    echo "  apt install ansible   (Debian/Ubuntu)"
    missing=true
  fi

  if ! command -v ansible &>/dev/null; then
    log_error "ansible not found."
    missing=true
  fi

  if [[ "$missing" == true ]]; then
    exit 1
  fi

  log_success "Ansible found: $(ansible --version | head -1)"
}

# Verify inventory file exists
check_inventory() {
  if [[ ! -f "$INVENTORY" ]]; then
    log_error "Inventory file not found: ${INVENTORY}"
    log_info "Create one from the example or set ANSIBLE_INVENTORY"
    exit 1
  fi
  log_success "Inventory: ${INVENTORY}"
}

# Verify playbook exists
check_playbook() {
  if [[ ! -f "$PLAYBOOK" ]]; then
    log_warn "Playbook not found: ${PLAYBOOK}"
    log_info "Searching for alternative playbook locations..."

    # Try alternative locations
    local alternatives=(
      "${PROJECT_ROOT}/platforms/linux/ansible/playbook.yaml"
      "${PROJECT_ROOT}/platforms/linux/ansible/playbook.yml"
      "${PROJECT_ROOT}/platforms/linux/playbook.yaml"
      "${SCRIPT_DIR}/playbook.yaml"
    )

    for alt in "${alternatives[@]}"; do
      if [[ -f "$alt" ]]; then
        PLAYBOOK="$alt"
        log_success "Found playbook: ${PLAYBOOK}"
        return 0
      fi
    done

    log_error "No playbook found. Expected at: ${PLAYBOOK}"
    log_info "Ensure the Ansible playbook exists in the platforms/linux/ansible/ directory"
    exit 1
  fi
  log_success "Playbook: ${PLAYBOOK}"
}

# Test connectivity to hosts
test_connectivity() {
  log_info "Testing connectivity to hosts..."
  if ansible all -i "$INVENTORY" -m ping --one-line 2>/dev/null; then
    log_success "All hosts reachable"
  else
    log_warn "Some hosts may be unreachable. Continuing anyway..."
  fi
}

# ---------------------------------------------------------------------------
# Parse Arguments
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
fi

ANSIBLE_ARGS=()
SKIP_CONNECTIVITY=false
DO_LIST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-hosts|--list-tags|--list-tasks)
      DO_LIST=true
      ANSIBLE_ARGS+=("$1")
      shift
      ;;
    --skip-connectivity-check)
      SKIP_CONNECTIVITY=true
      shift
      ;;
    *)
      ANSIBLE_ARGS+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=============================================="
echo " OllyStack - On-Premises Fleet Deployment"
echo "=============================================="
echo ""

# Pre-flight checks
check_prerequisites
check_inventory
check_playbook

# Add vault password file if set
VAULT_ARGS=()
if [[ -n "$VAULT_PASS" ]]; then
  if [[ -f "$VAULT_PASS" ]]; then
    VAULT_ARGS=("--vault-password-file" "$VAULT_PASS")
    log_success "Vault password file: ${VAULT_PASS}"
  else
    log_warn "Vault password file not found: ${VAULT_PASS}"
  fi
fi

# Skip connectivity test for list operations
if [[ "$DO_LIST" == false && "$SKIP_CONNECTIVITY" == false ]]; then
  echo ""
  test_connectivity
fi

echo ""
log_info "Running Ansible playbook..."
echo "----------------------------------------------"
echo ""

# Build the full command
CMD=(
  ansible-playbook
  -i "$INVENTORY"
  "$PLAYBOOK"
  "${VAULT_ARGS[@]}"
  "${ANSIBLE_ARGS[@]}"
)

# Show the command being run
log_info "Command: ${CMD[*]}"
echo ""

# Execute
exec "${CMD[@]}"
