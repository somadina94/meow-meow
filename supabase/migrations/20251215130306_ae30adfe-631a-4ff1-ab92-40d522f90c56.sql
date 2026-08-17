-- Add officer nomination system with community agreement
CREATE TABLE IF NOT EXISTS officer_nominations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_code text NOT NULL,
  nominee_id uuid NOT NULL,
  nominated_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  approvals_count integer DEFAULT 0,
  rejections_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  resolved_at timestamp with time zone,
  UNIQUE(language_code, nominee_id, status)
);

-- Track who approved/rejected nominations
CREATE TABLE IF NOT EXISTS officer_nomination_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nomination_id uuid NOT NULL REFERENCES officer_nominations(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL,
  vote_type text NOT NULL, -- approve, reject
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(nomination_id, voter_id)
);

-- Enable RLS
ALTER TABLE officer_nominations ENABLE ROW LEVEL SECURITY;
ALTER TABLE officer_nomination_votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for officer_nominations
CREATE POLICY "Auth users can view nominations" ON officer_nominations
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Auth users can self-nominate" ON officer_nominations
  FOR INSERT WITH CHECK (auth.uid() = nominee_id AND auth.uid() = nominated_by);

CREATE POLICY "System can update nominations" ON officer_nominations
  FOR UPDATE USING (true);

-- RLS Policies for officer_nomination_votes
CREATE POLICY "Auth users can view votes" ON officer_nomination_votes
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Auth users can vote on nominations" ON officer_nomination_votes
  FOR INSERT WITH CHECK (auth.uid() = voter_id);

CREATE POLICY "Users cannot change votes" ON officer_nomination_votes
  FOR UPDATE USING (false);

CREATE POLICY "Users cannot delete votes" ON officer_nomination_votes
  FOR DELETE USING (false);