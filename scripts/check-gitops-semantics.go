// Field-level GitOps semantic gate for Milestone 3 and Milestone 4.
// Parses YAML documents. Does not apply manifests or call a cluster.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	repoURL      = "https://github.com/leeclarkuk/platform-engineering-reference"
	inCluster    = "https://kubernetes.default.svc"
	nsArgocd     = "argocd"
	nsApps       = "apps"
	revMain      = "main"
	pathApps     = "gitops/apps"
	pathTpl      = "templates"
	rootAppName  = "gitops-root"
	sampleName   = "sample"
	projBoot     = "bootstrap"
	projPlat     = "platform"
	argoGroup    = "argoproj.io"
	kindApp      = "Application"
	groupApps    = "apps"
	kindDeploy   = "Deployment"
	kindService  = "Service"
	kindSA       = "ServiceAccount"
	contractFile = "testdata/workloadcontract-valid.yaml"
	valuesFile   = "templates/values.yaml"
	tfVarsFile   = "infra/aws/workload/variables.tf"
)

var requiredM3Fixtures = []string{
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
	"privilege-broadening",
	"extra-namespace",
	"wrong-metadata-namespace",
	"malformed-yaml",
}

// Twenty named Milestone 4 behaviours. Each directory must exist and the
// executable fixtures Go owns must fail. Pin, Terraform, and mutation
// fixtures are executed by gitops-validate.sh.
var requiredM4Fixtures = []m4Fixture{
	{name: "cluster-resource-whitelist", kind: "tree"},
	{name: "wildcard-permission", kind: "tree"},
	{name: "workload-app-on-bootstrap", kind: "tree"},
	{name: "root-app-on-platform", kind: "tree"},
	{name: "wrong-repo-or-revision", kind: "tree"},
	{name: "wrong-source-path", kind: "tree"},
	{name: "destination-argocd-or-unlisted", kind: "tree"},
	{name: "automated-sync", kind: "tree"},
	{name: "extra-platform-application", kind: "tree"},
	{name: "cluster-scoped-helm-output", kind: "helm"},
	{name: "helm-resources-outside-apps", kind: "helm"},
	{name: "missing-serviceaccount-sample", kind: "helm"},
	{name: "deployment-wrong-sa", kind: "helm"},
	{name: "raw-workload-under-gitops-apps", kind: "tree"},
	{name: "malformed-application-or-helm", kind: "tree"},
	{name: "missing-helm-pin-or-schema", kind: "pins"},
	{name: "stale-schema-hash", kind: "pins"},
	{name: "iam-or-terraform-under-gitops", kind: "tree"},
	{name: "k8s-helm-under-terraform", kind: "terraform"},
	{name: "live-mutation-in-validation", kind: "mutation"},
}

