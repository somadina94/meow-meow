/**
 * API Types
 * 
 * Shared types for the unified async API layer.
 */

// HTTP Methods
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

// Request configuration
export interface RequestConfig<TData = unknown> {
  method?: HttpMethod;
  headers?: Record<string, string>;
  body?: TData;
  timeout?: number;
  retries?: number;
  retryDelay?: number;
  idempotencyKey?: string;
  skipAuth?: boolean;
  cacheKey?: string;
  cacheTTL?: number;
  priority?: 'high' | 'normal' | 'low';
  signal?: AbortSignal;
}

// API Response wrapper
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: ApiError;
  meta?: ResponseMeta;
}

// Error structure
export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
  retryable: boolean;
}

// Response metadata
export interface ResponseMeta {
  cached: boolean;
  timestamp: number;
  requestId?: string;
  duration?: number;
}

// Request state for UI
export interface RequestState<T = unknown> {
  isLoading: boolean;
  isSuccess: boolean;
  isError: boolean;
  data: T | null;
  error: ApiError | null;
}

// Pending request for offline queue
export interface PendingRequest {
  id: string;
  url: string;
  method: HttpMethod;
  body?: unknown;
  headers?: Record<string, string>;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
  idempotencyKey?: string;
  priority: 'high' | 'normal' | 'low';
}

// Network status
export interface NetworkStatus {
  isOnline: boolean;
  connectionType?: 'wifi' | 'cellular' | 'ethernet' | 'unknown';
  effectiveType?: 'slow-2g' | '2g' | '3g' | '4g';
  downlink?: number;
  rtt?: number;
}

// Cache entry
export interface CacheEntry<T = unknown> {
  data: T;
  timestamp: number;
  ttl: number;
  key: string;
}

// Event types for API layer
export type ApiEventType = 
  | 'request:start'
  | 'request:success'
  | 'request:error'
  | 'request:retry'
  | 'network:online'
  | 'network:offline'
  | 'queue:add'
  | 'queue:process'
  | 'queue:complete'
  | 'cache:hit'
  | 'cache:miss'
  | 'cache:update';

export interface ApiEvent {
  type: ApiEventType;
  timestamp: number;
  data?: unknown;
}

// Subscription handler
export type ApiEventHandler = (event: ApiEvent) => void;
