-- Create admin_settings table for global app configuration
CREATE TABLE public.admin_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  setting_key TEXT NOT NULL UNIQUE,
  setting_name TEXT NOT NULL,
  setting_value TEXT NOT NULL,
  setting_type TEXT NOT NULL DEFAULT 'string',
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  is_sensitive BOOLEAN NOT NULL DEFAULT false,
  last_updated_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can access
CREATE POLICY "Admins can view all settings" ON public.admin_settings
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update settings" ON public.admin_settings
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert settings" ON public.admin_settings
  FOR INSERT WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete settings" ON public.admin_settings
  FOR DELETE USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index
CREATE INDEX idx_admin_settings_category ON public.admin_settings(category);
CREATE INDEX idx_admin_settings_key ON public.admin_settings(setting_key);

-- Add trigger for updated_at
CREATE TRIGGER update_admin_settings_updated_at
  BEFORE UPDATE ON public.admin_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Insert default settings
INSERT INTO public.admin_settings (setting_key, setting_name, setting_value, setting_type, category, description) VALUES
-- General Settings
('app_name', 'Application Name', 'Meow Chat', 'string', 'general', 'The name of the application'),
('app_tagline', 'App Tagline', 'Connect with people worldwide', 'string', 'general', 'Tagline shown on landing pages'),
('maintenance_mode', 'Maintenance Mode', 'false', 'boolean', 'general', 'Enable to put app in maintenance mode'),
('default_theme', 'Default Theme', 'light', 'select', 'general', 'Default theme for new users'),
('default_language', 'Default Language', 'en', 'select', 'general', 'Default language for the app'),

-- Security Settings
('require_email_verification', 'Require Email Verification', 'true', 'boolean', 'security', 'Users must verify email before accessing'),
('require_phone_verification', 'Require Phone Verification', 'false', 'boolean', 'security', 'Users must verify phone number'),
('max_login_attempts', 'Max Login Attempts', '5', 'number', 'security', 'Maximum failed login attempts before lockout'),
('session_timeout_minutes', 'Session Timeout (minutes)', '1440', 'number', 'security', 'Auto logout after inactivity'),
('enable_2fa', 'Enable Two-Factor Auth', 'false', 'boolean', 'security', 'Allow users to enable 2FA'),
('password_min_length', 'Minimum Password Length', '8', 'number', 'security', 'Minimum required password length'),

-- Chat Settings
('auto_translate_enabled', 'Auto Translation', 'true', 'boolean', 'chat', 'Enable automatic message translation'),
('max_message_length', 'Max Message Length', '2000', 'number', 'chat', 'Maximum characters per message'),
('chat_timeout_seconds', 'Chat Timeout (seconds)', '30', 'number', 'chat', 'Seconds before chat transfer'),
('enable_file_sharing', 'Enable File Sharing', 'true', 'boolean', 'chat', 'Allow file uploads in chat'),
('profanity_filter', 'Profanity Filter', 'true', 'boolean', 'chat', 'Filter inappropriate words'),

-- Payment Settings
('min_recharge_amount', 'Minimum Recharge', '100', 'number', 'payment', 'Minimum wallet recharge amount'),
('max_recharge_amount', 'Maximum Recharge', '50000', 'number', 'payment', 'Maximum wallet recharge amount'),
('min_withdrawal_amount', 'Minimum Withdrawal', '10000', 'number', 'payment', 'Minimum withdrawal amount'),
('withdrawal_processing_days', 'Withdrawal Processing Days', '3', 'number', 'payment', 'Days to process withdrawal'),
('platform_fee_percent', 'Platform Fee (%)', '20', 'number', 'payment', 'Platform commission percentage'),

-- Notification Settings
('email_notifications', 'Email Notifications', 'true', 'boolean', 'notifications', 'Send email notifications'),
('push_notifications', 'Push Notifications', 'true', 'boolean', 'notifications', 'Send push notifications'),
('marketing_emails', 'Marketing Emails', 'false', 'boolean', 'notifications', 'Send promotional emails'),

-- Analytics Settings
('track_user_activity', 'Track User Activity', 'true', 'boolean', 'analytics', 'Track user behavior for analytics'),
('enable_error_reporting', 'Error Reporting', 'true', 'boolean', 'analytics', 'Send error reports automatically'),
('analytics_retention_days', 'Analytics Retention (days)', '90', 'number', 'analytics', 'Days to retain analytics data');