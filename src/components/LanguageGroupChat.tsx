import { useState, useEffect, useRef, useCallback } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Users,
  Send,
  Paperclip,
  Image,
  FileText,
  File,
  X,
  Download,
  Circle,
  MessageCircle,
  Mic,
  StopCircle,
} from "lucide-react";
import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { toast as sonnerToast } from "sonner";
import { cn } from "@/lib/utils";
import { formatDistanceToNow } from "date-fns";
import { VoiceMessagePlayer } from "@/components/VoiceMessagePlayer";

interface CommunityMessage {
  id: string;
  senderId: string;
  senderName: string;
  senderPhoto: string | null;
  message: string | null;
  fileUrl: string | null;
  fileType: string | null;
  fileName: string | null;
  fileSize: number | null;
  createdAt: string;
  isOwn: boolean;
}

interface CommunityMember {
  userId: string;
  fullName: string;
  photoUrl: string | null;
  isOnline: boolean;
}

interface LanguageGroupChatProps {
  currentUserId: string;
  languageCode: string;
  languageName: string;
  userName: string;
  userPhoto: string | null;
}

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB
const ALLOWED_FILE_TYPES = [
  "image/jpeg", "image/png", "image/gif", "image/webp", "image/avif",
  "image/heic", "image/heif", "image/bmp", "image/tiff", "image/svg+xml",
  "video/mp4", "video/webm", "video/quicktime", "video/x-msvideo", "video/x-matroska", "video/3gpp",
  "audio/mpeg", "audio/wav", "audio/ogg", "audio/mp4", "audio/webm", "audio/x-m4a",
  "application/pdf", "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "text/plain", "text/csv", "application/rtf", "application/zip",
  "application/octet-stream"
];

