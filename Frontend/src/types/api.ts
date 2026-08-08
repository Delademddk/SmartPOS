export interface ApiMeta {
  page: number;
  page_size: number;
  total_items: number;
  total_pages: number;
}

export interface ApiSuccessResponse<T> {
  success: true;
  data: T;
  meta?: ApiMeta;
}

export interface ApiErrorDetail {
  field?: string;
  message: string;
}

export interface ApiError {
  code: string;
  message: string;
  details: ApiErrorDetail[];
  timestamp: string;
  request_id: string | null;
}

export interface ApiErrorResponse {
  success: false;
  error: ApiError;
}

export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;

export interface PaginationParams {
  page?: number;
  page_size?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: ApiMeta;
}
