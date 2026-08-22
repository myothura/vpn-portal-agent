// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get secureLogin => '安全登录';

  @override
  String get loginCredentials => '请输入您的代理凭据';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get login => '登录';

  @override
  String get loggingIn => '正在登录...';

  @override
  String get loginFailed => '登录失败。 请检查您的凭据。';

  @override
  String get selectLanguage => '选择语言';
}
