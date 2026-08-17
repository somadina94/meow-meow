/**
 * useDeviceDetect.ts
 * 
 * Comprehensive device detection hook for ALL platforms
 * Supports: Mobile, Tablets, Laptops, Desktops, Chromebooks, Foldables, TVs
 */

import { useState, useEffect, useMemo } from 'react';

export interface DeviceInfo {
  // Device category
  deviceCategory: 'mobile' | 'phablet' | 'tablet' | 'laptop' | 'desktop' | 'tv' | 'wearable' | 'unknown';
  
  // Device types
  isMobile: boolean;
  isPhablet: boolean;
  isTablet: boolean;
  isLaptop: boolean;
  isDesktop: boolean;
  isTV: boolean;
  isWearable: boolean;
  isFoldable: boolean;
  isFoldOpen: boolean;
  isChromebook: boolean;
  
  // Operating System - Comprehensive support
  os: 'ios' | 'ipados' | 'android' | 'windows' | 'macos' | 'linux' | 'chromeos' | 'tvos' | 'tizen' | 'webos' | 'fireos' | 'watchos' | 'wearos' | 'unknown';
  osVersion: string;
  isIOS: boolean;
  isIPadOS: boolean;
  isAndroid: boolean;
  isWindows: boolean;
  isMacOS: boolean;
  isLinux: boolean;
  isChromeOS: boolean;
  isTvOS: boolean;
  isTizen: boolean;
  isWebOS: boolean;
  isFireOS: boolean;
  isWatchOS: boolean;
  isWearOS: boolean;
  
  // Browser - All major browsers worldwide
  browser: 'chrome' | 'safari' | 'firefox' | 'edge' | 'opera' | 'samsung' | 'brave' | 'vivaldi' | 'uc' | 'qq' | 'baidu' | 'yandex' | 'silk' | 'unknown';
  browserVersion: string;
  isChrome: boolean;
  isSafari: boolean;
  isFirefox: boolean;
  isEdge: boolean;
  isOpera: boolean;
  isSamsung: boolean;
  isBrave: boolean;
  isVivaldi: boolean;
  isUCBrowser: boolean;
  isQQBrowser: boolean;
  isBaidu: boolean;
  isYandex: boolean;
  isSilk: boolean;
  
  // Specific devices - All major manufacturers
  isIPhone: boolean;
  isIPad: boolean;
  isAndroidPhone: boolean;
  isAndroidTablet: boolean;
  isMac: boolean;
  isSamsungGalaxy: boolean;
  isSamsungFold: boolean;
  isPixel: boolean;
  isOnePlus: boolean;
  isXiaomi: boolean;
  isHuawei: boolean;
  isOppo: boolean;
  isVivo: boolean;
  isRealme: boolean;
  isKindleFire: boolean;
  isGalaxyTab: boolean;
  isGalaxyWatch: boolean;
  isAppleWatch: boolean;
  isSmartTV: boolean;
  isAppleTV: boolean;
  isAndroidTV: boolean;
  isSamsungTV: boolean;
  isLGTV: boolean;
  isSonyTV: boolean;
  
  // Input capabilities
  isTouch: boolean;
  isStylus: boolean;
  isMouse: boolean;
  hasCamera: boolean;
  hasMicrophone: boolean;
  hasKeyboard: boolean;
  hasGamepad: boolean;
  
  // PWA/Native
  isPWA: boolean;
  isStandalone: boolean;
  isNativeApp: boolean;
  isCapacitor: boolean;
  isElectron: boolean;
  
  // Display
  isRetina: boolean;
  isRetina3x: boolean;
  is4K: boolean;
  isUltraWide: boolean;
  isLandscape: boolean;
  isPortrait: boolean;
  screenWidth: number;
  screenHeight: number;
  pixelRatio: number;
  
  // Preferences
  prefersReducedMotion: boolean;
  prefersDarkMode: boolean;
  prefersHighContrast: boolean;
  prefersReducedTransparency: boolean;
  
  // Network
  isOnline: boolean;
  connectionType: string;
  isSlowConnection: boolean;
}

