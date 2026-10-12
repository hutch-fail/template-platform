#!/usr/bin/env bash
# Wrapper-only OptMem tests (does not re-test upstream memo cover).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
wrap="${ROOT}/optmem/repo-memo"
memo="${ROOT}/optmem/upstream/memo"
fail=0
miss() { printf '✗ %s\n' "$*" >&2; fail=1; }

[[ -x "${wrap}" ]] || miss "repo-memo not executable"
[[ -x "${memo}" ]] || miss "upstream memo not executable"
grep -q '3dc120d01be3115ef6267eab4103e7909fc830d6227b549f20991ba999ee9ffb' "${ROOT}/optmem/PINNED" \
  || miss "PINNED missing expected sha256"
got="$(sha256sum "${memo}" | awk '{print $1}')"
want="$(awk '/^memo_sha256:/{print $2}' "${ROOT}/optmem/PINNED")"
[[ "${got}" == "${want}" ]] || miss "memo sha256 drift"

python3 - "${ROOT}" <<'PY' || miss "python wrapper tests failed"
import datetime, os, subprocess, sys, tempfile, shutil
from pathlib import Path
root = Path(sys.argv[1])
ns = {"__name__": "repomemo"}
exec(compile((root / "optmem" / "repo-memo").read_text(encoding="utf-8"), "repo-memo", "exec"), ns)
assert ns["sanitize_branch"]("feat/optmem") == "feat-optmem"
assert ns["sanitize_branch"]("a//b") == "a-b"
ws = Path(tempfile.mkdtemp())
subprocess.check_call(["git", "init", "-q"], cwd=ws)
subprocess.check_call(["git", "config", "user.email", "t@t"], cwd=ws)
subprocess.check_call(["git", "config", "user.name", "t"], cwd=ws)
subprocess.check_call(["git", "commit", "--allow-empty", "-q", "-m", "i"], cwd=ws)
subprocess.check_call(["git", "checkout", "-q", "-b", "feat/demo"], cwd=ws)
os.environ["HERMES_EVAL_KIT"] = str(root)
env = os.environ.copy()
env.pop("OPTMEM_RECONCILE", None)
r = subprocess.run([sys.executable, str(root / "optmem" / "repo-memo"), "init"], cwd=ws, env=env, capture_output=True, text=True)
assert r.returncode == 0, r.stderr
assert (ws / ".optmem" / "main" / "memory").is_dir()
assert ".lock" in (ws / ".optmem" / ".gitignore").read_text()
r = subprocess.run([sys.executable, str(root / "optmem" / "repo-memo"), "note", "hello from shard"], cwd=ws, env=env, capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
shards = [p for p in (ws / ".optmem" / "shards").iterdir() if p.is_dir() and not p.name.startswith(".")]
assert len(shards) == 1, (shards, r.stdout, r.stderr)
assert ns["SHARD_RE"].match(shards[0].name), shards[0].name
main_log = (ws / ".optmem" / "main" / "memory" / "LOG.txt").read_bytes()
assert len(main_log) == 0, (len(main_log), main_log[:80], list((ws/".optmem").rglob("*")))
r = subprocess.run([sys.executable, str(root / "optmem" / "repo-memo"), "note", "second line here"], cwd=ws, env=env, capture_output=True, text=True)
assert r.returncode == 0, r.stderr
shards2 = [p for p in (ws / ".optmem" / "shards").iterdir() if p.is_dir() and not p.name.startswith(".")]
assert len(shards2) == 1
sid = ns["new_shard_id"](ws, datetime.datetime(2026, 10, 5, 1, 2, 3, tzinfo=datetime.timezone.utc))
assert sid.startswith("20261005T010203Z-feat-demo")
r = subprocess.run([sys.executable, str(root / "optmem" / "repo-memo"), "reconcile"], cwd=ws, env=env, capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
assert list((ws / ".optmem" / "shards").glob("[0-9]*")) == []
assert len((ws / ".optmem" / "main" / "memory" / "LOG.txt").read_bytes()) >= 320
r = subprocess.run([sys.executable, str(root / "optmem" / "repo-memo"), "doctor"], cwd=ws, env=env, capture_output=True, text=True)
assert r.returncode == 0, r.stderr
nest = ws / "evals"
nest.mkdir()
(nest / "harness").mkdir()
(nest / "harness" / "goal.sh").write_text("#!/bin/sh\n")
(nest / ".optmem").mkdir()
assert ns["nested_evals_store"](ws) is True
print("ok")
PY

grep -q 'exclude '\''.optmem/'\''' "${ROOT}/scripts/sync-pull.sh" \
  || grep -q 'exclude .optmem/' "${ROOT}/scripts/sync-pull.sh" \
  || miss "sync-pull must exclude .optmem/"

grep -Fq 'optmem-reconcile-${{ github.repository }}' "${ROOT}/.github/workflows/optmem-reconcile.yml" \
  || miss "hub workflow missing concurrency group"
grep -Fq 'cancel-in-progress: false' "${ROOT}/.github/workflows/optmem-reconcile.yml" \
  || miss "hub workflow must not cancel in-progress reconcile"
grep -Fq 'optmem-reconcile-${{ github.repository }}' "${ROOT}/templates/github-workflows/optmem-reconcile.yml" \
  || miss "template workflow missing concurrency group"

chmod +x "${ROOT}/tests/unit/assert_optmem_pr_diff.sh"
# PR diff skip when no main change on this helper without git range — still executable
[[ -x "${ROOT}/tests/unit/assert_optmem_pr_diff.sh" ]] || miss "assert_optmem_pr_diff not executable"

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi
printf 'test_optmem_wrapper ok\n'
exit 0
