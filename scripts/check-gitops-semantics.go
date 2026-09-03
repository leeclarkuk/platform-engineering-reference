// Field-level GitOps semantic gate for Milestone 3.
// Parses YAML documents. Does not apply manifests or call a cluster.
package main

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	repoURL     = "https://github.com/leeclarkuk/platform-engineering-reference"
	inCluster   = "https://kubernetes.default.svc"
	nsArgocd    = "argocd"
	nsApps      = "apps"
	revMain     = "main"
	pathApps    = "gitops/apps"
	pathTpl     = "templates"
	rootAppName = "gitops-root"
	projBoot    = "bootstrap"
	projPlat    = "platform"
)

var requiredFixtures = []string{
	"privilege-inversion",
	"bootstrap-destination-apps",
	"targetrevision-not-main",
	"repourl-not-this-repo",
	"destination-namespace-wildcard",
	"destination-unlisted-ns",
	"sourcerepos-wildcard",
	"autosync-root",
	"source-path-templates",
	"iam-under-gitops",
	"terraform-under-gitops",
}

type object struct {
	APIVersion string
	Kind       string
	Name       string
	Namespace  string
	Raw        map[string]any
	Source     string
}

func main() {
	root, err := os.Getwd()
	if err != nil {
		fail("working directory: %v", err)
	}
	live := filepath.Join(root, "gitops")
	if err := checkTree(live, true); err != nil {
		fail("live gitops/: %v", err)
	}
	fmt.Println("ok live gitops/ semantic checks")

	fixRoot := filepath.Join(root, "testdata", "gitops-boundaries")
	seen := map[string]bool{}
	entries, err := os.ReadDir(fixRoot)
	if err != nil {
		fail("read fixtures: %v", err)
	}
	for _, ent := range entries {
		if !ent.IsDir() {
			continue
		}
		seen[ent.Name()] = true
		path := filepath.Join(fixRoot, ent.Name())
		err := checkTree(path, false)
		if err == nil {
			fail("fixture %s: wanted non-zero, got pass", ent.Name())
		}
		fmt.Printf("ok fixture %s failed as required: %v\n", ent.Name(), err)
	}
	for _, name := range requiredFixtures {
		if !seen[name] {
			fail("missing required fixture directory %s", name)
		}
	}
	fmt.Println("ok gitops semantic fixtures (all required negatives failed)")
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "FAIL check-gitops-semantics: "+format+"\n", args...)
	os.Exit(1)
}

