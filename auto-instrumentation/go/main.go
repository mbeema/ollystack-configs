// =============================================================================
// OpenTelemetry Setup for Go Applications
// =============================================================================
// This example demonstrates:
//   - Configuring a TracerProvider with an OTLP gRPC exporter
//   - Configuring a MeterProvider with an OTLP gRPC exporter
//   - Setting up W3C TraceContext + Baggage propagation
//   - Creating custom spans
//   - Instrumenting HTTP server and client with otelhttp
//   - Graceful shutdown of OTel providers
// =============================================================================

package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"
)

// ---------------------------------------------------------------------------
// Global tracer for creating custom spans
// ---------------------------------------------------------------------------
var tracer trace.Tracer

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}

// ---------------------------------------------------------------------------
// initResource creates the OTel Resource that describes this service.
// ---------------------------------------------------------------------------
func initResource(ctx context.Context) (*resource.Resource, error) {
	serviceName := getEnv("OTEL_SERVICE_NAME", "my-go-service")
	serviceVersion := getEnv("SERVICE_VERSION", "1.0.0")
	environment := getEnv("DEPLOYMENT_ENVIRONMENT", "development")

	return resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String(serviceName),
			semconv.ServiceVersionKey.String(serviceVersion),
			semconv.DeploymentEnvironmentKey.String(environment),
			attribute.String("service.namespace", "default"),
		),
		resource.WithOS(),
		resource.WithProcess(),
		resource.WithTelemetrySDK(),
	)
}

// ---------------------------------------------------------------------------
// initTracerProvider sets up the TracerProvider with an OTLP gRPC exporter.
// ---------------------------------------------------------------------------
func initTracerProvider(ctx context.Context, res *resource.Resource) (*sdktrace.TracerProvider, error) {
	endpoint := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317")

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(), // Use WithTLSCredentials() in production
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter,
			sdktrace.WithBatchTimeout(5*time.Second),
			sdktrace.WithMaxExportBatchSize(512),
			sdktrace.WithMaxQueueSize(2048),
		),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.AlwaysSample())),
	)

	return tp, nil
}

// ---------------------------------------------------------------------------
// initMeterProvider sets up the MeterProvider with an OTLP gRPC exporter.
// ---------------------------------------------------------------------------
func initMeterProvider(ctx context.Context, res *resource.Resource) (*metric.MeterProvider, error) {
	endpoint := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317")

	exporter, err := otlpmetricgrpc.New(ctx,
		otlpmetricgrpc.WithEndpoint(endpoint),
		otlpmetricgrpc.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create metric exporter: %w", err)
	}

	mp := metric.NewMeterProvider(
		metric.WithReader(metric.NewPeriodicReader(exporter,
			metric.WithInterval(60*time.Second),
		)),
		metric.WithResource(res),
	)

	return mp, nil
}

// ---------------------------------------------------------------------------
// initOpenTelemetry initializes all OTel components and returns a shutdown func.
// ---------------------------------------------------------------------------
func initOpenTelemetry(ctx context.Context) (func(context.Context) error, error) {
	var shutdownFuncs []func(context.Context) error

	// Helper to aggregate shutdown functions
	shutdown := func(ctx context.Context) error {
		var err error
		for _, fn := range shutdownFuncs {
			err = errors.Join(err, fn(ctx))
		}
		return err
	}

	// 1. Create Resource
	res, err := initResource(ctx)
	if err != nil {
		return shutdown, fmt.Errorf("failed to create resource: %w", err)
	}

	// 2. Set up propagation (W3C TraceContext + Baggage)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// 3. Set up TracerProvider
	tp, err := initTracerProvider(ctx, res)
	if err != nil {
		return shutdown, err
	}
	otel.SetTracerProvider(tp)
	shutdownFuncs = append(shutdownFuncs, tp.Shutdown)

	// 4. Set up MeterProvider
	mp, err := initMeterProvider(ctx, res)
	if err != nil {
		return shutdown, err
	}
	otel.SetMeterProvider(mp)
	shutdownFuncs = append(shutdownFuncs, mp.Shutdown)

	// 5. Set global error handler
	otel.SetErrorHandler(otel.ErrorHandlerFunc(func(err error) {
		log.Printf("[OTel] error: %v", err)
	}))

	return shutdown, nil
}

// ===========================================================================
// Example HTTP Handlers
// ===========================================================================

func handleRoot(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Create a custom child span
	_, span := tracer.Start(ctx, "handleRoot.process")
	defer span.End()

	span.SetAttributes(
		attribute.String("handler", "root"),
		attribute.String("method", r.Method),
	)

	span.AddEvent("processing_request", trace.WithAttributes(
		attribute.String("path", r.URL.Path),
	))

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"message": "Hello from Go with OpenTelemetry!"}`)
}

func handleOrder(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	orderID := r.PathValue("id")

	// Create a span for the order processing
	ctx, span := tracer.Start(ctx, "processOrder",
		trace.WithAttributes(
			attribute.String("order.id", orderID),
		),
	)
	defer span.End()

	// Simulate some work
	if err := processOrder(ctx, orderID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	span.SetStatus(codes.Ok, "order processed successfully")
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"order_id": "%s", "status": "processed"}`, orderID)
}

func processOrder(ctx context.Context, orderID string) error {
	// Create a child span for a sub-operation
	_, span := tracer.Start(ctx, "validateOrder")
	defer span.End()

	span.SetAttributes(attribute.String("order.id", orderID))

	// Simulate validation work
	time.Sleep(50 * time.Millisecond)

	span.AddEvent("order_validated")
	return nil
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status": "healthy"}`)
}

// ===========================================================================
// Main
// ===========================================================================

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize OpenTelemetry
	shutdownOtel, err := initOpenTelemetry(ctx)
	if err != nil {
		log.Fatalf("Failed to initialize OpenTelemetry: %v", err)
	}
	defer func() {
		// Give 10 seconds for shutdown to flush pending telemetry
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		if err := shutdownOtel(shutdownCtx); err != nil {
			log.Printf("Error shutting down OpenTelemetry: %v", err)
		}
		log.Println("OpenTelemetry shut down successfully")
	}()

	// Create a tracer for this package
	tracer = otel.Tracer("main")

	// Set up HTTP routes
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", handleRoot)
	mux.HandleFunc("GET /orders/{id}", handleOrder)
	mux.HandleFunc("GET /health", handleHealth)

	// Wrap with otelhttp for automatic HTTP instrumentation
	handler := otelhttp.NewHandler(mux, "server",
		otelhttp.WithMessageEvents(otelhttp.ReadEvents, otelhttp.WriteEvents),
	)

	// Create server
	server := &http.Server{
		Addr:         ":8080",
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("Server starting on %s", server.Addr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// Wait for interrupt signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	log.Println("Shutting down server...")

	// Graceful shutdown with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	log.Println("Server stopped")
}
