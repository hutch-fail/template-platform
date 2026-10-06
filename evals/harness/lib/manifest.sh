# Consumer manifest (evals/scope.yaml) reader for evals/harness.
# Normative rules: docs/scoping.md (Consumer manifest).
# Shared by list/select and doctor-scope (issue #7).

HERMES_EVAL_MANIFEST_REPO=""
HERMES_EVAL_MANIFEST_LANGUAGES=""
HERMES_EVAL_MANIFEST_ATTACHMENT=""
# Newline-separated parallel lists: id-or-path and reason
HERMES_EVAL_OPT_OUT_KEYS=""
HERMES_EVAL_OPT_OUT_REASONS=""

_hermes_eval_recipe_root() {
  if [[ -n "${HERMES_EVAL_RECIPE_ROOT:-}" && -d "${HERMES_EVAL_RECIPE_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_RECIPE_ROOT}" && pwd)"
  else
    printf '%s\n' "$(cd "${repo_evals}" && pwd)"
  fi
}

# Normalize a git remote URL to github.com/<org>/<repo> (best effort).
_hermes_eval_normalize_repo_id() {
  local raw="$1" s
  s="${raw%.git}"
  case "${s}" in
    git@github.com:*)
      s="github.com/${s#git@github.com:}"
      ;;
    https://github.com/*|http://github.com/*)
      s="${s#https://}"
      s="${s#http://}"
      ;;
    ssh://git@github.com/*)
      s="github.com/${s#ssh://git@github.com/}"
      ;;
  esac
  awk -F/ '{
    if (NF >= 3) print $1"/"$2"/"$3
    else print $0
  }' <<<"${s}"
}

_hermes_eval_infer_manifest_repo() {
  local root url
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    root="${HERMES_EVAL_REPO_ROOT}"
  elif git -C "$(_hermes_eval_recipe_root)" rev-parse --git-dir >/dev/null 2>&1; then
    root="$(_hermes_eval_recipe_root)"
  elif [[ -n "${repo_root:-}" && -d "${repo_root}" ]] \
    && git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1; then
    root="${repo_root}"
  else
    return 0
  fi
  url="$(git -C "${root}" remote get-url origin 2>/dev/null || true)"
  [[ -n "${url}" ]] || return 0
  _hermes_eval_normalize_repo_id "${url}"
}

# Load scope.yaml from recipe root (or soft defaults). Sets HERMES_EVAL_MANIFEST_*.
load_scope_manifest() {
  local recipe manifest
  recipe="$(_hermes_eval_recipe_root)"
  manifest="${recipe}/scope.yaml"
  HERMES_EVAL_MANIFEST_REPO=""
  HERMES_EVAL_MANIFEST_LANGUAGES=""
  HERMES_EVAL_MANIFEST_ATTACHMENT=""
  HERMES_EVAL_OPT_OUT_KEYS=""
  HERMES_EVAL_OPT_OUT_REASONS=""

  if [[ ! -f "${manifest}" ]]; then
    HERMES_EVAL_MANIFEST_REPO="$(_hermes_eval_infer_manifest_repo || true)"
    HERMES_EVAL_MANIFEST_ATTACHMENT="full"
    return 0
  fi

  # shellcheck disable=SC2034
  local parsed
  parsed="$(python3 - "${manifest}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
docs = "docs/scoping.md"
text = path.read_text(encoding="utf-8")
try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

data = None
if yaml is not None:
    data = yaml.safe_load(text)
else:
    # Minimal fallback without PyYAML: enough for evals-scope/v1 fixtures.
    data = {"schema": None, "repo": None, "attachment": None, "languages": [], "opt_out": []}
    cur_opt = None
    in_langs = False
    in_opt = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line.startswith("schema:"):
            data["schema"] = line.split(":", 1)[1].strip().strip("'\"")
            in_langs = in_opt = False
        elif line.startswith("repo:"):
            data["repo"] = line.split(":", 1)[1].strip().strip("'\"")
            in_langs = in_opt = False
        elif line.startswith("attachment:"):
            data["attachment"] = line.split(":", 1)[1].strip().strip("'\"")
            in_langs = in_opt = False
        elif line.startswith("languages:"):
            in_langs, in_opt = True, False
        elif line.startswith("opt_out:"):
            in_langs, in_opt = False, True
        elif in_langs and line.lstrip().startswith("-"):
            data["languages"].append(line.lstrip()[1:].strip().strip("'\""))
        elif in_opt and line.lstrip().startswith("-"):
            cur_opt = {}
            data["opt_out"].append(cur_opt)
            rest = line.lstrip()[1:].strip()
            if rest.startswith("id:"):
                cur_opt["id"] = rest.split(":", 1)[1].strip().strip("'\"")
            elif rest.startswith("path:"):
                cur_opt["path"] = rest.split(":", 1)[1].strip().strip("'\"")
            elif rest.startswith("reason:"):
                cur_opt["reason"] = rest.split(":", 1)[1].strip().strip("'\"")
        elif in_opt and cur_opt is not None and ":" in line:
            key, _, val = line.strip().partition(":")
            cur_opt[key.strip()] = val.strip().strip("'\"")

if not isinstance(data, dict):
    print(f"error: {path}: scope.yaml must be a mapping (see {docs})", file=sys.stderr)
    sys.exit(1)
schema = data.get("schema")
if schema != "evals-scope/v1":
    print(
        f"error: {path}: schema must be evals-scope/v1 (got {schema!r}; see {docs})",
        file=sys.stderr,
    )
    sys.exit(1)

repo = data.get("repo") or ""
att = data.get("attachment") or ""
if not isinstance(att, str):
    print(f"error: {path}: attachment must be a string (see {docs})", file=sys.stderr)
    sys.exit(1)
att = att.strip()
if att and att not in ("ephemeral", "kit", "full"):
    print(
        f"error: {path}: unknown attachment {att!r} (want ephemeral|kit|full; see {docs})",
        file=sys.stderr,
    )
    sys.exit(1)
langs = data.get("languages") or []
if isinstance(langs, str):
    langs = [langs]
opt = data.get("opt_out") or []
if not isinstance(opt, list):
    print(f"error: {path}: opt_out must be a list (see {docs})", file=sys.stderr)
    sys.exit(1)

print(f"repo={repo}")
if att:
    print(f"attachment={att}")
for lang in langs:
    if lang:
        print(f"language={lang}")
for entry in opt:
    if not isinstance(entry, dict):
        print(
            f"error: {path}: opt_out entries must be mappings (see {docs})",
            file=sys.stderr,
        )
        sys.exit(1)
    key = entry.get("id") or entry.get("path") or ""
    reason = entry.get("reason") or ""
    if not key:
        print(
            f"error: {path}: opt_out entry needs id or path (see {docs})",
            file=sys.stderr,
        )
        sys.exit(1)
    if not reason:
        print(
            f"error: {path}: opt_out {key!r} requires reason (see {docs})",
            file=sys.stderr,
        )
        sys.exit(1)
    # Use RS unit separator so reasons may contain spaces.
    print(f"opt_out={key}\x1f{reason}")
PY
)" || die "invalid scope.yaml: ${manifest} (see docs/scoping.md)"

  local line key reason
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    case "${line}" in
      repo=*)
        HERMES_EVAL_MANIFEST_REPO="${line#repo=}"
        ;;
      attachment=*)
        HERMES_EVAL_MANIFEST_ATTACHMENT="${line#attachment=}"
        ;;
      language=*)
        HERMES_EVAL_MANIFEST_LANGUAGES="${HERMES_EVAL_MANIFEST_LANGUAGES}${line#language=}"$'\n'
        ;;
      opt_out=*)
        key="${line#opt_out=}"
        reason="${key#*$'\x1f'}"
        key="${key%%$'\x1f'*}"
        HERMES_EVAL_OPT_OUT_KEYS="${HERMES_EVAL_OPT_OUT_KEYS}${key}"$'\n'
        HERMES_EVAL_OPT_OUT_REASONS="${HERMES_EVAL_OPT_OUT_REASONS}${reason}"$'\n'
        ;;
    esac
  done <<<"${parsed}"

  if [[ -z "${HERMES_EVAL_MANIFEST_REPO}" ]]; then
    HERMES_EVAL_MANIFEST_REPO="$(_hermes_eval_infer_manifest_repo || true)"
  fi
  if [[ -z "${HERMES_EVAL_MANIFEST_ATTACHMENT}" ]]; then
    HERMES_EVAL_MANIFEST_ATTACHMENT="full"
  fi
}

