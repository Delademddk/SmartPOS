import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Search, Shield, Activity, AlertTriangle, Lock } from "lucide-react"
import { apiGet } from "@/api/client"
import { usePagination } from "@/hooks/usePagination"
import { PageLoader, EmptyState } from "@/components/feedback"
import { formatDateTime } from "@/utils/format"
import type { AuditLog, ActivityLog, SecurityLog, ErrorLog } from "@/types"

type TabKey = "audit" | "activity" | "security" | "errors"

interface AuditFilters {
  user_id: string
  resource_type: string
  action_type: string
  date_from: string
  date_to: string
}

interface AuditLogsResponse {
  items: AuditLog[]
  total: number
  page: number
  per_page: number
}

interface ActivityLogsResponse {
  items: ActivityLog[]
  total: number
  page: number
  per_page: number
}

interface SecurityLogsResponse {
  items: SecurityLog[]
  total: number
  page: number
  per_page: number
}

interface ErrorLogsResponse {
  items: ErrorLog[]
  total: number
  page: number
  per_page: number
}

const TABS: { key: TabKey; label: string; icon: React.ElementType }[] = [
  { key: "audit", label: "Audit Logs", icon: Shield },
  { key: "activity", label: "Activity", icon: Activity },
  { key: "security", label: "Security", icon: Lock },
  { key: "errors", label: "Errors", icon: AlertTriangle },
]

const RESOURCE_TYPES = [
  "",
  "product",
  "order",
  "payment",
  "user",
  "inventory",
  "discount",
  "settings",
]

const ACTION_TYPES = [
  "",
  "create",
  "read",
  "update",
  "delete",
  "login",
  "logout",
  "export",
  "import",
]

