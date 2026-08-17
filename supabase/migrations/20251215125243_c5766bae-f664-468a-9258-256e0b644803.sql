-- Create community_elections table for annual elections
CREATE TABLE public.community_elections (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  election_year INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  election_officer_id UUID NOT NULL,
  winner_id UUID,
  scheduled_at TIMESTAMP WITH TIME ZONE,
  started_at TIMESTAMP WITH TIME ZONE,
  ended_at TIMESTAMP WITH TIME ZONE,
  total_votes INTEGER DEFAULT 0,
  election_results JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(language_code, election_year)
);

-- Create election_candidates table
CREATE TABLE public.election_candidates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  nomination_status TEXT NOT NULL DEFAULT 'pending',
  platform_statement TEXT,
  vote_count INTEGER DEFAULT 0,
  nominated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, user_id)
);

-- Create election_votes table with one vote per user per election
CREATE TABLE public.election_votes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  voter_id UUID NOT NULL,
  candidate_id UUID NOT NULL REFERENCES public.election_candidates(id) ON DELETE CASCADE,
  is_tiebreaker BOOLEAN DEFAULT false,
  voted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, voter_id)
);

-- Create voter_registry table for eligible voters
CREATE TABLE public.voter_registry (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  election_id UUID NOT NULL REFERENCES public.community_elections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  registered_by UUID NOT NULL,
  is_eligible BOOLEAN DEFAULT true,
  registered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(election_id, user_id)
);

-- Create community_leaders table for tracking elected leaders
CREATE TABLE public.community_leaders (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  user_id UUID NOT NULL,
  election_id UUID REFERENCES public.community_elections(id),
  term_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  term_end TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create election_officers table
CREATE TABLE public.election_officers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_code TEXT NOT NULL,
  user_id UUID NOT NULL,
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  auto_assigned BOOLEAN DEFAULT false,
  UNIQUE(language_code, user_id)
);

-- Enable RLS
ALTER TABLE public.community_elections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voter_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.election_officers ENABLE ROW LEVEL SECURITY;

-- RLS Policies for community_elections
CREATE POLICY "Members can view elections" 
ON public.community_elections FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can create elections" 
ON public.community_elections FOR INSERT 
WITH CHECK (auth.uid() = election_officer_id);

CREATE POLICY "Officers can update elections" 
ON public.community_elections FOR UPDATE 
USING (auth.uid() = election_officer_id);

-- RLS Policies for election_candidates
CREATE POLICY "Members can view candidates" 
ON public.election_candidates FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can manage candidates" 
ON public.election_candidates FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = election_candidates.election_id 
    AND e.election_officer_id = auth.uid()
  )
);

-- RLS Policies for election_votes
CREATE POLICY "Users can view own votes" 
ON public.election_votes FOR SELECT 
USING (auth.uid() = voter_id);

CREATE POLICY "Officers can view all votes after election" 
ON public.election_votes FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = election_votes.election_id 
    AND e.status = 'completed'
  )
);

CREATE POLICY "Registered voters can vote" 
ON public.election_votes FOR INSERT 
WITH CHECK (
  auth.uid() = voter_id AND
  EXISTS (
    SELECT 1 FROM voter_registry vr 
    WHERE vr.election_id = election_votes.election_id 
    AND vr.user_id = auth.uid() 
    AND vr.is_eligible = true
  )
);

-- RLS Policies for voter_registry
CREATE POLICY "Members can view voter registry" 
ON public.voter_registry FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Officers can manage voter registry" 
ON public.voter_registry FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM community_elections e 
    WHERE e.id = voter_registry.election_id 
    AND e.election_officer_id = auth.uid()
  )
);

-- RLS Policies for community_leaders
CREATE POLICY "Anyone can view leaders" 
ON public.community_leaders FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "System can manage leaders" 
ON public.community_leaders FOR ALL 
USING (true);

-- RLS Policies for election_officers
CREATE POLICY "Anyone can view officers" 
ON public.election_officers FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "System can manage officers" 
ON public.election_officers FOR ALL 
USING (true);

-- Create indexes for performance
CREATE INDEX idx_elections_language_year ON public.community_elections(language_code, election_year);
CREATE INDEX idx_elections_status ON public.community_elections(status);
CREATE INDEX idx_candidates_election ON public.election_candidates(election_id);
CREATE INDEX idx_votes_election ON public.election_votes(election_id);
CREATE INDEX idx_votes_candidate ON public.election_votes(candidate_id);
CREATE INDEX idx_voter_registry_election ON public.voter_registry(election_id);
CREATE INDEX idx_leaders_language ON public.community_leaders(language_code);
CREATE INDEX idx_officers_language ON public.election_officers(language_code);

-- Function to count and update vote counts
CREATE OR REPLACE FUNCTION public.update_candidate_vote_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.election_candidates
  SET vote_count = (
    SELECT COUNT(*) FROM public.election_votes 
    WHERE candidate_id = NEW.candidate_id
  )
  WHERE id = NEW.candidate_id;
  
  UPDATE public.community_elections
  SET total_votes = (
    SELECT COUNT(*) FROM public.election_votes 
    WHERE election_id = NEW.election_id
  ),
  updated_at = now()
  WHERE id = NEW.election_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to update vote counts when votes are cast
CREATE TRIGGER update_vote_counts_trigger
AFTER INSERT ON public.election_votes
FOR EACH ROW
EXECUTE FUNCTION public.update_candidate_vote_count();