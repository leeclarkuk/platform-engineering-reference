package contract

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func testdata(t *testing.T, name string) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	return filepath.Join(filepath.Dir(file), "..", "..", "testdata", name)
}

func TestValidateAcceptsValidFixture(t *testing.T) {
	path := testdata(t, "workloadcontract-valid.yaml")
	if err := File(path); err != nil {
		t.Fatalf("valid fixture rejected: %v", err)
	}
}

func TestValidateRejectsMissingOwner(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-missing-owner.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected missing owner to fail validation")
	}
}

func TestValidateRejectsGoldenPathKustomize(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-goldenpath-kustomize.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected goldenPath kustomize to fail validation")
	}
}

func TestValidateRejectsMissingName(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "missing-name.yaml")
	body := []byte(`apiVersion: platform.engineering.reference/v1alpha1
kind: WorkloadContract
metadata: {}
spec:
  owner: platform
  goldenPath: helm
  serviceAccount:
    namespace: apps
    name: sample
`)
	if err := os.WriteFile(path, body, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := File(path); err == nil {
		t.Fatal("expected missing metadata.name to fail validation")
	}
}

func TestValidateRejectsAWSField(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "aws-field.yaml")
	body := []byte(`apiVersion: platform.engineering.reference/v1alpha1
kind: WorkloadContract
metadata:
  name: sample
spec:
  owner: platform
  goldenPath: helm
  serviceAccount:
    namespace: apps
    name: sample
  awsAccountId: "123456789012"
`)
	if err := os.WriteFile(path, body, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := File(path); err == nil {
		t.Fatal("expected extra AWS field to fail validation")
	}
}

func TestCreateThenValidate(t *testing.T) {
	dir := t.TempDir()
	contractPath, err := Create(CreateOptions{
		Name:      "widget",
		Owner:     "platform",
		Namespace: "apps",
		OutDir:    dir,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := File(contractPath); err != nil {
		t.Fatalf("created contract failed validate: %v", err)
	}
	required := []string{
		filepath.Join(dir, "templates", "Chart.yaml"),
		filepath.Join(dir, "templates", "values.yaml"),
		filepath.Join(dir, "templates", "templates", "deployment.yaml"),
		filepath.Join(dir, "templates", "templates", "service.yaml"),
		filepath.Join(dir, "templates", "templates", "serviceaccount.yaml"),
	}
	for _, p := range required {
		if _, err := os.Stat(p); err != nil {
			t.Fatalf("missing helm skeleton file %s: %v", p, err)
		}
	}
	values, err := os.ReadFile(filepath.Join(dir, "templates", "values.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(values), "name: widget") || !strings.Contains(string(values), "namespace: apps") {
		t.Fatalf("values.yaml missing contract strings:\n%s", values)
	}
}

func TestCreateRequiresFlags(t *testing.T) {
	if _, err := Create(CreateOptions{Name: "x", Owner: "y"}); err == nil {
		t.Fatal("expected create without namespace to fail")
	}
}
