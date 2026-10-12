#!/usr/bin/env python3
"""Deterministic eval-pack quality lint (Tier 1).

Checks goal markdown structure, executive prose, grading, holdout signal,
fixture_dir resolution, optional sibling *-result.md proof shape,
launch-path (in-session GUI claims must grade openbox/menu + DISPLAY, not
only PATH/dpkg), use-path / kick-the-tires (behavior claims must exercise
the entrypoint, not only grep that it exists; reconverge needs a second pass),
and live-path (Host URL / portless / dashboard claims must grade doctor /
test/smoke / make up wiring — not only grep that a probe script mentions curl).

Exit 0 on pass; 1 on structural violations. Never prints secrets.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = (
    "Decision",
    "User outcome",
    "Success criteria",
    "Dataset",
    "Grading",
    "Acceptance gates",
)

GRADER_RE = re.compile(r"(?i)\b(program|person|model|check\.sh|p2p-smoke|grader)\b")
HOLDOUT_RE = re.compile(
    r"(?i)\b(hold[- ]?out|holdout|train\s*/\s*test|train\s*\|\s*test|train.?test)\b"
)
PROOF_CUE_RE = re.compile(
    r"(?i)(```|make\s+eval/|exit\s*(code|=)|assert-red|eval/verify|eval/bars|certified.?red|verdict=)"
)
VERDICT_RE = re.compile(r"(?i)\b(Adopt|Hold|Inconclusive|Verdict|Recommendation)\b")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")
# Guest GUI launch claims (not the bare word "desktop").
DESKTOP_LAUNCH_CLAIM_RE = re.compile(
    r"(?i)\b(openbox|menu\.d|kasm(?:vnc)?|desktop\.localhost|"
    r"desktop\s+ide|in-session\s+menu|kasm\s+display)\b"
)
LAUNCH_PATH_TOKEN_RE = re.compile(r"(?i)(menu\.d|menu\.xml|openbox|\.desktop)")
DISPLAY_TOKEN_RE = re.compile(r"(?i)(\bDISPLAY\b|desktop/env)")
PATH_ONLY_RE = re.compile(r"(?i)(command\s+-v|\bwhich\b|dpkg-query)")
PROBE_SCRIPT_RE = re.compile(r"scripts/probe-[A-Za-z0-9._-]+\.sh")
# Operator / feature *use* claims (not file-presence / wiring greps).
USE_PATH_CLAIM_RE = re.compile(
    r"(?i)("
    r"\bkick\s+the\s+tires\b|"
    r"\bsmoke\s+(?:test|check|path)\b|"
    r"\breceives?\b.{0,48}\b(?:seed|invent|skills?)\b|"
    r"\b(?:seed|invent)\b.{0,48}\b(?:receives?|survives?|works?|copies?)\b|"
    r"\bmirror\b.{0,48}\bdesiredSkills\b|"
    r"\bdesiredSkills\b|"
    r"\bbind(?:[- ]mount)?\b.{0,48}\b(?:onto|skills|invent)\b|"
    r"\bensure[-_]?(?:invent|seed|user|binds?|persona)\b|"
    r"\bensure_invent_bind\b|"
    r"\b(?:profile|hermes|seat)[- ]?reconcile\b|"
    r"\bmake\s+(?:up|ensure|bootstrap)\b.{0,40}\b(?:works?|converges?|green|ok)\b|"
    r"\b(?:heal|bootstrap)\b.{0,64}\b(?:works?|installs?|runs?|ok)\b|"
    r"\bidempotent\b|"
    r"\bre-?(?:run|ensure|apply|enter)\b|"
    r"\boperators?\s+(?:can|run|use)\b.{0,96}\b"
    r"(?:ensure|heal|reconcile|bootstrap|seed|mirror|bind|apply)\b"
    r")"
)
USE_PATH_ESCAPE_RE = re.compile(
    r"(?i)("
    r"use[- ]path\s+out\s+of\s+scope|"
    r"kick[- ]the[- ]tires\s+out\s+of\s+scope|"
    r"(?:grades?|covers?|this\s+pack\s+is)\s+wiring[- ]only|"
    r"wiring[- ]only\s+(?:grades?|fixture|check|bar|pack)\b|"
    r"(?:grades?|covers?)\s+presence[- ]only|"
    r"static\s+grep\s+only\s+(?:out\s+of\s+scope|grades?|bar)|"
    r"does\s+not\s+exercise\s+(?:the\s+)?(?:feature|entrypoint|operator)|"
    r"file[- ]presence\s+only\s+(?:out\s+of\s+scope|grades?)|"
    r"single[- ]shot\s+only|"
    r"cold[- ]start\s+only|"
    r"reconverge\s+out\s+of\s+scope|"
    r"idempotent(?:\s+re-?entry)?\s+out\s+of\s+scope"
    r")"
)
# Entry points operators actually run / reconcile calls.
USE_PATH_ENTRY_RE = re.compile(
    r"(?i)\b("
    r"ensure_invent_bind|ensure_seed_skills|mirror_profile_skills|"
    r"ensure-invent-binds|backfill-profile-skills|mirror-profile-skills|"
    r"make\s+(?:up|ensure|bootstrap)|"
    r"paperclip_invent_binds_install|paperclip_skills_mirror_install"
    r")\b"
)
GREP_FQ_RE = re.compile(
    r"""(?i)grep\s+(?:-[A-Za-z]*F[A-Za-z]*\s+|'|")"""
)
EXERCISE_CUE_RE = re.compile(
    r"(?i)("
    r"ensure_invent_bind\s*\(|ensure_seed_skills\s*\(|mirror_profile_skills\s*\(|"
    r"bash\s+[^\n]*(?:ensure-invent-binds|backfill-profile-skills|mirror-profile-skills)|"
    r"(?:^|\s)\./scripts/|"
    r"\bmake\s+(?:up|ensure|bootstrap)\b|"
    r"\bharbor\s+run\b|"
    r"kick[-_]?the[-_]?tires|#\s*use-path|"
    r"paperclip_invent_binds_install\s*\(|paperclip_skills_mirror_install"
    r")"
)
REENTRY_CUE_RE = re.compile(
    r"(?i)("
    r"\br2\s*=|\bsecond\s+pass\b|\bidempotent\b|"
    r"re-?(?:run|ensure|enter|apply)\b|"
    r"ensure_invent_bind\s*\([^)]*\)[\s\S]{0,400}?ensure_invent_bind\s*\(|"
    r"ensure_seed_skills\s*\([^)]*\)[\s\S]{0,400}?ensure_seed_skills\s*\("
    r")"
)
# Host / portless / dashboard L0 claims (operator green path = doctor + smoke).
LIVE_PATH_CLAIM_RE = re.compile(
    r"(?i)("
    r"\b[\w.-]+\.localhost\b|"
    r"/dashboard\b|"
    r"\bportless\b|"
    r"\bcurl\b.{0,80}\b(?:health|/health|200)\b|"
    r"\bhttps?://[^\s`]+\.localhost|"
    r"\b(?:host|portless)\s+(?:probe|smoke|curl)\b|"
    r"\boperators?\s+(?:can|open|hit|use)\b.{0,96}\b(?:\.localhost|/dashboard)\b"
    r")"
)
LIVE_PATH_ESCAPE_RE = re.compile(
    r"(?i)("
    r"live[- ]path\s+out\s+of\s+scope|"
    r"hermetic\s+wiring\s+only|"
    r"(?:grades?|covers?|this\s+pack\s+is)\s+wiring[- ]only|"
    r"wiring[- ]only\s+(?:grades?|fixture|check|bar|pack)\b|"
    r"does\s+not\s+prove\s+(?:live|portless|host)\b|"
    r"live\s+(?:curl|portless|URL)\s+(?:is\s+)?hold[- ]?out|"
    r"URL\s+works?\s+out\s+of\s+scope|"
    r"probe[- ]script\s+grep\s+only"
    r")"
)
LIVE_EXERCISE_CUE_RE = re.compile(
    r"(?i)("
    r"\btest[-_]?smoke\b|"
    r"\btest/smoke\b|"
    r"\bmake\s+(?:up|doctor|test/smoke)\b|"
    r"\bdoctor\b.{0,40}\b(?:feature_port|FEATURES)\b|"
    r"bash\s+[^\n]*probe-[A-Za-z0-9._-]+\.sh|"
    r"scripts/test-smoke\.sh|"
    r"probe-[A-Za-z0-9._-]+\.sh[^\n]{0,80}(?:test-smoke|test/smoke)|"
    r"test-smoke\.sh[^\n]{0,120}probe-|"
    r"#\s*live-path|"
    r"kick[-_]?the[-_]?tires\s+smoke"
    r")"
)
GREP_PROBE_ONLY_RE = re.compile(
    r"(?i)grep\s+[^\n]*(?:probe-[A-Za-z0-9._-]+\.sh|/dashboard|\.localhost|curl)"
)
LIVE_PROOF_TIER_RE = re.compile(r"(?i)\blive[- ]?proof\b")
PASS_RECOMMEND_RE = re.compile(
    r"(?:\*\*Recommendation:\*\*\s*|Recommendation:\s*|Verdict:\s*)(PASS|Adopt)\b",
    re.I | re.M,
)


