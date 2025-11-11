"""
OpenTelemetry Programmatic Setup for Python Applications.

This module configures the TracerProvider, MeterProvider, and LoggerProvider
with OTLP exporters and sets up auto-instrumentation for detected libraries.

Usage:
    # In your application entry point (e.g., app.py):
    from tracing import configure_opentelemetry

    configure_opentelemetry()

    # Or with a Flask/Django app:
    configure_opentelemetry(flask_app=app)
"""

import os
import logging

# ---------------------------------------------------------------------------
# OpenTelemetry API and SDK
# ---------------------------------------------------------------------------
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource, SERVICE_NAME
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor

# ---------------------------------------------------------------------------
# OTLP Exporters
# ---------------------------------------------------------------------------
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

# ---------------------------------------------------------------------------
# Propagation
# ---------------------------------------------------------------------------
from opentelemetry.propagate import set_global_textmap
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.trace.propagation import TraceContextTextMapPropagator
from opentelemetry.baggage.propagation import W3CBaggagePropagator

# ---------------------------------------------------------------------------
# Auto-Instrumentation
# ---------------------------------------------------------------------------
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.urllib3 import URLLib3Instrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor

logger = logging.getLogger(__name__)


def configure_opentelemetry(
    flask_app=None,
    django=False,
    service_name: str = None,
    otlp_endpoint: str = None,
    environment: str = None,
    service_version: str = None,
):
    """
    Configure OpenTelemetry with OTLP exporters and auto-instrumentation.

    Args:
        flask_app: Optional Flask app instance to instrument.
        django: If True, instrument Django.
        service_name: Override for OTEL_SERVICE_NAME env var.
        otlp_endpoint: Override for OTEL_EXPORTER_OTLP_ENDPOINT env var.
        environment: Override for deployment.environment resource attribute.
        service_version: Override for service.version resource attribute.
    """

    # -----------------------------------------------------------------------
    # 1. Build the Resource (service identity and metadata)
    # -----------------------------------------------------------------------
    _service_name = service_name or os.environ.get("OTEL_SERVICE_NAME", "my-python-service")
    _otlp_endpoint = otlp_endpoint or os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
    _environment = environment or os.environ.get("DEPLOYMENT_ENVIRONMENT", "development")
    _service_version = service_version or os.environ.get("SERVICE_VERSION", "0.1.0")

    resource = Resource.create(
        {
            SERVICE_NAME: _service_name,
            "deployment.environment": _environment,
            "service.version": _service_version,
            "telemetry.sdk.language": "python",
        }
    )

    logger.info(
        "Configuring OpenTelemetry: service=%s endpoint=%s env=%s",
        _service_name,
        _otlp_endpoint,
        _environment,
    )

    # -----------------------------------------------------------------------
    # 2. Configure TracerProvider with OTLP exporter
    # -----------------------------------------------------------------------
    trace_exporter = OTLPSpanExporter(endpoint=_otlp_endpoint, insecure=True)
    span_processor = BatchSpanProcessor(trace_exporter)

    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(span_processor)
    trace.set_tracer_provider(tracer_provider)

    # -----------------------------------------------------------------------
    # 3. Configure MeterProvider with OTLP exporter
    # -----------------------------------------------------------------------
    metric_exporter = OTLPMetricExporter(endpoint=_otlp_endpoint, insecure=True)
    metric_reader = PeriodicExportingMetricReader(
        metric_exporter,
        export_interval_millis=60000,
    )

    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)

    # -----------------------------------------------------------------------
    # 4. Configure LoggerProvider with OTLP exporter
    # -----------------------------------------------------------------------
    log_exporter = OTLPLogExporter(endpoint=_otlp_endpoint, insecure=True)
    log_processor = BatchLogRecordProcessor(log_exporter)

    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(log_processor)

    # Attach OTel log handler to Python's root logger
    otel_handler = LoggingHandler(
        level=logging.NOTSET,
        logger_provider=logger_provider,
    )
    logging.getLogger().addHandler(otel_handler)

    # -----------------------------------------------------------------------
    # 5. Configure Propagation
    # -----------------------------------------------------------------------
    set_global_textmap(
        CompositePropagator(
            [
                TraceContextTextMapPropagator(),
                W3CBaggagePropagator(),
            ]
        )
    )

    # -----------------------------------------------------------------------
    # 6. Auto-Instrument Libraries
    # -----------------------------------------------------------------------

    # HTTP clients
    RequestsInstrumentor().instrument()
    URLLib3Instrumentor().instrument()

    # Logging -- injects trace_id and span_id into log records
    LoggingInstrumentor().instrument(set_logging_format=True)

    # Flask (if provided)
    if flask_app is not None:
        try:
            from opentelemetry.instrumentation.flask import FlaskInstrumentor

            FlaskInstrumentor().instrument_app(flask_app)
            logger.info("Flask instrumentation enabled")
        except ImportError:
            logger.warning("Flask instrumentation package not installed")

    # Django
    if django:
        try:
            from opentelemetry.instrumentation.django import DjangoInstrumentor

            DjangoInstrumentor().instrument()
            logger.info("Django instrumentation enabled")
        except ImportError:
            logger.warning("Django instrumentation package not installed")

    # SQLAlchemy
    try:
        from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

        SQLAlchemyInstrumentor().instrument()
        logger.info("SQLAlchemy instrumentation enabled")
    except ImportError:
        pass

    # psycopg2
    try:
        from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

        Psycopg2Instrumentor().instrument()
        logger.info("psycopg2 instrumentation enabled")
    except ImportError:
        pass

    # Redis
    try:
        from opentelemetry.instrumentation.redis import RedisInstrumentor

        RedisInstrumentor().instrument()
        logger.info("Redis instrumentation enabled")
    except ImportError:
        pass

    # Celery
    try:
        from opentelemetry.instrumentation.celery import CeleryInstrumentor

        CeleryInstrumentor().instrument()
        logger.info("Celery instrumentation enabled")
    except ImportError:
        pass

    # gRPC
    try:
        from opentelemetry.instrumentation.grpc import (
            GrpcInstrumentorClient,
            GrpcInstrumentorServer,
        )

        GrpcInstrumentorClient().instrument()
        GrpcInstrumentorServer().instrument()
        logger.info("gRPC instrumentation enabled")
    except ImportError:
        pass

    logger.info("OpenTelemetry configured successfully")

    return tracer_provider


def shutdown():
    """
    Gracefully shut down all OTel providers, flushing pending telemetry.
    Call this during application shutdown (e.g., atexit or signal handler).
    """
    provider = trace.get_tracer_provider()
    if hasattr(provider, "shutdown"):
        provider.shutdown()

    meter_provider = metrics.get_meter_provider()
    if hasattr(meter_provider, "shutdown"):
        meter_provider.shutdown()

    logger.info("OpenTelemetry shut down")


# ---------------------------------------------------------------------------
# Convenience: If this file is imported, provide a module-level tracer
# ---------------------------------------------------------------------------
def get_tracer(name: str = __name__):
    """Get a tracer instance for creating custom spans."""
    return trace.get_tracer(name)


# ---------------------------------------------------------------------------
# Example usage
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import atexit

    configure_opentelemetry(service_name="example-service")
    atexit.register(shutdown)

    # Create a custom span
    tracer = get_tracer("example")
    with tracer.start_as_current_span("example-operation") as span:
        span.set_attribute("example.key", "value")
        span.add_event("doing-work")
        print("Hello from a traced operation!")
