-- Add production_mode setting to app_settings
-- Default to false (development mode) - set to true for production deployment

INSERT INTO public.app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'production_mode',
  'false',
  'boolean',
  'general',
  'When enabled, disables all mock/seed data utilities. Set to true for production deployment.',
  false
)
ON CONFLICT (setting_key) DO NOTHING;