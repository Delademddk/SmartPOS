import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Plus,
  Search,
  Edit2,
  Trash2,
  X,
  Package,
  DollarSign,
  Filter,
  ChevronLeft,
  ChevronRight,
  Archive,
  RotateCcw,
  Tag,
} from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost, apiPut, apiDelete } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { useDebounce } from "@/hooks/useDebounce";
import { PageLoader } from "@/components/feedback/PageLoader";
import { EmptyState } from "@/components/feedback/EmptyState";
import { Spinner } from "@/components/feedback/Spinner";
import { cn } from "@/utils/cn";
import { formatCurrency, formatDate, statusColor } from "@/utils/format";
import type { Product, Category, Supplier, TaxRate } from "@/types";

interface ProductListResponse {
  data: Product[];
  meta: { page: number; page_size: number; total_items: number; total_pages: number };
}

interface ProductCreatePayload {
  product_name: string;
  product_code: string;
  sku: string;
  barcode?: string;
  description?: string;
  category_id: number;
  supplier_id?: number;
  unit_price: number;
  cost_price: number;
  tax_rate_id?: number;
  reorder_level: number;
}

interface ProductUpdatePayload {
  product_name?: string;
  product_code?: string;
  sku?: string;
  barcode?: string;
  description?: string;
  category_id?: number;
  supplier_id?: number;
  unit_price?: number;
  cost_price?: number;
  tax_rate_id?: number;
  reorder_level?: number;
  is_active?: boolean;
}

interface PriceUpdatePayload {
  unit_price: number;
  cost_price: number;
}

const productCreateSchema = z.object({
  product_name: z.string().min(1, "Product name is required"),
  product_code: z.string().min(1, "Product code is required"),
  sku: z.string().min(1, "SKU is required"),
  barcode: z.string().optional(),
  description: z.string().optional(),
  category_id: z.number().min(1, "Category is required"),
  supplier_id: z.number().min(1, "Supplier is required").optional().or(z.literal(0)),
  unit_price: z.number().min(0, "Unit price must be positive"),
  cost_price: z.number().min(0, "Cost price must be positive"),
  tax_rate_id: z.number().min(1, "Tax rate is required").optional().or(z.literal(0)),
  reorder_level: z.number().min(0, "Reorder level must be non-negative"),
});

type ProductCreateForm = z.infer<typeof productCreateSchema>;

const priceUpdateSchema = z.object({
  unit_price: z.number().min(0, "Unit price must be positive"),
  cost_price: z.number().min(0, "Cost price must be positive"),
});

type PriceUpdateForm = z.infer<typeof priceUpdateSchema>;

const STOCK_OPTIONS = [
  { value: "", label: "All Stock" },
  { value: "IN_STOCK", label: "In Stock" },
  { value: "LOW_STOCK", label: "Low Stock" },
  { value: "OUT_OF_STOCK", label: "Out of Stock" },
] as const;

const ACTIVE_OPTIONS = [
  { value: "", label: "All Status" },
  { value: "true", label: "Active" },
  { value: "false", label: "Inactive" },
] as const;

