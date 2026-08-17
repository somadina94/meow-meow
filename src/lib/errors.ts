/**
 * Centralized Error Handling System
 *
 * Classifies every error the app may encounter — Supabase Auth, Supabase DB,
 * network failures, storage, real-time, and generic JS errors — and maps them
 * to friendly, actionable messages end users can actually understand.
 */

// ─── Error category enum ────────────────────────────────────────────────────

export enum ErrorCategory {
  AUTH = 'AUTH',
  NETWORK = 'NETWORK',
  DATABASE = 'DATABASE',
  STORAGE = 'STORAGE',
  VALIDATION = 'VALIDATION',
  PERMISSION = 'PERMISSION',
  RATE_LIMIT = 'RATE_LIMIT',
  SERVER = 'SERVER',
  REALTIME = 'REALTIME',
  PAYMENT = 'PAYMENT',
  MEDIA = 'MEDIA',
  UNKNOWN = 'UNKNOWN',
}

// ─── Structured app error ────────────────────────────────────────────────────

export interface AppError {
  /** User-facing title (short) */
  title: string;
  /** User-facing description (full sentence, plain language) */
  message: string;
  /** Whether the user can retry the same action */
  retryable: boolean;
  /** Optional CTA label for retry / action button */
  action?: string;
  /** Internal category for logging / analytics */
  category: ErrorCategory;
  /** Original raw error for dev logging */
  raw?: unknown;
}

// ─── Supabase Auth error code → friendly message ────────────────────────────

const AUTH_ERROR_MAP: Record<string, { title: string; message: string; retryable: boolean; action?: string }> = {
  // Sign-in errors
  invalid_credentials: {
    title: 'Incorrect email or password',
    message: 'The email or password you entered is incorrect. Please check and try again.',
    retryable: true,
  },
  invalid_grant: {
    title: 'Incorrect email or password',
    message: 'The email or password you entered is incorrect. Please check and try again.',
    retryable: true,
  },
  user_not_found: {
    title: 'Account not found',
    message: 'No account exists with that email address. Please check the email or create a new account.',
    retryable: true,
  },
  email_not_confirmed: {
    title: 'Email not verified',
    message: 'Please check your inbox and verify your email address before logging in.',
    retryable: false,
    action: 'Resend verification email',
  },
  user_banned: {
    title: 'Account suspended',
    message: 'Your account has been suspended. Please contact support if you believe this is a mistake.',
    retryable: false,
  },
  // Sign-up errors
  user_already_exists: {
    title: 'Email already registered',
    message: 'An account with this email already exists. Try logging in instead, or reset your password if you\'ve forgotten it.',
    retryable: false,
    action: 'Log in',
  },
  email_exists: {
    title: 'Email already in use',
    message: 'An account with this email already exists. Please log in or use a different email address.',
    retryable: false,
  },
  weak_password: {
    title: 'Password too weak',
    message: 'Your password must be at least 6 characters long. Try adding numbers or symbols to make it stronger.',
    retryable: true,
  },
  // Token / session errors
  token_expired: {
    title: 'Session expired',
    message: 'Your session has expired. Please log in again to continue.',
    retryable: false,
    action: 'Log in',
  },
  refresh_token_not_found: {
    title: 'Session expired',
    message: 'Your session has expired. Please log in again to continue.',
    retryable: false,
    action: 'Log in',
  },
  session_not_found: {
    title: 'Not logged in',
    message: 'You need to be logged in to do that. Please log in and try again.',
    retryable: false,
    action: 'Log in',
  },
  // Password errors
  same_password: {
    title: 'Same password',
    message: 'Your new password must be different from your current password.',
    retryable: true,
  },
  over_email_send_rate_limit: {
    title: 'Too many emails sent',
    message: 'We\'ve sent too many emails recently. Please wait a few minutes before trying again.',
    retryable: true,
  },
  over_request_rate_limit: {
    title: 'Too many attempts',
    message: 'You\'ve made too many attempts. Please wait a few minutes and try again.',
    retryable: true,
  },
  captcha_failed: {
    title: 'Verification failed',
    message: 'Security verification failed. Please refresh the page and try again.',
    retryable: true,
  },
  signup_disabled: {
    title: 'Registration unavailable',
    message: 'New registrations are temporarily disabled. Please try again later or contact support.',
    retryable: false,
  },
  phone_exists: {
    title: 'Phone number already used',
    message: 'This phone number is already linked to another account.',
    retryable: true,
  },
  otp_expired: {
    title: 'Code expired',
    message: 'The verification code has expired. Please request a new one.',
    retryable: true,
    action: 'Resend code',
  },
  bad_jwt: {
    title: 'Invalid session',
    message: 'Your session is invalid. Please log out and log in again.',
    retryable: false,
    action: 'Log in',
  },
  // OAuth errors
  provider_email_needs_verification: {
    title: 'Email verification required',
    message: 'Please verify your email address with your sign-in provider first.',
    retryable: false,
  },
};

