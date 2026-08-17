/**
 * useNativeApp.ts
 * 
 * PURPOSE: Detect native app environment (iOS/Android via Capacitor)
 * and provide platform-specific utilities.
 */

import { useState, useEffect } from "react";

interface NativeAppInfo {
  isNative: boolean;
  platform: "ios" | "android" | "web";
  isIOS: boolean;
  isAndroid: boolean;
  hasNotch: boolean;
  safeAreaInsets: {
    top: number;
    bottom: number;
    left: number;
    right: number;
  };
}

export function useNativeApp(): NativeAppInfo {
  const [appInfo, setAppInfo] = useState<NativeAppInfo>({
    isNative: false,
    platform: "web",
    isIOS: false,
    isAndroid: false,
    hasNotch: false,
    safeAreaInsets: { top: 0, bottom: 0, left: 0, right: 0 },
  });

  useEffect(() => {
    const detectPlatform = () => {
      const userAgent = navigator.userAgent.toLowerCase();
      const isCapacitor = !!(window as { Capacitor?: unknown }).Capacitor;
      
      // Detect platform
      const isIOS = /iphone|ipad|ipod/.test(userAgent) || 
        (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
      const isAndroid = /android/.test(userAgent);
      
      // Detect notch (iPhone X and later)
      const hasNotch = isIOS && (
        window.screen.height >= 812 || // iPhone X, XS, 11 Pro, 12 mini, 13 mini
        window.screen.width >= 812 // Landscape
      );

      // Get safe area insets from CSS environment variables
      const computedStyle = getComputedStyle(document.documentElement);
      const safeAreaTop = parseInt(computedStyle.getPropertyValue("--sat") || "0", 10) || 0;
      const safeAreaBottom = parseInt(computedStyle.getPropertyValue("--sab") || "0", 10) || 0;
      const safeAreaLeft = parseInt(computedStyle.getPropertyValue("--sal") || "0", 10) || 0;
      const safeAreaRight = parseInt(computedStyle.getPropertyValue("--sar") || "0", 10) || 0;

      setAppInfo({
        isNative: isCapacitor,
        platform: isIOS ? "ios" : isAndroid ? "android" : "web",
        isIOS,
        isAndroid,
        hasNotch,
        safeAreaInsets: {
          top: safeAreaTop,
          bottom: safeAreaBottom,
          left: safeAreaLeft,
          right: safeAreaRight,
        },
      });
    };

    detectPlatform();
    window.addEventListener("resize", detectPlatform);
    
    return () => window.removeEventListener("resize", detectPlatform);
  }, []);

  return appInfo;
}
