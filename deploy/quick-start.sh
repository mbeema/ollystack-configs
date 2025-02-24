#!/usr/bin/env bash
# ============================================================================
# OllyStack Quick-Start Deployment
# ============================================================================
# One-command deployment of the OTel Collector stack to Kubernetes.
# Deploys: Namespace → RBAC → ConfigMaps → Agent (DaemonSet) →
#          Gateway (Deployment + Service + HPA + PDB) → Cluster Receiver
#
# Prerequisites:
#   - kubectl configured with cluster access
#   - envsubst (part of gettext; brew install gettext on macOS)
#
# Usage:
#   ./deploy/quick-start.sh                           # Deploy with defaults
#   BACKEND_OTLP_ENDPOINT=tempo:4317 ./deploy/quick-start.sh  # Custom backend
#   ./deploy/quick-start.sh --dry-run                 # Preview manifests
#   ./deploy/quick-start.sh --delete                  # Tear down
#
# Environment variables (all optional except BACKEND_OTLP_ENDPOINT for gateway):
#   OTEL_NAMESPACE              Namespace (default: observability)
#   OTEL_COLLECTOR_IMAGE        Collector image (default: otel/opentelemetry-collector-contrib)
#   OTEL_COLLECTOR_VERSION      Collector version (default: 0.96.0)
#   BACKEND_OTLP_ENDPOINT       Backend OTLP endpoint (default: localhost:4317)
#   K8S_CLUSTER_NAME            Cluster name for resource attributes
#   DEPLOYMENT_ENVIRONMENT      Environment label (default: production)
# ============================================================================

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${REPO_ROOT}/platforms/kubernetes"

# Defaults
export OTEL_NAMESPACE="${OTEL_NAMESPACE:-observability}"
export OTEL_COLLECTOR_IMAGE="${OTEL_COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib}"
export OTEL_COLLECTOR_VERSION="${OTEL_COLLECTOR_VERSION:-0.96.0}"
export BACKEND_OTLP_ENDPOINT="${BACKEND_OTLP_ENDPOINT:-localhost:4317}"
export K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME:-my-cluster}"
export DEPLOYMENT_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT:-production}"
export OTEL_LOG_LEVEL="${OTEL_LOG_LEVEL:-info}"
export GATEWAY_REPLICAS="${GATEWAY_REPLICAS:-2}"
export GATEWAY_HPA_MIN_REPLICAS="${GATEWAY_HPA_MIN_REPLICAS:-2}"
export GATEWAY_HPA_MAX_REPLICAS="${GATEWAY_HPA_MAX_REPLICAS:-10}"
export OTEL_GATEWAY_INSECURE="${OTEL_GATEWAY_INSECURE:-true}"
export BACKEND_OTLP_INSECURE="${BACKEND_OTLP_INSECURE:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()   { echo -e "${RED}[error]${NC} $*" >&2; }

# ── Dependency check ─────────────────────────────────────────────────────────
check_deps() {
  local missing=0
  if ! command -v kubectl &>/dev/null; then
    err "kubectl is required but not found"
    missing=1
  fi
  if ! command -v envsubst &>/dev/null; then
    err "envsubst is required (install gettext: brew install gettext)"
    missing=1
  fi
  [[ $missing -eq 1 ]] && exit 1
}

# ── Render manifest (substitute env vars) ────────────────────────────────────
render() {
  local file="$1"
  # Only substitute variables we explicitly export; leave ${env:...} OTel
  # references and $(...) alone. envsubst with a variable list is safest.
  envsubst '${OTEL_NAMESPACE} ${OTEL_COLLECTOR_IMAGE} ${OTEL_COLLECTOR_VERSION}
    ${BACKEND_OTLP_ENDPOINT} ${K8S_CLUSTER_NAME} ${DEPLOYMENT_ENVIRONMENT}
    ${OTEL_LOG_LEVEL} ${GATEWAY_REPLICAS} ${GATEWAY_HPA_MIN_REPLICAS}
    ${GATEWAY_HPA_MAX_REPLICAS} ${OTEL_GATEWAY_INSECURE}
    ${BACKEND_OTLP_INSECURE}' < "$file"
}

# ── Create env ConfigMap ─────────────────────────────────────────────────────
render_env_configmap() {
  cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-env-config
  namespace: ${OTEL_NAMESPACE}
  labels:
    app.kubernetes.io/part-of: opentelemetry
data:
  OTEL_NAMESPACE: "${OTEL_NAMESPACE}"
  K8S_CLUSTER_NAME: "${K8S_CLUSTER_NAME}"
  DEPLOYMENT_ENVIRONMENT: "${DEPLOYMENT_ENVIRONMENT}"
  OTEL_LOG_LEVEL: "${OTEL_LOG_LEVEL}"
  BACKEND_OTLP_ENDPOINT: "${BACKEND_OTLP_ENDPOINT}"
EOF
}

