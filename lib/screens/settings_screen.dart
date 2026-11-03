import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../models/models.dart';
import 'hero_detail_screen.dart';
import '../widgets/app_image.dart';
import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/premium_ui.dart';
import '../widgets/update_checker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences & Info'), leading: const AppDrawerButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          PremiumGradientPanel(child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: context.appPrimary.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.tune_rounded, color: context.appPrimaryDark, size: 25)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ASTROML CONTROL CENTER', style: TextStyle(fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w900)),
              SizedBox(height: 4), Text('Personalize your experience', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ])),
          ])),
          const SizedBox(height: 20),
          Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .4)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: context.appCardBorder),
              boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: .04), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                _ListTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Theme',
                  subtitle: _themeLabel(theme.mode),
                  trailing: DropdownButton<ThemeMode>(
                    value: theme.mode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (m) {
                      if (m != null) theme.setMode(m);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .4)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: context.appCardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatically dismiss completed notifications'),
                subtitle: Text(state.autoDismissNotifications ? 'Notifications disappear after the selected time.' : 'Completed notifications stay until you dismiss them.'),
                value: state.autoDismissNotifications,
                onChanged: state.setAutoDismissNotifications,
              ),
              if (state.autoDismissNotifications) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Dismiss after'),
                  Text(state.notificationDismissSeconds >= 60
                    ? '${state.notificationDismissSeconds ~/ 60} min ${state.notificationDismissSeconds % 60 == 0 ? '' : '${state.notificationDismissSeconds % 60} sec'}'
                    : '${state.notificationDismissSeconds} sec', style: TextStyle(color: context.appPrimaryDark, fontWeight: FontWeight.w800)),
                ]),
                Slider(
                  min: 5, max: 300, divisions: 59,
                  value: state.notificationDismissSeconds.toDouble(),
                  label: '${state.notificationDismissSeconds}s',
                  onChanged: (v) => state.setNotificationDismissSeconds(v.round()),
                ),
                Text('5 seconds to 5 minutes', style: TextStyle(fontSize: 11, color: context.appOnSurfaceVariant)),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          Text('Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          const UpdateChecker(),
          const SizedBox(height: 20),
          Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .4)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: context.appCardBorder),
              boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: .04), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: state.history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No injection history yet.', style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant)),
                  )
                : Column(
                    children: [
                      for (final h in state.history.take(50))
                        _HistoryTile(
                          history: h,
                          onTap: () {
                            final hero = state.heroes.cast<HeroEntry?>().firstWhere(
                              (item) => item != null &&
                                ((h.heroId > 0 && item.heroInfo.id == h.heroId) ||
                                  item.heroInfo.name.toLowerCase() == h.heroName.toLowerCase()),
                              orElse: () => null,
                            );
                            if (hero != null) {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => HeroDetailScreen(hero: hero),
                              ));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hero data is not available right now.')),
                              );
                            }
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          onPressed: () => state.clearHistory(),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear history'),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text('About', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appOnSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .4)]),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: context.appCardBorder),
              boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: .04), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 20, color: context.appSecondary),
                    const SizedBox(width: 10),
                    const Text('ASTROML', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    _AppVersionText(color: context.appOnSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Developed & maintained by Astro Renz',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appPrimaryDark),
                ),
                const SizedBox(height: 10),
                Text(
                  'ASTROML is a Mobile Legends: Bang Bang (MLBB) skin injector for Android. '
                  'It lets you browse heroes, skills, and skins, favorite skins, and inject '
                  'custom asset packs directly into the game.\n\n'
                  'Features include Class Filters, Skin-to-Skin transforms, Favorites batch injection, '
                  'live cosmetic injection for skins, emotes, trails, recalls, eliminations, and '
                  'respawns, Advanced Offline Restore, SHA-256 injected status verification, '
                  'and Shizuku support on Android 11+.',
                  style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Disclaimer: For educational purposes only. All game data and skins belong to Moonton.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: context.appOnSurfaceVariant.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 18),
                Text('CONNECT WITH ASTRO RENZ', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: context.appOnSurfaceVariant)),
                const SizedBox(height: 8),
                _SocialLinkTile(
                  icon: Icons.send_rounded,
                  title: 'Telegram',
                  subtitle: 'Astro Star',
                  url: 'https://t.me/WashiWashi123',
                  color: const Color(0xFF229ED9),
                ),
                _SocialLinkTile(
                  icon: Icons.play_circle_fill_rounded,
                  title: 'YouTube',
                  subtitle: '@r3nz75',
                  url: 'https://youtube.com/@r3nz75',
                  color: const Color(0xFFFF3333),
                ),
                _SocialLinkTile(
                  icon: Icons.favorite_rounded,
                  title: 'SociaBuzz',
                  subtitle: 'Terence.',
                  url: 'https://sociabuzz.com/astrostarrenz/tribe',
                  color: const Color(0xFFE85D9E),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follow system',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

class _AppVersionText extends StatelessWidget {
  final Color color;
  const _AppVersionText({required this.color});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(
          version == null || version.isEmpty ? 'v—' : 'v$version',
          style: TextStyle(fontSize: 12, color: color),
        );
      },
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final Color color;

  const _SocialLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.color,
  });

  Future<void> _open() async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.open_in_new_rounded, size: 17),
      onTap: _open,
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ListTile({required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.appPrimaryDark),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final History history;
  final VoidCallback onTap;

  const _HistoryTile({required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 48,
          height: 48,
          child: history.skinImage.isNotEmpty
              ? AppImage(url: history.skinImage, width: 48, height: 48)
              : Container(
                  color: context.appSurfaceVariant,
                  child: Icon(Icons.history, color: context.appOnSurfaceVariant),
                ),
        ),
      ),
      title: Text(history.skinName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(history.heroName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_formatTime(history.timestamp),
          style: TextStyle(fontSize: 11, color: context.appOnSurfaceVariant)),
        const SizedBox(width: 5),
        Icon(Icons.chevron_right_rounded, color: context.appOnSurfaceVariant, size: 18),
      ]),
    );
  }

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
