import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/premium_ui.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  Future<void> _confirmAdvancedRestore(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced restore?'),
        content: Text(
            'Clears repair markers and re-applies ${state.favorites.length} cached favorite skin(s). '
            'The game must be closed while this runs. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run restore'),
          ),
        ],
      ),
    );
    if (ok == true) state.advancedRestoreAllFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final running = state.operation.running;

    return Scaffold(
      appBar: AppBar(title: const Text('System Restore'), leading: const AppDrawerButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          PremiumReveal(child: _EnvironmentCard(state: state)),
          const PremiumSectionTitle(title: 'Maintenance tools', subtitle: 'Check and manage local game state', icon: Icons.build_circle_outlined),
          const SizedBox(height: 16),
          PremiumReveal(index: 1, child: _ShizukuGuideCard(state: state)),
          const SizedBox(height: 16),
          PremiumReveal(index: 2, child: _Card(
            icon: Icons.restore,
            color: context.appSecondary,
            title: 'Advanced restore',
            subtitle: 'Clears the game repair markers then re-injects every cached '
                'favorite skin. Use this after the game repaired or reverted skins.',
            trailing: FilledButton(
              onPressed: state.favorites.isEmpty || running
                  ? null
                  : () => _confirmAdvancedRestore(context),
              child: const Text('Run'),
            ),
          )),
          const SizedBox(height: 16),
          PremiumReveal(index: 3, child: _Card(
            icon: Icons.manage_search,
            color: context.appPrimary,
            title: 'Check injected skins',
            subtitle: 'Re-verify which skins are still present in the game files '
                'and refresh the injected badge.',
            trailing: TextButton.icon(
              onPressed: running ? null : () => state.refreshInjectedStatus(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check'),
            ),
          )),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Make sure Mobile Legends: Bang Bang is fully closed before running '
              'any restore or injection operation.',
              style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  final AppState state;

  const _EnvironmentCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final game = state.game;
    final shizukuBound = state.shizukuState == 'bound' || state.shizukuState == 'granted';
    final shizukuLabel = shizukuBound
        ? 'Connected'
        : state.shizukuState == 'no_permission'
            ? 'Permission needed'
            : state.shizukuState == 'idle'
                ? 'Starting…'
                : 'Unavailable';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientMid.withValues(alpha: .24),
            blurRadius: 26,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System environment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Live device and access status', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              _StatusBadge(label: 'LIVE', ok: true),
            ],
          ),
          const SizedBox(height: 16),
          _EnvRow(
            icon: Icons.sports_esports_rounded,
            label: 'Game',
            value: game == null ? 'Not detected' : game.packageName,
            ok: game != null,
          ),
          _EnvRow(
            icon: Icons.folder_open_rounded,
            label: 'Storage access',
            value: state.storageGranted ? 'Granted' : 'Not granted',
            ok: state.storageGranted,
            actionLabel: 'Grant',
            onTap: state.storageGranted ? null : () => context.read<AppState>().grantStorage(),
          ),
          _EnvRow(
            icon: Icons.shield_rounded,
            label: 'Shizuku service',
            value: shizukuLabel,
            ok: shizukuBound,
            actionLabel: 'Connect',
            onTap: shizukuBound ? null : () => context.read<AppState>().requestShizukuPermission(),
          ),
          if (shizukuBound) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 8),
                  Expanded(child: Text('Shizuku is bound and ready', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool ok;
  const _StatusBadge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.circle : Icons.circle_outlined, size: 7, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ]),
      );
}

class _EnvRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final VoidCallback? onTap;
  final String actionLabel;

  const _EnvRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.onTap,
    this.actionLabel = 'Fix',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: .9)),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12)),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: ok ? .17 : .10),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: .18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.white.withValues(alpha: .14),
                shape: const StadiumBorder(),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .42)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appCardBorder),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: context.appOnSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ShizukuGuideCard extends StatelessWidget {
  final AppState state;

  const _ShizukuGuideCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isBound = state.shizukuState == 'granted' || state.shizukuState == 'bound';

    return ExpansionTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      backgroundColor: context.appSurface,
      collapsedBackgroundColor: context.appSurface,
      leading: Icon(
        Icons.help_outline,
        color: isBound ? context.appSuccess : context.appPrimaryDark,
      ),
      title: const Text(
        'Android 11+ Shizuku Setup Guide',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        isBound ? 'Shizuku connected & active' : 'Required to access game data files on Android 11+',
        style: TextStyle(
          fontSize: 12,
          color: isBound ? context.appSuccess : context.appOnSurfaceVariant,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              const Text(
                'Android 11+ restricts direct access to /Android/data. Shizuku grants elevated access without root:',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              _stepItem('1', 'Install Shizuku app from Play Store or GitHub.'),
              _stepItem('2', 'Enable Developer Options in phone settings.'),
              _stepItem('3', 'Turn on Wireless Debugging in Developer Options.'),
              _stepItem('4', 'Open Shizuku -> tap "Pairing" -> pair via Wireless Debugging code.'),
              _stepItem('5', 'Tap "Start" in Shizuku.'),
              _stepItem('6', 'Return to ASTROML and tap "Fix" or "Request Permission".'),
              const SizedBox(height: 12),
              if (!isBound)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AppState>().requestShizukuPermission(),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Request Shizuku Permission'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.gradientStart,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
