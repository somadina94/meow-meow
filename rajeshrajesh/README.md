# MeowMeow — TWA (Trusted Web Activity) Android Wrapper

This folder contains a **complete Android TWA project** that wraps your existing
published web app (`https://meow-meow.co.in`) into a native `.aab`/`.apk`
ready for the Google Play Store.

> ✅ **Zero changes to your `.ts`, `.tsx`, or database code.**
> The TWA simply opens your live PWA inside a Chrome Custom Tab with no browser UI.

---

## What is a TWA?

A Trusted Web Activity is a Chrome-powered Android container that runs a
verified web origin **fullscreen, with no address bar**, indistinguishable from
a native app. It is Google's officially supported way to publish a PWA to the
Play Store.

**Requirements your project already meets:**
- ✅ HTTPS site (`https://meow-meow.co.in`)
- ✅ Valid `manifest.json` with `display: standalone`, icons, theme color
- ✅ 192×192 and 512×512 PNG icons in `/public/icons/`
- ✅ Service worker / responsive UI (already shipped)

---

## Folder Contents

```
rajeshrajesh/
├── README.md                          ← this file
├── BUILD_INSTRUCTIONS.md              ← step-by-step build & Play Store guide
├── twa-manifest.json                  ← Bubblewrap config (single source of truth)
├── build.sh                           ← one-command build script
├── generate-assetlinks.sh             ← creates Digital Asset Links file
└── android/                           ← native Android project (Bubblewrap output)
    ├── app/
    │   ├── build.gradle
    │   ├── proguard-rules.pro
    │   └── src/main/
    │       ├── AndroidManifest.xml
    │       ├── java/app/lovable/meowmeow/
    │       │   ├── LauncherActivity.java
    │       │   └── Application.java
    │       └── res/
    │           ├── values/
    │           │   ├── colors.xml
    │           │   ├── strings.xml
    │           │   └── styles.xml
    │           └── xml/
    │               ├── filepaths.xml
    │               └── shortcuts.xml
    ├── build.gradle
    ├── gradle.properties
    ├── settings.gradle
    └── assetlinks.json                ← upload to web origin /.well-known/
```

---

## Quick Start (3 steps)

```bash
# 1. Install Bubblewrap CLI (one-time, requires Node.js + JDK 17 + Android SDK)
npm install -g @bubblewrap/cli

# 2. Build the signed App Bundle
cd rajeshrajesh
bash build.sh

# 3. Output:
#    rajeshrajesh/android/app/build/outputs/bundle/release/app-release.aab
#    → upload this file to Google Play Console
```

See `BUILD_INSTRUCTIONS.md` for the complete walkthrough including:
- Generating the upload keystore
- Creating Digital Asset Links (the URL-bar-removal trick)
- Submitting to Play Console
- Updating the app

---

## How It Works

```
┌─────────────────────┐         ┌──────────────────────────────┐
│  Android device     │  HTTPS  │  meow-meow.co.in     │
│  (TWA installed)    │ ──────► │  (your existing PWA)         │
│                     │         │                              │
│  Chrome engine      │         │  • React/Vite bundle         │
│  renders the page   │         │  • Supabase client           │
│  fullscreen         │         │  • All .ts/.tsx unchanged    │
└─────────────────────┘         └──────────────────────────────┘
```

The TWA contains **no business logic**. It is a 2 MB shell that:
1. Verifies it owns `meow-meow.co.in` via Digital Asset Links.
2. Launches Chrome in trusted mode pointing at your URL.
3. Hides the address bar because the verification succeeded.

When you push code to your web app, **all installed TWAs see the update on next launch** — no Play Store re-submission needed (unless you change icons, name, or version).
