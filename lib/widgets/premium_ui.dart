import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PremiumReveal extends StatelessWidget {
  final Widget child;
  final int index;
  const PremiumReveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index.clamp(0, 8) * 45).toInt()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class PremiumSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  const PremiumSectionTitle({super.key, required this.title, this.subtitle, this.trailing, this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
    child: Row(children: [
      if (icon != null) ...[
        Container(width: 34, height: 34, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [context.appPrimary.withValues(alpha: .22), context.appSecondary.withValues(alpha: .18)]),
          borderRadius: BorderRadius.circular(11),
        ), child: Icon(icon, size: 18, color: context.appPrimaryDark)),
        const SizedBox(width: 10),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.3)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 11, color: context.appOnSurfaceVariant)),
        ],
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class PremiumStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const PremiumStatPill({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: context.appSurface.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: context.appCardBorder),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: context.appPrimaryDark),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 10, color: context.appOnSurfaceVariant)),
      const SizedBox(width: 5),
      Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );
}

class PremiumGradientPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const PremiumGradientPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
        context.appPrimary.withValues(alpha: .19),
        context.appSecondary.withValues(alpha: .12),
        context.appSurface,
      ]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.appPrimary.withValues(alpha: .20)),
      boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: .07), blurRadius: 24, offset: const Offset(0, 9))],
    ),
    child: child,
  );
}

class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const PremiumEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(30),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 82, height: 82, decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [context.appPrimary.withValues(alpha: .20), context.appSecondary.withValues(alpha: .14)]),
      ), child: Icon(icon, size: 38, color: context.appPrimaryDark)),
      const SizedBox(height: 18),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: context.appOnSurfaceVariant)),
      if (action != null) ...[const SizedBox(height: 18), action!],
    ]),
  ));
}
