import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Currency Rate Model
class CurrencyRate {
  final double rate;
  final String symbol;
  final String code;

  const CurrencyRate({
    required this.rate,
    required this.symbol,
    required this.code,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    return CurrencyRate(
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      symbol: json['symbol'] as String? ?? '₹',
      code: json['code'] as String? ?? 'INR',
    );
  }
}

/// Payment Gateway Model
class PaymentGateway {
  final String id;
  final String name;
  final String logo;
  final String description;
  final List<String> features;

  const PaymentGateway({
    required this.id,
    required this.name,
    required this.logo,
    required this.description,
    this.features = const [],
  });

  factory PaymentGateway.fromJson(Map<String, dynamic> json) {
    return PaymentGateway(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logo: json['logo'] as String? ?? '💰',
      description: json['description'] as String? ?? '',
      features: (json['features'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// App Settings Model - synced with PWA useAppSettings hook
class AppSettings {
  final List<int> rechargeAmounts;
  final List<int> withdrawalAmounts;
  final List<String> supportedCurrencies;
  final String defaultCurrency;
  final int withdrawalProcessingHours;
  final Map<String, CurrencyRate> currencyRates;
  final List<PaymentGateway> indianGateways;
  final List<PaymentGateway> internationalGateways;
  final int maxParallelChats;
  final int maxReconnectAttempts;
  final int maxMessageLength;
  final int minVideoCallBalance;
  final int sessionTimeoutMinutes;
  final int maxFileUploadMb;

  const AppSettings({
    this.rechargeAmounts = const [100, 500, 1000, 2000, 5000, 10000],
    this.withdrawalAmounts = const [500, 1000, 2000, 5000, 10000],
    this.supportedCurrencies = const ['INR', 'USD', 'EUR'],
    this.defaultCurrency = 'INR',
    this.withdrawalProcessingHours = 24,
    this.currencyRates = const {},
    this.indianGateways = const [],
    this.internationalGateways = const [],
    this.maxParallelChats = 3,
    this.maxReconnectAttempts = 3,
    this.maxMessageLength = 2000,
    this.minVideoCallBalance = 50,
    this.sessionTimeoutMinutes = 30,
    this.maxFileUploadMb = 10,
  });

  List<PaymentGateway> get allGateways => [...indianGateways, ...internationalGateways];

  CurrencyRate getCurrencyForCountry(String countryCode) {
    return currencyRates[countryCode] ?? 
           currencyRates['DEFAULT'] ?? 
           const CurrencyRate(rate: 0.012, symbol: '\$', code: 'USD');
  }
}

/// App Settings Service Provider
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

/// App Settings Provider - fetches and caches settings
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final service = ref.watch(appSettingsServiceProvider);
  return service.fetchSettings();
});

/// App Settings Service
/// 
/// Fetches dynamic application settings from the database.
/// Synced with PWA useAppSettings hook - no hardcoded values.
class AppSettingsService {
  final SupabaseClient _client = Supabase.instance.client;

  // Setting key to property mapping
  static const _settingKeyMap = {
    'recharge_amounts': 'rechargeAmounts',
    'withdrawal_amounts': 'withdrawalAmounts',
    'supported_currencies': 'supportedCurrencies',
    'default_currency': 'defaultCurrency',
    'withdrawal_processing_hours': 'withdrawalProcessingHours',
    'currency_rates': 'currencyRates',
    'payment_gateways': 'paymentGateways',
    'max_parallel_chats': 'maxParallelChats',
    'max_reconnect_attempts': 'maxReconnectAttempts',
    'max_message_length': 'maxMessageLength',
    'min_video_call_balance': 'minVideoCallBalance',
    'session_timeout_minutes': 'sessionTimeoutMinutes',
    'max_file_upload_mb': 'maxFileUploadMb',
  };

  /// Fetch all public settings from database
  Future<AppSettings> fetchSettings() async {
    try {
      final response = await _client
          .from('app_settings')
          .select('setting_key, setting_value, setting_type')
          .eq('is_public', true);

      final settings = <String, dynamic>{};

      for (final row in response as List) {
        final key = row['setting_key'] as String;
        final propertyName = _settingKeyMap[key];
        if (propertyName != null) {
          dynamic value = row['setting_value'];
          settings[propertyName] = value;
        }
      }

      return _parseSettings(settings);
    } catch (e) {
      // Return default settings on error
      return const AppSettings();
    }
  }

  AppSettings _parseSettings(Map<String, dynamic> data) {
    // Parse currency rates
    Map<String, CurrencyRate> currencyRates = {};
    if (data['currencyRates'] != null) {
      final ratesData = data['currencyRates'] as Map<String, dynamic>;
      ratesData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          currencyRates[key] = CurrencyRate.fromJson(value);
        }
      });
    }

    // Parse payment gateways
    List<PaymentGateway> indianGateways = [];
    List<PaymentGateway> internationalGateways = [];
    if (data['paymentGateways'] != null) {
      final gatewaysData = data['paymentGateways'] as Map<String, dynamic>;
      if (gatewaysData['indian'] != null) {
        indianGateways = (gatewaysData['indian'] as List)
            .map((g) => PaymentGateway.fromJson(g as Map<String, dynamic>))
            .toList();
      }
      if (gatewaysData['international'] != null) {
        internationalGateways = (gatewaysData['international'] as List)
            .map((g) => PaymentGateway.fromJson(g as Map<String, dynamic>))
            .toList();
      }
    }

    return AppSettings(
      rechargeAmounts: (data['rechargeAmounts'] as List?)?.cast<int>() ?? 
                       const [100, 500, 1000, 2000, 5000, 10000],
      withdrawalAmounts: (data['withdrawalAmounts'] as List?)?.cast<int>() ?? 
                         const [500, 1000, 2000, 5000, 10000],
      supportedCurrencies: (data['supportedCurrencies'] as List?)?.cast<String>() ?? 
                           const ['INR', 'USD', 'EUR'],
      defaultCurrency: data['defaultCurrency'] as String? ?? 'INR',
      withdrawalProcessingHours: data['withdrawalProcessingHours'] as int? ?? 24,
      currencyRates: currencyRates,
      indianGateways: indianGateways,
      internationalGateways: internationalGateways,
      maxParallelChats: data['maxParallelChats'] as int? ?? 3,
      maxReconnectAttempts: data['maxReconnectAttempts'] as int? ?? 3,
      maxMessageLength: data['maxMessageLength'] as int? ?? 2000,
      minVideoCallBalance: data['minVideoCallBalance'] as int? ?? 50,
      sessionTimeoutMinutes: data['sessionTimeoutMinutes'] as int? ?? 30,
      maxFileUploadMb: data['maxFileUploadMb'] as int? ?? 10,
    );
  }

  /// Subscribe to settings changes
  RealtimeChannel subscribeToSettings(void Function() onUpdate) {
    return _client.channel('app_settings_changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'app_settings',
      callback: (_) => onUpdate(),
    ).subscribe();
  }
}
