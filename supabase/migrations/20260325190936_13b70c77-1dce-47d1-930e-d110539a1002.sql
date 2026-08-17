-- Fix #33: Make video call circuit breaker settings readable by authenticated users
-- These settings are is_public=false but need to be readable for the circuit breaker hook
CREATE POLICY "authenticated_read_circuit_breaker"
ON public.app_settings
FOR SELECT
TO authenticated
USING (
  setting_key IN ('video_call_circuit_breaker', 'video_calls_permanently_disabled')
);

-- Fix #30: Ensure only one active chat_pricing row can exist
CREATE UNIQUE INDEX IF NOT EXISTS chat_pricing_single_active 
ON public.chat_pricing (is_active) WHERE is_active = true;