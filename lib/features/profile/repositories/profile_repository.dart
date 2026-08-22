import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart'; // Ensure this exists
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/models/profile_user_model.dart';

class ProfileRepository {
  final Dio _dio = ApiClient().dio;
  final Box _box = Hive.box('app_cache');
  static const String _cacheKey = 'profile_data';

  // 1. Get Cached Data
  ProfileUser? getCachedProfile() {
    try {
      final data = _box.get(_cacheKey);
      if (data != null) {
        // Map<dynamic, dynamic> ကို Map<String, dynamic> ပြောင်းပေးရပါမယ် Hive ကြောင့်ပါ
        final jsonMap = Map<String, dynamic>.from(data);
        return ProfileUser.fromJson(jsonMap);
      }
    } catch (e) {
      print("Cache Load Error: $e");
    }
    return null;
  }

  // 2. Fetch from API & Save to Hive
  Future<ProfileUser> fetchProfile() async {
    try {
      // ✅ Use ApiConfig.baseUrl or relative path if BaseOptions set
      final response = await _dio.get('/agent/profile');

      if (response.statusCode == 200 && response.data != null) {
        final profile = ProfileUser.fromJson(response.data);

        // Save to Cache
        await _box.put(_cacheKey, profile.toJson());

        return profile;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: "Invalid Data",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // 3. Update Telegram
  Future<bool> updateTelegram(String username) async {
    try {
      final response = await _dio.post(
        '/agent/profile/update-general',
        data: {'telegram_username': username},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. Update Payment Methods
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
        if (item.localImagePath != null) {
          formData.files.add(
            MapEntry(
              'payment_details[$i][qr_code]',
              await MultipartFile.fromFile(item.localImagePath!),
            ),
          );
        }
      }

      final response = await _dio.post(
        '/agent/profile/update-payment',
        data: formData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
