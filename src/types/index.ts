/**
 * Shared Frontend Types
 * 
 * This file contains all shared TypeScript interfaces and types
 * used across the frontend application.
 * 
 * Note: Database types are auto-generated in src/integrations/supabase/types.ts
 * This file is for frontend-specific types and transformed data structures.
 */

// ============= User Types =============

export interface User {
  id: string;
  email: string | null;
  fullName: string | null;
  gender: 'male' | 'female' | null;
  age: number | null;
  photoUrl: string | null;
  country: string | null;
  state: string | null;
  isVerified: boolean;
  isOnline: boolean;
}

export interface UserProfile extends User {
  bio: string | null;
  interests: string[];
  occupation: string | null;
  educationLevel: string | null;
  religion: string | null;
  maritalStatus: string | null;
  heightCm: number | null;
  bodyType: string | null;
  languages: string[];
  accountStatus: 'active' | 'suspended' | 'banned';
  approvalStatus: 'pending' | 'approved' | 'rejected';
  createdAt: Date;
}

// ============= Chat Types =============

export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  receiverId: string;
  content: string;
  translatedContent: string | null;
  isRead: boolean;
  createdAt: Date;
}

export interface ChatSession {
  id: string;
  chatId: string;
  partnerId: string;
  partnerName: string;
  partnerPhotoUrl: string | null;
  status: 'active' | 'ended';
  lastMessage: string | null;
  lastMessageAt: Date | null;
  unreadCount: number;
}

// ============= Wallet Types =============

export interface WalletBalance {
  balance: number;
  currency: string;
  formattedBalance: string;
}

export interface Transaction {
  id: string;
  type: 'credit' | 'debit';
  amount: number;
  description: string | null;
  status: 'pending' | 'completed' | 'failed';
  createdAt: Date;
}

// ============= Match Types =============

export interface Match {
  id: string;
  userId: string;
  matchedUserId: string;
  matchScore: number;
  status: 'pending' | 'accepted' | 'rejected';
  createdAt: Date;
}

export interface MatchProfile extends User {
  matchScore: number;
  commonLanguages: string[];
  commonInterests: string[];
}

// ============= Admin Types =============

export interface AdminMetrics {
  totalUsers: number;
  activeUsers: number;
  maleUsers: number;
  femaleUsers: number;
  newUsersToday: number;
  activeChats: number;
  totalRevenue: number;
  pendingWithdrawals: number;
}

// ============= Settings Types =============

export interface UserSettings {
  theme: 'light' | 'dark' | 'system';
  language: string;
  autoTranslate: boolean;
  notificationSound: boolean;
  notificationVibration: boolean;
  showOnlineStatus: boolean;
  showReadReceipts: boolean;
}

// ============= Platform Types =============

export type Platform = 'web' | 'ios' | 'android' | 'desktop';

export interface DeviceInfo {
  platform: Platform;
  isNative: boolean;
  isMobile: boolean;
  isTablet: boolean;
  isDesktop: boolean;
  hasNotch: boolean;
}

// ============= Gift Types =============

export interface Gift {
  id: string;
  name: string;
  emoji: string;
  price: number;
  currency: string;
  category: string;
  description: string | null;
}

// ============= Video Call Types =============

export interface VideoCallSession {
  id: string;
  callId: string;
  partnerId: string;
  partnerName: string;
  status: 'ringing' | 'active' | 'ended';
  startedAt: Date | null;
  endedAt: Date | null;
  totalMinutes: number;
}

// ============= Notification Types =============

export interface Notification {
  id: string;
  type: 'message' | 'match' | 'gift' | 'system';
  title: string;
  message: string;
  isRead: boolean;
  actionUrl: string | null;
  createdAt: Date;
}
