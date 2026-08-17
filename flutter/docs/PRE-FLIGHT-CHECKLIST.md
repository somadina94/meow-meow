# Flutter App Pre-Flight Checklist

Complete this checklist to ensure your Flutter app is ready for development and production.

## 1. Environment Setup

### Prerequisites
- [ ] Flutter SDK 3.16+ installed (`flutter --version`)
- [ ] Dart SDK 3.2+ installed
- [ ] Xcode 15+ (for iOS) with Command Line Tools
- [ ] Android Studio with Android SDK 34+
- [ ] CocoaPods installed (`sudo gem install cocoapods`)

### IDE Setup
- [ ] VS Code with Flutter extension OR Android Studio with Flutter plugin
- [ ] Dart DevTools configured

## 2. Project Setup

### Create Flutter Project
```bash
flutter create meow_meow --org com.meowmeow
cd meow_meow
```

### Copy Project Files
```bash
# Copy all files from flutter/ directory to your new project
cp -r flutter/lib/* meow_meow/lib/
cp flutter/pubspec.yaml meow_meow/pubspec.yaml
cp -r flutter/assets/* meow_meow/assets/  # if exists
```

### Install Dependencies
```bash
flutter pub get
```

### Generate Code (Freezed Models)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 3. Supabase Configuration

### Update Credentials
Edit `lib/core/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://www.meow-meow.co.in:8443';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

### Verify Connection
- [ ] Supabase URL is correct
- [ ] Anon key is correct
- [ ] Test connection by running app and checking auth

## 4. Firebase Setup (Push Notifications)

### Android Setup
1. [ ] Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. [ ] Add Android app with package name `com.meowmeow.meow_meow`
3. [ ] Download `google-services.json`
4. [ ] Place in `android/app/google-services.json`
5. [ ] Update `android/build.gradle`:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
   }
   ```
6. [ ] Update `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### iOS Setup
1. [ ] Add iOS app in Firebase console
2. [ ] Download `GoogleService-Info.plist`
3. [ ] Add to `ios/Runner/` via Xcode (drag and drop)
4. [ ] Enable Push Notifications capability in Xcode
5. [ ] Enable Background Modes > Remote notifications

## 5. Agora Video Calling Setup

### Get Agora Credentials
1. [ ] Create account at [agora.io](https://www.agora.io)
2. [ ] Create new project
3. [ ] Get App ID and App Certificate

### Configure in App
Edit video call service with Agora credentials:
```dart
static const String agoraAppId = 'YOUR_AGORA_APP_ID';
```

### Platform Permissions
Already configured in:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## 6. Platform-Specific Configuration

### Android (`android/app/build.gradle`)
- [ ] `minSdkVersion 21` or higher
- [ ] `targetSdkVersion 34`
- [ ] `compileSdkVersion 34`
- [ ] Internet permission added
- [ ] Camera permission added
- [ ] Microphone permission added
- [ ] Storage permissions added

### iOS (`ios/Runner/Info.plist`)
- [ ] Camera usage description
- [ ] Microphone usage description
- [ ] Photo library usage description
- [ ] Location usage description (if needed)
- [ ] Background modes configured

## 7. App Assets

### Generate App Icons
```bash
flutter pub run flutter_launcher_icons
```

Ensure `flutter_launcher_icons` is in `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

### Generate Splash Screen
```bash
flutter pub run flutter_native_splash:create
```

## 8. Testing Checklist

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing
- [ ] App launches without crashes
- [ ] Login/Register works
- [ ] Profile creation works
- [ ] Chat messaging works (send/receive)
- [ ] Real-time updates work
- [ ] Push notifications work
- [ ] Video calling works
- [ ] Wallet transactions work
- [ ] Gift sending works
- [ ] Settings save correctly
- [ ] Logout works

## 9. Build Verification

### Debug Build
```bash
# Android
flutter build apk --debug

# iOS
flutter build ios --debug
```

### Release Build
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 10. Pre-Launch Checklist

### Code Quality
- [ ] No compiler warnings
- [ ] No lint errors (`flutter analyze`)
- [ ] All TODO comments resolved
- [ ] Debug prints removed
- [ ] API keys not hardcoded (use environment variables)

### Security
- [ ] Supabase RLS policies in place
- [ ] Secure storage for sensitive data
- [ ] Certificate pinning (optional)
- [ ] ProGuard/R8 enabled for Android release

### Performance
- [ ] Images optimized
- [ ] Lazy loading implemented
- [ ] Memory leaks checked
- [ ] App size optimized

### Store Requirements
- [ ] Privacy policy URL ready
- [ ] Terms of service URL ready
- [ ] App screenshots prepared
- [ ] App description written
- [ ] Age rating determined

## 11. Database Tables Used

The Flutter app connects to these Supabase tables:

| Table | Purpose |
|-------|---------|
| `profiles` | User profile data |
| `male_profiles` | Male user extended profiles |
| `female_profiles` | Female user extended profiles |
| `chat_messages` | Real-time chat messages |
| `wallets` | User wallet balances |
| `wallet_transactions` | Transaction history |
| `gifts` | Available gifts catalog |
| `gift_transactions` | Gift sending records |
| `matches` | User matches |
| `user_status` | Online/offline status |
| `shifts` | Women's work shifts |
| `scheduled_shifts` | Scheduled shifts |
| `attendance` | Shift attendance |
| `notifications` | Push notification records |
| `user_settings` | App settings |
| `video_call_sessions` | Video call records |
| `private_groups` | Group chat rooms |
| `group_messages` | Group chat messages |

## 12. Edge Functions Used

| Function | Purpose |
|----------|---------|
| `chat-manager` | Handles chat billing |
| `translate-message` | Real-time translation |
| `verify-photo` | Photo verification |
| `video-call-server` | Video call signaling |
| `ai-women-approval` | AI profile approval |
| `content-moderation` | Message moderation |
| `reset-password` | Password reset flow |
| `shift-scheduler` | Shift management |

## 13. Common Issues & Solutions

### Build Errors

**Gradle sync failed (Android)**
```bash
cd android && ./gradlew clean && cd ..
flutter clean
flutter pub get
```

**CocoaPods error (iOS)**
```bash
cd ios && pod deintegrate && pod install && cd ..
```

**Freezed generation errors**
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Runtime Errors

**Supabase connection failed**
- Verify URL and anon key
- Check internet connection
- Ensure Supabase project is active

**Push notifications not working**
- Verify Firebase configuration
- Check device token registration
- Test with Firebase console

**Video calls failing**
- Verify Agora App ID
- Check camera/microphone permissions
- Ensure Agora SDK properly initialized

## 14. Deployment Commands

### Android
```bash
# Generate signed APK
flutter build apk --release

# Generate App Bundle for Play Store
flutter build appbundle --release
```

### iOS
```bash
# Build for App Store
flutter build ios --release

# Archive in Xcode
# Product > Archive > Distribute App
```

## 15. Post-Launch

- [ ] Monitor crash reports (Firebase Crashlytics)
- [ ] Track analytics
- [ ] Monitor Supabase usage
- [ ] Set up error alerting
- [ ] Plan update schedule

---

## Quick Start Summary

```bash
# 1. Create project
flutter create meow_meow --org com.meowmeow

# 2. Copy files
cp -r flutter/* meow_meow/

# 3. Setup
cd meow_meow
flutter pub get
flutter pub run build_runner build

# 4. Configure
# - Update supabase_config.dart with credentials
# - Add Firebase config files
# - Add Agora credentials

# 5. Run
flutter run
```

**Your app is ready when all checkboxes are marked!**
