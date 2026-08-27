import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session_store.dart';

class HdcWorkflowException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? referenceId;

  const HdcWorkflowException({
    required this.code,
    required this.message,
    this.statusCode,
    this.referenceId,
  });

  @override
  String toString() => message;
}

class HdcWorkflowApiClient {
  static const _requestTimeout = Duration(seconds: 25);

  final Uri baseUri;
  final AuthSessionStore sessionStore;
  final http.Client _client;

  HdcWorkflowApiClient({
    required this.baseUri,
    required this.sessionStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<bool> get hasSession async {
    final session = await sessionStore.read();
    return session != null && !session.isExpired;
  }

  Future<Map<String, dynamic>> get(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> getPublic(String path) {
    return _send('GET', path, requiresAuthentication: false);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, Object?>? body}) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, Object?> body,
  }) {
    return _send('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool requiresAuthentication = true,
  }) async {
    final session = await sessionStore.read();
    if (requiresAuthentication && (session == null || session.isExpired)) {
      throw const HdcWorkflowException(
        code: 'authentication_required',
        message: 'Sign in to use authenticated HDC services.',
        statusCode: 401,
      );
    }

    final request = http.Request(method, _endpoint(path))
      ..headers.addAll({
        'accept': 'application/json',
        'content-type': 'application/json',
        if (requiresAuthentication && session != null)
          'authorization': 'Bearer ${session.token}',
      });
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = decoded?['error'] is String
            ? decoded!['error'] as String
            : 'workflow_request_failed';
        final referenceId = decoded?['referenceId'] is String
            ? decoded!['referenceId'] as String
            : response.headers['x-hdc-request-id'];
        final serverMessage = decoded?['message'] is String
            ? (decoded!['message'] as String).trim()
            : null;
        throw HdcWorkflowException(
          code: code,
          message: _messageFor(
            code,
            response.statusCode,
            serverMessage: serverMessage,
          ),
          statusCode: response.statusCode,
          referenceId: (referenceId?.trim().isEmpty ?? true)
              ? null
              : referenceId!.trim(),
        );
      }

