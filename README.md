<p align="center">
  <a href="https://github.com/YagnikBarasiya23/story_dock"><img src="https://raw.githubusercontent.com/YagnikBarasiya23/story_dock/main/media/banner.png" width="800" alt="Story Dock, a Wiiby component: a stories row that becomes a glass capsule in the top bar"></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/story_dock"><img src="https://img.shields.io/pub/v/story_dock.svg?color=1f2a3a" alt="pub package"></a>
  <a href="https://pub.dev/packages/story_dock/score"><img src="https://img.shields.io/pub/points/story_dock?color=1f2a3a" alt="pub points"></a>
  <a href="https://github.com/YagnikBarasiya23/story_dock/blob/main/LICENSE"><img src="https://img.shields.io/badge/licence-MIT-1f2a3a.svg" alt="MIT licence"></a>
</p>

A stories tray for Flutter that turns into a floating glass dock as the feed scrolls. Once the tray has scrolled away, a small capsule of faces appears in the top bar. Touch it and it grows into a strip of every story that you can swipe sideways.

<p align="center">
  <img src="https://raw.githubusercontent.com/YagnikBarasiya23/story_dock/main/media/demo-hd.gif" width="800" alt="Scrolling a feed: the tray scrolls away and a small capsule of faces appears between the add and theme buttons; a touch enlarges it into a sideways strip. Then the stack style, where faces fly into an overlapping stack with a +8 count.">
</p>

- **Two styles.**
  - `capsule` (default): the tray scrolls away with the feed, then a borderless glass capsule with four faces drops into the top bar between your leading and trailing buttons (each in its own glass circle). It stays still until touched. Swipe it and it scrolls under your finger straight away while it scales up about 1.6×, still four faces wide; the side buttons step aside. It always comes to rest on whole faces.
  - `stack`: the faces fly from the tray into an overlapping stack with a `+N` count as you scroll, and the front face shuffles to the back every couple of seconds.
- **Never moves your feed.** The dock is drawn on top, so the list doesn't jump.
- **Cheap to run.** Once the tray has scrolled away, scrolling the feed doesn't rebuild the bar, and growing the capsule is a pure scale, so no face is laid out again per frame.
- **Edge to edge.** The feed runs under the status bar; the bar and dock sit inside the top safe area.
- **Works with any vertical scroll view.** No scroll controller to wire up.
- **Accessible.** RTL, keyboard, screen reader labels, reduced motion and text scaling.

## Install

```sh
flutter pub add story_dock
```

## Usage

Put the `tray` widget first in your scroll view. For an edge-to-edge look, let the feed run under a transparent status bar (`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`); the dock keeps itself inside the top safe area.

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

The stack style (faces fly into an overlapping stack):

```dart
StoryDock(variant: StoryDockVariant.stack, …)
```

With a `CustomScrollView`, wrap the tray in `SliverToBoxAdapter(child: tray)` as the first sliver.

### Control it from code

```dart
final dock = StoryDockController();

StoryDock(controller: dock, …);

dock.progress;        // 0 open … 1 tray scrolled away
dock.isDocked;
dock.isDockExpanded;  // capsule enlarged
dock.expandDock();    // enlarge the capsule
dock.collapseDock();  // shrink it again
await dock.expand();  // scroll back to the top
await dock.dock();    // scroll just far enough to dock
```

## Options

