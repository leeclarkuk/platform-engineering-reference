// Field-level ObservabilityContract semantic gate for Milestone 5.
// Parses YAML. Does not start a collector, Prometheus, or a cluster.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v5"
	"gopkg.in/yaml.v3"
)

const (
	apiVersion   = "platform.engineering.reference/v1alpha1"
	kindContract = "ObservabilityContract"
	sampleName   = "sample"
	nsApps       = "apps"
	ownerPlat    = "platform"
	svcVersion   = "0.1.0"
	envLocal     = "local-design"
	jobSample    = "sample"
	metricUp     = "up"
	sevWarning   = "warning"
	contractFile = "observability/contracts/sample.yaml"
	schemaRel    = "observability/schemas/observabilitycontract.schema.json"
	collectorRel = "observability/otel/collector-metrics.yaml"
	rulesRel     = "observability/prometheus/rules/sample.yml"
	wcFile       = "testdata/workloadcontract-valid.yaml"
	chartFile    = "templates/Chart.yaml"
	valuesFile   = "templates/values.yaml"
	appFile      = "gitops/apps/application-sample.yaml"
)

var (
	attrServiceName   = "service.name"
	attrServiceNS     = "service.namespace"
	attrServiceVer    = "service.version"
	attrEnvName       = "deployment.environment.name"
	requiredAttrs     = []string{attrServiceName, attrServiceNS, attrServiceVer, attrEnvName}
	allowedReceivers  = map[string]bool{"otlp": true}
	allowedProcessors = map[string]bool{
		"memory_limiter": true,
		"resource":       true,
		"batch":          true,
	}
	allowedExporters = map[string]bool{
		"prometheus": true,
		"debug":      true,
	}
	highCardKeys = []string{
		"user.id", "user_id", "session.id", "session_id", "request.id", "request_id",
		"http.url", "http.target", "email", "ip", "client.address",
		"pod_name", "pod.uid", "container_id", "container.id", "trace_id", "span_id",
	}
	cloudExporters = []string{
		"datadog", "googlecloud", "googlemanagedprometheus", "awscloudwatch",
		"awsemf", "awsxray", "azuremonitor", "coralogix", "honeycomb",
		"newrelic", "splunkhec", "signalfx", "instana", "sentry",
		"cloudwatch", "prometheusremotewrite",
	}
	secretKeys = []string{
		"password", "api_key", "apikey", "secret", "authorization", "bearer",
		"aws_secret_access_key", "access_key", "private_key", "token",
	}
	sloNeedles = []string{
		"slo", "latency", "error-rate", "error_rate", "availability",
		"errorbudget", "error_budget", "burn_rate", "burn-rate",
		"histogram_quantile", "objective",
	}
	pagingNeedles  = []string{"critical", "page", "paging", "pagerduty", "p0", "p1"}
	metricSelector = regexp.MustCompile(`([a-zA-Z_:][a-zA-Z0-9_:]*)\s*\{`)
	jobLabel       = regexp.MustCompile(`job\s*=\s*"([^"]+)"`)
)

type gate struct {
	repoRoot string
	tree     string
	issues   []string
}

func (g *gate) failf(format string, args ...any) {
	g.issues = append(g.issues, fmt.Sprintf(format, args...))
}

func main() {
	repoRoot := flag.String("repo-root", "", "repository root for identity sources (WorkloadContract, Helm, Application)")
	tree := flag.String("tree", "", "tree containing observability/ (defaults to repo-root)")
	flag.Parse()

	wd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "FAIL observability-semantics: %v\n", err)
		os.Exit(1)
	}
	if *repoRoot == "" {
		*repoRoot = wd
	}
	if *tree == "" {
		*tree = *repoRoot
	}

	g := &gate{repoRoot: *repoRoot, tree: *tree}
	g.check()
	if len(g.issues) > 0 {
		for _, issue := range g.issues {
			fmt.Fprintf(os.Stderr, "FAIL observability-semantics: %s\n", issue)
		}
		os.Exit(1)
	}
	fmt.Printf("ok observability-semantics (tree %s)\n", g.tree)
}

