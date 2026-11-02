import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Checks the public GitHub Releases API and downloads the matching ASTROML APK.
/// Change these two values if the GitHub repository is renamed or transferred.
class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  static const _channel = MethodChannel('com.astroml.dev/updater');
  static const _owner = 'antyhacker75-cmyk';
  static const _repo = 'yuyu'; // GitHub repository slug; app branding/package is ASTROML.
  static const _api = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  bool _checking = false;
  bool _downloading = false;
  bool _updateAvailable = false;
  String _currentVersion = '...';
  String _status = 'Check GitHub for the latest ASTROML release.';
  String _notes = '';
  String? _apkUrl;
  String? _apkName;
  String? _downloadedPath;
  int _progress = 0;
  List<String> _images = [];
  bool _autoCheck = true;

  static const _autoKey = 'astroml_auto_update_check';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoCheck();

  }

  Future<void> _loadAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoKey) ?? true;
    if (!mounted) return;
    setState(() => _autoCheck = enabled);
    await _configurePush(enabled);
    if (enabled) {
      // Initial launch check is a fallback; release alerts are pushed by FCM.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _autoCheck) {
          _checkForUpdate(silent: true);
        }
      });
    }
  }

  Future<void> _configurePush(bool enabled) async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (enabled) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        await messaging.subscribeToTopic('astroml_updates');
      } else {
        await messaging.unsubscribeFromTopic('astroml_updates');
      }
    } catch (_) {
      // Manual GitHub checking remains available if push setup is unavailable.
    }
  }

  Future<void> _setAutoCheck(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, value);
    if (!mounted) return;
    setState(() => _autoCheck = value);
    await _configurePush(value);
    if (value) _checkForUpdate(silent: true);
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      if (mounted) setState(() => _currentVersion = '${info?['versionName'] ?? '0.0.0'}');
    } catch (_) {
      if (mounted) setState(() => _currentVersion = 'unknown');
    }
  }

  int _compareVersions(String a, String b) {
    List<int> parse(String value) => value.split(RegExp(r'[^0-9]+')).where((e) => e.isNotEmpty).map(int.parse).toList();
    final aa = parse(a), bb = parse(b);
    for (var i = 0; i < (aa.length > bb.length ? aa.length : bb.length); i++) {
      final x = i < aa.length ? aa[i] : 0;
      final y = i < bb.length ? bb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    if (_checking) return;
    if (!silent && mounted) {
      setState(() {
        _checking = true;
        _status = 'Checking latest release...';
      });
    } else {
      _checking = true;
    }
    try {
      final response = await http.get(Uri.parse(_api), headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw Exception('GitHub returned HTTP ${response.statusCode}. Check the repository or release visibility.');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = '${data['tag_name'] ?? ''}';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      final body = '${data['body'] ?? ''}';
      final assets = (data['assets'] as List? ?? []).cast<Map<String, dynamic>>();
      final info = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      final abis = (info?['abis'] as List? ?? []).map((e) => '$e').toList();
      final isArm64 = abis.any((e) => e == 'arm64-v8a');
      final isArm32 = !isArm64 && abis.any((e) => e == 'armeabi-v7a');
      final wanted = isArm64 ? '-arm64.apk' : isArm32 ? '-arm32.apk' : '-universal.apk';
      Map<String, dynamic>? asset;
      for (final item in assets) {
        final name = '${item['name'] ?? ''}';
        if (name.toLowerCase().endsWith(wanted)) { asset = item; break; }
      }
      asset ??= assets.cast<Map<String, dynamic>?>().firstWhere(
        (item) => '${item?['name'] ?? ''}'.toLowerCase().endsWith('-universal.apk'),
        orElse: () => null,
      );
      if (asset == null) throw Exception('No compatible APK was attached to the latest release.');
      final imageMatches = RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)').allMatches(body);
      final images = imageMatches.map((m) => m.group(1)!).take(2).toList();
      if (!mounted) return;
      setState(() {
        _notes = body.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '').trim();
        _images = images;
        _apkUrl = '${asset!['browser_download_url']}';
        _apkName = '${asset['name']}';
        _updateAvailable = _compareVersions(version, _currentVersion) > 0;
        _downloadedPath = null;
        _status = _updateAvailable ? 'ASTROML $version is available.' : 'You are using the latest version.';
      });
      if (_updateAvailable) {
        try { await _channel.invokeMethod('showUpdateNotification', {'version': version}); } catch (_) {}
        if (!silent && mounted) _showUpdateDialog(version);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _status = 'Update check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showUpdateDialog(String version) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('ASTROML $version is available'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (_notes.isNotEmpty) Text(_notes.replaceAll(RegExp(r'[#*_`]'), ''), style: const TextStyle(height: 1.4)),
          for (final image in _images.take(2)) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(image, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ],
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        FilledButton(onPressed: () { Navigator.pop(ctx); _downloadUpdate(); }, child: const Text('Download update')),
      ],
    ));
  }

  Future<void> _downloadUpdate() async {
    final url = _apkUrl;
    final name = _apkName;
    if (url == null || name == null) return;
    setState(() { _downloading = true; _progress = 0; _status = 'Downloading $name...'; });
    try {
      final dir = await getApplicationSupportDirectory();
      final updates = Directory('${dir.path}/updates');
      await updates.create(recursive: true);
      final target = File('${updates.path}/$name');
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'application/octet-stream';
      final client = http.Client();
      try {
        final response = await client.send(request).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) throw Exception('Download failed: HTTP ${response.statusCode}.');
        final total = response.contentLength ?? 0;
        var received = 0;
        final sink = target.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (mounted && total > 0) setState(() => _progress = (received * 100 / total).round().clamp(0, 100).toInt());
        }
        await sink.flush();
        await sink.close();
        if (await target.length() < 1024 * 100) throw Exception('Downloaded APK is unexpectedly small.');
      } finally {
        client.close();
      }
      if (!mounted) return;
      setState(() { _downloadedPath = target.path; _status = 'Download complete. Tap Install to continue.'; _progress = 100; });
    } catch (e) {
      if (mounted) setState(() => _status = 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _installUpdate() async {
    final path = _downloadedPath;
    if (path == null) return;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!allowed) {
        await _channel.invokeMethod('requestInstallPermission');
        if (mounted) setState(() => _status = 'Allow ASTROML to install unknown apps in Android settings, return here, then tap Install again.');
        return;
      }
      await _channel.invokeMethod('installApk', {'path': path});
    } on PlatformException catch (e) {
      if (mounted) setState(() => _status = e.message ?? 'Could not open the Android installer.');
    }
  }

  @override
  void dispose() { super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .65)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.system_update_alt_rounded, color: cs.primary), const SizedBox(width: 9), const Expanded(child: Text('App updates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))), Text('v$_currentVersion', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatically check for updates'),
          subtitle: Text(_autoCheck ? 'Receives release alerts through Firebase push notifications.' : 'Automatic checks and update alerts are off.'),
          value: _autoCheck, onChanged: _setAutoCheck,
        ),
        const SizedBox(height: 7),
        Text(_status, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),

        const SizedBox(height: 12),
        if (_downloading) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
        if (_downloading) Padding(padding: const EdgeInsets.only(top: 5), child: Text('$_progress%', style: const TextStyle(fontSize: 11))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!_autoCheck) OutlinedButton.icon(onPressed: _checking || _downloading ? null : _checkForUpdate, icon: _checking ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 17), label: const Text('Check for updates')),
          if (_updateAvailable && _downloadedPath == null) FilledButton.icon(onPressed: _downloading ? null : _downloadUpdate, icon: const Icon(Icons.download_rounded, size: 17), label: const Text('Download APK')),
          if (_downloadedPath != null) FilledButton.icon(onPressed: _installUpdate, icon: const Icon(Icons.install_mobile_rounded, size: 17), label: const Text('Install update')),
        ]),
        const SizedBox(height: 5),
        Text('APK installation is started automatically after you tap Install. Android may ask you to allow installs from ASTROML and confirm the update.', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
