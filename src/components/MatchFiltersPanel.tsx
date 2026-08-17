import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Slider } from "@/components/ui/slider";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
} from "@/components/ui/sheet";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Filter,
  User,
  Heart,
  Dumbbell,
  Utensils,
  Wine,
  Cigarette,
  Plane,
  PawPrint,
  Sparkles,
  Shield,
  Clock,
  Star,
  GraduationCap,
  Briefcase,
  Languages,
  MapPin,
  X,
  Check,
  ChevronsUpDown,
  Navigation,
} from "lucide-react";
import { countries } from "@/data/countries";
import { 
  ALL_SUPPORTED_LANGUAGES, 
  INDIAN_LANGUAGES, 
  NON_INDIAN_LANGUAGES,
  type SupportedLanguage 
} from "@/data/supportedLanguages";
import { cn } from "@/lib/utils";

export interface MatchFilters {
  // Demographic
  ageRange: [number, number];
  heightRange: [number, number];
  bodyType: string;
  educationLevel: string;
  occupation: string;
  religion: string;
  maritalStatus: string;
  hasChildren: string;
  
  // Location & Language
  country: string;
  language: string;
  distanceRange: [number, number];
  
  // Lifestyle
  smokingHabit: string;
  drinkingHabit: string;
  dietaryPreference: string;
  fitnessLevel: string;
  petPreference: string;
  travelFrequency: string;
  
  // Personality
  zodiacSign: string;
  personalityType: string;
  
  // App Behavior
  onlineNow: boolean;
  verifiedOnly: boolean;
  premiumOnly: boolean;
  newUsersOnly: boolean;
  hasPhoto: boolean;
  hasBio: boolean;
}

const DEFAULT_FILTERS: MatchFilters = {
  ageRange: [18, 60],
  heightRange: [140, 200],
  bodyType: "all",
  educationLevel: "all",
  occupation: "all",
  religion: "all",
  maritalStatus: "all",
  hasChildren: "all",
  country: "all",
  language: "all",
  distanceRange: [0, 15000],
  smokingHabit: "all",
  drinkingHabit: "all",
  dietaryPreference: "all",
  fitnessLevel: "all",
  petPreference: "all",
  travelFrequency: "all",
  zodiacSign: "all",
  personalityType: "all",
  onlineNow: false,
  verifiedOnly: false,
  premiumOnly: false,
  newUsersOnly: false,
  hasPhoto: false,
  hasBio: false,
};

const BODY_TYPES = ["Slim", "Athletic", "Average", "Curvy", "Muscular", "Plus Size"];
const EDUCATION_LEVELS = ["High School", "Diploma", "Bachelor's", "Master's", "PhD", "Other"];
const RELIGIONS = ["Hindu", "Muslim", "Christian", "Sikh", "Buddhist", "Jain", "Jewish", "Atheist", "Other"];
const MARITAL_STATUSES = ["Single", "Divorced", "Widowed", "Separated"];
const SMOKING_HABITS = ["Never", "Occasionally", "Regularly"];
const DRINKING_HABITS = ["Never", "Socially", "Occasionally", "Regularly"];
const DIETARY_PREFERENCES = ["No Preference", "Vegetarian", "Vegan", "Non-Vegetarian", "Pescatarian", "Keto", "Halal", "Kosher"];
const FITNESS_LEVELS = ["Sedentary", "Light", "Moderate", "Active", "Very Active"];
const PET_PREFERENCES = ["Dogs", "Cats", "Both", "Other Pets", "No Pets", "Allergic"];
const TRAVEL_FREQUENCIES = ["Rarely", "Occasionally", "Frequently", "Digital Nomad"];
const ZODIAC_SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
const PERSONALITY_TYPES = ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"];

interface MatchFiltersPanelProps {
  filters: MatchFilters;
  onFiltersChange: (filters: MatchFilters) => void;
  userCountry?: string; // User's country for showing Language feature (India only)
}

