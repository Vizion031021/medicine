import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sseudeuson/models/drug_info.dart';

class DrugService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<DrugInfo>> searchDrugs(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    dynamic request = _client.from('drug_standard_codes').select();
    if (trimmed.isNotEmpty) {
      final escaped = trimmed.replaceAll(',', ' ');
      request = request.or('한글상품명.ilike.%$escaped%,업체명.ilike.%$escaped%');
    }
    final rows = await request.limit(limit);
    return (rows as List)
        .map((row) => DrugInfo.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((drug) => drug.name.isNotEmpty)
        .toList();
  }

  static Future<DrugInfo?> findByProductCode(String productCode) async {
    final code = productCode.trim();
    if (code.isEmpty) return null;
    for (final column in ['대표코드', '표준코드']) {
      try {
        final rows = await _client.from('drug_standard_codes').select().eq(column, code).limit(1);
        if ((rows as List).isNotEmpty) {
          return DrugInfo.fromJson(Map<String, dynamic>.from(rows.first as Map));
        }
      } catch (_) { continue; }
    }
    return null;
  }

  // ── fetchWarnings ─────────────────────────────────────────────────────────

  static Future<List<DrugWarning>> fetchWarnings(DrugInfo drug) async {
    final pc = drug.displayCode;
    final ic = drug.ingredientCode;
    final results = await Future.wait<List<DrugWarning>>([
      _safeWarnings(() => _fetchDosageWarnings(drug, pc, ic)),
      _safeWarnings(() => _fetchDurationWarnings(drug, pc, ic)),
      _safeWarnings(() => _fetchEfficacyDupWarnings(pc, ic)),
      _safeWarnings(() => _fetchPregnancyWarnings(drug, pc, ic)),
    ]);
    return _dedupeWarnings(results.expand((items) => items).toList());
  }

  static Future<List<DrugWarning>> _safeWarnings(
    Future<List<DrugWarning>> Function() fetcher,
  ) async {
    try { return await fetcher().timeout(const Duration(seconds: 6)); }
    catch (_) { return []; }
  }

  // ── compareDrugs — young 브랜치 개선 버전 ─────────────────────────────────
  // 각 약물 쌍별로 정확하게 조회 (_fetchComboRowsForPairs)

  static Future<List<DrugWarning>> compareDrugs(List<DrugInfo> drugs) async {
    if (drugs.length < 2) return [];

    final ingredientCodes = drugs.expand(_ingredientCodesFor).toSet();
    final warnings = <DrugWarning>[];
    final seenWarnings = <String>{};

    // 성분/ATC/제품명 중복 체크
    final duplicateBasisByNames = <String, Set<String>>{};

    final ingredientGroups = <String, List<DrugInfo>>{};
    for (final drug in drugs) {
      if (drug.ingredientCode.isEmpty) continue;
      ingredientGroups.putIfAbsent(drug.ingredientCode, () => []).add(drug);
    }
    for (final entry in ingredientGroups.entries) {
      if (entry.value.length < 2) continue;
      _collectDuplicateBasis(
        duplicateBasisByNames: duplicateBasisByNames,
        basis: '성분코드 ${entry.key}',
        drugs: entry.value,
      );
    }

    final atcGroups = <String, List<DrugInfo>>{};
    for (final drug in drugs) {
      if (drug.atcCode.isEmpty) continue;
      atcGroups.putIfAbsent(drug.atcCode, () => []).add(drug);
    }
    for (final entry in atcGroups.entries) {
      if (entry.value.length < 2) continue;
      _collectDuplicateBasis(
        duplicateBasisByNames: duplicateBasisByNames,
        basis: 'ATC 코드 ${entry.key}',
        drugs: entry.value,
      );
    }

    final nameGroups = <String, List<DrugInfo>>{};
    for (final drug in drugs) {
      final key = _normalizedProductFamilyName(drug.name);
      if (key.length < 3) continue;
      nameGroups.putIfAbsent(key, () => []).add(drug);
    }
    for (final entry in nameGroups.entries) {
      if (entry.value.length < 2) continue;
      _collectDuplicateBasis(
        duplicateBasisByNames: duplicateBasisByNames,
        basis: '제품명 기준 ${entry.key}',
        drugs: entry.value,
      );
    }
    _addDuplicateWarnings(warnings: warnings, duplicateBasisByNames: duplicateBasisByNames);

    // 병용 금기 — 약물 쌍별로 정확하게 조회
    final comboRows = await _fetchComboRowsForPairs(drugs);
    for (final row in comboRows) {
      final pc1 = (row['제품코드1'] ?? '').toString();
      final pc2 = (row['제품코드2'] ?? '').toString();
      final ic1 = (row['성분코드1'] ?? '').toString();
      final ic2 = (row['성분코드2'] ?? '').toString();
      final productMatched = pc1.isNotEmpty && pc2.isNotEmpty &&
          _hasTwoDrugMatches(drugs: drugs, firstCode: pc1, secondCode: pc2,
              codesForDrug: _productCodesFor);
      final ingredientMatched = ic1.isNotEmpty && ic2.isNotEmpty &&
          _hasTwoDrugMatches(drugs: drugs, firstCode: ic1, secondCode: ic2,
              codesForDrug: _ingredientCodesFor);
      if (!productMatched && !ingredientMatched) continue;

      final pair = ingredientMatched ? [ic1, ic2] : [pc1, pc2];
      pair.sort();
      final reason = (row['금기사유'] ?? '').toString();
      final wKey = ['combo', ...pair, reason].join('|');
      if (!seenWarnings.add(wKey)) continue;

      final names = _matchedDrugNamesForCombo(
        drugs: drugs,
        productCode1: pc1, productCode2: pc2,
        ingredientCode1: ic1, ingredientCode2: ic2,
        ingredientMatched: ingredientMatched,
      );
      final n1 = names[0] ?? (row['성분명1'] ?? row['제품명1'] ?? '약 1').toString();
      final n2 = names[1] ?? (row['성분명2'] ?? row['제품명2'] ?? '약 2').toString();
      warnings.add(DrugWarning(
        type: DrugWarningType.comboContraindication,
        title: '병용 금기',
        message: '$n1 + $n2: ${reason.isEmpty ? 'DB 기준 병용 금기 정보가 있습니다.' : reason}',
        severity: '높음',
        raw: row,
      ));
    }

    // 효능군 중복
    if (ingredientCodes.isNotEmpty) {
      try {
        final dupRows = await _client.from('efficacy_dup_warnings').select()
            .inFilter('성분코드', ingredientCodes.toList())
            .timeout(const Duration(seconds: 6));
        final groups = <String, List<Map<String, dynamic>>>{};
        final groupCodes = <String, Set<String>>{};
        for (final raw in dupRows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final group = (row['효능군'] ?? '').toString();
          final ic = (row['성분코드'] ?? '').toString();
          if (group.isEmpty || ic.isEmpty) continue;
          groups.putIfAbsent(group, () => []).add(row);
          groupCodes.putIfAbsent(group, () => {}).add(ic);
        }
        for (final entry in groups.entries) {
          if ((groupCodes[entry.key] ?? {}).length > 1) {
            warnings.add(DrugWarning(
              type: DrugWarningType.efficacyDuplication,
              title: '효능군 중복주의',
              message: '${entry.key} 계열 약이 중복될 수 있습니다.',
              severity: '중간',
              raw: {'효능군': entry.key, 'items': entry.value},
            ));
          }
        }
      } catch (_) {}
    }

    return warnings;
  }

  // ── 코드 추출 헬퍼 ────────────────────────────────────────────────────────

  static Set<String> _productCodesFor(DrugInfo drug) {
    return {
      drug.displayCode, drug.productCode, drug.standardCode,
      (drug.raw['대표코드'] ?? '').toString(),
      (drug.raw['표준코드'] ?? '').toString(),
      (drug.raw['제품코드(개정후)'] ?? '').toString(),
      (drug.raw['제품코드'] ?? '').toString(),
    }.where((c) => c.isNotEmpty).toSet();
  }

  static Set<String> _ingredientCodesFor(DrugInfo drug) {
    return {
      drug.ingredientCode,
      (drug.raw['일반명코드(성분명코드)'] ?? '').toString(),
      (drug.raw['일반명코드'] ?? '').toString(),
      (drug.raw['성분명코드'] ?? '').toString(),
      (drug.raw['성분코드'] ?? '').toString(),
    }.where((c) => c.isNotEmpty).toSet();
  }

  static bool _hasTwoDrugMatches({
    required List<DrugInfo> drugs,
    required String firstCode,
    required String secondCode,
    required Set<String> Function(DrugInfo) codesForDrug,
  }) {
    for (var i = 0; i < drugs.length; i++) {
      for (var j = i + 1; j < drugs.length; j++) {
        final a = codesForDrug(drugs[i]);
        final b = codesForDrug(drugs[j]);
        if ((a.contains(firstCode) && b.contains(secondCode)) ||
            (a.contains(secondCode) && b.contains(firstCode))) return true;
      }
    }
    return false;
  }

  static List<String?> _matchedDrugNamesForCombo({
    required List<DrugInfo> drugs,
    required String productCode1, required String productCode2,
    required String ingredientCode1, required String ingredientCode2,
    required bool ingredientMatched,
  }) {
    final first = drugs.where((d) => ingredientMatched
        ? _ingredientCodesFor(d).contains(ingredientCode1)
        : _productCodesFor(d).contains(productCode1))
        .map((d) => d.name).toSet().toList()..sort();
    final second = drugs.where((d) => ingredientMatched
        ? _ingredientCodesFor(d).contains(ingredientCode2)
        : _productCodesFor(d).contains(productCode2))
        .map((d) => d.name).toSet().toList()..sort();
    return [first.isEmpty ? null : first.join(', '), second.isEmpty ? null : second.join(', ')];
  }

  static Future<List<Map<String, dynamic>>> _fetchComboRowsForPairs(
      List<DrugInfo> drugs) async {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < drugs.length; i++) {
      for (var j = i + 1; j < drugs.length; j++) {
        final a = drugs[i]; final b = drugs[j];
        for (final ai in _ingredientCodesFor(a)) {
          for (final bi in _ingredientCodesFor(b)) {
            rows.addAll(await _fetchComboPairRows(
                column1: '성분코드1', value1: ai, column2: '성분코드2', value2: bi));
            rows.addAll(await _fetchComboPairRows(
                column1: '성분코드1', value1: bi, column2: '성분코드2', value2: ai));
          }
        }
        for (final ap in _productCodesFor(a)) {
          for (final bp in _productCodesFor(b)) {
            rows.addAll(await _fetchComboPairRows(
                column1: '제품코드1', value1: ap, column2: '제품코드2', value2: bp));
            rows.addAll(await _fetchComboPairRows(
                column1: '제품코드1', value1: bp, column2: '제품코드2', value2: ap));
          }
        }
      }
    }
    final deduped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final ip = ([
        (row['성분코드1'] ?? '').toString(),
        (row['성분코드2'] ?? '').toString(),
      ]..sort()).where((v) => v.isNotEmpty).join('+');
      final pp = ([
        (row['제품코드1'] ?? '').toString(),
        (row['제품코드2'] ?? '').toString(),
      ]..sort()).where((v) => v.isNotEmpty).join('+');
      deduped['$ip|$pp|${row['금기사유']}'] = row;
    }
    return deduped.values.toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchComboPairRows({
    required String column1, required String value1,
    required String column2, required String value2,
  }) async {
    if (value1.isEmpty || value2.isEmpty) return [];
    try {
      final result = await _client.from('combo_contraindicated_drugs').select()
          .eq(column1, value1).eq(column2, value2).limit(20)
          .timeout(const Duration(seconds: 6));
      return (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) { return []; }
  }

  static void _collectDuplicateBasis({
    required Map<String, Set<String>> duplicateBasisByNames,
    required String basis,
    required List<DrugInfo> drugs,
  }) {
    final names = drugs.map((d) => d.name).toSet().toList()..sort();
    duplicateBasisByNames.putIfAbsent(names.join('|'), () => <String>{}).add(basis);
  }

  static void _addDuplicateWarnings({
    required List<DrugWarning> warnings,
    required Map<String, Set<String>> duplicateBasisByNames,
  }) {
    for (final entry in duplicateBasisByNames.entries) {
      final names = entry.key.split('|');
      final bases = entry.value.toList()..sort();
      warnings.add(DrugWarning(
        type: DrugWarningType.ingredientDuplication,
        title: '성분/계열 중복',
        message: '${names.join(', ')}: ${bases.join(', ')} 기준으로 중복 복용 가능성이 있습니다.',
        severity: '중간',
        raw: {'basis': bases.join(', '), 'items': names},
      ));
    }
  }

  static String _normalizedProductFamilyName(String name) {
    return name
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[0-9]+(\.[0-9]+)?'), '')
        .replaceAll(RegExp(
            r'(밀리그램|마이크로그램|그램|mg|㎎|g|ml|mL|%)', caseSensitive: false), '')
        .replaceAll(RegExp(r'(연질캡슐|서방정|장용정|캡슐|시럽|현탁액|주사|정|액|주)$'), '')
        .replaceAll(RegExp(r'[\s·ㆍ\-_]'), '')
        .trim();
  }

  // ── 개별 경고 조회 ────────────────────────────────────────────────────────

  static Future<List<DrugWarning>> _fetchDosageWarnings(
      DrugInfo drug, String productCode, String ingredientCode) async {
    final rows = await _selectByProductOrIngredient(
        table: 'dosage_warning_drugs',
        productCode: productCode, ingredientCode: ingredientCode);
    return rows.map((row) => DrugWarning(
      type: DrugWarningType.dosage, title: '용량 주의',
      message: '${drug.name} 1일 최대 투여량: ${row['1일최대투여량'] ?? row['1일최대 투여기준량'] ?? ''}',
      severity: '중간', raw: row,
    )).toList();
  }

  static Future<List<DrugWarning>> _fetchDurationWarnings(
      DrugInfo drug, String productCode, String ingredientCode) async {
    final rows = await _selectByProductOrIngredient(
        table: 'duration_warning_drugs',
        productCode: productCode, ingredientCode: ingredientCode);
    return rows.map((row) => DrugWarning(
      type: DrugWarningType.duration, title: '투여기간 주의',
      message: '${drug.name} 최대 투여기간: ${row['최대투여기간일수'] ?? '-'}일',
      severity: '중간', raw: row,
    )).toList();
  }

  static Future<List<DrugWarning>> _fetchEfficacyDupWarnings(
      String productCode, String ingredientCode) async {
    final rows = await _selectByProductOrIngredient(
        table: 'efficacy_dup_warnings',
        productCode: productCode, ingredientCode: ingredientCode);
    return rows.map((row) => DrugWarning(
      type: DrugWarningType.efficacyDuplication, title: '효능군 중복주의',
      message: '${row['효능군'] ?? '같은 효능군'} 계열 중복 복용에 주의하세요.',
      severity: '중간', raw: row,
    )).toList();
  }

  static Future<List<DrugWarning>> _fetchPregnancyWarnings(
      DrugInfo drug, String productCode, String ingredientCode) async {
    final rows = await _selectByProductOrIngredient(
        table: 'pregnancy_contraindicated_drugs',
        productCode: productCode, ingredientCode: ingredientCode);
    return rows.map((row) => DrugWarning(
      type: DrugWarningType.pregnancy, title: '임부 금기',
      message: '${drug.name} 금기등급: ${row['금기등급'] ?? '-'} / ${row['상세정보'] ?? ''}',
      severity: '높음', raw: row,
    )).toList();
  }

  static Future<List<Map<String, dynamic>>> _selectByProductOrIngredient({
    required String table,
    required String productCode, required String ingredientCode,
  }) async {
    if (productCode.isEmpty && ingredientCode.isEmpty) return [];
    final filters = <String>[];
    if (productCode.isNotEmpty) filters.add('제품코드.eq.$productCode');
    if (ingredientCode.isNotEmpty) filters.add('성분코드.eq.$ingredientCode');
    final rows = await _client.from(table).select().or(filters.join(',')).limit(20);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  // ── 중복 제거 ─────────────────────────────────────────────────────────────

  static List<DrugWarning> _dedupeWarnings(List<DrugWarning> warnings) {
    final seen = <String>{};
    return warnings.where((w) => seen.add(_warningKey(w))).toList();
  }

  static String _warningKey(DrugWarning w) {
    final r = w.raw;
    switch (w.type) {
      case DrugWarningType.dosage:
        return [w.type.name, r['성분코드'], r['성분명'],
            r['1일최대투여량'], r['1일최대 투여기준량']].join('|');
      case DrugWarningType.duration:
        return [w.type.name, r['성분코드'], r['성분명'], r['최대투여기간일수']].join('|');
      case DrugWarningType.efficacyDuplication:
        return [w.type.name, r['효능군'], r['그룹구분'],
            r['일반명코드'], r['성분코드'], r['성분명']].join('|');
      case DrugWarningType.pregnancy:
        return [w.type.name, r['성분코드'], r['성분명'],
            r['금기등급'], r['상세정보']].join('|');
      case DrugWarningType.comboContraindication:
      case DrugWarningType.ingredientDuplication:
        return '${w.type.name}|${w.title}|${w.message}';
    }
  }

  static Future<String> fetchIngredientName(DrugInfo drug) async {
    if (drug.ingredientName.isNotEmpty) return drug.ingredientName;
    if (drug.ingredientCode.isEmpty && drug.displayCode.isEmpty) return '';
    try {
      final rows = await _selectByProductOrIngredient(
        table: 'efficacy_dup_warnings',
        productCode: drug.displayCode,
        ingredientCode: drug.ingredientCode,
      ).timeout(const Duration(seconds: 4));
      for (final row in rows) {
        final name = (row['성분명'] ?? '').toString();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return '';
  }
}
