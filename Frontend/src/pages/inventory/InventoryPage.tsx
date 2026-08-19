import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Search, Edit2, X, Package, AlertTriangle, History } from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader, EmptyState, Spinner } from "@/components/feedback";
import { formatDate, formatDateTime, formatNumber, formatCurrency, statusColor } from "@/utils/format";
import { useCurrency } from "@/hooks/useCurrency";
import type {
  Inventory,
  InventoryMovement,
  LowStockAlert,
  PaginatedResponse,
} from "@/types";

type Tab = "inventory" | "movements" | "low-stock";

const restockSchema = z.object({
  product_id: z.string().min(1, "Product is required"),
  quantity: z.coerce.number().min(1, "Quantity must be at least 1"),
  unit_cost: z.coerce.number().min(0, "Unit cost is required"),
  reason: z.string().min(1, "Reason is required"),
});

type RestockForm = z.infer<typeof restockSchema>;

const adjustStockSchema = z.object({
  product_id: z.string().min(1, "Product is required"),
  adjustment_type: z.enum(["COUNT", "DAMAGE", "THEFT", "EXPIRY", "CORRECTION"]),
  system_quantity: z.coerce.number().min(0),
  counted_quantity: z.coerce.number().min(0),
  quantity_change: z.coerce.number(),
  reason: z.string().min(1, "Reason is required"),
});

type AdjustStockForm = z.infer<typeof adjustStockSchema>;

const stockStatusOptions = [
  { value: "", label: "All Statuses" },
  { value: "IN_STOCK", label: "In Stock" },
  { value: "LOW_STOCK", label: "Low Stock" },
  { value: "OUT_OF_STOCK", label: "Out of Stock" },
];

const movementTypeOptions = [
  { value: "", label: "All Types" },
  { value: "RESTOCK", label: "Restock" },
  { value: "SALE", label: "Sale" },
  { value: "ADJUSTMENT", label: "Adjustment" },
  { value: "RETURN", label: "Return" },
];

const adjustmentTypeOptions = [
  { value: "COUNT", label: "Count" },
  { value: "DAMAGE", label: "Damage" },
  { value: "THEFT", label: "Theft" },
  { value: "EXPIRY", label: "Expiry" },
  { value: "CORRECTION", label: "Correction" },
];

const lowStockStatusOptions = [
  { value: "", label: "All Alerts" },
  { value: "ACTIVE", label: "Active" },
  { value: "ACKNOWLEDGED", label: "Acknowledged" },
  { value: "RESOLVED", label: "Resolved" },
];

function StockStatusBadge({ status }: { status: string }) {
  const color = statusColor(status);
  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${color}`}
    >
      {status.replace(/_/g, " ")}
    </span>
  );
}

function AlertStatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    ACTIVE: "bg-red-100 text-red-800",
    ACKNOWLEDGED: "bg-yellow-100 text-yellow-800",
    RESOLVED: "bg-green-100 text-green-800",
  };
  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colors[status] || "bg-gray-100 text-gray-800"}`}
    >
      {status}
    </span>
  );
}