type m4Fixture struct {
	name string
	kind string
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
	helmRender := flag.String("helm-render", "", "path to helm template output (required for live gate)")
	flag.Parse()

	root, err := os.Getwd()
	if err != nil {
		fail("working directory: %v", err)
	}
	live := filepath.Join(root, "gitops")
	if err := checkTree(live); err != nil {
		fail("live gitops/: %v", err)
	}
	if err := checkLiveKustomize(root); err != nil {
		fail("live kustomization: %v", err)
	}
	fmt.Println("ok live gitops/ semantic checks")

	if *helmRender == "" {
		fail("missing --helm-render (Milestone 4 requires a Helm template file)")
	}
	if err := checkHelmRender(*helmRender); err != nil {
		fail("live helm render: %v", err)
	}
	fmt.Println("ok live helm render semantic checks")

	if err := checkIdentity(root, *helmRender); err != nil {
		fail("identity alignment: %v", err)
	}
	fmt.Println("ok identity alignment (WorkloadContract, Helm values, M2 Terraform inputs)")

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
		err := checkTree(path)
		if err == nil {
			fail("fixture %s: wanted non-zero, got pass", ent.Name())
		}
		fmt.Printf("ok fixture %s failed as required: %v\n", ent.Name(), err)
	}
	for _, name := range requiredM3Fixtures {
		if !seen[name] {
			fail("missing required fixture directory %s", name)
		}
	}
	fmt.Println("ok gitops semantic fixtures (all required M3 negatives failed)")

	m4Root := filepath.Join(root, "testdata", "gitops-m4-negatives")
	for _, fx := range requiredM4Fixtures {
		path := filepath.Join(m4Root, fx.name)
		if st, err := os.Stat(path); err != nil || !st.IsDir() {
			fail("missing required M4 fixture directory %s", fx.name)
		}
		switch fx.kind {
		case "tree":
			err := checkTree(path)
			if err == nil {
				fail("M4 fixture %s: wanted non-zero, got pass", fx.name)
			}
			fmt.Printf("ok M4 fixture %s failed as required: %v\n", fx.name, err)
		case "helm":
			render := filepath.Join(path, "render.yaml")
			err := checkHelmRender(render)
			if err == nil {
				fail("M4 fixture %s: wanted non-zero, got pass", fx.name)
			}
			fmt.Printf("ok M4 fixture %s failed as required: %v\n", fx.name, err)
		case "pins", "terraform", "mutation":
			fmt.Printf("ok M4 fixture %s present (executed by gitops-validate.sh)\n", fx.name)
		default:
			fail("unknown M4 fixture kind %s for %s", fx.kind, fx.name)
		}
	}
	if len(requiredM4Fixtures) != 20 {
		fail("internal error: required M4 fixtures want 20, got %d", len(requiredM4Fixtures))
	}
	fmt.Println("ok gitops M4 named fixtures (twenty committed; tree/helm executed here)")
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "FAIL check-gitops-semantics: "+format+"\n", args...)
	os.Exit(1)
}

func checkLiveKustomize(root string) error {
	rootK, err := loadSingleKustomize(filepath.Join(root, "gitops", "kustomization.yaml"))
	if err != nil {
		return err
	}
	wantRoot := []string{
		"bootstrap/namespace-argocd.yaml",
		"bootstrap/namespace-apps.yaml",
		"bootstrap/appproject-bootstrap.yaml",
		"bootstrap/appproject-platform.yaml",
		"bootstrap/application-gitops-root.yaml",
		"apps",
	}
	if err := equalStrings(rootK, wantRoot, "gitops/kustomization.yaml resources"); err != nil {
		return err
	}
	appsK, err := loadSingleKustomize(filepath.Join(root, "gitops", "apps", "kustomization.yaml"))
	if err != nil {
		return err
	}
	wantApps := []string{"application-sample.yaml"}
	return equalStrings(appsK, wantApps, "gitops/apps/kustomization.yaml resources")
}

func loadSingleKustomize(path string) ([]string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var raw map[string]any
	if err := yaml.Unmarshal(b, &raw); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return stringSlice(raw["resources"]), nil
}

func equalStrings(got, want []string, what string) error {
	if len(got) != len(want) {
		return fmt.Errorf("%s %v, want %v", what, got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			return fmt.Errorf("%s %v, want %v", what, got, want)
		}
	}
	return nil
}

