import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
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
        // Automatic and manual checks use the exact same release dialog.
        if (mounted) _showUpdateDialog(version);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _status = 'Update check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  TextSpan _markdownSpan(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) spans.add(TextSpan(text: text.substring(cursor, match.start), style: base));
      final bold = match.group(1) ?? match.group(2);
      final italic = match.group(3) ?? match.group(4);
      final code = match.group(5);
      if (bold != null) {
        spans.add(TextSpan(text: bold, style: base.copyWith(fontWeight: FontWeight.w800)));
      } else if (italic != null) {
        spans.add(TextSpan(text: italic, style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (code != null) {
        spans.add(TextSpan(text: code, style: base.copyWith(fontFamily: 'monospace', backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: base));
    return TextSpan(children: spans);
  }

  Widget _buildReleaseNotes(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _notes.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in lines) ...[
          if (raw.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Builder(builder: (context) {
                final line = raw.trim();
                final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
                final bullet = RegExp(r'^(?:[-*]|\d+\.)\s+(.+)$').firstMatch(line);
                final content = heading?.group(2) ?? bullet?.group(1) ?? line;
                final style = heading != null
                    ? theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)
                    : theme.textTheme.bodyMedium!.copyWith(height: 1.45);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (bullet != null) Padding(padding: const EdgeInsets.only(right: 8, top: 1), child: Icon(Icons.circle, size: 6, color: theme.colorScheme.primary)),
                  if (heading != null) const SizedBox(width: 0),
                  Expanded(child: RichText(text: _markdownSpan(content, style))),
                ]);
              }),
            ),
        ],
      ],
    );
  }

  void _showUpdateDialog(String version) {
    showDialog<void>(
      context: context,
      barrierDismissible: !_downloading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) {
          final cs = Theme.of(dialogContext).colorScheme;
          return Dialog(
            backgroundColor: cs.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: cs.primary.withValues(alpha: .28))),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cs.primary.withValues(alpha: .20), cs.tertiary.withValues(alpha: .08)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: cs.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.rocket_launch_rounded, color: cs.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ASTROML UPDATE', style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                      Text('Version $version is ready', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ])),
                    IconButton(onPressed: _downloading ? null : () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                  ]),
                ),
                Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_notes.isNotEmpty) _buildReleaseNotes(dialogContext) else Text('A new version of ASTROML is available.', style: Theme.of(dialogContext).textTheme.bodyMedium),
                  for (final image in _images.take(2)) ...[
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(image, width: double.infinity, fit: BoxFit.contain, loadingBuilder: (ctx, child, progress) => progress == null ? child : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())), errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                  ],
                  if (_downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100, minHeight: 6, borderRadius: BorderRadius.circular(8)),
                    const SizedBox(height: 7),
                    Text(_progress > 0 ? 'Downloading update... $_progress%' : 'Preparing download...', style: Theme.of(dialogContext).textTheme.labelMedium),
                  ],
                  if (_downloadedPath != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [Icon(Icons.check_circle_rounded, color: cs.primary, size: 18), const SizedBox(width: 7), const Expanded(child: Text('Download complete. Ready to install.'))]),
                  ],
                  if (_status.startsWith('Download failed:') || _status.startsWith('Allow ASTROML')) ...[
                    const SizedBox(height: 10),
                    Text(_status, style: TextStyle(color: cs.error, fontSize: 12)),
                  ],
                ]))),
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _downloading ? null : () => Navigator.pop(dialogContext), child: const Text('Later'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: FilledButton.icon(
                    onPressed: _downloading ? null : _downloadedPath != null
                        ? () { _installUpdate(); }
                        : () async { await _downloadUpdate(onChanged: () { if (dialogContext.mounted) refreshDialog(() {}); }); if (dialogContext.mounted) refreshDialog(() {}); },
                    icon: Icon(_downloadedPath != null ? Icons.install_mobile_rounded : Icons.download_rounded),
                    label: Text(_downloadedPath != null ? 'Install update' : _downloading ? 'Downloading...' : 'Download update'),
                  )),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadUpdate({VoidCallback? onChanged}) async {
    final url = _apkUrl;
    final name = _apkName;
    if (url == null || name == null) return;
    setState(() { _downloading = true; _progress = 0; _status = 'Downloading $name...'; });
    const engine = MethodChannel('com.astroml.dev/engine');
    const notificationId = 5106;
    try {
      // DownloadManager continues under Android's system download service when
      // the Activity is backgrounded; the app foreground service keeps the
      // matching ASTROML progress notification active while the UI is alive.
      try { await engine.invokeMethod('startBackgroundWork'); } catch (_) {}
      final id = await _channel.invokeMethod<int>('enqueueUpdateDownload', {'url': url, 'name': name});
      if (id == null) throw Exception('Android could not start the download.');
      var completedPath = <String, dynamic>{};
      while (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        final state = await _channel.invokeMapMethod<String, dynamic>('getUpdateDownload', {'id': id});
        if (state == null) throw Exception('Download record was not found.');
        final status = state['status'] as int? ?? 0;
        final downloaded = (state['downloaded'] as num?)?.toInt() ?? 0;
        final total = (state['total'] as num?)?.toInt() ?? 0;
        final percent = total > 0 ? (downloaded * 100 / total).round().clamp(0, 100) : -1;
        if (mounted) {
          setState(() => _progress = percent < 0 ? 0 : percent);
          onChanged?.call();
        }
        try {
          await engine.invokeMethod('updateInjectionNotification', {
            'title': 'ASTROML update',
            'message': percent < 0 ? 'Downloading $name...' : 'Downloading update • $percent%',
            'progress': percent,
            'image': '',
            'ongoing': status == 1 || status == 2 || status == 4,
            'notificationId': notificationId,
          });
        } catch (_) {}
        if (status == 8) {
          completedPath = state;
          break;
        }
        if (status == 16) throw Exception('Android DownloadManager reported a download failure.');
      }
      if (!mounted) return;
      final downloadedUri = '${completedPath['uri'] ?? ''}';
      if (!downloadedUri.startsWith('content://') && !downloadedUri.startsWith('file://')) {
        throw Exception('Download finished, but Android did not provide a valid APK URI.');
      }
      // Preserve DownloadManager's content:// URI; never access deprecated local filename columns.
      setState(() { _downloadedPath = downloadedUri; _status = 'Download complete. Tap Install to continue.'; _progress = 100; });
      await engine.invokeMethod('updateInjectionNotification', {
        'title': 'ASTROML update downloaded', 'message': 'Tap ASTROML to install the update',
        'progress': 100, 'image': '', 'ongoing': false, 'notificationId': notificationId,
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Download failed: $e');
      try {
        await engine.invokeMethod('updateInjectionNotification', {
          'title': 'ASTROML update failed', 'message': '$e',
          'progress': 0, 'image': '', 'ongoing': false, 'notificationId': notificationId,
        });
      } catch (_) {}
    } finally {
      try { await engine.invokeMethod('stopBackgroundWork'); } catch (_) {}
      if (mounted) setState(() => _downloading = false);
      onChanged?.call();
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
        if (!_autoCheck) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checking ? null : _checkForUpdate,
            icon: _checking ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Check for updates'),
          ),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_status, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
        ],
      ]),
    );
  }
}
