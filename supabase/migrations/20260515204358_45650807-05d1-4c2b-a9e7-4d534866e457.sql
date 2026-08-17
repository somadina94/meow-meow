CREATE TABLE IF NOT EXISTS public.scrolling_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message text NOT NULL,
  target_group text NOT NULL DEFAULT 'all' CHECK (target_group IN ('all','men','women')),
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scrolling_active ON public.scrolling_announcements(is_active, target_group, created_at DESC);

ALTER TABLE public.scrolling_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage scrolling announcements" ON public.scrolling_announcements;
CREATE POLICY "Admins manage scrolling announcements"
ON public.scrolling_announcements
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Authenticated users read active announcements" ON public.scrolling_announcements;
CREATE POLICY "Authenticated users read active announcements"
ON public.scrolling_announcements
FOR SELECT
TO authenticated
USING (is_active = true);

DROP TRIGGER IF EXISTS trg_scrolling_announcements_updated ON public.scrolling_announcements;
CREATE TRIGGER trg_scrolling_announcements_updated
BEFORE UPDATE ON public.scrolling_announcements
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();