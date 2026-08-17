/**
 * useAppSettings Hook (Singleton)
 * 
 * PURPOSE: Fetches dynamic application settings from the database.
 * Uses a shared global cache so multiple components share one fetch + subscription.
 */

import { useState, useEffect, useCallback, useSyncExternalStore } from "react";
import { supabase } from "@/integrations/supabase/client";

// Currency rate type
interface CurrencyRate {
  rate: number;
  symbol: string;
  code: string;
}

// Payment gateway type
interface PaymentGateway {
  id: string;
  name: string;
  logo: string;
  description: string;
  features: string[];
}

interface PaymentGateways {
  indian: PaymentGateway[];
  international: PaymentGateway[];
}

// Type definitions for settings
interface AppSettings {
  rechargeAmounts: number[];
  withdrawalAmounts: number[];
  supportedCurrencies: string[];
  defaultCurrency: string;
  withdrawalProcessingHours: number;
  currencyRates: Record<string, CurrencyRate>;
  paymentGateways: PaymentGateways;
  maxParallelChats: number;
  maxReconnectAttempts: number;
  maxMessageLength: number;
  minVideoCallBalance: number;
  mobileBreakpoint: number;
  sessionTimeoutMinutes: number;
  maxFileUploadMb: number;
  statementsTabVisible: boolean;
  chatEnabled: boolean;
  audioCallEnabled: boolean;
  videoCallEnabled: boolean;
  privateGroupsEnabled: boolean;
}

// Default fallback values (only used if database is unavailable)
const DEFAULT_SETTINGS: AppSettings = {
  rechargeAmounts: [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 2000, 3000, 5000, 10000],
  withdrawalAmounts: [500, 1000, 2000, 5000, 10000],
  supportedCurrencies: ["INR", "USD", "EUR"],
  defaultCurrency: "INR",
  withdrawalProcessingHours: 24,
  currencyRates: {
    IN: { rate: 1, symbol: "₹", code: "INR" },
    US: { rate: 0.012, symbol: "$", code: "USD" },
    GB: { rate: 0.0095, symbol: "£", code: "GBP" },
    EU: { rate: 0.011, symbol: "€", code: "EUR" },
    DEFAULT: { rate: 0.012, symbol: "$", code: "USD" },
  },
  paymentGateways: {
    indian: [
      { id: "razorpay", name: "Razorpay", logo: "💳", description: "Cards, UPI, Wallets, EMI", features: ["Cards", "UPI", "Wallets", "EMI"] },
    ],
    international: [],
  },
  maxParallelChats: 3,
  maxReconnectAttempts: 3,
  maxMessageLength: 2000,
  minVideoCallBalance: 50,
  mobileBreakpoint: 768,
  sessionTimeoutMinutes: 30,
  maxFileUploadMb: 10,
  statementsTabVisible: false,
  chatEnabled: true,
  audioCallEnabled: true,
  videoCallEnabled: true,
  privateGroupsEnabled: true,
};

// Setting key to property mapping
const SETTING_KEY_MAP: Record<string, keyof AppSettings> = {
  recharge_amounts: "rechargeAmounts",
  withdrawal_amounts: "withdrawalAmounts",
  supported_currencies: "supportedCurrencies",
  default_currency: "defaultCurrency",
  withdrawal_processing_hours: "withdrawalProcessingHours",
  currency_rates: "currencyRates",
  payment_gateways: "paymentGateways",
  max_parallel_chats: "maxParallelChats",
  max_reconnect_attempts: "maxReconnectAttempts",
  max_message_length: "maxMessageLength",
  min_video_call_balance: "minVideoCallBalance",
  mobile_breakpoint: "mobileBreakpoint",
  session_timeout_minutes: "sessionTimeoutMinutes",
  max_file_upload_mb: "maxFileUploadMb",
  statements_tab_visible: "statementsTabVisible",
  chat_enabled: "chatEnabled",
  audio_call_enabled: "audioCallEnabled",
  video_call_enabled: "videoCallEnabled",
  private_groups_enabled: "privateGroupsEnabled",
};

// ─── Singleton store ────────────────────────────────────────────────
interface StoreState {
  settings: AppSettings;
  isLoading: boolean;
  error: string | null;
}

let state: StoreState = { settings: DEFAULT_SETTINGS, isLoading: true, error: null };
const listeners = new Set<() => void>();
let subscribed = false;
let fetchInFlight = false;

function emit() {
  listeners.forEach((l) => l());
}

function setState(partial: Partial<StoreState>) {
  state = { ...state, ...partial };
  emit();
}

function parseRow(row: any): [keyof AppSettings, any] | null {
  const propertyName = SETTING_KEY_MAP[row.setting_key];
  if (!propertyName) return null;

  let value: any;
  try {
    if (row.setting_type === "json") {
      if (typeof row.setting_value === "string") {
        try { value = JSON.parse(row.setting_value); } catch { value = row.setting_value; }
      } else {
        value = row.setting_value;
      }
    } else if (row.setting_type === "number") {
      value = typeof row.setting_value === "string" ? parseFloat(row.setting_value) : row.setting_value;
    } else {
      value = row.setting_value;
    }
  } catch {
    value = row.setting_value;
  }

  return [propertyName, value];
}

async function fetchSettings() {
  if (fetchInFlight) return;
  fetchInFlight = true;

  try {
    setState({ isLoading: true, error: null });

    const { data, error: fetchError } = await supabase
      .from("app_settings")
      .select("setting_key, setting_value, setting_type")
      .eq("is_public", true);

    if (fetchError) throw fetchError;

    if (data && data.length > 0) {
      const parsed: Partial<AppSettings> = {};
      data.forEach((row: any) => {
        const result = parseRow(row);
        if (result) (parsed as any)[result[0]] = result[1];
      });
      setState({ settings: { ...DEFAULT_SETTINGS, ...parsed }, isLoading: false });
    } else {
      setState({ isLoading: false });
    }
  } catch (err) {
    console.error("Error fetching app settings:", err);
    setState({ error: err instanceof Error ? err.message : "Failed to load settings", isLoading: false });
  } finally {
    fetchInFlight = false;
  }
}

function ensureSubscription() {
  if (subscribed) return;
  subscribed = true;

  // Initial fetch
  fetchSettings();

  // Single realtime subscription shared by all consumers
  const channel = supabase
    .channel("app-settings-singleton")
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "app_settings" },
      () => { fetchSettings(); }
    )
    .subscribe();

  // Never unsubscribe — this is app-lifetime
}

function subscribe(listener: () => void) {
  ensureSubscription();
  listeners.add(listener);
  return () => { listeners.delete(listener); };
}

function getSnapshot(): StoreState {
  return state;
}

// ─── Public hook ────────────────────────────────────────────────────

export const useAppSettings = () => {
  const snap = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);

  const getSetting = useCallback(<K extends keyof AppSettings>(key: K): AppSettings[K] => {
    return snap.settings[key];
  }, [snap.settings]);

  return {
    settings: snap.settings,
    isLoading: snap.isLoading,
    error: snap.error,
    getSetting,
    refetch: fetchSettings,
  };
};

export default useAppSettings;

// Note: useChatPricing is now in its own file: src/hooks/useChatPricing.ts
// Import it from there: import { useChatPricing } from '@/hooks/useChatPricing';
