import { lazy, Suspense, ReactNode } from "react";
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";
import { Toaster } from "@/components/ui/sonner";

import { ThemeProvider } from "@/contexts/ThemeContext";
import { QueryClient, QueryClientProvider, QueryCache } from "@tanstack/react-query";
import ProtectedRoute from "@/components/ProtectedRoute";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import SecurityProvider from "@/components/SecurityProvider";
import ScreenCaptureGuard from "@/components/ScreenCaptureGuard";
import { AutoLogoutWrapper } from "@/components/AutoLogoutWrapper";
import { NetworkStatusIndicator } from "@/components/NetworkStatusIndicator";
import PWAInstallPrompt from "@/components/PWAInstallPrompt";
import { UserActivityProvider } from "@/contexts/UserActivityContext";

import { Loader2 } from "lucide-react";
import { useAutoAdjustUI } from "@/hooks/useAutoAdjustUI";
import { useLoginSessionTracker } from "@/hooks/useLoginSessionTracker";
import { isSupabaseConfigured } from "@/integrations/supabase/client";

const queryClient = new QueryClient({
  queryCache: new QueryCache({
    onError: (error) => {
      if (import.meta.env.DEV) {
        console.error('[ReactQuery] Query error:', error);
      }
    },
  }),
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5 * 60 * 1000,
      gcTime: 10 * 60 * 1000,
      refetchOnWindowFocus: false,
      refetchOnMount: false,
    },
  },
});

const Loading = () => (
  <div className="flex items-center justify-center min-h-screen">
    <Loader2 className="h-8 w-8 animate-spin text-primary" />
  </div>
);

/** Per-route Suspense wrapper with error boundary — isolates chunk failures */
const RouteSuspense = ({ children }: { children: ReactNode }) => (
  <ErrorBoundary showHomeButton>
    <Suspense fallback={<Loading />}>{children}</Suspense>
  </ErrorBoundary>
);

/** Configuration error screen shown when Supabase env vars are missing */
const ConfigError = () => (
  <div className="min-h-screen bg-background flex items-center justify-center p-4">
    <div className="max-w-md w-full text-center space-y-4">
      <h1 className="text-2xl font-bold text-foreground">Configuration Error</h1>
      <p className="text-muted-foreground">
        The app is missing required Supabase configuration. Please ensure
        VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY are set.
      </p>
      <button
        onClick={() => window.location.reload()}
        className="px-6 py-3 bg-primary text-primary-foreground rounded-lg"
      >
        Retry
      </button>
    </div>
  </div>
);

// Resilient lazy imports — retry once on chunk failure
function lazyRetry(factory: () => Promise<{ default: React.ComponentType<any> }>) {
  return lazy(() =>
    factory().catch(() =>
      new Promise<{ default: React.ComponentType<any> }>((resolve) => {
        setTimeout(() => resolve(factory()), 1500);
      })
    )
  );
}

// Auth & Registration
const AuthScreen = lazyRetry(() => import("@/pages/AuthScreen"));
const CaptchaScreen = lazyRetry(() => import("@/pages/CaptchaScreen"));
const ForgotPasswordScreen = lazyRetry(() => import("@/pages/ForgotPasswordScreen"));
const PasswordResetScreen = lazyRetry(() => import("@/pages/PasswordResetScreen"));
const PasswordResetSuccessScreen = lazyRetry(() => import("@/pages/PasswordResetSuccessScreen"));
const LanguageCountryScreen = lazyRetry(() => import("@/pages/LanguageCountryScreen"));
const BasicInfoScreen = lazyRetry(() => import("@/pages/BasicInfoScreen"));
const PersonalDetailsScreen = lazyRetry(() => import("@/pages/PersonalDetailsScreen"));
const PhotoUploadScreen = lazyRetry(() => import("@/pages/PhotoUploadScreen"));
const AdditionalPhotosScreen = lazyRetry(() => import("@/pages/AdditionalPhotosScreen"));
const LocationSetupScreen = lazyRetry(() => import("@/pages/LocationSetupScreen"));
const LanguagePreferencesScreen = lazyRetry(() => import("@/pages/LanguagePreferencesScreen"));
const PasswordSetupScreen = lazyRetry(() => import("@/pages/PasswordSetupScreen"));
const TermsAgreementScreen = lazyRetry(() => import("@/pages/TermsAgreementScreen"));
const AIProcessingScreen = lazyRetry(() => import("@/pages/AIProcessingScreen"));
const RegistrationCompleteScreen = lazyRetry(() => import("@/pages/RegistrationCompleteScreen"));
const ApprovalPendingScreen = lazyRetry(() => import("@/pages/ApprovalPendingScreen"));
const WelcomeTutorialScreen = lazyRetry(() => import("@/pages/WelcomeTutorialScreen"));

