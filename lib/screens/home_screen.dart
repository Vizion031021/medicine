import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/screens/auth/login_screen.dart';

// 시간대 구분
enum DayPeriod { morning, afternoon, evening, night }

extension DayPeriodExt on DayPeriod {
  String get label {
    switch (this) {
      case DayPeriod.morning:
        return '아침';
      case DayPeriod.afternoon:
        return '오후';
      case DayPeriod.evening:
        return '저녁';
      case DayPeriod.night:
        return '밤';
    }
  }

  String get greeting {
    switch (this) {
      case DayPeriod.morning:
        return '좋은 아침이에요 ☀';
      case DayPeriod.afternoon:
        return '좋은 오후예요 — 점심약 드셨나요?';
      case DayPeriod.evening:
        return '좋은 저녁이에요 — 저녁약 챙기세요';
      case DayPeriod.night:
        return '편안한 밤이에요 — 취침 전 약 드셨나요?';
    }
  }

  Color get skyColor {
    switch (this) {
      case DayPeriod.morning:
        return const Color(0xFFEDE9FF);
      case DayPeriod.afternoon:
        return const Color(0xFFE8E4F8);
      case DayPeriod.evening:
        return const Color(0xFFE0D8F5);
      case DayPeriod.night:
        return const Color(0xFF2D285A);
    }
  }

