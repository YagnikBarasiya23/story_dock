import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'story_dock_item.dart';
import 'story_dock_style.dart';

part 'story_dock_controller.dart';

/// Builds the scrolling feed. Put [tray] first in a vertical scroll view.
typedef StoryDockBuilder = Widget Function(BuildContext context, Widget tray);

const double _trayPadTop = 10;
const double _trayPadBottom = 10;
const double _trayPadSide = 6;
const double _labelGap = 6;
const double _dockPad = 6;
const double _arcHeight = 14;
const Duration _scrollDuration = Duration(milliseconds: 320);

const List<Color> _fallbackColors = <Color>[
  Color(0xFF6E62D9),
  Color(0xFF18946E),
  Color(0xFFD0582E),
  Color(0xFFC94C7A),
  Color(0xFF2F7FD0),
  Color(0xFFB06F14),
  Color(0xFF5B8F1F),
  Color(0xFF8A4FC4),
];

double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

/// A stories tray that collapses into a floating glass dock pinned to the
/// top bar as the feed scrolls.
///
/// The collapse follows the scroll offset of the vertical scroll view that
/// [builder] returns, so it is reversible and tracks the finger. Put the
/// `tray` widget handed to [builder] first in that scroll view:
///
/// ```dart
/// StoryDock(
///   stories: stories,
///   builder: (context, tray) => ListView(children: [tray, ...posts]),
/// )
/// ```
class StoryDock extends StatefulWidget {
  /// Creates a stories tray with a dock.
  const StoryDock({
    super.key,
    required this.stories,
    required this.builder,
    this.variant = StoryDockVariant.capsule,
    this.onStoryTap,
    this.onDockTap,
    this.leading,
    this.title,
    this.trailing,
    this.dockCount = 4,
    this.rotateEvery = const Duration(milliseconds: 1800),
    this.snap = true,
    this.hideActionsWhenDocked = true,
    this.controller,
    this.style = const StoryDockStyle(),
    this.dockSemanticLabel,
  }) : assert(dockCount > 0, 'dockCount must be at least 1');

  /// The accounts in the tray, in display order.
  final List<StoryDockItem> stories;

  /// Builds the feed. See [StoryDockBuilder].
  final StoryDockBuilder builder;

  /// How the docked avatars are laid out.
  final StoryDockVariant variant;

  /// Called with the index of a tapped tray avatar.
  final ValueChanged<int>? onStoryTap;

  /// Called when the dock is tapped. When null, the feed scrolls back to the
  /// top and the tray opens.
  final VoidCallback? onDockTap;

  /// Widget at the start of the top bar, for example an add button.
  final Widget? leading;

  /// Widget in the middle of the top bar. It fades out as the dock arrives.
  final Widget? title;

  /// Widget at the end of the top bar, for example a notifications button.
  final Widget? trailing;

  /// How many avatars the dock shows at once.
  final int dockCount;

  /// Time between two rotations of the docked avatars.
  final Duration rotateEvery;

  /// Whether a scroll that stops halfway settles to open or docked.
  final bool snap;

  /// Whether [leading] and [trailing] fade out once the dock has settled.
  /// The capsule then widens a little into the free space.
  final bool hideActionsWhenDocked;

  /// Optional controller to read the progress or open and dock from code.
  final StoryDockController? controller;

  /// Colours and sizes.
  final StoryDockStyle style;

  /// Screen reader label of the dock. Defaults to
  /// "Stories, N accounts, M new".
  final String? dockSemanticLabel;

  @override
  State<StoryDock> createState() => _StoryDockState();
}

