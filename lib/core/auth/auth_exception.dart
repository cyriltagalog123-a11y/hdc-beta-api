class HDCAuthException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const HDCAuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}
