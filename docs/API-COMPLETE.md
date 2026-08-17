# Meow Chat - Complete API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Authentication API](#authentication-api)
3. [Database API](#database-api)
4. [Edge Functions API](#edge-functions-api)
5. [Storage API](#storage-api)
6. [Realtime API](#realtime-api)
7. [Error Codes](#error-codes)

---

## Overview

### Base URLs
```
Supabase API:      https://www.meow-meow.co.in:8443
REST API:          https://www.meow-meow.co.in:8443/rest/v1
Auth API:          https://www.meow-meow.co.in:8443/auth/v1
Edge Functions:    https://www.meow-meow.co.in:8443/functions/v1
Storage:           https://www.meow-meow.co.in:8443/storage/v1
Realtime:          wss://www.meow-meow.co.in:8443/realtime/v1
```

### Authentication Headers
```typescript
// All API requests require these headers:
const headers = {
  'apikey': 'YOUR_ANON_KEY',
  'Authorization': 'Bearer YOUR_JWT_TOKEN',
  'Content-Type': 'application/json'
};
```

### Supabase Client Setup
```typescript
// src/integrations/supabase/client.ts
import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

const SUPABASE_URL = "https://www.meow-meow.co.in:8443";
const SUPABASE_KEY = "your-anon-key";

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    storage: localStorage,
    persistSession: true,
    autoRefreshToken: true,
  }
});
```

---

## Authentication API

### Sign Up
Create a new user account.

```typescript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'secure-password-123',
  options: {
    data: {
      full_name: 'John Doe',
      gender: 'male'
    }
  }
});

// Response
{
  user: {
    id: 'uuid',
    email: 'user@example.com',
    created_at: '2024-01-01T00:00:00.000Z'
  },
  session: {
    access_token: 'jwt-token',
    refresh_token: 'refresh-token'
  }
}
```

### Sign In
Authenticate an existing user.

```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'secure-password-123'
});

// Response
{
  user: { id: 'uuid', email: '...' },
  session: { access_token: '...', refresh_token: '...' }
}
```

### Sign Out
End the current session.

```typescript
const { error } = await supabase.auth.signOut();
```

### Get Current User
Get the authenticated user's details.

```typescript
const { data: { user }, error } = await supabase.auth.getUser();

// Response
{
  id: 'uuid',
  email: 'user@example.com',
  user_metadata: { full_name: 'John Doe' }
}
```

### Password Reset Request
Send password reset email.

```typescript
// Call the reset-password edge function
const { data, error } = await supabase.functions.invoke('reset-password', {
  body: { email: 'user@example.com' }
});
```

### Update Password
Update user's password with reset token.

```typescript
const { data, error } = await supabase.auth.updateUser({
  password: 'new-secure-password'
});
```

---

## Database API

### Profiles Table

#### Get User Profile
```typescript
const { data, error } = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', userId)
  .single();

// Response
{
  id: 'uuid',
  user_id: 'uuid',
  full_name: 'John Doe',
  gender: 'male',
  age: 28,
  country: 'India',
  state: 'Maharashtra',
  photo_url: 'https://...',
  primary_language: 'Hindi',
  preferred_language: 'English',
  bio: 'Hello world',
  approval_status: 'approved',
  account_status: 'active',
  created_at: '2024-01-01T00:00:00.000Z'
}
```

#### Update Profile
```typescript
const { data, error } = await supabase
  .from('profiles')
  .update({
    full_name: 'Jane Doe',
    bio: 'Updated bio'
  })
  .eq('user_id', userId)
  .select();
```

#### Get All Approved Female Profiles
```typescript
const { data, error } = await supabase
  .from('female_profiles')
  .select(`
    *,
    profiles!inner(photo_url, full_name)
  `)
  .eq('approval_status', 'approved')
  .eq('account_status', 'active')
  .order('last_active_at', { ascending: false });
```

### Chat Messages Table

#### Send Message
```typescript
const { data, error } = await supabase
  .from('chat_messages')
  .insert({
    chat_id: 'chat-uuid',
    sender_id: 'sender-uuid',
    receiver_id: 'receiver-uuid',
    message: 'Hello!',
    is_translated: false
  })
  .select();
```

#### Get Chat History
```typescript
const { data, error } = await supabase
  .from('chat_messages')
  .select('*')
  .eq('chat_id', chatId)
  .order('created_at', { ascending: true })
  .limit(100);
```

#### Mark Messages as Read
```typescript
const { data, error } = await supabase
  .from('chat_messages')
  .update({ is_read: true })
  .eq('chat_id', chatId)
  .eq('receiver_id', currentUserId)
  .is('is_read', false);
```

### Wallets Table

#### Get Wallet Balance
```typescript
const { data, error } = await supabase
  .from('wallets')
  .select('id, balance, currency')
  .eq('user_id', userId)
  .single();

// Response
{
  id: 'wallet-uuid',
  balance: 5000.00,
  currency: 'INR'
}
```

#### Process Transaction (via RPC)
```typescript
const { data, error } = await supabase.rpc('process_wallet_transaction', {
  p_user_id: userId,
  p_amount: 100.00,
  p_type: 'credit',  // or 'debit'
  p_description: 'Wallet top-up'
});

// Response
{
  success: true,
  transaction_id: 'uuid',
  previous_balance: 5000.00,
  new_balance: 5100.00
}
```

### Gifts Table

#### Get Available Gifts
```typescript
const { data, error } = await supabase
  .from('gifts')
  .select('*')
  .eq('is_active', true)
  .order('sort_order', { ascending: true });

// Response
[
  {
    id: 'gift-uuid',
    name: 'Rose',
    emoji: '🌹',
    price: 50.00,
    currency: 'INR',
    category: 'flowers',
    description: 'A beautiful rose'
  }
]
```

#### Send Gift (via RPC)
```typescript
const { data, error } = await supabase.rpc('process_gift_transaction', {
  p_sender_id: senderId,
  p_receiver_id: receiverId,
  p_gift_id: giftId,
  p_message: 'For you!'
});

// Response
{
  success: true,
  gift_transaction_id: 'uuid',
  wallet_transaction_id: 'uuid',
  previous_balance: 5000.00,
  new_balance: 4950.00,
  gift_name: 'Rose',
  gift_emoji: '🌹',
  women_share: 25.00,
  admin_share: 25.00
}
```

### Active Chat Sessions

#### Get Active Sessions
```typescript
const { data, error } = await supabase
  .from('active_chat_sessions')
  .select(`
    *,
    woman:profiles!woman_user_id(full_name, photo_url),
    man:profiles!man_user_id(full_name, photo_url)
  `)
  .eq('status', 'active')
  .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`);
```

---

## Edge Functions API

### chat-manager
Manages chat sessions and billing.

#### Start Chat Session
```typescript
const { data, error } = await supabase.functions.invoke('chat-manager', {
  body: {
    action: 'start_chat',
    man_user_id: 'uuid',
    woman_user_id: 'uuid'
  }
});

// Response
{
  success: true,
  session_id: 'uuid',
  chat_id: 'chat-uuid',
  rate_per_minute: 10.00
}
```

#### End Chat Session
```typescript
const { data, error } = await supabase.functions.invoke('chat-manager', {
  body: {
    action: 'end_chat',
    session_id: 'uuid'
  }
});

// Response
{
  success: true,
  total_minutes: 15.5,
  total_charged: 155.00,
  total_earned: 77.50
}
```

### translate-message
Translates messages using NLLB-200 AI model.

```typescript
const { data, error } = await supabase.functions.invoke('translate-message', {
  body: {
    text: 'Hello, how are you?',
    source_lang: 'eng_Latn',
    target_lang: 'hin_Deva'
  }
});

// Response
{
  translated_text: 'नमस्ते, आप कैसे हैं?',
  source_lang: 'eng_Latn',
  target_lang: 'hin_Deva'
}
```

### verify-photo
Verifies photos using AI gender classification.

```typescript
const { data, error } = await supabase.functions.invoke('verify-photo', {
  body: {
    imageBase64: 'data:image/jpeg;base64,...',
    expectedGender: 'female',
    userId: 'uuid',
    verificationType: 'profile'
  }
});

// Response
{
  verified: true,
  hasFace: true,
  detectedGender: 'female',
  confidence: 0.95,
  genderMatches: true,
  reason: 'Photo verified successfully'
}
```

### content-moderation
Moderates message content for policy violations.

```typescript
const { data, error } = await supabase.functions.invoke('content-moderation', {
  body: {
    action: 'moderate_message',
    content: 'Message text to check',
    user_id: 'uuid',
    chat_id: 'chat-uuid',
    message_id: 'message-uuid'
  }
});

// Response
{
  has_violation: false,
  violations: [],
  moderation_status: 'approved'
}
// OR
{
  has_violation: true,
  violations: [
    {
      type: 'contact_sharing',
      severity: 'high',
      matches: ['phone number pattern']
    }
  ],
  moderation_status: 'flagged'
}
```

### video-call-server
Manages video call sessions.

```typescript
// Start video call
const { data, error } = await supabase.functions.invoke('video-call-server', {
  body: {
    action: 'start_call',
    caller_id: 'uuid',
    callee_id: 'uuid'
  }
});

// Response
{
  success: true,
  session_id: 'uuid',
  stream_url: 'rtc://...'
}

// End video call
const { data, error } = await supabase.functions.invoke('video-call-server', {
  body: {
    action: 'end_call',
    session_id: 'uuid'
  }
});
```

### reset-password
Sends password reset email via Mailjet.

```typescript
const { data, error } = await supabase.functions.invoke('reset-password', {
  body: {
    email: 'user@example.com'
  }
});

// Response
{
  success: true,
  message: 'Password reset email sent'
}
```

---

## Storage API

### Storage Buckets
| Bucket | Public | Purpose |
|--------|--------|---------|
| `profile-photos` | Yes | User profile photos |
| `voice-messages` | Yes | Voice message recordings |
| `legal-documents` | Yes | Legal document files |

### Upload Profile Photo
```typescript
const file = /* File object */;
const fileName = `${userId}/${Date.now()}.jpg`;

const { data, error } = await supabase.storage
  .from('profile-photos')
  .upload(fileName, file, {
    contentType: 'image/jpeg',
    upsert: true
  });

// Get public URL
const { data: { publicUrl } } = supabase.storage
  .from('profile-photos')
  .getPublicUrl(fileName);
```

### Upload Voice Message
```typescript
const audioBlob = /* Audio Blob */;
const fileName = `${chatId}/${Date.now()}.webm`;

const { data, error } = await supabase.storage
  .from('voice-messages')
  .upload(fileName, audioBlob, {
    contentType: 'audio/webm'
  });
```

### Delete File
```typescript
const { error } = await supabase.storage
  .from('profile-photos')
  .remove([`${userId}/photo.jpg`]);
```

---

## Realtime API

### Subscribe to Chat Messages
```typescript
const subscription = supabase
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
      console.log('New message:', payload.new);
      // Handle new message
    }
  )
  .subscribe();

// Unsubscribe
subscription.unsubscribe();
```

### Subscribe to User Online Status
```typescript
const subscription = supabase
  .channel('user-presence')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'user_status'
    },
    (payload) => {
      console.log('Status change:', payload);
    }
  )
  .subscribe();
