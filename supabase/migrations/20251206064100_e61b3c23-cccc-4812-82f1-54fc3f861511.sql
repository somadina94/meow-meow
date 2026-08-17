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