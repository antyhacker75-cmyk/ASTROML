import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/lumina_api.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_image.dart';

class BoostersScreen extends StatefulWidget {
  const BoostersScreen({super.key});

  @override
  State<BoostersScreen> createState() => _BoostersScreenState();
}

class _BoostersScreenState extends State<BoostersScreen> {
  final TextEditingController _search = TextEditingController();
  late Future<List<BoosterItem>> _future = LuminaApi.fetchBoosters();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = LuminaApi.fetchBoosters());
  }

  Future<void> _confirmRestore(BoosterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove injection mark?'),
        content: Text(
          '${item.name} will be marked as not injected. The files stay in the game folder until the game repairs them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().restoreBooster(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boosters'),
        leading: const AppDrawerButton(),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search boosters',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: context.appSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<BoosterItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load boosters\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final query = _query.trim().toLowerCase();
          final items = (snapshot.data ?? <BoosterItem>[]).where((item) {
            return query.isEmpty ||
                item.name.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          }).toList();
          if (items.isEmpty) {
            return const Center(child: Text('No boosters found.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.64,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final injected = state.isBoosterInjected(item.name);
              final injecting = state.operation.running &&
                  state.operation.message.contains(item.name);
              final available = item.sc.isNotEmpty;

              return Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: injected
                        ? context.appPrimary.withValues(alpha: 0.65)
                        : context.appCardBorder,
                    width: injected ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppImage(url: item.image, fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appOnSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 9),
                          if (injecting)
                            Column(
                              children: [
                                state.operation.progress >= 0
                                    ? LinearProgressIndicator(
                                        value: state.operation.progress / 100,
                                        minHeight: 4,
                                      )
                                    : const LinearProgressIndicator(minHeight: 4),
                                const SizedBox(height: 5),
                                Text(
                                  state.operation.progress >= 0
                                      ? '${state.operation.stage.isEmpty ? 'Downloading' : state.operation.stage}: ${state.operation.progress}%'
                                      : (state.operation.stage.isEmpty ? 'Working...' : state.operation.stage),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            )
                          else if (injected)
                            OutlinedButton(
                              onPressed: state.operation.running
                                  ? null
                                  : () => _confirmRestore(item),
                              child: const Text('Injected'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: available && !state.operation.running
                                  ? () => state.injectBooster(item)
                                  : null,
                              icon: const Icon(Icons.download_rounded, size: 17),
                              label: Text(available ? 'Inject' : 'Unavailable'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
