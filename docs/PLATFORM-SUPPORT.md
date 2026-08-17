# Meow Meow - Complete Platform & Device Support

## Supported Devices

| Device Type | Screen Size | Examples |
|-------------|-------------|----------|
| **Small Phones** | 320px - 479px | iPhone SE, older Android phones |
| **Large Phones** | 480px - 767px | iPhone 15, Samsung Galaxy S24 |
| **Tablets** | 768px - 1023px | iPad, iPad Mini, Android tablets |
| **Laptops** | 1024px - 1279px | MacBook Air, most Windows laptops |
| **Desktops** | 1280px - 1535px | iMac, desktop monitors |
| **Large Desktops** | 1536px - 1919px | Ultrawide monitors |
| **4K/Ultra-wide** | 1920px+ | 4K monitors, ultra-wide displays |

## Supported Platforms
| Platform | Method | Install From |
|----------|--------|--------------|
| **Windows** | PWA + Electron | Chrome/Edge → Install icon in address bar |
| **macOS** | PWA + Electron | Chrome/Safari → Install prompt |
| **Linux** | PWA + Electron | Chrome/Firefox → Install prompt |
| **Chrome OS** | PWA | Chrome → Install prompt |

## Supported Browsers

### Full Support (PWA Installation + All Features)
| Browser | Windows | macOS | Linux | Android | iOS |
|---------|---------|-------|-------|---------|-----|
| **Chrome** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Edge** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Safari** | - | ✅ | - | - | ✅ |
| **Firefox** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Opera** | ✅ | ✅ | ✅ | ✅ | - |
| **Brave** | ✅ | ✅ | ✅ | ✅ | - |
| **Samsung Internet** | - | - | - | ✅ | - |
| **Vivaldi** | ✅ | ✅ | ✅ | ✅ | - |

### Legacy Browser Support
| Browser | Minimum Version | Notes |
|---------|-----------------|-------|
| Chrome | 80+ | Full PWA support |
| Firefox | 78+ | Limited PWA (no install prompt) |
| Safari | 14+ | iOS PWA via Add to Home Screen |
| Edge | 80+ | Full PWA support (Chromium) |
| Edge Legacy | 18+ | Basic support only |
| IE 11 | - | Not supported |

## Native App Builds

### Mobile (Capacitor)
```bash
# iOS
npx cap add ios
npx cap run ios

# Android  
npx cap add android
npx cap run android
```

### Desktop (Electron)
```bash
# Windows (.exe)
npm run electron:build:win

# macOS (.dmg)
npm run electron:build:mac

# Linux (.AppImage, .deb, .rpm)
npm run electron:build:linux
```

## Feature Support by Platform

| Feature | PWA | iOS Native | Android Native | Electron |
|---------|-----|------------|----------------|----------|
| Offline Mode | ✅ | ✅ | ✅ | ✅ |
| Push Notifications | ✅* | ✅ | ✅ | ✅ |
| Camera Access | ✅ | ✅ | ✅ | ✅ |
| Background Sync | ✅ | ❌ | ✅ | ✅ |
| System Tray | ❌ | ❌ | ❌ | ✅ |
| Auto-Update | ✅ | ✅ | ✅ | ✅ |
| App Store Distribution | ❌ | ✅ | ✅ | ❌ |

*PWA Push Notifications not supported on iOS Safari

## Installation Methods

### PWA (All Platforms)
1. Visit the app in a supported browser
2. Look for install prompt or:
   - **Chrome/Edge**: Click install icon (➕) in address bar
   - **Safari iOS**: Share → Add to Home Screen
   - **Firefox**: Menu → Install

### Native Mobile
1. Export project to GitHub
2. Clone and run `npx cap add ios` or `npx cap add android`
3. Build with Xcode (iOS) or Android Studio (Android)

### Native Desktop
1. Export project to GitHub
2. Install Electron dependencies
3. Run build command for your platform

## Recommended Setup

For maximum reach, we recommend:

1. **Primary**: PWA - Works everywhere, no app store needed
2. **Mobile Native**: Capacitor - For App Store/Play Store distribution
3. **Desktop Native**: Electron - For native desktop experience

All three share the same codebase and UI!
