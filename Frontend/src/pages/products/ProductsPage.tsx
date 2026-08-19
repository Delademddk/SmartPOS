import { useState, useRef, useEffect, type ChangeEvent } from "react";
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
  PackagePlus,
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
import { ProductImage } from "@/components/ui/ProductImage";
import { cn } from "@/utils/cn";
import { formatCurrency, statusColor } from "@/utils/format";
import { useCurrency } from "@/hooks/useCurrency";
import {
  ACCEPTED_IMAGE_INPUT,
  resolveImageUrl,
  validateProductImage,
} from "@/utils/image";
import type { Product, Category, Supplier, PaginatedResponse } from "@/types";

interface ProductCreatePayload {
  product_name: string;
  sku: string;
  barcode?: string;
  description?: string;
  category_id: number;
  supplier_id?: number;
  unit_price: number;
  cost_price: number;
  low_stock_threshold: number;
  initial_quantity?: number;
}

interface ProductUpdatePayload {
  product_name?: string;
  sku?: string;
  barcode?: string;
  description?: string;
  category_id?: number;
  supplier_id?: number;
  unit_price?: number;
  cost_price?: number;
  low_stock_threshold?: number;
  is_active?: boolean;
}

interface PriceUpdatePayload {
  unit_price: number;
  cost_price: number;
}

type ApiError = Error & {
  response?: { data?: { error?: { message?: string; details?: Array<{ message: string }> } } };
};

function getApiErrorMessage(error: ApiError, fallback: string): string {
  const details = error.response?.data?.error?.details;
  return details?.[0]?.message || error.response?.data?.error?.message || fallback;
}

function invalidateProductQueries(queryClient: ReturnType<typeof useQueryClient>) {
  queryClient.invalidateQueries({ queryKey: ["products"] });
  queryClient.invalidateQueries({ queryKey: ["pos-products"] });
  queryClient.invalidateQueries({ queryKey: ["inventory"] });
  queryClient.invalidateQueries({ queryKey: ["inventory-movements"] });
  queryClient.invalidateQueries({ queryKey: ["inventory-low-stock"] });
  queryClient.invalidateQueries({ queryKey: ["dashboard"] });
}

const productCreateSchema = z.object({
  product_name: z.string().min(1, "Product name is required"),
  sku: z.string().min(1, "SKU is required"),
  barcode: z.string().optional(),
  description: z.string().optional(),
  category_id: z.number().min(1, "Category is required"),
  supplier_id: z.number().min(1, "Supplier is required").optional().or(z.literal(0)),
  unit_price: z.number().min(0, "Unit price must be positive"),
  cost_price: z.number().min(0, "Cost price must be positive"),
  low_stock_threshold: z.coerce.number().int("Threshold must be a whole number").min(0, "Low stock threshold must be non-negative"),
  quantity: z.coerce.number().int("Quantity must be a whole number").min(0, "Quantity cannot be negative").optional(),
});

type ProductCreateForm = z.infer<typeof productCreateSchema>;

const priceUpdateSchema = z.object({
  unit_price: z.number().min(0, "Unit price must be positive"),
  cost_price: z.number().min(0, "Cost price must be positive"),
});

type PriceUpdateForm = z.infer<typeof priceUpdateSchema>;

const restockSchema = z.object({
  quantity: z.coerce.number().int("Quantity must be a whole number").positive("Quantity must be greater than zero"),
  unit_cost: z.coerce.number().min(0, "Unit cost must be non-negative").optional(),
  reason: z.string().max(255, "Reason is too long").optional(),
});

