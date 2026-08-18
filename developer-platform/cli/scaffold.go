package main

import "fmt"

func scaffold(name string) map[string]string {
	return map[string]string{
		"README.md": fmt.Sprintf("# %s\n\nGolden-path Go service. Probes: `/health`, `/ready`. Metrics: `/metrics`.\n", name),
		"go.mod":    fmt.Sprintf("module github.com/example/%s\n\ngo 1.24\n", name),
		"Dockerfile": `FROM golang:1.24-bookworm AS build
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/service ./cmd/service

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/service /service
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/service"]
`,
		"cmd/service/main.go": `package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]string{"service": "` + name + `", "status": "ok"})
	})
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(` + "`{\"status\":\"ok\"}`" + `))
	})
	mux.HandleFunc("GET /ready", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(` + "`{\"status\":\"ready\"}`" + `))
	})
	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte("# placeholder metrics\n"))
	})
	addr := ":8080"
	if v := os.Getenv("ADDR"); v != "" {
		addr = v
	}
	log.Info("listening", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
`,
		"deploy/helm/Chart.yaml": fmt.Sprintf("apiVersion: v2\nname: %s\nversion: 0.1.0\nappVersion: \"0.1.0\"\n", name),
		"deploy/helm/values.yaml": fmt.Sprintf(`image:
  repository: ghcr.io/example/%s
  tag: "0.1.0"
replicaCount: 2
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
`, name),
		"docs/SLO.md": `# SLO

These numbers are a starting example, not a company standard.

- Availability: 99.9 percent of successful (non-5xx) requests on the user path
- Latency: 95 percent of user-path requests under 300ms

Edit before production. A batch job should not inherit this file unchanged.
`,
		"docs/RUNBOOK.md": fmt.Sprintf(`# Runbook: %s

## Symptoms

Users see errors or latency.

## First checks

1. Hit /ready and /metrics
2. Argo CD application health
3. Recent deploys in Git

A green control plane does not prove the user path is healthy.
`, name),
		"OWNERS.yaml": fmt.Sprintf("service: %s\nteam: unset\nslack: unset\npage: unset\n", name),
		".github/workflows/ci.yml": `name: CI
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.24.x"
      - run: go test ./...
`,
	}
}
