import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { DashboardPage } from "@/pages/admin/DashboardPage";
import { apiGet } from "@/api/client";
import type { DashboardKPIs } from "@/types";

vi.mock("@/api/client", () => ({
  apiGet: vi.fn(),
}));

vi.mock("@/hooks/useAuth", () => ({
  useAuth: () => ({ isCashier: false }),
}));

const apiGetMock = vi.mocked(apiGet);

const kpis: DashboardKPIs = {
  today_sales_total: 6,
  today_sales_count: 2,
  today_returns_total: 0,
  today_refunds: 0,
  low_stock_count: 1,
  out_of_stock_count: 0,
  pending_credit_balance: 0,
  active_users_count: 3,
  total_products_active: 3,
};

const trend = [
  { date: "2026-08-13", weekday: "Thursday", total_sales: 0, sale_count: 0 },
  { date: "2026-08-14", weekday: "Friday", total_sales: 5, sale_count: 1 },
  { date: "2026-08-15", weekday: "Saturday", total_sales: 0, sale_count: 0 },
  { date: "2026-08-16", weekday: "Sunday", total_sales: 0, sale_count: 0 },
  { date: "2026-08-17", weekday: "Monday", total_sales: 0, sale_count: 0 },
  { date: "2026-08-18", weekday: "Tuesday", total_sales: 0, sale_count: 0 },
  { date: "2026-08-19", weekday: "Wednesday", total_sales: 6, sale_count: 2 },
];

const topProducts = [
  {
    product_id: 1,
    product_name: "Coca-Cola 500ml",
    sku: "BEV-001",
    qty_sold: 4,
    revenue: 20,
    share_pct: 76.92,
  },
  {
    product_id: 2,
    product_name: "Blue Pen",
    sku: "SKU-33",
    qty_sold: 3,
    revenue: 6,
    share_pct: 23.08,
  },
];

function renderDashboard() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <DashboardPage />
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  apiGetMock.mockReset();
});

describe("DashboardPage", () => {
  it("renders real dashboard data without crashing (backend contract)", async () => {
    apiGetMock.mockImplementation(async (url: string) => {
      if (url.includes("/dashboard/kpis")) return { success: true, data: kpis };
      if (url.includes("/dashboard/top-products"))
        return { success: true, data: topProducts };
      if (url.includes("/dashboard/sales-trend-7d"))
        return { success: true, data: trend };
      return { success: true, data: [] };
    });

    renderDashboard();

    expect(await screen.findByText("Coca-Cola 500ml")).toBeInTheDocument();
    expect(screen.getByText("4 sold")).toBeInTheDocument();
    expect(screen.getByText("$20.00")).toBeInTheDocument();
    expect(screen.getByText("2 sales")).toBeInTheDocument();
    expect(screen.getByText("$5.00")).toBeInTheDocument();
    expect(screen.getByText("2 transactions")).toBeInTheDocument();
  });

  it("renders empty states when there is no sales data", async () => {
    apiGetMock.mockImplementation(async (url: string) => {
      if (url.includes("/dashboard/kpis"))
        return {
          success: true,
          data: { ...kpis, today_sales_total: 0, today_sales_count: 0 },
        };
      return { success: true, data: [] };
    });

    renderDashboard();

    await waitFor(() => {
      expect(screen.getAllByText("No sales data yet.")).toHaveLength(2);
    });
  });
});