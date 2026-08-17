
-- End stuck active video call session
UPDATE public.video_call_sessions 
SET status = 'completed', ended_at = now(), end_reason = 'cleanup'
WHERE call_id = 'call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775624407648'
AND status = 'active';

-- Also bill the past ended calls that were never billed (total_earned = 0)
-- We'll handle this via RPC call from the client