// ─── Supabase PostgreSQL / DB error code → friendly message ─────────────────

const DB_ERROR_MAP: Record<string, { title: string; message: string; retryable: boolean; action?: string }> = {
  '23505': {
    title: 'Already exists',
    message: 'This record already exists. You may have already submitted this.',
    retryable: false,
  },
  '23503': {
    title: 'Invalid reference',
    message: 'This action requires related data that doesn\'t exist. Please refresh and try again.',
    retryable: true,
  },
  '23514': {
    title: 'Invalid data',
    message: 'The data you entered doesn\'t meet the required format. Please check and try again.',
    retryable: true,
  },
  '42501': {
    title: 'Permission denied',
    message: 'You don\'t have permission to perform this action.',
    retryable: false,
  },
  '42P01': {
    title: 'Service unavailable',
    message: 'A required part of the service is temporarily unavailable. Please try again shortly.',
    retryable: true,
  },
  'PGRST116': {
    title: 'Not found',
    message: 'The item you\'re looking for doesn\'t exist or has been removed.',
    retryable: false,
  },
  'PGRST301': {
    title: 'Session expired',
    message: 'Your session has expired. Please log in again.',
    retryable: false,
    action: 'Log in',
  },
};

// ─── Storage error messages ──────────────────────────────────────────────────

const STORAGE_ERROR_MAP: Record<string, { title: string; message: string }> = {
  'Payload too large': {
    title: 'File too large',
    message: 'The file you\'re trying to upload is too large. Please choose a smaller file (max 50MB).',
  },
  'invalid file type': {
    title: 'File type not allowed',
    message: 'This file type is not supported. Please use JPG, PNG, or MP4 files.',
  },
  'object not found': {
    title: 'File not found',
    message: 'The file you\'re looking for no longer exists.',
  },
  'Bucket not found': {
    title: 'Upload unavailable',
    message: 'The upload service is temporarily unavailable. Please try again shortly.',
  },
  'The resource already exists': {
    title: 'File already uploaded',
    message: 'This file has already been uploaded.',
  },
};

// ─── Network error patterns ──────────────────────────────────────────────────

