// lib/core/utils/formatters.dart
//
// AGENT_APP_SHARED_V1 — built once, not once per row per frame.
import 'package:intl/intl.dart';

/// Shared number and date formats.
///
/// `NumberFormat('#,##0')` was being constructed 32 times inside build()
/// methods, some of them inside list row builders — so once per visible row,
/// on every frame, on lists that reach 500 rows. Constructing one parses the
/// pattern and pulls in the locale's symbol table; it is not free, and none of
/// these vary at runtime.
///
/// `late final` means each is built on first use and never again.
class Fmt {
  const Fmt._();

  /// Money and counts: 1,234,567. No decimals anywhere in this app.
  static final NumberFormat money = NumberFormat('#,##0');

  /// 24 Sep 2026
  static final DateFormat date = DateFormat('dd MMM yyyy');

  /// 24 Sep 2026, 3:05 PM
  static final DateFormat dateTime = DateFormat('dd MMM yyyy, h:mm a');

  /// 24 Sep — for a row that already sits under a year heading.
  static final DateFormat dayMonth = DateFormat('dd MMM');

  /// Sep 2026
  static final DateFormat monthYear = DateFormat('MMM yyyy');

  /// 3:05 PM
  static final DateFormat time = DateFormat('h:mm a');
}
