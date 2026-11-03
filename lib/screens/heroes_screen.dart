import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';
import '../widgets/premium_ui.dart';
import 'hero_detail_screen.dart';

class HeroesScreen extends StatefulWidget {
  const HeroesScreen({super.key});

  @override
  State<HeroesScreen> createState() => _HeroesScreenState();
}

class _HeroesScreenState extends State<HeroesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _role;

  static const _baseClasses = ['Assassin', 'Fighter', 'Mage', 'Marksman', 'Support', 'Tank'];

  static List<String> _roleTokens(String role) =>
      role.split(RegExp(r'[\s/]+')).where((t) => t.isNotEmpty).toList();

  /// Only the individual base classes, never mixed roles like
  /// "Assassin Fighter". A hero with a mixed role is matched against each of
  /// its individual classes separately.
  List<String> _roles(List<HeroEntry> heroes) {
    final seen = <String>{};
    for (final h in heroes) {
      for (final token in _roleTokens(h.heroInfo.role)) {
        if (_baseClasses.contains(token)) seen.add(token);
      }
    }
    return _baseClasses.where(seen.contains).toList();
  }

  List<HeroEntry> _filtered(List<HeroEntry> heroes) {
    var list = heroes;
    if (_role != null) {
      list = list
          .where((h) => _roleTokens(h.heroInfo.role).contains(_role))
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((h) =>
          h.heroInfo.name.toLowerCase().contains(q) ||
          [...h.skins, ...h.otherSkins].any((skin) =>
              skin.name.toLowerCase().contains(q)) ||
          h.skinToSkin.any((group) => group.any((entry) {
            final skin = [...h.skins, ...h.otherSkins]
                .where((item) => item.id == entry.skinInfo);
            return skin.any((item) => item.name.toLowerCase().contains(q));
          }))).toList();
    }
    list.sort((a, b) => a.heroInfo.name.toLowerCase().compareTo(b.heroInfo.name.toLowerCase()));
    return list;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heroes = state.heroes;
    final roles = _roles(heroes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero Discovery'),
        leading: const AppDrawerButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: state.loading ? null : state.reloadHeroes,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search heroes, skins, and Other Skins',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: context.appSurface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (roles.length > 1)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _role == null,
                      onSelected: (_) => setState(() => _role = null),
                    ),
                  ),
                  for (final role in roles)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(role),
                        selected: _role == role,
                        onSelected: (_) => setState(() => _role = role),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildBody(state, heroes)),
        ],
      ),
    );
  }

  Widget _buildBody(AppState state, List<HeroEntry> heroes) {
    if (state.loading && heroes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null && heroes.isEmpty) {
      return _ErrorRetry(message: state.loadError!, onRetry: state.reloadHeroes);
    }
    final filtered = _filtered(heroes);
    final query = _query.trim().toLowerCase();
    final newItems = query.isEmpty
        ? <CosmeticItem>[]
        : state.newlyAddedSkins.where((item) =>
            item.title.toLowerCase().contains(query) ||
            item.type.toLowerCase().contains(query)).toList();
    final skinSearchItems = <({HeroEntry hero, Skin skin})>[];
    if (query.isNotEmpty) {
      for (final hero in heroes) {
        for (final skin in [...hero.skins, ...hero.otherSkins]) {
          if (skin.name.toLowerCase().contains(query) ||
              hero.heroInfo.name.toLowerCase().contains(query)) {
            if (!skinSearchItems.any((item) =>
                item.hero.heroInfo.id == hero.heroInfo.id &&
                item.skin.name.toLowerCase() == skin.name.toLowerCase())) {
              skinSearchItems.add((hero: hero, skin: skin));
            }
          }
        }
      }
    }
    final skinToSkinItems = <({HeroEntry hero, String title, String image, String route})>[];
    if (query.isNotEmpty) {
      for (final hero in heroes) {
        for (final group in hero.skinToSkin) {
          if (group.length < 2) continue;
          Skin? findSkin(int id) => [...hero.skins, ...hero.otherSkins]
              .where((skin) => skin.id == id).firstOrNull;
          final source = findSkin(group.first.skinInfo);
          for (final entry in group.skip(1)) {
            final target = findSkin(entry.skinInfo);
            if (target == null || source == null) continue;
            final route = '${source.name} → ${target.name}';
            if (source.name.toLowerCase().contains(query) ||
                target.name.toLowerCase().contains(query) ||
                route.toLowerCase().contains(query)) {
              if (!skinToSkinItems.any((item) => item.hero.heroInfo.id == hero.heroInfo.id && item.route == route)) {
                skinToSkinItems.add((hero: hero, title: target.name, image: target.image, route: route));
              }
            }
          }
        }
      }
    }
    if (filtered.isEmpty && newItems.isEmpty && skinSearchItems.isEmpty && skinToSkinItems.isEmpty) {
      return const PremiumEmptyState(icon: Icons.search_off_rounded, title: 'No results found', message: 'Try another hero or skin name, including Other Skins.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        if (newItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
            child: Row(children: [
              const Expanded(child: Text('NEWLY ADDED SKINS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              Text('${newItems.length} results', style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
            ]),
          ),
          for (final item in newItems.take(12))
            _NewSkinSearchTile(
              item: item,
              hero: state.heroes.where((hero) =>
                [...hero.skins, ...hero.otherSkins].any((skin) =>
                  skin.name.toLowerCase() == item.title.toLowerCase() ||
                  (item.img.isNotEmpty && skin.image == item.img))
              ).firstOrNull,
            ),
          const SizedBox(height: 14),
        ],
        if (skinSearchItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
            child: Row(children: [
              const Expanded(child: Text('MATCHING SKINS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              Text('${skinSearchItems.length} results', style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
            ]),
          ),
          for (final item in skinSearchItems.take(20))
            _SkinSearchTile(hero: item.hero, skin: item.skin),
          const SizedBox(height: 14),
        ],
        if (skinToSkinItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
            child: Row(children: [
              const Expanded(child: Text('SKIN-TO-SKIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              Text('${skinToSkinItems.length} results', style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
            ]),
          ),
          for (final item in skinToSkinItems.take(12))
            _SkinToSkinSearchTile(hero: item.hero, title: item.title, image: item.image, route: item.route),
          const SizedBox(height: 14),
        ],
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
            child: Text('HEROES & SKINS (${filtered.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          ),
        for (var index = 0; index < filtered.length; index++) ...[
          PremiumReveal(index: index, child: HeroCard(hero: filtered[index])),
          if (index != filtered.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkinSearchTile extends StatelessWidget {
  final HeroEntry hero;
  final Skin skin;
  const _SkinSearchTile({required this.hero, required this.skin});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: context.appSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.appCardBorder)),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeroDetailScreen(hero: hero))),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 52, height: 52, child: AppImage(url: skin.image, fit: BoxFit.cover))),
          title: Text(skin.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text('${hero.heroInfo.name} • ${skin.type.isEmpty ? 'Skin' : skin.type}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    ),
  );
}

class _SkinToSkinSearchTile extends StatelessWidget {
  final HeroEntry hero;
  final String title;
  final String image;
  final String route;

  const _SkinToSkinSearchTile({required this.hero, required this.title, required this.image, required this.route});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: context.appSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.appCardBorder)),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeroDetailScreen(hero: hero))),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 52, height: 52, child: AppImage(url: image, fit: BoxFit.cover))),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text('${hero.heroInfo.name} • $route', maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.auto_awesome_rounded),
        ),
      ),
    ),
  );
}