class _StoryDockState extends State<StoryDock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _pixels = ValueNotifier<double>(0);
  final ValueNotifier<int> _base = ValueNotifier<int>(0);
  late final ScrollController _trayScroll = ScrollController()
    ..addListener(_onTrayScroll);
  late final AnimationController _rotation;

  ScrollPosition? _position;
  double _trayOffset = 0;
  double _trayExtent = 0;
  double _topInset = 0;
  double _lastProgress = 0;
  bool _pressed = false;
  bool _appActive = true;
  bool _reduceMotion = false;

  int get _count => widget.stories.length;
  int get _slots => math.min(widget.dockCount, _count);
  double get _progress =>
      _trayExtent <= 0 ? 0 : _clamp01(_pixels.value / _trayExtent);
  bool get _docked => _progress >= 1;

  double get _shift =>
      Curves.easeInOutCubic.transform(_clamp01((_rotation.value - 0.7) / 0.3));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = _isVisible(WidgetsBinding.instance.lifecycleState);
    _rotation = AnimationController(vsync: this, duration: widget.rotateEvery)
      ..addStatusListener(_onRotationStatus);
    _pixels.addListener(_onPixels);
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncRotation();
  }

  @override
  void didUpdateWidget(StoryDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
      widget.controller?._updateProgress(_progress);
    }
    if (oldWidget.rotateEvery != widget.rotateEvery) {
      _rotation.duration = widget.rotateEvery;
    }
    if (_count == 0) {
      _base.value = 0;
    } else if (_base.value >= _count) {
      _base.value %= _count;
    }
    _syncRotation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(this);
    _rotation.dispose();
    _trayScroll.dispose();
    _pixels.dispose();
    _base.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = _isVisible(state);
    _syncRotation();
  }

  // Inactive still shows the app (for example an unfocused browser window),
  // so only hidden, paused and detached stop the rotation.
  static bool _isVisible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  // Scroll tracking ---------------------------------------------------------

  bool _onNotification(Notification notification) {
    ScrollMetrics? metrics;
    BuildContext? source;
    var ended = false;
    if (notification is ScrollNotification) {
      if (notification.depth != 0) return false;
      metrics = notification.metrics;
      source = notification.context;
      ended = notification is ScrollEndNotification;
    } else if (notification is ScrollMetricsNotification) {
      if (notification.depth != 0) return false;
      metrics = notification.metrics;
      source = notification.context;
    }
    if (metrics == null || metrics.axis != Axis.vertical) return false;
    final scrollable = source == null ? null : Scrollable.maybeOf(source);
    if (scrollable != null) _position = scrollable.position;
    _pixels.value = metrics.pixels;
    if (ended) _maybeSnap();
    return false;
  }

  void _onPixels() {
    final p = _progress;
    if (p > 0 && _lastProgress <= 0) {
      _base.value = _firstVisible();
    }
    if (p < 1 && _lastProgress >= 1) _revealBaseInTray();
    _lastProgress = p;
    widget.controller?._updateProgress(p);
    _syncRotation();
  }

  void _onTrayScroll() {
    if (_trayScroll.hasClients) _trayOffset = _trayScroll.offset;
  }

  int _firstVisible() {
    if (_count == 0) return 0;
    final index = (_trayOffset / widget.style.trayItemExtent).round();
    return index.clamp(0, _count - 1);
  }

  void _revealBaseInTray() {
    if (_firstVisible() == _base.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_trayScroll.hasClients) return;
      final position = _trayScroll.position;
      final target = (_base.value * widget.style.trayItemExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _trayScroll.jumpTo(target);
    });
  }

  void _maybeSnap() {
    if (!widget.snap) return;
    final p = _progress;
    if (p <= 0 || p >= 1) return;
    final target = p < 0.5 ? 0.0 : _trayExtent;
    Future<void>.microtask(() {
      final position = _position;
      if (!mounted || position == null || !position.hasPixels) return;
      if (position.isScrollingNotifier.value) return;
      _scrollTo(target);
    });
  }

  Future<void> _scrollTo(double target) async {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 0.5) return;
    if (_reduceMotion) {
      position.jumpTo(clamped);
    } else {
      await position.animateTo(
        clamped,
        duration: _scrollDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> expand() => _scrollTo(0);

  Future<void> dock() => _scrollTo(_trayExtent);

  // Rotation ----------------------------------------------------------------

  bool get _canRotate =>
      _docked &&
      !_pressed &&
      _appActive &&
      !_reduceMotion &&
      _count > _slots &&
      widget.rotateEvery > Duration.zero;

  void _syncRotation() {
    if (_canRotate) {
      if (!_rotation.isAnimating) _rotation.forward();
      return;
    }
    if (_rotation.isAnimating) _rotation.stop();
    if (_rotation.value > 0.7 && _count > 0) {
      // Finish a move that was cut short so faces never stop half way.
      _base.value = (_base.value + 1) % _count;
    }
    if (_rotation.value != 0) _rotation.value = 0;
  }

  void _onRotationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_count > 0) _base.value = (_base.value + 1) % _count;
    _rotation.value = 0;
    if (_canRotate) _rotation.forward();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    _syncRotation();
  }

  void _onDockTap() {
    final onDockTap = widget.onDockTap;
    if (onDockTap != null) {
      onDockTap();
    } else {
      expand();
    }
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final style = widget.style;
    final labelScaler = mq.textScaler.clamp(maxScaleFactor: 1.6);
    final labelStyle = _labelStyle(theme);

    _topInset = mq.padding.top + style.barHeight;
    if (_count == 0) {
      _trayExtent = 0;
    } else {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: labelStyle),
        textScaler: labelScaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      _trayExtent =
          _trayPadTop +
          style.trayAvatarSize +
          _labelGap +
          painter.height +
          _trayPadBottom;
      painter.dispose();
    }

    final tray = _buildTray(context, theme, labelStyle, labelScaler);

    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: Builder(
                    builder: (context) => widget.builder(context, tray),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    _pixels,
                    _base,
                    _rotation,
                  ]),
                  builder: (context, _) =>
                      _buildOverlay(context, theme, constraints.maxWidth),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _labelStyle(ThemeData theme) {
    final base = (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface,
    );
    return base.merge(widget.style.labelStyle);
  }

  Color _ringFor(StoryDockItem item, ThemeData theme) {
    final style = widget.style;
    return item.seen
        ? style.seenRingColor ?? theme.colorScheme.outlineVariant
        : style.ringColor ?? theme.colorScheme.primary;
  }

  Widget _buildTray(
    BuildContext context,
    ThemeData theme,
    TextStyle labelStyle,
    TextScaler labelScaler,
  ) {
    final style = widget.style;
    if (_count == 0) return SizedBox(height: _topInset);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: _topInset),
        SizedBox(
          height: _trayExtent,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: labelScaler),
            child: Material(
              type: MaterialType.transparency,
              child: ListView.builder(
                key: const PageStorageKey<String>('story_dock_tray'),
                controller: _trayScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: _trayPadSide),
                itemExtent: style.trayItemExtent,
                itemCount: _count,
                itemBuilder: (context, index) =>
                    _buildTrayItem(theme, labelStyle, index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayItem(ThemeData theme, TextStyle labelStyle, int index) {
    final item = widget.stories[index];
    final style = widget.style;
    void tap() => widget.onStoryTap?.call(index);
    return Semantics(
      button: true,
      label: "${item.label}'s story, ${item.seen ? 'seen' : 'new'}",
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey<String>('story_dock_tray_$index'),
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_pixels, _base]),
          builder: (context, _) {
            final p = _progress;
            final flying =
                !_reduceMotion &&
                p > 0 &&
                _slots > 0 &&
                (index - _base.value) % _count < _slots;
            final fade = 1 - _clamp01(p / 0.4);
            return Column(
              children: <Widget>[
                const SizedBox(height: _trayPadTop),
                Opacity(
                  opacity: flying ? 0 : (_reduceMotion ? fade : 1),
                  child: _Avatar(
                    item: item,
                    size: style.trayAvatarSize,
                    ringColor: _ringFor(item, theme),
                  ),
                ),
                const SizedBox(height: _labelGap),
                Opacity(
                  opacity: fade,
                  child: SizedBox(
                    width: style.trayItemExtent - 6,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, ThemeData theme, double width) {
    final style = widget.style;
    final mq = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    double mirror(double x) => rtl ? width - x : x;

    final p = _progress;
    final n = _slots;
    final capsule = widget.variant == StoryDockVariant.capsule;
    final flight = _clamp01(p / 0.7);
    final actionsOpacity = widget.hideActionsWhenDocked
        ? 1 - _clamp01((p - 0.55) / 0.3)
        : 1.0;
    final widen = capsule && widget.hideActionsWhenDocked
        ? Curves.easeOut.transform(_clamp01((p - 0.8) / 0.2))
        : 0.0;
    final dockOpacity = Curves.easeOut.transform(_clamp01((p - 0.15) / 0.45));
    final shift = _docked ? _shift : 0.0;
    final cx = width / 2;
    final cy = mq.padding.top + style.barHeight / 2;
    final d = style.dockAvatarSize * (1 + 0.12 * widen);
    final capH = d + _dockPad * 2;

    // Dock geometry in left-to-right terms, mirrored at the end.
    final extra = _count - n;
    TextPainter? countPainter;
    final countStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        )
        .merge(style.countStyle);
    double contentW;
    double Function(double slot) slotX;
    double countLeft = 0;
    if (capsule) {
      final gap = 6 + 4 * widen;
      contentW = n * d + math.max(0, n - 1) * gap;
      final left = cx - contentW / 2;
      slotX = (slot) => left + d / 2 + slot * (d + gap);
    } else {
      final step = d * 0.64;
      var countW = 0.0;
      if (extra > 0) {
        countPainter = TextPainter(
          text: TextSpan(text: '+$extra', style: countStyle),
          textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        countW = countPainter.width + 6;
      }
      contentW = d + math.max(0, n - 1) * step + countW;
      final left = cx - contentW / 2;
      slotX = (slot) => left + d / 2 + slot * step;
      countLeft = left + d + math.max(0, n - 1) * step + 6;
    }
    final capW = contentW + _dockPad * 2 + (capsule ? 4 : 2);

    final children = <Widget>[];

    if (style.barScrim) {
      final scrim = _clamp01(_pixels.value / 24);
      if (scrim > 0) {
        final surface = theme.colorScheme.surface;
        children.add(
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _topInset + 14,
            child: IgnorePointer(
              child: Opacity(
                opacity: scrim,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        surface.withValues(alpha: 0.94),
                        surface.withValues(alpha: 0.7),
                        surface.withValues(alpha: 0),
                      ],
                      stops: const <double>[0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    final title = widget.title;
    if (title != null) {
      final titleOpacity = 1 - _clamp01(p / 0.3);
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: mq.padding.top,
          height: style.barHeight,
          child: IgnorePointer(
            ignoring: titleOpacity < 0.1,
            child: ExcludeSemantics(
              excluding: titleOpacity < 0.1,
              child: Opacity(
                opacity: titleOpacity,
                child: Transform.translate(
                  offset: Offset(0, -6 * (1 - titleOpacity)),
                  child: Center(child: title),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final entry in <(Widget?, bool)>[
      (widget.leading, true),
      (widget.trailing, false),
    ]) {
      final child = entry.$1;
      if (child == null) continue;
      final hidden = actionsOpacity < 0.1;
      children.add(
        Positioned.directional(
          textDirection: Directionality.of(context),
          start: entry.$2 ? 4 : null,
          end: entry.$2 ? null : 4,
          top: mq.padding.top,
          height: style.barHeight,
          child: IgnorePointer(
            ignoring: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: Opacity(
                opacity: actionsOpacity,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    if (n > 0 && p > 0) {
      final interactive = dockOpacity >= 0.5;
      final unseen = widget.stories.where((s) => !s.seen).length;
      children.add(
        Positioned(
          left: cx - capW / 2,
          top: cy - capH / 2,
          width: capW,
          height: capH,
          child: IgnorePointer(
            ignoring: !interactive,
            child: ExcludeSemantics(
              excluding: !interactive,
              child: Opacity(
                opacity: dockOpacity,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * dockOpacity,
                  child: Semantics(
                    button: true,
                    label:
                        widget.dockSemanticLabel ??
                        'Stories, $_count accounts, $unseen new',
                    onTap: _onDockTap,
                    excludeSemantics: true,
                    child: Listener(
                      onPointerDown: (_) => _setPressed(true),
                      onPointerUp: (_) => _setPressed(false),
                      onPointerCancel: (_) => _setPressed(false),
                      child: _Glass(
                        key: const ValueKey<String>('story_dock_dock'),
                        style: style,
                        theme: theme,
                        height: capH,
                        onTap: _onDockTap,
                        canFocus: interactive,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final avatarSize = style.trayAvatarSize;
      final trayY = _topInset - _pixels.value + _trayPadTop + avatarSize / 2;
      final stagger = n > 1 ? math.min(0.07, 0.21 / (n - 1)) : 0.0;
      final separator = style.separatorColor ?? theme.colorScheme.surface;
      final avatars = <Widget>[];

      Widget place({
        required int slot,
        required double x,
        required double y,
        required double size,
        required double opacity,
        required Color ring,
      }) {
        final item = widget.stories[(_base.value + slot) % _count];
        return Positioned(
          key: ValueKey<String>('story_dock_slot_$slot'),
          left: mirror(x) - size / 2,
          top: y - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Opacity(
              opacity: _clamp01(opacity),
              child: _Avatar(item: item, size: size, ringColor: ring),
            ),
          ),
        );
      }

      for (var slot = 0; slot < n; slot++) {
        final item = widget.stories[(_base.value + slot) % _count];
        final index = (_base.value + slot) % _count;
        final e = _reduceMotion
            ? 1.0
            : Curves.easeInOutCubic.transform(
                _clamp01((flight - slot * stagger) / 0.79),
              );
        final startX =
            _trayPadSide +
            index * style.trayItemExtent +
            style.trayItemExtent / 2 -
            _trayOffset;
        final endX = slotX(slot - shift);
        final arc = _reduceMotion ? 0.0 : math.sin(math.pi * e);
        final x = ui.lerpDouble(startX, endX, e)!;
        final y = ui.lerpDouble(trayY, cy, e)! - arc * _arcHeight;
        final leaving = slot == 0 ? shift : 0.0;
        final size =
            (ui.lerpDouble(avatarSize, d, e)! + arc * 4) * (1 - 0.3 * leaving);
        final baseRing = _ringFor(item, theme);
        final ring = capsule
            ? baseRing
            : Color.lerp(baseRing, separator, _clamp01(e * 1.4 - 0.4))!;
        final opacity = (_reduceMotion ? dockOpacity : 1.0) * (1 - leaving);
        avatars.add(
          place(
            slot: slot,
            x: x,
            y: y,
            size: size,
            opacity: opacity,
            ring: ring,
          ),
        );
      }
      if (shift > 0) {
        final item = widget.stories[(_base.value + n) % _count];
        final ring = capsule ? _ringFor(item, theme) : separator;
        avatars.add(
          place(
            slot: n,
            x: slotX(n - shift),
            y: cy,
            size: d * (0.7 + 0.3 * shift),
            opacity: shift,
            ring: ring,
          ),
        );
      }
      // In the stack the front face sits on top.
      children.addAll(capsule ? avatars : avatars.reversed);

      if (countPainter != null) {
        final countW = countPainter.width;
        final countH = countPainter.height;
        countPainter.dispose();
        children.add(
          Positioned(
            left: rtl ? width - countLeft - countW : countLeft,
            top: cy - countH / 2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: dockOpacity,
                  child: Text(
                    '+$extra',
                    key: const ValueKey<String>('story_dock_count'),
                    style: countStyle,
                    textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      countPainter?.dispose();
    }

    return Stack(children: children);
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    super.key,
    required this.style,
    required this.theme,
    required this.height,
    required this.onTap,
    required this.canFocus,
  });

  final StoryDockStyle style;
  final ThemeData theme;
  final double height;
  final VoidCallback onTap;
  final bool canFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(height / 2);
    final tint = style.glassTint ?? scheme.surface.withValues(alpha: 0.55);
    final border =
        style.glassBorderColor ?? scheme.onSurface.withValues(alpha: 0.12);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: border, width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(Colors.white.withValues(alpha: 0.10), tint),
            tint,
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: canFocus,
          customBorder: const StadiumBorder(),
        ),
      ),
    );
    if (style.blurSigma > 0) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: body,
      );
    }
    return ClipRRect(borderRadius: radius, child: body);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.item,
    required this.size,
    required this.ringColor,
  });

  final StoryDockItem item;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final ring = math.max(1.0, size * 0.035);
    final image = item.image;
    final initials = _Initials(item: item);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: ring),
        ),
        child: Padding(
          padding: EdgeInsets.all(ring * 2),
          child: ClipOval(
            child: image == null
                ? initials
                : Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => initials,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.item});

  final StoryDockItem item;

  @override
  Widget build(BuildContext context) {
    final hash = item.label.codeUnits.fold<int>(0, (a, b) => a * 31 + b);
    final color =
        item.color ?? _fallbackColors[hash.abs() % _fallbackColors.length];
    return ColoredBox(
      color: color,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.6,
          heightFactor: 0.42,
          child: FittedBox(
            child: Text(
              item.initials,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
