import { useQuery } from "@tanstack/react-query";
import {
  DollarSign,
  RotateCcw,
  AlertTriangle,
  Package,
  TrendingUp,
} from "lucide-react";
import { apiGet } from "@/api/client";
import { useAuth } from "@/hooks/useAuth";
import { useCurrency } from "@/hooks/useCurrency";
import { formatCurrency, formatNumber } from "@/utils/format";
import { PageLoader } from "@/components/feedback/PageLoader";
import { ErrorDisplay } from "@/components/feedback/ErrorDisplay";
import type {
  DashboardKPIs,
  DashboardSalesTrendItem,
  DashboardTopProduct,
} from "@/types";

export function DashboardPage() {
  const { isCashier } = useAuth();
  useCurrency();

  const { data: kpis, isLoading, error } = useQuery({
    queryKey: ["dashboard", "kpis"],
    queryFn: async () => {
      const res = await apiGet<DashboardKPIs>("/dashboard/kpis");
      return res.data;
    },
  });

  if (isLoading) return <PageLoader />;
  if (error) return <ErrorDisplay message="Failed to load dashboard data." />;
  if (!kpis) return null;

  if (isCashier) {
    return <CashierDashboard kpis={kpis} />;
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        <StatCard
          icon={<DollarSign className="h-5 w-5 text-green-600" />}
          label="Today's Sales"
          value={formatCurrency(kpis.today_sales_total)}
          sub={`${kpis.today_sales_count} transactions`}
          iconBg="bg-green-50"
        />
        <StatCard
          icon={<RotateCcw className="h-5 w-5 text-yellow-600" />}
          label="Today's Returns"
          value={formatCurrency(kpis.today_returns_total)}
          sub={`${kpis.today_refunds} refunds`}
          iconBg="bg-yellow-50"
        />
        <StatCard
          icon={<AlertTriangle className="h-5 w-5 text-red-600" />}
          label="Low Stock Items"
          value={formatNumber(kpis.low_stock_count)}
          sub={`${kpis.out_of_stock_count} out of stock`}
          iconBg="bg-red-50"
        />
        <StatCard
          icon={<TrendingUp className="h-5 w-5 text-blue-600" />}
          label="Pending Credit"
          value={formatCurrency(kpis.pending_credit_balance)}
          sub={`${kpis.total_products_active} active products`}
          iconBg="bg-blue-50"
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <TopProductsWidget />
        <SalesTrendWidget />
      </div>
    </div>
  );
}

function CashierDashboard({ kpis }: { kpis: DashboardKPIs }) {
  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Cashier Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 mb-6">
        <StatCard
          icon={<DollarSign className="h-5 w-5 text-green-600" />}
          label="Today's Sales"
          value={formatCurrency(kpis.today_sales_total)}
          sub={`${kpis.today_sales_count} transactions`}
          iconBg="bg-green-50"
        />
        <StatCard
          icon={<RotateCcw className="h-5 w-5 text-yellow-600" />}
          label="Today's Returns"
          value={formatCurrency(kpis.today_returns_total)}
          sub={`${kpis.today_refunds} refunds`}
          iconBg="bg-yellow-50"
        />
        <StatCard
          icon={<Package className="h-5 w-5 text-primary-600" />}
          label="Low Stock Items"
          value={formatNumber(kpis.low_stock_count)}
          sub="Items need restocking"
          iconBg="bg-primary-50"
        />
      </div>
    </div>
  );
}

function StatCard({
  icon,
  label,
  value,
  sub,
  iconBg,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  sub: string;
  iconBg: string;
}) {
  return (
    <div className="stat-card">
      <div className="flex items-center gap-4">
        <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${iconBg}`}>
          {icon}
        </div>
        <div>
          <p className="text-sm text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
          <p className="text-xs text-gray-400">{sub}</p>
        </div>
      </div>
    </div>
  );
}

function TopProductsWidget() {
  const { data, isLoading } = useQuery({
    queryKey: ["dashboard", "top-products"],
    queryFn: async () => {
      const res = await apiGet<DashboardTopProduct[]>("/dashboard/top-products?days=30&limit=5");
      return res.data;
    },
  });

  return (
    <div className="card p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Products (30 days)</h3>
      {isLoading ? (
        <div className="flex justify-center py-8"><PageLoader /></div>
      ) : !data?.length ? (
        <p className="text-sm text-gray-500 py-8 text-center">No sales data yet.</p>
      ) : (
        <div className="space-y-3">
          {data.map((item, i) => (
            <div key={i} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
              <div>
                <p className="text-sm font-medium text-gray-900">{item.product_name}</p>
                <p className="text-xs text-gray-500">{item.qty_sold} sold</p>
              </div>
              <p className="text-sm font-semibold text-gray-900">{formatCurrency(item.revenue)}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function SalesTrendWidget() {
  const { data, isLoading } = useQuery({
    queryKey: ["dashboard", "sales-trend"],
    queryFn: async () => {
      const res = await apiGet<DashboardSalesTrendItem[]>("/dashboard/sales-trend-7d");
      return res.data;
    },
  });

  return (
    <div className="card p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">Sales Trend (7 days)</h3>
      {isLoading ? (
        <div className="flex justify-center py-8"><PageLoader /></div>
      ) : !data?.length ? (
        <p className="text-sm text-gray-500 py-8 text-center">No sales data yet.</p>
      ) : (
        <div className="space-y-2">
          {data.map((item, i) => (
            <div key={i} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
              <span className="text-sm text-gray-600">{item.date}</span>
              <div className="flex items-center gap-4">
                <span className="text-xs text-gray-500">{item.sale_count} sales</span>
                <span className="text-sm font-semibold text-gray-900">{formatCurrency(item.total_sales)}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
