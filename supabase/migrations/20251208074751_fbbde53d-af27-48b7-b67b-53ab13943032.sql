-- Insert chat and billing control settings
INSERT INTO admin_settings (setting_key, setting_name, setting_value, setting_type, category, description)
VALUES 
  -- Chat Pricing & Billing Settings
  ('chat_rate_per_minute', 'Chat Rate (₹/min)', '5', 'number', 'payment', 'Price charged to men per minute of chat'),
  ('women_earning_rate', 'Women Earning Rate (₹/min)', '2', 'number', 'payment', 'Amount women earn per minute of chat'),
  ('women_earning_percentage', 'Women Earning Percentage', '40', 'number', 'payment', 'Percentage of chat fee that goes to women (alternative to fixed rate)'),
  ('min_wallet_balance', 'Minimum Wallet Balance (₹)', '10', 'number', 'payment', 'Minimum wallet balance required to start a chat'),
  
  -- Connection & Session Settings  
  ('auto_disconnect_timer', 'Auto-Disconnect Timer (seconds)', '180', 'number', 'chat', 'Seconds of inactivity before auto-disconnect (default: 180 = 3 min)'),
  ('max_parallel_connections', 'Max Parallel Connections', '3', 'number', 'chat', 'Maximum number of simultaneous chat sessions per user'),
  ('reconnect_attempts', 'Auto-Reconnect Attempts', '3', 'number', 'chat', 'Number of times to attempt auto-reconnect when partner disconnects'),
  ('heartbeat_interval', 'Heartbeat Interval (seconds)', '60', 'number', 'chat', 'Seconds between billing heartbeats'),
  
  -- Data Retention Settings
  ('content_deletion_minutes', 'Content Deletion (minutes)', '15', 'number', 'security', 'Minutes after which chat content is deleted'),
  ('chat_history_retention_days', 'Chat History Retention (days)', '7', 'number', 'security', 'Days to retain chat history before deletion'),
  ('transaction_retention_years', 'Transaction Retention (years)', '7', 'number', 'security', 'Years to retain transaction records'),
  ('inactive_profile_days', 'Inactive Profile Warning (days)', '90', 'number', 'security', 'Days of inactivity before profile is flagged'),
  
  -- Queue Settings
  ('priority_wait_threshold', 'Priority Wait Threshold (seconds)', '180', 'number', 'chat', 'Seconds in queue before user gets priority matching'),
  ('queue_timeout_seconds', 'Queue Timeout (seconds)', '300', 'number', 'chat', 'Maximum seconds a user can wait in queue')
  
ON CONFLICT (setting_key) DO UPDATE SET
  setting_name = EXCLUDED.setting_name,
  description = EXCLUDED.description,
  setting_type = EXCLUDED.setting_type,
  category = EXCLUDED.category;