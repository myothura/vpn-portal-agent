// lib/l10n/l10n.dart
import 'package:flutter/material.dart';

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('my'),
    const Locale('zh'),
  ];

  /// AGENT_APP_G2_FLAGS — the two-letter language code, not a flag.
  ///
  /// A flag stands for a country, not a language, and this one was about to
  /// become visible: the picker had never been placed on a screen until the
  /// profile screen started opening it.
  static String getCode(String code) {
    switch (code) {
      case 'en':
        return 'EN';
      case 'my':
        return 'MY';
      case 'zh':
        return 'ZH';
      default:
        return code.toUpperCase();
    }
  }
}
