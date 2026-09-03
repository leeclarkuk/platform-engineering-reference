package contract

import (
	"bytes"
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

func TestValidateRejectsMissingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "does-not-exist.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected missing file to fail validation")
	}
}

func TestValidateRejectsWrongAPIVersion(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-apiversion.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected wrong apiVersion to fail validation")
	}
}

func TestValidateRejectsWrongKind(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-kind.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected wrong kind to fail validation")
	}
}

func TestValidateRejectsDNS1123Name(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-name-dns.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected metadata.name Demo to fail validation")
	}
}

func TestValidateRejectsDNS1123ServiceAccountNamespace(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-sa-namespace-dns.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected spec.serviceAccount.namespace Apps to fail validation")
	}
}

func TestValidateRejectsDNS1123ServiceAccountName(t *testing.T) {
	path := testdata(t, "workloadcontract-invalid-sa-name-dns.yaml")
	if err := File(path); err == nil {
		t.Fatal("expected spec.serviceAccount.name Demo to fail validation")
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
	dir := filepath.Join(t.TempDir(), "widget")
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

func TestCreateRejectsInvalidName(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "out")
	if _, err := Create(CreateOptions{
		Name:      "Demo",
		Owner:     "platform",
		Namespace: "apps",
		OutDir:    dir,
	}); err == nil {
		t.Fatal("expected create --name Demo to fail")
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("create must not write DIR when the name is invalid: %v", err)
	}
}

func TestCreateRejectsInvalidNamespace(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "out")
	if _, err := Create(CreateOptions{
		Name:      "widget",
		Owner:     "platform",
		Namespace: "Demo",
		OutDir:    dir,
	}); err == nil {
		t.Fatal("expected create --namespace Demo to fail")
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("create must not write DIR when the namespace is invalid: %v", err)
	}
}

func TestCreateFailsIfDirExists(t *testing.T) {
	dir := t.TempDir()
	if _, err := Create(CreateOptions{
		Name:      "widget",
		Owner:     "platform",
		Namespace: "apps",
		OutDir:    dir,
	}); err == nil {
		t.Fatal("expected create into an existing directory to fail")
	}
}

func TestCreateHelmSkeletonMatchesRepo(t *testing.T) {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	repoRoot := filepath.Join(filepath.Dir(file), "..", "..")
	outDir := filepath.Join(t.TempDir(), "sample")
	if _, err := Create(CreateOptions{
		Name:      "sample",
		Owner:     "platform",
		Namespace: "apps",
		OutDir:    outDir,
	}); err != nil {
		t.Fatalf("create: %v", err)
	}
	rels := []string{
		"Chart.yaml",
		"values.yaml",
		filepath.Join("templates", "deployment.yaml"),
		filepath.Join("templates", "service.yaml"),
		filepath.Join("templates", "serviceaccount.yaml"),
	}
	for _, rel := range rels {
		gotPath := filepath.Join(outDir, "templates", rel)
		wantPath := filepath.Join(repoRoot, "templates", rel)
		got, err := os.ReadFile(gotPath)
		if err != nil {
			t.Fatalf("read generated %s: %v", gotPath, err)
		}
		want, err := os.ReadFile(wantPath)
		if err != nil {
			t.Fatalf("read repo %s: %v", wantPath, err)
		}
		if !bytes.Equal(got, want) {
			t.Errorf("Helm skeleton drift in %s\ngenerated (%d bytes):\n%s\nrepo (%d bytes):\n%s", rel, len(got), got, len(want), want)
		}
	}
}
