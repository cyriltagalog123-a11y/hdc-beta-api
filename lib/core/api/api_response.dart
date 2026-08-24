class ApiResponse<T> {

  final bool success;

  final T? data;

  final String? message;

  const ApiResponse({

    required this.success,

    this.data,

    this.message,
  });
}