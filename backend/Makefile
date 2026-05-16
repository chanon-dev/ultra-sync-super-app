.PHONY: proto test lint tidy

# Generate Go + Dart stubs from all .proto files.
# Requires: buf CLI  ->  https://buf.build/docs/installation
proto:
	cd proto && buf dep update && buf generate
	@echo "Go stubs  -> backend/proto/gen/go/"
	@echo "Dart stubs -> backend/proto/gen/dart/  (copy to mobile/lib/gen/ as needed)"

# Run unit tests for every service.
test:
	@for svc in services/auth services/wallet services/logistics; do \
		echo "==> $$svc"; \
		(cd $$svc && go test ./...); \
	done

# Lint all services and the gateway.
lint:
	@for svc in services/auth services/wallet services/logistics api-gateway; do \
		echo "==> $$svc"; \
		(cd $$svc && golangci-lint run ./...); \
	done

# Tidy go.mod / go.sum for every module (run after adding deps).
tidy:
	@for svc in services/auth services/wallet services/logistics api-gateway pkg; do \
		echo "==> $$svc"; \
		(cd $$svc && go mod tidy); \
	done
