import 'package:flutter/material.dart';
import 'package:sseudeuson/theme/app_colors.dart';
import 'package:sseudeuson/models/medicine_model.dart';

class BagAddScreen extends StatefulWidget {
  final MedicineBag? targetBag;

  const BagAddScreen({super.key, this.targetBag});

  @override
  State<BagAddScreen> createState() => _BagAddScreenState();
}

class _BagAddScreenState extends State<BagAddScreen> {
  // 선택된 추가 방법
  int? _selectedAddMethod;

  // 선택된 약 (검색 결과)
  Medicine? _selectedMedicine;

  // 복용 설정
  final Set<TimeOfDay2> _selectedTimes = {TimeOfDay2.morning};
  MealTiming _selectedMealTiming = MealTiming.afterImmediate;
  int _selectedDailyCount = 2;
  int _selectedDuration = 30; // 0 = 계속 복용
  final _memoController = TextEditingController();
  final _searchController = TextEditingController();

  // 검색 결과 (더미)
  List<Medicine> _searchResults = [];

  @override
  void dispose() {
    _memoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _searchResults = DummyData.searchableMedicines
          .where((m) =>
              m.name.contains(query) || m.englishName.toLowerCase().contains(query.toLowerCase()))
          .take(5)
          .toList();
    });
  }

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
            const Text(
              '약 추가하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.targetBag != null)
              Text(
                widget.targetBag!.name,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        toolbarHeight: 58,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 추가 방법 선택 ──
            _sectionTitle('어떤 방법으로 추가할까요?'),
            const SizedBox(height: 8),
            Row(
              children: [
                _AddMethodCard(
                  icon: Icons.search,
                  label: '명칭으로',
                  isSelected: _selectedAddMethod == 0,
                  onTap: () => setState(() => _selectedAddMethod = 0),
                ),
                const SizedBox(width: 8),
                _AddMethodCard(
                  icon: Icons.qr_code_scanner,
                  label: '코드로',
                  isSelected: _selectedAddMethod == 1,
                  onTap: () => setState(() => _selectedAddMethod = 1),
                ),
                const SizedBox(width: 8),
                _AddMethodCard(
                  icon: Icons.camera_alt_outlined,
                  label: '사진으로',
                  isSelected: _selectedAddMethod == 2,
                  onTap: () => setState(() => _selectedAddMethod = 2),
                ),
              ],
            ),

            // ── 검색창 (명칭 선택 시) ──
            if (_selectedAddMethod == 0) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: '약품명 또는 성분명 검색',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppColors.lavender),
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.cardBorder, width: 0.5),
                  ),
                  child: Column(
                    children: _searchResults.map((med) {
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedMedicine = med;
                          _searchController.text = med.name;
                          _searchResults = [];
                          _selectedTimes.clear();
                          _selectedTimes.addAll(med.timesOfDay);
                          _selectedMealTiming = med.mealTiming;
                          _selectedDailyCount = med.dailyCount;
                          _selectedDuration = med.durationDays;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      med.englishName,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textHint),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.lavenderBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  med.category,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.lavenderDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],

            // ── 선택된 약 + 복용 설정 ──
            if (_selectedMedicine != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedMedicine!.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_selectedMedicine!.englishName} · ${_selectedMedicine!.category}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 복용 시간대
                    _settingLabel('복용 시간대'),
                    const SizedBox(height: 6),
                    _buildTimeChips(),
                    const SizedBox(height: 12),

                    // 식전/식후
                    _settingLabel('식전 / 식후'),
                    const SizedBox(height: 6),
                    _buildMealTimingChips(),
                    const SizedBox(height: 12),

                    // 1일 복용 횟수
                    _settingLabel('1일 복용 횟수'),
                    const SizedBox(height: 6),
                    _buildCountChips(),
                    const SizedBox(height: 12),

                    // 복용 기간
                    _settingLabel('복용 기간'),
                    const SizedBox(height: 6),
                    _buildDurationChips(),
                    const SizedBox(height: 12),

                    // 메모
                    _settingLabel('메모 (선택)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _memoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: '복용 관련 메모를 입력하세요...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    widget.targetBag != null
                        ? '${widget.targetBag!.name}에 저장'
                        : '새 봉투에 저장',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _settingLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTimeChips() {
    return Wrap(
      spacing: 6,
      children: TimeOfDay2.values.map((t) {
        final isSelected = _selectedTimes.contains(t);
        return _SelectableChip(
          label: t.label,
          isSelected: isSelected,
          onTap: () => setState(() {
            if (isSelected) {
              if (_selectedTimes.length > 1) _selectedTimes.remove(t);
            } else {
              _selectedTimes.add(t);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _buildMealTimingChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: MealTiming.values.map((t) {
        return _SelectableChip(
          label: t.label,
          isSelected: _selectedMealTiming == t,
          onTap: () => setState(() => _selectedMealTiming = t),
        );
      }).toList(),
    );
  }

  Widget _buildCountChips() {
    return Wrap(
      spacing: 6,
      children: [1, 2, 3].map((count) {
        return _SelectableChip(
          label: '$count회',
          isSelected: _selectedDailyCount == count,
          onTap: () => setState(() => _selectedDailyCount = count),
        );
      }).toList(),
    );
  }

  Widget _buildDurationChips() {
    final durations = [7, 14, 30, 60, 0]; // 0 = 계속 복용
    return Wrap(
      spacing: 6,
      children: durations.map((d) {
        return _SelectableChip(
          label: d == 0 ? '계속 복용' : '$d일',
          isSelected: _selectedDuration == d,
          onTap: () => setState(() => _selectedDuration = d),
        );
      }).toList(),
    );
  }

  void _saveMedicine() {
    if (_selectedMedicine == null) return;
    // 실제 구현에서는 상태 관리(Provider 등)를 통해 저장
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedMedicine!.name}이(가) ${widget.targetBag?.name ?? '새 봉투'}에 저장되었습니다.',
        ),
        backgroundColor: AppColors.lavender,
      ),
    );
    Navigator.pop(context);
  }
}

// ─── 추가 방법 카드 ──────────────────────────────────────────────────────────

class _AddMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddMethodCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lavender : AppColors.lavenderBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.lavender
                  : AppColors.lavenderBorder,
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : AppColors.lavender,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.lavenderDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 선택 가능한 칩 ──────────────────────────────────────────────────────────

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lavender : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.lavender : const Color(0xFFDDDDDD),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
