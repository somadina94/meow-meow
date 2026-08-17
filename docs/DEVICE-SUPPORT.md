# Meow Meow - Universal Device & Platform Support Guide

> **Complete compatibility with ALL devices, operating systems, and browsers worldwide**

---

## Master Compatibility Table

| Device Category | Example Devices | Screen Sizes | OS Versions | Browsers |
|-----------------|-----------------|--------------|-------------|----------|
| **Mobile (Smartphones)** | iPhone 15, iPhone SE, Samsung Galaxy S23, Google Pixel 8 | 320x568 → 430x932 | iOS 16–17, Android 11–14 | Safari, Chrome, Samsung Internet, Firefox, Edge, Opera |
| **Large Smartphones / Phablets** | iPhone 15 Pro Max, Samsung Galaxy Note, Pixel Fold | 430x932 → 480x1080 | iOS 16–17, Android 11–14 | Same as above |
| **Tablets** | iPad (Pro/Air/Mini), Galaxy Tab, Kindle Fire | 768x1024 → 1280x800 | iPadOS 15–17, Android 11–14, FireOS | Safari, Chrome, Samsung Internet, Firefox, Edge |
| **Laptops / Desktops** | MacBook Air/Pro, Windows Laptop, Ubuntu Desktop | 1280x800 → 3840x2160 | macOS Ventura/Sonoma, Windows 10/11, Linux | Chrome, Safari, Firefox, Edge, Opera, Brave |
| **Chromebooks** | Pixelbook, Acer, Samsung | 1366x768 → 2560x1600 | Chrome OS latest 2 versions | Chrome, Chromium-based |
| **Wearables** | Apple Watch, Samsung Galaxy Watch | 184x224 → 368x448 | watchOS 8–10, Wear OS | Limited (notifications) |
| **TV / Large Screens** | Smart TVs, Apple TV, Android TV | 1920x1080 → 3840x2160 | tvOS, Android TV, Tizen, webOS | Built-in browsers |

---

## 1. Mobile Devices

### Smartphones (All Major Brands)

| Brand | Models | Screen Width | Support |
|-------|--------|--------------|---------|
| **Apple** | iPhone 15, 14, 13, SE, etc. | 320px - 430px | ✅ Full |
| **Samsung** | Galaxy S24, S23, A series | 360px - 430px | ✅ Full |
| **Google** | Pixel 8, 7, 6 series | 360px - 412px | ✅ Full |
| **OnePlus** | OnePlus 12, 11, Nord | 360px - 412px | ✅ Full |
| **Xiaomi** | Mi, Redmi, POCO series | 360px - 400px | ✅ Full |
| **Huawei** | P60, Mate series, Honor | 360px - 400px | ✅ Full |
| **Oppo** | Find, Reno series | 360px - 400px | ✅ Full |
| **Vivo** | V, Y, X series | 360px - 400px | ✅ Full |
| **Realme** | GT, Number series | 360px - 400px | ✅ Full |

### Phablets / Large Smartphones

| Device | Screen Width | Support |
|--------|--------------|---------|
| iPhone 15 Pro Max | 430px | ✅ Full |
| Samsung Galaxy S24 Ultra | 412px | ✅ Full |
| Galaxy Note series | 412px - 480px | ✅ Full |
| Pixel Fold (phone mode) | 360px | ✅ Full |

### Mobile Features
- ✅ Portrait & landscape orientation
- ✅ Retina/high-density displays (2x, 3x)
- ✅ Touch input optimization (44px min targets)
- ✅ Safe area support (notch, Dynamic Island, home indicator)
- ✅ Pull-to-refresh disabled
- ✅ Smooth scrolling (-webkit-overflow-scrolling)
- ✅ PWA installation
- ✅ iOS zoom prevention on input focus

---

## 2. Tablets