func checkTree(dir string) error {
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

	var namespaces []object
	var apps []object
	var projects []object
	var boot, plat *object

	for i := range objs {
		o := &objs[i]
		if isIAM(o) {
			return fmt.Errorf("IAM object under gitops: %s %s/%s in %s", o.APIVersion, o.Kind, o.Name, o.Source)
		}
		switch o.Kind {
		case "Kustomization":
			continue
		case "Namespace":
			namespaces = append(namespaces, *o)
		case "Application":
			apps = append(apps, *o)
		case "AppProject":
			projects = append(projects, *o)
			switch o.Name {
			case projBoot:
				boot = o
			case projPlat:
				plat = o
			}
		case kindDeploy, kindService, kindSA:
			return fmt.Errorf("raw workload duplication under gitops (copied %s %s/%s in %s; orchestration only)", o.Kind, o.Namespace, o.Name, o.Source)
		case "":
			return fmt.Errorf("object missing kind in %s", o.Source)
		default:
			return fmt.Errorf("unexpected kind %s (%s/%s) in %s", o.Kind, o.APIVersion, o.Name, o.Source)
		}
		if err := rejectWildcards(o); err != nil {
			return err
		}
		if err := rejectClusterResourceWhitelist(o); err != nil {
			return err
		}
	}

	if len(namespaces) != 2 {
		return fmt.Errorf("want exactly two Namespace objects (argocd, apps), got %d", len(namespaces))
	}
	nsNames := []string{namespaces[0].Name, namespaces[1].Name}
	sort.Strings(nsNames)
	if nsNames[0] != nsApps || nsNames[1] != nsArgocd {
		return fmt.Errorf("namespaces must be exactly argocd and apps, got %q and %q", namespaces[0].Name, namespaces[1].Name)
	}

	if len(projects) != 2 {
		return fmt.Errorf("want exactly two AppProjects (bootstrap, platform), got %d", len(projects))
	}
	if boot == nil || plat == nil {
		return fmt.Errorf("want AppProjects named bootstrap and platform")
	}
	if boot.Namespace != nsArgocd {
		return fmt.Errorf("AppProject bootstrap metadata.namespace %q, want argocd", boot.Namespace)
	}
	if plat.Namespace != nsArgocd {
		return fmt.Errorf("AppProject platform metadata.namespace %q, want argocd", plat.Namespace)
	}
	if err := checkProject(boot, projBoot, nsArgocd, nsApps); err != nil {
		return err
	}
	if err := checkProject(plat, projPlat, nsApps, nsArgocd); err != nil {
		return err
	}

	var rootApp, sampleApp *object
	var platformApps []string
	for i := range apps {
		a := &apps[i]
		switch a.Name {
		case rootAppName:
			rootApp = a
		case sampleName:
			sampleApp = a
		}
		if mapString(mapOf(a.Raw["spec"]), "project") == projPlat {
			platformApps = append(platformApps, a.Name)
		}
	}
	if len(platformApps) > 1 {
		return fmt.Errorf("more than one platform workload Application: %s", strings.Join(platformApps, ", "))
	}
	if len(apps) != 2 {
		return fmt.Errorf("want exactly two Applications (gitops-root, sample), got %d", len(apps))
	}
	if rootApp == nil {
		return fmt.Errorf("missing Application %s", rootAppName)
	}
	if sampleApp == nil {
		return fmt.Errorf("missing Application %s", sampleName)
	}

	if err := checkRootApp(*rootApp); err != nil {
		return err
	}
	if err := checkSampleApp(*sampleApp); err != nil {
		return err
	}
	return nil
}

