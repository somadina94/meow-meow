-- Create function to increment vote count atomically
CREATE OR REPLACE FUNCTION public.increment_vote_count(candidate_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE election_candidates
  SET vote_count = COALESCE(vote_count, 0) + 1
  WHERE id = candidate_uuid;
END;
$$;