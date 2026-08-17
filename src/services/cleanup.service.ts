import { classifyError, logError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";

/**
 * Triggers the data-cleanup edge function to clean up old data
 */
export const triggerDataCleanup = async (): Promise<{ success: boolean; error?: string }> => {
  try {
    const { data, error } = await supabase.functions.invoke('data-cleanup', {
      body: {},
    });

    if (error) throw error;
    return { success: data?.success ?? true, error: data?.error };
  } catch (error) {
    console.error('Data cleanup error:', error);
    return { success: false, error: classifyError(error, 'run cleanup').message };
  }
};

/**
 * Triggers the group-cleanup edge function to clean up old group messages
 */
export const triggerGroupCleanup = async (): Promise<{ success: boolean; error?: string }> => {
  try {
    const { data, error } = await supabase.functions.invoke('group-cleanup', {
      body: {},
    });

    if (error) throw error;
    return { success: data?.success ?? true, error: data?.error };
  } catch (error) {
    console.error('Group cleanup error:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
};

/**
 * Triggers the video-cleanup edge function to clean up old video sessions
 */
export const triggerVideoCleanup = async (): Promise<{ success: boolean; error?: string }> => {
  try {
    const { data, error } = await supabase.functions.invoke('video-cleanup', {
      body: {},
    });

    if (error) throw error;
    return { success: data?.success ?? true, error: data?.error };
  } catch (error) {
    console.error('Video cleanup error:', error);
    return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
};

/**
 * Verifies a photo using the verify-photo edge function
 */
export const verifyPhoto = async (
  imageBase64: string,
  expectedGender?: 'male' | 'female',
  userId?: string
): Promise<{
  verified: boolean;
  detectedGender?: string;
  confidence?: number;
  reason?: string;
  genderMatches?: boolean;
}> => {
  try {
    const { data, error } = await supabase.functions.invoke('verify-photo', {
      body: {
        imageBase64,
        expectedGender,
        userId,
        verificationType: 'selfie',
      },
    });

    if (error) throw error;

    return {
      verified: data?.verified ?? false,
      detectedGender: data?.detectedGender ?? data?.detected_gender,
      confidence: data?.confidence,
      reason: data?.reason,
      genderMatches: data?.genderMatches ?? data?.gender_matches,
    };
  } catch (error) {
    console.error('Photo verification error:', error);
    return { verified: false, reason: 'Photo verification failed. Please try again.' };
  }
};

/**
 * Runs all cleanup tasks - useful for admin manual trigger
 */
export const runAllCleanups = async (): Promise<{
  dataCleanup: { success: boolean; error?: string };
  groupCleanup: { success: boolean; error?: string };
  videoCleanup: { success: boolean; error?: string };
}> => {
  const [dataCleanup, groupCleanup, videoCleanup] = await Promise.all([
    triggerDataCleanup(),
    triggerGroupCleanup(),
    triggerVideoCleanup(),
  ]);

  return { dataCleanup, groupCleanup, videoCleanup };
};
