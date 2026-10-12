# hutch-fail/matching-brackets

Harbor task wrapping Exercism Python
[`matching-brackets`](https://github.com/exercism/python/tree/main/exercises/practice/matching-brackets).

| Piece | Source |
| --- | --- |
| Stub | `environment/matching_brackets.py` |
| Canonical solution | `solution/matching_brackets.py` (from `.meta/example.py`) |
| Tests | `tests/test_outputs.py` (Exercism suite) |
| Instruction | `instruction.md` |

```bash
# From evals/
harbor run -p harbor/tasks/matching-brackets -a oracle -o harbor/jobs
harbor run -p harbor/tasks/matching-brackets -a claude-code \
  -m anthropic/claude-haiku-4-5 -o harbor/jobs
```
