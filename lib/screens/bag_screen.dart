import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/models/medicine_model.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/screens/bag_detail_screen.dart';
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
    } catch (e) {
      if (mounted) setState(() => _errorMsg = '약봉투 조회 실패: $e');
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

  // ── 봉투 추가 다이얼로그 ──────────────────────────────────────────────────

  Future<void> _showAddBagDialog() async {
    final nameCtrl = TextEditingController();
    int colorIdx = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('새 약봉투 만들기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
              child: const Text('만들기'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await BagService.addBag(nameCtrl.text.trim(), colorIdx);
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
    var dates = _datesFromInstruction(med.instruction);
    var startDate = dates.$1;
    var endDate = dates.$2;
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
                const Text('복용 기간', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [(3,'3일'),(7,'7일'),(14,'14일'),(30,'한달')].map((p) {
                  return GestureDetector(
                    onTap: () => setInner(() {
                      selectedPresetDays = p.$1;
                      endDate = DateTime(startDate.year, startDate.month, startDate.day + p.$1 - 1);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedPresetDays == p.$1 ? AppColors.lavender : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedPresetDays == p.$1 ? AppColors.lavender : AppColors.lavenderBorder, width: 0.7),
                      ),
                      child: Text(p.$2, style: TextStyle(fontSize: 11,
                          color: selectedPresetDays == p.$1 ? Colors.white : AppColors.lavenderDark, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList()),
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

    if (result != true) { nameCtrl.dispose(); return; }
    try {
      final sortedSlots = slots.toList()..sort((a, b) => _slotHour(a).compareTo(_slotHour(b)));
      final instruction = '${sortedSlots.join(', ')} $mealTiming 복용 · ${_fmtDt(startDate)}~${_fmtDt(endDate)}';
      await MedicationService.updateMedicationSettings(
        medication: med,
        customName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : med.displayName,
        instruction: instruction,
        durationDays: endDate.difference(startDate).inDays + 1,
        startDate: startDate, endDate: endDate,
        scheduleTimes: sortedSlots.map(_slotTime).toList(),
        mealTimingLabel: mealTiming,
      );
      nameCtrl.dispose();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${med.displayName} 복용 설정을 수정했습니다.'),
        backgroundColor: AppColors.lavender,
      ));
    } catch (e) {
      nameCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('수정 실패: $e'), backgroundColor: AppColors.danger));
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

  (DateTime, DateTime) _datesFromInstruction(String instruction) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final match = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})~(\d{4})\.(\d{2})\.(\d{2})').firstMatch(instruction);
    if (match == null) return (today, DateTime(today.year, today.month, today.day + 6));
    return (
    DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!)),
    DateTime(int.parse(match.group(4)!), int.parse(match.group(5)!), int.parse(match.group(6)!)),
    );
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

  String _slotTime(String slot) => '${_slotHour(slot).toString().padLeft(2, '0')}:00:00';

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
      await MedicationService.deactivateMedication(med.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${med.displayName} 삭제됨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: AppColors.danger),
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
                      hintText: '상품명, 업체명, 표준코드로 약물 검색',
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
                  // ── 통합 경고 (최상단 한 번만) ──────────────────
                  if (_bagWarnings.isNotEmpty)
                    _GlobalWarningSection(
                      warnings: _bagWarnings,
                      medications: _medications,
                      assignments: _assignments,
                      bags: _bags,
                    ),
                  if (_medications.length >= 2 && _bagWarnings.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 0.5),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                        SizedBox(width: 6),
                        Text('현재 DB 기준 확인된 병용 금기 없음',
                            style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
                      ]),
                    ),
                  // ── 봉투 목록 ────────────────────────────────────
                  ..._bags.map((bag) {
                    final meds = _medications
                        .where((m) =>
                    (_assignments[m.id] ?? 'default') == bag.id)
                        .toList();
                    return _BagCard(
                      bag: bag,
                      medications: meds,
                      warnings: const [],   // 봉투별 경고 제거
                      isExpanded: _expanded.contains(bag.id),
                      onToggle: () => setState(() {
                        if (_expanded.contains(bag.id)) {
                          _expanded.remove(bag.id);
                        } else {
                          _expanded.add(bag.id);
                        }
                      }),
                      onMedTap: (med) => _showEditMedicationDialog(med),
                      onMedDelete: _removeMedication,
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
  final List<DrugWarning> warnings;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<UserMedication> onMedTap;
  final ValueChanged<UserMedication> onMedDelete;
  final VoidCallback? onBagDelete;

  const _BagCard({
    required this.bag,
    required this.medications,
    required this.warnings,
    required this.isExpanded,
    required this.onToggle,
    required this.onMedTap,
    required this.onMedDelete,
    this.onBagDelete,
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
                  // ── 경고 스트립 ──────────────────────────────────────────
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...warnings.take(3).map((w) => _WarningStrip(warning: w)),
                  ] else if (medications.length >= 2) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 13),
                          SizedBox(width: 5),
                          Text('현재 DB 기준 확인된 병용 금기 없음',
                              style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
                        ],
                      ),
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

// ─── 통합 경고 섹션 (최상단 한 번만 표시) ────────────────────────────────────
//
// 각 경고 메시지에 관련 약물이 어느 봉투에 속하는지 표기
// 예: 코사인정(아파요, 싫어요)

class _GlobalWarningSection extends StatefulWidget {
  final List<DrugWarning> warnings;
  final List<UserMedication> medications;
  final Map<String, String> assignments;
  final List<BagData> bags;

  const _GlobalWarningSection({
    required this.warnings,
    required this.medications,
    required this.assignments,
    required this.bags,
  });

  @override
  State<_GlobalWarningSection> createState() => _GlobalWarningSectionState();
}

class _GlobalWarningSectionState extends State<_GlobalWarningSection> {
  bool _expanded = false;

  // 약물 이름에 봉투 이름 추가: "코사인정(아파요, 싫어요)"
  String _enrichMessage(String message) {
    String result = message;
    for (final med in widget.medications) {
      final name = med.displayName;
      if (!result.contains(name)) continue;

      // 해당 약이 속한 봉투 찾기
      final bagId = widget.assignments[med.id] ?? 'default';
      String? bagName;
      try {
        bagName = widget.bags.firstWhere((b) => b.id == bagId).name;
      } catch (_) {}

      if (bagName != null) {
        // 이미 봉투 표기된 경우 스킵
        if (result.contains('$name($bagName)') || result.contains('$name(')) continue;
        result = result.replaceAll(name, '$name($bagName)');
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final high = widget.warnings.where((w) => w.isHighRisk).toList();
    final mid  = widget.warnings.where((w) => !w.isHighRisk).toList();
    final displayWarnings = _expanded ? widget.warnings : widget.warnings.take(2).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: high.isNotEmpty
              ? AppColors.danger.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(children: [
              Icon(
                high.isNotEmpty ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
                size: 16,
                color: high.isNotEmpty ? AppColors.danger : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '약물 상호작용 주의 ${widget.warnings.length}건',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: high.isNotEmpty ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ),
              if (high.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('고위험 ${high.length}건',
                      style: const TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w700)),
                ),
              if (mid.isNotEmpty && high.isNotEmpty) const SizedBox(width: 4),
              if (mid.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('중위험 ${mid.length}건',
                      style: const TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const Divider(height: 0.5, color: AppColors.cardBorder),

          // ── 경고 목록 ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...displayWarnings.map((w) {
                  final isHigh = w.isHighRisk;
                  final color  = isHigh ? AppColors.danger : AppColors.warning;
                  final bg     = isHigh ? AppColors.dangerBg : AppColors.warningBg;
                  final enriched = _enrichMessage(w.message);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.2), width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${w.title} · 위험도 ${w.severity}',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          enriched,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.45),
                        ),
                      ],
                    ),
                  );
                }),
                // 더보기/접기
                if (widget.warnings.length > 2)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? '접기' : '나머지 ${widget.warnings.length - 2}건 더보기',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.lavender, fontWeight: FontWeight.w600),
                          ),
                          Icon(
                            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 14, color: AppColors.lavender,
                          ),
                        ],
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
                Text('${warning.title} · 위험도 ${warning.severity}',
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