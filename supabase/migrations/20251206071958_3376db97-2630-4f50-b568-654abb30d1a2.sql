-- Add moderation columns to chat_messages table
ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS flagged BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS flagged_by UUID,
ADD COLUMN IF NOT EXISTS flagged_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS flag_reason TEXT,
ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'pending';

-- Create index for moderation queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_flagged ON public.chat_messages(flagged);
CREATE INDEX IF NOT EXISTS idx_chat_messages_moderation_status ON public.chat_messages(moderation_status);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- Allow admins to view all chat messages for moderation
CREATE POLICY "Admins can view all messages for moderation"
ON public.chat_messages
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Allow admins to update message moderation status
CREATE POLICY "Admins can update message moderation"
ON public.chat_messages
FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role));