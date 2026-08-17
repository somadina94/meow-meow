/**
 * MatchDiscoveryScreen.tsx
 * 
 * PURPOSE: This screen displays potential match candidates based on language compatibility
 * and user preferences. Users can swipe right (like) or left (dislike) on profiles.
 * 
 * KEY FEATURES:
 * - Tinder-style card swiping interface
 * - Language-based matching algorithm
 * - Advanced filtering (age, location, lifestyle, etc.)
 * - Real-time match score calculation
 * - Integration with Supabase for data persistence
 * 
 * DATABASE TABLES USED:
 * - profiles: User profile information
 * - user_languages: Languages spoken by each user
 * - matches: Match records between users
 * - user_status: Online/offline status tracking
 */

// ============= IMPORTS SECTION =============
// React hooks for state management and side effects
import { useState, useEffect, useRef } from "react";
// React Router hook for programmatic navigation
import { useNavigate } from "react-router-dom";
// UI Components from shadcn/ui library
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
// Custom logo component for branding
import MeowLogo from "@/components/MeowLogo";
// Toast hook for displaying notifications to user
import { useToast } from "@/hooks/use-toast";
// Translation hook

// Lucide React icons for visual elements
import { 
  Heart,           // Like button icon
  X,               // Dislike button icon
  ArrowLeft,       // Back navigation icon
  Languages,       // Language indicator icon
  MapPin,          // Location indicator icon
  Loader2,         // Loading spinner icon
  Sparkles,        // Match score sparkle icon
  RefreshCw,       // Refresh button icon
  Eye,             // View profile icon
  Shield,          // Verified badge icon
  Star,            // Premium badge icon
  MoreVertical,    // Actions menu icon
  Home             // Home navigation icon
} from "lucide-react";
// Relationship actions component
import { ChatRelationshipActions } from "@/components/ChatRelationshipActions";
// Supabase client for database operations
import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
// Custom filter panel component and types
import { MatchFiltersPanel, DEFAULT_FILTERS, type MatchFilters } from "@/components/MatchFiltersPanel";
// Badge component for displaying tags
import { Badge } from "@/components/ui/badge";
// Match score calculator
import { calculateMatchScore } from "@/lib/matchScoreCalculator";

/**
 * MatchUser Interface
 * 
 * Defines the shape of a potential match user object.
 * Contains all information needed to display a match card.
 */
interface MatchUser {
  matchId: string;           // Unique identifier for this match record
  userId: string;            // User's UUID from auth.users
  fullName: string;          // Display name of the user
  avatar: string;            // URL to profile photo
  languages: string[];       // Array of languages the user speaks
  country: string;           // User's country of residence
  matchScore: number;        // Calculated compatibility score (0-100)
  commonLanguages: string[]; // Languages shared with current user
  age?: number;              // User's age (optional)
  isVerified?: boolean;      // Whether user passed verification
  isPremium?: boolean;       // Premium subscription status
  isOnline?: boolean;        // Current online status
  bio?: string;              // User's biography text
}

/**
 * MatchDiscoveryScreen Component
 * 
 * Main component that renders the match discovery interface.
 * Handles all match loading, filtering, and user interaction logic.
 */
