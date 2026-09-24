import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart'; // Import ApiClient
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/history/models/credit_history_model.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class CreditHistoryService {
  // ⭐️ ApiClient ရဲ့ dio ကို ယူသုံးပါ (Token Auto ပါသွားပါလိမ့်မယ်)
  final Dio _dio = ApiClient().dio;

  /// [type] is 'add' or 'spend', or null for everything. Filtering happens
  /// server-side — the screen only ever holds one page.
  Future<CreditHistoryResponse?> getCreditHistory({
    int page = 1,
    String? type,
  }) async {
    try {
      // ApiClient မှာ baseUrl ထည့်ထားပြီးသားမို့ path ပဲ ပေးလိုက်ရင် ရပါပြီ
      final response = await _dio.get(
        ApiConfig.agentCreditHistory,
        queryParameters: {
          'page': page,
          if (type != null) 'type': type,
        },
      );

      if (response.statusCode == 200) {
        return CreditHistoryResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Error တက်ရင် Log ထုတ်ကြည့်မယ်
      AppLog.e('credit', 'Failed to get credit history: $e');
      return null;
    }
  }
}