export const LanguageGroupChat = ({
  currentUserId,
  languageCode,
  languageName,
  userName,
  userPhoto
}: LanguageGroupChatProps) => {
  const { toast } = useToast();
  const [messages, setMessages] = useState<CommunityMessage[]>([]);
  const [members, setMembers] = useState<CommunityMember[]>([]);
  const [newMessage, setNewMessage] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [showMembers, setShowMembers] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const profileCacheRef = useRef<Map<string, { name: string; photo: string | null }>>(new Map());
  const [recording, setRecording] = useState(false);
  const [recordSecs, setRecordSecs] = useState(0);
  const recRef = useRef<MediaRecorder | null>(null);
  const recChunks = useRef<Blob[]>([]);
  const recTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const recMimeRef = useRef<{ mimeType: string; ext: string }>({ mimeType: "audio/webm", ext: "webm" });
  const recStreamRef = useRef<MediaStream | null>(null);
  const stoppingRef = useRef(false);
  const recordSecsRef = useRef(0);

  // Load messages and members
  useEffect(() => {
    if (languageName) {
      loadCommunityData();
      const cleanup = subscribeToMessages();
      return cleanup;
    }
  }, [languageName, currentUserId]);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const loadCommunityData = async () => {
    setIsLoading(true);
    try {
      await Promise.all([loadMessages(), loadMembers()]);
    } finally {
      setIsLoading(false);
    }
  };

  const loadMessages = async () => {
    try {
      const { data: messagesData, error } = await supabase
        .from("language_community_messages")
        .select("*")
        .eq("language_code", languageName)
        .order("created_at", { ascending: true })
        .limit(50);

      if (error) throw error;

      if (messagesData && messagesData.length > 0) {
        const senderIds = [...new Set(messagesData.map(m => m.sender_id))];
        
        const { fetchPublicProfiles } = await import("@/lib/profile-queries");
        const profiles = await fetchPublicProfiles(senderIds as string[]);

        const profileMap = new Map((profiles as any[] || []).map(p => [p.user_id, p]));
        
        profileMap.forEach((p, id) => {
          profileCacheRef.current.set(id, { name: p.full_name || "Unknown", photo: p.photo_url || null });
        });

        const mappedMessages: CommunityMessage[] = messagesData.map(m => ({
          id: m.id,
          senderId: m.sender_id,
          senderName: profileMap.get(m.sender_id)?.full_name || "Unknown",
          senderPhoto: profileMap.get(m.sender_id)?.photo_url || null,
          message: m.message,
          fileUrl: m.file_url,
          fileType: m.file_type,
          fileName: m.file_name,
          fileSize: m.file_size,
          createdAt: m.created_at,
          isOwn: m.sender_id === currentUserId
        }));

        setMessages(mappedMessages);
      }
    } catch (error) {
      console.error("Error loading messages:", error);
      toast({ title: "Messages unavailable", description: ERROR_MESSAGES.chat.loadFailed, variant: "destructive" });
    }
  };

  const loadMembers = async () => {
    try {
      const { data: languageUsers } = await supabase
        .from("user_languages")
        .select("user_id")
        .eq("language_name", languageName);

      const { fetchPublicProfiles: fetchProfiles } = await import("@/lib/profile-queries");
      const allLanguageProfiles = await fetchProfiles(
        (languageUsers?.map(u => u.user_id) || []) as string[]
      );
      const profilesByLanguage = allLanguageProfiles.filter(
        p => p.gender === "female" && 
        (p.primary_language === languageName || p.preferred_language === languageName)
      );

      const userIds = [...new Set([
        ...(languageUsers?.map(u => u.user_id) || []),
        ...profilesByLanguage.map(p => p.user_id)
      ])];

      if (userIds.length > 0) {
        const [profilesData, statusRes] = await Promise.all([
          fetchProfiles(userIds as string[]),
          supabase.from("user_status")
            .select("user_id, is_online")
            .in("user_id", userIds)
        ]);

        const statusMap = new Map(statusRes.data?.map(s => [s.user_id, s.is_online]) || []);

        setMembers(profilesData.filter(p => p.gender === "female").map(p => ({
          userId: p.user_id,
          fullName: p.full_name || "Unknown",
          photoUrl: p.photo_url,
          isOnline: (statusMap.get(p.user_id) as boolean) || false
        })));
      }
    } catch (error) {
      console.error("Error loading members:", error);
      toast({ title: "Members unavailable", description: "Unable to load group members. Please refresh.", variant: "destructive" });
    }
  };

  const subscribeToMessages = () => {
    const channel = supabase
      .channel(`community-${languageName}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "language_community_messages",
          filter: `language_code=eq.${languageName}`
        },
        async (payload) => {
          const newMsg = payload.new as any;
          
          let senderName = "Unknown";
          let senderPhoto: string | null = null;
          const cached = profileCacheRef.current.get(newMsg.sender_id);
          if (cached) {
            senderName = cached.name;
            senderPhoto = cached.photo;
          } else {
            const { data: profile } = await supabase
              .from("profiles")
              .select("full_name, photo_url")
              .eq("user_id", newMsg.sender_id)
              .maybeSingle();
            senderName = profile?.full_name || "Unknown";
            senderPhoto = profile?.photo_url || null;
            profileCacheRef.current.set(newMsg.sender_id, { name: senderName, photo: senderPhoto });
          }

          const message: CommunityMessage = {
            id: newMsg.id,
            senderId: newMsg.sender_id,
            senderName,
            senderPhoto,
            message: newMsg.message,
            fileUrl: newMsg.file_url,
            fileType: newMsg.file_type,
            fileName: newMsg.file_name,
            fileSize: newMsg.file_size,
            createdAt: newMsg.created_at,
            isOwn: newMsg.sender_id === currentUserId
          };

          setMessages(prev => prev.some(m => m.id === message.id) ? prev : [...prev, message]);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const handleSendMessage = async (fileOverride?: File | null) => {
    const fileToSend = fileOverride ?? selectedFile;
    if (isSending) return;
    if (!newMessage.trim() && !fileToSend) {
      toast({ title: "Nothing to send", description: "Type a message or attach a voice note first.", variant: "destructive" });
      return;
    }

    if (newMessage.trim()) {
      const { moderateMessage } = await import('@/lib/content-moderation');
      const moderationResult = moderateMessage(newMessage.trim());
      if (moderationResult.isBlocked) {
        toast({
          title: "Error",
          description: moderationResult.reason || "This message contains prohibited content.",
          variant: "destructive"
        });
        return;
      }
    }

    setIsSending(true);
    try {
      let fileUrl = null;
      let fileType = null;
      let fileName = null;
      let fileSize = null;

      if (fileToSend) {
        setIsUploading(true);
        const fileExt = fileToSend.name.split(".").pop();
        const filePath = `${languageName}/${currentUserId}/${crypto.randomUUID()}.${fileExt}`;

        const mimeMap: Record<string, string> = {
          jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif",
          webp: "image/webp", heic: "image/heic", heif: "image/heif", bmp: "image/bmp",
          mp4: "video/mp4", mov: "video/quicktime",
          mp3: "audio/mpeg", wav: "audio/wav", m4a: "audio/mp4", webm: "audio/webm", ogg: "audio/ogg",
          pdf: "application/pdf", doc: "application/msword",
          docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          xls: "application/vnd.ms-excel", xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          ppt: "application/vnd.ms-powerpoint", pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
          txt: "text/plain", csv: "text/csv", zip: "application/zip",
        };
        const extLower = (fileExt || "").toLowerCase();
        const isVoice = fileToSend.name.startsWith("voice-") || (fileToSend.type || "").startsWith("audio/");
        const contentType = isVoice
          ? "application/octet-stream"
          : (fileToSend.type || mimeMap[extLower] || "application/octet-stream");

        let { error: uploadError } = await supabase.storage
          .from("community-files")
          .upload(filePath, fileToSend, { contentType, upsert: false });

        if (uploadError) {
          const fallback = await supabase.storage
            .from("community-files")
            .upload(filePath, fileToSend, { contentType: "application/octet-stream", upsert: false });
          uploadError = fallback.error;
        }

        if (uploadError) throw uploadError;

        const { data: urlData } = supabase.storage
          .from("community-files")
          .getPublicUrl(filePath);

        fileUrl = urlData.publicUrl;
        fileType = isVoice ? (fileToSend.type || "audio/webm") : fileToSend.type;
        fileName = fileToSend.name;
        fileSize = fileToSend.size;
        setIsUploading(false);
      }

      const { data: inserted, error } = await supabase
        .from("language_community_messages")
        .insert({
          language_code: languageName,
          sender_id: currentUserId,
          message: newMessage.trim() || null,
          file_url: fileUrl,
          file_type: fileType,
          file_name: fileName,
          file_size: fileSize
        })
        .select("id, sender_id, message, file_url, file_type, file_name, file_size, created_at")
        .single();

      if (error) throw error;

      if (inserted) {
        const local: CommunityMessage = {
          id: inserted.id,
          senderId: inserted.sender_id,
          senderName: userName || "You",
          senderPhoto: userPhoto,
          message: inserted.message,
          fileUrl: inserted.file_url,
          fileType: inserted.file_type,
          fileName: inserted.file_name,
          fileSize: inserted.file_size,
          createdAt: inserted.created_at,
          isOwn: true,
        };
        setMessages(prev => prev.some(m => m.id === local.id) ? prev : [...prev, local]);
      }

      setNewMessage("");
      setSelectedFile(null);
    } catch (error: any) {
      console.error("Error sending message:", error);
      toast({
        title: "Error",
        description: classifyError(error, "send message").message,
        variant: "destructive"
      });
    } finally {
      setIsSending(false);
      setIsUploading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > MAX_FILE_SIZE) {
      toast({
        title: "File Too Large",
        description: "Maximum file size is 50MB",
        variant: "destructive"
      });
      return;
    }

    const ext = file.name.split(".").pop()?.toLowerCase() || "";
    const knownExts = ["jpg","jpeg","png","gif","webp","heic","heif","bmp","tiff","avif","svg",
                        "mp4","webm","mov","avi","mkv","3gp","mp3","wav","ogg","m4a",
                        "pdf","doc","docx","xls","xlsx","ppt","pptx","txt","csv","rtf","zip","rar"];
    const isAllowed = ALLOWED_FILE_TYPES.includes(file.type) || file.type.startsWith("image/") || file.type.startsWith("video/") || file.type.startsWith("audio/") || knownExts.includes(ext);
    if (!isAllowed) {
      toast({
        title: "Invalid File Type",
        description: "Allowed: Images, Videos, Audio, PDFs, Word, Excel, PowerPoint",
        variant: "destructive"
      });
      return;
    }

    setSelectedFile(file);
  };

  const startRecording = async () => {
    if (recording || isSending || stoppingRef.current) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true },
      });
      recStreamRef.current = stream;
      recChunks.current = [];

      const candidates: [string, string][] = [
        ["audio/webm;codecs=opus", "webm"],
        ["audio/webm", "webm"],
        ["audio/mp4", "m4a"],
        ["audio/ogg;codecs=opus", "ogg"],
      ];
      const picked = candidates.find(([mime]) =>
        typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(mime)
      ) || ["", "webm"] as [string, string];
      recMimeRef.current = { mimeType: picked[0], ext: picked[1] };

      const mr = recMimeRef.current.mimeType
        ? new MediaRecorder(stream, { mimeType: recMimeRef.current.mimeType })
        : new MediaRecorder(stream);
      mr.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) recChunks.current.push(e.data);
      };
      try {
        mr.start(250);
      } catch {
        mr.start();
      }
      recRef.current = mr;
      stoppingRef.current = false;
      recordSecsRef.current = 0;
      setRecordSecs(0);
      setRecording(true);
      recTimer.current = setInterval(() => {
        recordSecsRef.current += 1;
        setRecordSecs(recordSecsRef.current);
      }, 1000);
    } catch (e: any) {
      recStreamRef.current?.getTracks().forEach((t) => t.stop());
      recStreamRef.current = null;
      sonnerToast.error("Mic error", { description: e?.message ?? "Cannot access microphone" });
    }
  };

  const sendCommunityVoice = async (blob: Blob, ext: string, mimeType: string) => {
    const id = crypto.randomUUID();
    const fileName = `voice-${id.slice(0, 8)}.${ext}`;
    const audioType = mimeType || blob.type || "audio/webm";
    const buckets: Array<{ id: string; path: string }> = [
      { id: "community-files", path: `${languageName}/${currentUserId}/${id}.${ext}` },
      { id: "chat-attachments", path: `${currentUserId}/community/${id}.${ext}` },
      { id: "meowmeow-app-attachment", path: `meowmeow/app/attachment/${currentUserId}/community/${fileName}` },
    ];

    let fileUrl: string | null = null;
    let lastError = "Upload failed";

    for (const bucket of buckets) {
      try {
        const raced = await Promise.race([
          supabase.storage.from(bucket.id).upload(bucket.path, blob, {
            contentType: "application/octet-stream",
            upsert: false,
          }),
          new Promise<{ data: null; error: { message: string } }>((resolve) =>
            setTimeout(() => resolve({ data: null, error: { message: `${bucket.id} timed out` } }), 10000)
          ),
        ]);
        if (raced.error) {
          lastError = raced.error.message;
          continue;
        }
        if (bucket.id === "community-files") {
          fileUrl = supabase.storage.from(bucket.id).getPublicUrl(bucket.path).data.publicUrl;
        } else {
          const signed = await supabase.storage.from(bucket.id).createSignedUrl(bucket.path, 60 * 60 * 24 * 365);
          fileUrl = signed.data?.signedUrl || null;
        }
        if (fileUrl) break;
      } catch (e: any) {
        lastError = e?.message || lastError;
      }
    }

    if (!fileUrl) {
      throw new Error(lastError);
    }

    const { data: inserted, error } = await supabase
      .from("language_community_messages")
      .insert({
        language_code: languageName,
        sender_id: currentUserId,
        message: null,
        file_url: fileUrl,
        file_type: audioType.startsWith("audio/") ? audioType : "audio/webm",
        file_name: fileName,
        file_size: blob.size,
      })
      .select("id, sender_id, message, file_url, file_type, file_name, file_size, created_at")
      .single();

    if (error) throw error;
    if (!inserted) throw new Error("Voice note was not saved");

    const local: CommunityMessage = {
      id: inserted.id,
      senderId: inserted.sender_id,
      senderName: userName || "You",
      senderPhoto: userPhoto,
      message: inserted.message,
      fileUrl: inserted.file_url,
      fileType: inserted.file_type,
      fileName: inserted.file_name,
      fileSize: inserted.file_size,
      createdAt: inserted.created_at,
      isOwn: true,
    };
    setMessages((prev) => (prev.some((m) => m.id === local.id) ? prev : [...prev, local]));
  };

  const stopRecording = async () => {
    if (stoppingRef.current) return;
    stoppingRef.current = true;
    if (recTimer.current) {
      clearInterval(recTimer.current);
      recTimer.current = null;
    }
    const recorder = recRef.current;
    recRef.current = null;
    const recordedSecs = recordSecsRef.current;

    if (recorder && recorder.state !== "inactive") {
      await new Promise<void>((resolve) => {
        let settled = false;
        const finish = () => {
          if (settled) return;
          settled = true;
          recStreamRef.current?.getTracks().forEach((t) => t.stop());
          recStreamRef.current = null;
          resolve();
        };
        recorder.addEventListener("stop", finish, { once: true });
        recorder.addEventListener("error", finish, { once: true });
        try {
          if (recorder.state === "recording") recorder.requestData();
        } catch {
          /* ignore */
        }
        try {
          if (recorder.state !== "inactive") recorder.stop();
          else finish();
        } catch {
          finish();
        }
        window.setTimeout(finish, 800);
      });
    } else {
      recStreamRef.current?.getTracks().forEach((t) => t.stop());
      recStreamRef.current = null;
    }

    setRecording(false);
    setRecordSecs(0);

    const mimeType = (
      recMimeRef.current.mimeType.split(";")[0] ||
      recorder?.mimeType ||
      "audio/webm"
    ).split(";")[0];
    const ext =
      recMimeRef.current.ext ||
      (mimeType.includes("mp4") ? "m4a" : mimeType.includes("ogg") ? "ogg" : "webm");
    const blob = new Blob(recChunks.current, { type: mimeType || "audio/webm" });
    recChunks.current = [];

    if (blob.size < 50 && recordedSecs < 1) {
      stoppingRef.current = false;
      sonnerToast.error("Recording too short", { description: "Speak for a second or two, then tap send." });
      return;
    }
    if (blob.size < 50) {
      stoppingRef.current = false;
      sonnerToast.error("Voice not captured", { description: "This browser did not save audio. Try Chrome, or allow the microphone." });
      return;
    }

    setIsSending(true);
    setIsUploading(true);
    try {
      await sendCommunityVoice(blob, ext, mimeType);
    } catch (err: any) {
      console.error("[Community voice] send failed:", err);
      sonnerToast.error("Voice not sent", {
        description: classifyError(err, "send the voice note").message,
      });
    } finally {
      setIsSending(false);
      setIsUploading(false);
      stoppingRef.current = false;
    }
  };

  const getFileIcon = (fileType: string | null) => {
    if (!fileType) return <File className="w-5 h-5" />;
    if (fileType.startsWith("image/")) return <Image className="w-5 h-5" />;
    if (fileType.startsWith("video/")) return <Image className="w-5 h-5 text-purple-500" />;
    if (fileType.startsWith("audio/")) return <File className="w-5 h-5 text-pink-500" />;
    if (fileType.includes("pdf")) return <FileText className="w-5 h-5 text-red-500" />;
    if (fileType.includes("word") || fileType.includes("document")) 
      return <FileText className="w-5 h-5 text-blue-500" />;
    if (fileType.includes("sheet") || fileType.includes("excel"))
      return <FileText className="w-5 h-5 text-green-500" />;
    if (fileType.includes("presentation") || fileType.includes("powerpoint"))
      return <FileText className="w-5 h-5 text-orange-500" />;
    return <File className="w-5 h-5" />;
  };

  const formatFileSize = (bytes: number | null) => {
    if (!bytes) return "";
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const onlineCount = members.filter(m => m.isOnline).length;

  if (isLoading) {
    return (
      <Card className="h-full min-h-0 flex flex-col overflow-hidden">
        <CardHeader className="pb-3">
          <Skeleton className="h-6 w-48" />
        </CardHeader>
        <CardContent className="space-y-3">
          {[1, 2, 3, 4, 5].map(i => (
            <div key={i} className="flex gap-3">
              <Skeleton className="w-10 h-10 rounded-full" />
              <div className="flex-1 space-y-2">
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-12 w-3/4" />
              </div>
            </div>
          ))}
        </CardContent>
      </Card>
    );
  }

  return (
      <Card className="h-full min-h-0 flex flex-col overflow-hidden">
      {/* Header */}
      <CardHeader className="pb-3 border-b">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
              <MessageCircle className="w-5 h-5 text-primary" />
            </div>
            <div>
              <CardTitle className="text-lg">
                {languageName} Women Community
              </CardTitle>
              <p className="text-sm text-muted-foreground">
                {members.length} members · {onlineCount} online
              </p>
            </div>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowMembers(!showMembers)}
            className="gap-2"
          >
            <Users className="w-4 h-4" />
            {showMembers ? "Hide" : "Members"}
          </Button>
        </div>
      </CardHeader>

      <div className="flex-1 flex overflow-hidden">
        {/* Messages Area */}
        <div className={cn("flex-1 flex flex-col", showMembers && "md:w-2/3")}>
          <ScrollArea className="flex-1 p-4">
            <div className="space-y-4">
              {messages.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                  <MessageCircle className="w-12 h-12 mx-auto mb-3 opacity-50" />
                  <p>No messages yet</p>
                  <p className="text-sm">Start the conversation!</p>
                </div>
              ) : (
                messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={cn(
                      "flex gap-3",
                      msg.isOwn && "flex-row-reverse"
                    )}
                  >
                    <Avatar className="w-8 h-8 flex-shrink-0">
                      <AvatarImage src={msg.senderPhoto || undefined} />
                      <AvatarFallback className="text-xs">
                        {msg.senderName.charAt(0)}
                      </AvatarFallback>
                    </Avatar>
                    
                    <div className={cn("max-w-[70%]", msg.isOwn && "text-right")}>
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-sm font-medium">
                          {msg.isOwn ? "You" : msg.senderName}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {formatDistanceToNow(new Date(msg.createdAt), { addSuffix: true })}
                        </span>
                      </div>
                      
                      <div
                        className={cn(
                          "rounded-lg p-3",
                          msg.isOwn 
                            ? "bg-primary text-primary-foreground" 
                            : "bg-muted"
                        )}
                      >
                        {/* File attachment */}
                        {msg.fileUrl && (
                          <div className="mb-2">
                            {msg.fileType?.startsWith("image/") ? (
                              <a href={msg.fileUrl} target="_blank" rel="noopener noreferrer">
                                <img
                                  src={msg.fileUrl}
                                  alt={msg.fileName || "Image"}
                                  className="max-w-full max-h-48 rounded-md object-cover"
                                />
                              </a>
                            ) : (msg.fileType?.startsWith("audio/") || msg.fileName?.startsWith("voice-")) ? (
                              <VoiceMessagePlayer audioUrl={msg.fileUrl} isMine={msg.isOwn} />
                            ) : (
                              <a
                                href={msg.fileUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className={cn(
                                  "flex items-center gap-2 p-2 rounded-md",
                                  msg.isOwn ? "bg-primary-foreground/10" : "bg-background"
                                )}
                              >
                                {getFileIcon(msg.fileType)}
                                <div className="flex-1 min-w-0">
                                  <p className="text-sm font-medium truncate">
                                    {msg.fileName}
                                  </p>
                                  <p className="text-xs opacity-70">
                                    {formatFileSize(msg.fileSize)}
                                  </p>
                                </div>
                                <Download className="w-4 h-4" />
                              </a>
                            )}
                          </div>
                        )}
                        
                        {/* Message text */}
                        {msg.message && (
                          <p className="text-sm whitespace-pre-wrap break-words">
                            {msg.message}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                ))
              )}
              <div ref={messagesEndRef} />
            </div>
          </ScrollArea>

          {/* Selected file preview */}
          {selectedFile && (
            <div className="px-4 py-2 border-t bg-muted/50">
              <div className="flex items-center gap-2">
                {getFileIcon(selectedFile.type)}
                <span className="text-sm flex-1 truncate">{selectedFile.name}</span>
                <span className="text-xs text-muted-foreground">
                  {formatFileSize(selectedFile.size)}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-6 w-6"
                  onClick={() => setSelectedFile(null)}
                >
                  <X className="w-4 h-4" />
                </Button>
              </div>
            </div>
          )}

          {/* Input area */}
          <div className="p-4 border-t">
            <div className="flex items-center gap-2">
              <input
                type="file"
                ref={fileInputRef}
                className="hidden"
                onChange={handleFileSelect}
                accept={ALLOWED_FILE_TYPES.join(",")}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                onClick={() => fileInputRef.current?.click()}
                disabled={isSending || recording}
              >
                <Paperclip className="w-5 h-5" />
              </Button>

              {recording ? (
                <Button type="button" variant="destructive" size="icon" onClick={stopRecording} disabled={isSending}>
                  <StopCircle className="w-5 h-5" />
                </Button>
              ) : (
                <Button type="button" variant="ghost" size="icon" onClick={startRecording} disabled={isSending}>
                  <Mic className="w-5 h-5" />
                </Button>
              )}
              
              <Input
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && !recording && handleSendMessage()}
                placeholder={recording ? `Recording ${recordSecs}s… tap send` : "Type a message..."}
                disabled={isSending || recording}
                className="flex-1"
              />
              
              <Button
                type="button"
                onClick={() => (recording ? void stopRecording() : void handleSendMessage())}
                disabled={isSending || (!recording && !newMessage.trim() && !selectedFile)}
                size="icon"
              >
                {isUploading ? (
                  <div className="w-5 h-5 border-2 border-current border-t-transparent rounded-full animate-spin" />
                ) : (
                  <Send className="w-5 h-5" />
                )}
              </Button>
            </div>
          </div>
        </div>

        {/* Members sidebar */}
        {showMembers && (
          <div className="hidden md:block w-1/3 border-l">
            <div className="p-3 border-b">
              <h3 className="font-medium">Members</h3>
            </div>
            <ScrollArea className="h-[calc(100%-48px)]">
              <div className="p-2 space-y-1">
                {members.map((member) => (
                  <div
                    key={member.userId}
                    className="flex items-center gap-3 p-2 rounded-md hover:bg-muted"
                  >
                    <div className="relative">
                      <Avatar className="w-8 h-8">
                        <AvatarImage src={member.photoUrl || undefined} />
                        <AvatarFallback className="text-xs">
                          {member.fullName.charAt(0)}
                        </AvatarFallback>
                      </Avatar>
                      {member.isOnline && (
                        <Circle className="absolute -bottom-0.5 -right-0.5 w-3 h-3 fill-green-500 text-green-500" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{member.fullName}</p>
                      <p className="text-xs text-muted-foreground">
                        {member.isOnline ? "Online" : "Offline"}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </ScrollArea>
          </div>
        )}
      </div>
    </Card>
  );
};

export default LanguageGroupChat;
