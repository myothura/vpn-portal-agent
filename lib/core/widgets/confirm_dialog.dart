// lib/core/widgets/confirm_dialog.dart
//
// AGENT_APP_SHARED_V1 — one confirmation, used by every irreversible action.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One labelled line inside a confirmation — "ကုန်ကျမည့် Credit: 5,000".
///
/// The point of the dialog is that the agent sees the number before the tap,
/// not after it, so anything that will be spent or sent belongs here.
class ConfirmDetail {
  final String label;
  final String value;
  final bool emphasise;

  const ConfirmDetail(this.label, this.value, {this.emphasise = false});
}

/// Asks before something that costs money or cannot be taken back.
///
/// Returns true only on an explicit confirm. A dismissed dialog — back
/// gesture, tap outside, cancel — returns false, never null, so the caller
/// cannot forget to handle it.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'အတည်ပြုမည်',
  String cancelLabel = 'မလုပ်တော့ပါ',
  bool destructive = false,
  List<ConfirmDetail> details = const [],
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final accent = destructive ? AppColors.danger : AppColors.accentInk;
      return AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
        actionsPadding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: destructive
                    ? AppColors.dangerWash
                    : AppColors.accentWash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                destructive
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                size: 19,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        if (i > 0) const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                details[i].label,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              details[i].value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: details[i].emphasise ? 15 : 13,
                                height: 1.45,
                                fontWeight: details[i].emphasise
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: details[i].emphasise
                                    ? accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              cancelLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: accent,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
