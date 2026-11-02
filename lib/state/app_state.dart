import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/lumina_api.dart';
import '../models/models.dart';
import '../services/engine_service.dart';

class OperationState {
  final bool running;
  final String message;
  final int progress;
  final int done;
  final int total;
  final String skinImage;
  final String stage;

  const OperationState({
    this.running = false,
    this.message = '',
    this.progress = 0,
    this.done = 0,
    this.total = 0,
    this.skinImage = '',
    this.stage = '',
  });

  OperationState copyWith({
    bool? running,
    String? message,
    int? progress,
    int? done,
    int? total,
    String? skinImage,
    String? stage,
  }) =>
      OperationState(
        running: running ?? this.running,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        done: done ?? this.done,
        total: total ?? this.total,
        skinImage: skinImage ?? this.skinImage,
        stage: stage ?? this.stage,
      );
}

class AppState extends ChangeNotifier {
  List<HeroEntry> _heroes = [];
  bool _loading = true;
  String? _loadError;

  List<Favorite> _favorites = [];
  List<InjectedSkin> _manifest = [];
  List<History> _history = [];
  Set<String> _injected = {};
  Set<String> _injectedCosmetics = {};
  List<CosmeticItem> _newlyAddedSkins = [];

  final Map<CosmeticCategory, List<CosmeticItem>> _cosmetics = {};
  final Map<CosmeticCategory, bool> _cosmeticLoading = {};
  final Map<CosmeticCategory, String?> _cosmeticError = {};

  OperationState _operation = const OperationState();
  OperationState get operation => _operation;

  GameTarget? _game;
  bool _storageGranted = false;
  String _shizukuState = 'unavailable';

  StreamSubscription<String>? _resumeSub;

  Completer<void>? _opLock;
  final List<Favorite> _injectionQueue = [];
  bool _queueWorkerRunning = false;
  final Set<String> _queuedInjectionKeys = {};
  Timer? _operationDismissTimer;
  bool _autoDismissNotifications = true;
  int _notificationDismissSeconds = 30;
  bool get autoDismissNotifications => _autoDismissNotifications;
  int get notificationDismissSeconds => _notificationDismissSeconds;

  Future<void> setAutoDismissNotifications(bool value) async {
    _autoDismissNotifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_dismiss_notifications', value);
    await _syncNotificationSettings();
    notifyListeners();
  }

  Future<void> setNotificationDismissSeconds(int value) async {
    _notificationDismissSeconds = value.clamp(5, 300);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_dismiss_seconds', _notificationDismissSeconds);
    await _syncNotificationSettings();
    notifyListeners();
  }

  Future<void> _syncNotificationSettings() async {
    await EngineService.setNotificationSettings(
      autoDismiss: _autoDismissNotifications,
      seconds: _notificationDismissSeconds,
    );
  }

  void _showOperationResult(OperationState state) {
    _operationDismissTimer?.cancel();
    _operation = state;
    notifyListeners();
    if (!state.running && state.message.isNotEmpty) {
      _operationDismissTimer = Timer(const Duration(seconds: 4), () {
        if (!_operation.running && _operation.message == state.message) {
          _operation = const OperationState();
          notifyListeners();
        }
      });
    }
  }

  List<HeroEntry> get heroes => _heroes;
  bool get loading => _loading;
  String? get loadError => _loadError;
  List<Favorite> get favorites => _favorites;
  Set<String> get injected => _injected;
  List<CosmeticItem> get newlyAddedSkins => _newlyAddedSkins;

  bool isNewSkin(String name, String image) {
    final n = name.trim().toLowerCase();
    final img = image.trim();
    return _newlyAddedSkins.any((item) =>
        (n.isNotEmpty && item.title.trim().toLowerCase() == n) ||
        (img.isNotEmpty && item.img.isNotEmpty && item.img == img));
  }
  GameTarget? get game => _game;
  bool get storageGranted => _storageGranted;
  String get shizukuState => _shizukuState;

  List<CosmeticItem> cosmetics(CosmeticCategory category) =>
      _cosmetics[category] ?? const [];

