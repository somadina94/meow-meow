# Meow Meow - Flutter Mobile App

Complete Flutter implementation for iOS and Android with full feature parity to the React web app.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.16+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Dart 3.2+
- Xcode 15+ (for iOS)
- Android Studio / Android SDK (for Android)

### Setup

1. **Create new Flutter project:**
```bash
flutter create meow_meow --org com.meowmeow
cd meow_meow
```

2. **Copy all files from this `flutter/` directory to your Flutter project**

3. **Install dependencies:**
```bash
flutter pub get
```

4. **Configure Supabase:**
   - Update `lib/core/config/supabase_config.dart` with your credentials

5. **Run the app:**
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## 📁 Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── config/              # App configuration
│   ├── constants/           # App constants
│   ├── network/             # API & network handling
│   ├── services/            # Business logic services
│   ├── theme/               # App theming
│   └── utils/               # Utility functions
├── features/                # Feature modules
│   ├── auth/                # Authentication
│   ├── chat/                # Real-time chat
│   ├── matching/            # User matching
│   ├── profile/             # User profiles
│   ├── wallet/              # Wallet & payments
│   ├── video_call/          # Video calling
│   ├── gifts/               # Gift system
│   ├── admin/               # Admin dashboard
│   └── settings/            # App settings
├── shared/                  # Shared components
│   ├── models/              # Data models
│   ├── widgets/             # Reusable widgets
│   └── providers/           # State providers
└── main.dart                # App entry point
```

## ✨ Features

### Core Features
- ✅ Email/Password Authentication
- ✅ User Profiles (Male/Female)
- ✅ Real-time Chat with Translation
- ✅ User Matching System
- ✅ Wallet & Transactions
- ✅ Gift Sending
- ✅ Video Calling
- ✅ Push Notifications
- ✅ Offline Support
- ✅ Multi-language Support (16 languages)

### Admin Features
- ✅ Analytics Dashboard
- ✅ User Management
- ✅ Chat Monitoring
- ✅ Financial Reports
- ✅ Content Moderation

## 📱 Platform Support

| Platform | Minimum Version |
|----------|-----------------|
| iOS      | 12.0+           |
| Android  | API 21 (5.0)+   |

## 🔧 Configuration

### Environment Variables
Create `.env` file in project root:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

### iOS Configuration
Update `ios/Runner/Info.plist` for permissions:
- Camera
- Microphone
- Photo Library
- Push Notifications

### Android Configuration
Update `android/app/src/main/AndroidManifest.xml` for permissions:
- CAMERA
- RECORD_AUDIO
- INTERNET
- READ_EXTERNAL_STORAGE

## 📦 Dependencies

Key packages used:
- `supabase_flutter` - Supabase integration
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `dio` - HTTP client
- `hive_flutter` - Local storage
- `flutter_local_notifications` - Push notifications
- `agora_rtc_engine` - Video calling
- `cached_network_image` - Image caching
- `intl` - Internationalization

## 🏗️ Building for Production

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## 📄 License

Proprietary - All rights reserved