func checkTree(dir string, live bool) error {
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		return fmt.Errorf("missing directory %s", dir)
	}
	var tfHits []string
	var objs []object
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(dir, path)
		name := d.Name()
		lower := strings.ToLower(name)
		switch {
		case strings.HasSuffix(lower, ".tf"), strings.HasSuffix(lower, ".tf.json"), strings.HasSuffix(lower, ".tfvars"):
			tfHits = append(tfHits, rel)
			return nil
		case strings.HasSuffix(lower, ".yaml"), strings.HasSuffix(lower, ".yml"):
			docs, err := loadYAML(path)
			if err != nil {
				return fmt.Errorf("%s: %w", rel, err)
			}
			objs = append(objs, docs...)
		}
		return nil
	})
	if err != nil {
		return err
	}
	if len(tfHits) > 0 {
		return fmt.Errorf("terraform under gitops (%s)", strings.Join(tfHits, ", "))
	}

	var apps []object
	var projects []object
	bootCount := 0
	platCount := 0
	var boot, plat, rootApp *object

	for i := range objs {
		o := &objs[i]
		if isIAM(o) {
			return fmt.Errorf("IAM object under gitops: %s %s/%s in %s", o.APIVersion, o.Kind, o.Name, o.Source)
		}
		switch o.Kind {
		case "Kustomization":
			continue
		case "Application":
			apps = append(apps, *o)
		case "AppProject":
			projects = append(projects, *o)
			switch o.Name {
			case projBoot:
				bootCount++
				boot = o
			case projPlat:
				platCount++
				plat = o
			}
		}
		if err := rejectWildcards(o); err != nil {
			return err
		}
	}

	if bootCount != 1 || boot == nil {
		return fmt.Errorf("want exactly one AppProject named bootstrap, got %d", bootCount)
	}
	if platCount != 1 || plat == nil {
		return fmt.Errorf("want exactly one AppProject named platform, got %d", platCount)
	}
	if err := checkProject(boot, projBoot, nsArgocd, nsApps); err != nil {
		return err
	}
	if err := checkProject(plat, projPlat, nsApps, nsArgocd); err != nil {
		return err
	}

	var bootApps []object
	var platApps []object
	for i := range apps {
		a := apps[i]
		proj := mapString(mapOf(a.Raw["spec"]), "project")
		path := sourcePath(a)
		if path == pathTpl || strings.HasPrefix(path, pathTpl+"/") {
			return fmt.Errorf("Application %s source path %q is forbidden", a.Name, path)
		}
		destNS := destNamespace(a)
		if destNS != nsArgocd && destNS != nsApps {
			return fmt.Errorf("Application %s destination namespace %q is unlisted", a.Name, destNS)
		}
		switch proj {
		case projBoot:
			bootApps = append(bootApps, a)
		case projPlat:
			platApps = append(platApps, a)
			if destNS == nsArgocd {
				return fmt.Errorf("privilege inversion: Application %s uses project platform to destination argocd", a.Name)
			}
		default:
			return fmt.Errorf("Application %s uses unknown project %q", a.Name, proj)
		}
		if a.Name == rootAppName {
			cp := a
			rootApp = &cp
		}
	}

	if len(bootApps) != 1 {
		return fmt.Errorf("bootstrap project must be used only by Application gitops-root (found %d)", len(bootApps))
	}
	if bootApps[0].Name != rootAppName {
		return fmt.Errorf("bootstrap project used by Application %s, want gitops-root", bootApps[0].Name)
	}
	if rootApp == nil {
		return fmt.Errorf("missing Application gitops-root")
	}
	if err := checkRootApp(*rootApp); err != nil {
		return err
	}
	if len(platApps) != 0 {
		return fmt.Errorf("no Milestone 3 Application may use project platform (found %d, including %s)", len(platApps), platApps[0].Name)
	}
	_ = live
	return nil
}

func checkRootApp(o object) error {
	if o.Name != rootAppName {
		return fmt.Errorf("root Application name %q, want %s", o.Name, rootAppName)
	}
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return fmt.Errorf("gitops-root missing spec")
	}
	if mapString(spec, "project") != projBoot {
		return fmt.Errorf("gitops-root project %q, want %s", mapString(spec, "project"), projBoot)
	}
	src := mapOf(spec["source"])
	if mapString(src, "repoURL") != repoURL {
		return fmt.Errorf("gitops-root repoURL %q, want %s", mapString(src, "repoURL"), repoURL)
	}
	if mapString(src, "targetRevision") != revMain {
		return fmt.Errorf("gitops-root targetRevision %q, want %s", mapString(src, "targetRevision"), revMain)
	}
	if mapString(src, "path") != pathApps {
		return fmt.Errorf("gitops-root path %q, want %s", mapString(src, "path"), pathApps)
	}
	dest := mapOf(spec["destination"])
	if mapString(dest, "server") != inCluster {
		return fmt.Errorf("gitops-root destination.server %q, want %s", mapString(dest, "server"), inCluster)
	}
	if mapString(dest, "namespace") != nsArgocd {
		return fmt.Errorf("gitops-root destination.namespace %q, want %s", mapString(dest, "namespace"), nsArgocd)
	}
	if _, ok := spec["syncPolicy"]; ok {
		return fmt.Errorf("gitops-root must omit spec.syncPolicy (no automated, prune, or selfHeal)")
	}
	return nil
}

