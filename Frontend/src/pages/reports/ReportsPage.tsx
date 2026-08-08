import { useState } from "react"
import { useMutation } from "@tanstack/react-query"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { FileText, Download, Calendar, Filter } from "lucide-react"
import toast from "react-hot-toast"
import { apiPost } from "@/api/client"
import { PageLoader, Spinner, EmptyState } from "@/components/feedback"
import { formatCurrency, formatDate } from "@/utils/format"
import type { ReportRequest, ReportResponse } from "@/types"

const REPORT_TYPES = [
  { value: "daily_sales", label: "Daily Sales" },
  { value: "monthly_sales", label: "Monthly Sales" },
  { value: "inventory", label: "Inventory" },
  { value: "profit", label: "Profit" },
  { value: "cashier", label: "Cashier" },
  { value: "supplier", label: "Supplier" },
  { value: "credit", label: "Credit" },
] as const

type ReportType = (typeof REPORT_TYPES)[number]["value"]

interface ReportForm {
  report_type: ReportType
  date_from: string
  date_to: string
  category_id: string
  supplier_id: string
  product_id: string
  cashier_id: string
  customer_id: string
  payment_method_id: string
}

const reportSchema = z.object({
  report_type: z.string().min(1, "Report type is required"),
  date_from: z.string().min(1, "Start date is required"),
  date_to: z.string().min(1, "End date is required"),
  category_id: z.string().optional(),
  supplier_id: z.string().optional(),
  product_id: z.string().optional(),
  cashier_id: z.string().optional(),
  customer_id: z.string().optional(),
  payment_method_id: z.string().optional(),
})

function getReportLabel(type: string): string {
  return REPORT_TYPES.find((r) => r.value === type)?.label ?? type
}

function buildCSV(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return ""
  const headers = Object.keys(rows[0])
  const lines = [
    headers.join(","),
    ...rows.map((row) =>
      headers
        .map((h) => {
          const val = row[h]
          if (val === null || val === undefined) return ""
          const str = String(val)
          return str.includes(",") || str.includes('"') || str.includes("\n")
            ? `"${str.replace(/"/g, '""')}"`
            : str
        })
        .join(",")
    ),
  ]
  return lines.join("\n")
}

function downloadCSV(rows: Record<string, unknown>[], filename: string) {
  const csv = buildCSV(rows)
  if (!csv) return
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" })
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}