// Dashboards
const DashboardScreen = lazyRetry(() => import("@/pages/DashboardScreen"));
const WomenDashboardScreen = lazyRetry(() => import("@/pages/WomenDashboardScreen"));

// Features
const ChatScreen = lazyRetry(() => import("@/pages/ChatScreen"));
const MatchingScreen = lazyRetry(() => import("@/pages/MatchingScreen"));
const MatchDiscoveryScreen = lazyRetry(() => import("@/pages/MatchDiscoveryScreen"));
const OnlineUsersScreen = lazyRetry(() => import("@/pages/OnlineUsersScreen"));
const ProfileDetailScreen = lazyRetry(() => import("@/pages/ProfileDetailScreen"));

const SettingsScreen = lazyRetry(() => import("@/pages/SettingsScreen"));
const InstallApp = lazyRetry(() => import("@/pages/InstallApp"));

// Wallet
const WalletScreen = lazyRetry(() => import("@/pages/WalletScreen"));
const WomenWalletScreen = lazyRetry(() => import("@/pages/WomenWalletScreen"));

// Admin
const AdminDashboard = lazyRetry(() => import("@/pages/AdminDashboard"));
const AdminUserManagement = lazyRetry(() => import("@/pages/AdminUserManagement"));
const AdminAnalyticsDashboard = lazyRetry(() => import("@/pages/AdminAnalyticsDashboard"));
const AdminChatMonitoring = lazyRetry(() => import("@/pages/AdminChatMonitoring"));
const AdminLanguageGroups = lazyRetry(() => import("@/pages/AdminLanguageGroups"));
const AdminLanguageLimits = lazyRetry(() => import("@/pages/AdminLanguageLimits"));
const AdminKYCManagement = lazyRetry(() => import("@/pages/AdminKYCManagement"));
const AdminUserLookup = lazyRetry(() => import("@/pages/AdminUserLookup"));
const AdminModerationScreen = lazyRetry(() => import("@/pages/AdminModerationScreen"));
const AdminPolicyAlerts = lazyRetry(() => import("@/pages/AdminPolicyAlerts"));
const AdminPerformanceMonitoring = lazyRetry(() => import("@/pages/AdminPerformanceMonitoring"));
const AdminLegalDocuments = lazyRetry(() => import("@/pages/AdminLegalDocuments"));
const AdminBackupManagement = lazyRetry(() => import("@/pages/AdminBackupManagement"));
const AdminAuditLogs = lazyRetry(() => import("@/pages/AdminAuditLogs"));
const AdminMessaging = lazyRetry(() => import("@/pages/AdminMessaging"));
const AdminLiveMessenger = lazyRetry(() => import("@/pages/AdminLiveMessenger"));
const AdminSettings = lazyRetry(() => import("@/pages/AdminSettings"));
const AdminPayoutStatements = lazyRetry(() => import("@/pages/AdminPayoutStatements"));
const AdminEnableDisable = lazyRetry(() => import("@/pages/AdminEnableDisable"));
const NotFound = lazyRetry(() => import("@/pages/NotFound"));

