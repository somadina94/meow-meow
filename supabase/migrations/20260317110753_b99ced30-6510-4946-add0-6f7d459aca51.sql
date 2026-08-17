
-- Server-side content moderation trigger for chat_messages
-- Mirrors the client-side patterns from content-moderation.ts
-- Blocks: sexual content, contact info (phone/email/social media), harmful content

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
  
  lower_msg := lower(msg);

  -- 1. Sexual/explicit content (English + transliterated Indian languages)
  IF lower_msg ~* '\m(sex|nude[s]?|naked|porn|xxx|nsfw|erotic|orgasm|masturbat|blowjob|handjob|threesome|gangbang|fetish|bondage|bdsm|strip\s*tease|one\s*night\s*stand|hookup|hook\s*up|booty\s*call|slutt?y?|whor[e]?)\M'
    OR lower_msg ~* '\m(send\s*(me\s*)?(nudes?|pics?|photos?|body\s*pics?))\M'
    OR lower_msg ~* '\m(show\s*(me\s*)?(your\s*)?(body|boobs?|tits?|ass|butt|privates?))\M'
    OR lower_msg ~* '\m(let''?s?\s*(have\s*)?sex|wanna\s*(f[*]?ck|bang|smash|screw))\M'
    OR lower_msg ~* '\m(horny|turned\s*on|get\s*laid|make\s*love|sleep\s*with\s*me)\M'
    -- Hindi/Urdu transliterated
    OR lower_msg ~* '\m(chod|chud|lund|gaand|bhosdi|randi|chut|maderchod|behenchod|chudai)\M'
    -- Tamil transliterated
    OR lower_msg ~* '\m(otha|thevdiya|pundai|sunni|oombu|koothi)\M'
    -- Telugu transliterated
    OR lower_msg ~* '\m(dengey|modda|gudda|lanja|pooku|sulli)\M'
    -- Native script (Hindi)
    OR msg ~ '(चोद|चूत|लंड|गांड|भोसडी|रंडी|चुदाई|मादरचोद|बहनचोद)'
    -- Native script (Tamil)
    OR msg ~ '(ஓத்தா|தேவடியா|புண்டை|சுன்னி|ஊம்பு|கூதி)'
    -- Native script (Telugu)
    OR msg ~ '(దెంగేయ్|మొడ్డ|గుద్ద|లంజ|పూకు|సుల్లి)'
    -- Chinese characters
    OR msg ~ '[操肏屌屄婊鸡巴逼骚淫荡]'
    -- Korean
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

-- Attach trigger to chat_messages
DROP TRIGGER IF EXISTS trg_validate_chat_message ON public.chat_messages;
CREATE TRIGGER trg_validate_chat_message
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_chat_message();

-- Also protect group_messages
DROP TRIGGER IF EXISTS trg_validate_group_message ON public.group_messages;
CREATE TRIGGER trg_validate_group_message
  BEFORE INSERT ON public.group_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_chat_message();

-- Also protect language_community_messages
DROP TRIGGER IF EXISTS trg_validate_community_message ON public.language_community_messages;
CREATE TRIGGER trg_validate_community_message
  BEFORE INSERT ON public.language_community_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_chat_message();
