package doctor

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

func unsetAWSEnv(t *testing.T) {
	t.Helper()
	for _, k := range AWSCredentialEnvVars {
		orig, had := os.LookupEnv(k)
		if err := os.Unsetenv(k); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() {
			if had {
				_ = os.Setenv(k, orig)
				return
			}
			_ = os.Unsetenv(k)
		})
	}
}

func TestCheckReportsMissingTool(t *testing.T) {
	r := Check([]string{"definitely-not-a-platform-tool"})
	if len(r.Missing) != 1 || r.Missing[0] != "definitely-not-a-platform-tool" {
		t.Fatalf("missing=%v", r.Missing)
	}
	var buf bytes.Buffer
	Write(&buf, r)
	if !strings.Contains(buf.String(), "missing: definitely-not-a-platform-tool") {
		t.Fatalf("output=%q", buf.String())
	}
}

func TestCheckFindsGo(t *testing.T) {
	r := Check([]string{"go"})
	if len(r.Missing) != 0 {
		t.Fatalf("expected go on PATH, missing=%v", r.Missing)
	}
	if len(r.Found) != 1 || r.Found[0].Name != "go" {
		t.Fatalf("found=%v", r.Found)
	}
}

func TestCheckSucceedsWithAWSEnvUnset(t *testing.T) {
	unsetAWSEnv(t)
	r := Check(RequiredTools)
	if len(r.Missing) != 0 {
		t.Fatalf("doctor must succeed with AWS env unset, missing=%v", r.Missing)
	}
	var buf bytes.Buffer
	Write(&buf, r)
	if !strings.Contains(buf.String(), "platform doctor OK (no cloud credentials used)") {
		t.Fatalf("output=%q", buf.String())
	}
}
