import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_config.dart';

/// 用户信息Provider
final userInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await apiClient.get('/api/users/me');
  return response.data;
});

class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  String? _username;
  String? _gender;
  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(userInfoProvider.future);
      setState(() {
        _avatarUrl = data['avatar_url'];
        _username = data['username'];
        _gender = data['gender'];
        _latitude = data['latitude']?.toDouble();
        _longitude = data['longitude']?.toDouble();
        _locationName = data['location_name'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
      imageQuality: 80,
    );
    
    if (pickedFile == null) return;
    
    setState(() => _isUploadingAvatar = true);
    
    try {
      final file = File(pickedFile.path);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConfig.tokenKey);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
      
      final response = await Dio().post(
        '${AppConfig.apiBaseUrl}/api/users/me/avatar',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      
      final newAvatarUrl = response.data['avatar_url'];
      setState(() => _avatarUrl = newAvatarUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _getLocation() async {
    try {
      final location = Location();
      
      // 检查权限
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要定位权限')),
            );
          }
          return;
        }
      }
      
      // 获取位置
      final locationData = await location.getLocation();
      
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _latitude = locationData.latitude;
          _longitude = locationData.longitude;
        });
        
        // 保存到服务器
        await _saveLocation();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('定位成功: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('定位失败: $e')),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    try {
      await apiClient.put('/api/users/me', data: {
        'latitude': _latitude,
        'longitude': _longitude,
      });
    } catch (e) {
      // 静默处理
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '用户名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty && result != _username) {
      await _updateProfile(username: result);
    }
  }

  Future<void> _editGender() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择性别'),
        children: [
          RadioListTile<String>(
            value: 'male',
            groupValue: _gender,
            title: const Text('男'),
            onChanged: (value) => Navigator.pop(context, value),
          ),
          RadioListTile<String>(
            value: 'female',
            groupValue: _gender,
            title: const Text('女'),
            onChanged: (value) => Navigator.pop(context, value),
          ),
          RadioListTile<String>(
            value: 'other',
            groupValue: _gender,
            title: const Text('其他'),
            onChanged: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
    );
    
    if (result != null && result != _gender) {
      await _updateProfile(gender: result);
    }
  }

  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(
                labelText: '原密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: '新密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        await apiClient.put('/api/users/me/password', data: {
          'old_password': oldPasswordController.text,
          'new_password': newPasswordController.text,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码修改成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('修改失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateProfile({String? username, String? gender}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (gender != null) data['gender'] = gender;
      
      await apiClient.put('/api/users/me', data: data);
      
      if (username != null) setState(() => _username = username);
      if (gender != null) setState(() => _gender = gender);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  String _getGenderDisplay(String? gender) {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      case 'other':
        return '其他';
      default:
        return '未设置';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF6B6B);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text('个人资料'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 头像卡片
                  _buildCard(
                    child: Column(
                      children: [
                        const Text('头像', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: primaryColor.withOpacity(0.1),
                                backgroundImage: _avatarUrl != null
                                    ? NetworkImage('http://114.132.171.188$_avatarUrl')
                                    : null,
                                child: _avatarUrl == null
                                    ? Icon(Icons.person, size: 50, color: primaryColor)
                                    : null,
                              ),
                              if (_isUploadingAvatar)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击更换头像',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 基本信息卡片
                  _buildCard(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.person,
                          title: '用户名',
                          value: _username ?? '未设置',
                          onTap: _editUsername,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          icon: Icons.wc,
                          title: '性别',
                          value: _getGenderDisplay(_gender),
                          onTap: _editGender,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 安全设置卡片
                  _buildCard(
                    child: _buildInfoRow(
                      icon: Icons.lock,
                      title: '修改密码',
                      value: '••••••••',
                      onTap: _changePassword,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 位置信息卡片
                  _buildCard(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.location_on,
                          title: '定位信息',
                          value: _latitude != null
                              ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                              : '未获取',
                          onTap: _getLocation,
                        ),
                        if (_locationName != null) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.place, color: Colors.grey.shade400, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _locationName!,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B6B), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15)),
            ),
            Text(
              value,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