func (g *gate) check() {
	g.checkContract()
	g.checkCollector()
	g.checkRules()
	g.scanObservabilityTree()
}

func (g *gate) checkContract() {
	path := filepath.Join(g.tree, contractFile)
	raw, err := os.ReadFile(path)
	if err != nil {
		g.failf("malformed YAML: cannot read %s: %v", contractFile, err)
		return
	}
	var doc any
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		g.failf("malformed YAML: %v", err)
		return
	}
	if doc == nil {
		g.failf("malformed YAML: empty document")
		return
	}
	jsonDoc, err := yamlToJSONValue(doc)
	if err != nil {
		g.failf("malformed YAML: %v", err)
		return
	}
	schemaPath := filepath.Join(g.tree, schemaRel)
	schemaBytes, err := os.ReadFile(schemaPath)
	if err != nil {
		g.failf("missing schema: %v", err)
		return
	}
	schema, err := jsonschema.CompileString("observabilitycontract.schema.json", string(schemaBytes))
	if err != nil {
		g.failf("compile schema: %v", err)
		return
	}
	encoded, err := json.Marshal(jsonDoc)
	if err != nil {
		g.failf("encode JSON: %v", err)
		return
	}
	var instance any
	if err := json.Unmarshal(encoded, &instance); err != nil {
		g.failf("decode JSON: %v", err)
		return
	}
	if err := schema.Validate(instance); err != nil {
		msg := err.Error()
		lower := strings.ToLower(msg)
		if strings.Contains(lower, "additionalproperties") || strings.Contains(lower, "additional properties") {
			g.failf("unknown field: %v", err)
		} else if strings.Contains(lower, "apiversion") || strings.Contains(lower, "kind") || strings.Contains(lower, "const") {
			g.failf("wrong apiVersion/kind: %v", err)
		} else {
			g.failf("schema: %v", err)
		}
		g.noteHighCardinality(asMap(jsonDoc))
		g.noteInventedSLO(asMap(jsonDoc))
	}

	m := asMap(jsonDoc)
	if asString(m["apiVersion"]) != apiVersion {
		g.failf("wrong apiVersion: want %s", apiVersion)
	}
	if asString(m["kind"]) != kindContract {
		g.failf("wrong kind: want %s", kindContract)
	}

	meta := asMap(m["metadata"])
	name := asString(meta["name"])
	spec := asMap(m["spec"])
	owner := asString(spec["owner"])
	wref := asMap(spec["workloadRef"])
	wName := asString(wref["name"])
	wNS := asString(wref["namespace"])

	if name == "*" || wName == "*" || wNS == "*" || owner == "*" {
		g.failf("wildcard identity is forbidden")
	}
	if name == "" || wName == "" || wNS == "" || owner == "" {
		g.failf("empty identity is forbidden")
	}

	wantName, wantNS, wantOwner, wantVer := g.identityFromSources()
	if name != wantName || wName != wantName {
		g.failf("identity name drift: contract name=%q workloadRef.name=%q want %q", name, wName, wantName)
	}
	if wNS != wantNS {
		g.failf("identity namespace drift: workloadRef.namespace=%q want %q", wNS, wantNS)
	}
	if owner != wantOwner {
		g.failf("identity owner drift: spec.owner=%q want %q", owner, wantOwner)
	}

	otel := asMap(spec["openTelemetry"])
	attrs := asMap(otel["resourceAttributes"])
	if len(attrs) == 0 {
		g.failf("missing OTel resource attributes")
	}
	for _, key := range requiredAttrs {
		if asString(attrs[key]) == "" {
			g.failf("missing OTel attr %s", key)
		}
	}
	if asString(attrs[attrServiceName]) != wantName {
		g.failf("identity name drift: service.name=%q want %q", asString(attrs[attrServiceName]), wantName)
	}
	if asString(attrs[attrServiceNS]) != wantNS {
		g.failf("identity namespace drift: service.namespace=%q want %q", asString(attrs[attrServiceNS]), wantNS)
	}
	if asString(attrs[attrServiceVer]) != wantVer {
		g.failf("service.version %q does not equal Chart appVersion %q", asString(attrs[attrServiceVer]), wantVer)
	}
	if asString(attrs[attrEnvName]) != envLocal {
		g.failf("deployment.environment.name %q is not the design-only const %q", asString(attrs[attrEnvName]), envLocal)
	}
	g.noteHighCardinality(m)

	prom := asMap(spec["prometheus"])
	if asString(prom["job"]) != jobSample {
		g.failf("wrong job: prometheus.job=%q want %q", asString(prom["job"]), jobSample)
	}
	metrics, _ := prom["metrics"].([]any)
	hasUp := false
	for _, item := range metrics {
		im := asMap(item)
		if asString(im["name"]) != metricUp {
			continue
		}
		hasUp = true
		labels, _ := im["labels"].([]any)
		have := map[string]bool{}
		for _, l := range labels {
			have[asString(l)] = true
		}
		if !have["job"] || !have["instance"] {
			g.failf("metric up must declare labels job and instance")
		}
	}
	if !hasUp {
		g.failf("undeclared metric: allowlist must include up")
	}

	alerts := asMap(spec["alerts"])
	sev := strings.ToLower(asString(alerts["maxSeverity"]))
	if sev != sevWarning {
		g.failf("paging/critical severity forbidden: alerts.maxSeverity=%q", asString(alerts["maxSeverity"]))
	}
	if asString(alerts["owner"]) != wantOwner {
		g.failf("identity owner drift: alerts.owner=%q want %q", asString(alerts["owner"]), wantOwner)
	}
	g.noteInventedSLO(m)

	arts := asMap(spec["artifacts"])
	col := asString(arts["collectorConfig"])
	rules := asString(arts["prometheusRules"])
	if col != collectorRel {
		g.failf("artifacts.collectorConfig=%q want %q", col, collectorRel)
	}
	if rules != rulesRel {
		g.failf("artifacts.prometheusRules=%q want %q", rules, rulesRel)
	}
	if _, err := os.Stat(filepath.Join(g.tree, collectorRel)); err != nil {
		g.failf("missing collector artifact %s", collectorRel)
	}
	if _, err := os.Stat(filepath.Join(g.tree, rulesRel)); err != nil {
		g.failf("missing prometheus rules artifact %s", rulesRel)
	}
}

