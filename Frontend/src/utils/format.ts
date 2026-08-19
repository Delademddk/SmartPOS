export function formatCurrency(amount: number | null | undefined, symbol = "$"): string {
  const value = amount ?? 0;
  return `${symbol}${value.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
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
