import { useState, useCallback, useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { ArrowRight, ArrowLeft, User, Calendar, Heart, Mail, Phone } from "lucide-react";
import { format, differenceInYears } from "date-fns";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Calendar as CalendarComponent } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import MeowLogo from "@/components/MeowLogo";
import ProgressIndicator from "@/components/ProgressIndicator";
import PhoneInputWithCode from "@/components/PhoneInputWithCode";
import AuroraBackground from "@/components/AuroraBackground";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";


type Gender = "male" | "female" | "non-binary" | "prefer-not-to-say" | "";

const genderOptions = [
  { value: "male", label: "Male", emoji: "👨" },
  { value: "female", label: "Female", emoji: "👩" },
  { value: "non-binary", label: "Non-Binary", emoji: "🧑" },
  { value: "prefer-not-to-say", label: "Prefer not to say", emoji: "🤫" },
];

const phoneSchema = z.string().regex(/^\+?[1-9]\d{6,14}$/, "Please enter a valid phone number");

const BasicInfoScreen = () => {
  const navigate = useNavigate();
  const t = (key: string, def: string) => def;
  useRegistrationGuard([{ key: "selectedLanguage", storage: "session" }], "/register");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [fullName, setFullName] = useState("");
  const [dob, setDob] = useState<Date | undefined>(undefined);
  const [gender, setGender] = useState<Gender>("");
  const [calendarOpen, setCalendarOpen] = useState(false);
  
  // Validation states
  const [errors, setErrors] = useState<{
    email?: string;
    fullName?: string;
    dob?: string;
    gender?: string;
    phone?: string;
  }>({});
  const [shakeField, setShakeField] = useState<string | null>(null);
  const [touched, setTouched] = useState<{
    email?: boolean;
    fullName?: boolean;
    dob?: boolean;
    gender?: boolean;
    phone?: boolean;
  }>({});
  const [checkingEmail, setCheckingEmail] = useState(false);
  const [checkingPhone, setCheckingPhone] = useState(false);

  // Trigger shake animation
  const triggerShake = (field: string) => {
    setShakeField(field);
    setTimeout(() => setShakeField(null), 500);
  };

  // Validate email (format only)
  const validateEmail = (value: string) => {
    if (!value.trim()) return "Email is required";
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value.trim())) return "Please enter a valid email";
    return undefined;
  };

  // Backend availability check via SECURITY DEFINER RPC (bypasses RLS for anon signup)
  const checkAvailability = useCallback(
    async (
      checkEmail: string | null,
      checkPhone: string | null
    ): Promise<{ emailExists: boolean; phoneExists: boolean }> => {
      try {
        const { data, error } = await supabase.rpc("check_signup_availability", {
          p_email: checkEmail,
          p_phone: checkPhone,
        });
        if (error) throw error;
        const r = (data ?? {}) as { email_exists?: boolean; phone_exists?: boolean };
        return {
          emailExists: !!r.email_exists,
          phoneExists: !!r.phone_exists,
        };
      } catch (e) {
        console.warn("[BasicInfo] availability check failed:", e);
        return { emailExists: false, phoneExists: false };
      }
    },
    []
  );

  // Check email uniqueness (format + backend)
  const checkEmailUniqueness = useCallback(
    async (value: string): Promise<string | undefined> => {
      const formatError = validateEmail(value);
      if (formatError) return formatError;
      setCheckingEmail(true);
      try {
        const { emailExists } = await checkAvailability(value.trim().toLowerCase(), null);
        if (emailExists) return "Email already exists. Please try a different email.";
        return undefined;
      } finally {
        setCheckingEmail(false);
      }
    },
    [checkAvailability]
  );

  // Check phone uniqueness (format + backend across all profile tables)
  const checkPhoneUniqueness = useCallback(
    async (value: string): Promise<string | undefined> => {
      const formatError = validatePhone(value);
      if (formatError) return formatError;
      setCheckingPhone(true);
      try {
        const { phoneExists } = await checkAvailability(null, value.trim());
        if (phoneExists) return "Mobile number already exists. Please try a different mobile number.";
        return undefined;
      } finally {
        setCheckingPhone(false);
      }
    },
    [checkAvailability]
  );

  // Debounced live (AJAX-style) email uniqueness check while typing
  const emailReqIdRef = useRef(0);
  useEffect(() => {
    if (!email.trim()) {
      setErrors((prev) => ({ ...prev, email: undefined }));
      return;
    }
    const formatError = validateEmail(email);
    if (formatError) {
      setErrors((prev) => ({ ...prev, email: touched.email ? formatError : undefined }));
      return;
    }
    const reqId = ++emailReqIdRef.current;
    const handle = setTimeout(async () => {
      const err = await checkEmailUniqueness(email);
      if (reqId !== emailReqIdRef.current) return; // stale
      setErrors((prev) => ({ ...prev, email: err }));
      setTouched((prev) => ({ ...prev, email: true }));
    }, 500);
    return () => clearTimeout(handle);
  }, [email, checkEmailUniqueness, touched.email]);

  // Debounced live (AJAX-style) phone uniqueness check while typing
  const phoneReqIdRef = useRef(0);
  useEffect(() => {
    if (!phone.trim()) {
      setErrors((prev) => ({ ...prev, phone: undefined }));
      return;
    }
    const formatError = validatePhone(phone);
    if (formatError) {
      setErrors((prev) => ({ ...prev, phone: touched.phone ? formatError : undefined }));
      return;
    }
    const reqId = ++phoneReqIdRef.current;
    const handle = setTimeout(async () => {
      const err = await checkPhoneUniqueness(phone);
      if (reqId !== phoneReqIdRef.current) return;
      setErrors((prev) => ({ ...prev, phone: err }));
      setTouched((prev) => ({ ...prev, phone: true }));
    }, 500);
    return () => clearTimeout(handle);
  }, [phone, checkPhoneUniqueness, touched.phone]);


  // Validate full name
  const validateFullName = (value: string) => {
    if (!value.trim()) return "Full name is required";
    if (value.trim().length < 2) return "Name must be at least 2 characters";
    if (value.trim().length > 50) return "Name must be less than 50 characters";
    if (!/^[a-zA-Z\s\-'\.]+$/.test(value.trim())) return "Please enter a valid name";
    return undefined;
  };

  // Validate DOB
  const validateDob = (value: Date | undefined) => {
    if (!value) return "Date of birth is required";
    const age = differenceInYears(new Date(), value);
    if (age < 18) return "You must be at least 18 years old";
    if (age > 120) return "Please enter a valid date of birth";
    return undefined;
  };

  // Validate gender
  const validateGender = (value: Gender) => {
    if (!value) return "Please select your gender";
    return undefined;
  };

  // Validate phone (format only)
  const validatePhone = (value: string) => {
    if (!value.trim()) return "Phone number is required";
    const result = phoneSchema.safeParse(value.trim());
    if (!result.success) return result.error.errors[0].message;
    return undefined;
  };

  // Handle field blur
  const handleBlur = async (field: "email" | "fullName" | "dob" | "gender" | "phone") => {
    setTouched((prev) => ({ ...prev, [field]: true }));
    
    let error: string | undefined;
    if (field === "email") {
      error = await checkEmailUniqueness(email);
    } else if (field === "fullName") {
      error = validateFullName(fullName);
    } else if (field === "dob") {
      error = validateDob(dob);
    } else if (field === "gender") {
      error = validateGender(gender);
    } else if (field === "phone") {
      error = await checkPhoneUniqueness(phone);
    }

    if (error) {
      setErrors((prev) => ({ ...prev, [field]: error }));
      triggerShake(field);
    } else {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  // Calculate age display
  const getAgeDisplay = () => {
    if (!dob) return null;
    const age = differenceInYears(new Date(), dob);
    return age;
  };

  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleNext = async () => {
    // Validate all format rules first
    const emailFormatError = validateEmail(email);
    const fullNameError = validateFullName(fullName);
    const dobError = validateDob(dob);
    const genderError = validateGender(gender);
    const phoneFormatError = validatePhone(phone);

    const formatErrors = {
      email: emailFormatError,
      fullName: fullNameError,
      dob: dobError,
      gender: genderError,
      phone: phoneFormatError,
    };

    setErrors(formatErrors);
    setTouched({ email: true, fullName: true, dob: true, gender: true, phone: true });

    if (emailFormatError) triggerShake("email");
    else if (fullNameError) triggerShake("fullName");
    else if (phoneFormatError) triggerShake("phone");
    else if (dobError) triggerShake("dob");
    else if (genderError) triggerShake("gender");

    if (emailFormatError || fullNameError || dobError || genderError || phoneFormatError) {
      toast({
        title: "Please complete all fields",
        description: "All information is required to continue.",
        variant: "destructive",
      });
      return;
    }

    // Run uniqueness checks in parallel
    setIsSubmitting(true);
    try {
      const [emailError, phoneError] = await Promise.all([
        checkEmailUniqueness(email),
        checkPhoneUniqueness(phone),
      ]);

      if (emailError || phoneError) {
        const bothExist =
          emailError === "Email already exists. Please try a different email." &&
          phoneError === "Mobile number already exists. Please try a different mobile number.";
        const combinedMessage = bothExist
          ? "Email and mobile number already exist. Please try different ones."
          : emailError || phoneError || "Duplicate found";

        setErrors((prev) => ({
          ...prev,
          email: emailError,
          phone: phoneError,
        }));
        if (emailError) triggerShake("email");
        if (phoneError) triggerShake("phone");
        toast({
          title: combinedMessage,
          variant: "destructive",
        });
        return;
      }
    } finally {
      setIsSubmitting(false);
    }

    toast({
      title: "Looking great! 🌟",
      description: "Your basic info has been saved.",
    });
    
    // Store data for next screens
    sessionStorage.setItem("userEmail", email);
    sessionStorage.setItem("userGender", gender);
    sessionStorage.setItem("userPhone", phone);
    sessionStorage.setItem("userName", fullName);
    if (dob) {
      sessionStorage.setItem("userDob", dob.toISOString());
    }
    
    // Navigate to personal details screen
    navigate("/personal-details");
  };

  const handleBack = () => {
    navigate("/register");
  };

  const isComplete = email.trim() && fullName.trim() && dob && gender && phone.trim();

  // Get default month for calendar (18 years ago)
  const defaultMonth = new Date();
  defaultMonth.setFullYear(defaultMonth.getFullYear() - 18);

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      <AuroraBackground />
      
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
            <ProgressIndicator currentStep={2} totalSteps={10} />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto px-6 pb-8 relative z-10">
        <div className="max-w-lg mx-auto">
          {/* Logo & Title */}
          <div className="text-center mb-8 animate-fade-in">
            <MeowLogo size="sm" className="mx-auto mb-4" />
            <h1 className="font-display text-2xl font-bold text-foreground mb-2 drop-shadow-sm">
              {t('tellUsAboutYou', 'Tell us about you')}
            </h1>
            <p className="text-muted-foreground text-sm max-w-xs mx-auto">
              {t('helpUsPersonalize', 'Help us personalize your experience')}
            </p>
          </div>

          {/* Form Card */}
          <div className="bg-card/70 backdrop-blur-xl rounded-3xl p-6 border border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
            <div className="space-y-6">
            {/* Gender Selection */}
            <div 
              className={cn(
                "space-y-3 transition-all",
                shakeField === "gender" && "animate-shake"
              )}
            >
              <label className="flex items-center gap-2 text-sm font-semibold text-foreground">
                <Heart className="w-4 h-4 text-primary" />
                {t('gender', 'Gender')}
              </label>
              <div className="grid grid-cols-2 gap-3">
                {genderOptions.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => {
                      setGender(option.value as Gender);
                      setTouched((prev) => ({ ...prev, gender: true }));
                      setErrors((prev) => ({ ...prev, gender: undefined }));
                    }}
                    className={cn(
                      "flex items-center gap-2 p-3 rounded-xl border-2 transition-all",
                      "hover:border-primary/50 hover:bg-primary/5",
                      "focus:outline-none focus:ring-2 focus:ring-primary/20",
                      gender === option.value
                        ? "border-primary bg-primary/10 shadow-soft"
                        : "border-input bg-background/50",
                      errors.gender && touched.gender && !gender
                        ? "border-destructive/50"
                        : ""
                    )}
                  >
                    <span className="text-xl">{option.emoji}</span>
                    <span className={cn(
                      "text-sm font-medium",
                      gender === option.value ? "text-primary" : "text-foreground"
                    )}>
                      {option.label}
                    </span>
                  </button>
                ))}
              </div>
              {errors.gender && touched.gender && (
                <p className="text-xs text-destructive flex items-center gap-1 animate-fade-in">
                  <span className="inline-block w-1 h-1 rounded-full bg-destructive" />
                  {errors.gender}
                </p>
              )}
            </div>
            
            {/* Email */}
            <div 
              className={cn(
                "space-y-2 transition-all",
                shakeField === "email" && "animate-shake"
              )}
            >
              <label className="flex items-center gap-2 text-sm font-semibold text-foreground">
                <Mail className="w-4 h-4 text-primary" />
                {t('email', 'Email')}
              </label>
              <Input
                type="email"
                placeholder={t('enterYourEmail', 'Enter your email')}
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  if (touched.email) {
                    const error = validateEmail(e.target.value);
                    setErrors((prev) => ({ ...prev, email: error }));
                  }
                }}
                onBlur={() => handleBlur("email")}
                className={cn(
                  "h-12 rounded-xl border-2 transition-all focus:ring-2 focus:ring-primary/20",
                  errors.email && touched.email 
                    ? "border-destructive focus:border-destructive" 
                    : "border-input focus:border-primary"
                )}
              />
              {errors.email && touched.email && (
                <p className="text-xs text-destructive flex items-center gap-1 animate-fade-in">
                  <span className="inline-block w-1 h-1 rounded-full bg-destructive" />
                  {errors.email}
                </p>
              )}
            </div>

            {/* Phone Number with Country Code */}
            <div 
              className={cn(
                "space-y-2 transition-all",
                shakeField === "phone" && "animate-shake"
              )}
            >
              <label className="flex items-center gap-2 text-sm font-semibold text-foreground">
                <Phone className="w-4 h-4 text-primary" />
                {t('phoneNumber', 'Phone Number')}
              </label>
              <PhoneInputWithCode
                value={phone}
                onChange={(value) => {
                  setPhone(value);
                  if (touched.phone) {
                    const error = validatePhone(value);
                    setErrors((prev) => ({ ...prev, phone: error }));
                  }
                }}
                onBlur={() => handleBlur("phone")}
                error={!!(errors.phone && touched.phone)}
                placeholder="Enter phone number"
                defaultCountryCode="IN"
              />
              {errors.phone && touched.phone && (
                <p className="text-xs text-destructive flex items-center gap-1 animate-fade-in">
                  <span className="inline-block w-1 h-1 rounded-full bg-destructive" />
                  {errors.phone}
                </p>
              )}
            </div>

            {/* Full Name */}
            <div 
              className={cn(
                "space-y-2 transition-all",
                shakeField === "fullName" && "animate-shake"
              )}
            >
              <label className="flex items-center gap-2 text-sm font-semibold text-foreground">
                <User className="w-4 h-4 text-primary" />
                {t('fullName', 'Full Name')}
              </label>
              <Input
                type="text"
                placeholder={t('enterYourFullName', 'Enter your full name')}
                value={fullName}
                onChange={(e) => {
                  setFullName(e.target.value);
                  if (touched.fullName) {
                    const error = validateFullName(e.target.value);
                    setErrors((prev) => ({ ...prev, fullName: error }));
                  }
                }}
                onBlur={() => handleBlur("fullName")}
                className={cn(
                  "h-12 rounded-xl border-2 transition-all focus:ring-2 focus:ring-primary/20",
                  errors.fullName && touched.fullName 
                    ? "border-destructive focus:border-destructive" 
                    : "border-input focus:border-primary"
                )}
              />
              {errors.fullName && touched.fullName && (
                <p className="text-xs text-destructive flex items-center gap-1 animate-fade-in">
                  <span className="inline-block w-1 h-1 rounded-full bg-destructive" />
                  {errors.fullName}
                </p>
              )}
            </div>

            {/* Date of Birth */}
            <div 
              className={cn(
                "space-y-2 transition-all",
                shakeField === "dob" && "animate-shake"
              )}
            >
              <label className="flex items-center gap-2 text-sm font-semibold text-foreground">
                <Calendar className="w-4 h-4 text-primary" />
                {t('dateOfBirth', 'Date of Birth')}
                {getAgeDisplay() && (
                  <span className="ml-auto text-xs font-normal text-muted-foreground bg-muted px-2 py-0.5 rounded-full">
                    {getAgeDisplay()} {t('yearsOld', 'years old')}
                  </span>
                )}
              </label>
              <Popover open={calendarOpen} onOpenChange={setCalendarOpen}>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    className={cn(
                      "w-full h-12 rounded-xl border-2 justify-start text-left font-normal transition-all",
                      !dob && "text-muted-foreground",
                      errors.dob && touched.dob 
                        ? "border-destructive focus:border-destructive" 
                        : "border-input focus:border-primary hover:border-primary/50"
                    )}
                    onClick={() => setCalendarOpen(true)}
                  >
                    <Calendar className="mr-2 h-4 w-4 text-muted-foreground" />
                    {dob ? format(dob, "MMMM d, yyyy") : t('selectYourBirthday', 'Select your birthday')}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0 z-50" align="center">
                  <CalendarComponent
                    mode="single"
                    selected={dob}
                    onSelect={(date) => {
                      setDob(date);
                      setCalendarOpen(false);
                      setTouched((prev) => ({ ...prev, dob: true }));
                      const error = validateDob(date);
                      setErrors((prev) => ({ ...prev, dob: error }));
                      if (error) triggerShake("dob");
                    }}
                    defaultMonth={defaultMonth}
                    disabled={(date) =>
                      date > new Date() || date < new Date("1900-01-01")
                    }
                    initialFocus
                    className="p-3 pointer-events-auto bg-popover rounded-xl"
                    captionLayout="dropdown-buttons"
                    fromYear={1920}
                    toYear={new Date().getFullYear() - 18}
                  />
                </PopoverContent>
              </Popover>
              {errors.dob && touched.dob && (
                <p className="text-xs text-destructive flex items-center gap-1 animate-fade-in">
                  <span className="inline-block w-1 h-1 rounded-full bg-destructive" />
                  {errors.dob}
                </p>
              )}
            </div>

            {/* CTA Button inside Form Card */}
            <div className="mt-6">
              <Button
                variant="aurora"
                size="xl"
                className="w-full group"
                onClick={handleNext}
                disabled={!isComplete || isSubmitting || checkingEmail || checkingPhone}
              >
                {isSubmitting ? "Checking..." : "Continue"}
                {!isSubmitting && <ArrowRight className="w-5 h-5 transition-transform group-hover:translate-x-1" />}
              </Button>
              
              <p className="text-center text-xs text-muted-foreground mt-4">
                Your information is securely stored and never shared
              </p>
            </div>
          </div>
        </div>
      </div>
      </main>

      {/* Decorative Elements */}
      <div className="fixed top-32 right-8 w-24 h-24 rounded-full bg-primary/5 blur-2xl pointer-events-none" />
      <div className="fixed bottom-40 left-8 w-28 h-28 rounded-full bg-accent/20 blur-3xl pointer-events-none" />
    </div>
  );
};

export default BasicInfoScreen;