func (g *gate) identityFromSources() (name, namespace, owner, version string) {
	name, namespace, owner, version = sampleName, nsApps, ownerPlat, svcVersion
	wc := g.loadMap(g.repoRoot, wcFile)
	if wc != nil {
		meta := asMap(wc["metadata"])
		spec := asMap(wc["spec"])
		sa := asMap(spec["serviceAccount"])
		if n := asString(meta["name"]); n != "" {
			name = n
		}
		if o := asString(spec["owner"]); o != "" {
			owner = o
		}
		if ns := asString(sa["namespace"]); ns != "" {
			namespace = ns
		}
		if n := asString(sa["name"]); n != "" && n != name {
			g.failf("WorkloadContract serviceAccount.name %q != metadata.name %q", n, name)
		}
	} else {
		g.failf("missing WorkloadContract fixture %s", wcFile)
	}
	chart := g.loadMap(g.repoRoot, chartFile)
	if chart != nil {
		if n := asString(chart["name"]); n != "" && n != name {
			g.failf("Helm Chart.yaml name %q != contract name %q", n, name)
		}
		if v := asString(chart["appVersion"]); v != "" {
			version = v
		}
	} else {
		g.failf("missing Helm Chart.yaml")
	}
	values := g.loadMap(g.repoRoot, valuesFile)
	if values != nil {
		if n := asString(values["name"]); n != "" && n != name {
			g.failf("Helm values name %q != contract name %q", n, name)
		}
		if o := asString(values["owner"]); o != "" && o != owner {
			g.failf("Helm values owner %q != contract owner %q", o, owner)
		}
		img := asMap(values["image"])
		if t := asString(img["tag"]); t != "" && t != version {
			g.failf("Helm values image.tag %q != Chart appVersion %q", t, version)
		}
		sa := asMap(values["serviceAccount"])
		if n := asString(sa["name"]); n != "" && n != name {
			g.failf("Helm values serviceAccount.name %q != %q", n, name)
		}
		if ns := asString(sa["namespace"]); ns != "" && ns != namespace {
			g.failf("Helm values serviceAccount.namespace %q != %q", ns, namespace)
		}
	} else {
		g.failf("missing Helm values.yaml")
	}
	app := g.loadMap(g.repoRoot, appFile)
	if app != nil {
		meta := asMap(app["metadata"])
		if n := asString(meta["name"]); n != "" && n != name {
			g.failf("Application metadata.name %q != contract name %q", n, name)
		}
		spec := asMap(app["spec"])
		dest := asMap(spec["destination"])
		if ns := asString(dest["namespace"]); ns != "" && ns != namespace {
			g.failf("Application destination.namespace %q != %q", ns, namespace)
		}
	} else {
		g.failf("missing GitOps Application %s", appFile)
	}
	return name, namespace, owner, version
}

