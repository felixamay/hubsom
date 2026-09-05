import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum ReactionFx { float, burst, fire }

class LiveReactionKind extends Equatable {
  const LiveReactionKind({
    required this.id,
    required this.emoji,
    required this.name,
    required this.fx,
    required this.color,
  });

  final String id;
  final String emoji;
  final String name;
  final ReactionFx fx;
  final Color color;

  Duration get duration => switch (fx) {
        ReactionFx.fire => const Duration(milliseconds: 2800),
        ReactionFx.burst => const Duration(milliseconds: 2200),
        ReactionFx.float => const Duration(milliseconds: 1600),
      };

  int get floatCount => switch (fx) {
        ReactionFx.fire => 7,
        ReactionFx.burst => 5,
        ReactionFx.float => 3,
      };

  @override
  List<Object?> get props => [id, emoji];
}

abstract final class LiveReactionCatalog {
  static const kinds = <LiveReactionKind>[
    LiveReactionKind(
      id: 'fire',
      emoji: '🔥',
      name: 'Fire',
      fx: ReactionFx.fire,
      color: Color(0xFFFF6D00),
    ),
    LiveReactionKind(
      id: 'heart',
      emoji: '❤️',
      name: 'Love',
      fx: ReactionFx.burst,
      color: Color(0xFFFF4081),
    ),
    LiveReactionKind(
      id: 'laugh',
      emoji: '😂',
      name: 'LOL',
      fx: ReactionFx.float,
      color: Color(0xFFFFC107),
    ),
    LiveReactionKind(
      id: 'wow',
      emoji: '😮',
      name: 'Wow',
      fx: ReactionFx.float,
      color: Color(0xFF00AEEF),
    ),
    LiveReactionKind(
      id: 'clap',
      emoji: '👏',
      name: 'Clap',
      fx: ReactionFx.float,
      color: Color(0xFFFFC107),
    ),
    LiveReactionKind(
      id: 'hundred',
      emoji: '💯',
      name: '100',
      fx: ReactionFx.burst,
      color: Color(0xFFE53935),
    ),
    LiveReactionKind(
      id: 'party',
      emoji: '🎉',
      name: 'Party',
      fx: ReactionFx.burst,
      color: Color(0xFF7C4DFF),
    ),
    LiveReactionKind(
      id: 'rocket',
      emoji: '🚀',
      name: 'Rocket',
      fx: ReactionFx.burst,
      color: Color(0xFF2979FF),
    ),
    LiveReactionKind(
      id: 'boom',
      emoji: '💥',
      name: 'Boom',
      fx: ReactionFx.fire,
      color: Color(0xFFFF6D00),
    ),
    LiveReactionKind(
      id: 'muscle',
      emoji: '💪',
      name: 'Power',
      fx: ReactionFx.float,
      color: Color(0xFFF36F21),
    ),
    LiveReactionKind(
      id: 'cry',
      emoji: '😢',
      name: 'Cry',
      fx: ReactionFx.float,
      color: Color(0xFF42A5F5),
    ),
    LiveReactionKind(
      id: 'eyes',
      emoji: '👀',
      name: 'Eyes',
      fx: ReactionFx.float,
      color: Color(0xFF66BB6A),
    ),
  ];

  static const defaultId = 'fire';

  static LiveReactionKind get fire => byId('fire')!;

  static LiveReactionKind? byId(String id) {
    for (final k in kinds) {
      if (k.id == id) return k;
    }
    return null;
  }

  static LiveReactionKind byEmoji(String emoji) {
    for (final k in kinds) {
      if (k.emoji == emoji) return k;
    }
    if (emoji == '♥') return byId('heart')!;
    return LiveReactionKind(
      id: 'custom',
      emoji: emoji,
      name: 'React',
      fx: ReactionFx.float,
      color: const Color(0xFFFFFFFF),
    );
  }
}
