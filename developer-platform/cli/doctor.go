package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func doctor() error {
	tools := []string{"git", "go", "terraform"}
	var missing []string
	for _, t := range tools {
		if _, err := exec.LookPath(t); err != nil {
			missing = append(missing, t)
		} else {
			fmt.Printf("ok  %s\n", t)
		}
	}
	optional := []string{"helm", "kubectl", "docker"}
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
	fmt.Println("doctor OK")
	return nil
}
