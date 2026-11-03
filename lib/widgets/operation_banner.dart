import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class OperationBanner extends StatelessWidget {
  const OperationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final op = context.watch<AppState>().operation;
    final visible = op.running || op.message.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: visible ? _OperationPanel(op: op) : const SizedBox(width: double.infinity),
    );
  }
}

class _OperationPanel extends StatelessWidget {
  final OperationState op;
  const _OperationPanel({required this.op});

  @override
  Widget build(BuildContext context) {
    final running = op.running;
    final failed = op.message.toLowerCase().startsWith('failed');
    final color = running ? context.appSecondary : (failed ? context.appError : context.appSuccess);
    final hasProgress = running && op.total > 0;
    final indeterminate = running && op.progress < 0;
    final fraction = running ? (indeterminate ? null : (op.progress / 100).clamp(0.0, 1.0)) : (op.done / (op.total == 0 ? 1 : op.total)).clamp(0.0, 1.0);

    return Material(
      color: context.appSurface,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: color.withValues(alpha: 0.09),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: op.skinImage.isNotEmpty
                        ? Image.network(op.skinImage, width: 42, height: 42, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 42, height: 42, color: color.withValues(alpha: 0.15), child: Icon(Icons.image_not_supported_outlined, color: color, size: 20)))
                        : Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
                            child: running ? _PulseIcon(color: color) : Icon(failed ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: color, size: 20)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(running ? 'WORKING ON IT' : (failed ? 'OPERATION FAILED' : 'COMPLETED'), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(op.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.appOnSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (running || hasProgress)
                    if (!indeterminate) Text('${(fraction! * 100).round()}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                  if (!running)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.read<AppState>().dismissOperation(),
                      icon: Icon(Icons.close_rounded, color: context.appOnSurfaceVariant, size: 18),
                    ),
                ],
              ),
              if (running || hasProgress) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.13),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(op.stage.isNotEmpty ? op.stage : (op.done > 0 ? '${op.done} of ${op.total} items processed' : 'Processing...'), style: TextStyle(color: context.appOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final Color color;
  const _PulseIcon({required this.color});
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.45, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: Icon(Icons.sync_rounded, color: widget.color, size: 20),
  );
}
