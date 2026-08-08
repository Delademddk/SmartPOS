import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Search, Edit2, Trash2, X, Phone, Mail, User } from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost, apiPut, apiDelete } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader } from "@/components/feedback/PageLoader";
import { EmptyState } from "@/components/feedback/EmptyState";
import { Spinner } from "@/components/feedback/Spinner";
import { formatDate, statusColor } from "@/utils/format";
import type { Supplier, SupplierDetail, SupplierContact } from "@/types";

const supplierSchema = z.object({
  supplier_name: z.string().min(1, "Supplier name is required"),
  contact_person: z.string().optional().or(z.literal("")),
  email: z.string().email("Invalid email address").optional().or(z.literal("")),
  phone: z.string().optional().or(z.literal("")),
  address: z.string().optional().or(z.literal("")),
  city: z.string().optional().or(z.literal("")),
  state: z.string().optional().or(z.literal("")),
  postal_code: z.string().optional().or(z.literal("")),
  country: z.string().optional().or(z.literal("")),
});

type SupplierForm = z.infer<typeof supplierSchema>;

const contactSchema = z.object({
  contact_name: z.string().min(1, "Contact name is required"),
  contact_type: z.string().optional().or(z.literal("")),
  email: z.string().email("Invalid email address").optional().or(z.literal("")),
  phone: z.string().optional().or(z.literal("")),
  is_primary: z.boolean(),
});

type ContactForm = z.infer<typeof contactSchema>;

