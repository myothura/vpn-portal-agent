import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart'; // Import ApiClient
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/history/models/credit_history_model.dart';

class CreditHistoryService {
  // ⭐️ ApiClient ရဲ့ dio ကို ယူသုံးပါ (Token Auto ပါသွားပါလိမ့်မယ်)
  final Dio _dio = ApiClient().dio;

  Future<CreditHistoryResponse?> getCreditHistory({int page = 1}) async {
    try {
      // ApiClient မှာ baseUrl ထည့်ထားပြီးသားမို့ path ပဲ ပေးလိုက်ရင် ရပါပြီ
      final response = await _dio.get(
        ApiConfig.agentCreditHistory,
        queryParameters: {'page': page},
      );

      if (response.statusCode == 200) {
        return CreditHistoryResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Error တက်ရင် Log ထုတ်ကြည့်မယ်
      print('Failed to get credit history: $e');
      return null;
    }
  }
}
