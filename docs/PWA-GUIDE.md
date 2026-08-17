# Meow Meow - Universal PWA Guide

> **Complete PWA support for ALL devices, operating systems, and browsers worldwide**

---

## Browser & Platform Support Matrix

### Automatic Install Prompt Support
| Browser | Windows | macOS | Linux | Android | iOS |
|---------|---------|-------|-------|---------|-----|
| **Chrome** | ✅ | ✅ | ✅ | ✅ | ❌* |
| **Edge** | ✅ | ✅ | ✅ | ✅ | ❌* |
| **Samsung Internet** | - | - | - | ✅ | - |
| **Opera** | ✅ | ✅ | ✅ | ✅ | - |
| **Brave** | ✅ | ✅ | ✅ | ✅ | - |
| **Vivaldi** | ✅ | ✅ | ✅ | ✅ | - |

*iOS requires manual "Add to Home Screen" via Safari Share menu

### Manual Installation Required
| Browser | Platform | Install Method |
|---------|----------|----------------|
| **Safari** | iOS/iPadOS | Share → Add to Home Screen |
| **Safari** | macOS 14+ | File → Add to Dock |
| **Firefox** | Android | Menu → Install |
| **Firefox** | Desktop | Menu → Install App |

---

## Push Notification Support

| Browser | Windows | macOS | Linux | Android | iOS |
|---------|---------|-------|-------|---------|-----|
| **Chrome** | ✅ | ✅ | ✅ | ✅ | ✅ (16.4+) |
| **Safari** | - | ✅ (16+) | - | - | ✅ (16.4+) |
| **Firefox** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Edge** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Samsung Internet** | - | - | - | ✅ | - |
| **Opera** | ✅ | ✅ | ✅ | ✅ | - |

---

## What is a PWA?

A Progressive Web App (PWA) allows you to install Meow Meow directly to your device's home screen, giving you an app-like experience without needing to download from an app store.

### Benefits:
- ✅ **Works offline** - Access cached content even without internet
- ✅ **Fast loading** - App loads instantly from your device
- ✅ **Push notifications** - Receive real-time alerts for messages and matches
- ✅ **Auto-updates** - Always get the latest version automatically
- ✅ **No app store needed** - Install directly from your browser
- ✅ **Native-like experience** - Full screen, app icon, splash screen
- ✅ **Background sync** - Messages queue and send when back online
- ✅ **Storage efficient** - Uses less space than native apps

---

## Installation Instructions

### iOS (iPhone/iPad) - Safari Required

1. Open Meow Meow in **Safari** (must be Safari, not Chrome/Firefox)
2. Tap the **Share button** (square with arrow pointing up)
3. Scroll down and tap **"Add to Home Screen"**
4. Optionally edit the name, then tap **"Add"**
5. The app icon will appear on your home screen

> **Note**: iOS 16.4+ is required for push notifications. Update your device for best experience.

### Android - Chrome, Samsung Internet, Opera

**Automatic Prompt:**
1. Open Meow Meow in your browser
2. An install banner will appear at the bottom
3. Tap **"Install"** or **"Add to Home Screen"**

**Manual Installation:**
1. Tap the **menu button** (three dots)
2. Tap **"Install App"** or **"Add to Home Screen"**
3. Tap **"Install"** to confirm

### Windows - Chrome, Edge, Brave

1. Open Meow Meow in your browser
2. Look for the **install icon** (➕) in the address bar
3. Click **"Install"**
4. The app will be added to Start menu and taskbar

### macOS - Safari, Chrome

**Safari (macOS 14+):**
1. Open Meow Meow in Safari
2. Click **File** in the menu bar
3. Click **"Add to Dock"**

**Chrome:**
1. Open Meow Meow in Chrome
2. Click the install icon in the address bar
3. Click **"Install"**

### Linux - Chrome, Chromium, Brave

1. Open Meow Meow in your browser
2. Click the install icon in the address bar
3. Click **"Install"**
4. The app will appear in your application launcher

### Chromebook

1. Open Meow Meow in Chrome
2. Click the install icon in the address bar
3. Click **"Install"**
4. The app will appear in your launcher

---

## Features

### Offline Support
- View your previous chats and matches while offline
- Messages sent offline will be delivered when you're back online
- Profile photos are cached for quick loading
- Supports all browsers with Service Worker capability