export function ProductsPage() {
  const queryClient = useQueryClient();
  const { page, pageSize, setPage, setPageSize } = usePagination();
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounce(search);
  const [showForm, setShowForm] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [showPriceModal, setShowPriceModal] = useState<Product | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [filterCategory, setFilterCategory] = useState<string>("");
  const [filterSupplier, setFilterSupplier] = useState<string>("");
  const [filterStockStatus, setFilterStockStatus] = useState<string>("");
  const [filterIsActive, setFilterIsActive] = useState<string>("");

  const { data: productsData, isLoading: productsLoading } = useQuery<ProductListResponse>({
    queryKey: ["products", page, pageSize, debouncedSearch, filterCategory, filterSupplier, filterStockStatus, filterIsActive],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (debouncedSearch) params.set("search", debouncedSearch);
      if (filterCategory) params.set("category_id", filterCategory);
      if (filterSupplier) params.set("supplier_id", filterSupplier);
      if (filterStockStatus) params.set("stock_status", filterStockStatus);
      if (filterIsActive) params.set("is_active", filterIsActive);
      const res = await apiGet<Product[]>(`/products?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: categories } = useQuery({
    queryKey: ["categories-select"],
    queryFn: async () => {
      const params = new URLSearchParams({ page: "1", page_size: "200" });
      const res = await apiGet<Category[]>(`/categories?${params}`);
      return res.data;
    },
  });

  const { data: suppliers } = useQuery({
    queryKey: ["suppliers-select"],
    queryFn: async () => {
      const params = new URLSearchParams({ page: "1", page_size: "200" });
      const res = await apiGet<Supplier[]>(`/suppliers?${params}`);
      return res.data;
    },
  });

  const { data: taxRates } = useQuery({
    queryKey: ["tax-rates-select"],
    queryFn: async () => {
      const params = new URLSearchParams({ page: "1", page_size: "200" });
      const res = await apiGet<TaxRate[]>(`/tax-rates?${params}`);
      return res.data;
    },
  });

  const archiveMutation = useMutation({
    mutationFn: (productId: number) => apiPost(`/products/${productId}/archive`),
    onSuccess: () => {
      toast.success("Product archived");
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
    onError: () => toast.error("Failed to archive product"),
  });

  const deleteMutation = useMutation({
    mutationFn: (productId: number) => apiDelete(`/products/${productId}`),
    onSuccess: () => {
      toast.success("Product deleted");
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
    onError: () => toast.error("Failed to delete product"),
  });

  const activateMutation = useMutation({
    mutationFn: (product: Product) =>
      apiPut(`/products/${product.product_id}`, { is_active: true }),
    onSuccess: () => {
      toast.success("Product activated");
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
    onError: () => toast.error("Failed to activate product"),
  });

  const hasActiveFilters = filterCategory || filterSupplier || filterStockStatus || filterIsActive;

  const clearFilters = () => {
    setFilterCategory("");
    setFilterSupplier("");
    setFilterStockStatus("");
    setFilterIsActive("");
    setPage(1);
  };

  if (productsLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Products</h1>
        <button
          onClick={() => { setEditingProduct(null); setShowForm(true); }}
          className="btn-primary"
        >
          <Plus className="h-4 w-4" /> Add Product
        </button>
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative max-w-sm flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search products..."
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
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
                  {[filterCategory, filterSupplier, filterStockStatus, filterIsActive].filter(Boolean).length}
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
          <div className="mt-4 grid grid-cols-1 gap-3 border-t border-gray-200 pt-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label className="label">Category</label>
              <select
                value={filterCategory}
                onChange={(e) => { setFilterCategory(e.target.value); setPage(1); }}
                className="input"
              >
                <option value="">All Categories</option>
                {categories?.map((cat) => (
                  <option key={cat.category_id} value={cat.category_id}>
                    {cat.category_name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Supplier</label>
              <select
                value={filterSupplier}
                onChange={(e) => { setFilterSupplier(e.target.value); setPage(1); }}
                className="input"
              >
                <option value="">All Suppliers</option>
                {suppliers?.map((sup) => (
                  <option key={sup.supplier_id} value={sup.supplier_id}>
                    {sup.supplier_name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Stock Status</label>
              <select
                value={filterStockStatus}
                onChange={(e) => { setFilterStockStatus(e.target.value); setPage(1); }}
                className="input"
              >
                {STOCK_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Status</label>
              <select
                value={filterIsActive}
                onChange={(e) => { setFilterIsActive(e.target.value); setPage(1); }}
                className="input"
              >
                {ACTIVE_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
          </div>
        )}
      </div>

      {!productsData?.data.length ? (
        <EmptyState
          icon={<Package className="h-8 w-8 text-gray-400" />}
          title="No products found"
          description={hasActiveFilters || search ? "Try adjusting your search or filters." : "Create your first product to get started."}
          action={
            !hasActiveFilters && !search ? (
              <button onClick={() => setShowForm(true)} className="btn-primary">
                <Plus className="h-4 w-4" /> Add Product
              </button>
            ) : undefined
          }
        />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Product</th>
                <th>Category</th>
                <th>Supplier</th>
                <th className="text-right">Price</th>
                <th className="text-right">Cost</th>
                <th className="text-right">Stock</th>
                <th>Status</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {productsData.data.map((product) => (
                <tr key={product.product_id}>
                  <td>
                    <div>
                      <p className="font-medium">{product.product_name}</p>
                      <p className="text-xs text-gray-500">
                        {product.sku}
                        {product.barcode ? ` · ${product.barcode}` : ""}
                      </p>
                    </div>
                  </td>
                  <td>
                    <span className="badge-info">{product.category_name}</span>
                  </td>
                  <td className="text-sm text-gray-600">
                    {product.supplier_name || "—"}
                  </td>
                  <td className="text-right text-sm font-medium">
                    {formatCurrency(product.unit_price)}
                  </td>
                  <td className="text-right text-sm text-gray-600">
                    {formatCurrency(product.cost_price)}
                  </td>
                  <td className="text-right">
                    <div className="flex flex-col items-end">
                      <span className={cn("text-sm font-medium", stockTextColor(product.stock_status))}>
                        {product.quantity_on_hand}
                      </span>
                      <span className={cn("text-xs", statusColor(product.stock_status))}>
                        {product.stock_status.replace("_", " ")}
                      </span>
                    </div>
                  </td>
                  <td>
                    <span className={statusColor(product.is_active ? "ACTIVE" : "VOIDED")}>
                      {product.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td>
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => setShowPriceModal(product)}
                        className="btn-ghost btn-sm"
                        title="Edit Price"
                      >
                        <DollarSign className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => { setEditingProduct(product); setShowForm(true); }}
                        className="btn-ghost btn-sm"
                        title="Edit Product"
                      >
                        <Edit2 className="h-4 w-4" />
                      </button>
                      {product.is_active ? (
                        <button
                          onClick={() => {
                            if (confirm("Archive this product?")) archiveMutation.mutate(product.product_id);
                          }}
                          className="btn-ghost btn-sm text-amber-600"
                          title="Archive"
                        >
                          <Archive className="h-4 w-4" />
                        </button>
                      ) : (
                        <button
                          onClick={() => activateMutation.mutate(product)}
                          className="btn-ghost btn-sm text-green-600"
                          title="Reactivate"
                        >
                          <RotateCcw className="h-4 w-4" />
                        </button>
                      )}
                      <button
                        onClick={() => {
                          if (confirm(`Permanently delete "${product.product_name}"?`)) {
                            deleteMutation.mutate(product.product_id);
                          }
                        }}
                        className="btn-ghost btn-sm text-red-600"
                        title="Delete"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {productsData?.meta && productsData.meta.total_pages > 1 && (
        <Pagination
          page={productsData.meta.page}
          totalPages={productsData.meta.total_pages}
          totalItems={productsData.meta.total_items}
          pageSize={pageSize}
          onPageChange={setPage}
          onPageSizeChange={setPageSize}
        />
      )}

      {showForm && (
        <ProductModal
          product={editingProduct}
          categories={categories || []}
          suppliers={suppliers || []}
          taxRates={taxRates || []}
          onClose={() => { setShowForm(false); setEditingProduct(null); }}
        />
      )}

      {showPriceModal && (
        <PriceModal
          product={showPriceModal}
          onClose={() => setShowPriceModal(null)}
        />
      )}
    </div>
  );
}

function stockTextColor(status: string): string {
  switch (status) {
    case "OUT_OF_STOCK": return "text-red-600";
    case "LOW_STOCK": return "text-amber-600";
    default: return "text-gray-900";
  }
}

interface ProductModalProps {
  product: Product | null;
  categories: Category[];
  suppliers: Supplier[];
  taxRates: TaxRate[];
  onClose: () => void;
}

function ProductModal({ product, categories, suppliers, taxRates, onClose }: ProductModalProps) {
  const queryClient = useQueryClient();
  const isEdit = !!product;

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ProductCreateForm>({
    resolver: zodResolver(productCreateSchema),
    defaultValues: product
      ? {
          product_name: product.product_name,
          product_code: product.product_code,
          sku: product.sku,
          barcode: product.barcode || "",
          description: product.description || "",
          category_id: product.category_id,
          supplier_id: product.supplier_id || 0,
          unit_price: product.unit_price,
          cost_price: product.cost_price,
          tax_rate_id: product.tax_rate_id || 0,
          reorder_level: product.reorder_level,
        }
      : {
          unit_price: 0,
          cost_price: 0,
          reorder_level: 0,
        },
  });

  const mutation = useMutation({
    mutationFn: (data: ProductCreateForm) => {
      const payload: ProductCreatePayload = {
        product_name: data.product_name,
        product_code: data.product_code,
        sku: data.sku,
        barcode: data.barcode || undefined,
        description: data.description || undefined,
        category_id: data.category_id,
        supplier_id: data.supplier_id && data.supplier_id > 0 ? data.supplier_id : undefined,
        unit_price: data.unit_price,
        cost_price: data.cost_price,
        tax_rate_id: data.tax_rate_id && data.tax_rate_id > 0 ? data.tax_rate_id : undefined,
        reorder_level: data.reorder_level,
      };

      if (isEdit && product) {
        const updatePayload: ProductUpdatePayload = {};
        if (payload.product_name !== product.product_name) updatePayload.product_name = payload.product_name;
        if (payload.product_code !== product.product_code) updatePayload.product_code = payload.product_code;
        if (payload.sku !== product.sku) updatePayload.sku = payload.sku;
        if ((payload.barcode || "") !== (product.barcode || "")) updatePayload.barcode = payload.barcode;
        if ((payload.description || "") !== (product.description || "")) updatePayload.description = payload.description;
        if (payload.category_id !== product.category_id) updatePayload.category_id = payload.category_id;
        if ((payload.supplier_id || null) !== product.supplier_id) updatePayload.supplier_id = payload.supplier_id;
        if (payload.unit_price !== product.unit_price) updatePayload.unit_price = payload.unit_price;
        if (payload.cost_price !== product.cost_price) updatePayload.cost_price = payload.cost_price;
        if ((payload.tax_rate_id || null) !== product.tax_rate_id) updatePayload.tax_rate_id = payload.tax_rate_id;
        if (payload.reorder_level !== product.reorder_level) updatePayload.reorder_level = payload.reorder_level;
        return apiPut(`/products/${product.product_id}`, updatePayload);
      }

      return apiPost("/products", payload);
    },
    onSuccess: () => {
      toast.success(isEdit ? "Product updated" : "Product created");
      queryClient.invalidateQueries({ queryKey: ["products"] });
      onClose();
    },
    onError: (error: Error & { response?: { data?: { error?: { details?: Array<{ message: string }> } } } }) => {
      const msg = error.response?.data?.error?.details?.[0]?.message;
      toast.error(msg || (isEdit ? "Failed to update product" : "Failed to create product"));
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">{isEdit ? "Edit Product" : "Create Product"}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <label className="label">Product Name</label>
              <input
                {...register("product_name")}
                className={cn("input", errors.product_name && "input-error")}
                placeholder="e.g. Coca-Cola 500ml"
              />
              {errors.product_name && <p className="mt-1 text-xs text-red-600">{errors.product_name.message}</p>}
            </div>

            <div>
              <label className="label">Product Code</label>
              <input
                {...register("product_code")}
                className={cn("input", errors.product_code && "input-error")}
                placeholder="e.g. CC-500"
              />
              {errors.product_code && <p className="mt-1 text-xs text-red-600">{errors.product_code.message}</p>}
            </div>

            <div>
              <label className="label">SKU</label>
              <input
                {...register("sku")}
                className={cn("input", errors.sku && "input-error")}
                placeholder="e.g. SKU-001"
              />
              {errors.sku && <p className="mt-1 text-xs text-red-600">{errors.sku.message}</p>}
            </div>

            <div>
              <label className="label">Barcode</label>
              <input
                {...register("barcode")}
                className="input"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="label">Category</label>
              <select
                {...register("category_id", { valueAsNumber: true })}
                className={cn("input", errors.category_id && "input-error")}
              >
                <option value={0}>Select category</option>
                {categories.map((cat) => (
                  <option key={cat.category_id} value={cat.category_id}>{cat.category_name}</option>
                ))}
              </select>
              {errors.category_id && <p className="mt-1 text-xs text-red-600">{errors.category_id.message}</p>}
            </div>

            <div>
              <label className="label">Supplier</label>
              <select
                {...register("supplier_id", { valueAsNumber: true })}
                className="input"
              >
                <option value={0}>Select supplier (optional)</option>
                {suppliers.map((sup) => (
                  <option key={sup.supplier_id} value={sup.supplier_id}>{sup.supplier_name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="label">Unit Price</label>
              <input
                {...register("unit_price", { valueAsNumber: true })}
                type="number"
                step="0.01"
                min="0"
                className={cn("input", errors.unit_price && "input-error")}
              />
              {errors.unit_price && <p className="mt-1 text-xs text-red-600">{errors.unit_price.message}</p>}
            </div>

            <div>
              <label className="label">Cost Price</label>
              <input
                {...register("cost_price", { valueAsNumber: true })}
                type="number"
                step="0.01"
                min="0"
                className={cn("input", errors.cost_price && "input-error")}
              />
              {errors.cost_price && <p className="mt-1 text-xs text-red-600">{errors.cost_price.message}</p>}
            </div>

            <div>
              <label className="label">Tax Rate</label>
              <select
                {...register("tax_rate_id", { valueAsNumber: true })}
                className="input"
              >
                <option value={0}>Select tax rate (optional)</option>
                {taxRates.map((tr) => (
                  <option key={tr.tax_rate_id} value={tr.tax_rate_id}>
                    {tr.tax_name} ({tr.rate_percent}%)
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="label">Reorder Level</label>
              <input
                {...register("reorder_level", { valueAsNumber: true })}
                type="number"
                min="0"
                className={cn("input", errors.reorder_level && "input-error")}
              />
              {errors.reorder_level && <p className="mt-1 text-xs text-red-600">{errors.reorder_level.message}</p>}
            </div>

            <div className="sm:col-span-2">
              <label className="label">Description</label>
              <textarea
                {...register("description")}
                className="input min-h-[80px]"
                placeholder="Optional product description"
              />
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : isEdit ? "Save Changes" : "Create Product"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

interface PriceModalProps {
  product: Product;
  onClose: () => void;
}

function PriceModal({ product, onClose }: PriceModalProps) {
  const queryClient = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    watch,
  } = useForm<PriceUpdateForm>({
    resolver: zodResolver(priceUpdateSchema),
    defaultValues: {
      unit_price: product.unit_price,
      cost_price: product.cost_price,
    },
  });

  const watchedUnitPrice = watch("unit_price");
  const watchedCostPrice = watch("cost_price");
  const margin = watchedUnitPrice > 0
    ? ((watchedUnitPrice - watchedCostPrice) / watchedUnitPrice) * 100
    : 0;

  const mutation = useMutation({
    mutationFn: (data: PriceUpdateForm) => {
      const payload: PriceUpdatePayload = {
        unit_price: data.unit_price,
        cost_price: data.cost_price,
      };
      return apiPut(`/products/${product.product_id}/price`, payload);
    },
    onSuccess: () => {
      toast.success("Price updated");
      queryClient.invalidateQueries({ queryKey: ["products"] });
      onClose();
    },
    onError: () => toast.error("Failed to update price"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Edit Price</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="px-6 pt-4 pb-2">
          <div className="flex items-center gap-2 text-sm text-gray-600">
            <Tag className="h-4 w-4" />
            <span className="font-medium">{product.product_name}</span>
            <span className="text-gray-400">({product.sku})</span>
          </div>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div>
            <label className="label">Unit Price</label>
            <input
              {...register("unit_price", { valueAsNumber: true })}
              type="number"
              step="0.01"
              min="0"
              className={cn("input", errors.unit_price && "input-error")}
            />
            {errors.unit_price && <p className="mt-1 text-xs text-red-600">{errors.unit_price.message}</p>}
          </div>

          <div>
            <label className="label">Cost Price</label>
            <input
              {...register("cost_price", { valueAsNumber: true })}
              type="number"
              step="0.01"
              min="0"
              className={cn("input", errors.cost_price && "input-error")}
            />
            {errors.cost_price && <p className="mt-1 text-xs text-red-600">{errors.cost_price.message}</p>}
          </div>

          <div className="rounded-lg bg-gray-50 p-3 text-sm">
            <div className="flex justify-between text-gray-600">
              <span>Margin</span>
              <span className={cn("font-medium", margin >= 0 ? "text-green-600" : "text-red-600")}>
                {margin.toFixed(1)}%
              </span>
            </div>
            <div className="mt-1 flex justify-between text-gray-600">
              <span>Profit per unit</span>
              <span className="font-medium">
                {formatCurrency(watchedUnitPrice - watchedCostPrice)}
              </span>
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : "Update Price"}
            </button>
          </div>
        </form>
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
          <ChevronLeft className="h-4 w-4" />
        </button>
        {generatePageNumbers(page, totalPages).map((pageNum, idx) =>
          pageNum === "..." ? (
            <span key={`ellipsis-${idx}`} className="px-2 text-sm text-gray-400">...</span>
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
