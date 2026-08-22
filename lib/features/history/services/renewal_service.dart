import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart'; // Import ApiClient
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/history/models/renewal_request_model.dart';

class RenewalRequestService {
  // ⭐️ ApiClient ရဲ့ dio ကို ယူသုံးပါ (Token Auto ပါပြီးသား ဖြစ်မယ်)
  final Dio _dio = ApiClient().dio;

  Future<RenewalRequestResponse?> getRenewalRequests({int page = 1}) async {
    try {
      // ApiClient မှာ BaseUrl ရှိပြီးသားမို့ Endpoint ပဲ ထည့်ရုံပါ
      final response = await _dio.get(
        ApiConfig.agentRenewalRequests,
        queryParameters: {'page': page},
      );

      if (response.statusCode == 200) {
        return RenewalRequestResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Failed to get renewal requests: $e');
      return null;
    }
  }

  Future<bool> approveRequest(int requestId) async {
    try {
      // Approve Endpoint တည်ဆောက်ပုံ
      final response = await _dio.post(
        '${ApiConfig.agentRenewalRequests}/$requestId/approve',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to approve request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(int requestId, String reason) async {
    try {
      // Reject Endpoint တည်ဆောက်ပုံ
      final response = await _dio.post(
        '${ApiConfig.agentRenewalRequests}/$requestId/reject',
        data: {'reason': reason},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Failed to reject request: $e');
      return false;
    }
  }
}
