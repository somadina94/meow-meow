import type { Config } from "tailwindcss";

export default {
  darkMode: ["class"],
  content: ["./pages/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: {
        DEFAULT: "1rem",
        sm: "1.5rem",
        md: "2rem",
        lg: "2.5rem",
        xl: "3rem",
        "2xl": "4rem",
      },
      screens: {
        sm: "640px",
        md: "768px",
        lg: "1024px",
        xl: "1280px",
        "2xl": "1400px",
      },
    },
    screens: {
      // ========================================
      // MOBILE DEVICES
      // ========================================
      // Small phones (iPhone SE, older Android)
      "xs": "320px",
      // Standard phones (iPhone 14/15, Galaxy S series)
      "sm": "375px",
      // Large phones / Phablets (iPhone Pro Max, Galaxy Note)
      "phablet": "428px",
      
      // ========================================
      // TABLETS
      // ========================================
      // Small tablets (iPad Mini, Kindle Fire)
      "md": "768px",
      // Standard tablets (iPad, Galaxy Tab)
      "tablet": "834px",
      // Large tablets (iPad Pro 12.9")
      "tablet-lg": "1024px",
      
      // ========================================
      // LAPTOPS & DESKTOPS
      // ========================================
      // Small laptops / Chromebooks
      "lg": "1024px",
      // Standard laptops (MacBook Air/Pro 13")
      "laptop": "1280px",
      // Desktop monitors
      "xl": "1280px",
      // Large desktops
      "2xl": "1536px",
      // Ultra-wide / 4K
      "3xl": "1920px",
      // 5K / Large displays
      "4xl": "2560px",
      
      // ========================================
      // DEVICE-SPECIFIC BREAKPOINTS
      // ========================================
      // Mobile-only (phones)
      "mobile": { "max": "767px" },
      // Tablet-only
      "tablet-only": { "min": "768px", "max": "1023px" },
      // Laptop-only
      "laptop-only": { "min": "1024px", "max": "1279px" },
      // Desktop and above
      "desktop": { "min": "1280px" },
      
      // ========================================
      // FOLDABLE DEVICES
      // ========================================
      // Samsung Galaxy Fold (closed)
      "fold-closed": { "raw": "(max-width: 280px)" },
      // Samsung Galaxy Fold (open)
      "fold-open": { "raw": "(min-width: 717px) and (max-width: 884px)" },
      
      // ========================================
      // ORIENTATION
      // ========================================
      "portrait": { "raw": "(orientation: portrait)" },
      "landscape": { "raw": "(orientation: landscape)" },
      
      // ========================================
      // INPUT METHODS
      // ========================================
      // Touch devices (phones, tablets)
      "touch": { "raw": "(hover: none) and (pointer: coarse)" },
      // Stylus devices (drawing tablets)
      "stylus": { "raw": "(hover: none) and (pointer: fine)" },
      // Mouse/trackpad devices (laptops, desktops)
      "mouse": { "raw": "(hover: hover) and (pointer: fine)" },
      // Keyboard navigation
      "keyboard": { "raw": "(hover: hover)" },
      
      // ========================================
      // DISPLAY QUALITY
      // ========================================
      // Standard displays
      "standard-dpi": { "raw": "(max-resolution: 1dppx)" },
      // Retina / High-DPI displays
      "retina": { "raw": "(-webkit-min-device-pixel-ratio: 2), (min-resolution: 192dpi)" },
      // Super Retina / 3x displays
      "retina-3x": { "raw": "(-webkit-min-device-pixel-ratio: 3), (min-resolution: 288dpi)" },
      
      // ========================================
      // USER PREFERENCES
      // ========================================
      "motion-safe": { "raw": "(prefers-reduced-motion: no-preference)" },
      "motion-reduce": { "raw": "(prefers-reduced-motion: reduce)" },
      "dark-mode": { "raw": "(prefers-color-scheme: dark)" },
      "light-mode": { "raw": "(prefers-color-scheme: light)" },
      "high-contrast": { "raw": "(prefers-contrast: high)" },
      
      // ========================================
      // SPECIAL SCREENS
      // ========================================
      // Short screens (landscape phones)
      "short": { "raw": "(max-height: 500px)" },
      // Tall screens
      "tall": { "raw": "(min-height: 900px)" },
      // Wide screens (ultra-wide monitors)
      "wide": { "raw": "(min-aspect-ratio: 21/9)" },
      // Square-ish screens
      "square": { "raw": "(min-aspect-ratio: 3/4) and (max-aspect-ratio: 4/3)" },
      
      // ========================================
      // TV & LARGE SCREENS
      // ========================================
      "tv": { "raw": "(min-width: 1920px) and (min-height: 1080px)" },
      "tv-4k": { "raw": "(min-width: 3840px)" },
      
      // ========================================
      // CHROMEBOOK / HYBRID
      // ========================================
      "chromebook": { "raw": "(min-width: 1024px) and (hover: hover) and (pointer: fine), (min-width: 1024px) and (hover: none) and (pointer: coarse)" },
      
      // ========================================
      // PRINT
      // ========================================
      "print": { "raw": "print" },
      "screen": { "raw": "screen" },
    },
    extend: {
      fontFamily: {
        // Noto Sans as primary - supports 300+ languages/scripts
        sans: [
          'Noto Sans',
          'Noto Sans Devanagari',
          'Noto Sans Bengali',
          'Noto Sans Tamil',
          'Noto Sans Telugu',
          'Noto Sans Kannada',
          'Noto Sans Malayalam',
          'Noto Sans Gujarati',
          'Noto Sans Gurmukhi',
          'Noto Sans Arabic',
          'Noto Sans Hebrew',
          'Noto Sans Thai',
          'Noto Sans SC',
          'Noto Sans JP',
          'Noto Sans KR',
          'system-ui',
          '-apple-system',
          'sans-serif'
        ],
        display: [
          'Noto Sans',
          'Noto Sans Devanagari',
          'Noto Sans Arabic',
          'Noto Sans SC',
          'system-ui',
          'sans-serif'
        ],
        mono: [
          'Noto Sans Mono',
          'ui-monospace',
          'monospace'
        ],
      },
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
          glow: "hsl(var(--primary-glow))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        sidebar: {
          DEFAULT: "hsl(var(--sidebar-background))",
          foreground: "hsl(var(--sidebar-foreground))",
          primary: "hsl(var(--sidebar-primary))",
          "primary-foreground": "hsl(var(--sidebar-primary-foreground))",
          accent: "hsl(var(--sidebar-accent))",
          "accent-foreground": "hsl(var(--sidebar-accent-foreground))",
          border: "hsl(var(--sidebar-border))",
          ring: "hsl(var(--sidebar-ring))",
        },
        // Semantic status colors - use these instead of hardcoded colors
        success: {
          DEFAULT: "hsl(var(--success))",
          foreground: "hsl(var(--success-foreground))",
        },
        warning: {
          DEFAULT: "hsl(var(--warning))",
          foreground: "hsl(var(--warning-foreground))",
        },
        info: {
          DEFAULT: "hsl(var(--info))",
          foreground: "hsl(var(--info-foreground))",
        },
        // Status indicator colors
        online: {
          DEFAULT: "hsl(var(--online))",
          foreground: "hsl(var(--online-foreground))",
        },
        offline: {
          DEFAULT: "hsl(var(--offline))",
          foreground: "hsl(var(--offline-foreground))",
        },
        busy: {
          DEFAULT: "hsl(var(--busy))",
          foreground: "hsl(var(--busy-foreground))",
        },
        away: {
          DEFAULT: "hsl(var(--away))",
          foreground: "hsl(var(--away-foreground))",
        },
        // Gender colors
        male: "hsl(var(--male))",
        female: "hsl(var(--female))",
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
        xl: "calc(var(--radius) + 4px)",
        "2xl": "calc(var(--radius) + 8px)",
      },
      spacing: {
        // Safe area spacing
        "safe-top": "env(safe-area-inset-top)",
        "safe-right": "env(safe-area-inset-right)",
        "safe-bottom": "env(safe-area-inset-bottom)",
        "safe-left": "env(safe-area-inset-left)",
        // Touch-friendly sizes
        "touch": "44px",
        "touch-sm": "36px",
        "touch-lg": "48px",
      },
      minHeight: {
        "screen-safe": "calc(100vh - env(safe-area-inset-top) - env(safe-area-inset-bottom))",
        "touch": "44px",
      },
      maxWidth: {
        "mobile": "480px",
        "tablet": "768px",
        "laptop": "1024px",
        "desktop": "1280px",
        "wide": "1536px",
      },
      fontSize: {
        // Responsive font sizes
        "responsive-xs": ["clamp(0.75rem, 2vw, 0.875rem)", { lineHeight: "1.4" }],
        "responsive-sm": ["clamp(0.875rem, 2.5vw, 1rem)", { lineHeight: "1.5" }],
        "responsive-base": ["clamp(1rem, 3vw, 1.125rem)", { lineHeight: "1.6" }],
        "responsive-lg": ["clamp(1.125rem, 3.5vw, 1.25rem)", { lineHeight: "1.5" }],
        "responsive-xl": ["clamp(1.25rem, 4vw, 1.5rem)", { lineHeight: "1.4" }],
        "responsive-2xl": ["clamp(1.5rem, 5vw, 2rem)", { lineHeight: "1.3" }],
        "responsive-3xl": ["clamp(2rem, 6vw, 3rem)", { lineHeight: "1.2" }],
        "responsive-4xl": ["clamp(2.5rem, 8vw, 4rem)", { lineHeight: "1.1" }],
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        shimmer: {
          "100%": { transform: "translateX(100%)" },
        },
        danmu: {
          "0%": { transform: "translateX(0)" },
          "100%": { transform: "translateX(calc(-100% - 100vw))" },
        },
        "float-up": {
          "0%": { opacity: "1", transform: "translateY(0) scale(1)" },
          "50%": { opacity: "0.8", transform: "translateY(-80px) scale(1.2)" },
          "100%": { opacity: "0", transform: "translateY(-160px) scale(0.8)" },
        },
        "gift-entrance": {
          "0%": { opacity: "0", transform: "scale(0.3) rotate(-10deg)" },
          "50%": { opacity: "1", transform: "scale(1.15) rotate(2deg)" },
          "70%": { opacity: "1", transform: "scale(0.95) rotate(-1deg)" },
          "100%": { opacity: "1", transform: "scale(1) rotate(0deg)" },
        },
        "gift-pulse": {
          "0%, 100%": { transform: "scale(1)" },
          "50%": { transform: "scale(1.05)" },
        },
        marquee: {
          "0%": { transform: "translateX(0)" },
          "100%": { transform: "translateX(-50%)" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        shimmer: "shimmer 2s infinite",
        danmu: "danmu 8s linear forwards",
        "float-up": "float-up 3s ease-out forwards",
        "gift-entrance": "gift-entrance 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) forwards",
        "gift-pulse": "gift-pulse 2s ease-in-out infinite",
        marquee: "marquee 40s linear infinite",
      },
      boxShadow: {
        soft: "var(--shadow-soft)",
        card: "var(--shadow-card)",
        glow: "var(--shadow-glow)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
} satisfies Config;
