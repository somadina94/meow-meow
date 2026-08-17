import { classifyError, ERROR_MESSAGES } from "@/lib/errors";
import { useState, useEffect, useRef, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import {
  Send, X, Maximize2, Minimize2, Clock, IndianRupee, Loader2,
  ChevronDown, ChevronUp, TrendingUp, Wallet, AlertTriangle,
  Move, Paperclip, Image, Video, FileText, Mic, MoreHorizontal
} from "lucide-react";
import {
  Popover, PopoverContent, PopoverTrigger,
} from "@/components/ui/popover";
import { MiniChatActions } from "@/components/MiniChatActions";
import { SendGiftButton } from "@/components/SendGiftButton";
import { useBlockCheck } from "@/hooks/useBlockCheck";
import { useDraggablePosition } from "@/hooks/useDraggablePosition";
import { useResizableWindow } from "@/hooks/useResizableWindow";
import { useMiniChatBilling } from "@/hooks/useMiniChatBilling";
import { useMiniChatMessages } from "@/hooks/useMiniChatMessages";
import { usePartnerMonitor } from "@/hooks/usePartnerMonitor";
import { useChatPresence } from "@/hooks/useChatPresence";
import { PartnerStatusLine } from "@/components/chat/PartnerStatusLine";
import { VoiceRecorder } from "@/components/chat/VoiceRecorder";
import { extractVoiceUrl, storagePathFromAttachmentUrl } from "@/lib/chat-attachments";

interface DraggableMiniChatWindowProps {
  chatId: string;
  sessionId: string;
  partnerId: string;
  partnerName: string;
  partnerPhoto: string | null;
  partnerLanguage: string;
  isPartnerOnline: boolean;
  currentUserId: string;
  currentUserLanguage: string;
  currentUserName?: string;
  userGender: "male" | "female";
  ratePerMinute: number;
  earningRatePerMinute: number;
  partnerCountry?: string;
  onClose: () => void;
  initialPosition?: { x: number; y: number };
  zIndex?: number;
  onFocus?: () => void;
}

const DraggableMiniChatWindow = ({
  chatId,
  sessionId,
  partnerId,
  partnerName,
  partnerPhoto,
  partnerLanguage,
  isPartnerOnline,
  currentUserId,
  currentUserLanguage,
  currentUserName,
  userGender,
  ratePerMinute,
  earningRatePerMinute,
  partnerCountry,
  onClose,
  initialPosition = { x: 20, y: 20 },
  zIndex = 50,
  onFocus
}: DraggableMiniChatWindowProps) => {
  const { toast } = useToast();
  const [isMinimized, setIsMinimized] = useState(false);
  const [isMaximized, setIsMaximized] = useState(false);
  const [areButtonsExpanded, setAreButtonsExpanded] = useState(false);
  const [newMessage, setNewMessage] = useState("");
  const [isAttachOpen, setIsAttachOpen] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [isEarningEligible, setIsEarningEligible] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const windowRef = useRef<HTMLDivElement>(null);
  const sessionStartedRef = useRef(false);
  const sendingRef = useRef(false);
  const MAX_MESSAGE_LENGTH = 10000;

  const { isBlocked, isBlockedByThem } = useBlockCheck(currentUserId, partnerId);

  const { position, setPosition, isDragging, handleDragStart } = useDraggablePosition({
    initialPosition,
    size: { width: 320, height: 400 },
    isMaximized,
    isMinimized,
    onFocus,
  });

  const { size, isResizing, handleResizeStart } = useResizableWindow({
    position,
    setPosition,
  });

  const { messages, setMessages, unreadCount, setUnreadCount, messagesEndRef, hasOlderMessages, isLoadingOlder, loadOlderMessages, addSeenId } =
    useMiniChatMessages({ chatId, currentUserId, isMinimized, currentUserLanguage, partnerLanguage: partnerLanguage });

  const manId = userGender === "male" ? currentUserId : partnerId;
  const womanId = userGender === "female" ? currentUserId : partnerId;
  const isBillingDriver = userGender === "male" && currentUserId === manId;
  const billingHook = useMiniChatBilling({
    chatId,
    sessionId,
    manId,
    womanId,
    isActive: isBillingDriver && !!sessionId && !!chatId,
    activitySignal: messages.length ? `${messages.length}:${messages[messages.length - 1]?.createdAt}` : messages.length,
    onInsufficientBalance: () => {
      toast({ title: "Chat ended", description: "Insufficient balance to continue.", variant: "destructive" });
      onClose();
    },
  });

  const billing = {
    elapsedSeconds: billingHook.elapsedSeconds,
    billingStarted: billingHook.isBilling,
    setWalletBalance: (_v: number) => {},
    setTodayEarnings: (_v: number) => {},
    setLastActivityTime: (_v: number) => {},
    stopBillingTimers: billingHook.stopBillingTimers,
  };

  usePartnerMonitor({
    partnerId,
    partnerName,
    sessionId,
    isPartnerOnline,
    onClose,
  });

  const { partnerState, partnerLastSeen, sendTyping } = useChatPresence({
    chatId,
    currentUserId,
    partnerId,
    isWindowActive: !isMinimized && (typeof document === "undefined" || !document.hidden),
  });

  const [currentUserPhoto, setCurrentUserPhoto] = useState<string | null>(null);
  const [currentUserFullName, setCurrentUserFullName] = useState<string>(currentUserName || "Me");

  useEffect(() => {
    (async () => {
      try {
        const { data: profile } = await supabase
          .from("profiles")
          .select("full_name, photo_url, country")
          .eq("user_id", currentUserId)
          .maybeSingle();
        if (profile) {
          if (profile.photo_url) setCurrentUserPhoto(profile.photo_url);
          if (profile.full_name) setCurrentUserFullName(profile.full_name);
          if (profile.country) {
            const country = profile.country.toLowerCase().trim();
            setIsEarningEligible(["india", "in", "ind", "भारत"].includes(country));
          }
        }
      } catch (error) {
        console.error("Error loading profile:", error);
      }
    })();
  }, [currentUserId]);

  useEffect(() => {
    if (isBlocked) {
      toast({
        title: "Chat Ended",
        description: isBlockedByThem ? "This user has blocked you" : "You have blocked this user",
        variant: "destructive",
      });
      handleClose();
    }
  }, [isBlocked]);

  const prevPartnerStateRef = useRef(partnerState);

  // In-thread join/leave notices (status line in the header still updates live)
  useEffect(() => {
    const prev = prevPartnerStateRef.current;
    if (prev === partnerState) return;
    prevPartnerStateRef.current = partnerState;

    const pushSystem = (text: string) => {
      setMessages((msgs) => [
        ...msgs,
        {
          id: `sys-${Date.now()}`,
          ownerId: "system",
          message: text,
          createdAt: new Date().toISOString(),
          isSystem: true,
        },
      ]);
    };

    if (partnerState === "in_chat" && prev && prev !== "typing" && prev !== "in_chat") {
      pushSystem(`${partnerName} joined the chat`);
    } else if (partnerState === "left_chat" && prev && prev !== "left_chat") {
      pushSystem(`${partnerName} left the chat`);
    }
  }, [partnerState, partnerName, setMessages]);

  const handleKeyPress = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  };

  const toggleMinimize = () => {
    setIsMinimized(!isMinimized);
    if (isMinimized) setUnreadCount(0);
  };

  const toggleMaximize = () => {
    setIsMaximized(!isMaximized);
    if (!isMaximized) setIsMinimized(false);
  };

  const handleClose = async () => {
    await billing.stopBillingTimers();
    try {
      await supabase.from("active_chat_sessions")
        .update({ status: "ended", ended_at: new Date().toISOString(), end_reason: userGender === "male" ? "man_closed" : "woman_closed" })
        .eq("id", sessionId);
    } catch (error) {
      console.error("Error closing chat session:", error);
    }
    onClose();
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, fileType: "image" | "video" | "document") => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 50 * 1024 * 1024) {
      toast({ title: "File too large", description: "Maximum file size is 50MB", variant: "destructive" });
      return;
    }
    setIsUploading(true);
    setIsAttachOpen(false);
    billing.setLastActivityTime(Date.now());

    try {
      const fileExt = file.name.split(".").pop();
      const randomSuffix = crypto.randomUUID().slice(0, 8);
      const fileName = `meowmeow/app/attachment/${currentUserId}/${chatId}/${Date.now()}-${randomSuffix}.${fileExt}`;
      const bucket = "meowmeow-app-attachment";

      const mimeMap: Record<string, string> = {
        jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif",
        webp: "image/webp", heic: "image/heic", heif: "image/heif", bmp: "image/bmp",
        mp4: "video/mp4", webm: "video/webm", mov: "video/quicktime",
        mp3: "audio/mpeg", wav: "audio/wav", m4a: "audio/x-m4a",
        pdf: "application/pdf", doc: "application/msword",
        docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        xls: "application/vnd.ms-excel",
        xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ppt: "application/vnd.ms-powerpoint",
        pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        txt: "text/plain", csv: "text/csv", zip: "application/zip",
      };
      const extLower = (fileExt || "").toLowerCase();
      const contentType = file.type || mimeMap[extLower] || "application/octet-stream";

      const { error: uploadError } = await supabase.storage.from(bucket).upload(fileName, file, { cacheControl: "3600", upsert: false, contentType });
      if (uploadError) throw uploadError;

      const messageUrl = `chat-attachment://${fileName}`;
      const emoji = fileType === "image" ? "📷" : fileType === "video" ? "🎬" : "📎";
      const messageBody = `${emoji} [${fileType.toUpperCase()}:${messageUrl}] ${file.name}`;
      const { data: inserted, error: messageError } = await supabase
        .from("chat_messages")
        .insert({
          chat_id: chatId, sender_id: currentUserId, receiver_id: partnerId,
          message: messageBody,
        })
        .select("id, sender_id, message, created_at")
        .single();
      if (messageError) throw messageError;
      if (inserted) {
        addSeenId(inserted.id);
        setMessages((prev) =>
          prev.some((m) => m.id === inserted.id)
            ? prev
            : [...prev, { id: inserted.id, ownerId: inserted.sender_id, message: inserted.message, createdAt: inserted.created_at }]
        );
      }
      toast({ title: "File sent", description: `${file.name} has been sent` });
    } catch (error) {
      console.error("Error uploading file:", error);
      const classified = classifyError(error);
      toast({ title: classified.title, description: classified.message, variant: "destructive" });
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const triggerFileInput = (accept: string, fileType: "image" | "video" | "document") => {
    if (fileInputRef.current) {
      fileInputRef.current.accept = accept;
      fileInputRef.current.dataset.fileType = fileType;
      fileInputRef.current.click();
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.ceil(seconds / 60);
    return `${mins} min`;
  };

  const useFlexLayout = initialPosition.x === 0 && initialPosition.y === 0;

  const windowStyle = isMaximized
    ? { position: "fixed" as const, top: 0, left: 0, right: 0, bottom: 0, width: "100%", height: "100%", zIndex: zIndex + 100 }
    : useFlexLayout
      ? { position: "relative" as const, width: isMinimized ? 240 : size.width, height: isMinimized ? 48 : size.height, zIndex }
      : { position: "fixed" as const, left: position.x, top: position.y, width: isMinimized ? 240 : size.width, height: isMinimized ? 48 : size.height, zIndex };

  const sendMessage = async () => {
    const inputText = newMessage.trim();
    if (inputText.length > MAX_MESSAGE_LENGTH) {
      toast({ title: "Message too long", description: `Messages must be under ${MAX_MESSAGE_LENGTH} characters`, variant: "destructive" });
      return;
    }
    const messageTimestamp = new Date().toISOString();
    const tempId = `temp-${Date.now()}`;
    setNewMessage("");
    setMessages((prev) => [...prev, { id: tempId, ownerId: currentUserId, message: inputText, createdAt: messageTimestamp }]);
    try {
      const { data: insertedMessage, error: insertError } = await supabase
        .from("chat_messages")
        .insert({ chat_id: chatId, sender_id: currentUserId, receiver_id: partnerId, message: inputText })
        .select("id, sender_id, message, created_at")
        .single();
      if (insertError) throw insertError;
      if (insertedMessage?.id) {
        addSeenId(insertedMessage.id);
        setMessages((prev) => prev.map((m) => (m.id === tempId ? { ...m, id: insertedMessage.id, ownerId: insertedMessage.sender_id } : m)));
      }
    } catch (dbError) {
      console.error("[sendMessage] DB insert error:", dbError);
      setMessages((prev) => prev.map((m) =>
        m.id === tempId ? { ...m, sendFailed: true } : m
      ));
      toast({ title: "Message Not Sent", description: "Failed to send message", variant: "destructive" });
    }
  };

  return (
    <Card
      ref={windowRef}
      style={windowStyle}
      className={cn(
        "flex flex-col shadow-2xl border-2 transition-all duration-200",
        isPartnerOnline ? "border-primary/30" : "border-muted",
        isDragging && "opacity-90",
        isMaximized && "rounded-none"
      )}
      onClick={onFocus}
    >
      <div
        className={cn(
          "flex items-center justify-between p-2 bg-gradient-to-r from-primary/10 to-transparent border-b touch-none select-none",
          !isMaximized && "cursor-move"
        )}
        onMouseDown={handleDragStart}
        onTouchStart={handleDragStart}
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          {!isMaximized && <Move className="h-3 w-3 text-muted-foreground flex-shrink-0" />}
          <div className="relative">
            <Avatar className="h-7 w-7">
              <AvatarImage src={partnerPhoto || undefined} />
              <AvatarFallback className="text-xs bg-primary/20">{partnerName.charAt(0)}</AvatarFallback>
            </Avatar>
            <div
              className={cn(
                "absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-background",
                partnerState === "in_chat" || partnerState === "typing"
                  ? "bg-primary animate-pulse"
                  : partnerState === "online_away" || isPartnerOnline
                  ? "bg-online"
                  : "bg-muted-foreground"
              )}
              aria-hidden="true"
            />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1">
              <p className="text-xs font-medium truncate">{partnerName}</p>
            </div>
            <PartnerStatusLine
              state={partnerState}
              partnerName={partnerName}
              lastSeen={partnerLastSeen}
              fallbackOnline={isPartnerOnline}
            />
            {billing.billingStarted && (
              <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
                <Clock className="h-2 w-2 text-muted-foreground" />
                <span className="text-muted-foreground">{formatTime(billing.elapsedSeconds)}</span>
              </div>
            )}
          </div>
          {unreadCount > 0 && isMinimized && (
            <Badge className="h-4 min-w-[16px] text-[9px] px-1 bg-primary">{unreadCount}</Badge>
          )}
        </div>
        <div className="flex items-center gap-0.5" data-no-drag onMouseDown={(e) => e.stopPropagation()} onTouchStart={(e) => e.stopPropagation()}>
          <Button variant="ghost" size="icon" className="h-5 w-5" onClick={(e) => { e.stopPropagation(); setAreButtonsExpanded(!areButtonsExpanded); }} title={areButtonsExpanded ? "Hide actions" : "Show actions"}>
            <MoreHorizontal className="h-2.5 w-2.5" />
          </Button>
          {areButtonsExpanded && (
            <>
              {userGender === 'male' && (
                <SendGiftButton
                  senderUserId={currentUserId}
                  recipientUserId={partnerId}
                  context="chat"
                />
              )}
              <MiniChatActions currentUserId={currentUserId} targetUserId={partnerId} targetUserName={partnerName} isPartnerOnline={isPartnerOnline} onBlock={handleClose} onStopChat={handleClose} onLogOff={handleClose} />
              <Button variant="ghost" size="icon" className="h-5 w-5" onClick={toggleMaximize} title={isMaximized ? "Restore size" : "Maximize"}>
                {isMaximized ? <Minimize2 className="h-2.5 w-2.5" /> : <Maximize2 className="h-2.5 w-2.5" />}
              </Button>
            </>
          )}
          <Button variant="ghost" size="icon" className="h-5 w-5" onClick={(e) => { e.stopPropagation(); toggleMinimize(); }}>
            {isMinimized ? <ChevronUp className="h-2.5 w-2.5" /> : <ChevronDown className="h-2.5 w-2.5" />}
          </Button>
          <Button
            variant="ghost" size="icon"
            className="h-5 w-5 hover:bg-destructive/20 hover:text-destructive"
            onClick={(e) => { e.stopPropagation(); e.preventDefault(); handleClose(); }}
            onPointerDown={(e) => e.stopPropagation()}
            onMouseDown={(e) => e.stopPropagation()}
            onTouchStart={(e) => e.stopPropagation()}
          >
            <X className="h-2.5 w-2.5" />
          </Button>
        </div>
      </div>

      {!isMinimized && (
        <>
          <ScrollArea className="flex-1 p-2">
            <div className="space-y-1.5">
              {hasOlderMessages && (
                <button
                  onClick={loadOlderMessages}
                  disabled={isLoadingOlder}
                  className="w-full text-center text-[10px] text-primary hover:underline py-1 disabled:opacity-50"
                >
                  {isLoadingOlder ? "Loading..." : "↑ Load earlier messages"}
                </button>
              )}
              {messages.length === 0 && (
                <p className="text-center text-[10px] text-muted-foreground py-4">Say hi to start chatting.</p>
              )}
              {messages.map((msg) => (
                <MessageBubble
                  key={msg.id}
                  msg={msg}
                  partnerId={partnerId}
                  currentUserId={currentUserId}
                  currentUserName={currentUserFullName}
                  currentUserPhoto={currentUserPhoto}
                  partnerName={partnerName}
                  partnerPhoto={partnerPhoto}
                />
              ))}
              <div ref={messagesEndRef} />
            </div>
          </ScrollArea>

          <div className="border-t">
            <div className="p-2">
              <input type="file" ref={fileInputRef} className="hidden" onChange={(e) => {
                const fileType = fileInputRef.current?.dataset.fileType as "image" | "video" | "document";
                handleFileUpload(e, fileType);
              }} />
              <div className="flex items-center gap-1">
                <Popover open={isAttachOpen} onOpenChange={setIsAttachOpen}>
                  <PopoverTrigger asChild>
                    <Button type="button" variant="ghost" size="icon" className="h-8 w-8 shrink-0" disabled={isUploading}>
                      {isUploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Paperclip className="h-4 w-4" />}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-40 p-1 z-[100] bg-popover border shadow-lg" side="top" align="start">
                    <div className="flex flex-col gap-0.5">
                      <Button variant="ghost" size="sm" className="justify-start h-8 text-xs" onClick={() => triggerFileInput("image/*", "image")}>
                        <Image className="h-4 w-4 mr-2 text-blue-500" />Photo
                      </Button>
                      <Button variant="ghost" size="sm" className="justify-start h-8 text-xs" onClick={() => triggerFileInput("video/*", "video")}>
                        <Video className="h-4 w-4 mr-2 text-purple-500" />Video
                      </Button>
                      <Button variant="ghost" size="sm" className="justify-start h-8 text-xs" onClick={() => triggerFileInput(".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar", "document")}>
                        <FileText className="h-4 w-4 mr-2 text-orange-500" />Document
                      </Button>
                    </div>
                  </PopoverContent>
                </Popover>
                <div className="flex-1">
                  <Input placeholder="Type a message..." value={newMessage} onChange={(e) => { setNewMessage(e.target.value); sendTyping(e.target.value.trim().length > 0); }} onKeyDown={handleKeyPress} onBlur={() => sendTyping(false)} dir="auto" spellCheck={true} autoComplete="off" autoCorrect="on" inputMode="text" enterKeyHint="send" className="h-8 text-xs w-full unicode-text" disabled={isUploading} />
                </div>
                {newMessage.trim() ? (
                  <Button size="icon" className="h-8 w-8 shrink-0 bg-primary hover:bg-primary/90" onClick={sendMessage} disabled={!newMessage.trim()}>
                    <Send className="h-3.5 w-3.5" />
                  </Button>
                ) : (
                  <VoiceRecorder
                    chatId={chatId}
                    currentUserId={currentUserId}
                    receiverId={partnerId}
                    disabled={isUploading}
                    onVoiceSent={(row) => {
                      if (!row) return;
                      // Ensure the message format matches what the UI expects
                      // Based on ChatScreen and VoiceRecorder: "[VOICE:chat-attachment://path]"
                      addSeenId(row.id);
                      setMessages((prev) =>
                        prev.some((m) => m.id === row.id)
                          ? prev
                          : [...prev, { id: row.id, ownerId: row.sender_id, message: row.message, createdAt: row.created_at }]
                      );
                    }}
                    onError={(m) => toast({ title: "Voice failed", description: m, variant: "destructive" })}
                  />
                )}
              </div>
            </div>
          </div>

          {!isMaximized && (
            <>
              <div className="absolute bottom-0 right-0 w-4 h-4 cursor-se-resize flex items-center justify-center touch-none" onMouseDown={(e) => handleResizeStart(e, "se")} onTouchStart={(e) => handleResizeStart(e, "se")}>
                <div className="w-2 h-2 border-b-2 border-r-2 border-muted-foreground/30" />
              </div>
              <div className="absolute bottom-0 left-0 w-4 h-4 cursor-sw-resize touch-none" onMouseDown={(e) => handleResizeStart(e, "sw")} onTouchStart={(e) => handleResizeStart(e, "sw")} />
              <div className="absolute top-0 right-0 w-4 h-4 cursor-ne-resize touch-none" onMouseDown={(e) => handleResizeStart(e, "ne")} onTouchStart={(e) => handleResizeStart(e, "ne")} />
              <div className="absolute top-0 left-0 w-4 h-4 cursor-nw-resize touch-none" onMouseDown={(e) => handleResizeStart(e, "nw")} onTouchStart={(e) => handleResizeStart(e, "nw")} />
            </>
          )}
        </>
      )}
    </Card>
  );
};

interface MessageBubbleProps {
  msg: { id: string; ownerId: string; message: string; createdAt: string; sendFailed?: boolean; isSystem?: boolean; translatedMessage?: string; englishText?: string };
  partnerId: string;
  currentUserId: string;
  currentUserName: string;
  currentUserPhoto: string | null;
  partnerName: string;
  partnerPhoto: string | null;
  onRetry?: (msg: { id: string; ownerId: string; message: string; createdAt: string; sendFailed?: boolean; isSystem?: boolean }) => void;
}

const MessageBubble = ({
  msg,
  currentUserId,
  currentUserName,
  currentUserPhoto,
  partnerName,
  partnerPhoto,
  onRetry,
}: MessageBubbleProps) => {
  const isMine = String(msg.ownerId) === String(currentUserId);
  const displayName = isMine ? (currentUserName || "You") : (partnerName || "User");
  const displayPhoto = isMine ? currentUserPhoto : partnerPhoto;

  const voiceUrl = extractVoiceUrl(msg.message);
  const isImage = msg.message.includes("[IMAGE:");
  const isVideo = msg.message.includes("[VIDEO:");
  const isDocument = msg.message.includes("[DOCUMENT:");

  const extractUrl = (text: string, type: string) => {
    const match = text.match(new RegExp(`\\[${type}:([^\\]]+)\\]`));
    return match ? match[1] : null;
  };

  const rawUrl = voiceUrl
    ? voiceUrl
    : isImage ? extractUrl(msg.message, "IMAGE")
    : isVideo ? extractUrl(msg.message, "VIDEO")
    : isDocument ? extractUrl(msg.message, "DOCUMENT")
    : null;

  const [fileUrl, setFileUrl] = useState<string | null>(null);
  const [fileFailed, setFileFailed] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setFileFailed(false);
    if (!rawUrl) { setFileUrl(null); return; }
    if (!rawUrl.startsWith("chat-attachment://")) { setFileUrl(rawUrl); return; }
    const path = storagePathFromAttachmentUrl(rawUrl);
    const primary = path.startsWith("meowmeow/app/attachment/") ? "meowmeow-app-attachment" : "chat-attachments";
    (async () => {
      let res = await supabase.storage.from(primary).createSignedUrl(path, 3600);
      if ((!res.data?.signedUrl) && primary === "meowmeow-app-attachment") {
        res = await supabase.storage.from("chat-attachments").createSignedUrl(path, 3600);
      }
      if (!cancelled) {
        if (res.data?.signedUrl) setFileUrl(res.data.signedUrl);
        else setFileFailed(true);
      }
    })();
    return () => { cancelled = true; };
  }, [rawUrl]);

  if (msg.isSystem || msg.ownerId === "system") {
    return (
      <div className="flex justify-center my-1">
        <span className="text-[10px] text-muted-foreground bg-muted/60 px-2 py-0.5 rounded-full">
          {msg.message}
        </span>
      </div>
    );
  }

  return (
    <div className={cn("flex gap-2 mb-2", isMine ? "flex-row-reverse" : "flex-row")}>
      <Avatar className="h-6 w-6 mt-0.5 shrink-0">
        <AvatarImage src={displayPhoto || undefined} alt={displayName} />
        <AvatarFallback className="text-[10px] bg-primary/20">
          {(displayName || "U").charAt(0)}
        </AvatarFallback>
      </Avatar>

      <div className={cn("flex flex-col min-w-0", isMine ? "items-end" : "items-start")}>
        <span className={cn(
          "text-[9px] font-semibold mb-0.5 px-1",
          isMine ? "text-primary" : "text-emerald-600 dark:text-emerald-400"
        )}>
          {displayName}
        </span>
        <div
          className={cn(
            "max-w-[85%] px-2.5 py-1.5 rounded-xl text-[11px] border shadow-sm",
            isMine
              ? "bg-primary/5 border-primary/20 rounded-br-sm"
              : "bg-emerald-50 border-emerald-200 dark:bg-emerald-950/20 dark:border-emerald-800 rounded-bl-sm",
            msg.sendFailed && "bg-destructive/10 border-destructive/30 cursor-pointer"
          )}
          onClick={msg.sendFailed && onRetry ? () => onRetry(msg) : undefined}
        >
          {voiceUrl && fileUrl ? (
            <div className="flex items-center gap-2">
              <Mic className="h-3 w-3 shrink-0" />
              <audio src={fileUrl} controls preload="metadata" crossOrigin="anonymous" className="h-8 max-w-[160px]" />
            </div>
          ) : voiceUrl && fileFailed ? (
            <span className="text-[10px] text-destructive">Voice unavailable</span>
          ) : voiceUrl && !fileUrl ? (
            <span className="text-[10px] text-muted-foreground">Loading voice...</span>
          ) : isImage && fileUrl ? (
            <img src={fileUrl} alt="Shared image" className="max-w-[200px] max-h-[150px] rounded object-cover cursor-pointer" onClick={() => window.open(fileUrl, "_blank")} />
          ) : isVideo && fileUrl ? (
            <video src={fileUrl} controls className="max-w-[200px] max-h-[150px] rounded" />
          ) : isDocument && fileUrl ? (
            <a href={fileUrl} target="_blank" rel="noopener noreferrer" className="flex items-center gap-1 underline hover:opacity-80">
              <FileText className="h-3 w-3" /><span>View Document</span>
            </a>
          ) : (
            <>
              <p className={cn(
                "unicode-text leading-relaxed",
                isMine ? "text-primary dark:text-primary" : "text-emerald-800 dark:text-emerald-200"
              )} dir="auto">
                {msg.message}
              </p>
              {!isMine && msg.translatedMessage && msg.translatedMessage.trim().toLowerCase() !== msg.message.trim().toLowerCase() && (
                <p className="text-[9px] text-muted-foreground/70 italic mt-0.5" dir="auto">
                  {msg.translatedMessage}
                </p>
              )}
            </>
          )}
          {msg.sendFailed && (
            <span className="text-[8px] text-destructive block mt-0.5">⚠ Failed — tap to retry</span>
          )}
          <span className="text-[8px] text-muted-foreground/50 block mt-0.5">
            {new Date(msg.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
          </span>
        </div>
      </div>
    </div>
  );
};

export default DraggableMiniChatWindow;
