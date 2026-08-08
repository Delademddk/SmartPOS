import type { User } from "./models";

export interface UserSummary {
  user_id: number;
  username: string;
  email: string;
  full_name: string;
  role_id: number;
  role_code: string;
  role_name: string;
  is_active: boolean;
  must_change_password: boolean;
  last_login_at: string | null;
}

/**
 * The authenticated user held in AuthContext. It is compatible with both the
 * login/stored shape (UserSummary, which omits phone/created_at/updated_at)
 * and the full /auth/me record (User).
 */
export type AuthenticatedUser = UserSummary &
  Partial<Pick<User, "phone" | "created_at" | "updated_at">>;

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
}

export interface LoginResponse extends TokenResponse {
  refresh_token: string;
  user: UserSummary;
}

export interface ChangePasswordPayload {
  current_password: string;
  new_password: string;
}

export interface RequestPasswordResetPayload {
  email: string;
}

export interface CompletePasswordResetPayload {
  token: string;
  new_password: string;
}
