import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/aes_crypto.dart';

class LuminaApi {
  LuminaApi._();

  static const _base = 'https://mlbbbackend.pages.dev';

  static const _heroes = '/heroes-bytes.txt';
  static const _newlyAdded = '/newly-added-skin.txt';
  static const _newlyAddedFallback = '/newly-added-skin-bytes.txt';
  static const _emote = '/emote-bytes.txt';
  static const _trail = '/trail-bytes.txt';
  static const _recall = '/recall-bytes.txt';
  static const _elimination = '/elimination-bytes.txt';
  static const _respawn = '/respawn-bytes.txt';

  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);

  static Future<String> _fetchDecrypted(String endpoint) async {
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _client
            .get(Uri.parse('$_base$endpoint'))
            .timeout(_timeout);
        if (response.statusCode != 200) {
          throw http.ClientException(
              'HTTP ${response.statusCode} for $endpoint');
        }
        final decrypted = AesCrypto.decryptBase64(response.body);
        if (decrypted == null) {
          throw FormatException(
              'Failed to decrypt payload for $endpoint');
        }
        return decrypted;
      } catch (e) {
        if (attempt == _maxRetries) rethrow;
        await Future<void>.delayed(_retryDelay * attempt);
      }
    }
    throw StateError('unreachable');
  }

  static Future<List<HeroEntry>> fetchHeroes() async {
    final text = await _fetchDecrypted(_heroes);
    final list = jsonDecode(text) as List;
    return list
        .map((e) => HeroEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<CosmeticItem>> fetchNewlyAdded() async {
    Object? decoded;

    // The current endpoint may return plain JSON or an encrypted Base64
    // payload. Try both formats on the same response before using the legacy
    // bytes endpoint.
    try {
      final response = await _client
          .get(Uri.parse('$_base$_newlyAdded'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
            'HTTP ${response.statusCode} for $_newlyAdded');
      }
      final body = response.body.trim().replaceFirst('\uFEFF', '');
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        final decrypted = AesCrypto.decryptBase64(body);
        if (decrypted == null) rethrow;
        decoded = jsonDecode(decrypted.trim().replaceFirst('\uFEFF', ''));
      }
    } catch (_) {
      final text = await _fetchDecrypted(_newlyAddedFallback);
      decoded = jsonDecode(text.trim().replaceFirst('\uFEFF', ''));
    }

    // Accept the raw array and common object wrappers used by text endpoints.
    if (decoded is Map<String, dynamic>) {
      decoded = decoded['newlyAdded'] ??
          decoded['newly-added-skin'] ??
          decoded['skins'] ??
          decoded['otherSkins'];
    }
    if (decoded is! List) {
      throw const FormatException(
          'Newly added skin response is not a JSON list');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CosmeticItem.fromJson)
        .where((item) => item.title.isNotEmpty && item.img.isNotEmpty)
        .toList();
  }

  static Future<List<CosmeticItem>> fetchEmotes() => _fetchCosmetic(_emote);
  static Future<List<CosmeticItem>> fetchTrails() => _fetchCosmetic(_trail);
  static Future<List<CosmeticItem>> fetchRecalls() => _fetchCosmetic(_recall);
  static Future<List<CosmeticItem>> fetchEliminations() =>
      _fetchCosmetic(_elimination);
  static Future<List<CosmeticItem>> fetchRespaws() => _fetchCosmetic(_respawn);

  static Future<List<CosmeticItem>> _fetchCosmetic(String endpoint) async {
    final text = await _fetchDecrypted(endpoint);
    final list = jsonDecode(text) as List;
    return list
        .map((e) => CosmeticItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
