import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';

class DashboardRepository {
  final Dio _dio = ApiClient().dio;
  final Box _box = Hive.box(
    'app_cache',
  ); // main.dart မှာ Hive.openBox('app_cache') လုပ်ထားရမယ်
  static const String _cacheKey = 'dashboard_stats';

  // 1. Local Cache ကနေအရင်ယူမယ်
  DashboardStats? getCachedStats() {
    try {
      final cachedData = _box.get(_cacheKey);
      if (cachedData != null) {
        // Hive က Map ပြန်ပေးရင် dynamic ဖြစ်နေတတ်လို့ cast လုပ်ပေးတာပါ
        final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(
          cachedData,
        );
        return DashboardStats.fromJson(jsonMap);
      }
    } catch (e) {
      print("Cache Error: $e");
    }
    return null;
  }

  // 2. API ကနေ လှမ်းယူမယ် (ပြီးရင် Cache ထဲထည့်မယ်)
  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.agentDashboard}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData =
            response.data is Map<String, dynamic> &&
                response.data.containsKey('data')
            ? response.data['data']
            : response.data;

        final stats = DashboardStats.fromJson(responseData);

        // ⭐️ Save to Hive for Offline/Next Load
        await _box.put(_cacheKey, stats.toJson());

        return stats;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: "Invalid Response",
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
