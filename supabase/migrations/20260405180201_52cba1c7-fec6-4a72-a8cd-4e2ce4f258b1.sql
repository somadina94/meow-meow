UPDATE storage.buckets 
SET allowed_mime_types = ARRAY[
  -- Images
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif',
  'image/heic', 'image/heif', 'image/bmp', 'image/tiff', 'image/svg+xml',
  'image/x-icon', 'image/vnd.microsoft.icon',
  -- Videos
  'video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo',
  'video/x-matroska', 'video/3gpp', 'video/x-flv',
  -- Audio
  'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4', 'audio/webm',
  'audio/x-m4a', 'audio/flac', 'audio/aac', 'audio/x-wav',
  -- PDF
  'application/pdf',
  -- Microsoft Word
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  -- Microsoft Excel
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  -- Microsoft PowerPoint
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  -- OpenDocument formats
  'application/vnd.oasis.opendocument.text',
  'application/vnd.oasis.opendocument.spreadsheet',
  'application/vnd.oasis.opendocument.presentation',
  -- Text / CSV / RTF
  'text/plain', 'text/csv', 'text/rtf', 'application/rtf',
  -- Archives
  'application/zip', 'application/x-rar-compressed', 'application/x-7z-compressed',
  'application/gzip',
  -- Generic binary fallback
  'application/octet-stream'
]
WHERE id = 'chat-attachments';