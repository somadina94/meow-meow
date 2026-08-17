# Meow Chat - API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Database Tables](#database-tables)
4. [Edge Functions](#edge-functions)
5. [Realtime Subscriptions](#realtime-subscriptions)
6. [Error Handling](#error-handling)

---

## Overview

Meow Chat uses Supabase as its backend, providing:
- **PostgreSQL Database**: For data storage
- **Edge Functions**: For serverless API endpoints
- **Realtime**: For live updates
- **Auth**: For user authentication
- **Storage**: For file uploads

### Base URLs
```
Database API: https://www.meow-meow.co.in:8443/rest/v1
Edge Functions: https://www.meow-meow.co.in:8443/functions/v1
Auth: https://www.meow-meow.co.in:8443/auth/v1
Storage: https://www.meow-meow.co.in:8443/storage/v1
```

---

## Authentication

### Sign Up
```typescript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'secure-password'
});
```

### Sign In
```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'secure-password'
});
```

### Sign Out
```typescript
const { error } = await supabase.auth.signOut();
```

### Get Current User
```typescript
const { data: { user } } = await supabase.auth.getUser();
```

---

## Database Tables

### profiles
User profile information for all users.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to auth.users |
| full_name | text | User's full name |
| gender | text | 'male' or 'female' |
| age | integer | User's age |
| country | text | User's country |
| state | text | User's state |
| photo_url | text | Profile photo URL |
| primary_language | text | Primary language |
| preferred_language | text | Preferred chat language |
| bio | text | User biography |
| approval_status | text | 'pending', 'approved', 'rejected' |
| account_status | text | 'active', 'suspended', 'banned' |

**Example Query:**
```typescript
// Get user profile
const { data, error } = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', userId)
  .single();
```

### chat_messages
All chat messages between users.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| chat_id | text | Chat session identifier |
| sender_id | uuid | Sender user ID |
| receiver_id | uuid | Receiver user ID |
| message | text | Message content |
| translated_message | text | Translated message |
| is_translated | boolean | Translation status |
| is_read | boolean | Read status |
| created_at | timestamp | Creation time |
| flagged | boolean | Moderation flag |
| moderation_status | text | Moderation status |

**Example Query:**
```typescript
// Get chat messages
const { data, error } = await supabase
  .from('chat_messages')
  .select('*')
  .eq('chat_id', chatId)
  .order('created_at', { ascending: true });
```

### active_chat_sessions
Currently active chat sessions with billing information.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| chat_id | text | Chat identifier |
| man_user_id | uuid | Male user ID |
| woman_user_id | uuid | Female user ID |
| status | text | 'active', 'ended' |
| started_at | timestamp | Session start time |
| ended_at | timestamp | Session end time |
| rate_per_minute | numeric | Billing rate |
| total_minutes | numeric | Total chat minutes |
| total_earned | numeric | Total earnings |

### wallets
User wallet balances.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | User ID |
| balance | numeric | Current balance |
| currency | text | Currency code |

**Example Query:**
```typescript
// Get wallet balance
const { data, error } = await supabase
  .from('wallets')
  .select('balance, currency')
  .eq('user_id', userId)
  .single();
```

### wallet_transactions
All wallet transactions.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| wallet_id | uuid | Wallet reference |
| user_id | uuid | User ID |
| type | text | 'credit', 'debit' |
| amount | numeric | Transaction amount |
| description | text | Transaction description |
| status | text | Transaction status |

---

## Edge Functions

### chat-manager
Manages chat sessions and billing.

**Endpoint:** `POST /functions/v1/chat-manager`

**Actions:**
- `start_chat` - Start a new chat session
- `end_chat` - End an active chat session
- `get_active_chats` - Get user's active chats

**Example:**
```typescript
const { data, error } = await supabase.functions.invoke('chat-manager', {
  body: {
    action: 'start_chat',
    man_user_id: 'uuid',
    woman_user_id: 'uuid'
  }
});
```

### translate-message
Translates messages between languages.

**Endpoint:** `POST /functions/v1/translate-message`

**Example:**
```typescript
const { data, error } = await supabase.functions.invoke('translate-message', {
  body: {
    text: 'Hello, how are you?',
    source_lang: 'en',
    target_lang: 'es'
  }
});
```

### content-moderation
Moderates message content for policy violations.

**Endpoint:** `POST /functions/v1/content-moderation`

**Example:**
```typescript
const { data, error } = await supabase.functions.invoke('content-moderation', {
  body: {
    message_id: 'uuid',
    content: 'Message text to moderate'
  }
});
```

### verify-photo
Verifies uploaded photos using AI.

**Endpoint:** `POST /functions/v1/verify-photo`

**Example:**
```typescript
const { data, error } = await supabase.functions.invoke('verify-photo', {
  body: {
    photo_url: 'https://...',
    user_id: 'uuid',
    verification_type: 'profile'
  }
});
```

---

## Realtime Subscriptions

### Subscribe to Chat Messages
```typescript
const subscription = supabase
  .channel('chat-messages')
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
    }
  )
  .subscribe();

// Unsubscribe
subscription.unsubscribe();
```

### Subscribe to User Status
```typescript
const subscription = supabase
  .channel('user-status')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'user_status',
      filter: `user_id=eq.${userId}`
    },
    (payload) => {
      console.log('Status changed:', payload);
    }
  )
  .subscribe();
```

---

## Error Handling

### Standard Error Response
```typescript
interface ErrorResponse {
  error: {
    message: string;
    code: string;
    details?: string;
  }
}
```

### Common Error Codes
| Code | Description |
|------|-------------|
| `PGRST301` | Row not found |
| `PGRST204` | No content |
| `23505` | Unique constraint violation |
| `42501` | Permission denied (RLS) |
| `JWT_EXPIRED` | Authentication token expired |

### Error Handling Example
```typescript
const { data, error } = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', userId)
  .single();

if (error) {
  if (error.code === 'PGRST301') {
    console.log('Profile not found');
  } else if (error.code === '42501') {
    console.log('Permission denied');
  } else {
    console.error('Error:', error.message);
  }
}
```

---

## Rate Limits

- **Database Queries**: 1000 requests/minute per user
- **Edge Functions**: 500 invocations/minute per user
- **Realtime**: 100 concurrent connections per project
- **Storage**: 50 uploads/minute per user

---

## Best Practices

1. **Always use RLS**: Rely on Row Level Security for data access control
2. **Use `.single()` carefully**: Only when expecting exactly one row
3. **Handle errors gracefully**: Always check for errors in responses
4. **Unsubscribe from realtime**: Clean up subscriptions when components unmount
5. **Use typed queries**: Leverage TypeScript for type safety
