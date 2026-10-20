import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const double _gapCompact = 6;
const double _gapExpanded = 12;
const double _capsuleInset = 3;
const double _capsuleInsetExpanded = 8;
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

/// A stories tray that turns into a floating glass dock pinned to the top
/// bar once the feed scrolls past it.
///
/// With [StoryDockVariant.capsule] the tray scrolls away with the feed and a
/// small capsule of faces fades in at the top. Touching the capsule enlarges
/// it into a strip of every story that scrolls sideways. With
/// [StoryDockVariant.stack] the faces fly from the tray into an overlapping
/// stack as you scroll.
///
/// Put the `tray` widget handed to [builder] first in a vertical scroll
/// view:
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
    this.collapseAfter,
  }) : assert(dockCount > 0, 'dockCount must be at least 1');

  /// The accounts in the tray, in display order.
  final List<StoryDockItem> stories;

  /// Builds the feed. See [StoryDockBuilder].
  final StoryDockBuilder builder;

  /// How the docked avatars are laid out.
  final StoryDockVariant variant;

  /// Called with the index of a tapped tray avatar.
  final ValueChanged<int>? onStoryTap;

  /// Called when the stack dock is tapped. When null, the feed scrolls back
  /// to the top and the tray opens. The capsule dock enlarges instead.
  final VoidCallback? onDockTap;

  /// Widget at the start of the top bar, for example an add button.
  final Widget? leading;

  /// Widget in the middle of the top bar. It scrolls away with the tray.
  final Widget? title;

  /// Widget at the end of the top bar, for example a notifications button.
  final Widget? trailing;

  /// How many avatars the dock shows at once (the capsule before it is
  /// enlarged, or the stack).
  final int dockCount;

  /// Time between two rotations of the stack dock. The capsule never moves
  /// on its own.
  final Duration rotateEvery;

  /// Whether a scroll that stops halfway through the stack's flight settles
  /// to open or docked. The capsule never snaps: the feed rests wherever it
  /// is left.
  final bool snap;

  /// Whether [leading] and [trailing] make room for the dock: they fade out
  /// while the capsule is enlarged, and once the stack has settled.
  final bool hideActionsWhenDocked;

  /// Optional controller to read the progress or open and dock from code.
  final StoryDockController? controller;

  /// Colours and sizes.
  final StoryDockStyle style;

  /// Screen reader label of the dock. Defaults to
  /// "Stories, N accounts, M new".
  final String? dockSemanticLabel;

  /// How long an enlarged capsule waits after the last touch before it
  /// shrinks again. When null it stays enlarged until the feed is scrolled
  /// back to the tray.
  final Duration? collapseAfter;

  @override
  State<StoryDock> createState() => _StoryDockState();
}

