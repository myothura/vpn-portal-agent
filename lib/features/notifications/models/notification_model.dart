import 'dart:convert';

import 'package:vpn_agent_app/core/utils/app_time.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Where tapping this should go, from the payload the server writes:
  /// {"type": "renewal_request", "screen": "renewal_requests"}. Parsed here
  /// rather than guessed from the title, which is a display string and gets
  /// reworded.
  final String? screen;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
    this.screen,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '0',
      title: json['title']?.toString() ?? 'No Title',
      body: json['body']?.toString() ?? '',
      // AGENT_APP_Q1_NM — both are moments, both arrived unconverted.
      readAt: AppTime.parse(json['read_at']),
      createdAt: AppTime.parse(json['created_at']) ?? DateTime.now(),
      // The column is json, but Laravel hands it back as a string on a raw
      // DB::table query and as a Map through the model — both shapes occur.
      screen: _screenFrom(json['data']),
    );
  }

  static String? _screenFrom(dynamic raw) {
    if (raw == null) return null;
    try {
      final map = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      final screen = map['screen']?.toString();
      return (screen == null || screen.isEmpty) ? null : screen;
    } catch (_) {
      return null;
    }
  }

  // 👇 ဒီ Function လေးမရှိလို့ Error တက်နေတာပါ (ထပ်ဖြည့်ပေးလိုက်ပါပြီ)
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? readAt,
    DateTime? createdAt,
    String? screen,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      screen: screen ?? this.screen,
    );
  }
}
