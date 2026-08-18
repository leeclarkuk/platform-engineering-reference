package main

import (
	"fmt"
	"os"
	"path/filepath"
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
	dir := "."
	if len(args) > 0 {
		dir = args[0]
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
