
INSERT INTO admin_settings (setting_key, setting_name, setting_value, setting_type, category, description)
VALUES 
  ('storage_base_path', 'Storage Base Path', 'uploads', 'string', 'storage', 'Base folder path prefix for all file uploads (KYC docs, chat files, video calls, group calls)'),
  ('kyc_storage_path', 'KYC Documents Path', 'uploads/kyc-documents', 'string', 'storage', 'Folder path for KYC document uploads'),
  ('chat_files_path', 'Chat Files Path', 'uploads/chat-files', 'string', 'storage', 'Folder path for chat file uploads (images, documents)'),
  ('video_calls_path', 'Video Calls Path', 'uploads/video-calls', 'string', 'storage', 'Folder path for video call recordings'),
  ('group_calls_path', 'Group Calls Path', 'uploads/group-calls', 'string', 'storage', 'Folder path for private group call recordings'),
  ('group_chat_files_path', 'Group Chat Files Path', 'uploads/group-chat-files', 'string', 'storage', 'Folder path for private group chat file uploads')
ON CONFLICT (setting_key) DO NOTHING;
