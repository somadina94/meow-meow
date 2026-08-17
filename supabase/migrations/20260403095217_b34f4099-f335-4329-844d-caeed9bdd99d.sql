
-- Translation cache to avoid repeated Lingva API calls
CREATE TABLE public.translation_cache (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  source_lang TEXT NOT NULL,
  target_lang TEXT NOT NULL,
  source_text TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  hit_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT unique_translation UNIQUE (source_lang, target_lang, source_text)
);

-- Index for fast cache lookups
CREATE INDEX idx_translation_cache_lookup 
ON public.translation_cache (source_lang, target_lang, source_text);

-- Enable RLS
ALTER TABLE public.translation_cache ENABLE ROW LEVEL SECURITY;

-- Anyone can read cached translations
CREATE POLICY "Anyone can read translation cache"
ON public.translation_cache
FOR SELECT
USING (true);

-- Authenticated users can insert cache entries
CREATE POLICY "Authenticated users can insert translations"
ON public.translation_cache
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow updating hit_count
CREATE POLICY "Authenticated users can update cache hits"
ON public.translation_cache
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Auto-update timestamp trigger
CREATE TRIGGER update_translation_cache_updated_at
BEFORE UPDATE ON public.translation_cache
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