| Parameter | Default | What it does |
|---|---|---|
| `stories` | required | `StoryDockItem`s in display order. |
| `builder` | required | `(context, tray)` returns your vertical scroll view with `tray` first. |
| `variant` | `capsule` | `StoryDockVariant.capsule` or `StoryDockVariant.stack`. |
| `onStoryTap` | `null` | Called with the index of a tapped tray avatar. |
| `onDockTap` | scroll to top | Stack only: called when the dock is tapped. The capsule enlarges instead. |
| `leading`, `title`, `trailing` | `null` | Top bar slots. They scroll away with the tray; with the capsule, `leading` and `trailing` come back beside it. |
| `hideActionsWhenDocked` | `true` | Capsule: fade `leading` and `trailing` while enlarged so it can use the full width. Stack: fade them once docked. |
| `dockCount` | `4` | Faces in the compact capsule, or in the stack. |
| `collapseAfter` | `null` | Capsule: shrink again this long after the last touch. `null` keeps it enlarged until the feed returns to the tray. |
| `rotateEvery` | `1.8 s` | Stack only: time between two shuffles. `Duration.zero` turns it off. |
| `snap` | `true` | Stack only: settle a halfway scroll to open or docked. The capsule never snaps. |
| `controller` | `null` | A `StoryDockController`. |
| `style` | `StoryDockStyle()` | Colours and sizes, see below. |
| `dockSemanticLabel` | "Stories, N accounts, M new" | Screen reader label of the dock. |

`StoryDockItem(label, image, color, seen)`: `image` is any `ImageProvider`. Without one, the initials of `label` are drawn on `color` (or a colour picked from the label).

`StoryDockStyle` fields (all optional; colours default to the theme):

| Field | Default |
|---|---|
| `ringColor` / `seenRingColor` | `colorScheme.primary` / `colorScheme.outlineVariant` |
| `separatorColor` | `colorScheme.surface` (rings between faces in the stack) |
| `glassTint` / `glassBorderColor` | surface at 55% / none (borderless) |
| `actionGlass` | `true` (glass circles behind `leading` and `trailing` while the capsule shows) |
| `blurSigma` | `20` (0 turns the backdrop blur off) |
| `labelStyle` / `countStyle` | from `textTheme.labelSmall` / `labelMedium` |
| `trayAvatarSize` / `trayItemExtent` | `68` / `80` |
| `dockAvatarSize` | `28` (compact capsule and stack) |
| `expandedDockAvatarSize` | `46` (enlarged capsule; the capsule scales by `46 / 28`) |
| `dockMargin` | `16` (smallest gap between the enlarged capsule and the screen edges) |
| `barHeight` | `52` (plus the top safe area) |
| `barScrim` | `true` (soft fade behind the bar once content scrolls under it) |

## How it behaves

- Scroll progress `p` runs from 0 (tray open) to 1 (scrolled past the tray). The top bar row scrolls away with the tray.
- **Capsule:** at `p = 1` the compact capsule drops 24 px into place and fades in over 200 ms, together with `leading` and `trailing`. It starts with the first story that was visible in the tray. It doesn't move on its own. A swipe scrolls it at once and grows it (200 ms, the top edge stays put); a tap or Enter grows it too. Once grown, tap a face to open that story. Flings settle on whole faces. It stays enlarged while the feed scrolls (or until `collapseAfter`), Escape shrinks it, and scrolling back to the tray resets it. When it shrinks it keeps the faces you scrolled to.
- **Stack:** the faces leave their tray slots on a small arc, one after another, and land in the stack. While docked, the front face moves to the back every `rotateEvery`, only while the app is visible, the dock isn't pressed, and there are more stories than slots. Tapping it scrolls back to the top by default.

## Accessibility

- Each tray avatar is a button: "Ava Reyes's story, new" (or "seen").
- The dock is one button: "Stories, 12 accounts, 5 new". It can only be focused while it is shown. Once the capsule is enlarged, each face is its own button.
- Tab and Shift+Tab move between them; Enter or Space activates; Escape shrinks the enlarged capsule.
- With reduced motion (`MediaQuery.disableAnimations`), the capsule appears and grows without animating, the stack's faces fade instead of flying, nothing rotates, and snaps jump.
- Labels follow the text scale up to 1.6x and the tray grows to fit.
- The tray and dock mirror in right-to-left layouts.

## Support

Flutter 3.32 or newer, on Android, iOS, web, macOS, Windows and Linux. Pure Dart, no platform code. The example app is in [`example/`](example/lib/main.dart).

## License

MIT, see [LICENSE](https://github.com/YagnikBarasiya23/story_dock/blob/main/LICENSE).
