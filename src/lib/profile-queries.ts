/**
 * Secure profile query helpers
 * 
 * Uses get_public_profiles RPC to fetch other users' profiles
 * without exposing sensitive fields (email, phone, coordinates, DOB).
 * 
 * Self-queries still use direct profiles table access (owner policy).
 */
import { supabase } from "@/integrations/supabase/client";

export interface PublicProfile {
  id: string;
  user_id: string;
  full_name: string | null;
  gender: string | null;
  age: number | null;
  bio: string | null;
  country: string | null;
  state: string | null;
  city: string | null;
  photo_url: string | null;
  primary_language: string | null;
  preferred_language: string | null;
  language: string | null;
  interests: string[] | null;
  life_goals: string[] | null;
  occupation: string | null;
  education_level: string | null;
  religion: string | null;
  marital_status: string | null;
  height_cm: number | null;
  body_type: string | null;
  is_verified: boolean | null;
  is_premium: boolean | null;
  account_status: string;
  approval_status: string;
  profile_completeness: number | null;
  last_active_at: string | null;
  created_at: string;
  updated_at: string;
  is_indian: boolean | null;
  is_earning_eligible: boolean | null;
  earning_badge_type: string | null;
  performance_score: number | null;
  avg_response_time_seconds: number | null;
  total_chats_count: number | null;
  monthly_chat_minutes: number | null;
  verification_status: boolean | null;
  promoted_from_free: boolean | null;
  ai_approved: boolean | null;
}

/**
 * Fetch public profile data for one or more users (excludes sensitive fields)
 */
export async function fetchPublicProfiles(userIds: string[]): Promise<PublicProfile[]> {
  if (!userIds.length) return [];
  
  const { data, error } = await supabase.rpc('get_public_profiles', {
    user_ids: userIds,
  });
  
  if (error) {
    console.error('Error fetching public profiles:', error);
    return [];
  }
  
  return (data || []) as PublicProfile[];
}

/**
 * Fetch a single public profile by user_id
 */
export async function fetchPublicProfile(userId: string): Promise<PublicProfile | null> {
  const profiles = await fetchPublicProfiles([userId]);
  return profiles[0] || null;
}
