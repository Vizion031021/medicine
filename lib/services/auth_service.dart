import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyUserId = 'user_id';
  static const _keyNickname = 'nickname';
  static const _keyLoginId = 'login_id';

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNickname) ?? '사용자';
  }

  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLoginId) ?? '';
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final loginId = email.trim();
    final userName = nickname.trim();

    if (loginId.isEmpty || password.isEmpty || userName.isEmpty) {
      return '모든 항목을 입력해주세요.';
    }
    if (password.length < 4) return '데모 비밀번호는 4자 이상 입력해주세요.';
    if (userName.length < 2) return '닉네임은 2자 이상이어야 합니다.';

    try {
      final existing = await _client
          .from('user_info')
          .select('id')
          .eq('login_id', loginId)
          .maybeSingle();

      if (existing != null) return '이미 가입된 아이디입니다.';

      final inserted = await _client
          .from('user_info')
          .insert({
            'login_id': loginId,
            'password': password,
            'user_name': userName,
          })
          .select('id, login_id, user_name')
          .single();

      await _saveSession(Map<String, dynamic>.from(inserted));
      return null;
    } on PostgrestException catch (error) {
      return '회원가입 실패: ${error.message}';
    } catch (_) {
      return '회원가입 중 오류가 발생했습니다.';
    }
  }

  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final loginId = email.trim();
    if (loginId.isEmpty || password.isEmpty) {
      return '아이디와 비밀번호를 입력해주세요.';
    }

    try {
      final user = await _client
          .from('user_info')
          .select('id, login_id, user_name')
          .eq('login_id', loginId)
          .eq('password', password)
          .maybeSingle();

      if (user == null) return '아이디 또는 비밀번호가 올바르지 않습니다.';

      await _saveSession(Map<String, dynamic>.from(user));
      return null;
    } on PostgrestException catch (error) {
      return '로그인 실패: ${error.message}';
    } catch (_) {
      return '로그인 중 오류가 발생했습니다.';
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUserId);
  }

  static Future<void> updateNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    await prefs.setString(_keyNickname, nickname);
    if (userId != null) {
      await _client
          .from('user_info')
          .update({'user_name': nickname})
          .eq('id', userId);
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, (user['id'] ?? '').toString());
    await prefs.setString(_keyLoginId, (user['login_id'] ?? '').toString());
    await prefs.setString(_keyNickname, (user['user_name'] ?? '사용자').toString());
  }
}
