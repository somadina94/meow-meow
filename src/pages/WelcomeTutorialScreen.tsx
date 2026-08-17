import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import MeowLogo from "@/components/MeowLogo";
import { useToast } from "@/hooks/use-toast";
import { 
  ChevronLeft, 
  ChevronRight, 
  Sparkles, 
  MessageCircle, 
  Heart, 
  Shield, 
  Globe,
  Zap
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";

interface TutorialSlide {
  id: number;
  title: string;
  description: string;
  icon: React.ReactNode;
  color: string;
}

const tutorialSlides: TutorialSlide[] = [
  {
    id: 0,
    title: "Welcome to Meow!",
    description: "Your journey to meaningful connections starts here. Let's show you around!",
    icon: <Sparkles className="w-12 h-12" />,
    color: "from-primary to-primary/60",
  },
  {
    id: 1,
    title: "Start Conversations",
    description: "Send messages, voice notes, and photos. Express yourself freely and connect authentically.",
    icon: <MessageCircle className="w-12 h-12" />,
    color: "from-primary to-primary/80",
  },
  {
    id: 2,
    title: "Find Your Match",
    description: "Our AI-powered matching helps you discover people who share your interests and values.",
    icon: <Heart className="w-12 h-12" />,
    color: "from-accent to-accent/80",
  },
  {
    id: 3,
    title: "Stay Safe",
    description: "Your privacy matters. All profiles are verified, and you control who sees your information.",
    icon: <Shield className="w-12 h-12" />,
    color: "from-success to-success/80",
  },
  {
    id: 4,
    title: "Connect Globally",
    description: "Meet people from different cultures and backgrounds. Explore connections from around the world!",
    icon: <Globe className="w-12 h-12" />,
    color: "from-secondary to-secondary/80",
  },
  {
    id: 5,
    title: "You're All Set!",
    description: "Start exploring and make meaningful connections. Your perfect match is just a swipe away!",
    icon: <Zap className="w-12 h-12" />,
    color: "from-warning to-warning/80",
  },
];

const WelcomeTutorialScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [currentStep, setCurrentStep] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);
  const [slideDirection, setSlideDirection] = useState<"left" | "right">("right");
  const [stepsViewed, setStepsViewed] = useState<number[]>([0]);

  const totalSteps = tutorialSlides.length;
  const isLastStep = currentStep === totalSteps - 1;

  useEffect(() => {
    setStepsViewed(prev => 
      prev.includes(currentStep) ? prev : [...prev, currentStep]
    );
  }, [currentStep]);

  const animateTransition = useCallback((direction: "left" | "right", newStep: number) => {
    setSlideDirection(direction);
    setIsAnimating(true);
    
    setTimeout(() => {
      setCurrentStep(newStep);
      setIsAnimating(false);
    }, 200);
  }, []);

  const handleNext = () => {
    if (currentStep < totalSteps - 1) {
      animateTransition("right", currentStep + 1);
    }
  };

  const handlePrevious = () => {
    if (currentStep > 0) {
      animateTransition("left", currentStep - 1);
    }
  };

  const navigateIfAuthenticated = async (destination: string) => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user) {
      navigate(destination);
    } else {
      toast({
        title: "Session expired",
        description: "Please log in again to continue.",
        variant: "destructive",
      });
      navigate("/auth", { replace: true });
    }
  };

  const handleSkip = async () => {
    await saveTutorialProgress(true);
    await navigateIfAuthenticated("/registration-complete");
  };

  const handleComplete = async () => {
    await saveTutorialProgress(false);
    toast({
      title: "Tutorial Complete!",
      description: "You're ready to start connecting.",
    });
    await navigateIfAuthenticated("/registration-complete");
  };

  const saveTutorialProgress = async (skipped: boolean) => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session?.user) return;
      const user = session.user;

      // Always mark completed=true so user goes directly to dashboard on next login
      await supabase
        .from("tutorial_progress")
        .upsert({
          user_id: user.id,
          current_step: skipped ? currentStep : totalSteps - 1,
          completed: true,
          skipped,
          steps_viewed: stepsViewed,
          completed_at: new Date().toISOString(),
        });
    } catch (error) {
      console.error("Error saving tutorial progress:", error);
      // Non-critical: don't block tutorial with a toast, just log
    }
  };

  const goToStep = (step: number) => {
    if (step !== currentStep) {
      animateTransition(step > currentStep ? "right" : "left", step);
    }
  };

  const currentSlide = tutorialSlides[currentStep];

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-primary/5 flex flex-col overflow-hidden">
      {/* Header */}
      <header className="p-6 flex justify-between items-center">
        <MeowLogo />
        <Button
          variant="auroraGhost"
          onClick={handleSkip}
          className="text-muted-foreground hover:text-foreground"
        >
          Skip Tutorial
        </Button>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6">
        <Card className="w-full max-w-lg p-8 space-y-8 bg-card/80 backdrop-blur-sm border-border/50 shadow-xl overflow-hidden">
          {/* Slide Content with Animation */}
          <div 
            className={`transition-all duration-300 ease-out ${
              isAnimating 
                ? slideDirection === "right" 
                  ? "-translate-x-8 opacity-0" 
                  : "translate-x-8 opacity-0"
                : "translate-x-0 opacity-100"
            }`}
          >
            {/* Icon */}
            <div className="text-center mb-6">
              <div 
                className={`inline-flex items-center justify-center w-24 h-24 rounded-full bg-gradient-to-br ${currentSlide.color} text-white shadow-lg`}
              >
                {currentSlide.icon}
              </div>
            </div>

            {/* Title & Description */}
            <div className="text-center space-y-4">
              <h1 className="text-2xl font-bold text-foreground">
                {currentSlide.title}
              </h1>
              <p className="text-muted-foreground text-lg leading-relaxed">
                {currentSlide.description}
              </p>
            </div>
          </div>

          {/* Progress Dots */}
          <div className="flex justify-center gap-2 py-4">
            {tutorialSlides.map((_, index) => (
              <button
                key={index}
                onClick={() => goToStep(index)}
                className={`transition-all duration-300 rounded-full ${
                  index === currentStep
                    ? "w-8 h-2 bg-primary"
                    : stepsViewed.includes(index)
                    ? "w-2 h-2 bg-primary/40 hover:bg-primary/60"
                    : "w-2 h-2 bg-muted-foreground/30 hover:bg-muted-foreground/50"
                }`}
                aria-label={`Go to slide ${index + 1}`}
              />
            ))}
          </div>

          {/* Navigation Buttons */}
          <div className="flex gap-3">
            <Button
              variant="auroraOutline"
              onClick={handlePrevious}
              disabled={currentStep === 0}
              className="flex-1 h-12"
            >
              <ChevronLeft className="w-5 h-5 mr-1" />
              Previous
            </Button>
            
            {isLastStep ? (
              <Button
                onClick={handleComplete}
                className="flex-1 h-12 text-base font-medium"
                variant="aurora"
              >
                Get Started
                <Sparkles className="w-5 h-5 ml-2" />
              </Button>
            ) : (
              <Button
                onClick={handleNext}
                className="flex-1 h-12 text-base font-medium"
                variant="aurora"
              >
                Next
                <ChevronRight className="w-5 h-5 ml-1" />
              </Button>
            )}
          </div>

          {/* Step Counter */}
          <p className="text-xs text-center text-muted-foreground">
            Step {currentStep + 1} of {totalSteps}
          </p>
        </Card>
      </main>

      {/* Background Decorations */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden -z-10">
        <div 
          className={`absolute top-1/4 -left-20 w-64 h-64 rounded-full bg-gradient-to-br ${currentSlide.color} opacity-10 blur-3xl transition-all duration-700`}
        />
        <div 
          className={`absolute bottom-1/4 -right-20 w-80 h-80 rounded-full bg-gradient-to-br ${currentSlide.color} opacity-10 blur-3xl transition-all duration-700`}
        />
      </div>
    </div>
  );
};

export default WelcomeTutorialScreen;
