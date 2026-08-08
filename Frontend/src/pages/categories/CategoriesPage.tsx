import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Search, Edit2, Trash2, X } from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost, apiPut, apiDelete } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader } from "@/components/feedback/PageLoader";
import { EmptyState } from "@/components/feedback/EmptyState";
import { Spinner } from "@/components/feedback/Spinner";
import { formatDate, statusColor } from "@/utils/format";
import type { Category } from "@/types";

const categorySchema = z.object({
  category_name: z.string().min(1, "Category name is required"),
  category_code: z.string().min(1, "Category code is required"),
  description: z.string().optional(),
  parent_id: z.number().optional().nullable(),
});

type CategoryForm = z.infer<typeof categorySchema>;

export function CategoriesPage() {
  const queryClient = useQueryClient();
  const { page, pageSize, setPage, setPageSize } = usePagination();
  const [search, setSearch] = useState("");
  const [parentIdFilter, setParentIdFilter] = useState<string>("");
  const [isActiveFilter, setIsActiveFilter] = useState<string>("");
  const [showForm, setShowForm] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [deletingCategory, setDeletingCategory] = useState<Category | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["categories", page, pageSize, search, parentIdFilter, isActiveFilter],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (search) params.set("search", search);
      if (parentIdFilter) params.set("parent_id", parentIdFilter);
      if (isActiveFilter) params.set("is_active", isActiveFilter);
      const res = await apiGet<Category[]>(`/categories?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: allCategories } = useQuery({
    queryKey: ["categories", "all"],
    queryFn: async () => {
      const res = await apiGet<Category[]>("/categories?page_size=1000");
      return res.data;
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (categoryId: number) => apiDelete(`/categories/${categoryId}`),
    onSuccess: () => {
      toast.success("Category deleted successfully");
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      setDeletingCategory(null);
    },
    onError: () => toast.error("Failed to delete category"),
  });

  if (isLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Categories</h1>
        <button
          onClick={() => {
            setEditingCategory(null);
            setShowForm(true);
          }}
          className="btn-primary"
        >
          <Plus className="h-4 w-4" /> Add Category
        </button>
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="relative flex-1 min-w-[200px] max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search categories..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="input pl-10"
            />
          </div>
          <select
            value={parentIdFilter}
            onChange={(e) => setParentIdFilter(e.target.value)}
            className="input max-w-[200px]"
          >
            <option value="">All Parents</option>
            <option value="null">Root Categories</option>
            {allCategories?.map((cat) => (
              <option key={cat.category_id} value={cat.category_id}>
                {cat.category_name}
              </option>
            ))}
          </select>
          <select
            value={isActiveFilter}
            onChange={(e) => setIsActiveFilter(e.target.value)}
            className="input max-w-[160px]"
          >
            <option value="">All Status</option>
            <option value="true">Active</option>
            <option value="false">Inactive</option>
          </select>
        </div>
      </div>

      {!data?.data.length ? (
        <EmptyState
          title="No categories found"
          description="Create your first category to get started."
        />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Category</th>
                <th>Code</th>
                <th>Children</th>
                <th>Products</th>
                <th>Status</th>
                <th>Created</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((category) => (
                <tr key={category.category_id}>
                  <td>
                    <div>
                      <p className="font-medium">{category.category_name}</p>
                      {category.description && (
                        <p className="text-xs text-gray-500 truncate max-w-[250px]">
                          {category.description}
                        </p>
                      )}
                    </div>
                  </td>
                  <td>
                    <span className="badge-info">{category.category_code}</span>
                  </td>
                  <td>
                    <span className="text-sm text-gray-700">
                      {category.child_count}
                    </span>
                  </td>
                  <td>
                    <span className="text-sm text-gray-700">
                      {category.product_count}
                    </span>
                  </td>
                  <td>
                    <span
                      className={statusColor(
                        category.is_active ? "ACTIVE" : "VOIDED"
                      )}
                    >
                      {category.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td>{formatDate(category.created_at)}</td>
                  <td>
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => {
                          setEditingCategory(category);
                          setShowForm(true);
                        }}
                        className="btn-ghost btn-sm"
                        title="Edit"
                      >
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => setDeletingCategory(category)}
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

      {data?.meta && data.meta.total_pages > 1 && (
        <Pagination
          page={data.meta.page}
          totalPages={data.meta.total_pages}
          totalItems={data.meta.total_items}
          onPageChange={setPage}
        />
      )}

      {showForm && (
        <CategoryModal
          category={editingCategory}
          allCategories={allCategories || []}
          onClose={() => {
            setShowForm(false);
            setEditingCategory(null);
          }}
        />
      )}

      {deletingCategory && (
        <DeleteConfirmModal
          category={deletingCategory}
          isPending={deleteMutation.isPending}
          onConfirm={() => deleteMutation.mutate(deletingCategory.category_id)}
          onClose={() => setDeletingCategory(null)}
        />
      )}
    </div>
  );
}

function CategoryModal({
  category,
  allCategories,
  onClose,
}: {
  category: Category | null;
  allCategories: Category[];
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const isEdit = !!category;

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<CategoryForm>({
    resolver: zodResolver(categorySchema),
    defaultValues: category
      ? {
          category_name: category.category_name,
          category_code: category.category_code,
          description: category.description || "",
          parent_id: category.parent_id,
        }
      : {
          description: "",
          parent_id: null,
        },
  });

  const mutation = useMutation({
    mutationFn: (data: CategoryForm) => {
      const payload = {
        ...data,
        description: data.description || null,
        parent_id: data.parent_id || null,
      };
      if (isEdit && category) {
        return apiPut(`/categories/${category.category_id}`, payload);
      }
      return apiPost("/categories", payload);
    },
    onSuccess: () => {
      toast.success(isEdit ? "Category updated" : "Category created");
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      onClose();
    },
    onError: () =>
      toast.error(isEdit ? "Failed to update category" : "Failed to create category"),
  });

  const parentOptions = allCategories.filter(
    (c) => c.category_id !== category?.category_id
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">
            {isEdit ? "Edit Category" : "Create Category"}
          </h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        <form
          onSubmit={handleSubmit((data) => mutation.mutate(data))}
          className="p-6 space-y-4"
        >
          <div>
            <label className="label">Category Name</label>
            <input
              {...register("category_name")}
              className={`input ${errors.category_name ? "input-error" : ""}`}
            />
            {errors.category_name && (
              <p className="mt-1 text-xs text-red-600">
                {errors.category_name.message}
              </p>
            )}
          </div>
          <div>
            <label className="label">Category Code</label>
            <input
              {...register("category_code")}
              disabled={isEdit}
              className={`input ${errors.category_code ? "input-error" : ""} ${
                isEdit ? "bg-gray-50" : ""
              }`}
            />
            {errors.category_code && (
              <p className="mt-1 text-xs text-red-600">
                {errors.category_code.message}
              </p>
            )}
          </div>
          <div>
            <label className="label">Description</label>
            <textarea
              {...register("description")}
              rows={3}
              className="input resize-none"
            />
          </div>
          <div>
            <label className="label">Parent Category</label>
            <select {...register("parent_id", { valueAsNumber: true })} className="input">
              <option value="">None (Root Category)</option>
              {parentOptions.map((cat) => (
                <option key={cat.category_id} value={cat.category_id}>
                  {cat.category_name}
                </option>
              ))}
            </select>
          </div>
          {isEdit && (
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                {...register("is_active")}
                id="is_active"
                className="h-4 w-4 rounded border-gray-300"
              />
              <label htmlFor="is_active" className="text-sm text-gray-700">
                Active
              </label>
            </div>
          )}
          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="btn-primary"
            >
              {isSubmitting ? (
                <Spinner size="sm" />
              ) : isEdit ? (
                "Save Changes"
              ) : (
                "Create Category"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function DeleteConfirmModal({
  category,
  isPending,
  onConfirm,
  onClose,
}: {
  category: Category;
  isPending: boolean;
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Delete Category</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="p-6 space-y-4">
          <p className="text-sm text-gray-600">
            Are you sure you want to delete{" "}
            <span className="font-medium text-gray-900">
              {category.category_name}
            </span>
            ? This action cannot be undone.
          </p>
          {(category.child_count > 0 || category.product_count > 0) && (
            <div className="rounded-md bg-yellow-50 p-3">
              <p className="text-sm text-yellow-800">
                This category has{" "}
                {category.child_count > 0 &&
                  `${category.child_count} child ${
                    category.child_count === 1 ? "category" : "categories"
                  }`}
                {category.child_count > 0 && category.product_count > 0 && " and "}
                {category.product_count > 0 &&
                  `${category.product_count} product${
                    category.product_count === 1 ? "" : "s"
                  }`}
                . It may not be deletable.
              </p>
            </div>
          )}
          <div className="flex justify-end gap-3">
            <button onClick={onClose} className="btn-secondary">
              Cancel
            </button>
            <button
              onClick={onConfirm}
              disabled={isPending}
              className="btn-danger"
            >
              {isPending ? <Spinner size="sm" /> : "Delete"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function Pagination({
  page,
  totalPages,
  totalItems,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  totalItems: number;
  onPageChange: (p: number) => void;
}) {
  return (
    <div className="mt-4 flex items-center justify-between">
      <p className="text-sm text-gray-500">{totalItems} total items</p>
      <div className="flex items-center gap-2">
        <button
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
          className="btn-secondary btn-sm"
        >
          Previous
        </button>
        <span className="text-sm text-gray-600">
          Page {page} of {totalPages}
        </span>
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
