import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Eye, EyeOff, LogIn } from "lucide-react";
import toast from "react-hot-toast";
import { useAuth } from "@/hooks/useAuth";
import { Spinner } from "@/components/feedback/Spinner";

const loginSchema = z.object({
  username: z.string().min(1, "Username is required"),
  password: z.string().min(1, "Password is required"),
});

type LoginForm = z.infer<typeof loginSchema>;

export function LoginPage() {
  const { login } = useAuth();
  const [showPassword, setShowPassword] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginForm) => {
    try {
      await login(data);
      toast.success("Welcome back!");
    } catch (err: unknown) {
      const apiErr = err as { response?: { data?: { error?: { message?: string } } } };
      const message = apiErr.response?.data?.error?.message || "Login failed. Please try again.";
      toast.error(message);
    }
  };

  return (
    <div className="card p-8">
      <h2 className="text-xl font-bold text-gray-900 mb-6">Sign in to your account</h2>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div>
          <label htmlFor="username" className="label">Username</label>
          <input
            id="username"
            type="text"
            autoComplete="username"
            className={`input ${errors.username ? "input-error" : ""}`}
            placeholder="Enter your username"
            {...register("username")}
          />
          {errors.username && (
            <p className="mt-1 text-xs text-red-600">{errors.username.message}</p>
          )}
        </div>

        <div>
          <label htmlFor="password" className="label">Password</label>
          <div className="relative">
            <input
              id="password"
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              className={`input pr-10 ${errors.password ? "input-error" : ""}`}
              placeholder="Enter your password"
              {...register("password")}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
          {errors.password && (
            <p className="mt-1 text-xs text-red-600">{errors.password.message}</p>
          )}
        </div>

        <button
          type="submit"
          disabled={isSubmitting}
          className="btn-primary w-full"
        >
          {isSubmitting ? (
            <Spinner size="sm" />
          ) : (
            <>
              <LogIn className="h-4 w-4" />
              Sign in
            </>
          )}
        </button>
      </form>
    </div>
  );
}
