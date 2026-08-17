import React from "react";
import { Users, Radio, Lock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { GroupChatRoom } from "@/hooks/useGroupChat";

interface Props {
  room: GroupChatRoom;
  viewerGender: "male" | "female";
  isMine?: boolean;
  onJoin?: (room: GroupChatRoom) => void;
  onGoLive?: (room: GroupChatRoom) => void;
  onEndLive?: (room: GroupChatRoom) => void;
}

export const GroupChatRoomCard: React.FC<Props> = ({ room, viewerGender, isMine, onJoin, onGoLive, onEndLive }) => {
  const isLive = room.status === "live";
  const isFull = room.current_participant_count >= room.max_users;

  const renderAction = () => {
    if (viewerGender === "female") {
      if (isMine && isLive) {
        return <Button size="sm" variant="destructive" onClick={() => onEndLive?.(room)}>End Live</Button>;
      }
      if (isLive) {
        return <Button size="sm" variant="outline" disabled>Hosted</Button>;
      }
      return <Button size="sm" onClick={() => onGoLive?.(room)}>Go Live</Button>;
    }
    // Male
    if (!isLive) return null;
    if (isFull) return <Button size="sm" variant="outline" disabled>Full</Button>;
    return <Button size="sm" onClick={() => onJoin?.(room)}>Join</Button>;
  };

  return (
    <div className={cn(
      "rounded-xl border p-3 flex flex-col gap-2 bg-card",
      isLive ? "border-primary/40" : "border-border opacity-90"
    )}>
      <div className="flex items-center justify-between gap-2">
        <div className="font-semibold truncate flex items-center gap-1.5">
          {isLive ? <Radio className="w-3.5 h-3.5 text-red-500 animate-pulse" /> : <Lock className="w-3.5 h-3.5 text-muted-foreground" />}
          <span className="truncate">{room.name}</span>
        </div>
        {isLive && (
          <span className="text-[10px] font-bold tracking-wide bg-red-500 text-white px-1.5 py-0.5 rounded">LIVE</span>
        )}
      </div>
      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span className="inline-flex items-center gap-1">
          <Users className="w-3.5 h-3.5" />
          {room.current_participant_count}/{room.max_users}
        </span>
        {renderAction()}
      </div>
    </div>
  );
};

export default GroupChatRoomCard;