const NETWORK_PATTERNS: Array<{ pattern: RegExp; title: string; message: string }> = [
  {
    pattern: /failed to fetch|networkerror|network request failed/i,
    title: 'No internet connection',
    message: 'Unable to connect to the server. Please check your internet connection and try again.',
  },
  {
    pattern: /timeout|timed out/i,
    title: 'Request timed out',
    message: 'The server took too long to respond. Please check your connection and try again.',
  },
  {
    pattern: /aborted|abort/i,
    title: 'Request cancelled',
    message: 'The request was cancelled. Please try again.',
  },
  {
    pattern: /cors/i,
    title: 'Connection blocked',
    message: 'Your browser blocked the connection. Please refresh the page and try again.',
  },
  {
    pattern: /502|503|504|bad gateway|service unavailable|gateway timeout/i,
    title: 'Server temporarily unavailable',
    message: 'Our servers are temporarily unavailable. Please try again in a few moments.',
  },
  {
    pattern: /500|internal server error/i,
    title: 'Server error',
    message: 'Something went wrong on our end. Please try again. If the problem persists, contact support.',
  },
  {
    pattern: /401|unauthorized/i,
    title: 'Not authorised',
    message: 'You\'re not authorised to do that. Please log in and try again.',
  },
  {
    pattern: /403|forbidden/i,
    title: 'Access denied',
    message: 'You don\'t have permission to perform this action.',
  },
  {
    pattern: /404|not found/i,
    title: 'Not found',
    message: 'The resource you\'re looking for doesn\'t exist or has been removed.',
  },
  {
    pattern: /429|too many requests/i,
    title: 'Too many attempts',
    message: 'You\'ve made too many requests. Please wait a moment before trying again.',
  },
];

// ─── Media / camera error patterns ──────────────────────────────────────────

const MEDIA_ERROR_MAP: Record<string, { title: string; message: string }> = {
  NotAllowedError: {
    title: 'Camera / microphone access denied',
    message: 'Please allow camera and microphone access in your browser settings, then try again.',
  },
  PermissionDeniedError: {
    title: 'Camera / microphone access denied',
    message: 'Please allow camera and microphone access in your browser settings, then try again.',
  },
  NotFoundError: {
    title: 'Camera or microphone not found',
    message: 'No camera or microphone was detected. Please connect one and try again.',
  },
  NotReadableError: {
    title: 'Camera or microphone in use',
    message: 'Your camera or microphone is already being used by another app. Please close it and try again.',
  },
  OverconstrainedError: {
    title: 'Camera settings not supported',
    message: 'Your camera doesn\'t support the required settings. Please try a different camera.',
  },
  AbortError: {
    title: 'Camera access cancelled',
    message: 'Camera access was cancelled. Please try again.',
  },
};

// ─── Context-specific friendly messages ─────────────────────────────────────

