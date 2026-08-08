"""Pagination helpers shared across the API."""

from __future__ import annotations

from dataclasses import dataclass

from app.exceptions import ValidationError_


@dataclass(frozen=True)
class PageParams:
    page: int = 1
    page_size: int = 50


PAGE_DEFAULT = 1
PAGE_SIZE_DEFAULT = 50
PAGE_SIZE_MAX = 200


def normalize_pagination(
    page: int | None = None,
    page_size: int | None = None,
    *,
    max_page_size: int = PAGE_SIZE_MAX,
) -> PageParams:
    """Validate and clamp pagination parameters."""
    page = page or PAGE_DEFAULT
    page_size = page_size or PAGE_SIZE_DEFAULT

    if page < 1:
        raise ValidationError_("Page must be at least 1.", [{"field": "page", "message": "Must be >= 1"}])
    if page_size < 1:
        raise ValidationError_(
            "Page size must be at least 1.",
            [{"field": "page_size", "message": "Must be >= 1"}],
        )
    if page_size > max_page_size:
        raise ValidationError_(
            f"Page size must not exceed {max_page_size}.",
            [{"field": "page_size", "message": f"Must be <= {max_page_size}"}],
        )
    return PageParams(page=page, page_size=page_size)
