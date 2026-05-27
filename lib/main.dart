import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sseudeuson/config/supabase_config.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/screens/home_screen.dart';
import 'package:sseudeuson/screens/bag_screen.dart';
import 'package:sseudeuson/screens/calendar_screen.dart';
import 'package:sseudeuson/screens/compare_screen.dart';
import 'package:sseudeuson/screens/auth/login_screen.dart';
import 'package:sseudeuson/services/auth_service.dart';
// import 'package:sseudeuson/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  if (SupabaseConfig.anonKey.isEmpty) {
    throw StateError('SUPABASE_ANON_KEY is not set.');
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // await NotificationService.initialize();

  runApp(const SseudeusOnApp());
}

class SseudeusOnApp extends StatelessWidget {
  const SseudeusOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쓰디슨',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.lavender,
          brightness: Brightness.light,
        ),
        // ① 흰색 기본 배경
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.lavenderDark),
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        // ② 카드 배경 흰색, 테두리 라벤더
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
          ),
        ),
        dividerColor: AppColors.divider,
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.lavenderBg,
          labelStyle: const TextStyle(
            color: AppColors.lavenderDark,
            fontSize: 10,
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lavenderBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lavender, width: 1),
          ),
          hintStyle:
              const TextStyle(color: AppColors.textHint, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lavender,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.data == true) return const MainScaffold();
          return const LoginScreen();
        },
      ),
    );
  }
}

// ─── 스플래시 ─────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_rounded, size: 60, color: AppColors.lavender),
            SizedBox(height: 16),
            Text(
              '쓰디슨',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.lavenderDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 메인 스캐폴드 ────────────────────────────────────────────────────────────

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _homeKey = 0;
  int _bagKey = 0;
  int _calKey = 0;

  List<Widget> get _screens => [
        HomeScreen(key: ValueKey(_homeKey)),
        BagScreen(key: ValueKey(_bagKey)),
        CalendarScreen(key: ValueKey(_calKey)),
        const CompareScreen(), // ③ 4번째 탭: 약 비교
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: '홈',
                isActive: _currentIndex == 0,
                onTap: () => setState(() {
                  _currentIndex = 0;
                  _homeKey++;
                }),
              ),
              _NavItem(
                icon: Icons.medication_outlined,
                activeIcon: Icons.medication_rounded,
                label: '약봉투',
                isActive: _currentIndex == 1,
                onTap: () => setState(() {
                  _currentIndex = 1;
                  _bagKey++;
                }),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: '캘린더',
                isActive: _currentIndex == 2,
                onTap: () => setState(() {
                  _currentIndex = 2;
                  _calKey++;
                }),
              ),
              _NavItem(
                icon: Icons.compare_arrows_outlined,
                activeIcon: Icons.compare_arrows_rounded,
                label: '약 비교', // ③ 탭 이름 변경
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.lavender : AppColors.textHint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
