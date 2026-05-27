import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';

class BagDetailScreen extends StatelessWidget {
  final Medicine medicine;

  const BagDetailScreen({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.lavender),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicine.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${medicine.englishName} · ${medicine.category}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        children: [
          // ── 복용방법 ──
          _SectionCard(
            icon: Icons.medication_outlined,
            iconColor: AppColors.lavender,
            title: '복용방법',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoBadge(
                      label: medicine.timesOfDay.map((t) => t.label).join('·'),
                    ),
                    _InfoBadge(label: medicine.mealTiming.label),
                    _InfoBadge(label: '1일 ${medicine.dailyCount}회'),
                    _InfoBadge(
                      label: medicine.durationDays == 0
                          ? '계속 복용'
                          : '${medicine.durationDays}일 처방',
                    ),
                  ],
                ),
                if (medicine.memo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderBg,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(
                          color: AppColors.lavender,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      '메모: ${medicine.memo}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.lavenderDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 주의사항 ──
          _SectionCard(
            icon: Icons.shield_outlined,
            iconColor: AppColors.warning,
            title: '주의사항',
            child: medicine.cautions.isEmpty
                ? const Text(
                    '주의사항 정보가 없습니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: medicine.cautions.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '·  ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // ── 부작용 ──
          _SectionCard(
            icon: Icons.health_and_safety_outlined,
            iconColor: AppColors.danger,
            title: '부작용',
            child: medicine.sideEffects.isEmpty
                ? const Text(
                    '부작용 정보가 없습니다.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: medicine.sideEffects.map((se) {
                      Color bg = AppColors.dangerBg;
                      Color fg = const Color(0xFFC62828);
                      if (se.contains('드묾') || se.contains('rare')) {
                        bg = AppColors.lavenderBg;
                        fg = AppColors.lavenderDark;
                      } else if (se.contains('주의') || se.contains('설사') || se.contains('식욕')) {
                        bg = AppColors.warningBg;
                        fg = const Color(0xFF854F0B);
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          se,
                          style: TextStyle(fontSize: 11, color: fg),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 공통 섹션 카드 ──────────────────────────────────────────────────────────

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
              const SizedBox(width: 5),
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

class _InfoBadge extends StatelessWidget {
  final String label;
  const _InfoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.lavenderDark),
      ),
    );
  }
}
