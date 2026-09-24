// lib/core/utils/app_log.dart
import 'package:flutter/foundation.dart';

/// Debug-only logging.
///
/// This replaces 47 bare `print()` calls. Flutter does NOT strip `print` from a
/// release build, and several of those calls were dumping whole API error
/// bodies into logcat — including the payload of create-user and update-user,
/// which carries the VPN user's password, and the FCM token. Anyone with a
/// cable and `adb logcat` could read them off an agent's phone.
///
/// `debugPrint` inside a `kDebugMode` check is compiled out of release
/// entirely: the constant is known at compile time, so the branch and the
/// string interpolation inside it are both tree-shaken. The message is still
/// there during development, which is the only place it was ever useful.
///
/// [where] is the call site, so a line in a long log says which service
/// produced it without the message having to repeat the class name.
class AppLog {
  const AppLog._();

  /// Something failed and the caller handled it. The normal case here.
  static void e(String where, Object error) {
    if (kDebugMode) debugPrint('[$where] $error');
  }

  /// A step worth seeing while developing. Never a value, only a step.
  static void d(String where, [String? message]) {
    if (kDebugMode) {
      debugPrint(message == null ? '[$where]' : '[$where] $message');
    }
  }
}
