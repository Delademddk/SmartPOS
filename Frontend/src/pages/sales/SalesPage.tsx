import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Search, Eye, XCircle, ReceiptIcon, X, Calendar } from "lucide-react"
import toast from "react-hot-toast"
import { apiGet, apiPost } from "@/api/client"
import { usePagination } from "@/hooks/usePagination"
import { PageLoader, EmptyState, Spinner } from "@/components/feedback"
import { formatDate, formatDateTime, formatCurrency, statusColor } from "@/utils/format"
import type { Sale, Receipt, PaginatedResponse } from "@/types"

type StatusFilter = "" | "COMPLETED" | "VOIDED" | "REFUNDED"
type SaleTypeFilter = "" | "CASH" | "CREDIT" | "CREDIT_PARTIAL"

interface VoidSaleRequest {
  reason: string
}

interface SalesQueryParams {
  page: number
  per_page: number
  search?: string
  status?: StatusFilter
  sale_type?: SaleTypeFilter
  user_id?: number
  customer_id?: number
  date_from?: string
  date_to?: string
}

function VoidModal({
  isOpen,
  onClose,
  onConfirm,
  isLoading,
}: {
  isOpen: boolean
  onClose: () => void
  onConfirm: (reason: string) => void
  isLoading: boolean
}) {
  const [reason, setReason] = useState("")

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!reason.trim()) {
      toast.error("Please enter a reason for voiding")
      return
    }
    onConfirm(reason)
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md mx-4">
        <div className="flex items-center justify-between p-4 border-b">
          <h3 className="text-lg font-semibold text-gray-900">Void Sale</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-4 space-y-4">
          <p className="text-sm text-gray-600">
            Are you sure you want to void this sale? This action cannot be undone.
          </p>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Reason</label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
              rows={3}
              placeholder="Enter reason for voiding..."
              required
            />
          </div>
          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isLoading}
              className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 disabled:opacity-50"
            >
              {isLoading ? "Voiding..." : "Void Sale"}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function SaleDetailModal({
  saleId,
  isOpen,
  onClose,
}: {
  saleId: number | null
  isOpen: boolean
  onClose: () => void
}) {
  const { data: sale, isLoading } = useQuery<Sale>({
    queryKey: ["sale", saleId],
    queryFn: async () => {
      const res = await apiGet<Sale>(`/sales/${saleId}`)
      return res.data
    },
    enabled: isOpen && saleId !== null,
  })

  const queryClient = useQueryClient()
  const [voidModalOpen, setVoidModalOpen] = useState(false)

  const voidMutation = useMutation({
    mutationFn: (data: VoidSaleRequest) => apiPost(`/sales/${saleId}/void`, data),
    onSuccess: () => {
      toast.success("Sale voided successfully")
      queryClient.invalidateQueries({ queryKey: ["sales"] })
      setVoidModalOpen(false)
      onClose()
    },
    onError: (error: Error) => {
      toast.error(error.message || "Failed to void sale")
    },
  })

  const handleViewReceipt = async () => {
    if (!saleId) return
    try {
      const res = await apiGet<Receipt>(`/sales/${saleId}/receipt`)
      const receipt = res.data
      const printWindow = window.open("", "_blank")
      if (printWindow) {
        printWindow.document.write(`
          <html><head><title>Receipt ${receipt.receipt_number}</title>
          <style>body{font-family:monospace;padding:20px;max-width:300px;margin:0 auto;}
          h2,h3{text-align:center;margin:5px 0;}
          .line{border-top:1px dashed #000;margin:5px 0;}
          table{width:100%;border-collapse:collapse;}
          td{padding:2px 0;}</style></head><body>
          <h2>${receipt.business_name || ""}</h2>
          <p style="text-align:center;font-size:12px;">${receipt.business_address || ""}</p>
          <p style="text-align:center;font-size:12px;">${receipt.business_phone || ""}</p>
          <div class="line"></div>
          <p style="font-size:12px;">Receipt: ${receipt.receipt_number}</p>
          <p style="font-size:12px;">Cashier: ${receipt.cashier_name || ""}</p>
          <p style="font-size:12px;">Date: ${formatDateTime(receipt.sale_date)}</p>
          <div class="line"></div>
          <table>${(receipt.items || [])
            .map(
              (item) => `
            <tr>
              <td>${item.product_name} x${item.quantity}</td>
              <td style="text-align:right">${formatCurrency(item.line_total)}</td>
            </tr>`
            )
            .join("")}</table>
          <div class="line"></div>
          <table>
            <tr><td>Subtotal</td><td style="text-align:right">${formatCurrency(receipt.subtotal)}</td></tr>
            <tr><td>Tax</td><td style="text-align:right">${formatCurrency(receipt.tax_amount)}</td></tr>
            ${receipt.discount_amount > 0 ? `<tr><td>Discount</td><td style="text-align:right">-${formatCurrency(receipt.discount_amount)}</td></tr>` : ""}
            <tr><td><strong>Total</strong></td><td style="text-align:right"><strong>${formatCurrency(receipt.total_amount)}</strong></td></tr>
            <tr><td>Received</td><td style="text-align:right">${formatCurrency(receipt.amount_received)}</td></tr>
            ${receipt.change_amount > 0 ? `<tr><td>Change</td><td style="text-align:right">${formatCurrency(receipt.change_amount)}</td></tr>` : ""}
          </table>
          <div class="line"></div>
          <p style="text-align:center;font-size:12px;">Thank you!</p>
          </body></html>`)
        printWindow.document.close()
        printWindow.print()
      }
    } catch {
      toast.error("Failed to load receipt")
    }
  }

  if (!isOpen) return null

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
        <div className="bg-white rounded-lg shadow-xl w-full max-w-3xl mx-4 max-h-[90vh] flex flex-col">
          <div className="flex items-center justify-between p-4 border-b">
            <h3 className="text-lg font-semibold text-gray-900">Sale Detail</h3>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
              <X className="w-5 h-5" />
            </button>
          </div>
          <div className="p-4 overflow-y-auto flex-1">
            {isLoading ? (
              <div className="flex justify-center py-12">
                <Spinner />
              </div>
            ) : sale ? (
              <div className="space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div>
                    <p className="text-xs text-gray-500">Receipt #</p>
                    <p className="text-sm font-medium">{sale.receipt_number}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Type</p>
                    <span className="inline-block px-2 py-0.5 text-xs font-medium rounded-full bg-blue-100 text-blue-800">
                      {sale.sale_type}
                    </span>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Status</p>
                    <span className={`inline-block px-2 py-0.5 text-xs font-medium rounded-full ${statusColor(sale.status)}`}>
                      {sale.status}
                    </span>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Date</p>
                    <p className="text-sm font-medium">{formatDateTime(sale.created_at)}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Cashier</p>
                    <p className="text-sm font-medium">{sale.cashier_name || "—"}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Customer</p>
                    <p className="text-sm font-medium">{sale.customer_name || "—"}</p>
                  </div>
                  {sale.notes && (
                    <div className="col-span-2 md:col-span-4">
                      <p className="text-xs text-gray-500">Notes</p>
                      <p className="text-sm">{sale.notes}</p>
                    </div>
                  )}
                </div>

                <div>
                  <h4 className="text-sm font-semibold text-gray-900 mb-2">Items</h4>
                  <div className="border rounded-lg overflow-hidden">
                    <table className="w-full text-sm">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="text-left px-3 py-2 font-medium text-gray-600">Product</th>
                          <th className="text-left px-3 py-2 font-medium text-gray-600">SKU</th>
                          <th className="text-right px-3 py-2 font-medium text-gray-600">Qty</th>
                          <th className="text-right px-3 py-2 font-medium text-gray-600">Unit Price</th>
                          <th className="text-right px-3 py-2 font-medium text-gray-600">Discount</th>
                          <th className="text-right px-3 py-2 font-medium text-gray-600">Tax</th>
                          <th className="text-right px-3 py-2 font-medium text-gray-600">Total</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y">
                        {sale.items?.map((item) => (
                          <tr key={item.sale_item_id} className={item.is_returned ? "bg-red-50" : ""}>
                            <td className="px-3 py-2">
                              {item.product_name}
                              {item.is_returned && (
                                <span className="ml-1 text-xs text-red-600">(returned {item.returned_qty})</span>
                              )}
                            </td>
                            <td className="px-3 py-2 text-gray-500">{item.sku}</td>
                            <td className="px-3 py-2 text-right">{item.quantity}</td>
                            <td className="px-3 py-2 text-right">{formatCurrency(item.unit_price)}</td>
                            <td className="px-3 py-2 text-right">{item.discount_rate > 0 ? `${item.discount_rate}%` : "—"}</td>
                            <td className="px-3 py-2 text-right">{formatCurrency(item.tax_amount)}</td>
                            <td className="px-3 py-2 text-right font-medium">{formatCurrency(item.line_total)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h4 className="text-sm font-semibold text-gray-900 mb-2">Payments</h4>
                    {sale.payments?.length ? (
                      <div className="space-y-2">
                        {sale.payments.map((payment) => (
                          <div key={payment.payment_id} className="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
                            <div>
                              <p className="text-sm font-medium">{payment.method_name}</p>
                              {payment.reference_number && (
                                <p className="text-xs text-gray-500">Ref: {payment.reference_number}</p>
                              )}
                              <p className="text-xs text-gray-500">{formatDateTime(payment.created_at)}</p>
                            </div>
                            <div className="text-right">
                              <p className="text-sm font-medium">{formatCurrency(payment.amount)}</p>
                              <span className={`text-xs ${payment.status === "COMPLETED" ? "text-green-600" : "text-yellow-600"}`}>
                                {payment.status}
                              </span>
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-sm text-gray-500">No payments recorded</p>
                    )}
                  </div>

                  <div>
                    <h4 className="text-sm font-semibold text-gray-900 mb-2">Totals</h4>
                    <div className="space-y-1 text-sm">
                      <div className="flex justify-between"><span className="text-gray-600">Subtotal</span><span>{formatCurrency(sale.subtotal)}</span></div>
                      <div className="flex justify-between"><span className="text-gray-600">Tax</span><span>{formatCurrency(sale.tax_amount)}</span></div>
                      {sale.discount_amount > 0 && (
                        <div className="flex justify-between"><span className="text-gray-600">Discount</span><span className="text-red-600">-{formatCurrency(sale.discount_amount)}</span></div>
                      )}
                      <div className="flex justify-between border-t pt-1 font-semibold text-base">
                        <span>Total</span><span>{formatCurrency(sale.total_amount)}</span>
                      </div>
                      <div className="flex justify-between"><span className="text-gray-600">Amount Received</span><span>{formatCurrency(sale.amount_received)}</span></div>
                      {sale.change_amount > 0 && (
                        <div className="flex justify-between"><span className="text-gray-600">Change</span><span>{formatCurrency(sale.change_amount)}</span></div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ) : null}
          </div>
          <div className="flex items-center justify-end gap-2 p-4 border-t">
            <button
              onClick={handleViewReceipt}
              disabled={!sale}
              className="flex items-center gap-1 px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 disabled:opacity-50"
            >
              <ReceiptIcon className="w-4 h-4" /> View Receipt
            </button>
            {sale && sale.status === "COMPLETED" && (
              <button
                onClick={() => setVoidModalOpen(true)}
                className="flex items-center gap-1 px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700"
              >
                <XCircle className="w-4 h-4" /> Void Sale
              </button>
            )}
          </div>
        </div>
      </div>
      <VoidModal
        isOpen={voidModalOpen}
        onClose={() => setVoidModalOpen(false)}
        onConfirm={(reason) => voidMutation.mutate({ reason })}
        isLoading={voidMutation.isPending}
      />
    </>
  )
}

export function SalesPage() {
  const { page, pageSize, setPage, nextPage, prevPage } = usePagination()

  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("")
  const [saleTypeFilter, setSaleTypeFilter] = useState<SaleTypeFilter>("")
  const [dateFrom, setDateFrom] = useState("")
  const [dateTo, setDateTo] = useState("")
  const [userId, setUserId] = useState("")
  const [customerId, setCustomerId] = useState("")
  const [selectedSaleId, setSelectedSaleId] = useState<number | null>(null)
  const [detailOpen, setDetailOpen] = useState(false)

  const queryParams: SalesQueryParams = {
    page,
    per_page: pageSize,
  }
  if (search) queryParams.search = search
  if (statusFilter) queryParams.status = statusFilter
  if (saleTypeFilter) queryParams.sale_type = saleTypeFilter
  if (dateFrom) queryParams.date_from = dateFrom
  if (dateTo) queryParams.date_to = dateTo
  if (userId) queryParams.user_id = Number(userId)
  if (customerId) queryParams.customer_id = Number(customerId)

  const { data, isLoading, isFetching } = useQuery<PaginatedResponse<Sale>>({
    queryKey: ["sales", queryParams],
    queryFn: async () => {
      const params = new URLSearchParams()
      params.set("page", String(queryParams.page))
      params.set("per_page", String(queryParams.per_page))
      if (queryParams.search) params.set("search", queryParams.search)
      if (queryParams.status) params.set("status", queryParams.status)
      if (queryParams.sale_type) params.set("sale_type", queryParams.sale_type)
      if (queryParams.date_from) params.set("date_from", queryParams.date_from)
      if (queryParams.date_to) params.set("date_to", queryParams.date_to)
      if (queryParams.user_id) params.set("user_id", String(queryParams.user_id))
      if (queryParams.customer_id) params.set("customer_id", String(queryParams.customer_id))
      const res = await apiGet<Sale[]>(`/sales?${params.toString()}`)
      return { data: res.data, meta: res.meta! }
    },
  })

  const sales = data?.data || []
  const totalPages = data?.meta.total_pages || 1
  const total = data?.meta.total_items || 0

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    setPage(1)
  }

  const openDetail = (saleId: number) => {
    setSelectedSaleId(saleId)
    setDetailOpen(true)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Sales</h1>
        {isFetching && <Spinner className="w-4 h-4" />}
      </div>

      <div className="bg-white rounded-lg border p-4">
        <form onSubmit={handleSearch} className="grid grid-cols-1 md:grid-cols-4 gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search receipt, customer..."
              className="w-full pl-9 pr-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => { setStatusFilter(e.target.value as StatusFilter); setPage(1) }}
            className="border rounded-lg px-3 py-2 text-sm"
          >
            <option value="">All Status</option>
            <option value="COMPLETED">Completed</option>
            <option value="VOIDED">Voided</option>
            <option value="REFUNDED">Refunded</option>
          </select>
          <select
            value={saleTypeFilter}
            onChange={(e) => { setSaleTypeFilter(e.target.value as SaleTypeFilter); setPage(1) }}
            className="border rounded-lg px-3 py-2 text-sm"
          >
            <option value="">All Types</option>
            <option value="CASH">Cash</option>
            <option value="CREDIT">Credit</option>
            <option value="CREDIT_PARTIAL">Credit Partial</option>
          </select>
          <div className="flex items-center gap-2">
            <Calendar className="w-4 h-4 text-gray-400" />
            <input
              type="date"
              value={dateFrom}
              onChange={(e) => { setDateFrom(e.target.value); setPage(1) }}
              className="border rounded-lg px-3 py-2 text-sm"
              placeholder="From"
            />
            <span className="text-gray-400">—</span>
            <input
              type="date"
              value={dateTo}
              onChange={(e) => { setDateTo(e.target.value); setPage(1) }}
              className="border rounded-lg px-3 py-2 text-sm"
              placeholder="To"
            />
          </div>
        </form>
        <div className="flex items-center gap-3 mt-3">
          <input
            type="number"
            value={userId}
            onChange={(e) => { setUserId(e.target.value); setPage(1) }}
            placeholder="Cashier ID"
            className="border rounded-lg px-3 py-2 text-sm w-32"
          />
          <input
            type="number"
            value={customerId}
            onChange={(e) => { setCustomerId(e.target.value); setPage(1) }}
            placeholder="Customer ID"
            className="border rounded-lg px-3 py-2 text-sm w-32"
          />
          <button
            onClick={() => { setSearch(""); setStatusFilter(""); setSaleTypeFilter(""); setDateFrom(""); setDateTo(""); setUserId(""); setCustomerId(""); setPage(1) }}
            className="text-sm text-blue-600 hover:text-blue-800"
          >
            Clear filters
          </button>
        </div>
      </div>

      <div className="bg-white rounded-lg border overflow-hidden">
        {isLoading ? (
          <div className="flex justify-center py-12">
            <PageLoader />
          </div>
        ) : sales.length === 0 ? (
          <EmptyState title="No sales found" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Receipt #</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Type</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Cashier</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Customer</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-600">Subtotal</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-600">Tax</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-600">Discount</th>
                  <th className="text-right px-4 py-3 font-medium text-gray-600">Total</th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">Date</th>
                  <th className="text-center px-4 py-3 font-medium text-gray-600">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {sales.map((sale) => (
                  <tr
                    key={sale.sale_id}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => openDetail(sale.sale_id)}
                  >
                    <td className="px-4 py-3 font-medium">{sale.receipt_number}</td>
                    <td className="px-4 py-3">
                      <span className="inline-block px-2 py-0.5 text-xs font-medium rounded-full bg-blue-100 text-blue-800">
                        {sale.sale_type}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-block px-2 py-0.5 text-xs font-medium rounded-full ${statusColor(sale.status)}`}>
                        {sale.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">{sale.cashier_name || "—"}</td>
                    <td className="px-4 py-3">{sale.customer_name || "—"}</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(sale.subtotal)}</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(sale.tax_amount)}</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(sale.discount_amount)}</td>
                    <td className="px-4 py-3 text-right font-medium">{formatCurrency(sale.total_amount)}</td>
                    <td className="px-4 py-3">{formatDate(sale.created_at)}</td>
                    <td className="px-4 py-3 text-center">
                      <button
                        onClick={(e) => { e.stopPropagation(); openDetail(sale.sale_id) }}
                        className="text-blue-600 hover:text-blue-800"
                        title="View details"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {total > 0 && (
          <div className="flex items-center justify-between px-4 py-3 border-t">
            <p className="text-sm text-gray-600">
              Showing {((page - 1) * pageSize) + 1} to {Math.min(page * pageSize, total)} of {total} sales
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={prevPage}
                disabled={page <= 1}
                className="px-3 py-1 text-sm border rounded-lg disabled:opacity-50 hover:bg-gray-50"
              >
                Previous
              </button>
              <span className="text-sm text-gray-600">
                Page {page} of {totalPages}
              </span>
              <button
                onClick={nextPage}
                disabled={page >= totalPages}
                className="px-3 py-1 text-sm border rounded-lg disabled:opacity-50 hover:bg-gray-50"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>

      <SaleDetailModal
        saleId={selectedSaleId}
        isOpen={detailOpen}
        onClose={() => { setDetailOpen(false); setSelectedSaleId(null) }}
      />
    </div>
  )
}