import 'package:flutter/material.dart';

/// How the docked stories are laid out.
enum StoryDockVariant {
  /// Small avatars side by side in a glass capsule. The faces slide along
  /// the capsule like a carousel while docked.
  capsule,

  /// Overlapping avatars followed by a `+N` count. The front face leaves
  /// and a new one joins at the back while docked.
  stack,
}

/// Visual options for [StoryDock]. Null colours and text styles come from
/// the ambient [ThemeData].
@immutable
class StoryDockStyle {
  /// Creates a style. Every field is optional.
  const StoryDockStyle({
    this.ringColor,
    this.seenRingColor,
    this.separatorColor,
    this.glassTint,
    this.glassBorderColor,
    this.blurSigma = 20,
    this.labelStyle,
    this.countStyle,
    this.trayAvatarSize = 68,
    this.trayItemExtent = 80,
    this.dockAvatarSize = 28,
    this.barHeight = 52,
    this.barScrim = true,
  }) : assert(trayAvatarSize > 0),
       assert(trayItemExtent >= trayAvatarSize),
       assert(dockAvatarSize > 0),
       assert(barHeight >= dockAvatarSize + 8),
       assert(blurSigma >= 0);

  /// Ring around unseen stories. Defaults to `colorScheme.primary`.
  final Color? ringColor;

  /// Ring around seen stories. Defaults to `colorScheme.outlineVariant`.
  final Color? seenRingColor;

  /// Ring that separates overlapping faces in [StoryDockVariant.stack].
  /// Defaults to `colorScheme.surface`.
  final Color? separatorColor;

  /// Fill of the glass dock. Defaults to the surface colour at 55%.
  final Color? glassTint;

  /// Hairline edge of the glass dock.
  final Color? glassBorderColor;

  /// Backdrop blur of the glass dock. 0 turns the blur off.
  final double blurSigma;

  /// Style of the names under the tray avatars.
  final TextStyle? labelStyle;

  /// Style of the `+N` count in the stack dock.
  final TextStyle? countStyle;

  /// Outer diameter of a tray avatar, ring included.
  final double trayAvatarSize;

  /// Horizontal space given to each tray avatar.
  final double trayItemExtent;

  /// Outer diameter of a docked avatar.
  final double dockAvatarSize;

  /// Height of the top bar that holds the leading, title, trailing and dock.
  final double barHeight;

  /// Whether a soft fade is drawn behind the top bar once content scrolls
  /// under it.
  final bool barScrim;

  /// Returns a copy with the given fields replaced.
  StoryDockStyle copyWith({
    Color? ringColor,
    Color? seenRingColor,
    Color? separatorColor,
    Color? glassTint,
    Color? glassBorderColor,
    double? blurSigma,
    TextStyle? labelStyle,
    TextStyle? countStyle,
    double? trayAvatarSize,
    double? trayItemExtent,
    double? dockAvatarSize,
    double? barHeight,
    bool? barScrim,
  }) {
    return StoryDockStyle(
      ringColor: ringColor ?? this.ringColor,
      seenRingColor: seenRingColor ?? this.seenRingColor,
      separatorColor: separatorColor ?? this.separatorColor,
      glassTint: glassTint ?? this.glassTint,
      glassBorderColor: glassBorderColor ?? this.glassBorderColor,
      blurSigma: blurSigma ?? this.blurSigma,
      labelStyle: labelStyle ?? this.labelStyle,
      countStyle: countStyle ?? this.countStyle,
      trayAvatarSize: trayAvatarSize ?? this.trayAvatarSize,
      trayItemExtent: trayItemExtent ?? this.trayItemExtent,
      dockAvatarSize: dockAvatarSize ?? this.dockAvatarSize,
      barHeight: barHeight ?? this.barHeight,
      barScrim: barScrim ?? this.barScrim,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryDockStyle &&
      other.ringColor == ringColor &&
      other.seenRingColor == seenRingColor &&
      other.separatorColor == separatorColor &&
      other.glassTint == glassTint &&
      other.glassBorderColor == glassBorderColor &&
      other.blurSigma == blurSigma &&
      other.labelStyle == labelStyle &&
      other.countStyle == countStyle &&
      other.trayAvatarSize == trayAvatarSize &&
      other.trayItemExtent == trayItemExtent &&
      other.dockAvatarSize == dockAvatarSize &&
      other.barHeight == barHeight &&
      other.barScrim == barScrim;

  @override
  int get hashCode => Object.hash(
    ringColor,
    seenRingColor,
    separatorColor,
    glassTint,
    glassBorderColor,
    blurSigma,
    labelStyle,
    countStyle,
    trayAvatarSize,
    trayItemExtent,
    dockAvatarSize,
    barHeight,
    barScrim,
  );
}
