import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/services/drug_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class DrugDetailScreen extends StatefulWidget {
  final DrugInfo drug;

  const DrugDetailScreen({super.key, required this.drug});

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

  @override
  void initState() {
    super.initState();
    _warningsFuture = DrugService.fetchWarnings(widget.drug);
    _ingredientNameFuture = DrugService.fetchIngredientName(widget.drug);
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day + 6);
  }

  @override
  Widget build(BuildContext context) {
    final drug = widget.drug;
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
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
          _SectionCard(
            icon: Icons.science_outlined,
            iconColor: AppColors.success,
            title: '성분 확인',
            child: FutureBuilder<String>(
              future: _ingredientNameFuture,
              builder: (context, snapshot) {
                final ingredientName = snapshot.data ?? '';
                final label = ingredientName.isNotEmpty
                    ? '$ingredientName (${drug.ingredientCode})'
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
                    style: const TextStyle(fontSize: 11, color: AppColors.danger),
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
                    '제품코드 ${drug.displayCode.isEmpty ? '- ' : drug.displayCode} / 성분코드 ${drug.ingredientCode.isEmpty ? '- ' : drug.ingredientCode} 기준으로 조회된 주요 주의 정보가 없습니다.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      height: 1.5,
                    ),
                  ),
                );
              }

              return _SectionCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.warning,
                title: '주의 정보 ${warnings.length}건',
                child: Column(
                  children: warnings
                      .map((warning) => _WarningTile(warning: warning))
                      .toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _SectionCard(
            icon: Icons.schedule_outlined,
            iconColor: AppColors.lavender,
            title: '복용 알림 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '복용 시간대',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
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
                const Text(
                  '복용 기준',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _MealTiming.values.map((timing) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ChoiceChip(
                        label: timing.label,
                        isSelected: _mealTiming == timing,
                        onTap: () => setState(() => _mealTiming = timing),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedSlots
                      .map((slot) => '${slot.label} ${slot.timeText}')
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '복용 기간',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _DurationPreset(days: 3, label: '3일'),
                    _DurationPreset(days: 7, label: '7일'),
                    _DurationPreset(days: 14, label: '14일'),
                    _DurationPreset(days: 30, label: '한달'),
                  ].map((preset) {
                    return _ChoiceChip(
                      label: preset.label,
                      isSelected: _selectedPresetDays == preset.days,
                      onTap: () => _applyPreset(preset.days),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: '시작',
                        value: _formatDate(_startDate),
                        onTap: () => _pickStartDate(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateButton(
                        label: '종료',
                        value: _formatDate(_endDate),
                        onTap: () => _pickEndDate(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '캘린더에는 ${_formatDate(_startDate)}부터 ${_formatDate(_endDate)}까지만 복용 일정이 생성됩니다.',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addToBag,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 16),
              label: Text(_isSaving ? '저장 중' : '내 약봉투에 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToBag() async {
    setState(() => _isSaving = true);
    try {
      final slots = _selectedSlots.toList()
        ..sort((a, b) => a.hour.compareTo(b.hour));
      final timeLabels = slots.map((slot) => slot.label).join(', ');
      final instruction =
          '$timeLabels ${_mealTiming.label} 복용 · ${_formatDate(_startDate)}~${_formatDate(_endDate)}';
      await MedicationService.addMedication(
        drug: widget.drug,
        instruction: instruction,
        durationDays: _durationDays,
        startDate: _startDate,
        endDate: _endDate,
        scheduleTimes: slots.map((slot) => slot.scheduleTime).toList(),
        mealTimingLabel: _mealTiming.label,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내 약봉투에 저장했습니다.'),
          backgroundColor: AppColors.lavender,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('약봉투 저장 실패: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int get _durationDays => _endDate.difference(_startDate).inDays + 1;

  void _applyPreset(int days) {
    setState(() {
      _selectedPresetDays = days;
      _endDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day + days - 1,
      );
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      final presetDays = _selectedPresetDays;
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (presetDays > 0) {
        _endDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day + presetDays - 1,
        );
      } else if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
      _selectedPresetDays = _matchingPresetDays;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      _selectedPresetDays = _matchingPresetDays;
    });
  }

  int get _matchingPresetDays {
    final days = _durationDays;
    return const [3, 7, 14, 30].contains(days) ? days : 0;
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _DurationPreset {
  final int days;
  final String label;

  const _DurationPreset({required this.days, required this.label});
}

enum _MealSlot {
  breakfast,
  lunch,
  dinner;

  String get label {
    switch (this) {
      case _MealSlot.breakfast:
        return '아침';
      case _MealSlot.lunch:
        return '점심';
      case _MealSlot.dinner:
        return '저녁';
    }
  }

  int get hour {
    switch (this) {
      case _MealSlot.breakfast:
        return 9;
      case _MealSlot.lunch:
        return 12;
      case _MealSlot.dinner:
        return 18;
    }
  }

  String get timeText => '${hour.toString().padLeft(2, '0')}:00';

  String get scheduleTime => '${hour.toString().padLeft(2, '0')}:00:00';
}

enum _MealTiming {
  before,
  after;

  String get label {
    switch (this) {
      case _MealTiming.before:
        return '식전';
      case _MealTiming.after:
        return '식후';
    }
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

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
            color: isSelected ? AppColors.lavender : AppColors.lavenderBorder,
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

  const _DateButton({
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.lavenderDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: AppColors.lavender,
            ),
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

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

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
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 0.5, color: AppColors.divider),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
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
    final bg = warning.isHighRisk ? AppColors.dangerBg : AppColors.warningBg;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                warning.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                warning.severity,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            warning.message,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
