import { describe, it, expect } from "vitest";
import {
  formatCurrency,
  formatCurrencyWithConfig,
  setCurrencyConfig,
  formatNumber,
  formatPercent,
  truncate,
  getInitials,
  statusColor,
} from "@/utils/format";
import type { CurrencyConfig } from "@/utils/format";

const USD: CurrencyConfig = { code: "USD", symbol: "$", locale: "en-US", decimalPlaces: 2 };
const GHS: CurrencyConfig = { code: "GHS", symbol: "GH₵", locale: "en-GH", decimalPlaces: 2 };
const EUR: CurrencyConfig = { code: "EUR", symbol: "€", locale: "en-IE", decimalPlaces: 2 };

describe("formatCurrencyWithConfig", () => {
  it("formats positive amounts with explicit config", () => {
    expect(formatCurrencyWithConfig(1234.56, USD)).toBe("$1,234.56");
  });

  it("formats with the configured currency symbol and locale", () => {
    expect(formatCurrencyWithConfig(100, GHS)).toBe("GH₵100.00");
    expect(formatCurrencyWithConfig(100, EUR)).toBe("€100.00");
  });

  it("formats zero", () => {
    expect(formatCurrencyWithConfig(0, USD)).toBe("$0.00");
  });

  it("formats negative amounts with the minus before the symbol", () => {
    expect(formatCurrencyWithConfig(-500, USD)).toBe("-$500.00");
  });

  it("treats undefined as zero instead of crashing", () => {
    expect(formatCurrencyWithConfig(undefined, USD)).toBe("$0.00");
  });

  it("treats null as zero instead of crashing", () => {
    expect(formatCurrencyWithConfig(null, USD)).toBe("$0.00");
  });

  it("falls back to symbol concatenation when the code is invalid", () => {
    expect(formatCurrencyWithConfig(100, { ...USD, code: "XXX" })).toBe("$100.00");
  });
});

describe("formatCurrency with active config", () => {
  it("defaults to USD before any config is set", () => {
    setCurrencyConfig(USD);
    expect(formatCurrency(100)).toBe("$100.00");
  });

  it("uses the active application currency", () => {
    setCurrencyConfig(GHS);
    expect(formatCurrency(1234.5)).toBe("GH₵1,234.50");
    setCurrencyConfig(USD);
  });

  it("normalizes codes to uppercase", () => {
    setCurrencyConfig({ code: "ghs", symbol: "GH₵", locale: "en-GH", decimalPlaces: 2 });
    expect(formatCurrency(100)).toBe("GH₵100.00");
    setCurrencyConfig(USD);
  });

  it("ignores an empty code and falls back to USD", () => {
    setCurrencyConfig({ code: "   ", symbol: "GH₵", locale: "en-GH", decimalPlaces: 2 });
    expect(formatCurrency(100)).toBe("$100.00");
    setCurrencyConfig(USD);
  });
});

describe("formatNumber", () => {
  it("formats numbers with commas", () => {
    expect(formatNumber(1234567)).toBe("1,234,567");
  });
});

describe("formatPercent", () => {
  it("formats percentage", () => {
    expect(formatPercent(75.5)).toBe("75.5%");
  });
});

describe("truncate", () => {
  it("truncates long strings", () => {
    expect(truncate("Hello World", 5)).toBe("Hello...");
  });

  it("does not truncate short strings", () => {
    expect(truncate("Hi", 5)).toBe("Hi");
  });
});

describe("getInitials", () => {
  it("returns initials from full name", () => {
    expect(getInitials("John Doe")).toBe("JD");
  });

  it("returns single initial for single name", () => {
    expect(getInitials("John")).toBe("J");
  });

  it("caps at 2 characters", () => {
    expect(getInitials("John Michael Doe")).toBe("JM");
  });
});

describe("statusColor", () => {
  it("returns success for COMPLETED", () => {
    expect(statusColor("COMPLETED")).toBe("badge-success");
  });

  it("returns danger for VOIDED", () => {
    expect(statusColor("VOIDED")).toBe("badge-danger");
  });

  it("returns warning for PENDING", () => {
    expect(statusColor("PENDING")).toBe("badge-warning");
  });

  it("returns neutral for unknown status", () => {
    expect(statusColor("UNKNOWN")).toBe("badge-neutral");
  });
});