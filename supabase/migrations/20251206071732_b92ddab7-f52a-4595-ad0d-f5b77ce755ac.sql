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