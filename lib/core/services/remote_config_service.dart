import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Mirrors the user app's RemoteConfigService (VPN_Portal_VLESS).
/// Same Firebase project (starlink-vpn-user-app), same six keys, no
/// conditions — so the agent app reads the identical fallback chain.
///
/// HTTP keys are full URLs (scheme + /api); realtime keys are bare hosts.
/// Mixing the two formats silently falls back to defaults.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  String _activeApiUrl = 'https://control.vpnportal.org/api';
  String _backupApiUrl = 'https://control.vpnportal.org/api';
  String _backupApiUrl2 = '';
  String _backupApiUrl3 = '';
  String _realtimeHost = 'control.vpnportal.org';
  String _realtimeBackupHost = 'my-backup-api.org';
  String _realtimeBackupHost2 = '';
  String _realtimeBackupHost3 = '';

  String get activeApiUrl => _activeApiUrl;
  String get backupApiUrl => _backupApiUrl;
  String get backupApiUrl2 => _backupApiUrl2;
  String get backupApiUrl3 => _backupApiUrl3;
  String get realtimeHost => _realtimeHost;
  String get realtimeBackupHost => _realtimeBackupHost;
  String get realtimeBackupHost2 => _realtimeBackupHost2;
  String get realtimeBackupHost3 => _realtimeBackupHost3;

  void _read() {
    _activeApiUrl = _remoteConfig.getString('active_api_url');
    _backupApiUrl = _remoteConfig.getString('backup_api_url');
    _backupApiUrl2 = _remoteConfig.getString('backup_api_url_2');
    _backupApiUrl3 = _remoteConfig.getString('backup_api_url_3');
    _realtimeHost = _remoteConfig.getString('realtime_host');
    _realtimeBackupHost = _remoteConfig.getString('realtime_backup_host');
    _realtimeBackupHost2 = _remoteConfig.getString('realtime_backup_host_2');
    _realtimeBackupHost3 = _remoteConfig.getString('realtime_backup_host_3');

    if (_activeApiUrl.isEmpty) {
      _activeApiUrl = 'https://control.vpnportal.org/api';
    }
  }

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 15),
        ),
      );

      await _remoteConfig.setDefaults({
        'active_api_url': 'https://control.vpnportal.org/api',
        'backup_api_url': 'https://control.vpnportal.org/api',
        'backup_api_url_2': '',
        'backup_api_url_3': '',
        'realtime_host': 'control.vpnportal.org',
        'realtime_backup_host': 'my-backup-api.org',
        'realtime_backup_host_2': '',
        'realtime_backup_host_3': '',
      });

      await _remoteConfig.fetchAndActivate();
      _read();

      debugPrint('RemoteConfig: active=$_activeApiUrl backup=$_backupApiUrl');
    } catch (e) {
      debugPrint('RemoteConfig fetch failed: $e');
    }
  }

  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _read();
    } catch (e) {
      debugPrint('RemoteConfig refresh failed: $e');
    }
  }
}
