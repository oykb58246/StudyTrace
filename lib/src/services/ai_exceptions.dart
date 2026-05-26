/// AI 服务通用异常
class AiServiceException implements Exception {
  const AiServiceException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}
