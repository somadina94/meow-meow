UPDATE app_settings 
SET setting_value = '[100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 2000, 3000, 5000, 10000]'::jsonb,
    updated_at = now()
WHERE setting_key = 'recharge_amounts';