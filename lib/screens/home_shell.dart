import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/feedback_service.dart';

import '../theme/app_theme.dart';
import '../widgets/operation_banner.dart';
import 'cosmetics_screen.dart';
import 'favorites_screen.dart';
import 'heroes_screen.dart';
import 'restore_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // This runs only after the startup/splash gate has finished. If ASTROML has
    // not been authorized in Shizuku yet, Android's Shizuku permission dialog
    // is requested here; if already authorized, the UserService is rebound.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<AppState>().ensureShizukuReady());
      }
    });
  }

  static const _screens = [
    HeroesScreen(),
    CosmeticsScreen(),
    FavoritesScreen(),
    RestoreScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'Heroes'),
    (Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic_rounded, 'Cosmetics'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Favorites'),
    (Icons.restore_rounded, Icons.restore_rounded, 'Restore'),
    (Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
  ];

  Future<void> _showChangeLogs(BuildContext context) async {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _ChangeLogsDialog(),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final controller = TextEditingController();
    String type = 'Suggestion';
    bool sending = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Icon(Icons.feedback_outlined, color: context.appPrimary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Suggestions / Report')),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Help improve ASTROML by sharing an idea or reporting a problem.'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Suggestion', label: Text('Suggestion'), icon: Icon(Icons.lightbulb_outline)),
                  ButtonSegment(value: 'Issue report', label: Text('Report issue'), icon: Icon(Icons.bug_report_outlined)),
                ],
                selected: {type},
                onSelectionChanged: sending ? null : (value) => setDialogState(() => type = value.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 7,
                maxLength: 4000,
                enabled: !sending,
                decoration: InputDecoration(
                  hintText: type == 'Suggestion' ? 'Write your suggestion here...' : 'Describe the issue and how it happened...',
                  filled: true,
                  fillColor: context.appSurfaceVariant.withValues(alpha: .45),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.appCardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.appCardBorder)),
                ),
              ),
              const SizedBox(height: 8),
              Text('Device details are attached automatically: Infinix Note 50 Pro • Android 16 • Helio G100.', style: TextStyle(fontSize: 11, color: context.appOnSurfaceVariant)),
            ])),
          ),
          actions: [
            TextButton(onPressed: sending ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: sending ? null : () async {
                final message = controller.text.trim();
                if (message.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least 3 characters.')));
                  return;
                }
                setDialogState(() => sending = true);
                try {
                  await FeedbackService.submit(type: type, message: message);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you! Your feedback was sent.')));
                } catch (error) {
                  setDialogState(() => sending = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
                }
              },
              icon: sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(sending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: context.appSurface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
                    SizedBox(height: 18),
                    Text('ASTROML', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    SizedBox(height: 3),
                    Text('Your game companion', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Text('WORKSPACE', style: TextStyle(color: context.appOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              ),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: ListTile(
                    selected: _index == i,
                    selectedTileColor: context.appPrimary.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    leading: Icon(_index == i ? _items[i].$2 : _items[i].$1, color: _index == i ? context.appPrimary : context.appOnSurfaceVariant),
                    title: Text(_items[i].$3, style: TextStyle(fontWeight: _index == i ? FontWeight.w700 : FontWeight.w500)),
                    trailing: _index == i ? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.appPrimary) : null,
                    onTap: () {
                      setState(() => _index = i);
                      Navigator.pop(context);
                    },
                  ),
                ),
              const Divider(height: 24, indent: 20, endIndent: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Text('COMMUNITY', style: TextStyle(color: context.appOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: Icon(Icons.history_rounded, color: context.appPrimary),
                  title: const Text('Change Logs', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('See what changed in ASTROML'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeLogs(context);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: Icon(Icons.lightbulb_outline_rounded, color: context.appPrimary),
                  title: const Text('Suggestions / Report', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Send feedback directly to the developer'),
                  onTap: () {
                    Navigator.pop(context);
                    _showFeedbackDialog(context);
                  },
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('ASTROML • v5.1.5', style: TextStyle(color: context.appOnSurfaceVariant, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const OperationBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.025, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          border: Border(top: BorderSide(color: context.appCardBorder)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, -5))],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final item in _items)
              NavigationDestination(
                icon: Icon(item.$1),
                selectedIcon: Icon(item.$2),
                label: item.$3,
              ),
          ],
        ),
      ),
    );
  }
}



class _ChangeLogsDialog extends StatefulWidget {
  const _ChangeLogsDialog();

  @override
  State<_ChangeLogsDialog> createState() => _ChangeLogsDialogState();
}

class _ChangeLogsDialogState extends State<_ChangeLogsDialog> {
  late Future<List<_ReleaseLog>> _releases = _loadReleases();

  Future<List<_ReleaseLog>> _loadReleases() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/antyhacker75-cmyk/yuyu/releases?per_page=100'),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('GitHub returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid release list');
    return decoded.whereType<Map<String, dynamic>>().map((release) {
      final tag = (release['tag_name'] ?? '').toString();
      final version = tag.isEmpty ? 'Release' : tag;
      final title = (release['name'] ?? version).toString();
      final body = (release['body'] ?? '').toString();
      final items = body
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('- ') || line.startsWith('* '))
          .map((line) => line.substring(2).replaceAll(RegExp(r'\*\*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
      return _ReleaseLog(version, title, items.isEmpty ? ['No release notes were provided.'] : items);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.appSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Row(children: [
      Icon(Icons.history_rounded, color: context.appPrimary),
      const SizedBox(width: 10),
      const Expanded(child: Text('ASTROML Change Logs')),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      height: 460,
      child: FutureBuilder<List<_ReleaseLog>>(
        future: _releases,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load all release notes.\n${snapshot.error}'));
          }
          final releases = snapshot.data ?? const <_ReleaseLog>[];
          if (releases.isEmpty) return const Center(child: Text('No published releases found.'));
          return ListView.separated(
            itemCount: releases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final release = releases[index];
              return _ChangeLogEntry(version: release.version, title: release.title, items: release.items);
            },
          );
        },
      ),
    ),
    actions: [
      TextButton(onPressed: () => setState(() => _releases = _loadReleases()), child: const Text('Refresh')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
    ],
  );
}

class _ReleaseLog {
  const _ReleaseLog(this.version, this.title, this.items);
  final String version;
  final String title;
  final List<String> items;
}

class _ChangeLogEntry extends StatelessWidget {
  const _ChangeLogEntry({required this.version, required this.title, required this.items});
  final String version;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appSurfaceVariant.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appCardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(version, style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      for (final item in items)
        Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: context.appPrimary),
          const SizedBox(width: 8),
          Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
        ])),
    ]),
  );
}
