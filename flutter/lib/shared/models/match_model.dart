/// Match Model - Synced with matches table
class MatchModel {
  final String id;
  final String userId;
  final String matchedUserId;
  final int? matchScore;
  final String status;
  final DateTime? matchedAt;
  final DateTime? createdAt;

  const MatchModel({
    required this.id,
    required this.userId,
    required this.matchedUserId,
    this.matchScore,
    this.status = 'pending',
    this.matchedAt,
    this.createdAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      matchedUserId: json['matched_user_id'] as String,
      matchScore: json['match_score'] as int?,
      status: json['status'] as String? ?? 'pending',
      matchedAt: json['matched_at'] != null ? DateTime.parse(json['matched_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// Match Profile (with calculated score)
class MatchProfileModel {
  final String id;
  final String userId;
  final String? fullName;
  final int? age;
  final String? gender;
  final String? country;
  final String? state;
  final String? bio;
  final String? photoUrl;
  final List<String> interests;
  final String? occupation;
  final bool isVerified;
  final bool isOnline;
  final int matchScore;
  final List<String> commonLanguages;
  final List<String> commonInterests;

  const MatchProfileModel({
    required this.id,
    required this.userId,
    this.fullName,
    this.age,
    this.gender,
    this.country,
    this.state,
    this.bio,
    this.photoUrl,
    this.interests = const [],
    this.occupation,
    this.isVerified = false,
    this.isOnline = false,
    this.matchScore = 0,
    this.commonLanguages = const [],
    this.commonInterests = const [],
  });

  factory MatchProfileModel.fromJson(Map<String, dynamic> json) {
    return MatchProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String?,
      interests: (json['interests'] as List?)?.cast<String>() ?? [],
      occupation: json['occupation'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  MatchProfileModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    int? age,
    String? gender,
    String? country,
    String? state,
    String? bio,
    String? photoUrl,
    List<String>? interests,
    String? occupation,
    bool? isVerified,
    bool? isOnline,
    int? matchScore,
    List<String>? commonLanguages,
    List<String>? commonInterests,
  }) {
    return MatchProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      state: state ?? this.state,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      interests: interests ?? this.interests,
      occupation: occupation ?? this.occupation,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      matchScore: matchScore ?? this.matchScore,
      commonLanguages: commonLanguages ?? this.commonLanguages,
      commonInterests: commonInterests ?? this.commonInterests,
    );
  }
}

/// Match Filter Options
class MatchFilters {
  final int? minAge;
  final int? maxAge;
  final String? country;
  final String? state;
  final List<String>? languages;
  final List<String>? interests;
  final bool? onlineOnly;
  final bool? verifiedOnly;

  const MatchFilters({
    this.minAge,
    this.maxAge,
    this.country,
    this.state,
    this.languages,
    this.interests,
    this.onlineOnly,
    this.verifiedOnly,
  });
}
