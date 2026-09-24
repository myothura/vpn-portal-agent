import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class ProfileService {
  final Dio _dio = ApiClient().dio;

  // Get Profile including Payment Details
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      // ✅ FIXED: Domain အသေမရေးဘဲ Base URL (control.vpnportal.org) ကိုသုံးရန် ပြင်လိုက်ပါပြီ
      final response = await _dio.get('/agent/profile');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update Payment Methods (Uploads everything as a batch)
  Future<bool> updatePaymentMethods(List<PaymentMethod> methods) async {
    try {
      final formData = FormData();

      for (int i = 0; i < methods.length; i++) {
        final item = methods[i];

        formData.fields.addAll([
          MapEntry('payment_details[$i][id]', item.id),
          MapEntry('payment_details[$i][bank_name]', item.bankName),
          MapEntry('payment_details[$i][account_name]', item.accountName),
          MapEntry('payment_details[$i][account_number]', item.accountNumber),
        ]);

        // If a new image is picked from gallery
        if (item.localImagePath != null) {
          formData.files.add(
            MapEntry(
              'payment_details[$i][qr_code]',
              await MultipartFile.fromFile(item.localImagePath!),
            ),
          );
        }
      }

      // ✅ FIXED: Relative path
      final response = await _dio.post(
        '/agent/profile/update-payment',
        data: formData,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      AppLog.e('profile', 'Update Payment Error: ${e.response?.data}');
      return false;
    }
  }

  // ✅ NEW: Update General Info (Telegram Username)
  Future<bool> updateTelegramUsername(String username) async {
    try {
      // ✅ FIXED: Relative path
      final response = await _dio.post(
        '/agent/profile/update-general',
        data: {'telegram_username': username},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      AppLog.e('profile', 'Update General Info Error: ${e.response?.data}');
      return false;
    }
  }
}
