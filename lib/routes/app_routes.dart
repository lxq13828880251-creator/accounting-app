import 'package:flutter/material.dart';
import '../ui/pages/splash_page.dart';
import '../ui/pages/login_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/add_record_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String addRecord = '/add-record';
  
  static final pages = [
    GetPage(name: splash, page: () => const SplashPage()),
    GetPage(name: login, page: () => const LoginPage()),
    GetPage(name: home, page: () => const HomePage()),
    GetPage(name: addRecord, page: () => const AddRecordPage()),
  ];
}

// 简单的路由管理（兼容非GetX方式）
class GetPage {
  final String name;
  final Widget Function() page;
  
  const GetPage({required this.name, required this.page});
}
