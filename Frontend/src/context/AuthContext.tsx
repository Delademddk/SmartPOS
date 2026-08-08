import { createContext, useCallback, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { authService } from "@/services/auth.service";
import type { User, LoginCredentials } from "@/types";
import { ROLES, type RoleCode } from "@/constants";

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => Promise<void>;
  hasPermission: (permission: string) => boolean;
  hasRole: (role: RoleCode) => boolean;
  isAdmin: boolean;
  isCashier: boolean;
}

export const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [user, setUser] = useState<User | null>(authService.getStoredUser());

  const { data: currentUser, isLoading } = useQuery({
    queryKey: ["auth", "me"],
    queryFn: async () => {
      const me = await authService.getMe();
      setUser(me);
      return me;
    },
    enabled: authService.isAuthenticated(),
    retry: false,
    staleTime: 5 * 60 * 1000,
  });

  useEffect(() => {
    if (currentUser) {
      setUser(currentUser);
    }
  }, [currentUser]);

  const login = useCallback(
    async (credentials: LoginCredentials) => {
      const response = await authService.login(credentials);
      setUser(response.user);
      queryClient.clear();
      navigate(response.user.role_code === ROLES.CASHIER ? "/pos" : "/dashboard");
    },
    [navigate, queryClient],
  );

  const logout = useCallback(async () => {
    const refreshToken = authService.getRefreshToken();
    if (refreshToken) {
      await authService.logout(refreshToken);
    } else {
      authService.clearStorage();
    }
    setUser(null);
    queryClient.clear();
    navigate("/login");
  }, [navigate, queryClient]);

  const hasPermission = useCallback(
    (permission: string): boolean => {
      if (!user) return false;
      if (user.role_code === ROLES.ADMIN) return true;
      return true;
    },
    [user],
  );

  const hasRole = useCallback(
    (role: RoleCode): boolean => {
      return user?.role_code === role;
    },
    [user],
  );

  const isAdmin = user?.role_code === ROLES.ADMIN;
  const isCashier = user?.role_code === ROLES.CASHIER;

  const value = useMemo(
    () => ({
      user,
      isLoading,
      isAuthenticated: !!user,
      login,
      logout,
      hasPermission,
      hasRole,
      isAdmin,
      isCashier,
    }),
    [user, isLoading, login, logout, hasPermission, hasRole, isAdmin, isCashier],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
