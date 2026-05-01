import 'package:dio/dio.dart';
import 'package:magent_app/l10n/app_localizations.dart';

const agentConnectionFailureMessage = '连接失败，请检查 agent';

String userFriendlyErrorMessage(
  Object error, {
  String fallback = '操作失败',
  String? action,
  String agentConnectionFailure = agentConnectionFailureMessage,
}) {
  final message = _messageFor(
    error,
    fallback: fallback,
    agentConnectionFailure: agentConnectionFailure,
  );
  if (action == null || action.isEmpty) return message;
  return '$action：$message';
}

String localizedErrorMessage(
  AppLocalizations l10n,
  Object error, {
  String? action,
}) {
  return userFriendlyErrorMessage(
    error,
    action: action,
    fallback: l10n.operationFailed,
    agentConnectionFailure: l10n.agentConnectionFailure,
  );
}

String _messageFor(
  Object error, {
  required String fallback,
  required String agentConnectionFailure,
}) {
  if (error is DioException) {
    if (_isAgentUnavailable(error)) return agentConnectionFailure;
    final response = error.response;
    final status = response?.statusCode ?? 0;
    if (status >= 500) return agentConnectionFailure;
    final apiMessage = _extractApiMessage(
      response?.data,
      agentConnectionFailure: agentConnectionFailure,
    );
    if (apiMessage != null && apiMessage.isNotEmpty) return apiMessage;
    return fallback;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('connection') ||
      text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('connection refused') ||
      text.contains('failed host lookup')) {
    return agentConnectionFailure;
  }
  final display = _cleanMessage(
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
    agentConnectionFailure: agentConnectionFailure,
  );
  return display.isEmpty ? fallback : display;
}

bool _isAgentUnavailable(DioException error) {
  return error.response == null ||
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.unknown;
}

String? _extractApiMessage(
  dynamic data, {
  required String agentConnectionFailure,
}) {
  if (data is Map) {
    final error = data['error'];
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return _cleanMessage(
          message,
          agentConnectionFailure: agentConnectionFailure,
        );
      }
    }
    final message = data['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return _cleanMessage(
        message,
        agentConnectionFailure: agentConnectionFailure,
      );
    }
  }
  return null;
}

String _cleanMessage(String message, {required String agentConnectionFailure}) {
  final trimmed = message.trim();
  if (trimmed.startsWith('{') ||
      trimmed.startsWith('jsonrpc error') ||
      trimmed.contains('jsonrpc error') ||
      trimmed.contains('DioException') ||
      trimmed.contains('SocketException')) {
    return agentConnectionFailure;
  }
  return trimmed;
}