func checkRootApp(o object) error {
	if o.Name != rootAppName {
		return fmt.Errorf("root Application name %q, want %s", o.Name, rootAppName)
	}
	if o.Namespace != nsArgocd {
		return fmt.Errorf("gitops-root metadata.namespace %q, want argocd", o.Namespace)
	}
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return fmt.Errorf("gitops-root missing spec")
	}
	proj := mapString(spec, "project")
	if proj == projPlat {
		return fmt.Errorf("root Application assigned to platform")
	}
	if proj != projBoot {
		return fmt.Errorf("gitops-root project %q, want %s", proj, projBoot)
	}
	if _, ok := spec["sources"]; ok {
		return fmt.Errorf("gitops-root must not use spec.sources")
	}
	src := mapOf(spec["source"])
	if mapString(src, "repoURL") != repoURL {
		return fmt.Errorf("gitops-root repoURL %q, want %s", mapString(src, "repoURL"), repoURL)
	}
	if mapString(src, "targetRevision") != revMain {
		return fmt.Errorf("gitops-root targetRevision %q, want %s", mapString(src, "targetRevision"), revMain)
	}
	path := mapString(src, "path")
	if path == pathTpl || strings.HasPrefix(path, pathTpl+"/") {
		return fmt.Errorf("Application %s source path %q is forbidden", o.Name, path)
	}
	if path != pathApps {
		return fmt.Errorf("gitops-root path %q, want %s", path, pathApps)
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

func checkSampleApp(o object) error {
	if o.Name != sampleName {
		return fmt.Errorf("sample Application name %q, want %s", o.Name, sampleName)
	}
	if o.Namespace != nsArgocd {
		return fmt.Errorf("sample metadata.namespace %q, want argocd", o.Namespace)
	}
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return fmt.Errorf("sample missing spec")
	}
	proj := mapString(spec, "project")
	if proj == projBoot {
		return fmt.Errorf("workload Application assigned to bootstrap")
	}
	if proj != projPlat {
		return fmt.Errorf("sample project %q, want %s", proj, projPlat)
	}
	if _, ok := spec["sources"]; ok {
		return fmt.Errorf("sample must not use spec.sources")
	}
	src := mapOf(spec["source"])
	if src == nil {
		return fmt.Errorf("sample missing spec.source")
	}
	if _, ok := src["helm"]; ok {
		return fmt.Errorf("sample must omit spec.source.helm (no valueFiles, values, or parameters duplicating chart defaults)")
	}
	if mapString(src, "chart") != "" {
		return fmt.Errorf("sample must not set spec.source.chart (no chart repository)")
	}
	if mapString(src, "repoURL") != repoURL {
		return fmt.Errorf("sample repoURL %q, want %s", mapString(src, "repoURL"), repoURL)
	}
	if mapString(src, "targetRevision") != revMain {
		return fmt.Errorf("sample targetRevision %q, want %s", mapString(src, "targetRevision"), revMain)
	}
	path := mapString(src, "path")
	if path != pathTpl {
		return fmt.Errorf("wrong source path %q (want exact chart root %s)", path, pathTpl)
	}
	dest := mapOf(spec["destination"])
	server := mapString(dest, "server")
	destNS := mapString(dest, "namespace")
	if strings.Contains(server, "*") || strings.Contains(destNS, "*") {
		return fmt.Errorf("sample destination contains a wildcard")
	}
	if destNS == nsArgocd {
		return fmt.Errorf("sample destination.namespace argocd is forbidden")
	}
	if destNS != nsApps {
		return fmt.Errorf("sample destination.namespace %q is unlisted (want %s)", destNS, nsApps)
	}
	if server != inCluster {
		return fmt.Errorf("sample destination.server %q, want %s", server, inCluster)
	}
	if _, ok := spec["syncPolicy"]; ok {
		return fmt.Errorf("sample must omit spec.syncPolicy (no automated, prune, or selfHeal)")
	}
	return nil
}

func checkProject(o *object, name, allowNS, forbidNS string) error {
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return fmt.Errorf("AppProject %s missing spec", name)
	}
	if _, ok := spec["clusterResourceWhitelist"]; ok {
		return fmt.Errorf("AppProject %s must not set clusterResourceWhitelist", name)
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
	switch name {
	case projBoot:
		return checkBootstrapWhitelist(spec)
	case projPlat:
		return checkPlatformWhitelist(spec)
	}
	return nil
}

func checkBootstrapWhitelist(spec map[string]any) error {
	raw, ok := spec["namespaceResourceWhitelist"]
	if !ok {
		return fmt.Errorf("AppProject bootstrap missing namespaceResourceWhitelist (must be exactly argoproj.io/Application)")
	}
	items, ok := raw.([]any)
	if !ok {
		return fmt.Errorf("AppProject bootstrap namespaceResourceWhitelist must be a sequence")
	}
	if len(items) != 1 {
		return fmt.Errorf("AppProject bootstrap namespaceResourceWhitelist must be exactly argoproj.io/Application (got %d entries)", len(items))
	}
	m := mapOf(items[0])
	group := mapString(m, "group")
	kind := mapString(m, "kind")
	if strings.Contains(group, "*") || strings.Contains(kind, "*") {
		return fmt.Errorf("AppProject bootstrap namespaceResourceWhitelist contains a wildcard")
	}
	if group != argoGroup || kind != kindApp {
		return fmt.Errorf("AppProject bootstrap namespaceResourceWhitelist must be exactly argoproj.io/Application (got %s/%s)", group, kind)
	}
	return nil
}