# Scoped doctor hint for the consumer manifest (full make doctor is issue #2).
cmd_doctor_scope() {
  local recipe manifest
  recipe="$(_hermes_eval_recipe_root)"
  manifest="${recipe}/scope.yaml"

  if [[ ! -f "${manifest}" ]]; then
    printf 'hint: missing %s — create evals/scope.yaml (evals-scope/v1) to set repo, languages, and documented opt_out; see docs/scoping.md\n' \
      "${manifest}" >&2
    printf 'hint: example:\n' >&2
    printf '  schema: evals-scope/v1\n' >&2
    printf '  repo: github.com/<org>/<repo>\n' >&2
    printf '  languages: []\n' >&2
    printf '  opt_out: []\n' >&2
  fi

  load_scope_manifest

  # Soft hint: UI cues without languages: ui (bars/select stay declaration-based).
  local product_root
  product_root="$(cd "${recipe}/.." 2>/dev/null && pwd || true)"
  if [[ -n "${product_root}" ]] \
    && { [[ -d "${product_root}/design" ]] \
      || [[ -d "${product_root}/docs/design-system" ]] \
      || compgen -G "${product_root}/scripts/ui-*" >/dev/null 2>&1; }; then
    if [[ ! -f "${manifest}" ]] \
      || ! grep -qE '^[[:space:]]*-[[:space:]]*ui[[:space:]]*$|languages:.*ui' "${manifest}" 2>/dev/null; then
      printf 'hint: UI/design-system cues present — add languages: ui to evals/scope.yaml so language/ui bars select and eval/bars runs them in CI\n' \
        >&2
    fi
  fi

  printf 'doctor-scope: ready\n'
}

# Persist policy for attachment modes (ephemeral / kit / full).
cmd_doctor_attach() {
  # shellcheck source=attachment.sh
  source "${harness_dir}/lib/attachment.sh"
  load_scope_manifest
  local recipe product att slug
  recipe="$(_hermes_eval_recipe_root)"
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    product="${HERMES_EVAL_REPO_ROOT}"
  else
    product="$(cd "${recipe}/.." 2>/dev/null && pwd || printf '%s\n' "${repo_root}")"
  fi
  att="${HERMES_EVAL_MANIFEST_ATTACHMENT:-full}"
  slug="${HERMES_EVAL_MANIFEST_REPO:-}"
  eval_attachment_assert_persist_policy "${product}" "${att}" "${slug}" \
    || die "doctor-attach: persist policy failed (attachment=${att})"
  if [[ "${att}" == "kit" || "${att}" == "ephemeral" ]]; then
    if [[ -n "${slug}" ]]; then
      eval_attachment_refuse_foreign_leaves "${product}" "${slug}" \
        || die "doctor-attach: foreign github.com leaf present (attachment=${att})"
    fi
  fi
  printf 'doctor-attach: ready\n'
}
