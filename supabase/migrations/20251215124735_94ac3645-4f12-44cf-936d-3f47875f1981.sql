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