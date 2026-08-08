import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Plus, Search, Edit2, X, DollarSign, Clock, UserCheck } from "lucide-react"
import toast from "react-hot-toast"
import { apiGet, apiPost, apiPut, apiDelete } from "@/api/client"
import { usePagination } from "@/hooks/usePagination"
import { PageLoader, EmptyState, Spinner } from "@/components/feedback"
import { formatDate, formatDateTime, formatCurrency, statusColor } from "@/utils/format"
import type { CreditSale, Customer, CreditPayment, PaymentMethod } from "@/types"

const customerSchema = z.object({
  customer_name: z.string().min(1, "Name is required"),
  email: z.string().email("Invalid email").optional().or(z.literal("")),
  phone: z.string().optional().or(z.literal("")),
  address: z.string().optional().or(z.literal("")),
  credit_limit: z.coerce.number().min(0, "Must be 0 or greater").optional(),
})

type CustomerForm = z.infer<typeof customerSchema>

const settlementSchema = z.object({
  amount: z.coerce.number().positive("Must be greater than 0"),
  payment_method_id: z.coerce.number().min(1, "Select a payment method"),
  notes: z.string().optional().or(z.literal("")),
})

type SettlementForm = z.infer<typeof settlementSchema>

type Tab = "sales" | "customers"

const STATUS_OPTIONS = ["OPEN", "PARTIAL", "SETTLED", "OVERDUE", "WRITTEN_OFF"] as const

