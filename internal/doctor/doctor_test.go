package doctor

import (
	"bytes"
	"strings"
	"testing"
)

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
