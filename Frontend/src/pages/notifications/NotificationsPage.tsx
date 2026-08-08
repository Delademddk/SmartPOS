import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Bell,
  Check,
  CheckCheck,
  Trash2,
  Info,
  AlertTriangle,
  AlertCircle,
} from "lucide-react"
import toast from "react-hot-toast"
import { apiGet, apiPost } from "@/api/client"
import { usePagination } from "@/hooks/usePagination"
import { PageLoader, EmptyState } from "@/components/feedback"
import { formatDateTime, statusColor } from "@/utils/format"
import type { Notification, NotificationType } from "@/types"

type SeverityFilter = "" | "INFO" | "WARNING" | "CRITICAL"
type ReadFilter = "" | "true" | "false"

function severityIcon(severity: string) {
  switch (severity) {
    case "CRITICAL":
      return <AlertCircle className="h-5 w-5 text-red-500" />
    case "WARNING":
      return <AlertTriangle className="h-5 w-5 text-yellow-500" />
    default:
      return <Info className="h-5 w-5 text-blue-500" />
  }
}

function severityBg(severity: string) {
  switch (severity) {
    case "CRITICAL":
      return "border-l-red-500 bg-red-50"
    case "WARNING":
      return "border-l-yellow-500 bg-yellow-50"
    default:
      return "border-l-blue-500 bg-blue-50"
  }
}

