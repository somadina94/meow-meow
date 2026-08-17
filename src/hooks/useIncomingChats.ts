/**
 * useIncomingChats — DEPRECATED for chat sessions
 * 
 * Chat is now async (WhatsApp-style) — no accept/reject needed.
 * This hook is kept as a no-op for backward compatibility with markChatAsSelfInitiated imports.
 * Video/audio calls still use their own accept/reject flow via useIncomingCalls.
 */

// No-op: kept for backward compatibility with existing imports
export const markChatAsSelfInitiated = (_sessionId?: string, _chatId?: string) => {
  // Chat is now async — no incoming popup to suppress
};

interface UseIncomingChatsResult {
  incomingChats: never[];
  acceptChat: (sessionId: string) => void;
  rejectChat: (sessionId: string, reason?: 'manual' | 'auto_timeout') => Promise<void>;
  clearChat: (sessionId: string) => void;
}

export const useIncomingChats = (
  _currentUserId: string | null,
  _userGender: "male" | "female"
): UseIncomingChatsResult => {
  return {
    incomingChats: [],
    acceptChat: () => {},
    rejectChat: async () => {},
    clearChat: () => {},
  };
};
