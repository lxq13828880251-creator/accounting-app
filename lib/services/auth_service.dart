import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_config.dart';
import '../core/models/user.dart';

/// 认证服务
class AuthService {
  final ApiClient _apiClient = apiClient;
  
  /// 登录
  Future<User> login(String username, String password) async {
    try {
      final formData = FormData.fromMap({
        'username': username,
        'password': password,
      });
      
      final response = await Dio().post(
        '${AppConfig.apiBaseUrl}/api/auth/token',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      
      final data = response.data;
      final token = data['access_token'] as String;
      
      // 保存Token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.tokenKey, token);
      
      // 获取用户信息
      return await getUserInfo();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('用户名或密码错误');
      }
      throw Exception('登录失败: ${e.message}');
    }
  }
  
  /// 注册
  Future<void> register(String username, String email, String password) async {
    try {
      await _apiClient.post(
        '/api/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw Exception('注册失败: ${e.message}');
    }
  }
  
  /// 获取当前用户信息
  Future<User> getUserInfo() async {
    try {
      final response = await _apiClient.get('/api/auth/me');
      return User.fromJson(response.data);
    } catch (e) {
      throw Exception('获取用户信息失败');
    }
  }
  
  /// 登出
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove(AppConfig.userKey);
    // 通知所有监听器登录状态已变更
    notifyLoginExpired();
  }
  
  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.tokenKey) != null;
  }
}
