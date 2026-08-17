-- Create sample users configuration table
CREATE TABLE public.sample_users (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('male', 'female')),
  country TEXT NOT NULL,
  language TEXT NOT NULL,
  age INTEGER NOT NULL DEFAULT 25,
  bio TEXT,
  photo_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.sample_users ENABLE ROW LEVEL SECURITY;

-- Admins can manage sample users
CREATE POLICY "Admins can manage sample users"
ON public.sample_users
FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role));

-- Anyone can view active sample users (for matching display)
CREATE POLICY "Anyone can view active sample users"
ON public.sample_users
FOR SELECT
USING (is_active = true);

-- Create trigger for updated_at
CREATE TRIGGER update_sample_users_updated_at
BEFORE UPDATE ON public.sample_users
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Insert default sample users (3 male, 3 female per major country/language)
INSERT INTO public.sample_users (name, gender, country, language, age, bio, is_active) VALUES
-- India - Hindi
('Rahul Sharma', 'male', 'IN', 'hi', 28, 'Software engineer who loves cricket and music.', false),
('Amit Patel', 'male', 'IN', 'hi', 32, 'Business professional seeking meaningful connections.', false),
('Vikram Singh', 'male', 'IN', 'hi', 26, 'Fitness enthusiast and travel lover.', false),
('Priya Gupta', 'female', 'IN', 'hi', 25, 'Teacher who enjoys reading and cooking.', false),
('Anita Verma', 'female', 'IN', 'hi', 29, 'Marketing professional with a passion for art.', false),
('Sneha Reddy', 'female', 'IN', 'hi', 27, 'Doctor who loves dancing and movies.', false),

-- India - English
('Arjun Kumar', 'male', 'IN', 'en', 30, 'Tech entrepreneur building the future.', false),
('Karthik Nair', 'male', 'IN', 'en', 27, 'Photographer capturing life moments.', false),
('Rohan Mehta', 'male', 'IN', 'en', 31, 'Finance professional who loves hiking.', false),
('Kavya Iyer', 'female', 'IN', 'en', 26, 'Content creator and yoga instructor.', false),
('Divya Menon', 'female', 'IN', 'en', 28, 'HR professional who loves traveling.', false),
('Riya Kapoor', 'female', 'IN', 'en', 24, 'Fashion designer with creative spirit.', false),

-- USA - English
('John Smith', 'male', 'US', 'en', 29, 'Software developer and music lover.', false),
('Mike Johnson', 'male', 'US', 'en', 33, 'Marketing manager who enjoys sports.', false),
('David Williams', 'male', 'US', 'en', 28, 'Architect with passion for design.', false),
('Emily Davis', 'female', 'US', 'en', 27, 'Nurse who loves outdoor activities.', false),
('Sarah Brown', 'female', 'US', 'en', 30, 'Lawyer passionate about human rights.', false),
('Jessica Miller', 'female', 'US', 'en', 26, 'Artist and creative director.', false),

-- UK - English
('James Wilson', 'male', 'GB', 'en', 31, 'Investment banker who loves football.', false),
('Oliver Taylor', 'male', 'GB', 'en', 28, 'Chef with love for culinary arts.', false),
('Harry Anderson', 'male', 'GB', 'en', 26, 'Musician and songwriter.', false),
('Emma Thompson', 'female', 'GB', 'en', 29, 'Writer and literature enthusiast.', false),
('Sophie Clark', 'female', 'GB', 'en', 25, 'Fashion blogger and stylist.', false),
('Charlotte Lewis', 'female', 'GB', 'en', 27, 'Veterinarian who loves animals.', false);