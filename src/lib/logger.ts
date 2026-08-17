/**
 * Dev-only logger utility.
 * In production builds, all log calls become no-ops.
 * Usage: import { log, warn, error } from '@/lib/logger';
 */

export const log = import.meta.env.DEV
  ? (...args: unknown[]) => console.log(...args)
  : () => {};

export const warn = import.meta.env.DEV
  ? (...args: unknown[]) => console.warn(...args)
  : () => {};

export const error = (...args: unknown[]) => console.error(...args);
