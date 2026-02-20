.PHONY: validate lint dev-up dev-down generate-telemetry build clean help

COLLECTOR_BINARY ?= otelcol
YAMLLINT_CONFIG ?= .yamllint.yml
DOCKER_COMPOSE := docker compose -f dev/docker-compose.yml

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: ## Validate all collector YAML configs
	@echo "==> Validating collector configs..."
	@./scripts/validate-configs.sh

lint: ## YAML lint all config files
	@echo "==> Linting YAML files..."
	@find . -name '*.yaml' -o -name '*.yml' | grep -v node_modules | grep -v .git | \
		xargs yamllint -c $(YAMLLINT_CONFIG) || true

build: ## Build custom collector using OCB
	@echo "==> Building custom collector..."
	@cd collector/builder && ocb --config manifest.yaml

dev-up: ## Start local dev stack (Collector + Jaeger + Prometheus + Grafana)
	@echo "==> Starting dev stack..."
	$(DOCKER_COMPOSE) up -d
	@echo "==> Dev stack is running"
	@echo "    Jaeger UI:     http://localhost:16686"
	@echo "    Prometheus:    http://localhost:9090"
	@echo "    Grafana:       http://localhost:3000"
	@echo "    OTel Collector: grpc://localhost:4317 http://localhost:4318"
	@echo "    Health check:  http://localhost:13133"

dev-down: ## Tear down dev stack
	@echo "==> Stopping dev stack..."
	$(DOCKER_COMPOSE) down -v

dev-restart: ## Restart dev stack
	$(DOCKER_COMPOSE) restart

dev-logs: ## Follow dev stack logs
	$(DOCKER_COMPOSE) logs -f

generate-telemetry: ## Generate sample telemetry for testing
	@echo "==> Generating sample telemetry..."
	@docker run --rm --network host \
		ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
		traces --otlp-insecure --traces 10 --otlp-endpoint localhost:4317
	@docker run --rm --network host \
		ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
		metrics --otlp-insecure --metrics 10 --otlp-endpoint localhost:4317
	@docker run --rm --network host \
		ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
		logs --otlp-insecure --logs 10 --otlp-endpoint localhost:4317
	@echo "==> Telemetry generated"

merge: ## Merge config fragments (usage: make merge FILES="base.yaml fragment1.yaml fragment2.yaml")
	@./scripts/merge-configs.sh $(FILES)

clean: ## Clean generated files
	@rm -rf build/ tmp/ merged-*.yaml