type RestockForm = z.infer<typeof restockSchema>;

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
  useCurrency();
  const { page, pageSize, setPage, setPageSize } = usePagination();
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounce(search);
  const [showForm, setShowForm] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [showPriceModal, setShowPriceModal] = useState<Product | null>(null);
  const [restockProduct, setRestockProduct] = useState<Product | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [filterCategory, setFilterCategory] = useState<string>("");
  const [filterSupplier, setFilterSupplier] = useState<string>("");
  const [filterStockStatus, setFilterStockStatus] = useState<string>("");
  const [filterIsActive, setFilterIsActive] = useState<string>("");

  const { data: productsData, isLoading: productsLoading } = useQuery<PaginatedResponse<Product>>({
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

  const archiveMutation = useMutation({
    mutationFn: (productId: number) => apiPost(`/products/${productId}/archive`),
    onSuccess: () => {
      toast.success("Product archived");
      invalidateProductQueries(queryClient);
    },
    onError: () => toast.error("Failed to archive product"),
  });

  const deleteMutation = useMutation({
    mutationFn: (productId: number) => apiDelete(`/products/${productId}`),
    onSuccess: () => {
      toast.success("Product deleted");
      invalidateProductQueries(queryClient);
    },
    onError: () => toast.error("Failed to delete product"),
  });

  const activateMutation = useMutation({
    mutationFn: (product: Product) =>
      apiPut(`/products/${product.product_id}`, { is_active: true }),
    onSuccess: () => {
      toast.success("Product activated");
      invalidateProductQueries(queryClient);
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
                    <div className="flex items-center gap-3">
                      <ProductImage
                        imageUrl={product.image_url}
                        alt={product.product_name}
                        className="h-10 w-10 shrink-0 rounded-lg border border-gray-100"
                        iconClassName="h-5 w-5"
                      />
                      <div>
                        <p className="font-medium">{product.product_name}</p>
                        <p className="text-xs text-gray-500">
                          {product.sku}
                          {product.barcode ? ` · ${product.barcode}` : ""}
                        </p>
                      </div>
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
                    {formatCurrency(product.cost_price ?? 0)}
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
                        onClick={() => setRestockProduct(product)}
                        className="btn-ghost btn-sm text-blue-600"
                        title="Restock"
                      >
                        <PackagePlus className="h-4 w-4" />
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
          onClose={() => { setShowForm(false); setEditingProduct(null); }}
          onRestock={(product) => { setShowForm(false); setEditingProduct(null); setRestockProduct(product); }}
        />
      )}

      {showPriceModal && (
        <PriceModal
          product={showPriceModal}
          onClose={() => setShowPriceModal(null)}
        />
      )}

      {restockProduct && (
        <RestockModal
          product={restockProduct}
          onClose={() => setRestockProduct(null)}
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
  onClose: () => void;
  onRestock: (product: Product) => void;
}

function ProductModal({ product, categories, suppliers, onClose, onRestock }: ProductModalProps) {
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
          sku: product.sku,
          barcode: product.barcode || "",
          description: product.description || "",
          category_id: product.category_id ?? 0,
          supplier_id: product.supplier_id || 0,
          unit_price: product.unit_price,
          cost_price: product.cost_price ?? 0,
          low_stock_threshold: product.low_stock_threshold,
        }
        : {
            unit_price: 0,
            cost_price: 0,
            low_stock_threshold: 10,
            quantity: 0,
          },
  });

  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(() =>
    product?.image_url ? resolveImageUrl(product.image_url) : null,
  );
  const [removeCurrentImage, setRemoveCurrentImage] = useState(false);
  const [imageError, setImageError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    return () => {
      if (imagePreview && imagePreview.startsWith("blob:")) {
        URL.revokeObjectURL(imagePreview);
      }
    };
  }, [imagePreview]);

  const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] || null;
    if (!file) return;
    const error = validateProductImage(file);
    if (error) {
      setImageError(error);
      e.target.value = "";
      return;
    }
    setImageError(null);
    setRemoveCurrentImage(false);
    setSelectedFile(file);
    setImagePreview((prev) => {
      if (prev && prev.startsWith("blob:")) URL.revokeObjectURL(prev);
      return URL.createObjectURL(file);
    });
  };

  const handleClearImage = () => {
    setImageError(null);
    setRemoveCurrentImage(false);
    setSelectedFile(null);
    setImagePreview((prev) => {
      if (prev && prev.startsWith("blob:")) URL.revokeObjectURL(prev);
      return product?.image_url ? resolveImageUrl(product.image_url) : null;
    });
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const handleRemoveCurrentImage = () => {
    setImageError(null);
    setSelectedFile(null);
    setRemoveCurrentImage(true);
    setImagePreview((prev) => {
      if (prev && prev.startsWith("blob:")) URL.revokeObjectURL(prev);
      return null;
    });
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const mutation = useMutation({
    mutationFn: (data: ProductCreateForm) => {
      const payload: ProductCreatePayload = {
        product_name: data.product_name,
        sku: data.sku,
        barcode: data.barcode || undefined,
        description: data.description || undefined,
        category_id: data.category_id,
        supplier_id: data.supplier_id && data.supplier_id > 0 ? data.supplier_id : undefined,
        unit_price: data.unit_price,
        cost_price: data.cost_price,
        low_stock_threshold: data.low_stock_threshold,
        ...(!isEdit ? { initial_quantity: data.quantity ?? 0 } : {}),
      };

      const multipartConfig = { headers: { "Content-Type": "multipart/form-data" } };

      if (isEdit && product) {
        const updatePayload: ProductUpdatePayload = {};
        if (payload.product_name !== product.product_name) updatePayload.product_name = payload.product_name;
        if (payload.sku !== product.sku) updatePayload.sku = payload.sku;
        if ((payload.barcode || "") !== (product.barcode || "")) updatePayload.barcode = payload.barcode;
        if ((payload.description || "") !== (product.description || "")) updatePayload.description = payload.description;
        if (payload.category_id !== product.category_id) updatePayload.category_id = payload.category_id;
        if ((payload.supplier_id || null) !== product.supplier_id) updatePayload.supplier_id = payload.supplier_id;
        if (payload.unit_price !== product.unit_price) updatePayload.unit_price = payload.unit_price;
        if ((payload.cost_price ?? 0) !== (product.cost_price ?? 0)) updatePayload.cost_price = payload.cost_price;
        if (payload.low_stock_threshold !== product.low_stock_threshold) updatePayload.low_stock_threshold = payload.low_stock_threshold;

        if (selectedFile || removeCurrentImage) {
          const formData = new FormData();
          formData.append("data", JSON.stringify(updatePayload));
          if (selectedFile) formData.append("image", selectedFile);
          if (removeCurrentImage) formData.append("remove_image", "true");
          return apiPut(`/products/${product.product_id}`, formData, multipartConfig);
        }
        return apiPut(`/products/${product.product_id}`, updatePayload);
      }

      if (selectedFile) {
        const formData = new FormData();
        formData.append("data", JSON.stringify(payload));
        formData.append("image", selectedFile);
        return apiPost("/products", formData, multipartConfig);
      }
      return apiPost("/products", payload);
    },
    onSuccess: () => {
      toast.success(isEdit ? "Product updated" : "Product created");
      invalidateProductQueries(queryClient);
      onClose();
    },
    onError: (error: ApiError) => {
      toast.error(getApiErrorMessage(error, isEdit ? "Failed to update product" : "Failed to create product"));
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
              <label className="label">Product Image</label>
              <div className="flex items-center gap-4">
                <ProductImage
                  imageUrl={removeCurrentImage ? null : imagePreview}
                  alt={selectedFile?.name || product?.product_name || "Product image"}
                  className="h-20 w-20 shrink-0 rounded-lg border border-gray-200"
                  iconClassName="h-8 w-8"
                />
                <div className="flex flex-col gap-2">
                  <label className="btn-secondary btn-sm cursor-pointer peer-focus:ring-2 peer-focus:ring-primary-500 peer-focus:ring-offset-2">
                    {selectedFile
                      ? "Change Image"
                      : isEdit && product?.image_url
                        ? "Replace Image"
                        : "Choose Image"}
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept={ACCEPTED_IMAGE_INPUT}
                      className="peer sr-only"
                      onChange={handleFileChange}
                    />
                  </label>
                  {isEdit && product?.image_url && !selectedFile && !removeCurrentImage && (
                    <button
                      type="button"
                      onClick={handleRemoveCurrentImage}
                      className="btn-ghost btn-sm text-red-600"
                    >
                      Remove Image
                    </button>
                  )}
                  {(selectedFile || removeCurrentImage) && (
                    <button
                      type="button"
                      onClick={handleClearImage}
                      className="btn-ghost btn-sm text-gray-500"
                    >
                      {removeCurrentImage ? "Keep Current Image" : "Clear Selection"}
                    </button>
                  )}
                </div>
              </div>
              {imageError && <p className="mt-1 text-xs text-red-600">{imageError}</p>}
              {removeCurrentImage && !imageError && (
                <p className="mt-1 text-xs text-amber-600">
                  Current image will be removed when you save.
                </p>
              )}
            </div>

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

            {isEdit && product ? (
              <div className="flex items-end justify-between rounded-lg border border-gray-200 bg-gray-50 p-3">
                <div>
                  <label className="label !mb-1">Current Stock</label>
                  <p className="text-xl font-bold text-gray-900">{product.quantity_on_hand}</p>
                  <p className="text-xs text-gray-500">
                    To add more stock use the Restock action.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => onRestock(product)}
                  className="btn-secondary btn-sm"
                >
                  <PackagePlus className="h-4 w-4" /> Restock
                </button>
              </div>
            ) : (
              <div>
                <label className="label">Quantity</label>
                <input
                  {...register("quantity")}
                  type="number"
                  min="0"
                  step="1"
                  placeholder="0"
                  className={cn("input", errors.quantity && "input-error")}
                />
                {errors.quantity && <p className="mt-1 text-xs text-red-600">{errors.quantity.message}</p>}
              </div>
            )}

            <div>
              <label className="label">Low Stock Threshold</label>
              <input
                {...register("low_stock_threshold")}
                type="number"
                min="0"
                step="1"
                className={cn("input", errors.low_stock_threshold && "input-error")}
              />
              {errors.low_stock_threshold && <p className="mt-1 text-xs text-red-600">{errors.low_stock_threshold.message}</p>}
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
  useCurrency();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    watch,
  } = useForm<PriceUpdateForm>({
    resolver: zodResolver(priceUpdateSchema),
    defaultValues: {
      unit_price: product.unit_price,
      cost_price: product.cost_price ?? 0,
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

interface RestockModalProps {
  product: Product;
  onClose: () => void;
}

function RestockModal({ product, onClose }: RestockModalProps) {
  const queryClient = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<RestockForm>({
    resolver: zodResolver(restockSchema),
    defaultValues: {
      quantity: 0,
      unit_cost: product.cost_price ?? undefined,
      reason: "",
    },
  });

  const mutation = useMutation({
    mutationFn: (data: RestockForm) =>
      apiPost("/inventory/restock", {
        product_id: product.product_id,
        quantity: data.quantity,
        unit_cost: data.unit_cost,
        reason: data.reason || undefined,
      }),
    onSuccess: () => {
      toast.success("Stock restocked successfully");
      invalidateProductQueries(queryClient);
      onClose();
    },
    onError: (error: ApiError) => {
      toast.error(getApiErrorMessage(error, "Failed to restock product"));
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Restock Product</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div className="flex items-center gap-2 text-sm text-gray-600">
            <Tag className="h-4 w-4" />
            <span className="font-medium">{product.product_name}</span>
            <span className="text-gray-400">({product.sku})</span>
          </div>

          <div className="flex items-center justify-between rounded-lg bg-gray-50 p-3">
            <span className="text-sm text-gray-600">Current Stock</span>
            <span className="text-lg font-bold text-gray-900">{product.quantity_on_hand}</span>
          </div>

          <div>
            <label className="label">Quantity to Add</label>
            <input
              {...register("quantity")}
              type="number"
              min="1"
              step="1"
              className={cn("input", errors.quantity && "input-error")}
              placeholder="e.g. 25"
            />
            {errors.quantity && <p className="mt-1 text-xs text-red-600">{errors.quantity.message}</p>}
          </div>

          <div>
            <label className="label">Unit Cost (optional)</label>
            <input
              {...register("unit_cost")}
              type="number"
              min="0"
              step="0.01"
              className="input"
            />
            {errors.unit_cost && <p className="mt-1 text-xs text-red-600">{errors.unit_cost.message}</p>}
          </div>

          <div>
            <label className="label">Reason (optional)</label>
            <input
              {...register("reason")}
              className="input"
              placeholder="e.g. Reorder from supplier"
            />
            {errors.reason && <p className="mt-1 text-xs text-red-600">{errors.reason.message}</p>}
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : "Confirm Restock"}
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
