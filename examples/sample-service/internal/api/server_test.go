package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/config"
)

func TestRoutes(t *testing.T) {
	cfg := config.Config{ServiceName: "sample-service", Ready: true, Addr: ":0"}
	srv := New(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))

	tests := []struct {
		path string
		code int
	}{
		{path: "/", code: http.StatusOK},
		{path: "/health", code: http.StatusOK},
		{path: "/ready", code: http.StatusOK},
		{path: "/metrics", code: http.StatusOK},
	}

	for _, tc := range tests {
		req := httptest.NewRequest(http.MethodGet, tc.path, nil)
		rec := httptest.NewRecorder()
		srv.Handler.ServeHTTP(rec, req)
		if rec.Code != tc.code {
			t.Fatalf("%s: got %d want %d", tc.path, rec.Code, tc.code)
		}
	}

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, req)
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body["service"] != "sample-service" {
		t.Fatalf("unexpected body: %v", body)
	}
}

func TestReadyFailsWhenNotReady(t *testing.T) {
	cfg := config.Config{ServiceName: "sample-service", Ready: false, Addr: ":0"}
	srv := New(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rec := httptest.NewRecorder()
	srv.Handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("got %d", rec.Code)
	}
}
