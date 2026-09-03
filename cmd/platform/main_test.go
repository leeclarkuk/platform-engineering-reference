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
