class UiReviewConfig {
  const UiReviewConfig._();

  static const enabled = bool.fromEnvironment('STUDYTRACE_UI_REVIEW');

  static const target = String.fromEnvironment('STUDYTRACE_UI_REVIEW_TARGET');
}
