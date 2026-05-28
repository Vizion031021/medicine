import 'package:flutter/material.dart';

enum TimeOfDay2 { morning, lunch, evening }

extension TimeOfDay2Ext on TimeOfDay2 {
  String get label {
    switch (this) {
      case TimeOfDay2.morning: return '아침';
      case TimeOfDay2.lunch:   return '점심';
      case TimeOfDay2.evening: return '저녁';
    }
  }
}

enum MealTiming { before15, before30, afterImmediate, after1Hour }

extension MealTimingExt on MealTiming {
  String get label {
    switch (this) {
      case MealTiming.before15:       return '식전 15분';
      case MealTiming.before30:       return '식전 30분';
      case MealTiming.afterImmediate: return '식후 직후';
      case MealTiming.after1Hour:     return '식후 1시간';
    }
  }
}

class Medicine {
  final String id;
  final String name;
  final String englishName;
  final String category;
  final String dosage;
  List<TimeOfDay2> timesOfDay;
  MealTiming mealTiming;
  int dailyCount;
  int durationDays;
  String memo;
  List<String> cautions;
  List<String> sideEffects;

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
  });
}

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
}
