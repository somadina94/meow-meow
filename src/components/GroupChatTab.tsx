/**
 * GroupChatTab — Live women-hosted text-chat group rooms.
 * Men see only LIVE rooms; women see all rooms with Go Live / End Live.
 */
import React, { useMemo, useState } from "react";
import { Input } from "@/components/ui/input";
import { Search, Radio } from "lucide-react";
import { useGroupChatRooms, gcGoLive, gcJoin, gcEndLive, gcAnnounce, type GroupChatRoom } from "@/hooks/useGroupChat";
import { GroupChatRoomCard } from "./group-chat/GroupChatRoomCard";
import { GroupChatRoom as GroupChatRoomView } from "./group-chat/GroupChatRoom";
import { toast } from "@/hooks/use-toast";

interface Props {
  currentUserId: string;
  viewerGender: "male" | "female";
  viewerName: string;
  viewerLanguage?: string;
}

interface ActiveRoom { sessionId: string; roomId: string; roomName: string; hostId: string; }

const GroupChatTab: React.FC<Props> = ({ currentUserId, viewerGender, viewerName, viewerLanguage }) => {
  const isMale = viewerGender === "male";
  const { rooms, loading } = useGroupChatRooms({ onlyLive: isMale });
  const [search, setSearch] = useState("");
  const [active, setActive] = useState<ActiveRoom | null>(null);

  const filtered = useMemo(() => {
    if (!search.trim()) return rooms;
    const q = search.toLowerCase();
    return rooms.filter((r) => r.name.toLowerCase().includes(q) || r.tree_type.toLowerCase().includes(q));
  }, [rooms, search]);

  const liveCount = rooms.filter((r) => r.status === "live").length;

  const handleJoin = async (r: GroupChatRoom) => {
    const res = await gcJoin(r.id);
    if (!res.success) { toast({ title: "Cannot join", description: res.error, variant: "destructive" }); return; }
    setActive({ sessionId: res.session_id!, roomId: r.id, roomName: r.name, hostId: r.current_host_id! });
    gcAnnounce(res.session_id!, r.id, currentUserId, viewerName, viewerGender, "join");
  };
  const handleGoLive = async (r: GroupChatRoom) => {
    const res = await gcGoLive(r.id);
    if (!res.success) { toast({ title: "Cannot go live", description: res.error, variant: "destructive" }); return; }
    setActive({ sessionId: res.session_id!, roomId: r.id, roomName: r.name, hostId: currentUserId });
    gcAnnounce(res.session_id!, r.id, currentUserId, viewerName, viewerGender, "join");
  };
  const handleEndLive = async (r: GroupChatRoom) => {
    if (r.current_session_id) await gcEndLive(r.current_session_id);
  };

  return (
    <div className="h-full flex flex-col">
      <div className="shrink-0 px-3 py-2 space-y-2 border-b border-border bg-card">
        <div className="flex items-center justify-between">
          <div className="font-semibold text-sm flex items-center gap-1.5">
            <Radio className="w-4 h-4 text-red-500" />
            Group Chat {isMale ? "· Live Rooms" : ""}
          </div>
          <div className="text-xs text-muted-foreground">{liveCount} live</div>
        </div>
        <div className="relative">
          <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search trees…"
            className="h-8 pl-7 text-sm"
          />
        </div>
        {!isMale && (
          <p className="text-[11px] text-muted-foreground">
            Going live alone doesn't earn. Earnings start (₹1/min) per active male user.
          </p>
        )}
      </div>

      <div className="flex-1 overflow-y-auto p-2">
        {loading ? (
          <div className="text-center text-sm text-muted-foreground py-12">Loading rooms…</div>
        ) : filtered.length === 0 ? (
          <div className="text-center text-sm text-muted-foreground py-12">
            {isMale ? "No live rooms right now. Check back soon." : "No rooms found."}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {filtered.map((r) => (
              <GroupChatRoomCard
                key={r.id}
                room={r}
                viewerGender={viewerGender}
                isMine={r.current_host_id === currentUserId}
                onJoin={handleJoin}
                onGoLive={handleGoLive}
                onEndLive={handleEndLive}
              />
            ))}
          </div>
        )}
      </div>

      {active && (
        <GroupChatRoomView
          sessionId={active.sessionId}
          roomId={active.roomId}
          roomName={active.roomName}
          hostId={active.hostId}
          currentUserId={currentUserId}
          viewerGender={viewerGender}
          viewerName={viewerName}
          viewerLanguage={viewerLanguage}
          onClose={() => setActive(null)}
        />
      )}
    </div>
  );
};

export default GroupChatTab;
