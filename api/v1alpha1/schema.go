package v1alpha1

import _ "embed"

const (
	// APIVersion is the WorkloadContract apiVersion.
	APIVersion = "platform.engineering.reference/v1alpha1"
	// Kind is the WorkloadContract kind.
	Kind = "WorkloadContract"
	// GoldenPathHelm is the only legal spec.goldenPath value (ADR-0004).
	GoldenPathHelm = "helm"
)

// SchemaJSON is the JSON Schema for kind WorkloadContract.
//
//go:embed workloadcontract.schema.json
var SchemaJSON []byte
