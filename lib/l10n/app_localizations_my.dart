// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get secureLogin => 'လုံခြုံစွာဝင်ရောက်ခြင်း';

  @override
  String get loginCredentials => 'သင်၏ကိုယ်စားလှယ်အချက်အလက်ကိုထည့်ပါ';

  @override
  String get username => 'အသုံးပြုသူအမည်';

  @override
  String get password => 'စကားဝှက်';

  @override
  String get login => 'ဝင်ရောက်ရန်';

  @override
  String get loggingIn => 'ဝင်ရောက်နေသည်...';

  @override
  String get loginFailed =>
      'ဝင်ရောက်မှု မအောင်မြင်ပါ။ အချက်အလက်များပြန်စစ်ဆေးပါ။';

  @override
  String get selectLanguage => 'ဘာသာစကား ရွေးချယ်ပါ';
}
