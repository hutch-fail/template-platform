"""Meta-Eval B — Known-Case Discrimination (TypeSafe Noul per fixture)."""

from __future__ import annotations

from typing import Any

from typesafe_sdk import Noul, NoulCriteria, TypeSafeClient

THRESHOLD = 0.5


class DiscriminationError(RuntimeError):
    """Infrastructure or fixture-schema failure while running Meta-Eval B."""


def _fixture_passes(
    client: TypeSafeClient,
    *,
    criterion: str,
    fixture: dict[str, Any],
    label: str,
) -> dict[str, Any]:
    response = client.system_one(
        state={
            "criterion": criterion,
            "fixture": fixture,
            "fixture_label": label,
        },
        questions={
            "passes_criterion": Noul(
                instructions=(
                    "Given `criterion` and `fixture`, does this fixture PASS "
                    "the criterion (not fail it)?"
                ),
                criteria=NoulCriteria(
                    true="The fixture satisfies the PASS conditions.",
                    false="The fixture fails the criterion.",
                ),
            ),
        },
    )
    score = float(response.nouls["passes_criterion"].noul)
    return {"score": score, "value": score >= THRESHOLD}


def evaluate_discrimination(
    candidate: dict[str, Any],
    *,
    definition_passed: bool,
) -> dict[str, Any]:
    """Run Meta-Eval B or skip when definition failed.

    Proves only: known positive → PASS and known negative → FAIL.
    """
    if not definition_passed:
        return {
            "status": "skipped",
            "pass": False,
            "positive_result": None,
            "negative_result": None,
            "reasons": [
                "SKIPPED discrimination: definition quality failed; "
                "known-case check not run."
            ],
        }

    block = candidate.get("discrimination")
    if not isinstance(block, dict):
        raise DiscriminationError(
            "Definition passed but discrimination fixtures are missing. "
            "Add discrimination.positive and discrimination.negative maps "
            "to the candidate YAML."
        )
    positive = block.get("positive")
    negative = block.get("negative")
    if not isinstance(positive, dict) or not isinstance(negative, dict):
        raise DiscriminationError(
            "discrimination.positive and discrimination.negative must both "
            "be maps of input field → example value."
        )

    criterion = candidate.get("criterion")
    if not isinstance(criterion, str) or not criterion.strip():
        raise DiscriminationError("candidate.criterion must be a non-empty string.")

    try:
        with TypeSafeClient() as client:
            pos = _fixture_passes(
                client, criterion=criterion, fixture=positive, label="positive"
            )
            neg = _fixture_passes(
                client, criterion=criterion, fixture=negative, label="negative"
            )
    except DiscriminationError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise DiscriminationError(f"TypeSafe Meta-Eval B failed: {exc}") from exc

    disc_pass = bool(pos["value"]) and (not bool(neg["value"]))
    reasons: list[str] = []
    if not pos["value"]:
        reasons.append(
            "FAIL discrimination: known positive fixture did not PASS the criterion."
        )
    if neg["value"]:
        reasons.append(
            "FAIL discrimination: known negative fixture did not FAIL the criterion."
        )

    return {
        "status": "ran",
        "pass": disc_pass,
        "positive_result": pos["value"],
        "negative_result": neg["value"],
        "positive": pos,
        "negative": neg,
        "reasons": reasons,
    }
