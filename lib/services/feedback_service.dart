import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedbackService {
  // Deploy backend/telegram-feedback-worker.js and put its HTTPS URL here.
  // Never place a Telegram bot token in the Android application.
  static const String endpoint = 'https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev';

  static Future<void> submit({required String type, required String message}) async {
    if (endpoint.contains('YOUR-WORKER')) {
      throw Exception('Feedback service is not configured yet. Deploy the Telegram Worker and set its URL in feedback_service.dart.');
    }
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': type,
            'message': message,
            'device': 'Infinix Note 50 Pro',
            'android': '16',
            'chipset': 'MediaTek Helio G100',
            'manufacturer': 'Infinix',
            'model': 'X6855',
            'submittedAt': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server rejected the feedback (${response.statusCode}). Please try again.');
    }
  }
}