export function ReportsPage() {
  const [reportResult, setReportResult] = useState<ReportResponse | null>(null)

  const form = useForm<ReportForm>({
    resolver: zodResolver(reportSchema),
    defaultValues: {
      report_type: "daily_sales",
      date_from: "",
      date_to: "",
      category_id: "",
      supplier_id: "",
      product_id: "",
      cashier_id: "",
      customer_id: "",
      payment_method_id: "",
    },
  })

  const watchedType = form.watch("report_type")

  const generateMutation = useMutation({
    mutationFn: (data: ReportForm) => {
      const payload: ReportRequest = {
        report_type: data.report_type,
        date_from: data.date_from,
        date_to: data.date_to,
      }
      if (data.category_id) payload.category_id = Number(data.category_id)
      if (data.supplier_id) payload.supplier_id = Number(data.supplier_id)
      if (data.product_id) payload.product_id = Number(data.product_id)
      if (data.cashier_id) payload.cashier_id = Number(data.cashier_id)
      if (data.customer_id) payload.customer_id = Number(data.customer_id)
      if (data.payment_method_id) payload.payment_method_id = Number(data.payment_method_id)
      return apiPost<ReportResponse>("/reports", payload)
    },
    onSuccess: (response) => {
      setReportResult(response.data)
      toast.success("Report generated successfully")
    },
    onError: (error: Error) => {
      toast.error(error.message || "Failed to generate report")
    },
  })

  const onSubmit = (data: ReportForm) => {
    generateMutation.mutate(data)
  }

  const handleExport = () => {
    if (!reportResult || reportResult.rows.length === 0) return
    const filename = `${reportResult.report_type}_${reportResult.period.date_from}_${reportResult.period.date_to}.csv`
    downloadCSV(reportResult.rows, filename)
  }

  const showCategoryFilter = ["daily_sales", "monthly_sales", "profit", "inventory"].includes(watchedType)
  const showSupplierFilter = ["supplier", "inventory", "daily_sales", "monthly_sales"].includes(watchedType)
  const showProductFilter = ["inventory", "daily_sales", "monthly_sales"].includes(watchedType)
  const showCashierFilter = ["cashier", "daily_sales", "monthly_sales"].includes(watchedType)
  const showCustomerFilter = ["credit", "daily_sales", "monthly_sales"].includes(watchedType)
  const showPaymentMethodFilter = ["daily_sales", "monthly_sales"].includes(watchedType)

  const summaryKeys = reportResult ? Object.keys(reportResult.summary) : []
  const rowKeys = reportResult && reportResult.rows.length > 0 ? Object.keys(reportResult.rows[0]) : []

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
          <p className="mt-1 text-sm text-gray-500">
            Generate and export business reports
          </p>
        </div>
        {reportResult && reportResult.rows.length > 0 && (
          <button
            onClick={handleExport}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
          >
            <Download className="h-4 w-4" />
            Export CSV
          </button>
        )}
      </div>

      <div className="rounded-lg border border-gray-200 bg-white p-6">
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700">
                Report Type
              </label>
              <select
                {...form.register("report_type")}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              >
                {REPORT_TYPES.map((rt) => (
                  <option key={rt.value} value={rt.value}>
                    {rt.label}
                  </option>
                ))}
              </select>
              {form.formState.errors.report_type && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.report_type.message}
                </p>
              )}
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700">
                Date From
              </label>
              <div className="relative">
                <Calendar className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <input
                  type="date"
                  {...form.register("date_from")}
                  className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-3 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              {form.formState.errors.date_from && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.date_from.message}
                </p>
              )}
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700">
                Date To
              </label>
              <div className="relative">
                <Calendar className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <input
                  type="date"
                  {...form.register("date_to")}
                  className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-3 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              {form.formState.errors.date_to && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.date_to.message}
                </p>
              )}
            </div>
          </div>

          <div className="flex items-center gap-1 text-sm font-medium text-gray-700">
            <Filter className="h-4 w-4" />
            Additional Filters
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {showCategoryFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Category ID
                </label>
                <input
                  type="number"
                  {...form.register("category_id")}
                  placeholder="All categories"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
            {showSupplierFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Supplier ID
                </label>
                <input
                  type="number"
                  {...form.register("supplier_id")}
                  placeholder="All suppliers"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
            {showProductFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Product ID
                </label>
                <input
                  type="number"
                  {...form.register("product_id")}
                  placeholder="All products"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
            {showCashierFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Cashier ID
                </label>
                <input
                  type="number"
                  {...form.register("cashier_id")}
                  placeholder="All cashiers"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
            {showCustomerFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Customer ID
                </label>
                <input
                  type="number"
                  {...form.register("customer_id")}
                  placeholder="All customers"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
            {showPaymentMethodFilter && (
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">
                  Payment Method ID
                </label>
                <input
                  type="number"
                  {...form.register("payment_method_id")}
                  placeholder="All payment methods"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
          </div>

          <div className="flex justify-end pt-2">
            <button
              type="submit"
              disabled={generateMutation.isPending}
              className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 transition-colors"
            >
              {generateMutation.isPending ? (
                <Spinner className="h-4 w-4" />
              ) : (
                <FileText className="h-4 w-4" />
              )}
              {generateMutation.isPending ? "Generating..." : "Generate Report"}
            </button>
          </div>
        </form>
      </div>

      {generateMutation.isPending && (
        <div className="flex justify-center py-12">
          <PageLoader />
        </div>
      )}

      {!generateMutation.isPending && !reportResult && (
        <EmptyState
          title="Configure the filters above and click Generate Report to view results"
          icon={<FileText className="h-12 w-12 text-gray-400" />}
        />
      )}

      {reportResult && !generateMutation.isPending && (
        <div className="space-y-6">
          <div className="rounded-lg border border-gray-200 bg-white p-6">
            <h2 className="mb-1 text-lg font-semibold text-gray-900">
              {getReportLabel(reportResult.report_type)}
            </h2>
            <p className="mb-6 text-sm text-gray-500">
              Period: {formatDate(reportResult.period.date_from)} —{" "}
              {formatDate(reportResult.period.date_to)}
            </p>

            {summaryKeys.length > 0 && (
              <div className="mb-6">
                <h3 className="mb-3 text-sm font-semibold text-gray-700 uppercase tracking-wider">
                  Summary
                </h3>
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
                  {summaryKeys.map((key) => {
                    const value = reportResult.summary[key]
                    const display = typeof value === "number" ? formatCurrency(value) : String(value ?? "—")
                    return (
                      <div
                        key={key}
                        className="rounded-lg border border-gray-200 bg-gray-50 p-3"
                      >
                        <p className="text-xs font-medium text-gray-500 uppercase">
                          {key.replace(/_/g, " ")}
                        </p>
                        <p className="mt-1 text-lg font-bold text-gray-900">
                          {display}
                        </p>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            {reportResult.rows.length > 0 ? (
              <div className="overflow-x-auto rounded-lg border border-gray-200">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      {rowKeys.map((key) => (
                        <th
                          key={key}
                          className="whitespace-nowrap px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
                        >
                          {key.replace(/_/g, " ")}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {reportResult.rows.map((row, idx) => (
                      <tr key={idx} className="hover:bg-gray-50">
                        {rowKeys.map((key) => {
                          const value = row[key]
                          const isCurrency =
                            typeof value === "number" &&
                            (key.toLowerCase().includes("amount") ||
                              key.toLowerCase().includes("total") ||
                              key.toLowerCase().includes("price") ||
                              key.toLowerCase().includes("cost") ||
                              key.toLowerCase().includes("revenue") ||
                              key.toLowerCase().includes("profit"))
                          return (
                            <td
                              key={key}
                              className="whitespace-nowrap px-4 py-3 text-sm text-gray-700"
                            >
                              {isCurrency
                                ? formatCurrency(value as number)
                                : value === null || value === undefined
                                  ? "—"
                                  : String(value)}
                            </td>
                          )
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <EmptyState
                title="No data available for the selected filters"
                icon={<FileText className="h-12 w-12 text-gray-400" />}
              />
            )}

            {reportResult.rows.length > 0 && (
              <div className="mt-4 flex items-center justify-between text-sm text-gray-500">
                <span>{reportResult.rows.length} row(s) returned</span>
                <button
                  onClick={handleExport}
                  className="inline-flex items-center gap-1 text-blue-600 hover:text-blue-800 transition-colors"
                >
                  <Download className="h-4 w-4" />
                  Download CSV
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
