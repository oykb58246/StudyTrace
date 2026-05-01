/// AI service configuration stored in local preferences.
///
/// API keys are intentionally not part of this model; they are stored through
/// AiCredentialService using the platform secure storage APIs.
class AiConfig {
  final String provider;
  final String baseUrl;
  final String model;
  final String appId;
  final String blueHeartModel;
  final double temperature;
  final int maxTokens;
  final double topP;
  final bool thinkingMode;
  final bool thinkingEnabled;
  final double frequencyPenalty;
  final double presencePenalty;
  final String reasoningEffort;
  final bool isEnabled;

  const AiConfig({
    this.provider = 'deepseek',
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    this.appId = '',
    this.blueHeartModel = defaultBlueHeartModel,
    this.temperature = 0.7,
    this.maxTokens = 1200,
    this.topP = 0.7,
    this.thinkingMode = false,
    this.thinkingEnabled = false,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.reasoningEffort = '',
    this.isEnabled = false,
  });

  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-v4-flash';
  static const defaultBlueHeartModel = 'Volc-DeepSeek-V3.2';

  AiConfig copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    String? appId,
    String? blueHeartModel,
    double? temperature,
    int? maxTokens,
    double? topP,
    bool? thinkingMode,
    bool? thinkingEnabled,
    double? frequencyPenalty,
    double? presencePenalty,
    String? reasoningEffort,
    bool? isEnabled,
  }) {
    return AiConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      appId: appId ?? this.appId,
      blueHeartModel: blueHeartModel ?? this.blueHeartModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'baseUrl': baseUrl,
      'model': model,
      'appId': appId,
      'blueHeartModel': blueHeartModel,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'topP': topP,
      'thinkingMode': thinkingMode,
      'thinkingEnabled': thinkingEnabled,
      'frequencyPenalty': frequencyPenalty,
      'presencePenalty': presencePenalty,
      'reasoningEffort': reasoningEffort,
      'isEnabled': isEnabled,
    };
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = json['baseUrl'] as String?;
    final model = json['model'] as String?;
    final appId = json['appId'] as String?;
    final blueHeartModel = json['blueHeartModel'] as String?;
    return AiConfig(
      provider: json['provider'] as String? ?? 'deepseek',
      baseUrl: (baseUrl == null || baseUrl.trim().isEmpty)
          ? defaultBaseUrl
          : baseUrl.trim(),
      model:
          (model == null || model.trim().isEmpty) ? defaultModel : model.trim(),
      appId: appId == null ? '' : appId.trim(),
      blueHeartModel: (blueHeartModel == null || blueHeartModel.trim().isEmpty)
          ? defaultBlueHeartModel
          : blueHeartModel.trim(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 1200,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.7,
      thinkingMode: json['thinkingMode'] as bool? ?? false,
      thinkingEnabled: json['thinkingEnabled'] as bool? ?? false,
      frequencyPenalty:
          (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
      presencePenalty:
          (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
      reasoningEffort: json['reasoningEffort'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }
}
