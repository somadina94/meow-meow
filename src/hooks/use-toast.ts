/**
 * Compatibility layer: delegates all toast calls to sonner.
 *
 * Legacy code calls  toast({ title, description, variant })
 * or                 toast.error(title, { description })
 * or                 toast.success(title, { description })
 *
 * All of these now render through sonner's <Toaster />.
 * The shadcn <ShadToaster /> is removed from App.tsx.
 *
 * New code should import directly from "sonner".
 */

import { toast as sonnerToast } from "sonner";

interface ShadcnToastProps {
  title?: string;
  description?: string;
  variant?: "default" | "destructive";
  [key: string]: unknown;
}

/**
 * Accepts the shadcn-style object API and forwards to sonner.
 */
function toast(props: ShadcnToastProps) {
  const { title, description, variant } = props;

  if (variant === "destructive") {
    return sonnerToast.error(title ?? "Error", { description });
  }
  return sonnerToast(title ?? "", { description });
}

// Expose the sonner convenience methods directly so
// toast.success() / toast.error() / toast.info() etc. keep working.
toast.success = sonnerToast.success;
toast.error = sonnerToast.error;
toast.info = sonnerToast.info;
toast.warning = sonnerToast.warning;
toast.message = sonnerToast.message;
toast.dismiss = sonnerToast.dismiss;

/**
 * Hook kept for backward-compat — components that call
 * `const { toast } = useToast()` will get the same wrapper.
 */
function useToast() {
  return { toast, dismiss: sonnerToast.dismiss, toasts: [] as never[] };
}

export { useToast, toast };
