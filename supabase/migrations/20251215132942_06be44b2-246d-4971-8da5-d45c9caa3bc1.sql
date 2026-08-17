-- Insert currency rates setting into app_settings
INSERT INTO app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'currency_rates',
  '{
    "IN": {"rate": 1, "symbol": "₹", "code": "INR"},
    "US": {"rate": 0.012, "symbol": "$", "code": "USD"},
    "GB": {"rate": 0.0095, "symbol": "£", "code": "GBP"},
    "EU": {"rate": 0.011, "symbol": "€", "code": "EUR"},
    "AE": {"rate": 0.044, "symbol": "د.إ", "code": "AED"},
    "AU": {"rate": 0.018, "symbol": "A$", "code": "AUD"},
    "CA": {"rate": 0.016, "symbol": "C$", "code": "CAD"},
    "JP": {"rate": 1.79, "symbol": "¥", "code": "JPY"},
    "SG": {"rate": 0.016, "symbol": "S$", "code": "SGD"},
    "MY": {"rate": 0.053, "symbol": "RM", "code": "MYR"},
    "PH": {"rate": 0.67, "symbol": "₱", "code": "PHP"},
    "TH": {"rate": 0.41, "symbol": "฿", "code": "THB"},
    "SA": {"rate": 0.045, "symbol": "﷼", "code": "SAR"},
    "QA": {"rate": 0.044, "symbol": "ر.ق", "code": "QAR"},
    "KW": {"rate": 0.0037, "symbol": "د.ك", "code": "KWD"},
    "BD": {"rate": 1.31, "symbol": "৳", "code": "BDT"},
    "PK": {"rate": 3.34, "symbol": "Rs", "code": "PKR"},
    "NP": {"rate": 1.59, "symbol": "रू", "code": "NPR"},
    "LK": {"rate": 3.66, "symbol": "Rs", "code": "LKR"},
    "DEFAULT": {"rate": 0.012, "symbol": "$", "code": "USD"}
  }',
  'json',
  'payments',
  'Currency conversion rates from INR to other currencies',
  true
)
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = EXCLUDED.setting_value,
  updated_at = now();

-- Insert payment gateways setting
INSERT INTO app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES (
  'payment_gateways',
  '{
    "indian": [
      {"id": "razorpay", "name": "Razorpay", "logo": "🇮🇳", "description": "UPI, Cards, Netbanking", "features": ["UPI", "Debit/Credit Cards", "Netbanking", "Wallets"]},
      {"id": "ccavenue", "name": "CCAvenue", "logo": "🏦", "description": "Cards, Wallets, EMI", "features": ["Cards", "EMI", "Wallets", "Netbanking"]}
    ],
    "international": [
      {"id": "stripe", "name": "Stripe", "logo": "💎", "description": "Cards, Apple Pay, Google Pay", "features": ["Cards", "Apple Pay", "Google Pay", "Bank Transfers"]},
      {"id": "paypal", "name": "PayPal", "logo": "🅿️", "description": "200+ countries supported", "features": ["PayPal Balance", "Cards", "Bank Account"]},
      {"id": "wise", "name": "Wise", "logo": "💸", "description": "International Transfers", "features": ["Bank Transfer", "Low Fees", "Multi-currency"]},
      {"id": "adyen", "name": "Adyen", "logo": "🌐", "description": "Global Payments", "features": ["Cards", "Local Methods", "Digital Wallets"]}
    ]
  }',
  'json',
  'payments',
  'Supported payment gateways for different regions',
  true
)
ON CONFLICT (setting_key) DO UPDATE SET
  setting_value = EXCLUDED.setting_value,
  updated_at = now();

-- Drop sample tables (not needed - they contain mock data)
DROP TABLE IF EXISTS sample_men CASCADE;
DROP TABLE IF EXISTS sample_women CASCADE;
DROP TABLE IF EXISTS sample_users CASCADE;