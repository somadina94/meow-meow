/**
 * ErrorBoundary — catches React render errors and shows a friendly recovery screen.
 *
 * Wraps the entire app (and individual lazy-loaded routes) to prevent a single
 * component crash from taking down everything.
 */

import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, RefreshCw, Home, WifiOff, ShieldAlert, ServerCrash } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { classifyError, ErrorCategory } from '@/lib/errors';

interface Props {
  children: ReactNode;
  /** Optional custom fallback UI */
  fallback?: ReactNode;
  /** Called when an error is caught (for external logging) */
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
  /** Show a "Go home" button — useful for route-level boundaries */
  showHomeButton?: boolean;
}

interface State {
  hasError: boolean;
  error: Error | null;
  errorId: string | null;
}

function generateErrorId(): string {
  return Math.random().toString(36).slice(2, 8).toUpperCase();
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null, errorId: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return {
      hasError: true,
      error,
      errorId: generateErrorId(),
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    if (import.meta.env.DEV) {
      console.error('[ErrorBoundary] Caught error:', error);
      console.error('[ErrorBoundary] Component stack:', errorInfo.componentStack);
    }
    this.props.onError?.(error, errorInfo);
  }

  handleRetry = (): void => {
    this.setState({ hasError: false, error: null, errorId: null });
  };

  handleReload = async (): Promise<void> => {
    // Clear stale service worker and caches first to prevent reload loops
    try {
      if ('serviceWorker' in navigator) {
        const regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.map((r) => r.unregister()));
      }
      if ('caches' in window) {
        const keys = await caches.keys();
        await Promise.all(keys.map((k) => caches.delete(k)));
      }
    } catch {
      // Best-effort only
    }
    window.location.reload();
  };

  handleGoHome = (): void => {
    window.location.href = '/';
  };

  render(): ReactNode {
    if (!this.state.hasError) {
      return this.props.children;
    }

    if (this.props.fallback) {
      return this.props.fallback;
    }

    const appError = this.state.error ? classifyError(this.state.error) : null;

    const getErrorDisplay = () => {
      if (!appError) {
        return {
          icon: <AlertTriangle className="h-12 w-12 text-destructive" />,
          bgClass: 'bg-destructive/10',
          title: 'Something went wrong',
          message: 'An unexpected error occurred. Please try reloading the page.',
        };
      }
      switch (appError.category) {
        case ErrorCategory.NETWORK:
          return {
            icon: <WifiOff className="h-12 w-12 text-warning" />,
            bgClass: 'bg-warning/10',
            title: 'No internet connection',
            message: 'Please check your internet connection and try again.',
          };
        case ErrorCategory.AUTH:
        case ErrorCategory.PERMISSION:
          return {
            icon: <ShieldAlert className="h-12 w-12 text-primary" />,
            bgClass: 'bg-primary/10',
            title: appError.title,
            message: appError.message,
          };
        case ErrorCategory.SERVER:
          return {
            icon: <ServerCrash className="h-12 w-12 text-destructive" />,
            bgClass: 'bg-destructive/10',
            title: 'Server error',
            message: 'Our servers ran into a problem. Please try again in a few moments.',
          };
        default:
          return {
            icon: <AlertTriangle className="h-12 w-12 text-destructive" />,
            bgClass: 'bg-destructive/10',
            title: appError.title || 'Something went wrong',
            message: appError.message || 'An unexpected error occurred. Please try reloading the page.',
          };
      }
    };

    const display = getErrorDisplay();

    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <div className="max-w-md w-full text-center space-y-6 animate-fade-in">
          <div className="flex justify-center">
            <div className={`p-5 ${display.bgClass} rounded-full`}>
              {display.icon}
            </div>
          </div>

          <div className="space-y-2">
            <h1 className="text-2xl font-bold text-foreground">{display.title}</h1>
            <p className="text-muted-foreground leading-relaxed">{display.message}</p>
          </div>

          {this.state.errorId && (
            <p className="text-xs text-muted-foreground/60">
              Error reference: <span className="font-mono">{this.state.errorId}</span>
            </p>
          )}

          {import.meta.env.DEV && this.state.error && (
            <div className="p-4 bg-muted rounded-lg text-left max-h-40 overflow-y-auto">
              <p className="text-xs font-mono text-destructive break-all whitespace-pre-wrap">
                {this.state.error.message}
              </p>
            </div>
          )}

          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            {appError?.retryable !== false && (
              <Button variant="outline" onClick={this.handleRetry}>
                <RefreshCw className="h-4 w-4 mr-2" />
                Try again
              </Button>
            )}
            <Button onClick={this.handleReload}>
              <RefreshCw className="h-4 w-4 mr-2" />
              Reload page
            </Button>
            {this.props.showHomeButton && (
              <Button variant="ghost" onClick={this.handleGoHome}>
                <Home className="h-4 w-4 mr-2" />
                Go to home
              </Button>
            )}
          </div>

          <p className="text-xs text-muted-foreground">
            If this keeps happening, please{' '}
            <button
              className="underline underline-offset-2 hover:text-foreground transition-colors"
              onClick={() => {
                window.location.href = 'mailto:support@meow.app?subject=App error ' + this.state.errorId;
              }}
            >
              contact support
            </button>{' '}
            with the error reference above.
          </p>
        </div>
      </div>
    );
  }
}

export default ErrorBoundary;
