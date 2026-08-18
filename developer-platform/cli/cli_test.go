package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestValidateServiceName(t *testing.T) {
	if err := validateServiceName("payments-api"); err != nil {
		t.Fatal(err)
	}
	if err := validateServiceName("Payments"); err == nil {
		t.Fatal("expected error")
	}
}

func TestScaffoldHasRequiredFiles(t *testing.T) {
	files := scaffold("payments-api")
	for _, f := range requiredFiles {
		if _, ok := files[f]; !ok {
			t.Fatalf("scaffold missing %s", f)
		}
	}
}

func TestCreateDryRun(t *testing.T) {
	if err := create([]string{"service", "demo-api", "--dry-run"}); err != nil {
		t.Fatal(err)
	}
}

func TestCreateAndValidate(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "demo-api")
	if err := create([]string{"service", "demo-api", "--dir", target}); err != nil {
		t.Fatal(err)
	}
	if err := validate([]string{target}); err != nil {
		t.Fatal(err)
	}
	body, err := os.ReadFile(filepath.Join(target, "OWNERS.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(body), "demo-api") {
		t.Fatalf("owners not substituted: %s", body)
	}
}