def _section(text: str, name: str) -> str:
    pat = rf"^# {re.escape(name)}\s*\n(.*?)(?=^# |\Z)"
    m = re.search(pat, text, re.M | re.S)
    return m.group(1).strip() if m else ""


def _frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    block = text[3:end]
    out: dict[str, str] = {}
    for line in block.splitlines():
        if ":" not in line or line.strip().startswith("#"):
            continue
        k, v = line.split(":", 1)
        out[k.strip()] = v.strip().strip("'\"")
    return out


def _sentences(prose: str) -> list[str]:
    cleaned = re.sub(r"\|.*\|", " ", prose)  # drop table rows
    cleaned = re.sub(r"^[-*].*$", " ", cleaned, flags=re.M)
    parts = SENTENCE_SPLIT.split(cleaned.strip())
    return [p.strip() for p in parts if len(p.strip()) > 20]


def _has_executive_lead(text: str, decision: str, user_outcome: str) -> bool:
    if re.search(r"^# Executive overview\s*$", text, re.M):
        overview = _section(text, "Executive overview")
        return len(_sentences(overview)) >= 2
    return len(_sentences(decision)) >= 2 and len(_sentences(user_outcome)) >= 2


def discover_goals(scan_root: Path) -> list[Path]:
    roots: list[Path] = []
    for cand in (scan_root / "goals", scan_root / "evals" / "goals"):
        if cand.is_dir():
            roots.append(cand)
    found: list[Path] = []
    for root in roots:
        for path in sorted(root.rglob("*.md")):
            name = path.name
            if name.endswith("-result.md") or name.startswith("_"):
                continue
            if name in {"PROCESS.md", "README.md"}:
                continue
            found.append(path)
    return found


