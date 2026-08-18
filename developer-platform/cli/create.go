package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func create(args []string) error {
	if len(args) < 2 || args[0] != "service" {
		return fmt.Errorf("usage: platform create service <name> [--dir PATH] [--dry-run]")
	}
	name := args[1]
	if err := validateServiceName(name); err != nil {
		return err
	}
	dir := name
	dryRun := false
	for i := 2; i < len(args); i++ {
		switch args[i] {
		case "--dry-run":
			dryRun = true
		case "--dir":
			if i+1 >= len(args) {
				return fmt.Errorf("--dir requires a path")
			}
			i++
			dir = args[i]
		default:
			return fmt.Errorf("unknown flag %s", args[i])
		}
	}
	files := scaffold(name)
	if dryRun {
		fmt.Printf("would create service %s in %s\n", name, dir)
		for path := range files {
			fmt.Printf("  %s\n", path)
		}
		return nil
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for path, content := range files {
		full := filepath.Join(dir, path)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			return err
		}
	}
	fmt.Printf("created service %s in %s\n", name, dir)
	return nil
}

func validateServiceName(name string) error {
	if name == "" {
		return fmt.Errorf("name is required")
	}
	for _, r := range name {
		ok := (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-'
		if !ok {
			return fmt.Errorf("name must be lowercase alphanumeric and dashes")
		}
	}
	if strings.HasPrefix(name, "-") || strings.HasSuffix(name, "-") {
		return fmt.Errorf("name cannot start or end with a dash")
	}
	return nil
}
