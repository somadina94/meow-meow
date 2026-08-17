import { toast } from "sonner";
/**
 * usePWA.ts
 * 
 * PURPOSE: Universal PWA support for ALL devices, OS, and browsers
 * Supports: iOS Safari, Android Chrome, Windows Edge, macOS Safari, Linux Firefox, Samsung Internet, etc.
 */

import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { registerSW } from 'virtual:pwa-register';
import { supabase } from '@/integrations/supabase/client';

const isIframeOrPreviewHost = () => {
  if (typeof window === 'undefined') return true;
  const inIframe = (() => {
    try { return window.self !== window.top; }
    catch { return true; }
  })();
  const host = window.location.hostname;
  return inIframe || host.includes('id-preview--') || host.includes('lovableproject.com');
};

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

interface PWAState {
  // Installation
  isInstallable: boolean;
  isInstalled: boolean;
  canInstall: boolean;
  installMethod: 'prompt' | 'manual-ios' | 'manual-android' | 'none';
  
  // Updates
  needsUpdate: boolean;
  
  // Connectivity
  isOffline: boolean;
  connectionType: string;
  isSlowConnection: boolean;
  
  // Platform Detection
  isIOS: boolean;
  isIPadOS: boolean;
  isAndroid: boolean;
  isMacOS: boolean;
  isWindows: boolean;
  isLinux: boolean;
  isChromeOS: boolean;
  
  // Browser Detection
  isChrome: boolean;
  isSafari: boolean;
  isFirefox: boolean;
  isEdge: boolean;
  isSamsungInternet: boolean;
  isOpera: boolean;
  isBrave: boolean;
  isUCBrowser: boolean;
  
  // Push Notifications
  isPushSupported: boolean;
  isPushEnabled: boolean;
  pushPermission: NotificationPermission | 'unsupported';
  
  // Features Support
  isBackgroundSyncSupported: boolean;
  isPeriodicSyncSupported: boolean;
  isShareTargetSupported: boolean;
  isBadgingSupported: boolean;
  isWakeLockSupported: boolean;
  isFileSystemSupported: boolean;
  
  // Storage
  storageQuota: number;
  storageUsed: number;
  isPersistentStorageGranted: boolean;
}

