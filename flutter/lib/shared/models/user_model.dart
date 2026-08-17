/// User Model - Synced with profiles table in database
/// Plain Dart class (no Freezed) for simplicity
class UserModel {
  final String id;
  final String userId;
  final String? email;
  final String? phone;
  final String? fullName;
  final int? age;
  final String? gender;
  final String? dateOfBirth;
  final String? country;
  final String? state;
  final String? city;
  final String? bio;
  final String? photoUrl;
  final List<String> interests;
  final List<String> lifeGoals;
  final String? occupation;
  final String? educationLevel;
  final String? religion;
  final String? maritalStatus;
  final int? heightCm;
  final String? bodyType;
  final String? preferredLanguage;
  final String? primaryLanguage;
  final String? smokingHabit;
  final String? drinkingHabit;
  final String? dietaryPreference;
  final String? fitnessLevel;
  final bool? hasChildren;
  final String? petPreference;
  final String? travelFrequency;
  final String? personalityType;
  final String? zodiacSign;
  final bool isVerified;
  final bool isPremium;
  final String approvalStatus;
  final String accountStatus;
  final bool? aiApproved;
  final String? aiDisapprovalReason;
  final int? performanceScore;
  final int? avgResponseTimeSeconds;
  final int? totalChatsCount;
  final int? profileCompleteness;
  final bool? isEarningEligible;
  final bool? hasGoldenBadge;
  final String? goldenBadgeExpiresAt;
  final String? earningBadgeType;
  final int? monthlyChatMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActiveAt;

  const UserModel({
    required this.id,
    required this.userId,
    this.email,
    this.phone,
    this.fullName,
    this.age,
    this.gender,
    this.dateOfBirth,
    this.country,
    this.state,
    this.city,
    this.bio,
    this.photoUrl,
    this.interests = const [],
    this.lifeGoals = const [],
    this.occupation,
    this.educationLevel,
    this.religion,
    this.maritalStatus,
    this.heightCm,
    this.bodyType,
    this.preferredLanguage,
    this.primaryLanguage,
    this.smokingHabit,
    this.drinkingHabit,
    this.dietaryPreference,
    this.fitnessLevel,
    this.hasChildren,
    this.petPreference,
    this.travelFrequency,
    this.personalityType,
    this.zodiacSign,
    this.isVerified = false,
    this.isPremium = false,
    this.approvalStatus = 'pending',
    this.accountStatus = 'active',
    this.aiApproved,
    this.aiDisapprovalReason,
    this.performanceScore,
    this.avgResponseTimeSeconds,
    this.totalChatsCount,
    this.profileCompleteness,
    this.isEarningEligible,
    this.hasGoldenBadge,
    this.goldenBadgeExpiresAt,
    this.earningBadgeType,
    this.monthlyChatMinutes,
    this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
  });

  /// Factory from profiles table JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String?,
      interests: (json['interests'] as List?)?.cast<String>() ?? [],
      lifeGoals: (json['life_goals'] as List?)?.cast<String>() ?? [],
      occupation: json['occupation'] as String?,
      educationLevel: json['education_level'] as String?,
      religion: json['religion'] as String?,
      maritalStatus: json['marital_status'] as String?,
      heightCm: json['height_cm'] as int?,
      bodyType: json['body_type'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      primaryLanguage: json['primary_language'] as String?,
      smokingHabit: json['smoking_habit'] as String?,
      drinkingHabit: json['drinking_habit'] as String?,
      dietaryPreference: json['dietary_preference'] as String?,
      fitnessLevel: json['fitness_level'] as String?,
      hasChildren: json['has_children'] as bool?,
      petPreference: json['pet_preference'] as String?,
      travelFrequency: json['travel_frequency'] as String?,
      personalityType: json['personality_type'] as String?,
      zodiacSign: json['zodiac_sign'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      accountStatus: json['account_status'] as String? ?? 'active',
      aiApproved: json['ai_approved'] as bool?,
      aiDisapprovalReason: json['ai_disapproval_reason'] as String?,
      performanceScore: json['performance_score'] as int?,
      avgResponseTimeSeconds: json['avg_response_time_seconds'] as int?,
      totalChatsCount: json['total_chats_count'] as int?,
      profileCompleteness: json['profile_completeness'] as int?,
      isEarningEligible: json['is_earning_eligible'] as bool?,
      hasGoldenBadge: json['has_golden_badge'] as bool?,
      goldenBadgeExpiresAt: json['golden_badge_expires_at'] as String?,
      earningBadgeType: json['earning_badge_type'] as String?,
      monthlyChatMinutes: json['monthly_chat_minutes'] as int?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at']) : null,
    );
  }

