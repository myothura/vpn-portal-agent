// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get secureLogin => 'Secure Login';

  @override
  String get loginCredentials => 'Please enter your agent credentials';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get login => 'LOGIN';

  @override
  String get loggingIn => 'LOGGING IN...';

  @override
  String get loginFailed => 'Login Failed. Please check your credentials.';

  @override
  String get selectLanguage => 'Select Language';
}
