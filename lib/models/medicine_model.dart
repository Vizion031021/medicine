import 'package:flutter/material.dart';

// ─── 약물 복용 시간대 ───────────────────────────────────────────────────────

enum TimeOfDay2 { morning, lunch, evening }

extension TimeOfDay2Ext on TimeOfDay2 {
  String get label {
    switch (this) {
      case TimeOfDay2.morning:
        return '아침';
      case TimeOfDay2.lunch:
        return '점심';
      case TimeOfDay2.evening:
        return '저녁';
    }
  }
}
// ─── 식전/식후 타이밍 ───────────────────────────────────────────────────────

enum MealTiming {
  before15,
  before30,
  afterImmediate,
  after1Hour,
}
extension MealTimingExt on MealTiming {
  String get label {
    switch (this) {
      case MealTiming.before15:
        return '식전 15분';
      case MealTiming.before30:
        return '식전 30분';
      case MealTiming.afterImmediate:
        return '식후 직후';
      case MealTiming.after1Hour:
        return '식후 1시간';
    }
  }
}
// ─── 상호작용 심각도 ────────────────────────────────────────────────────────

enum InteractionSeverity { safe, caution, warning, danger }

extension InteractionSeverityExt on InteractionSeverity {
  String get label {
    switch (this) {
      case InteractionSeverity.safe:
        return '✓ 안전';
      case InteractionSeverity.caution:
        return '! 주의';
      case InteractionSeverity.warning:
        return '⚠ 주의';
      case InteractionSeverity.danger:
        return '⛔ 위험';
    }
  }

  Color get color {
    switch (this) {
      case InteractionSeverity.safe:
        return const Color(0xFF3B9E72);
      case InteractionSeverity.caution:
        return const Color(0xFFEF9F27);
      case InteractionSeverity.warning:
        return const Color(0xFFEF9F27);
      case InteractionSeverity.danger:
        return const Color(0xFFE24B4A);
    }
  }

  Color get bgColor {
    switch (this) {
      case InteractionSeverity.safe:
        return const Color(0xFFE8F5E9);
      case InteractionSeverity.caution:
        return const Color(0xFFFEF3E2);
      case InteractionSeverity.warning:
        return const Color(0xFFFEF3E2);
      case InteractionSeverity.danger:
        return const Color(0xFFFDEEEE);
    }
  }
}

// ─── 약물 상호작용 ──────────────────────────────────────────────────────────

class DrugInteraction {
  final String drug1;
  final String drug2;
  final InteractionSeverity severity;
  final String description;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
  });
}

// ─── 약물 모델 ──────────────────────────────────────────────────────────────

class Medicine {
  final String id;
  final String name;
  final String englishName;
  final String category;
  final String dosage;
  List<TimeOfDay2> timesOfDay;
  MealTiming mealTiming;
  int dailyCount;
  int durationDays; // 0 = 계속 복용
  String memo;
  List<String> cautions;
  List<String> sideEffects;
  List<DrugInteraction> interactions;

  Medicine({
    required this.id,
    required this.name,
    required this.englishName,
    required this.category,
    required this.dosage,
    this.timesOfDay = const [TimeOfDay2.morning],
    this.mealTiming = MealTiming.afterImmediate,
    this.dailyCount = 1,
    this.durationDays = 30,
    this.memo = '',
    this.cautions = const [],
    this.sideEffects = const [],
    this.interactions = const [],
  });

  Medicine copyWith({
    List<TimeOfDay2>? timesOfDay,
    MealTiming? mealTiming,
    int? dailyCount,
    int? durationDays,
    String? memo,
  }) {
    return Medicine(
      id: id,
      name: name,
      englishName: englishName,
      category: category,
      dosage: dosage,
      timesOfDay: timesOfDay ?? this.timesOfDay,
      mealTiming: mealTiming ?? this.mealTiming,
      dailyCount: dailyCount ?? this.dailyCount,
      durationDays: durationDays ?? this.durationDays,
      memo: memo ?? this.memo,
      cautions: cautions,
      sideEffects: sideEffects,
      interactions: interactions,
    );
  }
}

// ─── 약봉투 모델 ────────────────────────────────────────────────────────────

class MedicineBag {
  final String id;
  String name;
  Color color;
  List<Medicine> medicines;

  MedicineBag({
    required this.id,
    required this.name,
    required this.color,
    List<Medicine>? medicines,
  }) : medicines = medicines ?? [];

  bool get hasWarning => _checkInteractions();

  bool _checkInteractions() {
    for (final med in medicines) {
      for (final interaction in med.interactions) {
        if (medicines.any((m) =>
            m.name == interaction.drug2 &&
            interaction.severity != InteractionSeverity.safe)) {
          return true;
        }
      }
    }
    return false;
  }
}
