import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/services/bag_service.dart';
import 'package:sseudeuson/services/drug_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class DrugDetailScreen extends StatefulWidget {
  final DrugInfo drug;

  /// 약봉투 화면에서 넘어올 때 어느 봉투에 넣을지 지정.
  /// null 이면 기본 봉투('default')에 할당.
  final String? targetBagId;

  const DrugDetailScreen({super.key, required this.drug, this.targetBagId});

  @override
  State<DrugDetailScreen> createState() => _DrugDetailScreenState();
}

class _DrugDetailScreenState extends State<DrugDetailScreen> {
  late final Future<List<DrugWarning>> _warningsFuture;
  late final Future<String> _ingredientNameFuture;
  final Set<_MealSlot> _selectedSlots = {_MealSlot.breakfast};
  _MealTiming _mealTiming = _MealTiming.after;
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedPresetDays = 7;
  bool _isSaving = false;
  late final TextEditingController _customNameController;

  @override
  void initState() {
    super.initState();
    _warningsFuture = DrugService.fetchWarnings(widget.drug);
    _ingredientNameFuture = DrugService.fetchIngredientName(widget.drug);
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day + 6);
    final defaultName = widget.drug.name.length > 20
        ? widget.drug.name.substring(0, 20)
        : widget.drug.name;
    _customNameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              drug.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              drug.company.isEmpty ? '업체 정보 없음' : drug.company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
        toolbarHeight: 58,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        children: [
          // ── 기본 정보 ──────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.medication_outlined,
            iconColor: AppColors.lavender,
            title: '약품 기본 정보',
            child: Column(
              children: [
                _InfoRow(label: '한글상품명', value: drug.name),
                _InfoRow(label: '업체명', value: drug.company),
                _InfoRow(label: '제품코드', value: drug.productCode),
                _InfoRow(label: '표준코드', value: drug.standardCode),
                _InfoRow(label: '성분명코드', value: drug.ingredientCode),
                _InfoRow(label: 'ATC 코드', value: drug.atcCode),
                _InfoRow(label: '전문/일반', value: drug.prescriptionType),
                _InfoRow(label: '제형', value: drug.formType),
                _InfoRow(label: '규격', value: drug.specification),
                _InfoRow(label: '포장', value: drug.packageType),
              ],
            ),
          ),

