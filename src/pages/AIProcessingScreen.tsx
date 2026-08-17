import { useState, useRef, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import MeowLogo from "@/components/MeowLogo";
import AuroraBackground from "@/components/AuroraBackground";
import { useToast } from "@/hooks/use-toast";
import { useGenderClassification } from "@/hooks/useGenderClassification";
import { 
  Camera, 
  CheckCircle2, 
  XCircle, 
  Loader2, 
  Sparkles,
  AlertTriangle,
  User,
  RefreshCw
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";

const AIProcessingScreen = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  // Camera and capture state
  const [showCamera, setShowCamera] = useState(false);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [selfiePreview, setSelfiePreview] = useState<string | null>(null);
  const [countdown, setCountdown] = useState<number | null>(null);
  
  // Verification state
  const [verificationStatus, setVerificationStatus] = useState<"idle" | "verifying" | "success" | "failed">("idle");
  const [verificationResult, setVerificationResult] = useState<any>(null);
  const [progress, setProgress] = useState(0);
  
  // Gender classification hook
  const { isVerifying, isLoadingModel, modelLoadProgress, classifyGender } = useGenderClassification();
  
  // Get registered gender from localStorage
  const registeredGender = sessionStorage.getItem("userGender") as 'male' | 'female' | null;

  // Start camera
  const startCamera = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: 640, height: 480 }
      });
      setStream(mediaStream);
      setShowCamera(true);
    } catch (error) {
      toast({
        title: "Camera access required",
        description: "Please allow camera access for gender verification",
        variant: "destructive",
      });
    }
  };

  // Set video source when stream is ready
  useEffect(() => {
    if (stream && videoRef.current && showCamera) {
      videoRef.current.srcObject = stream;
    }
  }, [stream, showCamera]);

  // Stop camera
  const stopCamera = useCallback(() => {
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
      setStream(null);
    }
    setShowCamera(false);
  }, [stream]);

  // Capture photo with countdown
  const captureWithCountdown = () => {
    setCountdown(3);
  };

  // Countdown effect
  useEffect(() => {
    if (countdown === null) return;
    
    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    } else {
      // Capture the photo
      capturePhoto();
      setCountdown(null);
    }
  }, [countdown]);

  // Capture photo from video
  const capturePhoto = () => {
    if (videoRef.current && canvasRef.current) {
      const canvas = canvasRef.current;
      const video = videoRef.current;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (ctx) {
        // Mirror the image (selfie mode)
        ctx.translate(canvas.width, 0);
        ctx.scale(-1, 1);
        ctx.drawImage(video, 0, 0);
        
        const imageData = canvas.toDataURL("image/jpeg", 0.9);
        setSelfiePreview(imageData);
        stopCamera();
        
        // Start verification
        verifyGender(imageData);
      }
    }
  };

  // Verify gender using Hugging Face model
  const verifyGender = async (imageData: string) => {
    setVerificationStatus("verifying");
    setProgress(10);

    try {
      // Update progress during model loading
      const progressInterval = setInterval(() => {
        setProgress(prev => Math.min(prev + 5, 80));
      }, 500);

      // Get expected gender from registration
      const expectedGender = registeredGender || undefined;
      
      // Classify gender with 30-second timeout
      const classifyPromise = classifyGender(imageData, expectedGender);
      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('AI_TIMEOUT')), 30000)
      );
      
      const result = await Promise.race([classifyPromise, timeoutPromise]);
      
      clearInterval(progressInterval);
      setProgress(100);
      setVerificationResult(result);

      // Save verification result to Supabase
      await saveVerificationResult(result);

      if (result.verified && result.genderMatches) {
        setVerificationStatus("success");
        toast({
          title: "Verification Successful! ✓",
          description: `Gender verified as ${result.detectedGender} (${Math.round(result.confidence * 100)}% confidence)`,
        });
      } else if (!result.genderMatches) {
        setVerificationStatus("failed");
        toast({
          title: "Gender Mismatch",
          description: `Expected ${expectedGender}, but detected ${result.detectedGender}. Please try again.`,
          variant: "destructive",
        });
      } else {
        setVerificationStatus("failed");
        toast({
          title: "Verification Failed",
          description: result.reason || "Please try again with better lighting",
          variant: "destructive",
        });
      }
    } catch (error: any) {
      console.error("Verification error:", error);
      setProgress(100);
      setVerificationStatus("failed");
      const isTimeout = error?.message === 'AI_TIMEOUT';
      toast({
        title: isTimeout ? "Verification Timed Out" : "Verification Error",
        description: isTimeout 
          ? "AI verification took too long. You can retry or skip for now."
          : "An error occurred. Please try again.",
        variant: "destructive",
      });
    }
  };

  // Save verification result to Supabase
  const saveVerificationResult = async (result: any) => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session?.user) {
        const user = session.user;
        await supabase
          .from("processing_logs")
          .insert({
            user_id: user.id,
            processing_status: result.verified && result.genderMatches ? "completed" : "failed",
            gender_verified: result.verified && result.genderMatches,
            completed_at: new Date().toISOString(),
            errors: result.verified && result.genderMatches ? null : [result.reason],
          });
      }
    } catch (error) {
      console.error("Error saving verification result:", error);
      toast.error("Verification not saved", { description: "Your verification result could not be saved. Please complete the process again." });
    }
  };

  // Retry verification
  const retryVerification = () => {
    setSelfiePreview(null);
    setVerificationStatus("idle");
    setVerificationResult(null);
    setProgress(0);
    startCamera();
  };

  // Continue to next screen
  const handleContinue = () => {
    navigate("/welcome");
  };

  // Skip verification (with warning)
  const handleSkip = () => {
    toast({
      title: "Verification Skipped",
      description: "Some features may be limited without verification.",
    });
    navigate("/welcome");
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, [stream]);

  return (
    <div className="min-h-screen flex flex-col relative bg-background">
      <AuroraBackground />

      {/* Header */}
      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex justify-center">
          <MeowLogo size="md" />
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6 relative z-10">
        <Card className="w-full max-w-md p-6 bg-card/80 backdrop-blur-xl border border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
          <div className="text-center space-y-4">
            {/* Icon */}
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary/10 mx-auto">
              {verificationStatus === "success" ? (
                <CheckCircle2 className="w-8 h-8 text-accent" />
              ) : verificationStatus === "failed" ? (
                <XCircle className="w-8 h-8 text-destructive" />
              ) : (
                <User className="w-8 h-8 text-primary" />
              )}
            </div>

            {/* Title */}
            <div>
              <h1 className="text-2xl font-bold text-foreground font-display">
                {verificationStatus === "success" 
                  ? "Verification Complete!" 
                  : verificationStatus === "failed"
                  ? "Verification Failed"
                  : "Gender Verification"
                }
              </h1>
              <p className="text-muted-foreground text-sm mt-1">
                {verificationStatus === "idle" 
                  ? "Take a selfie to verify your identity"
                  : verificationStatus === "verifying"
                  ? "Analyzing your selfie..."
                  : verificationStatus === "success"
                  ? "Your identity has been verified"
                  : "Please try again with a clearer photo"
                }
              </p>
            </div>

            {/* Registered Gender Info */}
            {registeredGender && verificationStatus === "idle" && (
              <div className="p-3 bg-primary/5 rounded-xl border border-primary/20">
                <p className="text-sm text-muted-foreground">
                  Registered as: <span className="font-semibold text-primary capitalize">{registeredGender}</span>
                </p>
              </div>
            )}

            {/* Camera / Selfie Preview */}
            <div className="relative aspect-square max-w-[280px] mx-auto rounded-2xl overflow-hidden border-2 border-primary/20">
              {showCamera ? (
                <>
                  <video
                    ref={videoRef}
                    autoPlay
                    playsInline
                    muted
                    className="w-full h-full object-cover scale-x-[-1]"
                  />
                  {/* Face guide overlay */}
                  <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                    <div className="w-32 h-40 border-2 border-dashed border-primary/50 rounded-full" />
                  </div>
                  {/* Countdown overlay */}
                  {countdown !== null && (
                    <div className="absolute inset-0 flex items-center justify-center bg-background/50">
                      <span className="text-6xl font-bold text-primary animate-pulse">{countdown}</span>
                    </div>
                  )}
                </>
              ) : selfiePreview ? (
                <>
                  <img 
                    src={selfiePreview} 
                    alt="Selfie" 
                    className="w-full h-full object-cover"
                  />
                  {/* Verification overlay */}
                  {verificationStatus === "verifying" && (
                    <div className="absolute inset-0 flex flex-col items-center justify-center bg-background/80 gap-3">
                      <div className="relative">
                        <Loader2 className="w-12 h-12 text-primary animate-spin" />
                        <Sparkles className="w-5 h-5 text-primary absolute -top-1 -right-1 animate-pulse" />
                      </div>
                      <p className="text-sm font-medium text-foreground">AI Verifying...</p>
                    </div>
                  )}
                  {/* Success badge */}
                  {verificationStatus === "success" && (
                    <div className="absolute top-3 right-3 bg-accent text-accent-foreground rounded-full p-2 animate-in zoom-in duration-300">
                      <CheckCircle2 className="w-5 h-5" />
                    </div>
                  )}
                  {/* Failed badge */}
                  {verificationStatus === "failed" && (
                    <div className="absolute top-3 right-3 bg-destructive text-destructive-foreground rounded-full p-2 animate-in zoom-in duration-300">
                      <XCircle className="w-5 h-5" />
                    </div>
                  )}
                </>
              ) : (
                <div className="w-full h-full flex flex-col items-center justify-center bg-muted/50 gap-3">
                  <Camera className="w-12 h-12 text-muted-foreground" />
                  <p className="text-sm text-muted-foreground">Camera preview</p>
                </div>
              )}
            </div>

            <canvas ref={canvasRef} className="hidden" />

            {/* Progress bar (during verification) */}
            {verificationStatus === "verifying" && (
              <div className="space-y-2">
                <div className="flex justify-between text-xs">
                  <span className="text-muted-foreground">
                    {isLoadingModel ? "Loading AI model..." : "Analyzing..."}
                  </span>
                  <span className="font-medium text-foreground">{progress}%</span>
                </div>
                <Progress value={progress} className="h-2" />
              </div>
            )}

            {/* Model loading indicator */}
            {isLoadingModel && (
              <div className="p-3 bg-primary/5 rounded-xl border border-primary/20">
                <p className="text-xs text-muted-foreground">
                  Loading AI model: {modelLoadProgress}%
                </p>
              </div>
            )}

            {/* Verification Result */}
            {verificationResult && verificationStatus !== "verifying" && (
              <div className={`p-3 rounded-xl text-sm ${
                verificationStatus === "success"
                  ? "bg-accent/10 text-accent border border-accent/20"
                  : "bg-destructive/10 text-destructive border border-destructive/20"
              }`}>
                {verificationStatus === "success" ? (
                  <p>
                    ✓ Verified as <span className="font-semibold capitalize">{verificationResult.detectedGender}</span>
                    {" "}({Math.round(verificationResult.confidence * 100)}% confidence)
                  </p>
                ) : (
                  <p>{verificationResult.reason}</p>
                )}
              </div>
            )}

            {/* Action Buttons */}
            <div className="space-y-3 pt-2">
              {verificationStatus === "idle" && !showCamera && (
                <Button
                  variant="aurora"
                  size="xl"
                  className="w-full gap-2"
                  onClick={startCamera}
                >
                  <Camera className="w-5 h-5" />
                  Start Camera
                </Button>
              )}

              {showCamera && countdown === null && (
                <Button
                  variant="aurora"
                  size="xl"
                  className="w-full gap-2"
                  onClick={captureWithCountdown}
                >
                  <Camera className="w-5 h-5" />
                  Take Selfie
                </Button>
              )}

              {verificationStatus === "success" && (
                <Button
                  variant="aurora"
                  size="xl"
                  className="w-full"
                  onClick={handleContinue}
                >
                  Continue
                </Button>
              )}

              {verificationStatus === "failed" && (
                <div className="flex gap-3">
                  <Button
                    variant="outline"
                    className="flex-1 gap-2"
                    onClick={retryVerification}
                  >
                    <RefreshCw className="w-4 h-4" />
                    Retry
                  </Button>
                  <Button
                    variant="aurora"
                    className="flex-1"
                    onClick={handleContinue}
                  >
                    Continue Anyway
                  </Button>
                </div>
              )}

              {/* Skip option */}
              {verificationStatus === "idle" && (
                <Button
                  variant="ghost"
                  className="text-muted-foreground text-sm"
                  onClick={handleSkip}
                >
                  Skip for now
                </Button>
              )}

              {/* Cancel camera */}
              {showCamera && (
                <Button
                  variant="ghost"
                  className="text-muted-foreground"
                  onClick={stopCamera}
                >
                  Cancel
                </Button>
              )}
            </div>

            {/* Security note */}
            <p className="text-xs text-muted-foreground pt-2">
              🔒 Your selfie is processed locally using AI and is not stored
            </p>
          </div>
        </Card>
      </main>
    </div>
  );
};

export default AIProcessingScreen;
