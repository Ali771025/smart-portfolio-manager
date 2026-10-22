"""Domain-level RFC 7807 errors for ledger and valuation workflows."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class LedgerDomainError(Exception):
    type: str
    title: str
    status: int
    detail: str
    errors: list[dict[str, str]] | None = None


PROBLEM_BASE = "https://smartportfolio.dev/problems"


def problem_type(slug: str) -> str:
    return f"{PROBLEM_BASE}/{slug}"
