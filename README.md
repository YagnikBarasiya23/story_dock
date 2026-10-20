# Story Dock

[![pub package](https://img.shields.io/pub/v/story_dock.svg)](https://pub.dev/packages/story_dock)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A stories tray for Flutter that collapses into a floating glass dock as the feed scrolls. The faces fly from the tray into a capsule pinned to the top bar, then keep rotating through more accounts while you read.

<p align="center">
  <img src="https://raw.githubusercontent.com/YagnikBarasiya23/story_dock/main/media/demo.gif" width="300" alt="Scrolling a feed: the stories tray flies into a capsule at the top, which turns through more faces; then the stack style with a +8 count.">
</p>

- **Follows the finger.** The collapse is driven by the scroll offset, so it is reversible. A scroll that stops halfway settles open or docked.
- **Two styles.** `capsule` puts small faces side by side and turns them like a carousel. `stack` overlaps the faces with a `+N` count and shuffles the front one to the back.
- **Never moves your feed.** The dock is drawn on top, so the list doesn't jump.
- **Works with any vertical scroll view.** No scroll controller to wire up.
- **Accessible.** RTL, keyboard, screen reader labels, reduced motion and text scaling.

## Install

```sh
flutter pub add story_dock
```

## Usage

Put the `tray` widget first in your scroll view:

```dart
import 'package:story_dock/story_dock.dart';

StoryDock(
  stories: const [
    StoryDockItem(label: 'Ava Reyes', image: NetworkImage('https://…/ava.jpg')),
    StoryDockItem(label: 'Milo Kent'),             // initials on a colour
    StoryDockItem(label: 'Kai Adler', seen: true), // muted ring
  ],
  leading: IconButton(icon: const Icon(Icons.add), onPressed: () {}),
  title: const Text('Feed'),
  trailing: IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
  onStoryTap: (index) => openStory(index),
  builder: (context, tray) => ListView.builder(
    itemCount: posts.length + 1,
    itemBuilder: (context, i) => i == 0 ? tray : PostCard(posts[i - 1]),
  ),
)
```

The stack style:

```dart
StoryDock(variant: StoryDockVariant.stack, …)
```

With a `CustomScrollView`, wrap the tray in `SliverToBoxAdapter(child: tray)` as the first sliver.

### Control it from code

```dart
final dock = StoryDockController();

StoryDock(controller: dock, …);

dock.progress;   // 0 open … 1 docked
dock.isDocked;
await dock.expand(); // scroll back to the top
await dock.dock();   // scroll just far enough to dock
```

## Options

| Parameter | Default | What it does |
|---|---|---|
| `stories` | required | `StoryDockItem`s in display order. |
| `builder` | required | `(context, tray)` returns your vertical scroll view with `tray` first. |
| `variant` | `capsule` | `StoryDockVariant.capsule` or `StoryDockVariant.stack`. |
| `onStoryTap` | `null` | Called with the index of a tapped tray avatar. |
| `onDockTap` | scroll to top | Called when the dock is tapped. |
| `leading`, `title`, `trailing` | `null` | Top bar slots. The title fades as the dock arrives. |
| `hideActionsWhenDocked` | `true` | Fade `leading` and `trailing` once docked; the capsule widens into the space. |
| `dockCount` | `4` | Faces shown in the dock at once. |
| `rotateEvery` | `1.8 s` | Time between two rotations while docked. `Duration.zero` turns rotation off. |
| `snap` | `true` | Settle a halfway scroll to open or docked. |
| `controller` | `null` | A `StoryDockController`. |
| `style` | `StoryDockStyle()` | Colours and sizes, see below. |
| `dockSemanticLabel` | "Stories, N accounts, M new" | Screen reader label of the dock. |

`StoryDockItem(label, image, color, seen)`: `image` is any `ImageProvider`. Without one, the initials of `label` are drawn on `color` (or a colour picked from the label).

`StoryDockStyle` fields (all optional; colours default to the theme):

| Field | Default |
|---|---|
| `ringColor` / `seenRingColor` | `colorScheme.primary` / `colorScheme.outlineVariant` |
| `separatorColor` | `colorScheme.surface` (rings between faces in the stack) |
| `glassTint` / `glassBorderColor` | surface at 55% / onSurface at 12% |
| `blurSigma` | `20` (0 turns the backdrop blur off) |
| `labelStyle` / `countStyle` | from `textTheme.labelSmall` / `labelMedium` |
| `trayAvatarSize` / `trayItemExtent` | `68` / `80` |
| `dockAvatarSize` | `28` |
| `barHeight` | `52` (plus the top safe area) |
| `barScrim` | `true` (soft fade behind the bar once content scrolls under it) |

## How it behaves

- Scroll progress `p` runs from 0 (tray open) to 1 (scrolled past the tray). The faces leave their tray slots on a small arc, one after another, and land in the dock. The title fades first; then the leading and trailing actions fade and the capsule widens a little.
- The dock starts with the first story that is visible in the tray, so the faces you were looking at are the ones that fly up.
- While docked, the dock moves one place every `rotateEvery`. It only rotates while fully docked, while the app is visible, while the dock isn't pressed, and when there are more stories than slots.
- Tapping the dock scrolls back to the top by default.

## Accessibility

- Each tray avatar is a button: "Ava Reyes's story, new" (or "seen").
- The dock is one button: "Stories, 12 accounts, 5 new". It can only be focused while it is shown.
- Tab and Shift+Tab move between them; Enter or Space activates.
- With reduced motion (`MediaQuery.disableAnimations`), faces fade instead of flying, the dock doesn't rotate, and snaps jump.
- Labels follow the text scale up to 1.6x and the tray grows to fit.
- The tray and dock mirror in right-to-left layouts.

## Support

Flutter 3.32 or newer, on Android, iOS, web, macOS, Windows and Linux. Pure Dart, no platform code. The example app is in [`example/`](example/lib/main.dart).

## License

MIT, see [LICENSE](LICENSE).