class _StoryDockState extends State<StoryDock>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _pixels = ValueNotifier<double>(0);
  final ValueNotifier<int> _base = ValueNotifier<int>(0);
  late final ScrollController _trayScroll = ScrollController()
    ..addListener(_onTrayScroll);
  late final AnimationController _rotation;
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final AnimationController _expand =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 240),
        )
        ..addListener(_alignStrip)
        ..addStatusListener(_onExpandStatus);
  late final _StripController _strip = _StripController(_stripOffsetFor);
  Timer? _collapseTimer;
  double _width = 0;

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
  bool get _isCapsule => widget.variant == StoryDockVariant.capsule;

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
    if (oldWidget.variant != widget.variant) {
      _collapseTimer?.cancel();
      _expand.value = 0;
      _reveal.value = _isCapsule && _docked ? 1 : 0;
    }
    if (_count == 0) _expand.value = 0;
    _syncRotation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(this);
    _collapseTimer?.cancel();
    _rotation.dispose();
    _reveal.dispose();
    _expand.dispose();
    _strip.dispose();
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
    if (_isCapsule) {
      _syncReveal(p >= 1);
    } else if (p < 1 && _lastProgress >= 1) {
      _revealBaseInTray();
    }
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
    if (!widget.snap || _isCapsule) return;
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

  // Capsule -----------------------------------------------------------------

  void _syncReveal(bool show) {
    if (show) {
      if (_reveal.status == AnimationStatus.forward ||
          _reveal.status == AnimationStatus.completed) {
        return;
      }
      if (_reduceMotion) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    } else {
      collapseDock(instant: true);
      if (_reveal.status == AnimationStatus.reverse ||
          _reveal.status == AnimationStatus.dismissed) {
        return;
      }
      if (_reduceMotion) {
        _reveal.value = 0;
      } else {
        _reveal.reverse();
      }
    }
  }

  bool get _isDockExpanded =>
      _expand.status == AnimationStatus.forward ||
      _expand.status == AnimationStatus.completed;

  void expandDock() {
    if (!_isCapsule || _count == 0 || !_docked) return;
    _collapseTimer?.cancel();
    if (_isDockExpanded) return;
    if (_reduceMotion) {
      _expand.value = 1;
    } else {
      _expand.forward();
    }
  }

  void collapseDock({bool instant = false}) {
    _collapseTimer?.cancel();
    if (_expand.status == AnimationStatus.dismissed) return;
    if (_expand.status == AnimationStatus.reverse && !instant) return;
    // Shrink back around the faces the user scrolled to.
    if (_strip.hasClients && _count > 0) {
      final extent = _geometry(_width, _expand.value).extent;
      _base.value = (_strip.offset / extent).round().clamp(0, _count - 1);
    }
    if (instant || _reduceMotion) {
      _expand.value = 0;
    } else {
      _expand.reverse();
    }
  }

  void _scheduleCollapse() {
    final after = widget.collapseAfter;
    _collapseTimer?.cancel();
    if (after == null || !_isDockExpanded) return;
    _collapseTimer = Timer(after, collapseDock);
  }

  void _onDockPointerDown() {
    _collapseTimer?.cancel();
    if (!_isDockExpanded) expandDock();
  }

  void _onExpandStatus(AnimationStatus status) {
    widget.controller?._updateDockExpanded(_isDockExpanded);
    if (status == AnimationStatus.completed) _scheduleCollapse();
  }

  double _stripOffsetFor() {
    if (_count == 0) return 0;
    final g = _geometry(_width, _expand.value);
    final max = math.max(0.0, _count * g.extent + 2 * g.inset - g.width);
    return (_base.value * g.extent).clamp(0.0, max);
  }

  // While the capsule grows or shrinks, keep the same faces at its start.
  void _alignStrip() {
    if (!_strip.hasClients) return;
    if (_expand.status == AnimationStatus.completed) return;
    final target = _stripOffsetFor();
    if ((_strip.offset - target).abs() > 0.01) _strip.jumpTo(target);
  }

  _CapsuleGeometry _geometry(double width, double t) {
    final style = widget.style;
    final x = Curves.easeOutCubic.transform(_clamp01(t));
    final n = _slots;
    final cd = style.dockAvatarSize;
    final ed = style.expandedDockAvatarSize;
    final d = ui.lerpDouble(cd, ed, x)!;
    final extent = d + ui.lerpDouble(_gapCompact, _gapExpanded, x)!;
    final compactW = n * (cd + _gapCompact) + 2 * _capsuleInset;
    final side = widget.hideActionsWhenDocked
        ? style.dockMargin
        : style.dockMargin + 44;
    final roomW = math.max(compactW, width - 2 * side);
    final needW = _count * (ed + _gapExpanded) + 2 * _capsuleInsetExpanded;
    final expandedW = math.max(compactW, math.min(roomW, needW));
    final capW = ui.lerpDouble(compactW, expandedW, x)!;
    final inset = math.max(
      ui.lerpDouble(_capsuleInset, _capsuleInsetExpanded, x)!,
      (capW - _count * extent) / 2,
    );
    return _CapsuleGeometry(
      width: capW,
      height: d + ui.lerpDouble(12, 16, x)!,
      avatar: d,
      extent: extent,
      inset: inset,
      progress: x,
    );
  }

  // Rotation ----------------------------------------------------------------

  bool get _canRotate =>
      !_isCapsule &&
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
                    _reveal,
                    _expand,
                  ]),
                  builder: (context, _) {
                    _width = constraints.maxWidth;
                    return _buildOverlay(context, theme, constraints.maxWidth);
                  },
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
            final stack = !_isCapsule;
            final flying =
                stack &&
                !_reduceMotion &&
                p > 0 &&
                _slots > 0 &&
                (index - _base.value) % _count < _slots;
            final fade = stack ? 1 - _clamp01(p / 0.4) : 1.0;
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
    final capsule = _isCapsule;
    final p = _progress;
    final pixels = math.max(0.0, _pixels.value);
    final reveal = capsule ? Curves.easeOut.transform(_reveal.value) : 0.0;
    final expanded = capsule
        ? Curves.easeOutCubic.transform(_expand.value)
        : 0.0;
    // The top bar row scrolls away with the tray.
    final headerLift = math.min(pixels, style.barHeight);
    final headerFade = 1 - _clamp01(pixels / (style.barHeight * 0.6));

    final children = <Widget>[];

    if (style.barScrim) {
      final scrim = _clamp01(pixels / 24);
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
    if (title != null && headerFade > 0) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: mq.padding.top - headerLift,
          height: style.barHeight,
          child: IgnorePointer(
            ignoring: headerFade < 0.1,
            child: ExcludeSemantics(
              excluding: headerFade < 0.1,
              child: Opacity(
                opacity: headerFade,
                child: Center(child: title),
              ),
            ),
          ),
        ),
      );
    }

    final double actionsOpacity;
    final double actionsLift;
    if (capsule) {
      // Leave with the header, come back with the capsule, and make room
      // while the capsule is enlarged.
      actionsOpacity =
          math.max(headerFade, reveal) *
          (widget.hideActionsWhenDocked ? 1 - expanded : 1);
      actionsLift = headerLift * (1 - reveal);
    } else {
      actionsOpacity = widget.hideActionsWhenDocked
          ? 1 - _clamp01((p - 0.55) / 0.3)
          : 1.0;
      actionsLift = 0;
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
          top: mq.padding.top - actionsLift,
          height: style.barHeight,
          child: IgnorePointer(
            ignoring: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: Opacity(
                opacity: _clamp01(actionsOpacity),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    if (capsule) {
      _addCapsuleDock(children, context, theme, width, reveal);
    } else {
      _addStackDock(children, context, theme, width);
    }
    return Stack(children: children);
  }

  String get _dockLabel {
    final unseen = widget.stories.where((s) => !s.seen).length;
    return widget.dockSemanticLabel ?? 'Stories, $_count accounts, $unseen new';
  }

  void _addCapsuleDock(
    List<Widget> children,
    BuildContext context,
    ThemeData theme,
    double width,
    double reveal,
  ) {
    if (_slots == 0 || _reveal.value == 0) return;
    final style = widget.style;
    final mq = MediaQuery.of(context);
    final g = _geometry(width, _expand.value);
    final open = _expand.status == AnimationStatus.completed;
    final interactive = _reveal.value >= 0.5;
    final cx = width / 2;
    final cy = mq.padding.top + style.barHeight / 2;

    final strip = ExcludeSemantics(
      excluding: !open,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _scheduleCollapse();
          return false;
        },
        child: ListView.builder(
          key: const ValueKey<String>('story_dock_strip'),
          controller: _strip,
          scrollDirection: Axis.horizontal,
          physics: open ? null : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: g.inset),
          itemExtent: g.extent,
          itemCount: _count,
          itemBuilder: (context, index) =>
              _buildStripItem(theme, index, g.avatar, open),
        ),
      ),
    );

    final dock = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): collapseDock,
      },
      child: Listener(
        onPointerDown: (_) => _onDockPointerDown(),
        onPointerUp: (_) => _scheduleCollapse(),
        onPointerCancel: (_) => _scheduleCollapse(),
        child: _Glass(
          key: const ValueKey<String>('story_dock_dock'),
          style: style,
          theme: theme,
          height: g.height,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                strip,
                if (!open)
                  Semantics(
                    button: true,
                    label: _dockLabel,
                    onTap: expandDock,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: expandDock,
                      canRequestFocus: interactive,
                      customBorder: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    children.add(
      Positioned(
        left: cx - g.width / 2,
        top: cy - g.height / 2,
        width: g.width,
        height: g.height,
        child: IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: Opacity(
              opacity: reveal,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - reveal)),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * reveal,
                  child: dock,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStripItem(ThemeData theme, int index, double size, bool open) {
    final item = widget.stories[index];
    final avatar = SizedBox.square(
      key: ValueKey<String>('story_dock_strip_$index'),
      dimension: size,
      child: _Avatar(item: item, size: size, ringColor: _ringFor(item, theme)),
    );
    if (!open) return Center(child: avatar);
    void tap() => widget.onStoryTap?.call(index);
    return Center(
      child: Semantics(
        button: true,
        label: "${item.label}'s story, ${item.seen ? 'seen' : 'new'}",
        onTap: tap,
        excludeSemantics: true,
        child: InkResponse(onTap: tap, radius: size / 2 + 4, child: avatar),
      ),
    );
  }

  void _addStackDock(
    List<Widget> children,
    BuildContext context,
    ThemeData theme,
    double width,
  ) {
    final style = widget.style;
    final mq = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    double mirror(double x) => rtl ? width - x : x;

    final p = _progress;
    final n = _slots;
    final flight = _clamp01(p / 0.7);
    final dockOpacity = Curves.easeOut.transform(_clamp01((p - 0.15) / 0.45));
    final shift = _docked ? _shift : 0.0;
    final cx = width / 2;
    final cy = mq.padding.top + style.barHeight / 2;
    final d = style.dockAvatarSize;
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
    final contentW = d + math.max(0, n - 1) * step + countW;
    final left = cx - contentW / 2;
    double slotX(double slot) => left + d / 2 + slot * step;
    final countLeft = left + d + math.max(0, n - 1) * step + 6;
    final capW = contentW + _dockPad * 2 + 2;

    if (n == 0 || p <= 0) {
      countPainter?.dispose();
      return;
    }

    final interactive = dockOpacity >= 0.5;
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
                  label: _dockLabel,
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
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: _onDockTap,
                          canRequestFocus: interactive,
                          customBorder: const StadiumBorder(),
                        ),
                      ),
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
      final index = (_base.value + slot) % _count;
      final item = widget.stories[index];
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
      final ring = Color.lerp(
        _ringFor(item, theme),
        separator,
        _clamp01(e * 1.4 - 0.4),
      )!;
      final opacity = (_reduceMotion ? dockOpacity : 1.0) * (1 - leaving);
      avatars.add(
        place(slot: slot, x: x, y: y, size: size, opacity: opacity, ring: ring),
      );
    }
    if (shift > 0) {
      avatars.add(
        place(
          slot: n,
          x: slotX(n - shift),
          y: cy,
          size: d * (0.7 + 0.3 * shift),
          opacity: shift,
          ring: separator,
        ),
      );
    }
    // The front face sits on top.
    children.addAll(avatars.reversed);

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
  }
}

@immutable
class _CapsuleGeometry {
  const _CapsuleGeometry({
    required this.width,
    required this.height,
    required this.avatar,
    required this.extent,
    required this.inset,
    required this.progress,
  });

  final double width;
  final double height;
  final double avatar;
  final double extent;
  final double inset;
  final double progress;
}

/// Starts the strip at the faces the capsule shows, every time it appears.
class _StripController extends ScrollController {
  _StripController(this.offsetFor) : super(keepScrollOffset: false);

  final double Function() offsetFor;

  @override
  double get initialScrollOffset => offsetFor();
}

class _Glass extends StatelessWidget {
  const _Glass({
    super.key,
    required this.style,
    required this.theme,
    required this.height,
    required this.child,
  });

  final StoryDockStyle style;
  final ThemeData theme;
  final double height;
  final Widget child;

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
      child: child,
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
