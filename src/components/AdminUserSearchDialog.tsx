/**
 * Admin User Search Dialog
 * 
 * Allows admin to search for any user by name, email, or phone number
 * and view complete details including KYC information for legal compliance.
 * 
 * Purpose: Government/Police case compliance - complete user data retrieval
 */

import { useState, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { toast } from "sonner";
import {
  Search,
  User,
  Phone,
  Mail,
  MapPin,
  Calendar,
  FileText,
  Shield,
  Building,
  CreditCard,
  Image,
  AlertTriangle,
  Download,
  Copy,
  Check,
  Loader2,
  UserSearch,
  Wallet,
  MessageSquare,
  Clock,
  Heart,
} from "lucide-react";
import { format } from "date-fns";

interface UserProfile {
  id: string;
  user_id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  gender: string | null;
  date_of_birth: string | null;
  age: number | null;
  country: string | null;
  state: string | null;
  city: string | null;
  bio: string | null;
  photo_url: string | null;
  primary_language: string | null;
  preferred_language: string | null;
  // Lifestyle
  occupation: string | null;
  education_level: string | null;
  religion: string | null;
  marital_status: string | null;
  height_cm: number | null;
  body_type: string | null;
  smoking_habit: string | null;
  drinking_habit: string | null;
  dietary_preference: string | null;
  fitness_level: string | null;
  has_children: boolean | null;
  pet_preference: string | null;
  travel_frequency: string | null;
  personality_type: string | null;
  zodiac_sign: string | null;
  interests: string[] | null;
  life_goals: string[] | null;
  // Status
  account_status: string | null;
  approval_status: string | null;
  verification_status: boolean | null;
  is_verified: boolean | null;
  is_premium: boolean | null;
  is_indian: boolean | null;
  is_earning_eligible: boolean | null;
  ai_approved: boolean | null;
  ai_disapproval_reason: string | null;
  performance_score: number | null;
  total_chats_count: number | null;
  avg_response_time_seconds: number | null;
  profile_completeness: number | null;
  // Timestamps
  created_at: string;
  updated_at: string;
  last_active_at: string | null;
  earning_slot_assigned_at: string | null;
  earning_badge_type: string | null;
  monthly_chat_minutes: number | null;
}

interface WomenKYC {
  id: string;
  user_id: string;
  full_name_as_per_bank: string | null;
  date_of_birth: string | null;
  gender: string | null;
  country_of_residence: string | null;
  bank_name: string | null;
  account_holder_name: string | null;
  account_number: string | null;
  ifsc_code: string | null;
  id_type: string | null;
  id_number: string | null;
  document_front_url: string | null;
  document_back_url: string | null;
  selfie_url: string | null;
  verification_status: string | null;
  rejection_reason: string | null;
  verified_at: string | null;
  verified_by: string | null;
  consent_given: boolean | null;
  consent_timestamp: string | null;
  created_at: string;
  updated_at: string;
}

interface WalletInfo {
  balance: number;
  currency: string;
}

interface ChatStats {
  total_messages_sent: number;
  total_chats: number;
  last_chat_date: string | null;
}

interface SearchResult {
  profile: UserProfile;
  kyc: WomenKYC | null;
  wallet: WalletInfo | null;
  chatStats: ChatStats | null;
  relationships: {
    friends: number;
    blocked: number;
  };
}

export const AdminUserSearchDialog = () => {
  const [open, setOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [searching, setSearching] = useState(false);
  const [results, setResults] = useState<SearchResult[]>([]);
  const [selectedUser, setSelectedUser] = useState<SearchResult | null>(null);
  const [copied, setCopied] = useState<string | null>(null);

  const searchUsers = useCallback(async () => {
    if (!searchQuery.trim()) {
      toast.error("Please enter a search term");
      return;
    }

    setSearching(true);
    setResults([]);
    setSelectedUser(null);

    try {
      // Search in profiles by name, email, or phone
      const { data: profiles, error } = await supabase
        .from("profiles")
        .select("*")
        .or(`full_name.ilike.%${searchQuery}%,email.ilike.%${searchQuery}%,phone.ilike.%${searchQuery}%`)
        .limit(20);

      if (error) throw error;

      if (!profiles || profiles.length === 0) {
        toast.info("No users found matching the search criteria");
        setSearching(false);
        return;
      }

      // Fetch additional data for each user
      const enrichedResults: SearchResult[] = await Promise.all(
        profiles.map(async (profile) => {
          // Fetch KYC data if female user
          let kyc: WomenKYC | null = null;
          if (profile.gender?.toLowerCase() === "female") {
            const { data: kycData } = await supabase
              .from("women_kyc")
              .select("*")
              .eq("user_id", profile.user_id)
              .maybeSingle();
            kyc = kycData as WomenKYC | null;
          }

          // Wallet info removed — billing system removed
          let wallet: WalletInfo | null = null;

          // Fetch chat stats
          let chatStats: ChatStats | null = null;
          const { count: messageCount } = await supabase
            .from("chat_messages")
            .select("*", { count: "exact", head: true })
            .eq("sender_id", profile.user_id);

          const { data: lastChat } = await supabase
            .from("chat_messages")
            .select("created_at")
            .eq("sender_id", profile.user_id)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();

          chatStats = {
            total_messages_sent: messageCount || 0,
            total_chats: profile.total_chats_count || 0,
            last_chat_date: lastChat?.created_at || null,
          };

          // Fetch relationship counts
          const { count: friendsCount } = await supabase
            .from("user_friends")
            .select("*", { count: "exact", head: true })
            .or(`user_id.eq.${profile.user_id},friend_id.eq.${profile.user_id}`)
            .eq("status", "accepted");

          const { count: blockedCount } = await supabase
            .from("user_blocks")
            .select("*", { count: "exact", head: true })
            .or(`blocker_id.eq.${profile.user_id},blocked_id.eq.${profile.user_id}`);

          return {
            profile: profile as UserProfile,
            kyc,
            wallet,
            chatStats,
            relationships: {
              friends: friendsCount || 0,
              blocked: blockedCount || 0,
            },
          };
        })
      );

      setResults(enrichedResults);
      toast.success(`Found ${enrichedResults.length} user(s)`);
    } catch (error) {
      console.error("Error searching users:", error);
      toast.error("Failed to search users");
    } finally {
      setSearching(false);
    }
  }, [searchQuery]);

  const copyToClipboard = async (text: string, field: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(field);
      setTimeout(() => setCopied(null), 2000);
      toast.success("Copied to clipboard");
    } catch (err) {
      toast.error("Failed to copy");
    }
  };

  const exportUserData = (user: SearchResult) => {
    const exportData = {
      exportDate: new Date().toISOString(),
      purpose: "Legal/Government Compliance",
      profile: user.profile,
      kyc: user.kyc,
      wallet: user.wallet,
      chatStats: user.chatStats,
      relationships: user.relationships,
    };

    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `user-data-${user.profile.user_id}-${format(new Date(), "yyyy-MM-dd")}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    toast.success("User data exported successfully");
  };

  const renderCopyableField = (label: string, value: string | null | undefined, fieldKey: string) => {
    if (!value) return null;
    return (
      <div className="flex items-center justify-between py-2 border-b border-border/50">
        <span className="text-sm text-muted-foreground">{label}</span>
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{value}</span>
          <Button
            variant="ghost"
            size="icon"
            className="h-6 w-6"
            onClick={() => copyToClipboard(value, fieldKey)}
          >
            {copied === fieldKey ? (
              <Check className="h-3 w-3 text-success" />
            ) : (
              <Copy className="h-3 w-3" />
            )}
          </Button>
        </div>
      </div>
    );
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" className="gap-2">
          <UserSearch className="h-4 w-4" />
          Legal Search
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-5xl max-h-[90vh]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" />
            User Search - Legal Compliance
          </DialogTitle>
          <DialogDescription>
            Search for any user by name, email, or phone number to retrieve complete information for government/police case compliance.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* Search Bar */}
          <div className="flex gap-2">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search by name, email, or phone number..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && searchUsers()}
                className="pl-10"
              />
            </div>
            <Button onClick={searchUsers} disabled={searching}>
              {searching ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Search className="h-4 w-4" />
              )}
              <span className="ml-2">Search</span>
            </Button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 h-[60vh]">
            {/* Results List */}
            <Card className="md:col-span-1">
              <CardHeader className="py-3">
                <CardTitle className="text-sm">Search Results ({results.length})</CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                <ScrollArea className="h-[calc(60vh-60px)]">
                  {results.map((result) => (
                    <div
                      key={result.profile.id}
                      className={`p-3 border-b cursor-pointer hover:bg-muted/50 transition-colors ${
                        selectedUser?.profile.id === result.profile.id ? "bg-muted" : ""
                      }`}
                      onClick={() => setSelectedUser(result)}
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-muted flex items-center justify-center overflow-hidden">
                          {result.profile.photo_url ? (
                            <img
                              src={result.profile.photo_url}
                              alt=""
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            <User className="h-5 w-5 text-muted-foreground" />
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="font-medium truncate">
                            {result.profile.full_name || "No Name"}
                          </p>
                          <p className="text-xs text-muted-foreground truncate">
                            {result.profile.email || result.profile.phone || "No contact"}
                          </p>
                          <div className="flex gap-1 mt-1">
                            <Badge variant="outline" className="text-xs">
                              {result.profile.gender || "Unknown"}
                            </Badge>
                            {result.kyc && (
                              <Badge variant="secondary" className="text-xs">
                                KYC
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                  {results.length === 0 && !searching && (
                    <div className="p-8 text-center text-muted-foreground">
                      <UserSearch className="h-12 w-12 mx-auto mb-2 opacity-50" />
                      <p>Search for users to see results</p>
                    </div>
                  )}
                </ScrollArea>
              </CardContent>
            </Card>

            {/* User Details */}
            <Card className="md:col-span-2">
              <CardContent className="p-0">
                {selectedUser ? (
                  <Tabs defaultValue="profile" className="h-full">
                    <div className="flex items-center justify-between border-b px-4 py-2">
                      <TabsList>
                        <TabsTrigger value="profile">Profile</TabsTrigger>
                        <TabsTrigger value="kyc" disabled={!selectedUser.kyc}>
                          KYC Details
                        </TabsTrigger>
                        <TabsTrigger value="activity">Activity</TabsTrigger>
                      </TabsList>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => exportUserData(selectedUser)}
                      >
                        <Download className="h-4 w-4 mr-1" />
                        Export
                      </Button>
                    </div>

                    <ScrollArea className="h-[calc(60vh-60px)]">
                      {/* Profile Tab */}
                      <TabsContent value="profile" className="p-4 m-0 space-y-4">
                        <div className="flex items-start gap-4">
                          <div className="w-20 h-20 rounded-lg bg-muted overflow-hidden">
                            {selectedUser.profile.photo_url ? (
                              <img
                                src={selectedUser.profile.photo_url}
                                alt=""
                                className="w-full h-full object-cover"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center">
                                <User className="h-8 w-8 text-muted-foreground" />
                              </div>
                            )}
                          </div>
                          <div className="flex-1">
                            <h3 className="text-lg font-semibold">
                              {selectedUser.profile.full_name || "No Name"}
                            </h3>
                            <div className="flex flex-wrap gap-1 mt-1">
                              <Badge>{selectedUser.profile.gender || "Unknown"}</Badge>
                              <Badge variant="outline">{selectedUser.profile.account_status}</Badge>
                              {selectedUser.profile.is_verified && (
                                <Badge variant="secondary">Verified</Badge>
                              )}
                              {selectedUser.profile.is_premium && (
                                <Badge className="bg-primary">Premium</Badge>
                              )}
                            </div>
                          </div>
                        </div>

                        <Separator />

                        {/* Basic Info */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <User className="h-4 w-4" />
                            Basic Information
                          </h4>
                          <div className="space-y-1 text-sm">
                            {renderCopyableField("User ID", selectedUser.profile.user_id, "user_id")}
                            {renderCopyableField("Email", selectedUser.profile.email, "email")}
                            {renderCopyableField("Phone", selectedUser.profile.phone, "phone")}
                            {renderCopyableField("Date of Birth", selectedUser.profile.date_of_birth, "dob")}
                            {renderCopyableField("Age", selectedUser.profile.age?.toString(), "age")}
                          </div>
                        </div>

                        <Separator />

                        {/* Location */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <MapPin className="h-4 w-4" />
                            Location
                          </h4>
                          <div className="space-y-1 text-sm">
                            {renderCopyableField("Country", selectedUser.profile.country, "country")}
                            {renderCopyableField("State", selectedUser.profile.state, "state")}
                            {renderCopyableField("City", selectedUser.profile.city, "city")}
                          </div>
                        </div>

                        <Separator />

                        {/* Lifestyle */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <Heart className="h-4 w-4" />
                            Lifestyle Details
                          </h4>
                          <div className="grid grid-cols-2 gap-2 text-sm">
                            {renderCopyableField("Occupation", selectedUser.profile.occupation, "occupation")}
                            {renderCopyableField("Education", selectedUser.profile.education_level, "education")}
                            {renderCopyableField("Religion", selectedUser.profile.religion, "religion")}
                            {renderCopyableField("Marital Status", selectedUser.profile.marital_status, "marital")}
                            {renderCopyableField("Height (cm)", selectedUser.profile.height_cm?.toString(), "height")}
                            {renderCopyableField("Body Type", selectedUser.profile.body_type, "body")}
                            {renderCopyableField("Smoking", selectedUser.profile.smoking_habit, "smoking")}
                            {renderCopyableField("Drinking", selectedUser.profile.drinking_habit, "drinking")}
                          </div>
                        </div>

                        <Separator />

                        {/* Timestamps */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <Calendar className="h-4 w-4" />
                            Account Timeline
                          </h4>
                          <div className="space-y-1 text-sm">
                            {renderCopyableField(
                              "Created At",
                              selectedUser.profile.created_at
                                ? format(new Date(selectedUser.profile.created_at), "PPpp")
                                : null,
                              "created"
                            )}
                            {renderCopyableField(
                              "Last Active",
                              selectedUser.profile.last_active_at
                                ? format(new Date(selectedUser.profile.last_active_at), "PPpp")
                                : null,
                              "last_active"
                            )}
                          </div>
                        </div>
                      </TabsContent>

                      {/* KYC Tab */}
                      <TabsContent value="kyc" className="p-4 m-0 space-y-4">
                        {selectedUser.kyc ? (
                          <>
                            <div className="p-3 bg-warning/10 border border-warning/30 rounded-lg flex items-center gap-2">
                              <AlertTriangle className="h-5 w-5 text-warning" />
                              <span className="text-sm">
                                Sensitive KYC data - For legal compliance only
                              </span>
                            </div>

                            {/* KYC Status */}
                            <div className="flex items-center gap-2">
                              <Badge
                                variant={
                                  selectedUser.kyc.verification_status === "approved"
                                    ? "default"
                                    : selectedUser.kyc.verification_status === "rejected"
                                    ? "destructive"
                                    : "secondary"
                                }
                              >
                                {selectedUser.kyc.verification_status || "pending"}
                              </Badge>
                              {selectedUser.kyc.consent_given && (
                                <Badge variant="outline">Consent Given</Badge>
                              )}
                            </div>

                            <Separator />

                            {/* Bank Details */}
                            <div>
                              <h4 className="font-medium mb-2 flex items-center gap-2">
                                <Building className="h-4 w-4" />
                                Bank Information
                              </h4>
                              <div className="space-y-1 text-sm">
                                {renderCopyableField("Name (as per bank)", selectedUser.kyc.full_name_as_per_bank, "kyc_name")}
                                {renderCopyableField("Bank Name", selectedUser.kyc.bank_name, "bank_name")}
                                {renderCopyableField("Account Holder", selectedUser.kyc.account_holder_name, "acc_holder")}
                                {renderCopyableField("Account Number", selectedUser.kyc.account_number, "acc_number")}
                                {renderCopyableField("IFSC Code", selectedUser.kyc.ifsc_code, "ifsc")}
                              </div>
                            </div>

                            <Separator />

                            {/* ID Documents */}
                            <div>
                              <h4 className="font-medium mb-2 flex items-center gap-2">
                                <CreditCard className="h-4 w-4" />
                                Identity Documents
                              </h4>
                              <div className="space-y-1 text-sm">
                                {renderCopyableField("ID Type", selectedUser.kyc.id_type, "id_type")}
                                {renderCopyableField("ID Number", selectedUser.kyc.id_number, "id_number")}
                                {renderCopyableField("DOB (KYC)", selectedUser.kyc.date_of_birth, "kyc_dob")}
                                {renderCopyableField("Country of Residence", selectedUser.kyc.country_of_residence, "kyc_country")}
                              </div>
                            </div>

                            <Separator />

                            {/* Document Images */}
                            <div>
                              <h4 className="font-medium mb-2 flex items-center gap-2">
                                <Image className="h-4 w-4" />
                                Uploaded Documents
                              </h4>
                              <div className="grid grid-cols-3 gap-2">
                                {selectedUser.kyc.document_front_url && (
                                  <a
                                    href={selectedUser.kyc.document_front_url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="aspect-video bg-muted rounded-lg overflow-hidden hover:ring-2 ring-primary transition-all"
                                  >
                                    <img
                                      src={selectedUser.kyc.document_front_url}
                                      alt="ID Front"
                                      className="w-full h-full object-cover"
                                    />
                                  </a>
                                )}
                                {selectedUser.kyc.document_back_url && (
                                  <a
                                    href={selectedUser.kyc.document_back_url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="aspect-video bg-muted rounded-lg overflow-hidden hover:ring-2 ring-primary transition-all"
                                  >
                                    <img
                                      src={selectedUser.kyc.document_back_url}
                                      alt="ID Back"
                                      className="w-full h-full object-cover"
                                    />
                                  </a>
                                )}
                                {selectedUser.kyc.selfie_url && (
                                  <a
                                    href={selectedUser.kyc.selfie_url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="aspect-video bg-muted rounded-lg overflow-hidden hover:ring-2 ring-primary transition-all"
                                  >
                                    <img
                                      src={selectedUser.kyc.selfie_url}
                                      alt="Selfie"
                                      className="w-full h-full object-cover"
                                    />
                                  </a>
                                )}
                              </div>
                            </div>

                            <Separator />

                            {/* Consent */}
                            <div>
                              <h4 className="font-medium mb-2 flex items-center gap-2">
                                <FileText className="h-4 w-4" />
                                Consent & Verification
                              </h4>
                              <div className="space-y-1 text-sm">
                                {renderCopyableField(
                                  "Consent Given",
                                  selectedUser.kyc.consent_given ? "Yes" : "No",
                                  "consent"
                                )}
                                {renderCopyableField(
                                  "Consent Timestamp",
                                  selectedUser.kyc.consent_timestamp
                                    ? format(new Date(selectedUser.kyc.consent_timestamp), "PPpp")
                                    : null,
                                  "consent_time"
                                )}
                                {renderCopyableField(
                                  "Verified At",
                                  selectedUser.kyc.verified_at
                                    ? format(new Date(selectedUser.kyc.verified_at), "PPpp")
                                    : null,
                                  "verified_at"
                                )}
                                {selectedUser.kyc.rejection_reason &&
                                  renderCopyableField("Rejection Reason", selectedUser.kyc.rejection_reason, "rejection")}
                              </div>
                            </div>
                          </>
                        ) : (
                          <div className="p-8 text-center text-muted-foreground">
                            <FileText className="h-12 w-12 mx-auto mb-2 opacity-50" />
                            <p>No KYC data available for this user</p>
                          </div>
                        )}
                      </TabsContent>

                      {/* Activity Tab */}
                      <TabsContent value="activity" className="p-4 m-0 space-y-4">
                        {/* Wallet Info */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <Wallet className="h-4 w-4" />
                            Wallet Information
                          </h4>
                          {selectedUser.wallet ? (
                            <div className="grid grid-cols-2 gap-4">
                              <Card>
                                <CardContent className="p-3">
                                  <p className="text-xs text-muted-foreground">Balance</p>
                                  <p className="text-lg font-bold">
                                    {selectedUser.wallet.currency} {selectedUser.wallet.balance.toFixed(2)}
                                  </p>
                                </CardContent>
                              </Card>
                            </div>
                          ) : (
                            <p className="text-sm text-muted-foreground">No wallet data</p>
                          )}
                        </div>

                        <Separator />

                        {/* Chat Stats */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <MessageSquare className="h-4 w-4" />
                            Chat Activity
                          </h4>
                          {selectedUser.chatStats ? (
                            <div className="grid grid-cols-3 gap-4">
                              <Card>
                                <CardContent className="p-3">
                                  <p className="text-xs text-muted-foreground">Messages Sent</p>
                                  <p className="text-lg font-bold">
                                    {selectedUser.chatStats.total_messages_sent}
                                  </p>
                                </CardContent>
                              </Card>
                              <Card>
                                <CardContent className="p-3">
                                  <p className="text-xs text-muted-foreground">Total Chats</p>
                                  <p className="text-lg font-bold">
                                    {selectedUser.chatStats.total_chats}
                                  </p>
                                </CardContent>
                              </Card>
                              <Card>
                                <CardContent className="p-3">
                                  <p className="text-xs text-muted-foreground">Last Chat</p>
                                  <p className="text-sm font-medium">
                                    {selectedUser.chatStats.last_chat_date
                                      ? format(new Date(selectedUser.chatStats.last_chat_date), "PP")
                                      : "Never"}
                                  </p>
                                </CardContent>
                              </Card>
                            </div>
                          ) : (
                            <p className="text-sm text-muted-foreground">No chat data</p>
                          )}
                        </div>

                        <Separator />

                        {/* Performance Metrics */}
                        <div>
                          <h4 className="font-medium mb-2 flex items-center gap-2">
                            <Clock className="h-4 w-4" />
                            Performance Metrics
                          </h4>
                          <div className="space-y-1 text-sm">
                            {renderCopyableField(
                              "Performance Score",
                              selectedUser.profile.performance_score?.toString(),
                              "perf_score"
                            )}
                            {renderCopyableField(
                              "Avg Response Time (sec)",
                              selectedUser.profile.avg_response_time_seconds?.toString(),
                              "resp_time"
                            )}
                            {renderCopyableField(
                              "Profile Completeness",
                              selectedUser.profile.profile_completeness
                                ? `${selectedUser.profile.profile_completeness}%`
                                : null,
                              "completeness"
                            )}
                            {renderCopyableField(
                              "Monthly Chat Minutes",
                              selectedUser.profile.monthly_chat_minutes?.toString(),
                              "chat_mins"
                            )}
                          </div>
                        </div>

                        <Separator />

                        {/* Relationships */}
                        <div>
                          <h4 className="font-medium mb-2">Relationships</h4>
                          <div className="flex gap-4 text-sm">
                            <div>
                              <span className="text-muted-foreground">Friends: </span>
                              <span className="font-medium">{selectedUser.relationships.friends}</span>
                            </div>
                            <div>
                              <span className="text-muted-foreground">Blocked: </span>
                              <span className="font-medium">{selectedUser.relationships.blocked}</span>
                            </div>
                          </div>
                        </div>
                      </TabsContent>
                    </ScrollArea>
                  </Tabs>
                ) : (
                  <div className="h-full flex items-center justify-center text-muted-foreground">
                    <div className="text-center">
                      <User className="h-16 w-16 mx-auto mb-2 opacity-50" />
                      <p>Select a user to view details</p>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default AdminUserSearchDialog;
