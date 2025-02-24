#!/usr/bin/env bash
# ============================================================================
# OllyStack Telemetry Test Script
# ============================================================================
# Sends test traces, metrics, and logs to the OTel Collector and verifies
# the pipeline is healthy. Works both in-cluster and via port-forward.
#
# Prerequisites:
#   - kubectl configured with cluster access
#   - telemetrygen (optional, for sending test data)
#     Install: go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@latest
#
# Usage:
#   ./deploy/test-telemetry.sh                    # Full test suite
#   ./deploy/test-telemetry.sh health             # Health checks only
#   ./deploy/test-telemetry.sh send               # Send test telemetry only
#   ./deploy/test-telemetry.sh status             # Show pipeline metrics
# ============================================================================

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────────────────
NAMESPACE="${OTEL_NAMESPACE:-observability}"
GATEWAY_SVC="otel-gateway"
HEALTH_PORT="${HEALTH_PORT:-13133}"
OTLP_GRPC_PORT="${OTLP_GRPC_PORT:-4317}"
METRICS_PORT="${METRICS_PORT:-8888}"
PF_PID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[pass]${NC}  $*"; }
fail()  { echo -e "${RED}[fail]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }

TESTS_PASSED=0
TESTS_FAILED=0

assert_ok() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
    ((TESTS_PASSED++))
  else
    fail "$desc"
    ((TESTS_FAILED++))
  fi
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -n "$PF_PID" ]] && kill -0 "$PF_PID" 2>/dev/null; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ── Port-forward helper ──────────────────────────────────────────────────────
start_port_forward() {
  local local_health=13133
  local local_grpc=4317
  local local_metrics=8888

  info "Starting port-forward to ${GATEWAY_SVC} in ${NAMESPACE}..."
  kubectl -n "$NAMESPACE" port-forward "svc/${GATEWAY_SVC}" \
    "${local_health}:${HEALTH_PORT}" \
    "${local_grpc}:${OTLP_GRPC_PORT}" \
    "${local_metrics}:${METRICS_PORT}" &
  PF_PID=$!

  # Wait for port-forward to establish
  local retries=10
  while ! curl -s "http://localhost:${local_health}" >/dev/null 2>&1; do
    ((retries--))
    if [[ $retries -le 0 ]]; then
      fail "Port-forward failed to establish"
      exit 1
    fi
    sleep 1
  done
  ok "Port-forward established (PID: ${PF_PID})"
}

