import 'dart:io';
import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';

class AgentChatService {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>?> getUsers({String? search, int page = 1}) async {
    try {
      String url = '${ApiConfig.baseUrl}${ApiConfig.chatUsers}?page=$page';
      if (search != null && search.isNotEmpty) {
        // QUERY_ENCODE_V1 — a username containing & # + or a space produced a
        // malformed query, so an existing user came back as "no match"; the
        // same hole let extra parameters be appended to the request.
        url += '&search=${Uri.encodeQueryComponent(search)}';
      }
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } on DioException catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getHistory(int userId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.chatHistory(userId)}',
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } on DioException catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendReply(
    int userId, {
    String? message,
    File? image,
  }) async {
    try {
      final formData = FormData();
      if (message != null && message.trim().isNotEmpty) {
        formData.fields.add(MapEntry('message', message.trim()));
      }
      if (image != null) {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              image.path,
              filename: image.path.split('/').last,
            ),
          ),
        );
      }
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatReply(userId)}',
        data: formData,
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } on DioException catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendPlanCard(int userId) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatPlanCard(userId)}',
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } on DioException catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> extendSubscription(
    int userId,
    int months,
    int days,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatExtend(userId)}',
        data: {'months': months, 'days': days},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } on DioException catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> broadcastMessage(String message, String target) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatBroadcast}',
        data: {'message': message, 'target': target},
      );
      return response.statusCode == 200;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSelfRenewalStatus() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.chatSelfRenewalStatus}',
      );
      if (response.statusCode == 200) {
        return {
          'allow_self_renewal': response.data['allow_self_renewal'] == true,
          'is_admin': response.data['is_admin'] == true,
        };
      }
    } on DioException catch (_) {}
    return {'allow_self_renewal': false, 'is_admin': false};
  }

  Future<bool> toggleSelfRenewal(bool enabled) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatToggleSelfRenewal}',
        data: {'enabled': enabled},
      );
      return response.statusCode == 200;
    } on DioException catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> approveRequest(int requestId) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.agentRenewalRequests}/$requestId/approve',
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Approved',
        };
      }
      return {
        'success': false,
        'message': response.data?['message'] ?? 'Failed',
      };
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data['message'] ?? 'Error')
          : 'Network error';
      return {'success': false, 'message': msg};
    }
  }

  Future<Map<String, dynamic>> rejectRequest(
    int requestId, {
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.agentRenewalRequests}/$requestId/reject',
        // REJECT_KEY_V1 — see RenewalRequestService.rejectRequest.
        data: {'rejection_reason': reason ?? '', 'reason': reason ?? ''},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Rejected',
        };
      }
      return {
        'success': false,
        'message': response.data?['message'] ?? 'Failed',
      };
    } on DioException catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}
