import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
/**
 * ProfileEditDialog Component
 * 
 * A reusable dialog component for editing user profile information.
 * Protected fields (mobile, email, gender) are displayed but not editable.
 * 
 * @module components/ProfileEditDialog
 */

import { useState, useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { supabase } from "@/integrations/supabase/client";
import { Loader2, Lock, User, Calendar, MapPin, Briefcase, Book, Heart, Phone, Camera, Languages, Globe, Check, ChevronsUpDown, KeyRound } from "lucide-react";
import PhoneInputWithCode from "@/components/PhoneInputWithCode";
import { countries } from "@/data/countries";
import { statesByCountry, State } from "@/data/states";
import ProfilePhotosSection from "@/components/ProfilePhotosSection";
import { languages, type Language } from "@/data/languages";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
// ==================== Type Definitions ====================

/**
 * Profile data structure matching the database schema
 */
interface ProfileData {
  full_name: string | null;
  phone: string | null;
  gender: string | null;
  date_of_birth: string | null;
  country: string | null;
  state: string | null;
  bio: string | null;
  occupation: string | null;
  education_level: string | null;
  height_cm: number | null;
  body_type: string | null;
  marital_status: string | null;
  religion: string | null;
  interests: string[] | null;
  life_goals: string[] | null;
  primary_language: string | null;
  // Lifestyle fields
  smoking_habit: string | null;
  drinking_habit: string | null;
  dietary_preference: string | null;
  fitness_level: string | null;
  has_children: boolean | null;
  pet_preference: string | null;
  travel_frequency: string | null;
  personality_type: string | null;
  zodiac_sign: string | null;
}

/**
 * User language data for matching
 */
interface UserLanguage {
  language_name: string;
  language_code: string;
}

/**
 * Props for the ProfileEditDialog component
 */
interface ProfileEditDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onProfileUpdated?: () => void;
}

// ==================== Constants ====================

/**
 * Education level options for dropdown
 */
const EDUCATION_LEVELS = [
  "High School",
  "Some College",
  "Associate Degree",
  "Bachelor's Degree",
  "Master's Degree",
  "Doctorate",
  "Professional Degree",
  "Other"
];

/**
 * Body type options for dropdown
 */
const BODY_TYPES = [
  "Slim",
  "Athletic",
  "Average",
  "Curvy",
  "Plus Size"
];

/**
 * Marital status options for dropdown
 */
const MARITAL_STATUSES = [
  "Single",
  "Married",
  "Divorced",
  "Widowed",
  "Separated"
];

/**
 * Religion options for dropdown
 */
const RELIGIONS = [
  "Hindu",
  "Muslim",
  "Christian",
  "Sikh",
  "Buddhist",
  "Jain",
  "Jewish",
  "Other",
  "Prefer not to say"
];

/**
 * Smoking habit options
 */
const SMOKING_HABITS = ["Never", "Occasionally", "Regularly", "Trying to Quit"];

/**
 * Drinking habit options
 */
const DRINKING_HABITS = ["Never", "Socially", "Occasionally", "Regularly"];

/**
 * Dietary preference options
 */
const DIETARY_PREFERENCES = ["No Preference", "Vegetarian", "Vegan", "Non-Vegetarian", "Eggetarian", "Pescatarian"];

/**
 * Fitness level options
 */
const FITNESS_LEVELS = ["Sedentary", "Light Exercise", "Moderate", "Very Active", "Athlete"];

/**
 * Pet preference options
 */
const PET_PREFERENCES = ["Love Pets", "Have Pets", "No Pets", "Allergic to Pets"];

/**
 * Travel frequency options
 */
const TRAVEL_FREQUENCIES = ["Rarely", "Occasionally", "Frequently", "Love Traveling"];

/**
 * Personality type options
 */
const PERSONALITY_TYPES = ["Introvert", "Extrovert", "Ambivert"];

/**
 * Zodiac sign options
 */
const ZODIAC_SIGNS = [
  "Aries ♈", "Taurus ♉", "Gemini ♊", "Cancer ♋", "Leo ♌", "Virgo ♍",
  "Libra ♎", "Scorpio ♏", "Sagittarius ♐", "Capricorn ♑", "Aquarius ♒", "Pisces ♓"
];