  /// Convert to JSON for updates
  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'age': age,
      'date_of_birth': dateOfBirth,
      'country': country,
      'state': state,
      'city': city,
      'bio': bio,
      'photo_url': photoUrl,
      'interests': interests,
      'life_goals': lifeGoals,
      'occupation': occupation,
      'education_level': educationLevel,
      'religion': religion,
      'marital_status': maritalStatus,
      'height_cm': heightCm,
      'body_type': bodyType,
      'preferred_language': preferredLanguage,
      'primary_language': primaryLanguage,
      'smoking_habit': smokingHabit,
      'drinking_habit': drinkingHabit,
      'dietary_preference': dietaryPreference,
      'fitness_level': fitnessLevel,
      'has_children': hasChildren,
      'pet_preference': petPreference,
      'travel_frequency': travelFrequency,
      'personality_type': personalityType,
      'zodiac_sign': zodiacSign,
    };
  }

  UserModel copyWith({
    String? id,
    String? userId,
    String? email,
    String? phone,
    String? fullName,
    int? age,
    String? gender,
    String? dateOfBirth,
    String? country,
    String? state,
    String? city,
    String? bio,
    String? photoUrl,
    List<String>? interests,
    List<String>? lifeGoals,
    String? occupation,
    String? educationLevel,
    String? religion,
    String? maritalStatus,
    int? heightCm,
    String? bodyType,
    String? preferredLanguage,
    String? primaryLanguage,
    bool? isVerified,
    bool? isPremium,
    String? approvalStatus,
    String? accountStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      interests: interests ?? this.interests,
      lifeGoals: lifeGoals ?? this.lifeGoals,
      occupation: occupation ?? this.occupation,
      educationLevel: educationLevel ?? this.educationLevel,
      religion: religion ?? this.religion,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      heightCm: heightCm ?? this.heightCm,
      bodyType: bodyType ?? this.bodyType,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  /// Check if user has active golden badge
  bool get hasActiveGoldenBadge {
    if (hasGoldenBadge != true || goldenBadgeExpiresAt == null) return false;
    return DateTime.parse(goldenBadgeExpiresAt!).isAfter(DateTime.now());
  }

  /// Check if profile is female
  bool get isFemale => gender?.toLowerCase() == 'female';

  /// Check if profile is male  
  bool get isMale => gender?.toLowerCase() == 'male';
}

/// User Status Model
class UserStatusModel {
  final String id;
  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? statusText;

  const UserStatusModel({
    required this.id,
    required this.userId,
    this.isOnline = false,
    this.lastSeen,
    this.statusText,
  });
}

/// User Settings Model
class UserSettingsModel {
  final String userId;
  final String theme;
  final String language;
  final bool autoTranslate;
  final bool notificationSound;
  final bool notificationVibration;
  final bool showOnlineStatus;
  final bool showReadReceipts;
  final String profileVisibility;

  const UserSettingsModel({
    required this.userId,
    this.theme = 'system',
    this.language = 'en',
    this.autoTranslate = true,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.showOnlineStatus = true,
    this.showReadReceipts = true,
    this.profileVisibility = 'all',
  });
}

/// User Language Model
class UserLanguageModel {
  final String id;
  final String userId;
  final String languageCode;
  final String languageName;
  final DateTime? createdAt;

  const UserLanguageModel({
    required this.id,
    required this.userId,
    required this.languageCode,
    required this.languageName,
    this.createdAt,
  });
}
