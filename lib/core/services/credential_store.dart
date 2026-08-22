// lib/core/services/credential_store.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage for the "Remember Me" credentials.
///
/// The password previously sat in SharedPreferences as plain text — readable
/// from a rooted device or an ADB backup. An agent account can administer
/// hundreds of users, so that is not an acceptable place for it. It now lives
/// in the platform keystore (Android Keystore / iOS Keychain).
///
/// The email stays in SharedPreferences: it is not a secret, and keeping it
/// there means the login form can prefill without a keystore round-trip.
class CredentialStore {
  static const _rememberKey = 'remember_me';
  static const _emailKey = 'saved_email';

  /// Legacy key. Read once during migration, then deleted.
  static const _legacyPasswordKey = 'saved_password';

  /// Key inside secure storage. Deliberately different from the legacy one so
  /// a half-finished migration can never read one and write the other.
  static const _securePasswordKey = 'agent_password';

  static const _secure = FlutterSecureStorage(
    // encryptedSharedPreferences MUST be set: on v9 it defaults to false,
    // which falls back to ordinary SharedPreferences and would leave the
    // password exactly where this class exists to move it out of. With it on,
    // the value is held in EncryptedSharedPreferences under an Android
    // Keystore key.
    //
    // (v11 drops this flag and encrypts unconditionally, but it requires
    // compileSdk 37 — pinned to v9 to keep the Android build on 36.)
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // first_unlock rather than the default `unlocked`: a push notification can
    // wake the app while the phone is locked, and the credential must still be
    // readable then. It never leaves the device and is not iCloud-synced.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Moves any plain-text password already on the device into secure storage
  /// and removes the original. Safe to call on every launch: it is a no-op
  /// once the legacy key is gone.
  static Future<void> migrateLegacyPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPasswordKey);
      if (legacy == null) return;

      // Write first, delete second. If the app dies between the two, the
      // worst case is a duplicate — not a lost credential.
      await _secure.write(key: _securePasswordKey, value: legacy);
      await prefs.remove(_legacyPasswordKey);
      debugPrint('CredentialStore: migrated password out of SharedPreferences');
    } catch (e) {
      debugPrint('CredentialStore: migration failed: $e');
    }
  }

  static Future<bool> get isRemembering async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }

  static Future<({String email, String password})?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_rememberKey) ?? false)) return null;

      return (
        email: prefs.getString(_emailKey) ?? '',
        password: await _secure.read(key: _securePasswordKey) ?? '',
      );
    } catch (e) {
      debugPrint('CredentialStore: read failed: $e');
      return null;
    }
  }

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberKey, true);
      await prefs.setString(_emailKey, email);
      await _secure.write(key: _securePasswordKey, value: password);
    } catch (e) {
      debugPrint('CredentialStore: save failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rememberKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_legacyPasswordKey);
      await _secure.delete(key: _securePasswordKey);
    } catch (e) {
      debugPrint('CredentialStore: clear failed: $e');
    }
  }
}
