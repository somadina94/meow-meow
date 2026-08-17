import { useState, useRef, useEffect, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import MeowLogo from "@/components/MeowLogo";
import ProgressIndicator from "@/components/ProgressIndicator";
import { useToast } from "@/hooks/use-toast";
import { 
  ScrollText, 
  Shield, 
  Check, 
  Loader2, 
  FileText,
  Lock,
  Globe,
  Database,
  Users,
  Ban,
  CreditCard,
  Eye,
  UserCheck,
  Bot,
  Clock,
  CheckCircle2,
  ArrowLeft
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { countries } from "@/data/countries";
import { getStatesForCountry } from "@/data/states";
import { languages } from "@/data/languages";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

interface LegalDocument {
  id: string;
  title: string;
  icon: React.ReactNode;
  content: string;
  required: boolean;
}

const EFFECTIVE_DATE = "26 April 2026";

const legalDocuments: LegalDocument[] = [
  {
    id: "terms_of_service",
    title: "Terms of Service",
    icon: <ScrollText className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — TERMS OF SERVICE
Effective: ${EFFECTIVE_DATE}

1. ACCEPTANCE
By creating an account or using Meow MEOW FRND APP ("the App", "we", "us"), you enter a binding agreement with the operator of Meow MEOW FRND APP. If you do not agree, you must not use the App.

2. ELIGIBILITY (STRICT 18+)
• You must be at least 18 years old (or the legal age of majority in your jurisdiction, whichever is higher).
• The App is intended exclusively for residents of India and verified Indian users.
• Only two gender options are supported: Male and Female. Gender is verified using AI face/photo analysis.
• One natural person = one account. Duplicate, fake, bot, or shared accounts are prohibited.
• You must provide truthful, accurate, and current information at registration and keep it updated.
• Use of VPN, Tor, GPS spoofing, or any tool to misrepresent your location, identity, gender, or age is forbidden and will result in permanent ban and forfeiture of any wallet balance or virtual coins.

3. NATURE OF SERVICE
Meow MEOW FRND APP is an opposite-sex social and communication platform offering:
• Real-time text chat with auto-translation across 100+ languages.
• 1:1 audio and video calls — initiated by men, accepted by women, billed per second.
• Private flower-themed group video & audio calls (up to 50 rooms, multi-participant).
• Language-specific community group chat for women.
All communication channels — chat (text, images, videos, documents and voice messages), audio calls, video calls, and group calls — are expressly permitted within the App and governed by the same prohibitions, moderation, and safety rules. Media attachments are auto-deleted after 15 minutes. The service is online-only and depends on network, third-party infrastructure, and user availability.

4. ACCOUNT REGISTRATION & VERIFICATION
• Email, phone, gender, age, country (India), state, languages and a live selfie are required.
• AI face verification confirms a real, single, live human and estimates gender; mismatched photos are rejected.
• Female users may be asked to complete a KYC verification (PAN, Aadhaar with masking, bank account or UPI handle for identity matching, address proof, and a live selfie). KYC is collected solely for IDENTITY VERIFICATION, anti-fraud, anti-impersonation, age confirmation, and statutory compliance — NOT as a basis for any monetary payout. Women still do not receive any money from the platform; participation remains voluntary and is acknowledged only with non-monetary in-app virtual coins (see §7). KYC documents are encrypted, access-logged, and disclosed only to authorised compliance staff and to law enforcement on valid legal demand.
• We may re-verify identity at any time and suspend access pending verification.

5. PROHIBITED CONDUCT — SEXUAL CONTENT, HATE SPEECH & MORE
You shall NOT, directly or indirectly, in chat, audio, video, group calls, profile, or any other feature:
(a) SEXUAL CONTENT — Post, send, broadcast, perform on camera, narrate, roleplay, or solicit any sexual, obscene, pornographic, nude, semi-nude, lingerie, erotic, masturbatory, fetish, BDSM, or sexually-suggestive content. This is a strict zero-tolerance rule and a criminal offence under:
   • IT Act 2000 §67 (obscene material in electronic form, up to 5 years + ₹10 lakh fine; second offence up to 7 years + ₹10 lakh),
   • IT Act 2000 §67A (sexually explicit material, up to 5 years + ₹10 lakh),
   • IT Act 2000 §67B (any sexual depiction of a child — up to 7 years + ₹10 lakh),
   • IT Act 2000 §66E (capturing/transmitting private images without consent),
   • Bharatiya Nyaya Sanhita 2023 §§75, 76, 77, 78, 79 (sexual harassment, voyeurism, stalking, insult to modesty),
   • Indecent Representation of Women (Prohibition) Act 1986,
   • Immoral Traffic (Prevention) Act 1956 (no solicitation of prostitution / escort / sugar arrangements),
   • POCSO Act 2012 for any content involving minors,
   • EU Directive 2011/93/EU, US 18 USC §§2252/2252A/2422, UK Protection of Children Act 1978, and equivalent laws worldwide.
   Live audio/video/group calls are continuously moderated; any sexual exposure ends the call instantly, permanently bans the user, forfeits all balance and virtual coins, and may be referred to the National Cyber Crime Reporting Portal (cybercrime.gov.in), NCMEC CyberTipline, INTERPOL ICSE, and local police.

(b) CHILD PROTECTION — Engage with, attempt to engage with, groom, or depict any minor in any sexual, romantic, or exploitative context. Mandatory reporting under POCSO 2012, IT Act §67B, US 18 USC §2258A (NCMEC), and similar laws. All evidence (account, IP, device, payments, chat) is preserved indefinitely for law enforcement.

(c) HATE SPEECH & DISCRIMINATION — Post, transmit, or perform any content that incites hatred, enmity, violence, or discrimination on grounds of religion, caste, race, ethnicity, language, region, gender, sexual orientation, disability, or nationality. Prohibited under:
   • Bharatiya Nyaya Sanhita 2023 §196 (promoting enmity between groups), §197 (imputations prejudicial to national integration), §299 (deliberate insult to religious feelings), §351 (criminal intimidation), §353 (statements conducing to public mischief),
   • IT Act 2000 §69A (blocking of unlawful content) and §79 read with IT Rules 2021 §3(1)(b)(ii)–(x),
   • SC/ST (Prevention of Atrocities) Act 1989,
   • Protection of Civil Rights Act 1955,
   • Unlawful Activities (Prevention) Act 1967 (UAPA) for terror-related speech,
   • EU Digital Services Act 2022, German NetzDG, French Loi Avia, UK Online Safety Act 2023,
   • US incitement standards (Brandenburg v. Ohio) and platform anti-hate norms.
   Communalism, casteism, racism, misogyny, misandry, homophobia, transphobia, xenophobia, religious mockery, and dehumanising slurs are removed on detection and result in escalating bans up to permanent.

(d) HARASSMENT, STALKING & ABUSE — No threats, intimidation, defamation, doxxing, blackmail, sextortion, repeated unwanted contact after block, image-based abuse ("revenge porn"), or coordinated brigading. Covered by BNS §§78 (stalking), §79 (insult to modesty), §351 (criminal intimidation), §356 (defamation); IT Act §66E; and equivalents abroad.

(e) PRIVACY & CONTACT-SHARING — Do not solicit, exchange, or share personal contact details (phone, Telegram, Instagram, Snapchat, email, postal address, social handles) or external payment apps (UPI, Paytm, PhonePe, GPay, bank account). All chat, audio, video, and group conversations must remain inside the App.

(f) FRAUD & SCAMS — No romance scams, advance-fee fraud, investment / crypto / "lottery" / fake-emergency / "pig-butchering" scams, catfishing, impersonation, or coordinated inauthentic behaviour. Punishable under BNS §§316, 318 (cheating), §319 (cheating by personation), IT Act §66C/§66D, and global fraud statutes.

(g) PROHIBITED COMMERCE — No prostitution, escort services, sugar-daddy/sugar-baby arrangements, trafficking, or commercial sexual activity (Immoral Traffic (Prevention) Act 1956; UN Palermo Protocol; US TVPA).

(h) TECHNICAL ABUSE — No viruses, malware, spyware, scraping bots, automation scripts, reverse engineering, penetration testing, or denial-of-service.

(i) CIRCUMVENTION — No bypassing gender, age, geography, payment, or moderation controls; no VPN/Tor/GPS-spoofing.

(j) FINANCIAL CRIME — No money laundering, terror financing, or hawala (PMLA 2002, FEMA 1999, UAPA 1967, OFAC/UN/EU sanctions).

(k) IP INFRINGEMENT — No infringement of copyright, trademark, trade secret, publicity, or privacy rights.

(l) PAYMENT FRAUD — No chargeback fraud, "friendly fraud", or recharge with stolen instruments.

(m) ACCOUNT INTEGRITY — No selling, transferring, renting, or sharing your account.

6. PAYMENTS — MEN (Wallet, Coins, Limits)
• Recharge in INR via authorised processors (Razorpay/Stripe/Paddle/UPI).
• Per-second pro-rated billing for chat, calls, video calls, and group calls (see in-app rate card).
• 18% GST is included as required under CGST/SGST/IGST Acts; GST invoice on request.
• NO UPPER LIMIT ON RECHARGES OR WALLET BALANCE: men may recharge any amount, any number of times, and hold any wallet balance, subject only to (i) their own bank/card/UPI limits, (ii) the payment processor's per-transaction caps, and (iii) statutory anti-money-laundering checks under PMLA 2002, RBI Master Directions on Prepaid Payment Instruments, and the Payment and Settlement Systems Act 2007 (large or unusual transactions may be flagged or reported to FIU-IND). The administrator may introduce, modify, or remove recharge limits at any time without prior notice.
• Recharges are NON-REFUNDABLE except where mandated by the Consumer Protection Act 2019 or RBI guidelines.
• Chargeback without first contacting support is treated as fraud and results in permanent ban + payment-network blacklist.

7. WOMEN — VOLUNTARY PARTICIPATION & VIRTUAL COINS (NO MONEY)
• Women use Meow MEOW FRND APP ENTIRELY for their own social interest — to chat, audio-call, video-call, and join group calls with verified male users. Participation is voluntary, recreational, and personal.
• WOMEN DO NOT EARN, RECEIVE, OR HAVE ANY CLAIM TO REAL MONEY, INDIAN RUPEES, FOREIGN CURRENCY, CRYPTO, OR ANY OTHER FORM OF MONETARY VALUE FROM MEOW MEOW.
• Their in-app activity may be acknowledged with VIRTUAL COINS — non-monetary, in-app digital tokens that:
   – have NO cash value, NO redemption value, and NO exchange value;
   – are NOT a currency, security, e-money, prepaid instrument, deposit, or financial product under the RBI Act 1934, Payment & Settlement Systems Act 2007, RBI PPI Master Directions, FEMA 1999, or SEBI laws;
   – CANNOT be withdrawn, transferred to a bank, sold, gifted to another user, or converted into money or goods;
   – may only be used inside the App for cosmetic, recognition, status, or visibility features that the administrator may add, modify, or remove at any time without notice;
   – may be reduced, expired, frozen, or revoked by the administrator at sole discretion, without compensation.
• NO EMPLOYMENT — Meow MEOW FRND APP is not the woman's employer, principal, agent, partner, contractor, or counterparty. No employer-employee, contract-of-service, contract-for-service, agency, partnership, or joint-venture relationship is created. No salary, wage, commission, fee, bonus, or other remuneration is owed.
• NO TAX EVENT — Because no money or money's worth is received, no income, GST, TDS, or other tax obligation is created on the women's side, even where the platform has collected KYC documents (PAN, Aadhaar, bank/UPI handle, address proof) from her. KYC is held exclusively for identity verification, anti-fraud, age confirmation, and statutory compliance, and is never the basis of any monetary payment.
• NO PAYOUT MECHANISM exists for women on the platform. Any external request, message, or third-party offer to "convert" virtual coins into money is a scam and must be reported.
• Virtual coins earned through fake activity, automation, sexual content, hate speech, or contact-sharing are forfeited and the account is permanently banned.

8. CONTENT LICENSE
You retain ownership of content you create. By submitting it, you grant Meow MEOW FRND APP a worldwide, royalty-free, non-exclusive, sub-licensable licence to host, store, transmit, translate, moderate, and display it solely to operate, improve, and protect the service.

9. AI-ASSISTED FEATURES
The App uses AI for: face/liveness detection, gender estimation, age estimation, language detection, real-time translation, content moderation, and fraud detection. AI outputs may be wrong; you may request human review of any adverse automated decision.

10. SUSPENSION & TERMINATION
We may suspend, restrict, shadow-ban, or permanently terminate your account at our sole discretion, without prior notice, for any breach of these Terms or applicable law. You may delete your account at any time from Settings; certain data will be retained as described in the Data Retention Policy.

11. DISCLAIMERS
THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE". TO THE MAXIMUM EXTENT PERMITTED BY LAW WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND ACCURACY. WE DO NOT GUARANTEE COMPATIBILITY, FRIENDSHIP, RELATIONSHIP, OR ANY SPECIFIC OUTCOME WITH ANY OTHER USER.

12. LIMITATION OF LIABILITY
To the maximum extent permitted by law, our aggregate liability for any claim arising out of or relating to the App is limited to the amount you paid into your wallet in the 3 months preceding the claim, or INR 10,000, whichever is lower. We are not liable for indirect, incidental, special, consequential, exemplary, or punitive damages, lost profits, or loss of data.

13. INDEMNITY
You will defend, indemnify, and hold harmless Meow MEOW FRND APP, its directors, employees, and agents from any claim, loss, liability, or expense (including legal fees) arising from your breach of these Terms, your content, or your conduct.

14. GOVERNING LAW & JURISDICTION
These Terms are governed by the laws of India. Subject to the Arbitration and Conciliation Act 1996, disputes will be referred to a sole arbitrator in Bengaluru, Karnataka. Courts at Bengaluru have exclusive jurisdiction. Foreign users additionally consent to Indian jurisdiction and waive forum non-conveniens objections.

15. ADMIN DISCRETION & UNILATERAL CHANGES (NO USER NOTICE REQUIRED)
You expressly acknowledge and agree that:
• The administrator of Meow MEOW FRND APP has SOLE and ABSOLUTE DISCRETION over every rule, policy, feature, price, rate card, recharge limit, virtual-coin balance, virtual-coin grant or revocation, KYC requirement (men and women), moderation threshold, suspension, ban, content takedown, refund decision, gender/age verification outcome, and any other operational matter.
• The administrator MAY ADD, MODIFY, REPLACE, SUSPEND, OR REMOVE any rule, policy, feature, price, or limit at ANY TIME, EFFECTIVE IMMEDIATELY, WITHOUT PRIOR NOTICE, individual notification, email, push, or in-app banner to end-users.
• The current version of these Terms and all linked policies, as published in the App at the moment of any user action, governs that action. It is the user's responsibility to review the Terms periodically.
• Continued use of the App after any change constitutes full and final acceptance of the change. The user's sole remedy in case of disagreement is to stop using the App and request account deletion.
• No prior version of these Terms or any past communication, marketing material, or oral statement creates any vested right, estoppel, or legitimate expectation against the administrator's right to change the Terms unilaterally.
This unilateral-change right is exercised in good faith and subject only to the non-waivable rights granted to users by Indian law (DPDP 2023, Consumer Protection Act 2019) and applicable foreign mandatory law (e.g., GDPR Art. 22, EU consumer law). Where local mandatory law requires advance notice for a specific category of change (e.g., material privacy changes under GDPR), that legal minimum is honoured for affected users only.

16. CONTACT / GRIEVANCE OFFICER (per IT Rules 2021)
Grievance Officer: support@meowmeow.app | Response within 24 hours, resolution within 15 days as required by Rule 3(2) of the IT (Intermediary Guidelines) Rules 2021.

═══════════════════════════════════════════════════════════
17. DATING-APP LEGAL & COMPLIANCE FRAMEWORK (GLOBAL + INDIA)
═══════════════════════════════════════════════════════════
Meow MEOW FRND APP operates as an online dating / opposite-sex social-communication platform and complies with the following layered legal framework. This section is informational and binding; users accept its applicability.

🇮🇳 PART A — INDIA: CORE LAWS & REGULATIONS

A.1 Information Technology Act, 2000 (IT Act)
Primary law for digital platforms in India. We are an "intermediary" under this Act.
• Sec 69A — Government may order blocking of unlawful content; we will comply.
• Sec 66 / 66E / 67 / 67A / 67B — Cybercrime, privacy violation, obscene & sexually explicit material, child sexual abuse material. Strictly prohibited; reported to authorities.
• Sec 79 — Safe-harbour protection conditional on observing IT Rules 2021 due-diligence; we observe these obligations to retain safe-harbour.

A.2 Digital Personal Data Protection Act, 2023 (DPDP Act)
India's primary privacy statute. We:
• Obtain free, specific, informed, unconditional, unambiguous CONSENT before collecting personal data.
• State a CLEAR PURPOSE for every data category (matching, billing, safety).
• Honour the right to CORRECT, ERASE, and WITHDRAW consent (DPDP §§11-13).
• NOTIFY the Data Protection Board of India and affected users of any personal-data breach (DPDP §8(6)).
• Apply heightened protection to data the user uploads in a dating context — photos, location signals, chat content, gender, and any inference of sexual orientation.

A.3 IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021
We comply with all due-diligence obligations:
• A GRIEVANCE OFFICER located in India (see §16).
• User-complaint mechanism with 24 h acknowledgement and 15-day resolution (Rule 3(2)(a)).
• Takedown of unlawful content within 36 h of valid order (Rule 3(1)(d)) and within 24 h for non-consensual intimate imagery (Rule 3(2)(b)).
• Cooperation with law enforcement; user-traceability where ordered by competent authority for specified serious offences (Rule 4(2), where applicable to "significant social-media intermediaries").

A.4 IT Rules — Online Safety & Child Protection
• Strict 18+ minimum age — no underage accounts permitted.
• AI-assisted age verification at registration plus DOB cross-check.
• Mandatory reporting of child sexual exploitation under POCSO 2012 §§19-22 and IT Act §67B.

A.5 Bharatiya Nyaya Sanhita 2023 (replacing IPC 1860)
Relevant offences for dating-context misconduct:
• §75 — Sexual harassment; §76 — Assault to disrobe; §77 — Voyeurism; §78 — Stalking; §79 — Insult to modesty.
• §316/318/319 — Cheating, cheating by personation (catfishing, fake identity).
• §351 — Criminal intimidation; §356 — Defamation.
• §196/197/299 — Hate speech and inciting religious / communal disharmony.

A.6 Consumer Protection Act, 2019
Covers misleading subscriptions, opaque auto-renewals, refund disputes, and any monetised feature. We:
• Display all rates and charges clearly inside the App before payment.
• Do not auto-renew subscriptions without explicit consent.
• Provide a refund mechanism for failed/duplicate transactions per RBI guidelines (see §6).
• Maintain an internal redressal process before consumer-forum escalation.

A.7 RBI / Payment Regulations
Applicable because the App offers a wallet and processes UPI/card/net-banking payments:
• Recharges (men only) are routed only through RBI-licensed Payment Aggregators (Razorpay/Stripe/Paddle/etc.). No outbound payments are made to women.
• We comply with the Payment and Settlement Systems Act 2007 and the RBI Master Directions on Prepaid Payment Instruments.
• Card data is tokenised by PCI-DSS Level-1 processors; raw card numbers are never stored.
• Failed transactions are auto-reversed per RBI Turnaround-Time circular 2019.

🌍 PART B — EUROPE: GDPR

B.1 Applicability
The General Data Protection Regulation (Reg. (EU) 2016/679) applies whenever EU/EEA users access the App.

B.2 Key Requirements We Honour
• EXPLICIT, opt-in consent — never implied or pre-ticked (Art. 4(11), 7).
• Right of ACCESS to personal data (Art. 15).
• Right to ERASURE / "right to be forgotten" (Art. 17).
• Right to DATA PORTABILITY in machine-readable form (Art. 20).
• Personal-data BREACH NOTIFICATION to the supervisory authority within 72 hours (Art. 33) and to affected users without undue delay (Art. 34).

B.3 Special-Category Data (Art. 9)
Dating apps inevitably process sensitive data: facial biometrics from selfies, precise location signals (when used), and inferences about sexual orientation. We process such data only with EXPLICIT OPT-IN consent (Art. 9(2)(a)) and apply additional safeguards (encryption, minimisation, short retention).

🇺🇸 PART C — UNITED STATES

C.1 California — CCPA / CPRA
For users in California we honour:
• Right to KNOW what personal information is collected, used, and shared.
• Right to DELETE personal information.
• Right to OPT OUT of "sale" or "sharing" of personal information (we do not sell).
• Right to LIMIT use of sensitive personal information.
• Right to NON-DISCRIMINATION for exercising privacy rights.

C.2 FTC Act (Federal Trade Commission)
We do not engage in deceptive or unfair trade practices. Specifically prohibited:
• Fake / bot profiles operated by the platform.
• Hidden, obscure, or hard-to-cancel subscriptions ("ROSCA" — Restore Online Shoppers' Confidence Act compliance).
• Misleading claims about matching algorithms or success rates.

C.3 COPPA — Children's Online Privacy Protection Act
We never knowingly collect data from anyone under 13. Combined with our 18+ floor, no minors are permitted on the platform; underage accounts discovered are deleted within 7 days.

🌐 PART D — INTERNATIONAL / GLOBAL PLATFORM RULES

D.1 App Store Guidelines
Apple App Store:
• We declare every category of data collected and any tracking in App Privacy.
• We meet Apple's dating-app rules: 17+/18+ rating, no promotion of explicit sexual content, robust moderation.
Google Play:
• Complete Data-Safety section disclosure.
• Built-in user reporting and blocking tools.
• Active content-moderation system (AI + human).

D.2 PCI-DSS (Payment Card Industry Data Security Standard)
All cardholder data is processed exclusively by PCI-DSS Level-1 certified processors. We do not store PAN, CVV, or full card numbers on our infrastructure.

D.3 Other Jurisdictions
Where users access from other regions, equivalent local laws are observed: UK GDPR + DPA 2018, Canada PIPEDA, Brazil LGPD, Australia Privacy Act 1988, Singapore PDPA, UAE PDPL, Japan APPI, South Korea PIPA, and others.

🔐 PART E — CORE PRIVACY PRINCIPLES (ALL LAWS COMBINED)

E.1 Consent — explicit opt-in for location, profile visibility, photo / biometric verification, and matching.
E.2 Data Minimisation — we collect only what is needed to operate the App and comply with law.
E.3 Security — TLS 1.3 in transit, AES-256 at rest, OTP / OAuth-style secure authentication, RLS-isolated databases, MFA on admin accounts.
E.4 User Rights — every user can: delete account, export data, block/report any other user, and control profile visibility.
E.5 Retention — chat bodies auto-purged every 15 minutes; inactive accounts may be deleted after extended dormancy; statutory records (men's payment receipts, GST) retained only for the legally mandated period.

🚨 PART F — DATING-APP-SPECIFIC LEGAL RISKS & SAFEGUARDS

F.1 High-Risk Areas: fake profiles, harassment, sexual exploitation, underage access, location-tracking misuse, romance scams, sextortion, image-based abuse, trafficking.
F.2 Safeguards Implemented:
• AI age & gender verification at registration with periodic re-checks.
• In-app Report and Block on every profile, chat, audio call, video call, and group call.
• Layered content moderation — AI pre-publication filters + human review of reports.
• Identity controls — one account per natural person; device & IP fingerprinting; anti-VPN heuristics.
• Dedicated Trust & Safety / Grievance Officer team (see §16).

📜 PART G — TERMS-OF-SERVICE COVERAGE CHECKLIST
This document expressly addresses, as required for dating-platform ToS:
✓ Eligibility (strict 18+) — see §2.
✓ User responsibilities & prohibited conduct — see §5.
✓ Content ownership & licence — see §8.
✓ Data usage policy — see Privacy Policy.
✓ Payment / wallet terms — see §6.
✓ Refund policy — see Payments, Refunds & Payouts policy.
✓ Account termination rules — see §10.
✓ Liability disclaimer — see §§11-12.
✓ Anti-abuse policy — see §5 and Anti-Sexual Content & Hate-Speech policies.
✓ Privacy-policy linkage — see Privacy Policy document.

⚖️ PART H — SUMMARY OF APPLICABLE LAW

INDIA: IT Act 2000 · DPDP Act 2023 · IT (Intermediary Guidelines) Rules 2021 · Bharatiya Nyaya Sanhita 2023 · POCSO 2012 · Consumer Protection Act 2019 · Income Tax Act 1961 · CGST/SGST/IGST Acts · PMLA 2002 · FEMA 1999 · Payment & Settlement Systems Act 2007 · RBI PPI Master Directions.
GLOBAL: EU GDPR · UK GDPR + DPA 2018 · CCPA / CPRA (California) · FTC Act + ROSCA (US) · COPPA (US) · PIPEDA (Canada) · LGPD (Brazil) · Australian Privacy Act 1988 · Singapore PDPA · UAE PDPL · Japan APPI · South Korea PIPA.
PLATFORMS: Apple App Store Review Guidelines · Google Play Developer Policies · PCI-DSS v4.0.

By accepting these Terms you acknowledge that the above framework governs your use of Meow MEOW FRND APP regardless of your physical location, and you submit to the jurisdiction and dispute-resolution mechanism described in §14.`
  },
  {
    id: "privacy_policy",
    title: "Privacy Policy",
    icon: <Shield className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — PRIVACY POLICY
Effective: ${EFFECTIVE_DATE}

This Policy explains what personal data we collect, why, how we use it, and the rights you have under the Digital Personal Data Protection Act, 2023 (India), the EU/UK GDPR, the California Consumer Privacy Act / CPRA, Canada PIPEDA, Brazil LGPD, the Australian Privacy Act 1988, and other applicable laws.

1. DATA WE COLLECT
(a) Identity & profile: full name, gender, date of birth, age, country, state, languages, mother tongue, profile photo / live selfie.
(b) Account: email, phone, hashed password, device ID, IP address (truncated where possible), user-agent.
(c) KYC: (i) From women — PAN, Aadhaar (stored masked / last-4 only after verification), bank account or UPI handle for identity matching, IFSC, address proof, and a live selfie. Collected for identity verification, anti-fraud, age confirmation, and statutory compliance — never as a basis for any monetary payment. (ii) From men — name on card / UPI handle as returned by the payment processor for high-value recharges.
(d) Communications metadata: who chatted/called whom, duration, billing seconds. Chat message bodies are end-to-end encrypted in transit and auto-deleted (see §7).
(e) Payment data: amounts, GST, payment method type, transaction status. Full card / UPI credentials are handled directly by PCI-DSS compliant processors and never stored on our servers.
(f) Technical & safety: crash logs, abuse reports, moderation actions, AI verification scores.

2. SENSITIVE PERSONAL DATA
We treat the following as sensitive and apply additional safeguards:
• Biometric data (face embeddings used only for liveness/gender check — discarded after verification).
• Government IDs (PAN, Aadhaar, address proof) collected from women for KYC are encrypted at rest, access-logged, used solely for identity verification, anti-fraud, age confirmation and statutory compliance, and disclosed only to authorised compliance staff and to law enforcement on valid legal demand. From men, only payment-processor tokens are stored, encrypted at rest and access-logged.
We do NOT collect: contacts list, social-media accounts, browsing history outside the App, health data, religious or political opinions.

3. LEGAL BASIS (DPDP / GDPR Art. 6)
• Consent — for marketing, optional features, AI gender verification.
• Performance of contract — to operate the App, process payments, deliver chats/calls.
• Legal obligation — tax (Income Tax Act 1961, GST on men's recharges), KYC retention (PMLA 2002 where applicable), grievance redressal (IT Rules 2021), child-safety reporting (POCSO 2012).
• Legitimate interest — fraud prevention, security, service improvement, balanced against your rights.

4. PURPOSES OF USE
Account creation; matching opposite-sex users; chat/call/group delivery; AI translation; AI face/gender/age verification; KYC verification of women for identity, anti-fraud and age confirmation; per-second billing & GST invoicing on men's recharges; awarding non-monetary virtual coins to women; safety, moderation, anti-spam; complying with court orders, tax filings, and government requests; communicating service notices.

5. AI AUTOMATED PROCESSING
Decisions made wholly or partly by AI (gender mismatch, content takedown, fraud flag) can be appealed to a human reviewer at support@meowmeow.app within 30 days. We do not perform political profiling or sell biometric data.

6. SHARING & DISCLOSURE
We share data only with:
(a) Sub-processors under written contracts: Supabase (database & auth), Lovable AI Gateway, Razorpay/Stripe/Paddle (payments), TURN/STUN providers (calls), email/SMS gateways.
(b) Government, regulator, court, or law-enforcement when legally compelled (CrPC §91, IT Act §69, DPDP §17, foreign MLATs).
(c) Successor entity in a merger, acquisition, or asset sale (with continued protection).
We do NOT sell or rent personal data to advertisers or data brokers.

7. RETENTION
• Chat message bodies — deleted automatically every 15 minutes.
• Account & profile — until you delete the account, then 30 days grace.
• Payment & GST records — 8 years (Companies Act 2013, GST Act).
• Men's payment receipts & GST records — 8 years (Companies Act, GST Act).
• Women's KYC documents — retained for the period required by PMLA / RBI rules and applicable law (typically up to 8 years from last activity), then securely deleted; users may request earlier deletion subject to law.
• Server & security logs — 30–180 days.
• Court-preserved data — until release.

8. CROSS-BORDER TRANSFERS
Primary storage is in India. Limited data may be processed in Singapore, Japan, the EU, or the United States by sub-processors. Transfers rely on:
• DPDP §16 notified-country mechanism,
• EU Standard Contractual Clauses (SCCs) + Transfer Impact Assessment,
• UK IDTA, Swiss FDPIC clauses where applicable.

9. YOUR RIGHTS
Subject to applicable law you may:
• Access a copy of your data (DPDP §11, GDPR Art.15, CCPA "right to know").
• Correct inaccurate data (DPDP §12, GDPR Art.16).
• Erase your data ("right to be forgotten" — DPDP §12, GDPR Art.17, CCPA "right to delete").
• Restrict or object to processing (GDPR Art.18/21).
• Port your data in a machine-readable format (GDPR Art.20).
• Withdraw consent at any time without affecting prior lawful processing.
• Opt out of "sale/share" — we do not sell, but you can confirm via support.
• Lodge a complaint with the Data Protection Board of India, your EU/UK supervisory authority, the California Privacy Protection Agency, or other regulator.
Exercise rights at: privacy@meowmeow.app — response within 30 days.

10. CHILDREN
The App is strictly 18+. We do not knowingly process data of anyone under 18. If we discover an underage account, we delete it immediately and, where the user appears to be in danger, report to authorities under the POCSO Act 2012 and US COPPA equivalents.

11. SECURITY
TLS 1.3 in transit, AES-256 at rest, role-based access, MFA on admin, RLS-enforced database isolation, daily backups, 24/7 monitoring. No method is 100% secure; we will notify you and the regulator within 72 hours of a notifiable breach (DPDP §8(6), GDPR Art.33-34).

12. COOKIES & SIMILAR
We use only strictly-necessary first-party cookies / local storage for session, auth, and language preference. No third-party advertising trackers.

13. DATA PROTECTION OFFICER (DPO) & GRIEVANCE OFFICER
DPO / Grievance Officer (India): privacy@meowmeow.app — acknowledges within 24 h, resolves within 15 days (IT Rules 2021, Rule 3(2)(a)).

14. UPDATES
Material changes notified in-app 7 days in advance. Last updated: ${EFFECTIVE_DATE}.`
  },
  {
    id: "security_policy",
    title: "Security Policy",
    icon: <Lock className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — SECURITY POLICY
Effective: ${EFFECTIVE_DATE}

1. ENCRYPTION
• In transit: TLS 1.3 for all client-server traffic; DTLS-SRTP for media (audio/video calls).
• At rest: AES-256 GCM for databases, KYC documents, and backups.
• Passwords: hashed with bcrypt/argon2id + per-user salt.

2. INFRASTRUCTURE
• Cloud-native deployment on hardened, region-isolated servers.
• Web Application Firewall, DDoS mitigation, rate-limiting on auth & payment endpoints.
• coturn TURN/STUN servers with short-lived credentials for calls.
• Network segmentation between application, database, and admin tiers.

3. ACCESS CONTROL
• Principle of least privilege; role-based access (RBAC) enforced in DB via Row-Level Security.
• Multi-factor authentication on all admin accounts.
• Quarterly access reviews; immediate revocation on role change.
• Privileged actions are append-only audit-logged.

4. DEVELOPMENT & SUPPLY CHAIN
• OWASP ASVS-aligned secure SDLC.
• Dependency scanning, SAST, secret-scanning in CI.
• No production data in development or test environments.

5. MONITORING & INCIDENT RESPONSE
• 24/7 automated anomaly detection (failed-login spikes, abuse patterns, fraud signals).
• Incident response plan with RTO 4 h / RPO 1 h.
• Notifiable breach: regulator + affected users informed within 72 h, per DPDP §8(6) and GDPR Art.33-34.

6. BACKUPS & DISASTER RECOVERY
• Encrypted, geo-redundant daily backups, 30-day retention.
• Quarterly DR drills.

7. RESPONSIBLE DISCLOSURE
Researchers may report vulnerabilities to security@meowmeow.app. We commit not to pursue legal action for good-faith research that respects user privacy and avoids service disruption.`
  },
  {
    id: "gdpr_compliance",
    title: "GDPR / UK GDPR Compliance",
    icon: <Globe className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — EU / UK GDPR COMPLIANCE STATEMENT
Effective: ${EFFECTIVE_DATE}

1. CONTROLLER
Meow MEOW FRND APP is the data controller for personal data processed through the App.

2. LAWFUL BASES (Art. 6)
• Consent (Art. 6(1)(a)) — optional features, marketing.
• Contract (Art. 6(1)(b)) — providing the App.
• Legal obligation (Art. 6(1)(c)) — tax on men's recharges, KYC retention, law enforcement.
• Legitimate interest (Art. 6(1)(f)) — fraud, security, abuse prevention.

3. SPECIAL CATEGORY DATA (Art. 9)
Biometric face data is processed under Art. 9(2)(a) explicit consent for the limited purpose of liveness and gender verification. Templates are not retained beyond verification.

4. DATA SUBJECT RIGHTS (Art. 15-22)
Access, rectification, erasure, restriction, portability, objection, no automated decision without human review. Requests: privacy@meowmeow.app — response within 30 days.

5. INTERNATIONAL TRANSFERS (Chapter V)
Transfers to India and other non-adequacy countries rely on EU SCCs (Decision 2021/914) and the UK IDTA, with Transfer Impact Assessments and supplementary measures (encryption, pseudonymisation).

6. DPO & EU/UK REPRESENTATIVE
DPO: privacy@meowmeow.app
We will appoint a representative under GDPR Art. 27 / UK DPA Art. 27 for users in the EU/EEA and UK if our processing volume crosses the statutory threshold.

7. SUPERVISORY AUTHORITY
You may complain to your national Data Protection Authority — e.g., the Irish DPC, the UK ICO, the French CNIL.

8. CHILDREN (Art. 8)
The App is 18+ only; consent of a parent for users below 16 is not applicable.

9. DPIA
A Data Protection Impact Assessment has been performed for biometric verification, AI moderation, women's KYC processing, and the men's recharge / virtual-coin processing flows.`
  },
  {
    id: "data_storage_policy",
    title: "Data Localization & Storage",
    icon: <Database className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — DATA LOCALIZATION & STORAGE POLICY
Effective: ${EFFECTIVE_DATE}

1. PRIMARY STORAGE
Primary databases and backups are located in India to comply with:
• Digital Personal Data Protection Act, 2023.
• RBI Storage of Payment System Data (April 2018) — payment data is stored only in India.
• SEBI / IRDAI guidance where applicable.

2. SECONDARY PROCESSING
Limited operational data may be processed in:
• Singapore, Japan, the EU, the United States — for sub-processors (Supabase, payment, email/SMS, AI gateway).
All such transfers use SCCs / IDTA / DPDP §16 mechanisms with encryption in transit and at rest.

3. PAYMENT DATA
Card / UPI credentials are tokenised by PCI-DSS Level 1 processors and never stored on our servers. Aggregated transaction records are retained for 8 years as required by the Companies Act 2013 and GST Act.

4. KYC DATA (WOMEN)
PAN, Aadhaar (stored masked / last-4 only after verification), bank or UPI handle for identity matching, IFSC, and address proof are stored encrypted in India, segregated from operational tables, accessible only to authorised compliance staff under audit logging. KYC is collected for identity verification, anti-fraud, age confirmation, and statutory compliance — never as a basis for any monetary payment. Women earn only non-monetary in-app virtual coins.

5. USER CONSENT
By creating an account you provide express, informed consent under DPDP §6 / GDPR Art. 6 & 9 for storage in India and the cross-border transfers described above.

6. CERTIFICATIONS / FRAMEWORKS
Aligned with: ISO/IEC 27001:2022, ISO/IEC 27701, NIST CSF, SOC 2 Type II controls (sub-processor level).`
  },
  {
    id: "user_guidelines",
    title: "Community Guidelines",
    icon: <Users className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — COMMUNITY GUIDELINES
Effective: ${EFFECTIVE_DATE}

DO
• Be respectful and treat every user with dignity.
• Use truthful information and your real photo.
• Use the in-app translator — chat in any language.
• Block and report anyone who makes you uncomfortable.

DON'T
• No sexual, nude, semi-nude, suggestive, or pornographic content.
• No harassment, hate speech, threats, defamation, casteism, racism, communalism, or discrimination.
• No requests for or sharing of phone, Instagram, Snapchat, Telegram, email, address, UPI/Paytm/PhonePe/GPay, bank details, or any external contact.
• No requests for or offers of money, gifts, "loans", crypto, or investments.
• No prostitution, escort, sugar-baby, or commercial sexual services.
• No catfishing, impersonation, or use of someone else's photos.
• No spam, advertising, or promotion of third-party services.
• No bots, scripts, automation, or scraping.
• No content that exploits or endangers minors — instant ban + criminal report.
• No off-platform meet-ups arranged for sexual exploitation, trafficking, or abuse.

REPORTING
Use the in-app Report button or email report@meowmeow.app. Reports are reviewed within 24 hours; emergencies (CSAM, threats to life) are escalated immediately.`
  },
  {
    id: "anti_sexual_content",
    title: "Anti-Sexual Content & Child-Safety Policy",
    icon: <Ban className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — ANTI-SEXUAL CONTENT & CHILD-SAFETY POLICY
Effective: ${EFFECTIVE_DATE}

ZERO TOLERANCE — sending, soliciting, or hinting at any of the following results in IMMEDIATE permanent ban, forfeiture of wallet balance and virtual coins, and reporting to authorities:
• Erotic chat, sexual roleplay, sexting, "dirty talk".
• Nudity, semi-nudity, sexual imagery.
• Pornographic, obscene, or vulgar language.
• Sexual harassment, unsolicited sexual advances, sextortion.
• Non-consensual intimate imagery ("revenge porn") — covered by IT Act §66E, BNS §75, and similar global laws.
• Voyeurism, upskirt, or recordings without consent.
• Solicitation of prostitution, escort, sugar-baby, or commercial sexual services.

CHILD SEXUAL ABUSE MATERIAL (CSAM) — ZERO TOLERANCE
• Any content involving a minor (real or simulated, AI-generated included) is a criminal offence under:
  – Protection of Children from Sexual Offences Act 2012 (POCSO),
  – Information Technology Act 2000 §67B,
  – Bharatiya Nyaya Sanhita 2023,
  – US 18 USC §2252/2252A, UK Protection of Children Act 1978, EU Directive 2011/93/EU, and global equivalents.
• We hash-match against industry CSAM databases and proactively scan for such material.
• Discoveries are preserved and reported to:
  – National Cyber Crime Reporting Portal (cybercrime.gov.in),
  – NCMEC CyberTipline (United States),
  – INTERPOL ICSE,
  – Local police of the offender's jurisdiction.
• Account, IP, device fingerprint, payment info, and chat metadata are preserved as required by law.

LIVE-CALL ABUSE
Live audio/video calls are subject to the same rules. Recording and AI scanning may be performed for safety/abuse detection in compliance with applicable wiretap and privacy laws; users are notified before each call.

CONSENT
Even between consenting adults, sexual content is prohibited on this platform. Use a service designed for adult content elsewhere.`
  },
  {
    id: "payments_policy",
    title: "Payments, Refunds & Payouts",
    icon: <CreditCard className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — PAYMENTS, REFUNDS & PAYOUTS POLICY
Effective: ${EFFECTIVE_DATE}

A. WALLET RECHARGE (MEN)
• Recharge via Razorpay / Stripe / Paddle / authorised UPI in INR.
• Prices are inclusive of 18% GST under CGST/SGST/IGST Acts; GST invoice issued on request.
• Per-second pro-rated billing for chat, calls, and groups (rate card visible in-app).
• Wallet balance is non-transferable and tied to a single verified account.

B. REFUND POLICY
In line with the Consumer Protection Act 2019 and RBI guidelines:
• Recharges are non-refundable except where (i) duplicate charge, (ii) failed transaction with debit, (iii) verified system error.
• Refund requests must be raised within 7 days at billing@meowmeow.app; eligible refunds are processed within 7 working days to the original payment method.
• Unused coins are not refundable on account closure.

C. CHARGEBACKS / FRAUD
• Initiating a chargeback without contacting support first is treated as fraud.
• Result: permanent ban, blacklist with payment processors, forfeiture of balance, and possible legal action under BNS §316/318 (cheating), PMLA, and the Payment and Settlement Systems Act 2007.

D. WOMEN — VIRTUAL COINS ONLY (NO MONEY)
• Women DO NOT receive any payout, salary, fee, commission, or other monetary value from Meow MEOW FRND APP.
• Their participation is voluntary and personal; activity may be acknowledged with non-monetary in-app virtual coins.
• Virtual coins have NO cash value, are NOT redeemable, NOT transferable, NOT a currency, and NOT a financial instrument under any law.
• Women may be asked for KYC (PAN, Aadhaar, bank/UPI handle, IFSC, address proof, live selfie) for identity verification, anti-fraud, age confirmation, and statutory compliance — never as a basis for monetary payment. KYC documents are encrypted, access-logged, and never sold or shared with advertisers.

E. NO TAX EVENT FOR WOMEN
Because no money or money's worth is paid to women, no income, GST, TDS, Form 16A, or other tax obligation is generated by the platform on the women's side. Women are not "deductees" under §§194-O / 194-R / 194-S of the Income Tax Act 1961 in respect of Meow MEOW FRND APP activity.

F. ANTI-MONEY LAUNDERING
We comply with the Prevention of Money Laundering Act 2002 and FATF guidance on the inbound side (men's recharges). Suspicious recharge patterns are flagged and may be reported to FIU-IND. No outbound money flows to users.`
  },
  {
    id: "content_moderation",
    title: "Content Moderation & Enforcement",
    icon: <Eye className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — CONTENT MODERATION & ENFORCEMENT POLICY
Effective: ${EFFECTIVE_DATE}

1. WHAT WE MODERATE
Profile photos, display names, bio, chat messages, group names, call behaviour (where lawful), reports filed by users.

2. METHODS
• Pre-publication AI checks (face/gender, prohibited keywords, contact-detail patterns, abusive language).
• Real-time multilingual filters across 132+ languages.
• Post-publication user reports + 24-hour human review.
• Random audits of high-risk accounts.

3. ACTIONS
Tiered enforcement based on severity, history, and intent:
(i) Warning + content removal,
(ii) Temporary suspension (24 h – 30 days),
(iii) Permanent ban + forfeiture of wallet balance and virtual coins,
(iv) Shadow-restriction of visibility,
(v) Law-enforcement referral (CSAM, threats, fraud, trafficking).

4. APPEALS
Users may appeal any action within 30 days at appeals@meowmeow.app. Human reviewer (different from the original moderator) decides within 15 days, in line with IT Rules 2021 §3(2) and the EU Digital Services Act Art. 20 (where applicable).

5. TRANSPARENCY
We publish an annual transparency report summarising removals, suspensions, government requests, and CSAM reports.

6. STATUTORY COMPLIANCE
We act as an "intermediary" under IT Act 2000 §79 and observe due-diligence under IT (Intermediary Guidelines and Digital Media Ethics Code) Rules 2021. We will take down unlawful content within 36 hours of a valid court / government order, and within 24 hours for non-consensual intimate imagery (Rule 3(2)(b)).`
  },
  {
    id: "age_verification",
    title: "Age Verification (18+ Only)",
    icon: <UserCheck className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — AGE VERIFICATION POLICY
Effective: ${EFFECTIVE_DATE}

• Strict minimum age: 18 years (or higher local age of majority).
• Date of birth is collected at registration; AI age-estimation cross-checks the live selfie.
• Suspected underage accounts are immediately suspended; the user is asked for government-ID proof.
• If under-18 status is confirmed, the account and all data are deleted within 7 days, and where there is reason to believe the minor is at risk, a report is filed under POCSO 2012, IT Act §67B, and equivalent foreign laws.
• Misrepresentation of age is a fraud against the platform and may be a criminal offence (BNS §318 — cheating).
• Parents/guardians who discover that a minor created an account may write to safety@meowmeow.app for immediate removal.`
  },
  {
    id: "ai_disclosure",
    title: "AI Usage Disclosure",
    icon: <Bot className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — AI USAGE DISCLOSURE
Effective: ${EFFECTIVE_DATE}

We use artificial intelligence to keep the App safe, fair, and useful.

USED FOR
• Face & liveness detection (anti-spoofing).
• Gender estimation from selfie.
• Age estimation.
• Real-time language detection & translation across 100+ languages.
• Prohibited-content classification (sexual, violent, hateful, contact-info patterns).
• Fraud, bot, and abuse detection.

NOT USED FOR
• Final permanent-ban decisions without human review.
• Final virtual-coin grant or revocation without human review where significant.
• Profiling for advertising, political, or insurance pricing purposes.
• Sale of biometric or behavioural data to third parties.

GOVERNANCE
• Models are evaluated for bias on Indian skin tones, languages, and demographics.
• EU AI Act (Regulation 2024/1689): biometric categorisation and emotion-inference are limited to safety contexts permitted under Art. 5 / Annex III; users are informed when interacting with AI features.
• You can request human review of any AI-driven decision at ai-review@meowmeow.app within 30 days.`
  },
  {
    id: "data_retention",
    title: "Data Retention & Deletion",
    icon: <Clock className="w-4 h-4" />,
    required: true,
    content: `MEOW MEOW — DATA RETENTION & DELETION POLICY
Effective: ${EFFECTIVE_DATE}

Data Type                       | Retention
--------------------------------|------------------------------------------
Chat message bodies             | Auto-deleted every 15 minutes
Chat sessions metadata          | 30 days, then anonymised
Audio/video call recordings     | NOT recorded (signalling logs 30 days)
Account & profile               | Until deletion + 30-day grace period
Wallet ledger transactions      | 8 years (Companies Act, GST Act)
Virtual coin ledger (women)     | Lifetime of account (no monetary value)
Women's KYC documents           | Up to 8 years from last activity (PMLA / RBI)
Men's GST / payment receipts    | 8 years (Companies Act, GST Act)
Server / security logs          | 30–180 days
Abuse / fraud evidence          | 90 days, longer if under investigation
CSAM evidence                   | Preserved indefinitely for law enforcement
Court / government holds        | Until release order

DELETION RIGHT
Request account deletion any time from Settings or at privacy@meowmeow.app. We delete or anonymise all non-statutorily-retained data within 30 days, in compliance with DPDP §12, GDPR Art.17, CCPA / CPRA right-to-delete, and similar laws.

EXCEPTIONS
We may retain limited data where necessary to: (a) comply with law, (b) resolve disputes, (c) enforce agreements, (d) protect against fraud, (e) preserve evidence for criminal proceedings.`
  }
];

const TermsAgreementScreen = () => {
  const navigate = useNavigate();
  useRegistrationGuard([{ key: "userEmail" }, { key: "userPassword", storage: "session" }], "/password-setup");
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);
  const [expandedDoc, setExpandedDoc] = useState<string | undefined>("terms_of_service");
  const [consents, setConsents] = useState<Record<string, boolean>>({});
  const [agreeAll, setAgreeAll] = useState(false);

  const allRequiredAgreed = legalDocuments
    .filter(doc => doc.required)
    .every(doc => consents[doc.id]);

  const agreedCount = Object.values(consents).filter(Boolean).length;

  const handleToggleConsent = (docId: string) => {
    setConsents(prev => {
      const newConsents = { ...prev, [docId]: !prev[docId] };
      const allAgreed = legalDocuments.every(doc => newConsents[doc.id]);
      setAgreeAll(allAgreed);
      return newConsents;
    });
  };

  const handleAgreeAll = () => {
    const newAgreeAll = !agreeAll;
    setAgreeAll(newAgreeAll);
    const newConsents: Record<string, boolean> = {};
    legalDocuments.forEach(doc => {
      newConsents[doc.id] = newAgreeAll;
    });
    setConsents(newConsents);
  };

  const handleSubmit = async () => {
    if (!allRequiredAgreed) {
      toast({
        title: "Agreement required",
        description: "Please agree to all required policies to continue.",
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);

    try {
      // Get registration data from localStorage
      const email = sessionStorage.getItem("userEmail") || "";
      const password = sessionStorage.getItem("userPassword") || "";
      const fullName = sessionStorage.getItem("userName") || "";
      const gender = sessionStorage.getItem("userGender") || "";
      const phone = sessionStorage.getItem("userPhone") || "";

      // Re-validate password strength to prevent bypass via direct sessionStorage manipulation
      const passwordValid =
        password.length >= 8 &&
        /[A-Z]/.test(password) &&
        /[a-z]/.test(password) &&
        /[0-9]/.test(password) &&
        /[!@#$%^&*(),.?":{}|<>]/.test(password);

      if (!email || !password || !passwordValid) {
        toast({
          title: "Registration incomplete",
          description: !passwordValid && password
            ? "Password does not meet strength requirements. Please go back and set a valid password."
            : "Please complete all registration steps.",
          variant: "destructive",
        });
        navigate(passwordValid ? "/register" : "/password-setup", { replace: true });
        return;
      }

      if (!gender) {
        toast({
          title: "Gender required",
          description: "Please go back and select your gender.",
          variant: "destructive",
        });
        navigate("/basic-info");
        return;
      }

      // Create user account with Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: email,
        password: password,
        options: {
          emailRedirectTo: `${window.location.origin}/`,
          data: {
            full_name: fullName,
            gender: gender,
            phone: phone,
          }
        }
      });

      if (authError) {
        console.error("Auth error:", authError);
        toast({
          title: "Registration failed",
          description: authError.message || "Failed to create account. Please try again.",
          variant: "destructive",
        });
        setIsLoading(false);
        return;
      }

      const user = authData.user;

      if (!user) {
        toast({
          title: "Registration failed",
          description: "Failed to create account. Please try again.",
          variant: "destructive",
        });
        setIsLoading(false);
        return;
      }

      // Check if user already exists (identities is empty means duplicate email)
      if (user.identities?.length === 0) {
        toast({
          title: "Email already registered",
          description: "This email is already registered. Please try logging in instead.",
          variant: "destructive",
        });
        setIsLoading(false);
        return;
      }

      // Sign in the user immediately after signup to get a session
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email,
        password: password,
      });

      if (signInError) {
        console.error("Sign in error:", signInError);
        toast({
          title: "Login failed",
          description: "Account created but couldn't sign in. Please try logging in manually.",
          variant: "destructive",
        });
        navigate("/");
        return;
      }

      // Save all consent data
      const { error: consentError } = await supabase
        .from("user_consent")
        .upsert({
          user_id: user.id,
          agreed_terms: consents.terms_of_service,
          gdpr_consent: consents.gdpr_compliance,
          ccpa_consent: consents.gdpr_compliance,
          dpdp_consent: consents.data_storage_policy,
          terms_version: "1.0",
          consent_timestamp: new Date().toISOString(),
          user_agent: navigator.userAgent,
        });

      if (consentError) throw consentError;

      // Get remaining registration data from localStorage
      const dateOfBirth = sessionStorage.getItem("userDob") || sessionStorage.getItem("userDateOfBirth") || "";
      const countryCode = sessionStorage.getItem("userCountry") || "";
      const stateCode = sessionStorage.getItem("userState") || "";
      const city = sessionStorage.getItem("userCity") || "";
      const latitude = sessionStorage.getItem("userLatitude");
      const longitude = sessionStorage.getItem("userLongitude");
      const languageCode = sessionStorage.getItem("selectedLanguage") || sessionStorage.getItem("userPrimaryLanguage") || "";
      const pendingPhotoData = sessionStorage.getItem("pendingPhotoData") || "";
      const pendingAdditionalPhotos = JSON.parse(sessionStorage.getItem("pendingAdditionalPhotos") || "[]");

      // Convert country code to full name
      const countryData = countries.find(c => c.code === countryCode);
      const countryName = countryData?.name || countryCode;

      // Convert state code to full name
      let stateName = stateCode;
      if (countryCode && stateCode) {
        const statesForCountry = getStatesForCountry(countryCode);
        const stateData = statesForCountry.find(s => s.code === stateCode);
        stateName = stateData?.name || stateCode;
      }

      // Convert language code to full name
      const languageData = languages.find(l => l.code === languageCode);
      const languageName = languageData?.name || languageCode;
      
      // Get personal details from PersonalDetailsScreen
      const personalDetails = JSON.parse(sessionStorage.getItem("userPersonalDetails") || "{}");

      // Calculate age from DOB
      let age: number | null = null;
      if (dateOfBirth) {
        const dob = new Date(dateOfBirth);
        const today = new Date();
        age = today.getFullYear() - dob.getFullYear();
        const monthDiff = today.getMonth() - dob.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) {
          age--;
        }
      }

      // Upload selfie photo if exists
      let photoUrl: string | null = null;
      if (pendingPhotoData && pendingPhotoData.startsWith("data:image")) {
        const base64Data = pendingPhotoData.split(",")[1];
        const byteCharacters = atob(base64Data);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: "image/jpeg" });
        
        const fileName = `${user.id}/selfie_${Date.now()}.jpg`;
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from("profile-photos")
          .upload(fileName, blob, { contentType: "image/jpeg", upsert: true });
        
        if (!uploadError && uploadData) {
          const { data: urlData } = supabase.storage.from("profile-photos").getPublicUrl(fileName);
          photoUrl = urlData.publicUrl;
        }
      }

      // Build complete profile data including ALL registration fields
      const profileData: any = {
        user_id: user.id,
        email: email, // Store email in profiles table
        full_name: fullName,
        gender: gender.toLowerCase(),
        phone: phone,
        date_of_birth: dateOfBirth || null,
        age: age,
        country: countryName,
        state: stateName,
        city: city || null,
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        primary_language: languageName,
        preferred_language: languageName, // Also set preferred language
        photo_url: photoUrl,
        // Personal details from PersonalDetailsScreen
        bio: personalDetails.bio || null,
        height_cm: personalDetails.height_cm || null,
        occupation: personalDetails.occupation || null,
        body_type: personalDetails.body_type || null,
        education_level: personalDetails.education_level || null,
        marital_status: personalDetails.marital_status || null,
        religion: personalDetails.religion || null,
        smoking_habit: personalDetails.smoking_habit || null,
        drinking_habit: personalDetails.drinking_habit || null,
        dietary_preference: personalDetails.dietary_preference || null,
        fitness_level: personalDetails.fitness_level || null,
        has_children: personalDetails.has_children || null,
        pet_preference: personalDetails.pet_preference || null,
        travel_frequency: personalDetails.travel_frequency || null,
        personality_type: personalDetails.personality_type || null,
        zodiac_sign: personalDetails.zodiac_sign || null,
        interests: personalDetails.interests || [],
        life_goals: personalDetails.life_goals || [],
        account_status: "active",
        approval_status: gender.toLowerCase() === "female" ? "pending" : "approved",
        updated_at: new Date().toISOString(),
      };

      // Save to profiles table (upsert with retry for resilience)
      let profileError: any = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        const { error } = await supabase
          .from("profiles")
          .upsert(profileData, { onConflict: "user_id" });
        profileError = error;
        if (!error) break;
        if (attempt < 3) await new Promise(r => setTimeout(r, 1000 * attempt));
      }

      if (profileError) {
        console.error("Profile creation failed after retries:", profileError);
        // Sign out to prevent broken logged-in state with no profile
        await supabase.auth.signOut();
        toast({
          title: "Registration failed",
          description: "Account was created but profile setup failed. Please try registering again.",
          variant: "destructive",
        });
        navigate("/");
        return;
      }

      // NOTE: Profile data is synced to gender-specific tables (male_profiles/female_profiles)
      // via database trigger. Languages support all 386+ languages from languages.ts
      // The trigger automatically syncs primary_language and preferred_language fields

      // Save selfie as primary photo in user_photos
      if (photoUrl) {
        await supabase.from("user_photos").upsert({
          user_id: user.id,
          photo_url: photoUrl,
          photo_type: "selfie",
          is_primary: true,
          display_order: 0,
        }, { onConflict: "user_id,photo_url" });
      }

      // Upload and save additional photos
      for (let i = 0; i < pendingAdditionalPhotos.length; i++) {
        const photoData = pendingAdditionalPhotos[i];
        if (photoData && photoData.startsWith("data:image")) {
          const base64Data = photoData.split(",")[1];
          const byteCharacters = atob(base64Data);
          const byteNumbers = new Array(byteCharacters.length);
          for (let j = 0; j < byteCharacters.length; j++) {
            byteNumbers[j] = byteCharacters.charCodeAt(j);
          }
          const byteArray = new Uint8Array(byteNumbers);
          const blob = new Blob([byteArray], { type: "image/jpeg" });
          
          const fileName = `${user.id}/photo_${i + 1}_${Date.now()}.jpg`;
          const { data: uploadData, error: uploadError } = await supabase.storage
            .from("profile-photos")
            .upload(fileName, blob, { contentType: "image/jpeg", upsert: true });
          
          if (!uploadError && uploadData) {
            const { data: urlData } = supabase.storage.from("profile-photos").getPublicUrl(fileName);
            await supabase.from("user_photos").insert({
              user_id: user.id,
              photo_url: urlData.publicUrl,
              photo_type: "gallery",
              is_primary: false,
              display_order: i + 1,
            });
          }
        }
      }

      // Create wallet for user (unified wallets table)
      await supabase.from("wallets").upsert({
        user_id: user.id,
        balance: 0,
        currency: "INR",
        gender: gender.toLowerCase() === "female" ? "women" : "men",
      }, { onConflict: "user_id" });

      // Save language preferences from LanguagePreferencesScreen to user_languages table
      const savedLanguagePrefs = sessionStorage.getItem("userLanguagePreferences");
      if (savedLanguagePrefs) {
        try {
          const langPrefs = JSON.parse(savedLanguagePrefs) as Array<{ code: string; name: string }>;
          if (langPrefs.length > 0) {
            const langRecords = langPrefs.map((lang) => ({
              user_id: user.id,
              language_code: lang.code,
              language_name: lang.name,
            }));
            await supabase.from("user_languages").upsert(langRecords, { onConflict: "user_id,language_code" });
          }
        } catch {
          // Non-critical - language preferences can be set later from settings
        }
      }

      toast({
        title: "Registration Complete!",
        description: "Your account is being verified.",
      });

      // Navigate to AI processing for verification
      navigate("/ai-processing");
    } catch (error) {
      console.error("Error saving registration:", error);
      toast({
        title: "Error",
        description: "Failed to complete registration. Please try again.",
        variant: "destructive",
      });
    } finally {
      // Always clear sensitive registration data regardless of success/failure
      const registrationKeys = [
        "pendingPhotoData", "pendingAdditionalPhotos", "userName", "userEmail",
        "userPhone", "userGender", "userDob", "userDateOfBirth", "userCountry",
        "userState", "userCity", "userLatitude", "userLongitude",
        "userPrimaryLanguage", "userLanguagePreferences", "userPersonalDetails",
      ];
      registrationKeys.forEach(key => sessionStorage.removeItem(key));
      sessionStorage.removeItem("userPassword");
      sessionStorage.removeItem("selectedLanguage");
      sessionStorage.removeItem("selectedCountry");
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      {/* Aurora Background */}
      <Suspense fallback={
        <div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />
      }>
        <AuroraBackground />
      </Suspense>

      {/* Header */}
      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex items-center gap-4 mb-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => navigate("/password-setup")}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={9} totalSteps={10} />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6 relative z-10">
        <Card className="w-full max-w-2xl p-6 md:p-8 space-y-6 bg-card/70 backdrop-blur-xl border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 mb-4">
              <FileText className="w-8 h-8 text-primary" />
            </div>
            <h1 className="text-2xl font-display font-bold text-foreground">Final Step: Legal Agreements</h1>
            <p className="text-muted-foreground">
              Please read and accept all 12 policies to complete your registration
            </p>
            <div className="flex items-center justify-center gap-2 mt-2">
              <div className={`px-3 py-1 rounded-full text-sm font-medium ${
                allRequiredAgreed 
                  ? 'bg-accent/10 text-accent' 
                  : 'bg-muted text-muted-foreground'
              }`}>
                {agreedCount}/{legalDocuments.length} Accepted
              </div>
            </div>
          </div>

          {/* Agree All Checkbox */}
          <label
            className={`flex items-center gap-3 p-4 rounded-xl border transition-all cursor-pointer ${
              agreeAll
                ? "border-emerald-500 bg-emerald-500/10"
                : "border-border hover:border-primary/50"
            }`}
          >
            <Checkbox
              checked={agreeAll}
              onCheckedChange={handleAgreeAll}
              className="data-[state=checked]:bg-emerald-500 data-[state=checked]:border-emerald-500"
            />
            <div className="flex-1">
              <span className="font-semibold text-foreground">
                I agree to ALL policies and terms
              </span>
              <p className="text-sm text-muted-foreground">
                Check this to accept all {legalDocuments.length} legal documents at once
              </p>
            </div>
            {agreeAll && (
              <CheckCircle2 className="w-5 h-5 text-emerald-500" />
            )}
          </label>

          {/* Legal Documents Accordion */}
          <ScrollArea className="h-[400px] rounded-xl border border-border bg-muted/20 p-4">
            <Accordion 
              type="single" 
              collapsible 
              value={expandedDoc}
              onValueChange={setExpandedDoc}
              className="space-y-2"
            >
              {legalDocuments.map((doc) => (
                <AccordionItem 
                  key={doc.id} 
                  value={doc.id}
                  className={`border rounded-lg px-4 transition-all ${
                    consents[doc.id] 
                      ? 'border-emerald-500/50 bg-emerald-500/5' 
                      : 'border-border bg-card/50'
                  }`}
                >
                  <AccordionTrigger className="hover:no-underline py-3">
                    <div className="flex items-center gap-3 flex-1">
                      <div className={`p-2 rounded-lg ${
                        consents[doc.id] 
                          ? 'bg-emerald-500/10 text-emerald-500' 
                          : 'bg-muted text-muted-foreground'
                      }`}>
                        {doc.icon}
                      </div>
                      <span className="font-medium text-foreground text-left">
                        {doc.title}
                      </span>
                      {doc.required && (
                        <span className="text-xs text-destructive">*Required</span>
                      )}
                      {consents[doc.id] && (
                        <Check className="w-4 h-4 text-emerald-500 ml-auto mr-2" />
                      )}
                    </div>
                  </AccordionTrigger>
                  <AccordionContent className="pb-4">
                    <div className="bg-muted/50 rounded-lg p-4 mb-4 max-h-48 overflow-y-auto">
                      <pre className="text-sm text-muted-foreground whitespace-pre-wrap font-sans">
                        {doc.content}
                      </pre>
                    </div>
                    <label
                      className={`flex items-center gap-3 p-3 rounded-lg border transition-all cursor-pointer ${
                        consents[doc.id]
                          ? "border-emerald-500 bg-emerald-500/10"
                          : "border-border hover:border-primary/50"
                      }`}
                    >
                      <Checkbox
                        checked={consents[doc.id] || false}
                        onCheckedChange={() => handleToggleConsent(doc.id)}
                        className="data-[state=checked]:bg-emerald-500 data-[state=checked]:border-emerald-500"
                      />
                      <span className="text-sm font-medium text-foreground">
                        I have read and agree to the {doc.title}
                      </span>
                    </label>
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </ScrollArea>

          {/* Submit Button */}
          <div className="flex gap-3">
            <Button
              variant="auroraOutline"
              onClick={() => navigate("/password-setup")}
              className="flex-1 h-12"
            >
              Back
            </Button>
            <Button
              variant="aurora"
              onClick={handleSubmit}
              disabled={isLoading || !allRequiredAgreed}
              className="flex-1 h-12 text-base font-medium"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <CheckCircle2 className="w-5 h-5 mr-2" />
                  Accept All & Continue
                </>
              )}
            </Button>
          </div>

          {/* Footer Note */}
          <p className="text-xs text-center text-muted-foreground">
            By completing registration, your consent to all 12 documents will be recorded with a timestamp for GDPR, CCPA, and DPDP compliance.
            You can withdraw consent at any time from Settings.
          </p>
        </Card>
      </main>
    </div>
  );
};

export default TermsAgreementScreen;