func (g *gate) checkCollector() {
	path := filepath.Join(g.tree, collectorRel)
	raw, err := os.ReadFile(path)
	if err != nil {
		g.failf("invalid collector config: cannot read %s: %v", collectorRel, err)
		return
	}
	text := string(raw)
	lower := strings.ToLower(text)
	if strings.Contains(lower, "prometheusremotewrite") || strings.Contains(lower, "remote_write") || strings.Contains(lower, "remote-write") {
		g.failf("remote write is forbidden in collector config")
	}
	for _, ex := range cloudExporters {
		if exporterNamed(lower, ex) {
			g.failf("cloud/vendor exporter %s is forbidden", ex)
		}
	}
	if strings.Contains(lower, "kubernetes_sd") || strings.Contains(lower, "k8s_cluster") || strings.Contains(lower, "kubeletstats") || strings.Contains(lower, "k8sattributes") {
		g.failf("Kubernetes discovery is forbidden in collector config")
	}
	for _, sk := range secretKeys {
		if strings.Contains(lower, sk) {
			g.failf("embedded secrets are forbidden: found %s", sk)
		}
	}
	if strings.Contains(lower, "amazonaws.com") || strings.Contains(lower, "sts.amazonaws") {
		g.failf("AWS endpoint is forbidden in collector config")
	}

	var doc any
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		g.failf("invalid collector config: malformed YAML: %v", err)
		return
	}
	m := asMap(doc)
	if m["apiVersion"] != nil || m["kind"] != nil {
		g.failf("collector config must not be a Kubernetes resource (apiVersion/kind present)")
	}
	receivers := asMap(m["receivers"])
	processors := asMap(m["processors"])
	exporters := asMap(m["exporters"])
	if len(receivers) == 0 || len(processors) == 0 || len(exporters) == 0 {
		g.failf("invalid collector config: receivers, processors, and exporters are required")
	}
	for name := range receivers {
		if !allowedReceivers[name] {
			g.failf("invalid collector config: receiver %s is not allowed (otlp only)", name)
		}
	}
	if _, ok := receivers["otlp"]; !ok {
		g.failf("invalid collector config: otlp receiver is required")
	}
	for name := range processors {
		if !allowedProcessors[name] {
			g.failf("invalid collector config: processor %s is not allowed", name)
		}
	}
	for _, need := range []string{"memory_limiter", "resource", "batch"} {
		if _, ok := processors[need]; !ok {
			g.failf("invalid collector config: processor %s is required", need)
		}
	}
	for name := range exporters {
		if !allowedExporters[name] {
			if name == "prometheusremotewrite" {
				g.failf("remote write is forbidden in collector config")
			} else {
				g.failf("cloud/vendor exporter %s is forbidden", name)
			}
		}
	}
	if _, ok := exporters["prometheus"]; !ok {
		g.failf("invalid collector config: prometheus exporter is required")
	}

	svc := asMap(m["service"])
	pipes := asMap(svc["pipelines"])
	if pipes["logs"] != nil {
		g.failf("logs pipeline is forbidden")
	}
	if pipes["traces"] != nil {
		g.failf("traces pipeline is forbidden")
	}
	if pipes["metrics"] == nil {
		g.failf("invalid collector config: metrics pipeline is required")
	}
	for name := range pipes {
		if name != "metrics" {
			g.failf("%s pipeline is forbidden", name)
		}
	}
	metrics := asMap(pipes["metrics"])
	if !stringSliceHas(asStringSlice(metrics["receivers"]), "otlp") {
		g.failf("invalid collector config: metrics pipeline must use otlp receiver")
	}
}

