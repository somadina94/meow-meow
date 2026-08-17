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