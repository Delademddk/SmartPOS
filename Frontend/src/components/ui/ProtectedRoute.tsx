import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { PageLoader } from "@/components/feedback/PageLoader";
import type { RoleCode } from "@/constants";

interface ProtectedRouteProps {
  allowedRoles?: RoleCode[];
}

export function ProtectedRoute({ allowedRoles }: ProtectedRouteProps) {
  const { user, isLoading, isAuthenticated } = useAuth();

  if (isLoading) {
    return <PageLoader />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && user && !allowedRoles.includes(user.role_code as RoleCode)) {
    return <Navigate to="/dashboard" replace />;
  }

  return <Outlet />;
}
