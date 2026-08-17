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