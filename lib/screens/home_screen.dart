import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/screens/auth/login_screen.dart';

// ─── 계절 ────────────────────────────────────────────────────────────────────

enum Season { spring, summer, autumn, winter }

Season _detectSeason() {
  final m = DateTime.now().month;
  if (m >= 3 && m <= 5) return Season.spring;
  if (m >= 6 && m <= 8) return Season.summer;
  if (m >= 9 && m <= 11) return Season.autumn;
  return Season.winter;
}

// ─── 시간대 ──────────────────────────────────────────────────────────────────

enum DayPeriod { morning, afternoon, evening, night }

extension DayPeriodExt on DayPeriod {
  String get label {
    switch (this) {
      case DayPeriod.morning:   return '아침';
      case DayPeriod.afternoon: return '오후';
      case DayPeriod.evening:   return '저녁';
      case DayPeriod.night:     return '밤';
    }
  }

  String get greeting {
    switch (this) {
      case DayPeriod.morning:   return '좋은 아침이에요';
      case DayPeriod.afternoon: return '좋은 오후예요';
      case DayPeriod.evening:   return '노을이 예쁜 저녁이에요';
      case DayPeriod.night:     return '편안한 밤이에요';
    }
  }
}

// ─── 파티클 ──────────────────────────────────────────────────────────────────

class _Particle {
  double x, y, vx, vy;
  double size, opacity, rot, rotV;
  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.opacity,
    this.rot = 0, this.rotV = 0,
  });
}

// ─── 복약 일정 아이템 ─────────────────────────────────────────────────────────

class _ScheduleItem {
  final String? scheduleId;
  final int num;
  final String name;
  final String time;
  final String detail;
  final bool done;
  const _ScheduleItem({
    this.scheduleId,
    required this.num, required this.name,
    required this.time, required this.detail,
    required this.done,
  });
}

