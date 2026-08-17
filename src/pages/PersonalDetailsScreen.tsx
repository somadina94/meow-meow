import { useState, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, User, Ruler, Briefcase, GraduationCap, Heart, Utensils, Dumbbell, Baby, PawPrint, Plane, Brain, Star, Wine, Cigarette } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import MeowLogo from "@/components/MeowLogo";
import ProgressIndicator from "@/components/ProgressIndicator";
import ScreenTitle from "@/components/ScreenTitle";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import SearchableSelect from "@/components/SearchableSelect";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

// Options for various fields
const bodyTypeOptions = [
  { value: "slim", label: "Slim", icon: "🏃" },
  { value: "athletic", label: "Athletic", icon: "💪" },
  { value: "average", label: "Average", icon: "👤" },
  { value: "curvy", label: "Curvy", icon: "🌸" },
  { value: "plus_size", label: "Plus Size", icon: "🤗" },
];

const educationOptions = [
  { value: "high_school", label: "High School" },
  { value: "some_college", label: "Some College" },
  { value: "bachelors", label: "Bachelor's Degree" },
  { value: "masters", label: "Master's Degree" },
  { value: "doctorate", label: "Doctorate" },
  { value: "other", label: "Other" },
];

const maritalStatusOptions = [
  { value: "single", label: "Single" },
  { value: "married", label: "Married" },
  { value: "divorced", label: "Divorced" },
  { value: "widowed", label: "Widowed" },
  { value: "separated", label: "Separated" },
];

const religionOptions = [
  { value: "hindu", label: "Hindu" },
  { value: "muslim", label: "Muslim" },
  { value: "christian", label: "Christian" },
  { value: "sikh", label: "Sikh" },
  { value: "buddhist", label: "Buddhist" },
  { value: "jain", label: "Jain" },
  { value: "jewish", label: "Jewish" },
  { value: "other", label: "Other" },
  { value: "none", label: "No Religion" },
  { value: "prefer_not_to_say", label: "Prefer not to say" },
];

const smokingOptions = [
  { value: "never", label: "Never" },
  { value: "occasionally", label: "Occasionally" },
  { value: "regularly", label: "Regularly" },
  { value: "trying_to_quit", label: "Trying to Quit" },
];

const drinkingOptions = [
  { value: "never", label: "Never" },
  { value: "socially", label: "Socially" },
  { value: "occasionally", label: "Occasionally" },
  { value: "regularly", label: "Regularly" },
];

const dietaryOptions = [
  { value: "no_preference", label: "No Preference" },
  { value: "vegetarian", label: "Vegetarian" },
  { value: "vegan", label: "Vegan" },
  { value: "non_vegetarian", label: "Non-Vegetarian" },
  { value: "eggetarian", label: "Eggetarian" },
  { value: "pescatarian", label: "Pescatarian" },
];

const fitnessOptions = [
  { value: "sedentary", label: "Sedentary" },
  { value: "light", label: "Light Exercise" },
  { value: "moderate", label: "Moderate" },
  { value: "active", label: "Very Active" },
  { value: "athlete", label: "Athlete" },
];

const petOptions = [
  { value: "love_pets", label: "Love Pets" },
  { value: "have_pets", label: "Have Pets" },
  { value: "no_pets", label: "No Pets" },
  { value: "allergic", label: "Allergic to Pets" },
];

const travelOptions = [
  { value: "rarely", label: "Rarely" },
  { value: "occasionally", label: "Occasionally" },
  { value: "frequently", label: "Frequently" },
  { value: "love_traveling", label: "Love Traveling" },
];

const personalityOptions = [
  { value: "introvert", label: "Introvert" },
  { value: "extrovert", label: "Extrovert" },
  { value: "ambivert", label: "Ambivert" },
];

const zodiacOptions = [
  { value: "aries", label: "Aries ♈" },
  { value: "taurus", label: "Taurus ♉" },
  { value: "gemini", label: "Gemini ♊" },
  { value: "cancer", label: "Cancer ♋" },
  { value: "leo", label: "Leo ♌" },
  { value: "virgo", label: "Virgo ♍" },
  { value: "libra", label: "Libra ♎" },
  { value: "scorpio", label: "Scorpio ♏" },
  { value: "sagittarius", label: "Sagittarius ♐" },
  { value: "capricorn", label: "Capricorn ♑" },
  { value: "aquarius", label: "Aquarius ♒" },
  { value: "pisces", label: "Pisces ♓" },
];

const interestOptions = [
  "Music", "Movies", "Travel", "Reading", "Sports", "Cooking", "Photography",
  "Art", "Gaming", "Fitness", "Dancing", "Writing", "Technology", "Fashion",
  "Nature", "Yoga", "Meditation", "Food", "Pets", "Adventure"
];