export default function CreditsPage() {
  const queryClient = useQueryClient()
  const [tab, setTab] = useState<Tab>("sales")
  const [searchQuery, setSearchQuery] = useState("")
  const [statusFilter, setStatusFilter] = useState<string>("")
  const [customerFilter, setCustomerFilter] = useState<string>("")

  const [selectedSale, setSelectedSale] = useState<CreditSale | null>(null)
  const [showDetail, setShowDetail] = useState(false)
  const [showSettlement, setShowSettlement] = useState(false)

  const [showCustomerModal, setShowCustomerModal] = useState(false)
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null)

  const {
    page,
    limit,
    totalPages,
    setTotalPages,
    setPage,
    paginationParams,
  } = usePagination()

  // ─── Credit Sales ────────────────────────────────────────────────

  const creditParams: Record<string, string | number> = {
    ...paginationParams,
  }
  if (statusFilter) creditParams.status = statusFilter
  if (customerFilter) creditParams.customer_id = customerFilter

  const { data: salesData, isLoading: salesLoading } = useQuery({
    queryKey: ["credits", "sales", creditParams],
    queryFn: () => apiGet<{ items: CreditSale[]; total: number; pages: number }>("/credits", creditParams),
    onSuccess: (data) => setTotalPages(data.pages),
  })

  // ─── Selected Sale Detail ────────────────────────────────────────

  const { data: saleDetail, isLoading: detailLoading } = useQuery({
    queryKey: ["credits", "sale", selectedSale?.credit_sale_id],
    queryFn: () => apiGet<CreditSale>(`/credits/${selectedSale!.credit_sale_id}`),
    enabled: !!selectedSale,
  })

  const { data: paymentsData, isLoading: paymentsLoading } = useQuery({
    queryKey: ["credits", "payments", selectedSale?.credit_sale_id],
    queryFn: () =>
      apiGet<{ items: CreditPayment[] }>(`/credits/${selectedSale!.credit_sale_id}/payments`),
    enabled: !!selectedSale,
  })

  // ─── Settlement ──────────────────────────────────────────────────

  const { data: methodsData } = useQuery({
    queryKey: ["payment-methods"],
    queryFn: () => apiGet<{ items: PaymentMethod[] }>("/payments/methods"),
  })

  const settlementForm = useForm<SettlementForm>({
    resolver: zodResolver(settlementSchema),
  })

  const settleMutation = useMutation({
    mutationFn: (data: SettlementForm) =>
      apiPost(`/credits/${selectedSale!.credit_sale_id}/settle`, data),
    onSuccess: () => {
      toast.success("Payment recorded")
      setShowSettlement(false)
      setShowDetail(false)
      setSelectedSale(null)
      settlementForm.reset()
      queryClient.invalidateQueries(["credits"])
    },
    onError: () => toast.error("Failed to record payment"),
  })

  // ─── Customers ───────────────────────────────────────────────────

  const {
    page: custPage,
    limit: custLimit,
    totalPages: custTotalPages,
    setTotalPages: setCustTotalPages,
    setPage: setCustPage,
    paginationParams: custPaginationParams,
  } = usePagination()

  const customerParams: Record<string, string | number> = {
    ...custPaginationParams,
  }
  if (searchQuery) customerParams.search = searchQuery

  const { data: customersData, isLoading: customersLoading } = useQuery({
    queryKey: ["credits", "customers", customerParams],
    queryFn: () =>
      apiGet<{ items: Customer[]; total: number; pages: number }>("/credits/customers", customerParams),
    onSuccess: (data) => setCustTotalPages(data.pages),
  })

  const customerForm = useForm<CustomerForm>({
    resolver: zodResolver(customerSchema),
    defaultValues: {
      customer_name: "",
      email: "",
      phone: "",
      address: "",
      credit_limit: 0,
    },
  })

  const createCustomerMutation = useMutation({
    mutationFn: (data: CustomerForm) => {
      const payload = { ...data }
      if (!payload.email) delete payload.email
      if (!payload.phone) delete payload.phone
      if (!payload.address) delete payload.address
      if (payload.credit_limit === undefined || payload.credit_limit === null)
        delete payload.credit_limit
      return apiPost("/credits/customers", payload)
    },
    onSuccess: () => {
      toast.success("Customer created")
      setShowCustomerModal(false)
      customerForm.reset()
      queryClient.invalidateQueries(["credits", "customers"])
    },
    onError: () => toast.error("Failed to create customer"),
  })

  const updateCustomerMutation = useMutation({
    mutationFn: (data: CustomerForm) =>
      apiPut(`/credits/customers/${editingCustomer!.customer_id}`, data),
    onSuccess: () => {
      toast.success("Customer updated")
      setShowCustomerModal(false)
      setEditingCustomer(null)
      customerForm.reset()
      queryClient.invalidateQueries(["credits", "customers"])
    },
    onError: () => toast.error("Failed to update customer"),
  })

  const deleteCustomerMutation = useMutation({
    mutationFn: (id: number) => apiDelete(`/credits/customers/${id}`),
    onSuccess: () => {
      toast.success("Customer deleted")
      queryClient.invalidateQueries(["credits", "customers"])
    },
    onError: () => toast.error("Failed to delete customer"),
  })

  const handleCustomerSubmit = (data: CustomerForm) => {
    if (editingCustomer) {
      updateCustomerMutation.mutate(data)
    } else {
      createCustomerMutation.mutate(data)
    }
  }

  const openCustomerModal = (customer?: Customer) => {
    if (customer) {
      setEditingCustomer(customer)
      customerForm.reset({
        customer_name: customer.customer_name,
        email: customer.email ?? "",
        phone: customer.phone ?? "",
        address: customer.address ?? "",
        credit_limit: customer.credit_limit ?? 0,
      })
    } else {
      setEditingCustomer(null)
      customerForm.reset({
        customer_name: "",
        email: "",
        phone: "",
        address: "",
        credit_limit: 0,
      })
    }
    setShowCustomerModal(true)
  }

  // ─── Settlement submit ──────────────────────────────────────────

  const onSettlementSubmit = (data: SettlementForm) => {
    settleMutation.mutate(data)
  }

  const getSaleStatusColor = (status: string) => statusColor(status)

  // ─── Render ─────────────────────────────────────────────────────

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Credit Management</h1>
      </div>

      {/* Tabs */}
      <div className="flex gap-4 border-b border-gray-200 mb-6">
        <button
          className={`pb-3 px-1 border-b-2 font-medium text-sm transition-colors ${
            tab === "sales"
              ? "border-blue-600 text-blue-600"
              : "border-transparent text-gray-500 hover:text-gray-700"
          }`}
          onClick={() => setTab("sales")}
        >
          Credit Sales
        </button>
        <button
          className={`pb-3 px-1 border-b-2 font-medium text-sm transition-colors ${
            tab === "customers"
              ? "border-blue-600 text-blue-600"
              : "border-transparent text-gray-500 hover:text-gray-700"
          }`}
          onClick={() => setTab("customers")}
        >
          Customers
        </button>
      </div>

      {/* ── Sales Tab ───────────────────────────────────────────── */}
      {tab === "sales" && (
        <div>
          {/* Filters */}
          <div className="flex flex-wrap gap-3 mb-4">
            <div className="relative flex-1 min-w-[200px] max-w-sm">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Filter by customer ID..."
                value={customerFilter}
                onChange={(e) => {
                  setCustomerFilter(e.target.value)
                  setPage(1)
                }}
                className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value)
                setPage(1)
              }}
              className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">All Statuses</option>
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </div>

          {salesLoading ? (
            <PageLoader />
          ) : !salesData?.items?.length ? (
            <EmptyState message="No credit sales found" />
          ) : (
            <>
              <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Receipt
                      </th>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Customer
                      </th>
                      <th className="text-right px-4 py-3 font-medium text-gray-600">
                        Total
                      </th>
                      <th className="text-right px-4 py-3 font-medium text-gray-600">
                        Paid
                      </th>
                      <th className="text-right px-4 py-3 font-medium text-gray-600">
                        Balance
                      </th>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Due Date
                      </th>
                      <th className="text-center px-4 py-3 font-medium text-gray-600">
                        Status
                      </th>
                      <th className="text-center px-4 py-3 font-medium text-gray-600">
                        Overdue
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {salesData.items.map((sale) => (
                      <tr
                        key={sale.credit_sale_id}
                        className="hover:bg-gray-50 cursor-pointer transition-colors"
                        onClick={() => {
                          setSelectedSale(sale)
                          setShowDetail(true)
                          setShowSettlement(false)
                          settlementForm.reset({ amount: 0, payment_method_id: 0, notes: "" })
                        }}
                      >
                        <td className="px-4 py-3 font-mono text-xs">
                          {sale.receipt_number}
                        </td>
                        <td className="px-4 py-3">{sale.customer_name}</td>
                        <td className="px-4 py-3 text-right">
                          {formatCurrency(sale.total_amount)}
                        </td>
                        <td className="px-4 py-3 text-right">
                          {formatCurrency(sale.amount_paid)}
                        </td>
                        <td className="px-4 py-3 text-right font-medium">
                          {formatCurrency(sale.outstanding_balance)}
                        </td>
                        <td className="px-4 py-3">{formatDate(sale.due_date)}</td>
                        <td className="px-4 py-3 text-center">
                          <span
                            className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${getSaleStatusColor(
                              sale.status
                            )}`}
                          >
                            {sale.status}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          {sale.days_overdue != null && sale.days_overdue > 0 ? (
                            <span className="inline-flex items-center gap-1 text-red-600 text-xs font-medium">
                              <Clock className="h-3 w-3" />
                              {sale.days_overdue}d
                            </span>
                          ) : (
                            <span className="text-gray-400">—</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              <div className="flex items-center justify-between mt-4">
                <p className="text-sm text-gray-500">
                  Page {page} of {totalPages}
                </p>
                <div className="flex gap-2">
                  <button
                    onClick={() => setPage(page - 1)}
                    disabled={page <= 1}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Previous
                  </button>
                  <button
                    onClick={() => setPage(page + 1)}
                    disabled={page >= totalPages}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* ── Customers Tab ──────────────────────────────────────── */}
      {tab === "customers" && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="relative flex-1 min-w-[200px] max-w-sm">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search customers..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value)
                  setCustPage(1)
                }}
                className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <button
              onClick={() => openCustomerModal()}
              className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
            >
              <Plus className="h-4 w-4" />
              Add Customer
            </button>
          </div>

          {customersLoading ? (
            <PageLoader />
          ) : !customersData?.items?.length ? (
            <EmptyState message="No customers found" />
          ) : (
            <>
              <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Name
                      </th>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Email
                      </th>
                      <th className="text-left px-4 py-3 font-medium text-gray-600">
                        Phone
                      </th>
                      <th className="text-right px-4 py-3 font-medium text-gray-600">
                        Credit Limit
                      </th>
                      <th className="text-right px-4 py-3 font-medium text-gray-600">
                        Balance
                      </th>
                      <th className="text-center px-4 py-3 font-medium text-gray-600">
                        Active
                      </th>
                      <th className="text-center px-4 py-3 font-medium text-gray-600">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {customersData.items.map((customer) => (
                      <tr key={customer.customer_id} className="hover:bg-gray-50">
                        <td className="px-4 py-3 font-medium">
                          {customer.customer_name}
                        </td>
                        <td className="px-4 py-3 text-gray-500">
                          {customer.email || "—"}
                        </td>
                        <td className="px-4 py-3 text-gray-500">
                          {customer.phone || "—"}
                        </td>
                        <td className="px-4 py-3 text-right">
                          {formatCurrency(customer.credit_limit ?? 0)}
                        </td>
                        <td className="px-4 py-3 text-right font-medium">
                          {formatCurrency(customer.current_balance ?? 0)}
                        </td>
                        <td className="px-4 py-3 text-center">
                          {customer.is_active ? (
                            <span className="inline-block w-2 h-2 bg-green-500 rounded-full" />
                          ) : (
                            <span className="inline-block w-2 h-2 bg-gray-300 rounded-full" />
                          )}
                        </td>
                        <td className="px-4 py-3 text-center">
                          <div className="flex items-center justify-center gap-2">
                            <button
                              onClick={() => openCustomerModal(customer)}
                              className="text-gray-500 hover:text-blue-600 transition-colors"
                              title="Edit"
                            >
                              <Edit2 className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => {
                                if (
                                  window.confirm(
                                    `Delete customer "${customer.customer_name}"?`
                                  )
                                ) {
                                  deleteCustomerMutation.mutate(customer.customer_id)
                                }
                              }}
                              className="text-gray-500 hover:text-red-600 transition-colors"
                              title="Delete"
                            >
                              <X className="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="flex items-center justify-between mt-4">
                <p className="text-sm text-gray-500">
                  Page {custPage} of {custTotalPages}
                </p>
                <div className="flex gap-2">
                  <button
                    onClick={() => setCustPage(custPage - 1)}
                    disabled={custPage <= 1}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Previous
                  </button>
                  <button
                    onClick={() => setCustPage(custPage + 1)}
                    disabled={custPage >= custTotalPages}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* ── Sale Detail Drawer ─────────────────────────────────── */}
      {showDetail && selectedSale && (
        <div className="fixed inset-0 z-50 flex justify-end">
          <div
            className="absolute inset-0 bg-black/30"
            onClick={() => {
              setShowDetail(false)
              setShowSettlement(false)
              setSelectedSale(null)
            }}
          />
          <div className="relative w-full max-w-lg bg-white shadow-xl overflow-y-auto">
            {detailLoading ? (
              <div className="flex items-center justify-center h-full">
                <Spinner />
              </div>
            ) : (
              <div className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-lg font-bold">Credit Sale Detail</h2>
                  <button
                    onClick={() => {
                      setShowDetail(false)
                      setShowSettlement(false)
                      setSelectedSale(null)
                    }}
                    className="text-gray-400 hover:text-gray-600"
                  >
                    <X className="h-5 w-5" />
                  </button>
                </div>

                {/* Sale Info */}
                <div className="space-y-3 mb-6">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Receipt</span>
                    <span className="font-mono">{saleDetail?.receipt_number}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Customer</span>
                    <span>{saleDetail?.customer_name}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Created</span>
                    <span>
                      {saleDetail?.created_at
                        ? formatDateTime(saleDetail.created_at)
                        : "—"}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Due Date</span>
                    <span>{formatDate(saleDetail?.due_date ?? "")}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-500">Status</span>
                    <span
                      className={`px-2 py-0.5 rounded-full text-xs font-medium ${getSaleStatusColor(
                        saleDetail?.status ?? ""
                      )}`}
                    >
                      {saleDetail?.status}
                    </span>
                  </div>
                  {saleDetail?.days_overdue != null && saleDetail.days_overdue > 0 && (
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500">Days Overdue</span>
                      <span className="text-red-600 font-medium">
                        {saleDetail.days_overdue} days
                      </span>
                    </div>
                  )}
                </div>

                {/* Amounts */}
                <div className="bg-gray-50 rounded-lg p-4 mb-6">
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-500">Total Amount</span>
                    <span className="font-medium">
                      {formatCurrency(saleDetail?.total_amount ?? 0)}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-500">Amount Paid</span>
                    <span className="font-medium text-green-600">
                      {formatCurrency(saleDetail?.amount_paid ?? 0)}
                    </span>
                  </div>
                  <div className="border-t border-gray-200 pt-2 mt-2">
                    <div className="flex justify-between text-sm">
                      <span className="font-medium text-gray-700">
                        Outstanding Balance
                      </span>
                      <span className="font-bold text-red-600">
                        {formatCurrency(saleDetail?.outstanding_balance ?? 0)}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Settle Button */}
                {(saleDetail?.status === "OPEN" ||
                  saleDetail?.status === "PARTIAL" ||
                  saleDetail?.status === "OVERDUE") && (
                  <div className="mb-6">
                    {!showSettlement ? (
                      <button
                        onClick={() => {
                          setShowSettlement(true)
                          settlementForm.reset({
                            amount: saleDetail?.outstanding_balance ?? 0,
                            payment_method_id: 0,
                            notes: "",
                          })
                        }}
                        className="w-full flex items-center justify-center gap-2 bg-green-600 text-white py-2.5 rounded-lg font-medium hover:bg-green-700 transition-colors"
                      >
                        <DollarSign className="h-4 w-4" />
                        Settle Payment
                      </button>
                    ) : (
                      <div className="border border-gray-200 rounded-lg p-4">
                        <h3 className="text-sm font-medium mb-3">Record Payment</h3>
                        <form
                          onSubmit={settlementForm.handleSubmit(onSettlementSubmit)}
                          className="space-y-3"
                        >
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">
                              Amount
                            </label>
                            <input
                              type="number"
                              step="0.01"
                              {...settlementForm.register("amount", { valueAsNumber: true })}
                              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                            {settlementForm.formState.errors.amount && (
                              <p className="text-xs text-red-500 mt-1">
                                {settlementForm.formState.errors.amount.message}
                              </p>
                            )}
                          </div>
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">
                              Payment Method
                            </label>
                            <select
                              {...settlementForm.register("payment_method_id", {
                                valueAsNumber: true,
                              })}
                              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                              <option value={0}>Select method...</option>
                              {methodsData?.items?.map((m) => (
                                <option
                                  key={m.payment_method_id}
                                  value={m.payment_method_id}
                                >
                                  {m.name}
                                </option>
                              ))}
                            </select>
                            {settlementForm.formState.errors.payment_method_id && (
                              <p className="text-xs text-red-500 mt-1">
                                {settlementForm.formState.errors.payment_method_id.message}
                              </p>
                            )}
                          </div>
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">
                              Notes
                            </label>
                            <textarea
                              {...settlementForm.register("notes")}
                              rows={2}
                              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                          </div>
                          <div className="flex gap-2">
                            <button
                              type="submit"
                              disabled={settleMutation.isLoading}
                              className="flex-1 bg-green-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-green-700 disabled:opacity-50 transition-colors"
                            >
                              {settleMutation.isLoading ? "Processing..." : "Confirm Payment"}
                            </button>
                            <button
                              type="button"
                              onClick={() => setShowSettlement(false)}
                              className="px-4 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition-colors"
                            >
                              Cancel
                            </button>
                          </div>
                        </form>
                      </div>
                    )}
                  </div>
                )}

                {/* Payment History */}
                <div>
                  <h3 className="text-sm font-medium mb-3">Payment History</h3>
                  {paymentsLoading ? (
                    <div className="flex justify-center py-4">
                      <Spinner />
                    </div>
                  ) : !paymentsData?.items?.length ? (
                    <p className="text-sm text-gray-400 py-4 text-center">
                      No payments recorded
                    </p>
                  ) : (
                    <div className="space-y-2">
                      {paymentsData.items.map((payment) => (
                        <div
                          key={payment.credit_payment_id}
                          className="border border-gray-100 rounded-lg p-3"
                        >
                          <div className="flex justify-between text-sm">
                            <span className="font-medium">
                              {formatCurrency(payment.amount)}
                            </span>
                            <span className="text-xs text-gray-500">
                              {payment.payment_method}
                            </span>
                          </div>
                          {payment.notes && (
                            <p className="text-xs text-gray-500 mt-1">{payment.notes}</p>
                          )}
                          <p className="text-xs text-gray-400 mt-1">
                            {formatDateTime(payment.created_at)}
                          </p>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Customer Modal ─────────────────────────────────────── */}
      {showCustomerModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div
            className="absolute inset-0 bg-black/30"
            onClick={() => {
              setShowCustomerModal(false)
              setEditingCustomer(null)
            }}
          />
          <div className="relative bg-white rounded-xl shadow-xl w-full max-w-md mx-4">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h2 className="text-lg font-bold">
                {editingCustomer ? "Edit Customer" : "New Customer"}
              </h2>
              <button
                onClick={() => {
                  setShowCustomerModal(false)
                  setEditingCustomer(null)
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <form
              onSubmit={customerForm.handleSubmit(handleCustomerSubmit)}
              className="p-6 space-y-4"
            >
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name *
                </label>
                <input
                  type="text"
                  {...customerForm.register("customer_name")}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {customerForm.formState.errors.customer_name && (
                  <p className="text-xs text-red-500 mt-1">
                    {customerForm.formState.errors.customer_name.message}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  {...customerForm.register("email")}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {customerForm.formState.errors.email && (
                  <p className="text-xs text-red-500 mt-1">
                    {customerForm.formState.errors.email.message}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Phone
                </label>
                <input
                  type="text"
                  {...customerForm.register("phone")}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Address
                </label>
                <textarea
                  {...customerForm.register("address")}
                  rows={2}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Credit Limit
                </label>
                <input
                  type="number"
                  step="0.01"
                  {...customerForm.register("credit_limit", { valueAsNumber: true })}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                {customerForm.formState.errors.credit_limit && (
                  <p className="text-xs text-red-500 mt-1">
                    {customerForm.formState.errors.credit_limit.message}
                  </p>
                )}
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  type="submit"
                  disabled={
                    createCustomerMutation.isLoading || updateCustomerMutation.isLoading
                  }
                  className="flex-1 bg-blue-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 transition-colors"
                >
                  {createCustomerMutation.isLoading || updateCustomerMutation.isLoading
                    ? "Saving..."
                    : editingCustomer
                    ? "Update Customer"
                    : "Create Customer"}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowCustomerModal(false)
                    setEditingCustomer(null)
                  }}
                  className="px-4 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
