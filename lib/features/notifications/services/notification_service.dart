import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/features/notifications/models/notification_model.dart';

class NotificationService {
  final Dio _dio = ApiClient().dio;

  Future<bool> sendBroadcast({
    required String title,
    required String body,
    String userId = 'all',
  }) async {
    try {
      final response = await _dio.post(
        '/agent/notifications/send',
        data: {'title': title, 'body': body, 'user_id': userId},
      );
      return response.statusCode == 200;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<List<NotificationModel>> getNotifications({int page = 1}) async {
    try {
      final response = await _dio.get('/notifications?page=$page');

      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _dio.post('/notifications/mark-all-read');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await _dio.post('/notifications/$id/mark-read');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNotification(int id) async {
    try {
      final response = await _dio.delete('/notifications/$id');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
