import 'package:flutter/widgets.dart';

/// One account in the stories tray.
@immutable
class StoryDockItem {
  /// Creates a story entry.
  const StoryDockItem({
    required this.label,
    this.image,
    this.color,
    this.seen = false,
  });

  /// Name shown under the avatar and read by screen readers.
  final String label;

  /// Avatar image. When null, the initials of [label] are drawn on [color].
  final ImageProvider? image;

  /// Background for the initials avatar. Picked from [label] when null.
  final Color? color;

  /// Whether the story was already watched. Seen stories get a muted ring.
  final bool seen;

  /// Up to two initials taken from [label].
  String get initials {
    final words = label.trim().split(RegExp(r'[\s_.\-]+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words[1].characters.first).toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is StoryDockItem &&
      other.label == label &&
      other.image == image &&
      other.color == color &&
      other.seen == seen;

  @override
  int get hashCode => Object.hash(label, image, color, seen);
}
