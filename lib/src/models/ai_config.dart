/// AI service configuration stored in local preferences.
///
/// Model provider keys are intentionally not part of this model. The app only
/// stores local generation preferences while provider credentials live on the
/// backend.
class AiConfig {
  final double temperature;
  final int maxTokens;
  final double topP;
  final bool thinkingMode;
  final bool thinkingEnabled;
  final double frequencyPenalty;
  final double presencePenalty;
  final String reasoningEffort;
  final bool isEnabled;
  // 语音模式
  final bool voiceMode;
  final String voiceLanguage;
  final double voiceRate;

  const AiConfig({
    this.temperature = 0.7,
    this.maxTokens = 1200,
    this.topP = 0.7,
    this.thinkingMode = false,
    this.thinkingEnabled = false,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.reasoningEffort = '',
    this.isEnabled = true,
    this.voiceMode = false,
    this.voiceLanguage = 'zh-CN',
    this.voiceRate = 0.5,
  });

  AiConfig copyWith({
    double? temperature,
    int? maxTokens,
    double? topP,
    bool? thinkingMode,
    bool? thinkingEnabled,
    double? frequencyPenalty,
    double? presencePenalty,
    String? reasoningEffort,
    bool? isEnabled,
    bool? voiceMode,
    String? voiceLanguage,
    double? voiceRate,
  }) {
    return AiConfig(
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      isEnabled: isEnabled ?? this.isEnabled,
      voiceMode: voiceMode ?? this.voiceMode,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      voiceRate: voiceRate ?? this.voiceRate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'maxTokens': maxTokens,
      'topP': topP,
      'thinkingMode': thinkingMode,
      'thinkingEnabled': thinkingEnabled,
      'frequencyPenalty': frequencyPenalty,
      'presencePenalty': presencePenalty,
      'reasoningEffort': reasoningEffort,
      'isEnabled': isEnabled,
      'voiceMode': voiceMode,
      'voiceLanguage': voiceLanguage,
      'voiceRate': voiceRate,
    };
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
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
      isEnabled: json['isEnabled'] as bool? ?? true,
      voiceMode: json['voiceMode'] as bool? ?? false,
      voiceLanguage: json['voiceLanguage'] as String? ?? 'zh-CN',
      voiceRate: (json['voiceRate'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