export function InventoryPage() {
  const queryClient = useQueryClient();
  const { symbol: currencySymbol } = useCurrency();
  const [activeTab, setActiveTab] = useState<Tab>("inventory");
  const [search, setSearch] = useState("");
  const [stockStatusFilter, setStockStatusFilter] = useState("");
  const [movementTypeFilter, setMovementTypeFilter] = useState("");
  const [movementProductIdFilter, setMovementProductIdFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [lowStockStatusFilter, setLowStockStatusFilter] = useState("");
  const [showRestockModal, setShowRestockModal] = useState(false);
  const [showAdjustModal, setShowAdjustModal] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<Inventory | null>(null);
  const [viewProduct, setViewProduct] = useState<Inventory | null>(null);

  const pagination = usePagination({ initialPage: 1, initialPageSize: 20 });
  const movementsPagination = usePagination({ initialPage: 1, initialPageSize: 20 });
  const lowStockPagination = usePagination({ initialPage: 1, initialPageSize: 20 });

  const {
    data: inventoryData,
    isLoading: inventoryLoading,
  } = useQuery<PaginatedResponse<Inventory>>({
    queryKey: [
      "inventory",
      pagination.page,
      pagination.pageSize,
      search,
      stockStatusFilter,
    ],
    queryFn: async () => {
      const res = await apiGet<Inventory[]>("/inventory", {
        params: {
          page: pagination.page,
          page_size: pagination.pageSize,
          search: search || undefined,
          stock_status: stockStatusFilter || undefined,
        },
      });
      return { data: res.data, meta: res.meta! };
    },
  });

  const {
    data: movementsData,
  } = useQuery<PaginatedResponse<InventoryMovement>>({
    queryKey: [
      "inventory-movements",
      movementsPagination.page,
      movementsPagination.pageSize,
      movementTypeFilter,
      movementProductIdFilter,
      dateFrom,
      dateTo,
    ],
    queryFn: async () => {
      const res = await apiGet<InventoryMovement[]>("/inventory/movements", {
        params: {
          page: movementsPagination.page,
          page_size: movementsPagination.pageSize,
          product_id: movementProductIdFilter || undefined,
          movement_type: movementTypeFilter || undefined,
          date_from: dateFrom || undefined,
          date_to: dateTo || undefined,
        },
      });
      return { data: res.data, meta: res.meta! };
    },
    enabled: activeTab === "movements",
  });

  const {
    data: lowStockData,
  } = useQuery<PaginatedResponse<LowStockAlert>>({
    queryKey: [
      "inventory-low-stock",
      lowStockPagination.page,
      lowStockPagination.pageSize,
      lowStockStatusFilter,
    ],
    queryFn: async () => {
      const res = await apiGet<LowStockAlert[]>("/inventory/low-stock", {
        params: {
          page: lowStockPagination.page,
          page_size: lowStockPagination.pageSize,
          status: lowStockStatusFilter || undefined,
        },
      });
      return { data: res.data, meta: res.meta! };
    },
    enabled: activeTab === "low-stock",
  });

  const {
    data: productDetail,
    isLoading: productDetailLoading,
  } = useQuery<Inventory>({
    queryKey: ["inventory-product", viewProduct?.product_id],
    queryFn: async () => {
      const res = await apiGet<Inventory>(`/inventory/product/${viewProduct?.product_id}`);
      return res.data;
    },
    enabled: !!viewProduct,
  });

  const restockMutation = useMutation({
    mutationFn: (data: RestockForm) =>
      apiPost("/inventory/restock", {
        product_id: Number(data.product_id),
        quantity: data.quantity,
        unit_cost: data.unit_cost,
        reason: data.reason,
      }),
    onSuccess: () => {
      toast.success("Stock restocked successfully");
      queryClient.invalidateQueries({ queryKey: ["inventory"] });
      queryClient.invalidateQueries({ queryKey: ["inventory-movements"] });
      queryClient.invalidateQueries({ queryKey: ["inventory-low-stock"] });
      queryClient.invalidateQueries({ queryKey: ["products"] });
      queryClient.invalidateQueries({ queryKey: ["pos-products"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      setShowRestockModal(false);
      setSelectedProduct(null);
    },
    onError: (error: Error) => {
      toast.error(error.message || "Failed to restock");
    },
  });

  const adjustMutation = useMutation({
    mutationFn: (data: AdjustStockForm) =>
      apiPost("/inventory/adjust", {
        product_id: Number(data.product_id),
        adjustment_type: data.adjustment_type,
        system_quantity: data.system_quantity,
        counted_quantity: data.counted_quantity,
        quantity_change: data.quantity_change,
        reason: data.reason,
      }),
    onSuccess: () => {
      toast.success("Stock adjusted successfully");
      queryClient.invalidateQueries({ queryKey: ["inventory"] });
      queryClient.invalidateQueries({ queryKey: ["inventory-movements"] });
      queryClient.invalidateQueries({ queryKey: ["inventory-low-stock"] });
      queryClient.invalidateQueries({ queryKey: ["products"] });
      queryClient.invalidateQueries({ queryKey: ["pos-products"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      setShowAdjustModal(false);
      setSelectedProduct(null);
    },
    onError: (error: Error) => {
      toast.error(error.message || "Failed to adjust stock");
    },
  });

  const restockForm = useForm<RestockForm>({
    resolver: zodResolver(restockSchema),
    defaultValues: {
      product_id: "",
      quantity: 1,
      unit_cost: 0,
      reason: "",
    },
  });

  const adjustForm = useForm<AdjustStockForm>({
    resolver: zodResolver(adjustStockSchema),
    defaultValues: {
      product_id: "",
      adjustment_type: "COUNT",
      system_quantity: 0,
      counted_quantity: 0,
      quantity_change: 0,
      reason: "",
    },
  });

  const watchedSystemQty = adjustForm.watch("system_quantity");
  const watchedCountedQty = adjustForm.watch("counted_quantity");

  const items = inventoryData?.data ?? [];
  const totalInventoryItems = inventoryData?.meta.total_items ?? 0;
  const movements = movementsData?.data ?? [];
  const totalMovements = movementsData?.meta.total_items ?? 0;
  const lowStockAlerts = lowStockData?.data ?? [];
  const totalLowStock = lowStockData?.meta.total_items ?? 0;

  function openRestock(item?: Inventory) {
    if (item) {
      setSelectedProduct(item);
      restockForm.setValue("product_id", String(item.product_id));
    } else {
      setSelectedProduct(null);
      restockForm.reset({ product_id: "", quantity: 1, unit_cost: 0, reason: "" });
    }
    setShowRestockModal(true);
  }

  function openAdjust(item?: Inventory) {
    if (item) {
      setSelectedProduct(item);
      adjustForm.setValue("product_id", String(item.product_id));
      adjustForm.setValue("system_quantity", item.quantity_on_hand);
      adjustForm.setValue("counted_quantity", item.quantity_on_hand);
      adjustForm.setValue("quantity_change", 0);
    } else {
      setSelectedProduct(null);
      adjustForm.reset({
        product_id: "",
        adjustment_type: "COUNT",
        system_quantity: 0,
        counted_quantity: 0,
        quantity_change: 0,
        reason: "",
      });
    }
    setShowAdjustModal(true);
  }

  function handleTabChange(tab: Tab) {
    setActiveTab(tab);
  }

  if (inventoryLoading && activeTab === "inventory" && items.length === 0) {
    return <PageLoader />;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Inventory Management</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage stock levels, restock, and track inventory movements
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => openRestock()}
            className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Restock
          </button>
          <button
            onClick={() => openAdjust()}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
          >
            <Edit2 className="h-4 w-4" />
            Adjust Stock
          </button>
        </div>
      </div>

      <div className="border-b border-gray-200">
        <nav className="-mb-px flex gap-6">
          {[
            { key: "inventory" as Tab, label: "Inventory", icon: Package },
            { key: "movements" as Tab, label: "Movements", icon: History },
            { key: "low-stock" as Tab, label: "Low Stock Alerts", icon: AlertTriangle },
          ].map(({ key, label, icon: Icon }) => (
            <button
              key={key}
              onClick={() => handleTabChange(key)}
              className={`flex items-center gap-2 border-b-2 py-3 px-1 text-sm font-medium transition-colors ${
                activeTab === key
                  ? "border-blue-500 text-blue-600"
                  : "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
              }`}
            >
              <Icon className="h-4 w-4" />
              {label}
              {key === "low-stock" && totalLowStock > 0 && (
                <span className="ml-1 rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">
                  {totalLowStock}
                </span>
              )}
            </button>
          ))}
        </nav>
      </div>

      {activeTab === "inventory" && (
        <div className="space-y-4">
          <div className="flex flex-col gap-4 sm:flex-row">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Search by name or SKU..."
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  pagination.setPage(1);
                }}
                className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <select
              value={stockStatusFilter}
              onChange={(e) => {
                setStockStatusFilter(e.target.value);
                pagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              {stockStatusOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>

          <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Product
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    SKU
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    On Hand
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Reserved
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Available
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Low Stock Threshold
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Last Restock
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Last Sold
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {items.map((item) => (
                  <tr key={item.inventory_id} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-4 py-3">
                      <button
                        onClick={() => setViewProduct(item)}
                        className="text-sm font-medium text-blue-600 hover:text-blue-800"
                      >
                        {item.product_name}
                      </button>
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {item.sku}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-medium text-gray-900">
                      {formatNumber(item.quantity_on_hand)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-gray-500">
                      {formatNumber(item.quantity_reserved)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-medium text-gray-900">
                      {formatNumber(item.available_quantity)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-gray-500">
                      {formatNumber(item.low_stock_threshold ?? 0)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-center">
                      <StockStatusBadge status={item.stock_status} />
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {item.last_restocked_at ? formatDate(item.last_restocked_at) : "-"}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {item.last_sold_at ? formatDate(item.last_sold_at) : "-"}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-center">
                      <div className="flex items-center justify-center gap-1">
                        <button
                          onClick={() => openRestock(item)}
                          className="rounded p-1 text-blue-600 hover:bg-blue-50"
                          title="Restock"
                        >
                          <Plus className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => openAdjust(item)}
                          className="rounded p-1 text-amber-600 hover:bg-amber-50"
                          title="Adjust Stock"
                        >
                          <Edit2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {items.length === 0 && (
              <EmptyState
                title="No inventory items found"
                icon={<Package className="h-12 w-12 text-gray-400" />}
              />
            )}
          </div>

          <div className="flex items-center justify-between text-sm text-gray-500">
            <span>
              Showing {items.length} of {formatNumber(totalInventoryItems)} items
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={() => pagination.setPage(pagination.page - 1)}
                disabled={pagination.page <= 1}
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Previous
              </button>
              <span>
                Page {pagination.page} of {Math.max(1, inventoryData?.meta.total_pages ?? 1)}
              </span>
              <button
                onClick={() => pagination.setPage(pagination.page + 1)}
                disabled={pagination.page >= Math.max(1, inventoryData?.meta.total_pages ?? 1)}
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {activeTab === "movements" && (
        <div className="space-y-4">
          <div className="flex flex-col gap-4 sm:flex-row">
            <input
              type="text"
              placeholder="Product ID..."
              value={movementProductIdFilter}
              onChange={(e) => {
                setMovementProductIdFilter(e.target.value);
                movementsPagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
            <select
              value={movementTypeFilter}
              onChange={(e) => {
                setMovementTypeFilter(e.target.value);
                movementsPagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              {movementTypeOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
            <input
              type="date"
              value={dateFrom}
              onChange={(e) => {
                setDateFrom(e.target.value);
                movementsPagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="From date"
            />
            <input
              type="date"
              value={dateTo}
              onChange={(e) => {
                setDateTo(e.target.value);
                movementsPagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="To date"
            />
          </div>

          <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Reference
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Product
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Type
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Quantity
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Before
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    After
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Unit Cost
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Reason
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    User
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {movements.map((movement) => (
                  <tr key={movement.transaction_id} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-4 py-3 text-sm font-mono text-gray-500">
                      {movement.reference_type
                        ? `${movement.reference_type}${movement.reference_id ? ` #${movement.reference_id}` : ""}`
                        : "-"}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm font-medium text-gray-900">
                      {movement.product_name}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          movement.movement_type === "RESTOCK"
                            ? "bg-green-100 text-green-800"
                            : movement.movement_type === "SALE"
                              ? "bg-blue-100 text-blue-800"
                              : movement.movement_type === "ADJUSTMENT"
                                ? "bg-amber-100 text-amber-800"
                                : movement.movement_type === "RETURN"
                                  ? "bg-purple-100 text-purple-800"
                                  : "bg-gray-100 text-gray-800"
                        }`}
                      >
                        {movement.movement_type}
                      </span>
                    </td>
                    <td
                      className={`whitespace-nowrap px-4 py-3 text-right text-sm font-medium ${
                        movement.quantity > 0 ? "text-green-600" : "text-red-600"
                      }`}
                    >
                      {movement.quantity > 0 ? "+" : ""}
                      {formatNumber(movement.quantity)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-gray-500">
                      {formatNumber(movement.quantity_before)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-medium text-gray-900">
                      {formatNumber(movement.quantity_after)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-gray-500">
                      {(movement.unit_cost ?? 0) > 0
                        ? formatCurrency(movement.unit_cost)
                        : "-"}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500 max-w-[200px] truncate">
                      {movement.reason}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {movement.username}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {formatDateTime(movement.created_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {movements.length === 0 && (
              <EmptyState
                title="No inventory movements found"
                icon={<History className="h-12 w-12 text-gray-400" />}
              />
            )}
          </div>

          <div className="flex items-center justify-between text-sm text-gray-500">
            <span>
              Showing {movements.length} of {formatNumber(totalMovements)} movements
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={() => movementsPagination.setPage(movementsPagination.page - 1)}
                disabled={movementsPagination.page <= 1}
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Previous
              </button>
              <span>
                Page {movementsPagination.page} of{" "}
                {Math.max(1, movementsData?.meta.total_pages ?? 1)}
              </span>
              <button
                onClick={() => movementsPagination.setPage(movementsPagination.page + 1)}
                disabled={
                  movementsPagination.page >=
                  Math.max(1, movementsData?.meta.total_pages ?? 1)
                }
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {activeTab === "low-stock" && (
        <div className="space-y-4">
          <div className="flex gap-4">
            <select
              value={lowStockStatusFilter}
              onChange={(e) => {
                setLowStockStatusFilter(e.target.value);
                lowStockPagination.setPage(1);
              }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              {lowStockStatusOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>

          <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Product
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    SKU
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    On Hand
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                    Low Stock Threshold
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                    Raised
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {lowStockAlerts.map((alert) => (
                  <tr key={alert.alert_id} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-4 py-3 text-sm font-medium text-gray-900">
                      {alert.product_name}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {alert.sku}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm font-medium text-gray-900">
                      {formatNumber(alert.quantity_on_hand)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right text-sm text-gray-500">
                      {formatNumber(alert.low_stock_threshold)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-center">
                      <AlertStatusBadge status={alert.status} />
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-500">
                      {formatDateTime(alert.raised_at)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-center">
                      {alert.status === "ACTIVE" && (
                        <button
                          onClick={() => {
                            const mockItem: Inventory = {
                              inventory_id: alert.alert_id,
                              product_id: alert.product_id,
                              product_name: alert.product_name,
                              sku: alert.sku,
                              quantity_on_hand: alert.quantity_on_hand,
                              quantity_reserved: 0,
                              available_quantity: alert.quantity_on_hand,
                              low_stock_threshold: alert.low_stock_threshold,
                              reorder_level: null,
                              stock_status: "LOW_STOCK",
                              last_restocked_at: null,
                              last_sold_at: null,
                              updated_at: alert.raised_at,
                            };
                            openRestock(mockItem);
                          }}
                          className="rounded bg-blue-50 px-2 py-1 text-xs font-medium text-blue-600 hover:bg-blue-100"
                        >
                          Restock
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {lowStockAlerts.length === 0 && (
              <EmptyState
                title="No low stock alerts"
                icon={<AlertTriangle className="h-12 w-12 text-gray-400" />}
              />
            )}
          </div>

          <div className="flex items-center justify-between text-sm text-gray-500">
            <span>
              Showing {lowStockAlerts.length} of {formatNumber(totalLowStock)} alerts
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={() => lowStockPagination.setPage(lowStockPagination.page - 1)}
                disabled={lowStockPagination.page <= 1}
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Previous
              </button>
              <span>
                Page {lowStockPagination.page} of{" "}
                {Math.max(1, lowStockData?.meta.total_pages ?? 1)}
              </span>
              <button
                onClick={() => lowStockPagination.setPage(lowStockPagination.page + 1)}
                disabled={
                  lowStockPagination.page >=
                  Math.max(1, lowStockData?.meta.total_pages ?? 1)
                }
                className="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      )}

      {showRestockModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Restock Product</h3>
              <button
                onClick={() => {
                  setShowRestockModal(false);
                  setSelectedProduct(null);
                  restockForm.reset();
                }}
                className="rounded p-1 text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <form
              onSubmit={restockForm.handleSubmit((data) => restockMutation.mutate(data))}
              className="space-y-4"
            >
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Product ID
                </label>
                <input
                  {...restockForm.register("product_id")}
                  disabled={!!selectedProduct}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:bg-gray-100"
                  placeholder="Enter product ID"
                />
                {restockForm.formState.errors.product_id && (
                  <p className="mt-1 text-xs text-red-600">
                    {restockForm.formState.errors.product_id.message}
                  </p>
                )}
              </div>
              {selectedProduct && (
                <div className="rounded-lg bg-gray-50 p-3">
                  <p className="text-sm font-medium text-gray-900">
                    {selectedProduct.product_name}
                  </p>
                  <p className="text-xs text-gray-500">
                    SKU: {selectedProduct.sku} | Current stock:{" "}
                    {formatNumber(selectedProduct.quantity_on_hand)}
                  </p>
                </div>
              )}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Quantity
                  </label>
                  <input
                    type="number"
                    {...restockForm.register("quantity")}
                    min={1}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                  {restockForm.formState.errors.quantity && (
                    <p className="mt-1 text-xs text-red-600">
                      {restockForm.formState.errors.quantity.message}
                    </p>
                  )}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Unit Cost ({currencySymbol})
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    {...restockForm.register("unit_cost")}
                    min={0}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                  {restockForm.formState.errors.unit_cost && (
                    <p className="mt-1 text-xs text-red-600">
                      {restockForm.formState.errors.unit_cost.message}
                    </p>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Reason
                </label>
                <textarea
                  {...restockForm.register("reason")}
                  rows={3}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Reason for restocking..."
                />
                {restockForm.formState.errors.reason && (
                  <p className="mt-1 text-xs text-red-600">
                    {restockForm.formState.errors.reason.message}
                  </p>
                )}
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setShowRestockModal(false);
                    setSelectedProduct(null);
                    restockForm.reset();
                  }}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={restockMutation.isPending}
                  className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  {restockMutation.isPending && <Spinner className="h-4 w-4" />}
                  {restockMutation.isPending ? "Restocking..." : "Restock"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showAdjustModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Adjust Stock</h3>
              <button
                onClick={() => {
                  setShowAdjustModal(false);
                  setSelectedProduct(null);
                  adjustForm.reset();
                }}
                className="rounded p-1 text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <form
              onSubmit={adjustForm.handleSubmit((data) => adjustMutation.mutate(data))}
              className="space-y-4"
            >
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Product ID
                </label>
                <input
                  {...adjustForm.register("product_id")}
                  disabled={!!selectedProduct}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 disabled:bg-gray-100"
                  placeholder="Enter product ID"
                />
                {adjustForm.formState.errors.product_id && (
                  <p className="mt-1 text-xs text-red-600">
                    {adjustForm.formState.errors.product_id.message}
                  </p>
                )}
              </div>
              {selectedProduct && (
                <div className="rounded-lg bg-gray-50 p-3">
                  <p className="text-sm font-medium text-gray-900">
                    {selectedProduct.product_name}
                  </p>
                  <p className="text-xs text-gray-500">
                    SKU: {selectedProduct.sku}
                  </p>
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adjustment Type
                </label>
                <select
                  {...adjustForm.register("adjustment_type")}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                >
                  {adjustmentTypeOptions.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    System Quantity
                  </label>
                  <input
                    type="number"
                    {...adjustForm.register("system_quantity")}
                    min={0}
                    onChange={(e) => {
                      adjustForm.setValue("system_quantity", Number(e.target.value));
                      const counted = adjustForm.getValues("counted_quantity");
                      adjustForm.setValue("quantity_change", counted - Number(e.target.value));
                    }}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Counted Quantity
                  </label>
                  <input
                    type="number"
                    {...adjustForm.register("counted_quantity")}
                    min={0}
                    onChange={(e) => {
                      adjustForm.setValue("counted_quantity", Number(e.target.value));
                      const system = adjustForm.getValues("system_quantity");
                      adjustForm.setValue("quantity_change", Number(e.target.value) - system);
                    }}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Quantity Change
                </label>
                <input
                  type="number"
                  {...adjustForm.register("quantity_change")}
                  readOnly
                  className={`w-full rounded-lg border px-3 py-2 text-sm font-medium ${
                    watchedCountedQty - watchedSystemQty >= 0
                      ? "border-green-300 bg-green-50 text-green-700"
                      : "border-red-300 bg-red-50 text-red-700"
                  }`}
                />
                <p className="mt-1 text-xs text-gray-500">
                  {watchedCountedQty - watchedSystemQty >= 0 ? "Surplus" : "Shortage"}:{" "}
                  {Math.abs(watchedCountedQty - watchedSystemQty)} units
                </p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Reason
                </label>
                <textarea
                  {...adjustForm.register("reason")}
                  rows={3}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Reason for adjustment..."
                />
                {adjustForm.formState.errors.reason && (
                  <p className="mt-1 text-xs text-red-600">
                    {adjustForm.formState.errors.reason.message}
                  </p>
                )}
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setShowAdjustModal(false);
                    setSelectedProduct(null);
                    adjustForm.reset();
                  }}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={adjustMutation.isPending}
                  className="inline-flex items-center gap-2 rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-700 disabled:opacity-50"
                >
                  {adjustMutation.isPending && <Spinner className="h-4 w-4" />}
                  {adjustMutation.isPending ? "Adjusting..." : "Adjust Stock"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {viewProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="w-full max-w-lg rounded-lg bg-white p-6 shadow-xl">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Stock Details</h3>
              <button
                onClick={() => setViewProduct(null)}
                className="rounded p-1 text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            {productDetailLoading ? (
              <div className="flex justify-center py-8">
                <Spinner className="h-8 w-8" />
              </div>
            ) : (
              <div className="space-y-4">
                <div className="rounded-lg bg-gray-50 p-4">
                  <h4 className="text-sm font-semibold text-gray-900">
                    {productDetail?.product_name}
                  </h4>
                  <p className="text-xs text-gray-500">SKU: {productDetail?.sku}</p>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="rounded-lg border border-gray-200 p-3">
                    <p className="text-xs text-gray-500">Quantity on Hand</p>
                    <p className="text-xl font-bold text-gray-900">
                      {formatNumber(productDetail?.quantity_on_hand ?? 0)}
                    </p>
                  </div>
                  <div className="rounded-lg border border-gray-200 p-3">
                    <p className="text-xs text-gray-500">Reserved</p>
                    <p className="text-xl font-bold text-gray-900">
                      {formatNumber(productDetail?.quantity_reserved ?? 0)}
                    </p>
                  </div>
                  <div className="rounded-lg border border-gray-200 p-3">
                    <p className="text-xs text-gray-500">Available</p>
                    <p className="text-xl font-bold text-blue-600">
                      {formatNumber(productDetail?.available_quantity ?? 0)}
                    </p>
                  </div>
                  <div className="rounded-lg border border-gray-200 p-3">
                    <p className="text-xs text-gray-500">Low Stock Threshold</p>
                    <p className="text-xl font-bold text-gray-900">
                      {formatNumber(productDetail?.low_stock_threshold ?? 0)}
                    </p>
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-xs text-gray-500">Stock Status</p>
                    <StockStatusBadge status={productDetail?.stock_status ?? ""} />
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Last Restock</p>
                    <p className="text-sm text-gray-900">
                      {productDetail?.last_restocked_at
                        ? formatDate(productDetail.last_restocked_at)
                        : "Never"}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Last Sold</p>
                    <p className="text-sm text-gray-900">
                      {productDetail?.last_sold_at
                        ? formatDate(productDetail.last_sold_at)
                        : "Never"}
                    </p>
                  </div>
                </div>
                <div className="flex justify-end gap-3 pt-2 border-t border-gray-200">
                  <button
                    onClick={() => {
                      setViewProduct(null);
                      if (productDetail) openRestock(productDetail);
                    }}
                    className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                  >
                    <Plus className="h-4 w-4" />
                    Restock
                  </button>
                  <button
                    onClick={() => {
                      setViewProduct(null);
                      if (productDetail) openAdjust(productDetail);
                    }}
                    className="inline-flex items-center gap-2 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                  >
                    <Edit2 className="h-4 w-4" />
                    Adjust
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
