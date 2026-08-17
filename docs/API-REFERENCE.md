# Meow Chat - Complete API Reference

## Table of Contents
1. [Authentication API](#authentication-api)
2. [User Profiles API](#user-profiles-api)
3. [Chat API](#chat-api)
4. [Wallet & Transactions API](#wallet--transactions-api)
5. [Shift Management API](#shift-management-api)
6. [Moderation API](#moderation-api)
7. [Admin API](#admin-api)
8. [Storage API](#storage-api)
9. [Edge Functions Reference](#edge-functions-reference)
10. [Realtime Events](#realtime-events)
11. [Error Codes](#error-codes)

---

## Authentication API

### Overview
Authentication is handled through Supabase Auth with email/password authentication.

### Endpoints

#### Sign Up
Creates a new user account and triggers profile creation.

```typescript
/**
 * Creates a new user account
 * @param email - User's email address (must be unique)
 * @param password - Password (min 6 characters)
 * @returns User object and session
 */
const { data, error } = await supabase.auth.signUp({
  email: string,      // Required: Valid email address
  password: string    // Required: Minimum 6 characters
});

// Response
interface SignUpResponse {
  user: {
    id: string;           // UUID - User's unique identifier
    email: string;        // User's email
    created_at: string;   // ISO timestamp
    confirmed_at: string; // Email confirmation timestamp
  };
  session: {
    access_token: string;  // JWT access token
    refresh_token: string; // JWT refresh token
    expires_in: number;    // Token expiry in seconds
  };
}
```

#### Sign In
Authenticates an existing user.

```typescript
/**
 * Authenticates user with email and password
 * @param email - Registered email address
 * @param password - User's password
 * @returns Session with access tokens
 */
const { data, error } = await supabase.auth.signInWithPassword({
  email: string,
  password: string
});

// Response includes session tokens for authenticated requests
```

#### Sign Out
Terminates the current session.

```typescript
/**
 * Signs out the current user
 * Clears local session and invalidates tokens
 */
const { error } = await supabase.auth.signOut();
```

#### Get Current User
Retrieves the currently authenticated user.

```typescript
/**
 * Gets the current authenticated user
 * @returns User object or null if not authenticated
 */
const { data: { user } } = await supabase.auth.getUser();
```

#### Password Reset Request
Initiates password reset flow.

```typescript
/**
 * Sends password reset email
 * @param email - User's registered email
 */
const { error } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: 'https://app.meowchat.com/reset-password'
});
```

#### Update Password
Updates user's password after reset.

```typescript
/**
 * Updates the user's password
 * @param password - New password (min 6 characters)
 */
const { error } = await supabase.auth.updateUser({
  password: string
});
```

---

## User Profiles API

### Tables

#### profiles
Main user profile table containing all user information.

```typescript
interface Profile {
  // Primary Identifiers
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - References auth.users
  
  // Basic Information
  full_name: string | null;      // User's display name
  gender: 'male' | 'female' | null;  // User's gender
  age: number | null;            // Calculated from date_of_birth
  date_of_birth: string | null;  // ISO date format
  
  // Location
  country: string | null;        // Country name
  state: string | null;          // State/province name
  latitude: number | null;       // GPS latitude
  longitude: number | null;      // GPS longitude
  
  // Profile Content
  photo_url: string | null;      // Primary profile photo URL
  bio: string | null;            // User biography (max 500 chars)
  
  // Languages
  primary_language: string | null;    // User's native language
  preferred_language: string | null;  // Preferred chat language
  
  // Status & Verification
  approval_status: 'pending' | 'approved' | 'rejected';
  account_status: 'active' | 'suspended' | 'banned';
  is_verified: boolean;          // Identity verification status
  is_premium: boolean;           // Premium subscription status
  
  // AI Approval (for women)
  ai_approved: boolean | null;           // AI approval result
  ai_disapproval_reason: string | null;  // Reason if rejected
  
  // Performance Metrics
  performance_score: number | null;       // 0-100 score
  avg_response_time_seconds: number | null;
  total_chats_count: number | null;
  profile_completeness: number | null;    // 0-100 percentage
  
  // Extended Profile Fields
  occupation: string | null;
  education_level: string | null;
  marital_status: string | null;
  religion: string | null;
  height_cm: number | null;
  body_type: string | null;
  interests: string[] | null;      // Array of interest tags
  life_goals: string[] | null;     // Array of life goals
  
  // Lifestyle
  smoking_habit: string | null;
  drinking_habit: string | null;
  dietary_preference: string | null;
  fitness_level: string | null;
  pet_preference: string | null;
  travel_frequency: string | null;
  has_children: boolean | null;
  personality_type: string | null;
  zodiac_sign: string | null;
  
  // Timestamps
  created_at: string;            // ISO timestamp
  updated_at: string;            // ISO timestamp
  last_active_at: string | null; // Last activity timestamp
}
```

### Profile Operations

#### Get User Profile
```typescript
/**
 * Fetches a user's profile by user_id
 * @param userId - The auth user ID
 * @returns Profile object
 */
const { data, error } = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', userId)
  .single();
```

#### Update Profile
```typescript
/**
 * Updates user profile fields
 * @param userId - The auth user ID
 * @param updates - Object with fields to update
 * @returns Updated profile
 */
const { data, error } = await supabase
  .from('profiles')
  .update({
    full_name: 'New Name',
    bio: 'Updated bio',
    // ... other fields
  })
  .eq('user_id', userId)
  .select()
  .single();
```

#### Get Online Users
```typescript
/**
 * Fetches currently online users
 * @param gender - Filter by gender
 * @param language - Filter by preferred language
 * @returns Array of online user profiles
 */
const { data, error } = await supabase
  .from('user_status')
  .select(`
    user_id,
    is_online,
    last_seen,
    profiles!inner (
      full_name,
      photo_url,
      age,
      country,
      gender
    )
  `)
  .eq('is_online', true)
  .eq('profiles.gender', 'female')
  .eq('profiles.approval_status', 'approved');
```

### User Photos

#### user_photos Table
```typescript
interface UserPhoto {
  id: string;              // UUID - Primary key
  user_id: string;         // UUID - References auth.users
  photo_url: string;       // Storage URL
  photo_type: 'profile' | 'gallery' | 'verification';
  is_primary: boolean;     // Is this the main profile photo
  display_order: number;   // Order in gallery
  created_at: string;
  updated_at: string;
}
```

#### Upload Photo
```typescript
/**
 * Uploads a photo to storage and creates record
 */
// 1. Upload to storage
const { data: uploadData, error: uploadError } = await supabase.storage
  .from('profile-photos')
  .upload(`${userId}/${fileName}`, file);

// 2. Get public URL
const { data: { publicUrl } } = supabase.storage
  .from('profile-photos')
  .getPublicUrl(`${userId}/${fileName}`);

// 3. Create database record
const { data, error } = await supabase
  .from('user_photos')
  .insert({
    user_id: userId,
    photo_url: publicUrl,
    photo_type: 'gallery',
    is_primary: false,
    display_order: nextOrder
  });
```

---

## Chat API

### Tables

#### chat_messages
Stores all chat messages between users.

```typescript
interface ChatMessage {
  id: string;                    // UUID - Primary key
  chat_id: string;               // Chat session identifier
  sender_id: string;             // UUID - Sender user ID
  receiver_id: string;           // UUID - Receiver user ID
  message: string;               // Original message content
  translated_message: string | null;  // Translated version
  is_translated: boolean;        // Whether translation was applied
  is_read: boolean;              // Read receipt status
  created_at: string;            // ISO timestamp
  
  // Moderation
  flagged: boolean;              // Flagged for review
  flag_reason: string | null;    // Reason for flagging
  flagged_at: string | null;     // When flagged
  flagged_by: string | null;     // Who flagged (user or system)
  moderation_status: 'pending' | 'approved' | 'rejected' | null;
}
```

#### active_chat_sessions
Tracks active chat sessions with billing.

```typescript
interface ActiveChatSession {
  id: string;                    // UUID - Primary key
  chat_id: string;               // Unique chat identifier
  man_user_id: string;           // Male user (payer)
  woman_user_id: string;         // Female user (earner)
  status: 'active' | 'ended';    // Session status
  started_at: string;            // Session start time
  ended_at: string | null;       // Session end time
  last_activity_at: string;      // Last message time
  
  // Billing
  rate_per_minute: number;       // USD per minute
  total_minutes: number;         // Duration in minutes
  total_earned: number;          // Total earnings in USD
  end_reason: string | null;     // Why session ended
  
  created_at: string;
  updated_at: string;
}
```

### Chat Operations

#### Send Message
```typescript
/**
 * Sends a chat message
 * @param chatId - Chat session identifier
 * @param senderId - Sender's user ID
 * @param receiverId - Receiver's user ID
 * @param message - Message content
 * @returns Created message
 */
const { data, error } = await supabase
  .from('chat_messages')
  .insert({
    chat_id: chatId,
    sender_id: senderId,
    receiver_id: receiverId,
    message: message,
    is_read: false
  })
  .select()
  .single();
```

#### Get Chat History
```typescript
/**
 * Fetches chat message history
 * @param chatId - Chat session identifier
 * @param limit - Number of messages (default 50)
 * @param offset - Pagination offset
 * @returns Array of messages ordered by time
 */
const { data, error } = await supabase
  .from('chat_messages')
  .select('*')
  .eq('chat_id', chatId)
  .order('created_at', { ascending: true })
  .range(offset, offset + limit - 1);
```

#### Mark Messages as Read
```typescript
/**
 * Marks all messages in a chat as read
 * @param chatId - Chat session identifier
 * @param userId - Current user's ID (receiver)
 */
const { error } = await supabase
  .from('chat_messages')
  .update({ is_read: true })
  .eq('chat_id', chatId)
  .eq('receiver_id', userId)
  .eq('is_read', false);
```

#### Get Unread Message Count
```typescript
/**
 * Gets count of unread messages for a user
 * @param userId - User's ID
 * @returns Count of unread messages
 */
const { count, error } = await supabase
  .from('chat_messages')
  .select('*', { count: 'exact', head: true })
  .eq('receiver_id', userId)
  .eq('is_read', false);
```

---

## Wallet & Transactions API

### Tables

#### wallets
User wallet balances.

```typescript
interface Wallet {
  id: string;              // UUID - Primary key
  user_id: string;         // UUID - Owner's user ID
  balance: number;         // Current balance in USD
  currency: string;        // Currency code (default: 'USD')
  created_at: string;
  updated_at: string;
}
```

#### wallet_transactions
All wallet transaction records.

```typescript
interface WalletTransaction {
  id: string;                    // UUID - Primary key
  wallet_id: string;             // UUID - References wallets
  user_id: string;               // UUID - User ID
  type: 'credit' | 'debit';      // Transaction type
  amount: number;                // Transaction amount
  description: string | null;    // Human-readable description
  reference_id: string | null;   // Related record ID
  status: 'pending' | 'completed' | 'failed' | 'refunded';
  created_at: string;
}
```

#### withdrawal_requests
Withdrawal request records for women.

```typescript
interface WithdrawalRequest {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - Requestor's user ID
  amount: number;                // Requested amount in USD
  status: 'pending' | 'approved' | 'rejected' | 'completed';
  payment_method: string | null; // 'bank_transfer', 'paypal', etc.
  payment_details: object | null; // Bank/payment account details
  rejection_reason: string | null;
  processed_at: string | null;
  processed_by: string | null;   // Admin user ID
  created_at: string;
  updated_at: string;
}
```

### Wallet Operations

#### Get Wallet Balance
```typescript
/**
 * Gets user's current wallet balance
 * @param userId - User's ID
 * @returns Wallet with balance
 */
const { data, error } = await supabase
  .from('wallets')
  .select('id, balance, currency')
  .eq('user_id', userId)
  .single();
```

#### Get Transaction History
```typescript
/**
 * Gets user's transaction history
 * @param userId - User's ID
 * @param limit - Number of transactions
 * @returns Array of transactions
 */
const { data, error } = await supabase
  .from('wallet_transactions')
  .select('*')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
  .limit(limit);
```

#### Request Withdrawal
```typescript
/**
 * Creates a withdrawal request (women only)
 * @param userId - User's ID
 * @param amount - Amount to withdraw
 * @param paymentMethod - Payment method
 * @param paymentDetails - Payment account details
 */
const { data, error } = await supabase
  .from('withdrawal_requests')
  .insert({
    user_id: userId,
    amount: amount,
    payment_method: paymentMethod,
    payment_details: paymentDetails,
    status: 'pending'
  })
  .select()
  .single();
```

---

## Shift Management API

### Tables

#### shifts
Active and historical shift records for women.

```typescript
interface Shift {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - Woman's user ID
  start_time: string;            // Shift start timestamp
  end_time: string | null;       // Shift end timestamp
  status: 'active' | 'ended' | 'cancelled';
  earnings: number;              // Total earnings during shift
  bonus_earnings: number;        // Bonus earnings
  total_chats: number;           // Number of chats handled
  total_messages: number;        // Total messages sent
  notes: string | null;          // Shift notes
  created_at: string;
  updated_at: string;
}
```

#### scheduled_shifts
Pre-scheduled shifts for women.

```typescript
interface ScheduledShift {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - Woman's user ID
  scheduled_date: string;        // Date of shift
  start_time: string;            // Scheduled start time
  end_time: string;              // Scheduled end time
  timezone: string;              // Timezone (default: 'UTC')
  status: 'scheduled' | 'started' | 'completed' | 'missed' | 'cancelled';
  ai_suggested: boolean;         // Whether AI suggested this shift
  suggested_reason: string | null;
  created_at: string;
  updated_at: string;
}
```

#### women_availability
Real-time availability status for women.

```typescript
interface WomenAvailability {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - Woman's user ID
  is_available: boolean;         // Available for new chats
  is_available_for_calls: boolean;  // Available for video calls
  current_chat_count: number;    // Active chat count
  max_concurrent_chats: number;  // Maximum allowed chats
  current_call_count: number;    // Active call count
  max_concurrent_calls: number;  // Maximum allowed calls
  last_assigned_at: string | null;
  created_at: string;
  updated_at: string;
}
```

### Shift Operations

#### Start Shift
```typescript
/**
 * Starts a new work shift
 * @param userId - Woman's user ID
 * @returns Created shift record
 */
const { data, error } = await supabase
  .from('shifts')
  .insert({
    user_id: userId,
    start_time: new Date().toISOString(),
    status: 'active',
    earnings: 0,
    bonus_earnings: 0,
    total_chats: 0,
    total_messages: 0
  })
  .select()
  .single();

// Also update availability
await supabase
  .from('women_availability')
  .upsert({
    user_id: userId,
    is_available: true,
    current_chat_count: 0
  });
```

#### End Shift
```typescript
/**
 * Ends the current shift
 * @param shiftId - Active shift ID
 */
const { error } = await supabase
  .from('shifts')
  .update({
    end_time: new Date().toISOString(),
    status: 'ended'
  })
  .eq('id', shiftId);

// Update availability
await supabase
  .from('women_availability')
  .update({ is_available: false })
  .eq('user_id', userId);
```

---

## Moderation API

### Tables

#### moderation_reports
User reports and moderation actions.

```typescript
interface ModerationReport {
  id: string;                    // UUID - Primary key
  reporter_id: string;           // UUID - Who reported
  reported_user_id: string;      // UUID - Who was reported
  chat_message_id: string | null; // Related message ID
  report_type: 'spam' | 'harassment' | 'inappropriate' | 'scam' | 'other';
  content: string | null;        // Report details
  status: 'pending' | 'reviewed' | 'resolved' | 'dismissed';
  action_taken: string | null;   // Action taken by admin
  action_reason: string | null;  // Reason for action
  reviewed_by: string | null;    // Admin who reviewed
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}
```

#### policy_violation_alerts
Automated policy violation detection.

```typescript
interface PolicyViolationAlert {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - Violating user
  alert_type: 'content' | 'behavior' | 'fraud';
  violation_type: string;        // Specific violation
  severity: 'low' | 'medium' | 'high' | 'critical';
  content: string | null;        // Violating content
  source_message_id: string | null;
  source_chat_id: string | null;
  detected_by: 'ai' | 'system' | 'user';
  status: 'pending' | 'reviewing' | 'resolved' | 'dismissed';
  action_taken: string | null;
  admin_notes: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}
```

### Moderation Operations

#### Submit Report
```typescript
/**
 * Submits a moderation report
 * @param reporterId - Reporter's user ID
 * @param reportedUserId - Reported user's ID
 * @param reportType - Type of report
 * @param content - Report details
 */
const { data, error } = await supabase
  .from('moderation_reports')
  .insert({
    reporter_id: reporterId,
    reported_user_id: reportedUserId,
    report_type: reportType,
    content: content,
    status: 'pending'
  })
  .select()
  .single();
```

#### Flag Message
```typescript
/**
 * Flags a message for review
 * @param messageId - Message ID to flag
 * @param reason - Reason for flagging
 */
const { error } = await supabase
  .from('chat_messages')
  .update({
    flagged: true,
    flag_reason: reason,
    flagged_at: new Date().toISOString(),
    moderation_status: 'pending'
  })
  .eq('id', messageId);
```

---

## Admin API

### Tables

#### user_roles
Role-based access control.

```typescript
interface UserRole {
  id: string;                    // UUID - Primary key
  user_id: string;               // UUID - User ID
  role: 'user' | 'moderator' | 'admin' | 'super_admin';
  created_at: string;
}
```

#### audit_logs
Admin action audit trail.

```typescript
interface AuditLog {
  id: string;                    // UUID - Primary key
  admin_id: string;              // UUID - Admin who performed action
  admin_email: string | null;    // Admin's email
  action: string;                // Action performed
  action_type: string;           // Category of action
  resource_type: string;         // Type of resource affected
  resource_id: string | null;    // ID of affected resource
  old_value: object | null;      // Previous value
  new_value: object | null;      // New value
  details: string | null;        // Additional details
  status: 'success' | 'failed';
  ip_address: string | null;
  user_agent: string | null;
  created_at: string;
}
```

### Admin Operations

#### Check Admin Role
```typescript
/**
 * Checks if user has admin role
 * @param userId - User's ID
 * @returns Boolean indicating admin status
 */
const { data, error } = await supabase
  .rpc('has_role', {
    _user_id: userId,
    _role: 'admin'
  });
```

#### Get All Users (Admin)
```typescript
/**
 * Gets all users with filtering (admin only)
 * @param filters - Filter criteria
 * @returns Paginated user list
 */
const { data, error } = await supabase
  .from('profiles')
  .select('*, user_status(*)')
  .order('created_at', { ascending: false })
  .range(0, 49);
```

#### Suspend User
```typescript
/**
 * Suspends a user account (admin only)
 * @param userId - User to suspend
 * @param reason - Suspension reason
 */
const { error } = await supabase
  .from('profiles')
  .update({
    account_status: 'suspended',
    suspension_reason: reason,
    suspended_at: new Date().toISOString()
  })
  .eq('user_id', userId);

// Log the action
await supabase
  .from('audit_logs')
  .insert({
    admin_id: adminUserId,
    action: 'suspend_user',
    action_type: 'user_management',
    resource_type: 'profiles',
    resource_id: userId,
    details: reason
  });
```

---

## Storage API

### Buckets

| Bucket | Public | Purpose |
|--------|--------|---------|
| `profile-photos` | Yes | User profile and gallery photos |
| `voice-messages` | Yes | Voice message recordings |
| `legal-documents` | Yes | Terms, policies, legal docs |

### Operations

#### Upload File
```typescript
/**
 * Uploads a file to storage
 * @param bucket - Storage bucket name
 * @param path - File path within bucket
 * @param file - File to upload
 * @returns Upload result with path
 */
const { data, error } = await supabase.storage
  .from('profile-photos')
  .upload(`${userId}/${filename}`, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type
  });
```

#### Get Public URL
```typescript
/**
 * Gets public URL for a file
 * @param bucket - Storage bucket name
 * @param path - File path
 * @returns Public URL
 */
const { data } = supabase.storage
  .from('profile-photos')
  .getPublicUrl(`${userId}/${filename}`);

const publicUrl = data.publicUrl;
```

#### Delete File
```typescript
/**
 * Deletes a file from storage
 * @param bucket - Storage bucket name
 * @param paths - Array of file paths to delete
 */
const { error } = await supabase.storage
  .from('profile-photos')
  .remove([`${userId}/${filename}`]);
```

---

## Edge Functions Reference

### chat-manager
Manages chat sessions and billing.

**Endpoint:** `POST /functions/v1/chat-manager`

**Request:**
```typescript
interface ChatManagerRequest {
  action: 'start_chat' | 'end_chat' | 'get_active_chats' | 'update_billing';
  man_user_id?: string;
  woman_user_id?: string;
  chat_id?: string;
  end_reason?: string;
}
```

**Response:**
```typescript
interface ChatManagerResponse {
  success: boolean;
  data?: {
    chat_id?: string;
    session?: ActiveChatSession;
    sessions?: ActiveChatSession[];
  };
  error?: string;
}
```

### translate-message
Real-time message translation using NLLB-200.

**Endpoint:** `POST /functions/v1/translate-message`

**Request:**
```typescript
interface TranslateRequest {
  text: string;           // Text to translate
  source_lang: string;    // Source language code
  target_lang: string;    // Target language code
}
```

**Response:**
```typescript
interface TranslateResponse {
  translated_text: string;
  source_lang: string;
  target_lang: string;
  confidence?: number;
}
```

### content-moderation
AI-powered content moderation.

**Endpoint:** `POST /functions/v1/content-moderation`

**Request:**
```typescript
interface ModerationRequest {
  content: string;        // Content to moderate
  message_id?: string;    // Related message ID
  user_id?: string;       // User who created content
}
```

**Response:**
```typescript
interface ModerationResponse {
  is_safe: boolean;
  violations: string[];
  confidence: number;
  action_required: boolean;
  suggested_action?: 'warn' | 'flag' | 'block';
}
```

### verify-photo
AI photo verification for profiles.

**Endpoint:** `POST /functions/v1/verify-photo`

**Request:**
```typescript
interface VerifyPhotoRequest {
  photo_url: string;
  user_id: string;
  verification_type: 'profile' | 'identity' | 'gallery';
}
```

**Response:**
```typescript
interface VerifyPhotoResponse {
  is_valid: boolean;
  is_human: boolean;
  is_appropriate: boolean;
  detected_gender?: 'male' | 'female';
  confidence: number;
  rejection_reasons?: string[];
}
```

### ai-women-approval
AI-powered approval for women profiles.

**Endpoint:** `POST /functions/v1/ai-women-approval`

**Request:**
```typescript
interface ApprovalRequest {
  user_id: string;
  profile_data: Partial<Profile>;
  photos: string[];
}
```

**Response:**
```typescript
interface ApprovalResponse {
  approved: boolean;
  confidence: number;
  checks: {
    photo_valid: boolean;
    profile_complete: boolean;
    age_verified: boolean;
    gender_verified: boolean;
  };
  rejection_reason?: string;
}
```

---

## Realtime Events

### Chat Messages
```typescript
// Subscribe to new messages in a specific chat
const channel = supabase
  .channel(`chat:${chatId}`)
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'chat_messages',
      filter: `chat_id=eq.${chatId}`
    },
    (payload) => {
      const newMessage = payload.new as ChatMessage;
      // Handle new message
    }
  )
  .subscribe();
```

### User Status
```typescript
// Subscribe to user online/offline status
const channel = supabase
  .channel('user-status')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'user_status'
    },
    (payload) => {
      // Handle status change
    }
  )
  .subscribe();
```

### Chat Sessions
```typescript
// Subscribe to chat session updates
const channel = supabase
  .channel('chat-sessions')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'active_chat_sessions',
      filter: `woman_user_id=eq.${userId}`
    },
    (payload) => {
      // Handle session update
    }
  )
  .subscribe();
```

---

## Error Codes

### Supabase Error Codes
| Code | Description | Resolution |
|------|-------------|------------|
| `PGRST301` | Row not found | Check if record exists |
| `PGRST204` | No content returned | Expected for some operations |
| `23505` | Unique constraint violation | Record already exists |
| `23503` | Foreign key violation | Referenced record doesn't exist |
| `42501` | Permission denied (RLS) | Check user permissions |
| `42P01` | Table not found | Check table name |
| `22P02` | Invalid input syntax | Check data types |

### Auth Error Codes
| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_credentials` | Wrong email/password | Verify credentials |
| `email_not_confirmed` | Email not verified | Check email for verification link |
| `user_not_found` | No user with email | Register first |
| `weak_password` | Password too weak | Use stronger password |
| `email_taken` | Email already registered | Use different email or login |

### Edge Function Errors
| Code | Description |
|------|-------------|
| `400` | Bad request - invalid parameters |
| `401` | Unauthorized - missing or invalid token |
| `403` | Forbidden - insufficient permissions |
| `404` | Not found - resource doesn't exist |
| `429` | Rate limited - too many requests |
| `500` | Internal server error |

---

## Rate Limits

| Resource | Limit | Window |
|----------|-------|--------|
| Database queries | 1000 | Per minute per user |
| Edge function calls | 500 | Per minute per user |
| Auth attempts | 10 | Per minute per IP |
| File uploads | 50 | Per minute per user |
| Realtime connections | 100 | Concurrent per project |
| Message sends | 60 | Per minute per user |
