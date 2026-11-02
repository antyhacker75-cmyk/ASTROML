import 'package:flutter/material.dart';
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
  static const _screens = [HeroesScreen(), CosmeticsScreen(), FavoritesScreen(), RestoreScreen(), SettingsScreen()];
  static const _items = [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'Discover'),
    (Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic_rounded, 'Library'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
    (Icons.history_rounded, Icons.restore_rounded, 'Restore'),
    (Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(
        backgroundColor: context.appSurface,
        child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(22, 28, 22, 24), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF063B66), Color(0xFF087EAE), Color(0xFF6D28D9)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 34), SizedBox(height: 12), Text('YUYU', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)), Text('COSMETIC COMPANION', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(height: 12),
          for (var i=0; i<_items.length; i++) ListTile(leading: Icon(_items[i].$1, color: _index == i ? context.appPrimaryDark : context.appOnSurfaceVariant), title: Text(_items[i].$3, style: TextStyle(fontWeight: _index == i ? FontWeight.w800 : FontWeight.w500)), selected: _index == i, selectedTileColor: context.appPrimary.withValues(alpha: .10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), onTap: () { setState(() => _index=i); Navigator.pop(context); }),
          const Spacer(), Padding(padding: const EdgeInsets.all(20), child: Text('A cleaner way to explore your collection.', style: TextStyle(color: context.appOnSurfaceVariant, fontSize: 12))),
        ])),
      ),
      body: Column(children: [const OperationBanner(), Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 280), switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic, transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(.025, 0), end: Offset.zero).animate(animation), child: child)), child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index])))]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: context.appSurface, border: Border(top: BorderSide(color: context.appCardBorder)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .20 : .05), blurRadius: 22, offset: const Offset(0,-5))]),
        child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 5), child: Row(children: [for (var i=0; i<_items.length; i++) Expanded(child: _NavItem(icon: _items[i].$1, activeIcon: _items[i].$2, label: _items[i].$3, selected: _index==i, onTap: () => setState(() => _index=i)))]))),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon; final String label; final bool selected; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 7), decoration: BoxDecoration(color: selected ? context.appPrimary.withValues(alpha: .13) : Colors.transparent, borderRadius: BorderRadius.circular(15)), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedScale(scale: selected ? 1.08 : 1, duration: const Duration(milliseconds: 180), child: Icon(selected ? activeIcon : icon, size: 21, color: selected ? context.appPrimaryDark : context.appOnSurfaceVariant)), const SizedBox(height: 3), Text(label, maxLines: 1, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? context.appPrimaryDark : context.appOnSurfaceVariant))])));
}