const MatchDiscoveryScreen = () => {
  // ============= HOOKS INITIALIZATION =============
  
  // Navigation hook for redirecting to other pages
  const navigate = useNavigate();
  
  // Toast hook for showing notification messages
  const { toast } = useToast();

  // Translation hook
  const t = (key: string, def: string) => def;
  
  // ============= STATE DECLARATIONS =============
  
  // Loading state - true while fetching matches from database
  const [isLoading, setIsLoading] = useState(true);
  
  // Array of potential matches fetched from database
  const [matches, setMatches] = useState<MatchUser[]>([]);
  
  // Index of currently displayed match in the matches array
  const [currentIndex, setCurrentIndex] = useState(0);
  
  // Direction of card swipe animation (null when not animating)
  const [swipeDirection, setSwipeDirection] = useState<"left" | "right" | null>(null);
  
  // Current filter settings from the filter panel
  const [filters, setFilters] = useState<MatchFilters>(DEFAULT_FILTERS);
  
  // Available languages for filter dropdown (populated from matches)
  const [availableLanguages, setAvailableLanguages] = useState<string[]>([]);
  
  // Available countries for filter dropdown (populated from matches)
  const [availableCountries, setAvailableCountries] = useState<string[]>([]);
  
  // Current user's gender (used for opposite gender matching)
  const [currentUserGender, setCurrentUserGender] = useState<string>("");
  
  // Current user's country (used for Language feature visibility)
  const [currentUserCountry, setCurrentUserCountry] = useState<string>("");
  
  // Current user's ID for relationship actions
  const [currentUserId, setCurrentUserId] = useState<string>("");
  
  // Reference to the card DOM element for animations
  const cardRef = useRef<HTMLDivElement>(null);

  /**
   * useEffect: Load Matches on Component Mount or Filter Change
   * 
   * This effect runs when:
   * 1. Component first mounts
   * 2. Any filter value changes
   * 
   * It triggers the loadMatches function to fetch fresh match data.
   */
  useEffect(() => {
    loadMatches();
  }, [filters]); // Dependency array: re-run when filters change

  /**
   * loadMatches Function
   * 
   * Fetches potential matches from the database based on:
   * - Opposite gender preference
   * - Language compatibility
   * - Current filter settings
   * 
   * Algorithm:
   * 1. Get current user's profile and languages
   * 2. Build query with all applicable filters
   * 3. Exclude already matched users
   * 4. Calculate match scores for each candidate
   * 5. Sort by match score (highest first)
   */
  const loadMatches = async () => {
    try {
      // Set loading state to show spinner
      setIsLoading(true);
      
      // Get currently authenticated user
      const { data: { session } } = await supabase.auth.getSession();
      
      // If no user logged in, redirect to auth screen
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;

      // ============= FETCH CURRENT USER DATA =============
      
      // Get current user's profile with all fields needed for match calculation
      const { data: currentProfile } = await supabase
        .from("profiles")
        .select("user_id, gender, country, state, preferred_language, interests, education_level, occupation, religion, marital_status, smoking_habit, drinking_habit, dietary_preference, fitness_level, pet_preference, zodiac_sign, age, bio, photo_url")
        .eq("user_id", user.id)
        .maybeSingle(); // Returns null instead of error if not found

      // Also check male_profiles if no main profile exists
      const { data: maleProfile } = await supabase
        .from("male_profiles")
        .select("country, primary_language, preferred_language")
        .eq("user_id", user.id)
        .maybeSingle();

      // Get all languages the current user speaks
      const { data: currentUserLanguages } = await supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", user.id);

      // Extract language names into simple array
      const userLanguages = currentUserLanguages?.map(l => l.language_name) || [];
      
      // Determine user gender - check male_profiles first, then profiles table
      const userGender = maleProfile ? "male" : (currentProfile?.gender?.toLowerCase() || "");
      setCurrentUserGender(userGender);
      setCurrentUserCountry(maleProfile?.country || currentProfile?.country || "");
      setCurrentUserId(user.id);

      // ============= DETERMINE MATCHING GENDER =============
      
      // For heterosexual matching: Males see Females, Females see Males
      const oppositeGender = userGender === "male" ? "female" : 
                            userGender === "female" ? "male" : "";


      // ============= BUILD DATABASE QUERY =============
      
      // Start building the query with all profile fields we need
      // MANDATORY: Only show users with photos
      let profilesQuery = supabase
        .from("profiles")
        .select(`
          user_id, full_name, photo_url, country, state, preferred_language, interests,
          age, height_cm, body_type, education_level, occupation, religion,
          marital_status, has_children, smoking_habit, drinking_habit,
          dietary_preference, fitness_level, pet_preference, travel_frequency,
          personality_type, zodiac_sign, bio, is_verified, is_premium, last_active_at
        `)
        .neq("user_id", user.id) // Exclude current user from results
        .not("photo_url", "is", null)
        .neq("photo_url", ""); // Only users with photos are visible

      // Apply gender filter if we have opposite gender defined
      if (oppositeGender) {
        profilesQuery = profilesQuery.eq("gender", oppositeGender);
      }

      // ============= APPLY DEMOGRAPHIC FILTERS =============
      
      // Country filter - exact match
      if (filters.country !== "all") {
        profilesQuery = profilesQuery.eq("country", filters.country);
      }
      
      // Body type filter
      if (filters.bodyType !== "all") {
        profilesQuery = profilesQuery.eq("body_type", filters.bodyType);
      }
      
      // Education level filter
      if (filters.educationLevel !== "all") {
        profilesQuery = profilesQuery.eq("education_level", filters.educationLevel);
      }
      
      // Occupation filter
      if (filters.occupation !== "all") {
        profilesQuery = profilesQuery.eq("occupation", filters.occupation);
      }
      
      // Religion filter
      if (filters.religion !== "all") {
        profilesQuery = profilesQuery.eq("religion", filters.religion);
      }
      
      // Marital status filter
      if (filters.maritalStatus !== "all") {
        profilesQuery = profilesQuery.eq("marital_status", filters.maritalStatus);
      }
      
      // Has children filter - boolean check
      if (filters.hasChildren === "yes") {
        profilesQuery = profilesQuery.eq("has_children", true);
      } else if (filters.hasChildren === "no") {
        profilesQuery = profilesQuery.eq("has_children", false);
      }

      // ============= APPLY LIFESTYLE FILTERS =============
      
      // Smoking habit filter
      if (filters.smokingHabit !== "all") {
        profilesQuery = profilesQuery.eq("smoking_habit", filters.smokingHabit);
      }
      
      // Drinking habit filter
      if (filters.drinkingHabit !== "all") {
        profilesQuery = profilesQuery.eq("drinking_habit", filters.drinkingHabit);
      }
      
      // Dietary preference filter
      if (filters.dietaryPreference !== "all") {
        profilesQuery = profilesQuery.eq("dietary_preference", filters.dietaryPreference);
      }
      
      // Fitness level filter
      if (filters.fitnessLevel !== "all") {
        profilesQuery = profilesQuery.eq("fitness_level", filters.fitnessLevel);
      }
      
      // Pet preference filter
      if (filters.petPreference !== "all") {
        profilesQuery = profilesQuery.eq("pet_preference", filters.petPreference);
      }
      
      // Travel frequency filter
      if (filters.travelFrequency !== "all") {
        profilesQuery = profilesQuery.eq("travel_frequency", filters.travelFrequency);
      }

      // ============= APPLY PERSONALITY FILTERS =============
      
      // Zodiac sign filter
      if (filters.zodiacSign !== "all") {
        profilesQuery = profilesQuery.eq("zodiac_sign", filters.zodiacSign);
      }
      
      // Personality type filter (e.g., MBTI types)
      if (filters.personalityType !== "all") {
        profilesQuery = profilesQuery.eq("personality_type", filters.personalityType);
      }

      // ============= APPLY SAFETY & BEHAVIOR FILTERS =============
      
      // Only show verified users
      if (filters.verifiedOnly) {
        profilesQuery = profilesQuery.eq("is_verified", true);
      }
      
      // Only show premium users
      if (filters.premiumOnly) {
        profilesQuery = profilesQuery.eq("is_premium", true);
      }
      
      // Only show users with profile photos
      if (filters.hasPhoto) {
        profilesQuery = profilesQuery.not("photo_url", "is", null);
      }
      
      // Only show users with bio text
      if (filters.hasBio) {
        profilesQuery = profilesQuery.not("bio", "is", null);
      }
      
      // Only show users registered in last 7 days
      if (filters.newUsersOnly) {
        const weekAgo = new Date();
        weekAgo.setDate(weekAgo.getDate() - 7);
        profilesQuery = profilesQuery.gte("created_at", weekAgo.toISOString());
      }
      
      // Only show users active in last 5 minutes
      if (filters.onlineNow) {
        const fiveMinutesAgo = new Date();
        fiveMinutesAgo.setMinutes(fiveMinutesAgo.getMinutes() - 5);
        profilesQuery = profilesQuery.gte("last_active_at", fiveMinutesAgo.toISOString());
      }

      // Age range filter (server-side)
      if (filters.ageRange[0] > 18) {
        profilesQuery = profilesQuery.gte("age", filters.ageRange[0]);
      }
      if (filters.ageRange[1] < 60) {
        profilesQuery = profilesQuery.lte("age", filters.ageRange[1]);
      }

      // Height range filter (server-side)
      if (filters.heightRange[0] > 140) {
        profilesQuery = profilesQuery.gte("height_cm", filters.heightRange[0]);
      }
      if (filters.heightRange[1] < 200) {
        profilesQuery = profilesQuery.lte("height_cm", filters.heightRange[1]);
      }

      // Execute the query with a limit to prevent unbounded fetches
      const { data: profiles } = await profilesQuery.limit(100);

      // Handle empty results
      if (!profiles || profiles.length === 0) {
        setMatches([]);
        setIsLoading(false);
        return;
      }

      // ============= EXCLUDE ALREADY MATCHED USERS =============
      
      // Get list of users already matched with current user
      const { data: existingMatches } = await supabase
        .from("matches")
        .select("matched_user_id")
        .eq("user_id", user.id);

      // Convert to Set for O(1) lookup performance
      const matchedUserIds = new Set(existingMatches?.map(m => m.matched_user_id) || []);

      // ============= FETCH ONLINE STATUS FOR ALL PROFILES =============
      
      // Get all user IDs from profiles
      const userIds = profiles.map(p => p.user_id);
      
      // Batch fetch online status
      const { data: onlineStatuses } = await supabase
        .from("user_status")
        .select("user_id, is_online")
        .in("user_id", userIds);

      // Create Map for O(1) lookup of online status
      const onlineStatusMap = new Map(onlineStatuses?.map(s => [s.user_id, s.is_online]) || []);

      // ============= COLLECT FILTER OPTIONS =============
      
      // Sets to collect unique languages and countries for filter dropdowns
      const languagesSet = new Set<string>();
      const countriesSet = new Set<string>();

      // ============= CALCULATE MATCH SCORES =============

      // Pre-filter profiles before processing
      const eligibleProfiles = profiles
        .filter(p => !matchedUserIds.has(p.user_id));

      // Batch-fetch all languages in ONE query instead of N+1
      const eligibleUserIds = eligibleProfiles.map(p => p.user_id);
      const { data: allProfileLanguages } = eligibleUserIds.length > 0
        ? await supabase
            .from("user_languages")
            .select("user_id, language_name")
            .in("user_id", eligibleUserIds)
        : { data: [] };

      // Build a lookup map: user_id -> language_name[]
      const languagesByUserId = new Map<string, string[]>();
      (allProfileLanguages || []).forEach(row => {
        const existing = languagesByUserId.get(row.user_id) || [];
        existing.push(row.language_name);
        languagesByUserId.set(row.user_id, existing);
      });

      // Process each profile synchronously (no more async per-profile)
      const matchedUsers: MatchUser[] = eligibleProfiles.map((profile) => {
        const theirLanguages = languagesByUserId.get(profile.user_id) || [];

        // Add to filter options
        theirLanguages.forEach(l => languagesSet.add(l));
        if (profile.country) countriesSet.add(profile.country);

        // Find common languages between current user and this profile
        const commonLanguages = userLanguages.filter(lang =>
          theirLanguages.includes(lang)
        );

        // Use the centralized match score calculator
        const scoreResult = calculateMatchScore(
          currentProfile || { user_id: user.id },
          {
            user_id: profile.user_id,
            country: profile.country,
            preferred_language: profile.preferred_language,
            interests: profile.interests as string[] | undefined,
            education_level: profile.education_level,
            occupation: profile.occupation,
            religion: profile.religion,
            marital_status: profile.marital_status,
            smoking_habit: profile.smoking_habit,
            drinking_habit: profile.drinking_habit,
            dietary_preference: profile.dietary_preference,
            fitness_level: profile.fitness_level,
            pet_preference: profile.pet_preference,
            zodiac_sign: profile.zodiac_sign,
            age: profile.age,
            bio: profile.bio,
            photo_url: profile.photo_url,
          },
          userLanguages,
          theirLanguages
        );

        const matchScore = scoreResult.totalScore;

        return {
          matchId: `match_${profile.user_id}`,
          userId: profile.user_id,
          fullName: profile.full_name || "Anonymous",
          avatar: profile.photo_url || "",
          languages: theirLanguages,
          country: profile.country || "Unknown",
          matchScore: Math.min(matchScore, 100),
          commonLanguages,
          age: profile.age || undefined,
          isVerified: profile.is_verified || false,
          isPremium: profile.is_premium || false,
          isOnline: onlineStatusMap.get(profile.user_id) || false,
          bio: profile.bio || undefined,
        };
      });

      // Update filter dropdown options
      setAvailableLanguages(Array.from(languagesSet));
      setAvailableCountries(Array.from(countriesSet));

      // ============= APPLY LANGUAGE FILTER =============
      
      let filteredMatches = matchedUsers;
      if (filters.language !== "all") {
        filteredMatches = matchedUsers.filter(m => 
          m.languages.includes(filters.language)
        );
      }

      // ============= SORT BY MATCH SCORE =============
      
      // Sort descending: highest match scores first
      filteredMatches.sort((a, b) => b.matchScore - a.matchScore);

      // Update state with processed matches
      setMatches(filteredMatches);
      setCurrentIndex(0); // Reset to first match
      
    } catch (error) {
      // Log error for debugging
      console.error("Error loading matches:", error);
      toast.error("Matches unavailable", { description: ERROR_MESSAGES.matching.loadFailed });
      
      // Show error toast to user
      toast({
        title: t('error', 'Error'),
        description: t('failedToLoad', 'Failed to load matches'),
        variant: "destructive",
      });
    } finally {
      // Always turn off loading state
      setIsLoading(false);
    }
  };

  /**
   * handleLike Function
   * 
   * Called when user swipes right or taps the like button.
   * Creates a match record in the database and shows animation.
   * 
   * @param matchUser - The user being liked
   */
  const handleLike = async (matchUser: MatchUser) => {
    try {
      // Get current authenticated user
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      // Trigger swipe right animation
      setSwipeDirection("right");

      // ============= CREATE MATCH RECORD =============
      
      // Insert new match into database
      await supabase
        .from("matches")
        .insert({
          user_id: user.id,              // Current user
          matched_user_id: matchUser.userId, // Liked user
          status: "pending",              // Match is pending until other user likes back
          match_score: matchUser.matchScore, // Store calculated match score
        });

      // Show success toast with match score
      toast({
        title: "Liked! 💕",
        description: `Match score: ${matchUser.matchScore}% with ${matchUser.fullName}`,
      });

      // Wait for animation to complete, then move to next match
      setTimeout(() => {
        setSwipeDirection(null); // Reset animation state
        goToNext();              // Move to next match
      }, 300); // 300ms matches CSS animation duration
      
    } catch (error) {
      console.error("Error liking user:", error);
      toast.error("Action failed", { description: "Unable to process that action. Please try again." });
      setSwipeDirection(null); // Reset animation on error
      
      toast({
        title: "Error",
        description: "Failed to send like",
        variant: "destructive",
      });
    }
  };

  /**
   * handleDislike Function
   * 
   * Called when user swipes left or taps the X button.
   * Simply moves to next match without creating a record.
   */
  const handleDislike = () => {
    // Trigger swipe left animation
    setSwipeDirection("left");
    
    // Wait for animation, then move to next
    setTimeout(() => {
      setSwipeDirection(null);
      goToNext();
    }, 300);
  };

  /**
   * goToNext Function
   * 
   * Advances to the next match in the array.
   * Shows message when no more matches available.
   */
  const goToNext = () => {
    if (currentIndex < matches.length - 1) {
      // Move to next match
      setCurrentIndex(prev => prev + 1);
    } else {
      // No more matches - show toast
      toast({
        title: "No more matches",
        description: "Check back later for more recommendations!",
      });
    }
  };

  // Get the currently displayed match
  const currentMatch = matches[currentIndex];

  // ============= LOADING STATE RENDER =============
  
  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          {/* Spinning loader icon */}
          <Loader2 className="w-12 h-12 text-primary animate-spin mx-auto" />
          <p className="text-muted-foreground">Finding your matches...</p>
        </div>
      </div>
    );
  }

  // ============= MAIN RENDER =============
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5">
      {/* ============= HEADER SECTION ============= */}
      <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-lg border-b border-border/50">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
          {/* Back & Home buttons */}
          <div className="flex items-center gap-1">
            <button 
              onClick={() => navigate(-1)}
              className="p-2 rounded-full hover:bg-muted transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-muted-foreground" />
            </button>
            <button 
              onClick={() => navigate("/dashboard")}
              className="p-2 rounded-full hover:bg-muted transition-colors"
            >
              <Home className="w-5 h-5 text-muted-foreground" />
            </button>
          </div>
          
          {/* App logo centered */}
          <MeowLogo size="sm" />
          
          {/* Right side actions */}
          <div className="flex items-center gap-2">
            {/* Advanced Filters Panel - opens filter drawer */}
            <MatchFiltersPanel
              filters={filters}
              onFiltersChange={setFilters}
              userCountry={currentUserCountry}
            />

            {/* Refresh button - reloads matches */}
            <Button 
              variant="ghost" 
              size="icon"
              onClick={loadMatches}
              className="text-muted-foreground hover:text-foreground"
            >
              <RefreshCw className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </header>

      {/* ============= MAIN CONTENT ============= */}
      <main className="max-w-4xl mx-auto px-6 py-8">
        {/* No matches state */}
        {matches.length === 0 ? (
          <Card className="p-12 text-center animate-fade-in">
            {/* Empty state icon */}
            <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-muted flex items-center justify-center">
              <Sparkles className="w-10 h-10 text-muted-foreground" />
            </div>
            <h2 className="text-2xl font-bold text-foreground mb-2">No matches found</h2>
            <p className="text-muted-foreground mb-6">
              Try adjusting your filters or check back later
            </p>
            {/* Action buttons */}
            <div className="flex justify-center gap-3">
              <Button 
                variant="outline" 
                onClick={() => setFilters(DEFAULT_FILTERS)}
              >
                Clear Filters
              </Button>
              <Button variant="gradient" onClick={() => navigate("/dashboard")}>
                Back to Dashboard
              </Button>
            </div>
          </Card>
        ) : (
          <div className="space-y-6">
            {/* ============= PAGE TITLE ============= */}
            <div className="text-center animate-fade-in">
              <h1 className="text-2xl font-bold text-foreground mb-2">Discover Matches</h1>
              <p className="text-muted-foreground">
                {matches.length} potential match{matches.length !== 1 ? "es" : ""} based on language compatibility
              </p>
            </div>

            {/* ============= ACTIVE FILTERS DISPLAY ============= */}
            {/* Show badges for currently active filters */}
            {(filters.language !== "all" || filters.country !== "all" || filters.verifiedOnly || filters.onlineNow) && (
              <div className="flex flex-wrap justify-center gap-2 animate-fade-in">
                {/* Language filter badge */}
                {filters.language !== "all" && (
                  <Badge variant="secondary" className="gap-1">
                    <Languages className="w-3 h-3" />
                    {filters.language}
                  </Badge>
                )}
                {/* Country filter badge */}
                {filters.country !== "all" && (
                  <Badge variant="secondary" className="gap-1">
                    <MapPin className="w-3 h-3" />
                    {filters.country}
                  </Badge>
                )}
                {/* Verified filter badge */}
                {filters.verifiedOnly && (
                  <Badge variant="secondary" className="gap-1">
                    <Shield className="w-3 h-3" />
                    Verified
                  </Badge>
                )}
                {/* Online now filter badge */}
                {filters.onlineNow && (
                  <Badge variant="secondary" className="gap-1 bg-emerald-500/20 text-emerald-600">
                    Online Now
                  </Badge>
                )}
              </div>
            )}

            {/* ============= MATCH CARD ============= */}
            {currentMatch && (
              <div className="flex justify-center animate-fade-in" style={{ animationDelay: "0.1s" }}>
                {/* Animated card container */}
                <div 
                  ref={cardRef}
                  className={`relative w-full max-w-sm transition-all duration-300 ${
                    // Swipe left animation: slide left and rotate
                    swipeDirection === "left" 
                      ? "-translate-x-full rotate-[-20deg] opacity-0" 
                      // Swipe right animation: slide right and rotate
                      : swipeDirection === "right" 
                      ? "translate-x-full rotate-[20deg] opacity-0"
                      : ""
                  }`}
                >
                  <Card className="overflow-hidden shadow-card border-border/50">
                    {/* Match Score Badge - positioned top left */}
                    <div className="absolute top-4 left-4 z-10 flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary text-primary-foreground">
                      <Sparkles className="w-4 h-4" />
                      <span className="text-sm font-bold">{currentMatch.matchScore}% Match</span>
                    </div>

                    {/* ============= AVATAR SECTION ============= */}
                    <div className="relative h-[50vh] max-h-80 sm:max-h-96 bg-gradient-to-br from-muted to-muted/50">
                      {currentMatch.avatar ? (
                        // Profile photo
                        <img 
                          src={currentMatch.avatar} 
                          alt={currentMatch.fullName}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        // Fallback: initial letter avatar
                        <div className="w-full h-full flex items-center justify-center">
                          <span className="text-8xl font-bold text-muted-foreground/30">
                            {currentMatch.fullName.charAt(0).toUpperCase()}
                          </span>
                        </div>
                      )}
                      
                      {/* Gradient overlay for text readability */}
                      <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />
                      
                      {/* User info overlay at bottom */}
                      <div className="absolute bottom-0 left-0 right-0 p-4 sm:p-6 text-white">
                        {/* Name and badges row */}
                        <div className="flex items-center gap-2 mb-2">
                          <h2 className="text-xl sm:text-2xl font-bold">{currentMatch.fullName}</h2>
                          {/* Age display */}
                          {currentMatch.age && (
                            <span className="text-base sm:text-lg opacity-80">{currentMatch.age}</span>
                          )}
                          {/* Verified badge */}
                          {currentMatch.isVerified && (
                            <Shield className="w-4 h-4 sm:w-5 sm:h-5 text-blue-400" />
                          )}
                          {/* Premium badge */}
                          {currentMatch.isPremium && (
                            <Star className="w-4 h-4 sm:w-5 sm:h-5 text-amber-400" />
                          )}
                        </div>
                        
                        {/* Location with online indicator */}
                        <div className="flex items-center gap-2 text-xs sm:text-sm opacity-90 mb-2 sm:mb-3">
                          <MapPin className="w-3 h-3 sm:w-4 sm:h-4" />
                          <span>{currentMatch.country}</span>
                          {/* Online status indicator */}
                          {currentMatch.isOnline && (
                            <span className="flex items-center gap-1 text-emerald-400">
                              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                              Online
                            </span>
                          )}
                        </div>
                        
                        {/* Common languages display */}
                        {currentMatch.commonLanguages.length > 0 && (
                          <div className="flex items-center gap-2">
                            <Languages className="w-3 h-3 sm:w-4 sm:h-4" />
                            <span className="text-xs sm:text-sm">
                              {currentMatch.commonLanguages.join(", ")}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* ============= BIO SECTION ============= */}
                    {currentMatch.bio && (
                      <div className="p-3 sm:p-4 border-t border-border/50">
                        <p className="text-xs sm:text-sm text-muted-foreground line-clamp-2 sm:line-clamp-3">
                          {currentMatch.bio}
                        </p>
                      </div>
                    )}

                    {/* ============= ACTION BUTTONS ============= */}
                    <div className="p-3 sm:p-4 flex justify-center gap-4 sm:gap-6 bg-card">
                      {/* Dislike (X) button */}
                      <Button
                        size="lg"
                        variant="outline"
                        className="w-14 h-14 sm:w-16 sm:h-16 rounded-full border-2 border-destructive/50 hover:bg-destructive/10 hover:border-destructive transition-all"
                        onClick={handleDislike}
                      >
                        <X className="w-6 h-6 sm:w-8 sm:h-8 text-destructive" />
                      </Button>
                      
                      {/* View Profile button */}
                      <Button
                        size="lg"
                        variant="outline"
                        className="w-12 h-12 sm:w-14 sm:h-14 rounded-full border-2 border-muted-foreground/30 hover:bg-muted"
                        onClick={() => navigate(`/profile/${currentMatch.userId}`)}
                      >
                        <Eye className="w-5 h-5 sm:w-6 sm:h-6 text-muted-foreground" />
                      </Button>
                      
                      {/* Relationship Actions (Friend/Block) */}
                      {currentUserId && (
                        <ChatRelationshipActions
                          currentUserId={currentUserId}
                          targetUserId={currentMatch.userId}
                          targetUserName={currentMatch.fullName}
                          onBlock={() => goToNext()}
                          className="w-12 h-12 sm:w-14 sm:h-14 rounded-full border-2 border-muted-foreground/30"
                        />
                      )}
                      
                      {/* Like (Heart) button */}
                      <Button
                        size="lg"
                        variant="outline"
                        className="w-14 h-14 sm:w-16 sm:h-16 rounded-full border-2 border-emerald-500/50 hover:bg-emerald-500/10 hover:border-emerald-500 transition-all"
                        onClick={() => handleLike(currentMatch)}
                      >
                        <Heart className="w-6 h-6 sm:w-8 sm:h-8 text-emerald-500" />
                      </Button>
                    </div>
                  </Card>
                </div>
              </div>
            )}

            {/* ============= MATCH COUNTER ============= */}
            <div className="text-center text-sm text-muted-foreground">
              {currentIndex + 1} of {matches.length} matches
            </div>
          </div>
        )}
      </main>
    </div>
  );
};

// Export component as default for use in router
export default MatchDiscoveryScreen;
