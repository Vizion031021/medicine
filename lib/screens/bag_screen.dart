import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/screens/drug_detail_screen.dart';
import 'package:sseudeuson/services/bag_service.dart';
import 'package:sseudeuson/services/drug_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({super.key});

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  // ── 상태 ──────────────────────────────────────────────────────────────────
  List<BagData> _bags = [];
  List<UserMedication> _medications = [];
  List<DrugWarning> _bagWarnings = [];
  Map<String, String> _assignments = {};
  final Set<String> _expanded = {};

  // ── 상단 검색 ────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<DrugInfo> _searchResults = [];
  bool _isSearching = false;
  bool _showSearch = false;

  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final bags = await BagService.getBags();
      final medications = await MedicationService.fetchMyMedications();
      final assignments = await BagService.getAssignments();

      // 봉투에 할당 안 된 약 → 기본 봉투로
      for (final med in medications) {
        if (!assignments.containsKey(med.id)) {
          await BagService.assignMedication(med.id, 'default');
          assignments[med.id] = 'default';
        }
      }

      final drugs = medications.map((m) => m.drug).whereType<DrugInfo>().toList();
      List<DrugWarning> warnings = [];
      if (drugs.length >= 2) {
        try {
          warnings = await DrugService.compareDrugs(drugs);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _bags = bags;
        _medications = medications;
        _assignments = assignments;
        _bagWarnings = warnings;
        if (_expanded.isEmpty && bags.isNotEmpty) _expanded.add(bags.first.id);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = '약봉투를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 약물 검색 ─────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await DrugService.searchDrugs(query, limit: 20);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── 봉투 추가/수정 다이얼로그 ────────────────────────────────────────────

  Future<void> _showAddBagDialog() => _showBagDialog();

  Future<void> _showBagDialog({BagData? editBag}) async {
    final isEdit = editBag != null;
    final nameCtrl = TextEditingController(text: isEdit ? editBag.name : '');
    int colorIdx = isEdit ? editBag.colorIndex : 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(isEdit ? '약봉투 수정' : '새 약봉투 만들기',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  hintText: '봉투 이름 입력 (예: 아침약, 혈압약)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              const Text('색상 선택',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(AppColors.bagColors.length, (i) {
                  final selected = colorIdx == i;
                  return GestureDetector(
                    onTap: () => setInner(() => colorIdx = i),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.bagColors[i],
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.textPrimary, width: 2)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      if (isEdit) {
        await BagService.updateBag(editBag.id, nameCtrl.text.trim(), colorIdx);
      } else {
        await BagService.addBag(nameCtrl.text.trim(), colorIdx);
      }
      await _load();
    }
  }

  // ── 약물을 봉투에 추가 ────────────────────────────────────────────────────

  Future<void> _showBagPickerAndNavigate(DrugInfo drug) async {
    if (_bags.isEmpty) return;

    String? selectedBagId = _bags.first.id;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(
            drug.name,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('어느 약봉투에 추가할까요?',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ..._bags.map((bag) {
                return RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: bag.id,
                  groupValue: selectedBagId,
                  onChanged: (v) => setInner(() => selectedBagId = v),
                  title: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: bag.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(bag.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  activeColor: AppColors.lavender,
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedBagId),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    // 약 상세 화면으로 이동 (복용 설정 + 저장)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrugDetailScreen(drug: drug, targetBagId: picked),
      ),
    );

    setState(() {
      _searchCtrl.clear();
      _searchResults = [];
      _showSearch = false;
    });
    await _load();
  }

  // ── 복용 설정 수정 다이얼로그 [young] ───────────────────────────────────────

  Future<void> _showEditMedicationDialog(UserMedication med) async {
    final nameCtrl = TextEditingController(text: med.displayName);
    final slots = _slotsFromInstruction(med.instruction);
    var mealTiming = med.instruction.contains('식전') ? '식전' : '식후';
    var mealOffsetMinutes = _offsetFromInstruction(med.instruction);
    var useCustomOffset = !const [0, 30, 60].contains(mealOffsetMinutes);
    final offsetCtrl = TextEditingController(
      text: useCustomOffset ? mealOffsetMinutes.toString() : '',
    );
    var dates = _datesFromInstruction(med.instruction);
    var startDate = dates[0];
    var endDate = dates[1];
    var selectedPresetDays = _presetFor(startDate, endDate);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked == null) return;
            setInner(() {
              startDate = DateTime(picked.year, picked.month, picked.day);
              if (selectedPresetDays > 0) {
                endDate = DateTime(startDate.year, startDate.month, startDate.day + selectedPresetDays - 1);
              } else if (endDate.isBefore(startDate)) {
                endDate = startDate;
              }
              selectedPresetDays = _presetFor(startDate, endDate);
            });
          }
          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: endDate.isBefore(startDate) ? startDate : endDate,
              firstDate: startDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (picked == null) return;
            setInner(() {
              endDate = DateTime(picked.year, picked.month, picked.day);
              selectedPresetDays = _presetFor(startDate, endDate);
            });
          }

          return AlertDialog(
            title: const Text('복용 설정 수정',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('약 표시 이름', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, maxLength: 30,
                    decoration: const InputDecoration(hintText: '약 표시 이름', counterText: '')),
                const SizedBox(height: 12),
                const Text('복용 시간대', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: ['아침','점심','저녁'].map((slot) {
                  final selected = slots.contains(slot);
                  return GestureDetector(
                    onTap: () => setInner(() {
                      if (selected) { if (slots.length > 1) slots.remove(slot); }
                      else slots.add(slot);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.lavender : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? AppColors.lavender : AppColors.lavenderBorder, width: 0.7),
                      ),
                      child: Text(slot, style: TextStyle(fontSize: 11,
                          color: selected ? Colors.white : AppColors.lavenderDark, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                const Text('복용 기준', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(children: ['식전','식후'].map((t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setInner(() => mealTiming = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: mealTiming == t ? AppColors.lavender : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: mealTiming == t ? AppColors.lavender : AppColors.lavenderBorder, width: 0.7),
                      ),
                      child: Text(t, style: TextStyle(fontSize: 11,
                          color: mealTiming == t ? Colors.white : AppColors.lavenderDark, fontWeight: FontWeight.w600)),
                    ),
                  ),
                )).toList()),
                const SizedBox(height: 12),
                const Text('복용 간격', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _SmallChoiceChip(
                    label: '즉시',
                    selected: !useCustomOffset && mealOffsetMinutes == 0,
                    onTap: () => setInner(() {
                      useCustomOffset = false;
                      mealOffsetMinutes = 0;
                      offsetCtrl.clear();
                    }),
                  ),
                  _SmallChoiceChip(
                    label: '30분',
                    selected: !useCustomOffset && mealOffsetMinutes == 30,
                    onTap: () => setInner(() {
                      useCustomOffset = false;
                      mealOffsetMinutes = 30;
                      offsetCtrl.clear();
                    }),
                  ),
                  _SmallChoiceChip(
                    label: '1시간',
                    selected: !useCustomOffset && mealOffsetMinutes == 60,
                    onTap: () => setInner(() {
                      useCustomOffset = false;
                      mealOffsetMinutes = 60;
                      offsetCtrl.clear();
                    }),
                  ),
                  _SmallChoiceChip(
                    label: '기타',
                    selected: useCustomOffset,
                    onTap: () => setInner(() {
                      useCustomOffset = true;
                      mealOffsetMinutes = int.tryParse(offsetCtrl.text.trim()) ?? 0;
                    }),
                  ),
                ]),
                if (useCustomOffset) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: offsetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '원하는 시간 입력 (분 단위)',
                      suffixText: '분',
                    ),
                    onChanged: (value) => setInner(() {
                      mealOffsetMinutes = int.tryParse(value.trim()) ?? 0;
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('복용 기간', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: () {
                  final presets = [[3, '3일'], [7, '7일'], [14, '14일'], [30, '한달']];
                  return presets.map((p) {
                    final days = p[0] as int;
                    final label = p[1] as String;
                    return GestureDetector(
                      onTap: () => setInner(() {
                        selectedPresetDays = days;
                        endDate = DateTime(startDate.year, startDate.month, startDate.day + days - 1);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedPresetDays == days ? AppColors.lavender : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selectedPresetDays == days ? AppColors.lavender : AppColors.lavenderBorder, width: 0.7),
                        ),
                        child: Text(label, style: TextStyle(fontSize: 11,
                            color: selectedPresetDays == days ? Colors.white : AppColors.lavenderDark, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList();
                }()),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _EditDateBtn(label: '시작', value: _fmtDt(startDate), onTap: pickStart)),
                  const SizedBox(width: 8),
                  Expanded(child: _EditDateBtn(label: '종료', value: _fmtDt(endDate), onTap: pickEnd)),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소', style: TextStyle(color: AppColors.textHint))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
            ],
          );
        },
      ),
    );

    if (result != true) { nameCtrl.dispose(); offsetCtrl.dispose(); return; }
    try {
      final sortedSlots = slots.toList()..sort((a, b) => _slotHour(a).compareTo(_slotHour(b)));
      final offset = (useCustomOffset
          ? int.tryParse(offsetCtrl.text.trim()) ?? mealOffsetMinutes
          : mealOffsetMinutes)
          .clamp(0, 180)
          .toInt();
      final instruction = '${sortedSlots.join(', ')} $mealTiming ${_offsetLabel(offset)} 복용 · ${_fmtDt(startDate)}~${_fmtDt(endDate)}';
      await MedicationService.updateMedicationSettings(
        medication: med,
        customName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : med.displayName,
        instruction: instruction,
        durationDays: endDate.difference(startDate).inDays + 1,
        startDate: startDate, endDate: endDate,
        scheduleTimes: sortedSlots.map((slot) => _slotTime(slot, mealTiming, offset)).toList(),
        mealTimingLabel: mealTiming,
        mealOffsetMinutes: offset,
      );
      nameCtrl.dispose();
      offsetCtrl.dispose();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${med.displayName} 복용 설정을 수정했습니다.'),
        backgroundColor: AppColors.lavender,
      ));
    } catch (_) {
      nameCtrl.dispose();
      offsetCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('복용 설정을 저장하지 못했습니다. 다시 시도해 주세요.'),
          backgroundColor: AppColors.danger));
    }
  }

  Set<String> _slotsFromInstruction(String instruction) {
    final slots = <String>{};
    if (instruction.contains('아침')) slots.add('아침');
    if (instruction.contains('점심')) slots.add('점심');
    if (instruction.contains('저녁')) slots.add('저녁');
    if (slots.isEmpty) slots.add('아침');
    return slots;
  }

  List<DateTime> _datesFromInstruction(String instruction) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final match = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})~(\d{4})\.(\d{2})\.(\d{2})').firstMatch(instruction);
    if (match == null) return [today, DateTime(today.year, today.month, today.day + 6)];
    final start = DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
    final end   = DateTime(int.parse(match.group(4)!), int.parse(match.group(5)!), int.parse(match.group(6)!));
    return [start, end];
  }

  int _presetFor(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    return const [3, 7, 14, 30].contains(days) ? days : 0;
  }

  String _fmtDt(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  int _slotHour(String slot) {
    if (slot == '점심') return 12;
    if (slot == '저녁') return 18;
    return 9;
  }

  int _offsetFromInstruction(String instruction) {
    if (instruction.contains('즉시')) return 0;
    if (instruction.contains('1시간')) return 60;
    final match = RegExp(r'(\d+)분').firstMatch(instruction);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  String _offsetLabel(int minutes) {
    if (minutes <= 0) return '즉시';
    if (minutes == 60) return '1시간';
    return '$minutes분';
  }

  String _slotTime(String slot, String mealTiming, int offsetMinutes) {
    final direction = mealTiming == '식전' ? -1 : 1;
    final time = DateTime(2026, 1, 1, _slotHour(slot))
        .add(Duration(minutes: direction * offsetMinutes));
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  // ── 약물 삭제 ─────────────────────────────────────────────────────────────

  Future<void> _removeMedication(UserMedication med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('약봉투에서 빼기'),
        content: Text('${med.displayName}을(를) 약봉투에서 뺄까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('빼기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await MedicationService.deactivateMedication(
        med.id,
        productCode: med.productCode,
      );
      _assignments.remove(med.id);
      setState(() {
        _medications.removeWhere(
              (item) => item.id == med.id,
        );
        _bagWarnings = [];
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${med.displayName} 삭제됨')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('약을 약봉투에서 빼지 못했습니다. 다시 시도해 주세요.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('약봉투 관리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text('약봉투 · 약물 관리',
                style: TextStyle(fontSize: 10, color: AppColors.textHint,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        toolbarHeight: 56,
        actions: [
          // 검색 토글
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : Icons.search,
              color: AppColors.lavender,
            ),
            tooltip: '약물 검색',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          // ⑤ + 버튼: 약봉투 추가
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.lavender),
            tooltip: '새 약봉투 만들기',
            onPressed: _showAddBagDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ⑤ 상단 검색바 (약물 검색하여 봉투에 추가)
          if (_showSearch) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '상품명 또는 업체명으로 약물 검색',
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.lavender),
                      suffixIcon: _isSearching
                          ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                          : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          })
                          : null,
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder, width: 0.5),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 0.5, indent: 14, endIndent: 14),
                        itemBuilder: (ctx, i) {
                          final drug = _searchResults[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            title: Text(drug.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${drug.prescriptionType.isEmpty ? '' : '${drug.prescriptionType} · '}'
                                  '${drug.formType.isEmpty ? drug.company : drug.formType}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: const Icon(Icons.add_circle_outline,
                                size: 20, color: AppColors.lavender),
                            onTap: () => _showBagPickerAndNavigate(drug),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 0.5, color: AppColors.cardBorder),
          ],

          // ── 봉투 목록 ──────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _errorMsg != null
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_errorMsg!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ))
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                children: [
                  _OverallWarningPanel(
                    medicationCount: _medications.length,
                    warnings: _bagWarnings,
                    medications: _medications,
                    assignments: _assignments,
                    bags: _bags,
                  ),
                  const SizedBox(height: 10),
                  ..._bags.map((bag) {
                    final meds = _medications
                        .where((m) =>
                    (_assignments[m.id] ?? 'default') == bag.id)
                        .toList();
                    return _BagCard(
                      bag: bag,
                      medications: meds,
                      isExpanded: _expanded.contains(bag.id),
                      onToggle: () => setState(() {
                        if (_expanded.contains(bag.id)) {
                          _expanded.remove(bag.id);
                        } else {
                          _expanded.add(bag.id);
                        }
                      }),
                      onMedTap: _showEditMedicationDialog,
                      onMedDelete: _removeMedication,
                      onBagEdit: () => _showBagDialog(editBag: bag),
                      onBagDelete: bag.id == 'default'
                          ? null
                          : () async {
                        await BagService.removeBag(bag.id);
                        await _load();
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 약봉투 카드 ─────────────────────────────────────────────────────────────

class _BagCard extends StatelessWidget {
  final BagData bag;
  final List<UserMedication> medications;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<UserMedication> onMedTap;
  final ValueChanged<UserMedication> onMedDelete;
  final VoidCallback? onBagDelete;
  final VoidCallback? onBagEdit;

  const _BagCard({
    required this.bag,
    required this.medications,
    required this.isExpanded,
    required this.onToggle,
    required this.onMedTap,
    required this.onMedDelete,
    this.onBagDelete,
    this.onBagEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // ── 헤더 ────────────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: bag.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bag.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('약물 ${medications.length}종',
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  // 상태 배지
                  // 통합 경고로 이동 — 봉투별 배지 제거
                  const SizedBox(width: 6),
                  // 수정 버튼
                  GestureDetector(
                    onTap: onBagEdit,
                    child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textHint),
                  ),
                  const SizedBox(width: 6),
                  // 삭제 버튼 (기본 봉투 제외)
                  if (onBagDelete != null)
                    GestureDetector(
                      onTap: onBagDelete,
                      child: const Icon(Icons.delete_outline, size: 16, color: AppColors.textHint),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.textHint, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── 펼쳐진 내용 ──────────────────────────────────────────────────
          if (isExpanded) ...[
            const Divider(height: 0.5, color: AppColors.cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (medications.isEmpty)
                    const Text('이 봉투에 아직 약이 없습니다. 상단 검색으로 추가하세요.',
                        style: TextStyle(fontSize: 10, color: AppColors.textHint))
                  else ...[
                    const Text('탭하면 복용 시간·기간을 수정할 수 있어요',
                        style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: medications.map((med) {
                        return Container(
                          padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => onMedTap(med),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(med.displayName,
                                        style: const TextStyle(
                                            fontSize: 11, color: AppColors.lavenderDark)),
                                    const Icon(Icons.chevron_right,
                                        size: 12, color: AppColors.lavenderDark),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 2),
                              InkWell(
                                onTap: () => onMedDelete(med),
                                child: const Icon(Icons.close, size: 13, color: AppColors.textHint),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 전체 약 상호작용 패널 ────────────────────────────────────────────────────

class _OverallWarningPanel extends StatelessWidget {
  final int medicationCount;
  final List<DrugWarning> warnings;
  final List<UserMedication> medications;
  final Map<String, String> assignments;
  final List<BagData> bags;

  const _OverallWarningPanel({
    required this.medicationCount,
    required this.warnings,
    required this.medications,
    required this.assignments,
    required this.bags,
  });

  // 약물 이름에 봉투 이름 추가: "코사인정(아파요, 싫어요)"
  String _enrichMessage(String message) {
    String result = message;
    for (final med in medications) {
      final name = med.displayName;
      if (!result.contains(name)) continue;
      final bagId = assignments[med.id] ?? 'default';
      String? bagName;
      try { bagName = bags.firstWhere((b) => b.id == bagId).name; } catch (_) {}
      if (bagName != null && !result.contains('$name(')) {
        result = result.replaceAll(name, '$name($bagName)');
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final hasEnoughMeds = medicationCount >= 2;
    final high = warnings.where((w) => w.isHighRisk).toList();
    final mid  = warnings.where((w) => !w.isHighRisk).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warnings.isEmpty ? AppColors.cardBorder
              : high.isNotEmpty ? AppColors.danger.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              warnings.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 16,
              color: warnings.isEmpty ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text('전체 약 상호작용 종합',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    color: warnings.isEmpty ? AppColors.success : AppColors.danger))),
          ]),
          const SizedBox(height: 8),
          if (!hasEnoughMeds)
            const Text('약이 2개 이상 등록되면 전체 약 기준으로 상호작용을 확인합니다.',
                style: TextStyle(fontSize: 10, color: AppColors.textHint))
          else if (warnings.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                SizedBox(width: 6),
                Expanded(child: Text('현재 함께 복용 시 주의가 필요한 조합은 확인되지 않았습니다.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32)))),
              ]),
            )
          else
            _ExpandableWarningList(warnings: warnings, enrichMessage: _enrichMessage),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Badge({required this.label, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
  );
}

class _ExpandableWarningList extends StatefulWidget {
  final List<DrugWarning> warnings;
  final String Function(String) enrichMessage;
  const _ExpandableWarningList({required this.warnings, required this.enrichMessage});
  @override
  State<_ExpandableWarningList> createState() => _ExpandableWarningListState();
}

class _ExpandableWarningListState extends State<_ExpandableWarningList> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final displayWarnings = _expanded ? widget.warnings : widget.warnings.take(2).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...displayWarnings.map((w) {
        final isHigh = w.isHighRisk;
        final color = isHigh ? AppColors.danger : AppColors.warning;
        final bg = isHigh ? AppColors.dangerBg : AppColors.warningBg;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2), width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.isHighRisk ? '${w.title} · 확인 필요' : '${w.title} · 주의',
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.enrichMessage(w.message),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.45)),
          ]),
        );
      }),
      if (widget.warnings.length > 2)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_expanded ? '접기' : '나머지 ${widget.warnings.length - 2}건 더보기',
                  style: const TextStyle(fontSize: 10, color: AppColors.lavender, fontWeight: FontWeight.w600)),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14, color: AppColors.lavender),
            ]),
          ),
        ),
    ]);
  }
}

class _WarningStrip extends StatelessWidget {
  final DrugWarning warning;
  const _WarningStrip({required this.warning});

  @override
  Widget build(BuildContext context) {
    final isHigh = warning.isHighRisk;
    final color = isHigh ? AppColors.danger : AppColors.warning;
    final bg = isHigh ? AppColors.dangerBg : AppColors.warningBg;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isHigh ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
              color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warning.isHighRisk ? '${warning.title} · 확인 필요' : '${warning.title} · 주의',
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(warning.message,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool hasWarning;
  const _StatusBadge({required this.hasWarning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hasWarning ? AppColors.warningBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        hasWarning ? '⚠ 주의' : '✓ 확인',
        style: TextStyle(
          fontSize: 10,
          color: hasWarning ? const Color(0xFF854F0B) : const Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmallChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.lavender : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.lavenderBorder,
            width: 0.7,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : AppColors.lavenderDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── 날짜 선택 버튼 ───────────────────────────────────────────────────────────

class _EditDateBtn extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditDateBtn({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lavenderBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lavenderBorder, width: 0.7),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: AppColors.lavender),
          ],
        ),
      ),
    );
  }
}