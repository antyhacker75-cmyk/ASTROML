import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/update_checker.dart';

import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const AstroMlApp());
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
      home: const _RootHome(),
    );
  }
}


class _RootHome extends StatelessWidget {
  const _RootHome();

  @override
  Widget build(BuildContext context) {
    return const _StartupGate();
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loading) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          HomeShell(),
          Offstage(child: UpdateChecker(managerOnly: true)),
        ],
      );
    }
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