func checkProject(o *object, name, allowNS, forbidNS string) error {
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return fmt.Errorf("AppProject %s missing spec", name)
	}
	repos := stringSlice(spec["sourceRepos"])
	if len(repos) != 1 || repos[0] != repoURL {
		return fmt.Errorf("AppProject %s sourceRepos %v, want exactly [%s]", name, repos, repoURL)
	}
	dests, err := destList(spec["destinations"])
	if err != nil {
		return fmt.Errorf("AppProject %s: %w", name, err)
	}
	if len(dests) != 1 {
		return fmt.Errorf("AppProject %s want exactly one destination, got %d", name, len(dests))
	}
	if dests[0].server != inCluster {
		return fmt.Errorf("AppProject %s destination.server %q, want %s", name, dests[0].server, inCluster)
	}
	if dests[0].namespace != allowNS {
		return fmt.Errorf("AppProject %s destination.namespace %q, want %s", name, dests[0].namespace, allowNS)
	}
	if dests[0].namespace == forbidNS {
		return fmt.Errorf("AppProject %s must not destination %s", name, forbidNS)
	}
	return nil
}

type destRef struct {
	server    string
	namespace string
}

func destList(v any) ([]destRef, error) {
	items, ok := v.([]any)
	if !ok {
		return nil, fmt.Errorf("destinations must be a sequence")
	}
	var out []destRef
	for _, item := range items {
		m := mapOf(item)
		d := destRef{
			server:    mapString(m, "server"),
			namespace: mapString(m, "namespace"),
		}
		if d.namespace != nsArgocd && d.namespace != nsApps {
			if d.namespace == "*" || strings.Contains(d.namespace, "*") {
				return nil, fmt.Errorf("wildcard destination namespace %q", d.namespace)
			}
			return nil, fmt.Errorf("unlisted destination namespace %q", d.namespace)
		}
		out = append(out, d)
	}
	return out, nil
}

func rejectWildcards(o *object) error {
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return nil
	}
	for _, repo := range stringSlice(spec["sourceRepos"]) {
		if strings.Contains(repo, "*") {
			return fmt.Errorf("%s/%s sourceRepos contains wildcard %q", o.Kind, o.Name, repo)
		}
	}
	if dests, ok := spec["destinations"].([]any); ok {
		for _, d := range dests {
			m := mapOf(d)
			if strings.Contains(mapString(m, "namespace"), "*") || strings.Contains(mapString(m, "server"), "*") {
				return fmt.Errorf("%s/%s destinations contain a wildcard", o.Kind, o.Name)
			}
		}
	}
	dest := mapOf(spec["destination"])
	if strings.Contains(mapString(dest, "namespace"), "*") || strings.Contains(mapString(dest, "server"), "*") {
		return fmt.Errorf("%s/%s destination contains a wildcard", o.Kind, o.Name)
	}
	src := mapOf(spec["source"])
	if strings.Contains(mapString(src, "repoURL"), "*") {
		return fmt.Errorf("%s/%s repoURL contains a wildcard", o.Kind, o.Name)
	}
	return nil
}

func isIAM(o *object) bool {
	av := strings.ToLower(o.APIVersion)
	kind := strings.ToLower(o.Kind)
	if strings.Contains(av, "iam") {
		return true
	}
	if strings.Contains(kind, "iam") {
		return true
	}
	return false
}

func sourcePath(o object) string {
	spec := mapOf(o.Raw["spec"])
	src := mapOf(spec["source"])
	return mapString(src, "path")
}

func destNamespace(o object) string {
	spec := mapOf(o.Raw["spec"])
	dest := mapOf(spec["destination"])
	return mapString(dest, "namespace")
}

func loadYAML(path string) ([]object, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	dec := yaml.NewDecoder(strings.NewReader(string(b)))
	var out []object
	for {
		var raw map[string]any
		err := dec.Decode(&raw)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, err
		}
		if len(raw) == 0 {
			continue
		}
		meta := mapOf(raw["metadata"])
		out = append(out, object{
			APIVersion: mapString(raw, "apiVersion"),
			Kind:       mapString(raw, "kind"),
			Name:       mapString(meta, "name"),
			Namespace:  mapString(meta, "namespace"),
			Raw:        raw,
			Source:     path,
		})
	}
	return out, nil
}

func mapOf(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func mapString(m map[string]any, key string) string {
	if m == nil {
		return ""
	}
	s, _ := m[key].(string)
	return s
}

func stringSlice(v any) []string {
	items, ok := v.([]any)
	if !ok {
		return nil
	}
	var out []string
	for _, item := range items {
		s, _ := item.(string)
		out = append(out, s)
	}
	return out
}
