import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Search, Eye, X, RotateCcw } from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader, EmptyState, Spinner } from "@/components/feedback";
import { formatDate, formatDateTime, formatCurrency, statusColor } from "@/utils/format";
import type { Return, ReturnReason, Sale, SaleItem } from "@/types";

interface ReturnListResponse {
  data: Return[];
  meta: { page: number; page_size: number; total_items: number; total_pages: number };
}

interface SaleDetail extends Sale {}

interface ReturnCreatePayload {
  sale_id: number;
  return_reason_id: number;
  items: { sale_item_id: number; product_id: number; quantity: number; unit_price: number }[];
  notes?: string;
}

const returnCreateSchema = z.object({
  sale_id: z.number().min(1, "Sale is required"),
  return_reason_id: z.number().min(1, "Return reason is required"),
  notes: z.string().optional(),
});

type ReturnCreateForm = z.infer<typeof returnCreateSchema>;

interface ReturnItemForm {
  sale_item_id: number;
  product_id: number;
  product_name: string;
  quantity: number;
  max_quantity: number;
  unit_price: number;
}

const STATUS_OPTIONS = [
  { value: "", label: "All Status" },
  { value: "PENDING", label: "Pending" },
  { value: "COMPLETED", label: "Completed" },
  { value: "REJECTED", label: "Rejected" },
] as const;