export function useDeviceDetect(): DeviceInfo {
  const [screenWidth, setScreenWidth] = useState(typeof window !== 'undefined' ? window.innerWidth : 1024);
  const [screenHeight, setScreenHeight] = useState(typeof window !== 'undefined' ? window.innerHeight : 768);
  const [isOnline, setIsOnline] = useState(typeof navigator !== 'undefined' ? navigator.onLine : true);
  const [isLandscape, setIsLandscape] = useState(typeof window !== 'undefined' ? window.innerWidth > window.innerHeight : true);

  useEffect(() => {
    const handleResize = () => {
      setScreenWidth(window.innerWidth);
      setScreenHeight(window.innerHeight);
      setIsLandscape(window.innerWidth > window.innerHeight);
    };

    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('resize', handleResize);
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const deviceInfo = useMemo<DeviceInfo>(() => {
    if (typeof window === 'undefined' || typeof navigator === 'undefined') {
      return getDefaultDeviceInfo();
    }

    const ua = navigator.userAgent.toLowerCase();
    const platform = navigator.platform?.toLowerCase() || '';

    // ========================================
    // COMPREHENSIVE OS DETECTION
    // ========================================
    const isIOS = /iphone|ipod/.test(ua) || (platform === 'iphone');
    const isIPadOS = /ipad/.test(ua) || (platform === 'macintel' && navigator.maxTouchPoints > 1);
    const isAndroid = /android/.test(ua);
    const isWindows = /win/.test(platform) || /windows/.test(ua);
    const isMacOS = /mac/.test(platform) && !isIOS && !isIPadOS;
    const isLinux = /linux/.test(platform) && !isAndroid;
    const isChromeOS = /cros/.test(ua);
    const isTvOS = /appletv/.test(ua);
    const isTizen = /tizen/.test(ua);
    const isWebOS = /webos|web0s/.test(ua);
    const isFireOS = /silk|kindle|kf/.test(ua);
    const isWatchOS = /watch/.test(ua) && /apple/.test(ua);
    const isWearOS = /wearos|android.*watch/.test(ua);

    // ========================================
    // COMPREHENSIVE DEVICE DETECTION
    // ========================================
    // Apple devices
    const isIPhone = isIOS && !/ipad/.test(ua);
    const isIPad = isIPadOS;
    const isAppleWatch = isWatchOS;
    const isAppleTV = isTvOS;
    
    // Samsung devices
    const isSamsungGalaxy = /samsung|sm-g|sm-a|sm-n|sm-s/.test(ua);
    const isSamsungFold = /sm-f/.test(ua);
    const isGalaxyTab = /sm-t|sm-x/.test(ua);
    const isGalaxyWatch = /sm-r/.test(ua);
    const isSamsungTV = isTizen && /smart-tv|samsungtv/.test(ua);
    
    // Google devices
    const isPixel = /pixel/.test(ua);
    const isAndroidTV = /android.*tv|googletv/.test(ua);
    
    // Other manufacturers
    const isOnePlus = /oneplus/.test(ua);
    const isXiaomi = /xiaomi|mi\s|redmi|poco/.test(ua);
    const isHuawei = /huawei|honor/.test(ua);
    const isOppo = /oppo|cph/.test(ua);
    const isVivo = /vivo/.test(ua);
    const isRealme = /realme|rmx/.test(ua);
    const isKindleFire = /kindle|kf|silk/.test(ua);
    
    // TV detection
    const isLGTV = isWebOS;
    const isSonyTV = /sony.*tv|bravia/.test(ua);
    const isSmartTV = isTizen || isWebOS || isAndroidTV || isTvOS || /smart-tv|hbbtv|netcast/.test(ua);
    const isTV = isSmartTV || (screenWidth >= 1920 && screenHeight >= 1080 && !/mobile|tablet/.test(ua));
    
    // Wearable detection
    const isWearable = isWatchOS || isWearOS || isGalaxyWatch || isAppleWatch;
    
    // Foldable detection
    const isFoldable = isSamsungFold || /fold|razr|surface duo/.test(ua) || screenWidth <= 300;
    const isFoldOpen = isFoldable && screenWidth > 500;

    // Android tablet vs phone
    const isAndroidTablet = isAndroid && (!/mobile/.test(ua) || isGalaxyTab);
    const isAndroidPhone = isAndroid && /mobile/.test(ua) && !isAndroidTablet;

    // Screen size based detection
    const isPhablet = screenWidth >= 428 && screenWidth < 768 && !isTV;
    const isMobile = screenWidth < 428 && !isTV && !isWearable;
    const isTablet = screenWidth >= 768 && screenWidth < 1024 && !isTV;
    const isLaptop = screenWidth >= 1024 && screenWidth < 1280 && !isTV;
    const isDesktop = screenWidth >= 1280 && !isTV;
    const isChromebook = isChromeOS && screenWidth >= 1024;
    
    // Device category
    const deviceCategory = isWearable ? 'wearable' : isTV ? 'tv' : isDesktop ? 'desktop' : 
                          isLaptop ? 'laptop' : isTablet ? 'tablet' : isPhablet ? 'phablet' : 
                          isMobile ? 'mobile' : 'unknown';

    // ========================================
    // COMPREHENSIVE BROWSER DETECTION
    // ========================================
    const isUCBrowser = /ucbrowser|ucweb/.test(ua);
    const isQQBrowser = /qqbrowser|mqqbrowser/.test(ua);
    const isBaidu = /baidubrowser|baiduboxapp/.test(ua);
    const isYandex = /yabrowser/.test(ua);
    const isSilk = /silk/.test(ua);
    const isBrave = /brave/.test(ua) || !!(navigator as any).brave;
    const isVivaldi = /vivaldi/.test(ua);
    const isSamsung = /samsungbrowser/.test(ua);
    const isOpera = /opr|opera/.test(ua);
    const isEdge = /edge|edg/.test(ua);
    const isFirefox = /firefox|fxios/.test(ua);
    const isSafari = /safari/.test(ua) && !/chrome|chromium|crios|fxios|edge|edg/.test(ua);
    const isChrome = (/chrome|crios/.test(ua)) && !/edge|edg|opr|opera|brave|vivaldi|samsungbrowser|ucbrowser|qqbrowser|yabrowser/.test(ua);

    // Get browser version
    const getBrowserVersion = () => {
      if (isChrome) return ua.match(/(?:chrome|crios)\/(\d+)/)?.[1] || '';
      if (isSafari) return ua.match(/version\/(\d+)/)?.[1] || '';
      if (isFirefox) return ua.match(/(?:firefox|fxios)\/(\d+)/)?.[1] || '';
      if (isEdge) return ua.match(/edg\/(\d+)/)?.[1] || '';
      if (isOpera) return ua.match(/opr\/(\d+)/)?.[1] || '';
      if (isSamsung) return ua.match(/samsungbrowser\/(\d+)/)?.[1] || '';
      if (isUCBrowser) return ua.match(/ucbrowser\/(\d+)/)?.[1] || '';
      return '';
    };

    // Get OS version
    const getOSVersion = () => {
      if (isIOS || isIPadOS) return ua.match(/os (\d+[._]\d+)/)?.[1]?.replace('_', '.') || '';
      if (isAndroid) return ua.match(/android (\d+\.?\d*)/)?.[1] || '';
      if (isWindows) {
        const ntVersion = ua.match(/windows nt (\d+\.?\d*)/)?.[1];
        if (ntVersion === '10.0') return '10/11';
        if (ntVersion === '6.3') return '8.1';
        if (ntVersion === '6.2') return '8';
        if (ntVersion === '6.1') return '7';
        return ntVersion || '';
      }
      if (isMacOS) return ua.match(/mac os x (\d+[._]\d+)/)?.[1]?.replace('_', '.') || '';
      if (isChromeOS) return ua.match(/cros[^)]*?(\d+)/)?.[1] || '';
      return '';
    };

    // ========================================
    // INPUT CAPABILITIES
    // ========================================
    const isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    const isMouse = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    const isStylus = window.matchMedia('(hover: none) and (pointer: fine)').matches;
    const hasKeyboard = 'keyboard' in navigator || window.matchMedia('(hover: hover)').matches;
    const hasGamepad = 'getGamepads' in navigator;

    // ========================================
    // PWA/NATIVE DETECTION
    // ========================================
    const isPWA = window.matchMedia('(display-mode: standalone)').matches ||
                  (window.navigator as any).standalone === true ||
                  document.referrer.includes('android-app://');
    const isCapacitor = !!(window as any).Capacitor?.isNativePlatform?.();
    const isElectron = !!(window as any).process?.versions?.electron;

    // ========================================
    // USER PREFERENCES
    // ========================================
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const prefersDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const prefersHighContrast = window.matchMedia('(prefers-contrast: high)').matches;
    const prefersReducedTransparency = window.matchMedia('(prefers-reduced-transparency: reduce)').matches;

    // ========================================
    // DISPLAY CHARACTERISTICS
    // ========================================
    const pixelRatio = window.devicePixelRatio || 1;
    const isRetina = pixelRatio >= 2;
    const is4K = screenWidth >= 3840 || screenHeight >= 2160;
    const isUltraWide = screenWidth / screenHeight > 2;

    // ========================================
    // NETWORK
    // ========================================
    const connection = (navigator as any).connection;
    const connectionType = connection?.effectiveType || 'unknown';
    const isSlowConnection = connectionType === '2g' || connectionType === 'slow-2g';

    // Determine OS
    const os = isIOS ? 'ios' : isIPadOS ? 'ipados' : isAndroid ? 'android' : 
              isWindows ? 'windows' : isMacOS ? 'macos' : isLinux ? 'linux' : 
              isChromeOS ? 'chromeos' : isTvOS ? 'tvos' : isTizen ? 'tizen' : 
              isWebOS ? 'webos' : isFireOS ? 'fireos' : isWatchOS ? 'watchos' : 
              isWearOS ? 'wearos' : 'unknown';

    // Determine browser
    const browser = isChrome ? 'chrome' : isSafari ? 'safari' : isFirefox ? 'firefox' :
                   isEdge ? 'edge' : isOpera ? 'opera' : isSamsung ? 'samsung' : 
                   isBrave ? 'brave' : isVivaldi ? 'vivaldi' : isUCBrowser ? 'uc' :
                   isQQBrowser ? 'qq' : isBaidu ? 'baidu' : isYandex ? 'yandex' :
                   isSilk ? 'silk' : 'unknown';

    return {
      deviceCategory,
      isMobile,
      isPhablet,
      isTablet,
      isLaptop,
      isDesktop,
      isTV,
      isWearable,
      isFoldable,
      isFoldOpen,
      isChromebook,
      os,
      osVersion: getOSVersion(),
      isIOS,
      isIPadOS,
      isAndroid,
      isWindows,
      isMacOS,
      isLinux,
      isChromeOS,
      isTvOS,
      isTizen,
      isWebOS,
      isFireOS,
      isWatchOS,
      isWearOS,
      browser,
      browserVersion: getBrowserVersion(),
      isChrome,
      isSafari,
      isFirefox,
      isEdge,
      isOpera,
      isSamsung,
      isBrave,
      isVivaldi,
      isUCBrowser,
      isQQBrowser,
      isBaidu,
      isYandex,
      isSilk,
      isIPhone,
      isIPad,
      isAndroidPhone,
      isAndroidTablet,
      isMac: isMacOS,
      isSamsungGalaxy,
      isSamsungFold,
      isPixel,
      isOnePlus,
      isXiaomi,
      isHuawei,
      isOppo,
      isVivo,
      isRealme,
      isKindleFire,
      isGalaxyTab,
      isGalaxyWatch,
      isAppleWatch,
      isSmartTV,
      isAppleTV,
      isAndroidTV,
      isSamsungTV,
      isLGTV,
      isSonyTV,
      isTouch,
      isStylus,
      isMouse,
      hasCamera: !!(navigator.mediaDevices?.getUserMedia),
      hasMicrophone: !!(navigator.mediaDevices?.getUserMedia),
      hasKeyboard,
      hasGamepad,
      isPWA,
      isStandalone: isPWA,
      isNativeApp: isCapacitor || isElectron,
      isCapacitor,
      isElectron,
      isRetina,
      isRetina3x: pixelRatio >= 3,
      is4K,
      isUltraWide,
      isLandscape,
      isPortrait: !isLandscape,
      screenWidth,
      screenHeight,
      pixelRatio,
      prefersReducedMotion,
      prefersDarkMode,
      prefersHighContrast,
      prefersReducedTransparency,
      isOnline,
      connectionType,
      isSlowConnection,
    };
  }, [screenWidth, screenHeight, isOnline, isLandscape]);

  return deviceInfo;
}

function getDefaultDeviceInfo(): DeviceInfo {
  return {
    deviceCategory: 'desktop',
    isMobile: false,
    isPhablet: false,
    isTablet: false,
    isLaptop: false,
    isDesktop: true,
    isTV: false,
    isWearable: false,
    isFoldable: false,
    isFoldOpen: false,
    isChromebook: false,
    os: 'unknown',
    osVersion: '',
    isIOS: false,
    isIPadOS: false,
    isAndroid: false,
    isWindows: false,
    isMacOS: false,
    isLinux: false,
    isChromeOS: false,
    isTvOS: false,
    isTizen: false,
    isWebOS: false,
    isFireOS: false,
    isWatchOS: false,
    isWearOS: false,
    browser: 'unknown',
    browserVersion: '',
    isChrome: false,
    isSafari: false,
    isFirefox: false,
    isEdge: false,
    isOpera: false,
    isSamsung: false,
    isBrave: false,
    isVivaldi: false,
    isUCBrowser: false,
    isQQBrowser: false,
    isBaidu: false,
    isYandex: false,
    isSilk: false,
    isIPhone: false,
    isIPad: false,
    isAndroidPhone: false,
    isAndroidTablet: false,
    isMac: false,
    isSamsungGalaxy: false,
    isSamsungFold: false,
    isPixel: false,
    isOnePlus: false,
    isXiaomi: false,
    isHuawei: false,
    isOppo: false,
    isVivo: false,
    isRealme: false,
    isKindleFire: false,
    isGalaxyTab: false,
    isGalaxyWatch: false,
    isAppleWatch: false,
    isSmartTV: false,
    isAppleTV: false,
    isAndroidTV: false,
    isSamsungTV: false,
    isLGTV: false,
    isSonyTV: false,
    isTouch: false,
    isStylus: false,
    isMouse: true,
    hasCamera: false,
    hasMicrophone: false,
    hasKeyboard: true,
    hasGamepad: false,
    isPWA: false,
    isStandalone: false,
    isNativeApp: false,
    isCapacitor: false,
    isElectron: false,
    isRetina: false,
    isRetina3x: false,
    is4K: false,
    isUltraWide: false,
    isLandscape: true,
    isPortrait: false,
    screenWidth: 1024,
    screenHeight: 768,
    pixelRatio: 1,
    prefersReducedMotion: false,
    prefersDarkMode: false,
    prefersHighContrast: false,
    prefersReducedTransparency: false,
    isOnline: true,
    connectionType: 'unknown',
    isSlowConnection: false,
  };
}

// Utility hook for responsive breakpoints
export function useBreakpoint() {
  const { screenWidth } = useDeviceDetect();
  
  return {
    xs: screenWidth >= 320,
    sm: screenWidth >= 480,
    md: screenWidth >= 768,
    lg: screenWidth >= 1024,
    xl: screenWidth >= 1280,
    '2xl': screenWidth >= 1536,
    '3xl': screenWidth >= 1920,
  };
}

// Utility hook for orientation
export function useOrientation() {
  const { isLandscape, isPortrait } = useDeviceDetect();
  return { isLandscape, isPortrait };
}

// Utility hook for online status
export function useOnlineStatus() {
  const { isOnline, connectionType } = useDeviceDetect();
  return { isOnline, connectionType };
}