function AuditLogsTable() {
  const [filters, setFilters] = useState<AuditFilters>({
    user_id: "",
    resource_type: "",
    action_type: "",
    date_from: "",
    date_to: "",
  })
  const [searchTerm, setSearchTerm] = useState("")
  const pagination = usePagination({ defaultPerPage: 20 })

  const queryParams: Record<string, string | number> = {
    page: pagination.page,
    per_page: pagination.per_page,
  }
  if (filters.user_id) queryParams.user_id = filters.user_id
  if (filters.resource_type) queryParams.resource_type = filters.resource_type
  if (filters.action_type) queryParams.action_type = filters.action_type
  if (filters.date_from) queryParams.date_from = filters.date_from
  if (filters.date_to) queryParams.date_to = filters.date_to

  const { data, isLoading } = useQuery<AuditLogsResponse>({
    queryKey: ["audit-logs", queryParams],
    queryFn: () => apiGet("/audit/logs", { params: queryParams }),
  })

  const filteredItems = (data?.items ?? []).filter((log) => {
    if (!searchTerm) return true
    const term = searchTerm.toLowerCase()
    return (
      log.username.toLowerCase().includes(term) ||
      log.action_type.toLowerCase().includes(term) ||
      log.resource_type.toLowerCase().includes(term) ||
      log.resource_id.toLowerCase().includes(term)
    )
  })

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[200px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Search</label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by user, action, resource..."
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">User ID</label>
          <input
            type="text"
            value={filters.user_id}
            onChange={(e) => setFilters((f) => ({ ...f, user_id: e.target.value }))}
            placeholder="Filter by user"
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Resource Type</label>
          <select
            value={filters.resource_type}
            onChange={(e) => setFilters((f) => ({ ...f, resource_type: e.target.value }))}
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            {RESOURCE_TYPES.map((rt) => (
              <option key={rt} value={rt}>
                {rt || "All Resources"}
              </option>
            ))}
          </select>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Action Type</label>
          <select
            value={filters.action_type}
            onChange={(e) => setFilters((f) => ({ ...f, action_type: e.target.value }))}
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            {ACTION_TYPES.map((at) => (
              <option key={at} value={at}>
                {at || "All Actions"}
              </option>
            ))}
          </select>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Date From</label>
          <input
            type="date"
            value={filters.date_from}
            onChange={(e) => setFilters((f) => ({ ...f, date_from: e.target.value }))}
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Date To</label>
          <input
            type="date"
            value={filters.date_to}
            onChange={(e) => setFilters((f) => ({ ...f, date_to: e.target.value }))}
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
        <button
          onClick={() =>
            setFilters({
              user_id: "",
              resource_type: "",
              action_type: "",
              date_from: "",
              date_to: "",
            })
          }
          className="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          Clear Filters
        </button>
      </div>

      <div className="overflow-x-auto bg-white border border-gray-200 rounded-lg">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Action</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Resource</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Resource ID</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Old Value</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">New Value</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">IP Address</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filteredItems.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <EmptyState message="No audit logs found" />
                </td>
              </tr>
            ) : (
              filteredItems.map((log) => (
                <tr key={log.log_id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">{formatDateTime(log.created_at)}</td>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{log.username}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {log.action_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700">{log.resource_type}</td>
                  <td className="px-4 py-3 text-sm text-gray-500 font-mono">{log.resource_id}</td>
                  <td className="px-4 py-3 text-sm text-gray-500 max-w-[200px] truncate" title={log.old_value || undefined}>
                    {log.old_value || "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 max-w-[200px] truncate" title={log.new_value || undefined}>
                    {log.new_value || "—"}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 font-mono">{log.ip_address}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data && data.total > 0 && (
        <PaginationBar
          page={pagination.page}
          perPage={pagination.per_page}
          total={data.total}
          onPageChange={pagination.setPage}
          onPerPageChange={pagination.setPerPage}
        />
      )}
    </div>
  )
}

function ActivityLogsTable() {
  const [userId, setUserId] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const pagination = usePagination({ defaultPerPage: 20 })

  const queryParams: Record<string, string | number> = {
    page: pagination.page,
    per_page: pagination.per_page,
  }
  if (userId) queryParams.user_id = userId

  const { data, isLoading } = useQuery<ActivityLogsResponse>({
    queryKey: ["activity-logs", queryParams],
    queryFn: () => apiGet("/audit/activity", { params: queryParams }),
  })

  const filteredItems = (data?.items ?? []).filter((log) => {
    if (!searchTerm) return true
    const term = searchTerm.toLowerCase()
    return (
      log.username.toLowerCase().includes(term) ||
      log.action.toLowerCase().includes(term) ||
      log.description.toLowerCase().includes(term)
    )
  })

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[200px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Search</label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by user, action, description..."
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">User ID</label>
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="Filter by user"
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      <div className="overflow-x-auto bg-white border border-gray-200 rounded-lg">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Action</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Description</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">IP Address</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filteredItems.length === 0 ? (
              <tr>
                <td colSpan={5}>
                  <EmptyState message="No activity logs found" />
                </td>
              </tr>
            ) : (
              filteredItems.map((log) => (
                <tr key={log.activity_id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">{formatDateTime(log.created_at)}</td>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{log.username}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      {log.action}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700 max-w-[300px] truncate" title={log.description}>
                    {log.description}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 font-mono">{log.ip_address}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data && data.total > 0 && (
        <PaginationBar
          page={pagination.page}
          perPage={pagination.per_page}
          total={data.total}
          onPageChange={pagination.setPage}
          onPerPageChange={pagination.setPerPage}
        />
      )}
    </div>
  )
}

function SecurityLogsTable() {
  const [userId, setUserId] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const pagination = usePagination({ defaultPerPage: 20 })

  const queryParams: Record<string, string | number> = {
    page: pagination.page,
    per_page: pagination.per_page,
  }
  if (userId) queryParams.user_id = userId

  const { data, isLoading } = useQuery<SecurityLogsResponse>({
    queryKey: ["security-logs", queryParams],
    queryFn: () => apiGet("/audit/security", { params: queryParams }),
  })

  const filteredItems = (data?.items ?? []).filter((log) => {
    if (!searchTerm) return true
    const term = searchTerm.toLowerCase()
    return (
      log.username.toLowerCase().includes(term) ||
      log.event_type.toLowerCase().includes(term) ||
      log.description.toLowerCase().includes(term)
    )
  })

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[200px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Search</label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by user, event type, description..."
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">User ID</label>
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="Filter by user"
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      <div className="overflow-x-auto bg-white border border-gray-200 rounded-lg">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Event Type</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Description</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">IP Address</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User Agent</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filteredItems.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  <EmptyState message="No security logs found" />
                </td>
              </tr>
            ) : (
              filteredItems.map((log) => (
                <tr key={log.security_log_id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">{formatDateTime(log.created_at)}</td>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{log.username}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      {log.event_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700 max-w-[300px] truncate" title={log.description}>
                    {log.description}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 font-mono">{log.ip_address}</td>
                  <td className="px-4 py-3 text-sm text-gray-500 max-w-[200px] truncate" title={log.user_agent}>
                    {log.user_agent}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data && data.total > 0 && (
        <PaginationBar
          page={pagination.page}
          perPage={pagination.per_page}
          total={data.total}
          onPageChange={pagination.setPage}
          onPerPageChange={pagination.setPerPage}
        />
      )}
    </div>
  )
}

function ErrorLogsTable() {
  const [userId, setUserId] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const pagination = usePagination({ defaultPerPage: 20 })

  const queryParams: Record<string, string | number> = {
    page: pagination.page,
    per_page: pagination.per_page,
  }
  if (userId) queryParams.user_id = userId

  const { data, isLoading } = useQuery<ErrorLogsResponse>({
    queryKey: ["error-logs", queryParams],
    queryFn: () => apiGet("/audit/errors", { params: queryParams }),
  })

  const filteredItems = (data?.items ?? []).filter((log) => {
    if (!searchTerm) return true
    const term = searchTerm.toLowerCase()
    return (
      log.username.toLowerCase().includes(term) ||
      log.error_type.toLowerCase().includes(term) ||
      log.message.toLowerCase().includes(term)
    )
  })

  if (isLoading) return <PageLoader />

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[200px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">Search</label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by user, error type, message..."
              className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
        <div className="min-w-[150px]">
          <label className="block text-xs font-medium text-gray-500 mb-1">User ID</label>
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="Filter by user"
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      <div className="overflow-x-auto bg-white border border-gray-200 rounded-lg">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Error Type</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Message</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">IP Address</th>
              <th className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Stack Trace</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filteredItems.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  <EmptyState message="No error logs found" />
                </td>
              </tr>
            ) : (
              filteredItems.map((log) => (
                <tr key={log.error_log_id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">{formatDateTime(log.created_at)}</td>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{log.username}</td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                      {log.error_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700 max-w-[300px] truncate" title={log.message}>
                    {log.message}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 font-mono">{log.ip_address}</td>
                  <td className="px-4 py-3 text-sm text-gray-500 max-w-[250px] truncate font-mono" title={log.stack_trace || undefined}>
                    {log.stack_trace || "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data && data.total > 0 && (
        <PaginationBar
          page={pagination.page}
          perPage={pagination.per_page}
          total={data.total}
          onPageChange={pagination.setPage}
          onPerPageChange={pagination.setPerPage}
        />
      )}
    </div>
  )
}

interface PaginationBarProps {
  page: number
  perPage: number
  total: number
  onPageChange: (page: number) => void
  onPerPageChange: (perPage: number) => void
}

function PaginationBar({ page, perPage, total, onPageChange, onPerPageChange }: PaginationBarProps) {
  const totalPages = Math.ceil(total / perPage)
  const start = (page - 1) * perPage + 1
  const end = Math.min(page * perPage, total)

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 bg-white border border-gray-200 rounded-lg">
      <div className="flex items-center gap-2 text-sm text-gray-600">
        <span>Showing</span>
        <span className="font-medium text-gray-900">
          {start}–{end}
        </span>
        <span>of</span>
        <span className="font-medium text-gray-900">{total}</span>
      </div>
      <div className="flex items-center gap-2">
        <label className="text-sm text-gray-600">Per page:</label>
        <select
          value={perPage}
          onChange={(e) => onPerPageChange(Number(e.target.value))}
          className="px-2 py-1 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
        >
          {[10, 20, 50, 100].map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
        <div className="flex items-center gap-1 ml-2">
          <button
            onClick={() => onPageChange(1)}
            disabled={page === 1}
            className="px-2.5 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            First
          </button>
          <button
            onClick={() => onPageChange(page - 1)}
            disabled={page === 1}
            className="px-2.5 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Prev
          </button>
          {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
            const startPage = Math.max(1, Math.min(page - 2, totalPages - 4))
            const pageNum = startPage + i
            if (pageNum > totalPages) return null
            return (
              <button
                key={pageNum}
                onClick={() => onPageChange(pageNum)}
                className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
                  pageNum === page
                    ? "bg-blue-600 text-white border border-blue-600"
                    : "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"
                }`}
              >
                {pageNum}
              </button>
            )
          })}
          <button
            onClick={() => onPageChange(page + 1)}
            disabled={page === totalPages}
            className="px-2.5 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Next
          </button>
          <button
            onClick={() => onPageChange(totalPages)}
            disabled={page === totalPages}
            className="px-2.5 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Last
          </button>
        </div>
      </div>
    </div>
  )
}

const TAB_COMPONENTS: Record<TabKey, React.ComponentType> = {
  audit: AuditLogsTable,
  activity: ActivityLogsTable,
  security: SecurityLogsTable,
  errors: ErrorLogsTable,
}

export default function AuditPage() {
  const [activeTab, setActiveTab] = useState<TabKey>("audit")
  const ActiveComponent = TAB_COMPONENTS[activeTab]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Audit Logs</h1>
        <p className="text-sm text-gray-500 mt-1">Monitor system activity, security events, and errors</p>
      </div>

      <div className="border-b border-gray-200">
        <nav className="flex gap-0 -mb-px" role="tablist">
          {TABS.map((tab) => {
            const Icon = tab.icon
            const isActive = activeTab === tab.key
            return (
              <button
                key={tab.key}
                role="tab"
                aria-selected={isActive}
                onClick={() => setActiveTab(tab.key)}
                className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                  isActive
                    ? "border-blue-600 text-blue-600"
                    : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                }`}
              >
                <Icon className="h-4 w-4" />
                {tab.label}
              </button>
            )
          })}
        </nav>
      </div>

      <div role="tabpanel">
        <ActiveComponent />
      </div>
    </div>
  )
}
