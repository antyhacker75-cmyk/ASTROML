import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

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