export function NotificationsPage() {
  const queryClient = useQueryClient()
  const { page, pageSize, setPage } = usePagination()
  const [isReadFilter, setIsReadFilter] = useState<ReadFilter>("")
  const [severityFilter, setSeverityFilter] = useState<SeverityFilter>("")
  const [selectedNotification, setSelectedNotification] =
    useState<Notification | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: [
      "notifications",
      page,
      pageSize,
      isReadFilter,
      severityFilter,
    ],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      })
      if (isReadFilter) params.set("is_read", isReadFilter)
      if (severityFilter) params.set("severity", severityFilter)
      const res = await apiGet<Notification[]>(`/notifications?${params}`)
      return { data: res.data, meta: res.meta! }
    },
  })

  const { data: unreadCount } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: async () => {
      const res = await apiGet<{ count: number }>("/notifications/unread-count")
      return res.data
    },
  })

  const readMutation = useMutation({
    mutationFn: (notificationId: number) =>
      apiPost(`/notifications/${notificationId}/read`),
    onSuccess: () => {
      toast.success("Notification marked as read")
      queryClient.invalidateQueries({ queryKey: ["notifications"] })
      setSelectedNotification(null)
    },
    onError: () => toast.error("Failed to mark notification as read"),
  })

  const dismissMutation = useMutation({
    mutationFn: (notificationId: number) =>
      apiPost(`/notifications/${notificationId}/dismiss`),
    onSuccess: () => {
      toast.success("Notification dismissed")
      queryClient.invalidateQueries({ queryKey: ["notifications"] })
      setSelectedNotification(null)
    },
    onError: () => toast.error("Failed to dismiss notification"),
  })

  const markAllReadMutation = useMutation({
    mutationFn: () => apiPost("/notifications/mark-all-read"),
    onSuccess: () => {
      toast.success("All notifications marked as read")
      queryClient.invalidateQueries({ queryKey: ["notifications"] })
    },
    onError: () => toast.error("Failed to mark all as read"),
  })

  if (isLoading) return <PageLoader />

  return (
    <div>
      <div className="page-header">
        <div className="flex items-center gap-3">
          <h1 className="page-title">Notifications</h1>
          {unreadCount && unreadCount.count > 0 && (
            <span className="inline-flex items-center justify-center rounded-full bg-red-500 px-2.5 py-0.5 text-xs font-medium text-white">
              {unreadCount.count}
            </span>
          )}
        </div>
        {unreadCount && unreadCount.count > 0 && (
          <button
            onClick={() => markAllReadMutation.mutate()}
            disabled={markAllReadMutation.isPending}
            className="btn-primary"
          >
            <CheckCheck className="h-4 w-4" />
            {markAllReadMutation.isPending ? "Marking..." : "Mark All as Read"}
          </button>
        )}
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <select
            value={isReadFilter}
            onChange={(e) => {
              setIsReadFilter(e.target.value as ReadFilter)
              setPage(1)
            }}
            className="input max-w-[180px]"
          >
            <option value="">All Notifications</option>
            <option value="false">Unread</option>
            <option value="true">Read</option>
          </select>
          <select
            value={severityFilter}
            onChange={(e) => {
              setSeverityFilter(e.target.value as SeverityFilter)
              setPage(1)
            }}
            className="input max-w-[180px]"
          >
            <option value="">All Severities</option>
            <option value="INFO">Info</option>
            <option value="WARNING">Warning</option>
            <option value="CRITICAL">Critical</option>
          </select>
          <button
            onClick={() => {
              setIsReadFilter("")
              setSeverityFilter("")
              setPage(1)
            }}
            className="btn-ghost text-sm"
          >
            Clear Filters
          </button>
        </div>
      </div>

      <div className="mb-4">
        <NotificationTypesPanel />
      </div>

      {!data?.data.length ? (
        <EmptyState
          icon={<Bell className="h-8 w-8 text-gray-400" />}
          title="No notifications"
          description="You're all caught up! Notifications will appear here."
        />
      ) : (
        <div className="space-y-2">
          {data.data.map((notification) => (
            <div
              key={notification.notification_id}
              className={`card cursor-pointer border-l-4 p-4 transition-colors ${
                notification.is_dismissed
                  ? "opacity-50"
                  : severityBg(notification.severity)
              } ${!notification.is_read ? "ring-1 ring-blue-200" : ""}`}
              onClick={() => setSelectedNotification(notification)}
            >
              <div className="flex items-start gap-3">
                <div className="mt-0.5 shrink-0">
                  {severityIcon(notification.severity)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <h3
                      className={`text-sm ${
                        !notification.is_read
                          ? "font-semibold text-gray-900"
                          : "font-medium text-gray-700"
                      }`}
                    >
                      {notification.title}
                    </h3>
                    <span
                      className={`inline-block rounded px-1.5 py-0.5 text-xs font-medium ${statusColor(
                        notification.severity
                      )}`}
                    >
                      {notification.severity}
                    </span>
                    <span className="badge-info text-xs">
                      {notification.type_name}
                    </span>
                    {!notification.is_read && (
                      <span className="h-2 w-2 shrink-0 rounded-full bg-blue-500" />
                    )}
                  </div>
                  <p className="mt-1 text-sm text-gray-600 line-clamp-2">
                    {notification.message}
                  </p>
                  <div className="mt-2 flex items-center gap-3 text-xs text-gray-500">
                    <span>{formatDateTime(notification.created_at)}</span>
                    {notification.entity_type && (
                      <span>
                        {notification.entity_type} #{notification.entity_id}
                      </span>
                    )}
                  </div>
                </div>
                <div className="flex shrink-0 items-center gap-1">
                  {!notification.is_read && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        readMutation.mutate(notification.notification_id)
                      }}
                      disabled={readMutation.isPending}
                      className="btn-ghost btn-sm"
                      title="Mark as read"
                    >
                      <Check className="h-4 w-4" />
                    </button>
                  )}
                  {!notification.is_dismissed && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        dismissMutation.mutate(notification.notification_id)
                      }}
                      disabled={dismissMutation.isPending}
                      className="btn-ghost btn-sm text-red-600"
                      title="Dismiss"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {data?.meta && data.meta.total_pages > 1 && (
        <div className="mt-4 flex items-center justify-between">
          <p className="text-sm text-gray-500">
            {data.meta.total_items} total notifications
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage(page - 1)}
              disabled={page <= 1}
              className="btn-secondary btn-sm"
            >
              Previous
            </button>
            <span className="text-sm text-gray-600">
              Page {page} of {data.meta.total_pages}
            </span>
            <button
              onClick={() => setPage(page + 1)}
              disabled={page >= data.meta.total_pages}
              className="btn-secondary btn-sm"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {selectedNotification && (
        <NotificationDetailModal
          notification={selectedNotification}
          onClose={() => setSelectedNotification(null)}
          onMarkRead={(id) => readMutation.mutate(id)}
          onDismiss={(id) => dismissMutation.mutate(id)}
          isReadPending={readMutation.isPending}
          isDismissPending={dismissMutation.isPending}
        />
      )}
    </div>
  )
}

function NotificationTypesPanel() {
  const { data: types, isLoading } = useQuery({
    queryKey: ["notifications", "types"],
    queryFn: async () => {
      const res = await apiGet<NotificationType[]>("/notifications/types")
      return res.data
    },
  })

  if (isLoading) return null
  if (!types?.length) return null

  return (
    <div className="card p-4">
      <h2 className="mb-3 text-sm font-semibold text-gray-900">
        Notification Types
      </h2>
      <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {types.map((type) => (
          <div
            key={type.notification_type_id}
            className="flex items-center gap-3 rounded-lg border border-gray-200 p-3"
          >
            {severityIcon(type.default_severity)}
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-gray-900">
                {type.type_name}
              </p>
              {type.description && (
                <p className="truncate text-xs text-gray-500">
                  {type.description}
                </p>
              )}
            </div>
            <span
              className={`inline-block rounded px-1.5 py-0.5 text-xs font-medium ${statusColor(
                type.default_severity
              )}`}
            >
              {type.default_severity}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

function NotificationDetailModal({
  notification,
  onClose,
  onMarkRead,
  onDismiss,
  isReadPending,
  isDismissPending,
}: {
  notification: Notification
  onClose: () => void
  onMarkRead: (id: number) => void
  onDismiss: (id: number) => void
  isReadPending: boolean
  isDismissPending: boolean
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-lg">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Notification Detail</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded"
          >
            <span className="sr-only">Close</span>
            <span className="text-gray-500 text-lg">&times;</span>
          </button>
        </div>
        <div className="p-6 space-y-4">
          <div className="flex items-start gap-3">
            <div className="mt-0.5 shrink-0">
              {severityIcon(notification.severity)}
            </div>
            <div className="min-w-0 flex-1">
              <h3 className="text-base font-semibold text-gray-900">
                {notification.title}
              </h3>
              <div className="mt-1 flex items-center gap-2">
                <span
                  className={`inline-block rounded px-1.5 py-0.5 text-xs font-medium ${statusColor(
                    notification.severity
                  )}`}
                >
                  {notification.severity}
                </span>
                <span className="badge-info text-xs">
                  {notification.type_name}
                </span>
                {notification.is_read && (
                  <span className="text-xs text-gray-500">Read</span>
                )}
                {notification.is_dismissed && (
                  <span className="text-xs text-gray-500">Dismissed</span>
                )}
              </div>
            </div>
          </div>

          <p className="text-sm text-gray-700 whitespace-pre-wrap">
            {notification.message}
          </p>

          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-gray-500">Received</p>
              <p className="font-medium text-gray-900">
                {formatDateTime(notification.created_at)}
              </p>
            </div>
            {notification.entity_type && (
              <div>
                <p className="text-gray-500">Related Entity</p>
                <p className="font-medium text-gray-900">
                  {notification.entity_type} #{notification.entity_id}
                </p>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            {!notification.is_dismissed && (
              <button
                onClick={() => onDismiss(notification.notification_id)}
                disabled={isDismissPending}
                className="btn-danger"
              >
                <Trash2 className="h-4 w-4" />
                {isDismissPending ? "Dismissing..." : "Dismiss"}
              </button>
            )}
            {!notification.is_read && (
              <button
                onClick={() => onMarkRead(notification.notification_id)}
                disabled={isReadPending}
                className="btn-primary"
              >
                <Check className="h-4 w-4" />
                {isReadPending ? "Marking..." : "Mark as Read"}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
