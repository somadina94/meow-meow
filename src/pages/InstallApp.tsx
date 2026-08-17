/**
 * InstallApp.tsx
 * 
 * PURPOSE: Dedicated page for installing the PWA with instructions for all platforms
 * Includes device-specific instructions for iOS/Android mobile and tablet
 */

import { usePWA } from '@/hooks/usePWA';
import { useNativeApp } from '@/hooks/useNativeApp';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { 
  Download, 
  Smartphone, 
  Share, 
  PlusSquare, 
  Chrome, 
  CheckCircle2,
  ArrowLeft,
  Bell,
  WifiOff,
  Zap,
  Tablet,
  Monitor
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { MobileLayout, MobileContent, MobileHeader } from '@/components/MobileLayout';
import MeowLogo from '@/components/MeowLogo';
import { Badge } from '@/components/ui/badge';

export default function InstallApp() {
  const navigate = useNavigate();
  const { isInstallable, isInstalled, isIOS, isAndroid, install, isPushSupported, requestPushPermission } = usePWA();
  const { isNative } = useNativeApp();

  // Detect device type
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
  const isTabletUA = /iPad|Android(?!.*Mobile)/i.test(ua);
  const isMobileUA = /iPhone|Android.*Mobile/i.test(ua);
  
  const isTablet = isTabletUA || (!isMobileUA && typeof window !== 'undefined' && window.innerWidth >= 768 && window.innerWidth < 1024);
  const isMobile = isMobileUA;

  const deviceType = isTablet ? 'tablet' : isMobile ? 'mobile' : 'desktop';

  const handleInstall = async () => {
    await install();
  };

  // If running as native app, show different content
  if (isNative) {
    return (
      <MobileLayout>
        <MobileHeader>
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <h1 className="text-lg font-semibold">App Info</h1>
          </div>
        </MobileHeader>
        <MobileContent className="p-4">
          <Card className="border-green-500/20 bg-green-500/10">
            <CardContent className="flex items-center gap-4 p-6">
              <CheckCircle2 className="h-12 w-12 text-green-500" />
              <div>
                <h2 className="text-xl font-bold">Native App</h2>
                <p className="text-muted-foreground">
                  You're using the native app with full device features
                </p>
              </div>
            </CardContent>
          </Card>
        </MobileContent>
      </MobileLayout>
    );
  }

  // If already installed as PWA
  if (isInstalled) {
    return (
      <MobileLayout>
        <MobileHeader>
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <h1 className="text-lg font-semibold">App Installed</h1>
          </div>
        </MobileHeader>
        <MobileContent className="p-4 space-y-4">
          <Card className="border-primary/30 bg-primary/10">
            <CardContent className="flex flex-col items-center gap-4 p-6">
              <MeowLogo size="lg" />
              <div className="text-center">
                <h2 className="text-xl font-bold text-primary">App Installed!</h2>
                <p className="text-muted-foreground">
                  Meow MEOW FRND APP is installed on your {deviceType}
                </p>
              </div>
              <Badge variant="secondary" className="capitalize">
                {deviceType === 'mobile' && <Smartphone className="h-3 w-3 mr-1" />}
                {deviceType === 'tablet' && <Tablet className="h-3 w-3 mr-1" />}
                {deviceType === 'desktop' && <Monitor className="h-3 w-3 mr-1" />}
                {deviceType}
              </Badge>
            </CardContent>
          </Card>

          {isPushSupported && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Bell className="h-5 w-5 text-primary" />
                  Enable Notifications
                </CardTitle>
                <CardDescription>
                  Get notified about new messages and matches
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Button onClick={requestPushPermission} className="w-full">
                  Enable Push Notifications
                </Button>
              </CardContent>
            </Card>
          )}

          <Card>
            <CardHeader>
              <CardTitle>App Features</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex items-center gap-3">
                <WifiOff className="h-5 w-5 text-primary" />
                <span>Works offline</span>
              </div>
              <div className="flex items-center gap-3">
                <Zap className="h-5 w-5 text-primary" />
                <span>Fast and responsive</span>
              </div>
              <div className="flex items-center gap-3">
                <Download className="h-5 w-5 text-primary" />
                <span>No app store required</span>
              </div>
            </CardContent>
          </Card>
        </MobileContent>
      </MobileLayout>
    );
  }

  return (
    <MobileLayout>
      <MobileHeader>
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <h1 className="text-lg font-semibold">Install App</h1>
        </div>
      </MobileHeader>
      <MobileContent className="p-4 space-y-4">
        {/* Hero Section with Logo */}
        <div className="text-center py-6">
          <div className="mx-auto mb-4">
            <MeowLogo size="lg" />
          </div>
          <h1 className="text-2xl font-bold mb-2 font-display">Install Meow MEOW FRND APP</h1>
          <p className="text-muted-foreground">
            Get the full app experience on your {deviceType}
          </p>
          <Badge variant="outline" className="mt-2 capitalize">
            {deviceType === 'mobile' && <Smartphone className="h-3 w-3 mr-1" />}
            {deviceType === 'tablet' && <Tablet className="h-3 w-3 mr-1" />}
            {deviceType === 'desktop' && <Monitor className="h-3 w-3 mr-1" />}
            {isIOS ? 'iOS' : isAndroid ? 'Android' : 'Desktop'} {deviceType}
          </Badge>
        </div>

        {/* Features */}
        <Card className="border-primary/20">
          <CardHeader>
            <CardTitle className="text-primary">Why Install?</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-3">
              <Download className="h-5 w-5 text-primary" />
              <div>
                <p className="font-medium">Quick Access</p>
                <p className="text-sm text-muted-foreground">Launch from your home screen</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <WifiOff className="h-5 w-5 text-primary" />
              <div>
                <p className="font-medium">Works Offline</p>
                <p className="text-sm text-muted-foreground">Access the app without internet</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Bell className="h-5 w-5 text-primary" />
              <div>
                <p className="font-medium">Push Notifications</p>
                <p className="text-sm text-muted-foreground">Never miss a message</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Zap className="h-5 w-5 text-primary" />
              <div>
                <p className="font-medium">Fast & Smooth</p>
                <p className="text-sm text-muted-foreground">Native-like performance</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Install Button for Android/Desktop */}
        {isInstallable && !isIOS && (
          <Button size="lg" className="w-full gradient-primary" onClick={handleInstall}>
            <Download className="mr-2 h-5 w-5" />
            Install Now
          </Button>
        )}

        {/* iOS Instructions - iPhone */}
        {isIOS && !isTablet && (
          <Card className="border-primary/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Smartphone className="h-5 w-5 text-primary" />
                Install on iPhone
              </CardTitle>
              <CardDescription>
                Follow these steps in Safari browser
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  1
                </div>
                <div>
                  <p className="font-medium">Tap the Share button</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <Share className="h-4 w-4" />
                    <span>At the bottom of Safari</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  2
                </div>
                <div>
                  <p className="font-medium">Scroll and tap "Add to Home Screen"</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <PlusSquare className="h-4 w-4" />
                    <span>Look for this icon in the menu</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  3
                </div>
                <div>
                  <p className="font-medium">Tap "Add" in the top right</p>
                  <p className="text-sm text-muted-foreground">
                    Meow MEOW FRND APP icon will appear on your home screen
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* iOS Instructions - iPad */}
        {isIOS && isTablet && (
          <Card className="border-primary/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Tablet className="h-5 w-5 text-primary" />
                Install on iPad
              </CardTitle>
              <CardDescription>
                Follow these steps in Safari browser
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  1
                </div>
                <div>
                  <p className="font-medium">Tap the Share button</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <Share className="h-4 w-4" />
                    <span>In Safari's address bar (top right)</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  2
                </div>
                <div>
                  <p className="font-medium">Tap "Add to Home Screen"</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <PlusSquare className="h-4 w-4" />
                    <span>In the share menu dropdown</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  3
                </div>
                <div>
                  <p className="font-medium">Tap "Add" to confirm</p>
                  <p className="text-sm text-muted-foreground">
                    Meow MEOW FRND APP will appear on your iPad home screen
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Android Instructions - Phone */}
        {isAndroid && !isInstallable && !isTablet && (
          <Card className="border-primary/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Smartphone className="h-5 w-5 text-primary" />
                Install on Android Phone
              </CardTitle>
              <CardDescription>
                Follow these steps in Chrome browser
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  1
                </div>
                <div>
                  <p className="font-medium">Tap the menu button</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <Chrome className="h-4 w-4" />
                    <span>Three dots (⋮) in the top right corner</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  2
                </div>
                <div>
                  <p className="font-medium">Tap "Install app" or "Add to Home screen"</p>
                  <p className="text-sm text-muted-foreground">
                    The option may vary based on your browser
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  3
                </div>
                <div>
                  <p className="font-medium">Tap "Install" to confirm</p>
                  <p className="text-sm text-muted-foreground">
                    Meow MEOW FRND APP will be added to your app drawer
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Android Instructions - Tablet */}
        {isAndroid && !isInstallable && isTablet && (
          <Card className="border-primary/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Tablet className="h-5 w-5 text-primary" />
                Install on Android Tablet
              </CardTitle>
              <CardDescription>
                Follow these steps in Chrome browser
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  1
                </div>
                <div>
                  <p className="font-medium">Tap the menu button</p>
                  <div className="mt-1 flex items-center gap-2 text-sm text-muted-foreground">
                    <Chrome className="h-4 w-4" />
                    <span>Three dots (⋮) in Chrome toolbar</span>
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  2
                </div>
                <div>
                  <p className="font-medium">Select "Install app" or "Add to Home screen"</p>
                  <p className="text-sm text-muted-foreground">
                    Usually found near the top of the menu
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  3
                </div>
                <div>
                  <p className="font-medium">Confirm by tapping "Install"</p>
                  <p className="text-sm text-muted-foreground">
                    Meow MEOW FRND APP will appear on your tablet home screen
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Desktop Instructions */}
        {!isIOS && !isAndroid && !isInstallable && (
          <Card className="border-primary/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Monitor className="h-5 w-5 text-primary" />
                Install on Desktop
              </CardTitle>
              <CardDescription>
                Follow these steps in Chrome, Edge, or Brave
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  1
                </div>
                <div>
                  <p className="font-medium">Look for the install icon</p>
                  <p className="text-sm text-muted-foreground">
                    In the address bar (right side) or menu
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  2
                </div>
                <div>
                  <p className="font-medium">Click "Install" or "Install Meow MEOW FRND APP"</p>
                  <p className="text-sm text-muted-foreground">
                    A prompt will appear asking to confirm
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
                  3
                </div>
                <div>
                  <p className="font-medium">Launch from your applications</p>
                  <p className="text-sm text-muted-foreground">
                    Meow MEOW FRND APP will open as a standalone app
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Note about browser requirements */}
        <p className="text-xs text-center text-muted-foreground px-4">
          {isIOS 
            ? "Make sure you're using Safari browser for best installation experience on iOS devices."
            : isAndroid
            ? "Use Chrome, Edge, or Samsung Internet for best results on Android devices."
            : "Use Chrome, Edge, or Brave browser for the best installation experience."}
        </p>
      </MobileContent>
    </MobileLayout>
  );
}