# ── Test: Pod health ─────────────────────────────────────────────────────────
test_pods() {
  echo ""
  echo -e "${BOLD}── Pod Health ─────────────────────────────────────────${NC}"

  # Agent DaemonSet
  local agent_ready
  agent_ready=$(kubectl -n "$NAMESPACE" get daemonset otel-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  local agent_desired
  agent_desired=$(kubectl -n "$NAMESPACE" get daemonset otel-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  if [[ "$agent_ready" -gt 0 && "$agent_ready" == "$agent_desired" ]]; then
    ok "Agent DaemonSet: ${agent_ready}/${agent_desired} pods ready"
    ((TESTS_PASSED++))
  else
    fail "Agent DaemonSet: ${agent_ready}/${agent_desired} pods ready"
    ((TESTS_FAILED++))
  fi

  # Gateway Deployment
  local gw_ready
  gw_ready=$(kubectl -n "$NAMESPACE" get deployment otel-gateway -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  local gw_desired
  gw_desired=$(kubectl -n "$NAMESPACE" get deployment otel-gateway -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  if [[ "$gw_ready" -gt 0 && "$gw_ready" == "$gw_desired" ]]; then
    ok "Gateway Deployment: ${gw_ready}/${gw_desired} pods ready"
    ((TESTS_PASSED++))
  else
    fail "Gateway Deployment: ${gw_ready}/${gw_desired} pods ready"
    ((TESTS_FAILED++))
  fi

  # Cluster Receiver
  local cr_ready
  cr_ready=$(kubectl -n "$NAMESPACE" get deployment otel-cluster-receiver -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "$cr_ready" -ge 1 ]]; then
    ok "Cluster Receiver: ${cr_ready}/1 pods ready"
    ((TESTS_PASSED++))
  else
    fail "Cluster Receiver: ${cr_ready}/1 pods ready"
    ((TESTS_FAILED++))
  fi
}

# ── Test: Health endpoints ───────────────────────────────────────────────────
test_health() {
  echo ""
  echo -e "${BOLD}── Health Endpoints ───────────────────────────────────${NC}"

  # Gateway health via port-forward
  assert_ok "Gateway health endpoint responds" \
    curl -sf "http://localhost:${HEALTH_PORT}"

  # Check that response indicates healthy status
  local health_body
  health_body=$(curl -sf "http://localhost:${HEALTH_PORT}" 2>/dev/null || echo "")
  if echo "$health_body" | grep -qi "ok\|healthy\|ready\|UP" 2>/dev/null; then
    ok "Gateway reports healthy status"
    ((TESTS_PASSED++))
  elif [[ -n "$health_body" ]]; then
    warn "Gateway responded but status unclear: ${health_body:0:100}"
    ((TESTS_PASSED++))
  else
    fail "Gateway health endpoint returned empty response"
    ((TESTS_FAILED++))
  fi
}

# ── Test: Collector metrics ──────────────────────────────────────────────────
test_metrics() {
  echo ""
  echo -e "${BOLD}── Collector Self-Metrics ─────────────────────────────${NC}"

  local metrics
  metrics=$(curl -sf "http://localhost:${METRICS_PORT}/metrics" 2>/dev/null || echo "")

  if [[ -z "$metrics" ]]; then
    fail "Could not fetch collector metrics from :${METRICS_PORT}/metrics"
    ((TESTS_FAILED++))
    return
  fi

  ok "Collector metrics endpoint responds"
  ((TESTS_PASSED++))

  # Check key metric families exist
  local check_metrics=(
    "otelcol_receiver_accepted_spans"
    "otelcol_receiver_accepted_metric_points"
    "otelcol_exporter_sent_spans"
    "otelcol_processor_batch_batch_send_size"
    "otelcol_process_uptime"
    "otelcol_process_memory_rss"
  )

  for m in "${check_metrics[@]}"; do
    if echo "$metrics" | grep -q "$m"; then
      ok "Metric present: ${m}"
      ((TESTS_PASSED++))
    else
      warn "Metric not found: ${m} (may appear after first data)"
    fi
  done

  # Check for exporter failures
  local failures
  failures=$(echo "$metrics" | grep "otelcol_exporter_send_failed" | grep -v "^#" | awk '{sum+=$2} END {print sum+0}')
  if [[ "${failures}" == "0" ]]; then
    ok "No exporter send failures detected"
    ((TESTS_PASSED++))
  else
    fail "Exporter send failures detected: ${failures}"
    ((TESTS_FAILED++))
  fi
}

# ── Test: Send telemetry with telemetrygen ───────────────────────────────────
test_send() {
  echo ""
  echo -e "${BOLD}── Send Test Telemetry ────────────────────────────────${NC}"

  if ! command -v telemetrygen &>/dev/null; then
    warn "telemetrygen not installed — skipping send tests"
    echo "  Install: go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@latest"
    echo ""

    # Fall back to a simple gRPC connectivity test
    info "Falling back to gRPC connectivity test..."
    if command -v grpcurl &>/dev/null; then
      assert_ok "gRPC port 4317 accepts connections" \
        grpcurl -plaintext localhost:4317 list
    else
      # Raw TCP check
      assert_ok "OTLP gRPC port 4317 is open" \
        bash -c "echo '' | nc -z localhost 4317"
    fi
    return
  fi

  # Send test traces
  info "Sending 10 test traces..."
  if telemetrygen traces \
    --otlp-endpoint localhost:4317 \
    --otlp-insecure \
    --traces 10 \
    --service test-ollystack \
    --otlp-attributes='deployment.environment="test"' 2>/dev/null; then
    ok "10 test traces sent successfully"
    ((TESTS_PASSED++))
  else
    fail "Failed to send test traces"
    ((TESTS_FAILED++))
  fi

  # Send test metrics
  info "Sending 10 test metrics..."
  if telemetrygen metrics \
    --otlp-endpoint localhost:4317 \
    --otlp-insecure \
    --metrics 10 \
    --service test-ollystack 2>/dev/null; then
    ok "10 test metrics sent successfully"
    ((TESTS_PASSED++))
  else
    fail "Failed to send test metrics"
    ((TESTS_FAILED++))
  fi

  # Send test logs
  info "Sending 10 test logs..."
  if telemetrygen logs \
    --otlp-endpoint localhost:4317 \
    --otlp-insecure \
    --logs 10 \
    --service test-ollystack 2>/dev/null; then
    ok "10 test logs sent successfully"
    ((TESTS_PASSED++))
  else
    fail "Failed to send test logs"
    ((TESTS_FAILED++))
  fi

  # Verify data was processed (wait briefly for pipeline flush)
  sleep 3
  info "Verifying pipeline processed the test data..."
  local metrics_after
  metrics_after=$(curl -sf "http://localhost:${METRICS_PORT}/metrics" 2>/dev/null || echo "")

  local accepted_spans
  accepted_spans=$(echo "$metrics_after" | grep 'otelcol_receiver_accepted_spans{.*transport="grpc"' | grep -v "^#" | awk '{sum+=$2} END {print sum+0}')
  if [[ "${accepted_spans:-0}" -gt 0 ]]; then
    ok "Pipeline processed spans: ${accepted_spans} accepted"
    ((TESTS_PASSED++))
  else
    warn "No accepted spans metric found yet (pipeline may need more time)"
  fi
}

# ── Test: Agent connectivity (in-cluster check) ─────────────────────────────
test_agent_logs() {
  echo ""
  echo -e "${BOLD}── Agent Log Check ────────────────────────────────────${NC}"

  local agent_pod
  agent_pod=$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/name=otel-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$agent_pod" ]]; then
    warn "No agent pod found — skipping log check"
    return
  fi

  local logs
  logs=$(kubectl -n "$NAMESPACE" logs "$agent_pod" --tail=50 2>/dev/null || echo "")

  if echo "$logs" | grep -qi "error"; then
    local error_count
    error_count=$(echo "$logs" | grep -ci "error")
    fail "Agent logs contain ${error_count} error(s) in last 50 lines"
    ((TESTS_FAILED++))
    echo "  Latest errors:"
    echo "$logs" | grep -i "error" | tail -3 | sed 's/^/    /'
  else
    ok "Agent logs clean (no errors in last 50 lines)"
    ((TESTS_PASSED++))
  fi

  if echo "$logs" | grep -qi "everything is ready"; then
    ok "Agent reports 'everything is ready'"
    ((TESTS_PASSED++))
  fi
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}── Summary ────────────────────────────────────────────${NC}"
  local total=$((TESTS_PASSED + TESTS_FAILED))
  echo -e "  Passed: ${GREEN}${TESTS_PASSED}${NC} / ${total}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "  Failed: ${RED}${TESTS_FAILED}${NC} / ${total}"
    echo ""
    fail "Some tests failed. Check collector logs:"
    echo "  kubectl -n ${NAMESPACE} logs -l app.kubernetes.io/name=otel-gateway --tail=50"
    echo "  kubectl -n ${NAMESPACE} logs -l app.kubernetes.io/name=otel-agent --tail=50"
    return 1
  else
    echo ""
    ok "All tests passed!"
    return 0
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}OllyStack Telemetry Test${NC}

Usage: $0 [command]

Commands:
  all         Run full test suite (default)
  health      Health checks only (pods + endpoints)
  send        Send test telemetry only
  status      Show collector pipeline metrics

Environment variables:
  OTEL_NAMESPACE    Namespace (default: observability)
  HEALTH_PORT       Health check port (default: 13133)
  OTLP_GRPC_PORT    OTLP gRPC port (default: 4317)
  METRICS_PORT      Metrics port (default: 8888)

Prerequisites:
  - kubectl with cluster access
  - telemetrygen (optional):
    go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@latest
EOF
}

main() {
  case "${1:-all}" in
    all)
      info "Running OllyStack full test suite"
      info "Namespace: ${NAMESPACE}"
      test_pods
      start_port_forward
      test_health
      test_metrics
      test_send
      test_agent_logs
      print_summary
      ;;
    health)
      info "Running health checks"
      test_pods
      start_port_forward
      test_health
      print_summary
      ;;
    send)
      info "Sending test telemetry"
      start_port_forward
      test_send
      print_summary
      ;;
    status)
      start_port_forward
      test_metrics
      print_summary
      ;;
    -h|--help)
      usage
      ;;
    *)
      err "Unknown command: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
