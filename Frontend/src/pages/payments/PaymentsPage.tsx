import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search, CreditCard, Filter, ChevronLeft, ChevronRight, RotateCcw } from "lucide-react";
import { apiGet } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader, EmptyState } from "@/components/feedback";
import { formatDateTime, formatCurrency, statusColor } from "@/utils/format";
import { useCurrency } from "@/hooks/useCurrency";
import { cn } from "@/utils/cn";
import type { PaginatedResponse, PaymentMethod } from "@/types";

interface PaymentRead {
  payment_id: number;
  sale_id: number;
  payment_method_id: number;
  method_name: string;
  method_code: string;
  amount: number;
  reference_number: string | null;
  status: string;
  receipt_number: string;
  created_at: string;
}

const STATUS_OPTIONS = [
  { value: "", label: "All Status" },
  { value: "COMPLETED", label: "Completed" },
  { value: "PENDING", label: "Pending" },
  { value: "FAILED", label: "Failed" },
  { value: "VOIDED", label: "Voided" },
] as const;

export function PaymentsPage() {
  const { page, pageSize, setPage, setPageSize } = usePagination();
  useCurrency();
  const [search, setSearch] = useState("");
  const [showFilters, setShowFilters] = useState(false);
  const [filterSaleId, setFilterSaleId] = useState("");
  const [filterMethodId, setFilterMethodId] = useState("");
  const [filterStatus, setFilterStatus] = useState("");

  const hasActiveFilters = filterSaleId || filterMethodId || filterStatus;

  const clearFilters = () => {
    setFilterSaleId("");
    setFilterMethodId("");
    setFilterStatus("");
    setPage(1);
  };

  const { data: paymentsData, isLoading: paymentsLoading } = useQuery<PaginatedResponse<PaymentRead>>({
    queryKey: ["payments", page, pageSize, search, filterSaleId, filterMethodId, filterStatus],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (search) params.set("search", search);
      if (filterSaleId) params.set("sale_id", filterSaleId);
      if (filterMethodId) params.set("method_id", filterMethodId);
      if (filterStatus) params.set("status", filterStatus);
      const res = await apiGet<PaymentRead[]>(`/payments?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: methods } = useQuery({
    queryKey: ["payment-methods"],
    queryFn: async () => {
      const res = await apiGet<PaymentMethod[]>("/payments/methods");
      return res.data;
    },
  });

  if (paymentsLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Payments</h1>
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative max-w-sm flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search by reference number..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              className="input pl-10"
            />
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={cn("btn-secondary btn-sm", showFilters && "bg-gray-200")}
            >
              <Filter className="h-4 w-4" />
              Filters
              {hasActiveFilters && (
                <span className="ml-1 rounded-full bg-primary-600 px-1.5 py-0.5 text-[10px] font-medium text-white">
                  {[filterSaleId, filterMethodId, filterStatus].filter(Boolean).length}
                </span>
              )}
            </button>
            {hasActiveFilters && (
              <button onClick={clearFilters} className="btn-ghost btn-sm text-gray-500">
                <RotateCcw className="h-3.5 w-3.5" /> Clear
              </button>
            )}
          </div>
        </div>

        {showFilters && (
          <div className="mt-4 grid grid-cols-1 gap-3 border-t border-gray-200 pt-4 sm:grid-cols-3">
            <div>
              <label className="label">Sale ID</label>
              <input
                type="number"
                min="1"
                placeholder="Filter by sale ID"
                value={filterSaleId}
                onChange={(e) => {
                  setFilterSaleId(e.target.value);
                  setPage(1);
                }}
                className="input"
              />
            </div>
            <div>
              <label className="label">Payment Method</label>
              <select
                value={filterMethodId}
                onChange={(e) => {
                  setFilterMethodId(e.target.value);
                  setPage(1);
                }}
                className="input"
              >
                <option value="">All Methods</option>
                {methods?.map((m) => (
                  <option key={m.payment_method_id} value={m.payment_method_id}>
                    {m.method_name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Status</label>
              <select
                value={filterStatus}
                onChange={(e) => {
                  setFilterStatus(e.target.value);
                  setPage(1);
                }}
                className="input"
              >
                {STATUS_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
          </div>
        )}
      </div>

      {!paymentsData?.data.length ? (
        <EmptyState
          icon={<CreditCard className="h-8 w-8 text-gray-400" />}
          title="No payments found"
          description={
            hasActiveFilters || search
              ? "Try adjusting your search or filters."
              : "No payment records yet."
          }
        />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Payment ID</th>
                <th>Sale</th>
                <th>Method</th>
                <th>Reference</th>
                <th className="text-right">Amount</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {paymentsData.data.map((payment) => (
                <tr key={payment.payment_id}>
                  <td className="text-sm font-medium">#{payment.payment_id}</td>
                  <td>
                    <span className="badge-info">{payment.receipt_number}</span>
                  </td>
                  <td>
                    <div className="flex items-center gap-2">
                      <CreditCard className="h-4 w-4 text-gray-400" />
                      <span className="text-sm">{payment.method_name}</span>
                    </div>
                  </td>
                  <td className="text-sm text-gray-600">
                    {payment.reference_number || "\u2014"}
                  </td>
                  <td className="text-right text-sm font-medium">
                    {formatCurrency(payment.amount)}
                  </td>
                  <td>
                    <span className={statusColor(payment.status)}>
                      {payment.status}
                    </span>
                  </td>
                  <td className="text-sm text-gray-600">
                    {formatDateTime(payment.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {paymentsData?.meta && paymentsData.meta.total_pages > 1 && (
        <Pagination
          page={paymentsData.meta.page}
          totalPages={paymentsData.meta.total_pages}
          totalItems={paymentsData.meta.total_items}
          pageSize={pageSize}
          onPageChange={setPage}
          onPageSizeChange={setPageSize}
        />
      )}

      <div className="mt-8">
        <h2 className="page-title mb-4">Payment Methods</h2>
        {!methods?.length ? (
          <EmptyState
            icon={<CreditCard className="h-8 w-8 text-gray-400" />}
            title="No payment methods"
            description="No payment methods are configured."
          />
        ) : (
          <div className="table-container">
            <table className="table">
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th className="text-right">Sort Order</th>
                </tr>
              </thead>
              <tbody>
                {methods.map((method) => (
                  <tr key={method.payment_method_id}>
                    <td>
                      <span className="font-mono text-sm font-medium">
                        {method.method_code}
                      </span>
                    </td>
                    <td className="text-sm font-medium">{method.method_name}</td>
                    <td>
                      <span className={method.is_cash ? "badge-success" : "badge-info"}>
                        {method.is_cash ? "Cash" : "Non-Cash"}
                      </span>
                    </td>
                    <td>
                      <span className={statusColor(method.is_active ? "ACTIVE" : "VOIDED")}>
                        {method.is_active ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td className="text-right text-sm text-gray-600">
                      {method.sort_order}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

interface PaginationProps {
  page: number;
  totalPages: number;
  totalItems: number;
  pageSize: number;
  onPageChange: (p: number) => void;
  onPageSizeChange: (size: number) => void;
}

function Pagination({
  page,
  totalPages,
  totalItems,
  pageSize,
  onPageChange,
  onPageSizeChange,
}: PaginationProps) {
  return (
    <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-3 text-sm text-gray-500">
        <span>{totalItems} total items</span>
        <select
          value={pageSize}
          onChange={(e) => onPageSizeChange(Number(e.target.value))}
          className="input !py-1 !px-2 !text-xs w-auto"
        >
          {[10, 25, 50, 100].map((size) => (
            <option key={size} value={size}>
              {size} / page
            </option>
          ))}
        </select>
      </div>
      <div className="flex items-center gap-1">
        <button
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
          className="btn-secondary btn-sm"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        {generatePageNumbers(page, totalPages).map((pageNum, idx) =>
          pageNum === "..." ? (
            <span key={`ellipsis-${idx}`} className="px-2 text-sm text-gray-400">
              ...
            </span>
          ) : (
            <button
              key={pageNum}
              onClick={() => onPageChange(pageNum as number)}
              className={cn(
                "btn-sm min-w-[36px] text-sm",
                pageNum === page ? "bg-primary-600 text-white" : "btn-secondary"
              )}
            >
              {pageNum}
            </button>
          )
        )}
        <button
          onClick={() => onPageChange(page + 1)}
          disabled={page >= totalPages}
          className="btn-secondary btn-sm"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}

function generatePageNumbers(current: number, total: number): (number | string)[] {
  if (total <= 7) {
    return Array.from({ length: total }, (_, i) => i + 1);
  }

  const pages: (number | string)[] = [];

  if (current <= 3) {
    pages.push(1, 2, 3, 4, "...", total - 1, total);
  } else if (current >= total - 2) {
    pages.push(1, 2, "...", total - 3, total - 2, total - 1, total);
  } else {
    pages.push(1, "...", current - 1, current, current + 1, "...", total);
  }

  return pages;
}
