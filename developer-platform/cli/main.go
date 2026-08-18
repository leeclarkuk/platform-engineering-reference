package main

import (
	"fmt"
	"os"
)

var version = "dev"

func main() {
	if len(os.Args) < 2 {
		usage(os.Stderr)
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "version", "--version", "-v":
		fmt.Println(version)
	case "doctor":
		err = doctor(os.Args[2:])
	case "validate":
		err = validate(os.Args[2:])
	case "create":
		err = create(os.Args[2:])
	case "help", "--help", "-h":
		usage(os.Stdout)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		usage(os.Stderr)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func usage(w *os.File) {
	fmt.Fprint(w, `platform - golden-path CLI for this reference platform

Usage:
  platform version
  platform doctor [--provider aws]
  platform create service <name> [--dir PATH] [--dry-run]
  platform validate [PATH]
  platform validate --provider aws

The CLI does not require cloud credentials.
`)
}

func parseProvider(args []string) (provider string, rest []string, err error) {
	rest = make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--provider":
			if i+1 >= len(args) {
				return "", nil, fmt.Errorf("--provider requires a value")
			}
			i++
			provider = args[i]
		default:
			rest = append(rest, args[i])
		}
	}
	return provider, rest, nil
}
