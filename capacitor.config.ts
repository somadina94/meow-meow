/**
 * Capacitor Configuration
 * 
 * This file configures the native mobile app settings for iOS and Android.
 * 
 * SECURITY FEATURES:
 * - Android: FLAG_SECURE enabled to prevent screenshots
 * - iOS: Screenshot detection (cannot prevent on iOS due to OS limitations)
 * - Both: Secure content mode enabled
 */

import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  // Unique app identifier
  appId: 'app.lovable.83206b95108442d8a3efe71e72b4dab6',
  
  // Display name in app stores
  appName: 'Meow Meow',
  
  // Build output directory
  webDir: 'dist',
  
  // iOS-specific configuration
  ios: {
    contentInset: 'automatic',
    backgroundColor: '#0a0d14',
    preferredContentMode: 'mobile',
    // Enable screenshot protection notification
    handleApplicationNotifications: true,
  },
  
  // Android-specific configuration
  android: {
    backgroundColor: '#0a0d14',
    allowMixedContent: true,
    // SECURITY: Enable FLAG_SECURE to prevent screenshots
    // This blocks screenshots and screen recording on Android
    // Note: Requires native code modification - see android/app/src/main/java/.../MainActivity.java
    captureInput: true,
    webContentsDebuggingEnabled: false, // Disable in production
  },
  
  // Plugin configurations
  plugins: {
    // Keyboard behavior
    Keyboard: {
      resize: 'body',
      style: 'dark',
      resizeOnFullScreen: true,
    },
    // Status bar appearance
    StatusBar: {
      style: 'dark',
      backgroundColor: '#0a0d14',
    },
    // Splash screen settings
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#0a0d14',
      showSpinner: false,
    },
    // Privacy screen - blur app in recent apps
    PrivacyScreen: {
      enable: true,
    },
  },
  
  // Server configuration for development
  // Uncomment for hot-reload during development:
  // server: {
  //   url: 'https://83206b95-1084-42d8-a3ef-e71e72b4dab6.lovableproject.com?forceHideBadge=true',
  //   cleartext: true
  // },
};

export default config;
