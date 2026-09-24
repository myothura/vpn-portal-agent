// lib/features/dashboard/services/dashboard_service.dart
import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class DashboardService {
  // Use the singleton Dio instance from our central ApiClient
  final Dio _dio = ApiClient().dio;

  Future<DashboardStats?> getDashboardStats() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.agentDashboard}',
      );
      if (response.statusCode == 200 && response.data != null) {
        // API response မှာ data က 'data' key အောက်မှာတစ်ထပ်ထပ် nesting ဖြစ်နေတတ်လို့
        // အဲ့လိုဖြစ်နေခဲ့ရင် response.data['data'] ကိုသုံးပြီး၊ မဟုတ်ရင် response.data ကို တိုက်ရိုက်သုံးပါမယ်။
        final responseData =
            response.data is Map<String, dynamic> &&
                response.data.containsKey('data')
            ? response.data['data']
            : response.data;

        return DashboardStats.fromJson(responseData);
      }
      return null;
    } on DioException catch (e) {
      AppLog.e('dashboard', 'Failed to get dashboard stats: $e');
      return null;
    }
  }
}
