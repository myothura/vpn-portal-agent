// test/widget_test.dart
//
// AGENT_APP_TESTS_V1 — confirmAction, the dialog in front of every
// irreversible action.
//
// This file was the generated counter-app template: it pumped MyApp(), looked
// for find.text('0') and tapped Icons.add. This app has no counter, so it
// failed on every run.
//
// confirmAction guards saving an edited user, assigning a business plan,
// transferring credit, broadcasting to every conversation and approving a
// renewal. Its contract is that it returns true only on an explicit confirm
// and false — never null — for everything else, because the callers are
// written as `if (!await confirmAction(...)) return;`.
//
// A widget test over a plain MaterialApp. No network, no Firebase, no
// plugins: the dialog is Flutter widgets over AppColors tokens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_agent_app/core/widgets/confirm_dialog.dart';

void main() {
  /// Pumps one button that opens the dialog, runs [act] on the open dialog,
  /// and hands back whatever confirmAction resolved to.
  Future<bool?> openThen(
    WidgetTester tester,
    Future<void> Function(WidgetTester tester) act,
  ) async {
    bool? answer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  answer = await confirmAction(
                    context,
                    title: 'Approve this request',
                    message: 'Credit is deducted as soon as you confirm.',
                    details: const [
                      ConfirmDetail('Cost', '5,000', emphasise: true),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Approve this request'), findsOneWidget);

    await act(tester);
    await tester.pumpAndSettle();

    return answer;
  }

  testWidgets('confirming returns true', (tester) async {
    final answer = await openThen(tester, (t) async {
      await t.tap(find.byType(FilledButton));
    });

    expect(answer, isTrue);
    expect(find.text('Approve this request'), findsNothing);
  });

  testWidgets('cancelling returns false', (tester) async {
    final answer = await openThen(tester, (t) async {
      await t.tap(find.byType(TextButton));
    });

    expect(answer, isFalse);
    expect(find.text('Approve this request'), findsNothing);
  });

  testWidgets('dismissing the barrier returns false, never null', (
    tester,
  ) async {
    // showDialog resolves to null on a barrier tap or a back gesture.
    // confirmAction turns that into false so no caller can forget it.
    final answer = await openThen(tester, (t) async {
      await t.tapAt(const Offset(10, 10));
    });

    expect(answer, isNotNull);
    expect(answer, isFalse);
  });

  testWidgets('the number being spent is on screen before the tap', (
    tester,
  ) async {
    // The whole point of the details block: the agent sees the figure in the
    // dialog rather than finding out which button they pressed afterwards.
    final answer = await openThen(tester, (t) async {
      expect(find.text('Credit is deducted as soon as you confirm.'),
          findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);
      await t.tap(find.byType(TextButton));
    });

    expect(answer, isFalse);
  });
}
