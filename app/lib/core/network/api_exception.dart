/// Machine-readable exception for VibeKit API failures.
class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;
  final dynamic details;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
  });

  bool get isQuotaExceeded => code == 'QUOTA_EXCEEDED' || statusCode == 429;
  bool get isNetworkError => statusCode == 0;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() =>
      'ApiException(status: $statusCode, code: $code, message: $message)';
}
