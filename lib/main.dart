import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> astromlNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _showPushedUpdate(RemoteMessage message) async {
  if (astromlNavigatorKey.currentContext == null) return;
  try {
    final response = await http.get(Uri.parse('https://api.github.com/repos/antyhacker75-cmyk/yuyu/releases/latest'), headers: const {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = '${data['tag_name'] ?? ''}';
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    final body = '${data['body'] ?? ''}';
    final images = RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)').allMatches(body).map((m) => m.group(1)!).take(2).toList();
    final notes = body.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '').trim();
    final dialogContext = astromlNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    await showDialog<void>(context: dialogContext, builder: (ctx) => AlertDialog(
      title: Text('ASTROML $version is available'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(notes.isEmpty ? 'A new ASTROML update is available.' : notes),
        for (final image in images) ...[const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))],
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessageOpenedApp.listen(_showPushedUpdate);
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  runApp(const AstroMlApp());
  if (initialMessage != null) {
    Future<void>.delayed(const Duration(seconds: 2), () => _showPushedUpdate(initialMessage));
  }
}

class AstroMlApp extends StatelessWidget {
  const AstroMlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AppState()..init()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp(
      title: 'ASTROML',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      builder: (context, child) {
        AppColors.setThemeBrightness(Theme.of(context).brightness);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(theme.textScale),
          ),
          child: child!,
        );
      },
      navigatorKey: astromlNavigatorKey,
      home: const _StartupGate(),
    );
  }
}


class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loading) return const HomeShell();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surfaceContainerHighest, colors.surface],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .72, end: 1),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd]),
                      boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .25), blurRadius: 28, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('ASTROML', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 5)),
                const SizedBox(height: 8),
                Text('Preparing your workspace', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                const SizedBox(height: 25),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const LinearProgressIndicator(minHeight: 4),
                ),
                const SizedBox(height: 10),
                Text('Fetching hero data and checking services…', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
