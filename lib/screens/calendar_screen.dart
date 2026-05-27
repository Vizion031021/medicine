import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/services/bag_service.dart';
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

  DateTime? _filterStart;
  DateTime? _filterEnd;
  bool _isFilterActive = false;

  final Map<DateTime, List<UserSchedule>> _schedulesByDay = {};
  final Map<DateTime, List<String>> _memosByDay = {};

  List<BagData> _bags = [];
  List<String> _bagOrder = [];

  bool _isLoading = true;
  bool _showMemoInput = false;
  bool _showOrderPanel = false;
  String? _errorMessage;
  final TextEditingController _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBags();
    _loadMonth();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadBags() async {
    final bags = await BagService.getBags();
    if (mounted) {
      setState(() {
        _bags = bags;
        if (_bagOrder.isEmpty) _bagOrder = bags.map((b) => b.id).toList();
      });
    }
  }

  Future<void> _loadMonth() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final DateTime from;
    final DateTime to;
    if (_isFilterActive && _filterStart != null && _filterEnd != null) {
      from = _filterStart!;
      to = DateTime(_filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59);
    } else {
      from = DateTime(_focusedDay.year, _focusedDay.month, 1);
      to = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
    }

    try {
      final schedules = await ScheduleService.fetchSchedules(from: from, to: to);
      final memos = await CalendarMemoService.fetchMemos(from: from, to: to);

      final ns = <DateTime, List<UserSchedule>>{};
      for (final s in schedules) ns.putIfAbsent(_dayKey(s.date), () => []).add(s);

      final nm = <DateTime, List<String>>{};
      for (final m in memos) {
        final date = DateTime.tryParse((m['memo_date'] ?? '').toString());
        final content = (m['content'] ?? '').toString();
        if (date == null || content.isEmpty) continue;
        nm.putIfAbsent(_dayKey(date), () => []).add(content);
      }

      if (!mounted) return;
      setState(() {
        _schedulesByDay..clear()..addAll(ns);
        _memosByDay..clear()..addAll(nm);
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '캘린더 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserSchedule> _schedulesFor(DateTime day) => _schedulesByDay[_dayKey(day)] ?? [];
  List<String> _memosFor(DateTime day) => _memosByDay[_dayKey(day)] ?? [];
  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtDate(DateTime? d) {
    if (d == null) return '날짜 선택';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  String _dowLabel(DateTime d) => const ['일', '월', '화', '수', '목', '금', '토'][d.weekday % 7];

  Future<void> _pickFilterStart() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _filterStart ?? DateTime.now(),
      firstDate: DateTime(2023), lastDate: DateTime(2028),
    );
    if (p == null) return;
    setState(() {
      _filterStart = DateTime(p.year, p.month, p.day);
      if (_filterEnd != null && _filterEnd!.isBefore(_filterStart!)) _filterEnd = _filterStart;
      _focusedDay = _filterStart!;
    });
  }

  Future<void> _pickFilterEnd() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _filterEnd ?? (_filterStart ?? DateTime.now()),
      firstDate: _filterStart ?? DateTime(2023), lastDate: DateTime(2028),
    );
    if (p == null) return;
    setState(() => _filterEnd = DateTime(p.year, p.month, p.day));
  }

  void _applyFilter() {
    if (_filterStart == null || _filterEnd == null) return;
    // 기간 첫 날을 selectedDay로 설정
    _selectedDay = _filterStart!;
    setState(() => _isFilterActive = true);
    _loadMonth();
  }

  void _clearFilter() {
    setState(() {
      _isFilterActive = false;
      _filterStart = null;
      _filterEnd = null;
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
    _loadMonth();
  }

  // ─── 빌드 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // 필터 활성화 → 날짜 스트립 / 비활성화 → 전체 달력
            if (_isFilterActive)
              _buildFilteredDateStrip()
            else ...[
              Container(
                color: Colors.white,
                child: Column(children: [_buildCalendar(), _buildLegend()]),
              ),
            ],
            const Divider(height: 0.5, color: AppColors.cardBorder),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Text(_errorMessage!, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger))))
                  : RefreshIndicator(
                onRefresh: _loadMonth,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                  children: [
                    _buildDayHeader(),
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

  // ─── 헤더 ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Text('복약 캘린더',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (_bags.length > 1)
                IconButton(
                  icon: const Icon(Icons.sort, size: 18, color: AppColors.lavender),
                  tooltip: '약봉투 순서',
                  onPressed: () => setState(() => _showOrderPanel = !_showOrderPanel),
                ),
              IconButton(
                icon: Icon(
                  _isFilterActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: _isFilterActive ? AppColors.lavender : AppColors.textHint,
                ),
                tooltip: _isFilterActive ? '필터 해제' : '기간 설정',
                onPressed: () => _isFilterActive ? _clearFilter() : _showFilterSheet(),
              ),
            ],
          ),
          // 활성 필터 배지
          if (_isFilterActive && _filterStart != null && _filterEnd != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lavenderBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 13, color: AppColors.lavender),
                  const SizedBox(width: 6),
                  Text('${_fmtDate(_filterStart)}  ~  ${_fmtDate(_filterEnd)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearFilter,
                    child: const Icon(Icons.close, size: 14, color: AppColors.lavenderDark),
                  ),
                ],
              ),
            ),
          if (_showOrderPanel && _bags.length > 1) _buildOrderPanel(),
        ],
      ),
    );
  }

  // ─── 필터된 날짜 스트립 ───────────────────────────────────────────────────
  // 달력 대신 필터 기간의 날짜들만 가로 스크롤로 표시

  Widget _buildFilteredDateStrip() {
    if (_filterStart == null || _filterEnd == null) return const SizedBox();

    // 기간 내 날짜 목록 생성
    final days = <DateTime>[];
    var cur = _filterStart!;
    while (!cur.isAfter(_filterEnd!)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }

    // 선택된 날의 스크롤 위치로 자동 이동
    final selectedIdx = days.indexWhere((d) => isSameDay(d, _selectedDay));
    final scrollCtrl = ScrollController(
      initialScrollOffset: selectedIdx > 0 ? (selectedIdx * 62.0).clamp(0, double.infinity) : 0,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월/년 표시 (스트립 상단)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${_filterStart!.year}년 ${_filterStart!.month}월',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView.builder(
              controller: scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final day = days[i];
                final isSelected = isSameDay(day, _selectedDay);
                final isToday = isSameDay(day, DateTime.now());
                final schedules = _schedulesFor(day);
                final hasMemo = _memosFor(day).isNotEmpty;
                final hasTaken = schedules.any((s) => s.isTaken);
                final hasMissed = schedules.any((s) => !s.isTaken);

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDay = day;
                    _showMemoInput = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.lavender
                          : isToday
                          ? AppColors.lavenderBg
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.lavender
                            : isToday
                            ? AppColors.lavenderBorder
                            : AppColors.cardBorder,
                        width: isSelected ? 0 : 0.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(
                          color: AppColors.lavender.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 요일
                        Text(
                          _dowLabel(day),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : day.weekday == 7 || day.weekday == 6
                                ? AppColors.danger.withOpacity(0.7)
                                : AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 날짜
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 상태 점
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasTaken) _statusDot(AppColors.success, isSelected),
                            if (hasMissed) _statusDot(AppColors.danger, isSelected),
                            if (hasMemo) _statusDot(
                              isSelected ? Colors.white.withOpacity(0.8) : AppColors.lavender,
                              isSelected,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 범례
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _LegendDot(color: AppColors.success, label: '복용 완료'),
                const SizedBox(width: 12),
                _LegendDot(color: AppColors.danger, label: '미복용'),
                const SizedBox(width: 12),
                _LegendDot(color: AppColors.lavender, label: '메모'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, bool isSelected) {
    return Container(
      width: 5, height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ─── 전체 달력 (필터 비활성 시) ─────────────────────────────────────────

  Widget _buildCalendar() {
    return TableCalendar<UserSchedule>(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2028, 12, 31),
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
      eventLoader: _schedulesFor,
      calendarFormat: CalendarFormat.month,
      calendarStyle: CalendarStyle(
        todayDecoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        selectedDecoration: BoxDecoration(
          color: AppColors.lavender.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 1.5),
        ),
        selectedTextStyle: const TextStyle(color: AppColors.lavenderDark, fontSize: 12, fontWeight: FontWeight.w600),
        defaultTextStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
        outsideDaysVisible: false,
        markersMaxCount: 3,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textHint, size: 22),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textHint, size: 22),
        headerPadding: EdgeInsets.symmetric(vertical: 10),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
        weekendStyle: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500),
      ),
      calendarBuilders: CalendarBuilders<UserSchedule>(
        markerBuilder: (context, day, events) {
          final hasMemo = _memosFor(day).isNotEmpty;
          if (events.isEmpty && !hasMemo) return const SizedBox();
          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...events.take(3).map((s) => Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: s.isTaken ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                )),
                if (hasMemo)
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
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
          SizedBox(width: 12),
          _LegendDot(color: AppColors.danger, label: '미복용'),
          SizedBox(width: 12),
          _LegendDot(color: AppColors.lavender, label: '메모'),
        ],
      ),
    );
  }

  // ─── 선택 날짜 헤더 ───────────────────────────────────────────────────────

  Widget _buildDayHeader() {
    final schedules = _schedulesFor(_selectedDay);
    final done = schedules.where((s) => s.isTaken).length;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_selectedDay.month}월 ${_selectedDay.day}일 복용 일정',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
        Text('$done/${schedules.length} 완료',
            style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── 일정 카드 ────────────────────────────────────────────────────────────

  List<Widget> _buildScheduleCards() {
    final schedules = _schedulesFor(_selectedDay);
    if (schedules.isEmpty) {
      return [_EmptyCard(
        text: _isFilterActive
            ? '이 날의 복약 일정이 없습니다.'
            : '이 날의 복약 일정이 없습니다.',
      )];
    }

    return schedules.map((s) {
      final med = s.medication;
      final drug = med?.drug;
      final name = med?.displayName ?? '등록 약';
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
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: s.isTaken ? AppColors.success : AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    [s.time, if (drug?.company.isNotEmpty == true) drug!.company].join(' · '),
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                  if (med?.instruction.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(med!.instruction,
                        style: const TextStyle(fontSize: 10, color: AppColors.lavenderDark)),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () => _toggleTaken(s),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: Text(s.isTaken ? '취소' : '복용',
                  style: TextStyle(fontSize: 11,
                      color: s.isTaken ? AppColors.textHint : AppColors.lavender)),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildMemoCards() {
    final memos = _memosFor(_selectedDay);
    if (memos.isEmpty) return [];
    return memos.map((memo) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: AppColors.lavender, width: 2)),
      ),
      child: Text(memo, style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark, height: 1.5)),
    )).toList();
  }

  Widget _buildMemoButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showMemoInput = !_showMemoInput),
      icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.lavender),
      label: const Text('날짜별 메모 추가',
          style: TextStyle(color: AppColors.lavender, fontSize: 11)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          Text('${_selectedDay.month}월 ${_selectedDay.day}일 메모',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '처방 사유, 특이사항, 복용 실수 등을 기록하세요.'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveMemo,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _showMemoInput = false; _memoController.clear(); }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 기간 바텀시트 ────────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lavenderBorder,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('기간 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('설정한 기간의 날짜만 스트립으로 표시됩니다.',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _DatePickerButton(
                    label: '시작일', value: _fmtDate(_filterStart),
                    onTap: () async { await _pickFilterStart(); setSheet(() {}); },
                  )),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('~', style: TextStyle(fontSize: 16, color: AppColors.textHint))),
                  Expanded(child: _DatePickerButton(
                    label: '종료일', value: _fmtDate(_filterEnd),
                    onTap: () async { await _pickFilterEnd(); setSheet(() {}); },
                  )),
                ],
              ),
              const SizedBox(height: 14),
              const Text('빠른 선택',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _presetBtn(ctx, '이번 주', 7),
                _presetBtn(ctx, '2주', 14),
                _presetBtn(ctx, '이번 달', 30),
                _presetBtn(ctx, '3개월', 90),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _filterStart != null && _filterEnd != null
                      ? () { Navigator.pop(ctx); _applyFilter(); }
                      : null,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetBtn(BuildContext ctx, String label, int days) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        setState(() {
          _filterStart = DateTime(now.year, now.month, now.day);
          _filterEnd = DateTime(now.year, now.month, now.day + days - 1);
          _focusedDay = _filterStart!;
        });
        Navigator.pop(ctx);
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lavenderBorder, width: 0.7),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark)),
      ),
    );
  }

  // ─── 봉투 순서 패널 ───────────────────────────────────────────────────────

  Widget _buildOrderPanel() {
    final ordered = _bagOrder.map((id) {
      try { return _bags.firstWhere((b) => b.id == id); }
      catch (_) { return null; }
    }).whereType<BagData>().toList();

    return Container(
      margin: const EdgeInsets.only(top: 8, right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('캘린더 표시 순서',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.lavenderDark)),
          const SizedBox(height: 4),
          const Text('드래그하여 순서를 변경하세요',
              style: TextStyle(fontSize: 10, color: AppColors.textHint)),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ordered.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _bagOrder.removeAt(oldIdx);
                _bagOrder.insert(newIdx, item);
              });
            },
            itemBuilder: (ctx, i) {
              final bag = ordered[i];
              return Container(
                key: ValueKey(bag.id),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle, size: 16, color: AppColors.textHint),
                    const SizedBox(width: 8),
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: bag.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(bag.name,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    const Spacer(),
                    Text('${i + 1}번째',
                        style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── 액션 ────────────────────────────────────────────────────────────────

  Future<void> _toggleTaken(UserSchedule schedule) async {
    await ScheduleService.setTaken(scheduleId: schedule.id, isTaken: !schedule.isTaken);
    await _loadMonth();
  }

  Future<void> _saveMemo() async {
    final content = _memoController.text.trim();
    if (content.isEmpty) return;
    try {
      await CalendarMemoService.saveMemo(date: _selectedDay, content: content);
      _memoController.clear();
      setState(() => _showMemoInput = false);
      await _loadMonth();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모 저장 실패: $e'), backgroundColor: AppColors.danger));
    }
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────────────────────

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
      child: Center(child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint))),
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
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DatePickerButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lavenderBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lavenderBorder, width: 0.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 12, color: AppColors.lavenderDark, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
