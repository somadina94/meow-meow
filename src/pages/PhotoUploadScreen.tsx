import { useState, useRef, useCallback, useEffect, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import ProgressIndicator from "@/components/ProgressIndicator";
import ScreenTitle from "@/components/ScreenTitle";
import { toast } from "@/hooks/use-toast";
import { useFaceVerification } from "@/hooks/useFaceVerification";
import { ArrowLeft, Camera, Check, X, Loader2, Sparkles } from "lucide-react";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

type VerificationState = "idle" | "verifying" | "verified" | "failed";

const PhotoUploadScreen = () => {
  const navigate = useNavigate();
  useRegistrationGuard([{ key: "userEmail" }, { key: "userGender" }], "/basic-info");
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isVerifying, setIsVerifying] = useState(false);

  // Face verification hook for client-side gender detection
  const { verifyFace } = useFaceVerification();

  // Selfie state (with AI verification)
  const [selfiePreview, setSelfiePreview] = useState<string | null>(null);
  const [verificationState, setVerificationState] = useState<VerificationState>("idle");
  const [verificationResult, setVerificationResult] = useState<any>(null);
  const [showCamera, setShowCamera] = useState(false);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [lightboxSrc, setLightboxSrc] = useState<string | null>(null);
  const [selectedGender, setSelectedGender] = useState<"male" | "female" | null>(null);
  const [detectedGender, setDetectedGender] = useState<"male" | "female" | "unknown" | null>(null);
  const [genderChanged, setGenderChanged] = useState(false);

  // Restore previously captured selfie + read selected gender from registration
  useEffect(() => {
    const existing = sessionStorage.getItem("pendingPhotoData");
    if (existing) {
      setSelfiePreview(existing);
      // Keep state "idle" so user can re-verify if needed; Verify button stays visible
      setVerificationState("idle");
    }
    const storedGender = sessionStorage.getItem("userGender");
    if (storedGender === "male" || storedGender === "female") {
      setSelectedGender(storedGender);
    }
  }, []);

  const handleSelfieCapture = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) {
      toast({
        title: "Invalid file type",
        description: "Please upload an image file (JPG, PNG, etc.)",
        variant: "destructive",
      });
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      toast({
        title: "File too large",
        description: "Please upload an image smaller than 10MB",
        variant: "destructive",
      });
      return;
    }

    setVerificationState("idle");
    setVerificationResult(null);

    const reader = new FileReader();
    reader.onload = (e) => {
      setSelfiePreview(e.target?.result as string);
    };
    reader.readAsDataURL(file);
  }, []);

  const startCamera = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: 640, height: 480 }
      });
      setStream(mediaStream);
      setShowCamera(true);
    } catch (error) {
      toast({
        title: "Camera access denied",
        description: "Please allow camera access to take a selfie",
        variant: "destructive",
      });
    }
  };

  // Set video source when stream and video element are ready
  useEffect(() => {
    if (stream && videoRef.current && showCamera) {
      videoRef.current.srcObject = stream;
    }
  }, [stream, showCamera]);

  // Stop camera on unmount to prevent lingering stream
  useEffect(() => {
    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, [stream]);

  const stopCamera = () => {
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
      setStream(null);
    }
    setShowCamera(false);
  };

  const capturePhoto = () => {
    if (videoRef.current && canvasRef.current) {
      const canvas = canvasRef.current;
      const video = videoRef.current;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (ctx) {
        ctx.drawImage(video, 0, 0);
        canvas.toBlob((blob) => {
          if (blob) {
            const file = new File([blob], "selfie.jpg", { type: "image/jpeg" });
            handleSelfieCapture(file);
            stopCamera();
          }
        }, "image/jpeg", 0.9);
      }
    }
  };

  const verifySelfie = async () => {
    if (!selfiePreview) return;

    setVerificationState("verifying");
    setIsVerifying(true);
    setGenderChanged(false);
    setDetectedGender(null);

    try {
      const storedGender = sessionStorage.getItem("userGender");
      const expectedGender = storedGender === "male" || storedGender === "female" ? storedGender : null;
      if (storedGender && !expectedGender) sessionStorage.removeItem("userGender");

      const result = await verifyFace(selfiePreview, expectedGender || undefined);
      setVerificationResult(result);

      if (result.verified && result.hasFace) {
        const detected = result.detectedGender;
        setDetectedGender(detected);

        const isMismatch =
          (detected === "male" || detected === "female") &&
          expectedGender !== null &&
          expectedGender !== detected;

        if (isMismatch) {
          // Mismatch → warn the user and auto-switch the stored gender
          sessionStorage.setItem("userGender", detected);
          setSelectedGender(detected);
          setGenderChanged(true);
          toast({
            title: "⚠️ Gender mismatch — auto-corrected",
            description: `You selected ${expectedGender}, but the AI detected ${detected}. Your profile gender has been switched to ${detected}.`,
            variant: "destructive",
          });
        }
        // If detected === expectedGender → silent, no extra toast/action

        setVerificationState("verified");
        if (!isMismatch) {
          toast({
            title: "Selfie verified ✨",
            description:
              result.confidence && (detected === "male" || detected === "female")
                ? `Gender confirmed as ${detected} (${Math.round(result.confidence * 100)}% confidence)`
                : result.reason || "Your photo has been verified",
          });
        }
      } else {
        setVerificationState("failed");
        toast({
          title: "Verification issue",
          description: result.reason || "Please try taking a clearer selfie",
          variant: "destructive",
        });
      }
    } catch (error: any) {
      console.error("Verification error:", error);
      setVerificationState("failed");
      setVerificationResult({ reason: "Verification failed. Please try again." });
      toast({
        title: "Verification failed",
        description: "An error occurred during face verification. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsVerifying(false);
    }
  };

  const compressImage = (dataUrl: string, quality = 0.85): Promise<string> => {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement("canvas");
        const maxDim = 1080;
        let w = img.width, h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) { h = Math.round(h * maxDim / w); w = maxDim; }
          else { w = Math.round(w * maxDim / h); h = maxDim; }
        }
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext("2d");
        ctx?.drawImage(img, 0, 0, w, h);
        resolve(canvas.toDataURL("image/jpeg", quality));
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  };

  const handleNext = async () => {
    if (!selfiePreview) {
      toast({
        title: "Selfie required",
        description: "Please take a selfie before continuing",
        variant: "destructive",
      });
      return;
    }

    if (verificationState !== "verified") {
      toast({
        title: "Selfie not AI-verified",
        description: "Continuing without AI verification — your profile may need manual review.",
      });
    }

    try {
      const compressed = await compressImage(selfiePreview);
      sessionStorage.setItem("pendingPhotoData", compressed);
    } catch (storageError) {
      console.warn("Failed to save selfie:", storageError);
      toast({
        title: "Storage Error",
        description: "Unable to save the selfie. Your device storage may be full.",
        variant: "destructive",
      });
      return;
    }

    navigate("/additional-photos");
  };

  const handleBack = () => {
    stopCamera();
    navigate("/personal-details");
  };

  const clearSelfie = () => {
    setSelfiePreview(null);
    setVerificationState("idle");
    setVerificationResult(null);
    setDetectedGender(null);
    setGenderChanged(false);
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      <Suspense fallback={
        <div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />
      }>
        <AuroraBackground />
      </Suspense>

      <header className="px-6 pt-4 pb-2 relative z-10">
        <div className="flex items-center gap-4 mb-2">
          <Button
            variant="ghost"
            size="icon"
            onClick={handleBack}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={4} totalSteps={10} />
          </div>
        </div>
      </header>

        <main className="flex-1 flex flex-col items-center px-4 pb-3 overflow-y-auto relative z-10">
        <ScreenTitle
          title="Take a Selfie"
          subtitle="We'll verify your identity with a quick AI check"
          logoSize="sm"
          className="mb-3"
        />

        {showCamera && (
          <div className="fixed inset-0 z-50 bg-background/95 flex flex-col items-center justify-center p-4">
            <div className="relative">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className="max-w-full max-h-[60vh] rounded-2xl border-2 border-primary/20"
              />
              <div className="absolute inset-0 border-4 border-primary/30 rounded-2xl pointer-events-none">
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-48 h-48 border-2 border-dashed border-primary/50 rounded-full" />
              </div>
            </div>
            <p className="text-sm text-muted-foreground mt-4 mb-2">
              Position your face in the circle
            </p>
            <div className="flex gap-4 mt-4">
              <Button variant="outline" onClick={stopCamera}>
                Cancel
              </Button>
              <Button onClick={capturePhoto} className="gap-2">
                <Camera className="h-4 w-4" />
                Take Selfie
              </Button>
            </div>
          </div>
        )}

        <canvas ref={canvasRef} className="hidden" />

        <Card className="w-full max-w-md p-3 bg-card/70 backdrop-blur-xl border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)] mb-2">
          <div className="flex items-center gap-2 mb-2">
            <Camera className="h-4 w-4 text-primary" />
            <h2 className="font-semibold text-sm text-foreground">Selfie for Verification</h2>
            {verificationState === "verified" && (
              <span className="ml-auto text-[10px] bg-accent/20 text-accent-foreground px-2 py-0.5 rounded-full flex items-center gap-1">
                <Check className="h-3 w-3" /> Verified
              </span>
            )}
          </div>

          {/* Gender info: selected vs AI-detected */}
          {(selectedGender || detectedGender) && (
            <div className={`
              mb-2 p-2 rounded-lg text-xs flex items-center justify-between gap-2 flex-wrap
              ${genderChanged
                ? "bg-amber-500/10 text-amber-700 dark:text-amber-400 border border-amber-500/30"
                : "bg-muted/50 text-muted-foreground border border-border"
              }
            `}>
              <div className="flex items-center gap-2">
                <span className="font-medium">Selected:</span>
                <span className="capitalize">{selectedGender ?? "—"}</span>
              </div>
              {detectedGender && (
                <div className="flex items-center gap-2">
                  <span className="font-medium">AI:</span>
                  <span className="capitalize">{detectedGender}</span>
                </div>
              )}
              {genderChanged && (
                <span className="text-[10px] uppercase tracking-wide font-semibold px-1.5 py-0.5 rounded bg-amber-500/20">
                  Auto-updated
                </span>
              )}
            </div>
          )}

          {!selfiePreview ? (
            <Button
              variant="outline"
              className="w-full h-28 border-dashed border-2 gap-2 flex-col"
              onClick={startCamera}
            >
              <Camera className="h-7 w-7 text-primary" />
              <span className="text-sm">Take a Selfie</span>
            </Button>
          ) : (
            <div className="relative">
              <div className="relative rounded-xl overflow-hidden mx-auto w-40 h-40 sm:w-48 sm:h-48 animate-in fade-in duration-500 bg-muted">
                <img
                  src={selfiePreview}
                  alt="Selfie preview"
                  className="w-full h-full object-cover cursor-zoom-in"
                  onClick={() => setLightboxSrc(selfiePreview)}
                />

                {verificationState === "verifying" && (
                  <div className="absolute inset-0 bg-background/80 flex flex-col items-center justify-center gap-2">
                    <div className="relative">
                      <Loader2 className="h-8 w-8 text-primary animate-spin" />
                      <Sparkles className="h-4 w-4 text-primary absolute -top-1 -right-1 animate-pulse" />
                    </div>
                    <p className="text-xs font-medium text-foreground">
                      Verifying...
                    </p>
                  </div>
                )}

                {verificationState === "verified" && (
                  <div className="absolute top-2 right-2 bg-green-500 text-white rounded-full p-1.5 animate-in zoom-in duration-300">
                    <Check className="h-4 w-4" />
                  </div>
                )}

                {verificationState === "failed" && (
                  <div className="absolute top-2 right-2 bg-destructive text-destructive-foreground rounded-full p-1.5 animate-in zoom-in duration-300">
                    <X className="h-4 w-4" />
                  </div>
                )}
              </div>

              {verificationResult && verificationState !== "verifying" && (
                <div className={`
                  mt-2 p-2 rounded-lg text-xs
                  ${verificationState === "verified"
                    ? "bg-green-500/10 text-green-600 dark:text-green-400"
                    : "bg-destructive/10 text-destructive"
                  }
                `}>
                  {verificationResult.reason}
                </div>
              )}
            </div>
          )}
        </Card>

        {selfiePreview && (
          <div className="sticky bottom-0 z-30 w-full max-w-md bg-background/95 backdrop-blur-md border border-border rounded-lg p-2 shadow-lg">
            <div className="grid grid-cols-2 gap-2">
              <Button
                variant="outline"
                size="lg"
                className="min-h-11"
                onClick={clearSelfie}
              >
                Retake
              </Button>
              <Button
                size="lg"
                className="min-h-11 gap-2"
                onClick={verifySelfie}
                disabled={verificationState === "verifying" || isVerifying}
                variant={verificationState === "verified" ? "outline" : "default"}
              >
                {verificationState === "verifying" ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Verifying
                  </>
                ) : verificationState === "verified" ? (
                  <>
                    <Check className="h-4 w-4" />
                    Re-verify
                  </>
                ) : (
                  <>
                    <Sparkles className="h-4 w-4" />
                    Verify
                  </>
                )}
              </Button>
            </div>
          </div>
        )}

        {lightboxSrc && (
          <div
            className="fixed inset-0 z-[200] bg-background/95 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200"
            onClick={() => setLightboxSrc(null)}
          >
            <img
              src={lightboxSrc}
              alt="Full preview"
              className="max-w-full max-h-full object-contain rounded-xl shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            />
            <Button
              variant="outline"
              size="icon"
              className="absolute top-4 right-4"
              onClick={() => setLightboxSrc(null)}
              aria-label="Close preview"
            >
              <X className="h-5 w-5" />
            </Button>
          </div>
        )}
      </main>

      <div className="sticky bottom-0 z-20 px-4 py-3 bg-background/90 backdrop-blur-md border-t border-border/50">
        <Button
          variant="aurora"
          className="w-full max-w-md mx-auto flex"
          size="lg"
          onClick={handleNext}
          disabled={!selfiePreview}
        >
          Continue
        </Button>
      </div>
    </div>
  );
};

export default PhotoUploadScreen;
