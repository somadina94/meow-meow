export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  public: {
    Tables: {
      absence_records: {
        Row: {
          absence_date: string
          ai_detected: boolean
          approved: boolean | null
          created_at: string
          id: string
          leave_type: string
          reason: string | null
          user_id: string
        }
        Insert: {
          absence_date: string
          ai_detected?: boolean
          approved?: boolean | null
          created_at?: string
          id?: string
          leave_type?: string
          reason?: string | null
          user_id: string
        }
        Update: {
          absence_date?: string
          ai_detected?: boolean
          approved?: boolean | null
          created_at?: string
          id?: string
          leave_type?: string
          reason?: string | null
          user_id?: string
        }
        Relationships: []
      }
      active_chat_sessions: {
        Row: {
          chat_id: string
          created_at: string
          end_reason: string | null
          ended_at: string | null
          id: string
          last_activity_at: string
          man_user_id: string
          rate_per_minute: number
          started_at: string
          status: string
          total_earned: number
          total_minutes: number
          updated_at: string
          woman_user_id: string
        }
        Insert: {
          chat_id: string
          created_at?: string
          end_reason?: string | null
          ended_at?: string | null
          id?: string
          last_activity_at?: string
          man_user_id: string
          rate_per_minute?: number
          started_at?: string
          status?: string
          total_earned?: number
          total_minutes?: number
          updated_at?: string
          woman_user_id: string
        }
        Update: {
          chat_id?: string
          created_at?: string
          end_reason?: string | null
          ended_at?: string | null
          id?: string
          last_activity_at?: string
          man_user_id?: string
          rate_per_minute?: number
          started_at?: string
          status?: string
          total_earned?: number
          total_minutes?: number
          updated_at?: string
          woman_user_id?: string
        }
        Relationships: []
      }
      admin_broadcast_messages: {
        Row: {
          admin_id: string
          created_at: string
          id: string
          is_broadcast: boolean
          is_read: boolean
          message: string
          recipient_id: string | null
          subject: string
        }
        Insert: {
          admin_id: string
          created_at?: string
          id?: string
          is_broadcast?: boolean
          is_read?: boolean
          message: string
          recipient_id?: string | null
          subject: string
        }
        Update: {
          admin_id?: string
          created_at?: string
          id?: string
          is_broadcast?: boolean
          is_read?: boolean
          message?: string
          recipient_id?: string | null
          subject?: string
        }
        Relationships: []
      }
      admin_revenue_transactions: {
        Row: {
          amount: number
          created_at: string
          currency: string
          description: string | null
          id: string
          man_user_id: string | null
          reference_id: string | null
          session_id: string | null
          transaction_type: string
          woman_user_id: string | null
        }
        Insert: {
          amount?: number
          created_at?: string
          currency?: string
          description?: string | null
          id?: string
          man_user_id?: string | null
          reference_id?: string | null
          session_id?: string | null
          transaction_type: string
          woman_user_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          currency?: string
          description?: string | null
          id?: string
          man_user_id?: string | null
          reference_id?: string | null
          session_id?: string | null
          transaction_type?: string
          woman_user_id?: string | null
        }
        Relationships: []
      }
      admin_settings: {
        Row: {
          category: string
          created_at: string
          description: string | null
          id: string
          is_sensitive: boolean
          last_updated_by: string | null
          setting_key: string
          setting_name: string
          setting_type: string
          setting_value: string
          updated_at: string
        }
        Insert: {
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          is_sensitive?: boolean
          last_updated_by?: string | null
          setting_key: string
          setting_name: string
          setting_type?: string
          setting_value: string
          updated_at?: string
        }
        Update: {
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          is_sensitive?: boolean
          last_updated_by?: string | null
          setting_key?: string
          setting_name?: string
          setting_type?: string
          setting_value?: string
          updated_at?: string
        }
        Relationships: []
      }
      admin_user_messages: {
        Row: {
          admin_id: string | null
          created_at: string
          id: string
          is_read: boolean
          message: string
          sender_id: string
          sender_role: string
          target_group: string
          target_user_id: string | null
        }
        Insert: {
          admin_id?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message: string
          sender_id: string
          sender_role?: string
          target_group?: string
          target_user_id?: string | null
        }
        Update: {
          admin_id?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message?: string
          sender_id?: string
          sender_role?: string
          target_group?: string
          target_user_id?: string | null
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          category: string
          created_at: string
          description: string | null
          id: string
          is_public: boolean | null
          setting_key: string
          setting_type: string
          setting_value: Json
          updated_at: string
        }
        Insert: {
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          is_public?: boolean | null
          setting_key: string
          setting_type?: string
          setting_value: Json
          updated_at?: string
        }
        Update: {
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          is_public?: boolean | null
          setting_key?: string
          setting_type?: string
          setting_value?: Json
          updated_at?: string
        }
        Relationships: []
      }
      attendance: {
        Row: {
          attendance_date: string
          auto_marked: boolean
          check_in_time: string | null
          check_out_time: string | null
          created_at: string
          id: string
          notes: string | null
          scheduled_shift_id: string | null
          shift_id: string | null
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          attendance_date: string
          auto_marked?: boolean
          check_in_time?: string | null
          check_out_time?: string | null
          created_at?: string
          id?: string
          notes?: string | null
          scheduled_shift_id?: string | null
          shift_id?: string | null
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          attendance_date?: string
          auto_marked?: boolean
          check_in_time?: string | null
          check_out_time?: string | null
          created_at?: string
          id?: string
          notes?: string | null
          scheduled_shift_id?: string | null
          shift_id?: string | null
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          action_type: string
          admin_email: string | null
          admin_id: string
          created_at: string
          details: string | null
          id: string
          ip_address: string | null
          new_value: Json | null
          old_value: Json | null
          resource_id: string | null
          resource_type: string
          status: string
          user_agent: string | null
        }
        Insert: {
          action: string
          action_type?: string
          admin_email?: string | null
          admin_id: string
          created_at?: string
          details?: string | null
          id?: string
          ip_address?: string | null
          new_value?: Json | null
          old_value?: Json | null
          resource_id?: string | null
          resource_type: string
          status?: string
          user_agent?: string | null
        }
        Update: {
          action?: string
          action_type?: string
          admin_email?: string | null
          admin_id?: string
          created_at?: string
          details?: string | null
          id?: string
          ip_address?: string | null
          new_value?: Json | null
          old_value?: Json | null
          resource_id?: string | null
          resource_type?: string
          status?: string
          user_agent?: string | null
        }
        Relationships: []
      }
      backup_logs: {
        Row: {
          backup_type: string
          completed_at: string | null
          created_at: string
          error_message: string | null
          id: string
          size_bytes: number | null
          started_at: string
          status: string
          storage_path: string | null
          triggered_by: string | null
          updated_at: string
        }
        Insert: {
          backup_type?: string
          completed_at?: string | null
          created_at?: string
          error_message?: string | null
          id?: string
          size_bytes?: number | null
          started_at?: string
          status?: string
          storage_path?: string | null
          triggered_by?: string | null
          updated_at?: string
        }
        Update: {
          backup_type?: string
          completed_at?: string | null
          created_at?: string
          error_message?: string | null
          id?: string
          size_bytes?: number | null
          started_at?: string
          status?: string
          storage_path?: string | null
          triggered_by?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      chat_messages: {
        Row: {
          chat_id: string
          created_at: string
          deleted_at: string | null
          deleted_for_everyone: boolean
          deleted_for_receiver: boolean
          deleted_for_sender: boolean
          edited_at: string | null
          flag_reason: string | null
          flagged: boolean
          flagged_at: string | null
          flagged_by: string | null
          forwarded_from_id: string | null
          id: string
          is_edited: boolean
          is_forwarded: boolean
          is_pinned: boolean
          is_read: boolean | null
          is_translated: boolean | null
          message: string
          moderation_status: string | null
          original_english: string | null
          original_message: string | null
          pinned_at: string | null
          pinned_by: string | null
          receiver_id: string
          reply_to_id: string | null
          sender_id: string
          translated_message: string | null
        }
        Insert: {
          chat_id: string
          created_at?: string
          deleted_at?: string | null
          deleted_for_everyone?: boolean
          deleted_for_receiver?: boolean
          deleted_for_sender?: boolean
          edited_at?: string | null
          flag_reason?: string | null
          flagged?: boolean
          flagged_at?: string | null
          flagged_by?: string | null
          forwarded_from_id?: string | null
          id?: string
          is_edited?: boolean
          is_forwarded?: boolean
          is_pinned?: boolean
          is_read?: boolean | null
          is_translated?: boolean | null
          message: string
          moderation_status?: string | null
          original_english?: string | null
          original_message?: string | null
          pinned_at?: string | null
          pinned_by?: string | null
          receiver_id: string
          reply_to_id?: string | null
          sender_id: string
          translated_message?: string | null
        }
        Update: {
          chat_id?: string
          created_at?: string
          deleted_at?: string | null
          deleted_for_everyone?: boolean
          deleted_for_receiver?: boolean
          deleted_for_sender?: boolean
          edited_at?: string | null
          flag_reason?: string | null
          flagged?: boolean
          flagged_at?: string | null
          flagged_by?: string | null
          forwarded_from_id?: string | null
          id?: string
          is_edited?: boolean
          is_forwarded?: boolean
          is_pinned?: boolean
          is_read?: boolean | null
          is_translated?: boolean | null
          message?: string
          moderation_status?: string | null
          original_english?: string | null
          original_message?: string | null
          pinned_at?: string | null
          pinned_by?: string | null
          receiver_id?: string
          reply_to_id?: string | null
          sender_id?: string
          translated_message?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_pricing: {
        Row: {
          audio_rate_per_minute: number
          audio_women_earning_rate: number
          created_at: string
          currency: string
          gift_women_percent: number
          group_call_rate_per_minute: number
          group_call_women_earning_rate: number
          id: string
          is_active: boolean
          min_withdrawal_balance: number
          rate_per_minute: number
          recharge_platform_fee_percent: number
          updated_at: string
          video_rate_per_minute: number
          video_women_earning_rate: number
          withdrawal_fee_percent: number
          women_earning_rate: number
        }
        Insert: {
          audio_rate_per_minute?: number
          audio_women_earning_rate?: number
          created_at?: string
          currency?: string
          gift_women_percent?: number
          group_call_rate_per_minute?: number
          group_call_women_earning_rate?: number
          id?: string
          is_active?: boolean
          min_withdrawal_balance?: number
          rate_per_minute?: number
          recharge_platform_fee_percent?: number
          updated_at?: string
          video_rate_per_minute?: number
          video_women_earning_rate?: number
          withdrawal_fee_percent?: number
          women_earning_rate?: number
        }
        Update: {
          audio_rate_per_minute?: number
          audio_women_earning_rate?: number
          created_at?: string
          currency?: string
          gift_women_percent?: number
          group_call_rate_per_minute?: number
          group_call_women_earning_rate?: number
          id?: string
          is_active?: boolean
          min_withdrawal_balance?: number
          rate_per_minute?: number
          recharge_platform_fee_percent?: number
          updated_at?: string
          video_rate_per_minute?: number
          video_women_earning_rate?: number
          withdrawal_fee_percent?: number
          women_earning_rate?: number
        }
        Relationships: []
      }
      chat_wait_queue: {
        Row: {
          created_at: string
          id: string
          joined_at: string
          matched_at: string | null
          preferred_language: string
          priority: number
          status: string
          updated_at: string
          user_id: string
          wait_time_seconds: number | null
        }
        Insert: {
          created_at?: string
          id?: string
          joined_at?: string
          matched_at?: string | null
          preferred_language: string
          priority?: number
          status?: string
          updated_at?: string
          user_id: string
          wait_time_seconds?: number | null
        }
        Update: {
          created_at?: string
          id?: string
          joined_at?: string
          matched_at?: string | null
          preferred_language?: string
          priority?: number
          status?: string
          updated_at?: string
          user_id?: string
          wait_time_seconds?: number | null
        }
        Relationships: []
      }
      community_announcements: {
        Row: {
          content: string
          created_at: string
          id: string
          is_active: boolean
          language_code: string
          leader_id: string
          priority: string
          title: string
          updated_at: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          is_active?: boolean
          language_code: string
          leader_id: string
          priority?: string
          title: string
          updated_at?: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          is_active?: boolean
          language_code?: string
          leader_id?: string
          priority?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      community_disputes: {
        Row: {
          created_at: string
          description: string | null
          dispute_type: string
          id: string
          language_code: string
          reported_user_id: string | null
          reporter_id: string
          resolution: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          dispute_type?: string
          id?: string
          language_code: string
          reported_user_id?: string | null
          reporter_id: string
          resolution?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          dispute_type?: string
          id?: string
          language_code?: string
          reported_user_id?: string | null
          reporter_id?: string
          resolution?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      female_profiles: {
        Row: {
          account_status: string
          age: number | null
          ai_approved: boolean | null
          ai_disapproval_reason: string | null
          approval_status: string
          auto_approved: boolean | null
          avg_response_time_seconds: number | null
          bank_account_number: string | null
          bank_name: string | null
          bio: string | null
          body_type: string | null
          country: string | null
          created_at: string
          date_of_birth: string | null
          earning_badge_type: string | null
          earning_slot_assigned_at: string | null
          education_level: string | null
          employee_id: string
          full_name: string | null
          height_cm: number | null
          id: string
          ifsc_code: string | null
          interests: string[] | null
          is_earning_eligible: boolean | null
          is_indian: boolean | null
          is_premium: boolean | null
          is_verified: boolean | null
          last_active_at: string | null
          last_rotation_date: string | null
          life_goals: string[] | null
          marital_status: string | null
          monthly_chat_minutes: number | null
          occupation: string | null
          pan_number: string | null
          performance_score: number | null
          phone: string | null
          photo_url: string | null
          preferred_language: string | null
          primary_language: string | null
          profile_completeness: number | null
          promoted_from_free: boolean | null
          religion: string | null
          state: string | null
          suspended_at: string | null
          suspension_reason: string | null
          total_chats_count: number | null
          updated_at: string
          upi_id: string | null
          user_id: string
        }
        Insert: {
          account_status?: string
          age?: number | null
          ai_approved?: boolean | null
          ai_disapproval_reason?: string | null
          approval_status?: string
          auto_approved?: boolean | null
          avg_response_time_seconds?: number | null
          bank_account_number?: string | null
          bank_name?: string | null
          bio?: string | null
          body_type?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          earning_badge_type?: string | null
          earning_slot_assigned_at?: string | null
          education_level?: string | null
          employee_id?: string
          full_name?: string | null
          height_cm?: number | null
          id?: string
          ifsc_code?: string | null
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          last_rotation_date?: string | null
          life_goals?: string[] | null
          marital_status?: string | null
          monthly_chat_minutes?: number | null
          occupation?: string | null
          pan_number?: string | null
          performance_score?: number | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          promoted_from_free?: boolean | null
          religion?: string | null
          state?: string | null
          suspended_at?: string | null
          suspension_reason?: string | null
          total_chats_count?: number | null
          updated_at?: string
          upi_id?: string | null
          user_id: string
        }
        Update: {
          account_status?: string
          age?: number | null
          ai_approved?: boolean | null
          ai_disapproval_reason?: string | null
          approval_status?: string
          auto_approved?: boolean | null
          avg_response_time_seconds?: number | null
          bank_account_number?: string | null
          bank_name?: string | null
          bio?: string | null
          body_type?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          earning_badge_type?: string | null
          earning_slot_assigned_at?: string | null
          education_level?: string | null
          employee_id?: string
          full_name?: string | null
          height_cm?: number | null
          id?: string
          ifsc_code?: string | null
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          last_rotation_date?: string | null
          life_goals?: string[] | null
          marital_status?: string | null
          monthly_chat_minutes?: number | null
          occupation?: string | null
          pan_number?: string | null
          performance_score?: number | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          promoted_from_free?: boolean | null
          religion?: string | null
          state?: string | null
          suspended_at?: string | null
          suspension_reason?: string | null
          total_chats_count?: number | null
          updated_at?: string
          upi_id?: string | null
          user_id?: string
        }
        Relationships: []
      }
      free_chat_usage: {
        Row: {
          created_at: string
          id: string
          is_blocked: boolean
          man_user_id: string
          total_seconds_used: number
          updated_at: string
          woman_user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_blocked?: boolean
          man_user_id: string
          total_seconds_used?: number
          updated_at?: string
          woman_user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_blocked?: boolean
          man_user_id?: string
          total_seconds_used?: number
          updated_at?: string
          woman_user_id?: string
        }
        Relationships: []
      }
      gift_transactions: {
        Row: {
          created_at: string
          currency: string
          gift_id: string
          id: string
          message: string | null
          price_paid: number
          receiver_id: string
          sender_id: string
          status: string
        }
        Insert: {
          created_at?: string
          currency?: string
          gift_id: string
          id?: string
          message?: string | null
          price_paid: number
          receiver_id: string
          sender_id: string
          status?: string
        }
        Update: {
          created_at?: string
          currency?: string
          gift_id?: string
          id?: string
          message?: string | null
          price_paid?: number
          receiver_id?: string
          sender_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "gift_transactions_gift_id_fkey"
            columns: ["gift_id"]
            isOneToOne: false
            referencedRelation: "gifts"
            referencedColumns: ["id"]
          },
        ]
      }
      gifts: {
        Row: {
          category: string
          created_at: string
          currency: string
          description: string | null
          emoji: string
          id: string
          is_active: boolean
          name: string
          price: number
          sort_order: number
          updated_at: string
        }
        Insert: {
          category?: string
          created_at?: string
          currency?: string
          description?: string | null
          emoji?: string
          id?: string
          is_active?: boolean
          name: string
          price?: number
          sort_order?: number
          updated_at?: string
        }
        Update: {
          category?: string
          created_at?: string
          currency?: string
          description?: string | null
          emoji?: string
          id?: string
          is_active?: boolean
          name?: string
          price?: number
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      group_active_hosts: {
        Row: {
          group_id: string
          host_id: string
          host_language: string | null
          host_name: string
          host_photo: string | null
          id: string
          is_active: boolean
          last_heartbeat_at: string
          participant_count: number
          started_at: string
          stream_id: string | null
        }
        Insert: {
          group_id: string
          host_id: string
          host_language?: string | null
          host_name: string
          host_photo?: string | null
          id?: string
          is_active?: boolean
          last_heartbeat_at?: string
          participant_count?: number
          started_at?: string
          stream_id?: string | null
        }
        Update: {
          group_id?: string
          host_id?: string
          host_language?: string | null
          host_name?: string
          host_photo?: string | null
          id?: string
          is_active?: boolean
          last_heartbeat_at?: string
          participant_count?: number
          started_at?: string
          stream_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_active_hosts_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chat_messages: {
        Row: {
          body: string | null
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          english_translation: string | null
          id: string
          media_thumbnail: string | null
          media_type: string | null
          media_url: string | null
          original_lang: string | null
          pinned: boolean
          reply_to: string | null
          room_id: string
          sender_gender: string | null
          sender_id: string
          sender_name: string | null
          session_id: string
          translated_cache: Json
          transliteration: string | null
          voice_duration_seconds: number | null
        }
        Insert: {
          body?: string | null
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          english_translation?: string | null
          id?: string
          media_thumbnail?: string | null
          media_type?: string | null
          media_url?: string | null
          original_lang?: string | null
          pinned?: boolean
          reply_to?: string | null
          room_id: string
          sender_gender?: string | null
          sender_id: string
          sender_name?: string | null
          session_id: string
          translated_cache?: Json
          transliteration?: string | null
          voice_duration_seconds?: number | null
        }
        Update: {
          body?: string | null
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          english_translation?: string | null
          id?: string
          media_thumbnail?: string | null
          media_type?: string | null
          media_url?: string | null
          original_lang?: string | null
          pinned?: boolean
          reply_to?: string | null
          room_id?: string
          sender_gender?: string | null
          sender_id?: string
          sender_name?: string | null
          session_id?: string
          translated_cache?: Json
          transliteration?: string | null
          voice_duration_seconds?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "group_chat_messages_reply_to_fkey"
            columns: ["reply_to"]
            isOneToOne: false
            referencedRelation: "group_chat_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_chat_messages_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "group_chat_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_chat_messages_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "group_chat_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chat_moderation: {
        Row: {
          action: string
          by_host_id: string
          created_at: string
          id: string
          reason: string | null
          session_id: string
          target_user_id: string
          until: string | null
        }
        Insert: {
          action: string
          by_host_id: string
          created_at?: string
          id?: string
          reason?: string | null
          session_id: string
          target_user_id: string
          until?: string | null
        }
        Update: {
          action?: string
          by_host_id?: string
          created_at?: string
          id?: string
          reason?: string | null
          session_id?: string
          target_user_id?: string
          until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_chat_moderation_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "group_chat_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chat_participants: {
        Row: {
          id: string
          joined_at: string
          last_billed_minute: number
          left_at: string | null
          session_id: string
          total_billed: number
          total_seconds: number
          user_id: string
        }
        Insert: {
          id?: string
          joined_at?: string
          last_billed_minute?: number
          left_at?: string | null
          session_id: string
          total_billed?: number
          total_seconds?: number
          user_id: string
        }
        Update: {
          id?: string
          joined_at?: string
          last_billed_minute?: number
          left_at?: string | null
          session_id?: string
          total_billed?: number
          total_seconds?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_chat_participants_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "group_chat_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chat_rooms: {
        Row: {
          created_at: string
          current_host_id: string | null
          current_participant_count: number
          current_session_id: string | null
          id: string
          max_users: number
          name: string
          status: string
          tree_type: string
          updated_at: string
          variant_number: number
        }
        Insert: {
          created_at?: string
          current_host_id?: string | null
          current_participant_count?: number
          current_session_id?: string | null
          id?: string
          max_users?: number
          name: string
          status?: string
          tree_type: string
          updated_at?: string
          variant_number: number
        }
        Update: {
          created_at?: string
          current_host_id?: string | null
          current_participant_count?: number
          current_session_id?: string | null
          id?: string
          max_users?: number
          name?: string
          status?: string
          tree_type?: string
          updated_at?: string
          variant_number?: number
        }
        Relationships: []
      }
      group_chat_sessions: {
        Row: {
          created_at: string
          ended_at: string | null
          host_id: string
          id: string
          room_id: string
          started_at: string
          total_host_earning: number
          total_men_minutes: number
          total_platform_revenue: number
        }
        Insert: {
          created_at?: string
          ended_at?: string | null
          host_id: string
          id?: string
          room_id: string
          started_at?: string
          total_host_earning?: number
          total_men_minutes?: number
          total_platform_revenue?: number
        }
        Update: {
          created_at?: string
          ended_at?: string | null
          host_id?: string
          id?: string
          room_id?: string
          started_at?: string
          total_host_earning?: number
          total_men_minutes?: number
          total_platform_revenue?: number
        }
        Relationships: [
          {
            foreignKeyName: "group_chat_sessions_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "group_chat_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      group_memberships: {
        Row: {
          created_at: string
          gift_amount_paid: number
          group_id: string
          has_access: boolean
          id: string
          joined_at: string
          joined_host_id: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          gift_amount_paid?: number
          group_id: string
          has_access?: boolean
          id?: string
          joined_at?: string
          joined_host_id?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          gift_amount_paid?: number
          group_id?: string
          has_access?: boolean
          id?: string
          joined_at?: string
          joined_host_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_memberships_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_messages: {
        Row: {
          created_at: string
          file_name: string | null
          file_size: number | null
          file_type: string | null
          file_url: string | null
          group_id: string
          id: string
          is_translated: boolean | null
          message: string
          sender_id: string
          translated_message: string | null
        }
        Insert: {
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          file_type?: string | null
          file_url?: string | null
          group_id: string
          id?: string
          is_translated?: boolean | null
          message: string
          sender_id: string
          translated_message?: string | null
        }
        Update: {
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          file_type?: string | null
          file_url?: string | null
          group_id?: string
          id?: string
          is_translated?: boolean | null
          message?: string
          sender_id?: string
          translated_message?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_messages_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_session_extensions: {
        Row: {
          created_at: string
          extension_month: number
          extension_year: number
          group_id: string
          id: string
          reason: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          extension_month: number
          extension_year: number
          group_id: string
          id?: string
          reason?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          extension_month?: number
          extension_year?: number
          group_id?: string
          id?: string
          reason?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_session_extensions_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_video_access: {
        Row: {
          access_expires_at: string
          access_granted_at: string
          created_at: string
          gift_amount: number
          gift_id: string | null
          group_id: string
          id: string
          is_active: boolean
          user_id: string
        }
        Insert: {
          access_expires_at?: string
          access_granted_at?: string
          created_at?: string
          gift_amount?: number
          gift_id?: string | null
          group_id: string
          id?: string
          is_active?: boolean
          user_id: string
        }
        Update: {
          access_expires_at?: string
          access_granted_at?: string
          created_at?: string
          gift_amount?: number
          gift_id?: string | null
          group_id?: string
          id?: string
          is_active?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_video_access_gift_id_fkey"
            columns: ["gift_id"]
            isOneToOne: false
            referencedRelation: "gifts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_video_access_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "private_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      language_community_messages: {
        Row: {
          created_at: string
          file_name: string | null
          file_size: number | null
          file_type: string | null
          file_url: string | null
          id: string
          language_code: string
          message: string | null
          sender_id: string
        }
        Insert: {
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          file_type?: string | null
          file_url?: string | null
          id?: string
          language_code: string
          message?: string | null
          sender_id: string
        }
        Update: {
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          file_type?: string | null
          file_url?: string | null
          id?: string
          language_code?: string
          message?: string | null
          sender_id?: string
        }
        Relationships: []
      }
      language_groups: {
        Row: {
          created_at: string
          current_women_count: number
          description: string | null
          id: string
          is_active: boolean
          languages: string[]
          max_women_users: number
          name: string
          priority: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          current_women_count?: number
          description?: string | null
          id?: string
          is_active?: boolean
          languages?: string[]
          max_women_users?: number
          name: string
          priority?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          current_women_count?: number
          description?: string | null
          id?: string
          is_active?: boolean
          languages?: string[]
          max_women_users?: number
          name?: string
          priority?: number
          updated_at?: string
        }
        Relationships: []
      }
      language_limits: {
        Row: {
          created_at: string
          current_call_women: number
          current_chat_women: number
          current_earning_women: number | null
          id: string
          is_active: boolean
          language_name: string
          max_call_women: number
          max_chat_women: number
          max_earning_women: number | null
          max_monthly_promotions: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          current_call_women?: number
          current_chat_women?: number
          current_earning_women?: number | null
          id?: string
          is_active?: boolean
          language_name: string
          max_call_women?: number
          max_chat_women?: number
          max_earning_women?: number | null
          max_monthly_promotions?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          current_call_women?: number
          current_chat_women?: number
          current_earning_women?: number | null
          id?: string
          is_active?: boolean
          language_name?: string
          max_call_women?: number
          max_chat_women?: number
          max_earning_women?: number | null
          max_monthly_promotions?: number | null
          updated_at?: string
        }
        Relationships: []
      }
      legal_documents: {
        Row: {
          created_at: string
          description: string | null
          document_type: string
          effective_date: string | null
          file_path: string
          file_size: number | null
          id: string
          is_active: boolean
          mime_type: string | null
          name: string
          updated_at: string
          uploaded_by: string | null
          version: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          document_type?: string
          effective_date?: string | null
          file_path: string
          file_size?: number | null
          id?: string
          is_active?: boolean
          mime_type?: string | null
          name: string
          updated_at?: string
          uploaded_by?: string | null
          version?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          document_type?: string
          effective_date?: string | null
          file_path?: string
          file_size?: number | null
          id?: string
          is_active?: boolean
          mime_type?: string | null
          name?: string
          updated_at?: string
          uploaded_by?: string | null
          version?: string
        }
        Relationships: []
      }
      login_sessions: {
        Row: {
          client_info: Json | null
          created_at: string
          duration_seconds: number | null
          ended_at: string | null
          id: string
          started_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          client_info?: Json | null
          created_at?: string
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          started_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          client_info?: Json | null
          created_at?: string
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          started_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      male_profiles: {
        Row: {
          account_status: string
          age: number | null
          bio: string | null
          body_type: string | null
          country: string | null
          created_at: string
          date_of_birth: string | null
          education_level: string | null
          full_name: string | null
          height_cm: number | null
          id: string
          interests: string[] | null
          is_premium: boolean | null
          is_verified: boolean | null
          last_active_at: string | null
          life_goals: string[] | null
          marital_status: string | null
          occupation: string | null
          phone: string | null
          photo_url: string | null
          preferred_language: string | null
          primary_language: string | null
          profile_completeness: number | null
          religion: string | null
          state: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          account_status?: string
          age?: number | null
          bio?: string | null
          body_type?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          education_level?: string | null
          full_name?: string | null
          height_cm?: number | null
          id?: string
          interests?: string[] | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          life_goals?: string[] | null
          marital_status?: string | null
          occupation?: string | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          religion?: string | null
          state?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          account_status?: string
          age?: number | null
          bio?: string | null
          body_type?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          education_level?: string | null
          full_name?: string | null
          height_cm?: number | null
          id?: string
          interests?: string[] | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          life_goals?: string[] | null
          marital_status?: string | null
          occupation?: string | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          religion?: string | null
          state?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      matches: {
        Row: {
          created_at: string
          id: string
          match_score: number | null
          matched_at: string
          matched_user_id: string
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          match_score?: number | null
          matched_at?: string
          matched_user_id: string
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          match_score?: number | null
          matched_at?: string
          matched_user_id?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      message_reactions: {
        Row: {
          created_at: string
          emoji: string
          id: string
          message_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          emoji: string
          id?: string
          message_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          emoji?: string
          id?: string
          message_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_reactions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      moderation_reports: {
        Row: {
          action_reason: string | null
          action_taken: string | null
          chat_message_id: string | null
          content: string | null
          created_at: string
          id: string
          report_type: string
          reported_user_id: string
          reporter_id: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          updated_at: string
        }
        Insert: {
          action_reason?: string | null
          action_taken?: string | null
          chat_message_id?: string | null
          content?: string | null
          created_at?: string
          id?: string
          report_type?: string
          reported_user_id: string
          reporter_id: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          action_reason?: string | null
          action_taken?: string | null
          chat_message_id?: string | null
          content?: string | null
          created_at?: string
          id?: string
          report_type?: string
          reported_user_id?: string
          reporter_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "moderation_reports_chat_message_id_fkey"
            columns: ["chat_message_id"]
            isOneToOne: false
            referencedRelation: "chat_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_statements: {
        Row: {
          audio_call_amount: number
          chat_amount: number
          closing_balance: number
          excel_url: string | null
          gender: string
          generated_at: string
          gift_amount: number
          group_call_amount: number
          id: string
          month: number
          notes: string | null
          opening_balance: number
          paid_at: string | null
          payout_amount: number
          payout_status: string
          pdf_url: string | null
          recharge_amount: number
          tip_amount: number
          total_credit: number
          total_debit: number
          user_id: string
          video_call_amount: number
          year: number
        }
        Insert: {
          audio_call_amount?: number
          chat_amount?: number
          closing_balance?: number
          excel_url?: string | null
          gender: string
          generated_at?: string
          gift_amount?: number
          group_call_amount?: number
          id?: string
          month: number
          notes?: string | null
          opening_balance?: number
          paid_at?: string | null
          payout_amount?: number
          payout_status?: string
          pdf_url?: string | null
          recharge_amount?: number
          tip_amount?: number
          total_credit?: number
          total_debit?: number
          user_id: string
          video_call_amount?: number
          year: number
        }
        Update: {
          audio_call_amount?: number
          chat_amount?: number
          closing_balance?: number
          excel_url?: string | null
          gender?: string
          generated_at?: string
          gift_amount?: number
          group_call_amount?: number
          id?: string
          month?: number
          notes?: string | null
          opening_balance?: number
          paid_at?: string | null
          payout_amount?: number
          payout_status?: string
          pdf_url?: string | null
          recharge_amount?: number
          tip_amount?: number
          total_credit?: number
          total_debit?: number
          user_id?: string
          video_call_amount?: number
          year?: number
        }
        Relationships: []
      }
      monthly_wallet_summary: {
        Row: {
          closing_balance: number
          created_at: string
          forwarded_balance: number
          id: string
          month: number
          opening_balance: number
          total_credit: number
          total_debit: number
          user_id: string
          withdrawals: number
          year: number
        }
        Insert: {
          closing_balance?: number
          created_at?: string
          forwarded_balance?: number
          id?: string
          month: number
          opening_balance?: number
          total_credit?: number
          total_debit?: number
          user_id: string
          withdrawals?: number
          year: number
        }
        Update: {
          closing_balance?: number
          created_at?: string
          forwarded_balance?: number
          id?: string
          month?: number
          opening_balance?: number
          total_credit?: number
          total_debit?: number
          user_id?: string
          withdrawals?: number
          year?: number
        }
        Relationships: []
      }
      notifications: {
        Row: {
          action_url: string | null
          created_at: string
          id: string
          is_read: boolean
          message: string
          title: string
          type: string
          user_id: string
        }
        Insert: {
          action_url?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message: string
          title: string
          type?: string
          user_id: string
        }
        Update: {
          action_url?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message?: string
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      password_reset_tokens: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          token: string
          used: boolean
          user_id: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          token: string
          used?: boolean
          user_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          token?: string
          used?: boolean
          user_id?: string
        }
        Relationships: []
      }
      pending_recharges: {
        Row: {
          amount: number
          created_at: string | null
          gateway: string
          gateway_txn_id: string | null
          id: string
          status: string
          txn_id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string | null
          gateway?: string
          gateway_txn_id?: string | null
          id?: string
          status?: string
          txn_id: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string | null
          gateway?: string
          gateway_txn_id?: string | null
          id?: string
          status?: string
          txn_id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      platform_metrics: {
        Row: {
          active_chats: number
          active_users: number
          admin_profit: number
          completed_withdrawals: number
          created_at: string
          female_users: number
          gift_revenue: number
          id: string
          male_users: number
          men_recharges: number
          men_spent: number
          metric_date: string
          new_users: number
          pending_withdrawals: number
          total_chats: number
          total_matches: number
          total_messages: number
          total_users: number
          total_video_calls: number
          updated_at: string
          video_call_minutes: number
          video_call_revenue: number
          women_earnings: number
        }
        Insert: {
          active_chats?: number
          active_users?: number
          admin_profit?: number
          completed_withdrawals?: number
          created_at?: string
          female_users?: number
          gift_revenue?: number
          id?: string
          male_users?: number
          men_recharges?: number
          men_spent?: number
          metric_date?: string
          new_users?: number
          pending_withdrawals?: number
          total_chats?: number
          total_matches?: number
          total_messages?: number
          total_users?: number
          total_video_calls?: number
          updated_at?: string
          video_call_minutes?: number
          video_call_revenue?: number
          women_earnings?: number
        }
        Update: {
          active_chats?: number
          active_users?: number
          admin_profit?: number
          completed_withdrawals?: number
          created_at?: string
          female_users?: number
          gift_revenue?: number
          id?: string
          male_users?: number
          men_recharges?: number
          men_spent?: number
          metric_date?: string
          new_users?: number
          pending_withdrawals?: number
          total_chats?: number
          total_matches?: number
          total_messages?: number
          total_users?: number
          total_video_calls?: number
          updated_at?: string
          video_call_minutes?: number
          video_call_revenue?: number
          women_earnings?: number
        }
        Relationships: []
      }
      policy_violation_alerts: {
        Row: {
          action_taken: string | null
          admin_notes: string | null
          alert_type: string
          content: string | null
          created_at: string
          detected_by: string
          id: string
          reviewed_at: string | null
          reviewed_by: string | null
          severity: string
          source_chat_id: string | null
          source_message_id: string | null
          status: string
          updated_at: string
          user_id: string
          violation_type: string
        }
        Insert: {
          action_taken?: string | null
          admin_notes?: string | null
          alert_type?: string
          content?: string | null
          created_at?: string
          detected_by?: string
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          severity?: string
          source_chat_id?: string | null
          source_message_id?: string | null
          status?: string
          updated_at?: string
          user_id: string
          violation_type: string
        }
        Update: {
          action_taken?: string | null
          admin_notes?: string | null
          alert_type?: string
          content?: string | null
          created_at?: string
          detected_by?: string
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          severity?: string
          source_chat_id?: string | null
          source_message_id?: string | null
          status?: string
          updated_at?: string
          user_id?: string
          violation_type?: string
        }
        Relationships: []
      }
      private_groups: {
        Row: {
          access_type: string
          created_at: string
          current_host_id: string | null
          current_host_name: string | null
          current_host_number: number | null
          description: string | null
          id: string
          is_active: boolean
          is_live: boolean
          min_gift_amount: number
          name: string
          owner_id: string
          owner_language: string | null
          participant_count: number
          stream_id: string | null
          updated_at: string
        }
        Insert: {
          access_type?: string
          created_at?: string
          current_host_id?: string | null
          current_host_name?: string | null
          current_host_number?: number | null
          description?: string | null
          id?: string
          is_active?: boolean
          is_live?: boolean
          min_gift_amount?: number
          name: string
          owner_id: string
          owner_language?: string | null
          participant_count?: number
          stream_id?: string | null
          updated_at?: string
        }
        Update: {
          access_type?: string
          created_at?: string
          current_host_id?: string | null
          current_host_name?: string | null
          current_host_number?: number | null
          description?: string | null
          id?: string
          is_active?: boolean
          is_live?: boolean
          min_gift_amount?: number
          name?: string
          owner_id?: string
          owner_language?: string | null
          participant_count?: number
          stream_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      processing_logs: {
        Row: {
          age_verified: boolean | null
          completed_at: string | null
          created_at: string
          current_step: string | null
          errors: string[] | null
          gender_verified: boolean | null
          id: string
          language_detected: boolean | null
          photo_verified: boolean | null
          processing_status: string
          progress_percent: number | null
          started_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          age_verified?: boolean | null
          completed_at?: string | null
          created_at?: string
          current_step?: string | null
          errors?: string[] | null
          gender_verified?: boolean | null
          id?: string
          language_detected?: boolean | null
          photo_verified?: boolean | null
          processing_status?: string
          progress_percent?: number | null
          started_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          age_verified?: boolean | null
          completed_at?: string | null
          created_at?: string
          current_step?: string | null
          errors?: string[] | null
          gender_verified?: boolean | null
          id?: string
          language_detected?: boolean | null
          photo_verified?: boolean | null
          processing_status?: string
          progress_percent?: number | null
          started_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          account_status: string
          age: number | null
          ai_approved: boolean | null
          ai_disapproval_reason: string | null
          app_id: string | null
          app_sno: number | null
          approval_status: string
          avg_response_time_seconds: number | null
          bio: string | null
          body_type: string | null
          city: string | null
          country: string | null
          created_at: string
          date_of_birth: string | null
          dietary_preference: string | null
          drinking_habit: string | null
          earning_badge_type: string | null
          earning_slot_assigned_at: string | null
          education_level: string | null
          email: string | null
          fitness_level: string | null
          full_name: string | null
          gender: string | null
          global_app_id: number
          has_children: boolean | null
          height_cm: number | null
          host_number: number | null
          id: string
          interests: string[] | null
          is_earning_eligible: boolean | null
          is_indian: boolean | null
          is_language_leader: boolean
          is_premium: boolean | null
          is_verified: boolean | null
          language: string | null
          last_active_at: string | null
          last_rotation_date: string | null
          latitude: number | null
          life_goals: string[] | null
          longitude: number | null
          marital_status: string | null
          monthly_chat_minutes: number | null
          occupation: string | null
          performance_score: number | null
          personality_type: string | null
          pet_preference: string | null
          phone: string | null
          photo_url: string | null
          preferred_language: string | null
          primary_language: string | null
          profile_completeness: number | null
          promoted_from_free: boolean | null
          religion: string | null
          smoking_habit: string | null
          state: string | null
          total_chats_count: number | null
          travel_frequency: string | null
          updated_at: string
          user_code: string | null
          user_id: string
          verification_status: boolean | null
          zodiac_sign: string | null
        }
        Insert: {
          account_status?: string
          age?: number | null
          ai_approved?: boolean | null
          ai_disapproval_reason?: string | null
          app_id?: string | null
          app_sno?: number | null
          approval_status?: string
          avg_response_time_seconds?: number | null
          bio?: string | null
          body_type?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          dietary_preference?: string | null
          drinking_habit?: string | null
          earning_badge_type?: string | null
          earning_slot_assigned_at?: string | null
          education_level?: string | null
          email?: string | null
          fitness_level?: string | null
          full_name?: string | null
          gender?: string | null
          global_app_id?: number
          has_children?: boolean | null
          height_cm?: number | null
          host_number?: number | null
          id?: string
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_language_leader?: boolean
          is_premium?: boolean | null
          is_verified?: boolean | null
          language?: string | null
          last_active_at?: string | null
          last_rotation_date?: string | null
          latitude?: number | null
          life_goals?: string[] | null
          longitude?: number | null
          marital_status?: string | null
          monthly_chat_minutes?: number | null
          occupation?: string | null
          performance_score?: number | null
          personality_type?: string | null
          pet_preference?: string | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          promoted_from_free?: boolean | null
          religion?: string | null
          smoking_habit?: string | null
          state?: string | null
          total_chats_count?: number | null
          travel_frequency?: string | null
          updated_at?: string
          user_code?: string | null
          user_id: string
          verification_status?: boolean | null
          zodiac_sign?: string | null
        }
        Update: {
          account_status?: string
          age?: number | null
          ai_approved?: boolean | null
          ai_disapproval_reason?: string | null
          app_id?: string | null
          app_sno?: number | null
          approval_status?: string
          avg_response_time_seconds?: number | null
          bio?: string | null
          body_type?: string | null
          city?: string | null
          country?: string | null
          created_at?: string
          date_of_birth?: string | null
          dietary_preference?: string | null
          drinking_habit?: string | null
          earning_badge_type?: string | null
          earning_slot_assigned_at?: string | null
          education_level?: string | null
          email?: string | null
          fitness_level?: string | null
          full_name?: string | null
          gender?: string | null
          global_app_id?: number
          has_children?: boolean | null
          height_cm?: number | null
          host_number?: number | null
          id?: string
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_language_leader?: boolean
          is_premium?: boolean | null
          is_verified?: boolean | null
          language?: string | null
          last_active_at?: string | null
          last_rotation_date?: string | null
          latitude?: number | null
          life_goals?: string[] | null
          longitude?: number | null
          marital_status?: string | null
          monthly_chat_minutes?: number | null
          occupation?: string | null
          performance_score?: number | null
          personality_type?: string | null
          pet_preference?: string | null
          phone?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          profile_completeness?: number | null
          promoted_from_free?: boolean | null
          religion?: string | null
          smoking_habit?: string | null
          state?: string | null
          total_chats_count?: number | null
          travel_frequency?: string | null
          updated_at?: string
          user_code?: string | null
          user_id?: string
          verification_status?: boolean | null
          zodiac_sign?: string | null
        }
        Relationships: []
      }
      push_subscriptions: {
        Row: {
          auth: string
          created_at: string
          endpoint: string
          id: string
          p256dh: string
          updated_at: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          auth: string
          created_at?: string
          endpoint: string
          id?: string
          p256dh: string
          updated_at?: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          auth?: string
          created_at?: string
          endpoint?: string
          id?: string
          p256dh?: string
          updated_at?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      rate_limit_tracking: {
        Row: {
          function_name: string
          id: string
          request_at: string
          user_id: string
        }
        Insert: {
          function_name: string
          id?: string
          request_at?: string
          user_id: string
        }
        Update: {
          function_name?: string
          id?: string
          request_at?: string
          user_id?: string
        }
        Relationships: []
      }
      screen_capture_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          platform: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          event_type: string
          id?: string
          platform: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          platform?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      scrolling_announcements: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          message: string
          target_group: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          message: string
          target_group?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          message?: string
          target_group?: string
          updated_at?: string
        }
        Relationships: []
      }
      system_alerts: {
        Row: {
          alert_type: string
          created_at: string
          current_value: number
          id: string
          is_resolved: boolean
          message: string
          metric_name: string
          resolved_at: string | null
          threshold_value: number
        }
        Insert: {
          alert_type?: string
          created_at?: string
          current_value: number
          id?: string
          is_resolved?: boolean
          message: string
          metric_name: string
          resolved_at?: string | null
          threshold_value: number
        }
        Update: {
          alert_type?: string
          created_at?: string
          current_value?: number
          id?: string
          is_resolved?: boolean
          message?: string
          metric_name?: string
          resolved_at?: string | null
          threshold_value?: number
        }
        Relationships: []
      }
      system_metrics: {
        Row: {
          active_connections: number
          cpu_usage: number
          created_at: string
          disk_usage: number | null
          error_rate: number | null
          id: string
          memory_usage: number
          network_in: number | null
          network_out: number | null
          recorded_at: string
          response_time: number
        }
        Insert: {
          active_connections?: number
          cpu_usage?: number
          created_at?: string
          disk_usage?: number | null
          error_rate?: number | null
          id?: string
          memory_usage?: number
          network_in?: number | null
          network_out?: number | null
          recorded_at?: string
          response_time?: number
        }
        Update: {
          active_connections?: number
          cpu_usage?: number
          created_at?: string
          disk_usage?: number | null
          error_rate?: number | null
          id?: string
          memory_usage?: number
          network_in?: number | null
          network_out?: number | null
          recorded_at?: string
          response_time?: number
        }
        Relationships: []
      }
      translation_cache: {
        Row: {
          created_at: string
          hit_count: number
          id: string
          source_lang: string
          source_text: string
          target_lang: string
          translated_text: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          hit_count?: number
          id?: string
          source_lang: string
          source_text: string
          target_lang: string
          translated_text: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          hit_count?: number
          id?: string
          source_lang?: string
          source_text?: string
          target_lang?: string
          translated_text?: string
          updated_at?: string
        }
        Relationships: []
      }
      tutorial_progress: {
        Row: {
          completed: boolean
          completed_at: string | null
          created_at: string
          current_step: number
          id: string
          skipped: boolean | null
          steps_viewed: number[] | null
          theme_preference: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          completed?: boolean
          completed_at?: string | null
          created_at?: string
          current_step?: number
          id?: string
          skipped?: boolean | null
          steps_viewed?: number[] | null
          theme_preference?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          completed?: boolean
          completed_at?: string | null
          created_at?: string
          current_step?: number
          id?: string
          skipped?: boolean | null
          steps_viewed?: number[] | null
          theme_preference?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_blocks: {
        Row: {
          block_type: string
          blocked_by: string
          blocked_user_id: string
          created_at: string
          expires_at: string | null
          id: string
          reason: string | null
        }
        Insert: {
          block_type?: string
          blocked_by: string
          blocked_user_id: string
          created_at?: string
          expires_at?: string | null
          id?: string
          reason?: string | null
        }
        Update: {
          block_type?: string
          blocked_by?: string
          blocked_user_id?: string
          created_at?: string
          expires_at?: string | null
          id?: string
          reason?: string | null
        }
        Relationships: []
      }
      user_consent: {
        Row: {
          agreed_terms: boolean
          ccpa_consent: boolean | null
          consent_timestamp: string
          created_at: string
          dpdp_consent: boolean | null
          gdpr_consent: boolean | null
          id: string
          ip_address: string | null
          terms_version: string
          updated_at: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          agreed_terms?: boolean
          ccpa_consent?: boolean | null
          consent_timestamp?: string
          created_at?: string
          dpdp_consent?: boolean | null
          gdpr_consent?: boolean | null
          id?: string
          ip_address?: string | null
          terms_version?: string
          updated_at?: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          agreed_terms?: boolean
          ccpa_consent?: boolean | null
          consent_timestamp?: string
          created_at?: string
          dpdp_consent?: boolean | null
          gdpr_consent?: boolean | null
          id?: string
          ip_address?: string | null
          terms_version?: string
          updated_at?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_friends: {
        Row: {
          created_at: string
          created_by: string | null
          friend_id: string
          id: string
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          friend_id: string
          id?: string
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          friend_id?: string
          id?: string
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_languages: {
        Row: {
          created_at: string
          id: string
          language_code: string
          language_name: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          language_code: string
          language_name: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          language_code?: string
          language_name?: string
          user_id?: string
        }
        Relationships: []
      }
      user_photos: {
        Row: {
          created_at: string
          display_order: number
          id: string
          is_primary: boolean
          photo_type: string
          photo_url: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          display_order?: number
          id?: string
          is_primary?: boolean
          photo_type?: string
          photo_url: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          display_order?: number
          id?: string
          is_primary?: boolean
          photo_type?: string
          photo_url?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_service_roles: {
        Row: {
          assigned_by: string | null
          created_at: string
          id: string
          role: Database["public"]["Enums"]["service_role"]
          user_id: string
        }
        Insert: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["service_role"]
          user_id: string
        }
        Update: {
          assigned_by?: string | null
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["service_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_settings: {
        Row: {
          accent_color: string
          auto_translate: boolean
          created_at: string
          distance_unit: string
          id: string
          language: string
          notification_matches: boolean
          notification_messages: boolean
          notification_promotions: boolean
          notification_sound: boolean
          notification_vibration: boolean
          profile_visibility: string
          show_online_status: boolean
          show_read_receipts: boolean
          theme: string
          updated_at: string
          user_id: string
        }
        Insert: {
          accent_color?: string
          auto_translate?: boolean
          created_at?: string
          distance_unit?: string
          id?: string
          language?: string
          notification_matches?: boolean
          notification_messages?: boolean
          notification_promotions?: boolean
          notification_sound?: boolean
          notification_vibration?: boolean
          profile_visibility?: string
          show_online_status?: boolean
          show_read_receipts?: boolean
          theme?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          accent_color?: string
          auto_translate?: boolean
          created_at?: string
          distance_unit?: string
          id?: string
          language?: string
          notification_matches?: boolean
          notification_messages?: boolean
          notification_promotions?: boolean
          notification_sound?: boolean
          notification_vibration?: boolean
          profile_visibility?: string
          show_online_status?: boolean
          show_read_receipts?: boolean
          theme?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_status: {
        Row: {
          active_call_count: number | null
          active_chat_count: number | null
          created_at: string
          id: string
          is_online: boolean
          last_seen: string
          max_parallel_calls: number | null
          max_parallel_chats: number | null
          status: string
          status_text: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          active_call_count?: number | null
          active_chat_count?: number | null
          created_at?: string
          id?: string
          is_online?: boolean
          last_seen?: string
          max_parallel_calls?: number | null
          max_parallel_chats?: number | null
          status?: string
          status_text?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          active_call_count?: number | null
          active_chat_count?: number | null
          created_at?: string
          id?: string
          is_online?: boolean
          last_seen?: string
          max_parallel_calls?: number | null
          max_parallel_chats?: number | null
          status?: string
          status_text?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_warnings: {
        Row: {
          acknowledged_at: string | null
          created_at: string
          id: string
          issued_by: string
          message: string
          user_id: string
          warning_type: string
        }
        Insert: {
          acknowledged_at?: string | null
          created_at?: string
          id?: string
          issued_by: string
          message: string
          user_id: string
          warning_type?: string
        }
        Update: {
          acknowledged_at?: string | null
          created_at?: string
          id?: string
          issued_by?: string
          message?: string
          user_id?: string
          warning_type?: string
        }
        Relationships: []
      }
      users_wallet: {
        Row: {
          balance: number
          created_at: string
          currency: string
          gender: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          balance?: number
          created_at?: string
          currency?: string
          gender: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          balance?: number
          created_at?: string
          currency?: string
          gender?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      video_call_sessions: {
        Row: {
          call_id: string
          call_type: string
          created_at: string
          end_reason: string | null
          ended_at: string | null
          id: string
          man_user_id: string
          rate_per_minute: number
          started_at: string | null
          status: string
          total_earned: number
          total_minutes: number
          updated_at: string
          woman_user_id: string
        }
        Insert: {
          call_id: string
          call_type?: string
          created_at?: string
          end_reason?: string | null
          ended_at?: string | null
          id?: string
          man_user_id: string
          rate_per_minute?: number
          started_at?: string | null
          status?: string
          total_earned?: number
          total_minutes?: number
          updated_at?: string
          woman_user_id: string
        }
        Update: {
          call_id?: string
          call_type?: string
          created_at?: string
          end_reason?: string | null
          ended_at?: string | null
          id?: string
          man_user_id?: string
          rate_per_minute?: number
          started_at?: string | null
          status?: string
          total_earned?: number
          total_minutes?: number
          updated_at?: string
          woman_user_id?: string
        }
        Relationships: []
      }
      wallet_recharges: {
        Row: {
          amount: number
          created_at: string
          description: string | null
          gateway_transaction_id: string | null
          id: string
          payment_gateway: string
          status: string
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          description?: string | null
          gateway_transaction_id?: string | null
          id?: string
          payment_gateway?: string
          status?: string
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          description?: string | null
          gateway_transaction_id?: string | null
          id?: string
          payment_gateway?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      wallet_transactions: {
        Row: {
          amount: number
          balance_after: number | null
          billing_metadata: Json
          created_at: string
          description: string | null
          duration_seconds: number | null
          id: string
          idempotency_key: string
          rate_per_minute: number | null
          reference_id: string | null
          session_id: string | null
          session_type: string | null
          status: string
          transaction_type: string | null
          type: string
          user_id: string
          wallet_id: string | null
        }
        Insert: {
          amount: number
          balance_after?: number | null
          billing_metadata?: Json
          created_at?: string
          description?: string | null
          duration_seconds?: number | null
          id?: string
          idempotency_key: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string
          transaction_type?: string | null
          type: string
          user_id: string
          wallet_id?: string | null
        }
        Update: {
          amount?: number
          balance_after?: number | null
          billing_metadata?: Json
          created_at?: string
          description?: string | null
          duration_seconds?: number | null
          id?: string
          idempotency_key?: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string
          transaction_type?: string | null
          type?: string
          user_id?: string
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wallet_transactions_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_transactions_archive: {
        Row: {
          amount: number
          archived_at: string
          balance_after: number | null
          billing_metadata: Json
          created_at: string
          description: string | null
          duration_seconds: number | null
          id: string
          idempotency_key: string
          rate_per_minute: number | null
          reference_id: string | null
          session_id: string | null
          session_type: string | null
          status: string
          transaction_type: string | null
          type: string
          user_id: string
          wallet_id: string | null
        }
        Insert: {
          amount: number
          archived_at?: string
          balance_after?: number | null
          billing_metadata?: Json
          created_at: string
          description?: string | null
          duration_seconds?: number | null
          id: string
          idempotency_key: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string
          transaction_type?: string | null
          type: string
          user_id: string
          wallet_id?: string | null
        }
        Update: {
          amount?: number
          archived_at?: string
          balance_after?: number | null
          billing_metadata?: Json
          created_at?: string
          description?: string | null
          duration_seconds?: number | null
          id?: string
          idempotency_key?: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string
          transaction_type?: string | null
          type?: string
          user_id?: string
          wallet_id?: string | null
        }
        Relationships: []
      }
      wallet_transactions_purged_audit: {
        Row: {
          amount: number | null
          balance_after: number | null
          billing_metadata: Json | null
          created_at: string | null
          description: string | null
          duration_seconds: number | null
          id: string
          idempotency_key: string | null
          purge_reason: string
          purged_at: string
          rate_per_minute: number | null
          reference_id: string | null
          session_id: string | null
          session_type: string | null
          status: string | null
          transaction_type: string | null
          type: string | null
          user_id: string | null
          wallet_id: string | null
        }
        Insert: {
          amount?: number | null
          balance_after?: number | null
          billing_metadata?: Json | null
          created_at?: string | null
          description?: string | null
          duration_seconds?: number | null
          id: string
          idempotency_key?: string | null
          purge_reason: string
          purged_at?: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string | null
          transaction_type?: string | null
          type?: string | null
          user_id?: string | null
          wallet_id?: string | null
        }
        Update: {
          amount?: number | null
          balance_after?: number | null
          billing_metadata?: Json | null
          created_at?: string | null
          description?: string | null
          duration_seconds?: number | null
          id?: string
          idempotency_key?: string | null
          purge_reason?: string
          purged_at?: string
          rate_per_minute?: number | null
          reference_id?: string | null
          session_id?: string | null
          session_type?: string | null
          status?: string | null
          transaction_type?: string | null
          type?: string | null
          user_id?: string | null
          wallet_id?: string | null
        }
        Relationships: []
      }
      wallets: {
        Row: {
          balance: number
          created_at: string
          currency: string
          gender: string | null
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          balance?: number
          created_at?: string
          currency?: string
          gender?: string | null
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          balance?: number
          created_at?: string
          currency?: string
          gender?: string | null
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      withdrawal_requests: {
        Row: {
          amount: number
          bank_account_number: string | null
          bank_name: string | null
          created_at: string
          fee_amount: number | null
          fee_percent: number | null
          id: string
          ifsc_code: string | null
          net_amount: number | null
          payment_details: Json | null
          payment_method: string | null
          processed_at: string | null
          processed_by: string | null
          rejection_reason: string | null
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          amount: number
          bank_account_number?: string | null
          bank_name?: string | null
          created_at?: string
          fee_amount?: number | null
          fee_percent?: number | null
          id?: string
          ifsc_code?: string | null
          net_amount?: number | null
          payment_details?: Json | null
          payment_method?: string | null
          processed_at?: string | null
          processed_by?: string | null
          rejection_reason?: string | null
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          amount?: number
          bank_account_number?: string | null
          bank_name?: string | null
          created_at?: string
          fee_amount?: number | null
          fee_percent?: number | null
          id?: string
          ifsc_code?: string | null
          net_amount?: number | null
          payment_details?: Json | null
          payment_method?: string | null
          processed_at?: string | null
          processed_by?: string | null
          rejection_reason?: string | null
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      women_auto_ping_log: {
        Row: {
          created_at: string
          id: string
          last_sent_at: string
          man_user_id: string
          ping_type: string
          woman_user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          last_sent_at?: string
          man_user_id: string
          ping_type?: string
          woman_user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          last_sent_at?: string
          man_user_id?: string
          ping_type?: string
          woman_user_id?: string
        }
        Relationships: []
      }
      women_availability: {
        Row: {
          created_at: string
          current_call_count: number | null
          current_chat_count: number
          id: string
          is_available: boolean
          is_available_for_calls: boolean | null
          last_assigned_at: string | null
          max_concurrent_calls: number | null
          max_concurrent_chats: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_call_count?: number | null
          current_chat_count?: number
          id?: string
          is_available?: boolean
          is_available_for_calls?: boolean | null
          last_assigned_at?: string | null
          max_concurrent_calls?: number | null
          max_concurrent_chats?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_call_count?: number | null
          current_chat_count?: number
          id?: string
          is_available?: boolean
          is_available_for_calls?: boolean | null
          last_assigned_at?: string | null
          max_concurrent_calls?: number | null
          max_concurrent_chats?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      women_chat_modes: {
        Row: {
          created_at: string
          current_mode: string
          exclusive_free_locked_until: string | null
          force_free_minutes_limit: number
          force_free_minutes_used_today: number
          free_minutes_limit: number
          free_minutes_used_today: number
          id: string
          is_force_free_active: boolean
          last_free_reset_date: string
          mode_switched_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_mode?: string
          exclusive_free_locked_until?: string | null
          force_free_minutes_limit?: number
          force_free_minutes_used_today?: number
          free_minutes_limit?: number
          free_minutes_used_today?: number
          id?: string
          is_force_free_active?: boolean
          last_free_reset_date?: string
          mode_switched_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_mode?: string
          exclusive_free_locked_until?: string | null
          force_free_minutes_limit?: number
          force_free_minutes_used_today?: number
          free_minutes_limit?: number
          free_minutes_used_today?: number
          id?: string
          is_force_free_active?: boolean
          last_free_reset_date?: string
          mode_switched_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      women_kyc: {
        Row: {
          aadhaar_back_url: string | null
          aadhaar_front_url: string | null
          aadhaar_number: string | null
          account_holder_name: string
          account_number: string
          account_type: string | null
          address_proof_type: string | null
          address_proof_url: string | null
          annual_income_range: string | null
          app_sno: number | null
          bank_branch_name: string | null
          bank_name: string
          beneficiary_purpose: string
          city: string | null
          consent_given: boolean
          consent_timestamp: string | null
          country_of_residence: string
          created_at: string
          current_address: string | null
          date_of_birth: string
          declaration_place: string | null
          document_back_url: string | null
          document_front_url: string | null
          email_address: string | null
          fathers_name: string | null
          full_name_as_per_bank: string
          gender: string | null
          id: string
          id_number: string
          id_proof_back_url: string | null
          id_proof_front_url: string | null
          id_type: string
          ifsc_code: string
          marital_status: string | null
          mobile_number: string | null
          mothers_name: string | null
          nationality: string | null
          nominee_address: string | null
          nominee_dob: string | null
          nominee_name: string | null
          nominee_relationship: string | null
          occupation: string | null
          permanent_address: string | null
          pin_code: string | null
          rejection_reason: string | null
          selfie_url: string | null
          state: string | null
          updated_at: string
          upi_vpa: string | null
          user_id: string
          verification_status: string
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          aadhaar_back_url?: string | null
          aadhaar_front_url?: string | null
          aadhaar_number?: string | null
          account_holder_name: string
          account_number: string
          account_type?: string | null
          address_proof_type?: string | null
          address_proof_url?: string | null
          annual_income_range?: string | null
          app_sno?: number | null
          bank_branch_name?: string | null
          bank_name: string
          beneficiary_purpose?: string
          city?: string | null
          consent_given?: boolean
          consent_timestamp?: string | null
          country_of_residence?: string
          created_at?: string
          current_address?: string | null
          date_of_birth: string
          declaration_place?: string | null
          document_back_url?: string | null
          document_front_url?: string | null
          email_address?: string | null
          fathers_name?: string | null
          full_name_as_per_bank: string
          gender?: string | null
          id?: string
          id_number: string
          id_proof_back_url?: string | null
          id_proof_front_url?: string | null
          id_type: string
          ifsc_code: string
          marital_status?: string | null
          mobile_number?: string | null
          mothers_name?: string | null
          nationality?: string | null
          nominee_address?: string | null
          nominee_dob?: string | null
          nominee_name?: string | null
          nominee_relationship?: string | null
          occupation?: string | null
          permanent_address?: string | null
          pin_code?: string | null
          rejection_reason?: string | null
          selfie_url?: string | null
          state?: string | null
          updated_at?: string
          upi_vpa?: string | null
          user_id: string
          verification_status?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          aadhaar_back_url?: string | null
          aadhaar_front_url?: string | null
          aadhaar_number?: string | null
          account_holder_name?: string
          account_number?: string
          account_type?: string | null
          address_proof_type?: string | null
          address_proof_url?: string | null
          annual_income_range?: string | null
          app_sno?: number | null
          bank_branch_name?: string | null
          bank_name?: string
          beneficiary_purpose?: string
          city?: string | null
          consent_given?: boolean
          consent_timestamp?: string | null
          country_of_residence?: string
          created_at?: string
          current_address?: string | null
          date_of_birth?: string
          declaration_place?: string | null
          document_back_url?: string | null
          document_front_url?: string | null
          email_address?: string | null
          fathers_name?: string | null
          full_name_as_per_bank?: string
          gender?: string | null
          id?: string
          id_number?: string
          id_proof_back_url?: string | null
          id_proof_front_url?: string | null
          id_type?: string
          ifsc_code?: string
          marital_status?: string | null
          mobile_number?: string | null
          mothers_name?: string | null
          nationality?: string | null
          nominee_address?: string | null
          nominee_dob?: string | null
          nominee_name?: string | null
          nominee_relationship?: string | null
          occupation?: string | null
          permanent_address?: string | null
          pin_code?: string | null
          rejection_reason?: string | null
          selfie_url?: string | null
          state?: string | null
          updated_at?: string
          upi_vpa?: string | null
          user_id?: string
          verification_status?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: []
      }
      women_payout_snapshots: {
        Row: {
          account_holder_name: string | null
          address: string | null
          already_paid: number
          app_sno: number | null
          bank_account_number: string | null
          bank_name: string | null
          bank_reference: string | null
          beneficiary_purpose: string | null
          created_at: string
          email_address: string | null
          full_name: string
          gross_earned: number
          id: string
          ifsc_code: string | null
          incremental_payable: number
          ist_month: string
          ist_year: number
          mobile_number: string | null
          net_payable: number
          payment_status: string
          processed_at: string | null
          processed_by: string | null
          skipped_reason: string | null
          snapshot_ist_date: string
          snapshot_ist_datetime: string
          snapshot_type: string
          upi_vpa: string | null
          user_id: string
          wallet_balance_at_snapshot: number
          withdrawal_fee_amount: number
        }
        Insert: {
          account_holder_name?: string | null
          address?: string | null
          already_paid?: number
          app_sno?: number | null
          bank_account_number?: string | null
          bank_name?: string | null
          bank_reference?: string | null
          beneficiary_purpose?: string | null
          created_at?: string
          email_address?: string | null
          full_name: string
          gross_earned?: number
          id?: string
          ifsc_code?: string | null
          incremental_payable?: number
          ist_month: string
          ist_year: number
          mobile_number?: string | null
          net_payable?: number
          payment_status?: string
          processed_at?: string | null
          processed_by?: string | null
          skipped_reason?: string | null
          snapshot_ist_date: string
          snapshot_ist_datetime: string
          snapshot_type: string
          upi_vpa?: string | null
          user_id: string
          wallet_balance_at_snapshot?: number
          withdrawal_fee_amount?: number
        }
        Update: {
          account_holder_name?: string | null
          address?: string | null
          already_paid?: number
          app_sno?: number | null
          bank_account_number?: string | null
          bank_name?: string | null
          bank_reference?: string | null
          beneficiary_purpose?: string | null
          created_at?: string
          email_address?: string | null
          full_name?: string
          gross_earned?: number
          id?: string
          ifsc_code?: string | null
          incremental_payable?: number
          ist_month?: string
          ist_year?: number
          mobile_number?: string | null
          net_payable?: number
          payment_status?: string
          processed_at?: string | null
          processed_by?: string | null
          skipped_reason?: string | null
          snapshot_ist_date?: string
          snapshot_ist_datetime?: string
          snapshot_type?: string
          upi_vpa?: string | null
          user_id?: string
          wallet_balance_at_snapshot?: number
          withdrawal_fee_amount?: number
        }
        Relationships: []
      }
    }
    Views: {
      public_female_profiles: {
        Row: {
          account_status: string | null
          age: number | null
          approval_status: string | null
          bio: string | null
          country: string | null
          created_at: string | null
          earning_badge_type: string | null
          full_name: string | null
          id: string | null
          interests: string[] | null
          is_earning_eligible: boolean | null
          is_indian: boolean | null
          is_premium: boolean | null
          is_verified: boolean | null
          last_active_at: string | null
          photo_url: string | null
          preferred_language: string | null
          primary_language: string | null
          state: string | null
          user_id: string | null
        }
        Insert: {
          account_status?: string | null
          age?: number | null
          approval_status?: string | null
          bio?: string | null
          country?: string | null
          created_at?: string | null
          earning_badge_type?: string | null
          full_name?: string | null
          id?: string | null
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          state?: string | null
          user_id?: string | null
        }
        Update: {
          account_status?: string | null
          age?: number | null
          approval_status?: string | null
          bio?: string | null
          country?: string | null
          created_at?: string | null
          earning_badge_type?: string | null
          full_name?: string | null
          id?: string | null
          interests?: string[] | null
          is_earning_eligible?: boolean | null
          is_indian?: boolean | null
          is_premium?: boolean | null
          is_verified?: boolean | null
          last_active_at?: string | null
          photo_url?: string | null
          preferred_language?: string | null
          primary_language?: string | null
          state?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      accept_friend_request: { Args: { p_request_id: string }; Returns: Json }
      admin_deduct_wallet: {
        Args: {
          p_admin_id: string
          p_amount: number
          p_reason: string
          p_user_id: string
        }
        Returns: Json
      }
      admin_get_user_transactions: {
        Args: {
          p_include_archive?: boolean
          p_limit?: number
          p_user_id: string
        }
        Returns: {
          amount: number
          balance_after: number
          billing_metadata: Json
          created_at: string
          description: string
          duration_seconds: number
          id: string
          rate_per_minute: number
          reference_id: string
          session_id: string
          session_type: string
          source: string
          status: string
          transaction_type: string
          type: string
          user_id: string
        }[]
      }
      admin_list_statements: {
        Args: {
          p_gender?: string
          p_limit?: number
          p_month?: number
          p_offset?: number
          p_payout_status?: string
          p_user_id?: string
          p_year?: number
        }
        Returns: {
          audio_call_amount: number
          chat_amount: number
          closing_balance: number
          excel_url: string
          full_name: string
          gender: string
          generated_at: string
          gift_amount: number
          group_call_amount: number
          month: number
          opening_balance: number
          paid_at: string
          payout_amount: number
          payout_status: string
          pdf_url: string
          recharge_amount: number
          statement_id: string
          tip_amount: number
          total_credit: number
          total_debit: number
          user_id: string
          video_call_amount: number
          year: number
        }[]
      }
      admin_toggle_language_leader: {
        Args: { p_make_leader: boolean; p_user_id: string }
        Returns: Json
      }
      admin_update_payout: {
        Args: {
          p_excel_url?: string
          p_notes?: string
          p_pdf_url?: string
          p_statement_id: string
          p_status?: string
        }
        Returns: Json
      }
      archive_old_wallet_transactions: {
        Args: never
        Returns: {
          archived_count: number
          cutoff_date: string
        }[]
      }
      assign_earning_slots: { Args: never; Returns: Json }
      atomic_wallet_credit: {
        Args: { p_amount: number; p_wallet_id: string }
        Returns: number
      }
      atomic_wallet_debit: {
        Args: { p_amount: number; p_wallet_id: string }
        Returns: number
      }
      assert_language_call_capacity: {
        Args: { p_language: string; p_slots?: number }
        Returns: Json
      }
      assert_group_host_language_slot: {
        Args: { p_language: string }
        Returns: Json
      }
      count_active_call_users_for_language: {
        Args: { p_language: string }
        Returns: number
      }
      audit_wallet_table_grants: {
        Args: never
        Returns: {
          can_delete: boolean
          can_insert: boolean
          can_select: boolean
          can_update: boolean
          grantee: string
          table_name: string
        }[]
      }
      bill_gift_or_tip: {
        Args: {
          p_amount: number
          p_description?: string
          p_man_id: string
          p_reference_id?: string
          p_type: string
          p_woman_id: string
        }
        Returns: Json
      }
      bill_group_chat_minute: {
        Args: { p_man_id: string; p_session_id: string }
        Returns: Json
      }
      bill_group_gift_or_tip: {
        Args: {
          p_amount: number
          p_description?: string
          p_group_id: string
          p_man_id: string
          p_reference_id?: string
          p_type: string
        }
        Returns: Json
      }
      bill_session_minute: {
        Args: {
          p_man_count?: number
          p_man_id: string
          p_minute_index?: number
          p_minutes: number
          p_session_id: string
          p_session_type: string
          p_woman_id: string
        }
        Returns: Json
      }
      block_user: { Args: { p_target_user_id: string }; Returns: Json }
      can_access_service: {
        Args: { _service: string; _user_id: string }
        Returns: boolean
      }
      cancel_friend_request: { Args: { p_request_id: string }; Returns: Json }
      canonical_wallet_balance: { Args: { p_user_id: string }; Returns: number }
      capture_payout_snapshot: {
        Args: { p_snapshot_type: string }
        Returns: Json
      }
      check_free_chat_status: {
        Args: { p_man_id: string; p_woman_id: string }
        Returns: Json
      }
      check_men_free_minutes: { Args: { p_user_id: string }; Returns: Json }
      check_rate_limit: {
        Args: {
          p_function_name: string
          p_max_requests?: number
          p_user_id: string
          p_window_seconds?: number
        }
        Returns: boolean
      }
      check_session_balance: {
        Args: {
          p_session_id?: string
          p_session_type?: string
          p_user_id: string
        }
        Returns: Json
      }
      check_signup_availability: {
        Args: { p_email?: string; p_phone?: string }
        Returns: Json
      }
      cleanup_chat_media: { Args: never; Returns: undefined }
      cleanup_expired_data: { Args: never; Returns: undefined }
      cleanup_idle_sessions: { Args: never; Returns: undefined }
      cleanup_old_admin_messages: { Args: never; Returns: undefined }
      cleanup_old_chat_messages: { Args: never; Returns: undefined }
      cleanup_old_group_messages: { Args: never; Returns: undefined }
      cleanup_old_group_video_sessions: { Args: never; Returns: undefined }
      cleanup_old_transactions: { Args: never; Returns: undefined }
      cleanup_video_sessions: { Args: never; Returns: undefined }
      end_login_session: { Args: { _session_id?: string }; Returns: undefined }
      ensure_canonical_wallet: {
        Args: { p_gender?: string; p_user_id: string }
        Returns: string
      }
      expire_group_video_access: { Args: never; Returns: undefined }
      generate_female_employee_id: { Args: never; Returns: string }
      generate_payout_snapshot_now: { Args: never; Returns: Json }
      generate_payout_snapshot_unified: { Args: never; Returns: Json }
      get_analytics_summary: {
        Args: { p_end_date: string; p_start_date: string }
        Returns: Json
      }
      get_billing_seconds_for_month: {
        Args: { _month: string; _user_id: string }
        Returns: number
      }
      get_browsable_female_profiles: {
        Args: never
        Returns: {
          account_status: string
          age: number
          approval_status: string
          bio: string
          country: string
          full_name: string
          has_golden_badge: boolean
          id: string
          interests: string[]
          is_premium: boolean
          is_verified: boolean
          last_active_at: string
          life_goals: string[]
          photo_url: string
          preferred_language: string
          primary_language: string
          state: string
          user_id: string
        }[]
      }
      get_dashboard_stats: { Args: { p_user_id: string }; Returns: Json }
      get_global_app_id: { Args: { p_user_id?: string }; Returns: number }
      get_ledger_statement: {
        Args: { p_from_date?: string; p_to_date?: string; p_user_id: string }
        Returns: {
          counterparty_id: string
          created_at: string
          credit: number
          debit: number
          description: string
          duration_seconds: number
          id: string
          rate_per_minute: number
          reference_id: string
          running_balance: number
          session_id: string
          session_type: string
          transaction_type: string
        }[]
      }
      get_login_billing_seconds_bulk: {
        Args: { _month: string; _user_ids: string[] }
        Returns: {
          billing_seconds: number
          login_seconds: number
          user_id: string
        }[]
      }
      get_login_seconds_for_month: {
        Args: { _month: string; _user_id: string }
        Returns: number
      }
      get_man_active_chats: {
        Args: { p_user_id: string }
        Returns: {
          chat_id: string
          last_message: string
          last_message_at: string
          last_message_sender_id: string
          partner_active_chat_count: number
          partner_id: string
          partner_is_online: boolean
          partner_name: string
          partner_photo: string
          partner_status: string
          session_status: string
          unread_count: number
        }[]
      }
      get_man_balance: { Args: { p_user_id: string }; Returns: Json }
      get_men_transaction_history: {
        Args: { p_limit?: number; p_user_id: string }
        Returns: Json
      }
      get_men_wallet_balance: { Args: { p_user_id: string }; Returns: Json }
      get_men_wallet_balances_bulk: {
        Args: { p_user_ids: string[] }
        Returns: {
          balance: number
          user_id: string
        }[]
      }
      get_men_with_balance: {
        Args: { p_user_ids: string[] }
        Returns: {
          balance: number
          user_id: string
        }[]
      }
      get_offline_women_for_daily_ping: {
        Args: never
        Returns: {
          full_name: string
          user_id: string
        }[]
      }
      get_online_men_dashboard: {
        Args: never
        Returns: {
          active_chat_count: number
          age: number
          country: string
          full_name: string
          last_seen: string
          mother_tongue: string
          photo_url: string
          preferred_language: string
          primary_language: string
          state: string
          user_id: string
          wallet_balance: number
        }[]
      }
      get_online_women_for_ping: {
        Args: never
        Returns: {
          full_name: string
          user_id: string
        }[]
      }
      get_public_profiles: {
        Args: { user_ids?: string[] }
        Returns: {
          account_status: string
          age: number
          ai_approved: boolean
          approval_status: string
          avg_response_time_seconds: number
          bio: string
          body_type: string
          city: string
          country: string
          created_at: string
          earning_badge_type: string
          education_level: string
          full_name: string
          gender: string
          height_cm: number
          id: string
          interests: string[]
          is_earning_eligible: boolean
          is_indian: boolean
          is_premium: boolean
          is_verified: boolean
          language: string
          last_active_at: string
          life_goals: string[]
          marital_status: string
          monthly_chat_minutes: number
          occupation: string
          performance_score: number
          photo_url: string
          preferred_language: string
          primary_language: string
          profile_completeness: number
          promoted_from_free: boolean
          religion: string
          state: string
          total_chats_count: number
          updated_at: string
          user_id: string
          verification_status: boolean
        }[]
      }
      get_top_earner_today: {
        Args: never
        Returns: {
          full_name: string
          total_amount: number
          user_id: string
        }[]
      }
      get_unified_pricing: { Args: never; Returns: Json }
      get_unrecharged_men: {
        Args: never
        Returns: {
          full_name: string
          user_id: string
        }[]
      }
      get_user_group_call_history: {
        Args: { p_is_male: boolean; p_limit?: number; p_user_id: string }
        Returns: {
          amount: number
          created_at: string
          description: string
          duration_seconds: number
          id: string
          rate_per_minute: number
          session_id: string
          transaction_type: string
          type: string
        }[]
      }
      get_user_id_by_email: { Args: { p_email: string }; Returns: string }
      get_woman_active_chats: {
        Args: { p_user_id: string }
        Returns: {
          chat_id: string
          last_message: string
          last_message_at: string
          last_message_sender_id: string
          partner_active_chat_count: number
          partner_id: string
          partner_is_online: boolean
          partner_name: string
          partner_photo: string
          partner_status: string
          session_status: string
          unread_count: number
        }[]
      }
      get_woman_balance: { Args: { p_user_id: string }; Returns: Json }
      get_women_transaction_history: {
        Args: { p_limit?: number; p_user_id: string }
        Returns: Json
      }
      get_women_wallet_balance: { Args: { p_user_id: string }; Returns: Json }
      group_chat_end_live: { Args: { p_session_id: string }; Returns: Json }
      group_chat_go_live: { Args: { p_room_id: string }; Returns: Json }
      group_chat_join: { Args: { p_room_id: string }; Returns: Json }
      group_chat_leave: { Args: { p_session_id: string }; Returns: Json }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      has_service_role: {
        Args: {
          _role: Database["public"]["Enums"]["service_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_indian_woman:
        | { Args: { p_country: string }; Returns: boolean }
        | { Args: { user_id_param: string }; Returns: boolean }
      is_protected_admin: { Args: { p_user_id: string }; Returns: boolean }
      is_super_user: { Args: { user_email: string }; Returns: boolean }
      ist_now: { Args: never; Returns: string }
      join_group_atomic: {
        Args: {
          p_group_id: string
          p_max_participants?: number
          p_user_id: string
          p_host_id?: string
        }
        Returns: Json
      }
      ledger_recharge: {
        Args: {
          p_amount: number
          p_description?: string
          p_gateway: string
          p_gateway_txn_id?: string
          p_reference_id?: string
          p_user_id: string
        }
        Returns: Json
      }
      ledger_withdrawal: {
        Args: {
          p_amount: number
          p_payment_details?: Json
          p_payment_method?: string
          p_user_id: string
        }
        Returns: Json
      }
      mark_stalled_backups: { Args: never; Returns: number }
      men_ledger_balance: { Args: { p_man_id: string }; Returns: number }
      migrate_existing_wallets_to_ledger: { Args: never; Returns: Json }
      now_ist: { Args: never; Returns: string }
      perform_monthly_earning_rotation: { Args: never; Returns: Json }
      process_atomic_transfer: {
        Args: {
          p_amount: number
          p_description?: string
          p_from_user_id: string
          p_to_user_id: string
        }
        Returns: Json
      }
      process_monthly_payout: { Args: never; Returns: Json }
      query_wallet_transactions_unified: {
        Args: {
          p_include_archive?: boolean
          p_limit?: number
          p_user_id: string
        }
        Returns: {
          amount: number
          balance_after: number
          billing_metadata: Json
          created_at: string
          description: string
          duration_seconds: number
          id: string
          rate_per_minute: number
          reference_id: string
          session_type: string
          source: string
          status: string
          transaction_type: string
          type: string
          user_id: string
        }[]
      }
      r2: { Args: { v: number }; Returns: number }
      reconcile_user_busy_status: {
        Args: { _user_id?: string }
        Returns: number
      }
      reconcile_wallet_balance: { Args: { p_user_id: string }; Returns: Json }
      reject_friend_request: { Args: { p_request_id: string }; Returns: Json }
      reset_private_group_counts: { Args: never; Returns: undefined }
      reset_women_wallets_after_snapshot: { Args: never; Returns: Json }
      resolve_wallet_user_id: { Args: { p_id: string }; Returns: string }
      revert_busy_to_online: { Args: { p_user_id: string }; Returns: undefined }
      run_monthly_closing: {
        Args: { p_month?: number; p_year?: number }
        Returns: Json
      }
      safe_ledger_insert: {
        Args: {
          p_counterparty_id: string
          p_credit: number
          p_debit: number
          p_description: string
          p_duration_seconds: number
          p_entry_type: string
          p_rate: number
          p_ref_key: string
          p_session_id: string
          p_timestamp: string
          p_user_id: string
        }
        Returns: undefined
      }
      send_friend_request: { Args: { p_target_user_id: string }; Returns: Json }
      should_bypass_balance: { Args: { p_user_id: string }; Returns: boolean }
      should_woman_earn: { Args: { p_user_id: string }; Returns: boolean }
      simulate_group_call_billing: {
        Args: { p_man_id?: string; p_minutes?: number; p_woman_id?: string }
        Returns: Json
      }
      start_host_session: {
        Args: {
          p_group_id: string
          p_host_language?: string
          p_host_name: string
          p_host_photo?: string
          p_stream_id?: string
        }
        Returns: Json
      }
      start_login_session: { Args: { _client_info?: Json }; Returns: string }
      stop_host_session: { Args: { p_group_id: string }; Returns: Json }
      stop_live_safe: { Args: { p_group_id: string }; Returns: Json }
      sweep_stale_group_hosts: { Args: never; Returns: Json }
      sweep_stale_login_sessions: { Args: never; Returns: number }
      sweep_stale_statuses: { Args: never; Returns: number }
      sweep_stale_user_status: { Args: never; Returns: undefined }
      sync_wallet_balance_from_ledger: {
        Args: { p_user_id: string }
        Returns: number
      }
      text_to_uuid: { Args: { p_text: string }; Returns: string }
      today_ist: { Args: never; Returns: string }
      unblock_user: { Args: { p_target_user_id: string }; Returns: Json }
      unfriend_user: { Args: { p_target_user_id: string }; Returns: Json }
      update_daily_platform_metrics: { Args: never; Returns: undefined }
      update_free_chat_usage: {
        Args: { p_man_id: string; p_seconds: number; p_woman_id: string }
        Returns: Json
      }
      update_host_heartbeat: { Args: { p_group_id: string }; Returns: Json }
      use_men_free_minute: { Args: { p_user_id: string }; Returns: Json }
      validate_financial_sot: {
        Args: never
        Returns: {
          check_name: string
          details: string
          status: string
        }[]
      }
      verify_recharge_integrity: {
        Args: never
        Returns: {
          duplicate_keys: number
          ledger_recharge_total: number
          recharge_count: number
          user_id: string
        }[]
      }
      women_ledger_balance: { Args: { p_woman_id: string }; Returns: number }
    }
    Enums: {
      app_role: "admin" | "moderator" | "user"
      service_role:
        | "chat_role"
        | "audio_role"
        | "video_role"
        | "group_role"
        | "all_role"
        | "tl_role"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "moderator", "user"],
      service_role: [
        "chat_role",
        "audio_role",
        "video_role",
        "group_role",
        "all_role",
        "tl_role",
      ],
    },
  },
} as const