def resolve_fixture_dir(scan_root: Path, fixture_dir: str) -> Path | None:
    if not fixture_dir:
        return None
    raw = fixture_dir.strip().rstrip("/")
    candidates = [
        scan_root / raw,
        scan_root / raw.removeprefix("evals/"),
        scan_root.parent / raw.removeprefix("evals/"),
    ]
    # Hub kit: scan_root is product; fixture under kit when bars run from kit copy.
    kit = Path(__file__).resolve().parents[2]
    candidates.append(kit / raw.removeprefix("evals/"))
    for c in candidates:
        if c.is_dir():
            return c
    return None


def _product_roots(scan_root: Path) -> list[Path]:
    kit = Path(__file__).resolve().parents[2]
    roots = [scan_root, scan_root.parent, kit]
    if (scan_root / "evals").is_dir():
        roots.append(scan_root / "evals")
    seen: list[Path] = []
    for root in roots:
        resolved = root.resolve()
        if resolved not in seen:
            seen.append(resolved)
    return seen


def _read_if_file(path: Path) -> str:
    if path.is_file():
        return path.read_text(encoding="utf-8")
    return ""


def _launch_path_sources(_path: Path, scan_root: Path, text: str, fm: dict[str, str]) -> str:
    chunks: list[str] = []
    fixture_dir = fm.get("fixture_dir", "")
    f2p = fm.get("f2p_check", "")
    p2p = fm.get("p2p_check", "")
    resolved = resolve_fixture_dir(scan_root, fixture_dir) if fixture_dir else None
    if resolved is not None and f2p:
        chunks.append(_read_if_file(resolved / f2p))
    # Live/use-path graders often live in p2p-smoke (kick-the-tires), not F2P.
    if resolved is not None and p2p:
        chunks.append(_read_if_file(resolved / p2p))
    names = set(PROBE_SCRIPT_RE.findall(text))
    if resolved is not None and f2p:
        names.update(PROBE_SCRIPT_RE.findall(_read_if_file(resolved / f2p)))
    if resolved is not None and p2p:
        names.update(PROBE_SCRIPT_RE.findall(_read_if_file(resolved / p2p)))
    for name in names:
        for root in _product_roots(scan_root):
            found = _read_if_file(root / name)
            if found:
                chunks.append(found)
                break
            found = _read_if_file(root.parent / name)
            if found:
                chunks.append(found)
                break
    return "\n".join(chunks)


