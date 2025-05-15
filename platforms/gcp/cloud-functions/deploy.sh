#!/usr/bin/env bash
# deploy.sh
# Deploys a Cloud Function with OpenTelemetry instrumentation environment variables
# Usage: ./deploy.sh [--gen2] [--region REGION] [--runtime RUNTIME]
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Cloud Functions API enabled
#   - Cloud Trace API enabled
#   - Cloud Monitoring API enabled

set -euo pipefail

# --- Configuration (override via environment variables) ---
FUNCTION_NAME="${FUNCTION_NAME:?FUNCTION_NAME is required}"
GCP_PROJECT_ID="${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
GCP_REGION="${GCP_REGION:-us-central1}"
FUNCTION_RUNTIME="${FUNCTION_RUNTIME:-nodejs20}"
FUNCTION_ENTRY_POINT="${FUNCTION_ENTRY_POINT:-handler}"
FUNCTION_SOURCE="${FUNCTION_SOURCE:-.}"
FUNCTION_MEMORY="${FUNCTION_MEMORY:-512MB}"
FUNCTION_TIMEOUT="${FUNCTION_TIMEOUT:-60s}"
FUNCTION_MAX_INSTANCES="${FUNCTION_MAX_INSTANCES:-100}"
FUNCTION_MIN_INSTANCES="${FUNCTION_MIN_INSTANCES:-0}"
FUNCTION_TRIGGER="${FUNCTION_TRIGGER:-http}"
FUNCTION_SERVICE_ACCOUNT="${FUNCTION_SERVICE_ACCOUNT:-}"
FUNCTION_VERSION="${FUNCTION_VERSION:-1.0.0}"
ENVIRONMENT="${ENVIRONMENT:-production}"
USE_GEN2="${USE_GEN2:-true}"

# OTel Configuration
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-${FUNCTION_NAME}}"
OTEL_TRACES_SAMPLER="${OTEL_TRACES_SAMPLER:-parentbased_traceidratio}"
OTEL_TRACES_SAMPLER_ARG="${OTEL_TRACES_SAMPLER_ARG:-0.1}"
OTEL_LOG_LEVEL="${OTEL_LOG_LEVEL:-info}"
OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --gen2)
      USE_GEN2="true"
      shift
      ;;
    --gen1)
      USE_GEN2="false"
      shift
      ;;
    --region)
      GCP_REGION="$2"
      shift 2
      ;;
    --runtime)
      FUNCTION_RUNTIME="$2"
      shift 2
      ;;
    --trigger-topic)
      FUNCTION_TRIGGER="pubsub"
      PUBSUB_TOPIC="$2"
      shift 2
      ;;
    --trigger-bucket)
      FUNCTION_TRIGGER="storage"
      STORAGE_BUCKET="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --gen2              Deploy as Gen2 function (default)"
      echo "  --gen1              Deploy as Gen1 function"
      echo "  --region REGION     GCP region (default: us-central1)"
      echo "  --runtime RUNTIME   Function runtime (default: nodejs20)"
      echo "  --trigger-topic T   Use Pub/Sub trigger with topic T"
      echo "  --trigger-bucket B  Use Cloud Storage trigger with bucket B"
      echo "  --help              Show this help"
      echo ""
      echo "Environment variables:"
      echo "  FUNCTION_NAME       (required) Name of the function"
      echo "  GCP_PROJECT_ID      (required) GCP project ID"
      echo "  FUNCTION_ENTRY_POINT Entry point function name"
      echo "  FUNCTION_SOURCE      Source directory"
      echo "  FUNCTION_MEMORY      Memory allocation"
      echo "  FUNCTION_TIMEOUT     Timeout duration"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "============================================"
echo "Cloud Functions Deployment with OpenTelemetry"
echo "============================================"
echo "Function:    ${FUNCTION_NAME}"
echo "Project:     ${GCP_PROJECT_ID}"
echo "Region:      ${GCP_REGION}"
echo "Runtime:     ${FUNCTION_RUNTIME}"
echo "Gen2:        ${USE_GEN2}"
echo "Environment: ${ENVIRONMENT}"
echo "============================================"

