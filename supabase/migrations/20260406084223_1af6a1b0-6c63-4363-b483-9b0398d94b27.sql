-- MIGRATE-01: Fix existing broken voice message paths in chat_messages
-- Voice messages stored with double bucket prefix 'chat-attachments/' need to be corrected
UPDATE chat_messages
SET message = REPLACE(message, '🎤voice:chat-attachments/', '🎤voice:')
WHERE message LIKE '🎤voice:chat-attachments/%';