def _has_cli_escape(limitations: str, scope: str) -> bool:
    blob = f"{limitations}\n{scope}"
    if re.search(
        r"(?i)(desktop ide.{0,80}out of scope|openbox(?:\s+launch)?.{0,80}out of scope|"
        r"not a graphical session)",
        blob,
    ):
        return True
    for line in blob.splitlines():
        if re.search(r"(?i)does not .{0,60}cli[- ]only", line):
            continue
        if re.search(r"(?i)\bcli[- ]only\b", line):
            return True
    return False


def _launch_path_errors(_path: Path, scan_root: Path, text: str, fm: dict[str, str]) -> list[str]:
    if not DESKTOP_LAUNCH_CLAIM_RE.search(text):
        return []
    limitations = _section(text, "Limitations")
    scope = _section(text, "Scope")
    if _has_cli_escape(limitations, scope):
        return []
    blob = _launch_path_sources(_path, scan_root, text, fm)
    if not blob.strip():
        return [
            "launch-path: desktop-launch claim requires an f2p_check (or named "
            "scripts/probe-*.sh) that grades menu/launcher, not only PATH"
        ]
    errors: list[str] = []
    if not LAUNCH_PATH_TOKEN_RE.search(blob):
        errors.append(
            "launch-path: desktop-launch claim requires fixture/probe tokens "
            "menu.d|menu.xml|openbox|.desktop (PATH/dpkg is not a launch path)"
        )
    if not DISPLAY_TOKEN_RE.search(blob):
        errors.append(
            "launch-path: desktop-launch claim requires DISPLAY or desktop/env "
            "in the fixture or named probe"
        )
    if PATH_ONLY_RE.search(blob) and not LAUNCH_PATH_TOKEN_RE.search(blob):
        errors.append(
            "launch-path: command -v / which / dpkg-query cannot be the only "
            "install proof for an in-session GUI launch claim"
        )
    return errors


def _has_use_path_escape(limitations: str, scope: str) -> bool:
    return bool(USE_PATH_ESCAPE_RE.search(f"{limitations}\n{scope}"))


