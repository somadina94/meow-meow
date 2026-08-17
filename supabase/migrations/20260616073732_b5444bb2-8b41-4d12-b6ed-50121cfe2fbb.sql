
ALTER TABLE public.group_chat_messages
  ADD COLUMN IF NOT EXISTS original_lang text,
  ADD COLUMN IF NOT EXISTS transliteration text,
  ADD COLUMN IF NOT EXISTS english_translation text,
  ADD COLUMN IF NOT EXISTS voice_duration_seconds int,
  ADD COLUMN IF NOT EXISTS media_thumbnail text;
