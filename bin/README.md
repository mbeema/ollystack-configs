# OllyStack CLI

Command-line tool for composing OpenTelemetry Collector configurations from the OllyStack fragment library.

## Installation

The CLI requires [yq v4+](https://github.com/mikefarah/yq) for YAML processing.

```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

## Commands

### `ollystack init`

Interactive wizard that walks you through platform, backend, signal, and environment selection, then generates a composed config file.

```bash
./bin/ollystack init
```

### `ollystack list [category]`

Lists all available fragments grouped by category.

```bash
./bin/ollystack list              # All categories
./bin/ollystack list receivers    # Only receivers
./bin/ollystack list processors   # Only processors
./bin/ollystack list golden       # Golden configs
```

### `ollystack merge -o output.yaml file1.yaml file2.yaml ...`

Deep-merges multiple YAML fragment files into a single config.

```bash
./bin/ollystack merge -o my-config.yaml \
  collector/base/otel-agent-base.yaml \
  collector/fragments/receivers/otlp.yaml \
  collector/fragments/processors/memory-limiter.yaml \
  collector/fragments/processors/batch.yaml \
  collector/fragments/exporters/otlp-grpc.yaml
```

### `ollystack validate <config.yaml>`

Validates YAML syntax and checks for required OTel Collector config structure.

```bash
./bin/ollystack validate my-config.yaml
```

### `ollystack golden [config-name] [output-path]`

Copies a pre-assembled golden config as a starting point.

```bash
./bin/ollystack golden aws-datadog-production.yaml my-config.yaml
```

## How It Works

The CLI uses `yq` to deep-merge YAML fragments. The OTel Collector also supports multi-file configs natively:

```bash
otelcol --config=base.yaml --config=receivers.yaml --config=processors.yaml --config=exporters.yaml
```

The `ollystack merge` command produces a single merged file, which is often easier to review, version-control, and deploy.
