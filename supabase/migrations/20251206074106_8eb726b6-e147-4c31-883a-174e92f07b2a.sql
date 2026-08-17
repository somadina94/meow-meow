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