// ─── 홈 화면 ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  DayPeriod _period = DayPeriod.morning;
  Season _season = Season.spring;
  Timer? _periodTimer;
  String _nickname = '사용자';
  List<_ScheduleItem> _todaySchedules = [];

  // 파티클 + 별
  late AnimationController _animCtrl;
  List<_Particle> _particles = [];
  static final List<_StarPoint> _stars = _genStars();

  static List<_StarPoint> _genStars() {
    final rng = math.Random(42); // 고정 seed → 항상 같은 위치
    return List.generate(28, (_) => _StarPoint(
      x: rng.nextDouble() * 0.92 + 0.04,
      y: rng.nextDouble() * 0.62 + 0.03,
      r: rng.nextDouble() * 1.6 + 0.4,
      op: rng.nextDouble() * 0.6 + 0.3,
    ));
  }

  @override
  void initState() {
    super.initState();
    _season = _detectSeason();
    _period = _detectPeriod();
    _initParticles();
    _loadNickname();
    _loadTodaySchedules();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      if (_particles.isNotEmpty) _tickParticles();
    });

    final needsAnim = _season == Season.spring || _season == Season.winter;
    if (needsAnim) _animCtrl.repeat();

    _periodTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final p = _detectPeriod();
      if (p != _period && mounted) {
        setState(() => _period = p);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _periodTimer?.cancel();
    super.dispose();
  }

  DayPeriod _detectPeriod() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12)  return DayPeriod.morning;
    if (h >= 12 && h < 17) return DayPeriod.afternoon;
    if (h >= 17 && h < 21) return DayPeriod.evening;
    return DayPeriod.night;
  }

  void _initParticles() {
    final rng = math.Random();
    _particles = [];
    if (_season == Season.spring) {
      for (int i = 0; i < 18; i++) {
        _particles.add(_Particle(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          vx: (rng.nextDouble() - 0.5) * 0.0004,
          vy: rng.nextDouble() * 0.0003 + 0.00015,
          size: rng.nextDouble() * 5 + 3,
          opacity: rng.nextDouble() * 0.5 + 0.4,
          rot: rng.nextDouble() * 360,
          rotV: (rng.nextDouble() - 0.5) * 0.6,
        ));
      }
    } else if (_season == Season.winter) {
      for (int i = 0; i < 30; i++) {
        _particles.add(_Particle(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          vx: (rng.nextDouble() - 0.5) * 0.0003,
          vy: rng.nextDouble() * 0.0004 + 0.0002,
          size: rng.nextDouble() * 2.5 + 1.2,
          opacity: rng.nextDouble() * 0.55 + 0.35,
        ));
      }
    }
  }

  void _tickParticles() {
    for (final p in _particles) {
      p.y += p.vy;
      p.x += p.vx;
      p.rot += p.rotV;
      if (p.y > 1.02) { p.y = -0.03; p.x = math.Random().nextDouble(); }
      if (p.x > 1.05) p.x = -0.03;
      if (p.x < -0.05) p.x = 1.03;
    }
    setState(() {});
  }

  Future<void> _loadNickname() async {
    final n = await AuthService.getNickname();
    if (mounted) setState(() => _nickname = n);
  }

  Future<void> _loadTodaySchedules() async {
    final now = DateTime.now();
    try {
      final schedules = await ScheduleService.fetchSchedules(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      if (!mounted) return;
      setState(() {
        _todaySchedules = List.generate(schedules.length, (i) {
          final s = schedules[i];
          return _ScheduleItem(
            scheduleId: s.id,
            num: i + 1,
            name: s.medication?.displayName ?? '등록 약',
            time: s.time,
            detail: s.medication?.instruction.isNotEmpty == true
                ? s.medication!.instruction : '복용 예정',
            done: s.isTaken,
          );
        });
      });
    } catch (_) {}
  }

  // ── 현재 복용 시간대에 해당하는 미복용 약 ──
  List<_ScheduleItem> get _pendingNow {
    final h = DateTime.now().hour;
    return _todaySchedules.where((s) {
      if (s.done) return false;
      final sh = int.tryParse(s.time.split(':').first) ?? -1;
      switch (_period) {
        case DayPeriod.morning:   return sh >= 5 && sh < 12;
        case DayPeriod.afternoon: return sh >= 12 && sh < 17;
        case DayPeriod.evening:   return sh >= 17 && sh < 21;
        case DayPeriod.night:     return sh >= 21 || sh < 5;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildTodaySchedule(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더 ──

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 일러스트 캔버스
          SizedBox(
            height: 160,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, __) => CustomPaint(
                painter: _SeasonPainter(
                  period: _period,
                  season: _season,
                  particles: _particles,
                  stars: _stars,
                  pendingCount: _pendingNow.length,
                  pendingNames: _pendingNow.take(2).map((s) => s.name).toList(),
                ),
              ),
            ),
          ),
          // 사용자 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('안녕하세요',
                    style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '$_nickname님 ',
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text: '오늘도 건강하게!',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint),
                        ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
                      ),
                      child: Text(_period.label,
                          style: const TextStyle(
                            fontSize: 11, color: AppColors.lavenderDark,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, size: 13, color: AppColors.textHint),
                      SizedBox(width: 3),
                      Text('로그아웃',
                          style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, color: AppColors.cardBorder),
        ],
      ),
    );
  }

  // ── 오늘의 복약 일정 ──

  Widget _buildTodaySchedule() {
    final doneCount = _todaySchedules.where((s) => s.done).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘의 복약 일정',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text('$doneCount / ${_todaySchedules.length} 복용',
                  style: const TextStyle(fontSize: 11,
                      color: AppColors.lavenderDark, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: _todaySchedules.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('오늘 예정된 복용 일정이 없습니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ),
            )
                : Column(
              children: List.generate(_todaySchedules.length, (i) {
                return _ScheduleRow(
                  item: _todaySchedules[i],
                  isLast: i == _todaySchedules.length - 1,
                  onChanged: _loadTodaySchedules,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 별 위치 (고정) ───────────────────────────────────────────────────────────

class _StarPoint {
  final double x, y, r, op;
  const _StarPoint({required this.x, required this.y, required this.r, required this.op});
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class _SeasonPainter extends CustomPainter {
  final DayPeriod period;
  final Season season;
  final List<_Particle> particles;
  final List<_StarPoint> stars;
  final int pendingCount;
  final List<String> pendingNames;

  const _SeasonPainter({
    required this.period,
    required this.season,
    required this.particles,
    required this.stars,
    required this.pendingCount,
    required this.pendingNames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    switch (season) {
      case Season.spring:  _drawSpring(canvas, size);
      case Season.summer:  _drawSummer(canvas, size);
      case Season.autumn:  _drawAutumn(canvas, size);
      case Season.winter:  _drawWinter(canvas, size);
    }
    _drawCelestial(canvas, size);
    _drawParticles(canvas, size);
    _drawOverlayText(canvas, size);
  }

  // ── 하늘 ──

  void _drawSky(Canvas canvas, Size size) {
    final colors = _skyColors();
    final paint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.72));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.72), paint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      Paint()..color = _groundColor(),
    );
  }

  List<Color> _skyColors() {
    final m = {
      Season.spring: {
        DayPeriod.morning:   [const Color(0xFFFDEAF5), const Color(0xFFFCDFEF), const Color(0xFFDDBFE8)],
        DayPeriod.afternoon: [const Color(0xFFFFF0FA), const Color(0xFFFFD6F0), const Color(0xFFC5A3D9)],
        DayPeriod.evening:   [const Color(0xFFFFCCBC), const Color(0xFFF48FB1), const Color(0xFFCE93D8)],
        DayPeriod.night:     [const Color(0xFF1A0A2E), const Color(0xFF2D1B4E), const Color(0xFF3D2260)],
      },
      Season.summer: {
        DayPeriod.morning:   [const Color(0xFFE0F7FA), const Color(0xFFB2EBF2), const Color(0xFF80DEEA)],
        DayPeriod.afternoon: [const Color(0xFFB3E5FC), const Color(0xFF81D4FA), const Color(0xFF4FC3F7)],
        DayPeriod.evening:   [const Color(0xFFFFAB40), const Color(0xFFFF7043), const Color(0xFFE91E63)],
        DayPeriod.night:     [const Color(0xFF0D1B2A), const Color(0xFF1B2A3E), const Color(0xFF1E3A5F)],
      },
      Season.autumn: {
        DayPeriod.morning:   [const Color(0xFFFFF8E1), const Color(0xFFFFE0B2), const Color(0xFFFFCC80)],
        DayPeriod.afternoon: [const Color(0xFFFFE0B2), const Color(0xFFFFAB40), const Color(0xFFFF7043)],
        DayPeriod.evening:   [const Color(0xFFFF7043), const Color(0xFFE64A19), const Color(0xFFBF360C)],
        DayPeriod.night:     [const Color(0xFF1A0F00), const Color(0xFF2C1A00), const Color(0xFF3E2800)],
      },
      Season.winter: {
        DayPeriod.morning:   [const Color(0xFFE8EAF6), const Color(0xFFC5CAE9), const Color(0xFF9FA8DA)],
        DayPeriod.afternoon: [const Color(0xFFCFD8DC), const Color(0xFFB0BEC5), const Color(0xFF90A4AE)],
        DayPeriod.evening:   [const Color(0xFF7E57C2), const Color(0xFF5C6BC0), const Color(0xFFB39DDB)],
        DayPeriod.night:     [const Color(0xFF0D0D1A), const Color(0xFF141428), const Color(0xFF1A1A3A)],
      },
    };
    return m[season]![period]!;
  }

  Color _groundColor() {
    const g = {
      Season.spring: {DayPeriod.morning:Color(0xFFC8E6C9),DayPeriod.afternoon:Color(0xFFA5D6A7),DayPeriod.evening:Color(0xFFA5D6A7),DayPeriod.night:Color(0xFF1B5E20)},
      Season.summer: {DayPeriod.morning:Color(0xFFC8E6C9),DayPeriod.afternoon:Color(0xFFA5D6A7),DayPeriod.evening:Color(0xFF388E3C),DayPeriod.night:Color(0xFF1B5E20)},
      Season.autumn: {DayPeriod.morning:Color(0xFF8D6E63),DayPeriod.afternoon:Color(0xFF795548),DayPeriod.evening:Color(0xFF5D4037),DayPeriod.night:Color(0xFF3E2723)},
      Season.winter: {DayPeriod.morning:Color(0xFFE0E0E0),DayPeriod.afternoon:Color(0xFFBDBDBD),DayPeriod.evening:Color(0xFF9E9E9E),DayPeriod.night:Color(0xFF212121)},
    };
    return g[season]![period]!;
  }

  // ── 해/달 ──

  void _drawCelestial(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final sunX = {DayPeriod.morning: W*0.82, DayPeriod.afternoon: W*0.78, DayPeriod.evening: W*0.12, DayPeriod.night: W*0.82};
    final sunY = {DayPeriod.morning: H*0.5, DayPeriod.afternoon: H*0.16, DayPeriod.evening: H*0.72, DayPeriod.night: H*0.2};
    final cx = sunX[period]!, cy = sunY[period]!;

    if (period == DayPeriod.night) {
      canvas.drawCircle(Offset(cx, cy), 24, Paint()..color = const Color(0xFFC8D0F0));
      final bgColor = _skyColors()[1];
      canvas.drawCircle(Offset(cx + 13, cy - 7), 18, Paint()..color = bgColor);
      for (final s in stars) {
        canvas.drawCircle(
          Offset(s.x * W, s.y * H),
          s.r,
          Paint()..color = Colors.white.withOpacity(s.op),
        );
      }
      return;
    }

    final sunColors = {DayPeriod.morning: const Color(0xFFFAC775), DayPeriod.afternoon: const Color(0xFFFFD740), DayPeriod.evening: const Color(0xFFFF6D00)};
    final innerColors = {DayPeriod.morning: const Color(0xFFFAEEDA), DayPeriod.afternoon: const Color(0xFFFFF9C4), DayPeriod.evening: const Color(0xFFFFAB76)};

    final glowPaint = Paint()..shader = RadialGradient(
      colors: [sunColors[period]!.withOpacity(0.25), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 44));
    canvas.drawCircle(Offset(cx, cy), 44, glowPaint);
    canvas.drawCircle(Offset(cx, cy), 26, Paint()..color = sunColors[period]!);
    canvas.drawCircle(Offset(cx, cy), 17, Paint()..color = innerColors[period]!);
  }

  // ── 봄 ──

  void _drawSpring(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final isNight = period == DayPeriod.night;
    final flowerColor = isNight ? const Color(0xFFDCA0BE).withOpacity(0.65) : const Color(0xFFFFB7D5).withOpacity(0.82);
    final trunkPaint = Paint()..color = const Color(0xFF8D6E63)..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    for (final spec in [(W * 0.14, H * 0.72, 1.0), (W * 0.72, H * 0.72, 0.78)]) {
      final tx = spec.$1, ty = spec.$2, sc = spec.$3;
      trunkPaint.strokeWidth = 5 * sc;
      canvas.drawLine(Offset(tx, ty), Offset(tx, ty - 72 * sc), trunkPaint);
      trunkPaint.strokeWidth = 3 * sc;
      canvas.drawLine(Offset(tx, ty - 38 * sc), Offset(tx - 32 * sc, ty - 72 * sc), trunkPaint);
      canvas.drawLine(Offset(tx, ty - 48 * sc), Offset(tx + 28 * sc, ty - 76 * sc), trunkPaint);
      for (final pos in [(0.0, -70.0), (18.0, -62.0), (-18.0, -65.0), (8.0, -82.0), (-10.0, -78.0), (20.0, -78.0), (-22.0, -55.0), (10.0, -55.0)]) {
        canvas.drawCircle(
          Offset(tx + pos.$1 * sc, ty + pos.$2 * sc),
          (16 + pos.$1.abs() * 0.3) * sc,
          Paint()..color = flowerColor,
        );
      }
    }
    // 꽃
    final stemP = Paint()..color = const Color(0xFF66BB6A)..strokeWidth = 2..style = PaintingStyle.stroke;
    final flowerColors = [const Color(0xFFF06292), const Color(0xFFFF8A65), const Color(0xFFFF80AB), const Color(0xFFCE93D8), const Color(0xFFFFD54F), const Color(0xFF4FC3F7), const Color(0xFFF48FB1)];
    for (int i = 0; i < 7; i++) {
      final fx = 55.0 + i * 75, fy = H * 0.72;
      canvas.drawLine(Offset(fx, fy), Offset(fx, fy - 26), stemP);
      final path = Path()..addOval(Rect.fromCenter(center: Offset(fx, fy - 32), width: 12, height: 22));
      canvas.drawPath(path, Paint()..color = flowerColors[i]);
    }
  }

  // ── 여름 ──

  void _drawSummer(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final isNight = period == DayPeriod.night;
    final wY = H * 0.62;
    canvas.drawRect(Rect.fromLTWH(0, wY, W, H - wY),
        Paint()..color = isNight ? const Color(0xFF0D47A1) : const Color(0xFF29B6F6));
    final wavePaint = Paint()..color = Colors.white.withOpacity(0.42)..style = PaintingStyle.stroke..strokeWidth = 1.8;
    for (int w = 0; w < 2; w++) {
      final path = Path()..moveTo(0, wY + w * 12);
      for (double x = 0; x <= W; x += 38) {
        path.quadraticBezierTo(x + 19, wY + w * 12 - 10, x + 38, wY + w * 12);
      }
      canvas.drawPath(path, wavePaint);
    }
    canvas.drawRect(Rect.fromLTWH(0, H * 0.65, W, H * 0.08),
        Paint()..color = isNight ? const Color(0xFFBFA880) : const Color(0xFFFFD54F));

    for (final spec in [(W * 0.28, H * 0.68, 0), (W * 0.72, H * 0.68, 1)]) {
      final px = spec.$1, py = spec.$2;
      canvas.drawLine(Offset(px, py + 8), Offset(px, py - 28),
          Paint()..color = const Color(0xFF795548)..strokeWidth = 3..style = PaintingStyle.stroke);
      final path = Path()..moveTo(px - 30, py - 22)..quadraticBezierTo(px, py - 42, px + 30, py - 22)..close();
      canvas.drawPath(path, Paint()..color = spec.$3 == 0 ? const Color(0xFFEF5350) : const Color(0xFF42A5F5));
    }
  }

  // ── 가을 ──

  void _drawAutumn(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final isNight = period == DayPeriod.night;
    canvas.drawRect(Rect.fromLTWH(0, H * 0.58, W, H * 0.14),
        Paint()..color = isNight ? const Color(0xFF6D4C00) : const Color(0xFFF9A825));
    final stalkP = Paint()..strokeWidth = 1.8..style = PaintingStyle.stroke..color = isNight ? const Color(0xFFF57F17) : const Color(0xFFE65100);
    for (int i = 0; i < 16; i++) {
      final sx = 22.0 + i * 36, sy = H * 0.58 + 4;
      canvas.drawLine(Offset(sx, sy + 26), Offset(sx, sy), stalkP);
      final path = Path()..addOval(Rect.fromCenter(center: Offset(sx, sy - 7), width: 7, height: 20));
      canvas.drawPath(path, Paint()..color = stalkP.color);
    }
    for (final pos in [(W * 0.18, H * 0.72), (W * 0.80, H * 0.72)]) {
      final tx = pos.$1, ty = pos.$2;
      final trunk = Paint()..color = const Color(0xFF5D4037)..strokeWidth = 6..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(tx, ty), Offset(tx, ty - 72), trunk);
      trunk.strokeWidth = 3;
      for (final b in [(-32.0, -52.0), (28.0, -58.0), (-18.0, -76.0), (24.0, -72.0)]) {
        canvas.drawLine(Offset(tx, ty - 36), Offset(tx + b.$1, ty + b.$2), trunk);
      }
      for (int ci = 0; ci < 4; ci++) {
        canvas.drawCircle(
          Offset(tx + (ci % 2 == 1 ? 14.0 : -11.0), ty - 68 + (ci > 1 ? -12.0 : 0.0)),
          19,
          Paint()..color = [const Color(0xCCE65100), const Color(0xCCFF6F00), const Color(0xCCFF8F00), const Color(0xCCBF360C)][ci],
        );
      }
    }
  }

  // ── 겨울 ──

  void _drawWinter(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final isNight = period == DayPeriod.night;
    canvas.drawRect(Rect.fromLTWH(0, H * 0.68, W, H * 0.05),
        Paint()..color = isNight ? const Color(0xFFB0BEC5) : const Color(0xFFECEFF1));

    // 눈사람
    final sx = W * 0.74, sy = H * 0.73;
    final bodyP = Paint()..color = Colors.white;
    final outP = Paint()..color = const Color(0xFF90A4AE)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset(sx, sy - 14), 20, bodyP);
    canvas.drawCircle(Offset(sx, sy - 14), 20, outP);
    canvas.drawCircle(Offset(sx, sy - 46), 13, bodyP);
    canvas.drawCircle(Offset(sx, sy - 46), 13, outP);
    canvas.drawCircle(Offset(sx - 4, sy - 49), 2, Paint()..color = const Color(0xFF455A64));
    canvas.drawCircle(Offset(sx + 4, sy - 49), 2, Paint()..color = const Color(0xFF455A64));
    final nosePath = Path()..moveTo(sx, sy - 46)..lineTo(sx + 7, sy - 44)..lineTo(sx, sy - 42)..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFFFF7043));
    for (final by in [sy - 20, sy - 12, sy - 5]) {
      canvas.drawCircle(Offset(sx, by), 2, Paint()..color = const Color(0xFF607D8B));
    }
    canvas.drawArc(Rect.fromCircle(center: Offset(sx, sy - 33), radius: 13),
        0.3, math.pi - 0.6, false,
        Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawRect(Rect.fromLTWH(sx - 12, sy - 60, 24, 4), Paint()..color = const Color(0xFF37474F));
    canvas.drawRect(Rect.fromLTWH(sx - 9, sy - 74, 18, 16), Paint()..color = const Color(0xFF37474F));
    final armP = Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(sx - 18, sy - 16), Offset(sx - 34, sy - 26), armP);
    canvas.drawLine(Offset(sx + 18, sy - 16), Offset(sx + 34, sy - 26), armP);

    // 전나무
    for (final spec in [(W * 0.13, H * 0.72, 1.0), (W * 0.30, H * 0.72, 0.72)]) {
      final tx = spec.$1, ty = spec.$2, sc = spec.$3;
      for (final t in [(0.0, -62.0, 22.0), (0.0, -43.0, 30.0), (0.0, -24.0, 38.0)]) {
        final path = Path()
          ..moveTo(tx + t.$1, ty + t.$2 * sc)
          ..lineTo(tx - t.$3 * sc, ty + (t.$2 + 18) * sc)
          ..lineTo(tx + t.$3 * sc, ty + (t.$2 + 18) * sc)
          ..close();
        canvas.drawPath(path, Paint()..color = isNight ? const Color(0xFF1B5E20) : const Color(0xFF2E7D32));
        final snowPath = Path()
          ..moveTo(tx + t.$1, ty + t.$2 * sc)
          ..lineTo(tx - t.$3 * 0.5 * sc, ty + (t.$2 + 6) * sc)
          ..lineTo(tx + t.$3 * 0.5 * sc, ty + (t.$2 + 6) * sc)
          ..close();
        canvas.drawPath(snowPath, Paint()..color = Colors.white.withOpacity(0.68));
      }
      canvas.drawRect(Rect.fromLTWH(tx - 3.5 * sc, ty, 7 * sc, 10 * sc), Paint()..color = const Color(0xFF5D4037));
    }
  }

  // ── 파티클 ──

  void _drawParticles(Canvas canvas, Size size) {
    final isNight = period == DayPeriod.night;
    for (final p in particles) {
      final px = p.x * size.width, py = p.y * size.height;
      canvas.save();
      if (season == Season.spring) {
        canvas.translate(px, py);
        canvas.rotate(p.rot * math.pi / 180);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: p.size * 2, height: p.size),
          Paint()..color = (isNight ? const Color(0xFFD4A0BB) : const Color(0xFFFFB7D5)).withOpacity(p.opacity),
        );
      } else if (season == Season.winter) {
        canvas.drawCircle(
          Offset(px, py), p.size,
          Paint()..color = Colors.white.withOpacity(isNight ? p.opacity * 0.7 : p.opacity),
        );
      }
      canvas.restore();
    }
  }

  // ── 오버레이 텍스트 (인사말 + 복약 알림) ──

  void _drawOverlayText(Canvas canvas, Size size) {
    final isNight = period == DayPeriod.night;
    final textColor = isNight ? const Color(0xFFC8D0FF) : const Color(0xFF3C2864);

    // 반투명 바텀 배경
    final bgPaint = Paint()..color = (isNight ? Colors.black : Colors.white).withOpacity(0.18);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      bgPaint,
    );

    // 인사말
    final greetTp = TextPainter(
      text: TextSpan(
        text: period.greeting,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 32);
    greetTp.paint(canvas, Offset(16, size.height * 0.74));

    // 복약 알림
    if (pendingCount > 0) {
      final medNames = pendingNames.join(', ') + (pendingCount > 2 ? ' 외 ${pendingCount - 2}종' : '');
      final alertBg = isNight
          ? const Color(0xFF7B6FD4).withOpacity(0.55)
          : const Color(0xFF7B6FD4).withOpacity(0.18);

      // 알림 배경 박스
      final boxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(12, size.height * 0.83, size.width - 24, 28),
        const Radius.circular(8),
      );
      canvas.drawRRect(boxRect, Paint()..color = alertBg);

      // 알림 텍스트
      final alertTp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '💊 ',
              style: TextStyle(fontSize: 11, color: textColor),
            ),
            TextSpan(
              text: '지금 복용할 약: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isNight ? const Color(0xFFD0C8FF) : const Color(0xFF4A3FA8),
              ),
            ),
            TextSpan(
              text: medNames,
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 32);
      alertTp.paint(canvas, Offset(20, size.height * 0.838));
    }
  }

  @override
  bool shouldRepaint(_SeasonPainter old) =>
      old.period != period ||
          old.season != season ||
          old.particles != particles ||
          old.pendingCount != pendingCount;
}

