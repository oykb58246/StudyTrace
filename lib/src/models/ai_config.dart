/// AI service configuration stored in local preferences.
///
/// API keys are intentionally not part of this model; they are stored through
/// AiCredentialService using the platform secure storage APIs.
class AiConfig {
  final String provider;
  final String baseUrl;
  final String model;
  final bool thinkingMode;
  final bool isEnabled;

  const AiConfig({
    this.provider = 'deepseek',
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    this.thinkingMode = false,
    this.isEnabled = false,
  });

  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-v4-flash';

  AiConfig copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    bool? thinkingMode,
    bool? isEnabled,
  }) {
    return AiConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'baseUrl': baseUrl,
      'model': model,
      'thinkingMode': thinkingMode,
      'isEnabled': isEnabled,
    };
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = json['baseUrl'] as String?;
    final model = json['model'] as String?;
    return AiConfig(
      provider: json['provider'] as String? ?? 'deepseek',
      baseUrl: (baseUrl == null || baseUrl.trim().isEmpty)
          ? defaultBaseUrl
          : baseUrl.trim(),
      model:
          (model == null || model.trim().isEmpty) ? defaultModel : model.trim(),
      thinkingMode: json['thinkingMode'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }
}
