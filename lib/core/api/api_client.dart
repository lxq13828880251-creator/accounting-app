import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

/// 全局 NavigatorKey，供 ApiClient 处理 401 跳转登录使用
/// main.dart 的 MaterialApp 需要设置 navigatorKey: globalNavigatorKey
final globalNavigatorKey = GlobalKey<NavigatorState>();

/// 防止并发401请求重复触发跳转的静态标志
/// 使用静态变量确保全局唯一，不受实例生命周期影响
class _LoginState {
  static bool isRedirectingToLogin = false;
}

/// 登录过期监听器列表，用于通知各个页面刷新状态
final _loginExpiredListeners = <VoidCallback>[];

/// 添加登录过期监听器
void addLoginExpiredListener(VoidCallback callback) {
  _loginExpiredListeners.add(callback);
}

/// 移除登录过期监听器
void removeLoginExpiredListener(VoidCallback callback) {
  _loginExpiredListeners.remove(callback);
}

/// 通知所有监听器登录已过期
void notifyLoginExpired() {
  for (final listener in _loginExpiredListeners) {
    listener();
  }
}

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConfig.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 处理401错误 - Token过期或无效
        if (error.response?.statusCode == 401) {
          // 防止重复触发跳转
          if (!_LoginState.isRedirectingToLogin) {
            _LoginState.isRedirectingToLogin = true;

            // 清除本地token
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(AppConfig.tokenKey);
            await prefs.remove(AppConfig.userKey);

            // 通知监听器
            notifyLoginExpired();

            // 使用 postFrameCallback 确保在正确的Widget周期内执行
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _performLoginRedirect();
            });
          }
          // 返回一个特殊的错误，让调用方知道需要跳转
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: 'LOGIN_EXPIRED',
              message: '登录已过期，请重新登录',
              type: DioExceptionType.badResponse,
              response: error.response,
            ),
          );
        }

        // 处理网络连接错误
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          debugPrint('API超时: ${error.requestOptions.path}');
        } else if (error.type == DioExceptionType.connectionError) {
          debugPrint('网络连接错误: ${error.requestOptions.path}');
        }

        return handler.next(error);
      },
    ));
  }

  /// 执行登录跳转
  void _performLoginRedirect() {
    final navigator = globalNavigatorKey.currentState;
    if (navigator != null) {
      // 先显示提示
      final context = globalNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('登录已过期，请重新登录'),
              ],
            ),
            backgroundColor: Color(0xFFFF7F50),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 延迟一点跳转，让用户看到提示
      Future.delayed(const Duration(milliseconds: 500), () {
        // 跳转到登录页并清空路由栈
        navigator.pushNamedAndRemoveUntil('/login', (route) => false).then((_) {
          // 跳转完成后重置标志，允许下次正常跳转
          _LoginState.isRedirectingToLogin = false;
        });
      });
    } else {
      // 如果navigator不可用，立即重置标志
      _LoginState.isRedirectingToLogin = false;
    }
  }

  // GET请求
  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  // POST请求
  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  // PUT请求
  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  // DELETE请求
  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  /// 检查是否已登录（有有效Token）
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// 清除登录状态（主动登出时调用）
  Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove(AppConfig.userKey);
    notifyLoginExpired();
  }
}

final apiClient = ApiClient();

/// 判断DioException是否是登录过期错误
bool isLoginExpiredError(DioException error) {
  return error.error == 'LOGIN_EXPIRED' ||
         error.message == '登录已过期，请重新登录';
}
