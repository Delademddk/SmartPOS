import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { User, Lock, Save } from "lucide-react";
import toast from "react-hot-toast";
import { apiPut, apiPost } from "@/api/client";
import { useAuth } from "@/hooks/useAuth";
import { Spinner } from "@/components/feedback";
import { formatDate, getInitials } from "@/utils/format";

const profileSchema = z.object({
  full_name: z.string().min(1, "Full name is required"),
  phone: z.string().optional(),
  email: z.string().email("Invalid email address"),
});

type ProfileForm = z.infer<typeof profileSchema>;

const passwordSchema = z.object({
  current_password: z.string().min(1, "Current password is required"),
  new_password: z.string().min(8, "Password must be at least 8 characters"),
  confirm_password: z.string(),
}).refine((data) => data.new_password === data.confirm_password, {
  message: "Passwords do not match",
  path: ["confirm_password"],
});

type PasswordForm = z.infer<typeof passwordSchema>;

export function ProfilePage() {
  const { user } = useAuth();

  if (!user) return null;

  return (
    <div className="space-y-6">
      <div className="page-header">
        <h1 className="page-title">My Profile</h1>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="card p-6 lg:col-span-1">
          <div className="flex flex-col items-center text-center">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary-100 text-2xl font-bold text-primary-700">
              {getInitials(user.full_name)}
            </div>
            <h2 className="mt-4 text-lg font-semibold">{user.full_name}</h2>
            <p className="text-sm text-gray-500">@{user.username}</p>
            <span className="badge-info mt-2">{user.role_name}</span>
            <div className="mt-4 w-full space-y-2 text-sm text-gray-600">
              <div className="flex justify-between border-b border-gray-100 py-2">
                <span className="text-gray-500">Email</span>
                <span>{user.email}</span>
              </div>
              <div className="flex justify-between border-b border-gray-100 py-2">
                <span className="text-gray-500">Phone</span>
                <span>{user.phone || "Not set"}</span>
              </div>
              <div className="flex justify-between border-b border-gray-100 py-2">
                <span className="text-gray-500">Last Login</span>
                <span>{user.last_login_at ? formatDate(user.last_login_at) : "Never"}</span>
              </div>
              <div className="flex justify-between py-2">
                <span className="text-gray-500">Member Since</span>
                <span>{formatDate(user.created_at || "")}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-6 lg:col-span-2">
          <EditProfileForm user={user} />
          <ChangePasswordForm />
        </div>
      </div>
    </div>
  );
}

function EditProfileForm({ user }: { user: { full_name: string; phone?: string | null; email: string } }) {
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<ProfileForm>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      full_name: user.full_name,
      phone: user.phone || "",
      email: user.email,
    },
  });

  const onSubmit = async (data: ProfileForm) => {
    try {
      await apiPut("/users/me", {
        full_name: data.full_name,
        phone: data.phone || null,
        email: data.email,
      });
      toast.success("Profile updated successfully");
    } catch {
      toast.error("Failed to update profile");
    }
  };

  return (
    <div className="card">
      <div className="flex items-center gap-2 border-b border-gray-200 px-6 py-4">
        <User className="h-5 w-5 text-gray-500" />
        <h3 className="font-semibold">Edit Profile</h3>
      </div>
      <form onSubmit={handleSubmit(onSubmit)} className="p-6 space-y-4">
        <div>
          <label className="label">Full Name</label>
          <input {...register("full_name")} className={`input ${errors.full_name ? "input-error" : ""}`} />
          {errors.full_name && <p className="mt-1 text-xs text-red-600">{errors.full_name.message}</p>}
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
        <div className="flex justify-end pt-4 border-t">
          <button type="submit" disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? <Spinner size="sm" /> : <><Save className="h-4 w-4" /> Save Changes</>}
          </button>
        </div>
      </form>
    </div>
  );
}

function ChangePasswordForm() {
  const { register, handleSubmit, formState: { errors, isSubmitting }, reset } = useForm<PasswordForm>({
    resolver: zodResolver(passwordSchema),
  });

  const onSubmit = async (data: PasswordForm) => {
    try {
      await apiPost("/auth/change-password", {
        current_password: data.current_password,
        new_password: data.new_password,
      });
      toast.success("Password changed successfully");
      reset();
    } catch {
      toast.error("Failed to change password. Please check your current password.");
    }
  };

  return (
    <div className="card">
      <div className="flex items-center gap-2 border-b border-gray-200 px-6 py-4">
        <Lock className="h-5 w-5 text-gray-500" />
        <h3 className="font-semibold">Change Password</h3>
      </div>
      <form onSubmit={handleSubmit(onSubmit)} className="p-6 space-y-4">
        <div>
          <label className="label">Current Password</label>
          <input {...register("current_password")} type="password" className={`input ${errors.current_password ? "input-error" : ""}`} />
          {errors.current_password && <p className="mt-1 text-xs text-red-600">{errors.current_password.message}</p>}
        </div>
        <div>
          <label className="label">New Password</label>
          <input {...register("new_password")} type="password" className={`input ${errors.new_password ? "input-error" : ""}`} />
          {errors.new_password && <p className="mt-1 text-xs text-red-600">{errors.new_password.message}</p>}
        </div>
        <div>
          <label className="label">Confirm New Password</label>
          <input {...register("confirm_password")} type="password" className={`input ${errors.confirm_password ? "input-error" : ""}`} />
          {errors.confirm_password && <p className="mt-1 text-xs text-red-600">{errors.confirm_password.message}</p>}
        </div>
        <div className="flex justify-end pt-4 border-t">
          <button type="submit" disabled={isSubmitting} className="btn-primary">
            {isSubmitting ? <Spinner size="sm" /> : <><Lock className="h-4 w-4" /> Change Password</>}
          </button>
        </div>
      </form>
    </div>
  );
}
