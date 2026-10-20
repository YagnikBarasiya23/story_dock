## 1.0.0

- First release.
- `StoryDock`: a stories tray that collapses into a floating glass dock, driven by the scroll offset, with snap.
- Two styles: `StoryDockVariant.capsule` (faces side by side, carousel rotation) and `StoryDockVariant.stack` (overlapping faces with a `+N` count, shuffle rotation).
- Leading, title and trailing slots in the top bar; actions fade as the dock settles.
- `StoryDockController` with `progress`, `isDocked`, `expand()` and `dock()`.
- `StoryDockStyle` for colours, glass, sizes and bar height.
- RTL, keyboard, screen reader labels and reduced motion.
