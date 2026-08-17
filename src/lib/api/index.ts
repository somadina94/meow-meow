/**
 * API Layer Index
 * 
 * Exports active API utilities: network monitoring, payment service, and types.
 */

export { networkMonitor } from './network-monitor';

// Type exports
export type {
  NetworkStatus,
} from './types';

// Re-export for convenience
export { default as NetworkMonitor } from './network-monitor';
