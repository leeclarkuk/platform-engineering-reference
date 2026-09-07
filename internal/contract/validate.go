package contract

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/santhosh-tekuri/jsonschema/v5"
	"gopkg.in/yaml.v3"

	v1alpha1 "github.com/leeclarkuk/platform-engineering-reference/api/v1alpha1"
)

// File loads YAML from path and validates it as a WorkloadContract.
func File(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return bytes(data)
}

func bytes(data []byte) error {
	var doc interface{}
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("parse YAML: %w", err)
	}
	if doc == nil {
		return fmt.Errorf("empty document")
	}
	raw, err := json.Marshal(doc)
	if err != nil {
		return fmt.Errorf("encode JSON: %w", err)
	}
	var jsonDoc interface{}
	if err := json.Unmarshal(raw, &jsonDoc); err != nil {
		return fmt.Errorf("decode JSON: %w", err)
	}
	schema, err := jsonschema.CompileString("workloadcontract.schema.json", string(v1alpha1.SchemaJSON))
	if err != nil {
		return fmt.Errorf("compile schema: %w", err)
	}
	if err := schema.Validate(jsonDoc); err != nil {
		return fmt.Errorf("invalid WorkloadContract: %w", err)
	}
	return nil
}
