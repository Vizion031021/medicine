class NotificationService {
  static Future<void> initialize() async {}

  static Future<void> scheduleMedicationReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {}
}
