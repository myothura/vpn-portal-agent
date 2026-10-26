// PAYMENT_READER_V1 — Dart side of the native KBZPay reader (Android only).
//
// configure(): after login, hands the API base URL, bearer token and FCM token to the native
// side, which registers this device with the backend (POST agent/payment-verify/register). The
// backend answers registered:true only for the agent set in settings.payment_reader_agent_id, so
// every other agent's phone stays a plain Agent App. onCommand(): a payment_verify FCM data
// message (foreground or the background isolate) is handed to the native service.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';

class PaymentReaderBridge {
  static const _ch = MethodChannel('com.vpnportal.agent/payment_reader');

  static Future<Map<String, dynamic>?> configure({
    required String baseUrl,
    required String token,
    required String fcmToken,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final r = await _ch.invokeMethod<Map>('configure', {
        'baseUrl': baseUrl,
        'token': token,
        'fcmToken': fcmToken,
      });
      AppLog.d('payreader', 'configure -> $r');
      return r?.cast<String, dynamic>();
    } catch (e) {
      AppLog.e('payreader', 'configure failed: $e');
      return null;
    }
  }

  /// FCM data message -> native service. Safe to call for any message: only type=payment_verify acts.
  static Future<bool> onCommand(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return false;
    if (data['type'] != 'payment_verify') return false;
    try {
      return await _ch.invokeMethod<bool>('command', {'data': data}) ?? false;
    } catch (e) {
      AppLog.e('payreader', 'command failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> status() async {
    if (!Platform.isAndroid) return null;
    try {
      return (await _ch.invokeMethod<Map>('status'))?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> openA11ySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openA11ySettings');
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('clear');
    } catch (_) {}
  }
}
