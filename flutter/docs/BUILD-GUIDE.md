# Flutter to iOS & Android Build Guide

Complete guide to build and deploy the Meow Meow Flutter app for iOS and Android.

---

## 📋 Prerequisites

### For Both Platforms
- Flutter SDK 3.16+ installed ([flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install))
- Dart SDK 3.2+
- Git installed
- A code editor (VS Code recommended with Flutter extension)

### For iOS Development
- **macOS** (required - iOS apps can only be built on Mac)
- Xcode 15+ from Mac App Store
- Xcode Command Line Tools: `xcode-select --install`
- CocoaPods: `sudo gem install cocoapods`
- Apple Developer Account ($99/year for App Store publishing)

### For Android Development
- Android Studio (any OS: Windows, macOS, Linux)
- Android SDK (installed via Android Studio)
- Java Development Kit (JDK) 17+
- Google Play Developer Account ($25 one-time for Play Store publishing)

---

## 🚀 Step-by-Step Setup

### Step 1: Create Flutter Project

```bash
# Create new Flutter project
flutter create meow_meow --org com.meowmeow --platforms=ios,android

# Navigate to project
cd meow_meow
```

### Step 2: Copy Flutter Files

Copy all files from the `/flutter` directory in this repository to your new Flutter project:

```bash
# If you have the repo cloned
cp -r /path/to/repo/flutter/* /path/to/meow_meow/
```

Files to copy:
- `lib/` - All Dart source files
- `assets/` - Localization files, images
- `pubspec.yaml` - Dependencies (merge with existing)

### Step 3: Install Dependencies

```bash
flutter pub get
```

### Step 4: Generate Code (Freezed Models)

```bash
# Run build_runner for Freezed models
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 5: Configure Environment

Edit `lib/core/config/supabase_config.dart` with your Supabase credentials:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

---

## 🍎 Building for iOS

### Initial iOS Setup

```bash
# Navigate to iOS folder
cd ios

# Install CocoaPods dependencies
pod install

# Return to project root
cd ..
```

### Configure iOS App

1. **Open in Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Set Bundle Identifier**:
   - Select `Runner` in the project navigator
   - Go to `Signing & Capabilities` tab
   - Set Bundle Identifier: `com.meowmeow.app`

3. **Configure Signing**:
   - Select your Development Team
   - Enable "Automatically manage signing"

4. **Set App Name**:
   - Edit `ios/Runner/Info.plist`
   - Set `CFBundleDisplayName` to "Meow Meow"

5. **Configure Permissions** (add to `Info.plist`):
   ```xml
   <!-- Camera -->
   <key>NSCameraUsageDescription</key>
   <string>Camera access is needed for video calls and profile photos</string>
   
   <!-- Microphone -->
   <key>NSMicrophoneUsageDescription</key>
   <string>Microphone access is needed for voice messages and video calls</string>
   
   <!-- Photo Library -->
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Photo library access is needed for profile photos</string>
   
   <!-- Location (if needed) -->
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Location is used to find matches near you</string>
   ```

### Build iOS App

```bash
# Debug build (for testing)
flutter build ios --debug

# Release build (for App Store)
flutter build ios --release
```

### Run on iOS Simulator

```bash
# List available simulators
flutter devices

# Run on specific simulator
flutter run -d "iPhone 15 Pro"
```

### Run on Physical iPhone

1. Connect iPhone via USB
2. Trust the computer on your iPhone
3. Run:
   ```bash
   flutter run -d <device-id>
   ```

### Submit to App Store

1. **Create App Store Connect Record**:
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Create new app with your Bundle ID

2. **Archive and Upload**:
   ```bash
   # Build release
   flutter build ios --release
   
   # Open in Xcode
   open ios/Runner.xcworkspace
   ```
   - In Xcode: Product → Archive
   - Distribute App → App Store Connect → Upload

3. **Submit for Review**:
   - Complete app information in App Store Connect
   - Submit for review (typically 24-48 hours)

---

## 🤖 Building for Android

### Initial Android Setup

1. **Open in Android Studio**:
   ```bash
   # Open the android folder in Android Studio
   studio android/
   ```

2. **Sync Gradle**:
   - Android Studio will prompt to sync Gradle
   - Click "Sync Now"

### Configure Android App

1. **Set Application ID** in `android/app/build.gradle`:
   ```gradle
   android {
       defaultConfig {
           applicationId "com.meowmeow.app"
           minSdkVersion 21
           targetSdkVersion 34
           versionCode 1
           versionName "1.0.0"
       }
   }
   ```

2. **Set App Name** in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <application
       android:label="Meow Meow"
       ...>
   ```

