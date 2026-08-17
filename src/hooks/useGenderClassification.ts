/**
 * useGenderClassification Hook
 * 
 * Uses face-api.js for client-side gender classification.
 * This hook wraps useFaceVerification for backward compatibility.
 */

import { useState, useCallback, useEffect } from 'react';
import { useFaceVerification } from './useFaceVerification';

export interface GenderClassificationResult {
  verified: boolean;
  hasFace: boolean;
  detectedGender: 'male' | 'female' | 'unknown';
  confidence: number;
  reason: string;
  genderMatches: boolean;
}

export interface UseGenderClassificationReturn {
  isVerifying: boolean;
  isLoadingModel: boolean;
  modelLoadProgress: number;
  classifyGender: (imageBase64: string, expectedGender?: 'male' | 'female') => Promise<GenderClassificationResult>;
}

export const useGenderClassification = (): UseGenderClassificationReturn => {
  const { isVerifying, isLoadingModel, modelLoadProgress, verifyFace } = useFaceVerification();

  const classifyGender = useCallback(async (
    imageBase64: string,
    expectedGender?: 'male' | 'female'
  ): Promise<GenderClassificationResult> => {
    const result = await verifyFace(imageBase64, expectedGender);
    
    return {
      verified: result.verified,
      hasFace: result.hasFace,
      detectedGender: result.detectedGender,
      confidence: result.confidence,
      reason: result.reason,
      genderMatches: result.genderMatches ?? true
    };
  }, [verifyFace]);

  return {
    isVerifying,
    isLoadingModel,
    modelLoadProgress,
    classifyGender
  };
};
