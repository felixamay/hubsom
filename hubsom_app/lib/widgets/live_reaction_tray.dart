import 'package:flutter/material.dart';

import '../models/live_reaction_kind.dart';

class LiveReactionTray extends StatelessWidget {
  const LiveReactionTray({
    super.key,
    required this.selectedId,
    required this.onPick,
  });

  final String selectedId;
  final ValueChanged<LiveReactionKind> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'React',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kind in LiveReactionCatalog.kinds)
                  _Chip(
                    kind: kind,
                    selected: kind.id == selectedId,
                    onTap: () => onPick(kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final LiveReactionKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kind.color.withValues(alpha: 0.35) : Colors.white12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kind.emoji, style: const TextStyle(fontSize: 22)),
              Text(
                kind.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
