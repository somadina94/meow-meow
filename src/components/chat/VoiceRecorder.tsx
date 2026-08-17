/**
 * VoiceRecorder.tsx - WhatsApp-style push-to-talk voice message recorder
 */
import { useState, useRef, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Mic, Square, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { supabase } from '@/integrations/supabase/client';

interface VoiceRecorderProps {
  chatId: string;
  currentUserId: string;
  receiverId: string;
  disabled?: boolean;
  onVoiceSent?: (msg?: { id: string; sender_id: string; message: string; created_at: string }) => void;
  onError?: (msg: string) => void;
}

export const VoiceRecorder = ({
  chatId,
  currentUserId,
  receiverId,
  disabled = false,
  onVoiceSent,
  onError,
}: VoiceRecorderProps) => {
  const [isRecording, setIsRecording] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [duration, setDuration] = useState(0);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const mimeRef = useRef<{ mimeType: string; ext: string }>({ mimeType: "audio/webm", ext: "webm" });

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true },
      });
      streamRef.current = stream;
      chunksRef.current = [];
      setDuration(0);

      const pickMime = (): { mimeType: string; ext: string } => {
        const candidates: [string, string][] = [
          ["audio/webm;codecs=opus", "webm"],
          ["audio/webm", "webm"],
          ["audio/mp4", "m4a"],
          ["audio/ogg;codecs=opus", "ogg"],
        ];
        for (const [mimeType, ext] of candidates) {
          if (typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(mimeType)) {
            return { mimeType, ext };
          }
        }
        return { mimeType: "", ext: "webm" };
      };

      const { mimeType, ext } = pickMime();
      mimeRef.current = { mimeType, ext };

      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream);
      mediaRecorderRef.current = recorder;

      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };

      recorder.start(100); // collect data every 100ms
      setIsRecording(true);

      timerRef.current = setInterval(() => {
        setDuration(prev => prev + 1);
      }, 1000);
    } catch (err) {
      console.error('Microphone access error:', err);
      onError?.('Microphone permission denied or unavailable');
    }
  }, []);

  const stopAndSend = useCallback(async () => {
    if (!mediaRecorderRef.current || mediaRecorderRef.current.state === 'inactive') return;

    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    setIsRecording(false);
    setIsSending(true);

    // Wait for recorder to finish
    await new Promise<void>((resolve) => {
      const recorder = mediaRecorderRef.current!;
      recorder.onstop = () => {
        streamRef.current?.getTracks().forEach(t => t.stop());
        streamRef.current = null;
        resolve();
      };
      try { recorder.requestData(); } catch { /* some browsers throw if inactive */ }
      recorder.stop();
    });

    try {
      const mimeType = mimeRef.current.mimeType || "audio/webm";
      const ext = mimeRef.current.ext || "webm";
      const blob = new Blob(chunksRef.current, { type: mimeType.split(";")[0] || "audio/webm" });
      console.log('VoiceRecorder: Blob created', { size: blob.size, type: blob.type });
      
      if (blob.size < 500) {
        console.warn('VoiceRecorder: Blob too small, discarding');
        onError?.("Recording was too short. Hold a bit longer.");
        setIsSending(false);
        return;
      }

      if (!chatId || !currentUserId || !receiverId) {
        onError?.("Chat is not ready yet. Try again in a moment.");
        setIsSending(false);
        return;
      }

      const fileName = `voice_${crypto.randomUUID().replace(/-/g, "")}.${ext}`;
      const filePath = `meowmeow/app/attachment/${currentUserId}/${chatId}/${fileName}`;
      console.log('VoiceRecorder: Uploading to', filePath);

      const blobType = blob.type || (ext === "m4a" ? "audio/mp4" : ext === "ogg" ? "audio/ogg" : "audio/webm");
      let uploadedPath = filePath;
      let { error: uploadError } = await supabase.storage
        .from('meowmeow-app-attachment')
        .upload(filePath, blob, { contentType: blobType, upsert: false });

      if (uploadError) {
        console.warn('VoiceRecorder: primary bucket failed, trying chat-attachments', uploadError.message);
        const fallbackPath = `${currentUserId}/${chatId}/${fileName}`;
        const fallback = await supabase.storage
          .from('chat-attachments')
          .upload(fallbackPath, blob, { contentType: "application/octet-stream", upsert: false });
        if (fallback.error) {
          console.error('VoiceRecorder: Upload error:', fallback.error);
          onError?.(`Voice upload failed: ${fallback.error.message}`);
          setIsSending(false);
          return;
        }
        uploadedPath = fallbackPath;
      }
      console.log('VoiceRecorder: Upload successful');

      const voiceMarker = `[VOICE:chat-attachment://${uploadedPath}]`;
      console.log('VoiceRecorder: Inserting message', voiceMarker);
      
      const { data: inserted, error: insertErr } = await supabase
        .from('chat_messages')
        .insert({
          chat_id: chatId,
          sender_id: currentUserId,
          receiver_id: receiverId,
          message: voiceMarker,
        })
        .select('id, sender_id, message, created_at')
        .single();

      if (insertErr) {
        console.error('VoiceRecorder: Voice insert error:', insertErr);
        onError?.(`Voice send failed: ${insertErr.message}`);
        setIsSending(false);
        return;
      }
      console.log('VoiceRecorder: Message insert successful', inserted);

      onVoiceSent?.(inserted as any);
    } catch (err) {
      console.error('VoiceRecorder: Voice send error:', err);
      onError?.(`Voice send failed: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsSending(false);
      setDuration(0);
    }
  }, [chatId, currentUserId, receiverId, onVoiceSent, onError]);

  const cancelRecording = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }
    streamRef.current?.getTracks().forEach(t => t.stop());
    streamRef.current = null;
    chunksRef.current = [];
    setIsRecording(false);
    setDuration(0);
  }, []);

  const formatDuration = (s: number) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  if (isSending) {
    return (
      <div className="flex items-center gap-2 text-muted-foreground">
        <Loader2 className="h-4 w-4 animate-spin" />
        <span className="text-xs">Sending voice...</span>
      </div>
    );
  }

  if (isRecording) {
    return (
      <div className="flex items-center gap-2">
        <div className="flex items-center gap-2 bg-destructive/10 px-3 py-1.5 rounded-full">
          <div className="w-2 h-2 rounded-full bg-destructive animate-pulse" />
          <span className="text-xs font-medium text-destructive">{formatDuration(duration)}</span>
        </div>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-muted-foreground"
          onClick={cancelRecording}
          title="Cancel"
        >
          <Square className="h-4 w-4" />
        </Button>
        <Button
          variant="aurora"
          size="icon"
          className="h-10 w-10 rounded-full"
          onClick={stopAndSend}
          title="Send voice message"
        >
          <Mic className="h-5 w-5" />
        </Button>
      </div>
    );
  }

  return (
    <Button
      variant="ghost"
      size="icon"
      className="h-10 w-10 rounded-full text-muted-foreground hover:text-foreground"
      onClick={startRecording}
      disabled={disabled}
      title="Record voice message"
    >
      <Mic className="h-5 w-5" />
    </Button>
  );
};

export default VoiceRecorder;
