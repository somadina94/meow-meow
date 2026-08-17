import 'package:flutter/material.dart';

/// App Localizations
/// 
/// Placeholder for localization support.
/// In production, use flutter_localizations with ARB files.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ar'),
    Locale('bn'),
    Locale('es'),
    Locale('fr'),
    Locale('gu'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('or'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
    Locale('ur'),
    Locale('zh'),
  ];

  // Add translation methods here
  String get appName => 'Meow Meow';
  String get login => 'Login';
  String get signUp => 'Sign Up';
  String get email => 'Email';
  String get password => 'Password';
  String get forgotPassword => 'Forgot Password?';
  String get dashboard => 'Dashboard';
  String get profile => 'Profile';
  String get settings => 'Settings';
  String get wallet => 'Wallet';
  String get chat => 'Chat';
  String get matches => 'Matches';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
