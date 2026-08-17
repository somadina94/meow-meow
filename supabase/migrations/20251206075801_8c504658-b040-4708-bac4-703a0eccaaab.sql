-- Create chat_wait_queue table to track men waiting for chat
CREATE TABLE public.chat_wait_queue (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  preferred_language TEXT NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  matched_at TIMESTAMP WITH TIME ZONE,
  wait_time_seconds INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'waiting',
  priority INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.chat_wait_queue ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view their own queue position" ON public.chat_wait_queue
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert into queue" ON public.chat_wait_queue
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own queue entry" ON public.chat_wait_queue
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all queue entries" ON public.chat_wait_queue
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for faster queries
CREATE INDEX idx_chat_wait_queue_status ON public.chat_wait_queue(status);
CREATE INDEX idx_chat_wait_queue_language ON public.chat_wait_queue(preferred_language);
CREATE INDEX idx_chat_wait_queue_joined_at ON public.chat_wait_queue(joined_at);

-- Insert comprehensive global language groups
INSERT INTO public.language_groups (name, description, languages, priority, is_active) VALUES
-- Major World Languages
('English Global', 'English speakers worldwide', ARRAY['en', 'en-US', 'en-GB', 'en-AU', 'en-CA', 'en-NZ', 'en-IE', 'en-ZA', 'en-IN'], 1, true),
('Spanish Global', 'Spanish speakers worldwide', ARRAY['es', 'es-ES', 'es-MX', 'es-AR', 'es-CO', 'es-CL', 'es-PE', 'es-VE'], 2, true),
('Mandarin Chinese', 'Mandarin Chinese speakers', ARRAY['zh', 'zh-CN', 'zh-TW', 'zh-HK', 'zh-SG'], 3, true),
('Hindi & Urdu', 'Hindi and Urdu speakers', ARRAY['hi', 'hi-IN', 'ur', 'ur-PK', 'ur-IN'], 4, true),
('Arabic Global', 'Arabic speakers worldwide', ARRAY['ar', 'ar-SA', 'ar-EG', 'ar-AE', 'ar-IQ', 'ar-MA', 'ar-DZ', 'ar-TN', 'ar-LB', 'ar-JO'], 5, true),
('Portuguese Global', 'Portuguese speakers', ARRAY['pt', 'pt-BR', 'pt-PT', 'pt-AO', 'pt-MZ'], 6, true),
('French Global', 'French speakers worldwide', ARRAY['fr', 'fr-FR', 'fr-CA', 'fr-BE', 'fr-CH', 'fr-SN', 'fr-CI', 'fr-CM'], 7, true),
('Russian & CIS', 'Russian speakers in CIS', ARRAY['ru', 'ru-RU', 'ru-UA', 'ru-KZ', 'ru-BY'], 8, true),
('Japanese', 'Japanese speakers', ARRAY['ja', 'ja-JP'], 9, true),
('German & DACH', 'German speakers', ARRAY['de', 'de-DE', 'de-AT', 'de-CH'], 10, true),

-- South Asian Languages
('Bengali', 'Bengali speakers', ARRAY['bn', 'bn-BD', 'bn-IN'], 11, true),
('Tamil', 'Tamil speakers', ARRAY['ta', 'ta-IN', 'ta-LK', 'ta-SG', 'ta-MY'], 12, true),
('Telugu', 'Telugu speakers', ARRAY['te', 'te-IN'], 13, true),
('Marathi', 'Marathi speakers', ARRAY['mr', 'mr-IN'], 14, true),
('Gujarati', 'Gujarati speakers', ARRAY['gu', 'gu-IN'], 15, true),
('Kannada', 'Kannada speakers', ARRAY['kn', 'kn-IN'], 16, true),
('Malayalam', 'Malayalam speakers', ARRAY['ml', 'ml-IN'], 17, true),
('Punjabi', 'Punjabi speakers', ARRAY['pa', 'pa-IN', 'pa-PK'], 18, true),
('Odia', 'Odia speakers', ARRAY['or', 'or-IN'], 19, true),
('Nepali', 'Nepali speakers', ARRAY['ne', 'ne-NP', 'ne-IN'], 20, true),
('Sinhala', 'Sinhala speakers', ARRAY['si', 'si-LK'], 21, true),

-- Southeast Asian Languages
('Indonesian & Malay', 'Indonesian/Malay speakers', ARRAY['id', 'id-ID', 'ms', 'ms-MY', 'ms-SG', 'ms-BN'], 22, true),
('Vietnamese', 'Vietnamese speakers', ARRAY['vi', 'vi-VN'], 23, true),
('Thai', 'Thai speakers', ARRAY['th', 'th-TH'], 24, true),
('Filipino & Tagalog', 'Filipino speakers', ARRAY['tl', 'fil', 'fil-PH'], 25, true),
('Korean', 'Korean speakers', ARRAY['ko', 'ko-KR', 'ko-KP'], 26, true),
('Burmese', 'Burmese speakers', ARRAY['my', 'my-MM'], 27, true),
('Khmer', 'Khmer speakers', ARRAY['km', 'km-KH'], 28, true),
('Lao', 'Lao speakers', ARRAY['lo', 'lo-LA'], 29, true),

-- European Languages
('Italian', 'Italian speakers', ARRAY['it', 'it-IT', 'it-CH'], 30, true),
('Dutch & Flemish', 'Dutch speakers', ARRAY['nl', 'nl-NL', 'nl-BE'], 31, true),
('Polish', 'Polish speakers', ARRAY['pl', 'pl-PL'], 32, true),
('Ukrainian', 'Ukrainian speakers', ARRAY['uk', 'uk-UA'], 33, true),
('Romanian', 'Romanian speakers', ARRAY['ro', 'ro-RO', 'ro-MD'], 34, true),
('Greek', 'Greek speakers', ARRAY['el', 'el-GR', 'el-CY'], 35, true),
('Czech & Slovak', 'Czech/Slovak speakers', ARRAY['cs', 'cs-CZ', 'sk', 'sk-SK'], 36, true),
('Hungarian', 'Hungarian speakers', ARRAY['hu', 'hu-HU'], 37, true),
('Swedish', 'Swedish speakers', ARRAY['sv', 'sv-SE', 'sv-FI'], 38, true),
('Norwegian & Danish', 'Scandinavian speakers', ARRAY['no', 'nb', 'nn', 'da', 'da-DK'], 39, true),
('Finnish', 'Finnish speakers', ARRAY['fi', 'fi-FI'], 40, true),
('Bulgarian', 'Bulgarian speakers', ARRAY['bg', 'bg-BG'], 41, true),
('Serbian & Croatian', 'Serbo-Croatian speakers', ARRAY['sr', 'hr', 'bs', 'sr-RS', 'hr-HR', 'bs-BA'], 42, true),

-- Middle Eastern & Central Asian
('Turkish', 'Turkish speakers', ARRAY['tr', 'tr-TR'], 43, true),
('Persian & Dari', 'Persian speakers', ARRAY['fa', 'fa-IR', 'fa-AF', 'prs'], 44, true),
('Hebrew', 'Hebrew speakers', ARRAY['he', 'he-IL', 'iw'], 45, true),
('Kurdish', 'Kurdish speakers', ARRAY['ku', 'ckb', 'kmr'], 46, true),
('Kazakh & Uzbek', 'Central Asian Turkic', ARRAY['kk', 'kk-KZ', 'uz', 'uz-UZ'], 47, true),
('Pashto', 'Pashto speakers', ARRAY['ps', 'ps-AF', 'ps-PK'], 48, true),
('Azerbaijani', 'Azerbaijani speakers', ARRAY['az', 'az-AZ'], 49, true),

-- African Languages
('Swahili', 'Swahili speakers', ARRAY['sw', 'sw-KE', 'sw-TZ'], 50, true),
('Hausa', 'Hausa speakers', ARRAY['ha', 'ha-NG', 'ha-NE'], 51, true),
('Yoruba', 'Yoruba speakers', ARRAY['yo', 'yo-NG'], 52, true),
('Igbo', 'Igbo speakers', ARRAY['ig', 'ig-NG'], 53, true),
('Amharic', 'Amharic speakers', ARRAY['am', 'am-ET'], 54, true),
('Zulu & Xhosa', 'South African Bantu', ARRAY['zu', 'xh', 'zu-ZA', 'xh-ZA'], 55, true),
('Somali', 'Somali speakers', ARRAY['so', 'so-SO', 'so-ET', 'so-KE'], 56, true);

-- Add trigger for updated_at
CREATE TRIGGER update_chat_wait_queue_updated_at
  BEFORE UPDATE ON public.chat_wait_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();