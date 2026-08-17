/**
 * Network Status Indicator Component
 * 
 * Displays current network status with offline indicator.
 */

import React from 'react';
import { Wifi, WifiOff, CloudOff } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useNetworkStatus } from '@/hooks/useNetworkStatus';

interface NetworkStatusIndicatorProps {
  className?: string;
  compact?: boolean;
}

export function NetworkStatusIndicator({
  className,
  compact = false,
}: NetworkStatusIndicatorProps) {
  const { isOnline, connectionType, isSlowConnection } = useNetworkStatus();

  // Don't render anything when online
  if (isOnline) {
    return null;
  }

  if (compact) {
    return (
      <div
        className={cn(
          'flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium transition-all',
          'bg-destructive/10 text-destructive',
          className
        )}
      >
        <WifiOff className="h-3 w-3" />
      </div>
    );
  }

  return (
    <div
      className={cn(
        'flex items-center gap-2 px-3 py-2 rounded-lg transition-all',
        'bg-destructive/10 text-destructive',
        className
      )}
    >
      <CloudOff className="h-4 w-4" />
      
      <div className="flex flex-col">
        <span className="text-sm font-medium">Offline</span>
        
        {connectionType && connectionType !== 'unknown' && (
          <span className="text-xs opacity-75 capitalize">
            {connectionType}
            {isSlowConnection && ' (slow)'}
          </span>
        )}
      </div>
    </div>
  );
}

export default NetworkStatusIndicator;
