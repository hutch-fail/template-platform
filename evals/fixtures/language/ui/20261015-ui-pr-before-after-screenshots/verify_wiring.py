#!/usr/bin/env python3
"""Hermetic wiring asserts for the UI before/after PR screenshot gate."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def resolve_kit(here: Path) -> Path:
    env_kit = os.environ.get("HERMES_EVAL_KIT") or ""
    if env_kit and (Path(env_kit) / "tests/unit/assert_pr_has_eval_pack.sh").is_file():
        return Path(env_kit).resolve()
    candidates = [
        os.environ.get("HERMES_EVAL_REPO_ROOT", "") + "/evals",
        os.environ.get("HERMES_EVAL_REPO_ROOT", ""),
        os.environ.get("EVALS_ROOT", ""),
        str(here / "../../../.."),
    ]
    for cand in candidates:
        if not cand or cand == "/evals":
            continue
        p = Path(cand)
        if (p / "tests/unit/assert_pr_has_eval_pack.sh").is_file():
            return p.resolve()
    raise SystemExit("error: cannot resolve evals kit (set HERMES_EVAL_KIT)")


def must_contain(path: Path, needle: str, msg: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle not in text:
        raise SystemExit(f"error: {msg}")


def main() -> int:
    here = Path(__file__).resolve().parent
    kit = resolve_kit(here)
    assert_sh = kit / "tests/unit/assert_pr_has_eval_pack.sh"
    process = kit / "PROCESS.md"
    evals_doc = kit / "docs/evals.md"
    eval_ci = kit / ".github/workflows/eval-ci.yml"
    pack_gate = kit / ".github/workflows/eval-pack-gate.yml"
    goal = kit / "goals/language/ui/20261015-ui-pr-before-after-screenshots.md"

    for path, label in (
        (goal, "missing pre-run goal"),
        (assert_sh, "missing assert_pr_has_eval_pack.sh"),
        (process, "missing PROCESS.md"),
        (evals_doc, "missing docs/evals.md"),
        (eval_ci, "missing eval-ci.yml"),
        (pack_gate, "missing eval-pack-gate.yml"),
    ):
        if not path.exists():
            raise SystemExit(f"error: {label}")

    must_contain(process, "UI/UX PR screenshots", "PROCESS.md must document UI/UX PR screenshots")
    must_contain(process, "UI before/after: n/a", "PROCESS.md must document the n/a waiver")
    must_contain(evals_doc, "EVALS_PR_BODY", "docs/evals.md must mention EVALS_PR_BODY")
    must_contain(assert_sh, "path_is_ui_ux", "assert must define path_is_ui_ux")
    must_contain(assert_sh, "pr_body_has_ui_screenshots", "assert must define pr_body_has_ui_screenshots")
    must_contain(assert_sh, "ui_screenshot_gate_problem", "assert must define ui_screenshot_gate_problem")
    must_contain(eval_ci, "EVALS_PR_BODY", "eval-ci.yml must set EVALS_PR_BODY")
    must_contain(pack_gate, "EVALS_PR_BODY", "eval-pack-gate.yml must set EVALS_PR_BODY")
    must_contain(
        eval_ci,
        "github.event.pull_request.body",
        "eval-ci.yml must pass pull_request.body into EVALS_PR_BODY",
    )
    must_contain(
        eval_ci,
        "ci-eval-select-prepare.sh",
        "eval-ci.yml must call ci-eval-select-prepare.sh",
    )

    rc = subprocess.call(["bash", str(assert_sh)])
    if rc != 0:
        raise SystemExit("error: assert_pr_has_eval_pack.sh self-test failed")
    print("ui_pr_before_after_screenshots_ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
