import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/main.dart';
import 'package:vpn_agent_app/features/chat/screens/agent_chat_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class NotificationService {
  static final Dio _dio = ApiClient().dio;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
        playSound: true,
      );

  /// Initialize local notifications + FCM listeners (NO API calls)
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_chatChannel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages -> show local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  /// Register FCM token with backend (call AFTER auth confirmed)
  static Future<void> registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        AppLog.d('fcm', '📱 FCM Token: ${token.substring(0, 30)}...');
        await _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.agentUpdateFcmToken}',
          data: {'fcm_token': token},
        );
        AppLog.d('fcm', '✅ FCM Token sent to server');
      }
    } catch (e) {
      AppLog.e('fcm', '❌ FCM token registration failed: $e');
    }

    // Listen for token refresh - re-register
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.agentUpdateFcmToken}',
          data: {'fcm_token': newToken},
        );
      } catch (_) {}
    });
  }

  /// Get FCM token
  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      AppLog.e('fcm', 'getFcmToken error: $e');
      return null;
    }
  }

  /// Show local notification when app is in foreground
  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'New Message';
    final body = notification?.body ?? data['body'] ?? '';

    final payload =
        '${data['type'] ?? ''}|${data['vpn_user_id'] ?? ''}|${data['username'] ?? ''}';

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    final parts = payload.split('|');

    if (parts.isNotEmpty && parts[0] == 'chat_message') {
      final vpnUserId = int.tryParse(parts.length > 1 ? parts[1] : '');
      final username = parts.length > 2 ? parts[2] : '';

      if (vpnUserId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                AgentChatDetailScreen(userId: vpnUserId, username: username),
          ),
        );
      }
    }
  }
}
