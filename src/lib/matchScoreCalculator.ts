/**
 * Match Score Calculator
 * 
 * Calculates compatibility score between two users based on:
 * - Language compatibility (primary factor)
 * - Location matching (country/state)
 * - Profile completeness
 * - Interests overlap
 * - Lifestyle compatibility
 */

export interface UserProfile {
  user_id: string;
  country?: string | null;
  state?: string | null;
  preferred_language?: string | null;
  interests?: string[] | null;
  education_level?: string | null;
  occupation?: string | null;
  religion?: string | null;
  marital_status?: string | null;
  smoking_habit?: string | null;
  drinking_habit?: string | null;
  dietary_preference?: string | null;
  fitness_level?: string | null;
  pet_preference?: string | null;
  zodiac_sign?: string | null;
  age?: number | null;
  bio?: string | null;
  photo_url?: string | null;
}

export interface MatchScoreResult {
  totalScore: number;
  breakdown: {
    languageScore: number;
    locationScore: number;
    interestsScore: number;
    lifestyleScore: number;
    profileScore: number;
  };
}

/**
 * Calculate match score between current user and another user
 * @param currentUser - Current user's profile
 * @param otherUser - Other user's profile
 * @param currentUserLanguages - Languages spoken by current user
 * @param otherUserLanguages - Languages spoken by other user
 * @returns Match score (0-100) with breakdown
 */
export function calculateMatchScore(
  currentUser: UserProfile,
  otherUser: UserProfile,
  currentUserLanguages: string[] = [],
  otherUserLanguages: string[] = []
): MatchScoreResult {
  let languageScore = 0;
  let locationScore = 0;
  let interestsScore = 0;
  let lifestyleScore = 0;
  let profileScore = 0;

  // ============= LANGUAGE COMPATIBILITY (Max 35 points) =============
  // This is the most important factor for communication
  
  // Find common languages
  const commonLanguages = currentUserLanguages.filter(lang => 
    otherUserLanguages.some(l => l.toLowerCase() === lang.toLowerCase())
  );
  
  if (commonLanguages.length > 0) {
    // First common language: 20 points
    languageScore += 20;
    // Each additional common language: 5 points (max 15 more)
    languageScore += Math.min((commonLanguages.length - 1) * 5, 15);
  } else if (currentUser.preferred_language && otherUser.preferred_language) {
    // Check if preferred languages match
    if (currentUser.preferred_language.toLowerCase() === otherUser.preferred_language.toLowerCase()) {
      languageScore += 15;
    }
  }

  // ============= LOCATION COMPATIBILITY (Max 20 points) =============
  
  // Same country: 10 points
  if (currentUser.country && otherUser.country && 
      currentUser.country.toLowerCase() === otherUser.country.toLowerCase()) {
    locationScore += 10;
    
    // Same state within same country: additional 10 points
    if (currentUser.state && otherUser.state && 
        currentUser.state.toLowerCase() === otherUser.state.toLowerCase()) {
      locationScore += 10;
    }
  }

  // ============= INTERESTS OVERLAP (Max 20 points) =============
  
  const currentInterests = currentUser.interests || [];
  const otherInterests = otherUser.interests || [];
  
  if (currentInterests.length > 0 && otherInterests.length > 0) {
    const commonInterests = currentInterests.filter(interest =>
      otherInterests.some(i => i.toLowerCase() === interest.toLowerCase())
    );
    
    // Each common interest: 4 points (max 20)
    interestsScore = Math.min(commonInterests.length * 4, 20);
  }

  // ============= LIFESTYLE COMPATIBILITY (Max 15 points) =============
  
  let lifestyleMatches = 0;
  
  // Education level match
  if (currentUser.education_level && otherUser.education_level &&
      currentUser.education_level === otherUser.education_level) {
    lifestyleMatches++;
  }
  
  // Religion match
  if (currentUser.religion && otherUser.religion &&
      currentUser.religion.toLowerCase() === otherUser.religion.toLowerCase()) {
    lifestyleMatches++;
  }
  
  // Marital status compatibility
  if (currentUser.marital_status && otherUser.marital_status &&
      currentUser.marital_status === otherUser.marital_status) {
    lifestyleMatches++;
  }
  
  // Smoking habit compatibility
  if (currentUser.smoking_habit && otherUser.smoking_habit &&
      currentUser.smoking_habit === otherUser.smoking_habit) {
    lifestyleMatches++;
  }
  
  // Drinking habit compatibility
  if (currentUser.drinking_habit && otherUser.drinking_habit &&
      currentUser.drinking_habit === otherUser.drinking_habit) {
    lifestyleMatches++;
  }
  
  // Dietary preference match
  if (currentUser.dietary_preference && otherUser.dietary_preference &&
      currentUser.dietary_preference === otherUser.dietary_preference) {
    lifestyleMatches++;
  }
  
  // Fitness level match
  if (currentUser.fitness_level && otherUser.fitness_level &&
      currentUser.fitness_level === otherUser.fitness_level) {
    lifestyleMatches++;
  }
  
  // Pet preference match
  if (currentUser.pet_preference && otherUser.pet_preference &&
      currentUser.pet_preference === otherUser.pet_preference) {
    lifestyleMatches++;
  }
  
  // Zodiac compatibility (same element signs tend to be compatible)
  if (currentUser.zodiac_sign && otherUser.zodiac_sign) {
    const zodiacElements: Record<string, string> = {
      'aries': 'fire', 'leo': 'fire', 'sagittarius': 'fire',
      'taurus': 'earth', 'virgo': 'earth', 'capricorn': 'earth',
      'gemini': 'air', 'libra': 'air', 'aquarius': 'air',
      'cancer': 'water', 'scorpio': 'water', 'pisces': 'water'
    };
    
    const currentElement = zodiacElements[currentUser.zodiac_sign.toLowerCase()];
    const otherElement = zodiacElements[otherUser.zodiac_sign.toLowerCase()];
    
    if (currentElement && otherElement && currentElement === otherElement) {
      lifestyleMatches++;
    }
  }
  
  // Each lifestyle match: ~1.67 points (max 15 from 9 possible matches)
  lifestyleScore = Math.min(Math.round(lifestyleMatches * 1.67), 15);

  // ============= PROFILE COMPLETENESS (Max 10 points) =============
  // Users with complete profiles are more serious
  
  let profileCompleteness = 0;
  
  if (otherUser.bio && otherUser.bio.length > 20) profileCompleteness += 2;
  if (otherUser.photo_url) profileCompleteness += 2;
  if (otherUser.age) profileCompleteness += 1;
  if (otherUser.occupation) profileCompleteness += 1;
  if (otherUser.education_level) profileCompleteness += 1;
  if (otherInterests.length > 0) profileCompleteness += 1;
  if (otherUserLanguages.length > 0) profileCompleteness += 1;
  if (otherUser.country) profileCompleteness += 1;
  
  profileScore = Math.min(profileCompleteness, 10);

  // ============= CALCULATE TOTAL SCORE =============
  
  const totalScore = Math.min(
    languageScore + locationScore + interestsScore + lifestyleScore + profileScore,
    100
  );

  return {
    totalScore,
    breakdown: {
      languageScore,
      locationScore,
      interestsScore,
      lifestyleScore,
      profileScore
    }
  };
}