def _use_claim_blob(text: str) -> str:
    # Grade only outcome/criteria rows — Executive/Decision often narrate the
    # miss ("make up was only grepped") without claiming this pack proves it.
    return "\n".join(
        (
            _section(text, "User outcome"),
            _section(text, "Success criteria"),
            _section(text, "Acceptance gates"),
        )
    )


def _use_path_errors(_path: Path, scan_root: Path, text: str, fm: dict[str, str]) -> list[str]:
    """Reject wiring-only greps when the pack claims operators use the feature.

    Kick-the-tires: exercise the entrypoint (call / make / script). When the
    fixture already exercises ensure/seed/heal-class entrypoints, also require
    a re-entry cue (second call / idempotent) unless Limitations scopes
    single-shot / reconverge out.
    """
    claim_blob = _use_claim_blob(text)
    if not USE_PATH_CLAIM_RE.search(claim_blob):
        return []
    limitations = _section(text, "Limitations")
    scope = _section(text, "Scope")
    if _has_use_path_escape(limitations, scope):
        return []

    blob = _launch_path_sources(_path, scan_root, text, fm)
    if not blob.strip():
        return [
            "use-path: behavior / kick-the-tires claim requires an f2p_check "
            "(or named scripts/probe-*.sh) that exercises the feature — not "
            "only grepping that the entrypoint exists "
            "(PROCESS.md “Use path vs wiring path”)"
        ]

    errors: list[str] = []
    has_exercise = bool(EXERCISE_CUE_RE.search(blob))
    has_entry_mention = bool(USE_PATH_ENTRY_RE.search(blob) or USE_PATH_ENTRY_RE.search(claim_blob))
    grep_heavy = len(GREP_FQ_RE.findall(blob)) >= 2

    if not has_exercise:
        if grep_heavy or has_entry_mention or GREP_FQ_RE.search(blob):
            errors.append(
                "use-path: behavior claim is graded only by wiring greps "
                "(grep -Fq / presence). Kick the tires: call the entrypoint, "
                "run the operator script, or make the documented target, then "
                "assert an observable. Escape: Limitations “wiring-only” / "
                "“use-path out of scope”"
            )
        else:
            errors.append(
                "use-path: behavior claim needs an exercise cue in the fixture "
                "(function call, ./scripts/…, or make up|ensure|bootstrap). "
                "Grep-only presence checks are not kick-the-tires"
            )

    if has_exercise and USE_PATH_ENTRY_RE.search(blob) and not REENTRY_CUE_RE.search(blob):
        if not re.search(
            r"(?i)(single[- ]shot|cold[- ]start\s+only|reconverge\s+out)",
            f"{limitations}\n{scope}",
        ):
            errors.append(
                "use-path: fixture exercises an ensure/seed/heal-class "
                "entrypoint once but never re-enters (idempotent second pass). "
                "Operator reconverge (make ensure / re-bind) is ungraded — add "
                "a second call or Limitations “single-shot only” / "
                "“reconverge out of scope”"
            )

    return errors


def _has_live_path_escape(limitations: str, scope: str) -> bool:
    return bool(LIVE_PATH_ESCAPE_RE.search(f"{limitations}\n{scope}"))


def _live_claim_blob(text: str) -> str:
    return "\n".join(
        (
            _section(text, "User outcome"),
            _section(text, "Success criteria"),
            _section(text, "Acceptance gates"),
        )
    )


