import React, { memo } from 'react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { Globe, Users } from 'lucide-react';

export interface ChatUser {
  id: string;
  name: string;
  avatar?: string | null;
  language: string;
  languageCode: string;
  isOnline: boolean;
  lastSeen?: string;
  unreadCount?: number;
}

interface ChatUserListProps {
  users: ChatUser[];
  currentUserId?: string;
  selectedUserId?: string;
  onSelectUser?: (user: ChatUser) => void;
  className?: string;
  title?: string;
}

const OnlineIndicator = memo(({ isOnline }: { isOnline: boolean }) => (
  <span
    className={cn(
      'absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-background',
      isOnline ? 'bg-online' : 'bg-offline'
    )}
    aria-label={isOnline ? 'Online' : 'Offline'}
  />
));
OnlineIndicator.displayName = 'OnlineIndicator';

const UserItem = memo(({
  user,
  isSelected,
  isCurrentUser,
  onSelect,
}: {
  user: ChatUser;
  isSelected: boolean;
  isCurrentUser: boolean;
  onSelect?: () => void;
}) => {
  const t = (key: string, def: string) => def;

  return (
    <button
      onClick={onSelect}
      disabled={isCurrentUser}
      className={cn(
        'w-full flex items-center gap-3 p-3 rounded-lg transition-colors text-start',
        'hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary',
        isSelected && 'bg-primary/10 border border-primary/20',
        isCurrentUser && 'opacity-60 cursor-not-allowed'
      )}
      aria-current={isSelected ? 'true' : undefined}
      aria-label={`${user.name}, ${user.isOnline ? t('chat.online') : t('chat.offline')}, ${user.language}`}
    >
      {/* Avatar with online indicator */}
      <div className="relative flex-shrink-0">
        <Avatar className="h-10 w-10">
          <AvatarImage src={user.avatar || undefined} alt={user.name} />
          <AvatarFallback className="bg-primary/10 text-primary">
            {user.name.charAt(0).toUpperCase()}
          </AvatarFallback>
        </Avatar>
        <OnlineIndicator isOnline={user.isOnline} />
      </div>

      {/* User info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <span className="font-medium text-foreground truncate">
            {user.name}
            {isCurrentUser && (
              <span className="text-xs text-muted-foreground ml-1">
                ({t('common.you', 'You')})
              </span>
            )}
          </span>
          {user.unreadCount && user.unreadCount > 0 && (
            <Badge variant="destructive" className="h-5 min-w-[20px] px-1.5 text-xs">
              {user.unreadCount > 99 ? '99+' : user.unreadCount}
            </Badge>
          )}
        </div>
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Globe className="h-3 w-3 rtl:flip" />
          <span className="truncate">{user.language}</span>
        </div>
      </div>
    </button>
  );
});
UserItem.displayName = 'UserItem';

export const ChatUserList: React.FC<ChatUserListProps> = memo(({
  users,
  currentUserId,
  selectedUserId,
  onSelectUser,
  className,
  title,
}) => {
  const t = (key: string, def: string) => def;

  const onlineUsers = users.filter(u => u.isOnline);
  const offlineUsers = users.filter(u => !u.isOnline);

  return (
    <div className={cn('flex flex-col h-full', className)}>
      {/* Header */}
      <div className="p-4 border-b border-border">
        <div className="flex items-center gap-2">
          <Users className="h-5 w-5 text-primary" />
          <h2 className="font-semibold text-foreground">
            {title || t('chat.participants', 'Participants')}
          </h2>
          <Badge variant="secondary" className="ml-auto">
            {users.length}
          </Badge>
        </div>
        <p className="text-xs text-muted-foreground mt-1">
          {onlineUsers.length} {t('chat.online')}
        </p>
      </div>

      {/* User list */}
      <ScrollArea className="flex-1">
        <div className="p-2 space-y-1">
          {/* Online users first */}
          {onlineUsers.length > 0 && (
            <div className="mb-3">
              <p className="text-xs font-medium text-muted-foreground px-3 py-1.5">
                {t('chat.onlineNow', 'Online Now')} ({onlineUsers.length})
              </p>
              {onlineUsers.map(user => (
                <UserItem
                  key={user.id}
                  user={user}
                  isSelected={selectedUserId === user.id}
                  isCurrentUser={currentUserId === user.id}
                  onSelect={() => onSelectUser?.(user)}
                />
              ))}
            </div>
          )}

          {/* Offline users */}
          {offlineUsers.length > 0 && (
            <div>
              <p className="text-xs font-medium text-muted-foreground px-3 py-1.5">
                {t('chat.offline')} ({offlineUsers.length})
              </p>
              {offlineUsers.map(user => (
                <UserItem
                  key={user.id}
                  user={user}
                  isSelected={selectedUserId === user.id}
                  isCurrentUser={currentUserId === user.id}
                  onSelect={() => onSelectUser?.(user)}
                />
              ))}
            </div>
          )}

          {users.length === 0 && (
            <div className="text-center py-8 text-muted-foreground">
              <Users className="h-12 w-12 mx-auto mb-3 opacity-30" />
              <p>{t('chat.noParticipants', 'No participants yet')}</p>
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
});

ChatUserList.displayName = 'ChatUserList';

export default ChatUserList;
