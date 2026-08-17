-- DB-08: Add updated_at trigger for user_languages (column already added in prior migration)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_languages_updated_at') THEN
    CREATE TRIGGER update_user_languages_updated_at
    BEFORE UPDATE ON public.user_languages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;