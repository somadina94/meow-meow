import { useState, useEffect, useCallback, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import MeowLogo from "@/components/MeowLogo";
import ProgressIndicator from "@/components/ProgressIndicator";
import { useToast } from "@/hooks/use-toast";
import { MapPin, Navigation, Loader2, Globe, ArrowLeft } from "lucide-react";
import SearchableSelect from "@/components/SearchableSelect";
import { countries } from "@/data/countries";
import { getStatesForCountry, hasStates } from "@/data/states";
import { supabase } from "@/integrations/supabase/client";
import { isIndianCountry, NON_INDIA_ERROR } from "@/lib/indianValidation";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

const LocationSetupScreen = () => {
  const navigate = useNavigate();
  useRegistrationGuard([{ key: "userEmail" }, { key: "userGender" }], "/basic-info");
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);
  const [isDetecting, setIsDetecting] = useState(false);
  const [locationDetected, setLocationDetected] = useState(false);
  const [pinDropped, setPinDropped] = useState(false);
  
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [country, setCountry] = useState("");
  const [state, setState] = useState("");
  const [village, setVillage] = useState("");
  const [manualMode, setManualMode] = useState(false);

  const countryOptions = countries.map(c => ({
    value: c.code,
    label: c.name,
    icon: c.flag
  }));

  const stateOptions = country ? getStatesForCountry(country).map(s => ({
    value: s.code,
    label: s.name
  })) : [];

  const countryHasStates = country ? hasStates(country) : false;

  // Reset state and village when country changes
  const handleCountryChange = (newCountry: string) => {
    setCountry(newCountry);
    setState("");
    setVillage("");
  };

  const reverseGeocode = async (lat: number, lng: number, retries = 2): Promise<{ countryCode: string; stateValue: string; villageValue: string } | null> => {
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        // Rate-limit: wait 1.1s before retries to respect Nominatim's 1 req/sec limit
        if (attempt > 0) {
          await new Promise((resolve) => setTimeout(resolve, 1100 * attempt));
        }

        const response = await fetch(
          `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&addressdetails=1&accept-language=en`,
          {
            headers: {
              'User-Agent': 'MeowMeow-App/1.0'
            }
          }
        );

        if (response.status === 429) {
          console.warn(`Nominatim rate limited (attempt ${attempt + 1}/${retries + 1})`);
          if (attempt < retries) continue;
          throw new Error('Rate limit exceeded');
        }

        if (!response.ok) throw new Error(`Geocoding failed: ${response.status}`);

        const data = await response.json();
        const address = data.address || {};

        const countryCode = address.country_code?.toUpperCase() || "";
        const stateValue = address.state || address.province || address.region || "";
        const villageValue = address.village || address.town || address.city ||
                            address.municipality || address.suburb || address.neighbourhood || "";

        return { countryCode, stateValue, villageValue };
      } catch (error) {
        if (attempt === retries) {
          console.error('Reverse geocoding error:', error);
          toast.error('Location lookup failed', { description: 'Unable to determine your location name. Please enter it manually.' });
          return null;
        }
      }
    }
    return null;
  };

  const detectLocation = useCallback(async () => {
    if (!navigator.geolocation) {
      toast({
        title: "Geolocation not supported",
        description: "Your browser doesn't support location detection. Please enter manually.",
        variant: "destructive",
      });
      setManualMode(true);
      return;
    }

    setIsDetecting(true);
    
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        
        setLatitude(lat);
        setLongitude(lng);
        
        // Use OpenStreetMap Nominatim for reverse geocoding
        const geocodeResult = await reverseGeocode(lat, lng);
        
        if (geocodeResult) {
          const { countryCode, stateValue, villageValue } = geocodeResult;
          
          // Auto-fill country if found in our country list
          const matchedCountry = countries.find(c => c.code === countryCode);
          if (matchedCountry) {
            setCountry(matchedCountry.code);
            
            // Try to match state
            if (stateValue) {
              const statesForCountry = getStatesForCountry(matchedCountry.code);
              const matchedState = statesForCountry.find(
                s => s.name.toLowerCase() === stateValue.toLowerCase() ||
                     s.code.toLowerCase() === stateValue.toLowerCase()
              );
              if (matchedState) {
                setState(matchedState.code);
              } else {
                setState(stateValue);
              }
            }
          }
          
          // Set village/town
          if (villageValue) {
            setVillage(villageValue);
          }
          
          toast({
            title: "Location detected",
            description: villageValue 
              ? `Found: ${villageValue}${stateValue ? `, ${stateValue}` : ''}`
              : "Location found. Please verify below.",
          });
        } else {
          toast({
            title: "Location detected",
            description: "Please select your country and state below.",
          });
        }
        
        setLocationDetected(true);
        
        // Trigger pin drop animation
        setTimeout(() => {
          setPinDropped(true);
        }, 500);
        
        setIsDetecting(false);
      },
      (error) => {
        console.error("Geolocation error:", error);
        toast({
          title: "Location detection failed",
          description: "Please enter your location manually.",
          variant: "destructive",
        });
        setManualMode(true);
        setIsDetecting(false);
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0
      }
    );
  }, [toast]);

  const handleSubmit = async () => {
    if (!country) {
      toast({
        title: "Country required",
        description: "Please select your country.",
        variant: "destructive",
      });
      return;
    }

    if (!isIndianCountry(country)) {
      toast({ ...NON_INDIA_ERROR, variant: "destructive" });
      return;
    }

    // Save location data to localStorage for later use during account creation
    sessionStorage.setItem("userCountry", country);
    sessionStorage.setItem("userState", state || "");
    sessionStorage.setItem("userCity", village || "");
    if (latitude) sessionStorage.setItem("userLatitude", latitude.toString());
    if (longitude) sessionStorage.setItem("userLongitude", longitude.toString());

    toast({
      title: "Location saved",
      description: "Your location has been saved.",
    });

    navigate("/language-preferences");
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
            onClick={() => navigate("/photo-upload")}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={6} totalSteps={10} />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6 relative z-10">
        <Card className="w-full max-w-lg p-8 space-y-8 bg-card/70 backdrop-blur-xl border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 mb-4">
              <Globe className="w-8 h-8 text-primary" />
            </div>
            <h1 className="text-2xl font-display font-bold text-foreground">Your Location</h1>
            <p className="text-muted-foreground">
              Help us personalize your experience
            </p>
          </div>

          {/* Map Placeholder */}
          <div 
            className={`relative w-full h-48 rounded-xl overflow-hidden bg-gradient-to-br from-primary/20 via-accent/10 to-secondary/20 border border-border/50 transition-all duration-700 ${
              locationDetected ? 'scale-100' : 'scale-95 opacity-80'
            }`}
          >
            {/* Grid pattern for map effect */}
            <div className="absolute inset-0 opacity-30">
              <svg className="w-full h-full" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
                    <path d="M 20 0 L 0 0 0 20" fill="none" stroke="currentColor" strokeWidth="0.5" className="text-primary/30" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#grid)" />
              </svg>
            </div>

            {/* Animated circles for location effect */}
            {locationDetected && (
              <>
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="w-32 h-32 rounded-full bg-primary/10 animate-ping" style={{ animationDuration: '2s' }} />
                </div>
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="w-24 h-24 rounded-full bg-primary/20 animate-pulse" />
                </div>
              </>
            )}

            {/* Location Pin with drop animation */}
            <div 
              className={`absolute inset-0 flex items-center justify-center transition-all duration-500 ${
                pinDropped 
                  ? 'translate-y-0 opacity-100' 
                  : locationDetected 
                    ? '-translate-y-full opacity-0' 
                    : 'opacity-50'
              }`}
            >
              <div className={`relative ${pinDropped ? 'animate-bounce' : ''}`} style={{ animationIterationCount: 2 }}>
                <MapPin 
                  className={`w-12 h-12 text-primary drop-shadow-lg transition-transform duration-300 ${
                    pinDropped ? 'scale-110' : 'scale-100'
                  }`} 
                  fill="currentColor"
                />
                {pinDropped && (
                  <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-6 h-2 bg-foreground/20 rounded-full blur-sm" />
                )}
              </div>
            </div>

            {/* Coordinates display */}
            {latitude && longitude && (
              <div className="absolute bottom-3 left-3 right-3 flex justify-between text-xs font-mono text-muted-foreground bg-background/80 backdrop-blur-sm rounded-lg px-3 py-2">
                <span>Lat: {latitude.toFixed(4)}°</span>
                <span>Lng: {longitude.toFixed(4)}°</span>
              </div>
            )}
          </div>

          {/* Detect Location Button */}
          <Button
            variant="outline"
            className="w-full gap-2 h-12"
            onClick={detectLocation}
            disabled={isDetecting}
          >
            {isDetecting ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Detecting location...
              </>
            ) : (
              <>
                <Navigation className="w-5 h-5" />
                Detect My Location
              </>
            )}
          </Button>

          {/* Manual Input Section */}
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="h-px flex-1 bg-border" />
              <span className="text-xs text-muted-foreground uppercase tracking-wider">
                {locationDetected ? 'Confirm or edit' : 'Or enter manually'}
              </span>
              <div className="h-px flex-1 bg-border" />
            </div>

            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="country">Country *</Label>
                <SearchableSelect
                  options={countryOptions}
                  value={country}
                  onChange={handleCountryChange}
                  placeholder="Select your country"
                  searchPlaceholder="Search countries..."
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="state">State / Province</Label>
                {countryHasStates ? (
                  <SearchableSelect
                    options={stateOptions}
                    value={state}
                    onChange={setState}
                    placeholder="Select your state/province"
                    searchPlaceholder="Search states..."
                  />
                ) : (
                  <Input
                    id="state"
                    placeholder="Enter your state or province"
                    value={state}
                    onChange={(e) => setState(e.target.value)}
                    className="h-12"
                  />
                )}
              </div>

              <div className="space-y-2">
                <Label htmlFor="village">Village / Town / City</Label>
                <Input
                  id="village"
                  placeholder="Enter your village, town, or city"
                  value={village}
                  onChange={(e) => setVillage(e.target.value)}
                  className="h-12"
                />
                {village && locationDetected && (
                  <p className="text-xs text-muted-foreground flex items-center gap-1">
                    <MapPin className="w-3 h-3" />
                    Auto-detected location
                  </p>
                )}
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <Button
            onClick={handleSubmit}
            disabled={isLoading || !country}
            className="w-full h-12 text-base font-medium"
            variant="aurora"
          >
            {isLoading ? (
              <>
                <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                Saving...
              </>
            ) : (
              "Continue"
            )}
          </Button>
        </Card>
      </main>
    </div>
  );
};

export default LocationSetupScreen;
