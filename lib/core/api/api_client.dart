import 'api_response.dart';

abstract class ApiClient {

  Future<ApiResponse<T>> get<T>(
    String endpoint,
  );

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Object? body,
  });

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Object? body,
  });

  Future<ApiResponse<T>> delete<T>(
    String endpoint,
  );
}