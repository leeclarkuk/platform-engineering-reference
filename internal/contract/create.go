package contract

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	v1alpha1 "github.com/leeclarkuk/platform-engineering-reference/api/v1alpha1"
)

var dns1123Label = regexp.MustCompile(v1alpha1.DNS1123LabelPattern)

type workloadContract struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string `yaml:"kind"`
	Metadata   struct {
		Name string `yaml:"name"`
	} `yaml:"metadata"`
	Spec struct {
		Owner          string `yaml:"owner"`
		GoldenPath     string `yaml:"goldenPath"`
		ServiceAccount struct {
			Namespace string `yaml:"namespace"`
			Name      string `yaml:"name"`
		} `yaml:"serviceAccount"`
	} `yaml:"spec"`
}

// CreateOptions are the inputs for platform create.
type CreateOptions struct {
	Name      string
	Owner     string
	Namespace string
	OutDir    string
}

// Create writes a valid WorkloadContract YAML and one Helm chart skeleton.
// It writes no Terraform, GitOps, IAM, kubeconfig, or secrets.
func Create(opts CreateOptions) (contractPath string, err error) {
	name := strings.TrimSpace(opts.Name)
	owner := strings.TrimSpace(opts.Owner)
	namespace := strings.TrimSpace(opts.Namespace)
	if name == "" || owner == "" || namespace == "" {
		return "", fmt.Errorf("create requires --name, --owner and --namespace")
	}
	if !validDNS1123Label(name) {
		return "", fmt.Errorf("--name %q is not an RFC 1123 DNS label (lowercase letters, digits, hyphens)", name)
	}
	if !validDNS1123Label(namespace) {
		return "", fmt.Errorf("--namespace %q is not an RFC 1123 DNS label (lowercase letters, digits, hyphens)", namespace)
	}
	outDir := strings.TrimSpace(opts.OutDir)
	if outDir == "" {
		return "", fmt.Errorf("create requires an output directory")
	}
	if _, err := os.Stat(outDir); err == nil {
		return "", fmt.Errorf("directory already exists: %s", outDir)
	} else if !os.IsNotExist(err) {
		return "", err
	}

	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return "", err
	}

	doc := workloadContract{
		APIVersion: v1alpha1.APIVersion,
		Kind:       v1alpha1.Kind,
	}
	doc.Metadata.Name = name
	doc.Spec.Owner = owner
	doc.Spec.GoldenPath = v1alpha1.GoldenPathHelm
	doc.Spec.ServiceAccount.Namespace = namespace
	doc.Spec.ServiceAccount.Name = name
	body, err := yaml.Marshal(&doc)
	if err != nil {
		return "", err
	}
	contractPath = filepath.Join(outDir, name+".yaml")
	if err := os.WriteFile(contractPath, body, 0o644); err != nil {
		return "", err
	}
	if err := writeHelmSkeleton(outDir, name, owner, namespace); err != nil {
		return "", err
	}
	return contractPath, nil
}

func writeHelmSkeleton(outDir, name, owner, namespace string) error {
	chartDir := filepath.Join(outDir, "templates")
	tplDir := filepath.Join(chartDir, "templates")
	if err := os.MkdirAll(tplDir, 0o755); err != nil {
		return err
	}
	files := map[string]string{
		filepath.Join(chartDir, "Chart.yaml"): fmt.Sprintf(`apiVersion: v2
name: %s
description: Golden-path Helm skeleton (files on disk; not a deploy)
type: application
version: 0.1.0
appVersion: "0.1.0"
`, name),
		filepath.Join(chartDir, "values.yaml"): fmt.Sprintf(`name: %s
owner: %s
replicaCount: 1
image:
  repository: example.local/%s
  tag: "0.1.0"
service:
  port: 8080
serviceAccount:
  name: %s
  namespace: %s
`, name, owner, name, name, namespace),
		filepath.Join(tplDir, "deployment.yaml"):     helmDeployment,
		filepath.Join(tplDir, "service.yaml"):        helmService,
		filepath.Join(tplDir, "serviceaccount.yaml"): helmServiceAccount,
	}
	for path, contents := range files {
		if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func validDNS1123Label(s string) bool {
	if len(s) == 0 || len(s) > v1alpha1.DNS1123LabelMaxLen {
		return false
	}
	return dns1123Label.MatchString(s)
}

// Helm templates use Helm actions. They are files on disk, not a deploy.
const helmDeployment = `apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
  namespace: {{ .Values.serviceAccount.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.name }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      containers:
        - name: {{ .Values.name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
`

const helmService = `apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.name }}
  namespace: {{ .Values.serviceAccount.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.name }}
spec:
  selector:
    app.kubernetes.io/name: {{ .Values.name }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
`

const helmServiceAccount = `apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.serviceAccount.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.name }}
`