# ── Create gateway ConfigMap from standalone YAML ────────────────────────────
render_gateway_configmap() {
  local config_content
  config_content=$(render "${K8S_DIR}/gateway/otel-gateway.yaml")
  cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-gateway-config
  namespace: ${OTEL_NAMESPACE}
  labels:
    app.kubernetes.io/name: otel-gateway
    app.kubernetes.io/component: gateway
    app.kubernetes.io/part-of: opentelemetry
data:
  config.yaml: |
$(echo "$config_content" | sed 's/^/    /')
EOF
}

# ── Apply order ──────────────────────────────────────────────────────────────
MANIFESTS=(
  "${K8S_DIR}/agent/namespace.yaml"
  "${K8S_DIR}/agent/serviceaccount.yaml"
  "${K8S_DIR}/agent/configmap.yaml"
  "${K8S_DIR}/agent/daemonset.yaml"
  "${K8S_DIR}/gateway/deployment.yaml"
  "${K8S_DIR}/gateway/service.yaml"
  "${K8S_DIR}/gateway/hpa.yaml"
  "${K8S_DIR}/gateway/pdb.yaml"
  "${K8S_DIR}/cluster-receiver/deployment.yaml"
)

# ── Deploy ───────────────────────────────────────────────────────────────────
do_deploy() {
  local dry_run_flag=""
  [[ "${1:-}" == "--dry-run" ]] && dry_run_flag="--dry-run=client"

  info "Deploying OllyStack OTel Collector to namespace: ${OTEL_NAMESPACE}"
  echo ""
  info "Configuration:"
  echo "  Namespace:    ${OTEL_NAMESPACE}"
  echo "  Image:        ${OTEL_COLLECTOR_IMAGE}:${OTEL_COLLECTOR_VERSION}"
  echo "  Backend:      ${BACKEND_OTLP_ENDPOINT}"
  echo "  Environment:  ${DEPLOYMENT_ENVIRONMENT}"
  echo "  Cluster:      ${K8S_CLUSTER_NAME}"
  echo "  Gateway:      ${GATEWAY_REPLICAS} replicas (HPA: ${GATEWAY_HPA_MIN_REPLICAS}-${GATEWAY_HPA_MAX_REPLICAS})"
  echo ""

  # 1. Namespace + RBAC
  info "Creating namespace and RBAC..."
  render "${K8S_DIR}/agent/namespace.yaml" | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/agent/serviceaccount.yaml" | kubectl apply ${dry_run_flag} -f -
  ok "Namespace and RBAC ready"

  # 2. Environment ConfigMap
  info "Creating environment ConfigMap..."
  render_env_configmap | kubectl apply ${dry_run_flag} -f -
  ok "Environment ConfigMap ready"

  # 3. Agent (ConfigMap + DaemonSet)
  info "Deploying agent DaemonSet..."
  render "${K8S_DIR}/agent/configmap.yaml" | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/agent/daemonset.yaml" | kubectl apply ${dry_run_flag} -f -
  ok "Agent DaemonSet deployed"

  # 4. Gateway (ConfigMap + Deployment + Service + HPA + PDB)
  info "Deploying gateway..."
  render_gateway_configmap | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/gateway/deployment.yaml" | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/gateway/service.yaml" | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/gateway/hpa.yaml" | kubectl apply ${dry_run_flag} -f -
  render "${K8S_DIR}/gateway/pdb.yaml" | kubectl apply ${dry_run_flag} -f -
  ok "Gateway deployed (${GATEWAY_REPLICAS} replicas + HPA + PDB)"

  # 5. Cluster Receiver
  info "Deploying cluster receiver..."
  render "${K8S_DIR}/cluster-receiver/deployment.yaml" | kubectl apply ${dry_run_flag} -f -
  ok "Cluster receiver deployed"

  # 6. NetworkPolicy (if exists)
  local netpol="${SCRIPT_DIR}/networkpolicy.yaml"
  if [[ -f "$netpol" ]]; then
    info "Applying NetworkPolicy..."
    render "$netpol" | kubectl apply ${dry_run_flag} -f -
    ok "NetworkPolicy applied"
  fi

  echo ""
  ok "OllyStack deployment complete!"
  echo ""
  info "Verify with:"
  echo "  kubectl -n ${OTEL_NAMESPACE} get pods"
  echo "  kubectl -n ${OTEL_NAMESPACE} get svc"
  echo "  kubectl -n ${OTEL_NAMESPACE} logs -l app.kubernetes.io/name=otel-agent --tail=20"
  echo "  kubectl -n ${OTEL_NAMESPACE} logs -l app.kubernetes.io/name=otel-gateway --tail=20"
  echo ""
  info "Health check:"
  echo "  kubectl -n ${OTEL_NAMESPACE} port-forward svc/otel-gateway 13133:13133"
  echo "  curl http://localhost:13133"
  echo ""
  info "Send test telemetry:"
  echo "  ./deploy/test-telemetry.sh"
}

