import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final TextEditingController _memoController = TextEditingController();
  final Map<DateTime, List<UserSchedule>> _schedulesByDay = {};
  final Map<DateTime, List<String>> _memosByDay = {};
  bool _isLoading = true;
  bool _showMemoInput = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final from = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final to = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);

    try {
      final schedules = await ScheduleService.fetchSchedules(from: from, to: to);
      final memos = await CalendarMemoService.fetchMemos(from: from, to: to);

      final nextSchedules = <DateTime, List<UserSchedule>>{};
      for (final schedule in schedules) {
        final key = _dayKey(schedule.date);
        nextSchedules.putIfAbsent(key, () => []).add(schedule);
      }

      final nextMemos = <DateTime, List<String>>{};
      for (final memo in memos) {
        final date = DateTime.tryParse((memo['memo_date'] ?? '').toString());
        final content = (memo['content'] ?? '').toString();
        if (date == null || content.isEmpty) continue;
        nextMemos.putIfAbsent(_dayKey(date), () => []).add(content);
      }

      if (!mounted) return;
      setState(() {
        _schedulesByDay
          ..clear()
          ..addAll(nextSchedules);
        _memosByDay
          ..clear()
          ..addAll(nextMemos);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '캘린더 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserSchedule> _getSchedulesForDay(DateTime day) {
    return _schedulesByDay[_dayKey(day)] ?? [];
  }

  List<String> _getMemosForDay(DateTime day) {
    return _memosByDay[_dayKey(day)] ?? [];
  }

  DateTime _dayKey(DateTime day) => DateTime(day.year, day.month, day.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      body: SafeArea(
        child: Column(
          children: [
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMonth,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                            children: [
                              _buildSelectedDayHeader(),
                              const SizedBox(height: 8),
                              ..._buildScheduleCards(),
                              ..._buildMemoCards(),
                              const SizedBox(height: 8),
                              _buildMemoButton(),
                              if (_showMemoInput) _buildMemoInput(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar<UserSchedule>(
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
        _focusedDay = focusedDay;
        _loadMonth();
      },
      eventLoader: _getSchedulesForDay,
      calendarFormat: CalendarFormat.month,
      calendarStyle: CalendarStyle(
        todayDecoration: const BoxDecoration(
          color: AppColors.lavender,
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
        defaultTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        weekendTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.danger,
        ),
        outsideDaysVisible: false,
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
      calendarBuilders: CalendarBuilders<UserSchedule>(
        markerBuilder: (context, day, events) {
          final hasMemo = _getMemosForDay(day).isNotEmpty;
          if (events.isEmpty && !hasMemo) return const SizedBox();

          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...events.take(3).map((schedule) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: schedule.isTaken
                          ? AppColors.success
                          : AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
                if (hasMemo)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: AppColors.lavender,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        children: [
          _LegendDot(color: AppColors.success, label: '복용 완료'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.danger, label: '미복용'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.lavender, label: '메모'),
        ],
      ),
    );
  }

  Widget _buildSelectedDayHeader() {
    final month = _selectedDay.month;
    final day = _selectedDay.day;
    final schedules = _getSchedulesForDay(_selectedDay);
    final done = schedules.where((item) => item.isTaken).length;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$month월 ${day}일 복용 일정',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${done}/${schedules.length} 완료',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lavenderDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildScheduleCards() {
    final schedules = _getSchedulesForDay(_selectedDay);
    if (schedules.isEmpty) {
      return [
        _EmptyCard(
          text: '이 날의 복약 일정이 없습니다.',
        ),
      ];
    }

    return schedules.map((schedule) {
      final medication = schedule.medication;
      final drug = medication?.drug;
      final name = medication?.displayName ?? '등록 약';
      final subtitle = [
        schedule.time,
        if (drug?.company.isNotEmpty == true) drug!.company,
      ].join(' · ');

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: schedule.isTaken ? AppColors.success : AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (medication?.instruction.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      medication!.instruction,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.lavenderDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _toggleTaken(schedule),
              child: Text(schedule.isTaken ? '취소' : '복용'),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildMemoCards() {
    final memos = _getMemosForDay(_selectedDay);
    if (memos.isEmpty) return [];

    return memos.map((memo) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lavenderBg,
          borderRadius: BorderRadius.circular(10),
          border: const Border(
            left: BorderSide(color: AppColors.lavender, width: 2),
          ),
        ),
        child: Text(
          memo,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lavenderDark,
            height: 1.5,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMemoButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showMemoInput = !_showMemoInput),
      icon: const Icon(
        Icons.edit_outlined,
        size: 14,
        color: AppColors.lavender,
      ),
      label: const Text(
        '날짜별 메모 추가',
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
          Text(
            '${_selectedDay.month}월 ${_selectedDay.day}일 메모',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '처방 사유, 특이사항, 복용 실수 등을 기록하세요.',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveMemo,
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

  Future<void> _toggleTaken(UserSchedule schedule) async {
    await ScheduleService.setTaken(
      scheduleId: schedule.id,
      isTaken: !schedule.isTaken,
    );
    await _loadMonth();
  }

  Future<void> _saveMemo() async {
    final content = _memoController.text.trim();
    if (content.isEmpty) return;

    try {
      await CalendarMemoService.saveMemo(
        date: _selectedDay,
        content: content,
      );
      _memoController.clear();
      setState(() => _showMemoInput = false);
      await _loadMonth();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모 저장 실패: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ),
    );
  }
}

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
