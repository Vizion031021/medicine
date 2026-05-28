import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/screens/drug_detail_screen.dart';
import 'package:sseudeuson/services/drug_service.dart';
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
  List<DrugInfo> _selectedForCompare = [];
  List<DrugWarning> _compareWarnings = [];
  bool _isLoading = false;
  bool _isComparing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _search('');
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

  Future<void> _toggleCompare(DrugInfo drug) async {
    setState(() {
      if (_selectedForCompare.any((item) => item.displayCode == drug.displayCode)) {
        _selectedForCompare = _selectedForCompare
            .where((item) => item.displayCode != drug.displayCode)
            .toList();
      } else {
        _selectedForCompare = [..._selectedForCompare, drug];
      }
      _compareWarnings = [];
    });

    if (_selectedForCompare.length >= 2) {
      setState(() => _isComparing = true);
      try {
        final warnings = await DrugService.compareDrugs(_selectedForCompare);
        if (mounted) setState(() => _compareWarnings = warnings);
      } catch (_) {
        if (mounted) setState(() => _compareWarnings = []);
      } finally {
        if (mounted) setState(() => _isComparing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavenderLight,
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
            if (_selectedForCompare.isNotEmpty) _buildComparePanel(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
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
        ..._results.map(
          (drug) => _DrugResultCard(
            drug: drug,
            isSelected: _selectedForCompare.any(
              (item) => item.displayCode == drug.displayCode,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DrugDetailScreen(drug: drug),
              ),
            ),
            onCompareTap: () => _toggleCompare(drug),
          ),
        ),
      ],
    );
  }

  Widget _buildComparePanel() {
    return Container(
      color: AppColors.lavenderBg,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  size: 16, color: AppColors.lavender),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedForCompare.map((drug) => drug.name).join(' + '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _selectedForCompare = [];
                  _compareWarnings = [];
                }),
                child: const Text(
                  '초기화',
                  style: TextStyle(fontSize: 11, color: AppColors.lavender),
                ),
              ),
            ],
          ),
          if (_selectedForCompare.length == 1)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                '비교할 약을 하나 이상 더 선택하세요.',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ),
          if (_isComparing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_selectedForCompare.length >= 2 && !_isComparing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _compareWarnings.isEmpty
                    ? '선택한 약들 사이에서 DB 기준 확인된 병용금기/성분중복/효능군 중복 정보가 없습니다.'
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
  final VoidCallback onTap;
  final VoidCallback onCompareTap;

  const _DrugResultCard({
    required this.drug,
    required this.isSelected,
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '성분 비교 선택',
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
