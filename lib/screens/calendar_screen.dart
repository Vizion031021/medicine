import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Map<DateTime, List<MedicationLog>> _logs = DummyData.sampleLogs;
  final TextEditingController _memoController = TextEditingController();
  bool _showMemoInput = false;

  // 약봉투 색상 설정 (봉투별 색상 선택)
  final Map<String, Color> _bagColors = {
    'bag1': const Color(0xFF7B6FD4),
    'bag2': const Color(0xFF4A9EE8),
  };

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  List<MedicationLog> _getLogsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _logs[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── 캘린더 + 범례 ──
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildCalendar(),
                  _buildLegend(),
                ],
              ),
            ),
            const Divider(height: 0.5, color: AppColors.lavenderBg),
            // ── 선택된 날짜 기록 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                children: [
                  _buildSelectedDayHeader(),
                  const SizedBox(height: 8),
                  ..._buildLogCards(),
                  const SizedBox(height: 8),
                  _buildMemoButton(),
                  if (_showMemoInput) _buildMemoInput(),
                  const SizedBox(height: 10),
                  _buildColorSettings(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TableCalendar ──

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2027, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _showMemoInput = false;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
      calendarFormat: CalendarFormat.month,
      eventLoader: _getLogsForDay,
      calendarStyle: CalendarStyle(
        // 오늘 날짜
        todayDecoration: const BoxDecoration(
          color: AppColors.lavender,
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        // 선택된 날짜
        selectedDecoration: BoxDecoration(
          color: AppColors.lavender.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 1.5),
        ),
        selectedTextStyle: const TextStyle(
          color: AppColors.lavenderDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        // 기본 날짜
        defaultTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        weekendTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.danger,
        ),
        outsideDaysVisible: false,
        // 마커는 calendarBuilders로 커스텀
        markersMaxCount: 3,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: AppColors.textHint,
          size: 22,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: AppColors.textHint,
          size: 22,
        ),
        headerPadding: EdgeInsets.symmetric(vertical: 10),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11,
          color: AppColors.textHint,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          fontSize: 11,
          color: AppColors.danger,
          fontWeight: FontWeight.w500,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        // 커스텀 마커 (약봉투별 컬러 점)
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return const SizedBox();
          final logs = events.cast<MedicationLog>();

          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: logs.take(3).map((log) {
                final isMissed = !log.taken;
                final color = isMissed
                    ? AppColors.danger
                    : (log.bagName == '아침약 봉투'
                        ? _bagColors['bag1']!
                        : _bagColors['bag2']!);
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // ── 범례 ──

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        children: [
          _LegendDot(
            color: _bagColors['bag1']!,
            label: '아침약 봉투',
          ),
          const SizedBox(width: 14),
          _LegendDot(
            color: _bagColors['bag2']!,
            label: '저녁약 봉투',
          ),
          const SizedBox(width: 14),
          const _LegendDot(
            color: AppColors.danger,
            label: '미복용',
          ),
        ],
      ),
    );
  }

  // ── 선택된 날짜 헤더 ──

  Widget _buildSelectedDayHeader() {
    final month = _selectedDay.month;
    final day = _selectedDay.day;
    return Text(
      '$month월 ${day}일 기록',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── 복약 기록 카드들 ──

  List<Widget> _buildLogCards() {
    final logs = _getLogsForDay(_selectedDay);
    if (logs.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: const Center(
            child: Text(
              '이 날의 복약 기록이 없습니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
      ];
    }

    return logs.map((log) {
      final bagColor = log.bagName == '아침약 봉투'
          ? _bagColors['bag1']!
          : _bagColors['bag2']!;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: bagColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log.bagName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // 복용 상태
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: log.taken
                        ? AppColors.successBg
                        : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.taken
                        ? (log.takenAt != null
                            ? '${log.takenAt!.hour.toString().padLeft(2, '0')}:${log.takenAt!.minute.toString().padLeft(2, '0')} 완료'
                            : '완료')
                        : '미복용',
                    style: TextStyle(
                      fontSize: 10,
                      color: log.taken
                          ? const Color(0xFF2E7D32)
                          : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 약물 칩
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: log.medicineNames.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: log.taken
                        ? AppColors.successBg
                        : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      color: log.taken
                          ? const Color(0xFF2E7D32)
                          : AppColors.danger,
                    ),
                  ),
                );
              }).toList(),
            ),
            // 메모
            if (log.memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lavenderBg,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: AppColors.lavender, width: 2),
                  ),
                ),
                child: Text(
                  log.memo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.lavenderDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  // ── 메모 추가 버튼 ──

  Widget _buildMemoButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showMemoInput = !_showMemoInput),
      icon: const Icon(Icons.edit_outlined,
          size: 14, color: AppColors.lavender),
      label: const Text(
        '롱탭 또는 탭으로 날짜별 메모 추가',
        style: TextStyle(color: AppColors.lavender, fontSize: 11),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // ── 메모 입력 폼 ──

  Widget _buildMemoInput() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_outlined,
                  size: 13, color: AppColors.lavender),
              const SizedBox(width: 5),
              Text(
                '${_selectedDay.month}월 ${_selectedDay.day}일 메모',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '오늘의 복약 메모를 입력하세요...',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 메모 저장 로직
                    setState(() => _showMemoInput = false);
                    _memoController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('메모가 저장되었습니다.'),
                        backgroundColor: AppColors.lavender,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _showMemoInput = false;
                    _memoController.clear();
                  }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 약봉투 색깔 설정 ──

  Widget _buildColorSettings() {
    final bagNames = {'bag1': '아침약 봉투', 'bag2': '저녁약 봉투'};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_outlined,
                  size: 14, color: AppColors.lavender),
              SizedBox(width: 5),
              Text(
                '약봉투 색깔 설정',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bagNames.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    children: AppColors.bagColors.map((color) {
                      final isSelected = _bagColors[entry.key] == color;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _bagColors[entry.key] = color,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white,
                                    width: 2,
                                    strokeAlign:
                                        BorderSide.strokeAlignOutside,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ─── 범례 점 ─────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
