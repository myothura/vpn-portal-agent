// test/formatters_test.dart
//
// AGENT_APP_TESTS_V1 — the shared formats and the language codes.
//
// Fmt exists because NumberFormat('#,##0') was being constructed inside build()
// methods, some of them inside list row builders. These assert both that the
// patterns render what the screens expect and that each format is one object.
//
// Pure unit tests: no binding, no network, no plugins.
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_agent_app/core/utils/formatters.dart';
import 'package:vpn_agent_app/l10n/l10n.dart';

void main() {
  group('Fmt.money', () {
    test('groups in threes and never shows a decimal', () {
      expect(Fmt.money.format(0), '0');
      expect(Fmt.money.format(999), '999');
      expect(Fmt.money.format(1000), '1,000');
      expect(Fmt.money.format(430000), '430,000');
      expect(Fmt.money.format(1234567), '1,234,567');
    });

    test('a negative balance keeps its sign', () {
      expect(Fmt.money.format(-1234), '-1,234');
    });

    test('is one object, not one per read', () {
      // A getter that returned a new NumberFormat would put the pattern parse
      // and the locale symbol load back inside every row build.
      expect(identical(Fmt.money, Fmt.money), isTrue);
      expect(identical(Fmt.date, Fmt.date), isTrue);
    });
  });

  group('Fmt date patterns', () {
    final moment = DateTime(2026, 9, 24, 15, 5);

    test('each pattern renders the shape its screens were written for', () {
      expect(Fmt.date.format(moment), '24 Sep 2026');
      expect(Fmt.dateTime.format(moment), '24 Sep 2026, 3:05 PM');
      expect(Fmt.dayMonth.format(moment), '24 Sep');
      expect(Fmt.monthYear.format(moment), 'Sep 2026');
      expect(Fmt.time.format(moment), '3:05 PM');
    });

    test('the day and the hour are padded and not padded as documented', () {
      final early = DateTime(2026, 1, 5, 9, 7);

      expect(Fmt.date.format(early), '05 Jan 2026');
      expect(Fmt.dayMonth.format(early), '05 Jan');
      expect(Fmt.time.format(early), '9:07 AM');
    });

    test('midnight and noon land on the right half of the day', () {
      expect(Fmt.time.format(DateTime(2026, 9, 24, 0, 0)), '12:00 AM');
      expect(Fmt.time.format(DateTime(2026, 9, 24, 12, 0)), '12:00 PM');
    });
  });

  group('L10n', () {
    test('getCode returns the two-letter code for each supported locale', () {
      expect(L10n.getCode('en'), 'EN');
      expect(L10n.getCode('my'), 'MY');
      expect(L10n.getCode('zh'), 'ZH');
    });

    test('getCode falls back to the upper-cased code for anything else', () {
      expect(L10n.getCode('th'), 'TH');
      expect(L10n.getCode('ko'), 'KO');
      expect(L10n.getCode(''), '');
    });

    test('the picker offers exactly the three locales the app ships', () {
      expect(
        L10n.all.map((locale) => locale.languageCode).toList(),
        ['en', 'my', 'zh'],
      );
    });
  });
}
