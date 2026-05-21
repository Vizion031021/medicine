import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';
import 'package:sseudeuson/screens/bag_add_screen.dart';
import 'package:sseudeuson/screens/bag_detail_screen.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({super.key});

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late List<MedicineBag> _bags;
  final Set<String> _expandedBags = {};

  @override
  void initState() {
    super.initState();
    _bags = DummyData.defaultBags;
    // 첫 번째 봉투는 기본 펼침
    if (_bags.isNotEmpty) _expandedBags.add(_bags.first.id);
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        children: [
          ..._bags.map((bag) => _BagCard(
                bag: bag,
                isExpanded: _expandedBags.contains(bag.id),
                onToggle: () => setState(() {
                  if (_expandedBags.contains(bag.id)) {
                    _expandedBags.remove(bag.id);
                  } else {
                    _expandedBags.add(bag.id);
                  }
                }),
                onMedicineTap: (medicine) => _navigateToDetail(medicine),
                onAddMedicine: () => _navigateToAdd(bag: bag),
              )),
          // 새 봉투 추가 버튼
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _navigateToAdd,
            icon: const Icon(Icons.add, size: 18, color: AppColors.lavender),
            label: const Text(
              '새 약봉투 만들기 / 약 추가',
              style: TextStyle(color: AppColors.lavender, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                  color: AppColors.lavenderBorder, width: 1),
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

  void _navigateToAdd({MedicineBag? bag}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BagAddScreen(targetBag: bag),
      ),
    ).then((_) => setState(() {}));
  }

  void _navigateToDetail(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BagDetailScreen(medicine: medicine),
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
  final VoidCallback onAddMedicine;

  const _BagCard({
    required this.bag,
    required this.isExpanded,
    required this.onToggle,
    required this.onMedicineTap,
    required this.onAddMedicine,
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
                      return InkWell(
                        onTap: () => onMedicineTap(med),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderBg,
                            borderRadius: BorderRadius.circular(10),
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
