// lib/core/utils/app_time.dart
//
// AGENT_APP_Q1 — one parser for every timestamp the backend sends.
import 'package:flutter/foundation.dart';

/// Turns a server timestamp into a local [DateTime].
///
/// The backend runs on `app.timezone = UTC` and its database stores UTC, but
/// its endpoints are not consistent about saying so. Eloquent serialises
/// `2026-09-24T08:44:58.000000Z`; a query-builder row comes back as the bare
/// `2026-09-24 08:44:58`. Dart reads the second one as LOCAL time, so a
/// message sent at 15:14 in Yangon rendered as 8:44 AM — one UTC offset
/// early — and the `.toLocal()` the screens already called had nothing left
/// to convert.
///
/// A bare date is a different thing and is left where it is: an expiry of
/// `2026-09-27` means that day, not a moment, and shifting it back 6h30m
/// would show the 26th.
@immutable
class AppTime {
  const AppTime._();

  /// `Z`, `z`, `+06:30` or `-0500` at the end of the string.
  static final RegExp _hasZone = RegExp(r'(?:Z|z|[+-]\d{2}:?\d{2})$');

  /// A clock somewhere after the date part.
  static final RegExp _hasClock = RegExp(r'[T ]\d{2}:\d{2}');

  /// Parses [raw] and returns it in the device's own zone.
  ///
  /// Returns null for null, empty, or unparseable input — the same contract
  /// as `DateTime.tryParse`, so a call site's null handling is unchanged.
  static DateTime? parse(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    if (_hasZone.hasMatch(text)) {
      return DateTime.tryParse(text)?.toLocal();
    }

    // A date with no time of day: a deadline, not a moment. Parsed as it
    // stands so it keeps its calendar day.
    if (!_hasClock.hasMatch(text)) {
      return DateTime.tryParse(text);
    }

    // A clock with no zone. The server means UTC; say so, then convert.
    return DateTime.tryParse('${text.replaceFirst(' ', 'T')}Z')?.toLocal();
  }
}
