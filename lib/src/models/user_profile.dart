class UserProfile {
  final String nickname;
  final String avatarEmoji;
  final String? avatarImagePath;
  final String bio;

  const UserProfile({
    this.nickname = '学习者',
    this.avatarEmoji = '🎓',
    this.avatarImagePath,
    this.bio = '好好学习，天天向上',
  });

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'avatarEmoji': avatarEmoji,
        if (avatarImagePath != null) 'avatarImagePath': avatarImagePath,
        'bio': bio,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        nickname: (json['nickname'] as String?) ?? '学习者',
        avatarEmoji: (json['avatarEmoji'] as String?) ?? '🎓',
        avatarImagePath: json['avatarImagePath'] as String?,
        bio: (json['bio'] as String?) ?? '好好学习，天天向上',
      );

  UserProfile copyWith({
    String? nickname,
    String? avatarEmoji,
    String? avatarImagePath,
    String? bio,
  }) =>
      UserProfile(
        nickname: nickname ?? this.nickname,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarImagePath:
            avatarImagePath ?? this.avatarImagePath,
        bio: bio ?? this.bio,
      );
}
