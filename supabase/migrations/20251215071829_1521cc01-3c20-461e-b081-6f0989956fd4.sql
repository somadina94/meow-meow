-- Update existing profiles with language code 'te' to full name 'Telugu'
UPDATE profiles SET primary_language = 'Telugu', preferred_language = 'Telugu' WHERE primary_language = 'te' OR preferred_language = 'te';

-- Also update any other common short codes to full names
UPDATE profiles SET primary_language = 'Hindi', preferred_language = 'Hindi' WHERE primary_language = 'hi' OR preferred_language = 'hi';
UPDATE profiles SET primary_language = 'English', preferred_language = 'English' WHERE primary_language = 'en' OR preferred_language = 'en';
UPDATE profiles SET primary_language = 'Tamil', preferred_language = 'Tamil' WHERE primary_language = 'ta' OR preferred_language = 'ta';
UPDATE profiles SET primary_language = 'Kannada', preferred_language = 'Kannada' WHERE primary_language = 'kn' OR preferred_language = 'kn';
UPDATE profiles SET primary_language = 'Malayalam', preferred_language = 'Malayalam' WHERE primary_language = 'ml' OR preferred_language = 'ml';
UPDATE profiles SET primary_language = 'Bengali', preferred_language = 'Bengali' WHERE primary_language = 'bn' OR preferred_language = 'bn';
UPDATE profiles SET primary_language = 'Marathi', preferred_language = 'Marathi' WHERE primary_language = 'mr' OR preferred_language = 'mr';
UPDATE profiles SET primary_language = 'Gujarati', preferred_language = 'Gujarati' WHERE primary_language = 'gu' OR preferred_language = 'gu';
UPDATE profiles SET primary_language = 'Punjabi', preferred_language = 'Punjabi' WHERE primary_language = 'pa' OR preferred_language = 'pa';
UPDATE profiles SET primary_language = 'Odia', preferred_language = 'Odia' WHERE primary_language = 'or' OR preferred_language = 'or';
UPDATE profiles SET primary_language = 'Urdu', preferred_language = 'Urdu' WHERE primary_language = 'ur' OR preferred_language = 'ur';
UPDATE profiles SET primary_language = 'Arabic', preferred_language = 'Arabic' WHERE primary_language = 'ar' OR preferred_language = 'ar';
UPDATE profiles SET primary_language = 'Spanish', preferred_language = 'Spanish' WHERE primary_language = 'es' OR preferred_language = 'es';
UPDATE profiles SET primary_language = 'French', preferred_language = 'French' WHERE primary_language = 'fr' OR preferred_language = 'fr';
UPDATE profiles SET primary_language = 'Chinese', preferred_language = 'Chinese' WHERE primary_language = 'zh' OR preferred_language = 'zh';