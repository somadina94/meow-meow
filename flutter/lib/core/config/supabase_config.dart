/// Supabase Configuration
/// 
/// TEC-C-01: Credentials are now read from environment variables at build time.
/// Pass them via --dart-define:
///   flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
/// 
/// For production builds:
///   flutter build apk --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase Project URL — read from environment or fallback for dev
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://www.meow-meow.co.in:8443',
  );
  
  /// Alias for backward compatibility
  static const String supabaseUrl = url;

  /// Supabase Anonymous Key (publishable, safe for client)
  /// In production, pass via --dart-define to avoid hardcoding
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A',
  );
  
  /// Alias for backward compatibility
  static const String supabaseAnonKey = anonKey;

  /// Storage bucket names
  static const String profilePhotosBucket = 'profile-photos';
  static const String voiceMessagesBucket = 'voice-messages';
  static const String legalDocumentsBucket = 'legal-documents';

  /// Realtime channels
  static const String chatChannel = 'chat_messages';
  static const String presenceChannel = 'user_presence';
  static const String notificationsChannel = 'notifications';
}
