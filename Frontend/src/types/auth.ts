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

export interface RefreshResponse extends TokenResponse {}

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
