import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  // 닉네임만 화면에 빠르게 띄우기 위해 캐싱용으로 남겨둡니다.
  static const _keyNickname = 'nickname';

  // 1. 로그인 상태 확인 (메모장이 아닌 실제 Supabase 세션 확인)
  static bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }

  // 2. 현재 유저 ID 가져오기 (공식 신분증 번호)
  static String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }

  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNickname) ?? '사용자';
  }

  static String getEmail() {
    // SharedPreferences 대신 인증된 유저의 이메일을 바로 가져옵니다.
    return _client.auth.currentUser?.email ?? '';
  }

  // 3. 회원가입 (Supabase Auth 사용 + 메타데이터에 닉네임 저장)
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
    if (password.length < 6) return '비밀번호는 6자 이상 입력해주세요.';
    if (userName.length < 2) return '닉네임은 2자 이상이어야 합니다.';

    try {
      // 1단계: Supabase 공식 인증 시스템에 가입
      final AuthResponse res = await _client.auth.signUp(
        email: loginId,
        password: password,
        // 🌟 핵심: data 파라미터를 사용해 메타데이터에 닉네임을 함께 저장합니다!
        data: {
          'display_name': userName,
        },
      );

      final User? user = res.user;

      if (user != null) {
        // 2단계: 내 user_info 테이블에 부가 정보 저장 (기존과 동일)
        await _client.from('user_info').insert({
          'id': user.id,
          'user_name': userName,
        });

        // 닉네임 로컬 캐싱
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyNickname, userName);
      }
      return null; // 성공
    } on AuthException catch (error) {
      if (error.message.contains('already registered')) {
        return '이미 가입된 이메일입니다.';
      }
      return '회원가입을 완료하지 못했습니다. 입력한 정보를 다시 확인해 주세요.';
    } catch (_) {
      return '회원가입 중 오류가 발생했습니다.';
    }
  }

  // 4. 로그인 (Supabase Auth 사용)
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final loginId = email.trim();
    if (loginId.isEmpty || password.isEmpty) {
      return '아이디와 비밀번호를 입력해주세요.';
    }

    try {
      // Supabase 시스템이 비밀번호 검증과 토큰 발급을 알아서 해줍니다.
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: loginId,
        password: password,
      );

      // 로그인 성공 후 DB에서 닉네임 가져와서 캐싱
      if (res.user != null) {
        final userData = await _client
            .from('user_info')
            .select('user_name')
            .eq('id', res.user!.id)
            .single();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyNickname, userData['user_name'] ?? '사용자');
      }

      return null; // 성공
    } on AuthException catch (_) {
      return '아이디 또는 비밀번호가 올바르지 않습니다.';
    } catch (_) {
      return '로그인 중 오류가 발생했습니다.';
    }
  }

  // 5. 로그아웃
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNickname); // 로컬 캐시 삭제
    await _client.auth.signOut(); // Supabase 공식 로그아웃 (서버 세션 파기)
  }

  // 6. 닉네임 수정
  static Future<void> updateNickname(String nickname) async {
    final userId = getCurrentUserId();
    if (userId != null) {
      // 1. 서버 업데이트
      await _client
          .from('user_info')
          .update({'user_name': nickname})
          .eq('id', userId);

      // 2. 로컬 캐시 업데이트
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNickname, nickname);
    }
  }
}
