package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var requiredFiles = []string{
	"Dockerfile",
	"go.mod",
	"deploy/helm/Chart.yaml",
	"docs/SLO.md",
	"docs/RUNBOOK.md",
	"OWNERS.yaml",
}

func validate(args []string) error {
	provider, rest, err := parseProvider(args)
	if err != nil {
		return err
	}
	if provider == "aws" {
		if len(rest) > 0 {
			return fmt.Errorf("validate --provider aws does not take a path")
		}
		return validateAWS()
	}
	if provider != "" {
		return fmt.Errorf("validate --provider currently implements aws only")
	}
	dir := "."
	if len(rest) > 0 {
		dir = rest[0]
	}
	var missing []string
	for _, f := range requiredFiles {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			missing = append(missing, f)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("not a golden-path service; missing: %v", missing)
	}
	fmt.Printf("validate OK (%s)\n", dir)
	return nil
}

func validateAWS() error {
	root, err := findRepoRoot()
	if err != nil {
		return err
	}
	required := []string{
		"terraform/aws/bootstrap/main.tf",
		"terraform/aws/network/main.tf",
		"terraform/aws/workload/main.tf",
		"terraform/aws/network/environments/dev.tfvars",
		"terraform/aws/workload/environments/dev.tfvars",
		"gitops/bootstrap/root-app.yaml",
		"examples/sample-service/deploy/helm/sample-service/Chart.yaml",
		"docs/aws/account-model.md",
		"docs/aws/networking.md",
		"docs/aws/deployment.md",
		"docs/aws/operations.md",
	}
	var missing []string
	for _, f := range required {
		if _, err := os.Stat(filepath.Join(root, f)); err != nil {
			missing = append(missing, f)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("aws platform layout incomplete: %s", strings.Join(missing, ", "))
	}
	fmt.Printf("validate OK (aws %s)\n", root)
	return nil
}

func findRepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "terraform/aws/network/main.tf")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("not inside the platform-engineering-reference repository")
		}
		dir = parent
	}
}
