import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sseudeuson/models/drug_info.dart';
import 'package:sseudeuson/models/user_medication.dart';
import 'package:sseudeuson/services/auth_service.dart';
import 'package:sseudeuson/services/drug_service.dart';

class MedicationService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<UserMedication>> fetchMyMedications() async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return [];

    final rows = await _client
        .from('user_medications')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final medications = <UserMedication>[];
    final seenCodes = <String>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final productCode = (row['product_code'] ?? '').toString();
      if (productCode.isNotEmpty && !seenCodes.add(productCode)) continue;
      final drug = await DrugService.findByProductCode(productCode);
      medications.add(UserMedication.fromJson(row, drug: drug));
    }
    return medications;
  }

  static Future<UserMedication> addMedication({
    required DrugInfo drug,
    String customName = '',
    String instruction = '',
    int durationDays = 7,
    DateTime? startDate,
    DateTime? endDate,
    List<String> scheduleTimes = const ['08:00:00'],
    String mealTimingLabel = '식후',
  }) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) throw StateError('로그인이 필요합니다.');

    final code = drug.displayCode;
    if (code.isEmpty) throw StateError('약품 코드가 없어 약봉투에 저장할 수 없습니다.');

    final existing = await _client
        .from('user_medications')
        .select('id')
        .eq('user_id', userId)
        .eq('product_code', code)
        .eq('is_active', true)
        .maybeSingle();

    if (existing != null) throw StateError('이미 약봉투에 등록된 약입니다.');

    final inserted = await _client
        .from('user_medications')
        .insert({
          'user_id': userId,
          'product_code': code,
          'is_active': true,
          'custom_name': customName,
          'instruction': instruction,
        })
        .select()
        .single();

    final medication = UserMedication.fromJson(
      Map<String, dynamic>.from(inserted),
      drug: drug,
    );

    await _createDefaultSchedules(
      userId: userId,
      medicationId: medication.id,
      durationDays: durationDays,
      startDate: startDate,
      endDate: endDate,
      scheduleTimes: scheduleTimes,
      mealTimingLabel: mealTimingLabel,
    );

    return medication;
  }

  static Future<void> _createDefaultSchedules({
    required String userId,
    required String medicationId,
    required int durationDays,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<String> scheduleTimes,
    required String mealTimingLabel,
  }) async {
    final today = DateTime.now();
    final start = _dateOnly(startDate ?? today);
    final fallbackEnd = DateTime(start.year, start.month, start.day + durationDays - 1);
    final end = _dateOnly(endDate ?? fallbackEnd);
    final days = end.difference(start).inDays + 1;
    if (days <= 0) throw StateError('복용 종료일은 시작일 이후여야 합니다.');

    final rows = <Map<String, dynamic>>[];
    final ruleRows = <Map<String, dynamic>>[];

    for (var d = 0; d < days; d++) {
      final date = DateTime(start.year, start.month, start.day + d);
      for (final time in scheduleTimes) {
        final timing = mealTimingLabel == '식전' ? 'BEFORE' : 'AFTER';
        rows.add({
          'user_id': userId,
          'user_medication_id': medicationId,
          'schedule_date': date.toIso8601String(),
          'schedule_time': time,
          'is_taken': false,
        });
        if (d == 0) {
          ruleRows.add({
            'user_id': userId,
            'user_medication_id': medicationId,
            'rule_type': 'MEAL',
            'base_event': _baseEvent(time),
            'timing': timing,
            'offset_minutes': 0,
          });
        }
      }
    }

    if (rows.isNotEmpty) await _client.from('user_schedules').insert(rows);
    if (ruleRows.isNotEmpty) {
      try {
        await _client.from('medication_rules').insert(ruleRows);
      } catch (_) {
        // 발표 데모에서는 복약 일정 생성을 우선한다. 규칙 저장 실패가 약봉투 저장을 막지 않게 둔다.
      }
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _baseEvent(String time) {
    final h = int.tryParse(time.split(':').first) ?? 8;
    if (h < 11) return 'BREAKFAST';
    if (h < 16) return 'LUNCH';
    return 'DINNER';
  }

  static Future<void> deactivateMedication(String medicationId) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('user_medications')
        .update({'is_active': false})
        .eq('id', medicationId);
    await _client
        .from('user_schedules')
        .update({'deleted_at': now})
        .eq('user_medication_id', medicationId);
  }
}