export function MatchFiltersPanel({
  filters,
  onFiltersChange,
  userCountry = "",
}: MatchFiltersPanelProps) {
  // Check if user is from India to show language feature
  const isIndianUser = userCountry.toLowerCase() === "india";
  const [isOpen, setIsOpen] = useState(false);
  const [localFilters, setLocalFilters] = useState<MatchFilters>(filters);
  const [countryOpen, setCountryOpen] = useState(false);
  const [languageOpen, setLanguageOpen] = useState(false);
  const [countrySearch, setCountrySearch] = useState("");
  const [languageSearch, setLanguageSearch] = useState("");

  // All countries
  const allCountries = countries.map(c => ({ name: c.name, flag: c.flag }));

  // Supported languages (grouped by Indian/Non-Indian)
  const allSupportedLanguages = ALL_SUPPORTED_LANGUAGES;

  // Filter based on search
  const filteredCountries = allCountries.filter(c =>
    c.name.toLowerCase().includes(countrySearch.toLowerCase())
  );
  const filteredIndianLanguages = INDIAN_LANGUAGES.filter(l =>
    l.name.toLowerCase().includes(languageSearch.toLowerCase())
  );
  const filteredNonIndianLanguages = NON_INDIAN_LANGUAGES.filter(l =>
    l.name.toLowerCase().includes(languageSearch.toLowerCase())
  );

  const activeFilterCount = Object.entries(localFilters).filter(([key, value]) => {
    if (key === "ageRange") return value[0] !== 18 || value[1] !== 60;
    if (key === "heightRange") return value[0] !== 140 || value[1] !== 200;
    if (key === "distanceRange") return value[0] !== 0 || value[1] !== 15000;
    if (typeof value === "boolean") return value === true;
    if (typeof value === "string") return value !== "all";
    return false;
  }).length;

  const handleApply = () => {
    onFiltersChange(localFilters);
    setIsOpen(false);
  };

  const handleReset = () => {
    setLocalFilters(DEFAULT_FILTERS);
    onFiltersChange(DEFAULT_FILTERS);
  };

  const updateFilter = <K extends keyof MatchFilters>(key: K, value: MatchFilters[K]) => {
    setLocalFilters(prev => ({ ...prev, [key]: value }));
  };

  return (
    <Sheet open={isOpen} onOpenChange={setIsOpen}>
      <SheetTrigger asChild>
        <Button variant="outline" size="sm" className="gap-2 relative">
          <Filter className="w-4 h-4" />
          Filters
          {activeFilterCount > 0 && (
            <Badge variant="default" className="absolute -top-2 -right-2 h-5 w-5 p-0 flex items-center justify-center text-[10px]">
              {activeFilterCount}
            </Badge>
          )}
        </Button>
      </SheetTrigger>
      <SheetContent className="w-full sm:max-w-md p-0 flex flex-col">
        <SheetHeader className="px-6 py-4 border-b">
          <div className="flex items-center justify-between">
            <SheetTitle className="flex items-center gap-2">
              <Filter className="w-5 h-5 text-primary" />
              Match Filters
            </SheetTitle>
            {activeFilterCount > 0 && (
              <Button variant="ghost" size="sm" onClick={handleReset} className="text-muted-foreground">
                <X className="w-4 h-4 mr-1" />
                Reset All
              </Button>
            )}
          </div>
        </SheetHeader>

        <ScrollArea className="flex-1 px-6">
          <Accordion type="multiple" defaultValue={["demographic", "lifestyle", "behavior"]} className="w-full py-4">
            
            {/* 1. Demographic Filters */}
            <AccordionItem value="demographic">
              <AccordionTrigger className="text-sm font-semibold">
                <div className="flex items-center gap-2">
                  <User className="w-4 h-4 text-primary" />
                  Demographic Filters
                </div>
              </AccordionTrigger>
              <AccordionContent className="space-y-5 pt-4">
                {/* Age Range */}
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <Label className="text-sm">Age Range</Label>
                    <span className="text-sm text-muted-foreground">
                      {localFilters.ageRange[0]} - {localFilters.ageRange[1]} years
                    </span>
                  </div>
                  <Slider
                    value={localFilters.ageRange}
                    onValueChange={(value) => updateFilter("ageRange", value as [number, number])}
                    min={18}
                    max={60}
                    step={1}
                    className="w-full"
                  />
                </div>

                {/* Height Range */}
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <Label className="text-sm">Height Range</Label>
                    <span className="text-sm text-muted-foreground">
                      {localFilters.heightRange[0]} - {localFilters.heightRange[1]} cm
                    </span>
                  </div>
                  <Slider
                    value={localFilters.heightRange}
                    onValueChange={(value) => updateFilter("heightRange", value as [number, number])}
                    min={140}
                    max={200}
                    step={1}
                    className="w-full"
                  />
                </div>

                {/* Body Type */}
                <div className="space-y-2">
                  <Label className="text-sm">Body Type</Label>
                  <Select value={localFilters.bodyType} onValueChange={(v) => updateFilter("bodyType", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {BODY_TYPES.map(type => (
                        <SelectItem key={type} value={type.toLowerCase()}>{type}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Education */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <GraduationCap className="w-4 h-4" />
                    Education Level
                  </Label>
                  <Select value={localFilters.educationLevel} onValueChange={(v) => updateFilter("educationLevel", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {EDUCATION_LEVELS.map(level => (
                        <SelectItem key={level} value={level.toLowerCase()}>{level}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Occupation */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Briefcase className="w-4 h-4" />
                    Occupation
                  </Label>
                  <Select value={localFilters.occupation} onValueChange={(v) => updateFilter("occupation", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      <SelectItem value="tech">Technology</SelectItem>
                      <SelectItem value="healthcare">Healthcare</SelectItem>
                      <SelectItem value="business">Business</SelectItem>
                      <SelectItem value="education">Education</SelectItem>
                      <SelectItem value="arts">Arts & Creative</SelectItem>
                      <SelectItem value="finance">Finance</SelectItem>
                      <SelectItem value="government">Government</SelectItem>
                      <SelectItem value="other">Other</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {/* Religion */}
                <div className="space-y-2">
                  <Label className="text-sm">Religion</Label>
                  <Select value={localFilters.religion} onValueChange={(v) => updateFilter("religion", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {RELIGIONS.map(r => (
                        <SelectItem key={r} value={r.toLowerCase()}>{r}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Marital Status */}
                <div className="space-y-2">
                  <Label className="text-sm">Marital Status</Label>
                  <Select value={localFilters.maritalStatus} onValueChange={(v) => updateFilter("maritalStatus", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {MARITAL_STATUSES.map(status => (
                        <SelectItem key={status} value={status.toLowerCase()}>{status}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Has Children */}
                <div className="space-y-2">
                  <Label className="text-sm">Children</Label>
                  <Select value={localFilters.hasChildren} onValueChange={(v) => updateFilter("hasChildren", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      <SelectItem value="no">No Children</SelectItem>
                      <SelectItem value="yes">Has Children</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </AccordionContent>
            </AccordionItem>

            {/* 2. Location & Language */}
            <AccordionItem value="location">
              <AccordionTrigger className="text-sm font-semibold">
                <div className="flex items-center gap-2">
                  <MapPin className="w-4 h-4 text-primary" />
                  Location & Language
                </div>
              </AccordionTrigger>
              <AccordionContent className="space-y-5 pt-4">
                {/* Distance Range */}
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <Label className="text-sm flex items-center gap-2">
                      <Navigation className="w-4 h-4" />
                      Distance Range
                    </Label>
                    <span className="text-sm text-muted-foreground">
                      {localFilters.distanceRange[0].toLocaleString()} - {localFilters.distanceRange[1].toLocaleString()} km
                    </span>
                  </div>
                  <Slider
                    value={localFilters.distanceRange}
                    onValueChange={(value) => updateFilter("distanceRange", value as [number, number])}
                    min={0}
                    max={15000}
                    step={100}
                    className="w-full"
                  />
                  <div className="flex justify-between text-xs text-muted-foreground">
                    <span>0 km</span>
                    <span>15,000 km</span>
                  </div>
                </div>

                {/* Country - Searchable */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <MapPin className="w-4 h-4" />
                    Country
                  </Label>
                  <Popover open={countryOpen} onOpenChange={setCountryOpen}>
                    <PopoverTrigger asChild>
                      <Button
                        variant="outline"
                        role="combobox"
                        aria-expanded={countryOpen}
                        className="w-full justify-between bg-background"
                      >
                        {localFilters.country === "all" 
                          ? "All Countries" 
                          : allCountries.find(c => c.name === localFilters.country)
                            ? `${allCountries.find(c => c.name === localFilters.country)?.flag} ${localFilters.country}`
                            : localFilters.country}
                        <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                      </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-full p-0 bg-popover z-50" align="start">
                      <Command className="bg-popover">
                        <CommandInput 
                          placeholder="Search country..." 
                          value={countrySearch}
                          onValueChange={setCountrySearch}
                        />
                        <CommandList className="max-h-60">
                          <CommandEmpty>No country found.</CommandEmpty>
                          <CommandGroup>
                            <CommandItem
                              value="all"
                              onSelect={() => {
                                updateFilter("country", "all");
                                setCountryOpen(false);
                                setCountrySearch("");
                              }}
                            >
                              <Check className={cn("mr-2 h-4 w-4", localFilters.country === "all" ? "opacity-100" : "opacity-0")} />
                              🌍 All Countries
                            </CommandItem>
                            {filteredCountries.slice(0, 50).map((country) => (
                              <CommandItem
                                key={country.name}
                                value={country.name}
                                onSelect={() => {
                                  updateFilter("country", country.name);
                                  setCountryOpen(false);
                                  setCountrySearch("");
                                }}
                              >
                                <Check className={cn("mr-2 h-4 w-4", localFilters.country === country.name ? "opacity-100" : "opacity-0")} />
                                {country.flag} {country.name}
                              </CommandItem>
                            ))}
                          </CommandGroup>
                        </CommandList>
                      </Command>
                    </PopoverContent>
                  </Popover>
                </div>

                {/* Language filter removed - language is now set in Profile for matching */}
              </AccordionContent>
            </AccordionItem>

            {/* 3. Lifestyle & Interests */}
            <AccordionItem value="lifestyle">
              <AccordionTrigger className="text-sm font-semibold">
                <div className="flex items-center gap-2">
                  <Heart className="w-4 h-4 text-primary" />
                  Lifestyle & Interests
                </div>
              </AccordionTrigger>
              <AccordionContent className="space-y-5 pt-4">
                {/* Smoking */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Cigarette className="w-4 h-4" />
                    Smoking
                  </Label>
                  <Select value={localFilters.smokingHabit} onValueChange={(v) => updateFilter("smokingHabit", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {SMOKING_HABITS.map(h => (
                        <SelectItem key={h} value={h.toLowerCase()}>{h}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Drinking */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Wine className="w-4 h-4" />
                    Drinking
                  </Label>
                  <Select value={localFilters.drinkingHabit} onValueChange={(v) => updateFilter("drinkingHabit", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {DRINKING_HABITS.map(h => (
                        <SelectItem key={h} value={h.toLowerCase()}>{h}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Diet */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Utensils className="w-4 h-4" />
                    Dietary Preference
                  </Label>
                  <Select value={localFilters.dietaryPreference} onValueChange={(v) => updateFilter("dietaryPreference", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {DIETARY_PREFERENCES.map(d => (
                        <SelectItem key={d} value={d.toLowerCase().replace(' ', '_')}>{d}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Fitness */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Dumbbell className="w-4 h-4" />
                    Fitness Level
                  </Label>
                  <Select value={localFilters.fitnessLevel} onValueChange={(v) => updateFilter("fitnessLevel", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {FITNESS_LEVELS.map(f => (
                        <SelectItem key={f} value={f.toLowerCase()}>{f}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Pets */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <PawPrint className="w-4 h-4" />
                    Pet Preference
                  </Label>
                  <Select value={localFilters.petPreference} onValueChange={(v) => updateFilter("petPreference", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {PET_PREFERENCES.map(p => (
                        <SelectItem key={p} value={p.toLowerCase().replace(' ', '_')}>{p}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Travel */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Plane className="w-4 h-4" />
                    Travel Frequency
                  </Label>
                  <Select value={localFilters.travelFrequency} onValueChange={(v) => updateFilter("travelFrequency", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {TRAVEL_FREQUENCIES.map(t => (
                        <SelectItem key={t} value={t.toLowerCase().replace(' ', '_')}>{t}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </AccordionContent>
            </AccordionItem>

            {/* 4. Personality & Values */}
            <AccordionItem value="personality">
              <AccordionTrigger className="text-sm font-semibold">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-primary" />
                  Personality & Values
                </div>
              </AccordionTrigger>
              <AccordionContent className="space-y-5 pt-4">
                {/* Zodiac */}
                <div className="space-y-2">
                  <Label className="text-sm flex items-center gap-2">
                    <Star className="w-4 h-4" />
                    Zodiac Sign
                  </Label>
                  <Select value={localFilters.zodiacSign} onValueChange={(v) => updateFilter("zodiacSign", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {ZODIAC_SIGNS.map(z => (
                        <SelectItem key={z} value={z.toLowerCase()}>{z}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Personality Type */}
                <div className="space-y-2">
                  <Label className="text-sm">Personality Type (MBTI)</Label>
                  <Select value={localFilters.personalityType} onValueChange={(v) => updateFilter("personalityType", v)}>
                    <SelectTrigger><SelectValue placeholder="Any" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Any</SelectItem>
                      {PERSONALITY_TYPES.map(p => (
                        <SelectItem key={p} value={p.toLowerCase()}>{p}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </AccordionContent>
            </AccordionItem>

            {/* 5. App Behavior & Safety */}
            <AccordionItem value="behavior">
              <AccordionTrigger className="text-sm font-semibold">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-primary" />
                  App Behavior & Safety
                </div>
              </AccordionTrigger>
              <AccordionContent className="space-y-4 pt-4">
                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    <Clock className="w-4 h-4 text-emerald-500" />
                    Online Now
                  </Label>
                  <Switch
                    checked={localFilters.onlineNow}
                    onCheckedChange={(v) => updateFilter("onlineNow", v)}
                  />
                </div>

                <Separator />

                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    <Shield className="w-4 h-4 text-blue-500" />
                    Verified Only
                  </Label>
                  <Switch
                    checked={localFilters.verifiedOnly}
                    onCheckedChange={(v) => updateFilter("verifiedOnly", v)}
                  />
                </div>

                <Separator />

                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    <Star className="w-4 h-4 text-amber-500" />
                    Premium Members Only
                  </Label>
                  <Switch
                    checked={localFilters.premiumOnly}
                    onCheckedChange={(v) => updateFilter("premiumOnly", v)}
                  />
                </div>

                <Separator />

                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    <Sparkles className="w-4 h-4 text-pink-500" />
                    New Users Only
                  </Label>
                  <Switch
                    checked={localFilters.newUsersOnly}
                    onCheckedChange={(v) => updateFilter("newUsersOnly", v)}
                  />
                </div>

                <Separator />

                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    With Photo
                  </Label>
                  <Switch
                    checked={localFilters.hasPhoto}
                    onCheckedChange={(v) => updateFilter("hasPhoto", v)}
                  />
                </div>

                <Separator />

                <div className="flex items-center justify-between">
                  <Label className="text-sm flex items-center gap-2 cursor-pointer">
                    With Bio
                  </Label>
                  <Switch
                    checked={localFilters.hasBio}
                    onCheckedChange={(v) => updateFilter("hasBio", v)}
                  />
                </div>
              </AccordionContent>
            </AccordionItem>

          </Accordion>
        </ScrollArea>

        <SheetFooter className="px-6 py-4 border-t gap-3">
          <Button variant="outline" onClick={handleReset} className="flex-1">
            Reset
          </Button>
          <Button variant="gradient" onClick={handleApply} className="flex-1">
            Apply Filters
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}

export { DEFAULT_FILTERS };
export type { MatchFilters as FilterState };