### Push Notifications
After installing, you can enable push notifications to receive:
- New message alerts
- Match notifications
- Video call invitations
- Important updates

To enable notifications:
1. Open the installed app
2. You'll see a prompt to enable notifications
3. Tap **"Enable Notifications"**
4. Allow notifications in your device settings

### App Shortcuts (Android/Windows/macOS)
Long-press or right-click the app icon to access:
- **Chat** - Go directly to your chats
- **Wallet** - Check your balance
- **Matches** - View your matches

### Background Sync
When you're offline:
- Messages are queued locally
- They sync automatically when you're back online
- No messages are lost

### Activity-Based Online Status
- The app automatically shows you as **online** when you're active
- After **10 minutes of inactivity**, your status changes to **offline**
- You can also manually toggle your status

---

## Advanced PWA Features

| Feature | Support |
|---------|---------|
| **Service Worker** | All modern browsers |
| **Offline Caching** | All modern browsers |
| **Push Notifications** | Chrome, Safari 16+, Edge, Firefox, Samsung |
| **Background Sync** | Chrome, Edge, Samsung, Opera |
| **App Badging** | Chrome, Edge, Safari 17+ |
| **Share Target** | Chrome, Edge, Samsung |
| **Web Share** | All modern browsers |
| **Periodic Sync** | Chrome, Edge |

---

## Caching Strategy

| Resource | Strategy | Duration |
|----------|----------|----------|
| API Responses | Network First | 1 hour |
| Images | Cache First | 30 days |
| Fonts | Cache First | 1 year |
| CSS/JS | Stale While Revalidate | 7 days |
| Audio (Voice Messages) | Cache First | 7 days |

---

## Updating the App

The PWA updates automatically when you open it:
- If an update is available, you'll see an **"Update Available"** banner
- Tap **"Update Now"** to get the latest version
- The app will refresh with the new features

For manual update:
- Pull down to refresh (mobile)
- Press Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (macOS)

---

## Troubleshooting

### App not installing?
- **iOS**: Must use Safari, not Chrome or Firefox
- **Android**: Check you have enough storage
- **Desktop**: Look for install icon in address bar
- Clear browser cache and try again

### Not receiving notifications?
1. Check device Settings → Apps → Meow Meow
2. Ensure notifications are enabled
3. Check Do Not Disturb is off
4. iOS: Requires iOS 16.4+ for push notifications

### App seems outdated?
1. Open the app
2. Look for "Update Available" banner
3. Or pull down to refresh / press Ctrl+Shift+R

### Offline mode not working?
- Open the app once while online first
- Wait for content to cache
- Check storage isn't full

### Install banner not appearing?
- Wait 30 seconds after page load
- Some browsers require multiple visits
- Check if already installed

---

## Uninstalling

### Android
1. Long-press the app icon
2. Tap **"Uninstall"** or drag to "Remove"

### iPhone/iPad
1. Long-press the app icon
2. Tap **"Remove App"** or the (x) icon
3. Confirm removal

### Windows
1. Settings → Apps → Meow Meow → Uninstall
2. Or right-click in Start menu → Uninstall

### macOS
1. Open the app
2. Click menu (three dots) in title bar
3. Select **"Uninstall"**

### Linux
1. Open your applications menu
2. Right-click the app
3. Select **"Uninstall"** or remove from applications

---

## Technical Details

The Meow Meow PWA includes:
- **Service Worker** for offline caching and background sync
- **Web App Manifest** for native-like installation
- **Push API** for real-time notifications
- **Background Sync API** for offline message queuing
- **Cache API** for fast content delivery
- **Share Target API** for receiving shared content

All your data syncs seamlessly between the PWA and web versions - they share the same account and data.

---

## Browser Support Details

### Full Support (All Features)
- Chrome 80+ (Windows, macOS, Linux, Android)
- Edge 80+ (Windows, macOS, Linux, Android)
- Safari 16+ (macOS, iOS - with some limitations)
- Samsung Internet 14+ (Android)
- Opera 67+ (All platforms)
- Brave (All platforms)

### Partial Support
- Firefox 78+ (Install limitations, no Background Sync)
- UC Browser (Basic PWA features)
- QQ Browser (Basic PWA features)

### Not Supported
- Internet Explorer (Not supported)
- Very old browser versions

---

## Need Help?

If you have questions about the PWA, contact our support team through the app's Settings page.
