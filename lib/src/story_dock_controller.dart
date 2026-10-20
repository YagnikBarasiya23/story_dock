part of 'story_dock.dart';

/// Reads and drives the collapse of a [StoryDock] from outside.
///
/// Attach it with `StoryDock(controller: ...)`. Listeners are notified
/// whenever [progress] changes.
class StoryDockController extends ChangeNotifier {
  _StoryDockState? _state;
  double _progress = 0;
  bool _dockExpanded = false;

  /// 0 when the tray is fully open, 1 when the dock is fully settled.
  double get progress => _progress;

  /// Whether the dock is fully settled.
  bool get isDocked => _progress >= 1;

  /// Whether the capsule dock is enlarged (or growing).
  bool get isDockExpanded => _dockExpanded;

  /// Whether a [StoryDock] is using this controller.
  bool get isAttached => _state != null;

  /// Scrolls the feed back to the top so the full tray shows.
  Future<void> expand() => _state?.expand() ?? Future<void>.value();

  /// Scrolls the feed just far enough for the dock to settle.
  Future<void> dock() => _state?.dock() ?? Future<void>.value();

  /// Enlarges the capsule dock into the scrollable strip. Does nothing until
  /// the dock is showing, or for the stack style.
  void expandDock() => _state?.expandDock();

  /// Shrinks an enlarged capsule dock back to its small size.
  void collapseDock() => _state?.collapseDock();

  void _attach(_StoryDockState state) {
    assert(
      _state == null || identical(_state, state),
      'A StoryDockController can only drive one StoryDock at a time.',
    );
    _state = state;
  }

  void _detach(_StoryDockState state) {
    if (identical(_state, state)) _state = null;
  }

  void _updateDockExpanded(bool value) {
    if (value == _dockExpanded) return;
    _dockExpanded = value;
    notifyListeners();
  }

  void _updateProgress(double value) {
    if (value == _progress) return;
    _progress = value;
    notifyListeners();
  }
}
