-- Create table for idioms/phrases database
CREATE TABLE public.translation_idioms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  phrase TEXT NOT NULL UNIQUE,
  normalized_phrase TEXT NOT NULL,
  meaning TEXT NOT NULL,
  translations JSONB NOT NULL DEFAULT '{}',
  category TEXT NOT NULL DEFAULT 'idiom',
  register TEXT NOT NULL DEFAULT 'neutral',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create table for language grammar rules
CREATE TABLE public.translation_grammar_rules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL UNIQUE,
  language_name TEXT NOT NULL,
  word_order TEXT NOT NULL DEFAULT 'SVO',
  has_gender BOOLEAN NOT NULL DEFAULT false,
  has_articles BOOLEAN NOT NULL DEFAULT false,
  adjective_position TEXT NOT NULL DEFAULT 'before',
  uses_postpositions BOOLEAN NOT NULL DEFAULT false,
  subject_dropping BOOLEAN NOT NULL DEFAULT false,
  has_cases BOOLEAN NOT NULL DEFAULT false,
  has_honorific BOOLEAN NOT NULL DEFAULT false,
  sentence_end_particle TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create table for word sense disambiguation
CREATE TABLE public.translation_word_senses (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  word TEXT NOT NULL,
  sense_id TEXT NOT NULL,
  meaning TEXT NOT NULL,
  context_clues TEXT[] NOT NULL DEFAULT '{}',
  translations JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(word, sense_id)
);

-- Create table for morphology rules
CREATE TABLE public.translation_morphology_rules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  rule_type TEXT NOT NULL,
  pattern TEXT NOT NULL,
  replacement TEXT NOT NULL,
  conditions JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(language_code, rule_type, pattern)
);

-- Enable RLS
ALTER TABLE public.translation_idioms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_grammar_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_word_senses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translation_morphology_rules ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (translation data is public)
CREATE POLICY "Translation idioms are publicly readable" ON public.translation_idioms FOR SELECT USING (true);
CREATE POLICY "Translation grammar rules are publicly readable" ON public.translation_grammar_rules FOR SELECT USING (true);
CREATE POLICY "Translation word senses are publicly readable" ON public.translation_word_senses FOR SELECT USING (true);
CREATE POLICY "Translation morphology rules are publicly readable" ON public.translation_morphology_rules FOR SELECT USING (true);

-- Create indexes for fast lookups
CREATE INDEX idx_translation_idioms_phrase ON public.translation_idioms(normalized_phrase);
CREATE INDEX idx_translation_grammar_rules_code ON public.translation_grammar_rules(language_code);
CREATE INDEX idx_translation_word_senses_word ON public.translation_word_senses(word);
CREATE INDEX idx_translation_morphology_rules_lang ON public.translation_morphology_rules(language_code);

-- Create update timestamp triggers
CREATE TRIGGER update_translation_idioms_updated_at
BEFORE UPDATE ON public.translation_idioms
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_translation_grammar_rules_updated_at
BEFORE UPDATE ON public.translation_grammar_rules
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_translation_word_senses_updated_at
BEFORE UPDATE ON public.translation_word_senses
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();