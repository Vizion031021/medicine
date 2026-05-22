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
      _safeWarnings(() => _fetchDosageWarnings(productCode, ingredientCode)),
      _safeWarnings(() => _fetchDurationWarnings(productCode, ingredientCode)),
      _safeWarnings(() => _fetchEfficacyDupWarnings(productCode, ingredientCode)),
      _safeWarnings(() => _fetchPregnancyWarnings(productCode, ingredientCode)),
    ]);

    return results.expand((items) => items).toList();
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

    final codes = drugs.map((drug) => drug.displayCode).where((code) => code.isNotEmpty).toSet();
    final ingredientCodes =
        drugs.map((drug) => drug.ingredientCode).where((code) => code.isNotEmpty).toSet();
    final warnings = <DrugWarning>[];

    if (codes.isNotEmpty) {
      final comboRows = await _client
          .from('combo_contraindicated_drugs')
          .select()
          .inFilter('제품코드1', codes.toList());

      for (final raw in comboRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (codes.contains((row['제품코드2'] ?? '').toString())) {
          warnings.add(
            DrugWarning(
              type: DrugWarningType.comboContraindication,
              title: '병용 금기',
              message:
                  '${row['제품명1'] ?? ''} + ${row['제품명2'] ?? ''}: ${row['금기사유'] ?? '병용 주의가 필요합니다.'}',
              severity: '높음',
              raw: row,
            ),
          );
        }
      }
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    if (ingredientCodes.isNotEmpty) {
      final dupRows = await _client
          .from('efficacy_dup_warnings')
          .select()
          .inFilter('성분코드', ingredientCodes.toList());

      for (final raw in dupRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final group = (row['효능군'] ?? '').toString();
        if (group.isEmpty) continue;
        groups.putIfAbsent(group, () => []).add(row);
      }
    }

    for (final entry in groups.entries) {
      final matchedCodes =
          entry.value.map((row) => (row['성분코드'] ?? '').toString()).toSet();
      if (matchedCodes.length > 1) {
        warnings.add(
          DrugWarning(
            type: DrugWarningType.efficacyDuplication,
            title: '효능군 중복',
            message: '${entry.key} 계열 약이 중복될 수 있습니다.',
            severity: '중간',
            raw: {'효능군': entry.key, 'items': entry.value},
          ),
        );
      }
    }

    return warnings;
  }

  static Future<List<DrugWarning>> _fetchComboWarnings(String productCode) async {
    if (productCode.isEmpty) return [];
    final rows = await _client
        .from('combo_contraindicated_drugs')
        .select()
        .or('제품코드1.eq.$productCode,제품코드2.eq.$productCode')
        .limit(20);

    return (rows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return DrugWarning(
        type: DrugWarningType.comboContraindication,
        title: '병용 금기',
        message:
            '${row['제품명1'] ?? ''} + ${row['제품명2'] ?? ''}: ${row['금기사유'] ?? '병용 금기 정보가 있습니다.'}',
        severity: '높음',
        raw: row,
      );
    }).toList();
  }

  static Future<List<DrugWarning>> _fetchDosageWarnings(
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
        message: '${row['제품명'] ?? row['성분명'] ?? '해당 약'} 1일 최대 투여량: $maxDose',
        severity: '중간',
        raw: row,
      );
    }).toList();
  }

  static Future<List<DrugWarning>> _fetchDurationWarnings(
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
            '${row['제품명'] ?? row['성분명'] ?? '해당 약'} 최대 투여기간: ${row['최대투여기간일수'] ?? '-'}일',
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
            '${row['제품명'] ?? row['성분명'] ?? '해당 약'} 금기등급: ${row['금기등급'] ?? '-'} / ${row['상세정보'] ?? ''}',
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

    final rows = await _client.from(table).select().or(filters.join(',')).limit(20);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
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
