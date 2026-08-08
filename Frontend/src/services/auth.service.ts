import { apiPost, apiGet } from "@/api/client";
import type {
  LoginCredentials,
  LoginResponse,
  User,
  ChangePasswordPayload,
} from "@/types";
import { TOKEN_KEY, REFRESH_TOKEN_KEY, USER_KEY } from "@/constants";

export const authService = {
  async login(credentials: LoginCredentials): Promise<LoginResponse> {
    const response = await apiPost<LoginResponse>("/auth/login", credentials);
    if (response.success && response.data) {
      localStorage.setItem(TOKEN_KEY, response.data.access_token);
      localStorage.setItem(REFRESH_TOKEN_KEY, response.data.refresh_token);
      localStorage.setItem(USER_KEY, JSON.stringify(response.data.user));
    }
    return response.data;
  },

  async logout(refreshToken: string): Promise<void> {
    try {
      await apiPost("/auth/logout", { refresh_token: refreshToken });
    } finally {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(REFRESH_TOKEN_KEY);
      localStorage.removeItem(USER_KEY);
    }
  },

  async getMe(): Promise<User> {
    const response = await apiGet<User>("/auth/me");
    return response.data;
  },

  async changePassword(payload: ChangePasswordPayload): Promise<void> {
    await apiPost("/auth/change-password", payload);
  },

  getStoredUser(): LoginResponse["user"] | null {
    const stored = localStorage.getItem(USER_KEY);
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch {
        return null;
      }
    }
    return null;
  },

  getAccessToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  },

  getRefreshToken(): string | null {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
  },

  isAuthenticated(): boolean {
    return !!localStorage.getItem(TOKEN_KEY);
  },

  clearStorage(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  },
};
