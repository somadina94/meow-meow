INSERT INTO public.app_settings (setting_key, setting_value, setting_type, is_public, description)
VALUES ('statements_tab_visible', 'false'::jsonb, 'json', true, 'Controls visibility of Statements tab in user wallet screens (men & women). Hidden by default.')
ON CONFLICT (setting_key) DO NOTHING;