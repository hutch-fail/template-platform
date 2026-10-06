# Executive outcome

{{opening}}

# Result

**Recommendation:** {{recommendation}}

# Outcome

{{outcome}}

# Proof

Paste short harness snippets that an executive can trust (fenced blocks OK):
`make eval/assert-red` / `verify` / `bars` exits, key check lines, score deltas.
A result without at least one proof cue is incomplete.

{{evidence}}

# Manual verification

List every check you ran by hand and the automated check that now covers it
(`PROCESS.md` “Manual verification becomes a test”). Write `None — <why>` only
if nothing was run by hand. This section is required and must not be empty.

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
|  |  |  | hermetic / live-proof / none (say why + exact command) |

# Blocking findings

{{blocking}}

# Comparison

{{comparison}}

# Evidence and limitations

{{evidence}}

# Next action

{{next_action}}
