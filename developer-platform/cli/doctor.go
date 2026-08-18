package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func doctor(args []string) error {
	provider, rest, err := parseProvider(args)
	if err != nil {
		return err
	}
	if len(rest) > 0 {
		return fmt.Errorf("unexpected arguments: %s", strings.Join(rest, " "))
	}

	tools := []string{"git", "go", "terraform"}
	var missing []string
	for _, t := range tools {
		if _, err := exec.LookPath(t); err != nil {
			missing = append(missing, t)
		} else {
			fmt.Printf("ok  %s\n", t)
		}
	}
	optional := []string{"helm", "kubectl", "docker", "tflint", "kubeconform"}
	if provider == "aws" {
		optional = append(optional, "aws")
	}
	for _, t := range optional {
		if _, err := exec.LookPath(t); err != nil {
			fmt.Printf("opt %s not found\n", t)
		} else {
			fmt.Printf("ok  %s\n", t)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing required tools: %s", strings.Join(missing, ", "))
	}
	if os.Getenv("AWS_SECRET_ACCESS_KEY") != "" || os.Getenv("AZURE_CLIENT_SECRET") != "" {
		fmt.Println("warn standing cloud secrets are in the environment; prefer OIDC")
	}

	if provider == "aws" {
		root, err := findRepoRoot()
		if err != nil {
			return err
		}
		for _, p := range []string{
			"terraform/aws/bootstrap/main.tf",
			"terraform/aws/network/main.tf",
			"terraform/aws/workload/main.tf",
			"docs/aws/deployment.md",
		} {
			if _, err := os.Stat(filepath.Join(root, p)); err != nil {
				return fmt.Errorf("aws layout missing %s", p)
			}
			fmt.Printf("ok  %s\n", p)
		}
	} else if provider != "" && provider != "azure" && provider != "gcp" {
		return fmt.Errorf("unknown provider %s", provider)
	}

	fmt.Println("doctor OK")
	return nil
}
