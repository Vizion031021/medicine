import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/screens/drug_detail_screen.dart';
import 'package:sseudeuson/services/drug_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

// ─── 약 비교 화면 (4번째 탭) ─────────────────────────────────────────────────
//
// 기능:
//   ① 약봉투에 있는 내 약물 칩으로 바로 추가
//   ② 검색으로 약물 추가
//   ③ [위험도 분석] 버튼 → dosage_warning + combo + 성분 중복 + 임부 금기 표시
//   ④ 분석 결과: 고위험(빨강) / 중위험(주황) 구분 카드

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<DrugInfo> _searchResults = [];
  final List<DrugInfo> _selected = [];

  List<UserMedication> _myMeds = [];
  List<DrugWarning> _results = [];

  bool _isSearching = false;
  bool _isAnalyzing = false;
  bool _showResults = false;
  bool _loadingMyMeds = true;

  @override
  void initState() {
    super.initState();
    _loadMyMeds();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyMeds() async {
    setState(() => _loadingMyMeds = true);
    try {
      final meds = await MedicationService.fetchMyMedications();
      if (mounted) setState(() => _myMeds = meds);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMyMeds = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value),
    );
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final res = await DrugService.searchDrugs(query, limit: 15);
      if (mounted) setState(() => _searchResults = res);
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addDrug(DrugInfo drug) {
    if (_selected.any((d) => d.displayCode == drug.displayCode)) return;
    setState(() {
      _selected.add(drug);
      _searchResults = [];
      _searchCtrl.clear();
      _showResults = false;
      _results = [];
    });
  }

  void _removeDrug(DrugInfo drug) {
    setState(() {
      _selected.removeWhere((d) => d.displayCode == drug.displayCode);
      _showResults = false;
      _results = [];
    });
  }

  // ── 분석 ─────────────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    if (_selected.isEmpty) return;
    setState(() {
      _isAnalyzing = true;
      _showResults = false;
    });
    try {
      final all = <DrugWarning>[];

      // 약물별 개별 경고 (용량, 투여기간, 임부금기, 효능군)
      for (final drug in _selected) {
        final warnings = await DrugService.fetchWarnings(drug);
        all.addAll(warnings);
      }

      // 약물 간 비교 (병용금기, 성분중복, ATC중복)
      if (_selected.length >= 2) {
        final compare = await DrugService.compareDrugs(_selected);
        all.insertAll(0, compare);
      }

      // 중복 제거 (같은 title+message)
      final seen = <String>{};
      final deduped = all.where((w) {
        final key = '${w.title}|${w.message}';
        return seen.add(key);
      }).toList();

      // 고위험 우선 정렬
      deduped.sort((a, b) {
        if (a.isHighRisk == b.isHighRisk) return 0;
        return a.isHighRisk ? -1 : 1;
      });

      if (mounted) {
        setState(() {
          _results = deduped;
          _showResults = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분석 실패: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 + 검색바 ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '약 비교',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '약봉투에서 선택하거나 검색하여 복용 위험도를 분석하세요',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '③ 상품명, 성분명, 업체명으로 검색하여 추가',
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: AppColors.lavender),
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
                  // 검색 결과 드롭다운
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.cardBorder, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0.5, indent: 14, endIndent: 14),
                        itemBuilder: (ctx, i) {
                          final drug = _searchResults[i];
                          final added = _selected
                              .any((d) => d.displayCode == drug.displayCode);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            title: Text(drug.name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              _drugSubtitle(drug),
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: added
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.lavender, size: 18)
                                : const Icon(Icons.add_circle_outline,
                                    color: AppColors.lavender, size: 18),
                            onTap: added ? null : () => _addDrug(drug),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 0.5, color: AppColors.cardBorder),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                children: [
                  // ① 내 약봉투에서 추가 ─────────────────────────────────
                  _buildMyMedsSection(),
                  const SizedBox(height: 14),

                  // ② 선택된 약물 목록 ────────────────────────────────────
                  if (_selected.isNotEmpty) ...[
                    _buildSelectedSection(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _analyze,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.science_outlined, size: 18),
                        label: Text(_isAnalyzing ? '분석 중...' : '위험도 분석'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    _buildEmptyState(),
                    const SizedBox(height: 14),
                  ],

                  // ④ 분석 결과 ─────────────────────────────────────────
                  if (_showResults) _buildResultSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ① 내 약봉투 칩 ───────────────────────────────────────────────────────

  Widget _buildMyMedsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '① 내 약봉투에서 추가',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            if (_loadingMyMeds)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        if (_myMeds.isEmpty && !_loadingMyMeds)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lavenderBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
            ),
            child: const Text(
              '약봉투에 등록된 약이 없습니다.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _myMeds.map((med) {
              final drug = med.drug;
              if (drug == null) return const SizedBox.shrink();
              final isAdded =
                  _selected.any((d) => d.displayCode == drug.displayCode);
              return GestureDetector(
                onTap: isAdded ? () => _removeDrug(drug) : () => _addDrug(drug),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdded ? AppColors.lavender : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAdded
                          ? AppColors.lavender
                          : AppColors.lavenderBorder,
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        size: 13,
                        color: isAdded ? Colors.white : AppColors.lavender,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        med.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: isAdded
                              ? Colors.white
                              : AppColors.lavenderDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ── ② 선택된 약물 목록 ───────────────────────────────────────────────────

  Widget _buildSelectedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '② 비교 약물 ${_selected.length}개',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _selected.clear();
                _showResults = false;
                _results = [];
              }),
              child: const Text('초기화',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._selected.map(
          (drug) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lavenderBorder, width: 0.7),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DrugDetailScreen(drug: drug)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drug.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          _drugSubtitle(drug),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: AppColors.textHint),
                  onPressed: () => _removeDrug(drug),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 빈 상태 ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lavenderBorder, width: 0.5),
      ),
      child: const Column(
        children: [
          Icon(Icons.compare_arrows_rounded,
              size: 36, color: AppColors.lavenderDark),
          SizedBox(height: 8),
          Text('비교할 약을 추가하세요',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.lavenderDark,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('내 약봉투 칩을 탭하거나 위 검색창을 이용하세요',
              style: TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }

  // ── ④ 분석 결과 ──────────────────────────────────────────────────────────

  Widget _buildResultSection() {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.success.withOpacity(0.3), width: 0.5),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'DB 기준으로 확인된 주요 위험 정보가 없습니다.\n실제 복용 전 반드시 의사 · 약사와 상담하세요.',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    final high = _results.where((w) => w.isHighRisk).toList();
    final mid = _results.where((w) => !w.isHighRisk).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '분석 결과 ${_results.length}건',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            if (high.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '고위험 ${high.length}건',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // 고위험 먼저
        ...high.map((w) => _WarningCard(warning: w)),
        // 중위험
        ...mid.map((w) => _WarningCard(warning: w)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lavenderBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '⚠ 이 결과는 DB 기반 참고 정보입니다. 실제 복용 전 반드시 의사·약사와 상담하세요.',
            style: TextStyle(
                fontSize: 10, color: AppColors.lavenderDark, height: 1.5),
          ),
        ),
      ],
    );
  }

  String _drugSubtitle(DrugInfo drug) {
    final parts = <String>[];
    if (drug.prescriptionType.isNotEmpty) parts.add(drug.prescriptionType);
    if (drug.formType.isNotEmpty) parts.add(drug.formType);
    if (drug.company.isNotEmpty && drug.formType.isEmpty) parts.add(drug.company);
    return parts.join(' · ');
  }
}

// ─── 경고 카드 ────────────────────────────────────────────────────────────────

class _WarningCard extends StatelessWidget {
  final DrugWarning warning;
  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final isHigh = warning.isHighRisk;
    final color = isHigh ? AppColors.danger : AppColors.warning;
    final bg = isHigh ? AppColors.dangerBg : AppColors.warningBg;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHigh
                    ? Icons.dangerous_outlined
                    : Icons.warning_amber_rounded,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  warning.title,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '위험도 ${warning.severity}',
                  style: TextStyle(fontSize: 9, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            warning.message,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