3. **Configure Permissions** in `AndroidManifest.xml`:
   ```xml
   <!-- Internet -->
   <uses-permission android:name="android.permission.INTERNET"/>
   
   <!-- Camera -->
   <uses-permission android:name="android.permission.CAMERA"/>
   
   <!-- Microphone -->
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   
   <!-- Storage -->
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
   
   <!-- Location (optional) -->
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```

### Create Signing Key (for Release)

```bash
# Generate keystore
keytool -genkey -v -keystore ~/meowmeow-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias meowmeow
```

Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=meowmeow
storeFile=/path/to/meowmeow-release-key.jks
```

Update `android/app/build.gradle`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### Build Android App

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (recommended for Play Store)
flutter build appbundle --release
```

Output locations:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

### Run on Android Emulator

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Run app
flutter run
```

### Run on Physical Android Device

1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect via USB
4. Run:
   ```bash
   flutter devices  # Verify device is listed
   flutter run -d <device-id>
   ```

### Submit to Google Play Store

1. **Create Developer Account**:
   - Go to [play.google.com/console](https://play.google.com/console)
   - Pay $25 one-time fee

2. **Create App**:
   - Click "Create app"
   - Fill in app details

3. **Upload App Bundle**:
   - Go to Release → Production
   - Create new release
   - Upload `app-release.aab`

4. **Complete Store Listing**:
   - Add screenshots (phone & tablet)
   - Write description
   - Set content rating
   - Configure pricing

5. **Submit for Review** (typically 1-3 days)

---

## 🔥 Firebase Configuration (Push Notifications)

### iOS Firebase Setup

1. Create project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add iOS app with Bundle ID
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/`

### Android Firebase Setup

1. Add Android app in Firebase Console
2. Download `google-services.json`
3. Place in `android/app/`
4. Update `android/build.gradle`:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
   }
   ```
5. Update `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

---

## 📱 App Icons & Splash Screen

### Generate App Icons

1. Add icon to `assets/icon/app_icon.png` (1024x1024)
2. Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icon/app_icon.png"
   ```
3. Run:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

### Generate Splash Screen

1. Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_native_splash: ^2.3.5
   
   flutter_native_splash:
     color: "#EC4899"
     image: assets/splash/splash.png
     android: true
     ios: true
   ```
2. Run:
   ```bash
   flutter pub run flutter_native_splash:create
   ```

---

## 🔧 Troubleshooting

### Common iOS Issues

| Issue | Solution |
|-------|----------|
| CocoaPods not found | `sudo gem install cocoapods` |
| Pod install fails | `cd ios && pod deintegrate && pod install` |
| Signing issues | Check Apple Developer account & certificates |
| Simulator not starting | Reset simulator in Xcode |

### Common Android Issues

| Issue | Solution |
|-------|----------|
| Gradle sync failed | File → Invalidate Caches → Restart |
| SDK not found | Install via Android Studio SDK Manager |
| Build fails | `flutter clean && flutter pub get` |
| Emulator slow | Enable hardware acceleration in BIOS |

### General Issues

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Check Flutter installation
flutter doctor -v

# Update Flutter
flutter upgrade
```

---

## 📊 Build Comparison

| Feature | iOS | Android |
|---------|-----|---------|
| Build Time (Release) | ~5-10 min | ~3-5 min |
| Output Size | ~30-50 MB | ~20-40 MB |
| Review Time | 24-48 hours | 1-3 days |
| Developer Fee | $99/year | $25 one-time |
| Required OS | macOS only | Any OS |

---

## 📚 Additional Resources

- [Flutter Official Docs](https://docs.flutter.dev/)
- [iOS Deployment Guide](https://docs.flutter.dev/deployment/ios)
- [Android Deployment Guide](https://docs.flutter.dev/deployment/android)
- [App Store Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Play Store Policies](https://play.google.com/console/about/guides/)

---

## ✅ Deployment Checklist

### Before Release
- [ ] Test on multiple devices/screen sizes
- [ ] Test all features (auth, chat, payments, etc.)
- [ ] Configure production Supabase credentials
- [ ] Set up Firebase for push notifications
- [ ] Generate app icons and splash screen
- [ ] Prepare store assets (screenshots, descriptions)
- [ ] Set version number and build number
- [ ] Test offline functionality
- [ ] Review privacy policy and terms

### iOS Specific
- [ ] Create App Store Connect record
- [ ] Configure certificates and provisioning
- [ ] Add required privacy descriptions to Info.plist
- [ ] Test on physical device
- [ ] Prepare for App Review

### Android Specific
- [ ] Create release keystore
- [ ] Configure signing in build.gradle
- [ ] Set up Play Console listing
- [ ] Complete content rating questionnaire
- [ ] Prepare for Play Protect review
