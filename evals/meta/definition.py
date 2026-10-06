"""Meta-Eval A — Definition Quality (four parallel TypeSafe Nouls)."""

from __future__ import annotations

from typing import Any

from typesafe_sdk import Noul, NoulCriteria, TypeSafeClient

THRESHOLD = 0.5

DIMENSIONS = (
    "decidable",
    "executable",
    "single_claim",
    "binary_outcome",
)

_DIAGNOSTICS = {
    "decidable": (
        "FAIL decidable: There is no clear fact of the matter under the "
        "criterion (judgment is subjective or underspecified)."
    ),
    "executable": (
        "FAIL executable: The criterion requires evidence that is not "
        "represented in the declared input schema."
    ),
    "single_claim": (
        "FAIL single_claim: The criterion bundles more than one independently "
        "falsifiable property."
    ),
    "binary_outcome": (
        "FAIL binary_outcome: PASS vs FAIL is not operationally defined "
        "(e.g. 'looks good' rather than an explicit decision boundary)."
    ),
}

_QUESTIONS = {
    "decidable": Noul(
        instructions=(
            "Is there a fact of the matter under this criterion — a definite "
            "yes or no given enough evidence — rather than taste, preference, "
            "or open-ended quality judgment?"
        ),
        criteria=NoulCriteria(
            true=(
                "An informed judge could agree whether a concrete case passes "
                "or fails using only the criterion wording."
            ),
            false=(
                "The criterion asks for subjective quality, vague 'goodness', "
                "or something with no determinate answer."
            ),
        ),
    ),
    "executable": Noul(
        instructions=(
            "Can the PASS/FAIL decision be made using only the declared "
            "`inputs` (and the criterion text), without needing external "
            "knowledge, unstated context, or fields not listed in inputs?"
        ),
        criteria=NoulCriteria(
            true=(
                "Every piece of evidence the criterion needs appears as a "
                "typed declared input."
            ),
            false=(
                "The criterion needs facts, references, or world knowledge "
                "that are not in the declared input schema."
            ),
        ),
    ),
    "single_claim": Noul(
        instructions=(
            "Does the criterion assert exactly one independently falsifiable "
            "property (not a conjunction of unrelated claims)?"
        ),
        criteria=NoulCriteria(
            true="One atomic claim; failing it has a single clear reason.",
            false=(
                "Multiple independent properties are ANDed or mixed "
                "(e.g. 'has a URL and is polite and is complete')."
            ),
        ),
    ),
    "binary_outcome": Noul(
        instructions=(
            "Is the PASS vs FAIL boundary operationally explicit — concrete "
            "conditions for each side — rather than vague language like "
            "'looks good' or 'is high quality'?"
        ),
        criteria=NoulCriteria(
            true=(
                "PASS and FAIL are defined with observable conditions "
                "(e.g. 'contains at least one HTTPS URL')."
            ),
            false=(
                "The boundary is soft, aesthetic, or undefined "
                "('reasonable', 'looks good', 'adequate')."
            ),
        ),
    ),
}


class DefinitionError(RuntimeError):
    """Infrastructure failure while running Meta-Eval A."""


def _build_state(candidate: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": candidate.get("id"),
        "description": candidate.get("description"),
        "criterion": candidate.get("criterion"),
        "inputs": candidate.get("inputs"),
        "result": candidate.get("result"),
    }


def evaluate_definition(candidate: dict[str, Any]) -> dict[str, Any]:
    """Run Meta-Eval A; return structured result with raw scores.

    Raises DefinitionError on API / client failures (maps to META ERROR).
    """
    try:
        with TypeSafeClient() as client:
            response = client.system_one(
                state=_build_state(candidate),
                questions=_QUESTIONS,
            )
    except Exception as exc:  # noqa: BLE001 — surface as ERROR, not FAIL
        raise DefinitionError(f"TypeSafe Meta-Eval A failed: {exc}") from exc

    dimensions: dict[str, Any] = {}
    reasons: list[str] = []
    for name in DIMENSIONS:
        score = float(response.nouls[name].noul)
        value = score >= THRESHOLD
        dimensions[name] = {"score": score, "value": value}
        if not value:
            reasons.append(_DIAGNOSTICS[name])

    definition_pass = all(dimensions[d]["value"] for d in DIMENSIONS)
    return {
        "status": "ran",
        "pass": definition_pass,
        "dimensions": dimensions,
        "reasons": reasons,
    }