export function SuppliersPage() {
  const queryClient = useQueryClient();
  const { page, pageSize, setPage, setPageSize } = usePagination();
  const [search, setSearch] = useState("");
  const [activeFilter, setActiveFilter] = useState<string>("");
  const [showForm, setShowForm] = useState(false);
  const [editingSupplier, setEditingSupplier] = useState<Supplier | null>(null);
  const [selectedSupplierId, setSelectedSupplierId] = useState<number | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Supplier | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["suppliers", page, pageSize, search, activeFilter],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (search) params.set("search", search);
      if (activeFilter !== "") params.set("is_active", activeFilter);
      const res = await apiGet<Supplier[]>(`/suppliers?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: supplierDetail, isLoading: detailLoading } = useQuery({
    queryKey: ["supplier", selectedSupplierId],
    queryFn: async () => {
      const res = await apiGet<SupplierDetail>(`/suppliers/${selectedSupplierId}`);
      return res.data;
    },
    enabled: selectedSupplierId !== null,
  });

  const deleteMutation = useMutation({
    mutationFn: (supplierId: number) => apiDelete(`/suppliers/${supplierId}`),
    onSuccess: () => {
      toast.success("Supplier deleted");
      queryClient.invalidateQueries({ queryKey: ["suppliers"] });
      if (selectedSupplierId === deleteTarget?.supplier_id) {
        setSelectedSupplierId(null);
      }
      setDeleteTarget(null);
    },
    onError: () => toast.error("Failed to delete supplier"),
  });

  if (isLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Suppliers</h1>
        <button onClick={() => { setEditingSupplier(null); setShowForm(true); }} className="btn-primary">
          <Plus className="h-4 w-4" /> Add Supplier
        </button>
      </div>

      <div className="card mb-4 p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search suppliers..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="input pl-10"
            />
          </div>
          <select
            value={activeFilter}
            onChange={(e) => { setActiveFilter(e.target.value); setPage(1); }}
            className="input max-w-xs"
          >
            <option value="">All Status</option>
            <option value="true">Active</option>
            <option value="false">Inactive</option>
          </select>
        </div>
      </div>

      {!data?.data.length ? (
        <EmptyState title="No suppliers found" description="Create your first supplier to get started." />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Supplier</th>
                <th>Contact</th>
                <th>Location</th>
                <th>Status</th>
                <th>Created</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((supplier) => (
                <tr
                  key={supplier.supplier_id}
                  className="cursor-pointer hover:bg-gray-50"
                  onClick={() => setSelectedSupplierId(
                    selectedSupplierId === supplier.supplier_id ? null : supplier.supplier_id
                  )}
                >
                  <td>
                    <div>
                      <p className="font-medium">{supplier.supplier_name}</p>
                      {supplier.email && (
                        <p className="text-xs text-gray-500 flex items-center gap-1">
                          <Mail className="h-3 w-3" /> {supplier.email}
                        </p>
                      )}
                    </div>
                  </td>
                  <td>
                    <div>
                      {supplier.contact_person && (
                        <p className="text-sm">{supplier.contact_person}</p>
                      )}
                      {supplier.phone && (
                        <p className="text-xs text-gray-500 flex items-center gap-1">
                          <Phone className="h-3 w-3" /> {supplier.phone}
                        </p>
                      )}
                    </div>
                  </td>
                  <td>
                    <div>
                      {[supplier.city, supplier.state].filter(Boolean).join(", ") || <span className="text-gray-400">-</span>}
                    </div>
                  </td>
                  <td>
                    <span className={statusColor(supplier.is_active ? "ACTIVE" : "VOIDED")}>
                      {supplier.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td>{formatDate(supplier.created_at)}</td>
                  <td>
                    <div className="flex items-center justify-end gap-1" onClick={(e) => e.stopPropagation()}>
                      <button
                        onClick={() => { setEditingSupplier(supplier); setShowForm(true); }}
                        className="btn-ghost btn-sm"
                        title="Edit"
                      >
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => setDeleteTarget(supplier)}
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

      {selectedSupplierId && (
        <SupplierDetailPanel
          supplierId={selectedSupplierId}
          data={supplierDetail}
          isLoading={detailLoading}
          onClose={() => setSelectedSupplierId(null)}
        />
      )}

      {showForm && (
        <SupplierModal
          supplier={editingSupplier}
          onClose={() => { setShowForm(false); setEditingSupplier(null); }}
        />
      )}

      {deleteTarget && (
        <ConfirmDeleteModal
          title={deleteTarget.supplier_name}
          onConfirm={() => deleteMutation.mutate(deleteTarget.supplier_id)}
          onClose={() => setDeleteTarget(null)}
          isPending={deleteMutation.isPending}
        />
      )}
    </div>
  );
}

function SupplierDetailPanel({
  supplierId,
  data,
  isLoading,
  onClose,
}: {
  supplierId: number;
  data: SupplierDetail | undefined;
  isLoading: boolean;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [showContactForm, setShowContactForm] = useState(false);
  const [editingContact, setEditingContact] = useState<SupplierContact | null>(null);
  const [deleteContactTarget, setDeleteContactTarget] = useState<SupplierContact | null>(null);

  const deleteContactMutation = useMutation({
    mutationFn: (contactId: number) => apiDelete(`/suppliers/${supplierId}/contacts/${contactId}`),
    onSuccess: () => {
      toast.success("Contact deleted");
      queryClient.invalidateQueries({ queryKey: ["supplier", supplierId] });
    },
    onError: () => toast.error("Failed to delete contact"),
  });

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40">
      <div className="absolute inset-0" onClick={onClose} />
      <div className="relative w-full max-w-xl bg-white h-full overflow-y-auto shadow-xl animate-slide-in-right">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b bg-white px-6 py-4">
          <h2 className="text-lg font-semibold">Supplier Details</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="h-5 w-5" />
          </button>
        </div>

        {isLoading ? (
          <div className="flex justify-center py-12">
            <Spinner />
          </div>
        ) : !data ? (
          <div className="py-12 text-center text-gray-500">Supplier not found</div>
        ) : (
          <div className="p-6 space-y-6">
            <div className="space-y-3">
              <h3 className="font-semibold text-gray-900">{data.supplier_name}</h3>
              <div className="grid grid-cols-2 gap-3 text-sm">
                {data.contact_person && (
                  <div>
                    <span className="text-gray-500">Contact Person</span>
                    <p className="flex items-center gap-1"><User className="h-3 w-3" /> {data.contact_person}</p>
                  </div>
                )}
                {data.email && (
                  <div>
                    <span className="text-gray-500">Email</span>
                    <p className="flex items-center gap-1"><Mail className="h-3 w-3" /> {data.email}</p>
                  </div>
                )}
                {data.phone && (
                  <div>
                    <span className="text-gray-500">Phone</span>
                    <p className="flex items-center gap-1"><Phone className="h-3 w-3" /> {data.phone}</p>
                  </div>
                )}
                <div>
                  <span className="text-gray-500">Status</span>
                  <p>
                    <span className={statusColor(data.is_active ? "ACTIVE" : "VOIDED")}>
                      {data.is_active ? "Active" : "Inactive"}
                    </span>
                  </p>
                </div>
                {data.address && (
                  <div className="col-span-2">
                    <span className="text-gray-500">Address</span>
                    <p>{data.address}</p>
                  </div>
                )}
                {[data.city, data.state, data.postal_code, data.country].filter(Boolean).length > 0 && (
                  <div className="col-span-2">
                    <span className="text-gray-500">Location</span>
                    <p>{[data.city, data.state, data.postal_code, data.country].filter(Boolean).join(", ")}</p>
                  </div>
                )}
                <div>
                  <span className="text-gray-500">Created</span>
                  <p>{formatDate(data.created_at)}</p>
                </div>
                <div>
                  <span className="text-gray-500">Updated</span>
                  <p>{formatDate(data.updated_at)}</p>
                </div>
              </div>
            </div>

            <div className="border-t pt-4">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-gray-900">Contacts</h3>
                <button
                  onClick={() => { setEditingContact(null); setShowContactForm(true); }}
                  className="btn-primary btn-sm"
                >
                  <Plus className="h-3 w-3" /> Add Contact
                </button>
              </div>

              {!data.contacts.length ? (
                <p className="text-sm text-gray-500 text-center py-4">No contacts added yet</p>
              ) : (
                <div className="space-y-3">
                  {data.contacts.map((contact) => (
                    <div key={contact.contact_id} className="card p-3">
                      <div className="flex items-start justify-between">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-sm">{contact.contact_name}</p>
                            {contact.is_primary && (
                              <span className="badge-info text-xs">Primary</span>
                            )}
                            {!contact.is_active && (
                              <span className="text-xs text-gray-400">(Inactive)</span>
                            )}
                          </div>
                          {contact.contact_type && (
                            <p className="text-xs text-gray-500 capitalize">{contact.contact_type}</p>
                          )}
                          <div className="flex items-center gap-4 text-xs text-gray-500">
                            {contact.email && (
                              <span className="flex items-center gap-1"><Mail className="h-3 w-3" /> {contact.email}</span>
                            )}
                            {contact.phone && (
                              <span className="flex items-center gap-1"><Phone className="h-3 w-3" /> {contact.phone}</span>
                            )}
                          </div>
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => { setEditingContact(contact); setShowContactForm(true); }}
                            className="btn-ghost btn-sm"
                            title="Edit"
                          >
                            <Edit2 className="h-3.5 w-3.5" />
                          </button>
                          <button
                            onClick={() => setDeleteContactTarget(contact)}
                            className="btn-ghost btn-sm text-red-600"
                            title="Delete"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {showContactForm && (
          <ContactModal
            supplierId={supplierId}
            contact={editingContact}
            onClose={() => { setShowContactForm(false); setEditingContact(null); }}
          />
        )}

        {deleteContactTarget && (
          <ConfirmDeleteModal
            title={`contact "${deleteContactTarget.contact_name}"`}
            onConfirm={() => deleteContactMutation.mutate(deleteContactTarget.contact_id)}
            onClose={() => setDeleteContactTarget(null)}
            isPending={deleteContactMutation.isPending}
          />
        )}
      </div>
    </div>
  );
}

function SupplierModal({ supplier, onClose }: { supplier: Supplier | null; onClose: () => void }) {
  const queryClient = useQueryClient();
  const isEdit = !!supplier;

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<SupplierForm>({
    resolver: zodResolver(supplierSchema),
    defaultValues: supplier
      ? {
          supplier_name: supplier.supplier_name,
          contact_person: supplier.contact_person || "",
          email: supplier.email || "",
          phone: supplier.phone || "",
          address: supplier.address || "",
          city: supplier.city || "",
          state: supplier.state || "",
          postal_code: supplier.postal_code || "",
          country: supplier.country || "",
        }
      : {},
  });

  const mutation = useMutation({
    mutationFn: (data: SupplierForm) => {
      const payload = {
        ...data,
        email: data.email || null,
        phone: data.phone || null,
        contact_person: data.contact_person || null,
        address: data.address || null,
        city: data.city || null,
        state: data.state || null,
        postal_code: data.postal_code || null,
        country: data.country || null,
      };
      if (isEdit && supplier) {
        return apiPut(`/suppliers/${supplier.supplier_id}`, payload);
      }
      return apiPost("/suppliers", payload);
    },
    onSuccess: () => {
      toast.success(isEdit ? "Supplier updated" : "Supplier created");
      queryClient.invalidateQueries({ queryKey: ["suppliers"] });
      onClose();
    },
    onError: () => toast.error(isEdit ? "Failed to update supplier" : "Failed to create supplier"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">{isEdit ? "Edit Supplier" : "Create Supplier"}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded"><X className="h-5 w-5" /></button>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div>
            <label className="label">Supplier Name *</label>
            <input {...register("supplier_name")} className={`input ${errors.supplier_name ? "input-error" : ""}`} />
            {errors.supplier_name && <p className="mt-1 text-xs text-red-600">{errors.supplier_name.message}</p>}
          </div>
          <div>
            <label className="label">Contact Person</label>
            <input {...register("contact_person")} className="input" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">Email</label>
              <input {...register("email")} type="email" className={`input ${errors.email ? "input-error" : ""}`} />
              {errors.email && <p className="mt-1 text-xs text-red-600">{errors.email.message}</p>}
            </div>
            <div>
              <label className="label">Phone</label>
              <input {...register("phone")} className="input" />
            </div>
          </div>
          <div>
            <label className="label">Address</label>
            <input {...register("address")} className="input" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">City</label>
              <input {...register("city")} className="input" />
            </div>
            <div>
              <label className="label">State</label>
              <input {...register("state")} className="input" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">Postal Code</label>
              <input {...register("postal_code")} className="input" />
            </div>
            <div>
              <label className="label">Country</label>
              <input {...register("country")} className="input" />
            </div>
          </div>
          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : isEdit ? "Save Changes" : "Create Supplier"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function ContactModal({
  supplierId,
  contact,
  onClose,
}: {
  supplierId: number;
  contact: SupplierContact | null;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const isEdit = !!contact;

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<ContactForm>({
    resolver: zodResolver(contactSchema),
    defaultValues: contact
      ? {
          contact_name: contact.contact_name,
          contact_type: contact.contact_type || "",
          email: contact.email || "",
          phone: contact.phone || "",
          is_primary: contact.is_primary,
        }
      : { is_primary: false },
  });

  const mutation = useMutation({
    mutationFn: (data: ContactForm) => {
      const payload = {
        ...data,
        email: data.email || null,
        phone: data.phone || null,
        contact_type: data.contact_type || null,
      };
      if (isEdit && contact) {
        return apiPut(`/suppliers/${supplierId}/contacts/${contact.contact_id}`, payload);
      }
      return apiPost(`/suppliers/${supplierId}/contacts`, payload);
    },
    onSuccess: () => {
      toast.success(isEdit ? "Contact updated" : "Contact added");
      queryClient.invalidateQueries({ queryKey: ["supplier", supplierId] });
      onClose();
    },
    onError: () => toast.error(isEdit ? "Failed to update contact" : "Failed to add contact"),
  });

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">{isEdit ? "Edit Contact" : "Add Contact"}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded"><X className="h-5 w-5" /></button>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div>
            <label className="label">Contact Name *</label>
            <input {...register("contact_name")} className={`input ${errors.contact_name ? "input-error" : ""}`} />
            {errors.contact_name && <p className="mt-1 text-xs text-red-600">{errors.contact_name.message}</p>}
          </div>
          <div>
            <label className="label">Contact Type</label>
            <select {...register("contact_type")} className="input">
              <option value="">Select type</option>
              <option value="sales">Sales</option>
              <option value="support">Support</option>
              <option value="billing">Billing</option>
              <option value="technical">Technical</option>
              <option value="other">Other</option>
            </select>
          </div>
          <div>
            <label className="label">Email</label>
            <input {...register("email")} type="email" className={`input ${errors.email ? "input-error" : ""}`} />
            {errors.email && <p className="mt-1 text-xs text-red-600">{errors.email.message}</p>}
          </div>
          <div>
            <label className="label">Phone</label>
            <input {...register("phone")} className="input" />
          </div>
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              {...register("is_primary")}
              className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              id="is_primary"
            />
            <label htmlFor="is_primary" className="text-sm font-medium text-gray-700">
              Primary contact
            </label>
          </div>
          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : isEdit ? "Save Changes" : "Add Contact"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function ConfirmDeleteModal({
  title,
  onConfirm,
  onClose,
  isPending,
}: {
  title: string;
  onConfirm: () => void;
  onClose: () => void;
  isPending: boolean;
}) {
  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md p-6 space-y-4">
        <h2 className="text-lg font-semibold text-gray-900">Delete {title}</h2>
        <p className="text-sm text-gray-600">
          Are you sure you want to delete <strong>{title}</strong>? This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="btn-secondary">Cancel</button>
          <button onClick={onConfirm} disabled={isPending} className="btn-primary bg-red-600 hover:bg-red-700">
            {isPending ? <Spinner size="sm" /> : "Delete"}
          </button>
        </div>
      </div>
    </div>
  );
}

function Pagination({ page, totalPages, totalItems, onPageChange }: {
  page: number; totalPages: number; totalItems: number; onPageChange: (p: number) => void;
}) {
  return (
    <div className="mt-4 flex items-center justify-between">
      <p className="text-sm text-gray-500">{totalItems} total items</p>
      <div className="flex items-center gap-2">
        <button onClick={() => onPageChange(page - 1)} disabled={page <= 1} className="btn-secondary btn-sm">Previous</button>
        <span className="text-sm text-gray-600">Page {page} of {totalPages}</span>
        <button onClick={() => onPageChange(page + 1)} disabled={page >= totalPages} className="btn-secondary btn-sm">Next</button>
      </div>
    </div>
  );
}
