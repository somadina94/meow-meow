import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_token_service.dart';
import 'core/services/video_call_circuit_breaker.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/widgets/idle_timeout_wrapper.dart';
import 'core/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Initialize notifications
  await NotificationService.initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: MeowMeowApp(),
    ),
  );
}

class MeowMeowApp extends ConsumerStatefulWidget {
  const MeowMeowApp({super.key});

  @override
  ConsumerState<MeowMeowApp> createState() => _MeowMeowAppState();
}

class _MeowMeowAppState extends ConsumerState<MeowMeowApp> {
  @override
  void initState() {
    super.initState();
    // Boot the call CPU circuit breaker.
    VideoCallCircuitBreaker.instance.startMonitoring();
    // Register FCM token whenever the user signs in.
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        ref.read(pushTokenServiceProvider).registerForCurrentUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentTheme = ref.watch(currentThemeProvider);

    return MaterialApp.router(
      title: 'Meow Meow',
      debugShowCheckedModeBanner: false,
      theme: currentTheme.toThemeData(Brightness.light),
      darkTheme: currentTheme.toThemeData(Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) =>
          IdleTimeoutWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}
