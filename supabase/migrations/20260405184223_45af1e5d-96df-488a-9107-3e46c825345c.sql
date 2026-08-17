
ALTER TABLE public.chat_messages 
  ADD COLUMN IF NOT EXISTS deleted_for_sender boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_for_receiver boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_for_everyone boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

-- Allow sender to update deletion flags on their own messages
CREATE POLICY "Sender can delete own messages"
  ON public.chat_messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

-- Allow receiver to mark messages as deleted for themselves
CREATE POLICY "Receiver can delete messages for self"
  ON public.chat_messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);
