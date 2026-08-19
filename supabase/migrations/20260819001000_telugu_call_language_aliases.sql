-- Recognize Telugu spellings and locale codes (te-IN, Telegu) for 1:1 calls.

CREATE OR REPLACE FUNCTION public.normalize_call_language(p_lang text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_lang IS NULL OR trim(p_lang) = '' THEN ''
    WHEN lower(trim(p_lang)) IN ('bangla', 'bn', 'bn-in', 'bn_in', 'bengali', 'বাংলা', 'bengali (india)') THEN 'bengali'
    WHEN lower(trim(p_lang)) IN ('hi', 'hi-in', 'hi_in', 'hindi', 'हिन्दी', 'हिंदी') THEN 'hindi'
    WHEN lower(trim(p_lang)) IN ('mr', 'mr-in', 'mr_in', 'marathi', 'मराठी') THEN 'marathi'
    WHEN lower(trim(p_lang)) IN ('te', 'te-in', 'te_in', 'telugu', 'telegu', 'telgu', 'తెలుగు', 'telugu (india)') THEN 'telugu'
    WHEN lower(trim(p_lang)) IN ('ta', 'ta-in', 'ta_in', 'tamil', 'தமிழ்') THEN 'tamil'
    WHEN lower(trim(p_lang)) IN ('ur', 'urdu', 'اردو') THEN 'urdu'
    WHEN lower(trim(p_lang)) IN ('gu', 'gujarati', 'ગુજરાતી') THEN 'gujarati'
    WHEN lower(trim(p_lang)) IN ('kn', 'kannada', 'ಕನ್ನಡ') THEN 'kannada'
    WHEN lower(trim(p_lang)) IN ('ml', 'malayalam', 'മലയാളം') THEN 'malayalam'
    WHEN lower(trim(p_lang)) IN ('or', 'odia', 'oriya', 'ଓଡ଼ିଆ') THEN 'odia'
    WHEN lower(trim(p_lang)) IN ('pa', 'punjabi', 'panjabi', 'ਪੰਜਾਬੀ') THEN 'punjabi'
    WHEN lower(trim(p_lang)) IN ('as', 'assamese', 'অসমীয়া') THEN 'assamese'
    WHEN lower(trim(p_lang)) IN ('mai', 'maithili', 'मैथिली') THEN 'maithili'
    WHEN lower(trim(p_lang)) IN ('sat', 'santali', 'ᱥᱟᱱᱛᱟᱲᱤ') THEN 'santali'
    WHEN lower(trim(p_lang)) IN ('ks', 'kashmiri', 'कॉशुर') THEN 'kashmiri'
    WHEN lower(trim(p_lang)) IN ('kok', 'konkani', 'कोंकणी') THEN 'konkani'
    WHEN lower(trim(p_lang)) IN ('doi', 'dogri', 'डोगरी') THEN 'dogri'
    WHEN lower(trim(p_lang)) IN ('mni', 'manipuri', 'meitei', 'meetei', 'মৈতৈলোন্') THEN 'manipuri'
    WHEN lower(trim(p_lang)) IN ('brx', 'bodo', 'बड़ो') THEN 'bodo'
    WHEN lower(trim(p_lang)) IN ('sa', 'sanskrit', 'संस्कृतम्') THEN 'sanskrit'
    WHEN lower(trim(p_lang)) IN ('ne', 'nepali', 'नेपाली') THEN 'nepali'
    WHEN lower(trim(p_lang)) IN ('sd', 'sindhi', 'سنڌي') THEN 'sindhi'
    ELSE lower(trim(p_lang))
  END;
$$;

GRANT EXECUTE ON FUNCTION public.normalize_call_language(text) TO authenticated, service_role;
