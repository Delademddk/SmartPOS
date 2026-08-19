"""Centralized application currency configuration.

Single source of truth for the locale associated with each supported ISO
currency code. The authoritative currency code is stored on the business
profile (``business_information.currency_code``) and mirrored into the display
``settings`` rows; every other part of the application derives its symbol,
locale and formatting from this module.
"""

from __future__ import annotations

# Locale used for number/currency formatting per ISO currency code.
# The authoritative symbol always comes from the ``currencies`` table.
CURRENCY_LOCALES: dict[str, str] = {
    "USD": "en-US",
    "GHS": "en-GH",
    "EUR": "en-IE",
    "GBP": "en-GB",
    "NGN": "en-NG",
}

DEFAULT_CURRENCY_CODE = "USD"
DEFAULT_CURRENCY_SYMBOL = "$"
DEFAULT_CURRENCY_LOCALE = "en-US"
DEFAULT_CURRENCY_DECIMAL_PLACES = 2


def locale_for_currency(currency_code: str) -> str:
    """Return the display locale for an ISO currency code."""
    return CURRENCY_LOCALES.get(currency_code.upper(), DEFAULT_CURRENCY_LOCALE)