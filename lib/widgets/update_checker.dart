import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Checks the ASTROML Cloudflare update service and downloads the matching APK.
/// Change these two values if the GitHub repository is renamed or transferred.
class UpdateChecker extends StatefulWidget {
  final bool managerOnly;
  const UpdateChecker({super.key, this.managerOnly = false});

  /// Shared setting used by the always-mounted app-level update manager.
  static final ValueNotifier<bool> autoCheckNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<int> reminderIntervalNotifier = ValueNotifier<int>(300);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.astroml.dev/updater');
  static const _updateBase = 'https://astroml-update-server.terencesimbre075.workers.dev';
  static const _api = '$_updateBase/api/update/latest?channel=stable';

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
  int _lastDownloadedBytes = 0;
  List<String> _images = [];
  bool _autoCheck = true;

  static const _autoKey = 'astroml_auto_update_check';
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  bool _dialogOpen = false;
  Timer? _reminderTimer;
  static const _reminderKey = 'astroml_update_reminder_seconds';
  int _reminderSeconds = 300;
  String? _availableVersion;

  @override
  void initState() {
    super.initState();
    if (widget.managerOnly) {
      WidgetsBinding.instance.addObserver(this);
      UpdateChecker.autoCheckNotifier.addListener(_onAutoCheckChanged);
      UpdateChecker.reminderIntervalNotifier.addListener(_onReminderChanged);
      _startGlobalManager();
    } else {
      _loadCurrentVersion();
      _loadSettingsPreference();
    }
  }

