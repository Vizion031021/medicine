import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';
import 'package:sseudeuson/screens/bag_detail_screen.dart';
import 'package:sseudeuson/widgets/interaction_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '혈압약';
  List<Medicine> _searchResults = [];

  // 상호작용 검사를 위해 선택된 약물 (최대 2개)
  final List<Medicine> _selectedForCheck = [];

  final List<String> _categories = ['전체', '혈압약', '당뇨약', '위장약', '소염진통제', '항생제'];

  @override
  void initState() {
    super.initState();
    _filterByCategory('혈압약');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == '전체') {
        _searchResults = DummyData.searchableMedicines;
      } else {
        _searchResults = DummyData.searchableMedicines
            .where((m) => m.category.contains(
                  category == '혈압약'
                      ? '혈압'
                      : category == '당뇨약'
                          ? '당뇨'
                          : category == '위장약'
                              ? '위장'
                              : category == '소염진통제'
                                  ? '소염'
                                  : '항생',
                ))
            .toList();
      }
    });
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      _filterByCategory(_selectedCategory);
      return;
    }
    setState(() {
      _searchResults = DummyData.searchableMedicines
          .where((m) =>
              m.name.contains(query) ||
              m.englishName.toLowerCase().contains(query.toLowerCase()) ||
              m.category.contains(query))
          .toList();
    });
  }

  void _toggleForCheck(Medicine med) {
    setState(() {
      if (_selectedForCheck.any((m) => m.id == med.id)) {
        _selectedForCheck.removeWhere((m) => m.id == med.id);
      } else if (_selectedForCheck.length < 2) {
        _selectedForCheck.add(med);
      } else {
        // 2개 이미 선택 시 첫 번째 제거하고 새 약 추가
        _selectedForCheck.removeAt(0);
        _selectedForCheck.add(med);
      }
    });
  }

  List<DrugInteraction> _getInteractionsForSelected() {
    if (_selectedForCheck.length < 2) return [];
    final interactions = <DrugInteraction>[];
    for (final med in _selectedForCheck) {
      for (final interaction in med.interactions) {
        final otherMed = _selectedForCheck.firstWhere(
          (m) => m.id != med.id,
          orElse: () => med,
        );
        if (otherMed.id != med.id &&
            (otherMed.name.contains(interaction.drug2.split(' ').first) ||
                interaction.drug2.contains(otherMed.name.split(' ').first))) {
          if (!interactions.any(
            (i) => i.drug1 == interaction.drug1 && i.drug2 == interaction.drug2,
          )) {
            interactions.add(interaction);
          }
        }
      }
    }
    // 상호작용이 없으면 안전 결과 반환
    if (interactions.isEmpty && _selectedForCheck.length == 2) {
      interactions.add(DrugInteraction(
        drug1: _selectedForCheck[0].name.split(' ').first,
        drug2: _selectedForCheck[1].name.split(' ').first,
        severity: InteractionSeverity.safe,
        description:
            '두 약물 간 알려진 주요 상호작용이 없습니다. 일반적으로 안전하게 병용 가능하지만, 의사/약사와 상담하세요.',
      ));
    }
    return interactions;
  }

  @override
  Widget build(BuildContext context) {
    final interactions = _getInteractionsForSelected();

    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── 검색 헤더 ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '약물 검색',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 검색창
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: '약품명 또는 성분명 검색',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.lavender,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: AppColors.textHint),
                              onPressed: () {
                                _searchController.clear();
                                _filterByCategory(_selectedCategory);
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // ── 카테고리 필터 ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _filterByCategory(cat),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.lavender
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.lavender
                                  : const Color(0xFFDDDDDD),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 0.5, color: AppColors.lavenderBg),

            // ── 상호작용 검사 선택 배너 ──
            if (_selectedForCheck.isNotEmpty)
              _buildSelectionBanner(),

            // ── 결과 목록 + 상호작용 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                children: [
                  // 결과 수
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '검색 결과 ${_searchResults.length}건',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  // 검색 결과
                  ..._searchResults.map((med) => _SearchResultCard(
                        medicine: med,
                        isSelectedForCheck: _selectedForCheck.any(
                          (m) => m.id == med.id,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BagDetailScreen(medicine: med),
                          ),
                        ),
                        onLongPress: () => _toggleForCheck(med),
                        onCheckToggle: () => _toggleForCheck(med),
                      )),

                  // ── 상호작용 결과 ──
                  if (interactions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '상호작용 검사 결과',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...interactions.map(
                      (interaction) => _InteractionResultCard(
                        interaction: interaction,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 내 약봉투와 비교 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('약봉투 비교 기능은 준비 중입니다.'),
                              backgroundColor: AppColors.lavender,
                            ),
                          );
                        },
                        icon: const Icon(Icons.medication_outlined, size: 16),
                        label: const Text('내 약봉투와 비교하기'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBanner() {
    return Container(
      color: AppColors.lavenderBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows_rounded,
              size: 16, color: AppColors.lavender),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedForCheck.length == 1
                  ? '${_selectedForCheck[0].name.split(' ').first} 선택됨 — 비교할 약을 하나 더 롱탭하세요'
                  : '${_selectedForCheck[0].name.split(' ').first} + ${_selectedForCheck[1].name.split(' ').first} 상호작용 확인 중',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.lavenderDark,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _selectedForCheck.clear()),
            child: const Text(
              '초기화',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.lavender,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 검색 결과 카드 ───────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final Medicine medicine;
  final bool isSelectedForCheck;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckToggle;

  const _SearchResultCard({
    required this.medicine,
    required this.isSelectedForCheck,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelectedForCheck
                ? AppColors.lavenderBg
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelectedForCheck
                  ? AppColors.lavender
                  : AppColors.cardBorder,
              width: isSelectedForCheck ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medicine.englishName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        medicine.category,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.lavenderDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 비교 선택 버튼
              GestureDetector(
                onTap: onCheckToggle,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelectedForCheck
                        ? AppColors.lavender
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelectedForCheck
                          ? AppColors.lavender
                          : AppColors.lavenderBorder,
                      width: 1,
                    ),
                  ),
                  child: isSelectedForCheck
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : const Icon(Icons.add,
                          size: 14, color: AppColors.lavender),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 상호작용 결과 카드 ───────────────────────────────────────────────────────

class _InteractionResultCard extends StatelessWidget {
  final DrugInteraction interaction;
  const _InteractionResultCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: interaction.severity.bgColor.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                InteractionBadge(severity: interaction.severity),
                const SizedBox(width: 8),
                Text(
                  '${interaction.drug1} + ${interaction.drug2}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 내용
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 약물 조합
                Row(
                  children: [
                    _DrugChip(label: interaction.drug1),
                    const SizedBox(width: 7),
                    Text(
                      interaction.severity == InteractionSeverity.safe
                          ? '+'
                          : '✕',
                      style: TextStyle(
                        color: interaction.severity == InteractionSeverity.safe
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _DrugChip(label: interaction.drug2),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  interaction.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.6,
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

class _DrugChip extends StatelessWidget {
  final String label;
  const _DrugChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.lavenderDark),
      ),
    );
  }
}
