-- Voice/attachment paths include timestamps (e.g. voice_1723891234567.webm)
-- which the phone-number check treated as contact sharing and blocked inserts.
-- Skip moderation for storage markers so 1:1 voice and files can send.

CREATE OR REPLACE FUNCTION public.validate_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  msg TEXT;
  lower_msg TEXT;
BEGIN
  msg := NEW.message;
  IF msg IS NULL OR length(trim(msg)) = 0 THEN
    RETURN NEW;
  END IF;

  -- Media / voice / attachment markers are not user-typed contact info
  IF msg ~* '\[VOICE:'
     OR msg ~* '\[attachment:'
     OR msg ~* '\[IMAGE:'
     OR msg ~* '\[VIDEO:'
     OR msg ~* '\[DOCUMENT:'
     OR msg ~* 'chat-attachment://'
     OR msg ~* '^🎤'
  THEN
    RETURN NEW;
  END IF;

  lower_msg := lower(msg);

  -- 1. Sexual/explicit content (English + transliterated Indian languages)
  IF lower_msg ~* '\m(sex|nude[s]?|naked|porn|xxx|nsfw|erotic|orgasm|masturbat|blowjob|handjob|threesome|gangbang|fetish|bondage|bdsm|strip\s*tease|one\s*night\s*stand|hookup|hook\s*up|booty\s*call|slutt?y?|whor[e]?)\M'
    OR lower_msg ~* '\m(send\s*(me\s*)?(nudes?|pics?|photos?|body\s*pics?))\M'
    OR lower_msg ~* '\m(show\s*(me\s*)?(your\s*)?(body|boobs?|tits?|ass|butt|privates?))\M'
    OR lower_msg ~* '\m(let''?s?\s*(have\s*)?sex|wanna\s*(f[*]?ck|bang|smash|screw))\M'
    OR lower_msg ~* '\m(horny|turned\s*on|get\s*laid|make\s*love|sleep\s*with\s*me)\M'
    OR lower_msg ~* '\m(chod|chud|lund|gaand|bhosdi|randi|chut|maderchod|behenchod|chudai)\M'
    OR lower_msg ~* '\m(otha|thevdiya|pundai|sunni|oombu|koothi)\M'
    OR lower_msg ~* '\m(dengey|modda|gudda|lanja|pooku|sulli)\M'
    OR msg ~ '(चोद|चूत|लंड|गांड|भोसडी|रंडी|चुदाई|मादरचोद|बहनचोद)'
    OR msg ~ '(ஓத்தா|தேவடியா|புண்டை|சுன்னி|ஊம்பு|கூதி)'
    OR msg ~ '(దెంగేయ్|మొడ్డ|గుద్ద|లంజ|పూకు|సుల్లి)'
    OR msg ~ '[操肏屌屄婊鸡巴逼骚淫荡]'
    OR msg ~ '(씨발|존나|보지|자지|씹|좆)'
  THEN
    RAISE EXCEPTION 'Message blocked: sexual or explicit content is prohibited.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 2. Harmful/threatening content
  IF lower_msg ~* '\m(i(''?ll| will)\s*(kill|murder|hurt|harm|stab|shoot|beat|destroy|rape)\s*(you|him|her|them|myself|yourself))\M'
    OR lower_msg ~* '\m(kill\s*(yourself|urself|u)|go\s*die|hope\s*you\s*die)\M'
    OR lower_msg ~* '\m(death\s*threat|bomb\s*threat)\M'
    OR lower_msg ~* '\m(kys|k\.y\.s|kill\s*your\s*self)\M'
  THEN
    RAISE EXCEPTION 'Message blocked: threatening or harmful content is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 3. Phone numbers (7+ consecutive digits, or digits with separators)
  IF msg ~ '\d{7,15}'
    OR msg ~ '\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}'
    OR msg ~ '\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d'
  THEN
    RAISE EXCEPTION 'Message blocked: sharing phone numbers is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 4. Email addresses
  IF lower_msg ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
    OR lower_msg ~* '[a-z0-9._%+-]+\s*(at|@)\s*[a-z0-9.-]+\s*(dot|\.)\s*[a-z]{2,}'
  THEN
    RAISE EXCEPTION 'Message blocked: sharing email addresses is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 5. Social media app names
  IF lower_msg ~* '\m(whatsapp|whats\s*app|watsapp|instagram|insta|facebook|telegram|snapchat|discord|skype|twitter|signal|viber|tiktok|wechat|kakaotalk|linkedin)\M'
  THEN
    RAISE EXCEPTION 'Message blocked: mentioning social media apps is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 6. Contact sharing intent
  IF lower_msg ~* '\m(give|send|share|tell)\s*(me|you|your|my|ur)\s*(number|phone|mobile|cell|email|id|contact)\M'
    OR lower_msg ~* '\m(contact|reach|text|message|call)\s*(me|us)\s*(outside|privately|directly|off\s*this|off\s*app)\M'
    OR lower_msg ~* '\m(outside\s*(this\s*)?app|off\s*platform|another\s*app)\M'
  THEN
    RAISE EXCEPTION 'Message blocked: sharing contact information outside the app is not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;