| Device Category | Examples | Screen Width | Support |
|-----------------|----------|--------------|---------|
| **iPad Mini** | iPad Mini 6 | 744px | ✅ Full |
| **iPad** | iPad 10th gen | 820px | ✅ Full |
| **iPad Air** | iPad Air 5 | 834px | ✅ Full |
| **iPad Pro 11"** | iPad Pro 11" | 834px | ✅ Full |
| **iPad Pro 12.9"** | iPad Pro 12.9" | 1024px | ✅ Full |
| **Samsung Galaxy Tab** | Tab S9, S9+, S9 Ultra | 800px - 1848px | ✅ Full |
| **Kindle Fire** | Fire HD 8, HD 10 | 800px - 1200px | ✅ Full |
| **Lenovo Tab** | Tab P, M series | 800px - 1200px | ✅ Full |

### Foldable Devices

| Device | Closed | Open | Support |
|--------|--------|------|---------|
| Samsung Galaxy Z Fold 5 | 280px | 884px | ✅ Full |
| Samsung Galaxy Z Flip 5 | 720px (folded screen) | 1080px | ✅ Full |
| Google Pixel Fold | 360px | 841px | ✅ Full |
| Motorola Razr | 360px | 876px | ✅ Full |
| Microsoft Surface Duo | 540px | 1114px | ✅ Full |

### Tablet Features
- ✅ Larger touch targets (48px+)
- ✅ Split-screen multitasking support
- ✅ Portrait & landscape layouts
- ✅ Keyboard attachment support
- ✅ Stylus input detection
- ✅ Foldable screen adaptation

---

## 3. Laptops & Desktops

| Device Category | Examples | Screen Width | Support |
|-----------------|----------|--------------|---------|
| **Small Laptops** | MacBook Air 13", Chromebook | 1024px - 1279px | ✅ Full |
| **Standard Laptops** | MacBook Pro 14", Windows laptops | 1280px - 1535px | ✅ Full |
| **Desktop Monitors** | iMac 24", Windows desktops | 1536px - 1919px | ✅ Full |
| **Large Desktops** | iMac 27", 4K monitors | 1920px - 2559px | ✅ Full |
| **Ultra-wide** | 21:9 monitors | 2560px - 3440px | ✅ Full |
| **5K/4K** | 5K displays, 4K monitors | 3840px+ | ✅ Full |

### Operating System Support

| OS | Versions | Support |
|----|----------|---------|
| **Windows** | Windows 10, Windows 11 | ✅ Full |
| **macOS** | Monterey, Ventura, Sonoma | ✅ Full |
| **Linux** | Ubuntu 20.04+, Fedora 37+, Debian 11+ | ✅ Full |
| **Chrome OS** | Latest 2 versions | ✅ Full |

### Desktop Features
- ✅ Mouse & keyboard input
- ✅ Hover interactions
- ✅ Wide screen layouts
- ✅ High-DPI/Retina displays
- ✅ Custom scrollbars
- ✅ Keyboard navigation
- ✅ Focus visible states
- ✅ Right-click context menus

---

## 4. Chromebooks

| Device | Screen Size | Support |
|--------|-------------|---------|
| Google Pixelbook Go | 1920x1080 | ✅ Full |
| Acer Chromebook Spin | 1366x768 - 1920x1080 | ✅ Full |
| Samsung Chromebook Plus | 2400x1600 | ✅ Full |
| HP Chromebook x360 | 1366x768 - 1920x1080 | ✅ Full |
| Lenovo Chromebook Flex | 1366x768 - 1920x1080 | ✅ Full |

### Chromebook Features
- ✅ Touchscreen + keyboard hybrid
- ✅ Chrome browser PWA support
- ✅ Tablet mode detection
- ✅ Linux app compatibility
- ✅ Android app compatibility (PWA)

---

## 5. Wearables

| Device | Support Level | Notes |
|--------|---------------|-------|
| Apple Watch Series 9 | 📱 Notifications | Via iPhone companion |
| Apple Watch Ultra 2 | 📱 Notifications | Via iPhone companion |
| Samsung Galaxy Watch 6 | 📱 Notifications | Via Android companion |
| Google Pixel Watch 2 | 📱 Notifications | Via Android companion |
| Fitbit | ❌ Not supported | No web browser |

### Wearable Features
- 📱 Push notifications (via companion device)
- ⚠️ Very limited web view support
- ❌ Full interactive experience not available

---

## 6. TV & Large Screens