  Future<void> _loadSettingsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoKey) ?? true;
    final reminder = (prefs.getInt(_reminderKey) ?? 300).clamp(10, 3600).toInt();
    if (!mounted) return;
    setState(() { _autoCheck = enabled; _reminderSeconds = reminder; });
  }

  Future<void> _startGlobalManager() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoKey) ?? true;
    final reminder = (prefs.getInt(_reminderKey) ?? 300).clamp(10, 3600);
    if (!mounted) return;
    _autoCheck = enabled;
    _reminderSeconds = reminder.toInt();
    UpdateChecker.reminderIntervalNotifier.value = reminder;
    UpdateChecker.autoCheckNotifier.value = enabled;
    await _loadCurrentVersion();
    await _configurePush(enabled);

    // Both FCM launch paths are handled here, after the app-level navigator exists.
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_autoCheck && _isUpdateMessage(message)) _checkForUpdate(silent: true, forceDialog: true);
    });
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (_autoCheck && _isUpdateMessage(message)) _checkForUpdate(silent: true, forceDialog: true);
    });
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null && _isUpdateMessage(initial) && _autoCheck) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _checkForUpdate(silent: true, forceDialog: true);
        });
      }
    } catch (_) {}

    // Fallback for releases if a push was delayed or missed. The manager is
    // mounted at app root, so Settings does not need to be opened.
    if (enabled) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (mounted && _autoCheck) _checkForUpdate(silent: true, forceDialog: true);
      });
    }
  }

  bool _isUpdateMessage(RemoteMessage message) =>
      message.data['type'] == 'astroml_update' || message.data.containsKey('version');

  void _onReminderChanged() {
    _reminderSeconds = UpdateChecker.reminderIntervalNotifier.value.clamp(10, 3600).toInt();
    if (_updateAvailable && _autoCheck) _startReminderTimer();
  }

  void _startReminderTimer() {
    _reminderTimer?.cancel();
    if (!_autoCheck || !_updateAvailable || _availableVersion == null) return;
    _reminderTimer = Timer.periodic(Duration(seconds: _reminderSeconds), (_) async {
      if (!mounted || !_autoCheck || !_updateAvailable) return;
      try { await _channel.invokeMethod<bool>('showUpdateNotification', {'version': _availableVersion}); } catch (_) {}
    });
  }

  void _onAutoCheckChanged() {
    final enabled = UpdateChecker.autoCheckNotifier.value;
    if (!mounted || !widget.managerOnly) return;
    _autoCheck = enabled;
    _configurePush(enabled);
    if (enabled) _checkForUpdate(silent: true, forceDialog: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _autoCheck && widget.managerOnly) {
      // Always refresh on resume: a reminder notification may have opened the
      // already-running Activity, where a five-minute throttle could suppress
      // the update dialog the user explicitly tapped.
      _checkForUpdate(silent: true, forceDialog: true);
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
    UpdateChecker.autoCheckNotifier.value = value;
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
    final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-beta(\d*)?)?$');
    final aa = pattern.firstMatch(a.trim());
    final bb = pattern.firstMatch(b.trim());
    if (aa == null || bb == null) {
      List<int> parse(String value) => value.split(RegExp(r'[^0-9]+')).where((e) => e.isNotEmpty).map(int.parse).toList();
      final left = parse(a), right = parse(b);
      for (var i = 0; i < (left.length > right.length ? left.length : right.length); i++) {
        final x = i < left.length ? left[i] : 0;
        final y = i < right.length ? right[i] : 0;
        if (x != y) return x.compareTo(y);
      }
      return 0;
    }
    for (var i = 1; i <= 3; i++) {
      final result = int.parse(aa.group(i)!).compareTo(int.parse(bb.group(i)!));
      if (result != 0) return result;
    }
    final aBeta = aa.group(4) != null;
    final bBeta = bb.group(4) != null;
    if (aBeta != bBeta) return aBeta ? -1 : 1; // Stable is newer than beta.
    if (!aBeta) return 0;
    final aBetaNumber = int.tryParse(aa.group(4)!.isEmpty ? '1' : aa.group(4)!) ?? 1;
    final bBetaNumber = int.tryParse(bb.group(4)!.isEmpty ? '1' : bb.group(4)!) ?? 1;
    return aBetaNumber.compareTo(bBetaNumber);
  }

  Future<void> _checkForUpdate({bool silent = false, bool forceDialog = false}) async {
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
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('ASTROML update server returned HTTP ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('${data['error'] ?? 'Unable to retrieve the latest release.'}');
      }
      final version = '${data['version'] ?? ''}'.trim();
      if (version.isEmpty) throw Exception('The update server returned an empty version.');
      final body = '${data['notes'] ?? ''}';
      final assets = (data['assets'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
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
      if (asset == null && data['apkUrl'] is String && '${data['apkUrl']}'.startsWith('https://')) {
        asset = <String, dynamic>{'name': 'ASTROML-$version.apk', 'downloadUrl': data['apkUrl']};
      }
      if (asset == null) throw Exception('No compatible APK was attached to the latest release.');
      final imageMatches = RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)').allMatches(body);
      final images = imageMatches.map((m) => m.group(1)!).take(2).toList();
      if (!mounted) return;
      setState(() {
        _notes = body.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '').trim();
        _images = images;
        _apkUrl = '${asset!['downloadUrl'] ?? asset['browser_download_url'] ?? data['apkUrl'] ?? ''}';
        _apkName = '${asset['name']}';
        _updateAvailable = _compareVersions(version, _currentVersion) > 0;
        _availableVersion = _compareVersions(version, _currentVersion) > 0 ? version : null;
        _downloadedPath = null;
        _status = _updateAvailable ? 'ASTROML $version is available.' : 'You are using the latest version.';
      });
      if (_updateAvailable && mounted && widget.managerOnly) _startReminderTimer();
      if (_updateAvailable && mounted && (!silent || forceDialog)) {
        // All entry points use this same custom dialog, including notification taps.
        _showUpdateDialog(version);
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

  Future<void> _showUpdateDialog(String version) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
    await showDialog<void>(
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
                    Text(_progress > 0 ? 'Downloading update... $_progress%' : (_downloading ? 'Downloading • ${_formatBytes(_lastDownloadedBytes)}' : 'Preparing download...'), style: Theme.of(dialogContext).textTheme.labelMedium),
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
    } finally {
      _dialogOpen = false;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadUpdate({VoidCallback? onChanged}) async {
    final url = _apkUrl;
    final name = _apkName;
    if (url == null || name == null || !url.startsWith('https://')) {
      if (mounted) setState(() => _status = 'Download failed: the release APK URL is missing or invalid.');
      return;
    }
    setState(() { _downloading = true; _progress = 0; _lastDownloadedBytes = 0; _downloadedPath = null; _status = 'Connecting to GitHub release...'; });
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
      final downloadDeadline = DateTime.now().add(const Duration(minutes: 20));
      while (DateTime.now().isBefore(downloadDeadline)) {
        await Future.delayed(const Duration(seconds: 1));
        final state = await _channel.invokeMapMethod<String, dynamic>('getUpdateDownload', {'id': id});
        if (state == null) throw Exception('Download record was not found.');
        final status = state['status'] as int? ?? 0;
        final downloaded = (state['downloaded'] as num?)?.toInt() ?? 0;
        final total = (state['total'] as num?)?.toInt() ?? 0;
        final reason = (state['reason'] as num?)?.toInt() ?? 0;
        final percent = total > 0 ? (downloaded * 100 / total).round().clamp(0, 100) : -1;
        if (mounted) {
          setState(() { _progress = percent < 0 ? 0 : percent; _lastDownloadedBytes = downloaded; _status = percent < 0 ? 'Downloading $name • ${_formatBytes(downloaded)}' : 'Downloading $name • $percent%'; });
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
        if (status == 4) {
          if (mounted) setState(() => _status = 'Download paused (reason $reason). Waiting for Android Download Manager...');
        }
        if (status == 16) throw Exception('Android DownloadManager failed (reason $reason). Check your connection, storage, and GitHub release asset URL.');
      }
      if (completedPath.isEmpty) throw Exception('Download timed out after 20 minutes. Check your connection and try again.');
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
  void dispose() {
    if (widget.managerOnly) {
      WidgetsBinding.instance.removeObserver(this);
      UpdateChecker.autoCheckNotifier.removeListener(_onAutoCheckChanged);
      UpdateChecker.reminderIntervalNotifier.removeListener(_onReminderChanged);
      _reminderTimer?.cancel();
      _openedSubscription?.cancel();
      _foregroundSubscription?.cancel();
    }
    super.dispose();
  }

  String _formatReminder(int seconds) => seconds < 60 ? '${seconds}s' : seconds % 60 == 0 ? '${seconds ~/ 60} min' : '${seconds ~/ 60}m ${seconds % 60}s';

  @override
  Widget build(BuildContext context) {
    if (widget.managerOnly) return const SizedBox.shrink();
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
        if (_autoCheck) ...[
          const SizedBox(height: 8),
          Row(children: [const Expanded(child: Text('Update reminder interval', style: TextStyle(fontWeight: FontWeight.w700))), Text(_formatReminder(_reminderSeconds), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800))]),
          Slider(
            min: 10, max: 3600, divisions: 359,
            value: _reminderSeconds.toDouble(),
            label: _formatReminder(_reminderSeconds),
            onChanged: (value) async {
              final seconds = (value / 10).round() * 10;
              setState(() => _reminderSeconds = seconds.clamp(10, 3600));
              UpdateChecker.reminderIntervalNotifier.value = _reminderSeconds;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(_reminderKey, _reminderSeconds);
            },
          ),
          Text('Repeat update notification every 10 seconds to 1 hour while an update is available.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
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
