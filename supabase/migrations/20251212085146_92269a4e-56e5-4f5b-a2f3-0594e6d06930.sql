-- Create private_groups table for women to create private rooms
CREATE TABLE public.private_groups (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  min_gift_amount NUMERIC NOT NULL DEFAULT 100,
  access_type TEXT NOT NULL DEFAULT 'both' CHECK (access_type IN ('chat', 'video', 'both')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_live BOOLEAN NOT NULL DEFAULT false,
  stream_id TEXT,
  participant_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create group_memberships table to track who has access
CREATE TABLE public.group_memberships (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  gift_amount_paid NUMERIC NOT NULL DEFAULT 0,
  has_access BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- Create group_messages table for group chat
CREATE TABLE public.group_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  message TEXT NOT NULL,
  is_translated BOOLEAN DEFAULT false,
  translated_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.private_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for private_groups
CREATE POLICY "Anyone can view active groups" ON public.private_groups
  FOR SELECT USING (is_active = true);

CREATE POLICY "Women can create groups" ON public.private_groups
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update their groups" ON public.private_groups
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Owners can delete their groups" ON public.private_groups
  FOR DELETE USING (auth.uid() = owner_id);

-- RLS Policies for group_memberships
CREATE POLICY "Users can view their memberships" ON public.group_memberships
  FOR SELECT USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM public.private_groups WHERE id = group_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Users can join groups" ON public.group_memberships
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can update memberships" ON public.group_memberships
  FOR UPDATE USING (true);

-- RLS Policies for group_messages
CREATE POLICY "Members can view group messages" ON public.group_messages
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.group_memberships WHERE group_id = group_messages.group_id AND user_id = auth.uid() AND has_access = true)
    OR EXISTS (SELECT 1 FROM public.private_groups WHERE id = group_messages.group_id AND owner_id = auth.uid())
  );

CREATE POLICY "Members can send messages" ON public.group_messages
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.group_memberships WHERE group_id = group_messages.group_id AND user_id = auth.uid() AND has_access = true)
    OR EXISTS (SELECT 1 FROM public.private_groups WHERE id = group_messages.group_id AND owner_id = auth.uid())
  );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.private_groups;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_memberships;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;

-- Create function to process group gift and grant access
CREATE OR REPLACE FUNCTION public.process_group_gift(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_is_super_user BOOLEAN;
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Check if gift meets minimum requirement
  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift does not meet minimum requirement of ' || v_group.min_gift_amount);
  END IF;

  -- Check if super user
  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Check balance
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate 50/50 split
  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit wallet
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group access gift: ' || v_gift.name, 'completed');

  -- Credit woman's earnings (50%)
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_group.owner_id, v_women_share, 'gift', 'Group access gift (50% share): ' || v_gift.name);

  -- Create gift transaction
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_group.owner_id, p_gift_id, v_gift.price, v_gift.currency, 'Group access gift', 'completed');

  -- Grant access to group
  INSERT INTO public.group_memberships (group_id, user_id, gift_amount_paid, has_access)
  VALUES (p_group_id, p_sender_id, v_gift.price, true)
  ON CONFLICT (group_id, user_id) DO UPDATE SET has_access = true, gift_amount_paid = EXCLUDED.gift_amount_paid;

  -- Update participant count
  UPDATE public.private_groups SET participant_count = participant_count + 1 WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance
  );
END;
$$;