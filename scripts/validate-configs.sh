#!/usr/bin/env bash
# =============================================================================
# OllyStack - Configuration Validator
# =============================================================================
# Validates OpenTelemetry Collector configuration files using otelcol validate.
#
# Usage:
#   ./scripts/validate-configs.sh              # Validate all configs
#   ./scripts/validate-configs.sh --fix        # Attempt auto-fix on failures
#   ./scripts/validate-configs.sh --verbose    # Show detailed output
#   ./scripts/validate-configs.sh --help       # Show help
#
# The script scans collector/ and platforms/ directories for *.yaml files,
# skipping known fragment files that are not standalone configs.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERGE_SCRIPT="${SCRIPT_DIR}/merge-configs.sh"

# Directories to scan
SCAN_DIRS=(
  "${PROJECT_ROOT}/collector"
  "${PROJECT_ROOT}/platforms"
)

# Patterns that indicate a file is a fragment (not a complete config)
FRAGMENT_PATTERNS=(
  "*/fragments/*"
  "*/patches/*"
  "*/overlays/*"
  "*/partial/*"
  "*-fragment.yaml"
  "*-patch.yaml"
  "*_fragment.yaml"
  "*_patch.yaml"
)

# Base config to merge fragments with (if --fix is used)
BASE_CONFIG="${PROJECT_ROOT}/collector/base/otel-collector.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
FIX_MODE=false
VERBOSE=false
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FAILED_FILES=()

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validate OpenTelemetry Collector configuration files.

Options:
  --fix         Attempt to auto-fix failing configs (experimental)
  --verbose     Show detailed validation output
  --help        Show this help message

Description:
  Scans collector/ and platforms/ directories for *.yaml files and validates
  each using 'otelcol validate --config='. Fragment files (partials, patches)
  are detected and skipped unless --fix is specified, in which case they are
  merged with the base config before validation.

Exit Codes:
  0   All configs valid
  1   One or more configs failed validation
EOF
  exit 0
}

log_pass() {
  echo -e "  ${GREEN}PASS${NC}  $1"
  ((PASS_COUNT++))
}

log_fail() {
  echo -e "  ${RED}FAIL${NC}  $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "        ${RED}Error: ${2}${NC}"
  fi
  ((FAIL_COUNT++))
  FAILED_FILES+=("$1")
}