func (g *gate) checkRules() {
	path := filepath.Join(g.tree, rulesRel)
	raw, err := os.ReadFile(path)
	if err != nil {
		g.failf("invalid Prometheus rules: cannot read %s: %v", rulesRel, err)
		return
	}
	text := strings.ToLower(string(raw))
	for _, n := range sloNeedles {
		if strings.Contains(text, n) {
			g.failf("invented SLO: Prometheus rules contain %s", n)
		}
	}
	var doc any
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		g.failf("invalid Prometheus rules: malformed YAML: %v", err)
		return
	}
	m := asMap(doc)
	if m["apiVersion"] != nil || m["kind"] != nil {
		g.failf("Prometheus rules must not be a Kubernetes CRD (apiVersion/kind present)")
	}
	groups, _ := m["groups"].([]any)
	if len(groups) == 0 {
		g.failf("invalid Prometheus rules: groups is required")
		return
	}
	recording := 0
	alerting := 0
	for _, grp := range groups {
		gm := asMap(grp)
		rules, _ := gm["rules"].([]any)
		for _, rule := range rules {
			rm := asMap(rule)
			expr := asString(rm["expr"])
			if expr == "" {
				g.failf("invalid Prometheus rules: empty expr")
				continue
			}
			if rec := asString(rm["record"]); rec != "" {
				recording++
			}
			if alert := asString(rm["alert"]); alert != "" {
				alerting++
				labels := asMap(rm["labels"])
				sev := strings.ToLower(asString(labels["severity"]))
				if sev != sevWarning {
					g.failf("paging/critical severity forbidden: alert severity=%q", asString(labels["severity"]))
				}
				if asString(labels["owner"]) != ownerPlat {
					g.failf("identity owner drift: alert owner=%q want %q", asString(labels["owner"]), ownerPlat)
				}
				for _, n := range pagingNeedles {
					if sev == n || strings.EqualFold(asString(labels["severity"]), n) {
						g.failf("paging/critical severity forbidden")
					}
				}
			}
			for _, match := range metricSelector.FindAllStringSubmatch(expr, -1) {
				metric := match[1]
				if metric != metricUp {
					g.failf("undeclared metric %s (allowlist is up only)", metric)
				}
			}
			if !strings.Contains(expr, metricUp) {
				g.failf("undeclared metric: expr %q does not use up", expr)
			}
			for _, jm := range jobLabel.FindAllStringSubmatch(expr, -1) {
				if jm[1] != jobSample {
					g.failf("wrong job: rules use job=%q want %q", jm[1], jobSample)
				}
			}
			if !strings.Contains(expr, `job="sample"`) {
				g.failf("wrong job: rules must select job=%q", jobSample)
			}
		}
	}
	if recording < 1 {
		g.failf("invalid Prometheus rules: at least one recording rule is required")
	}
	if alerting < 1 {
		g.failf("invalid Prometheus rules: at least one alert is required")
	}
}

func (g *gate) scanObservabilityTree() {
	obs := filepath.Join(g.tree, "observability")
	_ = filepath.WalkDir(obs, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			g.failf("cannot walk %s: %v", path, err)
			return nil
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(obs, path)
		base := strings.ToLower(filepath.Base(path))
		ext := strings.ToLower(filepath.Ext(path))
		if ext == ".tf" || strings.HasSuffix(base, ".tf.json") || strings.Contains(base, "terraform") {
			g.failf("Terraform under observability/ is forbidden: %s", rel)
			return nil
		}
		if strings.Contains(base, "iam") && (ext == ".json" || ext == ".tf" || ext == ".yaml" || ext == ".yml") {
			g.failf("IAM under observability/ is forbidden: %s", rel)
			return nil
		}
		if ext != ".yaml" && ext != ".yml" {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		dec := yaml.NewDecoder(strings.NewReader(string(raw)))
		for {
			var doc any
			if err := dec.Decode(&doc); err != nil {
				break
			}
			m := asMap(doc)
			av := asString(m["apiVersion"])
			kind := asString(m["kind"])
			if av == "" && kind == "" {
				continue
			}
			if av == apiVersion && kind == kindContract {
				continue
			}
			g.failf("Kubernetes resource under observability/ is forbidden: %s apiVersion=%s kind=%s", rel, av, kind)
		}
		return nil
	})
}

