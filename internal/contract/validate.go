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
	return Bytes(data)
}

// Bytes validates WorkloadContract YAML against the JSON Schema.
func Bytes(data []byte) error {
	var doc interface{}
	if err := yaml.Unmarshal(data, &doc); err != nil {
		return fmt.Errorf("parse YAML: %w", err)
	}
	if doc == nil {
		return fmt.Errorf("empty document")
	}
	instance, err := yamlToJSONValue(doc)
	if err != nil {
		return err
	}
	raw, err := json.Marshal(instance)
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

func yamlToJSONValue(v interface{}) (interface{}, error) {
	switch x := v.(type) {
	case map[string]interface{}:
		out := make(map[string]interface{}, len(x))
		for k, val := range x {
			cv, err := yamlToJSONValue(val)
			if err != nil {
				return nil, err
			}
			out[k] = cv
		}
		return out, nil
	case map[interface{}]interface{}:
		out := make(map[string]interface{}, len(x))
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
	case []interface{}:
		out := make([]interface{}, len(x))
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
