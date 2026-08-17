/**
 * useFaceVerification Hook
 * 
 * Uses face-api.js for client-side face detection and gender classification.
 * Models are loaded from the public/models directory.
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import * as faceapi from 'face-api.js';

export interface FaceVerificationResult {
  verified: boolean;
  hasFace: boolean;
  detectedGender: 'male' | 'female' | 'unknown';
  confidence: number;
  reason: string;
  genderMatches?: boolean;
  autoAccepted?: boolean;
  modelLoadFailed?: boolean;
}

export interface UseFaceVerificationReturn {
  isVerifying: boolean;
  isLoadingModel: boolean;
  modelLoadProgress: number;
  verifyFace: (imageBase64: string, expectedGender?: 'male' | 'female') => Promise<FaceVerificationResult>;
}

// Model loading state - shared across instances
let modelsLoaded = false;
let modelsLoading = false;
let modelLoadPromise: Promise<void> | null = null;
let modelLoadError: string | null = null;

// Primary and fallback CDN URLs for face-api.js models (version-locked)
const MODEL_URLS = [
  'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.12/model',
  'https://unpkg.com/@vladmandic/face-api@1.7.12/model',
];

const MAX_LOAD_RETRIES = 2;

export const useFaceVerification = (): UseFaceVerificationReturn => {
  const [isVerifying, setIsVerifying] = useState(false);
  const [isLoadingModel, setIsLoadingModel] = useState(!modelsLoaded);
  const [modelLoadProgress, setModelLoadProgress] = useState(modelsLoaded ? 100 : 0);
  const loadAttempted = useRef(false);

  // Load face-api.js models on mount
  useEffect(() => {
    const loadModels = async () => {
      if (modelsLoaded) {
        setIsLoadingModel(false);
        setModelLoadProgress(100);
        return;
      }

      if (modelsLoading && modelLoadPromise) {
        await modelLoadPromise;
        setIsLoadingModel(false);
        setModelLoadProgress(100);
        return;
      }

      if (loadAttempted.current) return;
      loadAttempted.current = true;

      modelsLoading = true;
      setIsLoadingModel(true);

      modelLoadPromise = (async () => {
        let lastError: unknown = null;

        for (const modelUrl of MODEL_URLS) {
          for (let attempt = 1; attempt <= MAX_LOAD_RETRIES; attempt++) {
            try {
              console.log(`[FaceAPI] Loading models from: ${modelUrl} (attempt ${attempt})`);
              setModelLoadProgress(10);

              await Promise.all([
                faceapi.nets.tinyFaceDetector.loadFromUri(modelUrl),
                faceapi.nets.ageGenderNet.loadFromUri(modelUrl),
                faceapi.nets.faceLandmark68Net.loadFromUri(modelUrl),
              ]);
              console.log('[FaceAPI] All models loaded in parallel');
              setModelLoadProgress(100);

              modelsLoaded = true;
              modelLoadError = null;
              console.log('[FaceAPI] All models loaded successfully');
              return; // Success — exit both loops
            } catch (error) {
              lastError = error;
              console.warn(`[FaceAPI] Load attempt ${attempt} from ${modelUrl} failed:`, error);
            }
          }
        }

        // All CDNs and retries exhausted
        modelLoadError = lastError instanceof Error ? lastError.message : 'All CDN sources failed';
        console.error('[FaceAPI] All model load attempts failed:', modelLoadError);
        modelsLoading = false;
        loadAttempted.current = false;
        throw new Error(modelLoadError);
      })();

      try {
        await modelLoadPromise;
      } catch (error) {
        console.error('[FaceAPI] Model loading failed:', error);
      }
      
      setIsLoadingModel(false);
    };

    loadModels();
  }, []);

  const verifyFace = useCallback(async (
    imageBase64: string,
    expectedGender?: 'male' | 'female'
  ): Promise<FaceVerificationResult> => {
    setIsVerifying(true);

    try {
      // Wait for models if still loading
      if (!modelsLoaded && modelLoadPromise) {
        console.log('[FaceAPI] Waiting for models to load...');
        await modelLoadPromise;
      }

      if (!modelsLoaded) {
        console.warn('[FaceAPI] Models not loaded — rejecting verification');
        return {
          verified: false,
          hasFace: false,
          detectedGender: 'unknown',
          confidence: 0,
          reason: 'Face verification models failed to load. Please check your internet connection and try again.',
          genderMatches: false,
          modelLoadFailed: true
        };
      }

      // Create image element from base64
      const img = await createImageFromBase64(imageBase64);
      console.log('[FaceAPI] Image loaded, detecting faces...');

      // Detect faces with age and gender
      const detections = await faceapi
        .detectAllFaces(img, new faceapi.TinyFaceDetectorOptions({ inputSize: 416, scoreThreshold: 0.5 }))
        .withFaceLandmarks()
        .withAgeAndGender();

      console.log('[FaceAPI] Detections:', detections.length);

      if (detections.length === 0) {
        return {
          verified: false,
          hasFace: false,
          detectedGender: 'unknown',
          confidence: 0,
          reason: 'No face detected in the image',
          genderMatches: false
        };
      }

      // Use the first (or largest) face
      const detection = detections.reduce((prev, curr) => 
        curr.detection.box.area > prev.detection.box.area ? curr : prev
      );

      const detectedGender = detection.gender as 'male' | 'female';
      const genderProbability = detection.genderProbability;
      
      console.log('[FaceAPI] Detected gender:', detectedGender, 'probability:', genderProbability);

      // Check if gender matches expected
      const genderMatches = !expectedGender || detectedGender === expectedGender;

      return {
        verified: true,
        hasFace: true,
        detectedGender,
        confidence: genderProbability,
        reason: genderMatches 
          ? `Face verified as ${detectedGender}` 
          : `Detected ${detectedGender}, updating gender`,
        genderMatches
      };
    } catch (error) {
      console.error('[FaceAPI] Verification error:', error);
      // On error, reject — do not silently auto-accept
      return {
        verified: false,
        hasFace: false,
        detectedGender: 'unknown',
        confidence: 0,
        reason: 'Face verification failed due to an error. Please try again.',
        genderMatches: false
      };
    } finally {
      setIsVerifying(false);
    }
  }, []);

  return {
    isVerifying,
    isLoadingModel,
    modelLoadProgress,
    verifyFace,
  };
};

// Helper function to create an image element from base64
async function createImageFromBase64(base64: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    
    img.onload = () => resolve(img);
    img.onerror = (error) => reject(error);
    
    // Handle both with and without data URI prefix
    if (base64.startsWith('data:')) {
      img.src = base64;
    } else {
      img.src = `data:image/jpeg;base64,${base64}`;
    }
  });
}
