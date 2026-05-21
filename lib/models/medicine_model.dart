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

// ─── 복약 기록 모델 ─────────────────────────────────────────────────────────

class MedicationLog {
  final DateTime date;
  final String bagName;
  final List<String> medicineNames;
  final bool taken;
  final DateTime? takenAt;
  String memo;

  MedicationLog({
    required this.date,
    required this.bagName,
    required this.medicineNames,
    required this.taken,
    this.takenAt,
    this.memo = '',
  });
}

// ─── 더미 데이터 ────────────────────────────────────────────────────────────

class DummyData {
  static final List<Medicine> searchableMedicines = [
    Medicine(
      id: 'm1',
      name: '메트포르민 500mg',
      englishName: 'Metformin HCl',
      category: '당뇨병용제',
      dosage: '500mg',
      timesOfDay: [TimeOfDay2.morning, TimeOfDay2.evening],
      mealTiming: MealTiming.afterImmediate,
      dailyCount: 2,
      durationDays: 30,
      memo: '저혈당 증상 주의, 식사 거르지 말 것',
      cautions: [
        '신장 기능 저하 환자 주의',
        '알코올 섭취 시 유산산증 위험',
        'CT 조영제 검사 전 복용 중단 필요',
        '임부/수유부 복용 금지',
      ],
      sideEffects: ['소화불량', '구역감', '설사', '식욕저하', '두통 (드묾)'],
      interactions: [
        const DrugInteraction(
          drug1: '메트포르민',
          drug2: '글리메피리드',
          severity: InteractionSeverity.warning,
          description:
              '저혈당 위험 증가. 두 약 모두 혈당을 낮추므로 병용 시 저혈당 발생 가능. 식사를 거르지 마세요.',
        ),
      ],
    ),
    Medicine(
      id: 'm2',
      name: '글리메피리드 2mg',
      englishName: 'Glimepiride',
      category: '당뇨병용제',
      dosage: '2mg',
      timesOfDay: [TimeOfDay2.lunch],
      mealTiming: MealTiming.before15,
      cautions: ['저혈당 주의', '신장 기능 장애 시 용량 조절'],
      sideEffects: ['저혈당', '두통', '어지러움'],
    ),
    Medicine(
      id: 'm3',
      name: '아스피린 100mg',
      englishName: 'Aspirin',
      category: '항혈소판제',
      dosage: '100mg',
      timesOfDay: [TimeOfDay2.morning],
      mealTiming: MealTiming.afterImmediate,
      cautions: ['위장관 출혈 주의', '수술 전 복용 중단'],
      sideEffects: ['위장 불편감', '속쓰림'],
    ),
    Medicine(
      id: 'm4',
      name: '암로디핀 5mg',
      englishName: 'Amlodipine',
      category: '칼슘채널차단제 · 혈압약',
      dosage: '5mg',
      timesOfDay: [TimeOfDay2.evening],
      mealTiming: MealTiming.afterImmediate,
      cautions: ['저혈압 주의', '자몽 섭취 금지'],
      sideEffects: ['발목 부종', '두통', '안면홍조'],
    ),
    Medicine(
      id: 'm5',
      name: '로수바스타틴 10mg',
      englishName: 'Rosuvastatin',
      category: '고지혈증 치료제',
      dosage: '10mg',
      timesOfDay: [TimeOfDay2.evening],
      mealTiming: MealTiming.afterImmediate,
      cautions: ['임부 복용 금지', '근육통 발생 시 즉시 중단'],
      sideEffects: ['근육통', '두통', '위장 불편감'],
    ),
    Medicine(
      id: 'm6',
      name: '타이레놀정 500mg',
      englishName: 'Acetaminophen',
      category: '해열진통제',
      dosage: '500mg',
      timesOfDay: [TimeOfDay2.morning],
      mealTiming: MealTiming.afterImmediate,
      cautions: ['음주 시 간 손상 위험', '하루 최대 4g 초과 금지'],
      sideEffects: ['간 손상 (과량 복용 시)'],
    ),
    Medicine(
      id: 'm7',
      name: '발사르탄 80mg',
      englishName: 'Valsartan',
      category: 'ARB · 혈압약',
      dosage: '80mg',
      cautions: ['임부 복용 금지', '고칼륨혈증 주의'],
      sideEffects: ['어지러움', '피로감'],
      interactions: [
        const DrugInteraction(
          drug1: '발사르탄',
          drug2: '에날라프릴',
          severity: InteractionSeverity.warning,
          description: '신기능 저하, 고칼륨혈증, 저혈압 위험 증가. 동일 계열 병용을 피하세요.',
        ),
      ],
    ),
    Medicine(
      id: 'm8',
      name: '에날라프릴 10mg',
      englishName: 'Enalapril',
      category: 'ACE억제제 · 혈압약',
      dosage: '10mg',
      cautions: ['임부 복용 금지', '마른기침 부작용'],
      sideEffects: ['마른기침', '어지러움', '두통'],
    ),
  ];

  static List<MedicineBag> get defaultBags => [
        MedicineBag(
          id: 'bag1',
          name: '아침약 봉투',
          color: const Color(0xFF7B6FD4),
          medicines: [
            searchableMedicines[0], // 메트포르민
            searchableMedicines[1], // 글리메피리드
            searchableMedicines[2], // 아스피린
          ],
        ),
        MedicineBag(
          id: 'bag2',
          name: '저녁약 봉투',
          color: const Color(0xFF4A9EE8),
          medicines: [
            searchableMedicines[3], // 암로디핀
            searchableMedicines[4], // 로수바스타틴
          ],
        ),
      ];

  static Map<DateTime, List<MedicationLog>> get sampleLogs {
    final now = DateTime.now();
    final logs = <DateTime, List<MedicationLog>>{};

    for (int i = 1; i <= 20; i++) {
      final date = DateTime(now.year, now.month, i);
      if (i != 4) {
        // 4일은 미복용
        logs[date] = [
          MedicationLog(
            date: date,
            bagName: '아침약 봉투',
            medicineNames: ['메트포르민', '아스피린'],
            taken: true,
            takenAt: DateTime(date.year, date.month, date.day, 8, 12),
            memo: i == DateTime.now().day ? '식후 30분 복용, 속쓰림 없었음' : '',
          ),
        ];
      } else {
        logs[date] = [
          MedicationLog(
            date: date,
            bagName: '아침약 봉투',
            medicineNames: ['메트포르민', '아스피린'],
            taken: false,
            memo: '',
          ),
        ];
      }
    }
    return logs;
  }
}
