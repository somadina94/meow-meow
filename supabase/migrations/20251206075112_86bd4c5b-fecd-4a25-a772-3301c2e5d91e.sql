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