import { useState, useRef, useCallback, useEffect, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import ProgressIndicator from "@/components/ProgressIndicator";
import ScreenTitle from "@/components/ScreenTitle";
import { toast } from "@/hooks/use-toast";
import { ArrowLeft, Upload, X, Plus, Trash2 } from "lucide-react";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

const MAX_ADDITIONAL_PHOTOS = 5;

const AdditionalPhotosScreen = () => {
  const navigate = useNavigate();
  // Selfie must be completed first
  useRegistrationGuard(
    [{ key: "userEmail" }, { key: "userGender" }, { key: "pendingPhotoData" }],
    "/photo-upload"
  );
  const additionalFileInputRef = useRef<HTMLInputElement>(null);

  const [additionalPhotos, setAdditionalPhotos] = useState<string[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [lightboxSrc, setLightboxSrc] = useState<string | null>(null);

  // Restore previously uploaded photos if user navigates back
  useEffect(() => {
    const existing = sessionStorage.getItem("pendingAdditionalPhotos");
    if (existing) {
      try {
        const parsed = JSON.parse(existing);
        if (Array.isArray(parsed)) setAdditionalPhotos(parsed);
      } catch {
        // ignore
      }
    }
  }, []);

  const handleAdditionalPhoto = useCallback((file: File) => {
    return new Promise<boolean>((resolve) => {
      if (!file.type.startsWith("image/")) {
        toast({
          title: "Invalid file type",
          description: `${file.name} is not an image`,
          variant: "destructive",
        });
        return resolve(false);
      }

      if (file.size > 10 * 1024 * 1024) {
        toast({
          title: "File too large",
          description: `${file.name} is larger than 10MB`,
          variant: "destructive",
        });
        return resolve(false);
      }

      const reader = new FileReader();
      reader.onload = (e) => {
        const dataUrl = e.target?.result as string;
        setAdditionalPhotos((prev) => {
          if (prev.length >= MAX_ADDITIONAL_PHOTOS) {
            toast({
              title: "Maximum photos reached",
              description: `You can only add ${MAX_ADDITIONAL_PHOTOS} additional photos`,
              variant: "destructive",
            });
            return prev;
          }
          return [...prev, dataUrl];
        });
        resolve(true);
      };
      reader.onerror = () => resolve(false);
      reader.readAsDataURL(file);
    });
  }, []);

  const handleAdditionalPhotos = useCallback(
    async (files: FileList | File[]) => {
      const fileArr = Array.from(files);
      const remaining = MAX_ADDITIONAL_PHOTOS - additionalPhotos.length;
      if (remaining <= 0) {
        toast({
          title: "Maximum photos reached",
          description: `You can only add ${MAX_ADDITIONAL_PHOTOS} additional photos`,
          variant: "destructive",
        });
        return;
      }
      const toProcess = fileArr.slice(0, remaining);
      if (fileArr.length > remaining) {
        toast({
          title: "Some photos skipped",
          description: `Only ${remaining} more photo(s) can be added`,
        });
      }
      for (const file of toProcess) {
        await handleAdditionalPhoto(file);
      }
    },
    [additionalPhotos.length, handleAdditionalPhoto]
  );

  const removeAdditionalPhoto = (index: number) => {
    setAdditionalPhotos((prev) => prev.filter((_, i) => i !== index));
  };

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragging(false);
      const files = e.dataTransfer.files;
      if (files && files.length > 0) handleAdditionalPhotos(files);
    },
    [handleAdditionalPhotos]
  );

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback(() => {
    setIsDragging(false);
  }, []);

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
    if (additionalPhotos.length < MAX_ADDITIONAL_PHOTOS) {
      toast({
        title: "All 5 photos required",
        description: `Please upload ${MAX_ADDITIONAL_PHOTOS - additionalPhotos.length} more photo(s).`,
        variant: "destructive",
      });
      return;
    }

    try {
      const compressedPhotos = await Promise.all(
        additionalPhotos.map((p) => compressImage(p))
      );
      sessionStorage.setItem(
        "pendingAdditionalPhotos",
        JSON.stringify(compressedPhotos)
      );
    } catch (storageError) {
      console.warn("Failed to save photos:", storageError);
      toast({
        title: "Storage Error",
        description:
          "Unable to save photos. Your device storage may be full. Please free up space and try again.",
        variant: "destructive",
      });
      return;
    }

    toast({
      title: "Photos saved!",
      description: "Your photos have been saved",
    });

    navigate("/location-setup");
  };

  const handleBack = () => {
    navigate("/photo-upload");
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      <Suspense
        fallback={
          <div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />
        }
      >
        <AuroraBackground />
      </Suspense>

      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex items-center gap-4 mb-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={handleBack}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={5} totalSteps={10} />
          </div>
        </div>
      </header>

      <main className="flex-1 flex flex-col items-center px-4 pb-6 overflow-y-auto relative z-10">
        <ScreenTitle
          title="Add 5 More Photos"
          subtitle="Upload 5 clear photos to complete your profile"
          logoSize="md"
          className="mb-4"
        />

        <Card className="w-full max-w-2xl p-4 bg-card/70 backdrop-blur-xl border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
          <div className="flex items-center gap-2 mb-3">
            <Upload className="h-4 w-4 text-primary" />
            <h2 className="font-semibold text-foreground text-sm">
              Additional Photos <span className="text-destructive">*</span>
            </h2>
            <span className="ml-auto text-xs text-muted-foreground">
              {additionalPhotos.length}/{MAX_ADDITIONAL_PHOTOS} required
            </span>
          </div>

          <input
            ref={additionalFileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={(e) => {
              const files = e.target.files;
              if (files && files.length > 0) handleAdditionalPhotos(files);
              e.target.value = "";
            }}
            className="hidden"
          />

          {/* 5 slots in one row so all photo upload buttons are always visible */}
          <div className="grid grid-cols-5 gap-2">
            {additionalPhotos.map((photo, index) => (
              <div
                key={index}
                className="relative aspect-square rounded-lg overflow-hidden group animate-in fade-in duration-300 bg-muted"
              >
                <img
                  src={photo}
                  alt={`Photo ${index + 1}`}
                  className="w-full h-full object-cover cursor-zoom-in"
                  onClick={() => setLightboxSrc(photo)}
                />
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    removeAdditionalPhoto(index);
                  }}
                  className="absolute top-0.5 right-0.5 p-1 bg-destructive/90 text-destructive-foreground rounded-full opacity-95 hover:opacity-100 transition-opacity"
                  aria-label={`Remove photo ${index + 1}`}
                >
                  <Trash2 className="h-3 w-3" />
                </button>
                <span className="absolute bottom-0.5 left-0.5 text-[9px] bg-background/70 text-foreground px-1 py-0.5 rounded">
                  {index + 1}
                </span>
              </div>
            ))}

            {Array.from({
              length: MAX_ADDITIONAL_PHOTOS - additionalPhotos.length,
            }).map((_, i) => {
              const isFirstEmpty = i === 0;
              const slotNumber = additionalPhotos.length + i + 1;
              return (
                <div
                  key={`empty-${i}`}
                  onDrop={isFirstEmpty ? handleDrop : undefined}
                  onDragOver={isFirstEmpty ? handleDragOver : undefined}
                  onDragLeave={isFirstEmpty ? handleDragLeave : undefined}
                  onClick={() => additionalFileInputRef.current?.click()}
                  className={`
                    aspect-square rounded-lg border-2 border-dashed flex flex-col items-center justify-center gap-0.5
                    cursor-pointer transition-all duration-200
                    ${isFirstEmpty && isDragging
                      ? "border-primary bg-primary/10"
                      : "border-border hover:border-primary/50 hover:bg-primary/5"
                    }
                  `}
                  aria-label={`Add photo ${slotNumber}`}
                >
                  <Plus className="h-5 w-5 text-muted-foreground" />
                  <span className="text-[9px] text-muted-foreground leading-none">
                    {slotNumber}
                  </span>
                </div>
              );
            })}
          </div>

          {/* Bulk-add helper for users who prefer a big button */}
          {additionalPhotos.length < MAX_ADDITIONAL_PHOTOS && (
            <Button
              variant="outline"
              size="sm"
              className="w-full mt-3 gap-2"
              onClick={() => additionalFileInputRef.current?.click()}
            >
              <Plus className="h-4 w-4" />
              Add {MAX_ADDITIONAL_PHOTOS - additionalPhotos.length} more photo{MAX_ADDITIONAL_PHOTOS - additionalPhotos.length === 1 ? "" : "s"}
            </Button>
          )}

          <p className="text-xs text-muted-foreground mt-3 text-center">
            Tap any slot to upload. You can select multiple photos at once. Tap a photo to preview full size.
          </p>
        </Card>

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

        <Button
          variant="aurora"
          className="w-full max-w-2xl mt-4"
          size="lg"
          onClick={handleNext}
          disabled={additionalPhotos.length < MAX_ADDITIONAL_PHOTOS}
        >
          {additionalPhotos.length < MAX_ADDITIONAL_PHOTOS
            ? `Upload ${MAX_ADDITIONAL_PHOTOS - additionalPhotos.length} more to continue`
            : "Continue"}
        </Button>
      </main>
    </div>
  );
};

export default AdditionalPhotosScreen;