class ScheduleService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<UserSchedule>> fetchSchedules({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return [];

    await _ensureSchedules(userId: userId, from: from, to: to);

    final rows = await _client
        .from('user_schedules')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .gte('schedule_date', from.toIso8601String())
        .lte('schedule_date', to.toIso8601String())
        .order('schedule_date')
        .order('schedule_time');

    final schedules = <UserSchedule>[];
    final cache = <String, UserMedication?>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final medId = (row['user_medication_id'] ?? '').toString();
      cache[medId] ??= await _fetchMedication(medId);
      schedules.add(UserSchedule.fromJson(row, medication: cache[medId]));
    }
    return schedules;
  }

  static Future<void> setTaken({
    required String scheduleId,
    required bool isTaken,
  }) async {
    await _client
        .from('user_schedules')
        .update({'is_taken': isTaken})
        .eq('id', scheduleId);
  }

  static Future<void> _ensureSchedules({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final medications = await _client
        .from('user_medications')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true);

    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    final dayCount = toDay.difference(fromDay).inDays + 1;
    if (dayCount <= 0) return;

    for (final rawMed in medications as List) {
      final med = Map<String, dynamic>.from(rawMed as Map);
      final medId = (med['id'] ?? '').toString();
      if (medId.isEmpty) continue;

      final instruction = (med['instruction'] ?? '').toString();
      final times = _timesFromInstruction(instruction);
      final bounds = await _fetchBounds(userId: userId, medicationId: medId);

      final effFrom = bounds == null || fromDay.isAfter(bounds.$1) ? fromDay : bounds.$1;
      final effTo = bounds == null || toDay.isBefore(bounds.$2) ? toDay : bounds.$2;
      if (effTo.isBefore(effFrom)) continue;

      final existing = await _client
          .from('user_schedules')
          .select('schedule_date,schedule_time')
          .eq('user_id', userId)
          .eq('user_medication_id', medId)
          .isFilter('deleted_at', null)
          .gte('schedule_date', effFrom.toIso8601String())
          .lte('schedule_date', DateTime(effTo.year, effTo.month, effTo.day, 23, 59, 59).toIso8601String());

      final existingKeys = <String>{};
      for (final rawS in existing as List) {
        final s = Map<String, dynamic>.from(rawS as Map);
        final date = DateTime.tryParse((s['schedule_date'] ?? '').toString());
        final time = (s['schedule_time'] ?? '').toString();
        if (date == null || time.isEmpty) continue;
        existingKeys.add('${_dateStr(date)}|$time');
      }

      final rows = <Map<String, dynamic>>[];
      final effDays = effTo.difference(effFrom).inDays + 1;
      for (var d = 0; d < dayCount; d++) {
        if (d >= effDays) break;
        final date = DateTime(effFrom.year, effFrom.month, effFrom.day + d);
        for (final time in times) {
          if (existingKeys.contains('${_dateStr(date)}|$time')) continue;
          rows.add({
            'user_id': userId,
            'user_medication_id': medId,
            'schedule_date': date.toIso8601String(),
            'schedule_time': time,
            'is_taken': false,
          });
        }
      }
      if (rows.isNotEmpty) await _client.from('user_schedules').insert(rows);
    }
  }

  static List<String> _timesFromInstruction(String instruction) {
    final times = <String>[];
    if (instruction.contains('아침')) times.add('09:00:00');
    if (instruction.contains('점심')) times.add('12:00:00');
    if (instruction.contains('저녁')) times.add('18:00:00');
    if (times.isEmpty) times.add('09:00:00');
    return times;
  }

  static Future<(DateTime, DateTime)?> _fetchBounds({
    required String userId,
    required String medicationId,
  }) async {
    final rows = await _client
        .from('user_schedules')
        .select('schedule_date')
        .eq('user_id', userId)
        .eq('user_medication_id', medicationId)
        .isFilter('deleted_at', null)
        .order('schedule_date');

    DateTime? minDate;
    DateTime? maxDate;
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.tryParse((row['schedule_date'] ?? '').toString());
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (minDate == null || day.isBefore(minDate)) minDate = day;
      if (maxDate == null || day.isAfter(maxDate)) maxDate = day;
    }
    if (minDate == null || maxDate == null) return null;
    return (minDate, maxDate);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<UserMedication?> _fetchMedication(String medicationId) async {
    if (medicationId.isEmpty) return null;
    final row = await _client
        .from('user_medications')
        .select()
        .eq('id', medicationId)
        .maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    final productCode = (map['product_code'] ?? '').toString();
    final drug = await DrugService.findByProductCode(productCode);
    return UserMedication.fromJson(map, drug: drug);
  }
}

class CalendarMemoService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchMemos({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return [];

    final rows = await _client
        .from('calendar_memos')
        .select()
        .eq('user_id', userId)
        .gte('memo_date', _dateStr(from))
        .lte('memo_date', _dateStr(to))
        .order('memo_date');

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<void> saveMemo({
    required DateTime date,
    required String content,
  }) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) throw StateError('로그인이 필요합니다.');
    await _client.from('calendar_memos').insert({
      'user_id': userId,
      'memo_date': _dateStr(date),
      'content': content,
    });
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