      if (decoded == null) {
        throw const HdcWorkflowException(
          code: 'invalid_server_response',
          message: 'HDC returned an invalid workflow response.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const HdcWorkflowException(
        code: 'network_timeout',
        message: 'HDC workflow synchronization timed out. Please try again.',
      );
    } on http.ClientException {
      throw const HdcWorkflowException(
        code: 'network_unavailable',
        message:
            'Could not reach HDC workflow services. Check your connection.',
      );
    }
  }

  Uri _endpoint(String path) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, dynamic>? _decodeObject(String value) {
    if (value.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String _messageFor(String code, int statusCode, {String? serverMessage}) {
    final safeServerMessage =
        serverMessage != null &&
            serverMessage.isNotEmpty &&
            serverMessage.length <= 300
        ? serverMessage
        : null;
    return switch (code) {
      'unauthorized' || 'authentication_required' =>
        'Your HDC session is no longer valid. Please sign in again.',
      'forbidden' => 'Your HDC account is not allowed to perform this action.',
      'workflow_backend_not_ready' =>
        'HDC transaction services are being prepared. Please try again later.',
      'workflow_authority_unavailable' => 'HDC request services are temporarily unavailable. Please try again shortly.',
      'invalid_workflow_payload' ||
      'invalid_request_status' => 'Check the request details and try again.',
      'service_request_identifier_conflict' => 'This request could not be retried safely. Return to the form and review it again.',
      'role_backend_not_ready' || 'role_backend_unavailable' =>
        'HDC role services are being prepared. Please try again later.',
      'profile_backend_not_ready' || 'profile_backend_unavailable' =>
        'HDC profile services are being prepared. Please try again later.',
      'internal_backend_not_ready' || 'internal_backend_unavailable' =>
        'The private HDC workspace is being prepared. Please try again later.',
      'commerce_backend_not_ready' || 'commerce_backend_unavailable' =>
        'HDC marketplace services are being prepared. Please try again later.',
      'selling_role_required' => 'An approved Seller, Supplier, or Store role is required to list items.',
      'customer_role_required' =>
        'An active Customer workspace is required to request a purchase.',
      'invalid_product_listing' =>
        'Check the product-listing fields and try again.',
      'product_listing_not_found' =>
        'That product listing is no longer available.',
      'product_listing_conflict' || 'commerce_conflict' =>
        'That product listing changed elsewhere. Refresh and try again.',
      'invalid_product_listing_transition' =>
        'That product-listing status change is no longer allowed.',
      'invalid_purchase_request' || 'invalid_purchase_request_action' =>
        'Check the purchase request and try again.',
      'product_listing_unavailable' =>
        'That item or requested quantity is no longer available.',
      'self_purchase_not_allowed' =>
        'You cannot request a purchase from your own listing.',
      'purchase_request_pending' =>
        'You already have a pending request for this product.',
      'purchase_request_rate_limited' =>
        'Too many purchase requests were sent recently. Try again later.',
      'purchase_request_not_found' =>
        'That purchase request is no longer available.',
      'purchase_request_conflict' =>
        'That purchase request changed elsewhere. Refresh and try again.',
      'purchase_request_already_decided' =>
        'That purchase request is no longer awaiting a decision.',
      'internal_access_required' =>
        'This account is not authorized for the private HDC workspace.',
      'profile_role_inactive' =>
        'Activate that platform role before editing its profile.',
      'invalid_member_profile' ||
      'invalid_role_profile' => 'Check the profile fields and try again.',
      'profile_conflict' =>
        'That HDC profile changed elsewhere. Refresh and try again.',
      'platform_role_already_active' =>
        'That HDC platform role is already active on your account.',
      'platform_role_application_pending' =>
        'An application for that HDC platform role is already pending.',
      'invalid_role_application' =>
        'Complete every required role-application field and confirmation.',
      'internal_role_required' =>
        'Private approval permission is required for this action.',
      'role_application_already_reviewed' =>
        'That platform role application has already been reviewed.',
      'role_application_not_found' =>
        'That platform role application is no longer available.',
      'recovery_review_not_found' =>
        'That account recovery request is no longer available.',
      'recovery_review_already_completed' =>
        'That account recovery request has already been reviewed.',
      'service_request_not_found' =>
        'The service request is no longer available.',
      'proposal_not_found' => 'The proposal is no longer available.',
      'proposal_already_exists' =>
        'You already have a proposal for this request. Refresh it before editing.',
      'technician_already_selected' =>
        'A technician has already been selected for this request.',
      'request_not_accepting_proposals' =>
        'This request is no longer accepting proposals.',
      'proposal_not_eligible' =>
        'This proposal is no longer eligible for acceptance.',
      'invalid_request_transition' ||
      'invalid_proposal_transition' ||
      'invalid_transaction_transition' =>
        'That status change is no longer allowed. Refresh and try again.',
      'workflow_conflict' =>
        'That HDC record already exists or was changed elsewhere.',
      'private_conversation_not_found' =>
        'This private transaction conversation has not been started yet.',
      'private_messaging_unavailable' =>
        'Private messaging is not available for this transaction.',
      'private_message_blocked' =>
        'This message contains content HDC will not send in private chat.',
      'private_message_warning_required' =>
        'This message contains language that may be offensive.',
      'private_message_quota_exceeded' =>
        'HDC chat storage is full for this conversation.',
      'user_storage_not_connected' =>
        'User-owned chat storage is not connected yet.',
      'service_read_only' || 'service_maintenance' || 'service_incident' =>
        'HDC is temporarily limiting changes. Please try again later.',
      _ when statusCode >= 500 =>
        'HDC services are temporarily unavailable. Please try again.',
      _ when safeServerMessage != null => safeServerMessage,
      _ => 'The HDC workflow request could not be completed.',
    };
  }
}