export function usePWA() {
  const [installPrompt, setInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const disableServiceWorker = isIframeOrPreviewHost();
  const [needRefresh, setNeedRefresh] = useState(false);
  const updateServiceWorkerRef = useRef<(reloadPage?: boolean) => Promise<void>>(async () => undefined);
  const [state, setState] = useState<PWAState>({
    isInstallable: false,
    isInstalled: false,
    canInstall: false,
    installMethod: 'none',
    needsUpdate: false,
    isOffline: typeof navigator !== 'undefined' ? !navigator.onLine : false,
    connectionType: 'unknown',
    isSlowConnection: false,
    isIOS: false,
    isIPadOS: false,
    isAndroid: false,
    isMacOS: false,
    isWindows: false,
    isLinux: false,
    isChromeOS: false,
    isChrome: false,
    isSafari: false,
    isFirefox: false,
    isEdge: false,
    isSamsungInternet: false,
    isOpera: false,
    isBrave: false,
    isUCBrowser: false,
    isPushSupported: false,
    isPushEnabled: false,
    pushPermission: 'unsupported',
    isBackgroundSyncSupported: false,
    isPeriodicSyncSupported: false,
    isShareTargetSupported: false,
    isBadgingSupported: false,
    isWakeLockSupported: false,
    isFileSystemSupported: false,
    storageQuota: 0,
    storageUsed: 0,
    isPersistentStorageGranted: false,
  });

  const checkPushPermission = useCallback(async () => {
    if ('Notification' in window) {
      const permission = Notification.permission;
      setState(prev => ({ 
        ...prev, 
        isPushEnabled: permission === 'granted',
        pushPermission: permission,
      }));
    }
  }, []);

  const checkStorageInfo = useCallback(async () => {
    if ('storage' in navigator && 'estimate' in navigator.storage) {
      try {
        const estimate = await navigator.storage.estimate();
        const isPersisted = await navigator.storage.persisted?.() || false;
        setState(prev => ({
          ...prev,
          storageQuota: estimate.quota || 0,
          storageUsed: estimate.usage || 0,
          isPersistentStorageGranted: isPersisted,
        }));
      } catch (error) {
        console.error('Failed to get storage estimate:', error);
      }
    }
  }, []);

  useEffect(() => {
    if (disableServiceWorker) {
      navigator.serviceWorker?.getRegistrations().then((registrations) => {
        registrations.forEach((registration) => registration.unregister());
      }).catch(() => undefined);
      return;
    }

    updateServiceWorkerRef.current = registerSW({
      immediate: true,
      onNeedRefresh: () => setNeedRefresh(true),
      onRegistered(registration) {
        console.log('Service Worker registered:', registration);
        checkPushPermission();
        checkStorageInfo();
      },
      onRegisterError(error) {
        console.error('Service Worker registration error:', error);
      },
    });
  }, [disableServiceWorker, checkPushPermission, checkStorageInfo]);

  // Comprehensive platform and browser detection
  useEffect(() => {
    if (typeof navigator === 'undefined') return;

    const ua = navigator.userAgent.toLowerCase();
    const platform = navigator.platform?.toLowerCase() || '';

    // OS Detection
    const isIOS = /iphone|ipod/.test(ua);
    const isIPadOS = /ipad/.test(ua) || (platform === 'macintel' && navigator.maxTouchPoints > 1);
    const isAndroid = /android/.test(ua);
    const isMacOS = /mac/.test(platform) && !isIOS && !isIPadOS;
    const isWindows = /win/.test(platform) || /windows/.test(ua);
    const isLinux = /linux/.test(platform) && !isAndroid;
    const isChromeOS = /cros/.test(ua);

    // Browser Detection
    const isChrome = /chrome/.test(ua) && !/edge|edg|opr|opera|brave/.test(ua);
    const isSafari = /safari/.test(ua) && !/chrome|chromium|crios/.test(ua);
    const isFirefox = /firefox|fxios/.test(ua);
    const isEdge = /edge|edg/.test(ua);
    const isSamsungInternet = /samsungbrowser/.test(ua);
    const isOpera = /opr|opera/.test(ua);
    const isBrave = /brave/.test(ua) || !!(navigator as any).brave;
    const isUCBrowser = /ucbrowser|ucweb/.test(ua);

    // Check if already installed
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true ||
      document.referrer.includes('android-app://');

    // Determine install method based on platform/browser
    let installMethod: PWAState['installMethod'] = 'none';
    if (!isStandalone) {
      if (isIOS || isIPadOS) {
        installMethod = 'manual-ios'; // iOS requires Add to Home Screen
      } else if (isAndroid && !isSamsungInternet && !isChrome) {
        installMethod = 'manual-android'; // Some Android browsers need manual install
      } else {
        installMethod = 'prompt'; // Chrome, Edge, Samsung Internet support install prompt
      }
    }

    // Feature Detection
    const isPushSupported = 'PushManager' in window && 'serviceWorker' in navigator;
    const isBackgroundSyncSupported = 'SyncManager' in window;
    const isPeriodicSyncSupported = 'PeriodicSyncManager' in (navigator as any);
    const isShareTargetSupported = 'share' in navigator;
    const isBadgingSupported = 'setAppBadge' in navigator;
    const isWakeLockSupported = 'wakeLock' in navigator;
    const isFileSystemSupported = 'showOpenFilePicker' in window;

    // Connection info
    const connection = (navigator as any).connection;
    const connectionType = connection?.effectiveType || 'unknown';
    const isSlowConnection = connectionType === '2g' || connectionType === 'slow-2g';

    setState(prev => ({
      ...prev,
      isIOS,
      isIPadOS,
      isAndroid,
      isMacOS,
      isWindows,
      isLinux,
      isChromeOS,
      isChrome,
      isSafari,
      isFirefox,
      isEdge,
      isSamsungInternet,
      isOpera,
      isBrave,
      isUCBrowser,
      isInstalled: isStandalone,
      installMethod,
      canInstall: !isStandalone && installMethod !== 'none',
      isPushSupported,
      pushPermission: 'Notification' in window ? Notification.permission : 'unsupported',
      isBackgroundSyncSupported,
      isPeriodicSyncSupported,
      isShareTargetSupported,
      isBadgingSupported,
      isWakeLockSupported,
      isFileSystemSupported,
      connectionType,
      isSlowConnection,
    }));
  }, []);

  // Handle online/offline status
  useEffect(() => {
    const handleOnline = () => setState(prev => ({ ...prev, isOffline: false }));
    const handleOffline = () => setState(prev => ({ ...prev, isOffline: true }));

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    const connection = (navigator as any).connection as {
      effectiveType?: string;
      addEventListener?: (type: string, listener: () => void) => void;
      removeEventListener?: (type: string, listener: () => void) => void;
      addListener?: (listener: () => void) => void;
      removeListener?: (listener: () => void) => void;
    } | undefined;

    if (connection) {
      const handleConnectionChange = () => {
        setState(prev => ({
          ...prev,
          connectionType: connection.effectiveType || 'unknown',
          isSlowConnection: connection.effectiveType === '2g' || connection.effectiveType === 'slow-2g',
        }));
      };

      if (typeof connection.addEventListener === 'function') {
        connection.addEventListener('change', handleConnectionChange);
      } else {
        connection.addListener?.(handleConnectionChange);
      }

      return () => {
        window.removeEventListener('online', handleOnline);
        window.removeEventListener('offline', handleOffline);
        if (typeof connection.removeEventListener === 'function') {
          connection.removeEventListener('change', handleConnectionChange);
        } else {
          connection.removeListener?.(handleConnectionChange);
        }
      };
    }

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  // Handle install prompt (Chrome, Edge, Samsung Internet, Opera)
  useEffect(() => {
    const handleBeforeInstall = (e: Event) => {
      e.preventDefault();
      setInstallPrompt(e as BeforeInstallPromptEvent);
      setState(prev => ({ ...prev, isInstallable: true, canInstall: true }));
    };

    const handleAppInstalled = () => {
      setInstallPrompt(null);
      setState(prev => ({ 
        ...prev, 
        isInstallable: false, 
        isInstalled: true,
        canInstall: false,
      }));
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstall);
    window.addEventListener('appinstalled', handleAppInstalled);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstall);
      window.removeEventListener('appinstalled', handleAppInstalled);
    };
  }, []);

  // Update needsUpdate state
  useEffect(() => {
    setState(prev => ({ ...prev, needsUpdate: needRefresh }));
  }, [needRefresh]);

  // Install PWA (for browsers that support install prompt)
  const install = useCallback(async (): Promise<boolean> => {
    // Detect environments where the native install prompt cannot fire
    const isInIframe = (() => {
      try { return typeof window !== 'undefined' && window.self !== window.top; }
      catch { return true; }
    })();
    const host = typeof window !== 'undefined' ? window.location.hostname : '';
    const isPreviewHost = host.includes('lovable.app') || host.includes('lovableproject.com') || host.includes('localhost');
    const alreadyStandalone = typeof window !== 'undefined' && (
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true
    );

    if (alreadyStandalone) {
      // Already installed — no-op, no error
      return true;
    }

    if (!installPrompt) {
      // Native prompt isn't available — give a helpful, platform-specific hint instead of an error
      if (import.meta.env.DEV) console.log('[PWA] Install prompt not available', { isInIframe, isPreviewHost });

      if (isInIframe || isPreviewHost) {
        toast.info('Open in your browser to install', {
          description: 'Installation only works on the published app, not inside the editor preview.',
        });
        return false;
      }

      if (state.isIOS || state.isIPadOS) {
        toast.info('Add to Home Screen', {
          description: 'Tap the Share icon in Safari, then choose "Add to Home Screen".',
        });
      } else if (state.isAndroid) {
        toast.info('Install from browser menu', {
          description: 'Tap the ⋮ menu in Chrome and choose "Install app" or "Add to Home screen".',
        });
      } else {
        toast.info('Install from browser', {
          description: 'Look for the install icon (⊕) in your browser\'s address bar, or use the browser menu.',
        });
      }
      return false;
    }

    try {
      await installPrompt.prompt();
      const { outcome } = await installPrompt.userChoice;

      if (outcome === 'accepted') {
        setInstallPrompt(null);
        setState(prev => ({
          ...prev,
          isInstallable: false,
          isInstalled: true,
          canInstall: false,
        }));
        toast.success('App installed', { description: 'You can now launch it from your home screen.' });
        return true;
      }
      // User dismissed — that's fine, no error toast
      return false;
    } catch (error: any) {
      console.error('Install failed:', error);
      // Only show a real error if it's something other than the user cancelling
      const msg = String(error?.message || error || '').toLowerCase();
      if (!msg.includes('cancel') && !msg.includes('dismiss') && !msg.includes('user gesture')) {
        toast.error('Installation unavailable', {
          description: 'Your browser did not allow installation. Try the browser menu → "Install app".',
        });
      }
      return false;
    }
  }, [installPrompt, state.isIOS, state.isIPadOS, state.isAndroid]);

  // Get install instructions for manual installation (iOS, some Android browsers)
  const getInstallInstructions = useCallback(() => {
    if (state.isIOS || state.isIPadOS) {
      return {
        title: 'Install on iOS',
        steps: [
          'Tap the Share button (square with arrow)',
          'Scroll down and tap "Add to Home Screen"',
          'Tap "Add" in the top right corner',
        ],
        icon: 'share',
      };
    }
    if (state.isAndroid) {
      if (state.isFirefox) {
        return {
          title: 'Install on Android (Firefox)',
          steps: [
            'Tap the menu button (three dots)',
            'Tap "Install"',
            'Follow the prompts to install',
          ],
          icon: 'menu',
        };
      }
      return {
        title: 'Install on Android',
        steps: [
          'Tap the menu button (three dots)',
          'Tap "Add to Home Screen" or "Install App"',
          'Follow the prompts to install',
        ],
        icon: 'menu',
      };
    }
    if (state.isMacOS && state.isSafari) {
      return {
        title: 'Install on macOS Safari',
        steps: [
          'Click File in the menu bar',
          'Click "Add to Dock"',
          'The app will be added to your Dock',
        ],
        icon: 'file',
      };
    }
    return {
      title: 'Install App',
      steps: [
        'Look for an install icon in your browser\'s address bar',
        'Or check the browser menu for "Install" option',
      ],
      icon: 'download',
    };
  }, [state.isIOS, state.isIPadOS, state.isAndroid, state.isMacOS, state.isSafari, state.isFirefox]);

  // Update service worker
  const update = useCallback(async () => {
    await updateServiceWorkerRef.current(true);
    setNeedRefresh(false);
  }, [setNeedRefresh]);

  // Request push notification permission
  const requestPushPermission = useCallback(async (): Promise<boolean> => {
    if (!('Notification' in window)) {
      console.warn('Notifications not supported in this browser');
      return false;
    }

    try {
      const permission = await Notification.requestPermission();
      const granted = permission === 'granted';
      setState(prev => ({ 
        ...prev, 
        isPushEnabled: granted,
        pushPermission: permission,
      }));
      
      if (granted) {
        await subscribeToPush();
      }
      
      return granted;
    } catch (error) {
      console.error('Failed to request push permission:', error);
      toast.error('Notifications unavailable', { description: 'Unable to enable notifications. Please check your browser settings.' });
      return false;
    }
  }, []);

  // Subscribe to push notifications
  const subscribeToPush = useCallback(async () => {
    try {
      const registration = await navigator.serviceWorker.ready;

      // VAPID public key (publishable - safe in client code)
      const VAPID_PUBLIC_KEY = 'BIr6ItdAyYwCl7D1Zn9MKMCgQ14NZvS9fKb_lT3__M4YMO0JcNViewkOUNIjDhfd41eAuAM16MEUeBNkvpxGGQg';

      // Convert VAPID key to Uint8Array
      const urlBase64ToUint8Array = (base64String: string) => {
        const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
        const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
        const rawData = window.atob(base64);
        const outputArray = new Uint8Array(rawData.length);
        for (let i = 0; i < rawData.length; ++i) {
          outputArray[i] = rawData.charCodeAt(i);
        }
        return outputArray;
      };

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
      });

      // Save subscription to Supabase
      const subscriptionJSON = subscription.toJSON();
      const { error } = await supabase.from('push_subscriptions').upsert({
        user_id: (await supabase.auth.getUser()).data.user?.id,
        endpoint: subscriptionJSON.endpoint!,
        p256dh: subscriptionJSON.keys!.p256dh!,
        auth: subscriptionJSON.keys!.auth!,
        user_agent: navigator.userAgent,
      }, { onConflict: 'user_id,endpoint' });

      if (error) {
        console.error('Failed to save push subscription:', error);
      } else {
        console.log('Push subscription saved successfully');
      }

      return subscription;
    } catch (error) {
      console.error('Failed to subscribe to push:', error);
      return null;
    }
  }, []);

  // Show local notification
  const showNotification = useCallback(async (title: string, options?: NotificationOptions): Promise<boolean> => {
    if (!state.isPushEnabled) {
      console.warn('Push notifications not enabled');
      return false;
    }

    try {
      const registration = await navigator.serviceWorker.ready;
      await registration.showNotification(title, {
        icon: '/icons/icon-192x192.png',
        badge: '/icons/icon-72x72.png',
        ...options,
      });
      return true;
    } catch (error) {
      console.error('Failed to show notification:', error);
      // Non-critical - notification display
      return false;
    }
  }, [state.isPushEnabled]);

  // Set app badge (supported in Chrome, Edge, Safari 17+)
  const setBadge = useCallback(async (count: number): Promise<boolean> => {
    if (!state.isBadgingSupported) return false;
    
    try {
      if (count > 0) {
        await (navigator as any).setAppBadge(count);
      } else {
        await (navigator as any).clearAppBadge();
      }
      return true;
    } catch (error) {
      console.error('Failed to set badge:', error);
      // Non-critical - badge update
      return false;
    }
  }, [state.isBadgingSupported]);

  // Clear all caches
  const clearCache = useCallback(async (): Promise<boolean> => {
    try {
      const registration = await navigator.serviceWorker.ready;
      registration.active?.postMessage({ type: 'CLEAR_CACHE' });
      await checkStorageInfo();
      return true;
    } catch (error) {
      console.error('Failed to clear cache:', error);
      return false;
    }
  }, [checkStorageInfo]);

  // Request persistent storage
  const requestPersistentStorage = useCallback(async (): Promise<boolean> => {
    if (!('storage' in navigator && 'persist' in navigator.storage)) {
      return false;
    }
    
    try {
      const granted = await navigator.storage.persist();
      setState(prev => ({ ...prev, isPersistentStorageGranted: granted }));
      return granted;
    } catch (error) {
      console.error('Failed to request persistent storage:', error);
      // Non-critical - storage request
      return false;
    }
  }, []);

  // Share content (Web Share API)
  const share = useCallback(async (data: ShareData): Promise<boolean> => {
    if (!state.isShareTargetSupported || !navigator.share) {
      console.warn('Web Share API not supported');
      return false;
    }

    try {
      await navigator.share(data);
      return true;
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        console.error('Failed to share:', error);
      toast.error('Sharing failed', { description: 'Unable to share at this time. Please try copying the link manually.' });
      }
      return false;
    }
  }, [state.isShareTargetSupported]);

  // Browser support info
  const browserSupport = useMemo(() => ({
    installPrompt: state.isChrome || state.isEdge || state.isSamsungInternet || state.isOpera,
    pushNotifications: state.isPushSupported,
    backgroundSync: state.isBackgroundSyncSupported,
    periodicSync: state.isPeriodicSyncSupported,
    appBadge: state.isBadgingSupported,
    webShare: state.isShareTargetSupported,
    persistentStorage: 'storage' in navigator && 'persist' in navigator.storage,
    offlineSupport: 'serviceWorker' in navigator,
  }), [state]);

  return {
    ...state,
    browserSupport,
    install,
    getInstallInstructions,
    update,
    requestPushPermission,
    showNotification,
    setBadge,
    clearCache,
    requestPersistentStorage,
    share,
  };
}