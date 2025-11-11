// =============================================================================
// OpenTelemetry Programmatic Setup for .NET Applications
// =============================================================================
// Add this configuration to your Program.cs (or Startup.cs for older patterns).
//
// Required NuGet packages:
//   dotnet add package OpenTelemetry
//   dotnet add package OpenTelemetry.Extensions.Hosting
//   dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
//   dotnet add package OpenTelemetry.Instrumentation.AspNetCore
//   dotnet add package OpenTelemetry.Instrumentation.Http
//   dotnet add package OpenTelemetry.Instrumentation.SqlClient
//   dotnet add package OpenTelemetry.Instrumentation.EntityFrameworkCore
//   dotnet add package OpenTelemetry.Instrumentation.GrpcNetClient
//   dotnet add package OpenTelemetry.Instrumentation.StackExchangeRedis
//   dotnet add package OpenTelemetry.Instrumentation.Runtime
//   dotnet add package OpenTelemetry.Instrumentation.Process
// =============================================================================

using System.Diagnostics;
using OpenTelemetry;
using OpenTelemetry.Exporter;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

// ---------------------------------------------------------------------------
// Application-level ActivitySource for creating custom spans
// ---------------------------------------------------------------------------
public static class Telemetry
{
    public static readonly string ServiceName =
        Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME") ?? "my-dotnet-service";

    public static readonly string ServiceVersion =
        Environment.GetEnvironmentVariable("SERVICE_VERSION") ?? "1.0.0";

    public static readonly string Environment =
        System.Environment.GetEnvironmentVariable("DEPLOYMENT_ENVIRONMENT") ?? "development";

    // ActivitySource is the .NET equivalent of an OTel Tracer
    public static readonly ActivitySource ActivitySource = new(ServiceName, ServiceVersion);
}

// ---------------------------------------------------------------------------
// Program.cs -- Minimal API pattern (.NET 8+)
// ---------------------------------------------------------------------------
var builder = WebApplication.CreateBuilder(args);

// Read OTLP endpoint from environment
var otlpEndpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]
    ?? "http://localhost:4317";

// =========================================================================
// Configure OpenTelemetry
// =========================================================================
builder.Services.AddOpenTelemetry()
    // -----------------------------------------------------------------
    // Resource: identifies this service in your observability backend
    // -----------------------------------------------------------------
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: Telemetry.ServiceName,
            serviceVersion: Telemetry.ServiceVersion,
            serviceInstanceId: System.Environment.MachineName)
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = Telemetry.Environment,
            ["service.namespace"] = "default",
            ["telemetry.sdk.language"] = "dotnet",
        }))

    // -----------------------------------------------------------------
    // Traces
    // -----------------------------------------------------------------
    .WithTracing(tracing =>
    {
        tracing
            // Register the application's ActivitySource
            .AddSource(Telemetry.ServiceName)

            // ASP.NET Core incoming HTTP requests
            .AddAspNetCoreInstrumentation(options =>
            {
                // Filter out health check endpoints from traces
                options.Filter = (httpContext) =>
                    !httpContext.Request.Path.StartsWithSegments("/health")
                    && !httpContext.Request.Path.StartsWithSegments("/ready");

                // Enrich spans with additional request data
                options.EnrichWithHttpRequest = (activity, request) =>
                {
                    activity.SetTag("http.request.header.x-request-id",
                        request.Headers["X-Request-Id"].FirstOrDefault());
                };
            })

            // Outgoing HTTP requests via HttpClient
            .AddHttpClientInstrumentation(options =>
            {
                // Enrich with response status
                options.EnrichWithHttpResponseMessage = (activity, response) =>
                {
                    activity.SetTag("http.response.content_length",
                        response.Content.Headers.ContentLength);
                };
            })

            // SQL Server queries
            .AddSqlClientInstrumentation(options =>
            {
                options.SetDbStatementForText = true;  // Capture SQL statements
                options.RecordException = true;
            })

            // Entity Framework Core
            .AddEntityFrameworkCoreInstrumentation(options =>
            {
                options.SetDbStatementForText = true;
            })

            // gRPC client calls
            .AddGrpcClientInstrumentation()

            // OTLP exporter
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(otlpEndpoint);
                options.Protocol = OtlpExportProtocol.Grpc;
            });

        // Optionally add console exporter for development
        if (builder.Environment.IsDevelopment())
        {
            tracing.AddConsoleExporter();
        }
    })

    // -----------------------------------------------------------------
    // Metrics
    // -----------------------------------------------------------------
    .WithMetrics(metrics =>
    {
        metrics
            // ASP.NET Core HTTP metrics
            .AddAspNetCoreInstrumentation()

            // HttpClient metrics
            .AddHttpClientInstrumentation()

            // .NET Runtime metrics (GC, thread pool, etc.)
            .AddRuntimeInstrumentation()

            // Process metrics (CPU, memory)
            .AddProcessInstrumentation()

            // Register custom meters
            .AddMeter(Telemetry.ServiceName)

            // OTLP exporter
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(otlpEndpoint);
                options.Protocol = OtlpExportProtocol.Grpc;
            });
    });

// -----------------------------------------------------------------
// Logging -- send ILogger output to OTel
// -----------------------------------------------------------------
builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
    logging.ParseStateValues = true;

    logging.AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri(otlpEndpoint);
        options.Protocol = OtlpExportProtocol.Grpc;
    });
});

// =========================================================================
// Build and configure the app
// =========================================================================
var app = builder.Build();

// Health endpoint (excluded from tracing above)
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

// Example endpoint showing custom span creation
app.MapGet("/orders/{id}", async (string id) =>
{
    // Create a custom span
    using var activity = Telemetry.ActivitySource.StartActivity("GetOrder");
    activity?.SetTag("order.id", id);

    // Simulate work
    await Task.Delay(100);

    activity?.AddEvent(new ActivityEvent("OrderRetrieved",
        tags: new ActivityTagsCollection { { "order.status", "completed" } }));

    return Results.Ok(new { orderId = id, status = "completed" });
});

app.Run();
