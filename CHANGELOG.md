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
