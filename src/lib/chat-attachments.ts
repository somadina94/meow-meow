/** Strip one or more chat-attachment:// prefixes and return a single canonical URL. */
export function normalizeChatAttachmentUrl(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let path = raw.trim();
  while (path.startsWith("chat-attachment://")) {
    path = path.slice("chat-attachment://".length);
  }
  if (!path) return null;
  if (path.startsWith("http://") || path.startsWith("https://")) return path;
  return `chat-attachment://${path}`;
}

export function extractVoiceUrl(message: string): string | null {
  const match = message.match(/\[VOICE:\s*(.*?)\]/i) || message.match(/🎤\s*voice:\s*(.+)/i);
  if (!match) return null;
  return normalizeChatAttachmentUrl(match[1].trim());
}

export function storagePathFromAttachmentUrl(url: string): string {
  return url.replace(/^(chat-attachment:\/\/)+/, "");
}

/** Voice, images, files, and storage markers. */
export function isMediaChatMessage(message: string | null | undefined): boolean {
  if (!message) return false;
  const text = message.trim();
  if (!text) return false;
  return (
    /\[VOICE:/i.test(text) ||
    /🎤\s*voice:/i.test(text) ||
    /\[attachment:/i.test(text) ||
    /chat-attachment:\/\//i.test(text) ||
    /\[IMAGE:/i.test(text) ||
    /\[VIDEO:/i.test(text) ||
    /\[DOCUMENT:/i.test(text) ||
    text.startsWith("📷") ||
    text.startsWith("🎬") ||
    text.startsWith("📎") ||
    text.startsWith("🎤")
  );
}

/** Voice, images, files, and system rows must never go through translation. */
export function isTranslatableChatText(message: string | null | undefined): boolean {
  if (!message?.trim()) return false;
  return !isMediaChatMessage(message);
}