```

### Subscribe to Wallet Balance
```typescript
const subscription = supabase
  .channel(`wallet:${userId}`)
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'wallets',
      filter: `user_id=eq.${userId}`
    },
    (payload) => {
      console.log('Balance updated:', payload.new.balance);
    }
  )
  .subscribe();
```

---

## Error Codes

### Supabase Error Codes
| Code | Description | Solution |
|------|-------------|----------|
| `PGRST301` | Row not found | Check query filters |
| `PGRST204` | No content | Query returned empty result |
| `23505` | Unique constraint violation | Check for duplicates |
| `42501` | Permission denied (RLS) | Check RLS policies |
| `42P01` | Table does not exist | Check table name |
| `22P02` | Invalid input syntax | Check data types |

### Auth Error Codes
| Code | Description | Solution |
|------|-------------|----------|
| `invalid_grant` | Invalid credentials | Check email/password |
| `user_not_found` | User doesn't exist | Check email |
| `email_not_confirmed` | Email not verified | Verify email |
| `session_expired` | JWT expired | Refresh token |

### Edge Function Errors
| Code | Description | Solution |
|------|-------------|----------|
| `FunctionsHttpError` | HTTP error | Check function logs |
| `FunctionsRelayError` | Network error | Check connection |
| `FunctionsFetchError` | Fetch failed | Retry request |

### Error Handling Example
```typescript
try {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error) {
    switch (error.code) {
      case 'PGRST301':
        console.error('Profile not found');
        break;
      case '42501':
        console.error('Permission denied - check RLS policies');
        break;
      default:
        console.error('Database error:', error.message);
    }
    return null;
  }

  return data;
} catch (err) {
  console.error('Unexpected error:', err);
  throw err;
}
```

---

## Rate Limits

| Resource | Limit | Window |
|----------|-------|--------|
| Database queries | 1000 | per minute per user |
| Edge Function calls | 500 | per minute per user |
| Auth requests | 60 | per minute per IP |
| Storage uploads | 50 | per minute per user |
| Realtime connections | 100 | concurrent per project |

---

## Best Practices

1. **Always handle errors** - Check for errors in every response
2. **Use RLS** - Never bypass Row Level Security
3. **Type your queries** - Use TypeScript for type safety
4. **Paginate results** - Use `.range()` for large datasets
5. **Unsubscribe from realtime** - Clean up subscriptions
6. **Use transactions** - Use RPC functions for atomic operations
7. **Validate input** - Validate data before sending to API
8. **Cache when possible** - Reduce API calls with caching
