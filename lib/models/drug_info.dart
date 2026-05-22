class DrugInfo {
  final String id;
  final String name;
  final String company;
  final String standardCode;
  final String productCode;
  final String ingredientCode;
  final String specification;
  final String totalQuantity;
  final String formType;
  final String packageType;
  final String approvalCode;
  final String approvalDate;
  final String prescriptionType;
  final String atcCode;
  final String specialManagementType;
  final String ingredientName;
  final Map<String, dynamic> raw;

  const DrugInfo({
    required this.id,
    required this.name,
    required this.company,
    required this.standardCode,
    required this.productCode,
    required this.ingredientCode,
    required this.specification,
    required this.totalQuantity,
    required this.formType,
    required this.packageType,
    required this.approvalCode,
    required this.approvalDate,
    required this.prescriptionType,
    required this.atcCode,
    required this.specialManagementType,
    required this.ingredientName,
    required this.raw,
  });

  factory DrugInfo.fromJson(Map<String, dynamic> json) {
    String value(String key) => (json[key] ?? '').toString();

    return DrugInfo(
      id: value('ID'),
      name: value('한글상품명'),
      company: value('업체명'),
      standardCode: value('표준코드'),
      productCode: _firstValue(json, [
        '대표코드',
        '표준코드',
      ]),
      ingredientCode: _firstValue(json, [
        '일반명코드(성분명코드)',
        '일반명코드',
        '성분명코드',
        '성분코드',
      ]),
      specification: value('약품규격'),
      totalQuantity: value('제품총수량'),
      formType: value('제형구분'),
      packageType: value('포장형태'),
      approvalCode: value('품목기준코드'),
      approvalDate: value('품목허가일자'),
      prescriptionType: value('전문일반구분'),
      atcCode: value('국제표준코드(ATC코드)'),
      specialManagementType: value('특수관리약품구분'),
      ingredientName: _firstValue(json, ['성분명', '일반명', '주성분']),
      raw: json,
    );
  }

  String get displayCode => productCode.isNotEmpty ? productCode : standardCode;

  String get ingredientLabel {
    if (ingredientName.isNotEmpty && ingredientCode.isNotEmpty) {
      return '$ingredientName ($ingredientCode)';
    }
    if (ingredientName.isNotEmpty) return ingredientName;
    if (ingredientCode.isNotEmpty) return ingredientCode;
    return '성분 정보 없음';
  }

  static String _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = (json[key] ?? '').toString();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

enum DrugWarningType {
  comboContraindication,
  dosage,
  duration,
  efficacyDuplication,
  pregnancy,
}

class DrugWarning {
  final DrugWarningType type;
  final String title;
  final String message;
  final String severity;
  final Map<String, dynamic> raw;

  const DrugWarning({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.raw,
  });

  bool get isHighRisk =>
      type == DrugWarningType.comboContraindication ||
      type == DrugWarningType.pregnancy;
}