| Device | OS | Screen Size | Support |
|--------|-----|-------------|---------|
| **Samsung Smart TV** | Tizen | 1920x1080 - 3840x2160 | ✅ Basic |
| **LG Smart TV** | webOS | 1920x1080 - 3840x2160 | ✅ Basic |
| **Sony Smart TV** | Android TV | 1920x1080 - 3840x2160 | ✅ Basic |
| **Apple TV** | tvOS | 1920x1080 - 3840x2160 | ⚠️ Limited |
| **Android TV** | Android TV | 1920x1080 - 3840x2160 | ⚠️ Limited |
| **Fire TV** | Fire OS | 1920x1080 - 3840x2160 | ⚠️ Limited |
| **Roku** | Roku OS | - | ❌ No browser |

### TV Features
- ✅ 1080p HD layout support
- ✅ 4K Ultra HD layout support
- ⚠️ D-pad/remote navigation (limited)
- ⚠️ No touch input
- ⚠️ Limited browser capabilities

---

## Browser Support Matrix

### Desktop Browsers

| Browser | Windows | macOS | Linux | Min Version | Support |
|---------|---------|-------|-------|-------------|---------|
| **Chrome** | ✅ | ✅ | ✅ | 80+ | ✅ Full |
| **Safari** | - | ✅ | - | 14+ | ✅ Full |
| **Firefox** | ✅ | ✅ | ✅ | 78+ | ✅ Full |
| **Edge** | ✅ | ✅ | ✅ | 80+ | ✅ Full |
| **Opera** | ✅ | ✅ | ✅ | 67+ | ✅ Full |
| **Brave** | ✅ | ✅ | ✅ | Latest | ✅ Full |
| **Vivaldi** | ✅ | ✅ | ✅ | Latest | ✅ Full |

### Mobile Browsers

| Browser | Android | iOS | Min Version | Support |
|---------|---------|-----|-------------|---------|
| **Chrome** | ✅ | ✅ | 80+ | ✅ Full |
| **Safari** | - | ✅ | 14+ | ✅ Full |
| **Firefox** | ✅ | ✅ | 78+ | ✅ Full |
| **Edge** | ✅ | ✅ | 80+ | ✅ Full |
| **Samsung Internet** | ✅ | - | 14+ | ✅ Full |
| **Opera Mobile** | ✅ | - | Latest | ✅ Full |
| **UC Browser** | ✅ | ✅ | Latest | ✅ Full |
| **QQ Browser** | ✅ | ✅ | Latest | ✅ Full |
| **Baidu Browser** | ✅ | - | Latest | ✅ Full |
| **Yandex Browser** | ✅ | ✅ | Latest | ✅ Full |

### Special Browsers

| Browser | Platform | Support |
|---------|----------|---------|
| **Silk Browser** | Fire OS (Kindle) | ✅ Full |
| **Samsung Internet** | Samsung devices | ✅ Full |
| **Whale Browser** | Korean market | ✅ Full |
| **DuckDuckGo Browser** | All platforms | ✅ Full |

---

## Tailwind CSS Breakpoints

```css
/* Mobile Devices */
xs: 320px      /* Small phones (iPhone SE) */
sm: 375px      /* Standard phones (iPhone 14) */
phablet: 428px /* Large phones (iPhone Pro Max) */

/* Tablets */
md: 768px       /* Small tablets (iPad Mini) */
tablet: 834px   /* Standard tablets (iPad Air) */
tablet-lg: 1024px /* Large tablets (iPad Pro) */

/* Laptops & Desktops */
lg: 1024px     /* Small laptops / Chromebooks */
laptop: 1280px /* Standard laptops */
xl: 1280px     /* Desktop monitors */
2xl: 1536px    /* Large desktops */
3xl: 1920px    /* Full HD / Ultra-wide */
4xl: 2560px    /* 4K / 5K displays */
```

---

## Special Device Modifiers

