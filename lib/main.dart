import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:vpn_agent_app/core/services/remote_config_service.dart';

import 'package:vpn_agent_app/core/providers/locale_provider.dart';
import 'package:vpn_agent_app/features/auth/screens/auth_check_screen.dart';
import 'package:vpn_agent_app/l10n/app_localizations.dart';
import 'package:vpn_agent_app/l10n/l10n.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/chat/screens/agent_chat_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('app_cache');

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("Firebase Init Error: $e");
  }

  // Must complete BEFORE runApp: ApiClient is a singleton whose
  // BaseOptions.baseUrl is seeded at first construction, and AuthCheckScreen
  // fires an API call immediately. Fetching later would pin the first request
  // to the DPI-blocked default host and burn a connect timeout before the
  // fallback chain could rotate.
  await RemoteConfigService().initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Permission is requested once, in NotificationService.initialize(), which
    // owns notifications. Asking here too raced with it — firebase_messaging
    // throws "a request for permissions is already running", which stranded
    // AuthCheckScreen on the splash. The race only surfaced once the awaited
    // RemoteConfig fetch shifted startup timing.

    // App in foreground - show nothing, chat auto-refreshes
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message: ${message.data}');
    });

    // App in background - user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📩 Background tap: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // App was terminated - user taps notification to open
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📩 Initial message: ${initialMessage.data}');
      // Delay to ensure navigation is ready
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    if (type == 'chat_message') {
      final vpnUserId = int.tryParse(data['vpn_user_id']?.toString() ?? '');
      final username = data['username'] ?? '';
      if (vpnUserId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                AgentChatDetailScreen(userId: vpnUserId, username: username),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return Consumer<LocaleProvider>(
            builder: (context, provider, child) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'Agent Portal',
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: AppColors.darkBackground,
                  textTheme: Typography.englishLike2021.apply(
                    fontFamily: 'Ubuntu',
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                  ),
                ),
                locale: provider.locale,
                supportedLocales: L10n.all,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                home: const AuthCheckScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
