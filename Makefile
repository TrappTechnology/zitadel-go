# Pinned tool versions – these must match the versions used by the existing
# generated code so that re-generation produces identical output.
# NOTE: BUF_VERSION must stay in sync with .github/workflows/update-zitadel.yml
BUF_VERSION                := 1.45.0
PROTOC_GEN_GO_VERSION      := 1.31.0
PROTOC_GEN_GO_GRPC_VERSION := 1.3.0

# The ZITADEL tag to generate against.  Override on the command line:
#   make generate TAG=v4.12.0
TAG ?=

.PHONY: generate
generate:
ifeq ($(strip $(TAG)),)
	$(error TAG is required – usage: make generate TAG=v4.11.0)
endif
	@command -v buf >/dev/null 2>&1 || { echo "Error: buf is not installed. Install it from https://buf.build/docs/installation/ (expected v$(BUF_VERSION))"; exit 1; }
	@INSTALLED_BUF_VERSION=$$(buf --version 2>&1); \
	if [ "$$INSTALLED_BUF_VERSION" != "$(BUF_VERSION)" ]; then \
		echo "Error: buf version mismatch: installed $$INSTALLED_BUF_VERSION, expected $(BUF_VERSION)"; \
		exit 1; \
	fi
	@set -e; \
	_TMPDIR=$$(mktemp -d); \
	trap 'rm -rf "$$_TMPDIR"' EXIT; \
	echo "Installing protoc-gen-go v$(PROTOC_GEN_GO_VERSION) and protoc-gen-go-grpc v$(PROTOC_GEN_GO_GRPC_VERSION)..."; \
	GOBIN="$$_TMPDIR/bin" go install "google.golang.org/protobuf/cmd/protoc-gen-go@v$(PROTOC_GEN_GO_VERSION)"; \
	GOBIN="$$_TMPDIR/bin" go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@v$(PROTOC_GEN_GO_GRPC_VERSION)"; \
	export PATH="$$_TMPDIR/bin:$$PATH"; \
	echo "Cloning zitadel/zitadel at tag $(TAG)..."; \
	git clone --depth 1 -b "$(TAG)" https://github.com/zitadel/zitadel "$$_TMPDIR/zitadel"; \
	echo "Cleaning old generated files..."; \
	find pkg/client/zitadel -name '*.pb.go' -delete 2>/dev/null || true; \
	echo "Generating Go client code..."; \
	buf generate "$$_TMPDIR/zitadel/proto" --template buf.gen.yaml; \
	rm -rf pkg/client/zitadel/resources pkg/client/zitadel/settings/object; \
	echo "Done."

.PHONY: build
build:
	go build ./pkg/...

.PHONY: test
test:
	go test ./...

.PHONY: lint
lint:
	golangci-lint run --fix
