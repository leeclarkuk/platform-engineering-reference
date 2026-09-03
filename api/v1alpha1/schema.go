package v1alpha1

import _ "embed"

const (
	// APIVersion is the WorkloadContract apiVersion.
	APIVersion = "platform.engineering.reference/v1alpha1"
	// Kind is the WorkloadContract kind.
	Kind = "WorkloadContract"
	// GoldenPathHelm is the only legal spec.goldenPath value (ADR-0004).
	GoldenPathHelm = "helm"
	// DNS1123LabelPattern is the Kubernetes DNS-1123 label pattern used for
	// metadata.name. Max length is 63.
	DNS1123LabelPattern = `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
	// DNS1123LabelMaxLen is the maximum length of a DNS-1123 label.
	DNS1123LabelMaxLen = 63
)

// SchemaJSON is the JSON Schema for kind WorkloadContract.
//
//go:embed workloadcontract.schema.json
var SchemaJSON []byte
