/**
 * Network Monitor
 * 
 * Cross-platform network status detection for Web, PWA, and Mobile.
 * Uses Navigator.connection API with fallbacks for unsupported browsers.
 */

import type { NetworkStatus, ApiEventHandler, ApiEvent } from './types';

interface NetworkInformationLike extends EventTarget {
  type?: string;
  effectiveType?: string;
  downlink?: number;
  rtt?: number;
  saveData?: boolean;
  addListener?: (listener: () => void) => void;
  removeListener?: (listener: () => void) => void;
}

interface NavigatorWithConnection extends Navigator {
  connection?: NetworkInformationLike;
}

class NetworkMonitor {
  private static instance: NetworkMonitor;
  private status: NetworkStatus;
  private listeners: Set<ApiEventHandler> = new Set();
  private connection: NetworkInformationLike | null = null;

  private constructor() {
    this.status = {
      isOnline: typeof navigator !== 'undefined' ? navigator.onLine : true,
      connectionType: 'unknown',
    };

    if (typeof navigator !== 'undefined' && typeof window !== 'undefined') {
      this.initializeConnectionInfo();
      this.setupEventListeners();
    }
  }

  static getInstance(): NetworkMonitor {
    if (!NetworkMonitor.instance) {
      NetworkMonitor.instance = new NetworkMonitor();
    }
    return NetworkMonitor.instance;
  }

  private initializeConnectionInfo(): void {
    const nav = navigator as NavigatorWithConnection;
    if (nav.connection) {
      this.connection = nav.connection;
      this.updateConnectionStatus();
    }
  }

  private updateConnectionStatus(): void {
    if (this.connection) {
      this.status = {
        isOnline: navigator.onLine,
        connectionType: this.mapConnectionType(this.connection.type),
        effectiveType: this.connection.effectiveType as NetworkStatus['effectiveType'],
        downlink: this.connection.downlink,
        rtt: this.connection.rtt,
      };
    } else {
      this.status = {
        isOnline: navigator.onLine,
        connectionType: 'unknown',
      };
    }
  }

  private mapConnectionType(type?: string): NetworkStatus['connectionType'] {
    switch (type) {
      case 'wifi':
        return 'wifi';
      case 'cellular':
        return 'cellular';
      case 'ethernet':
        return 'ethernet';
      default:
        return 'unknown';
    }
  }

  private addConnectionChangeListener(): void {
    if (!this.connection) return;

    if (typeof this.connection.addEventListener === 'function') {
      this.connection.addEventListener('change', this.handleConnectionChange);
      return;
    }

    this.connection.addListener?.(this.handleConnectionChange);
  }

  private removeConnectionChangeListener(): void {
    if (!this.connection) return;

    if (typeof this.connection.removeEventListener === 'function') {
      this.connection.removeEventListener('change', this.handleConnectionChange);
      return;
    }

    this.connection.removeListener?.(this.handleConnectionChange);
  }

  private setupEventListeners(): void {
    window.addEventListener('online', this.handleOnline);
    window.addEventListener('offline', this.handleOffline);

    if (this.connection) {
      this.addConnectionChangeListener();
    }
  }

  private handleOnline = (): void => {
    this.status.isOnline = true;
    this.updateConnectionStatus();
    this.emit({
      type: 'network:online',
      timestamp: Date.now(),
      data: this.status,
    });
  };

  private handleOffline = (): void => {
    this.status.isOnline = false;
    this.emit({
      type: 'network:offline',
      timestamp: Date.now(),
      data: this.status,
    });
  };

  private handleConnectionChange = (): void => {
    this.updateConnectionStatus();
  };

  private emit(event: ApiEvent): void {
    this.listeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('Network monitor listener error:', error);
      }
    });
  }

  getStatus(): NetworkStatus {
    if (typeof navigator !== 'undefined') {
      this.status.isOnline = navigator.onLine;
    }
    return { ...this.status };
  }

  isOnline(): boolean {
    return typeof navigator !== 'undefined' ? navigator.onLine : true;
  }

  isSlowConnection(): boolean {
    const effectiveType = this.status.effectiveType;
    return effectiveType === 'slow-2g' || effectiveType === '2g';
  }

  subscribe(handler: ApiEventHandler): () => void {
    this.listeners.add(handler);
    return () => {
      this.listeners.delete(handler);
    };
  }

  destroy(): void {
    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.handleOnline);
      window.removeEventListener('offline', this.handleOffline);
    }
    this.removeConnectionChangeListener();
    this.listeners.clear();
  }
}

export const networkMonitor = NetworkMonitor.getInstance();
export default networkMonitor;
