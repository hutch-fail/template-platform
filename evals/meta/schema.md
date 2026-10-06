# Candidate YAML schema (meta-eval)

```yaml
id: short-kebab-id
description: >
  Human-readable purpose of the eval claim.
criterion: >
  PASS if … FAIL otherwise.  # operational boundary required for binary_outcome
inputs:
  field_name:
    type: string | integer | boolean | object | array
    description: What evidence this field supplies
result:
  type: boolean
discrimination:          # required when definition is expected to PASS
  positive:
    field_name: "example that must PASS"
  negative:
    field_name: "example that must FAIL"
```

## Calibration-only `expected`

```yaml
expected:
  definition:
    decidable: true|false
    executable: true|false
    single_claim: true|false
    binary_outcome: true|false
    pass: true|false
  discrimination:
    status: ran | skipped
    positive_result: true|false   # when status: ran
    negative_result: true|false
    pass: true|false
  pass: true|false
```

### Dimension meanings

| Key | Meaning |
| --- | --- |
| `decidable` | There is a fact of the matter under the criterion |
| `executable` | Declared inputs contain enough evidence |
| `single_claim` | One independently falsifiable property |
| `binary_outcome` | PASS vs FAIL is operationally defined |

`executable` fails when the criterion needs evidence not present in `inputs`
(e.g. “all claims factually correct” with only `response`).
