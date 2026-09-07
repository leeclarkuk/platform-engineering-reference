package main

import (
	"bytes"
	"os"
	"testing"
)

func TestDoctorCommandSourceDoesNotReadAWSEnv(t *testing.T) {
	src, err := os.ReadFile("main.go")
	if err != nil {
		t.Fatal(err)
	}
	for _, needle := range []string{"os.Getenv", "os.LookupEnv", "os.Environ", "github.com/aws"} {
		if bytes.Contains(src, []byte(needle)) {
			t.Fatalf("platform CLI must not read cloud env or call AWS; found %q", needle)
		}
	}
}

func TestCreateHelpExitsZero(t *testing.T) {
	if got := runCreate([]string{"-h"}); got != 0 {
		t.Fatalf("create -h exit=%d, want 0", got)
	}
}

func TestCreateRejectsUnexpectedArgs(t *testing.T) {
	if got := runCreate([]string{
		"--name", "widget",
		"--owner", "platform",
		"--namespace", "apps",
		"somedir",
	}); got != 2 {
		t.Fatalf("positional DIR exit=%d, want 2", got)
	}
}
