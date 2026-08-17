import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale Provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setLocale(Locale locale) {
    state = locale;
  }

  void setLocaleByCode(String code) {
    state = Locale(code);
  }
}

/// Supported Locales
const supportedLocales = [
  Locale('en'), // English
  Locale('hi'), // Hindi
  Locale('ar'), // Arabic
  Locale('bn'), // Bengali
  Locale('es'), // Spanish
  Locale('fr'), // French
  Locale('gu'), // Gujarati
  Locale('kn'), // Kannada
  Locale('ml'), // Malayalam
  Locale('mr'), // Marathi
  Locale('or'), // Odia
  Locale('pa'), // Punjabi
  Locale('ta'), // Tamil
  Locale('te'), // Telugu
  Locale('ur'), // Urdu
  Locale('zh'), // Chinese
];