# --- Build environment variables string ---
ENV_VARS="OTEL_SERVICE_NAME=${OTEL_SERVICE_NAME}"
ENV_VARS="${ENV_VARS},OTEL_RESOURCE_ATTRIBUTES=deployment.environment=${ENVIRONMENT},service.version=${FUNCTION_VERSION},faas.name=${FUNCTION_NAME}"
ENV_VARS="${ENV_VARS},OTEL_TRACES_SAMPLER=${OTEL_TRACES_SAMPLER}"
ENV_VARS="${ENV_VARS},OTEL_TRACES_SAMPLER_ARG=${OTEL_TRACES_SAMPLER_ARG}"
ENV_VARS="${ENV_VARS},OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL}"
ENV_VARS="${ENV_VARS},OTEL_LOG_LEVEL=${OTEL_LOG_LEVEL}"
ENV_VARS="${ENV_VARS},GCP_PROJECT_ID=${GCP_PROJECT_ID}"
ENV_VARS="${ENV_VARS},ENVIRONMENT=${ENVIRONMENT}"
ENV_VARS="${ENV_VARS},FUNCTION_VERSION=${FUNCTION_VERSION}"

# Runtime-specific OTel auto-instrumentation
case "${FUNCTION_RUNTIME}" in
  nodejs*)
    ENV_VARS="${ENV_VARS},NODE_OPTIONS=--require @opentelemetry/auto-instrumentations-node/register"
    ;;
  python*)
    ENV_VARS="${ENV_VARS},OTEL_PYTHON_DISTRO=opentelemetry-distro"
    ENV_VARS="${ENV_VARS},OTEL_PYTHON_CONFIGURATOR=opentelemetry-configurator"
    ;;
  java*)
    ENV_VARS="${ENV_VARS},JAVA_TOOL_OPTIONS=-javaagent:/workspace/opentelemetry-javaagent.jar"
    ;;
  go*)
    echo "Note: Go requires manual instrumentation. Auto-instrumentation is not available."
    ;;
esac

# --- Build gcloud command ---
CMD="gcloud functions deploy ${FUNCTION_NAME}"
CMD="${CMD} --project=${GCP_PROJECT_ID}"
CMD="${CMD} --region=${GCP_REGION}"
CMD="${CMD} --runtime=${FUNCTION_RUNTIME}"
CMD="${CMD} --entry-point=${FUNCTION_ENTRY_POINT}"
CMD="${CMD} --source=${FUNCTION_SOURCE}"
CMD="${CMD} --memory=${FUNCTION_MEMORY}"
CMD="${CMD} --timeout=${FUNCTION_TIMEOUT}"
CMD="${CMD} --max-instances=${FUNCTION_MAX_INSTANCES}"
CMD="${CMD} --min-instances=${FUNCTION_MIN_INSTANCES}"
CMD="${CMD} --set-env-vars=${ENV_VARS}"

# Gen2 flag
if [[ "${USE_GEN2}" == "true" ]]; then
  CMD="${CMD} --gen2"
fi

# Service account
if [[ -n "${FUNCTION_SERVICE_ACCOUNT}" ]]; then
  CMD="${CMD} --service-account=${FUNCTION_SERVICE_ACCOUNT}"
fi

# Trigger type
case "${FUNCTION_TRIGGER}" in
  http)
    CMD="${CMD} --trigger-http --allow-unauthenticated"
    ;;
  pubsub)
    CMD="${CMD} --trigger-topic=${PUBSUB_TOPIC}"
    ;;
  storage)
    CMD="${CMD} --trigger-resource=${STORAGE_BUCKET} --trigger-event=google.storage.object.finalize"
    ;;
esac

# --- Deploy ---
echo ""
echo "Deploying function..."
echo "Command: ${CMD}"
echo ""

eval "${CMD}"

# --- Verify deployment ---
echo ""
echo "Verifying deployment..."
gcloud functions describe "${FUNCTION_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --region="${GCP_REGION}" \
  --format="table(name, status, runtime, entryPoint, availableMemoryMb)" \
  ${USE_GEN2:+--gen2}

echo ""
echo "============================================"
echo "Deployment complete."
echo ""
echo "View traces:  https://console.cloud.google.com/traces/list?project=${GCP_PROJECT_ID}"
echo "View metrics: https://console.cloud.google.com/monitoring?project=${GCP_PROJECT_ID}"
echo "View logs:    https://console.cloud.google.com/logs?project=${GCP_PROJECT_ID}"
echo "============================================"
