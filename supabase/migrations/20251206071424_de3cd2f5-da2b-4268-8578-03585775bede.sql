-- Create gifts table for virtual gift pricing
CREATE TABLE public.gifts (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  emoji text NOT NULL DEFAULT '🎁',
  price numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'INR',
  category text NOT NULL DEFAULT 'general',
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;

-- Everyone can view active gifts
CREATE POLICY "Anyone can view active gifts"
ON public.gifts
FOR SELECT
USING (is_active = true);

-- Admins can manage all gifts
CREATE POLICY "Admins can manage gifts"
ON public.gifts
FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- Create gift_transactions table to track gift purchases
CREATE TABLE public.gift_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  gift_id uuid NOT NULL REFERENCES public.gifts(id),
  sender_id uuid NOT NULL,
  receiver_id uuid NOT NULL,
  price_paid numeric NOT NULL,
  currency text NOT NULL DEFAULT 'INR',
  message text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.gift_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view their gift transactions"
ON public.gift_transactions
FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send gifts
CREATE POLICY "Users can send gifts"
ON public.gift_transactions
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Admins can view all transactions
CREATE POLICY "Admins can view all gift transactions"
ON public.gift_transactions
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

-- Insert some default gifts
INSERT INTO public.gifts (name, description, emoji, price, category, sort_order) VALUES
('Rose', 'A beautiful red rose', '🌹', 50, 'flowers', 1),
('Heart', 'Show your love', '❤️', 100, 'love', 2),
('Chocolate', 'Sweet treat', '🍫', 75, 'food', 3),
('Diamond Ring', 'Precious gift', '💍', 500, 'luxury', 4),
('Teddy Bear', 'Cuddly companion', '🧸', 150, 'toys', 5),
('Champagne', 'Celebrate together', '🍾', 300, 'drinks', 6),
('Star', 'You are a star', '⭐', 25, 'general', 7),
('Kiss', 'Virtual kiss', '💋', 80, 'love', 8),
('Crown', 'Royal treatment', '👑', 400, 'luxury', 9),
('Flower Bouquet', 'Beautiful flowers', '💐', 200, 'flowers', 10);

-- Create indexes
CREATE INDEX idx_gifts_category ON public.gifts(category);
CREATE INDEX idx_gifts_is_active ON public.gifts(is_active);
CREATE INDEX idx_gift_transactions_sender ON public.gift_transactions(sender_id);
CREATE INDEX idx_gift_transactions_receiver ON public.gift_transactions(receiver_id);