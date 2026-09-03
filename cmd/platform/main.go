package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

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

doctor checks git, make and go. It does not call AWS. It succeeds with
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN and
AWS_PROFILE unset.
validate loads YAML and checks it against the WorkloadContract JSON Schema.
create writes a WorkloadContract YAML and a Helm chart skeleton into DIR.
DIR must not already exist. --name and --namespace must be RFC 1123 DNS
labels. It writes no Terraform, GitOps, IAM, kubeconfig or secrets.
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
	name := fs.String("name", "", "RFC 1123 DNS label (metadata.name and ServiceAccount name)")
	owner := fs.String("owner", "", "workload owner")
	namespace := fs.String("namespace", "", "RFC 1123 DNS label (ServiceAccount namespace; ADR-0002)")
	outDir := fs.String("out-dir", "", "output directory (must not already exist)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	dir := *outDir
	switch fs.NArg() {
	case 0:
		if dir == "" {
			dir = strings.TrimSpace(*name)
		}
	case 1:
		if dir != "" {
			fmt.Fprintln(os.Stderr, "create: pass DIR as --out-dir or as a positional argument, not both")
			return 2
		}
		dir = fs.Arg(0)
	default:
		fmt.Fprintln(os.Stderr, "usage: platform create --name NAME --owner OWNER --namespace NAMESPACE [--out-dir DIR]")
		return 2
	}
	path, err := contract.Create(contract.CreateOptions{
		Name:      *name,
		Owner:     *owner,
		Namespace: *namespace,
		OutDir:    dir,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "create: %v\n", err)
		return 1
	}
	fmt.Printf("ok wrote %s and Helm skeleton under %s/templates\n", path, dir)
	return 0
}
