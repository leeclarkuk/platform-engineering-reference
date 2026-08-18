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
		err = doctor()
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
  platform doctor
  platform create service <name> [--dir PATH] [--dry-run]
  platform validate [PATH]

The CLI does not require cloud credentials.
`)
}
