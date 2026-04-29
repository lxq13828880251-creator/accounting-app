import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_config.dart';
import 'core/api/api_client.dart';
import 'ui/theme/app_theme.dart';
import 'ui/pages/splash_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/add_record_page.dart';
import 'ui/pages/records_page.dart';
import 'ui/pages/stats_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/budget_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: GoldenAbacusApp(),
    ),
  );
}

class GoldenAbacusApp extends StatelessWidget {
  const GoldenAbacusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 注册全局 NavigatorKey，供 ApiClient 处理 401 跳转登录
      navigatorKey: globalNavigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/add-record': (context) => const AddRecordPage(),
        '/records': (context) => const RecordsPage(),
        '/stats': (context) => const StatsPage(),
        '/settings': (context) => const SettingsPage(),
        '/budget': (context) => const BudgetPage(),
      },
    );
  }
}
