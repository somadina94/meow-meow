UPDATE storage.buckets 
SET allowed_mime_types = ARRAY[
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif',
  'image/heic', 'image/heif', 'image/bmp', 'image/tiff', 'image/svg+xml',
  'image/x-icon', 'image/vnd.microsoft.icon',
  'video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo',
  'video/x-matroska', 'video/3gpp', 'video/x-flv',
  'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4', 'audio/webm',
  'audio/x-m4a', 'audio/flac', 'audio/aac', 'audio/x-wav',
  'application/pdf', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.oasis.opendocument.text',
  'application/vnd.oasis.opendocument.spreadsheet',
  'application/vnd.oasis.opendocument.presentation',
  'text/plain', 'text/csv', 'text/rtf', 'application/rtf',
  'application/zip', 'application/x-rar-compressed', 'application/x-7z-compressed',
  'application/gzip', 'application/octet-stream'
]
WHERE id = 'chat-files';