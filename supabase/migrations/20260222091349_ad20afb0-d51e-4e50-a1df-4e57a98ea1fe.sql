
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
