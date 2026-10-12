#!/usr/bin/env python3
"""Backfill OptMem shards for broad-kit merged PRs (local proof; merge-order).

Builds a deterministic evidence pack (title/desired, goals, results, checks),
hybrid-summarizes into 1–2 lasting notes (≤280 bytes), then optionally writes
shards via unmodified upstream memo. See docs/optmem.md.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

BROAD = re.compile(
    r"^(PROCESS\.md|AGENTS\.md|README\.md|Makefile|"
    r"docs/|"
    r"templates/|"
    r"skills/|"
    r"\.cursor/|"
    r"\.agents/|"
    r"scripts/|"
    r"harness/|"
    r"goals/|"
    r"fixtures/|"
    r"optmem/|"
    r"\.github/workflows/|"
    r"\.pre-commit)"
)
SKIP_TITLE = re.compile(r"(?i)^(chore\(deps\)|dependabot)")
BRANCH_SAFE = re.compile(r"[^A-Za-z0-9._-]+")
GOAL_PATH = re.compile(r"^goals/.+\.md$")
RESULT_PATH = re.compile(r"^goals/.+-result\.md$")
CHECK_PATH = re.compile(r"^fixtures/.+/(check|p2p-smoke)\.sh$")


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def repo_root() -> Path:
    out = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    return Path(out)


def gh_json(args: list[str]) -> object:
    raw = subprocess.check_output(["gh", *args], text=True)
    return json.loads(raw)


def shard_id(merged_at: str, head_ref: str) -> str:
    dt = datetime.fromisoformat(merged_at.replace("Z", "+00:00")).astimezone(
        timezone.utc
    )
    stamp = dt.strftime("%Y%m%dT%H%M%SZ")
    branch = BRANCH_SAFE.sub("-", head_ref).strip("-") or "branch"
    return f"{stamp}-{branch}"


def kit_paths(files: list[dict]) -> list[str]:
    out = []
    for f in files or []:
        p = f.get("path") or ""
        if BROAD.search(p):
            out.append(p)
    return out


def clip(s: str, n: int = 280) -> str:
    b = s.encode("utf-8")
    if len(b) <= n:
        return s
    return b[: n - 3].decode("utf-8", "ignore") + "..."


def extract_desired(body: str) -> str:
    body = body or ""
    for marker in ("## Desired result", "## Desired", "Desired result"):
        if marker in body:
            chunk = body.split(marker, 1)[1]
            chunk = re.split(r"\n##\s+", chunk, maxsplit=1)[0]
            return " ".join(chunk.split())
    return ""


def extract_body_para(body: str) -> str:
    para = ""
    for line in (body or "").splitlines():
        t = line.strip()
        if (
            not t
            or t.startswith("#")
            or t.startswith("<!--")
            or t.startswith("- [")
            or t.lower().startswith("pull request description")
        ):
            if para:
                break
            continue
        para = (para + " " + t).strip() if para else t
        if len(para) > 200:
            break
    if para.lower() in {"pull request description:", "pull request description"}:
        return ""
    return para


def read_trimmed(path: Path, *, max_chars: int = 1200) -> str:
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"(?s)^---\n.*?^---\n", "", text, count=1, flags=re.M)
    text = " ".join(text.split())
    return text[:max_chars]


def skim_check(path: Path, *, max_lines: int = 40) -> str:
    if not path.is_file():
        return ""
    lines = []
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines()):
        if i >= max_lines:
            break
        t = line.strip()
        if not t or t.startswith("#!") or t.startswith("set "):
            continue
        if t.startswith("#") or "assert" in t.lower() or "grep" in t or "miss" in t:
            lines.append(t.lstrip("# ").strip())
        if len(lines) >= 8:
            break
    return " ".join(lines)[:800]


def gather_evidence(pr: dict, *, repo_root: Path) -> dict:
    """Deterministic evidence pack from PR meta + kit files under repo_root."""
    paths = kit_paths(pr.get("files") or [])
    if "_kit_paths" in pr and not paths:
        paths = list(pr["_kit_paths"])
    body = pr.get("body") or ""
    desired = extract_desired(body)
    goals: list[dict] = []
    results: list[dict] = []
    checks: list[dict] = []
    seen: set[str] = set()

    for p in paths:
        if p in seen:
            continue
        seen.add(p)
        abs_p = repo_root / p
        if RESULT_PATH.match(p):
            results.append({"path": p, "text": read_trimmed(abs_p)})
            continue
        if GOAL_PATH.match(p) and not p.endswith("-result.md"):
            goals.append({"path": p, "text": read_trimmed(abs_p)})
            # sibling result
            if p.endswith(".md"):
                rp = p[:-3] + "-result.md"
                if rp not in seen:
                    rt = read_trimmed(repo_root / rp)
                    if rt:
                        results.append({"path": rp, "text": rt})
                        seen.add(rp)
            continue
        if CHECK_PATH.match(p):
            checks.append({"path": p, "text": skim_check(abs_p)})

    return {
        "number": pr.get("number"),
        "title": (pr.get("title") or "").strip(),
        "headRefName": pr.get("headRefName") or "",
        "desired": desired,
        "body_para": extract_body_para(body) if not desired else "",
        "kit_paths": paths,
        "goals": goals,
        "results": results,
        "checks": checks,
    }


def note_ok(line: str) -> bool:
    if not line or not line.strip():
        return False
    s = line.strip().strip('"').strip("'")
    if len(s.encode()) > 280 or len(s) < 24:
        return False
    low = s.lower()
    if low.startswith("touched:"):
        return False
    bad = (
        "maybe ",
        "need ",
        "let's ",
        "count bytes",
        "sentence:",
        "compress memories",
        "invent nothing",
    )
    if any(b in low for b in bad):
        return False
    # Reject pure path laundry
    if "touched:" in low and not any(
        k in low for k in ("lasting", "dependabot", "pack", "goal", "fail", "assert", "skip")
    ):
        # title+touched without lasting signal
        if low.count(",") >= 3 and "touched:" in low:
            return False
    return True


def heuristic_notes_from_evidence(ev: dict) -> list[str]:
    num = ev.get("number")
    title = ev.get("title") or ""
    desired = (ev.get("desired") or "").strip()
    body_para = (ev.get("body_para") or "").strip()
    goals = ev.get("goals") or []
    results = ev.get("results") or []
    checks = ev.get("checks") or []

    decision_bits: list[str] = []
    if desired:
        decision_bits.append(desired)
    elif body_para:
        decision_bits.append(body_para)
    elif goals:
        g = goals[0].get("text") or ""
        # Prefer Decision / Executive overview snippets
        for marker in ("Decision ", "A pass lets", "Executive overview "):
            if marker.lower() in g.lower():
                idx = g.lower().find(marker.lower())
                decision_bits.append(g[idx : idx + 220])
                break
        else:
            decision_bits.append(g[:220])
    else:
        decision_bits.append(title)

    decision = clip(f"PR #{num} lasting: {' '.join(decision_bits)}")
    notes = [decision]

    proof_bits: list[str] = []
    if results:
        proof_bits.append((results[0].get("text") or "")[:180])
    if checks:
        proof_bits.append((checks[0].get("text") or "")[:160])
    if goals:
        gid = Path(goals[0]["path"]).stem
        proof_bits.append(f"goal {gid}")
    if proof_bits:
        proof = clip(f"PR #{num} proof: {' | '.join(x for x in proof_bits if x)}")
        if proof != decision and note_ok(proof):
            notes.append(proof)

    # Ensure first note ok; fallback
    if not note_ok(notes[0]):
        notes[0] = clip(
            f"PR #{num} lasting: {title}. "
            + (desired or body_para or (goals[0]["text"][:160] if goals else "kit change"))
        )
    return notes[:2]


def _load_repo_memo_llm():
    """Import llm_summary / nap_summary_ok from optmem/repo-memo when available."""
    root = Path(__file__).resolve().parents[1]
    memo_wrap = root / "optmem" / "repo-memo"
    if not memo_wrap.is_file():
        return None
    import importlib.util

    spec = importlib.util.spec_from_file_location("repo_memo_llm", memo_wrap)
    if spec is None or spec.loader is None:
        return None
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception:
        return None
    return mod


def draft_notes_hybrid(ev: dict, *, allow_llm: bool = True) -> list[str]:
    """1–2 lasting notes ≤280 bytes from evidence; LLM optional + heuristic fallback."""
    if os.environ.get("OPTMEM_BACKFILL_NO_LLM") == "1":
        allow_llm = False

    heuristic = heuristic_notes_from_evidence(ev)
    if not allow_llm:
        return heuristic

    mod = _load_repo_memo_llm()
    if mod is None or not hasattr(mod, "llm_summary"):
        return heuristic

    pack = json.dumps(
        {
            "title": ev.get("title"),
            "desired": ev.get("desired"),
            "body_para": ev.get("body_para"),
            "goals": ev.get("goals"),
            "results": ev.get("results"),
            "checks": ev.get("checks"),
        },
        indent=2,
    )[:12000]
    prompt = (
        "Compress this PR evidence into ONE lasting OptMem note (≤280 bytes).\n"
        "Keep the decision agents must remember. Prefer Desired result + goal/"
        "check/result facts. Invent nothing. No Touched: path lists. No meta.\n"
        f"PR #{ev.get('number')}\n{pack}\n"
    )
    try:
        line = mod.llm_summary(prompt)
    except Exception:
        line = None
    notes: list[str] = []
    if line and note_ok(line):
        if not line.lower().startswith("pr #"):
            line = clip(f"PR #{ev.get('number')} lasting: {line}")
        notes.append(clip(line))
    else:
        notes.append(heuristic[0])

    if len(heuristic) > 1:
        # Keep heuristic proof as second note when distinct
        if heuristic[1] not in notes and note_ok(heuristic[1]):
            notes.append(heuristic[1])
    return notes[:2]


# Back-compat name used by older call sites / mental model
def draft_notes(pr: dict, paths: list[str], *, repo_root: Path | None = None) -> list[str]:
    root = repo_root or Path.cwd()
    pr2 = {**pr, "_kit_paths": paths, "files": pr.get("files") or [{"path": p} for p in paths]}
    ev = gather_evidence(pr2, repo_root=root)
    return draft_notes_hybrid(ev)


def list_prs() -> list[dict]:
    prs = gh_json(
        [
            "pr",
            "list",
            "--state",
            "merged",
            "--limit",
            "200",
            "--json",
            "number,title,body,mergedAt,headRefName,files",
        ]
    )
    assert isinstance(prs, list)
    prs = sorted(prs, key=lambda p: p["mergedAt"])
    out = []
    for p in prs:
        if SKIP_TITLE.search(p.get("title") or ""):
            paths = kit_paths(p.get("files") or [])
            if not paths:
                continue
        paths = kit_paths(p.get("files") or [])
        if not paths:
            continue
        out.append({**p, "_kit_paths": paths})
    return out


def write_inventory(root: Path, prs: list[dict], *, allow_llm: bool) -> Path:
    inv_dir = root / "runs" / "optmem-backfill"
    inv_dir.mkdir(parents=True, exist_ok=True)
    items = []
    for p in prs:
        ev = gather_evidence(p, repo_root=root)
        notes = draft_notes_hybrid(ev, allow_llm=allow_llm)
        items.append(
            {
                "number": p["number"],
                "mergedAt": p["mergedAt"],
                "headRefName": p["headRefName"],
                "title": p["title"],
                "shard_id": shard_id(p["mergedAt"], p["headRefName"]),
                "kit_paths": ev["kit_paths"],
                "evidence": {
                    "desired": ev.get("desired"),
                    "goals": [{"path": g["path"]} for g in ev.get("goals") or []],
                    "results": [{"path": r["path"]} for r in ev.get("results") or []],
                    "checks": [{"path": c["path"]} for c in ev.get("checks") or []],
                },
                "notes": notes,
            }
        )
    path = inv_dir / "notes.json"
    path.write_text(json.dumps({"prs": items, "count": len(items)}, indent=2) + "\n")
    print(f"wrote {path} count={len(items)}")
    return path


def run_memo(kit: Path, memory: Path, args: list[str]) -> None:
    memo = kit / "optmem" / "upstream" / "memo"
    env = os.environ.copy()
    env["MEMORY_DIR"] = str(memory)
    r = subprocess.run(
        [sys.executable, str(memo), *args],
        cwd=str(kit),
        env=env,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        die(f"memo {' '.join(args)} failed: {r.stderr or r.stdout}")


def reset_store(root: Path) -> None:
    """Wipe shards and re-init main with WAKE_LINES=96 (demo re-backfill)."""
    shards = root / ".optmem" / "shards"
    main_mem = root / ".optmem" / "main" / "memory"
    if shards.is_dir():
        shutil.rmtree(shards)
        shards.mkdir(parents=True, exist_ok=True)
        print(f"removed shards under {shards}")
    if main_mem.is_dir():
        shutil.rmtree(main_mem)
    main_mem.parent.mkdir(parents=True, exist_ok=True)
    run_memo(root, main_mem, ["init"])
    cfg = main_mem / "config"
    text = cfg.read_text(encoding="utf-8") if cfg.is_file() else ""
    if "WAKE_LINES" in text:
        text = re.sub(
            r"^#?\s*WAKE_LINES\s*=.*$",
            "WAKE_LINES   = 96",
            text,
            flags=re.M,
        )
    else:
        text = (text.rstrip() + "\nWAKE_LINES   = 96\n") if text else "WAKE_LINES   = 96\n"
    cfg.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8")
    for lock in main_mem.glob(".lock"):
        lock.unlink(missing_ok=True)
    print(f"re-init {main_mem} WAKE_LINES=96")


def write_shards(
    root: Path, inventory: dict, *, commit: bool, force: bool
) -> None:
    kit = root
    memo = kit / "optmem" / "upstream" / "memo"
    if not memo.is_file():
        die(f"missing {memo}")
    for item in inventory["prs"]:
        sid = item["shard_id"]
        mem = root / ".optmem" / "shards" / sid / "memory"
        if mem.is_dir() and (mem / "LOG.txt").is_file() and not force:
            print(f"skip existing {sid}")
            continue
        if mem.is_dir() and force:
            shutil.rmtree(mem.parent)
        mem.mkdir(parents=True, exist_ok=True)
        run_memo(kit, mem, ["init"])
        for note in item["notes"]:
            run_memo(kit, mem, ["note", note])
        for lock in mem.glob(".lock"):
            lock.unlink(missing_ok=True)
        print(f"shard {sid} notes={len(item['notes'])}")
        if commit:
            subprocess.check_call(["git", "add", f".optmem/shards/{sid}"], cwd=root)
            msg = (
                f"docs(optmem): backfill shard for PR #{item['number']} "
                f"{item['headRefName']}"
            )
            subprocess.check_call(["git", "commit", "-m", msg], cwd=root)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--inventory-only",
        action="store_true",
        help="Only write runs/optmem-backfill/notes.json",
    )
    ap.add_argument(
        "--write-shards",
        action="store_true",
        help="Create .optmem/shards/* from notes.json (or fresh inventory)",
    )
    ap.add_argument(
        "--commit",
        action="store_true",
        help="With --write-shards: one git commit per PR shard",
    )
    ap.add_argument(
        "--from-inventory",
        type=Path,
        help="Reuse existing notes.json instead of regenerating",
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="With --write-shards: replace existing shards",
    )
    ap.add_argument(
        "--reset-store",
        action="store_true",
        help="Wipe .optmem/shards and re-init .optmem/main (WAKE_LINES=96)",
    )
    ap.add_argument(
        "--no-llm",
        action="store_true",
        help="Heuristic notes only (also OPTMEM_BACKFILL_NO_LLM=1)",
    )
    args = ap.parse_args()
    root = repo_root()
    allow_llm = not args.no_llm and os.environ.get("OPTMEM_BACKFILL_NO_LLM") != "1"

    if args.reset_store:
        reset_store(root)

    if args.from_inventory:
        inventory = json.loads(args.from_inventory.read_text())
        print(f"loaded {args.from_inventory} count={inventory.get('count')}")
    elif args.write_shards or args.inventory_only or not args.reset_store:
        prs = list_prs()
        path = write_inventory(root, prs, allow_llm=allow_llm)
        inventory = json.loads(path.read_text())
    else:
        return 0

    if args.inventory_only and not args.write_shards:
        return 0
    if args.write_shards:
        write_shards(root, inventory, commit=args.commit, force=args.force)
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
