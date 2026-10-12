# Prior art: pin and wrap

Org default: **do not reimplement** a tool that already exists when we can pin
it and wrap it.

## When this applies

- A public or internal upstream already owns the mechanism (memory, linter,
  protocol client, merge driver).
- We need repo-scope, git, GitHub Actions, or evals-kit paths it does not ship.

## How

1. Vendor **unmodified** source (or a release artifact) under the kit.
2. Write `PINNED` with git SHA and sha256. A check must fail if the file
   drifts (hub OptMem: `20261005-optmem-repo-memory`).
3. Put org behavior in a sibling wrapper that execs the tool. Prefer env/flags
   the upstream documents (`MEMORY_DIR` for OptMem).
4. If the tool has no hook, still wrap (subprocess, temp dirs, git layout). Do
   **not** fork-and-edit the vendored file.
5. `THIRD_PARTY.md` when the upstream license is missing or restrictive.

## Evals

New kit tools should be graded as wrap-not-rewrite when an upstream is named in
the goal. Cheapest grader: checksum + “wrapper execs upstream.” See universe
`20261005-wrap-prior-art` and hub OptMem
`github.com/hutch-fail/evals/20261005-optmem-repo-memory` (this repository
only; product memories are separate repos’ concern).

Hub OptMem usage (notes, backfill, wake vs TREE): [`optmem.md`](optmem.md).
