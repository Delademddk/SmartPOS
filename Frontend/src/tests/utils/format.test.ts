import { describe, it, expect } from "vitest";
import {
  formatCurrency,
  formatNumber,
  formatPercent,
  truncate,
  getInitials,
  statusColor,
} from "@/utils/format";

describe("formatCurrency", () => {
  it("formats positive amounts", () => {
    expect(formatCurrency(1234.56)).toBe("$1,234.56");
  });

  it("formats zero", () => {
    expect(formatCurrency(0)).toBe("$0.00");
  });

  it("formats negative amounts", () => {
    expect(formatCurrency(-500)).toBe("$-500.00");
  });

  it("uses custom symbol", () => {
    expect(formatCurrency(100, "KES")).toBe("KES100.00");
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
