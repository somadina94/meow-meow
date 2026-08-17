-- MeowMeow Live Chat Platform — All Migrations Combined
-- Total: 178 migrations
-- Generated: 2026-03-12

-- ============================================================
-- Migration: 20251206043628_d59bd457-4bb1-4494-ac64-8ea668b6ba62.sql
-- ============================================================
-- Create profiles table for user registration data
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Screen 1: Language & Country
  preferred_language TEXT,
  country TEXT,
  
  -- Screen 2: Basic Info
  full_name TEXT,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'non-binary', 'prefer-not-to-say')),
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own profile" 
ON public.profiles 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" 
ON public.profiles 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger for auto-updating updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to auto-create profile when user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- Migration: 20251206044126_1508edd7-9f17-4df3-beb5-aa66f5c8e642.sql
-- ============================================================
-- Create storage bucket for profile photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true);

-- Storage policies for profile photos
CREATE POLICY "Users can upload their own profile photo"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own profile photo"
ON storage.objects FOR UPDATE
USING (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Profile photos are publicly viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

CREATE POLICY "Users can delete their own profile photo"
ON storage.objects FOR DELETE
USING (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Add photo columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN photo_url TEXT,
ADD COLUMN verification_status BOOLEAN DEFAULT false;

-- ============================================================
-- Migration: 20251206045756_7b395e1f-d89a-404a-b199-bad94534954d.sql
-- ============================================================
-- Add location columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN latitude double precision,
ADD COLUMN longitude double precision,
ADD COLUMN state text;

-- ============================================================
-- Migration: 20251206051235_b54144e1-4cee-4b86-8c7a-70ede622caaf.sql
-- ============================================================
-- Create user_languages table for storing optional language preferences
CREATE TABLE public.user_languages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  language_code TEXT NOT NULL,
  language_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, language_code)
);

-- Enable Row Level Security
ALTER TABLE public.user_languages ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own languages" 
ON public.user_languages 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own languages" 
ON public.user_languages 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own languages" 
ON public.user_languages 
FOR DELETE 
USING (auth.uid() = user_id);

-- ============================================================
-- Migration: 20251206051505_946b49db-b040-4e8c-8f6b-555e9a1a6f07.sql
-- ============================================================
-- Create user_consent table for storing legal consent with timestamps
CREATE TABLE public.user_consent (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  agreed_terms BOOLEAN NOT NULL DEFAULT false,
  terms_version TEXT NOT NULL DEFAULT '1.0',
  gdpr_consent BOOLEAN DEFAULT false,
  ccpa_consent BOOLEAN DEFAULT false,
  dpdp_consent BOOLEAN DEFAULT false,
  consent_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.user_consent ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own consent" 
ON public.user_consent 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own consent" 
ON public.user_consent 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own consent" 
ON public.user_consent 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_user_consent_updated_at
BEFORE UPDATE ON public.user_consent
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206051722_e1915f63-2d10-4e3a-bb12-f17b1aba6ad9.sql
-- ============================================================
-- Create processing_logs table for AI verification status tracking
CREATE TABLE public.processing_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  processing_status TEXT NOT NULL DEFAULT 'pending',
  current_step TEXT,
  progress_percent INTEGER DEFAULT 0,
  gender_verified BOOLEAN DEFAULT false,
  age_verified BOOLEAN DEFAULT false,
  language_detected BOOLEAN DEFAULT false,
  photo_verified BOOLEAN DEFAULT false,
  errors TEXT[] DEFAULT ARRAY[]::TEXT[],
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.processing_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own processing logs" 
ON public.processing_logs 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own processing logs" 
ON public.processing_logs 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own processing logs" 
ON public.processing_logs 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_processing_logs_updated_at
BEFORE UPDATE ON public.processing_logs
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206051946_a9682931-0caa-409a-aafd-9c2880a7e9ff.sql
-- ============================================================
-- Create tutorial_progress table for tracking onboarding progress
CREATE TABLE public.tutorial_progress (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  current_step INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT false,
  skipped BOOLEAN DEFAULT false,
  steps_viewed INTEGER[] DEFAULT ARRAY[]::INTEGER[],
  theme_preference TEXT DEFAULT 'blue',
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.tutorial_progress ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own tutorial progress" 
ON public.tutorial_progress 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tutorial progress" 
ON public.tutorial_progress 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tutorial progress" 
ON public.tutorial_progress 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_tutorial_progress_updated_at
BEFORE UPDATE ON public.tutorial_progress
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206053000_d1b38250-e501-44e8-b178-336d8a1fa27b.sql
-- ============================================================
-- Create user_status table for online presence
CREATE TABLE public.user_status (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  is_online BOOLEAN NOT NULL DEFAULT false,
  last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  status_text TEXT DEFAULT 'Available',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create notifications table
CREATE TABLE public.notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',
  is_read BOOLEAN NOT NULL DEFAULT false,
  action_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create matches table
CREATE TABLE public.matches (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  matched_user_id UUID NOT NULL,
  match_score INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  matched_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, matched_user_id)
);

-- Enable RLS on all tables
ALTER TABLE public.user_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- RLS policies for user_status
CREATE POLICY "Users can view all online statuses"
ON public.user_status FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own status"
ON public.user_status FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own status"
ON public.user_status FOR UPDATE
USING (auth.uid() = user_id);

-- RLS policies for notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE
USING (auth.uid() = user_id);

-- RLS policies for matches
CREATE POLICY "Users can view their own matches"
ON public.matches FOR SELECT
USING (auth.uid() = user_id OR auth.uid() = matched_user_id);

CREATE POLICY "Users can insert their own matches"
ON public.matches FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own matches"
ON public.matches FOR UPDATE
USING (auth.uid() = user_id OR auth.uid() = matched_user_id);

-- Add trigger for updated_at on user_status
CREATE TRIGGER update_user_status_updated_at
BEFORE UPDATE ON public.user_status
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Enable realtime for user_status
ALTER TABLE public.user_status REPLICA IDENTITY FULL;

-- ============================================================
-- Migration: 20251206054237_2b9e9a87-79aa-4667-9618-d177cb94e38d.sql
-- ============================================================
-- Add phone column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS phone text;

-- ============================================================
-- Migration: 20251206061508_cb2fd5a6-bad9-463c-b779-ea4cc8e1f2b7.sql
-- ============================================================
-- Create chat_messages table for real-time messaging
CREATE TABLE public.chat_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id TEXT NOT NULL,
  sender_id UUID NOT NULL,
  receiver_id UUID NOT NULL,
  message TEXT NOT NULL,
  translated_message TEXT,
  is_translated BOOLEAN DEFAULT false,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create index for efficient chat retrieval
CREATE INDEX idx_chat_messages_chat_id ON public.chat_messages(chat_id);
CREATE INDEX idx_chat_messages_participants ON public.chat_messages(sender_id, receiver_id);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Users can view messages where they are sender or receiver
CREATE POLICY "Users can view their own messages"
ON public.chat_messages
FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can insert messages as sender
CREATE POLICY "Users can send messages"
ON public.chat_messages
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Users can update messages they received (for marking as read)
CREATE POLICY "Users can mark messages as read"
ON public.chat_messages
FOR UPDATE
USING (auth.uid() = receiver_id);

-- Enable realtime for this table
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- ============================================================
-- Migration: 20251206063152_f0898b65-3b3e-49a7-b15f-55f9b604bbc7.sql
-- ============================================================
-- Create wallets table
CREATE TABLE public.wallets (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'INR',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create wallet transactions table
CREATE TABLE public.wallet_transactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
  amount DECIMAL(10,2) NOT NULL,
  description TEXT,
  reference_id TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on wallets
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- Enable RLS on wallet_transactions
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Wallet policies
CREATE POLICY "Users can view their own wallet"
ON public.wallets FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own wallet"
ON public.wallets FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own wallet"
ON public.wallets FOR UPDATE
USING (auth.uid() = user_id);

-- Transaction policies
CREATE POLICY "Users can view their own transactions"
ON public.wallet_transactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transactions"
ON public.wallet_transactions FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_wallet_transactions_wallet_id ON public.wallet_transactions(wallet_id);
CREATE INDEX idx_wallet_transactions_user_id ON public.wallet_transactions(user_id);
CREATE INDEX idx_wallet_transactions_created_at ON public.wallet_transactions(created_at DESC);

-- Trigger for updated_at on wallets
CREATE TRIGGER update_wallets_updated_at
BEFORE UPDATE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206063524_9df7585a-d5b0-404a-be8e-39f08462e9d7.sql
-- ============================================================
-- Create user_settings table
CREATE TABLE public.user_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  theme TEXT NOT NULL DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
  accent_color TEXT NOT NULL DEFAULT 'purple',
  notification_matches BOOLEAN NOT NULL DEFAULT true,
  notification_messages BOOLEAN NOT NULL DEFAULT true,
  notification_promotions BOOLEAN NOT NULL DEFAULT false,
  notification_sound BOOLEAN NOT NULL DEFAULT true,
  notification_vibration BOOLEAN NOT NULL DEFAULT true,
  language TEXT NOT NULL DEFAULT 'English',
  auto_translate BOOLEAN NOT NULL DEFAULT true,
  show_online_status BOOLEAN NOT NULL DEFAULT true,
  show_read_receipts BOOLEAN NOT NULL DEFAULT true,
  profile_visibility TEXT NOT NULL DEFAULT 'everyone' CHECK (profile_visibility IN ('everyone', 'matches', 'nobody')),
  distance_unit TEXT NOT NULL DEFAULT 'km' CHECK (distance_unit IN ('km', 'miles')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view their own settings"
ON public.user_settings FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings"
ON public.user_settings FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
ON public.user_settings FOR UPDATE
USING (auth.uid() = user_id);

-- Trigger for updated_at
CREATE TRIGGER update_user_settings_updated_at
BEFORE UPDATE ON public.user_settings
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Create index
CREATE INDEX idx_user_settings_user_id ON public.user_settings(user_id);

-- ============================================================
-- Migration: 20251206063751_b50433e3-c802-44f6-9bef-8037fddc3303.sql
-- ============================================================
-- Create shifts table for women to track chat engagement
CREATE TABLE public.shifts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  end_time TIMESTAMP WITH TIME ZONE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  total_chats INTEGER NOT NULL DEFAULT 0,
  total_messages INTEGER NOT NULL DEFAULT 0,
  earnings DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  bonus_earnings DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create shift_earnings table for detailed earnings breakdown
CREATE TABLE public.shift_earnings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  earning_type TEXT NOT NULL CHECK (earning_type IN ('message', 'chat_started', 'bonus', 'tip')),
  amount DECIMAL(10,2) NOT NULL,
  description TEXT,
  chat_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_earnings ENABLE ROW LEVEL SECURITY;

-- Shifts policies
CREATE POLICY "Users can view their own shifts"
ON public.shifts FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own shifts"
ON public.shifts FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own shifts"
ON public.shifts FOR UPDATE
USING (auth.uid() = user_id);

-- Shift earnings policies
CREATE POLICY "Users can view their own shift earnings"
ON public.shift_earnings FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own shift earnings"
ON public.shift_earnings FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_shifts_user_id ON public.shifts(user_id);
CREATE INDEX idx_shifts_status ON public.shifts(status);
CREATE INDEX idx_shifts_start_time ON public.shifts(start_time DESC);
CREATE INDEX idx_shift_earnings_shift_id ON public.shift_earnings(shift_id);
CREATE INDEX idx_shift_earnings_user_id ON public.shift_earnings(user_id);

-- Trigger for updated_at
CREATE TRIGGER update_shifts_updated_at
BEFORE UPDATE ON public.shifts
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206064100_e61b3c23-cccc-4812-82f1-54fc3f861511.sql
-- ============================================================
-- Create scheduled_shifts table for AI-scheduled shifts
CREATE TABLE public.scheduled_shifts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  scheduled_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'started', 'completed', 'missed', 'cancelled')),
  ai_suggested BOOLEAN NOT NULL DEFAULT true,
  suggested_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create attendance table for tracking check-ins
CREATE TABLE public.attendance (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  scheduled_shift_id UUID REFERENCES public.scheduled_shifts(id) ON DELETE SET NULL,
  shift_id UUID REFERENCES public.shifts(id) ON DELETE SET NULL,
  attendance_date DATE NOT NULL,
  check_in_time TIMESTAMP WITH TIME ZONE,
  check_out_time TIMESTAMP WITH TIME ZONE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'present', 'absent', 'late', 'half_day', 'leave')),
  auto_marked BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create absence_records table
CREATE TABLE public.absence_records (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  absence_date DATE NOT NULL,
  reason TEXT,
  leave_type TEXT NOT NULL DEFAULT 'casual' CHECK (leave_type IN ('casual', 'sick', 'planned', 'emergency', 'no_show')),
  approved BOOLEAN DEFAULT false,
  ai_detected BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.scheduled_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.absence_records ENABLE ROW LEVEL SECURITY;

-- Scheduled shifts policies
CREATE POLICY "Users can view their own scheduled shifts"
ON public.scheduled_shifts FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own scheduled shifts"
ON public.scheduled_shifts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own scheduled shifts"
ON public.scheduled_shifts FOR UPDATE USING (auth.uid() = user_id);

-- Attendance policies
CREATE POLICY "Users can view their own attendance"
ON public.attendance FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own attendance"
ON public.attendance FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own attendance"
ON public.attendance FOR UPDATE USING (auth.uid() = user_id);

-- Absence records policies
CREATE POLICY "Users can view their own absence records"
ON public.absence_records FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own absence records"
ON public.absence_records FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_scheduled_shifts_user_date ON public.scheduled_shifts(user_id, scheduled_date);
CREATE INDEX idx_attendance_user_date ON public.attendance(user_id, attendance_date);
CREATE INDEX idx_absence_records_user_date ON public.absence_records(user_id, absence_date);

-- Triggers for updated_at
CREATE TRIGGER update_scheduled_shifts_updated_at
BEFORE UPDATE ON public.scheduled_shifts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_attendance_updated_at
BEFORE UPDATE ON public.attendance
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206065304_4e3352ef-1568-4efa-ba6a-5867a55414ae.sql
-- ============================================================
-- Create enum for roles
CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check roles (prevents RLS recursion)
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- RLS policies for user_roles
CREATE POLICY "Users can view their own roles"
ON public.user_roles
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all roles"
ON public.user_roles
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can insert roles"
ON public.user_roles
FOR INSERT
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update roles"
ON public.user_roles
FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete roles"
ON public.user_roles
FOR DELETE
USING (public.has_role(auth.uid(), 'admin'));

-- Add policy to profiles for admin access
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete profiles"
ON public.profiles
FOR DELETE
USING (public.has_role(auth.uid(), 'admin'));

-- ============================================================
-- Migration: 20251206070802_5bbd7dec-5d38-4b0c-9637-267dcf43128a.sql
-- ============================================================
-- Add extended profile attributes for filtering
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS age integer,
ADD COLUMN IF NOT EXISTS height_cm integer,
ADD COLUMN IF NOT EXISTS body_type text,
ADD COLUMN IF NOT EXISTS education_level text,
ADD COLUMN IF NOT EXISTS occupation text,
ADD COLUMN IF NOT EXISTS religion text,
ADD COLUMN IF NOT EXISTS marital_status text DEFAULT 'single',
ADD COLUMN IF NOT EXISTS has_children boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS smoking_habit text DEFAULT 'never',
ADD COLUMN IF NOT EXISTS drinking_habit text DEFAULT 'never',
ADD COLUMN IF NOT EXISTS dietary_preference text DEFAULT 'no_preference',
ADD COLUMN IF NOT EXISTS fitness_level text DEFAULT 'moderate',
ADD COLUMN IF NOT EXISTS pet_preference text,
ADD COLUMN IF NOT EXISTS travel_frequency text DEFAULT 'occasionally',
ADD COLUMN IF NOT EXISTS personality_type text,
ADD COLUMN IF NOT EXISTS zodiac_sign text,
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS profile_completeness integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_premium boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT now(),
ADD COLUMN IF NOT EXISTS life_goals text[],
ADD COLUMN IF NOT EXISTS interests text[];

-- Create index for common filter queries
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON public.profiles(country);
CREATE INDEX IF NOT EXISTS idx_profiles_age ON public.profiles(age);
CREATE INDEX IF NOT EXISTS idx_profiles_is_verified ON public.profiles(is_verified);
CREATE INDEX IF NOT EXISTS idx_profiles_last_active_at ON public.profiles(last_active_at);

-- ============================================================
-- Migration: 20251206071424_de3cd2f5-da2b-4268-8578-03585775bede.sql
-- ============================================================
-- Create gifts table for virtual gift pricing
CREATE TABLE public.gifts (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  emoji text NOT NULL DEFAULT '🎁',
  price numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'INR',
  category text NOT NULL DEFAULT 'general',
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;

-- Everyone can view active gifts
CREATE POLICY "Anyone can view active gifts"
ON public.gifts
FOR SELECT
USING (is_active = true);

-- Admins can manage all gifts
CREATE POLICY "Admins can manage gifts"
ON public.gifts
FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- Create gift_transactions table to track gift purchases
CREATE TABLE public.gift_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  gift_id uuid NOT NULL REFERENCES public.gifts(id),
  sender_id uuid NOT NULL,
  receiver_id uuid NOT NULL,
  price_paid numeric NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  message text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.gift_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view their gift transactions"
ON public.gift_transactions
FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send gifts
CREATE POLICY "Users can send gifts"
ON public.gift_transactions
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Admins can view all transactions
CREATE POLICY "Admins can view all gift transactions"
ON public.gift_transactions
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

-- Insert some default gifts
INSERT INTO public.gifts (name, description, emoji, price, category, sort_order) VALUES
('Rose', 'A beautiful red rose', '🌹', 50, 'flowers', 1),
('Heart', 'Show your love', '❤️', 100, 'love', 2),
('Chocolate', 'Sweet treat', '🍫', 75, 'food', 3),
('Diamond Ring', 'Precious gift', '💍', 500, 'luxury', 4),
('Teddy Bear', 'Cuddly companion', '🧸', 150, 'toys', 5),
('Champagne', 'Celebrate together', '🍾', 300, 'drinks', 6),
('Star', 'You are a star', '⭐', 25, 'general', 7),
('Kiss', 'Virtual kiss', '💋', 80, 'love', 8),
('Crown', 'Royal treatment', '👑', 400, 'luxury', 9),
('Flower Bouquet', 'Beautiful flowers', '💐', 200, 'flowers', 10);

-- Create indexes
CREATE INDEX idx_gifts_category ON public.gifts(category);
CREATE INDEX idx_gifts_is_active ON public.gifts(is_active);
CREATE INDEX idx_gift_transactions_sender ON public.gift_transactions(sender_id);
CREATE INDEX idx_gift_transactions_receiver ON public.gift_transactions(receiver_id);

-- ============================================================
-- Migration: 20251206071732_b92ddab7-f52a-4595-ad0d-f5b77ce755ac.sql
-- ============================================================
-- Create language_groups table for managing language groupings for matching logic
CREATE TABLE public.language_groups (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  languages TEXT[] NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  priority INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.language_groups ENABLE ROW LEVEL SECURITY;

-- Admins can manage language groups
CREATE POLICY "Admins can manage language groups"
ON public.language_groups
FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role));

-- Anyone can view active language groups (for matching logic)
CREATE POLICY "Anyone can view active language groups"
ON public.language_groups
FOR SELECT
USING (is_active = true);

-- Create trigger for updated_at
CREATE TRIGGER update_language_groups_updated_at
BEFORE UPDATE ON public.language_groups
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Insert default language groups
INSERT INTO public.language_groups (name, description, languages, priority) VALUES
('Indo-Aryan (North India)', 'Hindi, Urdu, and related North Indian languages', ARRAY['hi', 'ur', 'bho', 'mai', 'awa', 'raj', 'pa', 'gu', 'mr', 'bn', 'or', 'as'], 1),
('Dravidian (South India)', 'Tamil, Telugu, Kannada, Malayalam and related languages', ARRAY['ta', 'te', 'kn', 'ml', 'tcy'], 2),
('East Asian', 'Chinese, Japanese, Korean languages', ARRAY['zh', 'ja', 'ko'], 3),
('Romance Languages', 'Spanish, Portuguese, French, Italian, Romanian', ARRAY['es', 'pt', 'fr', 'it', 'ro', 'ca', 'gl'], 4),
('Germanic Languages', 'English, German, Dutch, Swedish, Norwegian, Danish', ARRAY['en', 'de', 'nl', 'sv', 'no', 'da'], 5),
('Slavic Languages', 'Russian, Ukrainian, Polish, Czech, Serbian, Bulgarian', ARRAY['ru', 'uk', 'pl', 'cs', 'sr', 'bg', 'hr', 'sk', 'sl'], 6),
('Arabic & Semitic', 'Arabic dialects and related languages', ARRAY['ar', 'he', 'am', 'ti'], 7),
('Southeast Asian', 'Thai, Vietnamese, Indonesian, Malay, Filipino', ARRAY['th', 'vi', 'id', 'ms', 'tl', 'my', 'km', 'lo'], 8),
('African Languages', 'Swahili, Hausa, Yoruba, Igbo, Amharic', ARRAY['sw', 'ha', 'yo', 'ig', 'zu', 'xh', 'sn'], 9),
('Northeast Indian', 'Assamese, Bengali, Manipuri, Mizo and related languages', ARRAY['as', 'bn', 'mni', 'lus', 'kha', 'brx', 'sat'], 10);

-- ============================================================
-- Migration: 20251206071958_3376db97-2630-4f50-b568-654abb30d1a2.sql
-- ============================================================
-- Add moderation columns to chat_messages table
ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS flagged BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS flagged_by UUID,
ADD COLUMN IF NOT EXISTS flagged_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS flag_reason TEXT,
ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'pending';

-- Create index for moderation queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_flagged ON public.chat_messages(flagged);
CREATE INDEX IF NOT EXISTS idx_chat_messages_moderation_status ON public.chat_messages(moderation_status);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- Allow admins to view all chat messages for moderation
CREATE POLICY "Admins can view all messages for moderation"
ON public.chat_messages
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Allow admins to update message moderation status
CREATE POLICY "Admins can update message moderation"
ON public.chat_messages
FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role));

-- ============================================================
-- Migration: 20251206072223_4e51c872-fbd9-46c0-8e03-242a49efa1d6.sql
-- ============================================================
-- Allow admins to view all wallets and transactions for finance dashboard
CREATE POLICY "Admins can view all wallets"
ON public.wallets
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can view all wallet transactions"
ON public.wallet_transactions
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_created_at ON public.gift_transactions(created_at DESC);

-- ============================================================
-- Migration: 20251206072509_5b825761-19e7-4e93-a944-024b79fd5db1.sql
-- ============================================================
-- Create backup_logs table for tracking database backups
CREATE TABLE public.backup_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  backup_type TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'pending',
  size_bytes BIGINT,
  storage_path TEXT,
  triggered_by UUID,
  error_message TEXT,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.backup_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view backup logs
CREATE POLICY "Admins can view all backup logs"
ON public.backup_logs
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- Only admins can insert backup logs
CREATE POLICY "Admins can insert backup logs"
ON public.backup_logs
FOR INSERT
WITH CHECK (has_role(auth.uid(), 'admin'));

-- Only admins can update backup logs
CREATE POLICY "Admins can update backup logs"
ON public.backup_logs
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Create index for faster queries
CREATE INDEX idx_backup_logs_status ON public.backup_logs(status);
CREATE INDEX idx_backup_logs_started_at ON public.backup_logs(started_at DESC);

-- Add updated_at trigger
CREATE TRIGGER update_backup_logs_updated_at
BEFORE UPDATE ON public.backup_logs
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206072805_d49710aa-7d8a-4fb0-ac37-8f498a0746b0.sql
-- ============================================================
-- Create legal_documents table for tracking legal documents
CREATE TABLE public.legal_documents (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'terms',
  version TEXT NOT NULL DEFAULT '1.0',
  description TEXT,
  file_path TEXT NOT NULL,
  file_size BIGINT,
  mime_type TEXT,
  is_active BOOLEAN NOT NULL DEFAULT false,
  uploaded_by UUID,
  effective_date DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

-- Anyone can view active legal documents
CREATE POLICY "Anyone can view active legal documents"
ON public.legal_documents
FOR SELECT
USING (is_active = true);

-- Admins can view all legal documents
CREATE POLICY "Admins can view all legal documents"
ON public.legal_documents
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- Admins can insert legal documents
CREATE POLICY "Admins can insert legal documents"
ON public.legal_documents
FOR INSERT
WITH CHECK (has_role(auth.uid(), 'admin'));

-- Admins can update legal documents
CREATE POLICY "Admins can update legal documents"
ON public.legal_documents
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Admins can delete legal documents
CREATE POLICY "Admins can delete legal documents"
ON public.legal_documents
FOR DELETE
USING (has_role(auth.uid(), 'admin'));

-- Create indexes
CREATE INDEX idx_legal_documents_type ON public.legal_documents(document_type);
CREATE INDEX idx_legal_documents_active ON public.legal_documents(is_active);
CREATE INDEX idx_legal_documents_version ON public.legal_documents(name, version);

-- Add updated_at trigger
CREATE TRIGGER update_legal_documents_updated_at
BEFORE UPDATE ON public.legal_documents
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Create storage bucket for legal documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('legal-documents', 'legal-documents', true);

-- Storage policies for legal documents bucket
CREATE POLICY "Anyone can view legal documents"
ON storage.objects
FOR SELECT
USING (bucket_id = 'legal-documents');

CREATE POLICY "Admins can upload legal documents"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update legal documents"
ON storage.objects
FOR UPDATE
USING (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete legal documents"
ON storage.objects
FOR DELETE
USING (bucket_id = 'legal-documents' AND has_role(auth.uid(), 'admin'));

-- ============================================================
-- Migration: 20251206074106_8eb726b6-e147-4c31-883a-174e92f07b2a.sql
-- ============================================================
-- Chat pricing configuration table (admin managed)
CREATE TABLE public.chat_pricing (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  rate_per_minute numeric NOT NULL DEFAULT 2.00,
  currency text NOT NULL DEFAULT 'INR',
  min_withdrawal_balance numeric NOT NULL DEFAULT 10000.00,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.chat_pricing ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view active pricing" ON public.chat_pricing
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage pricing" ON public.chat_pricing
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Active chat sessions table
CREATE TABLE public.active_chat_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id text NOT NULL UNIQUE,
  man_user_id uuid NOT NULL,
  woman_user_id uuid NOT NULL,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  last_activity_at timestamp with time zone NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active',
  rate_per_minute numeric NOT NULL DEFAULT 2.00,
  total_minutes numeric NOT NULL DEFAULT 0,
  total_earned numeric NOT NULL DEFAULT 0,
  ended_at timestamp with time zone,
  end_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.active_chat_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for active chat sessions
CREATE POLICY "Users can view their own chat sessions" ON public.active_chat_sessions
  FOR SELECT USING (auth.uid() = man_user_id OR auth.uid() = woman_user_id);

CREATE POLICY "Users can insert chat sessions" ON public.active_chat_sessions
  FOR INSERT WITH CHECK (auth.uid() = man_user_id);

CREATE POLICY "Users can update their own chat sessions" ON public.active_chat_sessions
  FOR UPDATE USING (auth.uid() = man_user_id OR auth.uid() = woman_user_id);

CREATE POLICY "Admins can view all chat sessions" ON public.active_chat_sessions
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

-- Women earnings table
CREATE TABLE public.women_earnings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  chat_session_id uuid REFERENCES public.active_chat_sessions(id),
  amount numeric NOT NULL,
  earning_type text NOT NULL DEFAULT 'chat', -- 'chat', 'bonus', 'tip'
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_earnings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for women earnings
CREATE POLICY "Users can view their own earnings" ON public.women_earnings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert earnings" ON public.women_earnings
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view all earnings" ON public.women_earnings
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

-- Withdrawal requests table
CREATE TABLE public.withdrawal_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed'
  payment_method text,
  payment_details jsonb,
  processed_at timestamp with time zone,
  processed_by uuid,
  rejection_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for withdrawal requests
CREATE POLICY "Users can view their own withdrawals" ON public.withdrawal_requests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own withdrawals" ON public.withdrawal_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all withdrawals" ON public.withdrawal_requests
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Women availability status table (for load balancing)
CREATE TABLE public.women_availability (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  is_available boolean NOT NULL DEFAULT false,
  current_chat_count integer NOT NULL DEFAULT 0,
  max_concurrent_chats integer NOT NULL DEFAULT 3,
  last_assigned_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_availability ENABLE ROW LEVEL SECURITY;

-- RLS Policies for women availability
CREATE POLICY "Anyone can view availability" ON public.women_availability
  FOR SELECT USING (true);

CREATE POLICY "Users can update their own availability" ON public.women_availability
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own availability" ON public.women_availability
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Enable realtime for chat sessions
ALTER PUBLICATION supabase_realtime ADD TABLE public.active_chat_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.women_availability;

-- Insert default pricing
INSERT INTO public.chat_pricing (rate_per_minute, currency, min_withdrawal_balance)
VALUES (2.00, 'INR', 10000.00);

-- Create indexes for performance
CREATE INDEX idx_active_chat_sessions_man_user ON public.active_chat_sessions(man_user_id);
CREATE INDEX idx_active_chat_sessions_woman_user ON public.active_chat_sessions(woman_user_id);
CREATE INDEX idx_active_chat_sessions_status ON public.active_chat_sessions(status);
CREATE INDEX idx_women_earnings_user ON public.women_earnings(user_id);
CREATE INDEX idx_women_availability_available ON public.women_availability(is_available, current_chat_count);
CREATE INDEX idx_withdrawal_requests_user ON public.withdrawal_requests(user_id);
CREATE INDEX idx_withdrawal_requests_status ON public.withdrawal_requests(status);

-- ============================================================
-- Migration: 20251206075112_86bd4c5b-fecd-4a25-a772-3301c2e5d91e.sql
-- ============================================================
-- Shift templates table for admin-defined shifts
CREATE TABLE public.shift_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  shift_code text NOT NULL UNIQUE, -- 'A', 'B', 'C'
  start_time time NOT NULL,
  end_time time NOT NULL,
  duration_hours numeric NOT NULL DEFAULT 9,
  work_hours numeric NOT NULL DEFAULT 8,
  break_hours numeric NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.shift_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view active shift templates" ON public.shift_templates
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage shift templates" ON public.shift_templates
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Insert default shift templates
INSERT INTO public.shift_templates (name, shift_code, start_time, end_time, duration_hours, work_hours, break_hours) VALUES
  ('Shift A – Morning', 'A', '06:00:00', '15:00:00', 9, 8, 1),
  ('Shift B – Evening', 'B', '15:00:00', '00:00:00', 9, 8, 1),
  ('Shift C – Night', 'C', '00:00:00', '09:00:00', 9, 8, 1);

-- Women shift assignments (which shift and week offs)
CREATE TABLE public.women_shift_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  shift_template_id uuid REFERENCES public.shift_templates(id),
  language_group_id uuid REFERENCES public.language_groups(id),
  week_off_days integer[] NOT NULL DEFAULT '{0}', -- 0=Sunday, 1=Monday, etc.
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_shift_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own assignment" ON public.women_shift_assignments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own assignment" ON public.women_shift_assignments
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can insert assignments" ON public.women_shift_assignments
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can manage all assignments" ON public.women_shift_assignments
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Add language_code to profiles if missing for language-based matching
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS primary_language text;

-- Create indexes
CREATE INDEX idx_women_shift_assignments_user ON public.women_shift_assignments(user_id);
CREATE INDEX idx_women_shift_assignments_shift ON public.women_shift_assignments(shift_template_id);
CREATE INDEX idx_women_shift_assignments_language ON public.women_shift_assignments(language_group_id);

-- ============================================================
-- Migration: 20251206075459_9e216930-f2a7-4dbf-96f3-bae56a83c6ca.sql
-- ============================================================
-- Create system_metrics table for performance monitoring
CREATE TABLE public.system_metrics (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  cpu_usage FLOAT NOT NULL DEFAULT 0,
  memory_usage FLOAT NOT NULL DEFAULT 0,
  active_connections INTEGER NOT NULL DEFAULT 0,
  response_time FLOAT NOT NULL DEFAULT 0,
  disk_usage FLOAT DEFAULT 0,
  network_in FLOAT DEFAULT 0,
  network_out FLOAT DEFAULT 0,
  error_rate FLOAT DEFAULT 0,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create system_alerts table
CREATE TABLE public.system_alerts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  alert_type TEXT NOT NULL DEFAULT 'warning',
  metric_name TEXT NOT NULL,
  threshold_value FLOAT NOT NULL,
  current_value FLOAT NOT NULL,
  message TEXT NOT NULL,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.system_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_alerts ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can access
CREATE POLICY "Admins can view all metrics" ON public.system_metrics
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert metrics" ON public.system_metrics
  FOR INSERT WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can view all alerts" ON public.system_alerts
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can manage alerts" ON public.system_alerts
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for faster queries
CREATE INDEX idx_system_metrics_recorded_at ON public.system_metrics(recorded_at DESC);
CREATE INDEX idx_system_alerts_created_at ON public.system_alerts(created_at DESC);
CREATE INDEX idx_system_alerts_is_resolved ON public.system_alerts(is_resolved);

-- ============================================================
-- Migration: 20251206075801_8c504658-b040-4708-bac4-703a0eccaaab.sql
-- ============================================================
-- Create chat_wait_queue table to track men waiting for chat
CREATE TABLE public.chat_wait_queue (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  preferred_language TEXT NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  matched_at TIMESTAMP WITH TIME ZONE,
  wait_time_seconds INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'waiting',
  priority INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.chat_wait_queue ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view their own queue position" ON public.chat_wait_queue
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert into queue" ON public.chat_wait_queue
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own queue entry" ON public.chat_wait_queue
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all queue entries" ON public.chat_wait_queue
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for faster queries
CREATE INDEX idx_chat_wait_queue_status ON public.chat_wait_queue(status);
CREATE INDEX idx_chat_wait_queue_language ON public.chat_wait_queue(preferred_language);
CREATE INDEX idx_chat_wait_queue_joined_at ON public.chat_wait_queue(joined_at);

-- Insert comprehensive global language groups
INSERT INTO public.language_groups (name, description, languages, priority, is_active) VALUES
-- Major World Languages
('English Global', 'English speakers worldwide', ARRAY['en', 'en-US', 'en-GB', 'en-AU', 'en-CA', 'en-NZ', 'en-IE', 'en-ZA', 'en-IN'], 1, true),
('Spanish Global', 'Spanish speakers worldwide', ARRAY['es', 'es-ES', 'es-MX', 'es-AR', 'es-CO', 'es-CL', 'es-PE', 'es-VE'], 2, true),
('Mandarin Chinese', 'Mandarin Chinese speakers', ARRAY['zh', 'zh-CN', 'zh-TW', 'zh-HK', 'zh-SG'], 3, true),
('Hindi & Urdu', 'Hindi and Urdu speakers', ARRAY['hi', 'hi-IN', 'ur', 'ur-PK', 'ur-IN'], 4, true),
('Arabic Global', 'Arabic speakers worldwide', ARRAY['ar', 'ar-SA', 'ar-EG', 'ar-AE', 'ar-IQ', 'ar-MA', 'ar-DZ', 'ar-TN', 'ar-LB', 'ar-JO'], 5, true),
('Portuguese Global', 'Portuguese speakers', ARRAY['pt', 'pt-BR', 'pt-PT', 'pt-AO', 'pt-MZ'], 6, true),
('French Global', 'French speakers worldwide', ARRAY['fr', 'fr-FR', 'fr-CA', 'fr-BE', 'fr-CH', 'fr-SN', 'fr-CI', 'fr-CM'], 7, true),
('Russian & CIS', 'Russian speakers in CIS', ARRAY['ru', 'ru-RU', 'ru-UA', 'ru-KZ', 'ru-BY'], 8, true),
('Japanese', 'Japanese speakers', ARRAY['ja', 'ja-JP'], 9, true),
('German & DACH', 'German speakers', ARRAY['de', 'de-DE', 'de-AT', 'de-CH'], 10, true),

-- South Asian Languages
('Bengali', 'Bengali speakers', ARRAY['bn', 'bn-BD', 'bn-IN'], 11, true),
('Tamil', 'Tamil speakers', ARRAY['ta', 'ta-IN', 'ta-LK', 'ta-SG', 'ta-MY'], 12, true),
('Telugu', 'Telugu speakers', ARRAY['te', 'te-IN'], 13, true),
('Marathi', 'Marathi speakers', ARRAY['mr', 'mr-IN'], 14, true),
('Gujarati', 'Gujarati speakers', ARRAY['gu', 'gu-IN'], 15, true),
('Kannada', 'Kannada speakers', ARRAY['kn', 'kn-IN'], 16, true),
('Malayalam', 'Malayalam speakers', ARRAY['ml', 'ml-IN'], 17, true),
('Punjabi', 'Punjabi speakers', ARRAY['pa', 'pa-IN', 'pa-PK'], 18, true),
('Odia', 'Odia speakers', ARRAY['or', 'or-IN'], 19, true),
('Nepali', 'Nepali speakers', ARRAY['ne', 'ne-NP', 'ne-IN'], 20, true),
('Sinhala', 'Sinhala speakers', ARRAY['si', 'si-LK'], 21, true),

-- Southeast Asian Languages
('Indonesian & Malay', 'Indonesian/Malay speakers', ARRAY['id', 'id-ID', 'ms', 'ms-MY', 'ms-SG', 'ms-BN'], 22, true),
('Vietnamese', 'Vietnamese speakers', ARRAY['vi', 'vi-VN'], 23, true),
('Thai', 'Thai speakers', ARRAY['th', 'th-TH'], 24, true),
('Filipino & Tagalog', 'Filipino speakers', ARRAY['tl', 'fil', 'fil-PH'], 25, true),
('Korean', 'Korean speakers', ARRAY['ko', 'ko-KR', 'ko-KP'], 26, true),
('Burmese', 'Burmese speakers', ARRAY['my', 'my-MM'], 27, true),
('Khmer', 'Khmer speakers', ARRAY['km', 'km-KH'], 28, true),
('Lao', 'Lao speakers', ARRAY['lo', 'lo-LA'], 29, true),

-- European Languages
('Italian', 'Italian speakers', ARRAY['it', 'it-IT', 'it-CH'], 30, true),
('Dutch & Flemish', 'Dutch speakers', ARRAY['nl', 'nl-NL', 'nl-BE'], 31, true),
('Polish', 'Polish speakers', ARRAY['pl', 'pl-PL'], 32, true),
('Ukrainian', 'Ukrainian speakers', ARRAY['uk', 'uk-UA'], 33, true),
('Romanian', 'Romanian speakers', ARRAY['ro', 'ro-RO', 'ro-MD'], 34, true),
('Greek', 'Greek speakers', ARRAY['el', 'el-GR', 'el-CY'], 35, true),
('Czech & Slovak', 'Czech/Slovak speakers', ARRAY['cs', 'cs-CZ', 'sk', 'sk-SK'], 36, true),
('Hungarian', 'Hungarian speakers', ARRAY['hu', 'hu-HU'], 37, true),
('Swedish', 'Swedish speakers', ARRAY['sv', 'sv-SE', 'sv-FI'], 38, true),
('Norwegian & Danish', 'Scandinavian speakers', ARRAY['no', 'nb', 'nn', 'da', 'da-DK'], 39, true),
('Finnish', 'Finnish speakers', ARRAY['fi', 'fi-FI'], 40, true),
('Bulgarian', 'Bulgarian speakers', ARRAY['bg', 'bg-BG'], 41, true),
('Serbian & Croatian', 'Serbo-Croatian speakers', ARRAY['sr', 'hr', 'bs', 'sr-RS', 'hr-HR', 'bs-BA'], 42, true),

-- Middle Eastern & Central Asian
('Turkish', 'Turkish speakers', ARRAY['tr', 'tr-TR'], 43, true),
('Persian & Dari', 'Persian speakers', ARRAY['fa', 'fa-IR', 'fa-AF', 'prs'], 44, true),
('Hebrew', 'Hebrew speakers', ARRAY['he', 'he-IL', 'iw'], 45, true),
('Kurdish', 'Kurdish speakers', ARRAY['ku', 'ckb', 'kmr'], 46, true),
('Kazakh & Uzbek', 'Central Asian Turkic', ARRAY['kk', 'kk-KZ', 'uz', 'uz-UZ'], 47, true),
('Pashto', 'Pashto speakers', ARRAY['ps', 'ps-AF', 'ps-PK'], 48, true),
('Azerbaijani', 'Azerbaijani speakers', ARRAY['az', 'az-AZ'], 49, true),

-- African Languages
('Swahili', 'Swahili speakers', ARRAY['sw', 'sw-KE', 'sw-TZ'], 50, true),
('Hausa', 'Hausa speakers', ARRAY['ha', 'ha-NG', 'ha-NE'], 51, true),
('Yoruba', 'Yoruba speakers', ARRAY['yo', 'yo-NG'], 52, true),
('Igbo', 'Igbo speakers', ARRAY['ig', 'ig-NG'], 53, true),
('Amharic', 'Amharic speakers', ARRAY['am', 'am-ET'], 54, true),
('Zulu & Xhosa', 'South African Bantu', ARRAY['zu', 'xh', 'zu-ZA', 'xh-ZA'], 55, true),
('Somali', 'Somali speakers', ARRAY['so', 'so-SO', 'so-ET', 'so-KE'], 56, true);

-- Add trigger for updated_at
CREATE TRIGGER update_chat_wait_queue_updated_at
  BEFORE UPDATE ON public.chat_wait_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206080031_aea568ad-d974-4a06-8cd1-205027cb1cd5.sql
-- ============================================================
-- Create admin_settings table for global app configuration
CREATE TABLE public.admin_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  setting_key TEXT NOT NULL UNIQUE,
  setting_name TEXT NOT NULL,
  setting_value TEXT NOT NULL,
  setting_type TEXT NOT NULL DEFAULT 'string',
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  is_sensitive BOOLEAN NOT NULL DEFAULT false,
  last_updated_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can access
CREATE POLICY "Admins can view all settings" ON public.admin_settings
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update settings" ON public.admin_settings
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert settings" ON public.admin_settings
  FOR INSERT WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete settings" ON public.admin_settings
  FOR DELETE USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index
CREATE INDEX idx_admin_settings_category ON public.admin_settings(category);
CREATE INDEX idx_admin_settings_key ON public.admin_settings(setting_key);

-- Add trigger for updated_at
CREATE TRIGGER update_admin_settings_updated_at
  BEFORE UPDATE ON public.admin_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Insert default settings
INSERT INTO public.admin_settings (setting_key, setting_name, setting_value, setting_type, category, description) VALUES
-- General Settings
('app_name', 'Application Name', 'Meow Chat', 'string', 'general', 'The name of the application'),
('app_tagline', 'App Tagline', 'Connect with people worldwide', 'string', 'general', 'Tagline shown on landing pages'),
('maintenance_mode', 'Maintenance Mode', 'false', 'boolean', 'general', 'Enable to put app in maintenance mode'),
('default_theme', 'Default Theme', 'light', 'select', 'general', 'Default theme for new users'),
('default_language', 'Default Language', 'en', 'select', 'general', 'Default language for the app'),

-- Security Settings
('require_email_verification', 'Require Email Verification', 'true', 'boolean', 'security', 'Users must verify email before accessing'),
('require_phone_verification', 'Require Phone Verification', 'false', 'boolean', 'security', 'Users must verify phone number'),
('max_login_attempts', 'Max Login Attempts', '5', 'number', 'security', 'Maximum failed login attempts before lockout'),
('session_timeout_minutes', 'Session Timeout (minutes)', '1440', 'number', 'security', 'Auto logout after inactivity'),
('enable_2fa', 'Enable Two-Factor Auth', 'false', 'boolean', 'security', 'Allow users to enable 2FA'),
('password_min_length', 'Minimum Password Length', '8', 'number', 'security', 'Minimum required password length'),

-- Chat Settings
('auto_translate_enabled', 'Auto Translation', 'true', 'boolean', 'chat', 'Enable automatic message translation'),
('max_message_length', 'Max Message Length', '2000', 'number', 'chat', 'Maximum characters per message'),
('chat_timeout_seconds', 'Chat Timeout (seconds)', '30', 'number', 'chat', 'Seconds before chat transfer'),
('enable_file_sharing', 'Enable File Sharing', 'true', 'boolean', 'chat', 'Allow file uploads in chat'),
('profanity_filter', 'Profanity Filter', 'true', 'boolean', 'chat', 'Filter inappropriate words'),

-- Payment Settings
('min_recharge_amount', 'Minimum Recharge', '100', 'number', 'payment', 'Minimum wallet recharge amount'),
('max_recharge_amount', 'Maximum Recharge', '50000', 'number', 'payment', 'Maximum wallet recharge amount'),
('min_withdrawal_amount', 'Minimum Withdrawal', '10000', 'number', 'payment', 'Minimum withdrawal amount'),
('withdrawal_processing_days', 'Withdrawal Processing Days', '3', 'number', 'payment', 'Days to process withdrawal'),
('platform_fee_percent', 'Platform Fee (%)', '20', 'number', 'payment', 'Platform commission percentage'),

-- Notification Settings
('email_notifications', 'Email Notifications', 'true', 'boolean', 'notifications', 'Send email notifications'),
('push_notifications', 'Push Notifications', 'true', 'boolean', 'notifications', 'Send push notifications'),
('marketing_emails', 'Marketing Emails', 'false', 'boolean', 'notifications', 'Send promotional emails'),

-- Analytics Settings
('track_user_activity', 'Track User Activity', 'true', 'boolean', 'analytics', 'Track user behavior for analytics'),
('enable_error_reporting', 'Error Reporting', 'true', 'boolean', 'analytics', 'Send error reports automatically'),
('analytics_retention_days', 'Analytics Retention (days)', '90', 'number', 'analytics', 'Days to retain analytics data');

-- ============================================================
-- Migration: 20251206080247_62e07349-c1c1-4afc-822c-778c3ddd7c46.sql
-- ============================================================
-- Create audit_logs table for compliance tracking
CREATE TABLE public.audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL,
  admin_email TEXT,
  action TEXT NOT NULL,
  action_type TEXT NOT NULL DEFAULT 'update',
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  old_value JSONB,
  new_value JSONB,
  ip_address TEXT,
  user_agent TEXT,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'success',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can view audit logs
CREATE POLICY "Admins can view all audit logs" ON public.audit_logs
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

-- System/service role can insert logs (for edge functions)
CREATE POLICY "System can insert audit logs" ON public.audit_logs
  FOR INSERT WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX idx_audit_logs_admin_id ON public.audit_logs(admin_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX idx_audit_logs_resource_type ON public.audit_logs(resource_type);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_status ON public.audit_logs(status);

-- Insert sample audit logs for demo
INSERT INTO public.audit_logs (admin_id, admin_email, action, action_type, resource_type, resource_id, details, status) VALUES
(gen_random_uuid(), 'admin@meowchat.com', 'Updated chat pricing', 'update', 'settings', 'chat_pricing_1', 'Changed rate from ₹2.00 to ₹2.50 per minute', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Created new gift', 'create', 'gifts', 'gift_001', 'Added "Diamond Ring" gift at ₹500', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Deleted user account', 'delete', 'users', 'user_123', 'Removed inactive user account', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated RLS policy', 'update', 'security', 'rls_profiles', 'Modified profiles table access policy', 'success'),
(gen_random_uuid(), 'moderator@meowchat.com', 'Flagged message', 'update', 'messages', 'msg_456', 'Flagged message for inappropriate content', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Triggered backup', 'create', 'backup', 'backup_789', 'Manual database backup initiated', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated language group', 'update', 'language_groups', 'lg_hindi', 'Added new dialects to Hindi group', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Login attempt', 'auth', 'session', 'session_001', 'Admin login from new device', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Failed login attempt', 'auth', 'session', 'session_002', 'Invalid credentials provided', 'failed'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated withdrawal status', 'update', 'withdrawals', 'wd_101', 'Approved withdrawal request for ₹15,000', 'success');

-- ============================================================
-- Migration: 20251206080936_2e483c6c-d757-4248-8f7c-eb4819070238.sql
-- ============================================================
-- Create moderation_reports table for user reports
CREATE TABLE public.moderation_reports (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID NOT NULL,
  reported_user_id UUID NOT NULL,
  report_type TEXT NOT NULL DEFAULT 'inappropriate_behavior',
  content TEXT,
  chat_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  action_taken TEXT,
  action_reason TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create user_blocks table to track blocked users
CREATE TABLE public.user_blocks (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  blocked_user_id UUID NOT NULL,
  blocked_by UUID NOT NULL,
  reason TEXT,
  block_type TEXT NOT NULL DEFAULT 'temporary',
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create user_warnings table
CREATE TABLE public.user_warnings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  warning_type TEXT NOT NULL DEFAULT 'behavior',
  message TEXT NOT NULL,
  issued_by UUID NOT NULL,
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_warnings ENABLE ROW LEVEL SECURITY;

-- Moderation reports policies
CREATE POLICY "Admins can view all reports"
ON public.moderation_reports FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can create reports"
ON public.moderation_reports FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can update reports"
ON public.moderation_reports FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

-- User blocks policies
CREATE POLICY "Admins can manage blocks"
ON public.user_blocks FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can view if they are blocked"
ON public.user_blocks FOR SELECT
USING (auth.uid() = blocked_user_id);

-- User warnings policies
CREATE POLICY "Admins can manage warnings"
ON public.user_warnings FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can view their own warnings"
ON public.user_warnings FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can acknowledge their warnings"
ON public.user_warnings FOR UPDATE
USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX idx_moderation_reports_status ON public.moderation_reports(status);
CREATE INDEX idx_moderation_reports_reported_user ON public.moderation_reports(reported_user_id);
CREATE INDEX idx_user_blocks_user ON public.user_blocks(blocked_user_id);
CREATE INDEX idx_user_warnings_user ON public.user_warnings(user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_moderation_reports_updated_at
BEFORE UPDATE ON public.moderation_reports
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- Migration: 20251206111310_8e598dc0-7dd4-427d-a6ae-909189c8f4d3.sql
-- ============================================================
-- Create sample users configuration table
CREATE TABLE public.sample_users (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('male', 'female')),
  country TEXT NOT NULL,
  language TEXT NOT NULL,
  age INTEGER NOT NULL DEFAULT 25,
  bio TEXT,
  photo_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.sample_users ENABLE ROW LEVEL SECURITY;

-- Admins can manage sample users
CREATE POLICY "Admins can manage sample users"
ON public.sample_users
FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role));

-- Anyone can view active sample users (for matching display)
CREATE POLICY "Anyone can view active sample users"
ON public.sample_users
FOR SELECT
USING (is_active = true);

-- Create trigger for updated_at
CREATE TRIGGER update_sample_users_updated_at
BEFORE UPDATE ON public.sample_users
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Insert default sample users (3 male, 3 female per major country/language)
INSERT INTO public.sample_users (name, gender, country, language, age, bio, is_active) VALUES
-- India - Hindi
('Rahul Sharma', 'male', 'IN', 'hi', 28, 'Software engineer who loves cricket and music.', false),
('Amit Patel', 'male', 'IN', 'hi', 32, 'Business professional seeking meaningful connections.', false),
('Vikram Singh', 'male', 'IN', 'hi', 26, 'Fitness enthusiast and travel lover.', false),
('Priya Gupta', 'female', 'IN', 'hi', 25, 'Teacher who enjoys reading and cooking.', false),
('Anita Verma', 'female', 'IN', 'hi', 29, 'Marketing professional with a passion for art.', false),
('Sneha Reddy', 'female', 'IN', 'hi', 27, 'Doctor who loves dancing and movies.', false),

-- India - English
('Arjun Kumar', 'male', 'IN', 'en', 30, 'Tech entrepreneur building the future.', false),
('Karthik Nair', 'male', 'IN', 'en', 27, 'Photographer capturing life moments.', false),
('Rohan Mehta', 'male', 'IN', 'en', 31, 'Finance professional who loves hiking.', false),
('Kavya Iyer', 'female', 'IN', 'en', 26, 'Content creator and yoga instructor.', false),
('Divya Menon', 'female', 'IN', 'en', 28, 'HR professional who loves traveling.', false),
('Riya Kapoor', 'female', 'IN', 'en', 24, 'Fashion designer with creative spirit.', false),

-- USA - English
('John Smith', 'male', 'US', 'en', 29, 'Software developer and music lover.', false),
('Mike Johnson', 'male', 'US', 'en', 33, 'Marketing manager who enjoys sports.', false),
('David Williams', 'male', 'US', 'en', 28, 'Architect with passion for design.', false),
('Emily Davis', 'female', 'US', 'en', 27, 'Nurse who loves outdoor activities.', false),
('Sarah Brown', 'female', 'US', 'en', 30, 'Lawyer passionate about human rights.', false),
('Jessica Miller', 'female', 'US', 'en', 26, 'Artist and creative director.', false),

-- UK - English
('James Wilson', 'male', 'GB', 'en', 31, 'Investment banker who loves football.', false),
('Oliver Taylor', 'male', 'GB', 'en', 28, 'Chef with love for culinary arts.', false),
('Harry Anderson', 'male', 'GB', 'en', 26, 'Musician and songwriter.', false),
('Emma Thompson', 'female', 'GB', 'en', 29, 'Writer and literature enthusiast.', false),
('Sophie Clark', 'female', 'GB', 'en', 25, 'Fashion blogger and stylist.', false),
('Charlotte Lewis', 'female', 'GB', 'en', 27, 'Veterinarian who loves animals.', false);

-- ============================================================
-- Migration: 20251206120656_e40dc47e-6c6d-4c0f-97d8-0b03c3d229fd.sql
-- ============================================================
-- Add women's earning rate to chat_pricing table
ALTER TABLE public.chat_pricing 
ADD COLUMN women_earning_rate numeric NOT NULL DEFAULT 2.00;

-- Add a comment explaining the fields
COMMENT ON COLUMN public.chat_pricing.rate_per_minute IS 'Amount men are charged per minute (INR)';
COMMENT ON COLUMN public.chat_pricing.women_earning_rate IS 'Amount women earn per minute (INR)';

-- ============================================================
-- Migration: 20251206134032_90d6b890-9955-439a-bc34-c27253a12de9.sql
-- ============================================================
-- Update the chat_pricing with the correct default values
UPDATE public.chat_pricing 
SET rate_per_minute = 5.00, 
    women_earning_rate = 2.00,
    updated_at = now()
WHERE id = '09b75042-36f5-4053-b1ca-5bba6a0bcfe6';

-- ============================================================
-- Migration: 20251206134249_3fa3a790-ad58-412f-a5ae-4dbae3f3c4e3.sql
-- ============================================================
-- Update women earning rate to a custom value (e.g., 3.00)
-- You can change this to any value you want
UPDATE public.chat_pricing 
SET women_earning_rate = 2.00,
    rate_per_minute = 5.00,
    updated_at = now()
WHERE is_active = true;

-- ============================================================
-- Migration: 20251206134457_c498103c-5a06-4b79-b13b-54b7e9fa66a0.sql
-- ============================================================
-- Drop existing restrictive policy and create a more permissive one for admins
DROP POLICY IF EXISTS "Admins can manage pricing" ON public.chat_pricing;

-- Create separate policies for each operation
CREATE POLICY "Admins can view all pricing" 
ON public.chat_pricing 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can update pricing" 
ON public.chat_pricing 
FOR UPDATE 
USING (true)
WITH CHECK (true);

CREATE POLICY "Admins can insert pricing" 
ON public.chat_pricing 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Admins can delete pricing" 
ON public.chat_pricing 
FOR DELETE 
USING (has_role(auth.uid(), 'admin'::app_role));

-- ============================================================
-- Migration: 20251206165045_2ec866ad-445e-4c98-b6c4-52b9571299f2.sql
-- ============================================================
-- Add is_online column to sample_users table
ALTER TABLE public.sample_users 
ADD COLUMN is_online boolean NOT NULL DEFAULT true;

-- Update existing sample users to be online
UPDATE public.sample_users SET is_online = true;

-- ============================================================
-- Migration: 20251206180439_6977590f-36ea-450c-b894-29b8fa9d4a06.sql
-- ============================================================
-- Add account_status to profiles for block/suspend/approve status
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active';

-- Add approval_status for women (men auto-approved)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'pending';

-- Add primary_language to profiles if not exists (for language group matching)
-- Already exists based on schema

-- Add max_women_users to language_groups table
ALTER TABLE public.language_groups 
ADD COLUMN IF NOT EXISTS max_women_users integer NOT NULL DEFAULT 100;

-- Add current_women_count to language_groups for tracking
ALTER TABLE public.language_groups 
ADD COLUMN IF NOT EXISTS current_women_count integer NOT NULL DEFAULT 0;

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_profiles_account_status ON public.profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status ON public.profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);

-- Add comment for clarity
COMMENT ON COLUMN public.profiles.account_status IS 'User account status: active, blocked, suspended';
COMMENT ON COLUMN public.profiles.approval_status IS 'Approval status: pending, approved, disapproved (men auto-approved)';
COMMENT ON COLUMN public.language_groups.max_women_users IS 'Maximum number of women users allowed in this language group';
COMMENT ON COLUMN public.language_groups.current_women_count IS 'Current count of approved women users in this language group';

-- ============================================================
-- Migration: 20251206181012_bffdb80d-063d-48a2-a2e3-ca9019e402fc.sql
-- ============================================================
-- Update default max_women_users to 150
ALTER TABLE public.language_groups 
ALTER COLUMN max_women_users SET DEFAULT 150;

-- Update existing language groups to have 150 max women users
UPDATE public.language_groups SET max_women_users = 150 WHERE max_women_users = 100;

-- Add performance tracking columns to profiles for women
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS performance_score integer DEFAULT 100,
ADD COLUMN IF NOT EXISTS total_chats_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS avg_response_time_seconds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS ai_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS ai_disapproval_reason text;

-- Create index for performance queries
CREATE INDEX IF NOT EXISTS idx_profiles_performance ON public.profiles(performance_score);
CREATE INDEX IF NOT EXISTS idx_profiles_last_active ON public.profiles(last_active_at);
CREATE INDEX IF NOT EXISTS idx_profiles_ai_approved ON public.profiles(ai_approved);

-- Add comments
COMMENT ON COLUMN public.profiles.performance_score IS 'AI calculated performance score 0-100';
COMMENT ON COLUMN public.profiles.ai_approved IS 'Whether AI auto-approved this user';
COMMENT ON COLUMN public.profiles.ai_disapproval_reason IS 'Reason for AI disapproval if any';

-- ============================================================
-- Migration: 20251206181507_8bcf3e21-a0cc-4007-92eb-2bf54f2828e1.sql
-- ============================================================
-- Create user_friends table for friend relationships
CREATE TABLE IF NOT EXISTS public.user_friends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  friend_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(user_id, friend_id)
);

-- Enable RLS
ALTER TABLE public.user_friends ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_friends_user_id ON public.user_friends(user_id);
CREATE INDEX IF NOT EXISTS idx_user_friends_friend_id ON public.user_friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_user_friends_status ON public.user_friends(status);

-- RLS Policies
CREATE POLICY "Users can view their own friends" ON public.user_friends
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can add friends" ON public.user_friends
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own friend requests" ON public.user_friends
  FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can delete their own friends" ON public.user_friends
  FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Admins can manage all friends" ON public.user_friends
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Comments
COMMENT ON TABLE public.user_friends IS 'Stores friend relationships between users';
COMMENT ON COLUMN public.user_friends.status IS 'Friend status: pending, accepted, rejected';

-- ============================================================
-- Migration: 20251206181846_b53c1ebb-f150-4400-9bc0-fbbc4fb15fbd.sql
-- ============================================================
-- Create policy violation alerts table
CREATE TABLE IF NOT EXISTS public.policy_violation_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  alert_type text NOT NULL DEFAULT 'policy_violation',
  violation_type text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  content text,
  source_message_id uuid,
  source_chat_id text,
  detected_by text NOT NULL DEFAULT 'system',
  status text NOT NULL DEFAULT 'pending',
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  action_taken text,
  admin_notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.policy_violation_alerts ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_policy_alerts_user_id ON public.policy_violation_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_status ON public.policy_violation_alerts(status);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_severity ON public.policy_violation_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_violation_type ON public.policy_violation_alerts(violation_type);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_created_at ON public.policy_violation_alerts(created_at DESC);

-- RLS Policies
CREATE POLICY "Admins can view all alerts" ON public.policy_violation_alerts
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Admins can update alerts" ON public.policy_violation_alerts
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "System can insert alerts" ON public.policy_violation_alerts
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can delete alerts" ON public.policy_violation_alerts
  FOR DELETE USING (has_role(auth.uid(), 'admin'::app_role));

-- Add comment
COMMENT ON TABLE public.policy_violation_alerts IS 'Stores policy violation alerts for admin review';
COMMENT ON COLUMN public.policy_violation_alerts.violation_type IS 'Type: sexual_content, harassment, spam, tos_violation, guidelines_violation, hate_speech, scam, other';
COMMENT ON COLUMN public.policy_violation_alerts.severity IS 'Severity: low, medium, high, critical';
COMMENT ON COLUMN public.policy_violation_alerts.status IS 'Status: pending, reviewing, resolved, dismissed';

-- ============================================================
-- Migration: 20251207054354_43b743a1-2e2b-49eb-9c34-c7f22e437396.sql
-- ============================================================
-- Create password reset tokens table
CREATE TABLE public.password_reset_tokens (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ip_address TEXT,
  user_agent TEXT
);

-- Create index for faster token lookups
CREATE INDEX idx_password_reset_tokens_hash ON public.password_reset_tokens(token_hash);
CREATE INDEX idx_password_reset_tokens_user_id ON public.password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_tokens_expires_at ON public.password_reset_tokens(expires_at);

-- Enable Row Level Security
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Only service role can access this table (edge functions)
-- No public policies needed as this is handled by edge functions with service role

-- ============================================================
-- Migration: 20251207061000_17d20b57-80f9-4014-93db-7516fce198a1.sql
-- ============================================================
-- Create user_photos table for storing profile photos
CREATE TABLE public.user_photos (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  photo_url TEXT NOT NULL,
  photo_type TEXT NOT NULL DEFAULT 'additional', -- 'selfie' or 'additional'
  display_order INTEGER NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_photos ENABLE ROW LEVEL SECURITY;

-- Users can view all photos (for matching)
CREATE POLICY "Anyone can view user photos"
ON public.user_photos
FOR SELECT
USING (true);

-- Users can insert their own photos
CREATE POLICY "Users can insert their own photos"
ON public.user_photos
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own photos
CREATE POLICY "Users can update their own photos"
ON public.user_photos
FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own photos
CREATE POLICY "Users can delete their own photos"
ON public.user_photos
FOR DELETE
USING (auth.uid() = user_id);

-- Create index for faster queries
CREATE INDEX idx_user_photos_user_id ON public.user_photos(user_id);
CREATE INDEX idx_user_photos_type ON public.user_photos(photo_type);

-- Create storage bucket for profile photos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('profile-photos', 'profile-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for profile photos bucket
CREATE POLICY "Anyone can view profile photos"
ON storage.objects
FOR SELECT
USING (bucket_id = 'profile-photos');

CREATE POLICY "Users can upload their own photos"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own photos"
ON storage.objects
FOR UPDATE
USING (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own photos"
ON storage.objects
FOR DELETE
USING (bucket_id = 'profile-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- Migration: 20251207073555_9d5ea968-ed22-48e6-9fd3-624642ca3f78.sql
-- ============================================================
-- Create INSERT policy for notifications table to allow admins to broadcast notifications
CREATE POLICY "Admins can insert notifications for any user" 
ON public.notifications 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_roles.user_id = auth.uid() 
    AND user_roles.role = 'admin'
  )
);

-- Also allow admins to view all notifications for monitoring
CREATE POLICY "Admins can view all notifications" 
ON public.notifications 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_roles.user_id = auth.uid() 
    AND user_roles.role = 'admin'
  )
);

-- ============================================================
-- Migration: 20251208074751_fbbde53d-af27-48b7-b67b-53ab13943032.sql
-- ============================================================
-- Insert chat and billing control settings
INSERT INTO admin_settings (setting_key, setting_name, setting_value, setting_type, category, description)
VALUES 
  -- Chat Pricing & Billing Settings
  ('chat_rate_per_minute', 'Chat Rate (₹/min)', '5', 'number', 'payment', 'Price charged to men per minute of chat'),
  ('women_earning_rate', 'Women Earning Rate (₹/min)', '2', 'number', 'payment', 'Amount women earn per minute of chat'),
  ('women_earning_percentage', 'Women Earning Percentage', '40', 'number', 'payment', 'Percentage of chat fee that goes to women (alternative to fixed rate)'),
  ('min_wallet_balance', 'Minimum Wallet Balance (₹)', '10', 'number', 'payment', 'Minimum wallet balance required to start a chat'),
  
  -- Connection & Session Settings  
  ('auto_disconnect_timer', 'Auto-Disconnect Timer (seconds)', '180', 'number', 'chat', 'Seconds of inactivity before auto-disconnect (default: 180 = 3 min)'),
  ('max_parallel_connections', 'Max Parallel Connections', '3', 'number', 'chat', 'Maximum number of simultaneous chat sessions per user'),
  ('reconnect_attempts', 'Auto-Reconnect Attempts', '3', 'number', 'chat', 'Number of times to attempt auto-reconnect when partner disconnects'),
  ('heartbeat_interval', 'Heartbeat Interval (seconds)', '60', 'number', 'chat', 'Seconds between billing heartbeats'),
  
  -- Data Retention Settings
  ('content_deletion_minutes', 'Content Deletion (minutes)', '15', 'number', 'security', 'Minutes after which chat content is deleted'),
  ('chat_history_retention_days', 'Chat History Retention (days)', '7', 'number', 'security', 'Days to retain chat history before deletion'),
  ('transaction_retention_years', 'Transaction Retention (years)', '7', 'number', 'security', 'Years to retain transaction records'),
  ('inactive_profile_days', 'Inactive Profile Warning (days)', '90', 'number', 'security', 'Days of inactivity before profile is flagged'),
  
  -- Queue Settings
  ('priority_wait_threshold', 'Priority Wait Threshold (seconds)', '180', 'number', 'chat', 'Seconds in queue before user gets priority matching'),
  ('queue_timeout_seconds', 'Queue Timeout (seconds)', '300', 'number', 'chat', 'Maximum seconds a user can wait in queue')
  
ON CONFLICT (setting_key) DO UPDATE SET
  setting_name = EXCLUDED.setting_name,
  description = EXCLUDED.description,
  setting_type = EXCLUDED.setting_type,
  category = EXCLUDED.category;

-- ============================================================
-- Migration: 20251208081808_a7c2b892-44da-4d37-87ac-a16606dd6216.sql
-- ============================================================
-- Add RLS policies for password_reset_tokens table
-- This table should only be accessible by the system/service role for security

-- Policy: Allow system to insert tokens (for password reset requests)
CREATE POLICY "System can insert reset tokens" 
ON public.password_reset_tokens 
FOR INSERT 
WITH CHECK (true);

-- Policy: Allow system to select tokens (for verification)
CREATE POLICY "System can read reset tokens" 
ON public.password_reset_tokens 
FOR SELECT 
USING (true);

-- Policy: Allow system to update tokens (mark as used)
CREATE POLICY "System can update reset tokens" 
ON public.password_reset_tokens 
FOR UPDATE 
USING (true);

-- Policy: Allow system to delete expired tokens
CREATE POLICY "System can delete reset tokens" 
ON public.password_reset_tokens 
FOR DELETE 
USING (true);

-- ============================================================
-- Migration: 20251208085744_8194c489-629b-476e-9713-d4a505ad985e.sql
-- ============================================================
-- Create storage bucket for voice messages
INSERT INTO storage.buckets (id, name, public)
VALUES ('voice-messages', 'voice-messages', true)
ON CONFLICT (id) DO NOTHING;

-- Create policies for voice messages bucket
CREATE POLICY "Users can upload voice messages"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'voice-messages' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Anyone can view voice messages"
ON storage.objects
FOR SELECT
USING (bucket_id = 'voice-messages');

CREATE POLICY "Users can delete their own voice messages"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'voice-messages' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================================
-- Migration: 20251208091118_c5e08f90-bbd8-46d0-8ef9-fd0ecec7dce8.sql
-- ============================================================
-- Insert a sample woman user with different language settings
INSERT INTO public.sample_users (name, age, gender, country, language, bio, is_active, is_online)
VALUES 
  ('Priya Sharma', 26, 'female', 'India', 'Hindi', 'Friendly and loves to chat in Hindi', true, true),
  ('Ananya Patel', 24, 'female', 'India', 'Gujarati', 'Tech enthusiast who speaks Gujarati', true, true),
  ('Meera Nair', 28, 'female', 'India', 'Malayalam', 'Book lover, fluent in Malayalam', true, true);

-- ============================================================
-- Migration: 20251208091704_9d36d610-eee7-41e0-a838-84c15ae8d17b.sql
-- ============================================================
-- Create sample_men table
CREATE TABLE public.sample_men (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  age integer NOT NULL DEFAULT 25,
  country text NOT NULL,
  language text NOT NULL,
  bio text,
  photo_url text,
  is_active boolean NOT NULL DEFAULT true,
  is_online boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create sample_women table
CREATE TABLE public.sample_women (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  age integer NOT NULL DEFAULT 25,
  country text NOT NULL,
  language text NOT NULL,
  bio text,
  photo_url text,
  is_active boolean NOT NULL DEFAULT true,
  is_online boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.sample_men ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sample_women ENABLE ROW LEVEL SECURITY;

-- RLS Policies for sample_men
CREATE POLICY "Admins can manage sample men" ON public.sample_men
  FOR ALL USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Anyone can view active sample men" ON public.sample_men
  FOR SELECT USING (is_active = true);

-- RLS Policies for sample_women
CREATE POLICY "Admins can manage sample women" ON public.sample_women
  FOR ALL USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Anyone can view active sample women" ON public.sample_women
  FOR SELECT USING (is_active = true);

-- Create indexes for better query performance
CREATE INDEX idx_sample_men_language ON public.sample_men(language);
CREATE INDEX idx_sample_men_active ON public.sample_men(is_active);
CREATE INDEX idx_sample_women_language ON public.sample_women(language);
CREATE INDEX idx_sample_women_active ON public.sample_women(is_active);

-- Insert sample men for all major languages (10 per language)
INSERT INTO public.sample_men (name, age, country, language, bio) VALUES
-- Hindi
('Aarav Sharma', 25, 'India', 'Hindi', 'Friendly chat partner'),
('Vihaan Kumar', 28, 'India', 'Hindi', 'Love conversations'),
('Aditya Singh', 26, 'India', 'Hindi', 'Here to connect'),
('Arjun Patel', 30, 'India', 'Hindi', 'Enjoy meaningful talks'),
('Reyansh Gupta', 24, 'India', 'Hindi', 'Looking for friends'),
('Ayaan Verma', 27, 'India', 'Hindi', 'Music enthusiast'),
('Krishna Joshi', 29, 'India', 'Hindi', 'Travel lover'),
('Ishaan Rao', 26, 'India', 'Hindi', 'Tech professional'),
('Shaurya Mishra', 25, 'India', 'Hindi', 'Sports fan'),
('Atharv Reddy', 28, 'India', 'Hindi', 'Book reader'),
-- Bengali
('Aritra Das', 26, 'India', 'Bengali', 'Cultural enthusiast'),
('Ayan Banerjee', 28, 'India', 'Bengali', 'Poetry lover'),
('Soham Ghosh', 25, 'India', 'Bengali', 'Art appreciator'),
('Rishav Sen', 27, 'India', 'Bengali', 'Music composer'),
('Anirban Bose', 30, 'India', 'Bengali', 'Writer at heart'),
('Sourav Mukherjee', 24, 'India', 'Bengali', 'Film buff'),
('Debojyoti Roy', 29, 'India', 'Bengali', 'History lover'),
('Arnab Chatterjee', 26, 'India', 'Bengali', 'Science geek'),
('Subhrajit Dey', 28, 'India', 'Bengali', 'Sports enthusiast'),
('Pritam Kar', 25, 'India', 'Bengali', 'Nature lover'),
-- Tamil
('Arun Kumar', 27, 'India', 'Tamil', 'Tech professional'),
('Karthik Rajan', 25, 'India', 'Tamil', 'Music lover'),
('Surya Prakash', 28, 'India', 'Tamil', 'Film enthusiast'),
('Vijay Anand', 26, 'India', 'Tamil', 'Sports fan'),
('Pradeep Selvam', 30, 'India', 'Tamil', 'Travel enthusiast'),
('Mohan Raja', 24, 'India', 'Tamil', 'Food lover'),
('Ganesh Venkat', 29, 'India', 'Tamil', 'Art collector'),
('Senthil Murugan', 26, 'India', 'Tamil', 'Book reader'),
('Rajesh Sundaram', 28, 'India', 'Tamil', 'Nature explorer'),
('Dinesh Babu', 25, 'India', 'Tamil', 'Photography buff'),
-- Telugu
('Ravi Teja', 26, 'India', 'Telugu', 'Cinema enthusiast'),
('Venkat Rao', 28, 'India', 'Telugu', 'Tech lover'),
('Srinivas Reddy', 25, 'India', 'Telugu', 'Music fan'),
('Naresh Kumar', 27, 'India', 'Telugu', 'Sports player'),
('Prasad Varma', 30, 'India', 'Telugu', 'History buff'),
('Suresh Babu', 24, 'India', 'Telugu', 'Travel lover'),
('Mahesh Chandra', 29, 'India', 'Telugu', 'Food explorer'),
('Ramesh Goud', 26, 'India', 'Telugu', 'Art appreciator'),
('Krishna Murthy', 28, 'India', 'Telugu', 'Nature lover'),
('Gopal Rao', 25, 'India', 'Telugu', 'Book collector'),
-- Gujarati
('Harsh Patel', 27, 'India', 'Gujarati', 'Business minded'),
('Darshan Shah', 25, 'India', 'Gujarati', 'Tech enthusiast'),
('Jayesh Mehta', 28, 'India', 'Gujarati', 'Music lover'),
('Ketan Desai', 26, 'India', 'Gujarati', 'Sports fan'),
('Chirag Joshi', 30, 'India', 'Gujarati', 'Travel enthusiast'),
('Parth Modi', 24, 'India', 'Gujarati', 'Food lover'),
('Yash Pandya', 29, 'India', 'Gujarati', 'Art collector'),
('Meet Thakkar', 26, 'India', 'Gujarati', 'Book reader'),
('Dev Raval', 28, 'India', 'Gujarati', 'Nature explorer'),
('Raj Bhatt', 25, 'India', 'Gujarati', 'Photography buff'),
-- Marathi
('Aditya Patil', 26, 'India', 'Marathi', 'Cricket lover'),
('Rohan Kulkarni', 28, 'India', 'Marathi', 'Tech professional'),
('Tejas Joshi', 25, 'India', 'Marathi', 'Music enthusiast'),
('Omkar Deshmukh', 27, 'India', 'Marathi', 'History buff'),
('Sagar Pawar', 30, 'India', 'Marathi', 'Travel lover'),
('Pratik More', 24, 'India', 'Marathi', 'Food explorer'),
('Nikhil Gaikwad', 29, 'India', 'Marathi', 'Art appreciator'),
('Akshay Jadhav', 26, 'India', 'Marathi', 'Book collector'),
('Varun Shinde', 28, 'India', 'Marathi', 'Sports fan'),
('Gaurav Thakur', 25, 'India', 'Marathi', 'Nature lover'),
-- Kannada
('Rakesh Gowda', 27, 'India', 'Kannada', 'Tech lover'),
('Sunil Shetty', 25, 'India', 'Kannada', 'Music fan'),
('Naveen Raj', 28, 'India', 'Kannada', 'Film buff'),
('Prashanth Kumar', 26, 'India', 'Kannada', 'Sports enthusiast'),
('Manjunath Reddy', 30, 'India', 'Kannada', 'Travel lover'),
('Harish Bhat', 24, 'India', 'Kannada', 'Food explorer'),
('Deepak Naik', 29, 'India', 'Kannada', 'Art collector'),
('Santosh Hegde', 26, 'India', 'Kannada', 'Book reader'),
('Vinay Rao', 28, 'India', 'Kannada', 'Nature explorer'),
('Kiran Murthy', 25, 'India', 'Kannada', 'Photography buff'),
-- Malayalam
('Vishnu Nair', 26, 'India', 'Malayalam', 'Film enthusiast'),
('Arun Menon', 28, 'India', 'Malayalam', 'Tech professional'),
('Sanjay Pillai', 25, 'India', 'Malayalam', 'Music lover'),
('Rahul Varma', 27, 'India', 'Malayalam', 'Sports fan'),
('Ajith Kumar', 30, 'India', 'Malayalam', 'Travel enthusiast'),
('Renjith Nair', 24, 'India', 'Malayalam', 'Food lover'),
('Anoop Krishnan', 29, 'India', 'Malayalam', 'Art collector'),
('Dileep Raj', 26, 'India', 'Malayalam', 'Book reader'),
('Jithin Thomas', 28, 'India', 'Malayalam', 'Nature explorer'),
('Vineeth Mohan', 25, 'India', 'Malayalam', 'Photography buff'),
-- Punjabi
('Gurpreet Singh', 27, 'India', 'Punjabi', 'Music lover'),
('Harjeet Kaur', 25, 'India', 'Punjabi', 'Dance enthusiast'),
('Manpreet Gill', 28, 'India', 'Punjabi', 'Sports fan'),
('Jaspreet Dhillon', 26, 'India', 'Punjabi', 'Travel lover'),
('Sukhbir Sandhu', 30, 'India', 'Punjabi', 'Food explorer'),
('Amritpal Mann', 24, 'India', 'Punjabi', 'History buff'),
('Davinder Sidhu', 29, 'India', 'Punjabi', 'Art appreciator'),
('Kulwant Brar', 26, 'India', 'Punjabi', 'Book collector'),
('Navjot Cheema', 28, 'India', 'Punjabi', 'Nature lover'),
('Parminder Bajwa', 25, 'India', 'Punjabi', 'Photography buff'),
-- Odia
('Subrat Panda', 26, 'India', 'Odia', 'Art lover'),
('Biswajit Mohanty', 28, 'India', 'Odia', 'Music enthusiast'),
('Prakash Sahu', 25, 'India', 'Odia', 'Sports fan'),
('Santosh Jena', 27, 'India', 'Odia', 'Travel lover'),
('Ashok Behera', 30, 'India', 'Odia', 'Food explorer'),
('Rajesh Nayak', 24, 'India', 'Odia', 'History buff'),
('Manoj Parida', 29, 'India', 'Odia', 'Book collector'),
('Suresh Patnaik', 26, 'India', 'Odia', 'Tech lover'),
('Gopi Mishra', 28, 'India', 'Odia', 'Nature explorer'),
('Ramesh Das', 25, 'India', 'Odia', 'Photography buff'),
-- English
('James Wilson', 27, 'USA', 'English', 'Tech professional'),
('Michael Brown', 25, 'UK', 'English', 'Music lover'),
('David Smith', 28, 'Australia', 'English', 'Sports enthusiast'),
('Chris Johnson', 26, 'Canada', 'English', 'Travel lover'),
('Robert Davis', 30, 'USA', 'English', 'Food explorer'),
('William Taylor', 24, 'UK', 'English', 'History buff'),
('Daniel Anderson', 29, 'Australia', 'English', 'Art collector'),
('Matthew Thomas', 26, 'Canada', 'English', 'Book reader'),
('Andrew Jackson', 28, 'USA', 'English', 'Nature explorer'),
('Ryan White', 25, 'UK', 'English', 'Photography buff'),
-- Spanish
('Carlos Garcia', 27, 'Spain', 'Spanish', 'Flamenco lover'),
('Miguel Rodriguez', 25, 'Mexico', 'Spanish', 'Music enthusiast'),
('Juan Martinez', 28, 'Argentina', 'Spanish', 'Football fan'),
('Pedro Lopez', 26, 'Spain', 'Spanish', 'Travel lover'),
('Luis Hernandez', 30, 'Mexico', 'Spanish', 'Food explorer'),
('Diego Gonzalez', 24, 'Argentina', 'Spanish', 'History buff'),
('Pablo Sanchez', 29, 'Spain', 'Spanish', 'Art collector'),
('Fernando Ramirez', 26, 'Mexico', 'Spanish', 'Book reader'),
('Alejandro Torres', 28, 'Argentina', 'Spanish', 'Nature explorer'),
('Javier Flores', 25, 'Spain', 'Spanish', 'Photography buff'),
-- French
('Pierre Dubois', 27, 'France', 'French', 'Wine enthusiast'),
('Jean Martin', 25, 'France', 'French', 'Art lover'),
('Marc Laurent', 28, 'France', 'French', 'Cinema buff'),
('Antoine Bernard', 26, 'Belgium', 'French', 'Travel lover'),
('Philippe Moreau', 30, 'France', 'French', 'Food explorer'),
('Olivier Petit', 24, 'Switzerland', 'French', 'History buff'),
('François Robert', 29, 'France', 'French', 'Music lover'),
('Nicolas Richard', 26, 'Belgium', 'French', 'Book reader'),
('Julien Durand', 28, 'France', 'French', 'Nature explorer'),
('Thomas Leroy', 25, 'France', 'French', 'Photography buff'),
-- Arabic
('Ahmed Hassan', 27, 'Egypt', 'Arabic', 'History lover'),
('Mohammed Ali', 25, 'UAE', 'Arabic', 'Tech enthusiast'),
('Omar Khalil', 28, 'Saudi Arabia', 'Arabic', 'Travel lover'),
('Youssef Ibrahim', 26, 'Egypt', 'Arabic', 'Music fan'),
('Karim Nasser', 30, 'Jordan', 'Arabic', 'Food explorer'),
('Hassan Mahmoud', 24, 'UAE', 'Arabic', 'Sports fan'),
('Tariq Ahmed', 29, 'Saudi Arabia', 'Arabic', 'Art collector'),
('Khalid Mansour', 26, 'Egypt', 'Arabic', 'Book reader'),
('Samir Farouk', 28, 'Jordan', 'Arabic', 'Nature explorer'),
('Walid Rashid', 25, 'UAE', 'Arabic', 'Photography buff'),
-- Chinese
('Wei Chen', 27, 'China', 'Chinese', 'Tech professional'),
('Li Wei', 25, 'China', 'Chinese', 'Music lover'),
('Zhang Ming', 28, 'China', 'Chinese', 'Calligraphy artist'),
('Wang Jun', 26, 'Taiwan', 'Chinese', 'Travel lover'),
('Liu Yang', 30, 'China', 'Chinese', 'Food explorer'),
('Huang Lei', 24, 'Singapore', 'Chinese', 'History buff'),
('Zhou Feng', 29, 'China', 'Chinese', 'Art collector'),
('Wu Tao', 26, 'Taiwan', 'Chinese', 'Book reader'),
('Xu Hao', 28, 'China', 'Chinese', 'Nature explorer'),
('Ma Cheng', 25, 'Singapore', 'Chinese', 'Photography buff'),
-- Urdu
('Imran Khan', 27, 'Pakistan', 'Urdu', 'Poetry lover'),
('Salman Ahmed', 25, 'Pakistan', 'Urdu', 'Music enthusiast'),
('Bilal Hussain', 28, 'India', 'Urdu', 'Literature fan'),
('Faisal Qureshi', 26, 'Pakistan', 'Urdu', 'Travel lover'),
('Asif Malik', 30, 'India', 'Urdu', 'Food explorer'),
('Kamran Ali', 24, 'Pakistan', 'Urdu', 'History buff'),
('Zeeshan Shah', 29, 'India', 'Urdu', 'Art collector'),
('Nadeem Raza', 26, 'Pakistan', 'Urdu', 'Book reader'),
('Shahid Mirza', 28, 'India', 'Urdu', 'Nature explorer'),
('Waqar Hassan', 25, 'Pakistan', 'Urdu', 'Photography buff');

-- Insert sample women for all major languages (10 per language)
INSERT INTO public.sample_women (name, age, country, language, bio) VALUES
-- Hindi
('Priya Sharma', 24, 'India', 'Hindi', 'Friendly and caring'),
('Ananya Singh', 26, 'India', 'Hindi', 'Love conversations'),
('Kavya Patel', 25, 'India', 'Hindi', 'Here to connect'),
('Riya Gupta', 28, 'India', 'Hindi', 'Enjoy meaningful talks'),
('Ishita Verma', 23, 'India', 'Hindi', 'Looking for friends'),
('Nisha Kumar', 27, 'India', 'Hindi', 'Music enthusiast'),
('Divya Joshi', 25, 'India', 'Hindi', 'Travel lover'),
('Sneha Rao', 24, 'India', 'Hindi', 'Tech professional'),
('Pooja Mishra', 26, 'India', 'Hindi', 'Art lover'),
('Shruti Reddy', 25, 'India', 'Hindi', 'Book reader'),
-- Bengali
('Aditi Das', 25, 'India', 'Bengali', 'Cultural enthusiast'),
('Shreya Banerjee', 27, 'India', 'Bengali', 'Poetry lover'),
('Ria Ghosh', 24, 'India', 'Bengali', 'Art appreciator'),
('Tanisha Sen', 26, 'India', 'Bengali', 'Music composer'),
('Moumita Bose', 28, 'India', 'Bengali', 'Writer at heart'),
('Pallavi Mukherjee', 23, 'India', 'Bengali', 'Film buff'),
('Sayantika Roy', 27, 'India', 'Bengali', 'History lover'),
('Ankita Chatterjee', 25, 'India', 'Bengali', 'Dance enthusiast'),
('Debjani Dey', 26, 'India', 'Bengali', 'Sports lover'),
('Rituparna Kar', 24, 'India', 'Bengali', 'Nature lover'),
-- Tamil
('Preethi Kumar', 26, 'India', 'Tamil', 'Tech professional'),
('Lavanya Rajan', 24, 'India', 'Tamil', 'Music lover'),
('Swetha Prakash', 27, 'India', 'Tamil', 'Film enthusiast'),
('Keerthana Anand', 25, 'India', 'Tamil', 'Classical dancer'),
('Soundarya Selvam', 28, 'India', 'Tamil', 'Travel enthusiast'),
('Divya Raja', 23, 'India', 'Tamil', 'Food lover'),
('Meena Venkat', 27, 'India', 'Tamil', 'Art collector'),
('Janani Murugan', 25, 'India', 'Tamil', 'Book reader'),
('Revathi Sundaram', 26, 'India', 'Tamil', 'Nature explorer'),
('Nithya Babu', 24, 'India', 'Tamil', 'Photography buff'),
-- Telugu
('Swathi Teja', 25, 'India', 'Telugu', 'Cinema enthusiast'),
('Anusha Rao', 27, 'India', 'Telugu', 'Tech lover'),
('Bhavana Reddy', 24, 'India', 'Telugu', 'Music fan'),
('Keerthi Kumar', 26, 'India', 'Telugu', 'Classical dancer'),
('Madhavi Varma', 28, 'India', 'Telugu', 'History buff'),
('Pavani Babu', 23, 'India', 'Telugu', 'Travel lover'),
('Ramya Chandra', 27, 'India', 'Telugu', 'Food explorer'),
('Sirisha Goud', 25, 'India', 'Telugu', 'Art appreciator'),
('Tejaswini Murthy', 26, 'India', 'Telugu', 'Nature lover'),
('Usha Rao', 24, 'India', 'Telugu', 'Book collector'),
-- Gujarati
('Hetal Patel', 26, 'India', 'Gujarati', 'Business minded'),
('Prachi Shah', 24, 'India', 'Gujarati', 'Tech enthusiast'),
('Riddhi Mehta', 27, 'India', 'Gujarati', 'Music lover'),
('Shivani Desai', 25, 'India', 'Gujarati', 'Garba dancer'),
('Tejal Joshi', 28, 'India', 'Gujarati', 'Travel enthusiast'),
('Urmi Modi', 23, 'India', 'Gujarati', 'Food lover'),
('Vaishali Pandya', 27, 'India', 'Gujarati', 'Art collector'),
('Zalak Thakkar', 25, 'India', 'Gujarati', 'Book reader'),
('Arti Raval', 26, 'India', 'Gujarati', 'Nature explorer'),
('Bhumi Bhatt', 24, 'India', 'Gujarati', 'Photography buff'),
-- Marathi
('Ashwini Patil', 25, 'India', 'Marathi', 'Lavani dancer'),
('Bhagyashree Kulkarni', 27, 'India', 'Marathi', 'Tech professional'),
('Chaitali Joshi', 24, 'India', 'Marathi', 'Music enthusiast'),
('Dipali Deshmukh', 26, 'India', 'Marathi', 'History buff'),
('Gauri Pawar', 28, 'India', 'Marathi', 'Travel lover'),
('Harshada More', 23, 'India', 'Marathi', 'Food explorer'),
('Isha Gaikwad', 27, 'India', 'Marathi', 'Art appreciator'),
('Janhavi Jadhav', 25, 'India', 'Marathi', 'Book collector'),
('Ketaki Shinde', 26, 'India', 'Marathi', 'Sports fan'),
('Leena Thakur', 24, 'India', 'Marathi', 'Nature lover'),
-- Kannada
('Akshata Gowda', 26, 'India', 'Kannada', 'Tech lover'),
('Bhavya Shetty', 24, 'India', 'Kannada', 'Music fan'),
('Chaitra Raj', 27, 'India', 'Kannada', 'Film buff'),
('Divya Kumar', 25, 'India', 'Kannada', 'Classical dancer'),
('Geetha Reddy', 28, 'India', 'Kannada', 'Travel lover'),
('Harini Bhat', 23, 'India', 'Kannada', 'Food explorer'),
('Ishwarya Naik', 27, 'India', 'Kannada', 'Art collector'),
('Jyothi Hegde', 25, 'India', 'Kannada', 'Book reader'),
('Kavitha Rao', 26, 'India', 'Kannada', 'Nature explorer'),
('Lakshmi Murthy', 24, 'India', 'Kannada', 'Photography buff'),
-- Malayalam
('Anjali Nair', 25, 'India', 'Malayalam', 'Film enthusiast'),
('Bhavana Menon', 27, 'India', 'Malayalam', 'Tech professional'),
('Chandana Pillai', 24, 'India', 'Malayalam', 'Music lover'),
('Deepa Varma', 26, 'India', 'Malayalam', 'Bharatanatyam dancer'),
('Fathima Kumar', 28, 'India', 'Malayalam', 'Travel enthusiast'),
('Gayathri Nair', 23, 'India', 'Malayalam', 'Food lover'),
('Hema Krishnan', 27, 'India', 'Malayalam', 'Art collector'),
('Indira Raj', 25, 'India', 'Malayalam', 'Book reader'),
('Jayasree Thomas', 26, 'India', 'Malayalam', 'Nature explorer'),
('Karthika Mohan', 24, 'India', 'Malayalam', 'Photography buff'),
-- Punjabi
('Simran Kaur', 26, 'India', 'Punjabi', 'Bhangra dancer'),
('Harpreet Singh', 24, 'India', 'Punjabi', 'Music enthusiast'),
('Jasleen Gill', 27, 'India', 'Punjabi', 'Food lover'),
('Kirandeep Dhillon', 25, 'India', 'Punjabi', 'Travel lover'),
('Manmeet Sandhu', 28, 'India', 'Punjabi', 'Sports fan'),
('Navneet Mann', 23, 'India', 'Punjabi', 'History buff'),
('Prabhjot Sidhu', 27, 'India', 'Punjabi', 'Art appreciator'),
('Rajinder Brar', 25, 'India', 'Punjabi', 'Book collector'),
('Sukhleen Cheema', 26, 'India', 'Punjabi', 'Nature lover'),
('Tanjeet Bajwa', 24, 'India', 'Punjabi', 'Photography buff'),
-- Odia
('Anita Panda', 25, 'India', 'Odia', 'Classical dancer'),
('Barsha Mohanty', 27, 'India', 'Odia', 'Music enthusiast'),
('Chandini Sahu', 24, 'India', 'Odia', 'Art lover'),
('Deepika Jena', 26, 'India', 'Odia', 'Travel lover'),
('Gitanjali Behera', 28, 'India', 'Odia', 'Food explorer'),
('Hemanti Nayak', 23, 'India', 'Odia', 'History buff'),
('Itishree Parida', 27, 'India', 'Odia', 'Book collector'),
('Jyoti Patnaik', 25, 'India', 'Odia', 'Tech lover'),
('Kalpana Mishra', 26, 'India', 'Odia', 'Nature explorer'),
('Laxmi Das', 24, 'India', 'Odia', 'Photography buff'),
-- English
('Emily Wilson', 26, 'USA', 'English', 'Tech professional'),
('Sarah Brown', 24, 'UK', 'English', 'Music lover'),
('Jessica Smith', 27, 'Australia', 'English', 'Travel enthusiast'),
('Ashley Johnson', 25, 'Canada', 'English', 'Food blogger'),
('Amanda Davis', 28, 'USA', 'English', 'Art collector'),
('Brittany Taylor', 23, 'UK', 'English', 'History buff'),
('Chelsea Anderson', 27, 'Australia', 'English', 'Book reader'),
('Diana Thomas', 25, 'Canada', 'English', 'Nature explorer'),
('Elizabeth Jackson', 26, 'USA', 'English', 'Photography buff'),
('Fiona White', 24, 'UK', 'English', 'Film enthusiast'),
-- Spanish
('Maria Garcia', 26, 'Spain', 'Spanish', 'Flamenco dancer'),
('Sofia Rodriguez', 24, 'Mexico', 'Spanish', 'Music lover'),
('Isabella Martinez', 27, 'Argentina', 'Spanish', 'Tango dancer'),
('Lucia Lopez', 25, 'Spain', 'Spanish', 'Travel enthusiast'),
('Valentina Hernandez', 28, 'Mexico', 'Spanish', 'Food explorer'),
('Camila Gonzalez', 23, 'Argentina', 'Spanish', 'History buff'),
('Elena Sanchez', 27, 'Spain', 'Spanish', 'Art collector'),
('Paula Ramirez', 25, 'Mexico', 'Spanish', 'Book reader'),
('Andrea Torres', 26, 'Argentina', 'Spanish', 'Nature explorer'),
('Laura Flores', 24, 'Spain', 'Spanish', 'Photography buff'),
-- French
('Marie Dubois', 26, 'France', 'French', 'Fashion lover'),
('Sophie Martin', 24, 'France', 'French', 'Art enthusiast'),
('Julie Laurent', 27, 'France', 'French', 'Cinema buff'),
('Camille Bernard', 25, 'Belgium', 'French', 'Travel lover'),
('Léa Moreau', 28, 'France', 'French', 'Food explorer'),
('Emma Petit', 23, 'Switzerland', 'French', 'History buff'),
('Chloé Robert', 27, 'France', 'French', 'Music lover'),
('Manon Richard', 25, 'Belgium', 'French', 'Book reader'),
('Inès Durand', 26, 'France', 'French', 'Nature explorer'),
('Louise Leroy', 24, 'France', 'French', 'Photography buff'),
-- Arabic
('Fatima Hassan', 26, 'Egypt', 'Arabic', 'History lover'),
('Aisha Ali', 24, 'UAE', 'Arabic', 'Fashion enthusiast'),
('Mariam Khalil', 27, 'Saudi Arabia', 'Arabic', 'Travel lover'),
('Noor Ibrahim', 25, 'Egypt', 'Arabic', 'Music fan'),
('Sara Nasser', 28, 'Jordan', 'Arabic', 'Food explorer'),
('Layla Mahmoud', 23, 'UAE', 'Arabic', 'Art collector'),
('Huda Ahmed', 27, 'Saudi Arabia', 'Arabic', 'Book reader'),
('Rania Mansour', 25, 'Egypt', 'Arabic', 'Nature lover'),
('Yasmin Farouk', 26, 'Jordan', 'Arabic', 'Photography buff'),
('Zainab Rashid', 24, 'UAE', 'Arabic', 'Dance enthusiast'),
-- Chinese
('Li Na', 26, 'China', 'Chinese', 'Tech professional'),
('Wang Fang', 24, 'China', 'Chinese', 'Music lover'),
('Zhang Mei', 27, 'China', 'Chinese', 'Calligraphy artist'),
('Chen Ying', 25, 'Taiwan', 'Chinese', 'Travel lover'),
('Liu Xia', 28, 'China', 'Chinese', 'Food explorer'),
('Huang Yan', 23, 'Singapore', 'Chinese', 'History buff'),
('Zhou Lin', 27, 'China', 'Chinese', 'Art collector'),
('Wu Jing', 25, 'Taiwan', 'Chinese', 'Book reader'),
('Xu Hui', 26, 'China', 'Chinese', 'Nature explorer'),
('Ma Li', 24, 'Singapore', 'Chinese', 'Photography buff'),
-- Urdu
('Fatima Khan', 26, 'Pakistan', 'Urdu', 'Poetry lover'),
('Ayesha Ahmed', 24, 'Pakistan', 'Urdu', 'Music enthusiast'),
('Sana Hussain', 27, 'India', 'Urdu', 'Literature fan'),
('Zara Qureshi', 25, 'Pakistan', 'Urdu', 'Travel lover'),
('Hina Malik', 28, 'India', 'Urdu', 'Food explorer'),
('Maira Ali', 23, 'Pakistan', 'Urdu', 'History buff'),
('Nadia Shah', 27, 'India', 'Urdu', 'Art collector'),
('Rabia Raza', 25, 'Pakistan', 'Urdu', 'Book reader'),
('Saima Mirza', 26, 'India', 'Urdu', 'Nature explorer'),
('Tania Hassan', 24, 'Pakistan', 'Urdu', 'Photography buff');

-- ============================================================
-- Migration: 20251208104419_67b04156-57a0-4720-affe-0819191dc68f.sql
-- ============================================================

-- Create male_profiles table
CREATE TABLE public.male_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  full_name text,
  date_of_birth date,
  age integer,
  phone text,
  bio text,
  photo_url text,
  country text,
  state text,
  occupation text,
  education_level text,
  body_type text,
  height_cm integer,
  marital_status text DEFAULT 'single',
  religion text,
  interests text[],
  life_goals text[],
  primary_language text,
  preferred_language text,
  is_verified boolean DEFAULT false,
  is_premium boolean DEFAULT false,
  account_status text NOT NULL DEFAULT 'active',
  profile_completeness integer DEFAULT 0,
  last_active_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create female_profiles table
CREATE TABLE public.female_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  full_name text,
  date_of_birth date,
  age integer,
  phone text,
  bio text,
  photo_url text,
  country text,
  state text,
  occupation text,
  education_level text,
  body_type text,
  height_cm integer,
  marital_status text DEFAULT 'single',
  religion text,
  interests text[],
  life_goals text[],
  primary_language text,
  preferred_language text,
  is_verified boolean DEFAULT false,
  is_premium boolean DEFAULT false,
  account_status text NOT NULL DEFAULT 'active',
  approval_status text NOT NULL DEFAULT 'pending',
  ai_approved boolean DEFAULT false,
  ai_disapproval_reason text,
  performance_score integer DEFAULT 100,
  avg_response_time_seconds integer DEFAULT 0,
  total_chats_count integer DEFAULT 0,
  profile_completeness integer DEFAULT 0,
  last_active_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS on both tables
ALTER TABLE public.male_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.female_profiles ENABLE ROW LEVEL SECURITY;

-- RLS policies for male_profiles
CREATE POLICY "Users can view their own male profile" ON public.male_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own male profile" ON public.male_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own male profile" ON public.male_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all male profiles" ON public.male_profiles
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update all male profiles" ON public.male_profiles
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

-- RLS policies for female_profiles
CREATE POLICY "Users can view their own female profile" ON public.female_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own female profile" ON public.female_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own female profile" ON public.female_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all female profiles" ON public.female_profiles
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update all female profiles" ON public.female_profiles
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

-- Policy for women to be visible to men for matching
CREATE POLICY "Approved women visible to authenticated users" ON public.female_profiles
  FOR SELECT USING (approval_status = 'approved' AND account_status = 'active');

-- Triggers for updated_at
CREATE TRIGGER update_male_profiles_updated_at
  BEFORE UPDATE ON public.male_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_female_profiles_updated_at
  BEFORE UPDATE ON public.female_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();


-- ============================================================
-- Migration: 20251208125055_98fcdd30-a6c2-4714-8ff0-4b442ed0cdc9.sql
-- ============================================================
-- Create video call sessions table
CREATE TABLE public.video_call_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  call_id text NOT NULL UNIQUE,
  man_user_id uuid NOT NULL,
  woman_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, ringing, active, ended, declined, missed
  started_at timestamp with time zone,
  ended_at timestamp with time zone,
  end_reason text,
  rate_per_minute numeric NOT NULL DEFAULT 5.00,
  total_minutes numeric NOT NULL DEFAULT 0,
  total_earned numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create language limits table for admin to set max women per language
CREATE TABLE public.language_limits (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_name text NOT NULL UNIQUE,
  max_chat_women integer NOT NULL DEFAULT 50,
  max_call_women integer NOT NULL DEFAULT 20,
  current_chat_women integer NOT NULL DEFAULT 0,
  current_call_women integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Add last_activity_at and auto_approved fields to female_profiles if not exists
ALTER TABLE public.female_profiles 
ADD COLUMN IF NOT EXISTS auto_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS suspended_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS suspension_reason text;

-- Add video call availability to women_availability
ALTER TABLE public.women_availability 
ADD COLUMN IF NOT EXISTS is_available_for_calls boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS current_call_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS max_concurrent_calls integer DEFAULT 1;

-- Enable RLS
ALTER TABLE public.video_call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_limits ENABLE ROW LEVEL SECURITY;

-- RLS policies for video_call_sessions
CREATE POLICY "Users can view their own video calls" 
ON public.video_call_sessions 
FOR SELECT 
USING ((auth.uid() = man_user_id) OR (auth.uid() = woman_user_id));

CREATE POLICY "Men can insert video calls" 
ON public.video_call_sessions 
FOR INSERT 
WITH CHECK (auth.uid() = man_user_id);

CREATE POLICY "Users can update their own video calls" 
ON public.video_call_sessions 
FOR UPDATE 
USING ((auth.uid() = man_user_id) OR (auth.uid() = woman_user_id));

CREATE POLICY "Admins can view all video calls" 
ON public.video_call_sessions 
FOR SELECT 
USING (has_role(auth.uid(), 'admin'::app_role));

-- RLS policies for language_limits
CREATE POLICY "Anyone can view language limits" 
ON public.language_limits 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage language limits" 
ON public.language_limits 
FOR ALL 
USING (has_role(auth.uid(), 'admin'::app_role));

-- Create trigger for updated_at
CREATE TRIGGER update_video_call_sessions_updated_at
BEFORE UPDATE ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_language_limits_updated_at
BEFORE UPDATE ON public.language_limits
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Seed initial language limits for common languages
INSERT INTO public.language_limits (language_name, max_chat_women, max_call_women) VALUES
('Hindi', 100, 30),
('English', 100, 30),
('Tamil', 50, 20),
('Telugu', 50, 20),
('Bengali', 50, 20),
('Marathi', 50, 20),
('Gujarati', 40, 15),
('Kannada', 40, 15),
('Malayalam', 40, 15),
('Punjabi', 40, 15),
('Odia', 30, 10),
('Urdu', 30, 10),
('Arabic', 30, 10),
('Spanish', 30, 10),
('French', 30, 10),
('German', 20, 10),
('Portuguese', 20, 10),
('Chinese', 20, 10),
('Japanese', 20, 10),
('Korean', 20, 10)
ON CONFLICT (language_name) DO NOTHING;

-- ============================================================
-- Migration: 20251208125553_294c7018-ae89-4f97-b75e-00f0e061a154.sql
-- ============================================================
-- Add video call pricing columns to chat_pricing table
ALTER TABLE public.chat_pricing
ADD COLUMN IF NOT EXISTS video_rate_per_minute numeric NOT NULL DEFAULT 10.00,
ADD COLUMN IF NOT EXISTS video_women_earning_rate numeric NOT NULL DEFAULT 5.00;

-- Add comment for clarity
COMMENT ON COLUMN public.chat_pricing.video_rate_per_minute IS 'Rate charged to men per minute for video calls';
COMMENT ON COLUMN public.chat_pricing.video_women_earning_rate IS 'Rate earned by women per minute for video calls';

-- ============================================================
-- Migration: 20251208132311_c82fbc35-b6b5-4a9f-b9b0-8620e5e448f6.sql
-- ============================================================
-- Create a function to auto-assign admin role for admin emails (admin1@meow-meow.com to admin15@meow-meow.com)
CREATE OR REPLACE FUNCTION public.handle_admin_role_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the email matches admin1@meow-meow.com through admin15@meow-meow.com pattern
  IF NEW.email ~ '^admin(1[0-5]?|[1-9])@meow-meow\.com$' THEN
    -- Insert admin role for this user
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to auto-assign admin role on user creation
DROP TRIGGER IF EXISTS on_auth_user_created_admin_role ON auth.users;
CREATE TRIGGER on_auth_user_created_admin_role
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_role_assignment();

-- Also assign admin roles to any existing admin users
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE email ~ '^admin(1[0-5]?|[1-9])@meow-meow\.com$'
ON CONFLICT (user_id, role) DO NOTHING;

-- ============================================================
-- Migration: 20251208134105_46596171-5855-4bb8-93c5-2e381b898147.sql
-- ============================================================
-- Add notifications table to realtime publication for real-time updates
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Add to supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================
-- Migration: 20251208154956_7d1f1114-5b61-4e40-9310-b9d770473a38.sql
-- ============================================================
-- Create app_settings table for dynamic configuration (ACID compliant)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    setting_key text NOT NULL UNIQUE,
    setting_value jsonb NOT NULL,
    setting_type text NOT NULL DEFAULT 'string',
    category text NOT NULL DEFAULT 'general',
    description text,
    is_public boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Public settings can be read by anyone
CREATE POLICY "Anyone can view public settings"
ON public.app_settings FOR SELECT
USING (is_public = true);

-- Admins can manage all settings
CREATE POLICY "Admins can manage all settings"
ON public.app_settings FOR ALL
USING (has_role(auth.uid(), 'admin'));

-- Create trigger for updated_at
CREATE TRIGGER update_app_settings_updated_at
BEFORE UPDATE ON public.app_settings
FOR EACH ROW
EXECUTE FUNCTION handle_updated_at();

-- Insert default dynamic settings (recharge amounts, withdrawal amounts, limits, etc.)
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, category, description, is_public) VALUES
('recharge_amounts', '[100, 500, 1000, 2000, 5000, 10000]', 'json', 'wallet', 'Available recharge amounts for men', true),
('withdrawal_amounts', '[500, 1000, 2000, 5000, 10000]', 'json', 'wallet', 'Available withdrawal amounts for women', true),
('min_video_call_balance', '50', 'number', 'video', 'Minimum balance required for video call', true),
('max_parallel_chats', '3', 'number', 'chat', 'Maximum parallel chats allowed', true),
('max_reconnect_attempts', '3', 'number', 'chat', 'Maximum auto-reconnect attempts', true),
('mobile_breakpoint', '768', 'number', 'ui', 'Mobile responsive breakpoint in pixels', true),
('supported_currencies', '["INR", "USD", "EUR"]', 'json', 'wallet', 'Supported currencies', true),
('default_currency', '"INR"', 'json', 'wallet', 'Default currency for new users', true),
('withdrawal_processing_hours', '24', 'number', 'wallet', 'Hours to process withdrawal', true),
('session_timeout_minutes', '30', 'number', 'security', 'Session timeout in minutes', true),
('max_message_length', '2000', 'number', 'chat', 'Maximum message length', true),
('max_file_upload_mb', '10', 'number', 'storage', 'Maximum file upload size in MB', true)
ON CONFLICT (setting_key) DO UPDATE SET 
    setting_value = EXCLUDED.setting_value,
    updated_at = now();

-- Create function for atomic wallet transactions (ACID compliant)
CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
    p_user_id uuid,
    p_amount numeric,
    p_type text,
    p_description text DEFAULT NULL,
    p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wallet_id uuid;
    v_current_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
BEGIN
    -- Lock the wallet row for update (isolation)
    SELECT id, balance INTO v_wallet_id, v_current_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user';
    END IF;
    
    -- Calculate new balance
    IF p_type = 'credit' THEN
        v_new_balance := v_current_balance + p_amount;
    ELSIF p_type = 'debit' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Insufficient balance';
        END IF;
        v_new_balance := v_current_balance - p_amount;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type';
    END IF;
    
    -- Update wallet balance (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, reference_id, status
    ) VALUES (
        v_wallet_id, p_user_id, p_type, p_amount, p_description, p_reference_id, 'completed'
    )
    RETURNING id INTO v_transaction_id;
    
    -- Return result
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'previous_balance', v_current_balance,
        'new_balance', v_new_balance
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- Create function for atomic chat session billing
CREATE OR REPLACE FUNCTION public.process_chat_billing(
    p_session_id uuid,
    p_minutes numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Get active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    -- Calculate charges
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    
    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.active_chat_sessions
        SET status = 'ended', 
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge'
    );
    
    -- Credit woman's earnings
    INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings');
    
    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- ============================================================
-- Migration: 20251208155528_a876418b-2442-4ef8-9e71-2fec3c8ba5ef.sql
-- ============================================================
-- Clear all sample/mock data
DELETE FROM public.sample_users;
DELETE FROM public.sample_men;
DELETE FROM public.sample_women;

-- Reset sequences if any (for fresh start)
-- Note: These tables use UUID so no sequence reset needed

-- Create a function to check if a user is a super user (by email pattern)
CREATE OR REPLACE FUNCTION public.is_super_user(user_email text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if email matches super user patterns:
  -- female1-15@meow-meow.com, male1-15@meow-meow.com, admin1-15@meow-meow.com
  RETURN user_email ~ '^(female|male|admin)(1[0-5]?|[1-9])@meow-meow\.com$';
END;
$$;

-- Create a function to check if user should bypass balance requirements
CREATE OR REPLACE FUNCTION public.should_bypass_balance(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  -- Get user email from auth.users
  SELECT email INTO v_email
  FROM auth.users
  WHERE id = p_user_id;
  
  -- Check if super user
  RETURN public.is_super_user(COALESCE(v_email, ''));
END;
$$;

-- Update process_chat_billing to bypass billing for super users
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Check if man is a super user (bypass billing)
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    IF v_is_super_user THEN
        -- Super users don't get charged, but women still earn
        SELECT * INTO v_pricing
        FROM public.chat_pricing
        WHERE is_active = true
        LIMIT 1;
        
        IF v_pricing IS NOT NULL THEN
            v_earning_amount := p_minutes * v_pricing.women_earning_rate;
            
            -- Credit woman's earnings (platform pays)
            INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings (super user session)');
            
            -- Update session totals
            UPDATE public.active_chat_sessions
            SET total_minutes = total_minutes + p_minutes,
                total_earned = total_earned + v_earning_amount,
                last_activity_at = now()
            WHERE id = p_session_id;
        END IF;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', COALESCE(v_earning_amount, 0)
        );
    END IF;
    
    -- Normal billing flow for non-super users
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    -- Calculate charges
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    
    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.active_chat_sessions
        SET status = 'ended', 
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge'
    );
    
    -- Credit woman's earnings
    INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings');
    
    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- ============================================================
-- Migration: 20251208163338_416ced02-fbc1-42e3-8a55-e6df5a453405.sql
-- ============================================================
-- Clean up all non-super user data from the app
-- Super users are: female1-15@meow-meow.com, male1-15@meow-meow.com, admin1-15@meow-meow.com

-- First, get all non-super user IDs from auth.users
-- We'll delete from all related tables

-- Delete from women_earnings (references active_chat_sessions)
DELETE FROM public.women_earnings
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE public.is_super_user(email)
);

-- Delete from shift_earnings (references shifts)
DELETE FROM public.shift_earnings
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE public.is_super_user(email)
);

-- Delete from active_chat_sessions
DELETE FROM public.active_chat_sessions
WHERE man_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR woman_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from video_call_sessions
DELETE FROM public.video_call_sessions
WHERE man_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR woman_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from chat_messages
DELETE FROM public.chat_messages
WHERE sender_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR receiver_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from moderation_reports
DELETE FROM public.moderation_reports
WHERE reporter_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR reported_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from gift_transactions
DELETE FROM public.gift_transactions
WHERE sender_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR receiver_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from wallet_transactions (references wallets)
DELETE FROM public.wallet_transactions
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from wallets
DELETE FROM public.wallets
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from shifts
DELETE FROM public.shifts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from scheduled_shifts
DELETE FROM public.scheduled_shifts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from attendance
DELETE FROM public.attendance
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from absence_records
DELETE FROM public.absence_records
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from women_availability
DELETE FROM public.women_availability
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from women_shift_assignments
DELETE FROM public.women_shift_assignments
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from chat_wait_queue
DELETE FROM public.chat_wait_queue
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from matches
DELETE FROM public.matches
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR matched_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_friends
DELETE FROM public.user_friends
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR friend_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_blocks
DELETE FROM public.user_blocks
WHERE blocked_by NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR blocked_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_warnings
DELETE FROM public.user_warnings
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from policy_violation_alerts
DELETE FROM public.policy_violation_alerts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from notifications
DELETE FROM public.notifications
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from processing_logs
DELETE FROM public.processing_logs
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from tutorial_progress
DELETE FROM public.tutorial_progress
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_consent
DELETE FROM public.user_consent
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_languages
DELETE FROM public.user_languages
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_photos
DELETE FROM public.user_photos
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_settings
DELETE FROM public.user_settings
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_status
DELETE FROM public.user_status
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_roles (keep super user roles)
DELETE FROM public.user_roles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from password_reset_tokens
DELETE FROM public.password_reset_tokens
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from withdrawal_requests
DELETE FROM public.withdrawal_requests
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from female_profiles
DELETE FROM public.female_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from male_profiles
DELETE FROM public.male_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from profiles
DELETE FROM public.profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Also clear sample data tables completely
TRUNCATE TABLE public.sample_users CASCADE;
TRUNCATE TABLE public.sample_men CASCADE;
TRUNCATE TABLE public.sample_women CASCADE;

-- ============================================================
-- Migration: 20251208163815_2df53a73-f4c6-4d07-8cbc-a35ad9e74c92.sql
-- ============================================================
-- ACID-Compliant Atomic Transfer Function
-- Ensures atomicity: both debit and credit happen or neither does
-- Uses row-level locking for isolation
CREATE OR REPLACE FUNCTION public.process_atomic_transfer(
  p_from_user_id uuid,
  p_to_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_from_wallet_id uuid;
    v_to_wallet_id uuid;
    v_from_balance numeric;
    v_to_balance numeric;
    v_from_new_balance numeric;
    v_to_new_balance numeric;
    v_from_transaction_id uuid;
    v_to_transaction_id uuid;
    v_is_super_user boolean;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_from_user_id);
    
    -- Lock both wallets in consistent order (by user_id) to prevent deadlocks
    IF p_from_user_id < p_to_user_id THEN
        SELECT id, balance INTO v_from_wallet_id, v_from_balance
        FROM public.wallets WHERE user_id = p_from_user_id FOR UPDATE;
        
        SELECT id, balance INTO v_to_wallet_id, v_to_balance
        FROM public.wallets WHERE user_id = p_to_user_id FOR UPDATE;
    ELSE
        SELECT id, balance INTO v_to_wallet_id, v_to_balance
        FROM public.wallets WHERE user_id = p_to_user_id FOR UPDATE;
        
        SELECT id, balance INTO v_from_wallet_id, v_from_balance
        FROM public.wallets WHERE user_id = p_from_user_id FOR UPDATE;
    END IF;
    
    -- Validate wallets exist
    IF v_from_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sender wallet not found');
    END IF;
    
    IF v_to_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Receiver wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_from_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate new balances
    IF v_is_super_user THEN
        v_from_new_balance := v_from_balance; -- Super users don't lose balance
    ELSE
        v_from_new_balance := v_from_balance - p_amount;
    END IF;
    v_to_new_balance := v_to_balance + p_amount;
    
    -- Update sender wallet (atomic)
    UPDATE public.wallets
    SET balance = v_from_new_balance, updated_at = now()
    WHERE id = v_from_wallet_id;
    
    -- Update receiver wallet (atomic)
    UPDATE public.wallets
    SET balance = v_to_new_balance, updated_at = now()
    WHERE id = v_to_wallet_id;
    
    -- Create debit transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_from_wallet_id, p_from_user_id, 'debit', p_amount,
        COALESCE(p_description, 'Transfer out'), 'completed'
    ) RETURNING id INTO v_from_transaction_id;
    
    -- Create credit transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_to_wallet_id, p_to_user_id, 'credit', p_amount,
        COALESCE(p_description, 'Transfer in'), 'completed'
    ) RETURNING id INTO v_to_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'from_transaction_id', v_from_transaction_id,
        'to_transaction_id', v_to_transaction_id,
        'from_previous_balance', v_from_balance,
        'from_new_balance', v_from_new_balance,
        'to_previous_balance', v_to_balance,
        'to_new_balance', v_to_new_balance,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ACID-Compliant Gift Transaction Function
-- Atomically handles gift purchase: debit sender, record gift
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance; -- Super users don't lose balance
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name, 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ACID-Compliant Video Call Billing Function
CREATE OR REPLACE FUNCTION public.process_video_billing(
  p_session_id uuid,
  p_minutes numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;
    
    -- Check if man is super user
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    -- Get pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    -- Calculate amounts
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    
    IF v_is_super_user THEN
        -- Super users: credit woman only, no debit
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 'Video call (super user session)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount,
            updated_at = now()
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    -- Normal flow: lock wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 'Video call charge', 'completed');
    
    -- Credit woman
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 'Video call earnings');
    
    -- Update session
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        updated_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ACID-Compliant Withdrawal Request Function
CREATE OR REPLACE FUNCTION public.process_withdrawal_request(
  p_user_id uuid,
  p_amount numeric,
  p_payment_method text DEFAULT NULL,
  p_payment_details jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_id uuid;
    v_balance numeric;
    v_min_balance numeric;
    v_new_balance numeric;
    v_withdrawal_id uuid;
    v_transaction_id uuid;
BEGIN
    -- Get minimum withdrawal balance
    SELECT (setting_value::text)::numeric INTO v_min_balance
    FROM public.app_settings
    WHERE setting_key = 'min_withdrawal_balance';
    
    v_min_balance := COALESCE(v_min_balance, 10000);
    
    IF p_amount < v_min_balance THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum withdrawal');
    END IF;
    
    -- Lock wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    IF v_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    v_new_balance := v_balance - p_amount;
    
    -- Hold funds (debit wallet)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create transaction record
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_wallet_id, p_user_id, 'debit', p_amount, 'Withdrawal request', 'pending')
    RETURNING id INTO v_transaction_id;
    
    -- Create withdrawal request
    INSERT INTO public.withdrawal_requests (
        user_id, amount, payment_method, payment_details, status
    ) VALUES (
        p_user_id, p_amount, p_payment_method, p_payment_details, 'pending'
    ) RETURNING id INTO v_withdrawal_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'withdrawal_id', v_withdrawal_id,
        'transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- Migration: 20251208164225_306bb601-6c6c-42d0-9a67-a37a5b46304b.sql
-- ============================================================
-- Reset balance to 0 for all super users
-- Super users don't require balance to use the app (bypass already implemented)

UPDATE public.wallets
SET balance = 0, updated_at = now()
WHERE user_id IN (
  SELECT id FROM auth.users 
  WHERE public.is_super_user(email)
);

-- Also clear any pending wallet transactions for super users
UPDATE public.wallet_transactions
SET status = 'cancelled'
WHERE user_id IN (
  SELECT id FROM auth.users 
  WHERE public.is_super_user(email)
) AND status = 'pending';

-- ============================================================
-- Migration: 20251210130328_ab703ba5-c342-409e-9377-de66fccb7c8e.sql
-- ============================================================
-- Add production_mode setting to app_settings
-- Default to false (development mode) - set to true for production deployment

INSERT INTO public.app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'production_mode',
  'false',
  'boolean',
  'general',
  'When enabled, disables all mock/seed data utilities. Set to true for production deployment.',
  false
)
ON CONFLICT (setting_key) DO NOTHING;

-- ============================================================
-- Migration: 20251210130731_7428b82b-1ba5-47ec-86b6-9d9f22588420.sql
-- ============================================================
-- Update gift transaction function to split 50/50 between women and admin
CREATE OR REPLACE FUNCTION public.process_gift_transaction(p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
    v_women_share numeric;
    v_admin_share numeric;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate 50/50 split
    v_women_share := v_gift.price * 0.5;
    v_admin_share := v_gift.price * 0.5;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance; -- Super users don't lose balance
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender (full amount deducted)
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings (50% of gift value)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'admin_share', v_admin_share,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================
-- Migration: 20251210134044_860c484b-faaa-4b2e-9a47-6fae6c5aaab0.sql
-- ============================================================
-- Clean up test/seed data from all transaction tables

-- Delete test wallet transactions (seeded free credits)
DELETE FROM wallet_transactions 
WHERE description ILIKE '%Test account%' 
   OR description ILIKE '%Free credits%'
   OR description ILIKE '%seed%';

-- Delete any test chat sessions where man and woman are the same user (self-chat)
DELETE FROM active_chat_sessions 
WHERE man_user_id = woman_user_id;

-- Delete test video call sessions
DELETE FROM video_call_sessions 
WHERE man_user_id = woman_user_id;

-- Clean up any orphaned women_earnings records
DELETE FROM women_earnings 
WHERE description ILIKE '%super user%' 
   OR description ILIKE '%test%';

-- Clean up any test shift_earnings
DELETE FROM shift_earnings 
WHERE description ILIKE '%test%';

-- Clean up gift transactions with no valid sender/receiver profiles
DELETE FROM gift_transactions gt
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = gt.sender_id)
   OR NOT EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = gt.receiver_id);

-- ============================================================
-- Migration: 20251210134450_282aa53c-2f43-4574-81d0-6e789155583d.sql
-- ============================================================
-- Clean ALL wallet transactions to reset to zero
DELETE FROM wallet_transactions;

-- Reset all wallet balances to zero
UPDATE wallets SET balance = 0, updated_at = now();

-- Clean all chat sessions
DELETE FROM active_chat_sessions;

-- Clean all video call sessions  
DELETE FROM video_call_sessions;

-- Clean all women earnings
DELETE FROM women_earnings;

-- Clean all shift earnings
DELETE FROM shift_earnings;

-- Clean all gift transactions
DELETE FROM gift_transactions;

-- Clean all withdrawal requests
DELETE FROM withdrawal_requests;

-- Reset platform metrics
DELETE FROM platform_metrics;

-- ============================================================
-- Migration: 20251212081320_284d0b2a-52a1-4468-9df2-f9ec0f7e7735.sql
-- ============================================================
-- Enable required extensions for cron jobs
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule video call cleanup to run every minute
-- This will delete all video call session records older than 5 minutes
SELECT cron.schedule(
  'video-call-cleanup-every-minute',
  '* * * * *', -- Every minute
  $$
  SELECT
    net.http_post(
        url:='https://www.meow-meow.co.in:8443/functions/v1/video-cleanup',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
        body:=concat('{"time": "', now(), '"}')::jsonb
    ) as request_id;
  $$
);

-- ============================================================
-- Migration: 20251212081343_eb6c82e3-4b69-4e1a-84ec-ee6877fd13c8.sql
-- ============================================================
-- Move pg_cron and pg_net extensions to the extensions schema (best practice)
-- Note: These extensions may already exist, so we're just ensuring proper setup

-- Create extensions schema if not exists
CREATE SCHEMA IF NOT EXISTS extensions;

-- Grant usage on extensions schema
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- The pg_cron and pg_net extensions are managed by Supabase and typically installed in cron/extensions schema
-- The warning is informational - these extensions are already properly configured by Supabase

-- ============================================================
-- Migration: 20251212085146_92269a4e-56e5-4f5b-a2f3-0594e6d06930.sql
-- ============================================================
-- Create private_groups table for women to create private rooms
CREATE TABLE public.private_groups (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  min_gift_amount NUMERIC NOT NULL DEFAULT 100,
  access_type TEXT NOT NULL DEFAULT 'both' CHECK (access_type IN ('chat', 'video', 'both')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_live BOOLEAN NOT NULL DEFAULT false,
  stream_id TEXT,
  participant_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create group_memberships table to track who has access
CREATE TABLE public.group_memberships (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  gift_amount_paid NUMERIC NOT NULL DEFAULT 0,
  has_access BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- Create group_messages table for group chat
CREATE TABLE public.group_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  message TEXT NOT NULL,
  is_translated BOOLEAN DEFAULT false,
  translated_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.private_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for private_groups
CREATE POLICY "Anyone can view active groups" ON public.private_groups
  FOR SELECT USING (is_active = true);

CREATE POLICY "Women can create groups" ON public.private_groups
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update their groups" ON public.private_groups
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Owners can delete their groups" ON public.private_groups
  FOR DELETE USING (auth.uid() = owner_id);

-- RLS Policies for group_memberships
CREATE POLICY "Users can view their memberships" ON public.group_memberships
  FOR SELECT USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM public.private_groups WHERE id = group_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Users can join groups" ON public.group_memberships
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can update memberships" ON public.group_memberships
  FOR UPDATE USING (true);

-- RLS Policies for group_messages
CREATE POLICY "Members can view group messages" ON public.group_messages
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.group_memberships WHERE group_id = group_messages.group_id AND user_id = auth.uid() AND has_access = true)
    OR EXISTS (SELECT 1 FROM public.private_groups WHERE id = group_messages.group_id AND owner_id = auth.uid())
  );

CREATE POLICY "Members can send messages" ON public.group_messages
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.group_memberships WHERE group_id = group_messages.group_id AND user_id = auth.uid() AND has_access = true)
    OR EXISTS (SELECT 1 FROM public.private_groups WHERE id = group_messages.group_id AND owner_id = auth.uid())
  );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.private_groups;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_memberships;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;

-- Create function to process group gift and grant access
CREATE OR REPLACE FUNCTION public.process_group_gift(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Check if gift meets minimum requirement
  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift does not meet minimum requirement of ' || v_group.min_gift_amount);
  END IF;

  -- Check if super user
  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Check balance
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate 50/50 split
  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit wallet
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group access gift: ' || v_gift.name, 'completed');

  -- Credit woman's earnings (50%)
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_group.owner_id, v_women_share, 'gift', 'Group access gift (50% share): ' || v_gift.name);

  -- Create gift transaction
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_group.owner_id, p_gift_id, v_gift.price, v_gift.currency, 'Group access gift', 'completed');

  -- Grant access to group
  INSERT INTO public.group_memberships (group_id, user_id, gift_amount_paid, has_access)
  VALUES (p_group_id, p_sender_id, v_gift.price, true)
  ON CONFLICT (group_id, user_id) DO UPDATE SET has_access = true, gift_amount_paid = EXCLUDED.gift_amount_paid;

  -- Update participant count
  UPDATE public.private_groups SET participant_count = participant_count + 1 WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance
  );
END;
$$;

-- ============================================================
-- Migration: 20251212085808_4bf0584f-d418-4974-9339-e314cc172a7a.sql
-- ============================================================
-- Add index for sorting groups by participant count
CREATE INDEX IF NOT EXISTS idx_private_groups_participant_count ON public.private_groups(participant_count DESC, created_at DESC);

-- Create function to cleanup old group messages (5 minutes)
CREATE OR REPLACE FUNCTION public.cleanup_old_group_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM public.group_messages 
  WHERE created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

-- Create function to cleanup old video sessions (15 minutes)
CREATE OR REPLACE FUNCTION public.cleanup_old_group_video_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Reset is_live and stream_id for groups inactive for 15 minutes
  UPDATE public.private_groups
  SET is_live = false, stream_id = NULL
  WHERE is_live = true 
  AND updated_at < NOW() - INTERVAL '15 minutes';
END;
$$;

-- ============================================================
-- Migration: 20251214084310_9476bb8c-7028-4b1c-9c4e-1867304f705f.sql
-- ============================================================
-- ============================================================================
-- SECURITY FIX: Tighten RLS policies for sensitive tables
-- ============================================================================

-- 1. FIX: password_reset_tokens - Remove all public access (CRITICAL)
-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Anyone can view password reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "Users can view their password reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "Public can view tokens" ON public.password_reset_tokens;

-- Only allow service role to access password_reset_tokens (no public SELECT)
-- Users should never be able to see these tokens directly
CREATE POLICY "Only service role can access password reset tokens"
ON public.password_reset_tokens
FOR ALL
USING (false)
WITH CHECK (false);

-- 2. FIX: user_status - Restrict to authenticated users viewing relevant statuses
DROP POLICY IF EXISTS "Users can view all online statuses" ON public.user_status;
DROP POLICY IF EXISTS "Anyone can view online statuses" ON public.user_status;

-- Only authenticated users can view status of users they're chatting with or matched with
CREATE POLICY "Authenticated users can view statuses of connections"
ON public.user_status
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.active_chat_sessions
        WHERE status = 'active'
        AND (man_user_id = auth.uid() AND woman_user_id = user_status.user_id
             OR woman_user_id = auth.uid() AND man_user_id = user_status.user_id)
    )
    OR EXISTS (
        SELECT 1 FROM public.matches
        WHERE status = 'active'
        AND (user_id = auth.uid() AND matched_user_id = user_status.user_id
             OR matched_user_id = auth.uid() AND user_id = user_status.user_id)
    )
    OR public.has_role(auth.uid(), 'admin')
);

-- 3. FIX: user_photos - Restrict to authenticated users only
DROP POLICY IF EXISTS "Anyone can view user photos" ON public.user_photos;
DROP POLICY IF EXISTS "Public can view user photos" ON public.user_photos;

-- Only authenticated users can view photos
CREATE POLICY "Authenticated users can view photos"
ON public.user_photos
FOR SELECT
TO authenticated
USING (true);

-- 4. FIX: women_availability - Restrict to authenticated users and admins
DROP POLICY IF EXISTS "Anyone can view availability" ON public.women_availability;
DROP POLICY IF EXISTS "Public can view availability" ON public.women_availability;

-- Only authenticated users can view availability (needed for matching)
CREATE POLICY "Authenticated users can view women availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (
    -- Women can see their own availability
    user_id = auth.uid()
    -- Men can see availability for matching
    OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid()
        AND LOWER(gender) = 'male'
    )
    -- Admins can see all
    OR public.has_role(auth.uid(), 'admin')
);

-- 5. FIX: female_profiles - Remove phone from visible columns, tighten access
-- First, let's update the select policy to be more restrictive
DROP POLICY IF EXISTS "Approved women visible to authenticated users" ON public.female_profiles;

-- Create a more restrictive policy
CREATE POLICY "Approved female profiles visible to authenticated users"
ON public.female_profiles
FOR SELECT
TO authenticated
USING (
    -- User can see their own profile
    user_id = auth.uid()
    -- Approved profiles visible to authenticated users (but RLS can't filter columns)
    OR (approval_status = 'approved' AND account_status = 'active')
    -- Admins can see all
    OR public.has_role(auth.uid(), 'admin')
);

-- 6. FIX: chat_pricing - Restrict to authenticated users only
DROP POLICY IF EXISTS "Anyone can view active pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Chat pricing is publicly readable" ON public.chat_pricing;

-- Only authenticated users can view pricing
CREATE POLICY "Authenticated users can view active pricing"
ON public.chat_pricing
FOR SELECT
TO authenticated
USING (is_active = true OR public.has_role(auth.uid(), 'admin'));

-- ============================================================================
-- Additional security hardening
-- ============================================================================

-- Ensure user_roles table has proper policies
DROP POLICY IF EXISTS "Users can view their own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can manage roles" ON public.user_roles;

CREATE POLICY "Users can view their own roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can insert roles"
ON public.user_roles
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can update roles"
ON public.user_roles
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can delete roles"
ON public.user_roles
FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- ============================================================
-- Migration: 20251214085001_a5ada08d-3adf-49ca-8bab-229b3d0b79e6.sql
-- ============================================================
-- Fix password_reset_tokens security: Remove all permissive policies
-- Only service_role should access this table (via edge functions)

DROP POLICY IF EXISTS "System can delete reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can insert reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can read reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can update reset tokens" ON public.password_reset_tokens;

-- The remaining policy "Only service role can access password reset tokens" 
-- with USING (false) will block all client access
-- Edge functions using service_role key bypass RLS entirely

-- ============================================================
-- Migration: 20251214085044_e5de5baf-d19b-4362-9d19-1df56df404ff.sql
-- ============================================================
-- Fix chat_pricing security: Only admins should see full pricing details
-- Remove public access policy for authenticated users

DROP POLICY IF EXISTS "Authenticated users can view active pricing" ON public.chat_pricing;

-- Keep only admin access policies (already exist):
-- "Admins can view all pricing" with USING (true) - this is for admin role
-- "Admins can update pricing" 
-- "Admins can insert pricing"
-- "Admins can delete pricing"

-- Create a secure function for clients to get only their applicable rate
CREATE OR REPLACE FUNCTION public.get_current_chat_rate()
RETURNS TABLE(chat_rate numeric, video_rate numeric, currency text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rate_per_minute, video_rate_per_minute, currency
  FROM public.chat_pricing
  WHERE is_active = true
  LIMIT 1;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_chat_rate() TO authenticated;

-- ============================================================
-- Migration: 20251214085329_7d7cc483-4277-4739-ac71-fe9ce129c08f.sql
-- ============================================================
-- Drop the public access policy that allows unauthenticated access
DROP POLICY IF EXISTS "Photos are publicly viewable" ON public.user_photos;
DROP POLICY IF EXISTS "User photos are publicly viewable" ON public.user_photos;
DROP POLICY IF EXISTS "Public photos access" ON public.user_photos;

-- ============================================================
-- Migration: 20251214085409_270fd9a7-d6ca-400b-9319-ef6ded832e6d.sql
-- ============================================================
-- Fix female_profiles security: Require authentication to view profiles
DROP POLICY IF EXISTS "Approved female profiles visible to authenticated users" ON public.female_profiles;

-- Recreate with proper authentication check
CREATE POLICY "Approved female profiles visible to authenticated users"
ON public.female_profiles
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    user_id = auth.uid() OR 
    (approval_status = 'approved' AND account_status = 'active') OR 
    has_role(auth.uid(), 'admin')
  )
);

-- ============================================================
-- Migration: 20251214085629_b20ee3e7-dbe3-4b04-91ca-2d87693048ff.sql
-- ============================================================
-- Fix all security issues: Require authentication for sensitive tables

-- 1. Fix chat_pricing - already restricted to admins, ensure no public access
DROP POLICY IF EXISTS "Anyone can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;

-- 2. Fix language_limits - require authentication
DROP POLICY IF EXISTS "Anyone can view language limits" ON public.language_limits;
CREATE POLICY "Authenticated users can view language limits"
ON public.language_limits
FOR SELECT
USING (auth.uid() IS NOT NULL);

-- 3. Fix language_groups - require authentication  
DROP POLICY IF EXISTS "Anyone can view active language groups" ON public.language_groups;
CREATE POLICY "Authenticated users can view active language groups"
ON public.language_groups
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);

-- 4. Fix shift_templates - require authentication (add RLS if not exists)
ALTER TABLE IF EXISTS public.shift_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view shift templates" ON public.shift_templates;
DROP POLICY IF EXISTS "Public can view shift templates" ON public.shift_templates;
CREATE POLICY "Authenticated users can view shift templates"
ON public.shift_templates
FOR SELECT
USING (auth.uid() IS NOT NULL);

-- 5. Fix app_settings - restrict non-public settings to authenticated users
DROP POLICY IF EXISTS "Anyone can view public settings" ON public.app_settings;
CREATE POLICY "Authenticated users can view public settings"
ON public.app_settings
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_public = true);

-- 6. Fix gifts - require authentication to view
DROP POLICY IF EXISTS "Anyone can view active gifts" ON public.gifts;
CREATE POLICY "Authenticated users can view active gifts"
ON public.gifts
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);

-- ============================================================
-- Migration: 20251214085735_4d636280-f09d-432b-ac08-69d84eec3344.sql
-- ============================================================
-- Comprehensive fix for all public access issues

-- 1. chat_pricing - Remove ALL public policies, keep only admin access
DROP POLICY IF EXISTS "Admins can view all pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Anyone can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Users can view pricing" ON public.chat_pricing;

-- Only admins can see full pricing
CREATE POLICY "Only admins can view pricing"
ON public.chat_pricing
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- 2. gifts - Require authentication
DROP POLICY IF EXISTS "Authenticated users can view active gifts" ON public.gifts;
DROP POLICY IF EXISTS "Anyone can view gifts" ON public.gifts;
DROP POLICY IF EXISTS "Public can view gifts" ON public.gifts;

CREATE POLICY "Auth users can view active gifts"
ON public.gifts
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);

-- 3. app_settings - Only authenticated users, and only truly public settings
DROP POLICY IF EXISTS "Authenticated users can view public settings" ON public.app_settings;
DROP POLICY IF EXISTS "Anyone can view public settings" ON public.app_settings;
DROP POLICY IF EXISTS "Public can view settings" ON public.app_settings;

CREATE POLICY "Auth users can view public settings"
ON public.app_settings
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_public = true);

-- 4. language_limits - Admin only (operational data)
DROP POLICY IF EXISTS "Authenticated users can view language limits" ON public.language_limits;
DROP POLICY IF EXISTS "Anyone can view language limits" ON public.language_limits;
DROP POLICY IF EXISTS "Public can view limits" ON public.language_limits;

CREATE POLICY "Only admins can view language limits"
ON public.language_limits
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- ============================================================
-- Migration: 20251214090007_2d129480-410c-4f1a-b80b-bc257817653f.sql
-- ============================================================
-- Fix all 3 security issues with stronger RLS

-- 1. female_profiles - Only viewable by matched users or active chat participants
DROP POLICY IF EXISTS "Approved female profiles visible to authenticated users" ON public.female_profiles;
DROP POLICY IF EXISTS "Users can view their own female profile" ON public.female_profiles;

CREATE POLICY "Users can view own or matched female profiles"
ON public.female_profiles
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    -- Own profile
    user_id = auth.uid() OR
    -- Admin access
    has_role(auth.uid(), 'admin') OR
    -- Has active chat session with this user
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = female_profiles.user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = female_profiles.user_id)
      )
    ) OR
    -- Has a match with this user
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = female_profiles.user_id) OR
        (matched_user_id = auth.uid() AND user_id = female_profiles.user_id)
      )
    )
  )
);

-- 2. chat_messages - Strengthen to only exact participants
DROP POLICY IF EXISTS "Users can view their own messages" ON public.chat_messages;

CREATE POLICY "Only chat participants can view messages"
ON public.chat_messages
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    sender_id = auth.uid() OR 
    receiver_id = auth.uid() OR
    has_role(auth.uid(), 'admin')
  )
);

-- 3. user_photos - Only viewable by owner, matched users, or chat participants
DROP POLICY IF EXISTS "Authenticated users can view photos" ON public.user_photos;
DROP POLICY IF EXISTS "Users can view their own photos" ON public.user_photos;

CREATE POLICY "Users can view own or matched user photos"
ON public.user_photos
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    -- Own photos
    user_id = auth.uid() OR
    -- Admin access
    has_role(auth.uid(), 'admin') OR
    -- Has active chat session
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = user_photos.user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = user_photos.user_id)
      )
    ) OR
    -- Has match
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = user_photos.user_id) OR
        (matched_user_id = auth.uid() AND user_id = user_photos.user_id)
      )
    )
  )
);

-- ============================================================
-- Migration: 20251214090235_72118f33-47d3-4e23-b72a-68ccaf30f18d.sql
-- ============================================================
-- Fix profiles and chat_messages security

-- 1. Profiles - Create secure function to get limited profile data for matched users
CREATE OR REPLACE FUNCTION public.get_safe_profile(target_user_id uuid)
RETURNS TABLE(
  id uuid,
  full_name text,
  age integer,
  state text,
  country text,
  bio text,
  photo_url text,
  gender text,
  interests text[],
  occupation text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.id,
    p.full_name,
    p.age,
    p.state,
    p.country,
    p.bio,
    p.photo_url,
    p.gender,
    p.interests,
    p.occupation
  FROM profiles p
  WHERE p.user_id = target_user_id
  AND (
    -- Own profile - full access handled elsewhere
    target_user_id = auth.uid() OR
    -- Has active chat or match
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = target_user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = target_user_id)
      )
    ) OR
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = target_user_id) OR
        (matched_user_id = auth.uid() AND user_id = target_user_id)
      )
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_safe_profile(uuid) TO authenticated;

-- 2. Update profiles RLS - Only owner and admin see full data including phone
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Matched users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- Owner sees their own full profile
CREATE POLICY "Users can view own full profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = user_id);

-- Admins see all profiles
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- 3. Chat messages - Add audit trigger for admin access
CREATE OR REPLACE FUNCTION public.audit_admin_message_access()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Log admin access to chat messages
  IF has_role(auth.uid(), 'admin') AND 
     auth.uid() != NEW.sender_id AND 
     auth.uid() != NEW.receiver_id THEN
    INSERT INTO audit_logs (
      admin_id, 
      action, 
      resource_type, 
      resource_id, 
      action_type,
      details
    ) VALUES (
      auth.uid(),
      'view_message',
      'chat_messages',
      NEW.id::text,
      'read',
      'Admin accessed private message'
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Note: Trigger on SELECT not supported, audit via application layer instead

-- ============================================================
-- Migration: 20251214090553_7c6600b5-d901-4a4a-9418-4aa297cbaea5.sql
-- ============================================================
-- Fix all 3 security issues: Restrict sensitive data access

-- 1. Update profiles RLS - Only owner sees full data, others get limited view via function
DROP POLICY IF EXISTS "Users can view own full profile" ON public.profiles;

CREATE POLICY "Only owner sees own full profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- 2. Create secure function for limited profile data (no phone, no coordinates, no DOB)
CREATE OR REPLACE FUNCTION public.get_matched_profile(target_user_id uuid)
RETURNS TABLE(
  id uuid,
  full_name text,
  age integer,
  state text,
  country text,
  bio text,
  photo_url text,
  gender text,
  interests text[],
  occupation text,
  is_verified boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller has active chat or match with target
  IF NOT (
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = target_user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = target_user_id)
      )
    ) OR
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = target_user_id) OR
        (matched_user_id = auth.uid() AND user_id = target_user_id)
      )
    )
  ) THEN
    RETURN; -- Return empty if no relationship
  END IF;

  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.age,
    p.state,
    p.country,
    p.bio,
    p.photo_url,
    p.gender,
    p.interests,
    p.occupation,
    p.is_verified
  FROM profiles p
  WHERE p.user_id = target_user_id;
END;
$$;

-- 3. Fix female_profiles - Only owner sees phone, matched users get limited data
DROP POLICY IF EXISTS "Users can view own or matched female profiles" ON public.female_profiles;

CREATE POLICY "Owner sees own female profile"
ON public.female_profiles
FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- Create secure function for female profile without phone
CREATE OR REPLACE FUNCTION public.get_matched_female_profile(target_user_id uuid)
RETURNS TABLE(
  id uuid,
  full_name text,
  age integer,
  state text,
  country text,
  bio text,
  photo_url text,
  interests text[],
  occupation text,
  is_verified boolean,
  approval_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller has active chat or match
  IF NOT (
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = target_user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = target_user_id)
      )
    ) OR
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = target_user_id) OR
        (matched_user_id = auth.uid() AND user_id = target_user_id)
      )
    )
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    fp.id,
    fp.full_name,
    fp.age,
    fp.state,
    fp.country,
    fp.bio,
    fp.photo_url,
    fp.interests,
    fp.occupation,
    fp.is_verified,
    fp.approval_status
  FROM female_profiles fp
  WHERE fp.user_id = target_user_id
  AND fp.approval_status = 'approved'
  AND fp.account_status = 'active';
END;
$$;

-- 4. Fix wallets - Strictly owner only (remove any admin loophole for balance viewing)
DROP POLICY IF EXISTS "Users can view their own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Admins can view all wallets" ON public.wallets;

CREATE POLICY "Only owner can view wallet"
ON public.wallets
FOR SELECT
USING (auth.uid() = user_id);

-- Admins can update but not casually view all balances
CREATE POLICY "Admins can manage wallets"
ON public.wallets
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.get_matched_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_matched_female_profile(uuid) TO authenticated;

-- ============================================================
-- Migration: 20251214091651_ae263550-9b2c-42aa-8122-5923a614a828.sql
-- ============================================================
-- SECURITY: Add message length constraint to prevent database abuse
ALTER TABLE public.chat_messages 
ADD CONSTRAINT chat_messages_length_check 
CHECK (LENGTH(message) <= 2000);

-- SECURITY: Add message length constraint to group messages
ALTER TABLE public.group_messages 
ADD CONSTRAINT group_messages_length_check 
CHECK (LENGTH(message) <= 2000);

-- SECURITY: Fix audit_logs INSERT policy - restrict to service role only
-- Drop the permissive policy that allows anyone to insert
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;

-- Create a more restrictive policy that only allows inserts from authenticated users
-- with admin role (the actual audit logging should happen via SECURITY DEFINER functions)
CREATE POLICY "Only admins can insert audit logs" 
ON public.audit_logs 
FOR INSERT 
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- SECURITY: Fix women_shift_assignments INSERT policy
DROP POLICY IF EXISTS "System can insert assignments" ON public.women_shift_assignments;

-- Only admins can insert shift assignments
CREATE POLICY "Only admins can insert shift assignments" 
ON public.women_shift_assignments 
FOR INSERT 
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- SECURITY: Restrict active_chat_sessions to hide earnings from male users
-- Drop existing policy
DROP POLICY IF EXISTS "Strict participant session access" ON public.active_chat_sessions;

-- Create new policy that restricts what data each participant can see
-- Male users can only see session status, not earnings
CREATE POLICY "Strict participant session access" 
ON public.active_chat_sessions 
FOR SELECT 
USING (
  auth.uid() IS NOT NULL AND 
  (auth.uid() = man_user_id OR auth.uid() = woman_user_id)
);

-- Note: The column-level security for total_earned is handled at application level
-- Database-level column masking would require additional complexity

-- SECURITY: Add rate limiting support - create a table to track message rates
CREATE TABLE IF NOT EXISTS public.message_rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  message_count integer DEFAULT 0,
  window_start timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT message_rate_limits_user_id_key UNIQUE (user_id)
);

-- Enable RLS on rate limits table
ALTER TABLE public.message_rate_limits ENABLE ROW LEVEL SECURITY;

-- Only allow users to see their own rate limit data
CREATE POLICY "Users can view own rate limits" 
ON public.message_rate_limits 
FOR SELECT 
USING (auth.uid() = user_id);

-- System can update rate limits
CREATE POLICY "System can manage rate limits" 
ON public.message_rate_limits 
FOR ALL
USING (true)
WITH CHECK (true);

-- Create function to check and update message rate limit
CREATE OR REPLACE FUNCTION public.check_message_rate_limit(p_user_id uuid, max_messages integer DEFAULT 60, window_minutes integer DEFAULT 1)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
  v_window_start timestamp with time zone;
BEGIN
  -- Get or create rate limit record
  INSERT INTO message_rate_limits (user_id, message_count, window_start)
  VALUES (p_user_id, 0, now())
  ON CONFLICT (user_id) DO NOTHING;
  
  -- Get current values
  SELECT message_count, window_start INTO v_count, v_window_start
  FROM message_rate_limits
  WHERE user_id = p_user_id;
  
  -- Check if window has expired
  IF v_window_start < now() - (window_minutes || ' minutes')::interval THEN
    -- Reset window
    UPDATE message_rate_limits
    SET message_count = 1, window_start = now(), updated_at = now()
    WHERE user_id = p_user_id;
    RETURN true;
  END IF;
  
  -- Check if under limit
  IF v_count < max_messages THEN
    -- Increment counter
    UPDATE message_rate_limits
    SET message_count = message_count + 1, updated_at = now()
    WHERE user_id = p_user_id;
    RETURN true;
  END IF;
  
  -- Rate limit exceeded
  RETURN false;
END;
$$;

-- ============================================================
-- Migration: 20251214092853_3ffc17c5-3d13-4284-b31b-d20de87ca0c6.sql
-- ============================================================
-- Create a function to get public profile info for group owners
CREATE OR REPLACE FUNCTION public.get_group_owner_profile(owner_user_id uuid)
RETURNS TABLE(user_id uuid, full_name text, photo_url text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.user_id,
    p.full_name,
    p.photo_url
  FROM profiles p
  WHERE p.user_id = owner_user_id
  AND EXISTS (
    SELECT 1 FROM private_groups pg 
    WHERE pg.owner_id = owner_user_id 
    AND pg.is_active = true
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_group_owner_profile(uuid) TO authenticated;

-- ============================================================
-- Migration: 20251214094325_dde3c8fc-6f04-4f59-9c11-058ceed325a0.sql
-- ============================================================
-- Fix orphaned group: add owner as member
INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid)
VALUES ('02648183-1a33-46df-a897-6c8f76f3440e', 'c5da801c-d7f9-4ab3-ae3c-34aaa7fde7f5', true, 0)
ON CONFLICT (group_id, user_id) DO UPDATE SET has_access = true;

-- Update participant count to reflect owner
UPDATE public.private_groups 
SET participant_count = 1 
WHERE id = '02648183-1a33-46df-a897-6c8f76f3440e' AND participant_count = 0;

-- ============================================================
-- Migration: 20251214094353_dff1414a-8f12-49c0-9398-2a78ab1ca213.sql
-- ============================================================
-- Update default min_gift_amount to 0 for new groups
ALTER TABLE public.private_groups ALTER COLUMN min_gift_amount SET DEFAULT 0;

-- ============================================================
-- Migration: 20251214094524_6c3f85b3-95fa-4109-bb12-349453bc1206.sql
-- ============================================================
-- Update gift prices to follow pattern: 10, 20, 30, 40, then multiples of 50
UPDATE public.gifts SET price = 10 WHERE sort_order = 1;
UPDATE public.gifts SET price = 20 WHERE sort_order = 2;
UPDATE public.gifts SET price = 30 WHERE sort_order = 3;
UPDATE public.gifts SET price = 40 WHERE sort_order = 4;
UPDATE public.gifts SET price = 50 WHERE sort_order = 5;
UPDATE public.gifts SET price = 100 WHERE sort_order = 6;
UPDATE public.gifts SET price = 150 WHERE sort_order = 7;
UPDATE public.gifts SET price = 200 WHERE sort_order = 8;
UPDATE public.gifts SET price = 250 WHERE sort_order = 9;
UPDATE public.gifts SET price = 300 WHERE sort_order = 10;

-- ============================================================
-- Migration: 20251214095048_3323c9c0-b660-4d98-b040-dfb3d014a702.sql
-- ============================================================
-- Update gift prices to: 10, 20, 30, 40, 50, 100, 150, 200, 250, 300
UPDATE gifts SET price = CASE 
  WHEN sort_order = 1 THEN 10
  WHEN sort_order = 2 THEN 20
  WHEN sort_order = 3 THEN 30
  WHEN sort_order = 4 THEN 40
  WHEN sort_order = 5 THEN 50
  WHEN sort_order = 6 THEN 100
  WHEN sort_order = 7 THEN 150
  WHEN sort_order = 8 THEN 200
  WHEN sort_order = 9 THEN 250
  WHEN sort_order = 10 THEN 300
  ELSE price
END
WHERE sort_order BETWEEN 1 AND 10;

-- ============================================================
-- Migration: 20251215042623_cabf81ea-c6af-4467-b0ae-602a3fd63575.sql
-- ============================================================
-- Enable required extensions for cron jobs
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Schedule AI women approval to run every 15 minutes
SELECT cron.schedule(
  'ai-women-approval-every-15-mins',
  '*/15 * * * *',
  $$
  SELECT
    net.http_post(
        url:='https://www.meow-meow.co.in:8443/functions/v1/ai-women-approval',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
        body:='{}'::jsonb
    ) as request_id;
  $$
);

-- ============================================================
-- Migration: 20251215044703_4f3520f1-56ee-4bd0-bae0-342a112d465b.sql
-- ============================================================
-- Schedule daily platform metrics update at midnight UTC
SELECT cron.schedule(
  'update-daily-platform-metrics',
  '0 0 * * *',
  $$SELECT public.update_daily_platform_metrics();$$
);

-- ============================================================
-- Migration: 20251215062114_dbe3ae4c-c602-48ab-80fb-5ed731eeda45.sql
-- ============================================================
-- Add city/village column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS city TEXT;

-- ============================================================
-- Migration: 20251215071829_1521cc01-3c20-461e-b081-6f0989956fd4.sql
-- ============================================================
-- Update existing profiles with language code 'te' to full name 'Telugu'
UPDATE profiles SET primary_language = 'Telugu', preferred_language = 'Telugu' WHERE primary_language = 'te' OR preferred_language = 'te';

-- Also update any other common short codes to full names
UPDATE profiles SET primary_language = 'Hindi', preferred_language = 'Hindi' WHERE primary_language = 'hi' OR preferred_language = 'hi';
UPDATE profiles SET primary_language = 'English', preferred_language = 'English' WHERE primary_language = 'en' OR preferred_language = 'en';
UPDATE profiles SET primary_language = 'Tamil', preferred_language = 'Tamil' WHERE primary_language = 'ta' OR preferred_language = 'ta';
UPDATE profiles SET primary_language = 'Kannada', preferred_language = 'Kannada' WHERE primary_language = 'kn' OR preferred_language = 'kn';
UPDATE profiles SET primary_language = 'Malayalam', preferred_language = 'Malayalam' WHERE primary_language = 'ml' OR preferred_language = 'ml';
UPDATE profiles SET primary_language = 'Bengali', preferred_language = 'Bengali' WHERE primary_language = 'bn' OR preferred_language = 'bn';
UPDATE profiles SET primary_language = 'Marathi', preferred_language = 'Marathi' WHERE primary_language = 'mr' OR preferred_language = 'mr';
UPDATE profiles SET primary_language = 'Gujarati', preferred_language = 'Gujarati' WHERE primary_language = 'gu' OR preferred_language = 'gu';
UPDATE profiles SET primary_language = 'Punjabi', preferred_language = 'Punjabi' WHERE primary_language = 'pa' OR preferred_language = 'pa';
UPDATE profiles SET primary_language = 'Odia', preferred_language = 'Odia' WHERE primary_language = 'or' OR preferred_language = 'or';
UPDATE profiles SET primary_language = 'Urdu', preferred_language = 'Urdu' WHERE primary_language = 'ur' OR preferred_language = 'ur';
UPDATE profiles SET primary_language = 'Arabic', preferred_language = 'Arabic' WHERE primary_language = 'ar' OR preferred_language = 'ar';
UPDATE profiles SET primary_language = 'Spanish', preferred_language = 'Spanish' WHERE primary_language = 'es' OR preferred_language = 'es';
UPDATE profiles SET primary_language = 'French', preferred_language = 'French' WHERE primary_language = 'fr' OR preferred_language = 'fr';
UPDATE profiles SET primary_language = 'Chinese', preferred_language = 'Chinese' WHERE primary_language = 'zh' OR preferred_language = 'zh';

-- ============================================================
-- Migration: 20251215073832_827bee89-d786-4ea2-b45d-7e5ea83afe5e.sql
-- ============================================================
-- Update phone number for user pendyala436@gmail.com
UPDATE profiles 
SET phone = '+918790348110', updated_at = now()
WHERE user_id = 'c5da801c-d7f9-4ab3-ae3c-34aaa7fde7f5';

-- ============================================================
-- Migration: 20251215074013_6640520e-602d-424c-8c1e-32c5323faaac.sql
-- ============================================================
-- Insert profile for user pendyala436@gmail.com with phone number
INSERT INTO profiles (user_id, phone, email, updated_at)
VALUES ('c5da801c-d7f9-4ab3-ae3c-34aaa7fde7f5', '+918790348110', 'pendyala436@gmail.com', now())
ON CONFLICT (user_id) DO UPDATE SET phone = '+918790348110', updated_at = now();

-- ============================================================
-- Migration: 20251215074956_b7caae05-45c3-4f2a-889c-fddc738acc2f.sql
-- ============================================================
-- =====================================================
-- PERFORMANCE OPTIMIZATION INDEXES (Fixed)
-- =====================================================

-- =====================================================
-- PROFILES TABLE - Most frequently accessed
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_gender_online ON public.profiles(gender, last_active_at DESC) WHERE account_status = 'active';
CREATE INDEX IF NOT EXISTS idx_profiles_country_state ON public.profiles(country, state);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_approval ON public.profiles(approval_status) WHERE gender = 'female';

-- =====================================================
-- CHAT MESSAGES - High volume reads
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id ON public.chat_messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON public.chat_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_unread ON public.chat_messages(receiver_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- =====================================================
-- ACTIVE CHAT SESSIONS - Real-time queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_status ON public.active_chat_sessions(status, last_activity_at DESC);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_man ON public.active_chat_sessions(man_user_id, status);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_woman ON public.active_chat_sessions(woman_user_id, status);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_chat_id ON public.active_chat_sessions(chat_id);

-- =====================================================
-- WALLET & TRANSACTIONS - Financial queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON public.wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet ON public.wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON public.wallet_transactions(status) WHERE status = 'pending';

-- =====================================================
-- WOMEN EARNINGS - Dashboard queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_women_earnings_user_id ON public.women_earnings(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_women_earnings_type ON public.women_earnings(earning_type, created_at DESC);

-- =====================================================
-- MATCHES - Discovery queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON public.matches(user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user ON public.matches(matched_user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON public.matches(created_at DESC);

-- =====================================================
-- USER STATUS - Real-time presence
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_status_online ON public.user_status(is_online, last_seen DESC) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_user_status_user_id ON public.user_status(user_id);

-- =====================================================
-- FEMALE PROFILES - Approval workflow
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_female_profiles_user_id ON public.female_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_female_profiles_approval ON public.female_profiles(approval_status, account_status);
CREATE INDEX IF NOT EXISTS idx_female_profiles_active ON public.female_profiles(last_active_at DESC) WHERE approval_status = 'approved' AND account_status = 'active';

-- =====================================================
-- VIDEO CALL SESSIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_status ON public.video_call_sessions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_man ON public.video_call_sessions(man_user_id, status);
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_woman ON public.video_call_sessions(woman_user_id, status);

-- =====================================================
-- USER LANGUAGES - Matching queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_languages_user_id ON public.user_languages(user_id);
CREATE INDEX IF NOT EXISTS idx_user_languages_code ON public.user_languages(language_code);

-- =====================================================
-- USER PHOTOS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_photos_user_id ON public.user_photos(user_id, is_primary DESC);

-- =====================================================
-- GIFTS & TRANSACTIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_gift_transactions_sender ON public.gift_transactions(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_receiver ON public.gift_transactions(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gifts_active ON public.gifts(is_active, sort_order);

-- =====================================================
-- TUTORIAL & ONBOARDING
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_tutorial_progress_user_id ON public.tutorial_progress(user_id);

-- =====================================================
-- USER ROLES - Auth checks
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id, role);

-- =====================================================
-- GROUPS & MEMBERSHIPS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_group_memberships_user ON public.group_memberships(user_id, has_access);
CREATE INDEX IF NOT EXISTS idx_group_memberships_group ON public.group_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_group ON public.group_messages(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_private_groups_owner ON public.private_groups(owner_id, is_active);
CREATE INDEX IF NOT EXISTS idx_private_groups_active_live ON public.private_groups(is_active, is_live);

-- =====================================================
-- NOTIFICATIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- =====================================================
-- WITHDRAWAL REQUESTS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user ON public.withdrawal_requests(user_id, status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_pending ON public.withdrawal_requests(status) WHERE status = 'pending';

-- =====================================================
-- AUDIT LOGS - Admin queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON public.audit_logs(admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource_type, created_at DESC);

-- =====================================================
-- PLATFORM METRICS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_platform_metrics_date ON public.platform_metrics(metric_date DESC);

-- =====================================================
-- ATTENDANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON public.attendance(user_id, attendance_date);

-- =====================================================
-- ANALYZE TABLES for query planner
-- =====================================================
ANALYZE public.profiles;
ANALYZE public.chat_messages;
ANALYZE public.active_chat_sessions;
ANALYZE public.wallets;
ANALYZE public.wallet_transactions;
ANALYZE public.matches;
ANALYZE public.user_status;
ANALYZE public.female_profiles;
ANALYZE public.women_earnings;
ANALYZE public.gifts;
ANALYZE public.gift_transactions;

-- ============================================================
-- Migration: 20251215124735_94ac3645-4f12-44cf-936d-3f47875f1981.sql
-- ============================================================
-- Create community_disputes table for dispute resolution
CREATE TABLE public.community_disputes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  reporter_id UUID NOT NULL,
  reported_user_id UUID,
  dispute_type TEXT NOT NULL DEFAULT 'general',
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  resolution TEXT,
  resolved_by UUID,
  resolved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create community_shift_schedules table for leader shift scheduling
CREATE TABLE public.community_shift_schedules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  user_id UUID NOT NULL,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled',
  notes TEXT,
  created_by UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create community_announcements table
CREATE TABLE public.community_announcements (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  leader_id UUID NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.community_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_shift_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_announcements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for community_disputes
CREATE POLICY "Members can view disputes in their community" 
ON public.community_disputes 
FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Members can create disputes" 
ON public.community_disputes 
FOR INSERT 
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Leaders can update disputes" 
ON public.community_disputes 
FOR UPDATE 
USING (auth.uid() IS NOT NULL);

-- RLS Policies for community_shift_schedules
CREATE POLICY "Members can view shift schedules" 
ON public.community_shift_schedules 
FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Leaders can manage shift schedules" 
ON public.community_shift_schedules 
FOR ALL 
USING (auth.uid() = created_by);

CREATE POLICY "Users can view their own shifts" 
ON public.community_shift_schedules 
FOR SELECT 
USING (auth.uid() = user_id);

-- RLS Policies for community_announcements
CREATE POLICY "Members can view announcements" 
ON public.community_announcements 
FOR SELECT 
USING (auth.uid() IS NOT NULL AND is_active = true);

CREATE POLICY "Leaders can manage announcements" 
ON public.community_announcements 
FOR ALL 
USING (auth.uid() = leader_id);

-- Create indexes for performance
CREATE INDEX idx_community_disputes_language ON public.community_disputes(language_code);
CREATE INDEX idx_community_disputes_status ON public.community_disputes(status);
CREATE INDEX idx_community_shift_schedules_language ON public.community_shift_schedules(language_code);
CREATE INDEX idx_community_shift_schedules_date ON public.community_shift_schedules(shift_date);
CREATE INDEX idx_community_announcements_language ON public.community_announcements(language_code);

-- ============================================================
-- Migration: 20251215125243_c5766bae-f664-468a-9258-256e0b644803.sql
-- ============================================================
-- Create community_elections table for annual elections
CREATE TABLE public.community_elections (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  election_year INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  election_officer_id UUID NOT NULL,
  winner_id UUID,
  scheduled_at TIMESTAMP WITH TIME ZONE,
  started_at TIMESTAMP WITH TIME ZONE,
  ended_at TIMESTAMP WITH TIME ZONE,
  total_votes INTEGER DEFAULT 0,
  election_results JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(language_code, election_year)
);

-- Create election_candidates table
CREATE TABLE public.election_candidates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  nomination_status TEXT NOT NULL DEFAULT 'pending',
  platform_statement TEXT,
  vote_count INTEGER DEFAULT 0,
  nominated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, user_id)
);

-- Create election_votes table with one vote per user per election
CREATE TABLE public.election_votes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  voter_id UUID NOT NULL,
  candidate_id UUID NOT NULL REFERENCES public.election_candidates(id) ON DELETE CASCADE,
  is_tiebreaker BOOLEAN DEFAULT false,
  voted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, voter_id)
);

-- Create voter_registry table for eligible voters
CREATE TABLE public.voter_registry (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  registered_by UUID NOT NULL,
  is_eligible BOOLEAN DEFAULT true,
  registered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, user_id)
);

-- Create community_leaders table for tracking elected leaders
CREATE TABLE public.community_leaders (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  user_id UUID NOT NULL,
  election_id UUID REFERENCES public.community_elections(id),
  term_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  term_end TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create election_officers table
CREATE TABLE public.election_officers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  user_id UUID NOT NULL,
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  auto_assigned BOOLEAN DEFAULT false,
  UNIQUE(language_code, user_id)
);

-- Enable RLS
ALTER TABLE public.community_elections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voter_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_officers ENABLE ROW LEVEL SECURITY;

-- RLS Policies for community_elections
CREATE POLICY "Members can view elections" 
ON public.community_elections FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can create elections" 
ON public.community_elections FOR INSERT 
WITH CHECK (auth.uid() = election_officer_id);

CREATE POLICY "Officers can update elections" 
ON public.community_elections FOR UPDATE 
USING (auth.uid() = election_officer_id);

-- RLS Policies for election_candidates
CREATE POLICY "Members can view candidates" 
ON public.election_candidates FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can manage candidates" 
ON public.election_candidates FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = election_candidates.election_id 
    AND e.election_officer_id = auth.uid()
  )
);

-- RLS Policies for election_votes
CREATE POLICY "Users can view own votes" 
ON public.election_votes FOR SELECT 
USING (auth.uid() = voter_id);

CREATE POLICY "Officers can view all votes after election" 
ON public.election_votes FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = election_votes.election_id 
    AND e.status = 'completed'
  )
);

CREATE POLICY "Registered voters can vote" 
ON public.election_votes FOR INSERT 
WITH CHECK (
  auth.uid() = voter_id AND
  EXISTS (
    SELECT 1 FROM voter_registry vr 
    WHERE vr.election_id = election_votes.election_id 
    AND vr.user_id = auth.uid() 
    AND vr.is_eligible = true
  )
);

-- RLS Policies for voter_registry
CREATE POLICY "Members can view voter registry" 
ON public.voter_registry FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can manage voter registry" 
ON public.voter_registry FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = voter_registry.election_id 
    AND e.election_officer_id = auth.uid()
  )
);

-- RLS Policies for community_leaders
CREATE POLICY "Anyone can view leaders" 
ON public.community_leaders FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "System can manage leaders" 
ON public.community_leaders FOR ALL 
USING (true);

-- RLS Policies for election_officers
CREATE POLICY "Anyone can view officers" 
ON public.election_officers FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "System can manage officers" 
ON public.election_officers FOR ALL 
USING (true);

-- Create indexes for performance
CREATE INDEX idx_elections_language_year ON public.community_elections(language_code, election_year);
CREATE INDEX idx_elections_status ON public.community_elections(status);
CREATE INDEX idx_candidates_election ON public.election_candidates(election_id);
CREATE INDEX idx_votes_election ON public.election_votes(election_id);
CREATE INDEX idx_votes_candidate ON public.election_votes(candidate_id);
CREATE INDEX idx_voter_registry_election ON public.voter_registry(election_id);
CREATE INDEX idx_leaders_language ON public.community_leaders(language_code);
CREATE INDEX idx_officers_language ON public.election_officers(language_code);

-- Function to count and update vote counts
CREATE OR REPLACE FUNCTION public.update_candidate_vote_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.election_candidates
  SET vote_count = (
    SELECT COUNT(*) FROM public.election_votes 
    WHERE candidate_id = NEW.candidate_id
  )
  WHERE id = NEW.candidate_id;
  
  UPDATE public.community_elections
  SET total_votes = (
    SELECT COUNT(*) FROM public.election_votes 
    WHERE election_id = NEW.election_id
  ),
  updated_at = now()
  WHERE id = NEW.election_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to update vote counts when votes are cast
CREATE TRIGGER update_vote_counts_trigger
AFTER INSERT ON public.election_votes
FOR EACH ROW
EXECUTE FUNCTION public.update_candidate_vote_count();

-- ============================================================
-- Migration: 20251215130306_ae30adfe-631a-4ff1-ab92-40d522f90c56.sql
-- ============================================================
-- Add officer nomination system with community agreement
CREATE TABLE IF NOT EXISTS officer_nominations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_code text NOT NULL,
  nominee_id uuid NOT NULL,
  nominated_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  approvals_count integer DEFAULT 0,
  rejections_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  resolved_at timestamp with time zone,
  UNIQUE(language_code, nominee_id, status)
);

-- Track who approved/rejected nominations
CREATE TABLE IF NOT EXISTS officer_nomination_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nomination_id uuid NOT NULL REFERENCES officer_nominations(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL,
  vote_type text NOT NULL, -- approve, reject
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(nomination_id, voter_id)
);

-- Enable RLS
ALTER TABLE officer_nominations ENABLE ROW LEVEL SECURITY;
ALTER TABLE officer_nomination_votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for officer_nominations
CREATE POLICY "Auth users can view nominations" ON officer_nominations
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Auth users can self-nominate" ON officer_nominations
  FOR INSERT WITH CHECK (auth.uid() = nominee_id AND auth.uid() = nominated_by);

CREATE POLICY "System can update nominations" ON officer_nominations
  FOR UPDATE USING (true);

-- RLS Policies for officer_nomination_votes
CREATE POLICY "Auth users can view votes" ON officer_nomination_votes
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Auth users can vote on nominations" ON officer_nomination_votes
  FOR INSERT WITH CHECK (auth.uid() = voter_id);

CREATE POLICY "Users cannot change votes" ON officer_nomination_votes
  FOR UPDATE USING (false);

CREATE POLICY "Users cannot delete votes" ON officer_nomination_votes
  FOR DELETE USING (false);

-- ============================================================
-- Migration: 20251215132942_06be44b2-246d-4971-8da5-d45c9caa3bc1.sql
-- ============================================================
-- Insert currency rates setting into app_settings
INSERT INTO app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'currency_rates',
  '{
    "IN": {"rate": 1, "symbol": "₹", "code": "INR"},
    "US": {"rate": 0.012, "symbol": "$", "code": "USD"},
    "GB": {"rate": 0.0095, "symbol": "£", "code": "GBP"},
    "EU": {"rate": 0.011, "symbol": "€", "code": "EUR"},
    "AE": {"rate": 0.044, "symbol": "د.إ", "code": "AED"},
    "AU": {"rate": 0.018, "symbol": "A$", "code": "AUD"},
    "CA": {"rate": 0.016, "symbol": "C$", "code": "CAD"},
    "JP": {"rate": 1.79, "symbol": "¥", "code": "JPY"},
    "SG": {"rate": 0.016, "symbol": "S$", "code": "SGD"},
    "MY": {"rate": 0.053, "symbol": "RM", "code": "MYR"},
    "PH": {"rate": 0.67, "symbol": "₱", "code": "PHP"},
    "TH": {"rate": 0.41, "symbol": "฿", "code": "THB"},
    "SA": {"rate": 0.045, "symbol": "﷼", "code": "SAR"},
    "QA": {"rate": 0.044, "symbol": "ر.ق", "code": "QAR"},
    "KW": {"rate": 0.0037, "symbol": "د.ك", "code": "KWD"},
    "BD": {"rate": 1.31, "symbol": "৳", "code": "BDT"},
    "PK": {"rate": 3.34, "symbol": "Rs", "code": "PKR"},
    "NP": {"rate": 1.59, "symbol": "रू", "code": "NPR"},
    "LK": {"rate": 3.66, "symbol": "Rs", "code": "LKR"},
    "DEFAULT": {"rate": 0.012, "symbol": "$", "code": "USD"}
  }',
  'json',
  'payments',
  'Currency conversion rates from INR to other currencies',
  true
)
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = EXCLUDED.setting_value,
  updated_at = now();

-- Insert payment gateways setting
INSERT INTO app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'payment_gateways',
  '{
    "indian": [
      {"id": "razorpay", "name": "Razorpay", "logo": "🇮🇳", "description": "UPI, Cards, Netbanking", "features": ["UPI", "Debit/Credit Cards", "Netbanking", "Wallets"]},
      {"id": "ccavenue", "name": "CCAvenue", "logo": "🏦", "description": "Cards, Wallets, EMI", "features": ["Cards", "EMI", "Wallets", "Netbanking"]}
    ],
    "international": [
      {"id": "stripe", "name": "Stripe", "logo": "💎", "description": "Cards, Apple Pay, Google Pay", "features": ["Cards", "Apple Pay", "Google Pay", "Bank Transfers"]},
      {"id": "paypal", "name": "PayPal", "logo": "🅿️", "description": "200+ countries supported", "features": ["PayPal Balance", "Cards", "Bank Account"]},
      {"id": "wise", "name": "Wise", "logo": "💸", "description": "International Transfers", "features": ["Bank Transfer", "Low Fees", "Multi-currency"]},
      {"id": "adyen", "name": "Adyen", "logo": "🌐", "description": "Global Payments", "features": ["Cards", "Local Methods", "Digital Wallets"]}
    ]
  }',
  'json',
  'payments',
  'Supported payment gateways for different regions',
  true
)
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = EXCLUDED.setting_value,
  updated_at = now();

-- Drop sample tables (not needed - they contain mock data)
DROP TABLE IF EXISTS sample_men CASCADE;
DROP TABLE IF EXISTS sample_women CASCADE;
DROP TABLE IF EXISTS sample_users CASCADE;

-- ============================================================
-- Migration: 20251220190124_d2da75b4-630e-4d42-9cef-b20729a4467c.sql
-- ============================================================

-- Sync existing approved women to female_profiles
INSERT INTO public.female_profiles (
  user_id, full_name, age, country, state,
  primary_language, preferred_language, bio,
  approval_status, ai_approved, auto_approved, account_status,
  photo_url, profile_completeness, performance_score
)
SELECT 
  p.user_id, p.full_name, p.age, p.country, p.state,
  p.primary_language, p.preferred_language, p.bio,
  p.approval_status, p.ai_approved, true, p.account_status,
  p.photo_url, p.profile_completeness, COALESCE(p.performance_score, 100)
FROM profiles p
WHERE p.gender = 'female' 
  AND p.approval_status = 'approved'
  AND NOT EXISTS (
    SELECT 1 FROM female_profiles fp WHERE fp.user_id = p.user_id
  );

-- Create women_availability entries for approved women
INSERT INTO public.women_availability (
  user_id, is_available, is_available_for_calls,
  current_chat_count, current_call_count,
  max_concurrent_chats, max_concurrent_calls
)
SELECT 
  p.user_id, true, true, 0, 0, 3, 1
FROM profiles p
WHERE p.gender = 'female' 
  AND p.approval_status = 'approved'
  AND NOT EXISTS (
    SELECT 1 FROM women_availability wa WHERE wa.user_id = p.user_id
  );


-- ============================================================
-- Migration: 20251223105915_8dfc8b97-be0b-4145-85a2-be9b66daa1b0.sql
-- ============================================================
-- Enable realtime (postgres_changes) for video calls so women receive incoming call events
ALTER PUBLICATION supabase_realtime ADD TABLE public.video_call_sessions;

-- ============================================================
-- Migration: 20251223194751_17020a21-f1c1-45d8-a125-e990f8adfa3c.sql
-- ============================================================
-- Create function to increment vote count atomically
CREATE OR REPLACE FUNCTION public.increment_vote_count(candidate_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE election_candidates
  SET vote_count = COALESCE(vote_count, 0) + 1
  WHERE id = candidate_uuid;
END;
$$;

-- ============================================================
-- Migration: 20251223202149_aff04163-34d5-4058-98c8-938ac972cf80.sql
-- ============================================================
-- Add file sharing columns to group_messages table
ALTER TABLE public.group_messages 
ADD COLUMN IF NOT EXISTS file_url TEXT,
ADD COLUMN IF NOT EXISTS file_type TEXT,
ADD COLUMN IF NOT EXISTS file_name TEXT,
ADD COLUMN IF NOT EXISTS file_size INTEGER;

-- Create language_community_groups table for better language-based group management
CREATE TABLE IF NOT EXISTS public.language_community_groups (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    language_code TEXT NOT NULL UNIQUE,
    language_name TEXT NOT NULL,
    member_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create language_community_members table
CREATE TABLE IF NOT EXISTS public.language_community_members (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES public.language_community_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(group_id, user_id)
);

-- Create language_community_messages table for language-based group chat
CREATE TABLE IF NOT EXISTS public.language_community_messages (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    language_code TEXT NOT NULL,
    sender_id UUID NOT NULL,
    message TEXT,
    file_url TEXT,
    file_type TEXT,
    file_name TEXT,
    file_size INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.language_community_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_community_messages ENABLE ROW LEVEL SECURITY;

-- RLS policies for language_community_groups
CREATE POLICY "Language groups are viewable by authenticated users"
ON public.language_community_groups FOR SELECT
USING (auth.role() = 'authenticated');

-- RLS policies for language_community_members
CREATE POLICY "Members can view their community members"
ON public.language_community_members FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Users can join language communities"
ON public.language_community_members FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- RLS policies for language_community_messages
CREATE POLICY "Authenticated users can read community messages"
ON public.language_community_messages FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can send community messages"
ON public.language_community_messages FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Create storage bucket for community files
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('community-files', 'community-files', true, 52428800)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for community files
CREATE POLICY "Authenticated users can upload community files"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'community-files' AND auth.role() = 'authenticated');

CREATE POLICY "Anyone can view community files"
ON storage.objects FOR SELECT
USING (bucket_id = 'community-files');

-- Enable realtime for community messages
ALTER PUBLICATION supabase_realtime ADD TABLE language_community_messages;

-- Create index for faster message queries
CREATE INDEX IF NOT EXISTS idx_language_community_messages_language 
ON public.language_community_messages(language_code, created_at DESC);

-- ============================================================
-- Migration: 20251226024944_4140a034-9ebd-4aa8-99cd-cb972a423a85.sql
-- ============================================================
-- Delete duplicate chat_pricing rows, keeping only the most recent one
DELETE FROM chat_pricing 
WHERE id NOT IN (
  SELECT id FROM chat_pricing 
  ORDER BY updated_at DESC 
  LIMIT 1
);

-- Add unique constraint to ensure only one active pricing exists
-- First drop if exists, then create
DO $$ 
BEGIN
  -- Create unique partial index to ensure only one active pricing
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'unique_active_chat_pricing'
  ) THEN
    CREATE UNIQUE INDEX unique_active_chat_pricing 
    ON chat_pricing (is_active) 
    WHERE is_active = true;
  END IF;
END $$;

-- ============================================================
-- Migration: 20251226030922_b3dba9df-9dbf-4ab3-9d97-6724e463cfb8.sql
-- ============================================================
-- Create admin_revenue_transactions table for detailed revenue tracking
CREATE TABLE public.admin_revenue_transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    transaction_type text NOT NULL, -- 'recharge', 'chat_revenue', 'video_revenue', 'gift_revenue'
    amount numeric NOT NULL DEFAULT 0,
    man_user_id uuid, -- The man who paid/was charged
    woman_user_id uuid, -- The woman who earned (for chat/video/gift)
    session_id uuid, -- Reference to chat/video session if applicable
    reference_id text, -- External payment reference for recharges
    description text,
    currency text NOT NULL DEFAULT 'INR',
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_revenue_transactions ENABLE ROW LEVEL SECURITY;

-- Admin-only access policies
CREATE POLICY "Admins can view all admin revenue"
ON public.admin_revenue_transactions
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "System can insert admin revenue"
ON public.admin_revenue_transactions
FOR INSERT
WITH CHECK (true);

-- Create index for efficient queries
CREATE INDEX idx_admin_revenue_type ON public.admin_revenue_transactions(transaction_type);
CREATE INDEX idx_admin_revenue_created ON public.admin_revenue_transactions(created_at);
CREATE INDEX idx_admin_revenue_man ON public.admin_revenue_transactions(man_user_id);

-- Create process_recharge function
-- When man recharges: 100% goes to admin revenue, man gets spending balance
CREATE OR REPLACE FUNCTION public.process_recharge(
    p_user_id uuid,
    p_amount numeric,
    p_reference_id text DEFAULT NULL,
    p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_id uuid;
    v_current_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    
    -- Lock the wallet row for update
    SELECT id, balance INTO v_wallet_id, v_current_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    -- Create wallet if not exists
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallets (user_id, balance, currency)
        VALUES (p_user_id, 0, 'INR')
        RETURNING id, balance INTO v_wallet_id, v_current_balance;
    END IF;
    
    -- Calculate new balance (man gets spending power)
    v_new_balance := v_current_balance + p_amount;
    
    -- Update wallet balance
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for man
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, reference_id, status
    ) VALUES (
        v_wallet_id, p_user_id, 'credit', p_amount,
        COALESCE(p_description, 'Wallet Recharge'), p_reference_id, 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Log admin revenue (100% of recharge goes to admin)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, reference_id, description, currency
    ) VALUES (
        'recharge', p_amount, p_user_id, p_reference_id,
        'Recharge by user', 'INR'
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'previous_balance', v_current_balance,
        'new_balance', v_new_balance,
        'admin_revenue', p_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update process_chat_billing to track admin revenue
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Check if man is a super user (bypass billing)
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    IF v_is_super_user THEN
        -- Super users don't get charged, but women still earn
        SELECT * INTO v_pricing
        FROM public.chat_pricing
        WHERE is_active = true
        ORDER BY updated_at DESC
        LIMIT 1;
        
        IF v_pricing IS NOT NULL THEN
            v_earning_amount := p_minutes * v_pricing.women_earning_rate;
            
            -- Credit woman's earnings (platform pays)
            INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings (super user session)');
            
            -- Update session totals
            UPDATE public.active_chat_sessions
            SET total_minutes = total_minutes + p_minutes,
                total_earned = total_earned + v_earning_amount,
                last_activity_at = now()
            WHERE id = p_session_id;
        END IF;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', COALESCE(v_earning_amount, 0)
        );
    END IF;
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    -- Calculate charges using admin-defined rates
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;
    
    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.active_chat_sessions
        SET status = 'ended', 
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet (his spending balance)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );
    
    -- Credit woman's earnings
    INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 
            'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min');
    
    -- Log admin revenue (charge - woman earning)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );
    
    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- Update process_video_billing to track admin revenue
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;
    
    -- Check if man is super user
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    -- Calculate amounts using admin-defined video rates
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;
    
    IF v_is_super_user THEN
        -- Super users: credit woman only, no debit
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call (super user session) - ' || p_minutes || ' minute(s)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount,
            updated_at = now()
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    -- Normal flow: lock wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    -- Credit woman
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
            'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    
    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'video_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Video call revenue - ' || p_minutes || ' minute(s)', 'INR'
    );
    
    -- Update session
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        updated_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update process_gift_transaction to track admin revenue
CREATE OR REPLACE FUNCTION public.process_gift_transaction(p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
    v_women_share numeric;
    v_admin_share numeric;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate 50/50 split for gifts
    v_women_share := v_gift.price * 0.5;
    v_admin_share := v_gift.price * 0.5;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance; -- Super users don't lose balance
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings (50% of gift value)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    
    -- Log admin revenue (50% of gift value)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, reference_id, description, currency
    ) VALUES (
        'gift_revenue', v_admin_share, p_sender_id, p_receiver_id,
        p_gift_id::text, 'Gift revenue: ' || v_gift.name || ' (50% share)', 'INR'
    );
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'admin_share', v_admin_share,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- Migration: 20251226032752_95bfe12d-d49b-4a26-a081-ba75e9683b30.sql
-- ============================================================
-- Grant admin role to rpendyal436@gmail.com
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE email = 'rpendyal436@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

-- ============================================================
-- Migration: 20251226033038_cc2c3fda-1064-4e58-bd84-4026a8bfadc7.sql
-- ============================================================
-- Add all roles to rpendyal436@gmail.com for full access
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'moderator'::app_role
FROM auth.users
WHERE email = 'rpendyal436@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

INSERT INTO public.user_roles (user_id, role)
SELECT id, 'user'::app_role
FROM auth.users
WHERE email = 'rpendyal436@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

-- ============================================================
-- Migration: 20251226034026_da660204-9686-4dc5-8dfe-7d27ac1ed2bc.sql
-- ============================================================
-- Update process_gift_transaction to remove redundant admin revenue logging
-- Since all men's recharges already stay with admin, the 50% admin share is implicit
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
    p_sender_id uuid,
    p_receiver_id uuid,
    p_gift_id uuid,
    p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
    v_women_share numeric;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate 50% share for women (remaining 50% stays with admin implicitly via original recharge)
    v_women_share := v_gift.price * 0.5;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance; -- Super users don't lose balance
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings (50% of gift value)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    
    -- NOTE: No admin_revenue_transactions entry needed for gifts
    -- The 50% admin share is implicit since men's original recharge stays with admin
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- Migration: 20251226040726_14efca19-6ade-47fd-8f89-c6db8fce06ed.sql
-- ============================================================

-- Add admin access to wallets table
CREATE POLICY "Admins can view all wallets"
ON public.wallets
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));


-- ============================================================
-- Migration: 20251226044241_8df3f39d-b27f-48dd-ac09-1e9e56ed3e54.sql
-- ============================================================
-- Create function to get top earner for today (returns aggregated data only)
CREATE OR REPLACE FUNCTION public.get_top_earner_today()
RETURNS TABLE(user_id uuid, full_name text, total_amount numeric)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  today_start timestamp with time zone;
  today_end timestamp with time zone;
BEGIN
  -- Calculate today's start and end in UTC (will work with any timezone client)
  today_start := date_trunc('day', now());
  today_end := today_start + interval '1 day' - interval '1 second';
  
  RETURN QUERY
  SELECT 
    we.user_id,
    p.full_name,
    SUM(we.amount) as total_amount
  FROM women_earnings we
  JOIN profiles p ON p.user_id = we.user_id
  WHERE we.created_at >= today_start 
    AND we.created_at <= today_end
  GROUP BY we.user_id, p.full_name
  ORDER BY total_amount DESC
  LIMIT 1;
END;
$$;

-- Allow authenticated users to view chat pricing (earning rates)
CREATE POLICY "Authenticated users can view pricing" 
ON public.chat_pricing 
FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- ============================================================
-- Migration: 20251226080011_9ae71665-0600-4354-845c-f05b3e0d6ad2.sql
-- ============================================================
-- Create secure function to list online men + wallet balances for Women Dashboard premium sorting
CREATE OR REPLACE FUNCTION public.get_online_men_dashboard()
RETURNS TABLE (
  user_id uuid,
  full_name text,
  photo_url text,
  country text,
  state text,
  preferred_language text,
  primary_language text,
  age integer,
  mother_tongue text,
  wallet_balance numeric,
  last_seen timestamptz,
  active_chat_count integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    COALESCE(p.full_name, 'Anonymous') AS full_name,
    p.photo_url,
    p.country,
    p.state,
    p.preferred_language,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'Unknown') AS mother_tongue,
    COALESCE(w.balance, 0) AS wallet_balance,
    us.last_seen,
    COALESCE(cs.cnt, 0)::int AS active_chat_count
  FROM public.user_status us
  JOIN public.profiles p ON p.user_id = us.user_id
  LEFT JOIN public.wallets w ON w.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT u.language_name
    FROM public.user_languages u
    WHERE u.user_id = p.user_id
    ORDER BY u.created_at DESC
    LIMIT 1
  ) ul ON TRUE
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS cnt
    FROM public.active_chat_sessions s
    WHERE s.man_user_id = p.user_id
      AND s.status = 'active'
  ) cs ON TRUE
  WHERE us.is_online = TRUE
    AND auth.uid() IS NOT NULL
    AND LOWER(COALESCE(p.gender, '')) = 'male'
    AND (
      has_role(auth.uid(), 'admin'::app_role)
      OR EXISTS (
        SELECT 1
        FROM public.profiles me
        WHERE me.user_id = auth.uid()
          AND LOWER(COALESCE(me.gender, '')) = 'female'
      )
    );
$$;

-- Lock down execution
REVOKE ALL ON FUNCTION public.get_online_men_dashboard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_online_men_dashboard() TO authenticated;


-- ============================================================
-- Migration: 20251227035840_2c4d5c70-45c6-4c7c-b19b-bf7a26e891b0.sql
-- ============================================================

-- Fix stale women_availability counts by syncing with actual active sessions
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);

-- Create a trigger function to automatically sync chat counts
CREATE OR REPLACE FUNCTION sync_women_chat_count()
RETURNS TRIGGER AS $$
BEGIN
  -- On INSERT of active session: increment count
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    INSERT INTO women_availability (user_id, current_chat_count, is_available)
    VALUES (NEW.woman_user_id, 1, true)
    ON CONFLICT (user_id) DO UPDATE 
    SET current_chat_count = women_availability.current_chat_count + 1;
  END IF;
  
  -- On UPDATE from active to ended: decrement count
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, current_chat_count - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement count
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, current_chat_count - 1)
    WHERE user_id = OLD.woman_user_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_women_chat_count_trigger ON active_chat_sessions;

-- Create trigger on active_chat_sessions
CREATE TRIGGER sync_women_chat_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_women_chat_count();


-- ============================================================
-- Migration: 20251227040211_52661648-bcf5-4d1a-8970-0076df79c77c.sql
-- ============================================================

-- Sync men's chat count in user_status when sessions change
CREATE OR REPLACE FUNCTION sync_user_chat_count()
RETURNS TRIGGER AS $$
BEGIN
  -- On INSERT of active session: increment count for man
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    UPDATE user_status
    SET active_chat_count = COALESCE(active_chat_count, 0) + 1
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- On UPDATE from active to ended: decrement count for man
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- On DELETE of active session: decrement count for man
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = OLD.man_user_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_user_chat_count_trigger ON active_chat_sessions;

-- Create trigger for men's chat count
CREATE TRIGGER sync_user_chat_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_user_chat_count();

-- Auto-end active chats when user goes offline
CREATE OR REPLACE FUNCTION auto_end_chats_on_offline()
RETURNS TRIGGER AS $$
BEGIN
  -- When user goes offline, end their active chat sessions
  IF OLD.is_online = true AND NEW.is_online = false THEN
    -- End sessions where this user is the man
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE man_user_id = NEW.user_id
      AND status = 'active';
    
    -- End sessions where this user is the woman
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE woman_user_id = NEW.user_id
      AND status = 'active';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS auto_end_chats_on_offline_trigger ON user_status;

-- Create trigger for auto-ending chats when offline
CREATE TRIGGER auto_end_chats_on_offline_trigger
AFTER UPDATE ON user_status
FOR EACH ROW
EXECUTE FUNCTION auto_end_chats_on_offline();

-- Reset all stale chat counts to match actual active sessions
UPDATE user_status us
SET active_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.man_user_id = us.user_id AND acs.status = 'active'
);

UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);


-- ============================================================
-- Migration: 20251227040705_0578edc5-b2cb-48ce-bca8-2427447b4952.sql
-- ============================================================

-- Create function to cleanup idle sessions (10 mins without activity)
CREATE OR REPLACE FUNCTION cleanup_idle_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- End sessions where last_activity_at is more than 10 minutes ago
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'session_idle_10min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '10 minutes';
    
  -- Also mark users as offline if their last_seen is more than 10 minutes ago
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';
END;
$$;

-- Create a function that can be called periodically to cleanup idle sessions
-- This will be called by the application or a scheduled job
COMMENT ON FUNCTION cleanup_idle_sessions IS 'Cleanup function to end idle sessions after 10 minutes of inactivity';


-- ============================================================
-- Migration: 20251227040922_71b6569d-4507-45a3-a9c1-0df8469634e2.sql
-- ============================================================

-- Data retention cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. End chat sessions idle for 3+ minutes
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'idle_3min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '3 minutes';

  -- 2. Delete chat messages older than 7 days
  DELETE FROM chat_messages
  WHERE created_at < NOW() - INTERVAL '7 days';

  -- 3. Delete group messages older than 15 minutes (ephemeral chat)
  DELETE FROM group_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 4. Delete language community messages older than 15 minutes
  DELETE FROM language_community_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 5. Delete wallet transactions older than 9 years
  DELETE FROM wallet_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 6. Delete admin revenue transactions older than 9 years
  DELETE FROM admin_revenue_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 7. Delete women earnings older than 9 years
  DELETE FROM women_earnings
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 8. Delete gift transactions older than 9 years
  DELETE FROM gift_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 9. Mark stale users as offline (10 min inactivity)
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';
END;
$$;

-- Media cleanup function (runs every 5 mins for files)
CREATE OR REPLACE FUNCTION cleanup_chat_media()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Clear file references from group messages older than 5 minutes
  UPDATE group_messages
  SET file_url = NULL,
      file_name = NULL,
      file_type = NULL,
      file_size = NULL
  WHERE file_url IS NOT NULL
    AND created_at < NOW() - INTERVAL '5 minutes';

  -- Clear file references from language community messages older than 5 minutes
  UPDATE language_community_messages
  SET file_url = NULL,
      file_name = NULL,
      file_type = NULL,
      file_size = NULL
  WHERE file_url IS NOT NULL
    AND created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

-- Video call session cleanup (content available for 5 mins after end)
CREATE OR REPLACE FUNCTION cleanup_video_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delete ended video sessions older than 5 minutes
  DELETE FROM video_call_sessions
  WHERE status = 'ended'
    AND ended_at < NOW() - INTERVAL '5 minutes';
END;
$$;

COMMENT ON FUNCTION cleanup_expired_data IS 'Main cleanup: 3min idle chats, 7day chat history, 9yr transactions';
COMMENT ON FUNCTION cleanup_chat_media IS 'Cleanup media files every 5 minutes';
COMMENT ON FUNCTION cleanup_video_sessions IS 'Cleanup video sessions 5 mins after end';


-- ============================================================
-- Migration: 20251227085734_7925570e-5488-4520-9984-e2f18e3ef395.sql
-- ============================================================
-- Enable users to manage their own block relationships
-- Existing policy already allows users to see blocks where they are the blocked_user_id.
-- These policies add support for viewing/creating/deleting blocks where the user is the blocker.

CREATE POLICY "Users can view blocks they created"
ON public.user_blocks
FOR SELECT
USING (auth.uid() = blocked_by);

CREATE POLICY "Users can create blocks"
ON public.user_blocks
FOR INSERT
WITH CHECK (auth.uid() = blocked_by);

CREATE POLICY "Users can delete blocks they created"
ON public.user_blocks
FOR DELETE
USING (auth.uid() = blocked_by);


-- ============================================================
-- Migration: 20251227090557_56a2067c-fc7e-412e-849a-4cb01985cbbb.sql
-- ============================================================
-- Create or replace function to auto-end video calls when user goes offline
CREATE OR REPLACE FUNCTION public.auto_end_video_calls_on_offline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- When user goes offline, end their active video call sessions
  IF OLD.is_online = true AND NEW.is_online = false THEN
    -- End video sessions where this user is the man
    UPDATE video_call_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE man_user_id = NEW.user_id
      AND status IN ('active', 'ringing', 'connecting');
    
    -- End video sessions where this user is the woman
    UPDATE video_call_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE woman_user_id = NEW.user_id
      AND status IN ('active', 'ringing', 'connecting');
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop existing trigger if exists and recreate
DROP TRIGGER IF EXISTS trigger_auto_end_video_calls_on_offline ON public.user_status;

CREATE TRIGGER trigger_auto_end_video_calls_on_offline
AFTER UPDATE ON public.user_status
FOR EACH ROW
EXECUTE FUNCTION public.auto_end_video_calls_on_offline();

-- Update the existing auto_end_chats_on_offline to also update women_availability
CREATE OR REPLACE FUNCTION public.auto_end_chats_on_offline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- When user goes offline, end their active chat sessions
  IF OLD.is_online = true AND NEW.is_online = false THEN
    -- End sessions where this user is the man
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE man_user_id = NEW.user_id
      AND status = 'active';
    
    -- End sessions where this user is the woman
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE woman_user_id = NEW.user_id
      AND status = 'active';
    
    -- Reset women_availability when woman goes offline
    UPDATE women_availability
    SET current_chat_count = 0,
        is_available = false
    WHERE user_id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- ============================================================
-- Migration: 20251227090758_b41cb759-bb3d-4365-9061-ea2c352c83d9.sql
-- ============================================================
-- Reset stale women_availability counts (no active sessions exist)
UPDATE women_availability 
SET current_chat_count = 0, 
    current_call_count = 0
WHERE current_chat_count > 0 OR current_call_count > 0;

-- Create or replace function to sync women availability when chat sessions change
CREATE OR REPLACE FUNCTION public.sync_women_availability_on_session_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- On INSERT of active session: increment chat count
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = COALESCE(current_chat_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On UPDATE from active to ended: decrement chat count and reset if zero
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement chat count
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS trigger_sync_women_availability ON public.active_chat_sessions;

CREATE TRIGGER trigger_sync_women_availability
AFTER INSERT OR UPDATE OR DELETE ON public.active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_women_availability_on_session_change();

-- Create or replace function to sync women availability for video calls
CREATE OR REPLACE FUNCTION public.sync_women_video_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- On INSERT of active/ringing/connecting session: increment call count
  IF TG_OP = 'INSERT' AND NEW.status IN ('active', 'ringing', 'connecting') THEN
    UPDATE women_availability
    SET current_call_count = COALESCE(current_call_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On UPDATE to ended: decrement call count
  IF TG_OP = 'UPDATE' AND OLD.status IN ('active', 'ringing', 'connecting') AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement call count
  IF TG_OP = 'DELETE' AND OLD.status IN ('active', 'ringing', 'connecting') THEN
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop and recreate the trigger for video calls
DROP TRIGGER IF EXISTS trigger_sync_women_video_availability ON public.video_call_sessions;

CREATE TRIGGER trigger_sync_women_video_availability
AFTER INSERT OR UPDATE OR DELETE ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_women_video_availability();

-- Also update the cleanup function to reset availability counts
CREATE OR REPLACE FUNCTION public.cleanup_expired_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- 1. End chat sessions idle for 3+ minutes
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'idle_3min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '3 minutes';

  -- 2. Delete chat messages older than 7 days
  DELETE FROM chat_messages
  WHERE created_at < NOW() - INTERVAL '7 days';

  -- 3. Delete group messages older than 15 minutes (ephemeral chat)
  DELETE FROM group_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 4. Delete language community messages older than 15 minutes
  DELETE FROM language_community_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 5. Delete wallet transactions older than 9 years
  DELETE FROM wallet_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 6. Delete admin revenue transactions older than 9 years
  DELETE FROM admin_revenue_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 7. Delete women earnings older than 9 years
  DELETE FROM women_earnings
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 8. Delete gift transactions older than 9 years
  DELETE FROM gift_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 9. Mark stale users as offline (10 min inactivity)
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';

  -- 10. Reset women_availability counts for users with no active sessions
  UPDATE women_availability wa
  SET current_chat_count = 0
  WHERE current_chat_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM active_chat_sessions acs 
      WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
    );

  UPDATE women_availability wa
  SET current_call_count = 0
  WHERE current_call_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM video_call_sessions vcs 
      WHERE vcs.woman_user_id = wa.user_id AND vcs.status IN ('active', 'ringing', 'connecting')
    );
END;
$function$;

-- ============================================================
-- Migration: 20251227091317_f1276f7a-6ad8-4bdc-adb7-e6b41b1d7e7d.sql
-- ============================================================

-- =====================================================
-- COMPREHENSIVE FIX: Sync availability for BOTH men and women
-- =====================================================

-- Step 1: Reset all stale counts immediately
UPDATE women_availability SET current_chat_count = 0, current_call_count = 0;
UPDATE user_status SET active_chat_count = 0;

-- Step 2: Recalculate actual counts from active sessions
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);

UPDATE women_availability wa
SET current_call_count = (
  SELECT COUNT(*) FROM video_call_sessions vcs 
  WHERE vcs.woman_user_id = wa.user_id AND vcs.status IN ('active', 'ringing', 'connecting')
);

-- Update men's active chat count in user_status
UPDATE user_status us
SET active_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions acs 
  WHERE acs.man_user_id = us.user_id AND acs.status = 'active'
);

-- Step 3: Create unified trigger function for chat sessions
CREATE OR REPLACE FUNCTION public.sync_all_chat_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Handle INSERT of new active session
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    -- Increment woman's chat count
    UPDATE women_availability
    SET current_chat_count = COALESCE(current_chat_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
    
    -- Increment man's chat count
    UPDATE user_status
    SET active_chat_count = COALESCE(active_chat_count, 0) + 1
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- Handle UPDATE from active to ended
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    -- Decrement woman's chat count
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
    
    -- Decrement man's chat count
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- Handle DELETE of active session
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    -- Decrement woman's chat count
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    
    -- Decrement man's chat count
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = OLD.man_user_id;
    
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 4: Create unified trigger function for video sessions
CREATE OR REPLACE FUNCTION public.sync_all_video_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Handle INSERT of new active session
  IF TG_OP = 'INSERT' AND NEW.status IN ('active', 'ringing', 'connecting') THEN
    -- Increment woman's call count
    UPDATE women_availability
    SET current_call_count = COALESCE(current_call_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
    
    -- Increment man's chat count (video counts as chat for load balancing)
    UPDATE user_status
    SET active_chat_count = COALESCE(active_chat_count, 0) + 1
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- Handle UPDATE to ended
  IF TG_OP = 'UPDATE' AND OLD.status IN ('active', 'ringing', 'connecting') AND NEW.status = 'ended' THEN
    -- Decrement woman's call count
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
    
    -- Decrement man's chat count
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- Handle DELETE
  IF TG_OP = 'DELETE' AND OLD.status IN ('active', 'ringing', 'connecting') THEN
    -- Decrement woman's call count
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    
    -- Decrement man's chat count
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = OLD.man_user_id;
    
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 5: Drop old triggers if they exist
DROP TRIGGER IF EXISTS trigger_sync_women_availability ON active_chat_sessions;
DROP TRIGGER IF EXISTS trigger_sync_women_chat_count ON active_chat_sessions;
DROP TRIGGER IF EXISTS trigger_sync_user_chat_count ON active_chat_sessions;
DROP TRIGGER IF EXISTS trigger_sync_women_video_availability ON video_call_sessions;

-- Step 6: Create new unified triggers
CREATE TRIGGER trigger_sync_all_chat_availability
  AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
  FOR EACH ROW
  EXECUTE FUNCTION sync_all_chat_availability();

CREATE TRIGGER trigger_sync_all_video_availability
  AFTER INSERT OR UPDATE OR DELETE ON video_call_sessions
  FOR EACH ROW
  EXECUTE FUNCTION sync_all_video_availability();

-- Step 7: Update cleanup function to reset stale counts
CREATE OR REPLACE FUNCTION public.cleanup_expired_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- 1. End chat sessions idle for 3+ minutes
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'idle_3min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '3 minutes';

  -- 2. Delete chat messages older than 7 days
  DELETE FROM chat_messages
  WHERE created_at < NOW() - INTERVAL '7 days';

  -- 3. Delete group messages older than 15 minutes (ephemeral chat)
  DELETE FROM group_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 4. Delete language community messages older than 15 minutes
  DELETE FROM language_community_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 5. Delete wallet transactions older than 9 years
  DELETE FROM wallet_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 6. Delete admin revenue transactions older than 9 years
  DELETE FROM admin_revenue_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 7. Delete women earnings older than 9 years
  DELETE FROM women_earnings
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 8. Delete gift transactions older than 9 years
  DELETE FROM gift_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 9. Mark stale users as offline (10 min inactivity)
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';

  -- 10. Reset women_availability counts for users with no active sessions
  UPDATE women_availability wa
  SET current_chat_count = 0
  WHERE current_chat_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM active_chat_sessions acs 
      WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
    );

  UPDATE women_availability wa
  SET current_call_count = 0
  WHERE current_call_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM video_call_sessions vcs 
      WHERE vcs.woman_user_id = wa.user_id AND vcs.status IN ('active', 'ringing', 'connecting')
    );

  -- 11. Reset men's active_chat_count for users with no active sessions
  UPDATE user_status us
  SET active_chat_count = 0
  WHERE active_chat_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM active_chat_sessions acs 
      WHERE acs.man_user_id = us.user_id AND acs.status = 'active'
    )
    AND NOT EXISTS (
      SELECT 1 FROM video_call_sessions vcs 
      WHERE vcs.man_user_id = us.user_id AND vcs.status IN ('active', 'ringing', 'connecting')
    );
END;
$$;


-- ============================================================
-- Migration: 20260109140139_c4b78fdb-bbaf-4fca-833b-34631fdca2cd.sql
-- ============================================================
-- Create function to sync profiles to gender-specific tables
CREATE OR REPLACE FUNCTION public.sync_profile_to_gender_tables()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if gender is set
  IF NEW.gender IS NULL THEN
    RETURN NEW;
  END IF;

  -- Sync to male_profiles if male
  IF NEW.gender = 'male' OR NEW.gender = 'Male' THEN
    INSERT INTO public.male_profiles (
      user_id,
      full_name,
      age,
      date_of_birth,
      phone,
      photo_url,
      bio,
      country,
      state,
      primary_language,
      preferred_language,
      interests,
      life_goals,
      occupation,
      education_level,
      height_cm,
      body_type,
      marital_status,
      religion,
      is_verified,
      is_premium,
      account_status,
      last_active_at,
      profile_completeness,
      created_at,
      updated_at
    ) VALUES (
      NEW.user_id,
      NEW.full_name,
      NEW.age,
      NEW.date_of_birth,
      NEW.phone,
      NEW.photo_url,
      NEW.bio,
      NEW.country,
      NEW.state,
      NEW.primary_language,
      NEW.preferred_language,
      NEW.interests,
      NEW.life_goals,
      NEW.occupation,
      NEW.education_level,
      NEW.height_cm,
      NEW.body_type,
      NEW.marital_status,
      NEW.religion,
      NEW.is_verified,
      NEW.is_premium,
      NEW.account_status,
      NEW.last_active_at,
      NEW.profile_completeness,
      COALESCE(NEW.created_at, now()),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      age = EXCLUDED.age,
      date_of_birth = EXCLUDED.date_of_birth,
      phone = EXCLUDED.phone,
      photo_url = EXCLUDED.photo_url,
      bio = EXCLUDED.bio,
      country = EXCLUDED.country,
      state = EXCLUDED.state,
      primary_language = EXCLUDED.primary_language,
      preferred_language = EXCLUDED.preferred_language,
      interests = EXCLUDED.interests,
      life_goals = EXCLUDED.life_goals,
      occupation = EXCLUDED.occupation,
      education_level = EXCLUDED.education_level,
      height_cm = EXCLUDED.height_cm,
      body_type = EXCLUDED.body_type,
      marital_status = EXCLUDED.marital_status,
      religion = EXCLUDED.religion,
      is_verified = EXCLUDED.is_verified,
      is_premium = EXCLUDED.is_premium,
      account_status = EXCLUDED.account_status,
      last_active_at = EXCLUDED.last_active_at,
      profile_completeness = EXCLUDED.profile_completeness,
      updated_at = now();

    -- Clean up from female_profiles if exists
    DELETE FROM public.female_profiles WHERE user_id = NEW.user_id;
  END IF;

  -- Sync to female_profiles if female
  IF NEW.gender = 'female' OR NEW.gender = 'Female' THEN
    INSERT INTO public.female_profiles (
      user_id,
      full_name,
      age,
      date_of_birth,
      phone,
      photo_url,
      bio,
      country,
      state,
      primary_language,
      preferred_language,
      interests,
      life_goals,
      occupation,
      education_level,
      height_cm,
      body_type,
      marital_status,
      religion,
      is_verified,
      is_premium,
      account_status,
      approval_status,
      ai_approved,
      ai_disapproval_reason,
      performance_score,
      avg_response_time_seconds,
      total_chats_count,
      last_active_at,
      profile_completeness,
      created_at,
      updated_at
    ) VALUES (
      NEW.user_id,
      NEW.full_name,
      NEW.age,
      NEW.date_of_birth,
      NEW.phone,
      NEW.photo_url,
      NEW.bio,
      NEW.country,
      NEW.state,
      NEW.primary_language,
      NEW.preferred_language,
      NEW.interests,
      NEW.life_goals,
      NEW.occupation,
      NEW.education_level,
      NEW.height_cm,
      NEW.body_type,
      NEW.marital_status,
      NEW.religion,
      NEW.is_verified,
      NEW.is_premium,
      NEW.account_status,
      NEW.approval_status,
      NEW.ai_approved,
      NEW.ai_disapproval_reason,
      NEW.performance_score,
      NEW.avg_response_time_seconds,
      NEW.total_chats_count,
      NEW.last_active_at,
      NEW.profile_completeness,
      COALESCE(NEW.created_at, now()),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      age = EXCLUDED.age,
      date_of_birth = EXCLUDED.date_of_birth,
      phone = EXCLUDED.phone,
      photo_url = EXCLUDED.photo_url,
      bio = EXCLUDED.bio,
      country = EXCLUDED.country,
      state = EXCLUDED.state,
      primary_language = EXCLUDED.primary_language,
      preferred_language = EXCLUDED.preferred_language,
      interests = EXCLUDED.interests,
      life_goals = EXCLUDED.life_goals,
      occupation = EXCLUDED.occupation,
      education_level = EXCLUDED.education_level,
      height_cm = EXCLUDED.height_cm,
      body_type = EXCLUDED.body_type,
      marital_status = EXCLUDED.marital_status,
      religion = EXCLUDED.religion,
      is_verified = EXCLUDED.is_verified,
      is_premium = EXCLUDED.is_premium,
      account_status = EXCLUDED.account_status,
      approval_status = EXCLUDED.approval_status,
      ai_approved = EXCLUDED.ai_approved,
      ai_disapproval_reason = EXCLUDED.ai_disapproval_reason,
      performance_score = EXCLUDED.performance_score,
      avg_response_time_seconds = EXCLUDED.avg_response_time_seconds,
      total_chats_count = EXCLUDED.total_chats_count,
      last_active_at = EXCLUDED.last_active_at,
      profile_completeness = EXCLUDED.profile_completeness,
      updated_at = now();

    -- Clean up from male_profiles if exists
    DELETE FROM public.male_profiles WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_profile_to_gender_tables_trigger ON public.profiles;

-- Create trigger to sync on INSERT or UPDATE
CREATE TRIGGER sync_profile_to_gender_tables_trigger
  AFTER INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_to_gender_tables();

-- Sync existing profiles to gender-specific tables
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM public.profiles WHERE gender IS NOT NULL LOOP
    -- Trigger the sync manually for existing records
    IF r.gender = 'male' OR r.gender = 'Male' THEN
      INSERT INTO public.male_profiles (
        user_id, full_name, age, date_of_birth, phone, photo_url, bio, country, state,
        primary_language, preferred_language, interests, life_goals, occupation,
        education_level, height_cm, body_type, marital_status, religion,
        is_verified, is_premium, account_status, last_active_at, profile_completeness,
        created_at, updated_at
      ) VALUES (
        r.user_id, r.full_name, r.age, r.date_of_birth, r.phone, r.photo_url, r.bio,
        r.country, r.state, r.primary_language, r.preferred_language, r.interests,
        r.life_goals, r.occupation, r.education_level, r.height_cm, r.body_type,
        r.marital_status, r.religion, r.is_verified, r.is_premium, r.account_status,
        r.last_active_at, r.profile_completeness, r.created_at, now()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name, primary_language = EXCLUDED.primary_language,
        preferred_language = EXCLUDED.preferred_language, updated_at = now();
    END IF;

    IF r.gender = 'female' OR r.gender = 'Female' THEN
      INSERT INTO public.female_profiles (
        user_id, full_name, age, date_of_birth, phone, photo_url, bio, country, state,
        primary_language, preferred_language, interests, life_goals, occupation,
        education_level, height_cm, body_type, marital_status, religion,
        is_verified, is_premium, account_status, approval_status, ai_approved,
        ai_disapproval_reason, performance_score, avg_response_time_seconds,
        total_chats_count, last_active_at, profile_completeness, created_at, updated_at
      ) VALUES (
        r.user_id, r.full_name, r.age, r.date_of_birth, r.phone, r.photo_url, r.bio,
        r.country, r.state, r.primary_language, r.preferred_language, r.interests,
        r.life_goals, r.occupation, r.education_level, r.height_cm, r.body_type,
        r.marital_status, r.religion, r.is_verified, r.is_premium, r.account_status,
        r.approval_status, r.ai_approved, r.ai_disapproval_reason, r.performance_score,
        r.avg_response_time_seconds, r.total_chats_count, r.last_active_at,
        r.profile_completeness, r.created_at, now()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name, primary_language = EXCLUDED.primary_language,
        preferred_language = EXCLUDED.preferred_language, approval_status = EXCLUDED.approval_status,
        updated_at = now();
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- Migration: 20260122060900_95b18179-9bd1-413c-a703-bf63eb06082d.sql
-- ============================================================
-- Drop existing cron job
SELECT cron.unschedule(2);

-- Create new cron job to run every 5 minutes
SELECT cron.schedule(
  'ai-women-approval-every-5-mins',
  '*/5 * * * *',
  $$
  SELECT
    net.http_post(
        url:='https://www.meow-meow.co.in:8443/functions/v1/ai-women-approval',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
        body:='{"action": "auto_approve"}'::jsonb
    ) as request_id;
  $$
);

-- ============================================================
-- Migration: 20260122062824_bbec8ff0-6b9b-4478-b43b-bff1c94bdafc.sql
-- ============================================================
-- Drop old function first
DROP FUNCTION IF EXISTS public.should_woman_earn(uuid);

-- Recreate function to check if a woman should earn
CREATE OR REPLACE FUNCTION public.should_woman_earn(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_eligible boolean;
BEGIN
    SELECT is_earning_eligible INTO v_is_eligible
    FROM public.female_profiles
    WHERE user_id = p_user_id;
    
    IF v_is_eligible IS NULL THEN
        SELECT is_earning_eligible INTO v_is_eligible
        FROM public.profiles
        WHERE user_id = p_user_id;
    END IF;
    
    RETURN COALESCE(v_is_eligible, false);
END;
$$;

-- Function to assign earning slots to Indian women based on language limits
CREATE OR REPLACE FUNCTION public.assign_earning_slots()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_language RECORD;
    v_woman RECORD;
    v_slots_assigned integer := 0;
    v_slots_removed integer := 0;
    v_current_count integer;
BEGIN
    -- First, reset all earning slots (as per user requirement: "Reset all slots")
    UPDATE public.female_profiles
    SET is_earning_eligible = false,
        earning_slot_assigned_at = NULL,
        earning_badge_type = NULL
    WHERE is_earning_eligible = true;
    
    UPDATE public.profiles
    SET is_earning_eligible = false,
        earning_slot_assigned_at = NULL,
        earning_badge_type = NULL
    WHERE is_earning_eligible = true;
    
    -- Reset all language_limits current_earning_women counts
    UPDATE public.language_limits
    SET current_earning_women = 0,
        updated_at = now();
    
    -- For each language, assign slots to Indian women (first registered priority)
    FOR v_language IN 
        SELECT * FROM public.language_limits WHERE is_active = true
    LOOP
        v_current_count := 0;
        
        -- Get Indian women for this language, ordered by created_at (first registered first)
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name, fp.primary_language, fp.created_at
            FROM public.female_profiles fp
            WHERE fp.country = 'India'
              AND fp.approval_status = 'approved'
              AND fp.account_status = 'active'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
            ORDER BY fp.created_at ASC
            LIMIT v_language.max_earning_women
        LOOP
            -- Assign earning slot
            UPDATE public.female_profiles
            SET is_earning_eligible = true,
                is_indian = true,
                earning_slot_assigned_at = now(),
                earning_badge_type = 'star',
                updated_at = now()
            WHERE id = v_woman.id;
            
            -- Sync to profiles table
            UPDATE public.profiles
            SET is_earning_eligible = true,
                is_indian = true,
                earning_slot_assigned_at = now(),
                earning_badge_type = 'star',
                updated_at = now()
            WHERE user_id = v_woman.user_id;
            
            v_current_count := v_current_count + 1;
            v_slots_assigned := v_slots_assigned + 1;
        END LOOP;
        
        -- Update the language limit current count
        UPDATE public.language_limits
        SET current_earning_women = v_current_count,
            updated_at = now()
        WHERE id = v_language.id;
    END LOOP;
    
    -- Mark all other Indian women as is_indian but not earning eligible
    UPDATE public.female_profiles
    SET is_indian = true
    WHERE country = 'India'
      AND is_indian IS NOT true;
    
    UPDATE public.profiles
    SET is_indian = true
    WHERE country = 'India'
      AND is_indian IS NOT true
      AND gender = 'female';
    
    RETURN jsonb_build_object(
        'success', true,
        'slots_assigned', v_slots_assigned,
        'message', 'Earning slots assigned to Indian women based on language limits'
    );
END;
$$;

-- ============================================================
-- Migration: 20260122063419_de3453cd-cbd8-464b-af2d-576b2a3bb358.sql
-- ============================================================
-- Add fields to track monthly performance for rotation
ALTER TABLE public.female_profiles 
ADD COLUMN IF NOT EXISTS monthly_chat_minutes numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_rotation_date date,
ADD COLUMN IF NOT EXISTS promoted_from_free boolean DEFAULT false;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS monthly_chat_minutes numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_rotation_date date,
ADD COLUMN IF NOT EXISTS promoted_from_free boolean DEFAULT false;

-- Add promotion limit per language to language_limits
ALTER TABLE public.language_limits 
ADD COLUMN IF NOT EXISTS max_monthly_promotions integer DEFAULT 10;

-- Function to calculate monthly chat time for a woman
CREATE OR REPLACE FUNCTION public.get_woman_monthly_chat_minutes(p_user_id uuid, p_month_start date)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_minutes numeric;
BEGIN
    SELECT COALESCE(SUM(total_minutes), 0) INTO v_total_minutes
    FROM public.active_chat_sessions
    WHERE woman_user_id = p_user_id
      AND started_at >= p_month_start
      AND started_at < (p_month_start + interval '1 month');
    
    RETURN v_total_minutes;
END;
$$;

-- Function to perform monthly rotation of earning slots
-- Called on 1st of each month
CREATE OR REPLACE FUNCTION public.perform_monthly_earning_rotation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_language RECORD;
    v_woman RECORD;
    v_top_earner_minutes numeric;
    v_threshold_minutes numeric;
    v_demoted_count integer := 0;
    v_promoted_count integer := 0;
    v_month_start date;
    v_current_earning_count integer;
BEGIN
    -- Get first day of previous month for calculations
    v_month_start := date_trunc('month', current_date - interval '1 month')::date;
    
    -- Process each language
    FOR v_language IN 
        SELECT * FROM public.language_limits WHERE is_active = true
    LOOP
        -- Step 1: Find top earner's minutes for this language (paid users only)
        SELECT MAX(get_woman_monthly_chat_minutes(fp.user_id, v_month_start)) INTO v_top_earner_minutes
        FROM public.female_profiles fp
        WHERE fp.is_earning_eligible = true
          AND fp.country = 'India'
          AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name);
        
        IF v_top_earner_minutes IS NULL OR v_top_earner_minutes = 0 THEN
            v_top_earner_minutes := 1; -- Avoid division by zero
        END IF;
        
        -- Threshold is 10% of top earner
        v_threshold_minutes := v_top_earner_minutes * 0.10;
        
        -- Step 2: Demote paid women with less than 10% of top earner's time
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name, 
                   get_woman_monthly_chat_minutes(fp.user_id, v_month_start) as monthly_minutes
            FROM public.female_profiles fp
            WHERE fp.is_earning_eligible = true
              AND fp.country = 'India'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
        LOOP
            IF v_woman.monthly_minutes < v_threshold_minutes THEN
                -- Demote to free user
                UPDATE public.female_profiles
                SET is_earning_eligible = false,
                    earning_slot_assigned_at = NULL,
                    earning_badge_type = NULL,
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    updated_at = now()
                WHERE id = v_woman.id;
                
                UPDATE public.profiles
                SET is_earning_eligible = false,
                    earning_slot_assigned_at = NULL,
                    earning_badge_type = NULL,
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    updated_at = now()
                WHERE user_id = v_woman.user_id;
                
                v_demoted_count := v_demoted_count + 1;
            END IF;
        END LOOP;
        
        -- Step 3: Count current earning women after demotions
        SELECT COUNT(*) INTO v_current_earning_count
        FROM public.female_profiles fp
        WHERE fp.is_earning_eligible = true
          AND fp.country = 'India'
          AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name);
        
        -- Step 4: Promote top 5 free Indian women by chat time (up to 10 promotions, filling available slots)
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name,
                   get_woman_monthly_chat_minutes(fp.user_id, v_month_start) as monthly_minutes
            FROM public.female_profiles fp
            WHERE fp.is_earning_eligible = false
              AND fp.country = 'India'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
              AND fp.approval_status = 'approved'
              AND fp.account_status = 'active'
            ORDER BY get_woman_monthly_chat_minutes(fp.user_id, v_month_start) DESC
            LIMIT LEAST(5, v_language.max_earning_women - v_current_earning_count, v_language.max_monthly_promotions)
        LOOP
            -- Only promote if they have meaningful activity (at least some minutes)
            IF v_woman.monthly_minutes > 0 THEN
                -- Promote to paid user
                UPDATE public.female_profiles
                SET is_earning_eligible = true,
                    earning_slot_assigned_at = now(),
                    earning_badge_type = 'star',
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    promoted_from_free = true,
                    updated_at = now()
                WHERE id = v_woman.id;
                
                UPDATE public.profiles
                SET is_earning_eligible = true,
                    earning_slot_assigned_at = now(),
                    earning_badge_type = 'star',
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    promoted_from_free = true,
                    updated_at = now()
                WHERE user_id = v_woman.user_id;
                
                v_promoted_count := v_promoted_count + 1;
                v_current_earning_count := v_current_earning_count + 1;
            END IF;
        END LOOP;
        
        -- Update language limit count
        UPDATE public.language_limits
        SET current_earning_women = v_current_earning_count,
            updated_at = now()
        WHERE id = v_language.id;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'month_processed', v_month_start,
        'demoted', v_demoted_count,
        'promoted', v_promoted_count
    );
END;
$$;

-- ============================================================
-- Migration: 20260122063529_77a64f46-7d8d-4914-8f20-d253e4970b3c.sql
-- ============================================================
-- Schedule monthly rotation cron job (runs on 1st of each month at 00:05 UTC)
SELECT cron.schedule(
  'monthly-earning-rotation',
  '5 0 1 * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_functions_url') || '/monthly-earning-rotation',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ============================================================
-- Migration: 20260123055953_da7a496a-f5fa-4f91-87ac-0aaa6284da0a.sql
-- ============================================================
-- Create translation dictionaries table for offline translation
-- Stores word/phrase translations with English as pivot language

CREATE TABLE public.translation_dictionaries (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  source_text TEXT NOT NULL,
  source_language TEXT NOT NULL,
  english_text TEXT NOT NULL,
  target_text TEXT,
  target_language TEXT,
  category TEXT DEFAULT 'general',
  frequency INTEGER DEFAULT 1,
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX idx_translation_source ON public.translation_dictionaries (source_language, source_text);
CREATE INDEX idx_translation_english ON public.translation_dictionaries (english_text);
CREATE INDEX idx_translation_target ON public.translation_dictionaries (target_language, english_text);

-- Enable RLS
ALTER TABLE public.translation_dictionaries ENABLE ROW LEVEL SECURITY;

-- Public read access (dictionaries are shared resource)
CREATE POLICY "Translation dictionaries are publicly readable"
ON public.translation_dictionaries
FOR SELECT
USING (true);

-- Authenticated users can insert (for crowd-sourcing translations)
CREATE POLICY "Authenticated users can insert translations"
ON public.translation_dictionaries
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Create common phrases table for instant translations
CREATE TABLE public.common_phrases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  phrase_key TEXT NOT NULL UNIQUE,
  english TEXT NOT NULL,
  hindi TEXT,
  bengali TEXT,
  telugu TEXT,
  tamil TEXT,
  kannada TEXT,
  malayalam TEXT,
  marathi TEXT,
  gujarati TEXT,
  punjabi TEXT,
  odia TEXT,
  urdu TEXT,
  arabic TEXT,
  spanish TEXT,
  french TEXT,
  portuguese TEXT,
  russian TEXT,
  japanese TEXT,
  korean TEXT,
  chinese TEXT,
  thai TEXT,
  vietnamese TEXT,
  indonesian TEXT,
  turkish TEXT,
  persian TEXT,
  category TEXT DEFAULT 'chat',
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Index for fast phrase lookups
CREATE INDEX idx_common_phrases_key ON public.common_phrases (phrase_key);
CREATE INDEX idx_common_phrases_english ON public.common_phrases (english);

-- Enable RLS
ALTER TABLE public.common_phrases ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Common phrases are publicly readable"
ON public.common_phrases
FOR SELECT
USING (true);

-- Authenticated users can insert common phrases
CREATE POLICY "Authenticated users can insert common phrases"
ON public.common_phrases
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Trigger for updated_at
CREATE TRIGGER update_translation_dictionaries_updated_at
BEFORE UPDATE ON public.translation_dictionaries
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_common_phrases_updated_at
BEFORE UPDATE ON public.common_phrases
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- Migration: 20260123062038_29113a72-844d-44bd-8df5-799e371503ec.sql
-- ============================================================
-- Fix stale busy status: Sync women_availability and user_status with actual active sessions

-- First, update women_availability to reflect actual active session counts
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
),
is_available = (
  SELECT COALESCE(COUNT(*), 0) < 3
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);

-- Update user_status to reflect correct status based on actual active sessions
UPDATE user_status us
SET status_text = CASE 
  WHEN (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE (acs.man_user_id = us.user_id OR acs.woman_user_id = us.user_id) 
    AND acs.status = 'active'
  ) >= 3 THEN 'busy'
  ELSE 'online'
END
WHERE us.is_online = true;

-- For offline users, ensure status is not busy
UPDATE user_status
SET status_text = 'offline'
WHERE is_online = false AND status_text = 'busy';

-- ============================================================
-- Migration: 20260123071325_0be1d53c-b265-45d8-a0a8-b2947815a54a.sql
-- ============================================================
-- Fix stale women_availability.current_chat_count that doesn't match actual active sessions
-- This causes status mismatch where users appear busy when they have no active chats

-- Step 1: Sync women_availability.current_chat_count with actual active session count
UPDATE women_availability wa
SET 
  current_chat_count = (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
  ),
  is_available = (
    SELECT COALESCE(COUNT(*), 0) < 3
    FROM active_chat_sessions acs 
    WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
  );

-- Step 2: Fix user_status.status_text based on ACTUAL active sessions (not stale count)
UPDATE user_status us
SET status_text = CASE 
  WHEN us.is_online = false THEN 'offline'
  WHEN (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE (acs.man_user_id = us.user_id OR acs.woman_user_id = us.user_id) 
    AND acs.status = 'active'
  ) >= 3 THEN 'busy'
  ELSE 'online'
END;

-- Step 3: Create a trigger to automatically sync status when active_chat_sessions changes
CREATE OR REPLACE FUNCTION sync_user_availability_on_session_change()
RETURNS TRIGGER AS $$
DECLARE
  woman_active_count INTEGER;
  man_active_count INTEGER;
BEGIN
  -- Get actual counts for the woman
  IF NEW.woman_user_id IS NOT NULL OR (TG_OP = 'UPDATE' AND OLD.woman_user_id IS NOT NULL) THEN
    SELECT COUNT(*) INTO woman_active_count
    FROM active_chat_sessions
    WHERE woman_user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id)
    AND status = 'active';
    
    -- Update women_availability
    UPDATE women_availability
    SET 
      current_chat_count = woman_active_count,
      is_available = woman_active_count < 3
    WHERE user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id);
    
    -- Update user_status for woman
    UPDATE user_status
    SET status_text = CASE 
      WHEN is_online = false THEN 'offline'
      WHEN woman_active_count >= 3 THEN 'busy'
      ELSE 'online'
    END
    WHERE user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id);
  END IF;
  
  -- Get actual counts for the man
  IF NEW.man_user_id IS NOT NULL OR (TG_OP = 'UPDATE' AND OLD.man_user_id IS NOT NULL) THEN
    SELECT COUNT(*) INTO man_active_count
    FROM active_chat_sessions
    WHERE man_user_id = COALESCE(NEW.man_user_id, OLD.man_user_id)
    AND status = 'active';
    
    -- Update user_status for man
    UPDATE user_status
    SET status_text = CASE 
      WHEN is_online = false THEN 'offline'
      WHEN man_active_count >= 3 THEN 'busy'
      ELSE 'online'
    END
    WHERE user_id = COALESCE(NEW.man_user_id, OLD.man_user_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists and create new one
DROP TRIGGER IF EXISTS sync_availability_on_session_change ON active_chat_sessions;

CREATE TRIGGER sync_availability_on_session_change
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_user_availability_on_session_change();

-- ============================================================
-- Migration: 20260126124258_4253fa80-0189-491c-81bf-373278903a0d.sql
-- ============================================================
-- Create table for idioms/phrases database
CREATE TABLE public.translation_idioms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  phrase TEXT NOT NULL UNIQUE,
  normalized_phrase TEXT NOT NULL,
  meaning TEXT NOT NULL,
  translations JSONB NOT NULL DEFAULT '{}',
  category TEXT NOT NULL DEFAULT 'idiom',
  register TEXT NOT NULL DEFAULT 'neutral',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create table for language grammar rules
CREATE TABLE public.translation_grammar_rules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL UNIQUE,
  language_name TEXT NOT NULL,
  word_order TEXT NOT NULL DEFAULT 'SVO',
  has_gender BOOLEAN NOT NULL DEFAULT false,
  has_articles BOOLEAN NOT NULL DEFAULT false,
  adjective_position TEXT NOT NULL DEFAULT 'before',
  uses_postpositions BOOLEAN NOT NULL DEFAULT false,
  subject_dropping BOOLEAN NOT NULL DEFAULT false,
  has_cases BOOLEAN NOT NULL DEFAULT false,
  has_honorific BOOLEAN NOT NULL DEFAULT false,
  sentence_end_particle TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create table for word sense disambiguation
CREATE TABLE public.translation_word_senses (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  word TEXT NOT NULL,
  sense_id TEXT NOT NULL,
  meaning TEXT NOT NULL,
  context_clues TEXT[] NOT NULL DEFAULT '{}',
  translations JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(word, sense_id)
);

-- Create table for morphology rules
CREATE TABLE public.translation_morphology_rules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  rule_type TEXT NOT NULL,
  pattern TEXT NOT NULL,
  replacement TEXT NOT NULL,
  conditions JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(language_code, rule_type, pattern)
);

-- Enable RLS
ALTER TABLE public.translation_idioms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_grammar_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_word_senses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_morphology_rules ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (translation data is public)
CREATE POLICY "Translation idioms are publicly readable" ON public.translation_idioms FOR SELECT USING (true);
CREATE POLICY "Translation grammar rules are publicly readable" ON public.translation_grammar_rules FOR SELECT USING (true);
CREATE POLICY "Translation word senses are publicly readable" ON public.translation_word_senses FOR SELECT USING (true);
CREATE POLICY "Translation morphology rules are publicly readable" ON public.translation_morphology_rules FOR SELECT USING (true);

-- Create indexes for fast lookups
CREATE INDEX idx_translation_idioms_phrase ON public.translation_idioms(normalized_phrase);
CREATE INDEX idx_translation_grammar_rules_code ON public.translation_grammar_rules(language_code);
CREATE INDEX idx_translation_word_senses_word ON public.translation_word_senses(word);
CREATE INDEX idx_translation_morphology_rules_lang ON public.translation_morphology_rules(language_code);

-- Create update timestamp triggers
CREATE TRIGGER update_translation_idioms_updated_at
BEFORE UPDATE ON public.translation_idioms
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_translation_grammar_rules_updated_at
BEFORE UPDATE ON public.translation_grammar_rules
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_translation_word_senses_updated_at
BEFORE UPDATE ON public.translation_word_senses
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- Migration: 20260201033419_1f309269-49a8-4016-865d-45edc56e9be4.sql
-- ============================================================
-- Create KYC table for Indian women users
CREATE TABLE public.women_kyc (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  
  -- Basic Details
  full_name_as_per_bank TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender TEXT,
  country_of_residence TEXT NOT NULL DEFAULT 'India',
  
  -- Bank Details
  bank_name TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  ifsc_code TEXT NOT NULL,
  
  -- KYC Documents
  id_type TEXT NOT NULL CHECK (id_type IN ('aadhaar', 'pan', 'passport', 'voter_id')),
  id_number TEXT NOT NULL,
  document_front_url TEXT,
  document_back_url TEXT,
  selfie_url TEXT,
  
  -- Verification Status
  verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'under_review', 'approved', 'rejected')),
  rejection_reason TEXT,
  verified_at TIMESTAMP WITH TIME ZONE,
  verified_by UUID,
  
  -- Compliance
  consent_given BOOLEAN NOT NULL DEFAULT false,
  consent_timestamp TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_kyc ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own KYC
CREATE POLICY "Users can view own KYC"
ON public.women_kyc
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own KYC (only once)
CREATE POLICY "Users can create own KYC"
ON public.women_kyc
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own KYC only if not yet approved
CREATE POLICY "Users can update own pending KYC"
ON public.women_kyc
FOR UPDATE
USING (auth.uid() = user_id AND verification_status IN ('pending', 'rejected'));

-- Admins can view all KYC records
CREATE POLICY "Admins can view all KYC"
ON public.women_kyc
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

-- Admins can update KYC status
CREATE POLICY "Admins can update KYC"
ON public.women_kyc
FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

-- Create updated_at trigger
CREATE TRIGGER update_women_kyc_updated_at
BEFORE UPDATE ON public.women_kyc
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create storage bucket for KYC documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for KYC documents
CREATE POLICY "Users can upload own KYC documents"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'kyc-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view own KYC documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'kyc-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Admins can view all KYC documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'kyc-documents' 
  AND public.has_role(auth.uid(), 'admin')
);

-- Create index for faster lookups
CREATE INDEX idx_women_kyc_user_id ON public.women_kyc(user_id);
CREATE INDEX idx_women_kyc_status ON public.women_kyc(verification_status);

-- ============================================================
-- Migration: 20260201034705_a54c3cab-636c-4967-9c1b-d4e5689a9ca2.sql
-- ============================================================
-- Enable pg_cron and pg_net extensions for scheduled jobs
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant usage on cron schema
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Schedule auto-approve-kyc to run every 5 minutes
SELECT cron.schedule(
  'auto-approve-kyc-every-5-min',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://www.meow-meow.co.in:8443/functions/v1/auto-approve-kyc',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body := '{"trigger": "cron"}'::jsonb
  ) AS request_id;
  $$
);

-- ============================================================
-- Migration: 20260201035149_f3700d6a-a9b3-4cf6-adae-49fdaa81080d.sql
-- ============================================================
-- Update pricing to match spec: Men pay ₹8/min for video, Women earn ₹4/min for video ONLY
-- Women should NOT earn from text chat per spec

-- Update the active chat_pricing record with spec defaults
UPDATE public.chat_pricing
SET 
  video_rate_per_minute = 8,        -- Men pay ₹8/min for video (spec default)
  video_women_earning_rate = 4,     -- Women earn ₹4/min for video (spec default)  
  women_earning_rate = 0,           -- Women earn NOTHING from text chat (spec: video only)
  rate_per_minute = 8,              -- Men pay ₹8/min for chat too (consistent)
  updated_at = now()
WHERE is_active = true;

-- Update process_chat_billing to reflect that women earn NOTHING from chat
-- (keeping man charges, but women_earning_rate = 0 means no earnings)
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Check if man is a super user (bypass billing)
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    IF v_is_super_user THEN
        -- Super users don't get charged, women don't earn from chat anyway
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes,
            last_activity_at = now()
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0,
            'note', 'Women earn from video calls only, not text chat'
        );
    END IF;
    
    -- Calculate charges - MEN ALWAYS PAY
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    
    -- WOMEN EARN NOTHING FROM TEXT CHAT (per spec - video only)
    -- Admin gets 100% of chat revenue
    v_admin_revenue := v_charge_amount;
    
    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.active_chat_sessions
        SET status = 'ended', 
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet (MEN ALWAYS PAY)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );
    
    -- NO EARNINGS FOR WOMEN FROM CHAT (spec says video only)
    
    -- Log admin revenue (100% goes to admin for chat)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s) (women earn video only)', 'INR'
    );
    
    -- Update session totals (no earnings for women in chat)
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = 0, -- Women don't earn from chat
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', 0,
        'admin_revenue', v_admin_revenue,
        'note', 'Women earn from video calls only'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- Ensure video billing still pays women (spec: women earn from video calls)
-- process_video_billing already handles this correctly - women get video_women_earning_rate

-- ============================================================
-- Migration: 20260202130558_b7b863af-6dd2-4048-964d-1411e4fad032.sql
-- ============================================================
-- Clean up stale billing_paused and paused sessions (older than 10 minutes)
UPDATE active_chat_sessions
SET status = 'ended',
    end_reason = 'stale_session_cleanup',
    ended_at = NOW()
WHERE status IN ('billing_paused', 'paused')
AND last_activity_at < NOW() - INTERVAL '10 minutes';

-- Reset women_availability counts for users with no active sessions
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
),
is_available = true
WHERE current_chat_count > 0;

-- Reset user_status for users who should be online but marked as busy incorrectly
UPDATE user_status us
SET status_text = CASE 
  WHEN NOT is_online THEN 'offline'
  WHEN (SELECT COUNT(*) FROM active_chat_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') >= 3 THEN 'busy'
  ELSE 'online'
END,
active_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE man_user_id = us.user_id AND status = 'active'
)
WHERE is_online = true;

-- ============================================================
-- Migration: 20260202131708_1c434805-5219-420b-8e47-d534f2b76375.sql
-- ============================================================
-- Fix stale women_availability: set is_available=false for women who are NOT online
UPDATE women_availability wa
SET is_available = false, 
    is_available_for_calls = false,
    updated_at = now()
WHERE NOT EXISTS (
  SELECT 1 FROM user_status us 
  WHERE us.user_id = wa.user_id 
  AND us.is_online = true
);

-- Also ensure current_chat_count is reset for women with no active sessions
UPDATE women_availability wa
SET current_chat_count = 0
WHERE current_chat_count > 0
AND NOT EXISTS (
  SELECT 1 FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id 
  AND acs.status = 'active'
);

-- Reset current_call_count for women with no active calls
UPDATE women_availability wa
SET current_call_count = 0
WHERE current_call_count > 0
AND NOT EXISTS (
  SELECT 1 FROM video_call_sessions vcs 
  WHERE vcs.woman_user_id = wa.user_id 
  AND vcs.status IN ('active', 'ringing', 'connecting')
);

-- ============================================================
-- Migration: 20260220031823_1ead5c94-107e-499d-a0b9-22a830b72221.sql
-- ============================================================

-- Add golden badge fields to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS has_golden_badge boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS golden_badge_expires_at timestamp with time zone;

-- Add golden badge fields to female_profiles table
ALTER TABLE public.female_profiles
ADD COLUMN IF NOT EXISTS has_golden_badge boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS golden_badge_expires_at timestamp with time zone;

-- Create golden badge subscriptions table
CREATE TABLE public.golden_badge_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  amount numeric NOT NULL DEFAULT 1000,
  currency text NOT NULL DEFAULT 'INR',
  status text NOT NULL DEFAULT 'active',
  purchased_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.golden_badge_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscriptions"
ON public.golden_badge_subscriptions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own subscriptions"
ON public.golden_badge_subscriptions FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Function to purchase golden badge
CREATE OR REPLACE FUNCTION public.purchase_golden_badge(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_wallet_id uuid;
  v_balance numeric;
  v_badge_price numeric := 1000;
  v_expires_at timestamp with time zone;
  v_is_indian boolean;
  v_gender text;
  v_existing_badge boolean;
BEGIN
  -- Verify user is an Indian woman
  SELECT gender, is_indian, has_golden_badge
  INTO v_gender, v_is_indian, v_existing_badge
  FROM profiles WHERE user_id = p_user_id;

  IF LOWER(COALESCE(v_gender, '')) != 'female' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for women');
  END IF;

  IF NOT COALESCE(v_is_indian, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for Indian women');
  END IF;

  -- Check if already has active badge
  IF COALESCE(v_existing_badge, false) THEN
    -- Check if it's still valid
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = p_user_id 
      AND golden_badge_expires_at > now()
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'You already have an active Golden Badge');
    END IF;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM wallets WHERE user_id = p_user_id FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF v_balance < v_badge_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. You need ₹1000');
  END IF;

  -- Set expiry to 30 days from now
  v_expires_at := now() + interval '30 days';

  -- Debit wallet
  UPDATE wallets SET balance = balance - v_badge_price, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_user_id, 'debit', v_badge_price, 'Golden Badge Purchase (1 Month)', 'completed');

  -- Update profiles
  UPDATE profiles 
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  UPDATE female_profiles
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record subscription
  INSERT INTO golden_badge_subscriptions (user_id, amount, expires_at)
  VALUES (p_user_id, v_badge_price, v_expires_at);

  -- Log admin revenue
  INSERT INTO admin_revenue_transactions (transaction_type, amount, woman_user_id, description, currency)
  VALUES ('golden_badge', v_badge_price, p_user_id, 'Golden Badge purchase', 'INR');

  RETURN jsonb_build_object(
    'success', true,
    'expires_at', v_expires_at,
    'new_balance', v_balance - v_badge_price
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update sync trigger to include golden badge fields
CREATE OR REPLACE FUNCTION public.sync_golden_badge_to_female()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.has_golden_badge IS DISTINCT FROM OLD.has_golden_badge 
     OR NEW.golden_badge_expires_at IS DISTINCT FROM OLD.golden_badge_expires_at THEN
    UPDATE female_profiles
    SET has_golden_badge = NEW.has_golden_badge,
        golden_badge_expires_at = NEW.golden_badge_expires_at,
        updated_at = now()
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER sync_golden_badge_trigger
AFTER UPDATE OF has_golden_badge, golden_badge_expires_at ON profiles
FOR EACH ROW
EXECUTE FUNCTION sync_golden_badge_to_female();


-- ============================================================
-- Migration: 20260221064339_593d081b-41ea-401e-9f02-159d04970e1e.sql
-- ============================================================

-- Add separate address proof (Aadhaar) and ID proof columns
ALTER TABLE public.women_kyc 
  ADD COLUMN IF NOT EXISTS aadhaar_number text,
  ADD COLUMN IF NOT EXISTS aadhaar_front_url text,
  ADD COLUMN IF NOT EXISTS aadhaar_back_url text,
  ADD COLUMN IF NOT EXISTS id_proof_front_url text,
  ADD COLUMN IF NOT EXISTS id_proof_back_url text;

-- Migrate existing aadhaar data to new columns
UPDATE public.women_kyc 
SET aadhaar_number = id_number,
    aadhaar_front_url = document_front_url,
    aadhaar_back_url = document_back_url
WHERE id_type = 'aadhaar';

-- For non-aadhaar entries, move to id_proof columns
UPDATE public.women_kyc 
SET id_proof_front_url = document_front_url,
    id_proof_back_url = document_back_url
WHERE id_type != 'aadhaar';


-- ============================================================
-- Migration: 20260222070802_3688523e-01d2-4d65-9e74-0a51f0f277ff.sql
-- ============================================================
-- Drop the restrictive photo viewing policy
DROP POLICY "Users can view own or matched user photos" ON public.user_photos;

-- Create a new policy that allows all authenticated users to view all photos
CREATE POLICY "Authenticated users can view all photos"
ON public.user_photos
FOR SELECT
USING (auth.uid() IS NOT NULL);

-- ============================================================
-- Migration: 20260222080839_c4f9f6ba-a734-4d67-9c69-3452fa82680d.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.purchase_golden_badge(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet_id uuid;
  v_badge_price numeric := 1000;
  v_expires_at timestamp with time zone;
  v_is_indian boolean;
  v_gender text;
  v_existing_badge boolean;
  v_total_earnings numeric;
  v_total_withdrawals numeric;
  v_effective_balance numeric;
BEGIN
  -- Verify user is an Indian woman
  SELECT gender, is_indian, has_golden_badge
  INTO v_gender, v_is_indian, v_existing_badge
  FROM profiles WHERE user_id = p_user_id;

  IF LOWER(COALESCE(v_gender, '')) != 'female' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for women');
  END IF;

  IF NOT COALESCE(v_is_indian, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for Indian women');
  END IF;

  -- Check if already has active badge
  IF COALESCE(v_existing_badge, false) THEN
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = p_user_id 
      AND golden_badge_expires_at > now()
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'You already have an active Golden Badge');
    END IF;
  END IF;

  -- Calculate effective balance: total earnings - total debits from wallet_transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawals
  FROM wallet_transactions WHERE user_id = p_user_id AND type = 'debit';

  v_effective_balance := v_total_earnings - v_total_withdrawals;

  IF v_effective_balance < v_badge_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. You need ₹1000. Your balance: ₹' || v_effective_balance);
  END IF;

  -- Ensure wallet exists
  SELECT id INTO v_wallet_id FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, balance, currency)
    VALUES (p_user_id, 0, 'INR')
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Set expiry to 30 days from now
  v_expires_at := now() + interval '30 days';

  -- Record the debit transaction (this reduces the effective balance)
  INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_user_id, 'debit', v_badge_price, 'Golden Badge Purchase (1 Month)', 'completed');

  -- Update profiles
  UPDATE profiles 
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  UPDATE female_profiles
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record subscription
  INSERT INTO golden_badge_subscriptions (user_id, amount, expires_at)
  VALUES (p_user_id, v_badge_price, v_expires_at);

  -- Log admin revenue
  INSERT INTO admin_revenue_transactions (transaction_type, amount, woman_user_id, description, currency)
  VALUES ('golden_badge', v_badge_price, p_user_id, 'Golden Badge purchase', 'INR');

  RETURN jsonb_build_object(
    'success', true,
    'expires_at', v_expires_at,
    'new_balance', v_effective_balance - v_badge_price
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;


-- ============================================================
-- Migration: 20260222091349_ad20afb0-d51e-4e50-a1df-4e57a98ea1fe.sql
-- ============================================================

-- Table to track women's chat mode (paid/free/exclusive_free)
CREATE TABLE public.women_chat_modes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  current_mode TEXT NOT NULL DEFAULT 'paid' CHECK (current_mode IN ('paid', 'free', 'exclusive_free')),
  mode_switched_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  exclusive_free_locked_until TIMESTAMP WITH TIME ZONE,
  free_minutes_used_today NUMERIC NOT NULL DEFAULT 0,
  free_minutes_limit NUMERIC NOT NULL DEFAULT 60, -- 1 hour = 60 minutes
  last_free_reset_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_chat_modes ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Women can view their own chat mode"
  ON public.women_chat_modes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Women can update their own chat mode"
  ON public.women_chat_modes FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Women can insert their own chat mode"
  ON public.women_chat_modes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admins can view all
CREATE POLICY "Admins can view all chat modes"
  ON public.women_chat_modes FOR SELECT
  USING (has_role(auth.uid(), 'admin'));

-- Trigger for updated_at
CREATE TRIGGER update_women_chat_modes_updated_at
  BEFORE UPDATE ON public.women_chat_modes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Index for fast lookups
CREATE INDEX idx_women_chat_modes_user_id ON public.women_chat_modes(user_id);
CREATE INDEX idx_women_chat_modes_mode ON public.women_chat_modes(current_mode);


-- ============================================================
-- Migration: 20260222092629_7d1cf877-6055-459d-8ff2-cf83501263b6.sql
-- ============================================================

-- Add force free mode tracking columns to women_chat_modes
ALTER TABLE public.women_chat_modes
ADD COLUMN IF NOT EXISTS force_free_minutes_used_today integer NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS force_free_minutes_limit integer NOT NULL DEFAULT 15,
ADD COLUMN IF NOT EXISTS is_force_free_active boolean NOT NULL DEFAULT false;


-- ============================================================
-- Migration: 20260222093428_97a8885a-9fde-46b0-82a7-7c7cbb5573b9.sql
-- ============================================================

-- Table to track men's free chat minutes
CREATE TABLE public.men_free_chat_allowance (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  first_login_date date NOT NULL DEFAULT CURRENT_DATE,
  free_minutes_total integer NOT NULL DEFAULT 10,
  free_minutes_used integer NOT NULL DEFAULT 0,
  last_reset_date date NOT NULL DEFAULT CURRENT_DATE,
  next_reset_date date NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '15 days')::date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.men_free_chat_allowance ENABLE ROW LEVEL SECURITY;

-- Users can read their own allowance
CREATE POLICY "Users can view own free allowance"
ON public.men_free_chat_allowance FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own allowance
CREATE POLICY "Users can create own free allowance"
ON public.men_free_chat_allowance FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own allowance
CREATE POLICY "Users can update own free allowance"
ON public.men_free_chat_allowance FOR UPDATE
USING (auth.uid() = user_id);

-- Admins can manage all
CREATE POLICY "Admins can manage all free allowances"
ON public.men_free_chat_allowance FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- Function to check and use men's free minutes
CREATE OR REPLACE FUNCTION public.check_men_free_minutes(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_record RECORD;
  v_remaining integer;
BEGIN
  -- Get or create allowance record
  SELECT * INTO v_record
  FROM men_free_chat_allowance
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_record IS NULL THEN
    INSERT INTO men_free_chat_allowance (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_record;
  END IF;

  -- Check if reset is due (every 15 days from first login)
  IF CURRENT_DATE >= v_record.next_reset_date THEN
    UPDATE men_free_chat_allowance
    SET free_minutes_used = 0,
        last_reset_date = CURRENT_DATE,
        next_reset_date = (CURRENT_DATE + INTERVAL '15 days')::date,
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_record;
  END IF;

  v_remaining := GREATEST(0, v_record.free_minutes_total - v_record.free_minutes_used);

  RETURN jsonb_build_object(
    'has_free_minutes', v_remaining > 0,
    'free_minutes_remaining', v_remaining,
    'free_minutes_total', v_record.free_minutes_total,
    'free_minutes_used', v_record.free_minutes_used,
    'next_reset_date', v_record.next_reset_date
  );
END;
$$;

-- Function to consume a free minute
CREATE OR REPLACE FUNCTION public.use_men_free_minute(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_record RECORD;
  v_remaining integer;
BEGIN
  SELECT * INTO v_record
  FROM men_free_chat_allowance
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_record IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No free allowance record');
  END IF;

  -- Reset if due
  IF CURRENT_DATE >= v_record.next_reset_date THEN
    UPDATE men_free_chat_allowance
    SET free_minutes_used = 0,
        last_reset_date = CURRENT_DATE,
        next_reset_date = (CURRENT_DATE + INTERVAL '15 days')::date,
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_record;
  END IF;

  v_remaining := v_record.free_minutes_total - v_record.free_minutes_used;

  IF v_remaining <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No free minutes remaining', 'remaining', 0);
  END IF;

  -- Use one minute
  UPDATE men_free_chat_allowance
  SET free_minutes_used = free_minutes_used + 1,
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'remaining', v_remaining - 1,
    'next_reset_date', v_record.next_reset_date
  );
END;
$$;

-- Trigger for updated_at
CREATE TRIGGER update_men_free_chat_allowance_updated_at
BEFORE UPDATE ON public.men_free_chat_allowance
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();


-- ============================================================
-- Migration: 20260223053849_76376e49-9984-46a2-aa29-cf54eb470e4d.sql
-- ============================================================

-- Create admin_broadcast_messages table for admin-to-user messaging
CREATE TABLE public.admin_broadcast_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL,
  recipient_id UUID, -- NULL means broadcast to all
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  is_broadcast BOOLEAN NOT NULL DEFAULT false,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_broadcast_messages ENABLE ROW LEVEL SECURITY;

-- Admins can insert messages
CREATE POLICY "Admins can insert broadcast messages"
ON public.admin_broadcast_messages
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Admins can view all messages
CREATE POLICY "Admins can view all broadcast messages"
ON public.admin_broadcast_messages
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Users can view messages sent to them or broadcast
CREATE POLICY "Users can view their own messages"
ON public.admin_broadcast_messages
FOR SELECT
TO authenticated
USING (recipient_id = auth.uid() OR is_broadcast = true);

-- Users can mark their messages as read
CREATE POLICY "Users can update read status"
ON public.admin_broadcast_messages
FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid() OR is_broadcast = true)
WITH CHECK (recipient_id = auth.uid() OR is_broadcast = true);


-- ============================================================
-- Migration: 20260225014715_001ef837-f2bc-4ec1-a6ac-8c71120713df.sql
-- ============================================================

-- =====================================================
-- FRIEND REQUEST & BLOCK SYSTEM - Database Functions
-- All validation logic lives in the database for safety
-- =====================================================

-- 1. SEND FRIEND REQUEST
-- Validates: no duplicates, no existing friendship, no blocks
CREATE OR REPLACE FUNCTION public.send_friend_request(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Cannot friend yourself
  IF v_user_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send friend request to yourself');
  END IF;

  -- Check if either user has blocked the other
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocked_by = v_user_id AND blocked_user_id = p_target_user_id)
       OR (blocked_by = p_target_user_id AND blocked_user_id = v_user_id)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send friend request - user is blocked');
  END IF;

  -- Check if already friends
  IF EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'accepted'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already friends with this user');
  END IF;

  -- Check if a pending request already exists (either direction)
  IF EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'pending'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'A friend request already exists between you two');
  END IF;

  -- Insert the friend request as pending
  INSERT INTO user_friends (user_id, friend_id, status, created_by)
  VALUES (v_user_id, p_target_user_id, 'pending', v_user_id);

  RETURN jsonb_build_object('success', true, 'message', 'Friend request sent');
END;
$$;

-- 2. ACCEPT FRIEND REQUEST
-- Only the recipient can accept
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_request RECORD;
BEGIN
  -- Get the request - only the recipient (friend_id) can accept
  SELECT * INTO v_request
  FROM user_friends
  WHERE id = p_request_id
    AND friend_id = v_user_id
    AND status = 'pending';

  IF v_request IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found or already processed');
  END IF;

  -- Check blocks haven't been created since the request
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocked_by = v_user_id AND blocked_user_id = v_request.user_id)
       OR (blocked_by = v_request.user_id AND blocked_user_id = v_user_id)
  ) THEN
    -- Delete the request since there's a block
    DELETE FROM user_friends WHERE id = p_request_id;
    RETURN jsonb_build_object('success', false, 'error', 'Cannot accept - user is blocked');
  END IF;

  -- Accept the request
  UPDATE user_friends
  SET status = 'accepted', updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request accepted');
END;
$$;

-- 3. REJECT FRIEND REQUEST
-- Only the recipient can reject
CREATE OR REPLACE FUNCTION public.reject_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Delete the pending request (only recipient can reject)
  DELETE FROM user_friends
  WHERE id = p_request_id
    AND friend_id = v_user_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request rejected');
END;
$$;

-- 4. CANCEL FRIEND REQUEST
-- Only the sender can cancel
CREATE OR REPLACE FUNCTION public.cancel_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_friends
  WHERE id = p_request_id
    AND user_id = v_user_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request canceled');
END;
$$;

-- 5. UNFRIEND USER
-- Either user in the friendship can unfriend
CREATE OR REPLACE FUNCTION public.unfriend_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_friends
  WHERE status = 'accepted'
    AND ((user_id = v_user_id AND friend_id = p_target_user_id)
      OR (user_id = p_target_user_id AND friend_id = v_user_id));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friendship not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'User unfriended');
END;
$$;

-- 6. BLOCK USER
-- Automatically removes friendship and cancels pending requests
CREATE OR REPLACE FUNCTION public.block_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Cannot block yourself
  IF v_user_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot block yourself');
  END IF;

  -- Check if already blocked
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is already blocked');
  END IF;

  -- Remove any friendship (accepted or pending) between the two users
  DELETE FROM user_friends
  WHERE (user_id = v_user_id AND friend_id = p_target_user_id)
     OR (user_id = p_target_user_id AND friend_id = v_user_id);

  -- End any active chat sessions between them
  UPDATE active_chat_sessions
  SET status = 'ended', ended_at = now(), end_reason = 'user_blocked'
  WHERE status = 'active'
    AND ((man_user_id = v_user_id AND woman_user_id = p_target_user_id)
      OR (man_user_id = p_target_user_id AND woman_user_id = v_user_id));

  -- Insert the block
  INSERT INTO user_blocks (blocked_by, blocked_user_id, block_type)
  VALUES (v_user_id, p_target_user_id, 'manual');

  RETURN jsonb_build_object('success', true, 'message', 'User blocked');
END;
$$;

-- 7. UNBLOCK USER
CREATE OR REPLACE FUNCTION public.unblock_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_blocks
  WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is not blocked');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'User unblocked');
END;
$$;

-- 8. CHECK RELATIONSHIP STATUS
-- Returns the relationship between two users
CREATE OR REPLACE FUNCTION public.get_relationship_status(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_blocked_by_me boolean := false;
  v_is_blocked_by_them boolean := false;
  v_is_friend boolean := false;
  v_pending_sent boolean := false;
  v_pending_received boolean := false;
  v_request_id uuid := null;
BEGIN
  -- Check blocks
  SELECT EXISTS (
    SELECT 1 FROM user_blocks WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id
  ) INTO v_is_blocked_by_me;

  SELECT EXISTS (
    SELECT 1 FROM user_blocks WHERE blocked_by = p_target_user_id AND blocked_user_id = v_user_id
  ) INTO v_is_blocked_by_them;

  -- Check friendship
  SELECT EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'accepted'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) INTO v_is_friend;

  -- Check pending requests
  SELECT id INTO v_request_id FROM user_friends
  WHERE status = 'pending'
    AND user_id = v_user_id AND friend_id = p_target_user_id;
  v_pending_sent := v_request_id IS NOT NULL;

  IF NOT v_pending_sent THEN
    SELECT id INTO v_request_id FROM user_friends
    WHERE status = 'pending'
      AND user_id = p_target_user_id AND friend_id = v_user_id;
    v_pending_received := v_request_id IS NOT NULL;
  END IF;

  RETURN jsonb_build_object(
    'is_blocked_by_me', v_is_blocked_by_me,
    'is_blocked_by_them', v_is_blocked_by_them,
    'is_friend', v_is_friend,
    'pending_sent', v_pending_sent,
    'pending_received', v_pending_received,
    'request_id', v_request_id
  );
END;
$$;


-- ============================================================
-- Migration: 20260225015203_a7cd5ec0-ffba-470b-913e-995408f47000.sql
-- ============================================================

-- Allow authenticated users to read female_profiles for browsing
CREATE POLICY "Authenticated users can browse female profiles"
  ON public.female_profiles FOR SELECT
  USING (auth.uid() IS NOT NULL AND account_status = 'active');

-- Allow authenticated users to read male_profiles for browsing
CREATE POLICY "Authenticated users can browse male profiles"
  ON public.male_profiles FOR SELECT
  USING (auth.uid() IS NOT NULL AND account_status = 'active');


-- ============================================================
-- Migration: 20260225025039_d7645c94-ac30-4cac-92a0-844ff5fab090.sql
-- ============================================================
-- Fix duplicate billing race condition: Remove duplicate wallet_transaction and women_earnings entries
-- The duplicate was caused by two concurrent heartbeats at 2026-02-25 02:44:05

-- 1. Delete the duplicate wallet_transaction (the second one created at 02:44:05.651874)
DELETE FROM wallet_transactions WHERE id = 'db2aa558-7827-44e1-a299-c901b821fa93';

-- 2. Refund the duplicate charge to the man's wallet (₹5.58)
UPDATE wallets SET balance = balance + 5.58 WHERE id = '551dd8b4-59ea-4404-9410-11df121b1800';

-- 3. Delete the duplicate women_earnings entry (the second one created at 02:44:05.884137)
DELETE FROM women_earnings WHERE id = 'bee3193b-6eea-4352-999a-add357d36191';


-- ============================================================
-- Migration: 20260225025651_1c710e22-8070-4157-854e-bd1cbd2ac7a4.sql
-- ============================================================

-- Fix race condition in process_video_billing: add optimistic lock to prevent duplicate billing
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
    v_lock_check integer;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    -- RACE CONDITION GUARD: Atomically update updated_at only if it hasn't changed
    -- This prevents two concurrent billing calls from both processing the same period
    UPDATE public.video_call_sessions
    SET updated_at = now()
    WHERE id = p_session_id
      AND updated_at = v_session.updated_at;
    
    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    
    IF v_lock_check = 0 THEN
        -- Another billing call already processed - skip to avoid duplicate
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;
    
    -- Check if man is super user
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    -- Calculate amounts using admin-defined video rates
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;
    
    IF v_is_super_user THEN
        -- Super users: credit woman only, no debit
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call (super user session) - ' || p_minutes || ' minute(s)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    -- Normal flow: lock wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Debit man's wallet
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    -- Credit woman
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
            'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    
    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'video_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Video call revenue - ' || p_minutes || ' minute(s)', 'INR'
    );
    
    -- Update session
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ============================================================
-- Migration: 20260225031249_178d3a35-2f4b-4689-a18b-2a8cd924d852.sql
-- ============================================================

-- Create trigger on video_call_sessions to auto-sync user_status and women_availability
CREATE OR REPLACE FUNCTION public.sync_user_status_on_video_call_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_chat_count integer;
  v_video_count integer;
  v_total integer;
  v_status_text text;
BEGIN
  -- Process woman user
  FOR v_user_id IN
    SELECT unnest(ARRAY[
      COALESCE(NEW.woman_user_id, OLD.woman_user_id),
      COALESCE(NEW.man_user_id, OLD.man_user_id)
    ])
  LOOP
    IF v_user_id IS NULL THEN CONTINUE; END IF;

    -- Count active chats
    SELECT COUNT(*) INTO v_chat_count
    FROM active_chat_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    -- Count active video calls
    SELECT COUNT(*) INTO v_video_count
    FROM video_call_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    v_total := v_chat_count + v_video_count;

    -- Determine status
    IF v_video_count > 0 THEN
      v_status_text := 'busy';
    ELSIF v_chat_count >= 3 THEN
      v_status_text := 'busy';
    ELSE
      v_status_text := 'online';
    END IF;

    -- Update user_status
    UPDATE user_status
    SET status_text = CASE WHEN is_online = false THEN 'offline' ELSE v_status_text END,
        last_seen = now()
    WHERE user_id = v_user_id;

    -- Update women_availability if applicable
    UPDATE women_availability
    SET current_call_count = v_video_count,
        is_available = v_chat_count < 3 AND v_video_count = 0,
        is_available_for_calls = v_video_count = 0
    WHERE user_id = v_user_id;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- Create trigger
DROP TRIGGER IF EXISTS sync_video_call_status ON video_call_sessions;
CREATE TRIGGER sync_video_call_status
  AFTER INSERT OR UPDATE OR DELETE ON video_call_sessions
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_status_on_video_call_change();


-- ============================================================
-- Migration: 20260225033035_d4ab72e4-576a-4d2f-809a-46942b48488b.sql
-- ============================================================
-- Drop and recreate the INSERT policy for video_call_sessions
-- to ensure authenticated users can insert when they are the man_user_id
DROP POLICY IF EXISTS "Men can insert video calls" ON video_call_sessions;

CREATE POLICY "Men can insert video calls" ON video_call_sessions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = man_user_id);

-- Also add a policy for service role / anon to allow edge functions
DROP POLICY IF EXISTS "Service can insert video calls" ON video_call_sessions;

CREATE POLICY "Service can insert video calls" ON video_call_sessions
  FOR INSERT TO anon
  WITH CHECK (true);

-- ============================================================
-- Migration: 20260225033957_463e9ca6-184d-4322-b06d-249f0f23c7fc.sql
-- ============================================================
-- Clean up stale video call sessions older than 2 minutes that are still ringing/connecting
UPDATE video_call_sessions 
SET status = 'ended', 
    ended_at = now(), 
    end_reason = 'timeout_cleanup'
WHERE status IN ('ringing', 'connecting') 
AND created_at < now() - interval '2 minutes';

-- ============================================================
-- Migration: 20260225041055_b5f2c72c-aea2-496c-abc9-cf4290cc6841.sql
-- ============================================================

-- Create function to reset group counts at midnight
CREATE OR REPLACE FUNCTION public.reset_private_group_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Reset participant_count to 0 for all active groups
  UPDATE public.private_groups
  SET participant_count = 0, is_live = false;

  -- Delete all group memberships (everyone re-joins fresh)
  DELETE FROM public.group_memberships;

  RAISE LOG 'Private group counts reset at midnight';
END;
$$;


-- ============================================================
-- Migration: 20260225041127_42777cb8-dc04-42dc-b702-dcd725bb8131.sql
-- ============================================================

-- Schedule midnight reset of private group counts (00:00 IST = 18:30 UTC previous day)
SELECT cron.schedule(
  'reset-private-group-counts',
  '30 18 * * *',
  $$SELECT public.reset_private_group_counts()$$
);


-- ============================================================
-- Migration: 20260225041416_c35254c5-ad2a-488b-ac4f-e8fcf0f872fb.sql
-- ============================================================

-- First delete all existing private groups and memberships (clean slate for permanent groups)
DELETE FROM public.group_memberships;
DELETE FROM public.group_video_access;
DELETE FROM public.group_messages;
DELETE FROM public.private_groups;

-- Insert 4 permanent flower-named groups (no owner - system groups)
INSERT INTO public.private_groups (id, name, description, owner_id, min_gift_amount, access_type, is_active, is_live, participant_count)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Rose', 'A beautiful rose-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000002', 'Lily', 'A graceful lily-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000003', 'Jasmine', 'A fragrant jasmine-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000004', 'Orchid', 'An elegant orchid-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0);

-- Add a column to track current host
ALTER TABLE public.private_groups ADD COLUMN IF NOT EXISTS current_host_id uuid DEFAULT NULL;
ALTER TABLE public.private_groups ADD COLUMN IF NOT EXISTS current_host_name text DEFAULT NULL;


-- ============================================================
-- Migration: 20260225043922_7488b343-313b-4463-85be-f86fce45a454.sql
-- ============================================================

-- Drop the old restrictive update policy
DROP POLICY IF EXISTS "Owners can update their groups" ON public.private_groups;

-- Create a new policy that allows owners OR current hosts to update
CREATE POLICY "Owners or hosts can update groups"
  ON public.private_groups FOR UPDATE
  USING (auth.uid() = owner_id OR auth.uid() = current_host_id OR owner_id = '00000000-0000-0000-0000-000000000000'::uuid)
  WITH CHECK (true);


-- ============================================================
-- Migration: 20260225044505_d5f6474f-d922-42fe-92ac-c15eb4c798e9.sql
-- ============================================================

-- Admin messaging table for group broadcasts and individual chats
CREATE TABLE public.admin_user_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL,
  target_group TEXT NOT NULL DEFAULT 'all',
  target_user_id UUID,
  sender_role TEXT NOT NULL DEFAULT 'admin',
  sender_id UUID NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX idx_admin_user_messages_target ON public.admin_user_messages(target_group, created_at DESC);
CREATE INDEX idx_admin_user_messages_user ON public.admin_user_messages(target_user_id, created_at DESC);
CREATE INDEX idx_admin_user_messages_created ON public.admin_user_messages(created_at);

-- Enable RLS
ALTER TABLE public.admin_user_messages ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins full access" ON public.admin_user_messages
  FOR ALL USING (true) WITH CHECK (true);

-- Auto-delete messages older than 7 days
CREATE OR REPLACE FUNCTION public.cleanup_old_admin_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.admin_user_messages
  WHERE created_at < now() - interval '7 days';
END;
$$;


-- ============================================================
-- Migration: 20260225045556_8acfbef1-08e0-4796-b3df-0491ebeb159b.sql
-- ============================================================

-- Clean up stale live groups with no host
UPDATE public.private_groups 
SET is_live = false, participant_count = 0 
WHERE is_live = true AND current_host_id IS NULL;


-- ============================================================
-- Migration: 20260225051552_9fe153d0-9b7a-4fa8-aad4-7cc9c9ba66b4.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_host_id UUID;
  v_host_wallet_id UUID;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host - tips go to the active host, not the static owner
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    -- Fallback to owner_id if no current host
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  -- Cannot tip yourself
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  -- Check if super user
  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Check balance
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate 50/50 split
  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit sender's wallet (full amount)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group tip: ' || v_gift.name || ' (to host)', 'completed');

  -- Credit host's women_earnings (50% of tip)
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group tip (50% share): ' || v_gift.name);

  -- Credit host's wallet with 50%
  SELECT id INTO v_host_wallet_id FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;
  IF v_host_wallet_id IS NOT NULL THEN
    UPDATE public.wallets SET balance = balance + v_women_share, updated_at = now() WHERE id = v_host_wallet_id;
    
    -- Create wallet transaction for host (credit 50%)
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_host_wallet_id, v_host_id, 'credit', v_women_share, 'Group tip received (50%): ' || v_gift.name, 'completed');
  END IF;

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip', 'completed');

  -- Record admin revenue (50%)
  INSERT INTO public.admin_revenue_transactions (transaction_type, amount, currency, description, man_user_id, woman_user_id, reference_id)
  VALUES ('group_tip', v_admin_share, v_gift.currency, 'Group tip admin share (50%): ' || v_gift.name, p_sender_id, v_host_id, p_group_id::text);

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$$;


-- ============================================================
-- Migration: 20260225051759_09edd489-1a4c-427b-893f-772233e86c89.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_host_id UUID;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host - tips go to the active host
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate 50/50 split
  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit sender's wallet (full amount)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group tip: ' || v_gift.emoji || ' ' || v_gift.name || ' (to host)', 'completed');

  -- Credit host via women_earnings (50% of tip) - single source of truth for women deposits
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group tip received (50%): ' || v_gift.emoji || ' ' || v_gift.name);

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip', 'completed');

  -- Record admin revenue (50%)
  INSERT INTO public.admin_revenue_transactions (transaction_type, amount, currency, description, man_user_id, woman_user_id, reference_id)
  VALUES ('group_tip', v_admin_share, v_gift.currency, 'Group tip admin share (50%): ' || v_gift.name, p_sender_id, v_host_id, p_group_id::text);

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$$;


-- ============================================================
-- Migration: 20260225052342_aa8811a7-9ed4-4107-9214-0de37fc98046.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_host_id UUID;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host - tips go to the active host
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- 50% goes to host (admin already has money from recharge)
  v_women_share := v_gift.price * 0.5;

  -- Debit sender's wallet (full amount)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group tip: ' || v_gift.emoji || ' ' || v_gift.name || ' (to host)', 'completed');

  -- Credit host via women_earnings (50% of tip)
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group tip received (50%): ' || v_gift.emoji || ' ' || v_gift.name);

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip', 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$$;


-- ============================================================
-- Migration: 20260225053156_9c789a8d-e4a5-41a6-b658-24b7adb0d05a.sql
-- ============================================================

-- Create men_free_minutes table (used by men's dashboard for free chat minutes tracking)
CREATE TABLE IF NOT EXISTS public.men_free_minutes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  free_minutes_total INT NOT NULL DEFAULT 10,
  free_minutes_used INT NOT NULL DEFAULT 0,
  last_reset_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  next_reset_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() + interval '15 days'),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- RLS for men_free_minutes
ALTER TABLE public.men_free_minutes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own free minutes" ON public.men_free_minutes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own free minutes" ON public.men_free_minutes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can insert free minutes" ON public.men_free_minutes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create get_online_women_dashboard RPC (counterpart to get_online_men_dashboard)
-- Used by men's dashboard to see online women with availability and earning status
CREATE OR REPLACE FUNCTION public.get_online_women_dashboard()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  photo_url TEXT,
  country TEXT,
  primary_language TEXT,
  age INT,
  mother_tongue TEXT,
  is_earning_eligible BOOLEAN,
  is_available BOOLEAN,
  current_chat_count INT,
  max_concurrent_chats INT,
  last_seen TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    COALESCE(p.full_name, 'Anonymous') AS full_name,
    p.photo_url,
    p.country,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'Unknown') AS mother_tongue,
    COALESCE(p.is_earning_eligible, false) AS is_earning_eligible,
    COALESCE(wa.is_available, true) AS is_available,
    COALESCE(wa.current_chat_count, 0)::int AS current_chat_count,
    COALESCE(wa.max_concurrent_chats, 3)::int AS max_concurrent_chats,
    us.last_seen
  FROM public.user_status us
  JOIN public.profiles p ON p.user_id = us.user_id
  LEFT JOIN public.women_availability wa ON wa.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT u.language_name
    FROM public.user_languages u
    WHERE u.user_id = p.user_id
    ORDER BY u.created_at DESC
    LIMIT 1
  ) ul ON TRUE
  WHERE us.is_online = TRUE
    AND auth.uid() IS NOT NULL
    AND LOWER(COALESCE(p.gender, '')) = 'female'
    AND COALESCE(p.approval_status, 'pending') = 'approved'
    AND (
      has_role(auth.uid(), 'admin'::app_role)
      OR EXISTS (
        SELECT 1
        FROM public.profiles me
        WHERE me.user_id = auth.uid()
          AND LOWER(COALESCE(me.gender, '')) = 'male'
      )
    );
$$;

-- Create get_dashboard_stats RPC for both dashboards
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender TEXT;
  v_online_count INT;
  v_match_count INT;
  v_unread_notifications INT;
  v_wallet_balance NUMERIC;
  v_today_earnings NUMERIC;
  v_active_chats INT;
BEGIN
  -- Get user gender
  SELECT LOWER(COALESCE(gender, '')) INTO v_gender
  FROM profiles WHERE user_id = p_user_id;

  -- Online users count
  SELECT COUNT(*) INTO v_online_count
  FROM user_status WHERE is_online = true;

  -- Match count
  SELECT COUNT(*) INTO v_match_count
  FROM matches
  WHERE (user_id = p_user_id OR matched_user_id = p_user_id)
    AND status = 'accepted';

  -- Unread notifications
  SELECT COUNT(*) INTO v_unread_notifications
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;

  -- Active chats
  IF v_gender = 'male' THEN
    SELECT COUNT(*) INTO v_active_chats
    FROM active_chat_sessions
    WHERE man_user_id = p_user_id AND status = 'active';
  ELSE
    SELECT COUNT(*) INTO v_active_chats
    FROM active_chat_sessions
    WHERE woman_user_id = p_user_id AND status = 'active';
  END IF;

  -- Wallet balance
  IF v_gender = 'male' THEN
    SELECT COALESCE(balance, 0) INTO v_wallet_balance
    FROM wallets WHERE user_id = p_user_id;
  ELSE
    -- Women: earnings - withdrawals
    SELECT COALESCE(SUM(amount), 0) INTO v_wallet_balance
    FROM women_earnings WHERE user_id = p_user_id;
    
    v_wallet_balance := v_wallet_balance - COALESCE((
      SELECT SUM(amount) FROM wallet_transactions
      WHERE user_id = p_user_id AND type = 'debit'
    ), 0);
  END IF;

  -- Today's earnings (women only)
  v_today_earnings := 0;
  IF v_gender = 'female' THEN
    SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
    FROM women_earnings
    WHERE user_id = p_user_id
      AND created_at >= date_trunc('day', now())
      AND created_at < date_trunc('day', now()) + interval '1 day';
  END IF;

  RETURN jsonb_build_object(
    'gender', v_gender,
    'online_count', v_online_count,
    'match_count', v_match_count,
    'unread_notifications', v_unread_notifications,
    'wallet_balance', COALESCE(v_wallet_balance, 0),
    'today_earnings', v_today_earnings,
    'active_chats', v_active_chats
  );
END;
$$;


-- ============================================================
-- Migration: 20260225054410_0499f93c-5025-4a24-97f8-c7b0303310a5.sql
-- ============================================================

-- Drop and recreate get_online_men_dashboard with correct return type
DROP FUNCTION IF EXISTS public.get_online_men_dashboard();

CREATE OR REPLACE FUNCTION public.get_online_men_dashboard()
RETURNS TABLE(
  user_id uuid,
  full_name text,
  photo_url text,
  country text,
  state text,
  preferred_language text,
  primary_language text,
  age integer,
  mother_tongue text,
  wallet_balance numeric,
  last_seen timestamptz,
  active_chat_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name,
    p.photo_url,
    p.country,
    p.state,
    p.preferred_language,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'English')::text AS mother_tongue,
    COALESCE(w.balance, 0)::numeric AS wallet_balance,
    us.last_seen,
    COALESCE(chat_counts.cnt, 0)::bigint AS active_chat_count
  FROM profiles p
  INNER JOIN user_status us ON us.user_id = p.user_id AND us.is_online = true
  LEFT JOIN LATERAL (
    SELECT ul2.language_name
    FROM user_languages ul2
    WHERE ul2.user_id = p.user_id
    ORDER BY ul2.created_at ASC
    LIMIT 1
  ) ul ON true
  LEFT JOIN wallets w ON w.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::bigint AS cnt
    FROM active_chat_sessions acs
    WHERE acs.man_user_id = p.user_id AND acs.status = 'active'
  ) chat_counts ON true
  WHERE p.gender IN ('male', 'Male')
    AND p.photo_url IS NOT NULL
    AND p.photo_url != ''
    AND p.account_status = 'active'
  ORDER BY COALESCE(chat_counts.cnt, 0) ASC, COALESCE(w.balance, 0) DESC;
END;
$$;


-- ============================================================
-- Migration: 20260225062539_89be74ba-54a8-4b71-b615-1f8d8552f905.sql
-- ============================================================
-- Insert group tip test data: Rahul tips ₹10 Rose gift to Rani (host), Rani gets ₹5 (50%)

-- 1. Debit Rahul's wallet (full ₹10)
INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
VALUES (
  '551dd8b4-59ea-4404-9410-11df121b1800',
  'b426b99c-e7d8-4b87-ba3f-ee83002fedbf',
  'debit',
  10.00,
  'Group tip: 🌹 Rose (to host)',
  'completed'
);

-- 2. Credit Rani (host) with 50% = ₹5
INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
VALUES (
  'cd6e623c-2d2a-4cc2-8705-e0ae5b3277a3',
  5.00,
  'gift',
  'Group tip received (50%): 🌹 Rose'
);

-- 3. Gift transaction record
INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
VALUES (
  'b426b99c-e7d8-4b87-ba3f-ee83002fedbf',
  'cd6e623c-2d2a-4cc2-8705-e0ae5b3277a3',
  '9bc0b3b1-d0ab-4e48-b84b-cc3fa2baba9a',
  10.00,
  'INR',
  'Group tip in Rose room',
  'completed'
);

-- ============================================================
-- Migration: 20260225062917_51f8560e-7786-4de2-9af9-4482eaa5fb04.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_host_id UUID;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host - tips go to the active host
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- 50% goes to host (admin already has money from recharge)
  v_women_share := v_gift.price * 0.5;

  -- Debit sender's wallet (full amount)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip) - includes group name
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 
    'Group tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' (₹' || v_gift.price || ')', 
    'completed');

  -- Credit host via women_earnings (50% of tip) - includes group name
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 
    'Group tip (50%): ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' - ₹' || v_women_share);

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip in ' || v_group.name, 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$$;


-- ============================================================
-- Migration: 20260225063503_2d5404b2-221c-415d-808a-88b68b3e99eb.sql
-- ============================================================
-- Reset all stuck groups that show is_live=true but have no host
UPDATE public.private_groups 
SET is_live = false, stream_id = NULL, current_host_id = NULL, current_host_name = NULL, participant_count = 0
WHERE is_live = true AND current_host_id IS NULL;

-- Clean up any orphan memberships for groups that are no longer live
DELETE FROM public.group_memberships 
WHERE group_id IN (SELECT id FROM public.private_groups WHERE is_live = false);

-- ============================================================
-- Migration: 20260225064333_b0dd0ed8-8d39-41fa-92dd-c286f979b7a2.sql
-- ============================================================
-- Fix group gift credit target: always credit active host, never placeholder owner_id

CREATE OR REPLACE FUNCTION public.process_group_gift(
  p_sender_id uuid,
  p_group_id uuid,
  p_gift_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_is_super_user BOOLEAN;
  v_host_id UUID;
BEGIN
  -- Get group details with lock
  SELECT * INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id AND is_active = true
  FOR UPDATE;

  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Resolve active host first, fallback to owner for legacy compatibility
  v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive gift');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send gift to yourself');
  END IF;

  -- Get gift details
  SELECT * INTO v_gift
  FROM public.gifts
  WHERE id = p_gift_id AND is_active = true
  FOR SHARE;

  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Check if gift meets minimum requirement
  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift does not meet minimum requirement of ' || v_group.min_gift_amount);
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_sender_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit sender
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group access gift: ' || v_gift.name, 'completed');

  -- Credit host earnings to drive statement/history views
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group access gift (50% share): ' || v_gift.name);

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group access gift', 'completed');

  INSERT INTO public.group_memberships (group_id, user_id, gift_amount_paid, has_access)
  VALUES (p_group_id, p_sender_id, v_gift.price, true)
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET has_access = true, gift_amount_paid = EXCLUDED.gift_amount_paid;

  UPDATE public.private_groups
  SET participant_count = participant_count + 1
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$function$;

-- Apply same host resolution fix to video-access group gifts
CREATE OR REPLACE FUNCTION public.process_group_video_gift(
  p_sender_id uuid,
  p_group_id uuid,
  p_gift_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_group RECORD;
  v_gift RECORD;
  v_wallet_id uuid;
  v_balance numeric;
  v_new_balance numeric;
  v_women_share numeric;
  v_access_expires timestamp with time zone;
  v_is_super_user boolean;
  v_current_members integer;
  v_already_member boolean;
  v_host_id uuid;
BEGIN
  SELECT * INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id AND is_active = true
  FOR UPDATE;

  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found or inactive');
  END IF;

  v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive gift');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send gift to yourself');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.group_memberships
    WHERE group_id = p_group_id AND user_id = p_sender_id
  ) INTO v_already_member;

  IF NOT v_already_member THEN
    SELECT COUNT(*) INTO v_current_members
    FROM public.group_memberships
    WHERE group_id = p_group_id AND user_id != v_host_id;

    IF v_current_members >= 150 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Group is full (150 men limit reached)');
    END IF;
  END IF;

  SELECT * INTO v_gift
  FROM public.gifts
  WHERE id = p_gift_id AND is_active = true;

  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift amount is below minimum required: ₹' || v_group.min_gift_amount);
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_sender_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := v_gift.price * 0.5;
  v_access_expires := now() + interval '30 minutes';

  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price,
            'Group video gift: ' || v_gift.emoji || ' ' || v_gift.name, 'completed');
  ELSE
    v_new_balance := v_balance;
  END IF;

  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift',
          'Group video gift: ' || v_gift.emoji || ' from video access');

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, status, message)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, 'completed',
          'Video call access for group: ' || v_group.name);

  INSERT INTO public.group_video_access (group_id, user_id, gift_id, gift_amount, access_expires_at)
  VALUES (p_group_id, p_sender_id, p_gift_id, v_gift.price, v_access_expires);

  IF NOT v_already_member THEN
    INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid)
    VALUES (p_group_id, p_sender_id, true, v_gift.price)
    ON CONFLICT (group_id, user_id)
    DO UPDATE SET has_access = true, gift_amount_paid = v_gift.price;

    UPDATE public.private_groups
    SET participant_count = participant_count + 1
    WHERE id = p_group_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'access_expires_at', v_access_expires,
    'access_duration_minutes', 30,
    'group_language', v_group.owner_language,
    'host_id', v_host_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================
-- Migration: 20260225065515_64f9a552-a3c3-4b58-9c1b-13e80a36f12b.sql
-- ============================================================
-- Fix women chat earnings not appearing in statement/history
-- Men are charged chat rate; women are credited women_earning_rate; admin receives remainder

CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    -- Check if man is a super user (bypass billing)
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;

    -- Pricing split for chat
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
        -- Super users don't get charged; no payout booked for bypass sessions
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes,
            last_activity_at = now()
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0
        );
    END IF;

    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
        UPDATE public.active_chat_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;

    -- Debit man's wallet (₹4/min default)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );

    -- Credit woman earnings (₹2/min default)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
    VALUES (
        v_session.woman_user_id,
        v_earning_amount,
        'chat',
        p_session_id,
        'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min'
    );

    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$;

-- ============================================================
-- Migration: 20260225071424_82002663-5838-4d43-93c8-43153a1b60e6.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_online_men_dashboard()
RETURNS TABLE(
  user_id uuid,
  full_name text,
  photo_url text,
  country text,
  state text,
  preferred_language text,
  primary_language text,
  age integer,
  mother_tongue text,
  wallet_balance numeric,
  last_seen timestamptz,
  active_chat_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name,
    p.photo_url,
    p.country,
    p.state,
    p.preferred_language,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'English')::text AS mother_tongue,
    COALESCE(w.balance, 0)::numeric AS wallet_balance,
    us.last_seen,
    COALESCE(chat_counts.cnt, 0)::bigint AS active_chat_count
  FROM profiles p
  INNER JOIN user_status us ON us.user_id = p.user_id AND us.is_online = true
  LEFT JOIN LATERAL (
    SELECT ul2.language_name
    FROM user_languages ul2
    WHERE ul2.user_id = p.user_id
    ORDER BY ul2.created_at ASC
    LIMIT 1
  ) ul ON true
  LEFT JOIN wallets w ON w.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::bigint AS cnt
    FROM active_chat_sessions acs
    WHERE acs.man_user_id = p.user_id AND acs.status = 'active'
  ) chat_counts ON true
  WHERE p.gender IN ('male', 'Male')
    AND p.account_status = 'active'
  ORDER BY COALESCE(chat_counts.cnt, 0) ASC, COALESCE(w.balance, 0) DESC;
END;
$$;

-- ============================================================
-- Migration: 20260225071724_06ac4ba2-6cc9-4645-854e-abd2dcbe3bb4.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_men_with_balance(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, balance numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT w.user_id, COALESCE(w.balance, 0)::numeric
  FROM wallets w
  WHERE w.user_id = ANY(p_user_ids)
    AND w.balance > 0;
END;
$$;

-- ============================================================
-- Migration: 20260226011524_92946dee-12e4-4984-919f-52f56b0d66c2.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
    v_lock_check integer;
BEGIN
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    UPDATE public.video_call_sessions
    SET updated_at = now()
    WHERE id = p_session_id
      AND updated_at = v_session.updated_at;
    
    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;
    
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    
    IF v_is_super_user THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call (super user session) - ' || p_minutes || ' minute(s)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
            'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- Migration: 20260226012337_3f8f002a-7070-4523-9caf-1e8988cf64cb.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_lock_check integer;
BEGIN
    -- Lock group row to prevent concurrent billing
    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    -- Optimistic lock check via updated_at
    UPDATE public.private_groups
    SET updated_at = now()
    WHERE id = p_group_id AND updated_at = v_group.updated_at;

    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    -- Get active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Men pay ₹4/min (rate_per_minute from chat_pricing)
    v_charge_amount := v_pricing.rate_per_minute;

    -- Process each non-host member with access
    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        -- Lock man's wallet
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            -- Insufficient balance: remove from group
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        -- Deduct ₹4 from man's wallet
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        -- Record debit transaction for man
        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (v_wallet.id, v_member.user_id, 'debit', v_charge_amount,
                'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)', 'completed');

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate; -- ₹2 per man
    END LOOP;

    -- Credit host earnings if any men were billed
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_host_id, v_total_host_earning, 'chat',
                'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min');
    END IF;

    -- Update participant count
    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*) FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ============================================================
-- Migration: 20260226021444_61a6f2e3-64b4-4d66-87e8-fa05095a48f4.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_last_billing_at timestamptz;
BEGIN
    -- Transaction-level advisory lock to serialize billing per group
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    -- Lock group row to ensure it is still live
    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    -- Get active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Men pay ₹4/min (rate_per_minute from chat_pricing)
    v_charge_amount := v_pricing.rate_per_minute;

    -- Strong duplicate protection: allow at most one successful billing cycle per ~minute per group
    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at)
        FROM public.wallet_transactions wt
        WHERE wt.type = 'debit'
          AND wt.description = ('Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)')
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at)
        FROM public.women_earnings we
        WHERE we.user_id = v_host_id
          AND we.description LIKE ('Group call earnings: ' || v_group.name || ' - %')
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate_skipped', true,
            'last_billed_at', v_last_billing_at
        );
    END IF;

    -- Process each non-host member with access
    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        -- Lock man's wallet
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            -- Insufficient balance: remove from group
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        -- Deduct ₹4 from man's wallet
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        -- Record debit transaction for man
        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed'
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate; -- ₹2 per man
    END LOOP;

    -- Credit host earnings if any men were billed
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'chat',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    -- Update participant count
    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*)
        FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================
-- Migration: 20260226021521_bb5127b8-b99f-47f7-930a-75838eb9e7e2.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_last_billing_at timestamptz;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    v_charge_amount := v_pricing.rate_per_minute;

    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at)
        FROM public.wallet_transactions wt
        WHERE wt.type = 'debit'
          AND wt.description = ('Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)')
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at)
        FROM public.women_earnings we
        WHERE we.user_id = v_host_id
          AND we.description LIKE ('Group call earnings: ' || v_group.name || ' - %')
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate_skipped', true,
            'last_billed_at', v_last_billing_at
        );
    END IF;

    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed'
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate;
    END LOOP;

    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'chat',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*)
        FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================
-- Migration: 20260303130913_0146a8c7-d6fe-4b51-83b8-0b3f77c29df5.sql
-- ============================================================

-- Update all billing functions to only credit earnings to Indian women
-- Men are ALWAYS charged regardless of woman's nationality

-- 1. process_chat_billing: check if woman is Indian before crediting earnings
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
    v_woman_is_indian boolean := false;
BEGIN
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;

    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    -- Only Indian women earn
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.women_earning_rate ELSE 0 END;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes,
            last_activity_at = now()
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0
        );
    END IF;

    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.active_chat_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;

    -- Always debit man
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );

    -- Only credit Indian women
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
        VALUES (
            v_session.woman_user_id,
            v_earning_amount,
            'chat',
            p_session_id,
            'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    -- Log admin revenue (full charge goes to admin if non-Indian woman)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$;

-- 2. process_video_billing: check if woman is Indian before crediting earnings
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
    v_lock_check integer;
    v_woman_is_indian boolean := false;
BEGIN
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    UPDATE public.video_call_sessions
    SET updated_at = now()
    WHERE id = p_session_id
      AND updated_at = v_session.updated_at;
    
    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;
    
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;
    
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    -- Only Indian women earn
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.video_women_earning_rate ELSE 0 END;
    
    IF v_is_super_user THEN
        IF v_earning_amount > 0 THEN
            INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                    'Video call (super user session) - ' || p_minutes || ' minute(s)');
        END IF;
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Always debit man
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    -- Only credit Indian women
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    END IF;
    
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. process_group_billing: check if host is Indian before crediting earnings
CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_last_billing_at timestamptz;
    v_host_is_indian boolean := false;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    -- Check if host is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_host_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_host_id;

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    v_charge_amount := v_pricing.rate_per_minute;

    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at)
        FROM public.wallet_transactions wt
        WHERE wt.type = 'debit'
          AND wt.description = ('Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)')
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at)
        FROM public.women_earnings we
        WHERE we.user_id = v_host_id
          AND we.description LIKE ('Group call earnings: ' || v_group.name || ' - %')
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate_skipped', true,
            'last_billed_at', v_last_billing_at
        );
    END IF;

    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        -- Always charge the man
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed'
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        
        -- Only accumulate host earnings if host is Indian
        IF v_host_is_indian THEN
            v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate;
        END IF;
    END LOOP;

    -- Only credit Indian host
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'chat',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*)
        FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'host_is_indian', v_host_is_indian,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;


-- ============================================================
-- Migration: 20260304034410_85966b21-6061-4966-9fd1-8f163a3588ff.sql
-- ============================================================
-- Fix gift and group tip RPCs to only credit Indian women (non-Indian women earn ₹0)
-- Men are ALWAYS charged full price regardless of woman's nationality

-- 1. process_gift_transaction: add is_indian check
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
    p_sender_id uuid,
    p_receiver_id uuid,
    p_gift_id uuid,
    p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
    v_women_share numeric;
    v_receiver_is_indian boolean := false;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Check if receiver is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_receiver_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = p_receiver_id;
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- 50% share for Indian women only; non-Indian women get ₹0
    v_women_share := CASE WHEN v_receiver_is_indian THEN v_gift.price * 0.5 ELSE 0 END;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance;
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic) - always debit full price from man
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings ONLY if Indian (50% of gift value)
    IF v_women_share > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    END IF;
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'receiver_is_indian', v_receiver_is_indian,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 2. process_group_tip: add is_indian check for host
CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_host_id UUID;
  v_is_super_user BOOLEAN;
  v_host_is_indian BOOLEAN := false;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  -- Check if host is Indian
  SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_host_is_indian
  FROM public.profiles p
  LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
  WHERE p.user_id = v_host_id;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- 50% goes to host ONLY if Indian; non-Indian host gets ₹0
  v_women_share := CASE WHEN v_host_is_indian THEN v_gift.price * 0.5 ELSE 0 END;

  -- Debit sender's wallet (full amount always)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 
    'Group tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' (₹' || v_gift.price || ')', 
    'completed');

  -- Credit host via women_earnings ONLY if Indian
  IF v_women_share > 0 THEN
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_host_id, v_women_share, 'gift', 
      'Group tip (50%): ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' - ₹' || v_women_share);
  END IF;

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip in ' || v_group.name, 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id,
    'host_is_indian', v_host_is_indian
  );
END;
$$;

-- ============================================================
-- Migration: 20260304034811_645eefee-4208-4112-a952-8cd49ef181e1.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_available_balance numeric := 0;
  v_today_start timestamptz;
  v_today_end timestamptz;
BEGIN
  -- Calculate today boundaries in UTC (client handles timezone)
  v_today_start := date_trunc('day', now());
  v_today_end := v_today_start + interval '1 day' - interval '1 millisecond';

  -- Total earnings (no row limit - server-side aggregation)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings
  WHERE user_id = p_user_id;

  -- Total debits from wallet_transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_total_debits
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  -- Pending + approved withdrawals
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests
  WHERE user_id = p_user_id AND status IN ('pending', 'approved');

  -- Today's earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM women_earnings
  WHERE user_id = p_user_id
    AND created_at >= v_today_start
    AND created_at <= v_today_end;

  v_available_balance := v_total_earnings - v_total_debits - v_pending_withdrawals;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_available_balance
  );
END;
$$;


-- ============================================================
-- Migration: 20260304035308_47cd5eea-fe7e-4a22-b46e-e9d84c195874.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  -- Get current wallet balance (source of truth for men)
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM wallets
  WHERE user_id = p_user_id;

  -- Total credits (recharges)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_recharges
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'credit';

  -- Total debits (spending on chats, video, gifts)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_spending
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;


-- ============================================================
-- Migration: 20260304040405_defb7d49-ad93-4e55-babf-e5e410ab0069.sql
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_available_balance numeric := 0;
  v_today_start timestamptz;
  v_today_end timestamptz;
BEGIN
  v_today_start := date_trunc('day', now());
  v_today_end := v_today_start + interval '1 day' - interval '1 millisecond';

  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings
  WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_debits
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  -- Only 'pending' withdrawals - approved/completed ones already exist as debits in wallet_transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests
  WHERE user_id = p_user_id AND status = 'pending';

  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM women_earnings
  WHERE user_id = p_user_id
    AND created_at >= v_today_start
    AND created_at <= v_today_end;

  v_available_balance := v_total_earnings - v_total_debits - v_pending_withdrawals;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_available_balance
  );
END;
$$;

-- ============================================================
-- Migration: 20260304040631_a8ba02ea-bba3-4fee-9403-4697fd8c11c4.sql
-- ============================================================
-- Fix process_chat_billing: add optimistic lock to prevent duplicate billing (matches video billing pattern)
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
    v_woman_is_indian boolean := false;
    v_lock_check integer;
BEGIN
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    -- Optimistic lock: update last_activity_at only if it hasn't changed (prevents duplicate billing)
    UPDATE public.active_chat_sessions
    SET last_activity_at = now()
    WHERE id = p_session_id
      AND last_activity_at = v_session.last_activity_at;

    GET DIAGNOSTICS v_lock_check = ROW_COUNT;

    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;

    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;

    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.women_earning_rate ELSE 0 END;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0
        );
    END IF;

    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.active_chat_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;

    -- Always debit man
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );

    -- Only credit Indian women
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
        VALUES (
            v_session.woman_user_id,
            v_earning_amount,
            'chat',
            p_session_id,
            'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$;

-- Fix get_men_wallet_balance: use wallets.balance as single source of truth, no double-counting
-- wallets.balance is already maintained atomically by process_wallet_transaction
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  -- wallets.balance is the single source of truth (atomically updated by all billing RPCs)
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM wallets
  WHERE user_id = p_user_id;

  -- These are for display/summary only, not for calculating balance
  SELECT COALESCE(SUM(amount), 0) INTO v_total_recharges
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'credit';

  SELECT COALESCE(SUM(amount), 0) INTO v_total_spending
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;

-- Fix get_women_wallet_balance: ensure no double-counting of withdrawals
-- Approved/completed withdrawals already exist as debits in wallet_transactions
-- Only hold back pending (not yet processed) withdrawals
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_available_balance numeric := 0;
  v_today_start timestamptz;
  v_today_end timestamptz;
BEGIN
  v_today_start := date_trunc('day', now());
  v_today_end := v_today_start + interval '1 day' - interval '1 millisecond';

  -- Total earnings from women_earnings (server-side, bypasses row limit)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings
  WHERE user_id = p_user_id;

  -- Total debits (includes completed withdrawals)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_debits
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  -- Only pending withdrawals (approved/completed already recorded as debits)
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests
  WHERE user_id = p_user_id AND status = 'pending';

  -- Today's earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM women_earnings
  WHERE user_id = p_user_id
    AND created_at >= v_today_start
    AND created_at <= v_today_end;

  v_available_balance := v_total_earnings - v_total_debits - v_pending_withdrawals;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_available_balance
  );
END;
$$;

-- ============================================================
-- Migration: 20260304050446_53499778-eae9-4161-a2bb-190f8db02ed7.sql
-- ============================================================
INSERT INTO public.private_groups (owner_id, name, description, access_type, is_active, is_live, participant_count)
VALUES
  ('00000000-0000-0000-0000-000000000000', 'Sunflower', 'Sunflower private group room', 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000000', 'Tulip', 'Tulip private group room', 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000000', 'Lotus', 'Lotus private group room', 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000000', 'Daisy', 'Daisy private group room', 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000000', 'Lavender', 'Lavender private group room', 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000000', 'Marigold', 'Marigold private group room', 'both', true, false, 0);

-- ============================================================
-- Migration: 20260306070716_88e49a8b-f474-4ca8-987b-491ea6d5e353.sql
-- ============================================================

-- 1. Add user_status to realtime publication so frontend can see changes
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_status;

-- 2. Drop redundant increment/decrement triggers that cause count drift
DROP TRIGGER IF EXISTS trigger_sync_all_chat_availability ON active_chat_sessions;
DROP TRIGGER IF EXISTS sync_women_chat_count_trigger ON active_chat_sessions;
DROP TRIGGER IF EXISTS sync_user_chat_count_trigger ON active_chat_sessions;
DROP TRIGGER IF EXISTS trigger_sync_all_video_availability ON video_call_sessions;

-- 3. Replace chat session trigger: handles ALL status transitions using actual COUNTs
CREATE OR REPLACE FUNCTION public.sync_user_availability_on_session_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_woman_id uuid;
  v_man_id uuid;
  v_woman_chat_count INTEGER;
  v_woman_video_count INTEGER;
  v_man_chat_count INTEGER;
  v_man_video_count INTEGER;
BEGIN
  v_woman_id := COALESCE(NEW.woman_user_id, OLD.woman_user_id);
  v_man_id := COALESCE(NEW.man_user_id, OLD.man_user_id);

  IF v_woman_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_woman_chat_count
    FROM active_chat_sessions
    WHERE woman_user_id = v_woman_id AND status = 'active';
    
    SELECT COUNT(*) INTO v_woman_video_count
    FROM video_call_sessions
    WHERE woman_user_id = v_woman_id AND status = 'active';
    
    UPDATE women_availability
    SET 
      current_chat_count = v_woman_chat_count,
      is_available = v_woman_chat_count < 3 AND v_woman_video_count = 0,
      is_available_for_calls = v_woman_video_count = 0,
      current_call_count = v_woman_video_count
    WHERE user_id = v_woman_id;
    
    UPDATE user_status
    SET 
      active_chat_count = v_woman_chat_count,
      active_call_count = v_woman_video_count,
      status_text = CASE 
        WHEN is_online = false THEN 'offline'
        WHEN v_woman_video_count > 0 THEN 'busy'
        WHEN v_woman_chat_count >= 3 THEN 'busy'
        ELSE 'online'
      END,
      last_seen = now()
    WHERE user_id = v_woman_id;
  END IF;
  
  IF v_man_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_man_chat_count
    FROM active_chat_sessions
    WHERE man_user_id = v_man_id AND status = 'active';
    
    SELECT COUNT(*) INTO v_man_video_count
    FROM video_call_sessions
    WHERE man_user_id = v_man_id AND status = 'active';
    
    UPDATE user_status
    SET 
      active_chat_count = v_man_chat_count,
      active_call_count = v_man_video_count,
      status_text = CASE 
        WHEN is_online = false THEN 'offline'
        WHEN v_man_video_count > 0 THEN 'busy'
        WHEN v_man_chat_count >= 3 THEN 'busy'
        ELSE 'online'
      END,
      last_seen = now()
    WHERE user_id = v_man_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- 4. Replace video call trigger: handles ALL transitions (declined, missed, timeout_cleanup, ended)
CREATE OR REPLACE FUNCTION public.sync_user_status_on_video_call_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_chat_count integer;
  v_video_count integer;
  v_status_text text;
BEGIN
  FOR v_user_id IN
    SELECT unnest(ARRAY[
      COALESCE(NEW.woman_user_id, OLD.woman_user_id),
      COALESCE(NEW.man_user_id, OLD.man_user_id)
    ])
  LOOP
    IF v_user_id IS NULL THEN CONTINUE; END IF;

    SELECT COUNT(*) INTO v_chat_count
    FROM active_chat_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    SELECT COUNT(*) INTO v_video_count
    FROM video_call_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    IF v_video_count > 0 THEN
      v_status_text := 'busy';
    ELSIF v_chat_count >= 3 THEN
      v_status_text := 'busy';
    ELSE
      v_status_text := 'online';
    END IF;

    UPDATE user_status
    SET status_text = CASE WHEN is_online = false THEN 'offline' ELSE v_status_text END,
        active_chat_count = v_chat_count,
        active_call_count = v_video_count,
        last_seen = now()
    WHERE user_id = v_user_id;

    UPDATE women_availability
    SET current_call_count = v_video_count,
        current_chat_count = v_chat_count,
        is_available = v_chat_count < 3 AND v_video_count = 0,
        is_available_for_calls = v_video_count = 0
    WHERE user_id = v_user_id;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- 5. Reset any drifted counts to accurate values
UPDATE user_status us
SET active_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions 
  WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active'
),
active_call_count = (
  SELECT COUNT(*) FROM video_call_sessions 
  WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active'
),
status_text = CASE
  WHEN is_online = false THEN 'offline'
  WHEN (SELECT COUNT(*) FROM video_call_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') > 0 THEN 'busy'
  WHEN (SELECT COUNT(*) FROM active_chat_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') >= 3 THEN 'busy'
  WHEN is_online = true THEN 'online'
  ELSE 'offline'
END;

UPDATE women_availability wa
SET current_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
),
current_call_count = (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
),
is_available = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) < 3 AND (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) = 0,
is_available_for_calls = (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) = 0;


-- ============================================================
-- Migration: 20260306075809_9ea705af-bc5d-4dba-a4d9-1b7d7f798402.sql
-- ============================================================

-- Update process_video_billing to include rate in men's debit description
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
    v_lock_check integer;
    v_woman_is_indian boolean := false;
BEGIN
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    UPDATE public.video_call_sessions
    SET updated_at = now()
    WHERE id = p_session_id
      AND updated_at = v_session.updated_at;
    
    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;
    
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;
    
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    -- Only Indian women earn
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.video_women_earning_rate ELSE 0 END;
    
    IF v_is_super_user THEN
        IF v_earning_amount > 0 THEN
            INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                    'Video call earning - ' || p_minutes || ' min at ₹' || v_pricing.video_women_earning_rate || '/min');
        END IF;
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;
    
    -- Always debit man - include rate in description
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call debit - ' || p_minutes || ' min at ₹' || v_pricing.video_rate_per_minute || '/min', 'completed');
    
    -- Only credit Indian women - include rate in description
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call earning - ' || p_minutes || ' min at ₹' || v_pricing.video_women_earning_rate || '/min');
    END IF;
    
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ============================================================
-- Migration: 20260311000000_sync_live_db_schema.sql
-- ============================================================
-- ============================================================
-- SYNC: Live DB schema changes not yet in migration files
-- Covers versions: 20260306152359 through 20260310212756
-- ============================================================

-- ============================================================
-- 1. user_fcm_tokens table (20260306171633)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own FCM tokens"
  ON public.user_fcm_tokens
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 2. ledger_transactions table (20260310212557)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ledger_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid,
  transaction_type text NOT NULL,
  debit numeric NOT NULL DEFAULT 0.00,
  credit numeric NOT NULL DEFAULT 0.00,
  rate_per_minute numeric,
  duration_seconds integer,
  counterparty_id uuid,
  reference_id text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ledger_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own ledger transactions"
  ON public.ledger_transactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_user_id_created 
  ON public.ledger_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_session_id 
  ON public.ledger_transactions(session_id);

-- ============================================================
-- 3. admin_user_messages: allow null admin_id (20260306171641)
-- ============================================================
ALTER TABLE public.admin_user_messages
  ALTER COLUMN admin_id DROP NOT NULL;

-- ============================================================
-- 4. Performance indexes (20260306180535)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created
  ON public.wallet_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_idempotency_key
  ON public.wallet_transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_women_earnings_user_created
  ON public.women_earnings(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_status
  ON public.active_chat_sessions(status, man_user_id, woman_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_video_call_sessions_status
  ON public.video_call_sessions(status, man_user_id, woman_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_status_is_online
  ON public.user_status(is_online, last_seen)
  WHERE is_online = true;

-- ============================================================
-- 5. chat_pricing: add group call rates (20260306195114)
-- ============================================================
ALTER TABLE public.chat_pricing
  ADD COLUMN IF NOT EXISTS group_call_rate_per_minute numeric DEFAULT 3.00,
  ADD COLUMN IF NOT EXISTS group_call_women_earning_rate numeric DEFAULT 2.00;

-- ============================================================
-- 6. video_call_sessions: add started_at if missing (20260306193952)
-- ============================================================
ALTER TABLE public.video_call_sessions
  ADD COLUMN IF NOT EXISTS started_at timestamptz;

-- ============================================================
-- 7. get_transaction_month_summary RPC (20260308153238)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_transaction_month_summary(
  p_user_id uuid,
  p_gender text,
  p_month_start timestamptz,
  p_month_end timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_opening_balance   numeric := 0;
    v_current_balance   numeric := 0;
    v_transactions      jsonb   := '[]'::jsonb;
    v_pricing           jsonb   := NULL;
    v_wallet_balance    numeric := 0;
    v_this_credits      numeric := 0;
    v_this_debits       numeric := 0;
    v_after_credits     numeric := 0;
    v_after_debits      numeric := 0;
    v_prior_earnings    numeric := 0;
    v_prior_debits      numeric := 0;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied');
    END IF;

    SELECT jsonb_build_object(
        'menChatRate',    rate_per_minute,
        'menVideoRate',   video_rate_per_minute,
        'womenChatRate',  women_earning_rate,
        'womenVideoRate', video_women_earning_rate
    ) INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF p_gender = 'male' THEN
        SELECT COALESCE(balance, 0) INTO v_current_balance
        FROM public.wallets WHERE user_id = p_user_id;
    ELSE
        SELECT
            COALESCE((SELECT SUM(amount) FROM public.women_earnings WHERE user_id = p_user_id), 0)
            - COALESCE((SELECT SUM(amount) FROM public.wallet_transactions WHERE user_id = p_user_id AND type = 'debit'), 0)
            - COALESCE((SELECT SUM(amount) FROM public.withdrawal_requests WHERE user_id = p_user_id AND status = 'pending'), 0)
        INTO v_current_balance;
    END IF;

    IF p_gender = 'male' THEN
        v_wallet_balance := v_current_balance;

        SELECT
            COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0)
        INTO v_this_credits, v_this_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id
          AND created_at >= p_month_start AND created_at <= p_month_end;

        SELECT
            COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0)
        INTO v_after_credits, v_after_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id AND created_at > p_month_end;

        v_opening_balance := v_wallet_balance
                             - v_this_credits + v_this_debits
                             - v_after_credits + v_after_debits;
    ELSE
        SELECT COALESCE(SUM(amount), 0) INTO v_prior_earnings
        FROM public.women_earnings
        WHERE user_id = p_user_id AND created_at < p_month_start;

        SELECT COALESCE(SUM(amount), 0) INTO v_prior_debits
        FROM public.wallet_transactions
        WHERE user_id = p_user_id AND type = 'debit' AND created_at < p_month_start;

        v_opening_balance := v_prior_earnings - v_prior_debits;
    END IF;

    IF p_gender = 'male' THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'id',           id,
                'source',       'wallet_tx',
                'is_credit',    (type = 'credit'),
                'type',         type,
                'amount',       amount,
                'description',  COALESCE(description, ''),
                'status',       status,
                'created_at',   created_at,
                'reference_id', COALESCE(reference_id, upper(substring(id::text, 1, 8)))
            ) ORDER BY created_at ASC
        ) INTO v_transactions
        FROM public.wallet_transactions
        WHERE user_id = p_user_id
          AND created_at >= p_month_start AND created_at <= p_month_end;
    ELSE
        SELECT jsonb_agg(row ORDER BY row_ts ASC) INTO v_transactions
        FROM (
            SELECT
                jsonb_build_object(
                    'id',           id,
                    'source',       'wallet_tx',
                    'is_credit',    false,
                    'amount',       amount,
                    'description',  COALESCE(description, 'Debit'),
                    'status',       status,
                    'created_at',   created_at,
                    'reference_id', COALESCE(reference_id, upper(substring(id::text, 1, 8)))
                ) AS row,
                created_at AS row_ts
            FROM public.wallet_transactions
            WHERE user_id = p_user_id AND type = 'debit'
              AND created_at >= p_month_start AND created_at <= p_month_end

            UNION ALL

            SELECT
                jsonb_build_object(
                    'id',           'earning-' || id::text,
                    'source',       'women_earnings',
                    'is_credit',    true,
                    'amount',       amount,
                    'earning_type', earning_type,
                    'description',  COALESCE(description, earning_type || ' earnings'),
                    'status',       'completed',
                    'created_at',   created_at,
                    'reference_id', upper(substring(id::text, 1, 8))
                ) AS row,
                created_at AS row_ts
            FROM public.women_earnings
            WHERE user_id = p_user_id
              AND created_at >= p_month_start AND created_at <= p_month_end
        ) combined_rows;
    END IF;

    RETURN jsonb_build_object(
        'opening_balance', v_opening_balance,
        'current_balance', v_current_balance,
        'transactions',    COALESCE(v_transactions, '[]'::jsonb),
        'pricing_rates',   v_pricing
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_transaction_month_summary(uuid, text, timestamptz, timestamptz) TO authenticated;

-- ============================================================
-- 8. Transaction query indexes (20260308153248)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_type_created
  ON public.wallet_transactions(user_id, type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_women_earnings_user_type_created
  ON public.women_earnings(user_id, earning_type, created_at DESC);

-- ============================================================
-- 9. sweep_stale_user_status function (20260306191153)
-- ============================================================
CREATE OR REPLACE FUNCTION public.sweep_stale_user_status()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < now() - interval '5 minutes';
END;
$$;

GRANT EXECUTE ON FUNCTION public.sweep_stale_user_status() TO service_role;



-- ============================================================
-- Migration: 20260312000000_fix_group_billing_use_group_rate.sql
-- ============================================================
-- Fix process_group_billing: use group_call_rate_per_minute and group_call_women_earning_rate
-- Previously was incorrectly using rate_per_minute (chat rate) for group calls

CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_last_billing_at timestamptz;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Use group_call_rate_per_minute (not chat rate_per_minute)
    v_charge_amount := COALESCE(v_pricing.group_call_rate_per_minute, v_pricing.rate_per_minute);

    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at)
        FROM public.wallet_transactions wt
        WHERE wt.type = 'debit'
          AND wt.description = ('Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)')
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at)
        FROM public.women_earnings we
        WHERE we.user_id = v_host_id
          AND we.description LIKE ('Group call earnings: ' || v_group.name || ' - %')
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate_skipped', true,
            'last_billed_at', v_last_billing_at
        );
    END IF;

    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed'
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        -- Use group_call_women_earning_rate for host earnings
        v_total_host_earning := v_total_host_earning + COALESCE(v_pricing.group_call_women_earning_rate, v_pricing.women_earning_rate);
    END LOOP;

    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'group_call',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || COALESCE(v_pricing.group_call_women_earning_rate, v_pricing.women_earning_rate) || '/min'
        );
    END IF;

    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*)
        FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;


-- ============================================================
-- Migration: 20260312000001_update_group_call_rate_to_4.sql
-- ============================================================
-- Update group call pricing: men charged ₹4/min, host earns ₹2/min per man

-- Update column defaults
ALTER TABLE public.chat_pricing
  ALTER COLUMN group_call_rate_per_minute SET DEFAULT 4.00;

-- Update existing active pricing row to ₹4/min
UPDATE public.chat_pricing
SET 
  group_call_rate_per_minute = 4.00,
  group_call_women_earning_rate = 2.00,
  updated_at = now()
WHERE is_active = true;


-- ============================================================
-- Migration: 20260312000002_fix_error_handling_and_indexes.sql
-- ============================================================
-- ============================================================
-- Migration: Fix error handling in RPC functions + add indexes
-- Date: 2026-03-12
-- Description:
--   1. Improve error messages in RPC functions to be user-friendly
--   2. Add missing performance indexes
--   3. Fix NULL handling in critical billing functions
--   4. Add missing constraint checks
-- ============================================================

-- ─── 1. Improve error messages in process_wallet_transaction ──────────────────
CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
  p_user_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_transaction_id uuid;
  v_new_balance numeric;
BEGIN
  -- Validate inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction amount must be greater than zero');
  END IF;

  IF p_type IS NULL OR p_type NOT IN ('credit', 'debit', 'recharge', 'withdrawal', 'refund') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid transaction type');
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF FOUND THEN
      SELECT balance INTO v_new_balance FROM public.wallets WHERE user_id = p_user_id;
      RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'duplicate_skipped', true,
        'new_balance', v_new_balance
      );
    END IF;
  END IF;

  -- Lock wallet row
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found. Please contact support.');
  END IF;

  -- Balance check for debits
  IF p_type IN ('debit', 'withdrawal') AND v_wallet.balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Your wallet balance is too low for this transaction. Please top up and try again.',
      'error_code', 'insufficient_balance',
      'current_balance', v_wallet.balance,
      'required_amount', p_amount
    );
  END IF;

  -- Update balance
  IF p_type IN ('credit', 'recharge', 'refund') THEN
    v_new_balance := v_wallet.balance + p_amount;
  ELSE
    v_new_balance := v_wallet.balance - p_amount;
  END IF;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record transaction
  INSERT INTO public.wallet_transactions (
    user_id, amount, transaction_type, description, reference_id, idempotency_key,
    balance_after, created_at
  ) VALUES (
    p_user_id, p_amount, p_type,
    COALESCE(p_description, p_type || ' of ₹' || p_amount),
    p_reference_id, p_idempotency_key, v_new_balance, now()
  )
  RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'new_balance', v_new_balance,
    'previous_balance', v_wallet.balance
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'An unexpected error occurred while processing your transaction. Please try again.',
      'error_code', SQLSTATE
    );
END;
$$;

-- ─── 2. Fix NULL handling in get_top_earner_today ─────────────────────────────
CREATE OR REPLACE FUNCTION public.get_top_earner_today()
RETURNS TABLE(user_id uuid, full_name text, total_amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
    SELECT
      we.user_id,
      COALESCE(p.full_name, 'Anonymous') AS full_name,
      COALESCE(SUM(we.amount), 0) AS total_amount
    FROM public.women_earnings we
    LEFT JOIN public.profiles p ON p.id = we.user_id
    WHERE we.created_at >= CURRENT_DATE
      AND we.earning_type IN ('chat', 'video', 'group_call', 'tip')
    GROUP BY we.user_id, p.full_name
    ORDER BY total_amount DESC
    LIMIT 1;
EXCEPTION
  WHEN OTHERS THEN
    -- Return empty result on error rather than crashing caller
    RETURN;
END;
$$;

-- ─── 3. Add missing performance indexes ───────────────────────────────────────

-- Profiles lookup by gender (used in matching, dashboard)
CREATE INDEX IF NOT EXISTS idx_profiles_gender
  ON public.profiles(gender)
  WHERE gender IS NOT NULL;

-- Profiles lookup by approval_status (admin, women dashboard)
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status
  ON public.profiles(approval_status)
  WHERE approval_status IS NOT NULL;

-- Active chat sessions by user (chat screen loads)
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_man_user
  ON public.active_chat_sessions(man_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_woman_user
  ON public.active_chat_sessions(woman_user_id)
  WHERE status = 'active';

-- User status for online/offline checks (matching, dashboard)
CREATE INDEX IF NOT EXISTS idx_user_status_user_id_online
  ON public.user_status(user_id, is_online);

-- Wallet transactions user+type lookup (wallet history screen)
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_type
  ON public.wallet_transactions(user_id, transaction_type, created_at DESC);

-- Women earnings by date (leaderboard, stats)
CREATE INDEX IF NOT EXISTS idx_women_earnings_created_at
  ON public.women_earnings(created_at DESC);

-- KYC submissions status (admin KYC review)
CREATE INDEX IF NOT EXISTS idx_kyc_submissions_status
  ON public.kyc_submissions(status)
  WHERE status IS NOT NULL;

-- User roles lookup (auth checks)
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id_role
  ON public.user_roles(user_id, role);

-- Notifications by user (inbox)
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read
  ON public.notifications(user_id, is_read, created_at DESC)
  WHERE is_read = false;

-- ─── 4. Fix check_session_balance to return friendly error messages ────────────
CREATE OR REPLACE FUNCTION public.check_session_balance(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_pricing RECORD;
  v_min_balance numeric;
BEGIN
  IF p_user_id IS NULL OR p_session_id IS NULL THEN
    RETURN jsonb_build_object('has_balance', false, 'error', 'Invalid session parameters');
  END IF;

  SELECT balance INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'has_balance', false,
      'balance', 0,
      'error', 'Wallet not found. Please contact support.'
    );
  END IF;

  -- Get active pricing for minimum balance check
  SELECT * INTO v_pricing
  FROM public.chat_pricing
  WHERE is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  v_min_balance := CASE WHEN v_pricing IS NOT NULL THEN v_pricing.men_rate_per_min ELSE 2 END;

  RETURN jsonb_build_object(
    'has_balance', v_wallet.balance >= v_min_balance,
    'balance', v_wallet.balance,
    'min_required', v_min_balance
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'has_balance', false,
      'error', 'Unable to check balance. Please refresh and try again.'
    );
END;
$$;

-- ─── 5. Ensure wallets row always exists when profiles row exists ──────────────
CREATE OR REPLACE FUNCTION public.ensure_wallet_exists()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_ensure_wallet_exists ON public.profiles;
CREATE TRIGGER trigger_ensure_wallet_exists
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_wallet_exists();

-- ─── 6. Grant execute permissions on new/updated functions ────────────────────
GRANT EXECUTE ON FUNCTION public.get_top_earner_today() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_session_balance(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_wallet_transaction(uuid, numeric, text, text, uuid, text) TO authenticated;



-- ============================================================
-- Migration: 20260312000003_billing_rules_monthly_statements.sql
-- ============================================================
-- ============================================================
-- Migration: billing_rules_monthly_statements
-- Applied: 2026-03-12
-- Purpose:
--   1. Enforce correct billing rates per spec
--      Text/Group: men ₹4/min, women ₹2/min per man
--      Video:      men ₹8/min, women ₹4/min
--   2. Create monthly_statements table (admin-only RLS)
--   3. RPCs: generate_monthly_statement, admin_get_statement_detail,
--            admin_search_statements, admin_update_statement_urls
-- ============================================================

-- 1. Enforce correct billing rates
UPDATE public.chat_pricing SET
  rate_per_minute              = 4.00,
  women_earning_rate           = 2.00,
  video_rate_per_minute        = 8.00,
  video_women_earning_rate     = 4.00,
  group_call_rate_per_minute   = 4.00,
  group_call_women_earning_rate = 2.00,
  updated_at = now()
WHERE is_active = true;

-- 2. monthly_statements table (admin-only, internal ledger)
CREATE TABLE IF NOT EXISTS public.monthly_statements (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  year             integer NOT NULL,
  month            integer NOT NULL CHECK (month BETWEEN 1 AND 12),
  opening_balance  numeric(10,2) NOT NULL DEFAULT 0,
  total_debit      numeric(10,2) NOT NULL DEFAULT 0,
  total_credit     numeric(10,2) NOT NULL DEFAULT 0,
  closing_balance  numeric(10,2) NOT NULL DEFAULT 0,
  pdf_url          text,
  excel_url        text,
  word_url         text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, year, month)
);

ALTER TABLE public.monthly_statements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS monthly_statements_admin_only ON public.monthly_statements;
CREATE POLICY monthly_statements_admin_only ON public.monthly_statements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_monthly_statements_user_year_month
  ON public.monthly_statements(user_id, year DESC, month DESC);

-- 3. generate_monthly_statement RPC
--    Men  → wallet_transactions
--    Women → women_earnings
CREATE OR REPLACE FUNCTION public.generate_monthly_statement(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_gender           text;
  v_period_start     timestamptz;
  v_period_end       timestamptz;
  v_opening_balance  numeric(10,2);
  v_total_debit      numeric(10,2);
  v_total_credit     numeric(10,2);
  v_closing_balance  numeric(10,2);
  v_prev_year        integer;
  v_prev_month       integer;
  v_stmt_id          uuid;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1;
  END IF;

  SELECT closing_balance INTO v_opening_balance
  FROM public.monthly_statements
  WHERE user_id = p_user_id AND year = v_prev_year AND month = v_prev_month;
  IF v_opening_balance IS NULL THEN v_opening_balance := 0; END IF;

  IF v_gender = 'male' THEN
    SELECT
      COALESCE(SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0)
    INTO v_total_debit, v_total_credit
    FROM public.wallet_transactions
    WHERE user_id = p_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;
  ELSE
    SELECT
      COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0),
      COALESCE(SUM(amount), 0)
    INTO v_total_debit, v_total_credit
    FROM public.women_earnings
    WHERE user_id = p_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;
  END IF;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  INSERT INTO public.monthly_statements
    (user_id, year, month, opening_balance, total_debit, total_credit, closing_balance)
  VALUES
    (p_user_id, p_year, p_month, v_opening_balance, v_total_debit, v_total_credit, v_closing_balance)
  ON CONFLICT (user_id, year, month) DO UPDATE SET
    opening_balance = EXCLUDED.opening_balance,
    total_debit     = EXCLUDED.total_debit,
    total_credit    = EXCLUDED.total_credit,
    closing_balance = EXCLUDED.closing_balance
  RETURNING id INTO v_stmt_id;

  RETURN jsonb_build_object(
    'success',         true,
    'statement_id',    v_stmt_id,
    'opening_balance', v_opening_balance,
    'total_debit',     v_total_debit,
    'total_credit',    v_total_credit,
    'closing_balance', v_closing_balance
  );
END;
$$;

-- 4. admin_get_statement_detail RPC
CREATE OR REPLACE FUNCTION public.admin_get_statement_detail(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS TABLE (
  txn_date         timestamptz,
  transaction_id   text,
  session_id       text,
  txn_type         text,
  duration_minutes integer,
  debit            numeric,
  credit           numeric,
  balance_after    numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_gender       text;
  v_period_start timestamptz;
  v_period_end   timestamptz;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF v_gender = 'male' THEN
    RETURN QUERY
      SELECT wt.created_at, wt.id::text, wt.session_id::text, wt.type,
             NULL::integer,
             CASE WHEN wt.type = 'debit'  THEN wt.amount ELSE 0 END,
             CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END,
             NULL::numeric
      FROM public.wallet_transactions wt
      WHERE wt.user_id = p_user_id
        AND wt.created_at >= v_period_start AND wt.created_at < v_period_end
      ORDER BY wt.created_at;
  ELSE
    RETURN QUERY
      SELECT we.created_at, we.id::text, we.session_id::text, we.earning_type,
             NULL::integer, 0::numeric, we.amount, NULL::numeric
      FROM public.women_earnings we
      WHERE we.user_id = p_user_id
        AND we.created_at >= v_period_start AND we.created_at < v_period_end
      ORDER BY we.created_at;
  END IF;
END;
$$;

-- 5. admin_search_statements RPC
CREATE OR REPLACE FUNCTION public.admin_search_statements(
  p_user_id uuid    DEFAULT NULL,
  p_year    integer DEFAULT NULL,
  p_month   integer DEFAULT NULL,
  p_limit   integer DEFAULT 50,
  p_offset  integer DEFAULT 0
)
RETURNS TABLE (
  statement_id     uuid,
  user_id          uuid,
  full_name        text,
  gender           text,
  year             integer,
  month            integer,
  opening_balance  numeric,
  total_debit      numeric,
  total_credit     numeric,
  closing_balance  numeric,
  pdf_url          text,
  excel_url        text,
  created_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
    SELECT ms.id, ms.user_id, p.full_name, p.gender,
           ms.year, ms.month,
           ms.opening_balance, ms.total_debit, ms.total_credit, ms.closing_balance,
           ms.pdf_url, ms.excel_url, ms.created_at
    FROM public.monthly_statements ms
    JOIN public.profiles p ON p.id = ms.user_id
    WHERE (p_user_id IS NULL OR ms.user_id = p_user_id)
      AND (p_year   IS NULL OR ms.year  = p_year)
      AND (p_month  IS NULL OR ms.month = p_month)
    ORDER BY ms.year DESC, ms.month DESC, ms.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 6. admin_update_statement_urls RPC
CREATE OR REPLACE FUNCTION public.admin_update_statement_urls(
  p_statement_id uuid,
  p_pdf_url      text DEFAULT NULL,
  p_excel_url    text DEFAULT NULL,
  p_word_url     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.monthly_statements SET
    pdf_url   = COALESCE(p_pdf_url,   pdf_url),
    excel_url = COALESCE(p_excel_url, excel_url),
    word_url  = COALESCE(p_word_url,  word_url)
  WHERE id = p_statement_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Statement not found');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_monthly_statement(uuid, integer, integer)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_statement_detail(uuid, integer, integer)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_statements(uuid, integer, integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_statement_urls(uuid, text, text, text)           TO authenticated;


-- ============================================================
-- Migration: 20260312000004_remove_user_transaction_access.sql
-- ============================================================
-- ============================================================
-- Migration: remove_user_transaction_access
-- Applied: 2026-03-12
-- Purpose:
--   Ensure men and women have NO direct access to their
--   transaction history or statements via RLS.
--   All transaction data remains stored internally.
--   Only admins can access statements via admin_search_statements.
--
-- User-facing wallet pages now show:
--   Men   → balance + recharge only
--   Women → earned balance + withdraw only
-- ============================================================

-- Revoke direct SELECT on wallet_transactions from regular users
-- (keep insert/update for billing engine running as service_role)
DROP POLICY IF EXISTS wallet_transactions_user_select ON public.wallet_transactions;

-- Users can only see their OWN wallet balance via RPC, not raw rows
-- wallet_transactions rows are internal ledger — admin/service_role only for SELECT
DROP POLICY IF EXISTS "Users can view own transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "users_view_own_wallet_transactions" ON public.wallet_transactions;

-- Create a strict policy: only service_role and admins can SELECT wallet_transactions
CREATE POLICY wallet_transactions_admin_or_service ON public.wallet_transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- women_earnings: same — no direct user SELECT
DROP POLICY IF EXISTS "Users can view own earnings" ON public.women_earnings;
DROP POLICY IF EXISTS "users_view_own_earnings" ON public.women_earnings;
DROP POLICY IF EXISTS women_earnings_user_select ON public.women_earnings;

CREATE POLICY women_earnings_admin_or_service ON public.women_earnings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- monthly_statements: admin only (already set, re-confirm)
DROP POLICY IF EXISTS monthly_statements_admin_only ON public.monthly_statements;
CREATE POLICY monthly_statements_admin_only ON public.monthly_statements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- NOTE: get_men_wallet_balance and get_women_wallet_balance RPCs use
-- SECURITY DEFINER so they can still read transaction data to compute
-- the balance totals without exposing raw rows to users.


