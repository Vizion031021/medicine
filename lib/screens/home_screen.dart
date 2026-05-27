import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/screens/auth/login_screen.dart';

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
      case DayPeriod.morning:   return '좋은 아침이에요 ☀';
      case DayPeriod.afternoon: return '좋은 오후예요 — 점심약 드셨나요?';
      case DayPeriod.evening:   return '좋은 저녁이에요 — 저녁약 챙기세요';
      case DayPeriod.night:     return '편안한 밤이에요 — 취침 전 약 드셨나요?';
    }
  }

  Color get skyTop {
    switch (this) {
      case DayPeriod.morning:   return const Color(0xFFEDE9FF);
      case DayPeriod.afternoon: return const Color(0xFFE8E4F8);
      case DayPeriod.evening:   return const Color(0xFFE0D8F5);
      case DayPeriod.night:     return const Color(0xFF2D285A);
    }
  }

  Color get skyBottom {
    switch (this) {
      case DayPeriod.morning:   return const Color(0xFFDDD8F5);
      case DayPeriod.afternoon: return const Color(0xFFCBC4ED);
      case DayPeriod.evening:   return const Color(0xFFB8AEE0);
      case DayPeriod.night:     return const Color(0xFF1E1A45);
    }
  }
}

class _ScheduleItem {
  final String? scheduleId;
  final int num;
  final String name;
  final String time;
  final String detail;
  final bool done;
  const _ScheduleItem({
    this.scheduleId,
    required this.num,
    required this.name,
    required this.time,
    required this.detail,
    required this.done,
  });
}

// ─── 홈 화면 ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ② 수동 버튼 없음 — 자동 감지
  DayPeriod _period = DayPeriod.morning;
  Timer? _periodTimer;
  String _nickname = '사용자';
  List<_ScheduleItem> _todaySchedules = [];

  @override
  void initState() {
    super.initState();
    _period = _detectPeriod();
    _loadNickname();
    _loadTodaySchedules();
    // 1분마다 시간대 자동 갱신
    _periodTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final p = _detectPeriod();
      if (p != _period && mounted) setState(() => _period = p);
    });
  }

  @override
  void dispose() {
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
                ? s.medication!.instruction
                : '복용 예정',
            done: s.isTaken,
          );
        });
      });
    } catch (_) {}
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

  // ── 헤더: 시간대 일러스트 + 인사말 (자동 감지, 수동 버튼 없음) ──

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(painter: _SeasonPainter(_period)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_nickname님 ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const TextSpan(
                            text: '오늘도 건강하게!',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    // ② 시간대 자동 표시 (읽기 전용 뱃지)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
                      ),
                      child: Text(
                        _period.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lavenderDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 로그아웃 버튼
                GestureDetector(
                  onTap: () async {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
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
              const Text(
                '오늘의 복약 일정',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$doneCount / ${_todaySchedules.length} 복용',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.lavenderDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
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

// ─── 복약 일정 행 ────────────────────────────────────────────────────────────

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
    final meal  = _mealLabel(widget.item.time);
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
              // 시간 뱃지
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: mealColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: mealColor.withOpacity(0.28), width: 0.8),
                ),
                child: Column(
                  children: [
                    Text(meal, style: TextStyle(fontSize: 12, color: mealColor, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(timeText, style: const TextStyle(fontSize: 9, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('$meal $timing 복용',
                        style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // 체크 버튼
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
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _done ? AppColors.lavender : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _done ? AppColors.lavender : AppColors.lavenderBorder,
                      width: 1.5,
                    ),
                  ),
                  child: _done
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
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

// ─── 계절 일러스트 CustomPainter ─────────────────────────────────────────────

class _SeasonPainter extends CustomPainter {
  final DayPeriod period;
  _SeasonPainter(this.period);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = period.skyTop);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
        Paint()..color = period.skyBottom);

    switch (period) {
      case DayPeriod.morning:
      case DayPeriod.afternoon:
        _drawSun(canvas, size);
        _drawClouds(canvas, size);
      case DayPeriod.evening:
        _drawSettingSun(canvas, size);
        _drawClouds(canvas, size, alpha: 100);
      case DayPeriod.night:
        _drawMoon(canvas, size);
        _drawStars(canvas, size);
    }
    _drawText(canvas, size);
  }

  void _drawSun(Canvas canvas, Size size) {
    final cy = period == DayPeriod.afternoon ? size.height * 0.22 : size.height * 0.58;
    canvas.drawCircle(Offset(size.width * 0.81, cy), 28, Paint()..color = const Color(0xFFFAC775));
    canvas.drawCircle(Offset(size.width * 0.81, cy), 20, Paint()..color = const Color(0xFFFAEEDA));
  }

  void _drawSettingSun(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(44, size.height * 0.82), 32,
        Paint()..color = const Color(0xFFEF9F27).withOpacity(0.45));
    canvas.drawCircle(Offset(44, size.height * 0.82), 22,
        Paint()..color = const Color(0xFFFAC775).withOpacity(0.5));
  }

  void _drawClouds(Canvas canvas, Size size, {int alpha = 190}) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(14, size.height * 0.48, 60, 16), const Radius.circular(8)),
        Paint()..color = Colors.white.withAlpha(alpha));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(110, size.height * 0.36, 46, 14), const Radius.circular(7)),
        Paint()..color = Colors.white.withAlpha(alpha - 30));
  }

  void _drawMoon(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.28), 18,
        Paint()..color = const Color(0xFFC4BCE8));
    canvas.drawCircle(Offset(size.width * 0.84 + 10, size.height * 0.22), 14,
        Paint()..color = const Color(0xFF2D285A));
  }

  void _drawStars(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.75);
    for (final pos in [
      Offset(size.width * 0.09, size.height * 0.2),
      Offset(size.width * 0.25, size.height * 0.12),
      Offset(size.width * 0.47, size.height * 0.18),
      Offset(size.width * 0.63, size.height * 0.09),
      Offset(size.width * 0.19, size.height * 0.36),
      Offset(size.width * 0.34, size.height * 0.30),
    ]) {
      canvas.drawCircle(pos, 1.5, p);
    }
  }

  void _drawText(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: period.greeting,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: period == DayPeriod.night
              ? const Color(0xFFC4BCE8)
              : AppColors.lavenderDark,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width - 32);
    tp.paint(canvas, Offset(16, size.height - tp.height - 10));
  }

  @override
  bool shouldRepaint(_SeasonPainter old) => old.period != period;
}
