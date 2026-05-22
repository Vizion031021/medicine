import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/screens/bag_detail_screen.dart';
import 'package:sseudeuson/screens/search_screen.dart';
import 'package:sseudeuson/services/medication_service.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({super.key});

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late List<MedicineBag> _bags;
  List<UserSchedule> _todaySchedules = [];
  final Set<String> _expandedBags = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bags = [];
    _loadBags();
  }

  Future<void> _loadBags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final medications = await MedicationService.fetchMyMedications();
      final now = DateTime.now();
      final todaySchedules = await ScheduleService.fetchSchedules(
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      final medicines = medications.map((item) {
        final drug = item.drug;
        return Medicine(
          id: item.id,
          name: item.displayName,
          englishName: drug?.company ?? '',
          category: drug?.prescriptionType ?? '',
          dosage: drug?.specification ?? '',
          memo: item.instruction,
          cautions: [
            if (drug?.productCode.isNotEmpty == true) '제품코드: ${drug!.productCode}',
            if (drug?.ingredientCode.isNotEmpty == true) '성분명코드: ${drug!.ingredientCode}',
            if (drug?.atcCode.isNotEmpty == true) 'ATC 코드: ${drug!.atcCode}',
          ],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _bags = [
          MedicineBag(
            id: 'supabase-bag',
            name: '내 약봉투',
            color: AppColors.lavender,
            medicines: medicines,
          ),
        ];
        _todaySchedules = todaySchedules;
        _expandedBags.add('supabase-bag');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '약봉투 조회 실패: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '약봉투 관리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '복용중인 약 · 탭하여 상세 보기 · 부작용 자동 검사',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 58,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.lavender),
            onPressed: _navigateToAdd,
          ),
        ],
      ),
      body: _isLoading
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                  children: [
                    _TodayStatusCard(
                      schedules: _todaySchedules,
                      onToggle: _toggleScheduleTaken,
                    ),
                    if (_bags.every((bag) => bag.medicines.isEmpty))
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          '아직 저장된 약이 없습니다. 검색 탭에서 약을 찾아 약봉투에 추가해보세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ..._bags.map(
                      (bag) => _BagCard(
                        bag: bag,
                        isExpanded: _expandedBags.contains(bag.id),
                        onToggle: () => setState(() {
                          if (_expandedBags.contains(bag.id)) {
                            _expandedBags.remove(bag.id);
                          } else {
                            _expandedBags.add(bag.id);
                          }
                        }),
                        onMedicineTap: (medicine) =>
                            _navigateToDetail(medicine),
                        onMedicineDelete: _removeMedication,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _navigateToAdd,
                      icon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.lavender,
                      ),
                      label: const Text(
                        '검색해서 약 추가',
                        style: TextStyle(
                          color: AppColors.lavender,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.lavenderBorder,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _toggleScheduleTaken(UserSchedule schedule) async {
    await ScheduleService.setTaken(
      scheduleId: schedule.id,
      isTaken: !schedule.isTaken,
    );
    await _loadBags();
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    ).then((_) => _loadBags());
  }

  void _navigateToDetail(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BagDetailScreen(medicine: medicine),
      ),
    );
  }

  Future<void> _removeMedication(Medicine medicine) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('약봉투에서 빼기'),
        content: Text('${medicine.name}을(를) 약봉투에서 뺄까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '빼기',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    try {
      await MedicationService.deactivateMedication(medicine.id);
      await _loadBags();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medicine.name}을(를) 약봉투에서 뺐습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('약 삭제 실패: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _TodayStatusCard extends StatelessWidget {
  final List<UserSchedule> schedules;
  final ValueChanged<UserSchedule> onToggle;

  const _TodayStatusCard({
    required this.schedules,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = schedules.where((item) => item.isTaken).length;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘 복용 확인',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$doneCount / ${schedules.length} 복용',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.lavenderDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (schedules.isEmpty)
            const Text(
              '오늘 예정된 복용 일정이 없습니다.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            )
          else
            ...schedules.map((schedule) => _TodayScheduleRow(
                  schedule: schedule,
                  onToggle: () => onToggle(schedule),
                )),
        ],
      ),
    );
  }
}

class _TodayScheduleRow extends StatelessWidget {
  final UserSchedule schedule;
  final VoidCallback onToggle;

  const _TodayScheduleRow({
    required this.schedule,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final medication = schedule.medication;
    final mealLabel = _mealLabelFromTime(schedule.time);
    final mealTiming = _mealTimingFromInstruction(medication?.instruction ?? '');
    final timeText = _formatTime(schedule.time);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _MealBadge(label: mealLabel, time: timeText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication?.displayName ?? '등록 약',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$mealLabel $mealTiming 복용',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: schedule.isTaken ? AppColors.lavender : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: schedule.isTaken
                      ? AppColors.lavender
                      : AppColors.lavenderBorder,
                  width: 1.5,
                ),
              ),
              child: schedule.isTaken
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _mealLabelFromTime(String time) {
    final hour = int.tryParse(time.split(':').first) ?? 9;
    if (hour < 11) return '아침';
    if (hour < 16) return '점심';
    return '저녁';
  }

  String _mealTimingFromInstruction(String instruction) {
    if (instruction.contains('식전')) return '식전';
    if (instruction.contains('식후')) return '식후';
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

// ─── 약봉투 카드 ─────────────────────────────────────────────────────────────

class _BagCard extends StatelessWidget {
  final MedicineBag bag;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<Medicine> onMedicineTap;
  final ValueChanged<Medicine> onMedicineDelete;

  const _BagCard({
    required this.bag,
    required this.isExpanded,
    required this.onToggle,
    required this.onMedicineTap,
    required this.onMedicineDelete,
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
          // 헤더 (탭하여 펼침/접힘)
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // 봉투 색상 점
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: bag.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 봉투 이름
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bag.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '약물 ${bag.medicines.length}종',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상태 배지
                  _StatusBadge(hasWarning: bag.hasWarning),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 펼쳐진 내용
          if (isExpanded) ...[
            const Divider(height: 0.5, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '아래 약을 탭하면 상호작용·주의사항·부작용을 확인할 수 있어요',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 약물 칩들
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: bag.medicines.map((med) {
                      return Container(
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 4,
                          top: 4,
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lavenderBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => onMedicineTap(med),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      med.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.lavenderDark,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 12,
                                      color: AppColors.lavenderDark,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: () => onMedicineDelete(med),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 13,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  // 경고 스트립
                  if (bag.hasWarning) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getWarningText(bag),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF854F0B),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 13),
                          SizedBox(width: 5),
                          Text(
                            '심각한 상호작용 없음',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
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

  String _getWarningText(MedicineBag bag) {
    for (final med in bag.medicines) {
      for (final interaction in med.interactions) {
        final hasDrug2 = bag.medicines.any((m) => m.name.contains(
            interaction.drug2.split(' ').first));
        if (hasDrug2 &&
            interaction.severity != InteractionSeverity.safe) {
          return '${interaction.drug1} + ${interaction.drug2}: ${interaction.description}';
        }
      }
    }
    return '상호작용 주의사항이 있습니다. 의사와 상담하세요.';
  }
}

// ─── 상태 배지 ───────────────────────────────────────────────────────────────

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
        hasWarning ? '⚠ 주의' : '✓ 안전',
        style: TextStyle(
          fontSize: 10,
          color: hasWarning
              ? const Color(0xFF854F0B)
              : const Color(0xFF2E7D32),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