def _live_path_errors(_path: Path, scan_root: Path, text: str, fm: dict[str, str]) -> list[str]:
    """Reject probe-script greps when the pack claims a Host URL / portless L0.

    Tire-kick for L0 is the product doctor / test/smoke / make up path.
    Grepping that probe-foo.sh mentions curl is wiring, not smoke.
    """
    claim_blob = _live_claim_blob(text)
    if not LIVE_PATH_CLAIM_RE.search(claim_blob):
        return []
    limitations = _section(text, "Limitations")
    scope = _section(text, "Scope")
    if _has_live_path_escape(limitations, scope):
        return []

    blob = _launch_path_sources(_path, scan_root, text, fm)
    if not blob.strip():
        return [
            "live-path: Host URL / portless / dashboard claim requires an "
            "f2p_check (or p2p) that grades doctor/test-smoke/make up wiring "
            "— not only grepping that a probe script mentions curl "
            "(PROCESS.md “Live path vs probe-script path”)"
        ]

    errors: list[str] = []
    has_exercise = bool(LIVE_EXERCISE_CUE_RE.search(blob))
    grep_probe_only = bool(GREP_PROBE_ONLY_RE.search(blob)) and not has_exercise

    if not has_exercise:
        errors.append(
            "live-path: Host/portless claim is graded without doctor/test-smoke/"
            "make up exercise cues. Wire the probe into test-smoke (or doctor) "
            "and assert that arm in F2P — or Limitations “live-path out of "
            "scope” / “hermetic wiring only” (and do not PASS the URL claim)"
        )
    if grep_probe_only:
        errors.append(
            "live-path: fixture only greps the probe script for curl/"
            ".localhost — that is wiring. Kick the tires via test/smoke "
            "(or make up) invoking the probe"
        )

    return errors


def _live_result_errors(path: Path, text: str) -> list[str]:
    """PASS/Adopt + URL claim needs live-proof tier when sibling result exists."""
    claim_blob = _live_claim_blob(text)
    if not LIVE_PATH_CLAIM_RE.search(claim_blob):
        return []
    limitations = _section(text, "Limitations")
    scope = _section(text, "Scope")
    if _has_live_path_escape(limitations, scope):
        return []
    result_path = path.with_name(path.stem + "-result.md")
    if not result_path.is_file():
        return []
    rtext = result_path.read_text(encoding="utf-8")
    if not PASS_RECOMMEND_RE.search(rtext):
        return []
    if LIVE_PROOF_TIER_RE.search(rtext):
        return []
    if re.search(r"(?i)make\s+test/smoke|make\s+up\b", rtext) and re.search(
        r"(?i)live[- ]?proof|HTTP\s*2|probe-headroom|test-smoke", rtext
    ):
        return []
    return [
        f"live-path: sibling result {result_path.name} recommends PASS/Adopt "
        "for a Host/portless claim without a Manual verification tier "
        "live-proof (run make test/smoke or make up; attach smoke log)"
    ]


