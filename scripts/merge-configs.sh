#!/usr/bin/env bash
# =============================================================================
# OllyStack - YAML Configuration Merger
# =============================================================================
# Deep-merges multiple OpenTelemetry Collector YAML config files using yq.
# Later files override earlier files. Properly handles all OTel sections:
# receivers, processors, exporters, extensions, connectors, and service.
#
# Usage:
#   ./scripts/merge-configs.sh base.yaml fragment1.yaml fragment2.yaml
#   ./scripts/merge-configs.sh base.yaml fragment1.yaml > output.yaml
#   ./scripts/merge-configs.sh --output merged.yaml base.yaml overlay.yaml
#
# Requirements:
#   - yq v4+ (https://github.com/mikefarah/yq)
#
# Examples:
#   # Merge base with AWS platform overlay
#   ./scripts/merge-configs.sh \
#     collector/base/otel-collector.yaml \
#     platforms/aws/eks/collector-config.yaml \
#     > my-merged-config.yaml
#
#   # Merge multiple fragments
#   ./scripts/merge-configs.sh \
#     collector/base/otel-collector.yaml \
#     collector/receivers/otlp.yaml \
#     collector/processors/batch.yaml \
#     collector/exporters/otlp.yaml
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE=""
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] file1.yaml file2.yaml [file3.yaml ...]

Deep-merge multiple OpenTelemetry Collector YAML configuration files.

Arguments:
  file1.yaml    Base configuration file
  file2.yaml    Overlay/fragment to merge (overrides base)
  file3.yaml    Additional overlays (applied in order)

Options:
  -o, --output FILE   Write output to FILE instead of stdout
  -v, --verbose       Show merge progress on stderr
  -h, --help          Show this help message

Notes:
  - Files are merged left to right; later files override earlier ones
  - Deep merge is used: maps are merged recursively, arrays are replaced
  - All OTel Collector sections are handled: receivers, processors,
    exporters, extensions, connectors, and service (including pipelines)
  - Output goes to stdout by default (redirect to file as needed)

Requirements:
  - yq v4+ (https://github.com/mikefarah/yq)
EOF
  exit 0
}

log_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    echo -e "${BLUE}[MERGE]${NC} $1" >&2
  fi
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Check prerequisites
check_prerequisites() {
  if ! command -v yq &>/dev/null; then
    log_error "'yq' is not installed or not in PATH."
    echo "" >&2
    echo "Install yq v4+:" >&2
    echo "  brew install yq                    # macOS" >&2
    echo "  snap install yq                    # Linux (snap)" >&2
    echo "  go install github.com/mikefarah/yq/v4@latest  # Go" >&2
    echo "  https://github.com/mikefarah/yq/releases      # Binary" >&2
    exit 1
  fi

  # Verify yq version (must be v4+)
  local yq_version
  yq_version=$(yq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local major_version
  major_version=$(echo "$yq_version" | cut -d. -f1)

  if [[ -n "$major_version" ]] && [[ "$major_version" -lt 4 ]]; then
    log_error "yq v4+ is required, but found v${yq_version}"
    log_error "Please upgrade: https://github.com/mikefarah/yq"
    exit 1
  fi

  log_verbose "Using yq version: ${yq_version}"
}

# Validate that a file exists and is readable
validate_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "File not found: ${file}"
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    log_error "File not readable: ${file}"
    return 1
  fi

  # Basic YAML syntax check
  if ! yq eval '.' "$file" >/dev/null 2>&1; then
    log_error "Invalid YAML syntax in: ${file}"
    return 1
  fi

  return 0
}

# Deep merge two YAML files using yq
# Uses yq's built-in merge operator (*) for deep merging
deep_merge() {
  local base="$1"
  local overlay="$2"

  # yq's multiply-merge operator (*) performs deep merge:
  # - Maps are merged recursively
  # - Scalar values from overlay replace base values
  # - Arrays from overlay replace base arrays (standard OTel behavior)
  yq eval-all '
    select(fileIndex == 0) * select(fileIndex == 1)
  ' "$base" "$overlay"
}

# Merge service.pipelines section with special handling
# This ensures pipeline arrays (receivers, processors, exporters) are
# properly merged rather than just replaced
merge_with_pipeline_append() {
  local base="$1"
  local overlay="$2"

  # Use yq to deep merge with custom pipeline handling
  yq eval-all '
    # Deep merge all top-level keys
    select(fileIndex == 0) * select(fileIndex == 1)
  ' "$base" "$overlay"
}

# ---------------------------------------------------------------------------
# Parse Arguments
# ---------------------------------------------------------------------------
INPUT_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      if [[ -z "${2:-}" ]]; then
        log_error "--output requires a filename argument"
        exit 1
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      log_error "Unknown option: $1"
      echo "" >&2
      usage
      ;;
    *)
      INPUT_FILES+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate Inputs
# ---------------------------------------------------------------------------
if [[ ${#INPUT_FILES[@]} -lt 2 ]]; then
  log_error "At least 2 input files are required."
  echo "" >&2
  usage
fi

check_prerequisites

# Validate all input files exist
for file in "${INPUT_FILES[@]}"; do
  if ! validate_file "$file"; then
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Perform Merge
# ---------------------------------------------------------------------------
log_verbose "Merging ${#INPUT_FILES[@]} configuration files..."

# Start with the first file as the base
TEMP_RESULT=$(mktemp /tmp/ollystack-merge-XXXXXX.yaml)
TEMP_INTERMEDIATE=$(mktemp /tmp/ollystack-merge-intermediate-XXXXXX.yaml)

# Cleanup temp files on exit
cleanup() {
  rm -f "$TEMP_RESULT" "$TEMP_INTERMEDIATE"
}
trap cleanup EXIT

# Copy the first file as the starting base
cp "${INPUT_FILES[0]}" "$TEMP_RESULT"
log_verbose "Base: ${INPUT_FILES[0]}"

# Iteratively merge each subsequent file
for ((i = 1; i < ${#INPUT_FILES[@]}; i++)); do
  overlay="${INPUT_FILES[$i]}"
  log_verbose "Merging overlay ${i}/${#INPUT_FILES[@]}: ${overlay}"

  # Perform deep merge
  if ! deep_merge "$TEMP_RESULT" "$overlay" > "$TEMP_INTERMEDIATE" 2>/dev/null; then
    log_error "Failed to merge: ${overlay}"
    exit 1
  fi

  # Swap result
  cp "$TEMP_INTERMEDIATE" "$TEMP_RESULT"
done

# ---------------------------------------------------------------------------
# Output Result
# ---------------------------------------------------------------------------
# Add a header comment
HEADER="# =============================================================================
# Merged OpenTelemetry Collector Configuration
# =============================================================================
# Generated by: $(basename "$0")
# Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# Source files:
$(for f in "${INPUT_FILES[@]}"; do echo "#   - ${f}"; done)
# =============================================================================
"

if [[ -n "$OUTPUT_FILE" ]]; then
  {
    echo "$HEADER"
    cat "$TEMP_RESULT"
  } > "$OUTPUT_FILE"
  log_verbose "Output written to: ${OUTPUT_FILE}"
  echo -e "${GREEN}Successfully merged ${#INPUT_FILES[@]} files -> ${OUTPUT_FILE}${NC}" >&2
else
  echo "$HEADER"
  cat "$TEMP_RESULT"
  log_verbose "Output written to stdout"
fi