func (g *gate) noteHighCardinality(m map[string]any) {
	spec := asMap(m["spec"])
	otel := asMap(spec["openTelemetry"])
	attrs := asMap(otel["resourceAttributes"])
	allowed := map[string]bool{}
	for _, k := range requiredAttrs {
		allowed[k] = true
	}
	for k := range attrs {
		if !allowed[k] {
			lk := strings.ToLower(k)
			for _, h := range highCardKeys {
				if lk == h || strings.Contains(lk, h) {
					g.failf("high-cardinality attr %s is forbidden", k)
					return
				}
			}
			g.failf("high-cardinality/unknown OTel attr %s is forbidden", k)
			return
		}
	}
}

func (g *gate) noteInventedSLO(m map[string]any) {
	spec := asMap(m["spec"])
	for k := range spec {
		lk := strings.ToLower(k)
		for _, n := range sloNeedles {
			if strings.Contains(lk, n) {
				g.failf("invented SLO: spec.%s is forbidden", k)
				return
			}
		}
	}
	raw, _ := json.Marshal(spec)
	lower := strings.ToLower(string(raw))
	for _, n := range sloNeedles {
		if strings.Contains(lower, `"`+n) || strings.Contains(lower, n+"_") {
			g.failf("invented SLO: %s is forbidden", n)
			return
		}
	}
}

func (g *gate) loadMap(root, rel string) map[string]any {
	raw, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		return nil
	}
	var doc any
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		g.failf("malformed YAML in %s: %v", rel, err)
		return nil
	}
	return asMap(doc)
}

func exporterNamed(lower, name string) bool {
	return strings.Contains(lower, "\n  "+name+":") || strings.Contains(lower, "\n"+name+":") ||
		strings.Contains(lower, "- "+name) || strings.Contains(lower, "["+name+"]") ||
		strings.Contains(lower, name+":")
}

func asMap(v any) map[string]any {
	switch x := v.(type) {
	case map[string]any:
		return x
	default:
		return map[string]any{}
	}
}

func asString(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case fmt.Stringer:
		return x.String()
	default:
		if v == nil {
			return ""
		}
		return fmt.Sprint(v)
	}
}

func asStringSlice(v any) []string {
	switch x := v.(type) {
	case []any:
		out := make([]string, 0, len(x))
		for _, i := range x {
			out = append(out, asString(i))
		}
		return out
	case []string:
		return x
	default:
		return nil
	}
}

func stringSliceHas(items []string, want string) bool {
	for _, i := range items {
		if i == want {
			return true
		}
	}
	return false
}

func yamlToJSONValue(v any) (any, error) {
	switch x := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(x))
		for k, val := range x {
			cv, err := yamlToJSONValue(val)
			if err != nil {
				return nil, err
			}
			out[k] = cv
		}
		return out, nil
	case map[any]any:
		out := make(map[string]any, len(x))
		for k, val := range x {
			ks, ok := k.(string)
			if !ok {
				return nil, fmt.Errorf("non-string YAML key %T", k)
			}
			cv, err := yamlToJSONValue(val)
			if err != nil {
				return nil, err
			}
			out[ks] = cv
		}
		return out, nil
	case []any:
		out := make([]any, len(x))
		for i, val := range x {
			cv, err := yamlToJSONValue(val)
			if err != nil {
				return nil, err
			}
			out[i] = cv
		}
		return out, nil
	default:
		return v, nil
	}
}
