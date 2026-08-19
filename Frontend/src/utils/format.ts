export interface CurrencyConfig {
  code: string;
  symbol: string;
  locale: string;
  decimalPlaces: number;
}

const SUPPORTED_CURRENCY_CODES = new Set(["USD", "GHS", "EUR", "GBP", "NGN"]);

const DEFAULT_CURRENCY: CurrencyConfig = {
  code: "USD",
  symbol: "$",
  locale: "en-US",
  decimalPlaces: 2,
};

let activeCurrency: CurrencyConfig = DEFAULT_CURRENCY;
const currencyListeners = new Set<() => void>();

function normalizeCode(code: string): string | null {
  const trimmed = code.trim().toUpperCase();
  return SUPPORTED_CURRENCY_CODES.has(trimmed) ? trimmed : null;
}

/**
 * Sets the active application currency configuration used by formatCurrency.
 * The value comes from the backend (authoritative application setting) and is
 * kept in sync by the settings layer. Falls back to the USD default whenever
 * the code is empty or unsupported.
 */
export function setCurrencyConfig(config: Partial<CurrencyConfig>): void {
  const code = normalizeCode(config.code ?? "");
  activeCurrency = code ? { ...DEFAULT_CURRENCY, ...config, code } : { ...DEFAULT_CURRENCY };
  currencyListeners.forEach((listener) => listener());
}

export function getCurrencyConfig(): CurrencyConfig {
  return activeCurrency;
}

export function subscribeCurrency(listener: () => void): () => void {
  currencyListeners.add(listener);
  return () => {
    currencyListeners.delete(listener);
  };
}

/**
 * Formats a numeric amount with an explicit currency configuration. Internal
 * canonical implementation shared by formatCurrency and the settings layer so
 * there is exactly one currency-formatting routine.
 */
export function formatCurrencyWithConfig(
  amount: number | null | undefined,
  config: CurrencyConfig,
): string {
  const value = amount ?? 0;
  const { code, locale, decimalPlaces } = config;
  if (!SUPPORTED_CURRENCY_CODES.has(code)) {
    return `${config.symbol}${value.toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  }
  try {
    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: code,
      minimumFractionDigits: decimalPlaces,
      maximumFractionDigits: decimalPlaces,
    }).format(value);
  } catch {
    return `${config.symbol}${value.toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  }
}

/**
 * Formats a numeric amount with the active application currency. This is the
 * single canonical currency-formatting utility; every monetary display in the
 * application goes through it. Safe to call before settings load (defaults to
 * USD and never throws on null/undefined/loading states).
 */
export function formatCurrency(amount: number | null | undefined): string {
  return formatCurrencyWithConfig(amount, activeCurrency);
}

export function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatDateTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatNumber(value: number): string {
  return value.toLocaleString("en-US");
}

export function formatPercent(value: number): string {
  return `${value.toFixed(1)}%`;
}

export function truncate(str: string, length: number): string {
  if (str.length <= length) return str;
  return str.slice(0, length) + "...";
}

export function getInitials(name: string): string {
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

export function statusColor(status: string): string {
  const colors: Record<string, string> = {
    COMPLETED: "badge-success",
    ACTIVE: "badge-success",
    IN_STOCK: "badge-success",
    SETTLED: "badge-success",
    RESOLVED: "badge-success",
    VOIDED: "badge-danger",
    REJECTED: "badge-danger",
    OUT_OF_STOCK: "badge-danger",
    CANCELLED: "badge-danger",
    FAILED: "badge-danger",
    WRITTEN_OFF: "badge-danger",
    OVERDUE: "badge-danger",
    LOW_STOCK: "badge-warning",
    PENDING: "badge-warning",
    OPEN: "badge-warning",
    PARTIAL: "badge-warning",
    INFO: "badge-info",
    WARNING: "badge-warning",
    CRITICAL: "badge-danger",
  };
  return colors[status] || "badge-neutral";
}