export const ERROR_MESSAGES = {
  // Auth
  auth: {
    loginFailed: 'Unable to log in. Please check your email and password.',
    logoutFailed: 'Unable to log out. Please refresh the page and try again.',
    sessionExpired: 'Your session has expired. Please log in again to continue.',
    notAuthenticated: 'You need to be logged in to do that.',
    passwordResetSent: 'If an account exists with that email, you\'ll receive a reset link shortly.',
    passwordResetFailed: 'Unable to send reset email. Please check the email address and try again.',
    passwordChangeFailed: 'Unable to change your password. Please try again.',
    registrationFailed: 'Unable to create your account. Please try again.',
  },
  // Profile
  profile: {
    loadFailed: 'Unable to load your profile. Please refresh the page.',
    updateFailed: 'Unable to save your profile changes. Please try again.',
    photoUploadFailed: 'Unable to upload your photo. Make sure it\'s a JPG or PNG under 10MB.',
    photoDeleteFailed: 'Unable to delete the photo. Please try again.',
    kycSubmitFailed: 'Unable to submit your verification documents. Please try again.',
    kycLoadFailed: 'Unable to load verification details. Please refresh the page.',
  },
  // Chat
  chat: {
    loadFailed: 'Unable to load messages. Please refresh the page.',
    sendFailed: 'Your message couldn\'t be sent. Please try again.',
    attachmentFailed: 'Unable to send the attachment. Make sure it\'s under 50MB.',
    connectionLost: 'Chat connection lost. Reconnecting…',
    blocked: 'You can\'t message this user. They may have blocked you or vice versa.',
    initFailed: 'Unable to start the chat session. Please go back and try again.',
    translationFailed: 'Message translation failed. The original message is shown instead.',
    voiceRecordFailed: 'Unable to start voice recording. Please allow microphone access.',
  },
  // Wallet
  wallet: {
    loadFailed: 'Unable to load your wallet. Please refresh the page.',
    rechargeFailed: 'Recharge failed. Please try again or choose a different payment method.',
    withdrawFailed: 'Withdrawal failed. Please check your payment details and try again.',
    insufficientBalance: 'You don\'t have enough balance to do that. Please top up your wallet.',
    invalidAmount: 'Please enter a valid amount.',
    missingPaymentDetails: 'Please enter your payment details before withdrawing.',
    transactionFailed: 'Transaction failed. Your balance has not been changed.',
    historyLoadFailed: 'Unable to load transaction history. Please refresh the page.',
  },
  // Video / calls
  video: {
    joinFailed: 'Unable to join the call. Please check your internet connection and try again.',
    startFailed: 'Unable to start the call. Please try again.',
    cameraFailed: 'Unable to access your camera. Please allow camera access in your browser settings.',
    micFailed: 'Unable to access your microphone. Please allow microphone access in your browser settings.',
    connectionFailed: 'Call connection failed. Please check your internet and try again.',
    qualityPoor: 'Poor connection detected. Video quality has been reduced to maintain the call.',
    callEnded: 'The call has ended.',
    callDeclined: 'Call declined.',
    callNotAvailable: 'The other person is not available for a call right now.',
  },
  // Matching
  matching: {
    loadFailed: 'Unable to load matches. Please refresh the page.',
    noMatchesFound: 'No matches found right now. Try adjusting your preferences.',
    actionFailed: 'Unable to process that action. Please try again.',
    profileLoadFailed: 'Unable to load this profile. Please try again.',
  },
  // Admin
  admin: {
    accessDenied: 'You don\'t have admin privileges to access this area.',
    loadFailed: 'Unable to load admin data. Please refresh the page.',
    actionFailed: 'Admin action failed. Please try again.',
    userCreateFailed: 'Unable to create the user. Please check the details and try again.',
    userUpdateFailed: 'Unable to update the user. Please try again.',
    userDeleteFailed: 'Unable to delete the user. Please try again.',
    exportFailed: 'Unable to export data. Please try again.',
    broadcastFailed: 'Unable to send the broadcast message. Please try again.',
  },
  // Network / system
  system: {
    offline: 'You\'re offline. Please check your internet connection.',
    slowConnection: 'Your connection appears slow. Some features may take longer than usual.',
    serverDown: 'Our servers are temporarily unavailable. Please try again in a few minutes.',
    unknown: 'Something went wrong. Please try again. If the problem continues, contact support.',
    pageLoadFailed: 'Unable to load this page. Please refresh or go back and try again.',
    timeout: 'The request took too long. Please check your connection and try again.',
  },
  // File uploads
  upload: {
    tooLarge: 'This file is too large. Please choose a file under 50MB.',
    wrongType: 'This file type isn\'t supported. Please use JPG, PNG, or MP4.',
    failed: 'Upload failed. Please check your connection and try again.',
    virusScan: 'This file couldn\'t be verified as safe and was rejected.',
  },
  // Gifts
  gifts: {
    sendFailed: 'Unable to send the gift. Please try again.',
    loadFailed: 'Unable to load gifts. Please refresh the page.',
    insufficientBalance: 'You don\'t have enough balance to send this gift. Please top up your wallet.',
  },
} as const;

// ─── Core classifier function ────────────────────────────────────────────────

/**
 * Takes any error (Supabase Auth, Supabase DB, fetch, JS, string, etc.)
 * and returns a structured AppError with a user-friendly title and message.
 */
