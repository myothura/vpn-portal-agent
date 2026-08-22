import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import '../models/notification_model.dart';

class NotificationListService {
  // ✅ FIX: Use Dio instance from ApiClient (Automatically handles Token & Base URL)
  final Dio _dio = ApiClient().dio;

  // 1. Notification များ ရယူခြင်း (Inbox)
  Future<List<NotificationModel>> getNotifications({int page = 1}) async {
    try {
      final response = await _dio.get('/agent/notifications?page=$page');

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> rawList = [];

        if (data is Map<String, dynamic> && data['data'] != null) {
          rawList = data['data'];
        } else if (data is List) {
          rawList = data;
        }

        return rawList.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  // 2. VPN User စာရင်းကို ဆွဲထုတ်ခြင်း
  Future<List<Map<String, dynamic>>> getVpnUsers() async {
    try {
      // ✅ FIX: Use Dio to ensure Authentication Header is attached
      final response = await _dio.get('/agent/users');

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> usersList = [];

        if (data is Map<String, dynamic> && data['data'] != null) {
          usersList = data['data'];
        } else if (data is List) {
          usersList = data;
        }

        return usersList
            .map(
              (user) => {
                'id': user['id'].toString(),
                'name': user['name'] ?? 'Unknown User',
                'email': user['email'] ?? '',
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      print("Error fetching users: $e");
      return [];
    }
  }

  // 3. Notification ပေးပို့ခြင်း (Supports Single & Bulk)
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // /agent/notifications/send, not /agent/send-notification.
      //
      // The two endpoints do the same job and only one is safe. The old one
      // checked neither the can_send_notifications permission nor ownership:
      // a single-user send went to any id in the table, and 'all' reached
      // every active user on the fleet rather than the sender's own. This one
      // scopes both to reseller_agent_id, with super-admin exempted.
      final response = await _dio.post(
        '/agent/notifications/send',
        data: {'user_id': userId, 'title': title, 'body': body},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error sending notification: $e");
      return false;
    }
  }
}