def lint_goal(
    path: Path,
    *,
    scan_root: Path,
    require_executive: bool = True,
) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    fm = _frontmatter(text)

    for sec in REQUIRED_SECTIONS:
        if not re.search(rf"^# {re.escape(sec)}\s*$", text, re.M):
            errors.append(f"missing section #{sec}")

    decision = _section(text, "Decision")
    user_outcome = _section(text, "User outcome")
    if require_executive and not _has_executive_lead(text, decision, user_outcome):
        errors.append(
            "executive prose weak: need # Executive overview (≥2 sentences) "
            "or Decision + User outcome each ≥2 sentences"
        )

    success = _section(text, "Success criteria")
    grading = _section(text, "Grading")
    dataset = _section(text, "Dataset")
    limitations = _section(text, "Limitations")

    if success and re.search(r"\|.*Criterion", success):
        if not grading.strip() or grading.count("|") < 2:
            errors.append("Grading table empty while Success criteria exist")
        elif not GRADER_RE.search(grading):
            errors.append(
                "Grading rows must name program | person | model (or check.sh)"
            )
        if not dataset.strip():
            errors.append("Dataset missing while Success criteria exist")

    holdout_blob = f"{dataset}\n{limitations}\n{text}"
    if success and not HOLDOUT_RE.search(holdout_blob):
        errors.append(
            "holdout signal missing: Dataset or Limitations must mention "
            "hold-out / train|test (or name the gap)"
        )

    fixture_dir = fm.get("fixture_dir", "")
    f2p = fm.get("f2p_check", "")
    if fixture_dir:
        resolved = resolve_fixture_dir(scan_root, fixture_dir)
        if resolved is None:
            errors.append(f"fixture_dir does not resolve: {fixture_dir}")
        elif f2p:
            check = resolved / f2p
            if not check.is_file():
                errors.append(f"f2p_check missing: {check}")
            elif not (check.stat().st_mode & 0o111):
                errors.append(f"f2p_check not executable: {check}")

    result_path = path.with_name(path.stem + "-result.md")
    if result_path.is_file():
        rtext = result_path.read_text(encoding="utf-8")
        if not VERDICT_RE.search(rtext):
            errors.append(
                f"sibling result {result_path.name} needs Adopt/Hold/Inconclusive "
                "(or Verdict/Recommendation)"
            )
        if not PROOF_CUE_RE.search(rtext):
            errors.append(
                f"sibling result {result_path.name} needs a proof cue "
                "(fenced block, make eval/…, or exit code)"
            )

    errors.extend(_launch_path_errors(path, scan_root, text, fm))
    errors.extend(_use_path_errors(path, scan_root, text, fm))
    errors.extend(_live_path_errors(path, scan_root, text, fm))
    errors.extend(_live_result_errors(path, text))

    return errors


def should_lint(path: Path, text: str, mode: str) -> bool:
    if mode == "all":
        return True
    # opt-in: Executive overview section or pack_quality frontmatter
    fm = _frontmatter(text)
    if fm.get("pack_quality", "").lower() in {"required", "ratchet", "1", "true"}:
        return True
    if re.search(r"^# Executive overview\s*$", text, re.M):
        return True
    return False


def run_lint(
    scan_root: Path,
    *,
    mode: str = "opt-in",
    paths: list[Path] | None = None,
) -> int:
    goals = paths if paths is not None else discover_goals(scan_root)
    fail = 0
    checked = 0
    for path in goals:
        text = path.read_text(encoding="utf-8")
        if "schema: goal/v1" not in text and "fixture_dir:" not in text:
            continue
        if not should_lint(path, text, mode):
            continue
        checked += 1
        errs = lint_goal(path, scan_root=scan_root, require_executive=True)
        if errs:
            fail = 1
            for e in errs:
                print(f"error: {path}: {e}", file=sys.stderr)
        else:
            print(f"pack_quality_ok path={path}")
    if checked == 0 and mode == "all":
        print("error: no goal packs found to lint", file=sys.stderr)
        return 1
    if checked == 0:
        print(f"pack_quality_skip reason=no_opt_in_goals root={scan_root}")
    return fail