export function classifyError(error: unknown, context?: string): AppError {
  // ── Null / undefined ──
  if (!error) {
    return {
      title: 'Unexpected error',
      message: ERROR_MESSAGES.system.unknown,
      retryable: true,
      category: ErrorCategory.UNKNOWN,
      raw: error,
    };
  }

  const raw = error;
  const errObj = error as Record<string, unknown>;

  // ── Supabase Auth errors ──
  // They have __isAuthError: true, and a 'code' field
  if (errObj.__isAuthError || errObj.name === 'AuthApiError') {
    const code = (errObj.code as string) || '';
    const msg = ((errObj.message as string) || '').toLowerCase();

    // Try exact code match first
    const known = AUTH_ERROR_MAP[code];
    if (known) {
      return {
        ...known,
        action: (known as any).action,
        category: ErrorCategory.AUTH,
        raw,
      };
    }

    // Fallback: try to match message string
    if (msg.includes('invalid') && (msg.includes('password') || msg.includes('credential'))) {
      return { ...AUTH_ERROR_MAP.invalid_credentials, category: ErrorCategory.AUTH, raw };
    }
    if (msg.includes('email') && msg.includes('confirm')) {
      return { ...AUTH_ERROR_MAP.email_not_confirmed, category: ErrorCategory.AUTH, raw };
    }
    if (msg.includes('already') && msg.includes('registered')) {
      return { ...AUTH_ERROR_MAP.user_already_exists, category: ErrorCategory.AUTH, raw };
    }
    if (msg.includes('expired') || msg.includes('token')) {
      return { ...AUTH_ERROR_MAP.token_expired, category: ErrorCategory.AUTH, raw };
    }
    if (msg.includes('rate limit')) {
      return { ...AUTH_ERROR_MAP.over_request_rate_limit, category: ErrorCategory.RATE_LIMIT, raw };
    }
    if (msg.includes('password')) {
      return { ...AUTH_ERROR_MAP.weak_password, category: ErrorCategory.AUTH, raw };
    }

    return {
      title: 'Authentication error',
      message: 'Unable to complete the login. Please try again or contact support.',
      retryable: true,
      category: ErrorCategory.AUTH,
      raw,
    };
  }

  // ── Supabase PostgREST / DB errors ──
  // They have a 'code' field that is a PostgreSQL error code or PGRST code
  if (errObj.code && typeof errObj.code === 'string') {
    const code = errObj.code as string;
    const known = DB_ERROR_MAP[code];
    if (known) {
      return {
        ...known,
        action: (known as any).action,
        category: ErrorCategory.DATABASE,
        raw,
      };
    }
    // RLS / permission code
    if (code.startsWith('42') || code === 'PGRST301' || code === 'PGRST204') {
      return {
        title: 'Permission denied',
        message: 'You don\'t have permission to perform this action.',
        retryable: false,
        category: ErrorCategory.PERMISSION,
        raw,
      };
    }
  }

  // ── Storage errors ──
  if (errObj.statusCode === 413 || (errObj.message as string)?.includes('Payload too large')) {
    return {
      title: STORAGE_ERROR_MAP['Payload too large'].title,
      message: STORAGE_ERROR_MAP['Payload too large'].message,
      retryable: false,
      category: ErrorCategory.STORAGE,
      raw,
    };
  }

  // ── Media / getUserMedia errors ──
  const errName = (errObj.name as string) || '';
  if (MEDIA_ERROR_MAP[errName]) {
    const m = MEDIA_ERROR_MAP[errName];
    return {
      title: m.title,
      message: m.message,
      retryable: errName !== 'NotFoundError',
      category: ErrorCategory.MEDIA,
      raw,
    };
  }

  // ── Supabase FunctionsHttpError ──
  if (errObj.context || (errObj.name as string) === 'FunctionsHttpError') {
    const status = errObj.status as number | undefined;
    if (status === 401 || status === 403) {
      return {
        title: 'Session expired',
        message: 'Your session has expired. Please log in again.',
        retryable: false,
        action: 'Log in',
        category: ErrorCategory.AUTH,
        raw,
      };
    }
    if (status === 429) {
      return {
        title: 'Too many attempts',
        message: 'Please wait a moment before trying again.',
        retryable: true,
        category: ErrorCategory.RATE_LIMIT,
        raw,
      };
    }
    if (status && status >= 500) {
      return {
        title: 'Server error',
        message: 'Something went wrong on our end. Please try again shortly.',
        retryable: true,
        category: ErrorCategory.SERVER,
        raw,
      };
    }
    return {
      title: 'Request failed',
      message: 'The request could not be completed. Please try again.',
      retryable: true,
      category: ErrorCategory.SERVER,
      raw,
    };
  }

  // ── Standard Error with message ──
  const message = (
    typeof error === 'string' ? error :
    typeof errObj.message === 'string' ? errObj.message :
    ''
  );

  if (message) {
    const lowerMsg = message.toLowerCase();

    // Storage-specific messages
    for (const [key, val] of Object.entries(STORAGE_ERROR_MAP)) {
      if (lowerMsg.includes(key.toLowerCase())) {
        return {
          title: val.title,
          message: val.message,
          retryable: key !== 'Payload too large',
          category: ErrorCategory.STORAGE,
          raw,
        };
      }
    }

    // Network patterns
    for (const p of NETWORK_PATTERNS) {
      if (p.pattern.test(message)) {
        const isNetworkDown = /failed to fetch|networkerror|network request failed/i.test(message);
        return {
          title: p.title,
          message: p.message,
          retryable: true,
          category: isNetworkDown ? ErrorCategory.NETWORK : ErrorCategory.SERVER,
          raw,
        };
      }
    }

    // Auth-related message strings
    if (lowerMsg.includes('not authenticated') || lowerMsg.includes('session expired') || lowerMsg.includes('not logged in')) {
      return {
        title: 'Session expired',
        message: 'Your session has expired. Please log in again.',
        retryable: false,
        action: 'Log in',
        category: ErrorCategory.AUTH,
        raw,
      };
    }
    if (lowerMsg.includes('insufficient balance') || lowerMsg.includes('not enough balance')) {
      return {
        title: 'Insufficient balance',
        message: ERROR_MESSAGES.wallet.insufficientBalance,
        retryable: false,
        action: 'Top up wallet',
        category: ErrorCategory.PAYMENT,
        raw,
      };
    }
    if (lowerMsg.includes('permission') || lowerMsg.includes('forbidden') || lowerMsg.includes('access denied')) {
      return {
        title: 'Permission denied',
        message: 'You don\'t have permission to perform this action.',
        retryable: false,
        category: ErrorCategory.PERMISSION,
        raw,
      };
    }
    if (lowerMsg.includes('rate limit') || lowerMsg.includes('too many')) {
      return {
        title: 'Too many attempts',
        message: 'You\'ve made too many requests. Please wait a moment and try again.',
        retryable: true,
        category: ErrorCategory.RATE_LIMIT,
        raw,
      };
    }
    if (lowerMsg.includes('file') && (lowerMsg.includes('large') || lowerMsg.includes('size'))) {
      return {
        title: 'File too large',
        message: ERROR_MESSAGES.upload.tooLarge,
        retryable: false,
        category: ErrorCategory.STORAGE,
        raw,
      };
    }
  }

  // ── Fallback ──
  return {
    title: 'Something went wrong',
    message: context
      ? `Unable to ${context.toLowerCase()}. Please try again.`
      : ERROR_MESSAGES.system.unknown,
    retryable: true,
    category: ErrorCategory.UNKNOWN,
    raw,
  };
}

// ─── Helper: get just the user message string ────────────────────────────────

/**
 * Quick helper — returns just the user-facing message string for use in toasts etc.
 */
export function getErrorMessage(error: unknown, fallback?: string): string {
  const classified = classifyError(error);
  return classified.message || fallback || ERROR_MESSAGES.system.unknown;
}

/**
 * Logs the error to console in dev, silently in production.
 */
export function logError(error: unknown, context?: string): void {
  if (import.meta.env.DEV) {
    console.error(`[AppError]${context ? ` [${context}]` : ''}`, error);
  }
}
