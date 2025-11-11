/**
 * OpenTelemetry Setup for Node.js Applications
 *
 * This file configures the OpenTelemetry NodeSDK with:
 *   - OTLP gRPC exporters for traces, metrics, and logs
 *   - Auto-instrumentation for all detected libraries
 *   - Resource attributes (service.name from env)
 *   - W3C TraceContext + Baggage propagation
 *
 * Usage:
 *   node --require ./tracing.js app.js
 *
 * Or set NODE_OPTIONS:
 *   NODE_OPTIONS="--require ./tracing.js" node app.js
 */

'use strict';

const process = require('process');

// ---------------------------------------------------------------------------
// OpenTelemetry SDK
// ---------------------------------------------------------------------------
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
  ATTR_DEPLOYMENT_ENVIRONMENT,
} = require('@opentelemetry/semantic-conventions');

// ---------------------------------------------------------------------------
// Auto-Instrumentations (meta-package that includes all supported libs)
// ---------------------------------------------------------------------------
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

// ---------------------------------------------------------------------------
// OTLP Exporters (gRPC)
// ---------------------------------------------------------------------------
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-grpc');

// ---------------------------------------------------------------------------
// Metric reader
// ---------------------------------------------------------------------------
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

// ---------------------------------------------------------------------------
// Log record processor
// ---------------------------------------------------------------------------
const { BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');

// ---------------------------------------------------------------------------
// Configuration from environment variables
// ---------------------------------------------------------------------------
const serviceName = process.env.OTEL_SERVICE_NAME || 'my-node-service';
const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317';
const environment = process.env.DEPLOYMENT_ENVIRONMENT || 'development';
const serviceVersion = process.env.SERVICE_VERSION || '1.0.0';

// ---------------------------------------------------------------------------
// Build Resource (service identity and metadata)
// ---------------------------------------------------------------------------
const resource = new Resource({
  [ATTR_SERVICE_NAME]: serviceName,
  [ATTR_SERVICE_VERSION]: serviceVersion,
  [ATTR_DEPLOYMENT_ENVIRONMENT]: environment,
});

// ---------------------------------------------------------------------------
// Configure OTLP Exporters
// ---------------------------------------------------------------------------
const traceExporter = new OTLPTraceExporter({
  url: otlpEndpoint,
});

const metricExporter = new OTLPMetricExporter({
  url: otlpEndpoint,
});

const logExporter = new OTLPLogExporter({
  url: otlpEndpoint,
});

// ---------------------------------------------------------------------------
// Configure the NodeSDK
// ---------------------------------------------------------------------------
const sdk = new NodeSDK({
  resource: resource,

  // Trace exporter
  traceExporter: traceExporter,

  // Metric reader with periodic export
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 60000, // Export metrics every 60 seconds
  }),

  // Log record processor
  logRecordProcessor: new BatchLogRecordProcessor(logExporter),

  // Auto-instrumentations for all detected libraries
  instrumentations: [
    getNodeAutoInstrumentations({
      // Fine-tune individual instrumentations if needed
      '@opentelemetry/instrumentation-fs': {
        enabled: false, // fs instrumentation can be noisy
      },
      '@opentelemetry/instrumentation-dns': {
        enabled: false, // dns instrumentation can be noisy
      },
      '@opentelemetry/instrumentation-net': {
        enabled: false, // net instrumentation can be noisy
      },
      '@opentelemetry/instrumentation-http': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-pg': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-redis': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-ioredis': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-mongodb': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-grpc': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-graphql': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-winston': {
        enabled: true, // Inject trace context into Winston logs
      },
      '@opentelemetry/instrumentation-pino': {
        enabled: true, // Inject trace context into Pino logs
      },
    }),
  ],
});

// ---------------------------------------------------------------------------
// Start the SDK
// ---------------------------------------------------------------------------
sdk.start();
console.log(`[OTel] Tracing initialized for service: ${serviceName}`);
console.log(`[OTel] Exporting to: ${otlpEndpoint}`);

// ---------------------------------------------------------------------------
// Graceful Shutdown
// ---------------------------------------------------------------------------
const shutdown = () => {
  sdk
    .shutdown()
    .then(() => {
      console.log('[OTel] SDK shut down successfully');
    })
    .catch((err) => {
      console.error('[OTel] Error shutting down SDK:', err);
    })
    .finally(() => {
      process.exit(0);
    });
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
