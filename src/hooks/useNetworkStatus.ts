/**
 * useNetworkStatus Hook
 * 
 * React hook for monitoring network connectivity status.
 * Provides real-time online/offline detection across all platforms.
 */

import { useState, useEffect, useCallback } from 'react';
import { networkMonitor, type NetworkStatus } from '@/lib/api';

interface UseNetworkStatusReturn extends NetworkStatus {
  checkConnection: () => Promise<boolean>;
  isSlowConnection: boolean;
}

/**
 * Hook to monitor and react to network status changes
 */
export function useNetworkStatus(): UseNetworkStatusReturn {
  const [status, setStatus] = useState<NetworkStatus>(() => networkMonitor.getStatus());

  useEffect(() => {
    // Update initial status
    setStatus(networkMonitor.getStatus());

    // Subscribe to network changes
    const unsubscribe = networkMonitor.subscribe((event) => {
      if (event.type === 'network:online' || event.type === 'network:offline') {
        setStatus(event.data as NetworkStatus);
      }
    });

    // Fallback: Listen to browser events directly
    const handleOnline = () => {
      setStatus(prev => ({ ...prev, isOnline: true }));
    };

    const handleOffline = () => {
      setStatus(prev => ({ ...prev, isOnline: false }));
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      unsubscribe();
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  /**
   * Actively check if the connection is working by making a small request
   */
  const checkConnection = useCallback(async (): Promise<boolean> => {
    if (!navigator.onLine) return false;

    try {
      // Try to fetch a small resource
      const response = await fetch('/favicon.ico', {
        method: 'HEAD',
        cache: 'no-cache',
      });
      return response.ok;
    } catch {
      return false;
    }
  }, []);

  const isSlowConnection = status.effectiveType === 'slow-2g' || status.effectiveType === '2g';

  return {
    ...status,
    checkConnection,
    isSlowConnection,
  };
}

export default useNetworkStatus;
