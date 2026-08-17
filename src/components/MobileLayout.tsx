/**
 * MobileLayout.tsx
 * 
 * PURPOSE: Wrapper component that provides mobile-optimized layout
 * with safe area handling for iOS and Android devices.
 */

import React from "react";
import { cn } from "@/lib/utils";
import { useNativeApp } from "@/hooks/useNativeApp";

interface MobileLayoutProps {
  children: React.ReactNode;
  className?: string;
  /** Whether to include bottom safe area padding (for screens without bottom navigation) */
  bottomSafeArea?: boolean;
  /** Whether to include top safe area padding */
  topSafeArea?: boolean;
  /** Custom background class */
  background?: string;
}

export const MobileLayout: React.FC<MobileLayoutProps> = ({
  children,
  className,
  bottomSafeArea = true,
  topSafeArea = true,
  background = "bg-background",
}) => {
  const { isIOS, isAndroid, hasNotch } = useNativeApp();

  return (
    <div
      className={cn(
        "min-h-screen w-full flex flex-col",
        background,
        // Safe area handling
        topSafeArea && "pt-[env(safe-area-inset-top)]",
        bottomSafeArea && "pb-[env(safe-area-inset-bottom)]",
        "pl-[env(safe-area-inset-left)]",
        "pr-[env(safe-area-inset-right)]",
        // Platform-specific adjustments
        isIOS && hasNotch && "ios-notch",
        isAndroid && "android-layout",
        className
      )}
    >
      {children}
    </div>
  );
};

/**
 * MobileHeader - Fixed header with safe area support
 */
interface MobileHeaderProps {
  children: React.ReactNode;
  className?: string;
}

export const MobileHeader: React.FC<MobileHeaderProps> = ({ 
  children, 
  className 
}) => {
  return (
    <header
      className={cn(
        "sticky top-0 z-50 w-full bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-b border-border",
        "pt-[env(safe-area-inset-top)]",
        className
      )}
    >
      <div className="flex h-14 items-center px-4">
        {children}
      </div>
    </header>
  );
};

/**
 * MobileContent - Scrollable content area
 */
interface MobileContentProps {
  children: React.ReactNode;
  className?: string;
}

export const MobileContent: React.FC<MobileContentProps> = ({
  children,
  className,
}) => {
  return (
    <main
      className={cn(
        "flex-1 overflow-y-auto overscroll-contain",
        "-webkit-overflow-scrolling: touch",
        className
      )}
    >
      {children}
    </main>
  );
};

/**
 * MobileFooter - Fixed footer with safe area support
 */
interface MobileFooterProps {
  children: React.ReactNode;
  className?: string;
}

export const MobileFooter: React.FC<MobileFooterProps> = ({
  children,
  className,
}) => {
  return (
    <footer
      className={cn(
        "sticky bottom-0 z-50 w-full bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-t border-border",
        "pb-[env(safe-area-inset-bottom)]",
        className
      )}
    >
      <div className="flex items-center justify-around px-4 py-2">
        {children}
      </div>
    </footer>
  );
};

/**
 * TouchableOpacity - Touch-friendly pressable component
 */
interface TouchableOpacityProps {
  children: React.ReactNode;
  className?: string;
  onPress?: () => void;
  disabled?: boolean;
}

export const TouchableOpacity: React.FC<TouchableOpacityProps> = ({
  children,
  className,
  onPress,
  disabled,
}) => {
  return (
    <button
      onClick={onPress}
      disabled={disabled}
      className={cn(
        "touch-manipulation active:opacity-70 transition-opacity duration-150",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        "min-h-[44px] min-w-[44px]", // iOS recommended touch target
        className
      )}
    >
      {children}
    </button>
  );
};

export default MobileLayout;