/**
 * Quick match score calculation for simpler use cases
 * Returns just the numeric score
 */
export async function getQuickMatchScore(
  supabase: any,
  currentUserId: string,
  otherUserId: string
): Promise<number> {
  try {
    // Fetch both profiles - current user via direct table (owner), other via secure RPC
    const { fetchPublicProfile } = await import("@/lib/profile-queries");
    const [currentProfileResult, otherProfile] = await Promise.all([
      supabase
        .from("profiles")
        .select("user_id, country, state, preferred_language, interests, education_level, occupation, religion, marital_status, smoking_habit, drinking_habit, dietary_preference, fitness_level, pet_preference, zodiac_sign, age, bio, photo_url")
        .eq("user_id", currentUserId)
        .maybeSingle(),
      fetchPublicProfile(otherUserId)
    ]);

    const currentProfile = currentProfileResult.data;

    if (!currentProfile || !otherProfile) {
      return 50; // Default score if profiles not found
    }

    // Fetch languages for both users
    const [currentLangsResult, otherLangsResult] = await Promise.all([
      supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", currentUserId),
      supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", otherUserId)
    ]);

    const currentLanguages = currentLangsResult.data?.map((l: any) => l.language_name) || [];
    const otherLanguages = otherLangsResult.data?.map((l: any) => l.language_name) || [];

    const result = calculateMatchScore(
      currentProfile,
      otherProfile,
      currentLanguages,
      otherLanguages
    );

    return result.totalScore;
  } catch (error) {
    console.error("Error calculating match score:", error);
    return 50; // Default score on error
  }
}
