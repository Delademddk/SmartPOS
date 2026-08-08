import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Search, Edit2, Trash2, KeyRound, X } from "lucide-react";
import toast from "react-hot-toast";
import { apiGet, apiPost, apiPut } from "@/api/client";
import { usePagination } from "@/hooks/usePagination";
import { PageLoader } from "@/components/feedback/PageLoader";
import { EmptyState } from "@/components/feedback/EmptyState";
import { Spinner } from "@/components/feedback/Spinner";
import { formatDate, statusColor } from "@/utils/format";
import type { User, Role } from "@/types";

const userSchema = z.object({
  username: z.string().min(3, "Username must be at least 3 characters"),
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters").optional().or(z.literal("")),
  full_name: z.string().min(1, "Full name is required"),
  phone: z.string().optional(),
  role_id: z.number().min(1, "Role is required"),
  must_change_password: z.boolean().optional(),
});

type UserForm = z.infer<typeof userSchema>;

export function UsersPage() {
  const queryClient = useQueryClient();
  const { page, pageSize, setPage } = usePagination();
  const [search, setSearch] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [showResetPassword, setShowResetPassword] = useState<User | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["users", page, pageSize, search],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        page_size: String(pageSize),
      });
      if (search) params.set("search", search);
      const res = await apiGet<User[]>(`/users?${params}`);
      return { data: res.data, meta: res.meta! };
    },
  });

  const { data: roles } = useQuery({
    queryKey: ["roles"],
    queryFn: async () => {
      const res = await apiGet<Role[]>("/roles");
      return res.data;
    },
  });

  const deactivateMutation = useMutation({
    mutationFn: (userId: number) => apiPost(`/users/${userId}/deactivate`),
    onSuccess: () => {
      toast.success("User deactivated");
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
    onError: () => toast.error("Failed to deactivate user"),
  });

  if (isLoading) return <PageLoader />;

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Users</h1>
        <button onClick={() => { setEditingUser(null); setShowForm(true); }} className="btn-primary">
          <Plus className="h-4 w-4" /> Add User
        </button>
      </div>

      <div className="card mb-4 p-4">
        <div className="relative max-w-sm">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search users..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-10"
          />
        </div>
      </div>

      {!data?.data.length ? (
        <EmptyState title="No users found" description="Create your first user to get started." />
      ) : (
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last Login</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((user) => (
                <tr key={user.user_id}>
                  <td>
                    <div>
                      <p className="font-medium">{user.full_name}</p>
                      <p className="text-xs text-gray-500">@{user.username} &middot; {user.email}</p>
                    </div>
                  </td>
                  <td><span className="badge-info">{user.role_name}</span></td>
                  <td>
                    <span className={statusColor(user.is_active ? "ACTIVE" : "VOIDED")}>
                      {user.is_active ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td>{user.last_login_at ? formatDate(user.last_login_at) : "Never"}</td>
                  <td>
                    <div className="flex items-center justify-end gap-1">
                      <button onClick={() => { setEditingUser(user); setShowForm(true); }} className="btn-ghost btn-sm" title="Edit">
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button onClick={() => setShowResetPassword(user)} className="btn-ghost btn-sm" title="Reset Password">
                        <KeyRound className="h-4 w-4" />
                      </button>
                      <button onClick={() => deactivateMutation.mutate(user.user_id)} className="btn-ghost btn-sm text-red-600" title="Deactivate">
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
        <UserModal
          user={editingUser}
          roles={roles || []}
          onClose={() => { setShowForm(false); setEditingUser(null); }}
        />
      )}

      {showResetPassword && (
        <ResetPasswordModal
          user={showResetPassword}
          onClose={() => setShowResetPassword(null)}
        />
      )}
    </div>
  );
}

function UserModal({ user, roles, onClose }: { user: User | null; roles: Role[]; onClose: () => void }) {
  const queryClient = useQueryClient();
  const isEdit = !!user;

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<UserForm>({
    resolver: zodResolver(userSchema),
    defaultValues: user
      ? { username: user.username, email: user.email, full_name: user.full_name, phone: user.phone || "", role_id: user.role_id }
      : { must_change_password: true },
  });

  const mutation = useMutation({
    mutationFn: (data: UserForm) => {
      if (isEdit && user) {
        return apiPut(`/users/${user.user_id}`, {
          full_name: data.full_name,
          phone: data.phone || null,
          role_id: data.role_id,
        });
      }
      return apiPost("/users", data);
    },
    onSuccess: () => {
      toast.success(isEdit ? "User updated" : "User created");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      onClose();
    },
    onError: () => toast.error(isEdit ? "Failed to update user" : "Failed to create user"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">{isEdit ? "Edit User" : "Create User"}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded"><X className="h-5 w-5" /></button>
        </div>
        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="p-6 space-y-4">
          <div>
            <label className="label">Username</label>
            <input {...register("username")} disabled={isEdit} className={`input ${errors.username ? "input-error" : ""} ${isEdit ? "bg-gray-50" : ""}`} />
            {errors.username && <p className="mt-1 text-xs text-red-600">{errors.username.message}</p>}
          </div>
          <div>
            <label className="label">Email</label>
            <input {...register("email")} type="email" className={`input ${errors.email ? "input-error" : ""}`} />
            {errors.email && <p className="mt-1 text-xs text-red-600">{errors.email.message}</p>}
          </div>
          {!isEdit && (
            <div>
              <label className="label">Password</label>
              <input {...register("password")} type="password" className={`input ${errors.password ? "input-error" : ""}`} />
              {errors.password && <p className="mt-1 text-xs text-red-600">{errors.password.message}</p>}
            </div>
          )}
          <div>
            <label className="label">Full Name</label>
            <input {...register("full_name")} className={`input ${errors.full_name ? "input-error" : ""}`} />
            {errors.full_name && <p className="mt-1 text-xs text-red-600">{errors.full_name.message}</p>}
          </div>
          <div>
            <label className="label">Phone</label>
            <input {...register("phone")} className="input" />
          </div>
          <div>
            <label className="label">Role</label>
            <select {...register("role_id", { valueAsNumber: true })} className={`input ${errors.role_id ? "input-error" : ""}`}>
              <option value="">Select a role</option>
              {roles.map((r) => (
                <option key={r.role_id} value={r.role_id}>{r.role_name}</option>
              ))}
            </select>
            {errors.role_id && <p className="mt-1 text-xs text-red-600">{errors.role_id.message}</p>}
          </div>
          <div className="flex justify-end gap-3 pt-4 border-t">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" disabled={isSubmitting} className="btn-primary">
              {isSubmitting ? <Spinner size="sm" /> : isEdit ? "Save Changes" : "Create User"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function ResetPasswordModal({ user, onClose }: { user: User; onClose: () => void }) {
  const [newPassword, setNewPassword] = useState("");

  const mutation = useMutation({
    mutationFn: () => apiPost(`/users/${user.user_id}/reset-password`, { new_password: newPassword }),
    onSuccess: () => {
      toast.success("Password reset successfully");
      onClose();
    },
    onError: () => toast.error("Failed to reset password"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="card w-full max-w-md">
        <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold">Reset Password for {user.username}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded"><X className="h-5 w-5" /></button>
        </div>
        <div className="p-6 space-y-4">
          <div>
            <label className="label">New Password</label>
            <input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} className="input" minLength={8} />
          </div>
          <div className="flex justify-end gap-3">
            <button onClick={onClose} className="btn-secondary">Cancel</button>
            <button onClick={() => mutation.mutate()} disabled={!newPassword || newPassword.length < 8} className="btn-primary">
              {mutation.isPending ? <Spinner size="sm" /> : "Reset Password"}
            </button>
          </div>
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
