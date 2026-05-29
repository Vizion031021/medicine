import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // ── 달력 상태 ──────────────────────────────────────────────────────────────
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // ── 필터 ──────────────────────────────────────────────────────────────────
  DateTime? _filterStart;
  DateTime? _filterEnd;
  bool _isFilterActive = false;
  bool _stripMode = false; // 스위치: 7칸 그리드 고정

  // ── 데이터 ────────────────────────────────────────────────────────────────
  final Map<DateTime, List<UserSchedule>> _schedulesByDay = {};
  final Map<DateTime, List<String>> _memosByDay = {};
  final Map<String, String> _scheduleMemos = {}; // scheduleId → memo

  // ── 약봉투 ────────────────────────────────────────────────────────────────
  List<BagData> _bags = [];
  List<String> _bagOrder = [];
  Map<String, String> _assignments = {};
  List<UserMedication> _medications = [];

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
    _loadScheduleMemos();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  // ── 데이터 로드 ────────────────────────────────────────────────────────────

  Future<void> _loadBags() async {
    final bags = await BagService.getBags();
    final assignments = await BagService.getAssignments();
    try {
      final meds = await MedicationService.fetchMyMedications();
      if (mounted) setState(() => _medications = meds);
    } catch (_) {}
    if (mounted) setState(() {
      _bags = bags;
      _assignments = assignments;
      if (_bagOrder.isEmpty) _bagOrder = bags.map((b) => b.id).toList();
    });
  }

  Future<void> _loadMonth() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final DateTime from, to;
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
      for (final s in schedules) ns.putIfAbsent(_dk(s.date), () => []).add(s);
      final nm = <DateTime, List<String>>{};
      for (final m in memos) {
        final date = DateTime.tryParse((m['memo_date'] ?? '').toString());
        final content = (m['content'] ?? '').toString();
        if (date == null || content.isEmpty) continue;
        nm.putIfAbsent(_dk(date), () => []).add(content);
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

  // ── 일정별 메모 (SharedPreferences) ────────────────────────────────────────

  Future<void> _loadScheduleMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('sched_memo_'));
    final map = <String, String>{};
    for (final k in keys) {
      final v = prefs.getString(k) ?? '';
      if (v.isNotEmpty) map[k.replaceFirst('sched_memo_', '')] = v;
    }
    if (mounted) setState(() => _scheduleMemos.addAll(map));
  }

  Future<void> _saveScheduleMemo(String scheduleId, String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sched_memo_$scheduleId', content);
    setState(() => _scheduleMemos[scheduleId] = content);
  }

  Future<void> _deleteScheduleMemo(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sched_memo_$scheduleId');
    setState(() => _scheduleMemos.remove(scheduleId));
  }

  // ── 유틸 ──────────────────────────────────────────────────────────────────

  List<UserSchedule> _schedulesFor(DateTime day) => _schedulesByDay[_dk(day)] ?? [];
  List<String> _memosFor(DateTime day) => _memosByDay[_dk(day)] ?? [];
  DateTime _dk(DateTime d) => DateTime(d.year, d.month, d.day);

  /// young 브랜치에서 가져옴: 미래 일정은 복용 체크 불가
  bool _canEditTaken(UserSchedule schedule) {
    final today = _dk(DateTime.now());
    final scheduleDay = _dk(schedule.date);
    return !scheduleDay.isAfter(today);
  }

  String _mealLabel(String time) {
    final h = int.tryParse(time.split(':').first) ?? 9;
    if (h < 11) return '아침';
    if (h < 16) return '점심';
    return '저녁';
  }

  Color _mealColor(String meal) {
    switch (meal) {
      case '아침': return const Color(0xFFEF9F27);
      case '점심': return AppColors.lavender;
      default:    return const Color(0xFF4A6FA5);
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '날짜 선택';
    return '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';
  }

  String _fmtTime(String t) {
    final p = t.split(':');
    return '${(p.isNotEmpty?p[0]:'09').padLeft(2,'0')}:${(p.length>1?p[1]:'00').padLeft(2,'0')}';
  }

  String _dowLabel(DateTime d) =>
      const ['일','월','화','수','목','금','토'][d.weekday % 7];

  // ── 필터 ─────────────────────────────────────────────────────────────────

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
    _selectedDay = _filterStart!;
    setState(() => _isFilterActive = true);
    _loadMonth();
  }

  void _clearFilter() {
    setState(() {
      _isFilterActive = false;
      _filterStart = null;
      _filterEnd = null;
      _stripMode = false;
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
    _loadMonth();
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMonth,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    // ── 달력 영역 ──────────────────────────────────────────
                    if (_isFilterActive && _stripMode)
                      _buildStripGrid()
                    else if (_isFilterActive)
                      _buildHorizontalStrip()
                    else
                      Container(
                        color: Colors.white,
                        child: Column(children: [_buildCalendar(), _buildLegend()]),
                      ),
                    const Divider(height: 0.5, color: AppColors.cardBorder),
                    // ── 일정 영역 ──────────────────────────────────────────
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_errorMessage!, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDayHeader(),
                            const SizedBox(height: 8),
                            ..._buildGroupedScheduleCards(),
                            ..._buildMemoCards(),
                            const SizedBox(height: 8),
                            _buildMemoButton(),
                            if (_showMemoInput) _buildMemoInput(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 헤더 ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
      child: Column(children: [
        Row(children: [
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
        ]),
        // 활성 필터 배지 + 스트립 스위치
        if (_isFilterActive && _filterStart != null && _filterEnd != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 2, right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lavenderBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.date_range, size: 13, color: AppColors.lavender),
              const SizedBox(width: 6),
              Text('${_fmtDate(_filterStart)}  ~  ${_fmtDate(_filterEnd)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark)),
              const Spacer(),
              const Text('그리드 고정',
                  style: TextStyle(fontSize: 10, color: AppColors.lavenderDark)),
              const SizedBox(width: 2),
              Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: _stripMode,
                  onChanged: (v) => setState(() => _stripMode = v),
                  activeColor: AppColors.lavender,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              GestureDetector(
                onTap: _clearFilter,
                child: const Icon(Icons.close, size: 14, color: AppColors.lavenderDark),
              ),
            ]),
          ),
        if (_showOrderPanel && _bags.length > 1) _buildOrderPanel(),
      ]),
    );
  }

  // ── 가로 스크롤 스트립 (필터 ON, 스위치 OFF) — young 스타일 ─────────────────

  Widget _buildHorizontalStrip() {
    if (_filterStart == null || _filterEnd == null) return const SizedBox();
    final days = <DateTime>[];
    var cur = _filterStart!;
    while (!cur.isAfter(_filterEnd!)) { days.add(cur); cur = cur.add(const Duration(days: 1)); }

    final selectedIdx = days.indexWhere((d) => isSameDay(d, _selectedDay));
    final scrollCtrl = ScrollController(
      initialScrollOffset: selectedIdx > 0 ? (selectedIdx * 62.0).clamp(0, double.infinity) : 0,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('${_filterStart!.year}년 ${_filterStart!.month}월',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                onTap: () => setState(() { _selectedDay = day; _showMemoInput = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.lavender
                        : isToday ? AppColors.lavenderBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.lavender
                          : isToday ? AppColors.lavenderBorder : AppColors.cardBorder,
                      width: isSelected ? 0 : 0.5,
                    ),
                    boxShadow: isSelected ? [BoxShadow(
                        color: AppColors.lavender.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 2))] : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_dowLabel(day), style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white.withOpacity(0.85)
                          : day.weekday % 7 == 0 ? AppColors.danger.withOpacity(0.7)
                          : AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    )),
                    const SizedBox(height: 4),
                    Text('${day.day}', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    )),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (hasTaken) _sDot(AppColors.success),
                      if (hasMissed) _sDot(AppColors.danger),
                      if (hasMemo) _sDot(isSelected ? Colors.white.withOpacity(0.8) : AppColors.lavender),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
        _buildLegend(),
      ]),
    );
  }

  // ── 7칸 그리드 (필터 ON, 스위치 ON) ──────────────────────────────────────────

  Widget _buildStripGrid() {
    if (_filterStart == null || _filterEnd == null) return const SizedBox();
    final days = <DateTime>[];
    var cur = _filterStart!;
    while (!cur.isAfter(_filterEnd!)) { days.add(cur); cur = cur.add(const Duration(days: 1)); }
    const dows = ['일','월','화','수','목','금','토'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filterStart!.year}년 ${_filterStart!.month}월'
                  '${_filterEnd!.month != _filterStart!.month ? ' ~ ${_filterEnd!.month}월' : ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ),
        // 요일 헤더
        Row(children: List.generate(7, (i) => Expanded(
          child: Center(child: Text(dows[i], style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: i == 0 ? AppColors.danger : AppColors.textHint,
          ))),
        ))),
        const SizedBox(height: 4),
        // 날짜 그리드
        ...() {
          final startDow = _filterStart!.weekday % 7;
          final padded = List<DateTime?>.filled(startDow, null) + days.cast<DateTime?>();
          while (padded.length % 7 != 0) padded.add(null);
          return List.generate(padded.length ~/ 7, (r) {
            return Row(children: List.generate(7, (c) {
              final day = padded[r * 7 + c];
              if (day == null) return const Expanded(child: SizedBox(height: 58));
              final isSelected = isSameDay(day, _selectedDay);
              final isToday = isSameDay(day, DateTime.now());
              final scheds = _schedulesFor(day);
              final hasMemo = _memosFor(day).isNotEmpty;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _selectedDay = day; _showMemoInput = false; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 58,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lavender
                          : isToday ? AppColors.lavenderBg : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.lavender
                            : isToday ? AppColors.lavenderBorder : AppColors.cardBorder,
                        width: isSelected ? 0 : 0.5,
                      ),
                      boxShadow: isSelected ? [BoxShadow(
                        color: AppColors.lavender.withOpacity(0.25),
                        blurRadius: 6, offset: const Offset(0, 2),
                      )] : null,
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_dowLabel(day), style: TextStyle(fontSize: 9,
                          color: isSelected ? Colors.white.withOpacity(0.8)
                              : day.weekday % 7 == 0 ? AppColors.danger.withOpacity(0.7)
                              : AppColors.textHint)),
                      const SizedBox(height: 2),
                      Text('${day.day}', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      )),
                      const SizedBox(height: 3),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (scheds.any((s) => s.isTaken)) _sDot(AppColors.success),
                        if (scheds.any((s) => !s.isTaken)) _sDot(AppColors.danger),
                        if (hasMemo) _sDot(isSelected ? Colors.white.withOpacity(0.7) : AppColors.lavender),
                      ]),
                    ]),
                  ),
                ),
              );
            }));
          });
        }(),
        _buildLegend(),
      ]),
    );
  }

  Widget _sDot(Color color) => Container(
    width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── 풀 달력 ──────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return TableCalendar<UserSchedule>(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2028, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; _showMemoInput = false; });
      },
      onPageChanged: (focusedDay) { _focusedDay = focusedDay; _loadMonth(); },
      eventLoader: _schedulesFor,
      calendarFormat: CalendarFormat.month,
      calendarStyle: CalendarStyle(
        todayDecoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        selectedDecoration: BoxDecoration(
          color: AppColors.lavender.withOpacity(0.2), shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 1.5),
        ),
        selectedTextStyle: const TextStyle(color: AppColors.lavenderDark, fontSize: 12, fontWeight: FontWeight.w600),
        defaultTextStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
        outsideDaysVisible: false, markersMaxCount: 3,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false, titleCentered: true,
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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ...events.take(3).map((s) => Container(
                width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: s.isTaken ? AppColors.success : AppColors.danger,
                  shape: BoxShape.circle,
                ),
              )),
              if (hasMemo) Container(
                width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(children: [
        _LDot(color: AppColors.success, label: '복용 완료'),
        SizedBox(width: 12),
        _LDot(color: AppColors.danger, label: '미복용'),
        SizedBox(width: 12),
        _LDot(color: AppColors.lavender, label: '메모'),
      ]),
    );
  }

  // ── 날짜 헤더 ────────────────────────────────────────────────────────────

  Widget _buildDayHeader() {
    final schedules = _schedulesFor(_selectedDay);
    final done = schedules.where((s) => s.isTaken).length;
    return Row(children: [
      Expanded(child: Text('${_selectedDay.month}월 ${_selectedDay.day}일 복용 일정',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      Text('$done/${schedules.length} 완료',
          style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── 약봉투별 + 시간대별 그룹 카드 ────────────────────────────────────────────

  List<Widget> _buildGroupedScheduleCards() {
    final schedules = _schedulesFor(_selectedDay);
    if (schedules.isEmpty) {
      return [const _EmptyCard(text: '이 날의 복약 일정이 없습니다.')];
    }

    // 봉투별 그룹화
    final bagGroups = <String, List<UserSchedule>>{};
    for (final s in schedules) {
      final med = s.medication;
      final bagId = med != null ? (_assignments[med.id] ?? 'default') : 'default';
      bagGroups.putIfAbsent(bagId, () => []).add(s);
    }

    // 봉투 순서 정렬
    final orderedBagIds = [..._bagOrder]
      ..retainWhere(bagGroups.containsKey);
    for (final id in bagGroups.keys) {
      if (!orderedBagIds.contains(id)) orderedBagIds.add(id);
    }

    return orderedBagIds.map((bagId) {
      final group = bagGroups[bagId]!;
      BagData? bag;
      try { bag = _bags.firstWhere((b) => b.id == bagId); } catch (_) {}
      return _BagScheduleGroup(
        bag: bag,
        schedules: group,
        scheduleMemos: _scheduleMemos,
        mealLabel: _mealLabel,
        mealColor: _mealColor,
        fmtTime: _fmtTime,
        canEditTaken: _canEditTaken,
        onToggle: (s) async {
          if (!_canEditTaken(s)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('미래 복용 일정은 당일이 되면 체크할 수 있습니다.')));
            return;
          }
          await ScheduleService.setTaken(scheduleId: s.id, isTaken: !s.isTaken);
          await _loadMonth();
        },
        onMemoSave: _saveScheduleMemo,
        onMemoDelete: _deleteScheduleMemo,
      );
    }).toList();
  }

  // ── 날짜 메모 ────────────────────────────────────────────────────────────

  List<Widget> _buildMemoCards() {
    final memos = _memosFor(_selectedDay);
    if (memos.isEmpty) return [];
    return memos.map((memo) => Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg, borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: AppColors.lavender, width: 2)),
      ),
      child: Text(memo, style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark, height: 1.5)),
    )).toList();
  }

  Widget _buildMemoButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showMemoInput = !_showMemoInput),
      icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.lavender),
      label: const Text('날짜 메모 추가', style: TextStyle(color: AppColors.lavender, fontSize: 11)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.lavenderBorder, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _buildMemoInput() {
    return Container(
      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_selectedDay.month}월 ${_selectedDay.day}일 메모',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(controller: _memoController, maxLines: 3,
            decoration: const InputDecoration(hintText: '처방 사유, 특이사항, 복용 실수 등을 기록하세요.')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _saveDateMemo,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
            child: const Text('저장'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() { _showMemoInput = false; _memoController.clear(); }),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          )),
        ]),
      ]),
    );
  }

  // ── 기간 바텀시트 ─────────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.lavenderBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('기간 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('설정한 기간의 날짜를 달력 또는 그리드로 표시합니다.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _DatePickBtn(label: '시작일', value: _fmtDate(_filterStart),
                  onTap: () async { await _pickFilterStart(); setSheet(() {}); })),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('~', style: TextStyle(fontSize: 16, color: AppColors.textHint))),
              Expanded(child: _DatePickBtn(label: '종료일', value: _fmtDate(_filterEnd),
                  onTap: () async { await _pickFilterEnd(); setSheet(() {}); })),
            ]),
            const SizedBox(height: 14),
            const Text('빠른 선택', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _presetBtn(ctx, '이번 주', 7), _presetBtn(ctx, '2주', 14),
              _presetBtn(ctx, '이번 달', 30), _presetBtn(ctx, '3개월', 90),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _filterStart != null && _filterEnd != null
                  ? () { Navigator.pop(ctx); _applyFilter(); } : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('적용'),
            )),
          ]),
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
        Navigator.pop(ctx); _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lavenderBorder, width: 0.7)),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark)),
      ),
    );
  }

  // ── 봉투 순서 패널 ────────────────────────────────────────────────────────

  Widget _buildOrderPanel() {
    final ordered = _bagOrder.map((id) {
      try { return _bags.firstWhere((b) => b.id == id); } catch (_) { return null; }
    }).whereType<BagData>().toList();

    return Container(
      margin: const EdgeInsets.only(top: 8, right: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.lavenderBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lavenderBorder, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('캘린더 표시 순서',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.lavenderDark)),
        const SizedBox(height: 4),
        const Text('드래그하여 순서를 변경하세요',
            style: TextStyle(fontSize: 10, color: AppColors.textHint)),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: ordered.length,
          onReorder: (o, n) => setState(() {
            if (n > o) n--;
            final item = _bagOrder.removeAt(o);
            _bagOrder.insert(n, item);
          }),
          itemBuilder: (ctx, i) {
            final bag = ordered[i];
            return Container(
              key: ValueKey(bag.id),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5)),
              child: Row(children: [
                const Icon(Icons.drag_handle, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: bag.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(bag.name, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                const Spacer(),
                Text('${i+1}번째', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  // ── 액션 ─────────────────────────────────────────────────────────────────

  Future<void> _saveDateMemo() async {
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

// ─── 약봉투별 일정 그룹 ────────────────────────────────────────────────────────

class _BagScheduleGroup extends StatelessWidget {
  final BagData? bag;
  final List<UserSchedule> schedules;
  final Map<String, String> scheduleMemos;
  final String Function(String) mealLabel;
  final Color Function(String) mealColor;
  final String Function(String) fmtTime;
  final bool Function(UserSchedule) canEditTaken;
  final Future<void> Function(UserSchedule) onToggle;
  final Future<void> Function(String, String) onMemoSave;
  final Future<void> Function(String) onMemoDelete;

  const _BagScheduleGroup({
    required this.bag, required this.schedules, required this.scheduleMemos,
    required this.mealLabel, required this.mealColor, required this.fmtTime,
    required this.canEditTaken, required this.onToggle,
    required this.onMemoSave, required this.onMemoDelete,
  });

  @override
  Widget build(BuildContext context) {
    const mealOrder = ['아침', '점심', '저녁'];
    final groups = <String, List<UserSchedule>>{};
    for (final s in schedules) groups.putIfAbsent(mealLabel(s.time), () => []).add(s);
    final ordered = [...mealOrder.where(groups.containsKey),
      ...groups.keys.where((k) => !mealOrder.contains(k))];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 봉투 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: bag?.color ?? AppColors.lavender, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(bag?.name ?? '내 약봉투',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            Text('${schedules.where((s) => s.isTaken).length}/${schedules.length} 복용',
                style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(height: 0.5, color: AppColors.cardBorder),
        // 시간대별 섹션
        ...ordered.map((meal) {
          final group = groups[meal]!..sort((a, b) => a.time.compareTo(b.time));
          final mc = mealColor(meal);
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 시간대 라벨
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: mc.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: mc.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(meal, style: TextStyle(fontSize: 10, color: mc, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text(group.isNotEmpty ? fmtTime(group.first.time) : '',
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                const Spacer(),
                Text('${group.where((s) => s.isTaken).length}/${group.length}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 8),
              // 일정 칩
              Wrap(spacing: 6, runSpacing: 6, children: group.map((s) => _ScheduleChip(
                schedule: s,
                memo: scheduleMemos[s.id],
                canEdit: canEditTaken(s),
                onToggle: () => onToggle(s),
                onMemoSave: (m) => onMemoSave(s.id, m),
                onMemoDelete: () => onMemoDelete(s.id),
              )).toList()),
              const SizedBox(height: 4),
            ]),
          );
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}

// ─── 일정 칩 ─────────────────────────────────────────────────────────────────

class _ScheduleChip extends StatelessWidget {
  final UserSchedule schedule;
  final String? memo;
  final bool canEdit;
  final VoidCallback onToggle;
  final Future<void> Function(String) onMemoSave;
  final Future<void> Function() onMemoDelete;

  const _ScheduleChip({
    required this.schedule, this.memo, required this.canEdit,
    required this.onToggle, required this.onMemoSave, required this.onMemoDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = schedule.medication?.displayName ?? '등록 약';
    final isTaken = schedule.isTaken;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isTaken ? AppColors.successBg : AppColors.lavenderBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isTaken ? AppColors.success.withOpacity(0.4) : AppColors.lavenderBorder,
            width: 0.7,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isTaken ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 13, color: isTaken ? AppColors.success : AppColors.textHint),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: isTaken ? const Color(0xFF2E7D32) : AppColors.lavenderDark,
          )),
          if (memo != null && memo!.isNotEmpty) ...[
            const SizedBox(width: 4),
            const Icon(Icons.sticky_note_2_outlined, size: 11, color: AppColors.lavender),
          ],
          if (!canEdit) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock_outline, size: 10, color: AppColors.textHint),
          ],
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final med = schedule.medication;
    final drug = med?.drug;
    final memoCtrl = TextEditingController(text: memo ?? '');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.lavenderBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med?.displayName ?? '등록 약',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (drug != null && drug.company.isNotEmpty)
                Text(drug.company, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ])),
            GestureDetector(
              onTap: canEdit ? () { onToggle(); Navigator.pop(ctx); } : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: !canEdit ? AppColors.lavenderBg
                      : schedule.isTaken ? AppColors.successBg : AppColors.lavenderBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !canEdit ? AppColors.lavenderBorder
                        : schedule.isTaken ? AppColors.success : AppColors.lavender,
                    width: 0.7,
                  ),
                ),
                child: Text(
                  !canEdit ? '🔒 예정' : (schedule.isTaken ? '✓ 복용 완료' : '복용 예정'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: !canEdit ? AppColors.textHint
                          : schedule.isTaken ? AppColors.success : AppColors.lavender),
                ),
              ),
            ),
          ]),
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('미래 일정은 당일이 되면 체크할 수 있습니다.',
                  style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ),
          const SizedBox(height: 12),
          // 상세 정보
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.lavenderBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lavenderBorder, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (med?.instruction.isNotEmpty == true)
                _DRow(icon: Icons.schedule_outlined, text: med!.instruction),
              if (drug != null && drug.specification.isNotEmpty)
                _DRow(icon: Icons.medication_outlined, text: drug.specification),
              if (drug != null && drug.prescriptionType.isNotEmpty)
                _DRow(icon: Icons.local_pharmacy_outlined, text: drug.prescriptionType),
              if (drug != null && drug.formType.isNotEmpty)
                _DRow(icon: Icons.science_outlined, text: drug.formType),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('메모', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(controller: memoCtrl, maxLines: 2,
              decoration: const InputDecoration(hintText: '복용 후 증상, 특이사항 등을 기록하세요.')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () async {
                final content = memoCtrl.text.trim();
                if (content.isEmpty) await onMemoDelete();
                else await onMemoSave(content);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              child: const Text('저장'),
            )),
            if (memo != null && memo!.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async { await onMemoDelete(); if (ctx.mounted) Navigator.pop(ctx); },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Icon(icon, size: 13, color: AppColors.lavender),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark))),
    ]),
  );
}

// ─── 공통 위젯 ────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5)),
    child: Center(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textHint))),
  );
}

class _LDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]);
}

class _DatePickBtn extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DatePickBtn({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.lavenderBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lavenderBorder, width: 0.7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.lavenderDark, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}