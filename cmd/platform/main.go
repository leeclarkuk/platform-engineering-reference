package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/leeclarkuk/platform-engineering-reference/internal/contract"
	"github.com/leeclarkuk/platform-engineering-reference/internal/doctor"
)

func main() {
	if len(os.Args) < 2 {
		usage(os.Stderr)
		os.Exit(2)
	}
	switch os.Args[1] {
	case "doctor":
		os.Exit(runDoctor(os.Args[2:]))
	case "validate":
		os.Exit(runValidate(os.Args[2:]))
	case "create":
		os.Exit(runCreate(os.Args[2:]))
	case "-h", "-help", "--help", "help":
		usage(os.Stdout)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		usage(os.Stderr)
		os.Exit(2)
	}
}

func usage(w *os.File) {
	fmt.Fprintf(w, `platform: local contract CLI (no cloud credentials, no AWS)

Usage:
  platform doctor
  platform validate <file>
  platform create --name NAME --owner OWNER --namespace NAMESPACE [--out-dir DIR]

doctor checks git, make and go. It does not call AWS.
validate loads YAML and checks it against the WorkloadContract JSON Schema.
create writes a WorkloadContract YAML and a Helm chart skeleton. It writes
no Terraform, GitOps, IAM, kubeconfig or secrets.
`)
}

func runDoctor(args []string) int {
	if len(args) > 0 {
		fmt.Fprintln(os.Stderr, "usage: platform doctor")
		return 2
	}
	r := doctor.Check(doctor.RequiredTools)
	doctor.Write(os.Stdout, r)
	if len(r.Missing) > 0 {
		return 1
	}
	return 0
}

func runValidate(args []string) int {
	if len(args) != 1 || args[0] == "-h" || args[0] == "--help" {
		fmt.Fprintln(os.Stderr, "usage: platform validate <file>")
		if len(args) == 1 && (args[0] == "-h" || args[0] == "--help") {
			return 0
		}
		return 2
	}
	if err := contract.File(args[0]); err != nil {
		fmt.Fprintf(os.Stderr, "validate: %v\n", err)
		return 1
	}
	fmt.Printf("ok %s\n", args[0])
	return 0
}

func runCreate(args []string) int {
	fs := flag.NewFlagSet("create", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	name := fs.String("name", "", "workload name (metadata.name and ServiceAccount name)")
	owner := fs.String("owner", "", "workload owner")
	namespace := fs.String("namespace", "", "ServiceAccount namespace (ADR-0002 contract string)")
	outDir := fs.String("out-dir", ".", "directory for the contract YAML and templates/ Helm skeleton")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if fs.NArg() != 0 {
		fmt.Fprintln(os.Stderr, "usage: platform create --name NAME --owner OWNER --namespace NAMESPACE [--out-dir DIR]")
		return 2
	}
	path, err := contract.Create(contract.CreateOptions{
		Name:      *name,
		Owner:     *owner,
		Namespace: *namespace,
		OutDir:    *outDir,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "create: %v\n", err)
		return 1
	}
	fmt.Printf("ok wrote %s and Helm skeleton under %s/templates\n", path, *outDir)
	return 0
}