  bool isCosmeticLoading(CosmeticCategory category) =>
      _cosmeticLoading[category] ?? false;

  String? cosmeticError(CosmeticCategory category) =>
      _cosmeticError[category];

  bool isCosmeticInjected(CosmeticCategory category, String title) =>
      _injectedCosmetics.contains(_cosmeticKey(category, title));

  bool get isReady {
    if (_game == null || !_storageGranted) return false;
    if (_needsShizuku && _shizukuState != 'bound') return false;
    return true;
  }

  bool get _needsShizuku => Platform.isAndroid;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs);
    _autoDismissNotifications = prefs.getBool('auto_dismiss_notifications') ?? true;
    _notificationDismissSeconds = (prefs.getInt('notification_dismiss_seconds') ?? 30).clamp(5, 300);
    await _syncNotificationSettings();
    notifyListeners();

    _loadHeroes();
    _loadNewlyAddedSkins();
    await refreshEnv();
    refreshInjectedStatus();
    cleanupCache();

    _resumeSub = EngineService.onResume.listen((_) async {
      await refreshEnv();
      // A return from Shizuku's own permission/service screen must immediately
      // trigger a new permission check and UserService bind without app restart.
      unawaited(ensureShizukuReady());
    });
  }

  @override
  void dispose() {
    _resumeSub?.cancel();
    _operationDismissTimer?.cancel();
    super.dispose();
  }

  void _loadFromPrefs(SharedPreferences prefs) {
    _favorites = _decodeList(prefs.getString('favorites'))
        .map((e) => Favorite.fromJson(e))
        .toList();
    _manifest = _decodeList(prefs.getString('injected_manifest'))
        .map((e) => InjectedSkin.fromJson(e))
        .toList();
    _history = _decodeList(prefs.getString('history'))
        .map((e) => History.fromJson(e))
        .toList();
    _injectedCosmetics = _decodeList(prefs.getString('injected_cosmetics'))
        .map((e) => e['key'] as String? ?? '')
        .where((k) => k.isNotEmpty)
        .toSet();
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshEnv() async {
    _game = await EngineService.findGame();
    _storageGranted = await EngineService.storageGranted();
    _shizukuState = await EngineService.shizukuState();
    notifyListeners();
  }

  Future<void> requestShizukuPermission() async {
    await EngineService.requestShizukuPermission();
    // Permission approval and UserService binding are asynchronous. Keep
    // refreshing until the native service reports Bound, rather than making
    // the user tap Fix/Request Permission a second time.
    await _waitForShizukuBound();
  }

  Future<void> bindShizuku() async {
    await EngineService.bindShizuku();
    await _waitForShizukuBound();
  }

  Future<void> _waitForShizukuBound() async {
    const attempts = 24;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      try {
        _shizukuState = await EngineService.shizukuState();
      } catch (_) {
        _shizukuState = 'unavailable';
      }
      notifyListeners();
      if (_shizukuState == 'bound' ||
          _shizukuState == 'no_permission' ||
          _shizukuState == 'unavailable') {
        // Stop on success or a definitive state. If still idle, continue
        // waiting because bindUserService has not called back yet.
        if (_shizukuState != 'bound') {
          if (_shizukuState == 'no_permission' ||
              _shizukuState == 'unavailable') {
            return;
          }
        } else {
          return;
        }
      }
    }
    await refreshEnv();
  }

  Future<void> grantStorage() async {
    await EngineService.openStorageSettings();
  }

  void dismissOperation() {
    if (!_operation.running) {
      _operationDismissTimer?.cancel();
      _operation = const OperationState();
      notifyListeners();
    }
  }

  Future<void> _loadHeroes() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _heroes = await LuminaApi.fetchHeroes();
    } catch (e) {
      _loadError = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadNewlyAddedSkins() async {
    try {
      _newlyAddedSkins = await LuminaApi.fetchNewlyAdded();
      notifyListeners();
    } catch (_) {
      // Keep search and hero browsing available if the optional feed is offline.
    }
  }

  Future<void> reloadNewlyAddedSkins() async {
    await _loadNewlyAddedSkins();
  }

  Future<void> reloadHeroes() => _loadHeroes();

  bool isFavorite(int heroId, String skinName) =>
      _favorites.any((f) => f.heroId == heroId && f.skinName == skinName);

  Future<void> addFavorite(HeroEntry hero, String skinName, String image, String sc) async {
    if (isFavorite(hero.heroInfo.id, skinName)) return;
    _favorites.removeWhere((f) => f.heroId == hero.heroInfo.id);
    _favorites.add(Favorite(
      heroName: hero.heroInfo.name,
      heroId: hero.heroInfo.id,
      skinName: skinName,
      skinImage: image,
      skinSc: sc,
    ));
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> removeFavorite(int heroId, String skinName) async {
    _favorites.removeWhere((f) => f.heroId == heroId && f.skinName == skinName);
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'favorites',
      jsonEncode(_favorites.map((f) => f.toJson()).toList()),
    );
  }

  String _safeName(Favorite fav) =>
      '${fav.heroName}-${fav.skinName}'.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');

  Future<File> _cachedZip(Favorite fav) async {
    final cache = await EngineService.cacheDir();
    await cache.create(recursive: true);
    return File('${cache.path}/${_safeName(fav)}.zip');
  }

  Future<void> _deleteCachedZip(File zip) async {
    try {
      if (zip.existsSync()) await zip.delete();
    } catch (_) {}
  }

  Future<void> cleanupCache({int maxFiles = 50, int maxAgeDays = 7}) async {
    try {
      final cache = await EngineService.cacheDir();
      if (!await cache.exists()) return;
      final files = cache.listSync().whereType<File>().toList();
      final now = DateTime.now();
      for (final f in files) {
        try {
          final stat = f.statSync();
          final age = now.difference(stat.modified).inDays;
          if (age > maxAgeDays) {
            await f.delete();
            continue;
          }
        } catch (_) {}
      }
      final remaining = cache.listSync().whereType<File>().toList();
      if (remaining.length > maxFiles) {
        remaining.sort((a, b) {
          try {
            return a.statSync().modified.compareTo(b.statSync().modified);
          } catch (_) {
            return 0;
          }
        });
        for (var i = 0; i < remaining.length - maxFiles; i++) {
          try {
            await remaining[i].delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _acquireOpLock() async {
    while (_opLock != null) {
      await _opLock!.future;
    }
    _opLock = Completer<void>();
  }

  void _releaseOpLock() {
    final c = _opLock;
    _opLock = null;
    c?.complete();
  }

  void _setInjectionStage(Favorite fav, String stage, int percent) {
    // Native download/extraction currently has no byte/file callback. Use an
    // indeterminate state instead of presenting invented percentage values.
    _operation = _operation.copyWith(running: true, message: stage, progress: -1, skinImage: fav.skinImage, stage: stage);
    notifyListeners();
    EngineService.updateInjectionNotification(
      title: fav.skinName,
      message: stage,
      progress: -1, image: fav.skinImage);
  }

  Future<File> _downloadFavoriteArchive(Favorite fav) async {
    if (fav.skinSc.isEmpty) throw 'No download URL for ${fav.skinName}';
    final zip = await _cachedZip(fav);
    if (zip.existsSync() && zip.lengthSync() > 0) return zip;

    _setInjectionStage(fav, 'Downloading skin archive...', 5);
    var lastPercent = -1;
    var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    final progressSub = EngineService.downloadProgress.listen((event) {
      final percent = (event['progress'] as num?)?.toInt();
      if (percent == null || !_operation.running) return;
      final currentPercent = percent.clamp(0, 100);
      // Ignore stale/out-of-order events and avoid rebuilding the UI for every
      // tiny network read. Downloading itself remains on the native IO thread.
      if (currentPercent < lastPercent) return;
      final now = DateTime.now();
      if (currentPercent == lastPercent && currentPercent != 100) return;
      if (currentPercent != 100 && now.difference(lastUiUpdate).inMilliseconds < 400) return;
      lastPercent = currentPercent;
      lastUiUpdate = now;
      _operation = _operation.copyWith(
        message: 'Downloading ${fav.skinName}: $currentPercent%',
        progress: currentPercent,
        stage: 'Downloading',
      );
      notifyListeners();
      EngineService.updateInjectionNotification(
        title: fav.skinName,
        message: 'Downloading: $currentPercent%',
        progress: currentPercent,
        image: fav.skinImage,
      );
    });
    final dl = await EngineService.downloadFile(fav.skinSc, zip.path);
    await progressSub.cancel();
    if (!dl.ok) {
      await _deleteCachedZip(zip);
      throw 'Download failed for ${fav.skinName}'
          '${dl.error != null ? ': ${dl.error}' : ''}';
    }
    if (!zip.existsSync() || zip.lengthSync() == 0) {
      await _deleteCachedZip(zip);
      throw 'Download produced empty file for ${fav.skinName}';
    }

    _setInjectionStage(fav, 'Download complete · validating archive...', 42);
    try {
      final raf = await zip.open();
      final sig = await raf.read(6);
      await raf.close();
      final isZip = sig.length >= 4 && sig[0] == 0x50 && sig[1] == 0x4B &&
          ((sig[2] == 0x03 && sig[3] == 0x04) ||
           (sig[2] == 0x05 && sig[3] == 0x06) ||
           (sig[2] == 0x07 && sig[3] == 0x08));
      final is7z = sig.length == 6 && sig[0] == 0x37 && sig[1] == 0x7A &&
          sig[2] == 0xBC && sig[3] == 0xAF && sig[4] == 0x27 && sig[5] == 0x1C;
      if (!(isZip || is7z)) throw 'Downloaded file is not a valid archive for ${fav.skinName}';
    } catch (e) {
      await _deleteCachedZip(zip);
      rethrow;
    }
    return zip;
  }

  Future<void> _injectFavorite(Favorite fav) async {
    final game = await EngineService.findGame();
    if (game == null) throw 'Mobile Legends is not installed';

    final zip = await _downloadFavoriteArchive(fav);
    _setInjectionStage(fav, 'Unzipping and extracting files...', 50);
    final uz = await EngineService.unzip(zip.path, game.assetsDir);
    if (!uz.ok) {
      throw 'Extraction failed for ${fav.skinName}'
          '${uz.error != null ? ': ${uz.error}' : ''}';
    }

    _setInjectionStage(fav, 'Verifying extracted files...', 90);
    final injected = await _buildInjectedSkin(fav, zip, game);
    if (injected.files.isEmpty) {
      throw 'Extraction finished, but no installed files could be verified for ${fav.skinName}';
    }
    await _recordInjected(injected);
    _addHistory(fav);
    _setInjectionStage(fav, 'Injection completed', 100);
    if (_operation.total <= 1) {
      await EngineService.updateInjectionNotification(
        title: fav.skinName, message: 'Injection completed', progress: 100,
        image: fav.skinImage, ongoing: false);
    }
  }

  Future<InjectedSkin> _buildInjectedSkin(
      Favorite fav, File zip, GameTarget game) async {
    final entries = await EngineService.hashZipEntries(zip.path);
    if (entries.isEmpty) {
      return InjectedSkin(heroName: fav.heroName, heroId: fav.heroId,
          skinName: fav.skinName, skinImage: fav.skinImage,
          skinSc: fav.skinSc);
    }
    final files = <InjectedFile>[];
    for (final (name, expectedHash) in entries) {
      final hashes = await EngineService.sha256Files(['${game.assetsDir}/$name']);
      final actual = hashes.isNotEmpty ? hashes.first : null;
      if (actual != null && actual.isNotEmpty &&
          actual.toLowerCase() == expectedHash.toLowerCase()) {
        files.add(InjectedFile(path: name, sha256: expectedHash));
      }
    }
    return InjectedSkin(heroName: fav.heroName, heroId: fav.heroId,
        skinName: fav.skinName, skinImage: fav.skinImage,
        skinSc: fav.skinSc, files: files);
  }

  String _queueKey(Favorite fav) =>
      '${fav.heroId}:${fav.skinName.toLowerCase()}';

  Future<bool> ensureShizukuReady({bool requestIfMissing = true}) async {
    if (!Platform.isAndroid) return true;
    var permissionRequestIssued = false;
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        _shizukuState = await EngineService.shizukuState();
      } catch (_) {
        _shizukuState = 'unavailable';
      }
      if (_shizukuState == 'bound') {
        notifyListeners();
        return true;
      }
      if (_shizukuState == 'no_permission' && requestIfMissing && !permissionRequestIssued) {
        permissionRequestIssued = true;
        await EngineService.requestShizukuPermission();
      } else if (_shizukuState == 'idle') {
        await EngineService.bindShizuku();
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await refreshEnv();
    return _shizukuState == 'bound';
  }

  Future<void> _enqueueInjections(Iterable<Favorite> favorites) async {
    if (!await ensureShizukuReady()) {
      _showOperationResult(const OperationState(
        running: false,
        message: 'Injection blocked: Shizuku permission/service is required. Start Shizuku, grant ASTROML access, then try again.',
      ));
      return;
    }
    var added = 0;
    for (final fav in favorites) {
      if (fav.skinSc.isEmpty) continue;
      final key = _queueKey(fav);
      if (_queuedInjectionKeys.add(key)) {
        _injectionQueue.add(fav);
        added++;
      }
    }
    if (added == 0 && !_queueWorkerRunning) return;
    _operation = OperationState(
      running: true,
      message: _queueWorkerRunning
          ? 'Added $added skin(s) to the injection queue'
          : 'Preparing injection queue...',
      done: 0,
      total: _injectionQueue.length,
      stage: 'Queued',
    );
    notifyListeners();
    if (!_queueWorkerRunning) {
      _queueWorkerRunning = true;
      unawaited(_processInjectionQueue());
    }
  }

  Future<void> _processInjectionQueue() async {
    final failures = <String>[];
    var completed = 0;
    await EngineService.startBackgroundWork();
    try {
      while (_injectionQueue.isNotEmpty) {
        final fav = _injectionQueue.removeAt(0);
        final key = _queueKey(fav);
        final total = completed + 1 + _injectionQueue.length;
        _operation = OperationState(
          running: true,
          message: 'Preparing ${fav.skinName} (${completed + 1}/$total)',
          progress: 0,
          done: completed,
          total: total,
          skinImage: fav.skinImage,
          stage: 'Starting',
        );
        notifyListeners();
        try {
          await _acquireOpLock();
          try {
            await EngineService.updateInjectionNotification(
              title: fav.skinName,
              message: 'Starting download...',
              progress: -1,
              image: fav.skinImage,
            );
            await _injectFavorite(fav);
            _replaceInjectedKey(fav.heroId, '${fav.heroId}:${fav.skinName}');
            await EngineService.updateInjectionNotification(
              title: fav.skinName,
              message: 'Injection completed',
              progress: 100,
              image: fav.skinImage,
              ongoing: false,
            );
          } finally {
            _releaseOpLock();
          }
        } catch (e) {
          failures.add('${fav.skinName}: ${_msg(e)}');
          await EngineService.updateInjectionNotification(
            title: fav.skinName,
            message: 'Injection failed: ${_msg(e)}',
            progress: 0,
            image: fav.skinImage,
            ongoing: false,
          );
        } finally {
          _queuedInjectionKeys.remove(key);
        }
        completed++;
        _operation = _operation.copyWith(
          running: true,
          done: completed,
          total: completed + _injectionQueue.length,
          message: _injectionQueue.isEmpty
              ? 'Finishing injection queue...'
              : 'Completed $completed · Next: ${_injectionQueue.first.skinName}',
        );
        notifyListeners();
      }
      final summary = 'Inject completed: ${completed - failures.length} ok, ${failures.length} failed'
          '${failures.isEmpty ? '' : '\n${failures.take(8).join('\n')}'}';
      _showOperationResult(OperationState(
        running: false,
        message: summary,
        done: completed - failures.length,
        total: completed,
      ));
    } finally {
      _queueWorkerRunning = false;
      await EngineService.stopBackgroundWork();
      if (_injectionQueue.isNotEmpty) {
        _queueWorkerRunning = true;
        unawaited(_processInjectionQueue());
      }
    }
  }

  Future<void> injectSkin(HeroEntry hero, String skinName, String image, String sc) =>
      _enqueueInjections([Favorite(
        heroName: hero.heroInfo.name,
        heroId: hero.heroInfo.id,
        skinName: skinName,
        skinImage: image,
        skinSc: sc,
      )]);

  Future<void> injectSkinToSkin(
      HeroEntry hero, String fromSkin, String toSkin, String sc) {
    final target = [...hero.skins, ...hero.otherSkins]
        .where((skin) => skin.name == toSkin).firstOrNull;
    return _enqueueInjections([Favorite(
      heroName: hero.heroInfo.name,
      heroId: hero.heroInfo.id,
      skinName: '$fromSkin → $toSkin',
      skinImage: target?.image ?? hero.heroInfo.portraitIcon,
      skinSc: sc,
    )]);
  }

  Future<void> injectSkinFromFavorite(Favorite fav) =>
      _enqueueInjections([fav]);

  Future<void> injectAllFavorites() =>
      _enqueueInjections(List<Favorite>.from(_favorites));

  Future<void> advancedRestoreAllFavorites() async {
    if (_operation.running || _favorites.isEmpty) return;
    final list = List<Favorite>.from(_favorites);
    _operation = OperationState(running: true, message: 'Advanced restore running...', total: list.length);
    notifyListeners();

    await _acquireOpLock();
    try {
      var done = 0;
      var failures = 0;
      for (final fav in list) {
        _operation = _operation.copyWith(
          done: done,
          message: 'Restoring ${fav.skinName}',
          progress: (done * 100) ~/ list.length,
        );
        notifyListeners();
        try {
          final game = await EngineService.findGame();
          if (game == null) throw 'Mobile Legends is not installed';
          await EngineService.clearRepairMarkers(game.assetsDir, game.dataDir);
          final zip = await _cachedZip(fav);
          if (zip.existsSync() && fav.skinSc.isNotEmpty) {
            final uz = await EngineService.unzip(zip.path, game.assetsDir);
            if (!uz.ok) {
              await _deleteCachedZip(zip);
              throw 'Extraction failed: ${uz.error}';
            }
          }
          _addHistory(fav);
        } catch (_) {
          failures++;
        }
        done++;
      }

      _operation = OperationState(
        running: false,
        message: 'Advanced restore completed: ${list.length - failures} ok, $failures failed',
        done: list.length - failures,
        total: list.length,
      );
    } finally {
      _releaseOpLock();
    }
    notifyListeners();
  }

  Future<void> refreshInjectedStatus() async {
    _injected = {};
    _operation = const OperationState(
      running: true, message: 'Checking installed skin files...', progress: -1,
      stage: 'Verifying',
    );
    notifyListeners();
    try {
      final game = await EngineService.findGame();
      if (game == null) {
        _operation = const OperationState(
          running: false, message: 'Cannot check skins: game folder not found');
        notifyListeners();
        return;
      }

      var manifest = List<InjectedSkin>.from(_manifest);
      var backfilled = false;
      for (var i = 0; i < manifest.length; i++) {
        if (manifest[i].files.isNotEmpty) continue;
        final rebuilt = await _backfillInjectedSkin(manifest[i]);
        if (rebuilt != null && rebuilt.files.isNotEmpty) {
          manifest[i] = rebuilt;
          backfilled = true;
        }
      }
      if (backfilled) {
        _manifest = manifest;
        await _saveManifest();
      }

      final result = <String>{};
      var checked = 0;
      for (final entry in manifest) {
        checked++;
        _operation = _operation.copyWith(
          message: 'Verifying ${entry.skinName} ($checked/${manifest.length})',
          progress: manifest.isEmpty ? 90 : 10 + (checked * 80) ~/ manifest.length,
        );
        notifyListeners();
        if (entry.files.isEmpty) continue;
        try {
          final paths = entry.files.map((f) => '${game.assetsDir}/${f.path}').toList();
          final hashes = await EngineService.sha256Files(paths);
          var allMatch = hashes.length == entry.files.length;
          for (var i = 0; allMatch && i < entry.files.length; i++) {
            final current = hashes[i];
            if (current == null || current.isEmpty ||
                current.toLowerCase() != entry.files[i].sha256.toLowerCase()) {
              allMatch = false;
            }
          }
          if (allMatch) result.add('${entry.heroId}:${entry.skinName}');
        } catch (_) {
          // A file may have been removed by a game repair; leave it unmarked.
        }
      }
      _injected = result;
      _showOperationResult(OperationState(
        running: false,
        message: 'Check complete: ${result.length} injected skin(s) verified',
        progress: 100, done: result.length, total: manifest.length,
      ));
    } catch (e) {
      _operation = OperationState(
        running: false, message: 'Could not check injected skins: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<InjectedSkin?> _backfillInjectedSkin(InjectedSkin entry) async {
    final zip = await _cachedZip(Favorite(
      heroName: entry.heroName,
      heroId: entry.heroId,
      skinName: entry.skinName,
      skinImage: entry.skinImage,
      skinSc: entry.skinSc,
    ));
    if (!zip.existsSync()) return null;
    final entries = await EngineService.hashZipEntries(zip.path);
    if (entries.isEmpty) return null;
    return InjectedSkin(
      heroName: entry.heroName,
      heroId: entry.heroId,
      skinName: entry.skinName,
      skinImage: entry.skinImage,
      skinSc: entry.skinSc,
      files: entries.map((e) => InjectedFile(path: e.$1, sha256: e.$2)).toList(),
    );
  }

  Future<void> _recordInjected(InjectedSkin injected) async {
    _manifest = _manifest
            .where((m) => !(m.heroId == injected.heroId &&
                m.skinName.toLowerCase() == injected.skinName.toLowerCase()))
            .toList() +
        [injected];
    await _saveManifest();
  }

  void _replaceInjectedKey(int heroId, String key) {
    _injected = {..._injected, key};
  }

  Future<void> _saveManifest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'injected_manifest',
      jsonEncode(_manifest.map((m) => m.toJson()).toList()),
    );
  }

  List<History> get history => _history;

  void _addHistory(Favorite fav) {
    _history = [
      History(
          heroName: fav.heroName,
          heroId: fav.heroId,
          skinName: fav.skinName,
          skinImage: fav.skinImage,
          timestamp: DateTime.now().millisecondsSinceEpoch),
      ..._history.where(
          (h) => !(h.heroName == fav.heroName && h.skinName == fav.skinName)),
    ].take(200).toList();
    _saveHistory();
  }

  Future<void> clearHistory() async {
    _history = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'history',
      jsonEncode(_history.map((h) => h.toJson()).toList()),
    );
  }

  String _cosmeticKey(CosmeticCategory category, String title) =>
      '${category.id}|$title';

  Future<void> loadCosmetics(CosmeticCategory category) async {
    if (_cosmetics.containsKey(category)) return;
    await _fetchCosmeticsOf(category);
  }

  Future<void> reloadCosmetics(CosmeticCategory category) async {
    _cosmetics.remove(category);
    await _fetchCosmeticsOf(category);
  }

  Future<void> _fetchCosmeticsOf(CosmeticCategory category) async {
    if (_cosmeticLoading[category] ?? false) return;
    _cosmeticLoading[category] = true;
    _cosmeticError[category] = null;
    notifyListeners();
    try {
      _cosmetics[category] = await _fetchFromApi(category);
    } catch (e) {
      _cosmeticError[category] = e.toString();
    }
    _cosmeticLoading[category] = false;
    notifyListeners();
  }

  Future<List<CosmeticItem>> _fetchFromApi(CosmeticCategory category) =>
      switch (category) {
        CosmeticCategory.newlyAdded => LuminaApi.fetchNewlyAdded(),
        CosmeticCategory.emotes => LuminaApi.fetchEmotes(),
        CosmeticCategory.trails => LuminaApi.fetchTrails(),
        CosmeticCategory.recalls => LuminaApi.fetchRecalls(),
        CosmeticCategory.eliminations => LuminaApi.fetchEliminations(),
        CosmeticCategory.respawns => LuminaApi.fetchRespaws(),
      };

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');

  Future<void> _deleteFile(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  Future<void> injectCosmetic(
      CosmeticCategory category, CosmeticItem item) async {
    if (_operation.running) return;
    if (!await ensureShizukuReady()) {
      _showOperationResult(const OperationState(
        running: false,
        message: 'Download/injection blocked: Shizuku access is required. Start Shizuku and grant ASTROML permission first.',
      ));
      return;
    }
    if (item.sc.isEmpty) {
      _operation = OperationState(
          running: false,
          message: 'Failed: no download URL for ${item.title}');
      notifyListeners();
      return;
    }
    final game = await EngineService.findGame();
    if (game == null) {
      _operation = OperationState(
          running: false, message: 'Failed: Mobile Legends is not installed');
      notifyListeners();
      return;
    }

    _operation = OperationState(
        running: true, message: 'Injecting ${item.title}...', total: 1);
    notifyListeners();
    try {
      await _acquireOpLock();
      try {
        final cache = await EngineService.cacheDir();
        await cache.create(recursive: true);
        final zip = File(
            '${cache.path}/${category.id}_${_sanitizeFileName(item.title)}.zip');
        if (!zip.existsSync() || zip.lengthSync() == 0) {
          final dl = await EngineService.downloadFile(item.sc, zip.path);
          if (!dl.ok) {
            await _deleteFile(zip);
            throw 'Download failed for ${item.title}'
                '${dl.error != null ? ': ${dl.error}' : ''}';
          }
          if (!zip.existsSync() || zip.lengthSync() == 0) {
            await _deleteFile(zip);
            throw 'Download produced empty file for ${item.title}';
          }
          try {
            final raf = await zip.open();
            final sig = await raf.read(6);
            await raf.close();
            final isZip = sig.length >= 4 &&
                sig[0] == 0x50 && sig[1] == 0x4B &&
                ((sig[2] == 0x03 && sig[3] == 0x04) ||
                 (sig[2] == 0x05 && sig[3] == 0x06) ||
                 (sig[2] == 0x07 && sig[3] == 0x08));
            final is7z = sig.length == 6 &&
                sig[0] == 0x37 && sig[1] == 0x7A && sig[2] == 0xBC &&
                sig[3] == 0xAF && sig[4] == 0x27 && sig[5] == 0x1C;
            if (!(isZip || is7z)) {
              await _deleteFile(zip);
              throw 'Downloaded file is not a valid zip for ${item.title}';
            }
          } catch (e) {
            if (e.toString().contains('valid zip')) rethrow;
            await _deleteFile(zip);
            throw 'Invalid zip file for ${item.title}';
          }
        }
        final uz = await EngineService.unzip(zip.path, game.assetsDir);
        if (!uz.ok) {
          await _deleteFile(zip);
          throw 'Extraction failed for ${item.title}'
              '${uz.error != null ? ': ${uz.error}' : ''}';
        }
        _injectedCosmetics = {..._injectedCosmetics, _cosmeticKey(category, item.title)};
        await _saveInjectedCosmetics();
        _operation = OperationState(
            running: false,
            message: 'Injected: ${item.title}',
            done: 1,
            total: 1);
      } finally {
        _releaseOpLock();
      }
    } catch (e) {
      _operation = OperationState(running: false, message: 'Failed: ${_msg(e)}');
    }
    notifyListeners();
  }

  Future<void> restoreCosmetic(
      CosmeticCategory category, CosmeticItem item) async {
    final key = _cosmeticKey(category, item.title);
    if (!_injectedCosmetics.contains(key)) return;
    _injectedCosmetics = {..._injectedCosmetics}..remove(key);
    await _saveInjectedCosmetics();
    _operation = OperationState(
        running: false, message: 'Removed injected mark: ${item.title}');
    notifyListeners();
  }

  Future<void> _saveInjectedCosmetics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'injected_cosmetics',
      jsonEncode(
          _injectedCosmetics.map((k) => {'key': k}).toList()),
    );
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
}
