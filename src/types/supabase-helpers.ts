/**
 * Helper types for Supabase query results that lose type inference
 * when put into Maps or used with complex query patterns.
 */

export interface ProfileQueryResult {
  user_id: string;
  full_name: string | null;
  photo_url: string | null;
  primary_language: string | null;
  preferred_language?: string | null;
  gender?: string | null;
  age?: number | null;
  country?: string | null;
  is_indian?: boolean | null;
  is_earning_eligible?: boolean | null;
  ai_approved?: boolean | null;
  approval_status?: string;
}

export interface AvailabilityQueryResult {
  user_id: string;
  is_available: boolean;
  current_chat_count: number;
  max_concurrent_chats: number;
}

export interface WalletQueryResult {
  user_id: string;
  balance: number;
}

export interface StatusQueryResult {
  user_id: string;
  is_online: boolean;
}
