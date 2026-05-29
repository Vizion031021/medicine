import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/screens/drug_detail_screen.dart';
import 'package:sseudeuson/services/bag_service.dart';
import 'package:sseudeuson/services/drug_service.dart';
import 'package:sseudeuson/services/medication_service.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<DrugInfo> _results = [];
  List<DrugInfo> _extraCompareDrugs = [];
  List<DrugWarning> _compareWarnings = [];
  List<UserMedication> _myMedications = [];
  List<BagData> _bags = [];
  Map<String, String> _assignments = {};
  String? _selectedBagId;
  bool _isLoading = false;
  bool _isComparing = false;
  bool _isLoadingMyMeds = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _search('');
    _loadMyMedications();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await DrugService.searchDrugs(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '약 검색 실패: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyMedications() async {
    setState(() => _isLoadingMyMeds = true);
    try {
      final results = await Future.wait([
        MedicationService.fetchMyMedications(),
        BagService.getBags(),
        BagService.getAssignments(),
      ]);
      final meds = results[0] as List<UserMedication>;
      final bags = results[1] as List<BagData>;
      final assignments = results[2] as Map<String, String>;
      final selectedBagId =
          _selectedBagId ?? (bags.isNotEmpty ? bags.first.id : null);

      if (mounted) {
        setState(() {
          _myMedications = meds;
          _bags = bags;
          _assignments = assignments;
          _selectedBagId = selectedBagId;
          _compareWarnings = [];
        });
        await _refreshCompareWarnings();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _myMedications = [];
          _bags = [];
          _assignments = {};
          _selectedBagId = null;
          _extraCompareDrugs = [];
          _compareWarnings = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingMyMeds = false);
    }
  }

  Future<void> _toggleCompare(DrugInfo drug) async {
    final key = _drugKey(drug);
    if (_selectedBagDrugs.any((item) => _drugKey(item) == key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 선택한 약봉투에 들어있는 약입니다.')),
      );
      return;
    }

    setState(() {
      if (_extraCompareDrugs.any((item) => _drugKey(item) == key)) {
        _extraCompareDrugs = _extraCompareDrugs
            .where((item) => _drugKey(item) != key)
            .toList();
      } else {
        _extraCompareDrugs = [..._extraCompareDrugs, drug];
      }
      _compareWarnings = [];
    });

    await _refreshCompareWarnings();
  }

  Future<void> _refreshCompareWarnings() async {
    final comparisonDrugs = _comparisonDrugs;
    if (_extraCompareDrugs.isEmpty || comparisonDrugs.length < 2) {
      if (mounted) {
        setState(() {
          _compareWarnings = [];
          _isComparing = false;
        });
      }
      return;
    }

    setState(() => _isComparing = true);
    try {
      final warnings = await DrugService.compareDrugs(comparisonDrugs);
      if (mounted) setState(() => _compareWarnings = warnings);
    } catch (_) {
      if (mounted) setState(() => _compareWarnings = []);
    } finally {
      if (mounted) setState(() => _isComparing = false);
    }
  }

  void _selectBag(String bagId) {
    setState(() {
      _selectedBagId = bagId;
      _extraCompareDrugs = [];
      _compareWarnings = [];
    });
  }

  List<DrugInfo> _drugsForBag({
    required List<UserMedication> meds,
    required Map<String, String> assignments,
    required String? bagId,
  }) {
    if (bagId == null) return [];
    return meds
        .where((med) => (assignments[med.id] ?? 'default') == bagId)
        .map((med) => med.drug)
        .whereType<DrugInfo>()
        .toList();
  }

  String _drugKey(DrugInfo drug) =>
      drug.displayCode.isNotEmpty ? drug.displayCode : drug.name;

  List<DrugInfo> get _selectedBagDrugs => _drugsForBag(
    meds: _myMedications,
    assignments: _assignments,
    bagId: _selectedBagId,
  );

  List<DrugInfo> get _comparisonDrugs => [
    ..._selectedBagDrugs,
    ..._extraCompareDrugs,
  ];

  BagData? get _selectedBag {
    for (final bag in _bags) {
      if (bag.id == _selectedBagId) return bag;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '약 검색',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '상품명, 업체명, 표준코드 검색',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.lavender,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            _buildMyMedicationPanel(),
            if (_selectedBagDrugs.isNotEmpty || _extraCompareDrugs.isNotEmpty)
              _buildComparePanel(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMedicationPanel() {
    if (_isLoadingMyMeds) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (_bags.isEmpty) return const SizedBox.shrink();
    final selectedBagId = _selectedBagId ?? _bags.first.id;
    final meds = _myMedications
        .where((med) =>
    (med.drug != null) &&
        ((_assignments[med.id] ?? 'default') == selectedBagId))
        .toList();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '비교할 약봉투 선택',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _bags.map((bag) {
                final selected = bag.id == selectedBagId;
                final count = _myMedications
                    .where((med) => (_assignments[med.id] ?? 'default') == bag.id)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text('${bag.name} $count'),
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: bag.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onSelected: (_) => _selectBag(bag.id),
                    selectedColor: AppColors.lavenderBg,
                    side: BorderSide(
                      color: selected
                          ? AppColors.lavender
                          : AppColors.cardBorder,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? AppColors.lavenderDark
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (meds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '선택한 약봉투에 담긴 약이 없습니다.',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: meds.map((med) {
                return Chip(
                  label: Text(
                    med.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: AppColors.lavenderBg,
                  side: BorderSide(
                    color: AppColors.lavender.withValues(alpha: 0.45),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 10,
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없습니다.',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                '검색 결과 ${_results.length}건',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              if (_isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
        ..._results.map((drug) {
          final key = _drugKey(drug);
          final isInSelectedBag =
          _selectedBagDrugs.any((item) => _drugKey(item) == key);
          final isExtraSelected =
          _extraCompareDrugs.any((item) => _drugKey(item) == key);
          return _DrugResultCard(
            drug: drug,
            isSelected: isInSelectedBag || isExtraSelected,
            isInSelectedBag: isInSelectedBag,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DrugDetailScreen(drug: drug),
              ),
            ),
            onCompareTap: () => _toggleCompare(drug),
          );
        }),
      ],
    );
  }

  Widget _buildComparePanel() {
    final selectedBag = _selectedBag;
    final selectedBagDrugs = _selectedBagDrugs;
    final hasExtraDrugs = _extraCompareDrugs.isNotEmpty;

    return Container(
      color: AppColors.lavenderBg,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows_rounded,
                size: 16,
                color: AppColors.lavender,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedBag == null
                      ? '비교할 약봉투를 선택하세요'
                      : '기준 약봉투: ${selectedBag.name} (${selectedBagDrugs.length}개)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasExtraDrugs)
                InkWell(
                  onTap: () => setState(() {
                    _extraCompareDrugs = [];
                    _compareWarnings = [];
                  }),
                  child: const Text(
                    '추가 선택 초기화',
                    style: TextStyle(fontSize: 11, color: AppColors.lavender),
                  ),
                ),
            ],
          ),
          if (selectedBagDrugs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                '검색 결과에서 새 약을 선택하면 이 약봉투와 비교합니다.',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ),
          if (hasExtraDrugs)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '추가 비교 약: ${_extraCompareDrugs.map((drug) => drug.name).join(' + ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_isComparing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (hasExtraDrugs && !_isComparing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _compareWarnings.isEmpty
                    ? '선택한 약봉투와 새 약 사이에서 DB 기준 확인된 병용금기/성분중복/효능군중복 정보가 없습니다.'
                    : _compareWarnings.map((warning) => warning.message).join('\n'),
                style: TextStyle(
                  fontSize: 10,
                  color: _compareWarnings.isEmpty
                      ? AppColors.success
                      : AppColors.danger,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrugResultCard extends StatelessWidget {
  final DrugInfo drug;
  final bool isSelected;
  final bool isInSelectedBag;
  final VoidCallback onTap;
  final VoidCallback onCompareTap;

  const _DrugResultCard({
    required this.drug,
    required this.isSelected,
    required this.isInSelectedBag,
    required this.onTap,
    required this.onCompareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.lavender : AppColors.cardBorder,
          width: isSelected ? 1.2 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drug.company.isEmpty ? '업체 정보 없음' : drug.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _MiniBadge(label: drug.prescriptionType),
                        _MiniBadge(label: drug.formType),
                        _MiniBadge(label: drug.displayCode),
                        if (isInSelectedBag) const _MiniBadge(label: '선택한 약봉투'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isInSelectedBag ? '선택한 약봉투에 포함됨' : '비교 약 선택',
                onPressed: onCompareTap,
                icon: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: isSelected ? AppColors.lavender : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: AppColors.lavenderDark),
      ),
    );
  }
}