```css
/* Device Categories */
mobile:        /* Phones only (max-width: 767px) */
tablet-only:   /* Tablets only (768px - 1023px) */
laptop-only:   /* Laptops only (1024px - 1279px) */
desktop:       /* Desktop and above (1280px+) */

/* Foldable Devices */
fold-closed:   /* Galaxy Fold closed (~280px) */
fold-open:     /* Galaxy Fold open (717px - 884px) */

/* Input Methods */
touch:         /* Touch devices (no hover) */
stylus:        /* Stylus/pen input */
mouse:         /* Mouse/trackpad devices */
keyboard:      /* Keyboard-navigable */

/* Display Quality */
standard-dpi:  /* Standard displays (1x) */
retina:        /* Retina/HiDPI displays (2x) */
retina-3x:     /* Super Retina displays (3x) */

/* Orientation */
portrait:      /* Portrait orientation */
landscape:     /* Landscape orientation */

/* Screen Dimensions */
short:         /* Short screens (< 500px height) */
tall:          /* Tall screens (> 900px height) */
wide:          /* Ultra-wide (21:9+) */
square:        /* Square-ish (3:4 to 4:3) */

/* TV & Large Screens */
tv:            /* TV screens (1920x1080+) */
tv-4k:         /* 4K TV screens (3840px+) */
chromebook:    /* Chromebook devices */

/* User Preferences */
motion-safe:   /* Animations enabled */
motion-reduce: /* Reduced motion preference */
dark-mode:     /* Dark color scheme preference */
light-mode:    /* Light color scheme preference */
high-contrast: /* High contrast mode */

/* Media */
print:         /* Print styles */
screen:        /* Screen only */
```

---

## Usage Examples

```tsx
// Responsive layout for all screen sizes
<div className="
  px-4 py-2           // Mobile default (320px+)
  sm:px-6 sm:py-4     // Standard phones (375px+)
  phablet:px-6        // Phablets (428px+)
  md:px-8 md:py-6     // Tablets (768px+)
  lg:px-12 lg:py-8    // Laptops (1024px+)
  xl:px-16 xl:py-10   // Desktops (1280px+)
  2xl:px-20           // Large desktops (1536px+)
  3xl:px-24           // Full HD (1920px+)
">

// Touch vs Mouse interactions
<button className="
  touch:min-h-[48px] touch:p-4  // Larger on touch
  mouse:hover:scale-105         // Hover only with mouse
  mouse:cursor-pointer          // Pointer cursor
">

// Orientation-specific layouts
<div className="
  portrait:flex-col    // Stack in portrait
  landscape:flex-row   // Side by side in landscape
  landscape:gap-8      // More spacing in landscape
">

// Foldable device support
<div className="
  fold-closed:text-sm fold-closed:p-2   // Compact when closed
  fold-open:text-base fold-open:p-4     // Normal when open
">

// Motion preference
<div className="
  motion-safe:animate-fade-in    // Animate if allowed
  motion-reduce:animate-none     // No animation if reduced
">

// TV-optimized layout
<div className="
  tv:text-2xl tv:p-8             // Larger text/padding for TV
  tv-4k:text-3xl tv-4k:p-12      // Even larger for 4K
">

// High contrast mode
<div className="
  high-contrast:border-2 high-contrast:border-current
">
```

---

## Installation Methods

| Device Type | Method | Instructions |
|-------------|--------|--------------|
| **iPhone/iPad** | PWA | Safari → Share → Add to Home Screen |
| **Android** | PWA | Chrome → Menu → Install App |
| **Windows** | PWA / Electron | Browser → Install / Download .exe |
| **macOS** | PWA / Electron | Browser → Install / Download .dmg |
| **Linux** | PWA / Electron | Browser → Install / Download .AppImage |
| **Chromebook** | PWA | Chrome → Install |
| **Smart TV** | Web Browser | Navigate to app URL |

---

## Testing Recommendations

### Cross-Platform Testing Tools
- **BrowserStack** - Real device cloud testing
- **LambdaTest** - Cross-browser testing
- **Sauce Labs** - Automated testing at scale
- **Chrome DevTools** - Device emulation

### Key Test Scenarios
1. Portrait vs Landscape on mobile/tablet
2. Touch vs Mouse input
3. Retina vs Standard displays
4. Slow network (2G/3G) conditions
5. Reduced motion preference
6. Dark mode vs Light mode
7. Foldable device states (open/closed)
8. PWA installation flow
9. Safe area handling (notch, Dynamic Island)
10. Keyboard navigation (accessibility)