          // ── 성분 ──────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.science_outlined,
            iconColor: AppColors.success,
            title: '성분 확인',
            child: FutureBuilder<String>(
              future: _ingredientNameFuture,
              builder: (context, snapshot) {
                final name = snapshot.data ?? '';
                final label = name.isNotEmpty
                    ? '$name (${drug.ingredientCode})'
                    : drug.ingredientLabel;
                return Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
          ),

          // ── 주의 정보 ──────────────────────────────────────────────────
          FutureBuilder<List<DrugWarning>>(
            future: _warningsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _SectionCard(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.warning,
                  title: '주의 정보',
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _SectionCard(
                  icon: Icons.error_outline,
                  iconColor: AppColors.danger,
                  title: '주의 정보',
                  child: Text(
                    '주의 정보 조회 실패: ${snapshot.error}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.danger),
                  ),
                );
              }
              final warnings = snapshot.data ?? [];
              if (warnings.isEmpty) {
                return _SectionCard(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.success,
                  title: '주의 정보',
                  child: Text(
                    '제품코드 ${drug.displayCode.isEmpty ? '-' : drug.displayCode} /'
                        ' 성분코드 ${drug.ingredientCode.isEmpty ? '-' : drug.ingredientCode}'
                        ' 기준으로 조회된 주요 주의 정보가 없습니다.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint, height: 1.5),
                  ),
                );
              }
              return _SectionCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                title: '주의 정보 ${warnings.length}건',
                child: Column(
                  children: warnings
                      .map((w) => _WarningTile(warning: w))
                      .toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── 복용 설정 ──────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.schedule_outlined,
            iconColor: AppColors.lavender,
            title: '복용 알림 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 약 표시 이름
                const _SettingLabel('약 표시 이름'),
                const SizedBox(height: 4),
                const Text(
                  '캘린더·약봉투에 표시될 이름을 수정할 수 있어요',
                  style: TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customNameController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    hintText: '약 표시 이름 입력',
                    prefixIcon: Icon(Icons.edit_outlined, size: 16, color: AppColors.lavender),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 14),

                // 시간대
                const _SettingLabel('복용 시간대'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _MealSlot.values.map((slot) {
                    return _ChoiceChip(
                      label: slot.label,
                      isSelected: _selectedSlots.contains(slot),
                      onTap: () => setState(() {
                        if (_selectedSlots.contains(slot)) {
                          if (_selectedSlots.length > 1) {
                            _selectedSlots.remove(slot);
                          }
                        } else {
                          _selectedSlots.add(slot);
                        }
                      }),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // 식전/식후
                const _SettingLabel('복용 기준'),
                const SizedBox(height: 8),
                Row(
                  children: _MealTiming.values.map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ChoiceChip(
                        label: t.label,
                        isSelected: _mealTiming == t,
                        onTap: () => setState(() => _mealTiming = t),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // 복용 기간
                const _SettingLabel('복용 기간'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _DPreset(days: 3, label: '3일'),
                    _DPreset(days: 7, label: '7일'),
                    _DPreset(days: 14, label: '14일'),
                    _DPreset(days: 30, label: '한달'),
                  ].map((p) {
                    return _ChoiceChip(
                      label: p.label,
                      isSelected: _selectedPresetDays == p.days,
                      onTap: () => _applyPreset(p.days),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: '시작',
                        value: _fmtDate(_startDate),
                        onTap: _pickStart,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateButton(
                        label: '종료',
                        value: _fmtDate(_endDate),
                        onTap: _pickEnd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_fmtDate(_startDate)}부터 ${_fmtDate(_endDate)}까지 복용 일정이 생성됩니다.',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint, height: 1.4),
                ),

                // 선택된 봉투 표시
                if (widget.targetBagId != null) ...[
                  const SizedBox(height: 10),
                  FutureBuilder<List<BagData>>(
                    future: BagService.getBags(),
                    builder: (ctx, snap) {
                      final bags = snap.data ?? [];
                      final bag = bags.firstWhere(
                            (b) => b.id == widget.targetBagId,
                        orElse: () =>
                            BagData(id: 'default', name: '내 약봉투'),
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.lavenderBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.lavenderBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: bag.color,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '저장 위치: ${bag.name}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.lavenderDark),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── 약봉투에 추가 버튼 ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addToBag,
              icon: _isSaving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add, size: 16),
              label: Text(_isSaving ? '저장 중' : '내 약봉투에 추가'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 약봉투에 추가 + 캘린더 자동 생성 ────────────────────────────────────

  Future<void> _addToBag() async {
    setState(() => _isSaving = true);
    try {
      final slots = _selectedSlots.toList()
        ..sort((a, b) => a.hour.compareTo(b.hour));
      final instruction =
          '${slots.map((s) => s.label).join(', ')} ${_mealTiming.label} 복용 · '
          '${_fmtDate(_startDate)}~${_fmtDate(_endDate)}';

      final medication = await MedicationService.addMedication(
        drug: widget.drug,
        customName: _customNameController.text.trim().isNotEmpty
            ? _customNameController.text.trim()
            : widget.drug.name,
        instruction: instruction,
        durationDays: _durationDays,
        startDate: _startDate,
        endDate: _endDate,
        scheduleTimes: slots.map((s) => s.scheduleTime).toList(),
        mealTimingLabel: _mealTiming.label,
      );

      // 봉투 할당
      final bagId = widget.targetBagId ?? 'default';
      await BagService.assignMedication(medication.id, bagId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.drug.name}을(를) 약봉투와 캘린더에 저장했습니다.\n'
                '${_fmtDate(_startDate)} ~ ${_fmtDate(_endDate)}',
          ),
          backgroundColor: AppColors.lavender,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('약봉투 저장 실패: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 날짜 유틸 ─────────────────────────────────────────────────────────────

  int get _durationDays => _endDate.difference(_startDate).inDays + 1;

  void _applyPreset(int days) {
    setState(() {
      _selectedPresetDays = days;
      _endDate = DateTime(
          _startDate.year, _startDate.month, _startDate.day + days - 1);
    });
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_selectedPresetDays > 0) {
        _endDate = DateTime(_startDate.year, _startDate.month,
            _startDate.day + _selectedPresetDays - 1);
      } else if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
      _selectedPresetDays = _matchPreset;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      _selectedPresetDays = _matchPreset;
    });
  }

  int get _matchPreset =>
      const [3, 7, 14, 30].contains(_durationDays) ? _durationDays : 0;

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

// ─── 내부 데이터 클래스 ───────────────────────────────────────────────────────

class _DPreset {
  final int days;
  final String label;
  const _DPreset({required this.days, required this.label});
}

enum _MealSlot {
  breakfast, lunch, dinner;

  String get label {
    switch (this) {
      case _MealSlot.breakfast: return '아침';
      case _MealSlot.lunch:     return '점심';
      case _MealSlot.dinner:    return '저녁';
    }
  }

  int get hour {
    switch (this) {
      case _MealSlot.breakfast: return 9;
      case _MealSlot.lunch:     return 12;
      case _MealSlot.dinner:    return 18;
    }
  }

  String get timeText     => '${hour.toString().padLeft(2, '0')}:00';
  String get scheduleTime => '${hour.toString().padLeft(2, '0')}:00:00';
}

enum _MealTiming {
  before, after;

  String get label {
    switch (this) {
      case _MealTiming.before: return '식전';
      case _MealTiming.after:  return '식후';
    }
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────────────────────

class _SettingLabel extends StatelessWidget {
  final String text;
  const _SettingLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ChoiceChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lavender : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
            isSelected ? AppColors.lavender : AppColors.lavenderBorder,
            width: 0.7,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : AppColors.lavenderDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton(
      {required this.label, required this.value, required this.onTap});

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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  const _SectionCard(
      {required this.icon,
        required this.iconColor,
        required this.title,
        required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 0.5, color: AppColors.cardBorder),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  final DrugWarning warning;
  const _WarningTile({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warning.isHighRisk ? AppColors.danger : AppColors.warning;
    final bg =
    warning.isHighRisk ? AppColors.dangerBg : AppColors.warningBg;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: color),
            const SizedBox(width: 5),
            Text(warning.title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const Spacer(),
            Text(warning.severity,
                style: TextStyle(fontSize: 10, color: color)),
          ]),
          const SizedBox(height: 6),
          Text(warning.message,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  height: 1.5)),
        ],
      ),
    );
  }
}