const lifeGoalOptions = [
  "Career Growth", "Family", "Travel the World", "Financial Freedom", 
  "Health & Fitness", "Education", "Start a Business", "Spiritual Growth",
  "Creative Pursuits", "Community Service", "Finding Love", "Personal Development"
];

const PersonalDetailsScreen = () => {
  const navigate = useNavigate();
  useRegistrationGuard([{ key: "userEmail" }, { key: "userGender" }], "/basic-info");
  
  // Form state
  const [bio, setBio] = useState("");
  const [heightCm, setHeightCm] = useState("");
  const [occupation, setOccupation] = useState("");
  const [bodyType, setBodyType] = useState("");
  const [education, setEducation] = useState("");
  const [maritalStatus, setMaritalStatus] = useState("");
  const [religion, setReligion] = useState("");
  const [smokingHabit, setSmokingHabit] = useState("");
  const [drinkingHabit, setDrinkingHabit] = useState("");
  const [dietaryPreference, setDietaryPreference] = useState("");
  const [fitnessLevel, setFitnessLevel] = useState("");
  const [hasChildren, setHasChildren] = useState<boolean | null>(null);
  const [petPreference, setPetPreference] = useState("");
  const [travelFrequency, setTravelFrequency] = useState("");
  const [personalityType, setPersonalityType] = useState("");
  const [zodiacSign, setZodiacSign] = useState("");
  const [selectedInterests, setSelectedInterests] = useState<string[]>([]);
  const [selectedLifeGoals, setSelectedLifeGoals] = useState<string[]>([]);

  const toggleInterest = (interest: string) => {
    setSelectedInterests(prev => 
      prev.includes(interest) 
        ? prev.filter(i => i !== interest)
        : prev.length < 10 ? [...prev, interest] : prev
    );
  };

  const toggleLifeGoal = (goal: string) => {
    setSelectedLifeGoals(prev => 
      prev.includes(goal) 
        ? prev.filter(g => g !== goal)
        : prev.length < 5 ? [...prev, goal] : prev
    );
  };

  // Minimum required fields for a non-blank profile
  const requiredFieldsFilled = bio.trim().length >= 10 && occupation.trim() && maritalStatus;
  const completedFieldsCount = [
    bio.trim(), heightCm, occupation.trim(), bodyType, education,
    maritalStatus, religion, smokingHabit, drinkingHabit,
    dietaryPreference, fitnessLevel, petPreference,
    travelFrequency, personalityType, zodiacSign,
    hasChildren !== null ? "yes" : "",
    selectedInterests.length > 0 ? "yes" : "",
    selectedLifeGoals.length > 0 ? "yes" : "",
  ].filter(Boolean).length;

  const handleNext = (skip = false) => {
    if (!skip) {
      // Validate minimum required fields
      if (!bio.trim() || bio.trim().length < 10) {
        toast({
          title: "Bio is required",
          description: "Please write at least 10 characters about yourself.",
          variant: "destructive",
        });
        return;
      }
      if (!occupation.trim()) {
        toast({
          title: "Occupation is required",
          description: "Please enter your occupation.",
          variant: "destructive",
        });
        return;
      }
      if (!maritalStatus) {
        toast({
          title: "Marital status is required",
          description: "Please select your marital status.",
          variant: "destructive",
        });
        return;
      }
    }

    // Store all personal details
    const personalDetails = {
      bio: bio.trim(),
      height_cm: heightCm ? parseInt(heightCm) : null,
      occupation: occupation.trim(),
      body_type: bodyType,
      education_level: education,
      marital_status: maritalStatus,
      religion,
      smoking_habit: smokingHabit,
      drinking_habit: drinkingHabit,
      dietary_preference: dietaryPreference,
      fitness_level: fitnessLevel,
      has_children: hasChildren,
      pet_preference: petPreference,
      travel_frequency: travelFrequency,
      personality_type: personalityType,
      zodiac_sign: zodiacSign,
      interests: selectedInterests,
      life_goals: selectedLifeGoals,
      profile_completeness: Math.round((completedFieldsCount / 18) * 100),
    };

    sessionStorage.setItem("userPersonalDetails", JSON.stringify(personalDetails));

    toast({
      title: skip ? "Skipped for now" : "Details saved! ✨",
      description: "Let's upload your photos next.",
    });

    navigate("/photo-upload");
  };

  const handleBack = () => {
    navigate("/basic-info");
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      {/* Aurora Background */}
      <Suspense fallback={
        <div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />
      }>
        <AuroraBackground />
      </Suspense>
      
      {/* Header */}
      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex items-center gap-4 mb-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={handleBack}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={3} totalSteps={10} />
          </div>
        </div>
      </header>

      {/* Main Content - Scrollable */}
      <main className="flex-1 overflow-y-auto px-6 pb-8 relative z-10">
        <div className="max-w-lg mx-auto">
          {/* Title */}
          <ScreenTitle
            title="Personal Details"
            subtitle="Share more about yourself (optional but helps matching)"
            logoSize="sm"
            className="mb-6"
          />

          {/* Form */}
          <div className="space-y-6 bg-card/70 backdrop-blur-xl rounded-3xl p-6 border border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
            
            {/* Bio */}
            <div className="space-y-2">
              <Label className="flex items-center gap-2 text-sm font-semibold">
                <User className="w-4 h-4 text-primary" />
                About Me
              </Label>
              <Textarea
                placeholder="Write a short bio about yourself..."
                value={bio}
                onChange={(e) => setBio(e.target.value.slice(0, 500))}
                className="min-h-[100px] resize-none"
                maxLength={500}
              />
              <p className="text-xs text-muted-foreground text-right">{bio.length}/500</p>
            </div>

            {/* Height & Occupation Row */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="flex items-center gap-2 text-sm font-semibold">
                  <Ruler className="w-4 h-4 text-primary" />
                  Height (cm)
                </Label>
                <Input
                  type="number"
                  placeholder="170"
                  value={heightCm}
                  onChange={(e) => {
                    const val = e.target.value;
                    // Only allow valid height range
                    if (val === "" || (Number(val) >= 0 && Number(val) <= 250)) {
                      setHeightCm(val);
                    }
                  }}
                  onBlur={() => {
                    if (heightCm && (Number(heightCm) < 100 || Number(heightCm) > 250)) {
                      setHeightCm("");
                      toast({ title: "Invalid height", description: "Height must be between 100-250 cm", variant: "destructive" });
                    }
                  }}
                  min="100"
                  max="250"
                  inputMode="numeric"
                />
              </div>
              <div className="space-y-2">
                <Label className="flex items-center gap-2 text-sm font-semibold">
                  <Briefcase className="w-4 h-4 text-primary" />
                  Occupation
                </Label>
                <Input
                  placeholder="Software Engineer"
                  value={occupation}
                  onChange={(e) => setOccupation(e.target.value)}
                  maxLength={50}
                />
              </div>
            </div>

            {/* Body Type */}
            <div className="space-y-2">
              <Label className="text-sm font-semibold">Body Type</Label>
              <div className="flex flex-wrap gap-2">
                {bodyTypeOptions.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setBodyType(bodyType === opt.value ? "" : opt.value)}
                    className={cn(
                      "px-4 py-2 rounded-full text-sm border-2 transition-all",
                      bodyType === opt.value
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-input bg-background/50 hover:border-primary/50"
                    )}
                  >
                    {opt.icon} {opt.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Education */}
            <div className="space-y-2">
              <Label className="flex items-center gap-2 text-sm font-semibold">
                <GraduationCap className="w-4 h-4 text-primary" />
                Education
              </Label>
              <SearchableSelect
                options={educationOptions}
                value={education}
                onChange={setEducation}
                placeholder="Select education level"
              />
            </div>

            {/* Marital Status & Religion Row */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="flex items-center gap-2 text-sm font-semibold">
                  <Heart className="w-4 h-4 text-primary" />
                  Marital Status
                </Label>
                <SearchableSelect
                  options={maritalStatusOptions}
                  value={maritalStatus}
                  onChange={setMaritalStatus}
                  placeholder="Select status"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-sm font-semibold">Religion</Label>
                <SearchableSelect
                  options={religionOptions}
                  value={religion}
                  onChange={setReligion}
                  placeholder="Select religion"
                />
              </div>
            </div>

            {/* Lifestyle Section */}
            <div className="pt-4 border-t border-border/50">
              <h3 className="text-sm font-semibold text-foreground mb-4">Lifestyle</h3>
              
              {/* Smoking & Drinking */}
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Cigarette className="w-3 h-3 text-primary" />
                    Smoking
                  </Label>
                  <SearchableSelect
                    options={smokingOptions}
                    value={smokingHabit}
                    onChange={setSmokingHabit}
                    placeholder="Select"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Wine className="w-3 h-3 text-primary" />
                    Drinking
                  </Label>
                  <SearchableSelect
                    options={drinkingOptions}
                    value={drinkingHabit}
                    onChange={setDrinkingHabit}
                    placeholder="Select"
                  />
                </div>
              </div>

              {/* Diet & Fitness */}
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Utensils className="w-3 h-3 text-primary" />
                    Diet
                  </Label>
                  <SearchableSelect
                    options={dietaryOptions}
                    value={dietaryPreference}
                    onChange={setDietaryPreference}
                    placeholder="Select"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Dumbbell className="w-3 h-3 text-primary" />
                    Fitness
                  </Label>
                  <SearchableSelect
                    options={fitnessOptions}
                    value={fitnessLevel}
                    onChange={setFitnessLevel}
                    placeholder="Select"
                  />
                </div>
              </div>

              {/* Children */}
              <div className="space-y-2 mb-4">
                <Label className="flex items-center gap-2 text-xs">
                  <Baby className="w-3 h-3 text-primary" />
                  Do you have children?
                </Label>
                <div className="flex gap-2">
                  {[
                    { value: true, label: "Yes" },
                    { value: false, label: "No" },
                  ].map((opt) => (
                    <button
                      key={String(opt.value)}
                      type="button"
                      onClick={() => setHasChildren(hasChildren === opt.value ? null : opt.value)}
                      className={cn(
                        "flex-1 px-4 py-2 rounded-xl text-sm border-2 transition-all",
                        hasChildren === opt.value
                          ? "border-primary bg-primary/10 text-primary"
                          : "border-input bg-background/50 hover:border-primary/50"
                      )}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Pets & Travel */}
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <PawPrint className="w-3 h-3 text-primary" />
                    Pets
                  </Label>
                  <SearchableSelect
                    options={petOptions}
                    value={petPreference}
                    onChange={setPetPreference}
                    placeholder="Select"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Plane className="w-3 h-3 text-primary" />
                    Travel
                  </Label>
                  <SearchableSelect
                    options={travelOptions}
                    value={travelFrequency}
                    onChange={setTravelFrequency}
                    placeholder="Select"
                  />
                </div>
              </div>

              {/* Personality & Zodiac */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Brain className="w-3 h-3 text-primary" />
                    Personality
                  </Label>
                  <SearchableSelect
                    options={personalityOptions}
                    value={personalityType}
                    onChange={setPersonalityType}
                    placeholder="Select"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2 text-xs">
                    <Star className="w-3 h-3 text-primary" />
                    Zodiac
                  </Label>
                  <SearchableSelect
                    options={zodiacOptions}
                    value={zodiacSign}
                    onChange={setZodiacSign}
                    placeholder="Select"
                  />
                </div>
              </div>
            </div>

            {/* Interests */}
            <div className="pt-4 border-t border-border/50">
              <Label className="text-sm font-semibold mb-3 block">
                Interests (select up to 10)
              </Label>
              <div className="flex flex-wrap gap-2">
                {interestOptions.map((interest) => (
                  <button
                    key={interest}
                    type="button"
                    onClick={() => toggleInterest(interest)}
                    className={cn(
                      "px-3 py-1.5 rounded-full text-xs border transition-all",
                      selectedInterests.includes(interest)
                        ? "border-primary bg-primary/20 text-primary"
                        : "border-input bg-background/50 hover:border-primary/50"
                    )}
                  >
                    {interest}
                  </button>
                ))}
              </div>
              <p className="text-xs text-muted-foreground mt-2">
                {selectedInterests.length}/10 selected
              </p>
            </div>

            {/* Life Goals */}
            <div className="pt-4 border-t border-border/50">
              <Label className="text-sm font-semibold mb-3 block">
                Life Goals (select up to 5)
              </Label>
              <div className="flex flex-wrap gap-2">
                {lifeGoalOptions.map((goal) => (
                  <button
                    key={goal}
                    type="button"
                    onClick={() => toggleLifeGoal(goal)}
                    className={cn(
                      "px-3 py-1.5 rounded-full text-xs border transition-all",
                      selectedLifeGoals.includes(goal)
                        ? "border-accent bg-accent/20 text-accent-foreground"
                        : "border-input bg-background/50 hover:border-accent/50"
                    )}
                  >
                    {goal}
                  </button>
                ))}
              </div>
              <p className="text-xs text-muted-foreground mt-2">
                {selectedLifeGoals.length}/5 selected
              </p>
            </div>
          </div>

          {/* Continue Button */}
          <div className="mt-6 space-y-3">
            <Button
              variant="aurora"
              size="xl"
              className="w-full group"
              onClick={() => handleNext(false)}
              disabled={!requiredFieldsFilled}
            >
              Continue ({completedFieldsCount}/18 fields)
            </Button>
            <Button
              variant="ghost"
              className="w-full text-muted-foreground"
              onClick={() => handleNext(true)}
            >
              Skip for now
            </Button>
          </div>
        </div>
      </main>
    </div>
  );
};

export default PersonalDetailsScreen;