class _NewSkinSearchTile extends StatelessWidget {
  final CosmeticItem item;
  final HeroEntry? hero;
  const _NewSkinSearchTile({required this.item, this.hero});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.appCardBorder),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hero != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HeroDetailScreen(hero: hero!),
            ));
          } else {
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(item.title),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (item.img.isNotEmpty)
                    SizedBox(height: 150, child: AppImage(url: item.img, fit: BoxFit.contain)),
                  const SizedBox(height: 8),
                  Text(item.type.isEmpty ? 'Newly added skin' : item.type),
                  const SizedBox(height: 6),
                  const Text('No matching hero or injection entry is available in the current data.'),
                ]),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
              ),
            );
          }
        },
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 52, height: 52,
          child: AppImage(url: item.img, fit: BoxFit.cover)),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(item.type.isEmpty ? 'Newly added skin' : item.type,
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: context.appPrimary,
          borderRadius: BorderRadius.circular(7)),
        child: const Text('NEW', style: TextStyle(color: Colors.white,
          fontSize: 9, fontWeight: FontWeight.w900)),
      ),
      ),
      ),
    ),
  );
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
              'Could not load heroes',
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

class HeroCard extends StatelessWidget {
  final HeroEntry hero;

  const HeroCard({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final role = hero.heroInfo.role
        .split(RegExp(r'[\s/]+'))
        .where((t) => t.isNotEmpty)
        .join(' / ');

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HeroDetailScreen(hero: hero)),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: context.appCardBorder),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: AppImage(url: hero.heroInfo.portraitIcon, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hero.heroInfo.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(role.isEmpty ? 'Hero' : role, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant, fontWeight: FontWeight.w600)),
                    if (hero.heroInfo.lane.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(hero.heroInfo.lane, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: context.appPrimaryDark)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: context.appOnSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
