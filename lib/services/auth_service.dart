import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyNickname = 'nickname';
  static const _keyEmail = 'email';
  static const _keyPassword = 'password'; // 실제 앱에서는 암호화 필요

  // ── 로그인 여부 확인 ──
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // ── 닉네임 가져오기 ──
  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNickname) ?? '사용자';
  }

  // ── 이메일 가져오기 ──
  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  // ── 회원가입 ──
  static Future<String?> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    if (email.isEmpty || password.isEmpty || nickname.isEmpty) {
      return '모든 항목을 입력해주세요.';
    }
    if (!email.contains('@')) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    if (password.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (nickname.length < 2) {
      return '닉네임은 2자 이상이어야 합니다.';
    }

    final prefs = await SharedPreferences.getInstance();

    // 이미 가입된 이메일 체크
    final savedEmail = prefs.getString(_keyEmail);
    if (savedEmail == email) {
      return '이미 가입된 이메일입니다.';
    }

    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
    await prefs.setString(_keyNickname, nickname);
    await prefs.setBool(_keyIsLoggedIn, true);
    return null; // null = 성공
  }

  // ── 로그인 ──
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      return '이메일과 비밀번호를 입력해주세요.';
    }

    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_keyEmail);
    final savedPassword = prefs.getString(_keyPassword);

    if (savedEmail == null || savedEmail != email) {
      return '가입되지 않은 이메일입니다.';
    }
    if (savedPassword != password) {
      return '비밀번호가 올바르지 않습니다.';
    }

    await prefs.setBool(_keyIsLoggedIn, true);
    return null; // null = 성공
  }

  // ── 로그아웃 ──
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  // ── 닉네임 변경 ──
  static Future<void> updateNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
  }
}