/**
 * Interest options
 */
const INTEREST_OPTIONS = [
  "Music", "Movies", "Travel", "Reading", "Sports", "Cooking", "Photography",
  "Art", "Gaming", "Fitness", "Dancing", "Writing", "Technology", "Fashion",
  "Nature", "Yoga", "Meditation", "Food", "Pets", "Adventure"
];

/**
 * Life goal options
 */
const LIFE_GOAL_OPTIONS = [
  "Career Growth", "Family", "Travel the World", "Financial Freedom", 
  "Health & Fitness", "Education", "Start a Business", "Spiritual Growth",
  "Creative Pursuits", "Community Service", "Finding Love", "Personal Development"
];

// ==================== Component ====================

const ProfileEditDialog = ({ open, onOpenChange, onProfileUpdated }: ProfileEditDialogProps) => {
  const { toast } = useToast();
  const navigate = useNavigate();
  
  // State for profile data
  const [profile, setProfile] = useState<ProfileData>({
    full_name: null,
    phone: null,
    gender: null,
    date_of_birth: null,
    country: null,
    state: null,
    bio: null,
    occupation: null,
    education_level: null,
    height_cm: null,
    body_type: null,
    marital_status: null,
    religion: null,
    interests: null,
    life_goals: null,
    primary_language: null,
    smoking_habit: null,
    drinking_habit: null,
    dietary_preference: null,
    fitness_level: null,
    has_children: null,
    pet_preference: null,
    travel_frequency: null,
    personality_type: null,
    zodiac_sign: null,
  });
  
  // Original profile data to track changes
  const [originalProfile, setOriginalProfile] = useState<ProfileData | null>(null);
  const [originalLanguage, setOriginalLanguage] = useState<UserLanguage | null>(null);
  
  // User's selected language for matching
  const [userLanguage, setUserLanguage] = useState<UserLanguage | null>(null);
  const [languageOpen, setLanguageOpen] = useState(false);
  const [languageSearch, setLanguageSearch] = useState("");
  
  // User email from auth (protected field)
  const [userEmail, setUserEmail] = useState<string>("");
  
  // Current user ID
  const [currentUserId, setCurrentUserId] = useState<string>("");
  
  // Has at least one photo
  const [hasPhotos, setHasPhotos] = useState(true);
  
  // Track if photos were changed (photos save automatically, but we track for UI feedback)
  const [photosChanged, setPhotosChanged] = useState(false);
  
  // Loading states
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  
  // Available states based on selected country
  const [availableStates, setAvailableStates] = useState<State[]>([]);
  
  // Check if there are any changes - use useMemo for reactivity
  const hasChanges = useMemo(() => {
    if (!originalProfile) return false;
    
    // Check profile fields
    const profileChanged = Object.keys(profile).some(key => {
      const k = key as keyof ProfileData;
      const current = profile[k];
      const original = originalProfile[k];
      
      // Handle null/undefined normalization
      const normalizedCurrent = current === undefined ? null : current;
      const normalizedOriginal = original === undefined ? null : original;
      
      // Handle arrays
      if (Array.isArray(normalizedCurrent) && Array.isArray(normalizedOriginal)) {
        return JSON.stringify(normalizedCurrent) !== JSON.stringify(normalizedOriginal);
      }
      
      // Handle null comparisons
      if (normalizedCurrent === null && normalizedOriginal === null) {
        return false;
      }
      
      return normalizedCurrent !== normalizedOriginal;
    });
    
    // Check language change - explicit null checks
    const currentLangCode = userLanguage?.language_code ?? '';
    const originalLangCode = originalLanguage?.language_code ?? '';
    const languageChanged = currentLangCode !== originalLangCode;
    
    return profileChanged || languageChanged;
  }, [profile, originalProfile, userLanguage, originalLanguage]);
  // ==================== Effects ====================

  /**
   * Load profile data when dialog opens
   */
  useEffect(() => {
    if (open) {
      loadProfile();
    }
  }, [open]);

  /**
   * Update available states when country changes
   */
  useEffect(() => {
    // Find the country code from the country name
    const countryData = countries.find(c => c.name === profile.country);
    if (countryData && statesByCountry[countryData.code]) {
      setAvailableStates(statesByCountry[countryData.code]);
    } else {
      setAvailableStates([]);
    }
  }, [profile.country]);

  // ==================== Data Fetching ====================

  /**
   * Load the current user's profile from Supabase
   */
  const loadProfile = async () => {
    setIsLoading(true);
    try {
      // Get authenticated user from session (more reliable than getUser on refresh)
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      // Set user ID and email
      setCurrentUserId(user.id);
      setUserEmail(user.email || "");

      // Always use main profiles table (single source of truth)
      const { data: profileData, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();
      if (error) throw error;
      const data = profileData;

      // Get language from the profile data itself (stored in primary_language/preferred_language)
      // Each profile type has its own language stored independently
      if (data && data.primary_language) {
        // Use master language list
        const foundLang = languages.find(l => l.name === data.primary_language);
        if (foundLang) {
          const langData = {
            language_name: foundLang.name,
            language_code: foundLang.code
          };
          setUserLanguage(langData);
          setOriginalLanguage(langData);
        } else {
          // Language name exists but not in our list - use it anyway
          setUserLanguage({ language_name: data.primary_language, language_code: data.primary_language });
          setOriginalLanguage({ language_name: data.primary_language, language_code: data.primary_language });
        }
      } else {
        setUserLanguage(null);
        setOriginalLanguage(null);
      }

      // Update state with fetched data
      if (data) {
        const profileData: ProfileData = {
          full_name: data.full_name,
          phone: data.phone,
          gender: data.gender,
          date_of_birth: data.date_of_birth,
          country: data.country,
          state: data.state,
          bio: data.bio,
          occupation: data.occupation,
          education_level: data.education_level,
          height_cm: data.height_cm,
          body_type: data.body_type,
          marital_status: data.marital_status,
          religion: data.religion,
          interests: data.interests,
          life_goals: data.life_goals,
          primary_language: data.primary_language,
          smoking_habit: data.smoking_habit,
          drinking_habit: data.drinking_habit,
          dietary_preference: data.dietary_preference,
          fitness_level: data.fitness_level,
          has_children: data.has_children,
          pet_preference: data.pet_preference,
          travel_frequency: data.travel_frequency,
          personality_type: data.personality_type,
          zodiac_sign: data.zodiac_sign,
        };
        setProfile(profileData);
        setOriginalProfile(profileData);
      }
    } catch (error) {
      console.error("Error loading profile:", error);
      toast.error("Profile unavailable", { description: ERROR_MESSAGES.profile.loadFailed });
      toast({
        title: "Error",
        description: "Failed to load profile",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // ==================== Event Handlers ====================

  /**
   * Handle saving profile changes to database
   * Protected fields (phone, gender) are NOT sent to update
   */
  const handleSave = async () => {
    // Client-side validation before saving
    if (profile.full_name && (profile.full_name.trim().length < 2 || profile.full_name.trim().length > 100)) {
      toast({ title: "Invalid Name", description: "Name must be between 2-100 characters", variant: "destructive" });
      return;
    }
    if (profile.bio && profile.bio.trim().length > 500) {
      toast({ title: "Bio too long", description: "Bio must be less than 500 characters", variant: "destructive" });
      return;
    }
    if (profile.height_cm !== null && profile.height_cm !== undefined && (profile.height_cm < 100 || profile.height_cm > 250)) {
      toast({ title: "Invalid Height", description: "Height must be between 100-250 cm", variant: "destructive" });
      return;
    }
    if (profile.occupation && profile.occupation.trim().length > 50) {
      toast({ title: "Occupation too long", description: "Occupation must be less than 50 characters", variant: "destructive" });
      return;
    }

    setIsSaving(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const user = session.user;

      // Sanitize text fields before saving
      const sanitize = (v: string | null) => v ? v.replace(/<[^>]*>/g, "").trim() : v;

      // Note: phone and gender are NOT included as they are protected fields
      const profileData = {
        full_name: sanitize(profile.full_name),
        date_of_birth: profile.date_of_birth,
        country: profile.country,
        state: profile.state,
        bio: sanitize(profile.bio),
        occupation: sanitize(profile.occupation),
        education_level: profile.education_level,
        height_cm: profile.height_cm,
        body_type: profile.body_type,
        marital_status: profile.marital_status,
        religion: profile.religion,
        interests: profile.interests,
        life_goals: profile.life_goals,
        primary_language: userLanguage?.language_name || profile.primary_language,
        preferred_language: userLanguage?.language_name || profile.primary_language,
        smoking_habit: profile.smoking_habit,
        drinking_habit: profile.drinking_habit,
        dietary_preference: profile.dietary_preference,
        fitness_level: profile.fitness_level,
        has_children: profile.has_children,
        pet_preference: profile.pet_preference,
        travel_frequency: profile.travel_frequency,
        personality_type: profile.personality_type,
        zodiac_sign: profile.zodiac_sign,
        updated_at: new Date().toISOString(),
      };

      // Always update main profiles table (single source of truth)
      const { error } = await supabase
        .from("profiles")
        .update({
          ...profileData,
          gender: profile.gender,
        })
        .eq("user_id", user.id);
      if (error) throw error;

      // Also update user_languages table to trigger real-time subscription for dashboard refresh
      if (userLanguage && userLanguage.language_name) {
        console.log("[ProfileEditDialog] Updating user_languages to:", userLanguage.language_name, userLanguage.language_code);
        
        // Delete existing and insert new to ensure proper realtime trigger
        await supabase
          .from("user_languages")
          .delete()
          .eq("user_id", user.id);
        
        const { error: langInsertError } = await supabase
          .from("user_languages")
          .insert({
            user_id: user.id,
            language_name: userLanguage.language_name,
            language_code: userLanguage.language_code
          });
        
        if (langInsertError) {
          console.error("[ProfileEditDialog] Error updating user_languages:", langInsertError);
          toast.error("Language preference not saved", { description: "Your other profile changes were saved, but the language preference update failed. Please try saving again." });
        } else {
          console.log("[ProfileEditDialog] Successfully updated user_languages");
        }

        // Update original language to reflect saved state
        setOriginalLanguage({
          language_name: userLanguage.language_name,
          language_code: userLanguage.language_code
        });
      }

      toast({
        title: "Profile Updated",
        description: "Your changes have been saved successfully",
      });

      // Notify parent component
      onProfileUpdated?.();
      onOpenChange(false);
    } catch (error) {
      console.error("Error saving profile:", error);
      toast.error("Changes not saved", { description: ERROR_MESSAGES.profile.updateFailed });
      toast({
        title: "Error",
        description: "Failed to save profile",
        variant: "destructive",
      });
    } finally {
      setIsSaving(false);
    }
  };

  /**
   * Update a specific field in the profile state
   */
  const updateField = <K extends keyof ProfileData>(field: K, value: ProfileData[K]) => {
    setProfile(prev => ({ ...prev, [field]: value }));
  };

  // ==================== Render ====================

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <User className="w-5 h-5" />
            Edit Profile
          </DialogTitle>
          <DialogDescription>
            Update your profile information. Some fields cannot be changed for security reasons.
          </DialogDescription>
        </DialogHeader>

        {isLoading ? (
          // Loading State
          <div className="flex items-center justify-center py-8">
            <Loader2 className="w-8 h-8 animate-spin text-primary" />
          </div>
        ) : (
          <div className="space-y-6 py-4">
            {/* ==================== Protected Fields Section ==================== */}
            <div className="space-y-4 p-4 bg-muted/50 rounded-lg border border-border">
              <p className="text-sm text-muted-foreground flex items-center gap-2">
                <Lock className="w-4 h-4" />
                These fields cannot be changed for security reasons
              </p>

              {/* Email - Protected */}
              <div className="space-y-2">
                <Label className="text-muted-foreground">Email</Label>
                <Input
                  value={userEmail}
                  disabled
                  className="bg-muted cursor-not-allowed"
                />
              </div>

              {/* Mobile Number - Protected */}
              <div className="space-y-2">
                <Label className="text-muted-foreground flex items-center gap-2">
                  <Phone className="w-4 h-4" />
                  Mobile Number
                </Label>
                <Input
                  value={profile.phone || ""}
                  disabled
                  className="bg-muted cursor-not-allowed"
                />
              </div>

              {/* Gender - Protected */}
              <div className="space-y-2">
                <Label className="text-muted-foreground flex items-center gap-2">
                  <User className="w-4 h-4" />
                  Gender
                </Label>
                <Input
                  value={profile.gender === 'male' ? 'Male' : profile.gender === 'female' ? 'Female' : profile.gender || ''}
                  disabled
                  className="bg-muted cursor-not-allowed capitalize"
                />
              </div>
            </div>

            {/* ==================== Profile Photos Section ==================== */}
            {currentUserId && (
              <div className="space-y-4 p-4 bg-muted/30 rounded-lg border border-border">
                <div className="flex items-center gap-2 text-sm font-medium">
                  <Camera className="w-4 h-4" />
                  Profile Photos & Selfie Verification
                </div>
                <ProfilePhotosSection 
                  userId={currentUserId}
                  expectedGender={(profile.gender === 'male' || profile.gender === 'female') ? profile.gender : undefined}
                  onPhotosChange={(hasAnyPhotos) => {
                    setHasPhotos(hasAnyPhotos);
                    setPhotosChanged(true);
                  }}
                />
              </div>
            )}

            {/* ==================== Editable Fields Section ==================== */}

            {/* ==================== Editable Fields Section ==================== */}
            
            {/* Full Name */}
            <div className="space-y-2">
              <Label htmlFor="full_name" className="flex items-center gap-2">
                <User className="w-4 h-4" />
                Full Name
              </Label>
              <Input
                id="full_name"
                value={profile.full_name || ""}
                onChange={(e) => updateField("full_name", e.target.value)}
                placeholder="Enter your full name"
              />
            </div>

            {/* Date of Birth */}
            <div className="space-y-2">
              <Label htmlFor="dob" className="flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                Date of Birth
              </Label>
              <Input
                id="dob"
                type="date"
                value={profile.date_of_birth || ""}
                onChange={(e) => updateField("date_of_birth", e.target.value)}
              />
            </div>

            {/* Country & State Row */}
            <div className="grid grid-cols-2 gap-4">
              {/* Country */}
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <MapPin className="w-4 h-4" />
                  Country
                </Label>
                <Select
                  value={profile.country || ""}
                  onValueChange={(value) => {
                    updateField("country", value);
                    updateField("state", null); // Reset state when country changes
                  }}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select country" />
                  </SelectTrigger>
                <SelectContent>
                    {countries.map((country) => (
                      <SelectItem key={country.code} value={country.name}>
                        {country.flag} {country.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* State */}
              <div className="space-y-2">
                <Label>State/Province</Label>
                <Select
                  value={profile.state || ""}
                  onValueChange={(value) => updateField("state", value)}
                  disabled={!availableStates.length}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select state" />
                  </SelectTrigger>
                <SelectContent>
                    {availableStates.map((state) => (
                      <SelectItem key={state.code} value={state.name}>
                        {state.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* ==================== Language Selection (for Matching) ==================== */}
            <div className="space-y-3 p-4 bg-primary/5 rounded-lg border border-primary/20">
              <Label className="flex items-center gap-2 text-sm font-medium">
                <Languages className="w-4 h-4 text-primary" />
                My Language (for Chat Matching)
              </Label>
              <p className="text-xs text-muted-foreground">
                Select your primary language from {languages.length}+ languages. Auto-translation is available.
              </p>
              
              <Popover open={languageOpen} onOpenChange={setLanguageOpen}>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={languageOpen}
                    className="w-full justify-between bg-background"
                  >
                    {userLanguage ? (
                      <span className="flex items-center gap-2">
                        <Globe className="w-4 h-4 text-primary" />
                        {userLanguage.language_name}
                      </span>
                    ) : (
                      <span className="text-muted-foreground">Select your language...</span>
                    )}
                    <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-[400px] p-0 bg-popover z-50" align="start">
                  <Command className="bg-popover">
                    <CommandInput 
                      placeholder="Search from 842 languages..." 
                      value={languageSearch}
                      onValueChange={setLanguageSearch}
                    />
                    <CommandList className="max-h-80">
                      <CommandEmpty>No language found. Try searching by name.</CommandEmpty>
                      
                      {/* Show filtered results - increased limit */}
                      <CommandGroup heading={`🌐 Languages (${languages.filter(l => 
                        !languageSearch || 
                        l.name.toLowerCase().includes(languageSearch.toLowerCase()) || 
                        l.nativeName.toLowerCase().includes(languageSearch.toLowerCase())
                      ).length} available)`}>
                        {languages
                          .filter(l => 
                            !languageSearch || 
                            l.name.toLowerCase().includes(languageSearch.toLowerCase()) || 
                            l.nativeName.toLowerCase().includes(languageSearch.toLowerCase())
                          )
                          .slice(0, 100)
                          .map((lang) => (
                            <CommandItem
                              key={lang.code}
                              value={`${lang.name} ${lang.nativeName}`}
                              onSelect={() => {
                                setUserLanguage({
                                  language_name: lang.name,
                                  language_code: lang.code
                                });
                                setLanguageOpen(false);
                                setLanguageSearch("");
                              }}
                              className="cursor-pointer"
                            >
                              <Check className={cn("mr-2 h-4 w-4 shrink-0", userLanguage?.language_code === lang.code ? "opacity-100" : "opacity-0")} />
                              <span className="flex-1 truncate">{lang.name}</span>
                              <span className="text-xs text-muted-foreground ml-2 truncate">{lang.nativeName}</span>
                            </CommandItem>
                          ))}
                      </CommandGroup>
                      
                      {!languageSearch && (
                        <div className="p-2 text-xs text-center text-muted-foreground border-t">
                          Type to search all 842 languages
                        </div>
                      )}
                    </CommandList>
                  </Command>
                </PopoverContent>
              </Popover>

              {userLanguage && (
                <div className="flex items-center gap-2">
                  <Badge variant="secondary" className="text-xs">
                    <Globe className="w-3 h-3 mr-1" />
                    Auto-translation enabled
                  </Badge>
                  <span className="text-xs text-muted-foreground">
                    Connect with users in any language
                  </span>
                </div>
              )}
            </div>

            {/* Occupation */}
            <div className="space-y-2">
              <Label htmlFor="occupation" className="flex items-center gap-2">
                <Briefcase className="w-4 h-4" />
                Occupation
              </Label>
              <Input
                id="occupation"
                value={profile.occupation || ""}
                onChange={(e) => updateField("occupation", e.target.value)}
                placeholder="Enter your occupation"
              />
            </div>

            {/* Education Level */}
            <div className="space-y-2">
              <Label className="flex items-center gap-2">
                <Book className="w-4 h-4" />
                Education Level
              </Label>
              <Select
                value={profile.education_level || ""}
                onValueChange={(value) => updateField("education_level", value)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select education level" />
                </SelectTrigger>
                <SelectContent>
                  {EDUCATION_LEVELS.map((level) => (
                    <SelectItem key={level} value={level}>
                      {level}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Physical Attributes Row */}
            <div className="grid grid-cols-2 gap-4">
              {/* Height */}
              <div className="space-y-2">
                <Label htmlFor="height">Height (cm)</Label>
                <Input
                  id="height"
                  type="number"
                  value={profile.height_cm || ""}
                  onChange={(e) => updateField("height_cm", e.target.value ? parseInt(e.target.value) : null)}
                  placeholder="e.g., 170"
                  min={100}
                  max={250}
                />
              </div>

              {/* Body Type */}
              <div className="space-y-2">
                <Label>Body Type</Label>
                <Select
                  value={profile.body_type || ""}
                  onValueChange={(value) => updateField("body_type", value)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select body type" />
                  </SelectTrigger>
                  <SelectContent>
                    {BODY_TYPES.map((type) => (
                      <SelectItem key={type} value={type}>
                        {type}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Personal Details Row */}
            <div className="grid grid-cols-2 gap-4">
              {/* Marital Status */}
              <div className="space-y-2">
                <Label className="flex items-center gap-2">
                  <Heart className="w-4 h-4" />
                  Marital Status
                </Label>
                <Select
                  value={profile.marital_status || ""}
                  onValueChange={(value) => updateField("marital_status", value)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    {MARITAL_STATUSES.map((status) => (
                      <SelectItem key={status} value={status}>
                        {status}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Religion */}
              <div className="space-y-2">
                <Label>Religion</Label>
                <Select
                  value={profile.religion || ""}
                  onValueChange={(value) => updateField("religion", value)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select religion" />
                  </SelectTrigger>
                  <SelectContent>
                    {RELIGIONS.map((religion) => (
                      <SelectItem key={religion} value={religion}>
                        {religion}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Bio */}
            <div className="space-y-2">
              <Label htmlFor="bio">About Me</Label>
              <Textarea
                id="bio"
                value={profile.bio || ""}
                onChange={(e) => updateField("bio", e.target.value)}
                placeholder="Tell others about yourself..."
                rows={4}
                maxLength={500}
              />
              <p className="text-xs text-muted-foreground text-right">
                {(profile.bio?.length || 0)}/500 characters
              </p>
            </div>

            {/* ==================== Lifestyle Section ==================== */}
            <div className="space-y-4 p-4 bg-muted/30 rounded-lg border border-border">
              <h3 className="text-sm font-semibold text-foreground">Lifestyle</h3>
              
              {/* Smoking & Drinking */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs">Smoking</Label>
                  <Select
                    value={profile.smoking_habit || ""}
                    onValueChange={(value) => updateField("smoking_habit", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {SMOKING_HABITS.map((habit) => (
                        <SelectItem key={habit} value={habit.toLowerCase()}>
                          {habit}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label className="text-xs">Drinking</Label>
                  <Select
                    value={profile.drinking_habit || ""}
                    onValueChange={(value) => updateField("drinking_habit", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {DRINKING_HABITS.map((habit) => (
                        <SelectItem key={habit} value={habit.toLowerCase()}>
                          {habit}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Diet & Fitness */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs">Diet</Label>
                  <Select
                    value={profile.dietary_preference || ""}
                    onValueChange={(value) => updateField("dietary_preference", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {DIETARY_PREFERENCES.map((diet) => (
                        <SelectItem key={diet} value={diet.toLowerCase().replace(/ /g, '_')}>
                          {diet}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label className="text-xs">Fitness Level</Label>
                  <Select
                    value={profile.fitness_level || ""}
                    onValueChange={(value) => updateField("fitness_level", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {FITNESS_LEVELS.map((level) => (
                        <SelectItem key={level} value={level.toLowerCase().replace(/ /g, '_')}>
                          {level}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Pets & Travel */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs">Pets</Label>
                  <Select
                    value={profile.pet_preference || ""}
                    onValueChange={(value) => updateField("pet_preference", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {PET_PREFERENCES.map((pref) => (
                        <SelectItem key={pref} value={pref.toLowerCase().replace(/ /g, '_')}>
                          {pref}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label className="text-xs">Travel</Label>
                  <Select
                    value={profile.travel_frequency || ""}
                    onValueChange={(value) => updateField("travel_frequency", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {TRAVEL_FREQUENCIES.map((freq) => (
                        <SelectItem key={freq} value={freq.toLowerCase().replace(/ /g, '_')}>
                          {freq}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Has Children */}
              <div className="space-y-2">
                <Label className="text-xs">Do you have children?</Label>
                <div className="flex gap-2">
                  <Button
                    type="button"
                    variant={profile.has_children === true ? "default" : "outline"}
                    size="sm"
                    className="flex-1"
                    onClick={() => updateField("has_children", profile.has_children === true ? null : true)}
                  >
                    Yes
                  </Button>
                  <Button
                    type="button"
                    variant={profile.has_children === false ? "default" : "outline"}
                    size="sm"
                    className="flex-1"
                    onClick={() => updateField("has_children", profile.has_children === false ? null : false)}
                  >
                    No
                  </Button>
                </div>
              </div>

              {/* Personality & Zodiac */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs">Personality</Label>
                  <Select
                    value={profile.personality_type || ""}
                    onValueChange={(value) => updateField("personality_type", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {PERSONALITY_TYPES.map((type) => (
                        <SelectItem key={type} value={type.toLowerCase()}>
                          {type}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label className="text-xs">Zodiac Sign</Label>
                  <Select
                    value={profile.zodiac_sign || ""}
                    onValueChange={(value) => updateField("zodiac_sign", value)}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      {ZODIAC_SIGNS.map((sign) => (
                        <SelectItem key={sign} value={sign.split(' ')[0].toLowerCase()}>
                          {sign}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </div>

            {/* ==================== Interests Section ==================== */}
            <div className="space-y-3">
              <Label className="text-sm font-medium">Interests (select up to 10)</Label>
              <div className="flex flex-wrap gap-2">
                {INTEREST_OPTIONS.map((interest) => {
                  const isSelected = profile.interests?.includes(interest);
                  return (
                    <Button
                      key={interest}
                      type="button"
                      variant={isSelected ? "default" : "outline"}
                      size="sm"
                      className="text-xs"
                      onClick={() => {
                        const current = profile.interests || [];
                        if (isSelected) {
                          updateField("interests", current.filter(i => i !== interest));
                        } else if (current.length < 10) {
                          updateField("interests", [...current, interest]);
                        }
                      }}
                    >
                      {interest}
                    </Button>
                  );
                })}
              </div>
              <p className="text-xs text-muted-foreground">
                {(profile.interests?.length || 0)}/10 selected
              </p>
            </div>

            {/* ==================== Life Goals Section ==================== */}
            <div className="space-y-3">
              <Label className="text-sm font-medium">Life Goals (select up to 5)</Label>
              <div className="flex flex-wrap gap-2">
                {LIFE_GOAL_OPTIONS.map((goal) => {
                  const isSelected = profile.life_goals?.includes(goal);
                  return (
                    <Button
                      key={goal}
                      type="button"
                      variant={isSelected ? "default" : "outline"}
                      size="sm"
                      className="text-xs"
                      onClick={() => {
                        const current = profile.life_goals || [];
                        if (isSelected) {
                          updateField("life_goals", current.filter(g => g !== goal));
                        } else if (current.length < 5) {
                          updateField("life_goals", [...current, goal]);
                        }
                      }}
                    >
                      {goal}
                    </Button>
                  );
                })}
              </div>
              <p className="text-xs text-muted-foreground">
                {(profile.life_goals?.length || 0)}/5 selected
              </p>
            </div>

            {/* ==================== Password Reset Section ==================== */}
            <div className="space-y-4 p-4 bg-muted/30 rounded-lg border border-border">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <KeyRound className="w-4 h-4 text-muted-foreground" />
                  <div>
                    <Label className="text-sm font-medium">Reset Password</Label>
                    <p className="text-xs text-muted-foreground">
                      Send a password reset link to your email
                    </p>
                  </div>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    navigate('/forgot-password');
                  }}
                >
                  <KeyRound className="w-4 h-4 mr-2" />
                  Reset
                </Button>
              </div>
            </div>

            {/* ==================== Action Buttons ==================== */}
            <div className="flex justify-end gap-3 pt-4 border-t">
              <Button
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={isSaving}
              >
                Cancel
              </Button>
              <Button
                onClick={handleSave}
                disabled={isSaving || (!hasChanges && !photosChanged)}
                title={!hasChanges && !photosChanged ? "No changes to save" : ""}
              >
                {isSaving ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Saving...
                  </>
                ) : photosChanged && !hasChanges ? (
                  "Close"
                ) : (
                  "Save Changes"
                )}
              </Button>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
};

export default ProfileEditDialog;
