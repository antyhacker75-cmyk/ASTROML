import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class FeedbackService {
  // Deploy backend/telegram-feedback-worker.js and put its HTTPS URL here.
  // Never place a Telegram bot token in the Android application.
  static const String endpoint = 'https://astroml-feedback.terencesimbre075.workers.dev/';

  static const MethodChannel _deviceChannel = MethodChannel('com.astroml.dev/updater');

  static String _formatLocalTimestamp(DateTime dateTime) {
    final hour24 = dateTime.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = hour12.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second $period';
  }

  static Future<void> submit({required String type, required String message}) async {
    if (endpoint.contains('YOUR-WORKER')) {
      throw Exception('Feedback service is not configured yet. Deploy the Telegram Worker and set its URL in feedback_service.dart.');
    }
    final device = await _deviceChannel.invokeMapMethod<String, dynamic>('getDeviceInfo') ?? <String, dynamic>{};
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': type,
            'message': message,
            'device': device['marketName'] ?? device['model'] ?? 'Unknown',
            'android': device['androidVersion'] ?? 'Unknown',
            'chipset': device['chipset'] ?? 'Unknown',
            'manufacturer': device['manufacturer'] ?? 'Unknown',
            'model': device['model'] ?? 'Unknown',
            'deviceCodename': device['device'] ?? 'Unknown',
            'submittedAt': _formatLocalTimestamp(DateTime.now()),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server rejected the feedback (${response.statusCode}). Please try again.');
    }
  }
}
