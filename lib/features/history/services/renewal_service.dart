import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart'; // Import ApiClient
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/history/models/renewal_request_model.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class RenewalRequestService {
  // ⭐️ ApiClient ရဲ့ dio ကို ယူသုံးပါ (Token Auto ပါပြီးသား ဖြစ်မယ်)
  final Dio _dio = ApiClient().dio;

  /// [status] is one of pending / approved / rejected, or null for all.
  /// Filtering happens server-side — the screen only ever holds one page.
  Future<RenewalRequestResponse?> getRenewalRequests({
    int page = 1,
    String? status,
  }) async {
    try {
      // ApiClient မှာ BaseUrl ရှိပြီးသားမို့ Endpoint ပဲ ထည့်ရုံပါ
      final response = await _dio.get(
        ApiConfig.agentRenewalRequests,
        queryParameters: {
          'page': page,
          // Omitted entirely when null: the backend treats an unrecognised
          // status as "no filter", but sending an empty string would still
          // read as a deliberate parameter.
          // AGENT_APP_P1 — null-aware element; same meaning as the `if`.
          'status': ?status,
        },
      );

      if (response.statusCode == 200) {
        return RenewalRequestResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppLog.e('renewal', 'Failed to get renewal requests: $e');
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
      AppLog.e('renewal', 'Failed to approve request: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(int requestId, String reason) async {
    try {
      // Reject Endpoint တည်ဆောက်ပုံ
      final response = await _dio.post(
        '${ApiConfig.agentRenewalRequests}/$requestId/reject',
        // REJECT_KEY_V1 — the chat path sends rejection_reason and this one
        // sends reason. Only one can match the server's validator; sending
        // both means the agent's words survive whichever it is.
        data: {'reason': reason, 'rejection_reason': reason},
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLog.e('renewal', 'Failed to reject request: $e');
      return false;
    }
  }
}
