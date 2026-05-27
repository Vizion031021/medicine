import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sseudeuson/config/supabase_config.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/screens/home_screen.dart';
import 'package:sseudeuson/screens/bag_screen.dart';
import 'package:sseudeuson/screens/calendar_screen.dart';
import 'package:sseudeuson/screens/search_screen.dart';
import 'package:sseudeuson/screens/auth/login_screen.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/services/notification_service.dart';

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
  await NotificationService.initialize();

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
        scaffoldBackgroundColor: AppColors.lavenderLight,
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
            borderSide: const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lavender, width: 1),
          ),
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      // 로그인 여부에 따라 시작 화면 결정
      home: FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.data == true) {
            return const MainScaffold();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// ─── 스플래시 화면 ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.lavenderLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_rounded,
              size: 60,
              color: AppColors.lavender,
            ),
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

// ─── 메인 스캐폴드 (하단 탭바) ─────────────────────────────────────────────

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _homeRefreshKey = 0;
  int _bagRefreshKey = 0;
  int _calendarRefreshKey = 0;

  List<Widget> get _screens => [
        HomeScreen(key: ValueKey(_homeRefreshKey)),
        BagScreen(key: ValueKey(_bagRefreshKey)),
        CalendarScreen(key: ValueKey(_calendarRefreshKey)),
        const SearchScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECE8F8), width: 0.5),
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
                  _homeRefreshKey++;
                }),
              ),
              _NavItem(
                icon: Icons.medication_outlined,
                activeIcon: Icons.medication_rounded,
                label: '약봉투',
                isActive: _currentIndex == 1,
                onTap: () => setState(() {
                  _currentIndex = 1;
                  _bagRefreshKey++;
                }),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: '캘린더',
                isActive: _currentIndex == 2,
                onTap: () => setState(() {
                  _currentIndex = 2;
                  _calendarRefreshKey++;
                }),
              ),
              _NavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: '검색',
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
        borderRadius: BorderRadius.circular(8),
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