def selftest(samples_root: Path) -> int:
    good = samples_root / "good" / "goal.md"
    bad = samples_root / "bad" / "goal.md"
    good_desktop = samples_root / "good-desktop" / "goal.md"
    bad_desktop = samples_root / "bad-desktop" / "goal.md"
    good_use = samples_root / "good-use" / "goal.md"
    bad_use = samples_root / "bad-use" / "goal.md"
    good_live = samples_root / "good-live" / "goal.md"
    bad_live = samples_root / "bad-live" / "goal.md"
    if not good.is_file() or not bad.is_file():
        print(f"error: missing samples under {samples_root}", file=sys.stderr)
        return 1
    if not good_desktop.is_file() or not bad_desktop.is_file():
        print(f"error: missing desktop samples under {samples_root}", file=sys.stderr)
        return 1
    if not good_use.is_file() or not bad_use.is_file():
        print(f"error: missing use-path samples under {samples_root}", file=sys.stderr)
        return 1
    if not good_live.is_file() or not bad_live.is_file():
        print(f"error: missing live-path samples under {samples_root}", file=sys.stderr)
        return 1
    good_errs = lint_goal(good, scan_root=good.parent, require_executive=True)
    bad_errs = lint_goal(bad, scan_root=bad.parent, require_executive=True)
    good_desktop_errs = lint_goal(
        good_desktop, scan_root=good_desktop.parent, require_executive=True
    )
    bad_desktop_errs = lint_goal(
        bad_desktop, scan_root=bad_desktop.parent, require_executive=True
    )
    good_use_errs = lint_goal(good_use, scan_root=good_use.parent, require_executive=True)
    bad_use_errs = lint_goal(bad_use, scan_root=bad_use.parent, require_executive=True)
    good_live_errs = lint_goal(
        good_live, scan_root=good_live.parent, require_executive=True
    )
    bad_live_errs = lint_goal(bad_live, scan_root=bad_live.parent, require_executive=True)
    rc = 0
    if good_errs:
        rc = 1
        for e in good_errs:
            print(f"error: selftest good unexpectedly failed: {e}", file=sys.stderr)
    else:
        print("pack_quality_selftest_good_ok")
    if not bad_errs:
        rc = 1
        print("error: selftest bad unexpectedly passed", file=sys.stderr)
    else:
        print(f"pack_quality_selftest_bad_ok n_errors={len(bad_errs)}")
    if good_desktop_errs:
        rc = 1
        for e in good_desktop_errs:
            print(
                f"error: selftest good-desktop unexpectedly failed: {e}",
                file=sys.stderr,
            )
    else:
        print("pack_quality_selftest_good_desktop_ok")
    launch_hits = [e for e in bad_desktop_errs if "launch-path" in e]
    if not launch_hits:
        rc = 1
        print(
            "error: selftest bad-desktop must fail launch-path "
            f"(errors={bad_desktop_errs!r})",
            file=sys.stderr,
        )
    else:
        print(f"pack_quality_selftest_bad_desktop_ok n_errors={len(bad_desktop_errs)}")
    if good_use_errs:
        rc = 1
        for e in good_use_errs:
            print(
                f"error: selftest good-use unexpectedly failed: {e}",
                file=sys.stderr,
            )
    else:
        print("pack_quality_selftest_good_use_ok")
    use_hits = [e for e in bad_use_errs if "use-path" in e]
    if not use_hits:
        rc = 1
        print(
            "error: selftest bad-use must fail use-path "
            f"(errors={bad_use_errs!r})",
            file=sys.stderr,
        )
    else:
        print(f"pack_quality_selftest_bad_use_ok n_errors={len(bad_use_errs)}")
    if good_live_errs:
        rc = 1
        for e in good_live_errs:
            print(
                f"error: selftest good-live unexpectedly failed: {e}",
                file=sys.stderr,
            )
    else:
        print("pack_quality_selftest_good_live_ok")
    live_hits = [e for e in bad_live_errs if "live-path" in e]
    if not live_hits:
        rc = 1
        print(
            "error: selftest bad-live must fail live-path "
            f"(errors={bad_live_errs!r})",
            file=sys.stderr,
        )
    else:
        print(f"pack_quality_selftest_bad_live_ok n_errors={len(bad_live_errs)}")
    return rc


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scan-root", type=Path, required=True)
    p.add_argument("--mode", choices=("opt-in", "all"), default="opt-in")
    p.add_argument("--selftest", type=Path, default=None, help="samples/ directory")
    p.add_argument(
        "--selftest-only",
        action="store_true",
        help="Run selftest and exit (skip scan-root lint)",
    )
    p.add_argument("paths", nargs="*", type=Path)
    args = p.parse_args(argv)

    rc = 0
    if args.selftest is not None:
        rc = selftest(args.selftest) or rc
        if args.selftest_only:
            return rc
    paths = [Path(x) for x in args.paths] if args.paths else None
    rc = run_lint(args.scan_root, mode=args.mode, paths=paths) or rc
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