  Color get groundColor {
    switch (this) {
      case DayPeriod.morning:
        return const Color(0xFFDDD8F5);
      case DayPeriod.afternoon:
        return const Color(0xFFCBC4ED);
      case DayPeriod.evening:
        return const Color(0xFFB8AEE0);
      case DayPeriod.night:
        return const Color(0xFF1E1A45);
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
  DayPeriod _period = DayPeriod.morning;
  String _nickname = '사용자';
  List<_ScheduleItem> _todaySchedules = [];

  @override
  void initState() {
    super.initState();
    _period = _detectCurrentPeriod();
    _loadNickname();
    _loadTodaySchedules();
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService.getNickname();
    if (mounted) setState(() => _nickname = nickname);
  }

  Future<void> _loadTodaySchedules() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final schedules = await ScheduleService.fetchSchedules(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _todaySchedules = List.generate(schedules.length, (index) {
          final schedule = schedules[index];
          return _ScheduleItem(
            scheduleId: schedule.id,
            num: index + 1,
            name: schedule.medication?.displayName ?? '등록 약',
            time: schedule.time,
            detail: schedule.medication?.instruction.isNotEmpty == true
                ? schedule.medication!.instruction
                : '복용 예정',
            done: schedule.isTaken,
          );
        });
      });
    } catch (_) {
      // 홈은 발표 안정성을 위해 조회 실패 시 빈 상태를 유지한다.
    }
  }

  DayPeriod _detectCurrentPeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return DayPeriod.morning;
    if (hour >= 12 && hour < 17) return DayPeriod.afternoon;
    if (hour >= 17 && hour < 21) return DayPeriod.evening;
    return DayPeriod.night;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildTodaySchedule(),
              const SizedBox(height: 6),
              Container(height: 6, color: AppColors.lavenderBg),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── 계절/시간 일러스트 헤더 ──

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 일러스트 영역
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: _SeasonPainter(_period),
            ),
          ),
          // 인사말 + 시간 선택
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안녕하세요',
                  style: TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 로그아웃 버튼
                    GestureDetector(
                      onTap: () async {
                        await AuthService.logout();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Icon(
                        Icons.logout,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 시간대 선택 칩
                Row(
                  children: DayPeriod.values.map((period) {
                    final isSelected = _period == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _period = period),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.lavender
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.lavender
                                  : AppColors.lavenderBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            period.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.lavenderDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, color: AppColors.lavenderBg),
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
                      child: Text(
                        '오늘 예정된 복용 일정이 없습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
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

// ─── 복약 일정 행 ───────────────────────────────────────────────────────────

class _ScheduleRow extends StatefulWidget {
  final _ScheduleItem item;
  final bool isLast;
  final VoidCallback? onChanged;

  const _ScheduleRow({
    required this.item,
    required this.isLast,
    this.onChanged,
  });

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

  @override
  Widget build(BuildContext context) {
    final mealLabel = _mealLabelFromTime(widget.item.time);
    final mealTiming = _mealTimingFromDetail(widget.item.detail);
    final timeText = _formatTime(widget.item.time);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _MealBadge(label: mealLabel, time: timeText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '$mealLabel $mealTiming 복용',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 체크 버튼
              GestureDetector(
                onTap: () async {
                  final next = !_done;
                  setState(() => _done = next);
                  final scheduleId = widget.item.scheduleId;
                  if (scheduleId != null) {
                    await ScheduleService.setTaken(
                      scheduleId: scheduleId,
                      isTaken: next,
                    );
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
                      color: _done
                          ? AppColors.lavender
                          : AppColors.lavenderBorder,
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
          const Divider(
            height: 0.5,
            color: AppColors.divider,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }

  String _mealLabelFromTime(String time) {
    final hour = int.tryParse(time.split(':').first) ?? 9;
    if (hour < 11) return '아침';
    if (hour < 16) return '점심';
    return '저녁';
  }

  String _mealTimingFromDetail(String detail) {
    if (detail.contains('식전')) return '식전';
    if (detail.contains('식후')) return '식후';
    return '예정';
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? parts[0].padLeft(2, '0') : '09';
    final minute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    return '$hour:$minute';
  }
}

class _MealBadge extends StatelessWidget {
  final String label;
  final String time;

  const _MealBadge({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      '아침' => const Color(0xFFEF9F27),
      '점심' => AppColors.lavender,
      _ => const Color(0xFF4A6FA5),
    };

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.28), width: 0.8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            time,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 계절 일러스트 CustomPainter ─────────────────────────────────────────────

class _SeasonPainter extends CustomPainter {
  final DayPeriod period;
  _SeasonPainter(this.period);

  @override
  void paint(Canvas canvas, Size size) {
    // 하늘 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = period.skyColor,
    );

    // 땅
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      Paint()..color = period.groundColor,
    );

    switch (period) {
      case DayPeriod.morning:
      case DayPeriod.afternoon:
        _drawSun(canvas, size);
        _drawClouds(canvas, size);
        break;
      case DayPeriod.evening:
        _drawSettingSun(canvas, size);
        _drawClouds(canvas, size, alpha: 100);
        break;
      case DayPeriod.night:
        _drawMoon(canvas, size);
        _drawStars(canvas, size);
        break;
    }

    // 인사 텍스트
    _drawText(canvas, size);
  }

  void _drawSun(Canvas canvas, Size size) {
    final cx = size.width * 0.81;
    final cy = period == DayPeriod.afternoon ? size.height * 0.22 : size.height * 0.58;
    canvas.drawCircle(
      Offset(cx, cy),
      28,
      Paint()..color = const Color(0xFFFAC775),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      20,
      Paint()..color = const Color(0xFFFAEEDA),
    );
  }

  void _drawSettingSun(Canvas canvas, Size size) {
    final sunPaint = Paint()..color = const Color(0xFFEF9F27).withOpacity(0.45);
    canvas.drawCircle(Offset(44, size.height * 0.82), 32, sunPaint);
    final sun2Paint = Paint()..color = const Color(0xFFFAC775).withOpacity(0.5);
    canvas.drawCircle(Offset(44, size.height * 0.82), 22, sun2Paint);
  }

  void _drawClouds(Canvas canvas, Size size, {int alpha = 190}) {
    final cloudPaint = Paint()..color = Colors.white.withAlpha(alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, size.height * 0.48, 60, 16),
        const Radius.circular(8),
      ),
      cloudPaint,
    );
    final cloud2Paint = Paint()..color = Colors.white.withAlpha(alpha - 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(110, size.height * 0.36, 46, 14),
        const Radius.circular(7),
      ),
      cloud2Paint,
    );
  }

  void _drawMoon(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.28),
      18,
      Paint()..color = const Color(0xFFC4BCE8),
    );
    // 달의 어두운 부분 (초승달 효과)
    canvas.drawCircle(
      Offset(size.width * 0.84 + 10, size.height * 0.22),
      14,
      Paint()..color = const Color(0xFF2D285A),
    );
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withOpacity(0.75);
    final positions = [
      Offset(size.width * 0.09, size.height * 0.2),
      Offset(size.width * 0.25, size.height * 0.12),
      Offset(size.width * 0.47, size.height * 0.18),
      Offset(size.width * 0.63, size.height * 0.09),
      Offset(size.width * 0.19, size.height * 0.36),
      Offset(size.width * 0.34, size.height * 0.30),
    ];
    for (final pos in positions) {
      canvas.drawCircle(pos, 1.5, starPaint);
    }
  }

  void _drawText(Canvas canvas, Size size) {
    final textPainter = TextPainter(
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
    textPainter.layout(maxWidth: size.width - 32);
    textPainter.paint(
      canvas,
      Offset(16, size.height - textPainter.height - 10),
    );
  }

  @override
  bool shouldRepaint(_SeasonPainter oldDelegate) =>
      oldDelegate.period != period;
}
