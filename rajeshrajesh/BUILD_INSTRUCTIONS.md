# TWA Build & Play Store Submission Guide

Complete walkthrough — from zero to a published Android app.

---

## Phase 1 — One-Time Setup (your local machine)

### 1.1 Install prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | ≥ 18 | https://nodejs.org |
| JDK | **17** (exact) | `brew install openjdk@17` / `apt install openjdk-17-jdk` |
| Android SDK | API 34 | Android Studio → SDK Manager |
| Bubblewrap CLI | latest | `npm install -g @bubblewrap/cli` |

Set environment variables:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk        # macOS
# export ANDROID_HOME=$HOME/Android/Sdk               # Linux
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin
export JAVA_HOME=$(/usr/libexec/java_home -v 17)     # macOS
```

Verify:
```bash
java -version          # should print "17.x.x"
adb --version
bubblewrap --version
```

---

## Phase 2 — Build the App

### 2.1 Generate keystore + build (single command)

```bash
cd rajeshrajesh
bash build.sh
```

What it does:
1. Creates `android.keystore` (prompts for passwords — **save them!**)
2. Runs `bubblewrap init` to scaffold `android/` from `twa-manifest.json`
3. Runs `bubblewrap build` → produces signed `.aab` and `.apk`
4. Prints the SHA-256 certificate fingerprint

> 🔐 **CRITICAL:** Back up `android.keystore` to encrypted storage AND
> a password manager. If you lose it, **you can never update the app on
> Play Store** — you'd have to publish under a new package ID.

### 2.2 Outputs

```
rajeshrajesh/
├── android.keystore                                       ← KEEP SECRET
├── android/
│   ├── app-release-signed.apk                             ← sideload for testing
│   └── app/build/outputs/bundle/release/app-release.aab   ← upload to Play Store
```

---

## Phase 3 — Digital Asset Links (removes the URL bar)

Without this step, the TWA shows a Chrome URL bar at the top — looks like a
browser, not an app.

### 3.1 Generate the file

```bash
bash generate-assetlinks.sh
```

This creates `assetlinks.json` containing your app's package ID and SHA-256
fingerprint.

### 3.2 Host it on your web origin

The file MUST be reachable at exactly:

```
https://meow-meow.co.in/.well-known/assetlinks.json
```

For your Lovable-hosted web app:

```bash
mkdir -p public/.well-known
cp rajeshrajesh/assetlinks.json public/.well-known/assetlinks.json
```

Then redeploy your web app. (This is a static file in `public/` — it does NOT
touch any `.ts`, `.tsx`, or database code.)

### 3.3 Verify

```bash
curl https://meow-meow.co.in/.well-known/assetlinks.json
```

Should return the JSON. Also test with Google's official validator:
https://developers.google.com/digital-asset-links/tools/generator

---

## Phase 4 — Test on a Real Device

### 4.1 Sideload the APK

```bash
adb install rajeshrajesh/android/app-release-signed.apk
```

Open the app on the phone. **Check carefully:**
- ✅ No URL bar visible at top → asset links working
- ❌ URL bar visible → asset links failed; re-check Phase 3
- ✅ Splash screen shows your icon
- ✅ App opens to your live web app
- ✅ Login, chat, calls all work

### 4.2 Common test issues

| Symptom | Fix |
|---------|-----|
| URL bar visible | assetlinks.json not deployed or wrong SHA-256 |
| Blank white screen | Check `https://meow-meow.co.in` loads in mobile Chrome |
| Splash shows then exits | `startUrl` in `twa-manifest.json` returns 404 |
| Camera/mic denied silently | Make sure permissions are requested in your web code (already done) |

---

## Phase 5 — Submit to Google Play Store

### 5.1 Prerequisites

- Google Play Developer account ($25 one-time fee)
- Privacy Policy URL (public, accessible)
- App icon 512×512 (already in your manifest)
- Feature graphic 1024×500 (create one)
- 2–8 screenshots from a real device

### 5.2 Create the app

1. Go to https://play.google.com/console
2. **Create app** → fill name, default language, app/game, free/paid
3. Complete all required forms:
   - **App content** → Privacy Policy, Ads, Content rating, Target audience, News app, COVID-19, Data safety
   - **Store listing** → screenshots, descriptions, icon
   - **Pricing & distribution** → countries (select India + others as needed)

### 5.3 Upload the AAB

1. **Production → Create new release**
2. Drag `app-release.aab` into the upload area
3. Add release notes
4. **Save → Review release → Start rollout to Production**

Review takes 1–7 days for first submission.

### 5.4 Recommended: use Internal Testing first

Before Production, push to **Internal Testing** track:
- Add tester emails (up to 100)
- Get a private install link
- Verify everything in production conditions before public launch

---

## Phase 6 — Updating the App

### 6.1 Web-only changes (most updates)

If you only changed `.ts`, `.tsx`, CSS, components, or database code:

✅ **Just deploy your web app as normal.**
❌ **No Play Store re-submission needed.**

All installed TWAs will fetch the new code on next launch (Chrome cache permitting).

### 6.2 Native changes (rare)

You only need to rebuild and re-submit the AAB if you change:
- App icon
- App name
- Package ID (don't!)
- Theme colors / splash
- Shortcuts
- Permissions

To release an update:

```bash
# 1. Bump version in twa-manifest.json
#    "appVersionName": "1.0.1"
#    "appVersionCode": 2          ← MUST always increase

# 2. Rebuild
bash build.sh

# 3. Upload new app-release.aab to Play Console as a new release
```

---

## Phase 7 — Push Notifications (Optional)

TWAs support web push notifications **automatically** as long as your web app
already implements them. No extra Android code required. Users will see the
permission prompt on first request just like on desktop Chrome.

---

## Architecture Summary

```
┌──────────────────────────┐
│  Google Play Store       │
│  ┌────────────────────┐  │
│  │ app-release.aab    │  │  ← 2 MB shell, signed with android.keystore
│  │ (TWA wrapper only) │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │ install
             ▼
┌──────────────────────────┐
│  User's Android phone    │
│  ┌────────────────────┐  │
│  │ TWA shell launches │  │
│  │ Chrome in trusted  │  │
│  │ mode               │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │ HTTPS
             ▼
┌──────────────────────────────────────┐
│  https://meow-meow.co.in     │
│                                      │
│  • All your React/.tsx components    │
│  • Supabase client                   │
│  • Database queries (RLS-protected)  │
│  • Edge functions                    │
│                                      │
│  ⚠️  ZERO changes from current code  │
└──────────────────────────────────────┘
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `bubblewrap: command not found` | `npm install -g @bubblewrap/cli` |
| `JAVA_HOME is not set` | `export JAVA_HOME=$(/usr/libexec/java_home -v 17)` |
| Build fails with SDK error | Open Android Studio → SDK Manager → install API 34 + Build-Tools 34 |
| Play Console: "use Android App Bundle" | Upload `.aab` not `.apk` for Production |
| Play Console: "target API 34 required" | Already set — re-run `build.sh` to regenerate |
| URL bar still shows after install | Check `curl https://meow-meow.co.in/.well-known/assetlinks.json` returns 200 with correct SHA-256 |
| App opens then closes | `startUrl` is wrong; verify `https://meow-meow.co.in/` loads in mobile Chrome |

---

## Files You Should Never Commit to Git

Add to `.gitignore`:
```
rajeshrajesh/android.keystore
rajeshrajesh/*.keystore
rajeshrajesh/android/app-release-signed.apk
rajeshrajesh/android/app/build/
rajeshrajesh/android/build/
rajeshrajesh/android/.gradle/
```
