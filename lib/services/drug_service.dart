import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sseudeuson/models/drug_info.dart';

class DrugService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<DrugInfo>> searchDrugs(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    dynamic request = _client.from('drug_standard_codes').select();

    if (trimmed.isNotEmpty) {
      final escaped = trimmed.replaceAll(',', ' ');
      request = request.or(
        '한글상품명.ilike.%$escaped%,업체명.ilike.%$escaped%',
      );
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

    final columns = ['대표코드', '표준코드'];
    for (final column in columns) {
      try {
        final rows = await _client
            .from('drug_standard_codes')
            .select()
            .eq(column, code)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          return DrugInfo.fromJson(Map<String, dynamic>.from(rows.first as Map));
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  static Future<List<DrugWarning>> fetchWarnings(DrugInfo drug) async {
    final productCode = drug.displayCode;
    final ingredientCode = drug.ingredientCode;

    final results = await Future.wait<List<DrugWarning>>([
      _safeWarnings(
        () => _fetchDosageWarnings(drug, productCode, ingredientCode),
      ),
      _safeWarnings(
        () => _fetchDurationWarnings(drug, productCode, ingredientCode),
      ),
      _safeWarnings(() => _fetchEfficacyDupWarnings(productCode, ingredientCode)),
      _safeWarnings(
        () => _fetchPregnancyWarnings(drug, productCode, ingredientCode),
      ),
    ]);

    return _dedupeWarnings(results.expand((items) => items).toList());
  }

  static Future<List<DrugWarning>> _safeWarnings(
    Future<List<DrugWarning>> Function() fetcher,
  ) async {
    try {
      return await fetcher().timeout(const Duration(seconds: 6));
    } catch (_) {
      return [];
    }
  }

  static Future<List<DrugWarning>> compareDrugs(List<DrugInfo> drugs) async {
    if (drugs.length < 2) return [];

    final codes = drugs.expand(_productCodesFor).toSet();
    final ingredientCodes = drugs.expand(_ingredientCodesFor).toSet();
    final warnings = <DrugWarning>[];
    final seenWarnings = <String>{};

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

    _addDuplicateWarnings(
      warnings: warnings,
      duplicateBasisByNames: duplicateBasisByNames,
    );

    final comboRows = await _fetchComboRowsForPairs(drugs);

    for (final row in comboRows) {
      final productCode1 = (row['제품코드1'] ?? '').toString();
      final productCode2 = (row['제품코드2'] ?? '').toString();
      final ingredientCode1 = (row['성분코드1'] ?? '').toString();
      final ingredientCode2 = (row['성분코드2'] ?? '').toString();
      final productMatched = productCode1.isNotEmpty &&
          productCode2.isNotEmpty &&
          _hasTwoDrugMatches(
            drugs: drugs,
            firstCode: productCode1,
            secondCode: productCode2,
            codesForDrug: _productCodesFor,
          );
      final ingredientMatched = ingredientCode1.isNotEmpty &&
          ingredientCode2.isNotEmpty &&
          _hasTwoDrugMatches(
            drugs: drugs,
            firstCode: ingredientCode1,
            secondCode: ingredientCode2,
            codesForDrug: _ingredientCodesFor,
          );

      if (!productMatched && !ingredientMatched) continue;

      final pair = ingredientMatched
          ? [ingredientCode1, ingredientCode2]
          : [productCode1, productCode2];
      pair.sort();
      final reason = (row['금기사유'] ?? '').toString();
      final warningKey = ['combo', ...pair, reason].join('|');
      if (!seenWarnings.add(warningKey)) continue;
      final matchedNames = _matchedDrugNamesForCombo(
        drugs: drugs,
        productCode1: productCode1,
        productCode2: productCode2,
        ingredientCode1: ingredientCode1,
        ingredientCode2: ingredientCode2,
        ingredientMatched: ingredientMatched,
      );
      final name1 = matchedNames.$1 ??
          (row['성분명1'] ?? row['제품명1'] ?? '약 1').toString();
      final name2 = matchedNames.$2 ??
          (row['성분명2'] ?? row['제품명2'] ?? '약 2').toString();

      warnings.add(
        DrugWarning(
          type: DrugWarningType.comboContraindication,
          title: '병용 금기',
          message:
              '$name1 + $name2: ${reason.isEmpty ? 'DB 기준 병용 금기 정보가 있습니다.' : reason}',
          severity: '높음',
          raw: row,
        ),
      );
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    final groupIngredientCodes = <String, Set<String>>{};
    if (ingredientCodes.isNotEmpty) {
      try {
        final dupRows = await _client
            .from('efficacy_dup_warnings')
            .select()
            .inFilter('성분코드', ingredientCodes.toList())
            .timeout(const Duration(seconds: 6));

        for (final raw in dupRows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final group = (row['효능군'] ?? '').toString();
          final ingredientCode = (row['성분코드'] ?? '').toString();
          if (group.isEmpty || ingredientCode.isEmpty) continue;
          groups.putIfAbsent(group, () => []).add(row);
          groupIngredientCodes.putIfAbsent(group, () => {}).add(ingredientCode);
        }
      } catch (_) {}
    }

    for (final entry in groups.entries) {
      final matchedCodes = groupIngredientCodes[entry.key] ?? {};
      if (matchedCodes.length > 1) {
        warnings.add(
          DrugWarning(
            type: DrugWarningType.efficacyDuplication,
            title: '효능군 중복주의',
            message: '${entry.key} 계열 약이 중복될 수 있습니다.',
            severity: '중간',
            raw: {'효능군': entry.key, 'items': entry.value},
          ),
        );
      }
    }

    return warnings;
  }

  static Set<String> _productCodesFor(DrugInfo drug) {
    return {
      drug.displayCode,
      drug.productCode,
      drug.standardCode,
      (drug.raw['대표코드'] ?? '').toString(),
      (drug.raw['표준코드'] ?? '').toString(),
      (drug.raw['제품코드(개정후)'] ?? '').toString(),
      (drug.raw['제품코드'] ?? '').toString(),
    }.where((code) => code.isNotEmpty).toSet();
  }

  static Set<String> _ingredientCodesFor(DrugInfo drug) {
    return {
      drug.ingredientCode,
      (drug.raw['일반명코드(성분명코드)'] ?? '').toString(),
      (drug.raw['일반명코드'] ?? '').toString(),
      (drug.raw['성분명코드'] ?? '').toString(),
      (drug.raw['성분코드'] ?? '').toString(),
    }.where((code) => code.isNotEmpty).toSet();
  }

  static bool _hasTwoDrugMatches({
    required List<DrugInfo> drugs,
    required String firstCode,
    required String secondCode,
    required Set<String> Function(DrugInfo drug) codesForDrug,
  }) {
    for (var i = 0; i < drugs.length; i++) {
      for (var j = i + 1; j < drugs.length; j++) {
        final firstDrugCodes = codesForDrug(drugs[i]);
        final secondDrugCodes = codesForDrug(drugs[j]);
        final forward = firstDrugCodes.contains(firstCode) &&
            secondDrugCodes.contains(secondCode);
        final reverse = firstDrugCodes.contains(secondCode) &&
            secondDrugCodes.contains(firstCode);
        if (forward || reverse) return true;
      }
    }
    return false;
  }

  static (String?, String?) _matchedDrugNamesForCombo({
    required List<DrugInfo> drugs,
    required String productCode1,
    required String productCode2,
    required String ingredientCode1,
    required String ingredientCode2,
    required bool ingredientMatched,
  }) {
    final first = drugs.where((drug) {
      if (ingredientMatched) return _ingredientCodesFor(drug).contains(ingredientCode1);
      return _productCodesFor(drug).contains(productCode1);
    }).map((drug) => drug.name).toSet().toList();

    final second = drugs.where((drug) {
      if (ingredientMatched) return _ingredientCodesFor(drug).contains(ingredientCode2);
      return _productCodesFor(drug).contains(productCode2);
    }).map((drug) => drug.name).toSet().toList();

    first.sort();
    second.sort();
    return (
      first.isEmpty ? null : first.join(', '),
      second.isEmpty ? null : second.join(', '),
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchComboRowsForPairs(
    List<DrugInfo> drugs,
  ) async {
    final rows = <Map<String, dynamic>>[];

    for (var i = 0; i < drugs.length; i++) {
      for (var j = i + 1; j < drugs.length; j++) {
        final a = drugs[i];
        final b = drugs[j];
        for (final aIngredientCode in _ingredientCodesFor(a)) {
          for (final bIngredientCode in _ingredientCodesFor(b)) {
            rows.addAll(await _fetchComboPairRows(
              column1: '성분코드1',
              value1: aIngredientCode,
              column2: '성분코드2',
              value2: bIngredientCode,
            ));
            rows.addAll(await _fetchComboPairRows(
              column1: '성분코드1',
              value1: bIngredientCode,
              column2: '성분코드2',
              value2: aIngredientCode,
            ));
          }
        }
        for (final aProductCode in _productCodesFor(a)) {
          for (final bProductCode in _productCodesFor(b)) {
            rows.addAll(await _fetchComboPairRows(
              column1: '제품코드1',
              value1: aProductCode,
              column2: '제품코드2',
              value2: bProductCode,
            ));
            rows.addAll(await _fetchComboPairRows(
              column1: '제품코드1',
              value1: bProductCode,
              column2: '제품코드2',
              value2: aProductCode,
            ));
          }
        }
      }
    }

    final deduped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final ingredientPair = [
        (row['성분코드1'] ?? '').toString(),
        (row['성분코드2'] ?? '').toString(),
      ]..sort();
      final productPair = [
        (row['제품코드1'] ?? '').toString(),
        (row['제품코드2'] ?? '').toString(),
      ]..sort();
      final key = [
        ingredientPair.where((value) => value.isNotEmpty).join('+'),
        productPair.where((value) => value.isNotEmpty).join('+'),
        row['금기사유'],
      ].join('|');
      deduped[key] = row;
    }

    return deduped.values.toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchComboPairRows({
    required String column1,
    required String value1,
    required String column2,
    required String value2,
  }) async {
    if (value1.isEmpty || value2.isEmpty) return [];

    try {
      final result = await _client
          .from('combo_contraindicated_drugs')
          .select()
          .eq(column1, value1)
          .eq(column2, value2)
          .limit(20)
          .timeout(const Duration(seconds: 6));
      return (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void _collectDuplicateBasis({
    required Map<String, Set<String>> duplicateBasisByNames,
    required String basis,
    required List<DrugInfo> drugs,
  }) {
    final names = drugs.map((drug) => drug.name).toSet().toList()..sort();
    duplicateBasisByNames
        .putIfAbsent(names.join('|'), () => <String>{})
        .add(basis);
  }

  static void _addDuplicateWarnings({
    required List<DrugWarning> warnings,
    required Map<String, Set<String>> duplicateBasisByNames,
  }) {
    for (final entry in duplicateBasisByNames.entries) {
      final names = entry.key.split('|');
      final bases = entry.value.toList()..sort();
      warnings.add(
        DrugWarning(
          type: DrugWarningType.ingredientDuplication,
          title: '성분/계열 중복',
          message:
              '${names.join(', ')}: ${bases.join(', ')} 기준으로 중복 복용 가능성이 있습니다.',
          severity: '중간',
          raw: {
            'basis': bases.join(', '),
            'items': names,
          },
        ),
      );
    }
  }

  static String _normalizedProductFamilyName(String name) {
    return name
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[0-9]+(\.[0-9]+)?'), '')
        .replaceAll(RegExp(
            r'(밀리그램|마이크로그램|그램|mg|㎎|g|ml|mL|%)',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'(연질캡슐|서방정|장용정|캡슐|시럽|현탁액|주사|정|액|주)$'), '')
        .replaceAll(RegExp(r'[\s·ㆍ\-_]'), '')
        .trim();
  }

  static Future<List<DrugWarning>> _fetchDosageWarnings(
    DrugInfo drug,
    String productCode,
    String ingredientCode,
  ) async {
    final rows = await _selectByProductOrIngredient(
      table: 'dosage_warning_drugs',
      productCode: productCode,
      ingredientCode: ingredientCode,
    );

    return rows.map((row) {
      final maxDose = row['1일최대투여량'] ?? row['1일최대 투여기준량'] ?? '';
      return DrugWarning(
        type: DrugWarningType.dosage,
        title: '용량 주의',
        message: '${drug.name} 1일 최대 투여량: $maxDose',
        severity: '중간',
        raw: row,
      );
    }).toList();
  }

  static Future<List<DrugWarning>> _fetchDurationWarnings(
    DrugInfo drug,
    String productCode,
    String ingredientCode,
  ) async {
    final rows = await _selectByProductOrIngredient(
      table: 'duration_warning_drugs',
      productCode: productCode,
      ingredientCode: ingredientCode,
    );

    return rows.map((row) {
      return DrugWarning(
        type: DrugWarningType.duration,
        title: '투여기간 주의',
        message:
            '${drug.name} 최대 투여기간: ${row['최대투여기간일수'] ?? '-'}일',
        severity: '중간',
        raw: row,
      );
    }).toList();
  }

  static Future<List<DrugWarning>> _fetchEfficacyDupWarnings(
    String productCode,
    String ingredientCode,
  ) async {
    final rows = await _selectByProductOrIngredient(
      table: 'efficacy_dup_warnings',
      productCode: productCode,
      ingredientCode: ingredientCode,
    );

    return rows.map((row) {
      return DrugWarning(
        type: DrugWarningType.efficacyDuplication,
        title: '효능군 중복주의',
        message: '${row['효능군'] ?? '같은 효능군'} 계열 중복 복용에 주의하세요.',
        severity: '중간',
        raw: row,
      );
    }).toList();
  }

  static Future<List<DrugWarning>> _fetchPregnancyWarnings(
    DrugInfo drug,
    String productCode,
    String ingredientCode,
  ) async {
    final rows = await _selectByProductOrIngredient(
      table: 'pregnancy_contraindicated_drugs',
      productCode: productCode,
      ingredientCode: ingredientCode,
    );

    return rows.map((row) {
      return DrugWarning(
        type: DrugWarningType.pregnancy,
        title: '임부 금기',
        message:
            '${drug.name} 금기등급: ${row['금기등급'] ?? '-'} / ${row['상세정보'] ?? ''}',
        severity: '높음',
        raw: row,
      );
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _selectByProductOrIngredient({
    required String table,
    required String productCode,
    required String ingredientCode,
  }) async {
    if (productCode.isEmpty && ingredientCode.isEmpty) return [];

    final filters = <String>[];
    if (productCode.isNotEmpty) filters.add('제품코드.eq.$productCode');
    if (ingredientCode.isNotEmpty) filters.add('성분코드.eq.$ingredientCode');

    final rows =
        await _client.from(table).select().or(filters.join(',')).limit(20);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ─── 중복 제거 ────────────────────────────────────────────────────────────

  static List<DrugWarning> _dedupeWarnings(List<DrugWarning> warnings) {
    final result = <DrugWarning>[];
    final seen = <String>{};

    for (final warning in warnings) {
      final key = _warningKey(warning);
      if (!seen.add(key)) continue;
      result.add(warning);
    }

    return result;
  }

  static String _warningKey(DrugWarning warning) {
    final row = warning.raw;
    switch (warning.type) {
      case DrugWarningType.dosage:
        return [
          warning.type.name,
          row['성분코드'],
          row['성분명'],
          row['1일최대투여량'],
          row['1일최대 투여기준량'],
          row['점검기준 성분함량(총함량)'],
        ].join('|');
      case DrugWarningType.duration:
        return [
          warning.type.name,
          row['성분코드'],
          row['성분명'],
          row['최대투여기간일수'],
        ].join('|');
      case DrugWarningType.efficacyDuplication:
        return [
          warning.type.name,
          row['효능군'],
          row['그룹구분'],
          row['일반명코드'],
          row['성분코드'],
          row['성분명'],
        ].join('|');
      case DrugWarningType.pregnancy:
        return [
          warning.type.name,
          row['성분코드'],
          row['성분명'],
          row['금기등급'],
          row['상세정보'],
        ].join('|');
      case DrugWarningType.comboContraindication:
      case DrugWarningType.ingredientDuplication:
        return '${warning.type.name}|${warning.title}|${warning.message}';
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
    } catch (_) {
      return '';
    }

    return '';
  }
}
