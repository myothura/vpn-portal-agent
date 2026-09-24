import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn_agent_app/core/api/api_client.dart'; // Import ApiClient
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/services/notification_service.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vpn_agent_app/core/services/agent_realtime_service.dart';

class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _permissionKey = 'can_send_noti';
  static const String _agentIdKey = 'agent_id';

  // ⚠️ Login ဝင်တဲ့အချိန်မှာ ApiClient ကို သုံးလို့မရပါ (Circular Dependency ဖြစ်တတ်လို့ပါ)
  // ဒါကြောင့် Login အတွက် သီးသန့် Dio (Clean Dio) ကို တည်ဆောက်ထားပါတယ်
  // No baseUrl here: login must walk the RemoteConfig domain chain itself.
  // ApiClient can't be reused (circular dependency, and there is no token yet),
  // so the candidate list is walked explicitly in login().
  //
  // LogInterceptor is debug-only — it prints the full login response, which
  // contains the Sanctum token, and that must never reach a release build's
  // device log.
  final Dio _publicDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  )..interceptors.addAll([
      if (kDebugMode) LogInterceptor(responseBody: true, requestBody: true),
    ]);

  /// Ordered, de-duplicated, non-empty base URLs from RemoteConfig.
  List<String> get _candidates {
    final raw = <String>[
      ApiConfig.baseUrl,
      ApiConfig.backupUrl,
      ApiConfig.backupUrl2,
      ApiConfig.backupUrl3,
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final u in raw) {
      if (u.isEmpty) continue;
      if (seen.add(u)) out.add(u);
    }
    return out;
  }

  // ⭐️ Login ဝင်ပြီးနောက်ပိုင်းသုံးမည့် Authenticated Request များအတွက်
  // ApiClient ထဲက dio ကို လှမ်းယူသုံးပါမယ် (Auto Token Insert & Auto Logout ပါပြီးသားဖြစ်မယ်)
  Dio get _authDio => ApiClient().dio;

  Future<bool> login(String email, String password) async {
    try {
      // Login လုပ်ချိန်မှာ Interceptor မပါတဲ့ _publicDio ကိုသုံးပါ
      Response? response;
      DioException? lastErr;
      for (final base in _candidates) {
        try {
          response = await _publicDio.post(
            '$base${ApiConfig.agentLogin}',
            data: {'email': email, 'password': password},
          );
          break;
        } on DioException catch (e) {
          // Auth failures are answers, not transport failures — stop rotating.
          if (e.response != null) {
            lastErr = e;
            break;
          }
          debugPrint('AuthService: login candidate failed: $base');
          lastErr = e;
        }
      }
      if (response == null) throw lastErr!;

      if (response.statusCode == 200 && response.data['token'] != null) {
        final String token = response.data['token'];

        // 🔥 FIX: 'agent' မဟုတ်ဘဲ 'user' key ကို သုံးရပါမယ်
        final userData = response.data['user'];

        // Permission Check (Safety Check ထည့်ထားပါသည်)
        bool canSendNoti = false;
        if (userData != null) {
          canSendNoti = userData['can_send_notifications'] ?? false;
        }

        // Save to Local Storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setBool(_permissionKey, canSendNoti);
        final dynamic aid = userData != null ? userData['id'] : null;
        if (aid != null) {
          final int? aidInt = aid is int ? aid : int.tryParse(aid.toString());
          if (aidInt != null) await prefs.setInt(_agentIdKey, aidInt);
        }

        AppLog.d('auth', "✅ Token saved. Can Send Noti? $canSendNoti");

        // Token ရပြီဖြစ်တဲ့အတွက် FCM Token ကို Server ပို့ပါမယ်
        await _updateFcmToken();

        return true;
      }
      return false;
    } on DioException catch (e) {
      AppLog.e('auth', "Login Error: ${e.message}");
      return false;
    }
  }

  // FCM Token Update လုပ်ခြင်း
  Future<void> _updateFcmToken() async {
    try {
      final fcmToken = await NotificationService.getFcmToken();
      if (fcmToken != null) {
        // ⭐️ ApiClient ရဲ့ _authDio ကိုသုံးတဲ့အတွက် Header ထည့်ပေးစရာ မလိုတော့ပါ
        await _authDio.post(
          ApiConfig.agentUpdateFcmToken,
          data: {'fcm_token': fcmToken},
        );
        AppLog.d('auth', "✅ FCM Token updated successfully via ApiClient");
      }
    } catch (e) {
      AppLog.e('auth', "Error updating FCM token: $e");
      // FCM update မအောင်မြင်လည်း Login process ကို မရပ်တန့်စေပါ
    }
  }

  Future<void> logout() async {
    try {
      // 1. Server ဘက်ကို Logout လုပ်ကြောင်း လှမ်းပြောမယ် (Optional)
      // Token ရှိမှသာ ခေါ်ပါမယ်
      if (await hasToken()) {
        await _authDio.post(ApiConfig.agentLogout);
        AppLog.d('auth', "✅ Server Logout Successful");
      }
    } catch (e) {
      // Server error တက်လည်း ဂရုမစိုက်ဘဲ Local ကကောင်ကို ဆက်ဖျက်မယ်
      AppLog.e('auth', "Server Logout Warning: $e");
    } finally {
      // 2. ဖုန်းထဲက Data တွေကို အပြီးရှင်းမယ်
      // SESSION_HYGIENE_V1 — everything the previous agent left behind.
      //
      // Removing only the token left agent_id cached, and getAgentId()
      // returns the cached value first — so the next sign-in could keep the
      // previous agent's identity, including the id == 16 super-admin branch.
      // The Hive box is worse: it holds profile_data (name, email, credit
      // balance, every payment method's bank account number) and
      // dashboard_stats, and ProfileBloc paints that cache before its first
      // network call. On a shared shop phone the next agent saw it.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_permissionKey);
      await prefs.remove(_agentIdKey);

      try {
        AgentRealtimeService.instance.stop();
      } catch (e) {
        AppLog.e('auth', 'realtime stop on logout: $e');
      }

      try {
        if (Hive.isBoxOpen('app_cache')) await Hive.box('app_cache').clear();
      } catch (e) {
        AppLog.e('auth', 'cache clear on logout: $e');
      }
    }
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<int?> getAgentId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_agentIdKey);
    if (cached != null) return cached;
    try {
      final res = await _authDio.get(ApiConfig.agentProfile);
      final id = _extractId(res.data);
      if (id != null) {
        await prefs.setInt(_agentIdKey, id);
        return id;
      }
    } catch (e) {
      AppLog.e('auth', 'getAgentId fetch error: $e');
    }
    return null;
  }

  int? _extractId(dynamic data) {
    if (data is Map) {
      if (data['id'] != null) return _asInt(data['id']);
      for (final k in ['data', 'agent', 'user', 'profile']) {
        if (data[k] is Map && data[k]['id'] != null) return _asInt(data[k]['id']);
      }
    }
    return null;
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<bool> canSendNotification() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionKey) ?? false;
  }
}
