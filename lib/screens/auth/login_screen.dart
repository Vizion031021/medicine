import 'package:flutter/material.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/screens/auth/signup_screen.dart';
import 'package:sseudeuson/main.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final error = await AuthService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);
    if (error != null) { setState(() => _errorMessage = error); return; }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const MainScaffold()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('쓰디슨', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lavenderDark)),
                const SizedBox(height: 6),
                const Text('나만의 약품 관리 앱', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              ])),
              const SizedBox(height: 48),
              const Text('이메일', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.lavender),
                ),
              ),
              const SizedBox(height: 16),
              const Text('비밀번호', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '4자 이상 입력',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.lavender),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: AppColors.textHint),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
                    const SizedBox(width: 7),
                    Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.lavender,
                    disabledBackgroundColor: AppColors.lavender.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('로그인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('아직 계정이 없으신가요?  ', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: const Text('회원가입',
                      style: TextStyle(fontSize: 13, color: AppColors.lavender, fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline, decorationColor: AppColors.lavender)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
