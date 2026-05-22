import 'package:sseudeuson/models/drug_info.dart';

class UserMedication {
  final String id;
  final String userId;
  final String productCode;
  final bool isActive;
  final String customName;
  final String instruction;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DrugInfo? drug;

  const UserMedication({
    required this.id,
    required this.userId,
    required this.productCode,
    required this.isActive,
    required this.customName,
    required this.instruction,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.drug,
  });

  factory UserMedication.fromJson(
    Map<String, dynamic> json, {
    DrugInfo? drug,
  }) {
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return UserMedication(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      productCode: (json['product_code'] ?? '').toString(),
      isActive: json['is_active'] != false,
      customName: (json['custom_name'] ?? '').toString(),
      instruction: (json['instruction'] ?? '').toString(),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      deletedAt: date('deleted_at') ?? date('deleated_at'),
      drug: drug,
    );
  }

  String get displayName {
    if (customName.isNotEmpty) return customName;
    if (drug != null && drug!.name.isNotEmpty) return drug!.name;
    return productCode;
  }
}

class UserSchedule {
  final String id;
  final String userId;
  final String userMedicationId;
  final DateTime date;
  final String time;
  final bool isTaken;
  final UserMedication? medication;

  const UserSchedule({
    required this.id,
    required this.userId,
    required this.userMedicationId,
    required this.date,
    required this.time,
    required this.isTaken,
    this.medication,
  });

  factory UserSchedule.fromJson(
    Map<String, dynamic> json, {
    UserMedication? medication,
  }) {
    return UserSchedule(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      userMedicationId: (json['user_medication_id'] ?? '').toString(),
      date: DateTime.tryParse((json['schedule_date'] ?? '').toString()) ??
          DateTime.now(),
      time: (json['schedule_time'] ?? '').toString(),
      isTaken: json['is_taken'] == true,
      medication: medication,
    );
  }
}