# ── Delete ───────────────────────────────────────────────────────────────────
do_delete() {
  warn "Deleting OllyStack from namespace: ${OTEL_NAMESPACE}"
  echo ""

  # Reverse order
  info "Removing cluster receiver..."
  render "${K8S_DIR}/cluster-receiver/deployment.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true

  info "Removing gateway..."
  render "${K8S_DIR}/gateway/pdb.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  render "${K8S_DIR}/gateway/hpa.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  render "${K8S_DIR}/gateway/service.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  render "${K8S_DIR}/gateway/deployment.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  kubectl -n "${OTEL_NAMESPACE}" delete configmap otel-gateway-config --ignore-not-found 2>/dev/null || true

  info "Removing agent..."
  render "${K8S_DIR}/agent/daemonset.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  render "${K8S_DIR}/agent/configmap.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true

  info "Removing RBAC and env config..."
  kubectl -n "${OTEL_NAMESPACE}" delete configmap otel-env-config --ignore-not-found 2>/dev/null || true
  render "${K8S_DIR}/agent/serviceaccount.yaml" | kubectl delete --ignore-not-found -f - 2>/dev/null || true

  local netpol="${SCRIPT_DIR}/networkpolicy.yaml"
  if [[ -f "$netpol" ]]; then
    info "Removing NetworkPolicy..."
    render "$netpol" | kubectl delete --ignore-not-found -f - 2>/dev/null || true
  fi

  info "Removing namespace..."
  kubectl delete namespace "${OTEL_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  echo ""
  ok "OllyStack removed"
}

# ── Status ───────────────────────────────────────────────────────────────────
do_status() {
  info "OllyStack status in namespace: ${OTEL_NAMESPACE}"
  echo ""

  echo -e "${BOLD}Pods:${NC}"
  kubectl -n "${OTEL_NAMESPACE}" get pods -o wide 2>/dev/null || warn "No pods found"
  echo ""

  echo -e "${BOLD}Services:${NC}"
  kubectl -n "${OTEL_NAMESPACE}" get svc 2>/dev/null || warn "No services found"
  echo ""

  echo -e "${BOLD}DaemonSet:${NC}"
  kubectl -n "${OTEL_NAMESPACE}" get daemonset 2>/dev/null || warn "No DaemonSets found"
  echo ""

  echo -e "${BOLD}Deployments:${NC}"
  kubectl -n "${OTEL_NAMESPACE}" get deployments 2>/dev/null || warn "No Deployments found"
  echo ""

  echo -e "${BOLD}HPA:${NC}"
  kubectl -n "${OTEL_NAMESPACE}" get hpa 2>/dev/null || warn "No HPA found"
}

# ── Main ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}OllyStack Quick-Start Deployment${NC}

Usage: $0 [command]

Commands:
  deploy      Deploy the full collector stack (default)
  --dry-run   Preview manifests without applying
  --delete    Remove the collector stack
  status      Show deployment status

Environment variables:
  OTEL_NAMESPACE            Namespace (default: observability)
  BACKEND_OTLP_ENDPOINT     Backend endpoint (default: localhost:4317)
  K8S_CLUSTER_NAME          Cluster name (default: my-cluster)
  DEPLOYMENT_ENVIRONMENT    Environment (default: production)
  OTEL_COLLECTOR_VERSION    Collector version (default: 0.96.0)
  GATEWAY_REPLICAS          Gateway replicas (default: 2)

Examples:
  $0                                                          # Deploy with defaults
  BACKEND_OTLP_ENDPOINT=tempo:4317 $0                         # Custom backend
  OTEL_NAMESPACE=monitoring K8S_CLUSTER_NAME=prod-us-east $0  # Custom namespace
  $0 --dry-run                                                # Preview only
  $0 --delete                                                 # Tear down
  $0 status                                                   # Check status
EOF
}

main() {
  check_deps

  case "${1:-deploy}" in
    deploy)     do_deploy ;;
    --dry-run)  do_deploy "--dry-run" ;;
    --delete)   do_delete ;;
    status)     do_status ;;
    -h|--help)  usage ;;
    *)          err "Unknown command: $1"; usage; exit 1 ;;
  esac
}

main "$@"
