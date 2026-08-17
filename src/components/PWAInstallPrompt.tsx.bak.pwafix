/**
 * PWAInstallPrompt.tsx
 * 
 * PURPOSE: Auto-trigger native browser install prompt for PWA installation
 * Shows manual instructions for iOS Safari and fallback for other platforms
 * NOTE: beforeinstallprompt only works on production sites, not in iframes/previews
 */

import { useEffect, useState } from 'react';
import { usePWA } from '@/hooks/usePWA';
import { WifiOff, Share, X, Download, MoreVertical } from 'lucide-react';
import { Button } from '@/components/ui/button';

export function PWAInstallPrompt() {
  const { isInstallable, isInstalled, install, isIOS, isIPadOS, isAndroid, isMacOS, isSafari, getInstallInstructions } = usePWA();
  const [showPrompt, setShowPrompt] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [autoPromptTriggered, setAutoPromptTriggered] = useState(false);

  // Check if in standalone mode (already installed)
  const isInStandaloneMode = typeof window !== 'undefined' && (
    window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as any).standalone === true
  );

  // Log PWA state for debugging (dev only)
  useEffect(() => {
    if (import.meta.env.DEV) {
      if (import.meta.env.DEV) console.log('[PWA] State:', { isInstallable, isInstalled, isInStandaloneMode, isIOS, isIPadOS, isAndroid });
    }
  }, [isInstallable, isInstalled, isInStandaloneMode, isIOS, isIPadOS, isAndroid]);

  // Auto-trigger native install prompt when available (Android, Windows, Linux, macOS Chrome/Edge)
  useEffect(() => {
    if (isInstallable && !isInstalled && !autoPromptTriggered) {
      if (import.meta.env.DEV) console.log('[PWA] Auto-triggering install prompt...');
      const timer = setTimeout(async () => {
        setAutoPromptTriggered(true);
        const result = await install();
        if (import.meta.env.DEV) console.log('[PWA] Install result:', result);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isInstallable, isInstalled, install, autoPromptTriggered]);

  // Check if previously dismissed (within 7 days)
  useEffect(() => {
    const dismissedAt = localStorage.getItem('pwa-install-dismissed');
    if (dismissedAt) {
      const daysSinceDismissed = (Date.now() - parseInt(dismissedAt)) / (1000 * 60 * 60 * 24);
      if (daysSinceDismissed < 7) {
        setDismissed(true);
      } else {
        localStorage.removeItem('pwa-install-dismissed');
      }
    }
  }, []);

  // Show install prompt after a short delay on EVERY route (not just landing)
  // as long as the app isn't already installed and the user hasn't dismissed it.
  useEffect(() => {
    if (dismissed || isInstalled || isInStandaloneMode) return;

    const timer = setTimeout(() => {
      if (import.meta.env.DEV) console.log('[PWA] Showing install prompt', { isInstallable, isIOS, isIPadOS });
      setShowPrompt(true);
    }, 4000);

    return () => clearTimeout(timer);
  }, [isIOS, isIPadOS, dismissed, isInstalled, isInStandaloneMode, isInstallable]);

  // Don't show if already installed or dismissed
  if (isInstalled || isInStandaloneMode || dismissed || !showPrompt) {
    return null;
  }

  const instructions = getInstallInstructions();
  const isIOSDevice = isIOS || isIPadOS;

  const handleInstall = async () => {
    if (isInstallable) {
      // Native install prompt available - trigger it
      if (import.meta.env.DEV) console.log('[PWA] Triggering native install prompt');
      const result = await install();
      if (import.meta.env.DEV) console.log('[PWA] Install result:', result);
      if (result) {
        setDismissed(true);
      }
    } else if (isIOSDevice) {
      // iOS - open share sheet hint (can't programmatically install)
      // Just dismiss and let user follow manual instructions
      setDismissed(true);
    } else {
      // Fallback - try to trigger install anyway
      const result = await install();
      if (!result) {
        // If failed, show browser-specific instructions
        alert(isAndroid 
          ? 'Tap the menu (⋮) in your browser and select "Install App" or "Add to Home Screen"'
          : 'Look for the install icon (⊕) in your browser\'s address bar, or check the browser menu'
        );
      }
      setDismissed(true);
    }
  };

  const handleIgnore = () => {
    setDismissed(true);
    // Store in localStorage to not show again for 7 days
    localStorage.setItem('pwa-install-dismissed', Date.now().toString());
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 z-50 bg-card border border-border rounded-xl p-4 shadow-lg animate-in slide-in-from-bottom-4">
      <button 
        onClick={handleIgnore}
        className="absolute top-2 right-2 p-1 text-muted-foreground hover:text-foreground"
      >
        <X className="h-4 w-4" />
      </button>
      
      <div className="flex items-start gap-3">
        <div className="p-2 bg-primary/10 rounded-lg">
          {isIOSDevice ? (
            <Share className="h-5 w-5 text-primary" />
          ) : (
            <Download className="h-5 w-5 text-primary" />
          )}
        </div>
        <div className="flex-1">
          <p className="font-semibold text-foreground mb-1">Install This App</p>
          <p className="text-sm text-muted-foreground mb-3">
            {isIOSDevice ? (
              <>Tap <Share className="inline h-4 w-4 mx-0.5" /> <strong>Share</strong> below, then <strong>Add to Home Screen</strong></>
            ) : isAndroid ? (
              <>Install for quick access and offline use</>
            ) : (
              <>Install for faster access and offline support</>
            )}
          </p>
          <div className="flex gap-2">
            <Button 
              variant="default" 
              size="sm" 
              onClick={handleInstall}
              className="flex-1"
            >
              {isIOSDevice ? (
                <>
                  <Share className="h-4 w-4 mr-1" />
                  Open Share
                </>
              ) : (
                <>
                  <Download className="h-4 w-4 mr-1" />
                  Install Now
                </>
              )}
            </Button>
            <Button 
              variant="outline" 
              size="sm" 
              onClick={handleIgnore}
              className="flex-1"
            >
              Not Now
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function OfflineIndicator() {
  const { isOffline } = usePWA();

  if (!isOffline) return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-50 bg-amber-500 text-amber-950">
      <div className="flex items-center justify-center gap-2 py-1.5 text-xs font-medium">
        <WifiOff className="h-3 w-3" />
        <span>You are offline - Some features may be limited</span>
      </div>
    </div>
  );
}

export default PWAInstallPrompt;
