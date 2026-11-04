import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';
import '../widgets/premium_ui.dart';

class CosmeticsScreen extends StatefulWidget {
  const CosmeticsScreen({super.key});

  @override
  State<CosmeticsScreen> createState() => _CosmeticsScreenState();
}

class _CosmeticsScreenState extends State<CosmeticsScreen> {
  CosmeticCategory _category = CosmeticCategory.newlyAdded;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadCosmetics(_category);
    });
  }

  void _selectCategory(CosmeticCategory category) {
    if (_category == category) return;
    setState(() => _category = category);
    context.read<AppState>().loadCosmetics(category);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetic Library'),
        leading: const AppDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: state.operation.running
                ? null
                : () => state.reloadCosmetics(_category),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              children: [
                for (final category in CosmeticCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: category == _category
                        ? FilledButton(
                            onPressed: () => _selectCategory(category),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 34),
                            ),
                            child: Text(category.label),
                          )
                        : OutlinedButton(
                            onPressed: () => _selectCategory(category),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 34),
                            ),
                            child: Text(category.label),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: TextField(controller: _search, onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(hintText: 'Search cosmetics', prefixIcon: const Icon(Icons.search), suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() => _query = ''); }), filled: true, fillColor: context.appSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
        _CosmeticLibraryHeader(category: _category, count: state.cosmetics(_category).length, loading: state.isCosmeticLoading(_category)),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero).animate(animation), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(_category), child: _buildBody(state)),
        )),
      ]),
    );
  }

  Widget _buildBody(AppState state) {
    final allItems = state.cosmetics(_category);
    final query = _query.trim().toLowerCase();
    final items = query.isEmpty ? allItems : allItems.where((item) => item.title.toLowerCase().contains(query) || item.type.toLowerCase().contains(query)).toList();
    final loading = state.isCosmeticLoading(_category);
    final error = state.cosmeticError(_category);

    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return _ErrorRetry(
        message: error,
        onRetry: () => state.reloadCosmetics(_category),
      );
    }
    if (items.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.auto_awesome_mosaic_outlined,
        title: 'Nothing here yet',
        message: 'There are no items in this category right now. Try another category or refresh the library.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PremiumReveal(index: index, child: _CosmeticCard(category: _category, item: item));
      },
    );
  }
}

class _CosmeticLibraryHeader extends StatelessWidget {
  final CosmeticCategory category;
  final int count;
  final bool loading;
  const _CosmeticLibraryHeader({required this.category, required this.count, required this.loading});

  IconData get _icon => switch (category) {
    CosmeticCategory.newlyAdded => Icons.auto_awesome_rounded,
    CosmeticCategory.emotes => Icons.emoji_emotions_rounded,
    CosmeticCategory.trails => Icons.blur_on_rounded,
    CosmeticCategory.recalls => Icons.swap_calls_rounded,
    CosmeticCategory.eliminations => Icons.flash_on_rounded,
    CosmeticCategory.respawns => Icons.restart_alt_rounded,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: PremiumGradientPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(
          color: context.appPrimary.withValues(alpha: .16), borderRadius: BorderRadius.circular(15),
        ), child: Icon(_icon, color: context.appPrimaryDark, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(category.label.toUpperCase(), style: TextStyle(fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.w900, color: context.appPrimaryDark)),
          const SizedBox(height: 3),
          const Text('Explore the collection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Browse available cosmetic items', style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(loading ? '…' : '$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('ITEMS', style: TextStyle(fontSize: 8, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: context.appOnSurfaceVariant)),
        ]),
      ]),
    ),
  );
}

class _CosmeticCard extends StatelessWidget {
  final CosmeticCategory category;
  final CosmeticItem item;

  const _CosmeticCard({required this.category, required this.item});

  Future<void> _confirmRestore(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove injection mark?'),
        content: Text(
            '${item.title} will be marked as not injected. The files stay on '
            'disk until the game repairs them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) state.restoreCosmetic(category, item);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final injected = state.isCosmeticInjected(category, item.title);
    final injecting =
        state.operation.running && state.operation.message.contains(item.title);
    final available = item.sc.isNotEmpty && item.img.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(21),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .38)]),
        boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: injected ? .16 : .055), blurRadius: injected ? 22 : 14, offset: const Offset(0, 7))],
        border: Border.all(
          color: injected
              ? context.appPrimary.withValues(alpha: 0.6)
              : context.appCardBorder,
          width: injected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(url: item.img, fit: BoxFit.cover),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x55000000)]))),
                if (injected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.appPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Injected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -.2),
                ),
                if (item.type.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.type,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: context.appOnSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                if (injecting)
                  Column(
                    children: [
                      const LinearProgressIndicator(minHeight: 4),
                      const SizedBox(height: 4),
                      Text(
                        'Injecting...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (injected)
                  OutlinedButton(
                    onPressed: state.operation.running
                        ? null
                        : () => _confirmRestore(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Injected'),
                  )
                else
                  FilledButton(
                    onPressed: available && !state.operation.running
                        ? () => state.injectCosmetic(category, item)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: Text(available ? 'Inject' : 'No injection file'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: context.appOnSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'Could not load cosmetics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}