package doctor

import (
	"fmt"
	"io"
	"os/exec"
	"strings"
)

// RequiredTools are the binaries platform doctor requires. make doctor
// still checks git and make only; this list additionally requires go.
var RequiredTools = []string{"git", "make", "go"}

// AWSCredentialEnvVars are never read. platform doctor must succeed when
// they are unset and must not call AWS.
var AWSCredentialEnvVars = []string{
	"AWS_ACCESS_KEY_ID",
	"AWS_SECRET_ACCESS_KEY",
	"AWS_SESSION_TOKEN",
	"AWS_PROFILE",
}

// Result is the local-tool check outcome. It never inspects cloud
// credentials and never calls AWS.
type Result struct {
	Missing []string
	Found   []Found
}

// Found is a required tool that is present on PATH.
type Found struct {
	Name string
	Path string
}

// Check looks up each tool with exec.LookPath. It does not call AWS.
func Check(tools []string) Result {
	var r Result
	for _, t := range tools {
		path, err := exec.LookPath(t)
		if err != nil {
			r.Missing = append(r.Missing, t)
			continue
		}
		r.Found = append(r.Found, Found{Name: t, Path: path})
	}
	return r
}

// Write reports the result. Missing tools are printed as "missing: <tool>".
// Returns a non-zero suggestion: the caller should exit 1 when Missing is
// non-empty.
func Write(w io.Writer, r Result) {
	for _, f := range r.Found {
		fmt.Fprintf(w, "ok  %s (%s)\n", f.Name, f.Path)
	}
	for _, t := range r.Missing {
		fmt.Fprintf(w, "missing: %s\n", t)
	}
	if len(r.Missing) > 0 {
		fmt.Fprintf(w, "platform doctor FAIL: required local tools missing (%s)\n", strings.Join(r.Missing, ", "))
		return
	}
	fmt.Fprintln(w, "platform doctor OK (no cloud credentials used)")
}
