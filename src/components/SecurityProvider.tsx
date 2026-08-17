/**
 * Security Provider
 * 
 * Provides security context for the app. Real security is enforced
 * server-side via RLS policies, JWT validation, and edge functions.
 * 
 * Client-side protections are limited to content-specific copy/select
 * blocking on elements marked with data-protected / data-no-select.
 */

import React, { useEffect, createContext, useContext, useState, memo } from 'react';
import { useToast } from '@/hooks/use-toast';

interface SecurityContextType {
  isSecurityActive: boolean;
  captureAttempts: number;
  devToolsOpen: boolean;
}

const SecurityContext = createContext<SecurityContextType>({
  isSecurityActive: true,
  captureAttempts: 0,
  devToolsOpen: false
});

export const useSecurityContext = () => useContext(SecurityContext);

interface SecurityProviderProps {
  children: React.ReactNode;
  enableDevToolsDetection?: boolean;
  enableConsoleProtection?: boolean;
  enableKeyboardBlocking?: boolean;
}

const SecurityProvider: React.FC<SecurityProviderProps> = memo(({
  children,
  enableConsoleProtection = false,
}) => {
  const [captureAttempts] = useState(0);
  const { toast } = useToast();

  useEffect(() => {
    // Console protection in production — only suppress debug/log, preserve warn/error for diagnostics
    if (enableConsoleProtection && import.meta.env.PROD) {
      console.log = () => {};
      console.info = () => {};
    }

    // Selection and copy handlers for protected content only
    const handleSelectStart = (e: Event) => {
      const target = e.target as HTMLElement;
      if (target.closest('[data-protected]') || target.closest('[data-no-select]')) {
        e.preventDefault();
      }
    };

    const handleCopy = (e: ClipboardEvent) => {
      const selection = window.getSelection();
      const selectedNode = selection?.anchorNode?.parentElement;
      
      if (selectedNode?.closest('[data-protected]')) {
        e.preventDefault();
        toast({
          title: "Copy blocked",
          description: "Copying this content is not allowed.",
          variant: "destructive"
        });
      }
    };

    document.addEventListener('selectstart', handleSelectStart);
    document.addEventListener('copy', handleCopy);

    return () => {
      document.removeEventListener('selectstart', handleSelectStart);
      document.removeEventListener('copy', handleCopy);
    };
  }, [enableConsoleProtection, toast]);

  return (
    <SecurityContext.Provider 
      value={{ 
        isSecurityActive: true, 
        captureAttempts, 
        devToolsOpen: false 
      }}
    >
      {children}
    </SecurityContext.Provider>
  );
});

SecurityProvider.displayName = 'SecurityProvider';

export default SecurityProvider;