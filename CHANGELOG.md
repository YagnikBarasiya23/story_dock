## 2.1.0

Smoother capsule, checked frame by frame against the reference recording.

- The enlarged capsule is now the compact one scaled up (about 1.6×), still four faces wide, instead of stretching across the bar. Its top edge stays put and it grows down and out.
- The compact capsule scrolls under the finger straight away and grows as the drag starts, without dropping the gesture. A tap or Enter still grows it.
- Growing is a pure scale of a fixed layout: no relayout per frame, and the scroll position carries through.
- Flings settle on whole faces.
- The capsule drops in from above with `leading` and `trailing` (200 ms), with no scale.
- Borderless glass by default (`glassBorderColor` is now `null`), with glass circles behind `leading` and `trailing` while the capsule shows (`StoryDockStyle.actionGlass`, default `true`).
- Performance: scrolling the feed no longer rebuilds the bar once the tray has scrolled away, the capsule's tray items no longer listen to the scroll, and all glass shapes share one backdrop (`BackdropGroup`).
- `expandedDockAvatarSize` now defaults to 46.
- Example: edge to edge under a transparent status bar, with full-bleed posts.

## 2.0.0

Breaking: the capsule style now follows the pinned stories bar it was modelled on.

- `StoryDockVariant.capsule`: the tray scrolls away with the feed (no flying faces). Once it is gone, a compact glass capsule fades in between `leading` and `trailing`. It no longer rotates on its own.
- Touching the capsule (or pressing Enter) enlarges it to nearly the full bar width and turns it into a horizontal strip of every story. Tap a face to open it. It stays enlarged while the feed scrolls, shrinks on Escape, with `collapseAfter`, or when the feed returns to the tray, and keeps the faces you scrolled to.
- The capsule ignores `snap`, `rotateEvery` and `onDockTap` (they still apply to `StoryDockVariant.stack`, which is unchanged).
- The top bar row (`leading`, `title`, `trailing`) scrolls away with the tray.
- New: `StoryDock.collapseAfter`, `StoryDockController.expandDock()`, `collapseDock()` and `isDockExpanded`, `StoryDockStyle.expandedDockAvatarSize` and `dockMargin`.

## 1.0.0

- First release.
- `StoryDock`: a stories tray that collapses into a floating glass dock, driven by the scroll offset, with snap.
- Two styles: `StoryDockVariant.capsule` (faces side by side, carousel rotation) and `StoryDockVariant.stack` (overlapping faces with a `+N` count, shuffle rotation).
- Leading, title and trailing slots in the top bar; actions fade as the dock settles.
- `StoryDockController` with `progress`, `isDocked`, `expand()` and `dock()`.
- `StoryDockStyle` for colours, glass, sizes and bar height.
- RTL, keyboard, screen reader labels and reduced motion.
