module github.com/example/my-go-service

go 1.23

require (
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.58.0
	go.opentelemetry.io/otel v1.33.0
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.33.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.33.0
	go.opentelemetry.io/otel/propagation v1.33.0
	go.opentelemetry.io/otel/sdk v1.33.0
	go.opentelemetry.io/otel/sdk/metric v1.33.0
	go.opentelemetry.io/otel/semconv v1.26.0
	go.opentelemetry.io/otel/trace v1.33.0
)

require (
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.58.0
	go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql v0.58.0
	go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin v0.58.0
)
