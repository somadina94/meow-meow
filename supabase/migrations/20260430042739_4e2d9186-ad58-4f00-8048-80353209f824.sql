INSERT INTO public.app_settings (setting_key, setting_value, setting_type, is_public, description)
VALUES
  ('chat_enabled', 'true'::jsonb, 'json', true, 'Global toggle: when false, hides Chats tab and blocks new chat starts on men/women dashboards. Existing chats unaffected.'),
  ('audio_call_enabled', 'true'::jsonb, 'json', true, 'Global toggle: when false, hides audio call buttons and blocks new audio calls. Active calls unaffected.'),
  ('video_call_enabled', 'true'::jsonb, 'json', true, 'Global toggle: when false, hides video call buttons and blocks new video calls. Active calls unaffected.'),
  ('private_groups_enabled', 'true'::jsonb, 'json', true, 'Global toggle: when false, hides Groups tab and blocks entering private group calls. Active group sessions unaffected.')
ON CONFLICT (setting_key) DO NOTHING;