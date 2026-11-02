import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';
import '../widgets/premium_ui.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _confirmInjectAll(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inject all favorites?'),
        content: Text(
            'This will download and inject ${state.favorites.length} skin(s) into the game. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Inject all'),
          ),
        ],
      ),
    );
    if (ok == true) state.injectAllFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favorites;
    final running = state.operation.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Collection'),
        leading: const AppDrawerButton(),
        actions: [
          if (favorites.isNotEmpty && !running)
            TextButton.icon(
              onPressed: () => _confirmInjectAll(context),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Inject all'),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? const _EmptyFavorites()
          : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
              PremiumGradientPanel(child: Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: context.appPrimary.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.bookmarks_rounded, color: context.appPrimaryDark, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR COLLECTION', style: TextStyle(fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${favorites.length} saved skin${favorites.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Your bookmarked looks in one place', style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
                ])),
              ])),
              const PremiumSectionTitle(title: 'Saved skins', subtitle: 'Quick access to your favorites', icon: Icons.star_rounded),
              for (var i = 0; i < favorites.length; i++) ...[
                PremiumReveal(index: i, child: _FavoriteTile(favorite: favorites[i])),
                if (i != favorites.length - 1) const SizedBox(height: 11),
              ],
            ]),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const PremiumEmptyState(icon: Icons.star_border_rounded, title: 'No favorites yet', message: 'Tap the star on any skin to save it here. Your collection will be ready whenever you need it.');
  }
}

class _FavoriteTile extends StatelessWidget {
  final Favorite favorite;

  const _FavoriteTile({required this.favorite});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final injected = state.injected.contains('${favorite.heroId}:${favorite.skinName}');
    final injecting = state.operation.running && state.operation.message.contains(favorite.skinName);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.appSurface, context.appSurfaceVariant.withValues(alpha: .42)]),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: context.appCardBorder),
        boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: .05), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            // A larger portrait viewport keeps the full skin artwork visible.
            // BoxFit.contain preserves each skin image's original aspect ratio.
            width: 112,
            height: 136,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.appSurfaceVariant, context.appPrimary.withValues(alpha: .10)],
              ),
              border: Border.all(color: context.appCardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: favorite.skinImage.isEmpty
                ? Icon(Icons.image_outlined, color: context.appOnSurfaceVariant, size: 28)
                : AppImage(url: favorite.skinImage, width: 112, height: 136, fit: BoxFit.contain),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.skinName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    favorite.heroName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.appOnSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  if (injecting)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                          value: state.operation.progress < 0
                              ? null
                              : state.operation.progress / 100,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.operation.stage.isEmpty ? 'Injecting...' : state.operation.stage,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appOnSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        if (injected) ...[
                          Icon(Icons.check_circle, size: 14, color: context.appSuccess),
                          const SizedBox(width: 4),
                          Text(
                            'Injected',
                            style: TextStyle(fontSize: 11, color: context.appSuccess, fontWeight: FontWeight.w600),
                          ),
                        ] else
                          FilledButton(
                            onPressed: state.operation.running
                                ? null
                                : () => state.injectSkinFromFavorite(favorite),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Inject'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove from favorites',
            onPressed: () async {
              await state.removeFavorite(favorite.heroId, favorite.skinName);
            },
            icon: Icon(Icons.close, size: 20, color: context.appOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
