-- Enforce 80-women per Indian language cap, seed all 22 official Indian languages

-- 1) Seed/upsert all 22 official Indian languages with cap = 80, deactivate the rest
WITH indian_langs(name) AS (
  VALUES
    ('Hindi'),('Bengali'),('Telugu'),('Marathi'),('Tamil'),('Urdu'),
    ('Gujarati'),('Kannada'),('Odia'),('Malayalam'),('Punjabi'),('Assamese'),
    ('Maithili'),('Santali'),('Kashmiri'),('Nepali'),('Konkani'),('Sindhi'),
    ('Dogri'),('Manipuri'),('Bodo'),('Sanskrit'),('English')
)
INSERT INTO public.language_limits (language_name, max_chat_women, max_call_women, max_earning_women, is_active)
SELECT name, 80, 80, 80, true FROM indian_langs
ON CONFLICT (language_name) DO UPDATE
SET max_chat_women = 80,
    max_call_women = 80,
    max_earning_women = 80,
    is_active = true,
    updated_at = now();

-- Deactivate any non-Indian languages (keep rows for history)
UPDATE public.language_limits
SET is_active = false, updated_at = now()
WHERE language_name NOT IN (
  'Hindi','Bengali','Telugu','Marathi','Tamil','Urdu','Gujarati','Kannada',
  'Odia','Malayalam','Punjabi','Assamese','Maithili','Santali','Kashmiri',
  'Nepali','Konkani','Sindhi','Dogri','Manipuri','Bodo','Sanskrit','English'
);

-- Add unique index on language_name if not present (needed for ON CONFLICT)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname='public' AND tablename='language_limits' AND indexname='language_limits_language_name_key'
  ) THEN
    BEGIN
      ALTER TABLE public.language_limits ADD CONSTRAINT language_limits_language_name_key UNIQUE (language_name);
    EXCEPTION WHEN duplicate_table THEN NULL;
    END;
  END IF;
END $$;

-- 2) Enforcement trigger: block women profile insert/update when language cap reached
CREATE OR REPLACE FUNCTION public.enforce_women_language_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lang TEXT;
  v_max INT;
  v_current INT;
BEGIN
  -- Only enforce for women
  IF NEW.gender IS DISTINCT FROM 'female' THEN
    RETURN NEW;
  END IF;

  v_lang := COALESCE(NEW.primary_language, NEW.language, NEW.preferred_language);
  IF v_lang IS NULL OR v_lang = '' THEN
    RETURN NEW;
  END IF;

  SELECT max_chat_women INTO v_max
  FROM public.language_limits
  WHERE lower(language_name) = lower(v_lang) AND is_active = true
  LIMIT 1;

  -- If language not in the active Indian list, reject
  IF v_max IS NULL THEN
    RAISE EXCEPTION 'Language "%" is not supported. Only the 22 official Indian languages are accepted.', v_lang
      USING ERRCODE = 'check_violation';
  END IF;

  -- Count existing approved/active women in this language (excluding this row on UPDATE)
  SELECT COUNT(*) INTO v_current
  FROM public.profiles
  WHERE gender = 'female'
    AND lower(COALESCE(primary_language, language, preferred_language)) = lower(v_lang)
    AND COALESCE(account_status, 'active') <> 'deleted'
    AND (TG_OP = 'INSERT' OR user_id <> NEW.user_id);

  IF v_current >= v_max THEN
    RAISE EXCEPTION 'Registration limit reached for %: maximum % women allowed per language.', v_lang, v_max
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_women_language_cap ON public.profiles;
CREATE TRIGGER trg_enforce_women_language_cap
BEFORE INSERT OR UPDATE OF primary_language, language, preferred_language, gender
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.enforce_women_language_cap();