export function ReturnsPage() {
  const queryClient = useQueryClient();
  const { page, pageSize, setPage, setPageSize } = usePagination();
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState<string>("");
  const [filterSaleId, setFilterSaleId] = useState<string>("");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [viewReturnId, setViewReturnId] = useState<number | null>(null);

  const { data: returnsData, isLoading: returnsLoading } = useQuery<ReturnListResponse>({
    queryKey: ["returns", page, pageSize, search, filterStatus, filterSaleId],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (filterSaleId) params.set("sale_id", filterSaleId);
      if (filterStatus) params.set("status", filterStatus);
      const res = await apiGet<Return[]>(`/returns?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: reasons } = useQuery({
    queryKey: ["return-reasons"],
    queryFn: async () => {
      const res = await apiGet<ReturnReason[]>("/returns/reasons");
      return res.data;
    },
  });

  const filteredReturns = returnsData?.data.filter((r) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      r.receipt_number.toLowerCase().includes(q) ||
      r.return_reason.toLowerCase().includes(q) ||
      r.user_name.toLowerCase().includes(q)
    );
  });

  if (returnsLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Returns</h1>
        <button onClick={() => setShowCreateModal(true)} className="btn-primary">
          <Plus className="h-4 w-4" /> New Return
        </button>
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative max-w-sm flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search returns..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="input pl-10"
            />
          </div>
          <input
            type="text"
            placeholder="Sale ID..."
            value={filterSaleId}
            onChange={(e) => { setFilterSaleId(e.target.value); setPage(1); }}
            className="input max-w-[140px]"
          />
          <select
            value={filterStatus}
            onChange={(e) => { setFilterStatus(e.target.value); setPage(1); }}
            className="input max-w-[180px]"
          >
            {STATUS_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>{opt.label}</option>
            ))}
          </select>
        </div>
      </div>

      {!filteredReturns?.length ? (
        <EmptyState
          icon={<RotateCcw className="h-8 w-8 text-gray-400" />}
          title="No returns found"
          description={search || filterStatus || filterSaleId ? "Try adjusting your search or filters." : "No returns have been processed yet."}
        />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Return ID</th>
                <th>Receipt</th>
                <th>Reason</th>
                <th className="text-right">Refund</th>
                <th>Status</th>
                <th>Cashier</th>
                <th>Date</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredReturns.map((ret) => (
                <tr key={ret.return_id}>
                  <td className="font-medium">#{ret.return_id}</td>
                  <td className="text-sm text-gray-600">{ret.receipt_number}</td>
                  <td>
                    <span className="badge-info">{ret.return_reason}</span>
                  </td>
                  <td className="text-right text-sm font-medium text-red-600">
                    {formatCurrency(ret.total_refund_amount)}
                  </td>
                  <td>
                    <span className={statusColor(ret.status)}>
                      {ret.status}
                    </span>
                  </td>
                  <td className="text-sm text-gray-600">{ret.user_name}</td>
                  <td className="text-sm text-gray-500">{formatDate(ret.created_at)}</td>
                  <td>
                    <div className="flex items-center justify-end">
                      <button
                        onClick={() => setViewReturnId(ret.return_id)}
                        className="btn-ghost btn-sm"
                        title="View Details"
                      >
                        <Eye className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {returnsData?.meta && returnsData.meta.total_pages > 1 && (
        <Pagination
          page={returnsData.meta.page}
          totalPages={returnsData.meta.total_pages}
          totalItems={returnsData.meta.total_items}
          pageSize={pageSize}
          onPageChange={setPage}
          onPageSizeChange={setPageSize}
        />
      )}

      {showCreateModal && (
        <CreateReturnModal
          reasons={reasons || []}
          onClose={() => setShowCreateModal(false)}
        />
      )}

      {viewReturnId !== null && (
        <ReturnDetailModal
          returnId={viewReturnId}
          onClose={() => setViewReturnId(null)}
        />
      )}
    </div>
  );
}

interface CreateReturnModalProps {
  reasons: ReturnReason[];
  onClose: () => void;
}

function CreateReturnModal({ reasons, onClose }: CreateReturnModalProps) {
  const queryClient = useQueryClient();
  const [selectedSaleId, setSelectedSaleId] = useState<string>("");
  const [selectedItems, setSelectedItems] = useState<ReturnItemForm[]>([]);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setValue,
    watch,
  } = useForm<ReturnCreateForm>({
    resolver: zodResolver(returnCreateSchema),
    defaultValues: {
      sale_id: 0,
      return_reason_id: 0,
      notes: "",
    },
  });

  const watchedReturnReason = watch("return_reason_id");

  const { data: saleDetail, isLoading: saleLoading } = useQuery({
    queryKey: ["sale-detail", selectedSaleId],
    queryFn: async () => {
      const res = await apiGet<SaleDetail>(`/sales/${selectedSaleId}`);
      return res.data;
    },
    enabled: !!selectedSaleId,
  });

  const createMutation = useMutation({
    mutationFn: (data: ReturnCreatePayload) => apiPost("/returns", data),
    onSuccess: () => {
      toast.success("Return processed successfully");
      queryClient.invalidateQueries({ queryKey: ["returns"] });
      onClose();
    },
    onError: (error: Error & { response?: { data?: { error?: { details?: Array<{ message: string }> } } } }) => {
      const msg = error.response?.data?.error?.details?.[0]?.message;
      toast.error(msg || "Failed to process return");
    },
  });

  function handleSaleIdLookup() {
    if (selectedSaleId) {
      setSelectedItems([]);
      setValue("sale_id", Number(selectedSaleId));
    }
  }

  function handleSaleSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const val = e.target.value;
    setSelectedSaleId(val);
    setSelectedItems([]);
    if (val) {
      setValue("sale_id", Number(val));
    } else {
      setValue("sale_id", 0);
    }
  }

  function toggleItem(item: SaleItem) {
    const exists = selectedItems.find((i) => i.sale_item_id === item.sale_item_id);
    if (exists) {
      setSelectedItems((prev) => prev.filter((i) => i.sale_item_id !== item.sale_item_id));
    } else {
      const maxQty = item.quantity - item.returned_qty;
      if (maxQty <= 0) return;
      setSelectedItems((prev) => [
        ...prev,
        {
          sale_item_id: item.sale_item_id,
          product_id: item.product_id,
          product_name: item.product_name,
          quantity: 1,
          max_quantity: maxQty,
          unit_price: item.unit_price,
        },
      ]);
    }
  }

  function updateItemQuantity(saleItemId: number, qty: number) {
    setSelectedItems((prev) =>
      prev.map((i) =>
        i.sale_item_id === saleItemId
          ? { ...i, quantity: Math.max(1, Math.min(qty, i.max_quantity)) }
          : i
      )
    );
  }

  const totalRefund = selectedItems.reduce((sum, i) => sum + i.unit_price * i.quantity, 0);

  function onSubmit(data: ReturnCreateForm) {
    if (selectedItems.length === 0) {
      toast.error("Select at least one item to return");
      return;
    }
    createMutation.mutate({
      sale_id: data.sale_id,
      return_reason_id: data.return_reason_id,
      items: selectedItems.map((i) => ({
        sale_item_id: i.sale_item_id,
        product_id: i.product_id,
        quantity: i.quantity,
        unit_price: i.unit_price,
      })),
      notes: data.notes || undefined,
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Process Return</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit(onSubmit)} className="p-6 space-y-6">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="label">Sale ID</label>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={selectedSaleId}
                  onChange={handleSaleSelect}
                  className="input flex-1"
                  placeholder="Enter sale ID"
                />
                <button
                  type="button"
                  onClick={handleSaleIdLookup}
                  disabled={!selectedSaleId}
                  className="btn-secondary"
                >
                  Lookup
                </button>
              </div>
              {errors.sale_id && <p className="mt-1 text-xs text-red-600">{errors.sale_id.message}</p>}
            </div>
            <div>
              <label className="label">Return Reason</label>
              <select
                {...register("return_reason_id", { valueAsNumber: true })}
                className="input"
              >
                <option value={0}>Select reason</option>
                {reasons
                  .filter((r) => r.is_active)
                  .map((r) => (
                    <option key={r.return_reason_id} value={r.return_reason_id}>
                      {r.reason_name}
                    </option>
                  ))}
              </select>
              {errors.return_reason_id && (
                <p className="mt-1 text-xs text-red-600">{errors.return_reason_id.message}</p>
              )}
            </div>
          </div>

          {saleLoading && selectedSaleId && (
            <div className="flex justify-center py-4">
              <Spinner />
            </div>
          )}

          {saleDetail && (
            <div className="space-y-4">
              <div className="rounded-lg bg-gray-50 p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-900">
                      Receipt: {saleDetail.receipt_number}
                    </p>
                    <p className="text-xs text-gray-500">
                      {formatDateTime(saleDetail.created_at)} · {saleDetail.cashier_name}
                    </p>
                  </div>
                  <p className="text-sm font-semibold text-gray-900">
                    Total: {formatCurrency(saleDetail.total_amount)}
                  </p>
                </div>
              </div>

              <div>
                <p className="text-sm font-medium text-gray-700 mb-2">Select items to return:</p>
                <div className="border border-gray-200 rounded-lg divide-y divide-gray-200">
                  {saleDetail.items.filter((item) => item.quantity - item.returned_qty > 0).length === 0 ? (
                    <p className="p-4 text-sm text-gray-500 text-center">
                      No items available for return
                    </p>
                  ) : (
                    saleDetail.items
                      .filter((item) => item.quantity - item.returned_qty > 0)
                      .map((item) => {
                        const isSelected = selectedItems.some((i) => i.sale_item_id === item.sale_item_id);
                        const returnableQty = item.quantity - item.returned_qty;
                        return (
                          <div
                            key={item.sale_item_id}
                            className={`p-3 flex items-center gap-4 cursor-pointer transition-colors ${
                              isSelected ? "bg-blue-50" : "hover:bg-gray-50"
                            }`}
                            onClick={() => toggleItem(item)}
                          >
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => toggleItem(item)}
                              className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                            />
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-medium text-gray-900 truncate">
                                {item.product_name}
                              </p>
                              <p className="text-xs text-gray-500">
                                {formatCurrency(item.unit_price)} × {item.quantity}
                                {item.returned_qty > 0 && (
                                  <span className="ml-1 text-amber-600">
                                    ({item.returned_qty} already returned)
                                  </span>
                                )}
                              </p>
                            </div>
                            {isSelected && (
                              <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
                                <label className="text-xs text-gray-500">Qty:</label>
                                <input
                                  type="number"
                                  min={1}
                                  max={returnableQty}
                                  value={selectedItems.find((i) => i.sale_item_id === item.sale_item_id)?.quantity || 1}
                                  onChange={(e) => updateItemQuantity(item.sale_item_id, Number(e.target.value))}
                                  className="input !py-1 !px-2 !text-xs w-16"
                                />
                                <span className="text-xs text-gray-400">/ {returnableQty}</span>
                              </div>
                            )}
                            <p className="text-sm font-medium text-gray-900 whitespace-nowrap">
                              {formatCurrency(item.unit_price * (isSelected ? (selectedItems.find((i) => i.sale_item_id === item.sale_item_id)?.quantity || 1) : 0))}
                            </p>
                          </div>
                        );
                      })
                  )}
                </div>
              </div>

              {selectedItems.length > 0 && (
                <div className="rounded-lg bg-gray-50 p-3 flex items-center justify-between">
                  <span className="text-sm text-gray-600">Total Refund</span>
                  <span className="text-lg font-semibold text-red-600">
                    {formatCurrency(totalRefund)}
                  </span>
                </div>
              )}
            </div>
          )}

          <div>
            <label className="label">Notes (optional)</label>
            <textarea
              {...register("notes")}
              className="input min-h-[60px]"
              placeholder="Additional notes about this return..."
            />
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || createMutation.isPending || selectedItems.length === 0}
              className="btn-primary"
            >
              {createMutation.isPending ? <Spinner size="sm" /> : "Process Return"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

interface ReturnDetailModalProps {
  returnId: number;
  onClose: () => void;
}

function ReturnDetailModal({ returnId, onClose }: ReturnDetailModalProps) {
  const { data: returnDetail, isLoading } = useQuery({
    queryKey: ["return-detail", returnId],
    queryFn: async () => {
      const res = await apiGet<Return>(`/returns/${returnId}`);
      return res.data;
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Return Details</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>

        {isLoading ? (
          <div className="flex justify-center py-12">
            <Spinner />
          </div>
        ) : !returnDetail ? (
          <div className="py-12 text-center text-gray-500">Return not found</div>
        ) : (
          <div className="p-6 space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-xs text-gray-500">Return ID</p>
                <p className="text-sm font-medium text-gray-900">#{returnDetail.return_id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Status</p>
                <span className={statusColor(returnDetail.status)}>
                  {returnDetail.status}
                </span>
              </div>
              <div>
                <p className="text-xs text-gray-500">Receipt Number</p>
                <p className="text-sm font-medium text-gray-900">{returnDetail.receipt_number}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Sale ID</p>
                <p className="text-sm font-medium text-gray-900">#{returnDetail.sale_id}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Reason</p>
                <span className="badge-info">{returnDetail.return_reason}</span>
              </div>
              <div>
                <p className="text-xs text-gray-500">Processed By</p>
                <p className="text-sm text-gray-900">{returnDetail.user_name}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Date</p>
                <p className="text-sm text-gray-900">{formatDateTime(returnDetail.created_at)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Refund Amount</p>
                <p className="text-sm font-semibold text-red-600">
                  {formatCurrency(returnDetail.total_refund_amount)}
                </p>
              </div>
            </div>

            {returnDetail.notes && (
              <div>
                <p className="text-xs text-gray-500 mb-1">Notes</p>
                <p className="text-sm text-gray-700 rounded-lg bg-gray-50 p-3">
                  {returnDetail.notes}
                </p>
              </div>
            )}

            <div className="border-t pt-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Returned Items</h3>
              <div className="border border-gray-200 rounded-lg overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Product</th>
                      <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Qty</th>
                      <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Unit Price</th>
                      <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Refund</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {returnDetail.items.map((item) => (
                      <tr key={item.return_item_id}>
                        <td className="px-3 py-2 text-gray-900 font-medium">{item.product_name}</td>
                        <td className="px-3 py-2 text-right text-gray-600">{item.quantity}</td>
                        <td className="px-3 py-2 text-right text-gray-600">{formatCurrency(item.unit_price)}</td>
                        <td className="px-3 py-2 text-right font-medium text-red-600">
                          {formatCurrency(item.refund_amount)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot className="bg-gray-50">
                    <tr>
                      <td colSpan={3} className="px-3 py-2 text-right text-sm font-semibold text-gray-900">
                        Total Refund:
                      </td>
                      <td className="px-3 py-2 text-right text-sm font-bold text-red-600">
                        {formatCurrency(returnDetail.total_refund_amount)}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>

            <div className="flex justify-end pt-4 border-t">
              <button onClick={onClose} className="btn-secondary">
                Close
              </button>
            </div>
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

function Pagination({ page, totalPages, totalItems, pageSize, onPageChange, onPageSizeChange }: PaginationProps) {
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
            <option key={size} value={size}>{size} / page</option>
          ))}
        </select>
      </div>
      <div className="flex items-center gap-1">
        <button
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
          className="btn-secondary btn-sm"
        >
          Previous
        </button>
        {generatePageNumbers(page, totalPages).map((pageNum, idx) =>
          pageNum === "..." ? (
            <span key={`ellipsis-${idx}`} className="px-2 text-sm text-gray-400">...</span>
          ) : (
            <button
              key={pageNum}
              onClick={() => onPageChange(pageNum as number)}
              className={`btn-sm min-w-[36px] text-sm ${
                pageNum === page ? "bg-primary-600 text-white" : "btn-secondary"
              }`}
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
          Next
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
