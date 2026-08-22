// lib/shared_widgets/language_picker_widget.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vpn_agent_app/core/providers/locale_provider.dart';
import 'package:vpn_agent_app/l10n/app_localizations.dart';
import 'package:vpn_agent_app/l10n/l10n.dart'; // ⭐️ Import အသစ်ထည့်လိုက်ပါပြီ

class LanguagePickerWidget extends StatelessWidget {
  const LanguagePickerWidget({super.key});

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'my':
        return 'မြန်မာ';
      case 'zh':
        return '中文';
      default:
        return '';
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentLocale =
        localeProvider.locale ?? Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  ...L10n.all.map((locale) {
                    final isSelected =
                        currentLocale.languageCode == locale.languageCode;
                    return GestureDetector(
                      onTap: () {
                        localeProvider.setLocale(locale);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 8.0,
                        ),
                        margin: const EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            Text(
                              L10n.getFlag(locale.languageCode),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _getLanguageName(locale.languageCode),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale =
        localeProvider.locale ?? Localizations.localeOf(context);

    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            L10n.getFlag(currentLocale.languageCode),
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