/** Inner component that lives inside BrowserRouter — safe to use router hooks */
const AppShell = () => {
  useAutoAdjustUI();
  useLoginSessionTracker();
  const location = useLocation();
  const showInstallPrompt = location.pathname === "/" || location.pathname === "/index";

  if (!isSupabaseConfigured) {
    return <ConfigError />;
  }

  return (
    <SecurityProvider>
      <ScreenCaptureGuard>
      <UserActivityProvider>
        <AutoLogoutWrapper>
          <Routes>
          {/* Auth */}
          <Route path="/" element={<RouteSuspense><AuthScreen /></RouteSuspense>} />
          <Route path="/auth" element={<RouteSuspense><AuthScreen /></RouteSuspense>} />
          <Route path="/captcha" element={<RouteSuspense><CaptchaScreen /></RouteSuspense>} />
            <Route path="/forgot-password" element={<RouteSuspense><ForgotPasswordScreen /></RouteSuspense>} />
            <Route path="/reset-password" element={<RouteSuspense><PasswordResetScreen /></RouteSuspense>} />
            <Route path="/password-reset-success" element={<RouteSuspense><PasswordResetSuccessScreen /></RouteSuspense>} />

            {/* Registration */}
            <Route path="/register" element={<RouteSuspense><LanguageCountryScreen /></RouteSuspense>} />
            <Route path="/basic-info" element={<RouteSuspense><BasicInfoScreen /></RouteSuspense>} />
            <Route path="/personal-details" element={<RouteSuspense><PersonalDetailsScreen /></RouteSuspense>} />
            <Route path="/photo-upload" element={<RouteSuspense><PhotoUploadScreen /></RouteSuspense>} />
            <Route path="/additional-photos" element={<RouteSuspense><AdditionalPhotosScreen /></RouteSuspense>} />
            <Route path="/location-setup" element={<RouteSuspense><LocationSetupScreen /></RouteSuspense>} />
            <Route path="/language-preferences" element={<RouteSuspense><LanguagePreferencesScreen /></RouteSuspense>} />
            <Route path="/password-setup" element={<RouteSuspense><PasswordSetupScreen /></RouteSuspense>} />
            <Route path="/terms-agreement" element={<RouteSuspense><TermsAgreementScreen /></RouteSuspense>} />
            <Route path="/ai-processing" element={<RouteSuspense><AIProcessingScreen /></RouteSuspense>} />
            <Route path="/registration-complete" element={<RouteSuspense><RegistrationCompleteScreen /></RouteSuspense>} />
            <Route path="/approval-pending" element={<RouteSuspense><ApprovalPendingScreen /></RouteSuspense>} />
            <Route path="/welcome" element={<RouteSuspense><WelcomeTutorialScreen /></RouteSuspense>} />

            {/* Men Dashboard */}
            <Route path="/dashboard" element={<ProtectedRoute requiredRole="male"><DashboardScreen /></ProtectedRoute>} />

            {/* Women Dashboard */}
            <Route path="/women-dashboard" element={<ProtectedRoute requiredRole="female"><WomenDashboardScreen /></ProtectedRoute>} />

            {/* Shared Features */}
            <Route path="/chat/:partnerId" element={<ProtectedRoute><ChatScreen /></ProtectedRoute>} />
            <Route path="/matching" element={<ProtectedRoute><MatchingScreen /></ProtectedRoute>} />
            <Route path="/match-discovery" element={<ProtectedRoute><MatchDiscoveryScreen /></ProtectedRoute>} />
            <Route path="/online-users" element={<ProtectedRoute><OnlineUsersScreen /></ProtectedRoute>} />
            <Route path="/profile/:userId" element={<ProtectedRoute><ProfileDetailScreen /></ProtectedRoute>} />
            <Route path="/settings" element={<ProtectedRoute><SettingsScreen /></ProtectedRoute>} />
            <Route path="/wallet" element={<ProtectedRoute requiredRole="male"><WalletScreen /></ProtectedRoute>} />
            <Route path="/women-wallet" element={<ProtectedRoute requiredRole="female"><WomenWalletScreen /></ProtectedRoute>} />
            <Route path="/install" element={<RouteSuspense><InstallApp /></RouteSuspense>} />

            {/* Admin */}
            <Route path="/admin" element={<ProtectedRoute requiredRole="admin"><AdminDashboard /></ProtectedRoute>} />
            <Route path="/admin/users" element={<ProtectedRoute requiredRole="admin"><AdminUserManagement /></ProtectedRoute>} />
            <Route path="/admin/analytics" element={<ProtectedRoute requiredRole="admin"><AdminAnalyticsDashboard /></ProtectedRoute>} />
            <Route path="/admin/chat-monitoring" element={<ProtectedRoute requiredRole="admin"><AdminChatMonitoring /></ProtectedRoute>} />
            <Route path="/admin/languages" element={<ProtectedRoute requiredRole="admin"><AdminLanguageGroups /></ProtectedRoute>} />
            <Route path="/admin/language-limits" element={<ProtectedRoute requiredRole="admin"><AdminLanguageLimits /></ProtectedRoute>} />
            <Route path="/admin/kyc" element={<ProtectedRoute requiredRole="admin"><AdminKYCManagement /></ProtectedRoute>} />
            <Route path="/admin/user-lookup" element={<ProtectedRoute requiredRole="admin"><AdminUserLookup /></ProtectedRoute>} />
            <Route path="/admin/moderation" element={<ProtectedRoute requiredRole="admin"><AdminModerationScreen /></ProtectedRoute>} />
            <Route path="/admin/policy-alerts" element={<ProtectedRoute requiredRole="admin"><AdminPolicyAlerts /></ProtectedRoute>} />
            <Route path="/admin/performance" element={<ProtectedRoute requiredRole="admin"><AdminPerformanceMonitoring /></ProtectedRoute>} />
            <Route path="/admin/legal-documents" element={<ProtectedRoute requiredRole="admin"><AdminLegalDocuments /></ProtectedRoute>} />
            <Route path="/admin/backups" element={<ProtectedRoute requiredRole="admin"><AdminBackupManagement /></ProtectedRoute>} />
            <Route path="/admin/audit-logs" element={<ProtectedRoute requiredRole="admin"><AdminAuditLogs /></ProtectedRoute>} />
           <Route path="/admin/messaging" element={<ProtectedRoute requiredRole="admin"><AdminMessaging /></ProtectedRoute>} />
           <Route path="/admin/messenger" element={<ProtectedRoute requiredRole="admin"><AdminLiveMessenger /></ProtectedRoute>} />
            <Route path="/admin/settings" element={<ProtectedRoute requiredRole="admin"><AdminSettings /></ProtectedRoute>} />
            <Route path="/admin/enable_disable" element={<ProtectedRoute requiredRole="admin"><AdminEnableDisable /></ProtectedRoute>} />
            <Route path="/admin/enable-disable" element={<ProtectedRoute requiredRole="admin"><AdminEnableDisable /></ProtectedRoute>} />
            <Route path="/admin/payout-statements" element={<ProtectedRoute requiredRole="admin"><AdminPayoutStatements /></ProtectedRoute>} />

            <Route path="*" element={<RouteSuspense><NotFound /></RouteSuspense>} />
          </Routes>
          <Toaster />
          <NetworkStatusIndicator />
          {showInstallPrompt && <PWAInstallPrompt />}
        </AutoLogoutWrapper>
      </UserActivityProvider>
      </ScreenCaptureGuard>
    </SecurityProvider>
  );
};

const App = () => (
  <QueryClientProvider client={queryClient}>
    <ThemeProvider>
      <ErrorBoundary>
        <BrowserRouter>
          <AppShell />
        </BrowserRouter>
      </ErrorBoundary>
    </ThemeProvider>
  </QueryClientProvider>
);

export default App;
