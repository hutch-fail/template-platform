#!/usr/bin/env bash
# F2P: product root must declare opentofu in evals/scope.yaml.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-}"
if [[ -z "${root}" || ! -d "${root}" ]]; then
  printf 'HERMES_EVAL_REPO_ROOT unset or not a directory\n' >&2
  exit 1
fi

manifest=""
if [[ -f "${root}/evals/scope.yaml" ]]; then
  manifest="${root}/evals/scope.yaml"
elif [[ -f "${root}/scope.yaml" ]] && [[ -d "${root}/harness" || -d "${root}/goals" ]]; then
  # Hub kit as product root
  manifest="${root}/scope.yaml"
fi

if [[ -z "${manifest}" ]]; then
  printf 'missing evals/scope.yaml under %s (OpenTofu consumers must declare languages: opentofu)\n' "${root}" >&2
  exit 1
fi

python3 - "${manifest}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

if yaml is not None:
    data = yaml.safe_load(text)
else:
    data = {"schema": None, "languages": []}
    in_langs = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line.startswith("schema:"):
            data["schema"] = line.split(":", 1)[1].strip().strip("'\"")
            in_langs = False
        elif line.startswith("languages:"):
            in_langs = True
        elif in_langs and line.lstrip().startswith("-"):
            data["languages"].append(line.lstrip()[1:].strip().strip("'\""))
        elif ":" in line and not line.startswith(" "):
            in_langs = False

if not isinstance(data, dict):
    print(f"error: {path}: scope.yaml must be a mapping", file=sys.stderr)
    sys.exit(1)
if data.get("schema") != "evals-scope/v1":
    print(f"error: {path}: schema must be evals-scope/v1", file=sys.stderr)
    sys.exit(1)
langs = data.get("languages") or []
if isinstance(langs, str):
    langs = [langs]
if "opentofu" not in langs:
    print(f"error: {path}: languages must include opentofu (got {langs!r})", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
