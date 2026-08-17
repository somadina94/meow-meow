-- Add file sharing columns to group_messages table
ALTER TABLE public.group_messages 
ADD COLUMN IF NOT EXISTS file_url TEXT,
ADD COLUMN IF NOT EXISTS file_type TEXT,
ADD COLUMN IF NOT EXISTS file_name TEXT,
ADD COLUMN IF NOT EXISTS file_size INTEGER;

-- Create language_community_groups table for better language-based group management
CREATE TABLE IF NOT EXISTS public.language_community_groups (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    language_code TEXT NOT NULL UNIQUE,
    language_name TEXT NOT NULL,
    member_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create language_community_members table
CREATE TABLE IF NOT EXISTS public.language_community_members (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES public.language_community_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(group_id, user_id)
);

-- Create language_community_messages table for language-based group chat
CREATE TABLE IF NOT EXISTS public.language_community_messages (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    language_code TEXT NOT NULL,
    sender_id UUID NOT NULL,
    message TEXT,
    file_url TEXT,
    file_type TEXT,
    file_name TEXT,
    file_size INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.language_community_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_community_messages ENABLE ROW LEVEL SECURITY;

-- RLS policies for language_community_groups
CREATE POLICY "Language groups are viewable by authenticated users"
ON public.language_community_groups FOR SELECT
USING (auth.role() = 'authenticated');

-- RLS policies for language_community_members
CREATE POLICY "Members can view their community members"
ON public.language_community_members FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Users can join language communities"
ON public.language_community_members FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- RLS policies for language_community_messages
CREATE POLICY "Authenticated users can read community messages"
ON public.language_community_messages FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can send community messages"
ON public.language_community_messages FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Create storage bucket for community files
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('community-files', 'community-files', true, 52428800)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for community files
CREATE POLICY "Authenticated users can upload community files"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'community-files' AND auth.role() = 'authenticated');

CREATE POLICY "Anyone can view community files"
ON storage.objects FOR SELECT
USING (bucket_id = 'community-files');

-- Enable realtime for community messages
ALTER PUBLICATION supabase_realtime ADD TABLE language_community_messages;

-- Create index for faster message queries
CREATE INDEX IF NOT EXISTS idx_language_community_messages_language 
ON public.language_community_messages(language_code, created_at DESC);