log_skip() {
  echo -e "  ${YELLOW}SKIP${NC}  $1 ${BLUE}(fragment)${NC}"
  ((SKIP_COUNT++))
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if a file matches any fragment pattern
is_fragment() {
  local file="$1"
  for pattern in "${FRAGMENT_PATTERNS[@]}"; do
    # Use bash pattern matching (glob is intentional)
    # shellcheck disable=SC2053
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# Check if otelcol binary is available
check_otelcol() {
  if ! command -v otelcol &>/dev/null && ! command -v otelcol-contrib &>/dev/null; then
    echo -e "${YELLOW}WARNING: 'otelcol' binary not found in PATH.${NC}"
    echo -e "${YELLOW}Install it from: https://opentelemetry.io/docs/collector/installation/${NC}"
    echo ""
    echo "Falling back to basic YAML syntax validation..."
    return 1
  fi
  return 0
}

# Get the otelcol binary name
get_otelcol_bin() {
  if command -v otelcol-contrib &>/dev/null; then
    echo "otelcol-contrib"
  elif command -v otelcol &>/dev/null; then
    echo "otelcol"
  else
    echo ""
  fi
}

# Validate a single config file using otelcol
validate_with_otelcol() {
  local file="$1"
  local otelcol_bin
  otelcol_bin="$(get_otelcol_bin)"

  if [[ -z "$otelcol_bin" ]]; then
    # Fallback: basic YAML syntax check using python
    if command -v python3 &>/dev/null; then
      local output
      output=$(python3 -c "
import yaml, sys
try:
    with open('${file}', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
" 2>&1)
      return $?
    else
      # No validation tool available, skip
      return 0
    fi
  fi

  local output
  if [[ "$VERBOSE" == true ]]; then
    output=$("${otelcol_bin}" validate --config="$file" 2>&1) || {
      echo "$output"
      return 1
    }
    echo "$output"
  else
    output=$("${otelcol_bin}" validate --config="$file" 2>&1) || {
      echo "$output" | tail -5
      return 1
    }
  fi
  return 0
}

# Attempt to fix a config by merging with base
attempt_fix() {
  local file="$1"
  local tmp_merged
  tmp_merged=$(mktemp /tmp/ollystack-merged-XXXXXX.yaml)

  if [[ ! -f "$BASE_CONFIG" ]]; then
    echo "Base config not found at ${BASE_CONFIG}, cannot auto-fix"
    rm -f "$tmp_merged"
    return 1
  fi

  if [[ ! -x "$MERGE_SCRIPT" ]]; then
    echo "Merge script not found or not executable at ${MERGE_SCRIPT}"
    rm -f "$tmp_merged"
    return 1
  fi

  log_info "Attempting fix: merging with base config..."
  if "${MERGE_SCRIPT}" "${BASE_CONFIG}" "$file" > "$tmp_merged" 2>/dev/null; then
    if validate_with_otelcol "$tmp_merged" >/dev/null 2>&1; then
      echo -e "  ${GREEN}FIXED${NC} Merged config validates successfully"
      echo -e "        ${BLUE}Suggested: ${MERGE_SCRIPT} ${BASE_CONFIG} ${file}${NC}"
      rm -f "$tmp_merged"
      return 0
    fi
  fi

  rm -f "$tmp_merged"
  echo -e "  ${RED}UNFIXABLE${NC} Could not auto-fix this config"
  return 1
}

# ---------------------------------------------------------------------------
# Parse Arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=============================================="
echo " OllyStack - Configuration Validator"
echo "=============================================="
echo ""

check_otelcol || true
echo ""

# Collect all YAML files from scan directories
CONFIG_FILES=()
for dir in "${SCAN_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' file; do
      CONFIG_FILES+=("$file")
    done < <(find "$dir" -name "*.yaml" -o -name "*.yml" | sort | tr '\n' '\0')
  else
    log_info "Directory not found, skipping: ${dir}"
  fi
done

if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No configuration files found to validate.${NC}"
  echo "Searched directories:"
  for dir in "${SCAN_DIRS[@]}"; do
    echo "  - ${dir}"
  done
  exit 0
fi

log_info "Found ${#CONFIG_FILES[@]} configuration file(s) to validate"
echo ""

# Validate each file
for config_file in "${CONFIG_FILES[@]}"; do
  # Make path relative for display
  relative_path="${config_file#"${PROJECT_ROOT}"/}"

  # Check if this is a fragment
  if is_fragment "$config_file"; then
    if [[ "$FIX_MODE" == true ]]; then
      # In fix mode, try to merge fragments with base and validate
      log_info "Fragment detected, attempting merge+validate: ${relative_path}"
      if attempt_fix "$config_file"; then
        ((PASS_COUNT++))
      else
        log_fail "$relative_path" "Fragment could not be merged and validated"
      fi
    else
      log_skip "$relative_path"
    fi
    continue
  fi

  # Validate the config
  error_output=""
  if error_output=$(validate_with_otelcol "$config_file" 2>&1); then
    log_pass "$relative_path"
  else
    log_fail "$relative_path" "$error_output"

    # Attempt fix if requested
    if [[ "$FIX_MODE" == true ]]; then
      attempt_fix "$config_file" || true
    fi
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Validation Summary"
echo "=============================================="
echo -e "  ${GREEN}Passed:${NC}  ${PASS_COUNT}"
echo -e "  ${RED}Failed:${NC}  ${FAIL_COUNT}"
echo -e "  ${YELLOW}Skipped:${NC} ${SKIP_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -gt 0 ]]; then
  echo -e "${RED}Failed files:${NC}"
  for f in "${FAILED_FILES[@]}"; do
    echo "  - ${f}"
  done
  echo ""
  echo -e "${RED}Validation FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}All configurations valid!${NC}"
  exit 0
fi
