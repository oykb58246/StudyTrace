class ApiEndpointConfig {
  static const String apiHost = 'api.studytrace.oykb.cn';
  static const String legacySiteHost = 'studytrace.oykb.cn';

  static String defaultBaseUrl() {
    final current = Uri.base;
    if ((current.scheme == 'http' || current.scheme == 'https') &&
        current.host == apiHost) {
      return '${current.scheme}://${current.authority}';
    }
    return 'https://$apiHost';
  }

  static String normalizeBaseUrl(String? value) {
    final trimmed = value?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
    if (trimmed.isEmpty) return defaultBaseUrl();

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      if (uri.host == apiHost) {
        return '${uri.scheme}://${uri.authority}';
      }
      if (uri.host == legacySiteHost) {
        return defaultBaseUrl();
      }
      return trimmed;
    }

    final hostOnly = trimmed.replaceAll(RegExp(r'/.*$'), '');
    if (hostOnly == apiHost || hostOnly == legacySiteHost) {
      return defaultBaseUrl();
    }
    return 'http://$trimmed';
  }
}