// ─── 복약 일정 행 ─────────────────────────────────────────────────────────────

class _ScheduleRow extends StatefulWidget {
  final _ScheduleItem item;
  final bool isLast;
  final VoidCallback? onChanged;
  const _ScheduleRow({required this.item, required this.isLast, this.onChanged});

  @override
  State<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<_ScheduleRow> {
  late bool _done;

  @override
  void initState() {
    super.initState();
    _done = widget.item.done;
  }

  String _mealLabel(String time) {
    final h = int.tryParse(time.split(':').first) ?? 9;
    if (h < 11) return '아침';
    if (h < 16) return '점심';
    return '저녁';
  }

  String _mealTiming(String detail) {
    if (detail.contains('식전')) return '식전';
    if (detail.contains('식후')) return '식후';
    return '예정';
  }

  String _fmtTime(String time) {
    final parts = time.split(':');
    return '${(parts.isNotEmpty ? parts[0] : '09').padLeft(2, '0')}:'
        '${(parts.length > 1 ? parts[1] : '00').padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final meal = _mealLabel(widget.item.time);
    final timing = _mealTiming(widget.item.detail);
    final timeText = _fmtTime(widget.item.time);
    final mealColor = switch (meal) {
      '아침' => const Color(0xFFEF9F27),
      '점심' => AppColors.lavender,
      _     => const Color(0xFF4A6FA5),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: mealColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: mealColor.withOpacity(0.28), width: 0.8),
                ),
                child: Column(children: [
                  Text(meal, style: TextStyle(fontSize: 12, color: mealColor, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(timeText, style: const TextStyle(fontSize: 9, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$meal $timing 복용',
                      style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              GestureDetector(
                onTap: () async {
                  final next = !_done;
                  setState(() => _done = next);
                  final id = widget.item.scheduleId;
                  if (id != null) {
                    await ScheduleService.setTaken(scheduleId: id, isTaken: next);
                    widget.onChanged?.call();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _done ? AppColors.lavender : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _done ? AppColors.lavender : AppColors.lavenderBorder,
                      width: 1.5,
                    ),
                  ),
                  child: _done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isLast)
          const Divider(height: 0.5, color: AppColors.cardBorder, indent: 14, endIndent: 14),
      ],
    );
  }
}