func checkPlatformWhitelist(spec map[string]any) error {
	raw, ok := spec["namespaceResourceWhitelist"]
	if !ok {
		return fmt.Errorf("AppProject platform missing namespaceResourceWhitelist (must be exactly Deployment apps, Service core, ServiceAccount core)")
	}
	items, ok := raw.([]any)
	if !ok {
		return fmt.Errorf("AppProject platform namespaceResourceWhitelist must be a sequence")
	}
	if len(items) != 3 {
		return fmt.Errorf("AppProject platform namespaceResourceWhitelist must be exactly three chart kinds (got %d entries)", len(items))
	}
	seen := map[string]bool{}
	for _, item := range items {
		m := mapOf(item)
		group := mapString(m, "group")
		kind := mapString(m, "kind")
		if strings.Contains(group, "*") || strings.Contains(kind, "*") {
			return fmt.Errorf("AppProject platform namespaceResourceWhitelist contains a wildcard")
		}
		key := group + "/" + kind
		seen[key] = true
	}
	want := map[string]bool{
		groupApps + "/" + kindDeploy: true,
		"/" + kindService:            true,
		"/" + kindSA:                 true,
	}
	for k := range want {
		if !seen[k] {
			return fmt.Errorf("AppProject platform namespaceResourceWhitelist missing %s", k)
		}
	}
	for k := range seen {
		if !want[k] {
			return fmt.Errorf("AppProject platform namespaceResourceWhitelist extra entry %s", k)
		}
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

func rejectClusterResourceWhitelist(o *object) error {
	if o.Kind != "AppProject" {
		return nil
	}
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return nil
	}
	if _, ok := spec["clusterResourceWhitelist"]; ok {
		return fmt.Errorf("AppProject %s sets clusterResourceWhitelist (forbidden for any contents)", o.Name)
	}
	return nil
}

func rejectWildcards(o *object) error {
	spec := mapOf(o.Raw["spec"])
	if spec == nil {
		return nil
	}
	return walkAllowWildcards(o, spec, "spec")
}

func walkAllowWildcards(o *object, v any, path string) error {
	switch t := v.(type) {
	case string:
		if strings.Contains(t, "*") && isAllowSurface(path) {
			return fmt.Errorf("%s/%s wildcard permission in %s: %q", o.Kind, o.Name, path, t)
		}
	case []any:
		for i, item := range t {
			if err := walkAllowWildcards(o, item, fmt.Sprintf("%s[%d]", path, i)); err != nil {
				return err
			}
		}
	case map[string]any:
		for k, item := range t {
			if err := walkAllowWildcards(o, item, path+"."+k); err != nil {
				return err
			}
		}
	}
	return nil
}

func isAllowSurface(path string) bool {
	markers := []string{
		"sourceRepos",
		"destinations",
		"destination",
		"namespaceResourceWhitelist",
		"namespaceResourceBlacklist",
		"clusterResourceWhitelist",
		"clusterResourceBlacklist",
		"group",
		"kind",
		"namespace",
		"server",
		"repoURL",
	}
	for _, m := range markers {
		if strings.Contains(path, m) {
			return true
		}
	}
	return false
}

func checkHelmRender(path string) error {
	docs, err := loadYAML(path)
	if err != nil {
		return fmt.Errorf("malformed Helm output %s: %w", path, err)
	}
	if len(docs) == 0 {
		return fmt.Errorf("Helm output %s produced no objects", path)
	}
	var deploy, svc, sa *object
	for i := range docs {
		o := &docs[i]
		if o.Kind == "" {
			return fmt.Errorf("malformed Helm output: object missing kind in %s", o.Source)
		}
		ns := o.Namespace
		if isClusterScoped(o) {
			return fmt.Errorf("cluster-scoped Helm output: %s %s", o.Kind, o.Name)
		}
		if ns != nsApps {
			return fmt.Errorf("rendered resource outside ns apps: %s %s/%s", o.Kind, ns, o.Name)
		}
		switch o.Kind {
		case kindDeploy:
			if deploy != nil {
				return fmt.Errorf("Helm output has more than one Deployment")
			}
			deploy = o
		case kindService:
			if svc != nil {
				return fmt.Errorf("Helm output has more than one Service")
			}
			svc = o
		case kindSA:
			if sa != nil {
				return fmt.Errorf("Helm output has more than one ServiceAccount")
			}
			sa = o
		default:
			return fmt.Errorf("unexpected Helm kind %s (%s/%s)", o.Kind, o.APIVersion, o.Name)
		}
	}
	if sa == nil || sa.Name != sampleName || sa.Namespace != nsApps {
		return fmt.Errorf("missing or renamed ServiceAccount apps/sample")
	}
	if deploy == nil || deploy.Name != sampleName || deploy.Namespace != nsApps {
		return fmt.Errorf("Helm output missing Deployment apps/sample")
	}
	if svc == nil || svc.Name != sampleName || svc.Namespace != nsApps {
		return fmt.Errorf("Helm output missing Service apps/sample")
	}
	saName := nestedString(deploy.Raw, "spec", "template", "spec", "serviceAccountName")
	if saName != sampleName {
		return fmt.Errorf("Deployment not using ServiceAccount sample (got %q)", saName)
	}
	return nil
}

func isClusterScoped(o *object) bool {
	switch o.Kind {
	case "Namespace", "Node", "PersistentVolume", "ClusterRole", "ClusterRoleBinding",
		"CustomResourceDefinition", "StorageClass", "MutatingWebhookConfiguration",
		"ValidatingWebhookConfiguration", "APIService", "PriorityClass", "CSIDriver",
		"VolumeSnapshotClass", "RuntimeClass":
		return true
	}
	if o.Namespace == "" && o.Kind != kindSA && o.Kind != kindService && o.Kind != kindDeploy {
		return true
	}
	return false
}

func checkIdentity(root, helmRender string) error {
	contractPath := filepath.Join(root, contractFile)
	docs, err := loadYAML(contractPath)
	if err != nil {
		return fmt.Errorf("WorkloadContract fixture: %w", err)
	}
	if len(docs) != 1 {
		return fmt.Errorf("WorkloadContract fixture: want one document, got %d", len(docs))
	}
	c := docs[0]
	if c.Kind != "WorkloadContract" {
		return fmt.Errorf("WorkloadContract fixture kind %q", c.Kind)
	}
	if c.Name != sampleName {
		return fmt.Errorf("WorkloadContract metadata.name %q, want %s", c.Name, sampleName)
	}
	sa := mapOf(mapOf(c.Raw["spec"])["serviceAccount"])
	if mapString(sa, "namespace") != nsApps || mapString(sa, "name") != sampleName {
		return fmt.Errorf("WorkloadContract serviceAccount %s/%s, want %s/%s", mapString(sa, "namespace"), mapString(sa, "name"), nsApps, sampleName)
	}

	valuesPath := filepath.Join(root, valuesFile)
	vb, err := os.ReadFile(valuesPath)
	if err != nil {
		return err
	}
	var values map[string]any
	if err := yaml.Unmarshal(vb, &values); err != nil {
		return fmt.Errorf("Helm values: %w", err)
	}
	if mapString(values, "name") != sampleName {
		return fmt.Errorf("Helm values name %q, want %s", mapString(values, "name"), sampleName)
	}
	vsa := mapOf(values["serviceAccount"])
	if mapString(vsa, "name") != sampleName || mapString(vsa, "namespace") != nsApps {
		return fmt.Errorf("Helm values serviceAccount %s/%s, want %s/%s", mapString(vsa, "namespace"), mapString(vsa, "name"), nsApps, sampleName)
	}

	if err := terraformDefault(filepath.Join(root, tfVarsFile), "service_account_namespace", nsApps); err != nil {
		return err
	}
	if err := terraformDefault(filepath.Join(root, tfVarsFile), "service_account_name", sampleName); err != nil {
		return err
	}

	return checkHelmRender(helmRender)
}

func terraformDefault(path, variable, want string) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	text := string(b)
	needle := `variable "` + variable + `"`
	i := strings.Index(text, needle)
	if i < 0 {
		return fmt.Errorf("Terraform variable %s missing in %s", variable, path)
	}
	rest := text[i:]
	end := strings.Index(rest[len(needle):], `variable "`)
	block := rest
	if end >= 0 {
		block = rest[:len(needle)+end]
	}
	if !strings.Contains(block, `default     = "`+want+`"`) && !strings.Contains(block, `default = "`+want+`"`) {
		return fmt.Errorf("Terraform variable %s default is not %q", variable, want)
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

func nestedString(m map[string]any, keys ...string) string {
	cur := m
	for i, k := range keys {
		if i == len(keys)-1 {
			return mapString(cur, k)
		}
		cur = mapOf(cur[k])
		if cur == nil {
			return ""
		}
	}
	return ""
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
