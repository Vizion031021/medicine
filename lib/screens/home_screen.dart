import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';
import 'package:sseudeuson/widgets/interaction_badge.dart';
import 'package:sseudeuson/services/auth_service.dart';
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

// 더미 오늘의 복약 일정
const _todaySchedule = [
  _ScheduleItem(num: 1, name: '타이레놀정 500mg', time: '오전 8:00', detail: '아침 식후', done: true),
  _ScheduleItem(num: 2, name: '메트포르민 500mg', time: '오전 8:00', detail: '아침 식후 30분', done: true),
  _ScheduleItem(num: 3, name: '글리메피리드 2mg', time: '오후 1:00', detail: '점심 식전 15분', done: false),
  _ScheduleItem(num: 4, name: '암로디핀 5mg', time: '오후 7:00', detail: '저녁 식후', done: false),
];

class _ScheduleItem {
  final int num;
  final String name;
  final String time;
  final String detail;
  final bool done;
  const _ScheduleItem({
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

  @override
  void initState() {
    super.initState();
    _period = _detectCurrentPeriod();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService.getNickname();
    if (mounted) setState(() => _nickname = nickname);
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
              const SizedBox(height: 10),
              _buildRecentInteractions(),
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
    final doneCount = _todaySchedule.where((s) => s.done).length;
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
                '$doneCount / ${_todaySchedule.length} 복용',
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
            child: Column(
              children: List.generate(_todaySchedule.length, (i) {
                return _ScheduleRow(
                  item: _todaySchedule[i],
                  isLast: i == _todaySchedule.length - 1,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── 최근 상호작용 ──

  Widget _buildRecentInteractions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 확인한 상호작용',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              children: [
                _InteractionRow(
                  drug1: '메트포르민',
                  drug2: '글리메피리드',
                  severity: InteractionSeverity.warning,
                  isLast: false,
                ),
                _InteractionRow(
                  drug1: '암로디핀',
                  drug2: '에날라프릴',
                  severity: InteractionSeverity.safe,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 경고 배너
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '저혈당 위험   메트포르민 + 글리메피리드 병용 시 주의. 식사와 함께 복용하고 혈당을 모니터링하세요.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFC62828),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
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
  const _ScheduleRow({required this.item, required this.isLast});

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // 번호 원
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.lavenderBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.item.num}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lavenderDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 약 정보
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
                        Text(
                          '${widget.item.time} · ${widget.item.detail}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 체크 버튼
              GestureDetector(
                onTap: () => setState(() => _done = !_done),
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
}

// ─── 상호작용 행 ─────────────────────────────────────────────────────────────

class _InteractionRow extends StatelessWidget {
  final String drug1;
  final String drug2;
  final InteractionSeverity severity;
  final bool isLast;

  const _InteractionRow({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              InteractionBadge(severity: severity),
              const SizedBox(width: 8),
              _DrugChip(label: drug1),
              const SizedBox(width: 5),
              Text(
                severity == InteractionSeverity.safe ? '+' : '✕',
                style: TextStyle(
                  color: severity == InteractionSeverity.safe
                      ? AppColors.success
                      : AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 5),
              _DrugChip(label: drug2),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 0.5,
            color: AppColors.divider,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

class _DrugChip extends StatelessWidget {
  final String label;
  const _DrugChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.lavenderDark),
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
