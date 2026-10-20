import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_dock/story_dock.dart';

List<StoryDockItem> people(int n, {int seenFrom = 1 << 30}) => List.generate(
  n,
  (i) => StoryDockItem(label: 'User $i', seen: i >= seenFrom),
);

const Key feedKey = Key('feed');
const Duration rotate = Duration(milliseconds: 1000);

Future<void> pumpDock(
  WidgetTester tester, {
  List<StoryDockItem>? stories,
  // Most behaviour tests below exercise the flying stack; the capsule has
  // its own group.
  StoryDockVariant variant = StoryDockVariant.stack,
  StoryDockController? controller,
  ValueChanged<int>? onStoryTap,
  VoidCallback? onDockTap,
  Widget? leading,
  Widget? title,
  Widget? trailing,
  int dockCount = 4,
  bool snap = true,
  bool hideActionsWhenDocked = true,
  StoryDockStyle style = const StoryDockStyle(),
  String? dockSemanticLabel,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  bool reduceMotion = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 700),
  ScrollController? feedController,
  Duration? collapseAfter,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorSchemeSeed: const Color(0xFFE8503A),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: StoryDock(
              stories: stories ?? people(10),
              variant: variant,
              controller: controller,
              onStoryTap: onStoryTap,
              onDockTap: onDockTap,
              leading: leading,
              title: title,
              trailing: trailing,
              dockCount: dockCount,
              rotateEvery: rotate,
              snap: snap,
              hideActionsWhenDocked: hideActionsWhenDocked,
              style: style,
              dockSemanticLabel: dockSemanticLabel,
              collapseAfter: collapseAfter,
              builder: (context, tray) => ListView(
                key: feedKey,
                controller: feedController,
                children: <Widget>[
                  tray,
                  for (var i = 0; i < 12; i++)
                    Container(
                      height: 240,
                      margin: const EdgeInsets.all(8),
                      color: Color(0xFF203040 + i * 0x101010),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Scrolls the feed by [dy] without letting go.
Future<TestGesture> holdScroll(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(const Offset(200, 500));
  await gesture.moveBy(const Offset(0, -20)); // past touch slop
  await gesture.moveBy(Offset(0, -dy));
  await tester.pump();
  return gesture;
}

/// Pumps frames for [time]. pumpAndSettle never returns while the docked
/// faces rotate.
Future<void> settle(
  WidgetTester tester, [
  Duration time = const Duration(milliseconds: 1500),
]) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < time; t += frame) {
    await tester.pump(frame);
  }
}

/// Advances time frame by frame so tickers see every step.
Future<void> advance(WidgetTester tester, Duration time) =>
    settle(tester, time);

Future<void> dockIt(WidgetTester tester) async {
  await tester.drag(find.byKey(feedKey), const Offset(0, -400));
  await settle(tester, const Duration(milliseconds: 100));
}

Finder slot(int i) => find.byKey(ValueKey<String>('story_dock_slot_$i'));

String slotText(WidgetTester tester, int i) => tester
    .widget<Text>(find.descendant(of: slot(i), matching: find.byType(Text)))
    .data!;

Finder get dock => find.byKey(const ValueKey<String>('story_dock_dock'));

double opacityAbove(WidgetTester tester, Finder finder) => tester
    .widget<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('defaults', () {
    testWidgets('renders the tray with no configuration', (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoryDock(
              stories: people(6),
              builder: (context, tray) => ListView(
                children: <Widget>[tray, const SizedBox(height: 2000)],
              ),
            ),
          ),
        ),
      );
      expect(find.text('User 0'), findsOneWidget);
      expect(find.text('U0'), findsOneWidget);
      expect(dock, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('initials and item equality', (tester) async {
      expect(const StoryDockItem(label: 'ava reyes').initials, 'AR');
      expect(const StoryDockItem(label: 'milo').initials, 'M');
      expect(const StoryDockItem(label: 'june_park.dev').initials, 'JP');
      expect(const StoryDockItem(label: '  ').initials, '');
      expect(
        const StoryDockItem(label: 'a', seen: true),
        const StoryDockItem(label: 'a', seen: true),
      );
      expect(
        const StoryDockItem(label: 'a').hashCode,
        const StoryDockItem(label: 'a').hashCode,
      );
      expect(
        const StoryDockItem(label: 'a') == const StoryDockItem(label: 'b'),
        isFalse,
      );
    });

    testWidgets('style copyWith and equality', (tester) async {
      const style = StoryDockStyle();
      final changed = style.copyWith(
        ringColor: Colors.red,
        seenRingColor: Colors.grey,
        separatorColor: Colors.black,
        glassTint: Colors.white,
        glassBorderColor: Colors.blue,
        blurSigma: 4,
        labelStyle: const TextStyle(fontSize: 10),
        countStyle: const TextStyle(fontSize: 9),
        trayAvatarSize: 60,
        trayItemExtent: 70,
        dockAvatarSize: 24,
        barHeight: 48,
        barScrim: false,
      );
      expect(changed == style, isFalse);
      expect(changed, changed.copyWith());
      expect(changed.hashCode, changed.copyWith().hashCode);
      expect(changed.trayAvatarSize, 60);
      expect(changed.barScrim, isFalse);
    });
  });

  group('scroll-driven collapse', () {
    testWidgets('progress follows the finger and is reversible', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      expect(controller.progress, 0);
      final gesture = await holdScroll(tester, 30);
      final a = controller.progress;
      expect(a, greaterThan(0));
      expect(a, lessThan(1));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(controller.progress, greaterThan(a));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(controller.progress, closeTo(a, 0.001));
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump();
      expect(controller.progress, 1);
      expect(controller.isDocked, isTrue);
      expect(dock, findsOneWidget);
      await gesture.up();
      await settle(tester);
    });

    testWidgets('a halfway release snaps to the nearer end', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      var gesture = await holdScroll(tester, 20);
      expect(controller.progress, inExclusiveRange(0, 0.5));
      await gesture.up();
      await settle(tester);
      expect(controller.progress, 0);

      gesture = await holdScroll(tester, 75);
      expect(controller.progress, inExclusiveRange(0.5, 1));
      await gesture.up();
      await settle(tester);
      expect(controller.progress, 1);
    });

    testWidgets('snap: false leaves a partial collapse', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller, snap: false);
      final gesture = await holdScroll(tester, 30);
      final p = controller.progress;
      await gesture.up();
      await settle(tester);
      expect(controller.progress, closeTo(p, 0.001));
    });

    testWidgets('fling down docks and fling up opens', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      await tester.fling(find.byKey(feedKey), const Offset(0, -300), 2000);
      await settle(tester);
      expect(controller.progress, 1);
      await tester.fling(find.byKey(feedKey), const Offset(0, 600), 4000);
      await settle(tester);
      expect(controller.progress, 0);
    });

    testWidgets('docked avatars fly from their tray slots', (tester) async {
      final feed = ScrollController();
      addTearDown(feed.dispose);
      await pumpDock(tester, feedController: feed, snap: false);
      final tray = tester.getRect(
        find.byKey(const ValueKey<String>('story_dock_tray_1')),
      );
      // Avatar centre: 10 px top padding plus half the 68 px avatar.
      final avatarCenter = Offset(tray.center.dx, tray.top + 10 + 34);
      feed.jumpTo(1);
      await tester.pump();
      final start = tester.getCenter(slot(1));
      expect((start - avatarCenter + const Offset(0, 1)).distance, lessThan(1));
      feed.jumpTo(40);
      await tester.pump();
      final mid = tester.getCenter(slot(1));
      expect(mid.dy, lessThan(start.dy - 40), reason: 'arcs up');
      feed.jumpTo(300);
      await tester.pump();
      final end = tester.getCenter(slot(1));
      expect(end.dy, closeTo(26, 0.5)); // middle of the 52 px bar
      expect(tester.getSize(slot(1)).width, closeTo(28, 0.5));
      feed.jumpTo(0);
      await tester.pump();
      expect(slot(1), findsNothing);
    });

    testWidgets('controller expand and dock', (tester) async {
      final controller = StoryDockController();
      expect(controller.isAttached, isFalse);
      await controller.expand(); // no-op while detached
      await pumpDock(tester, controller: controller);
      expect(controller.isAttached, isTrue);
      await tester.drag(
        find.byKey(feedKey),
        const Offset(0, -1),
      ); // attach position
      await settle(tester);
      controller.dock();
      await settle(tester);
      expect(controller.progress, 1);
      controller.expand();
      await settle(tester);
      expect(controller.progress, 0);
      var notified = 0;
      controller.addListener(() => notified++);
      await dockIt(tester);
      expect(notified, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      expect(controller.isAttached, isFalse);
    });
  });

  group('story counts', () {
    testWidgets('no stories: no tray, no dock, feed still scrolls', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(tester, stories: const [], controller: controller);
      await dockIt(tester);
      expect(controller.progress, 0);
      expect(dock, findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final n in <int>[1, 3]) {
      testWidgets('$n stories fill $n dock slots and never rotate', (
        tester,
      ) async {
        await pumpDock(tester, stories: people(n));
        await dockIt(tester);
        for (var i = 0; i < n; i++) {
          expect(slot(i), findsOneWidget);
        }
        expect(slot(n), findsNothing);
        final before = slotText(tester, 0);
        await tester.pump(rotate * 3);
        expect(slotText(tester, 0), before);
      });
    }

    testWidgets('50 stories scroll in the tray', (tester) async {
      await pumpDock(tester, stories: people(50));
      expect(find.text('User 49'), findsNothing);
      await tester.dragUntilVisible(
        find.text('User 49'),
        find.byType(Scrollable).last, // the tray, inside the feed
        const Offset(-300, 0),
      );
      expect(find.text('User 49'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dock starts at the first visible tray story', (tester) async {
      await pumpDock(tester, stories: people(20));
      await tester.drag(
        find.byKey(const ValueKey<String>('story_dock_tray_0')),
        const Offset(-400, 0),
      );
      await settle(tester);
      await dockIt(tester);
      expect(slotText(tester, 0), 'U5');
    });

    testWidgets('stories can change at runtime', (tester) async {
      await pumpDock(tester, stories: people(10));
      await dockIt(tester);
      await tester.pump(rotate * 5); // base moves past index 2
      await pumpDock(tester, stories: people(2));
      await tester.pump();
      expect(slot(0), findsOneWidget);
      expect(slot(1), findsOneWidget);
      expect(slot(2), findsNothing);
      await pumpDock(tester, stories: const []);
      await tester.pump();
      expect(dock, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('rotation', () {
    testWidgets('docked faces rotate one place per period', (tester) async {
      await pumpDock(tester);
      await dockIt(tester);
      expect(slotText(tester, 0), 'U0');
      await advance(tester, rotate * 0.75); // mid move
      expect(slot(4), findsOneWidget); // the face coming in
      await advance(tester, rotate * 0.2);
      expect(slotText(tester, 0), 'U1');
      expect(slot(4), findsNothing);
      await advance(tester, rotate);
      expect(slotText(tester, 0), 'U2');
    });

    testWidgets('pauses while the dock is pressed', (tester) async {
      await pumpDock(tester);
      await dockIt(tester);
      final gesture = await tester.startGesture(tester.getCenter(dock));
      await tester.pump(rotate * 3);
      expect(slotText(tester, 0), 'U0');
      await gesture.cancel();
      await advance(tester, rotate * 1.05);
      expect(slotText(tester, 0), 'U1');
    });

    testWidgets('pauses while the app is hidden or paused', (tester) async {
      await pumpDock(tester);
      await dockIt(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await advance(tester, rotate);
      expect(slotText(tester, 0), 'U1', reason: 'inactive is still visible');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(rotate * 3);
      expect(slotText(tester, 0), 'U1');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance(tester, rotate * 1.05);
      expect(slotText(tester, 0), 'U2');
    });

    testWidgets('only rotates while fully docked', (tester) async {
      await pumpDock(tester, snap: false);
      final gesture = await holdScroll(tester, 40);
      await tester.pump(rotate * 3);
      expect(slotText(tester, 0), 'U0');
      await gesture.up();
      await settle(tester);
    });
  });

  group('taps', () {
    testWidgets('tray avatar reports its index', (tester) async {
      int? tapped;
      await pumpDock(tester, onStoryTap: (i) => tapped = i);
      await tester.tap(find.byKey(const ValueKey<String>('story_dock_tray_2')));
      expect(tapped, 2);
    });

    testWidgets('dock tap scrolls to the top by default', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      await dockIt(tester);
      await tester.tap(dock);
      await settle(tester);
      expect(controller.progress, 0);
      expect(find.text('User 0'), findsOneWidget);
    });

    testWidgets('custom onDockTap replaces the scroll', (tester) async {
      final controller = StoryDockController();
      var taps = 0;
      await pumpDock(tester, controller: controller, onDockTap: () => taps++);
      await dockIt(tester);
      await tester.tap(dock);
      await settle(tester);
      expect(taps, 1);
      expect(controller.progress, 1);
    });
  });

  group('layout', () {
    testWidgets('RTL mirrors the tray and the dock', (tester) async {
      final feed = ScrollController();
      addTearDown(feed.dispose);
      await pumpDock(
        tester,
        direction: TextDirection.rtl,
        feedController: feed,
        snap: false,
      );
      final first = tester.getCenter(
        find.byKey(const ValueKey<String>('story_dock_tray_0')),
      );
      expect(first.dx, greaterThan(200));
      feed.jumpTo(0.5);
      await tester.pump();
      expect(
        (tester.getCenter(slot(0)).dx - first.dx).abs(),
        lessThan(1),
        reason: 'flight starts from the mirrored tray slot',
      );
      feed.jumpTo(300);
      await tester.pump();
      expect(
        tester.getCenter(slot(0)).dx,
        greaterThan(tester.getCenter(slot(1)).dx),
      );
    });

    testWidgets('text scale 2.0 grows the tray without overflow', (
      tester,
    ) async {
      await pumpDock(tester);
      final normal = tester.getSize(
        find.byKey(const ValueKey<String>('story_dock_tray_0')),
      );
      await pumpDock(tester, textScale: 2);
      await tester.pump();
      final scaled = tester.getSize(
        find.byKey(const ValueKey<String>('story_dock_tray_0')),
      );
      expect(scaled.height, greaterThan(normal.height));
      await dockIt(tester);
      await pumpDock(tester, textScale: 2, variant: StoryDockVariant.stack);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a 320 px wide phone', (tester) async {
      for (final variant in StoryDockVariant.values) {
        await pumpDock(
          tester,
          variant: variant,
          size: const Size(320, 640),
          leading: const Icon(Icons.add),
          trailing: const Icon(Icons.favorite_border),
        );
        await dockIt(tester);
        final rect = tester.getRect(dock);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        await tester.drag(find.byKey(feedKey), const Offset(0, 2000));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('options', () {
    testWidgets('stack shows a +N count and overlaps faces', (tester) async {
      await pumpDock(tester, variant: StoryDockVariant.stack);
      await dockIt(tester);
      expect(find.text('+6'), findsOneWidget);
      final a = tester.getRect(slot(0));
      final b = tester.getRect(slot(1));
      expect(b.left, lessThan(a.right)); // overlap
      final capsuleCount = find.text('+6');
      await pumpDock(tester, variant: StoryDockVariant.capsule);
      await tester.pump();
      expect(capsuleCount, findsNothing);
    });

    testWidgets('dockCount sets the number of slots', (tester) async {
      await pumpDock(tester, dockCount: 2);
      await dockIt(tester);
      expect(slot(1), findsOneWidget);
      expect(slot(2), findsNothing);
    });

    testWidgets('actions and title fade unless kept', (tester) async {
      await pumpDock(
        tester,
        leading: const Text('lead'),
        trailing: const Text('trail'),
        title: const Text('title'),
      );
      expect(opacityAbove(tester, find.text('lead')), 1);
      await dockIt(tester);
      expect(opacityAbove(tester, find.text('lead')), 0);
      expect(opacityAbove(tester, find.text('trail')), 0);
      expect(find.text('title'), findsNothing); // scrolled away

      await pumpDock(
        tester,
        leading: const Text('lead'),
        hideActionsWhenDocked: false,
      );
      await tester.pump();
      expect(opacityAbove(tester, find.text('lead')), 1);
      expect(tester.getSize(slot(0)).width, closeTo(28, 0.5));
    });

    testWidgets('style sizes and glass options apply', (tester) async {
      await pumpDock(
        tester,
        style: const StoryDockStyle(
          trayAvatarSize: 56,
          trayItemExtent: 64,
          dockAvatarSize: 22,
          barHeight: 44,
          blurSigma: 0,
          barScrim: false,
          ringColor: Colors.red,
        ),
        hideActionsWhenDocked: false,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('story_dock_tray_0')))
            .width,
        64,
      );
      // Tray rings use ringColor (the stack recolours its own to separate).
      final ring = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('story_dock_tray_0')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      await dockIt(tester);
      expect(tester.getSize(slot(0)).width, closeTo(22, 0.5));
      expect(tester.getCenter(slot(0)).dy, closeTo(22, 0.5));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        ((ring.decoration as BoxDecoration).border! as Border).top.color,
        Colors.red,
      );
    });

    testWidgets('blur is on by default', (tester) async {
      await pumpDock(tester);
      await dockIt(tester);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('tray avatars and the dock are labelled buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDock(tester, stories: people(6, seenFrom: 4));
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('story_dock_tray_0')),
        ),
        matchesSemantics(
          label: "User 0's story, new",
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel("User 4's story, seen"), findsOneWidget);
      await dockIt(tester);
      expect(
        find.bySemanticsLabel('Stories, 6 accounts, 4 new'),
        findsOneWidget,
      );
      await pumpDock(tester, dockSemanticLabel: 'Open stories');
      await tester.pump();
      expect(find.bySemanticsLabel('Open stories'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keyboard: Tab to a story and press Enter', (tester) async {
      int? tapped;
      await pumpDock(tester, onStoryTap: (i) => tapped = i);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapped, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('keyboard: the stack dock opens the tray', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      await dockIt(tester);
      bool dockFocused() {
        final context = FocusManager.instance.primaryFocus?.context;
        var found = false;
        context?.visitAncestorElements((element) {
          found =
              element.widget.key == const ValueKey<String>('story_dock_dock');
          return !found;
        });
        return found;
      }

      for (var i = 0; i < 20 && !dockFocused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(dockFocused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(controller.progress, 0);
    });

    testWidgets('reduced motion: no flight, no rotation, instant snap', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller, reduceMotion: true);
      final gesture = await holdScroll(tester, 20);
      // Faces wait at the dock position and only fade.
      expect(tester.getCenter(slot(0)).dy, closeTo(26, 0.5));
      expect(opacityAbove(tester, find.text('U0').last), lessThan(1));
      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(controller.progress, 0);
      await dockIt(tester);
      await tester.pump(rotate * 3);
      expect(slotText(tester, 0), 'U0');
    });
  });

  group('capsule', () {
    const capsule = StoryDockVariant.capsule;
    Finder strip(int i) => find.byKey(ValueKey<String>('story_dock_strip_$i'));
    final stripList = find.byKey(const ValueKey<String>('story_dock_strip'));

    // Faces are laid out at 40 px and scaled; measure what is on screen.
    double faceWidth(WidgetTester tester, Finder face) =>
        tester.getRect(face).width;
    // The enlarged capsule: 46 px faces in 64.4 px slots (gap 0.4 of a
    // face) with 8.28 px insets. The compact one is the same, scaled 28/46.
    const unit = 46 * 1.4;
    const inset = 46 * 0.18;
    double expandedWidth(int n) => n * unit + 2 * inset;
    double compactWidth(int n) => expandedWidth(n) * 28 / 46;

    Future<void> showCapsule(WidgetTester tester) async {
      await dockIt(tester);
      await settle(tester, const Duration(milliseconds: 300));
    }

    Future<void> touchDock(WidgetTester tester) async {
      await tester.tap(dock);
      await settle(tester, const Duration(milliseconds: 400));
    }

    testWidgets('the tray scrolls away; no faces fly', (tester) async {
      final feed = ScrollController();
      addTearDown(feed.dispose);
      await pumpDock(tester, variant: capsule, feedController: feed);
      final tray = tester.getTopLeft(
        find.byKey(const ValueKey<String>('story_dock_tray_0')),
      );
      feed.jumpTo(40);
      await tester.pump();
      expect(slot(0), findsNothing);
      expect(dock, findsNothing);
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey<String>('story_dock_tray_0')),
        ),
        tray - const Offset(0, 40),
      );
    });

    testWidgets('appears once the tray is gone and never snaps', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(tester, variant: capsule, controller: controller);
      var gesture = await holdScroll(tester, 30);
      await gesture.up();
      await settle(tester);
      final p = controller.progress;
      expect(p, inExclusiveRange(0, 1), reason: 'feed rests where left');
      expect(dock, findsNothing);
      gesture = await holdScroll(tester, 200);
      await gesture.up();
      await settle(tester, const Duration(milliseconds: 300));
      expect(controller.progress, 1);
      expect(dock, findsOneWidget);
      expect(tester.getCenter(dock).dy, closeTo(26, 0.5));
      // Compact: the first four faces, 28 px each.
      for (var i = 0; i < 4; i++) {
        expect(strip(i), findsOneWidget);
        expect(faceWidth(tester, strip(i)), closeTo(28, 0.1));
      }
      expect(tester.getSize(dock).width, closeTo(compactWidth(4), 0.5));
    });

    testWidgets('never rotates on its own', (tester) async {
      await pumpDock(tester, variant: capsule);
      await showCapsule(tester);
      final before = tester.getTopLeft(strip(0));
      await tester.pump(rotate * 5);
      expect(tester.getTopLeft(strip(0)), before);
      final controller = tester.state<ScrollableState>(
        find.descendant(of: stripList, matching: find.byType(Scrollable)),
      );
      expect(controller.position.pixels, 0);
    });

    testWidgets('a touch enlarges it into a scrollable strip', (tester) async {
      int? opened;
      final controller = StoryDockController();
      await pumpDock(
        tester,
        variant: capsule,
        controller: controller,
        stories: people(12),
        leading: const Text('lead'),
        trailing: const Text('trail'),
        onStoryTap: (i) => opened = i,
      );
      await showCapsule(tester);
      expect(opacityAbove(tester, find.text('lead')), 1);
      final small = tester.getSize(dock);

      await touchDock(tester);
      expect(controller.isDockExpanded, isTrue);
      expect(opened, isNull, reason: 'the first touch only enlarges');
      final big = tester.getSize(dock);
      // A uniform scale of the compact capsule: still four faces wide.
      expect(big.width, closeTo(expandedWidth(4), 0.5));
      expect(big.width / small.width, closeTo(46 / 28, 0.01));
      expect(big.height / small.height, closeTo(46 / 28, 0.01));
      expect(faceWidth(tester, strip(0)), closeTo(46, 0.1));
      expect(opacityAbove(tester, find.text('lead')), 0);
      expect(opacityAbove(tester, find.text('trail')), 0);

      // Swipe sideways through every story.
      await tester.drag(dock, const Offset(-300, 0));
      await settle(tester);
      expect(strip(0).hitTestable(), findsNothing);
      expect(strip(8), findsOneWidget);
      await tester.tap(strip(8));
      expect(opened, 8);
    });

    testWidgets('a drag on the compact capsule scrolls at once and grows', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(
        tester,
        variant: capsule,
        controller: controller,
        stories: people(12),
      );
      await showCapsule(tester);
      final before = tester.getRect(strip(3)).left;
      final gesture = await tester.startGesture(tester.getCenter(dock));
      await gesture.moveBy(const Offset(-30, 0)); // past touch slop
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      // Growing has started and the faces already follow the finger.
      expect(controller.isDockExpanded, isTrue);
      final duringDrag = tester.getRect(strip(3)).left;
      expect(duringDrag, lessThan(before));
      // The same drag keeps scrolling while the capsule grows.
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(strip(3)).left, lessThan(duringDrag - 60));
      await gesture.up();
      await settle(tester, const Duration(milliseconds: 800));
      expect(faceWidth(tester, strip(5)), closeTo(46, 0.1));
      // It comes to rest on whole faces.
      final offset = tester
          .state<ScrollableState>(
            find.descendant(of: stripList, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;
      expect(offset % unit, anyOf(closeTo(0, 0.5), closeTo(unit, 0.5)));
    });

    testWidgets('borderless glass, with glass circles behind the actions', (
      tester,
    ) async {
      await pumpDock(
        tester,
        variant: capsule,
        leading: const Text('lead'),
        trailing: const Text('trail'),
      );
      await showCapsule(tester);
      final glass = tester.widget<DecoratedBox>(
        find.descendant(of: dock, matching: find.byType(DecoratedBox)).first,
      );
      expect((glass.decoration as BoxDecoration).border, isNull);
      // Capsule plus one circle behind each action.
      expect(find.byType(BackdropFilter), findsNWidgets(3));
      expect(find.byType(BackdropGroup), findsOneWidget);

      await pumpDock(
        tester,
        variant: capsule,
        leading: const Text('lead'),
        trailing: const Text('trail'),
        style: const StoryDockStyle(
          actionGlass: false,
          glassBorderColor: Colors.white,
        ),
      );
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
      final bordered = tester.widget<DecoratedBox>(
        find.descendant(of: dock, matching: find.byType(DecoratedBox)).first,
      );
      expect((bordered.decoration as BoxDecoration).border, isNotNull);
    });

    testWidgets('drops in from above with the actions, within the safe area', (
      tester,
    ) async {
      final feed = ScrollController();
      addTearDown(feed.dispose);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoryDock(
              stories: people(8),
              leading: const Text('lead'),
              builder: (context, tray) => ListView(
                controller: feed,
                children: <Widget>[tray, const SizedBox(height: 3000)],
              ),
            ),
          ),
        ),
      );
      // The tray starts below the status bar and the bar.
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey<String>('story_dock_tray_0')))
            .dy,
        47 + 52,
      );
      feed.jumpTo(400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final early = tester.getCenter(dock).dy;
      final leadEarly = tester.getCenter(find.text('lead')).dy;
      await settle(tester, const Duration(milliseconds: 300));
      final settled = tester.getCenter(dock).dy;
      expect(settled, closeTo(47 + 26, 0.5), reason: 'centred in the bar');
      expect(early, lessThan(settled), reason: 'slides down into place');
      expect(
        tester.getCenter(find.text('lead')).dy - leadEarly,
        closeTo(settled - early, 1),
        reason: 'the actions move with the capsule',
      );
    });

    testWidgets('scrolling the feed while docked does not rebuild the bar', (
      tester,
    ) async {
      final feed = ScrollController();
      addTearDown(feed.dispose);
      var builds = 0;
      await pumpDock(
        tester,
        variant: capsule,
        feedController: feed,
        title: Builder(
          builder: (context) {
            builds++;
            return const Text('title');
          },
        ),
      );
      final atRest = builds;
      feed.jumpTo(30);
      await tester.pump();
      expect(builds, greaterThan(atRest), reason: 'the header still moves');
      feed.jumpTo(400);
      await settle(tester, const Duration(milliseconds: 300));
      final docked = tester.widget<ListView>(stripList);
      for (var y = 410.0; y < 900; y += 30) {
        feed.jumpTo(y);
        await tester.pump();
      }
      expect(
        identical(tester.widget<ListView>(stripList), docked),
        isTrue,
        reason: 'the overlay was not rebuilt',
      );
    });

    testWidgets('stays enlarged while the feed scrolls, shrinks at the tray', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(tester, variant: capsule, controller: controller);
      await showCapsule(tester);
      await touchDock(tester);
      await tester.drag(find.byKey(feedKey), const Offset(0, -500));
      await settle(tester);
      expect(controller.isDockExpanded, isTrue);
      expect(dock, findsOneWidget);
      await tester.drag(find.byKey(feedKey), const Offset(0, 3000));
      await settle(tester);
      expect(controller.progress, 0);
      expect(controller.isDockExpanded, isFalse);
      expect(dock, findsNothing);
      await showCapsule(tester);
      expect(tester.getSize(dock).width, closeTo(compactWidth(4), 0.5));
    });

    testWidgets('shrinks around the faces the user scrolled to', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(
        tester,
        variant: capsule,
        controller: controller,
        stories: people(20),
      );
      await showCapsule(tester);
      await touchDock(tester);
      await tester.drag(dock, const Offset(-4 * unit, 0)); // four faces
      await settle(tester);
      controller.collapseDock();
      await settle(tester, const Duration(milliseconds: 400));
      expect(controller.isDockExpanded, isFalse);
      final left = tester.getRect(dock).left;
      // Inset plus the face's centring in its slot, at the compact scale.
      expect(
        tester.getRect(strip(4)).left,
        closeTo(left + (inset + (unit - 46) / 2) * 28 / 46, 1),
      );
    });

    testWidgets('collapseAfter shrinks it after the last touch', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(
        tester,
        variant: capsule,
        controller: controller,
        collapseAfter: const Duration(seconds: 2),
      );
      await showCapsule(tester);
      await touchDock(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isDockExpanded, isTrue);
      final gesture = await tester.startGesture(tester.getCenter(dock));
      await tester.pump(const Duration(seconds: 3)); // held: no timeout
      expect(controller.isDockExpanded, isTrue);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(controller.isDockExpanded, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester, const Duration(milliseconds: 300));
      expect(controller.isDockExpanded, isFalse);
    });

    testWidgets('controller expandDock and collapseDock', (tester) async {
      final controller = StoryDockController();
      var changes = 0;
      controller.addListener(() => changes++);
      await pumpDock(tester, variant: capsule, controller: controller);
      controller.expandDock(); // not shown yet: ignored
      await tester.pump();
      expect(controller.isDockExpanded, isFalse);
      await showCapsule(tester);
      controller.expandDock();
      await settle(tester, const Duration(milliseconds: 400));
      expect(controller.isDockExpanded, isTrue);
      controller.collapseDock();
      await settle(tester, const Duration(milliseconds: 400));
      expect(controller.isDockExpanded, isFalse);
      expect(changes, greaterThan(2));
    });

    testWidgets(
      'keyboard: Enter enlarges, Tab reaches a face, Escape shrinks',
      (tester) async {
        int? opened;
        final controller = StoryDockController();
        await pumpDock(
          tester,
          variant: capsule,
          controller: controller,
          onStoryTap: (i) => opened = i,
        );
        await showCapsule(tester);
        bool inDock() {
          final context = FocusManager.instance.primaryFocus?.context;
          var found = false;
          context?.visitAncestorElements((element) {
            found =
                element.widget.key == const ValueKey<String>('story_dock_dock');
            return !found;
          });
          return found;
        }

        for (var i = 0; i < 30 && !inDock(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(inDock(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, const Duration(milliseconds: 400));
        expect(controller.isDockExpanded, isTrue);
        for (var i = 0; i < 30 && !inDock(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(inDock(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester, const Duration(milliseconds: 400));
        expect(controller.isDockExpanded, isFalse);
      },
    );

    testWidgets('semantics: one button, then a button per face', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDock(tester, variant: capsule, stories: people(6, seenFrom: 2));
      await showCapsule(tester);
      expect(
        find.bySemanticsLabel('Stories, 6 accounts, 2 new'),
        findsOneWidget,
      );
      await touchDock(tester);
      expect(find.bySemanticsLabel('Stories, 6 accounts, 2 new'), findsNothing);
      expect(find.bySemanticsLabel("User 1's story, new"), findsWidgets);
      expect(find.bySemanticsLabel("User 2's story, seen"), findsWidgets);
      handle.dispose();
    });

    testWidgets('fewer stories than slots', (tester) async {
      for (final n in <int>[1, 3]) {
        await pumpDock(tester, variant: capsule, stories: people(n));
        await showCapsule(tester);
        expect(tester.getSize(dock).width, closeTo(compactWidth(n), 0.5));
        await touchDock(tester);
        // Only as wide as its faces, not the whole bar.
        expect(tester.getSize(dock).width, closeTo(expandedWidth(n), 0.5));
        await tester.drag(find.byKey(feedKey), const Offset(0, 3000));
        await settle(tester);
      }
      await pumpDock(tester, variant: capsule, stories: const []);
      await dockIt(tester);
      expect(dock, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL strip starts on the right', (tester) async {
      await pumpDock(tester, variant: capsule, direction: TextDirection.rtl);
      await showCapsule(tester);
      expect(
        tester.getCenter(strip(0)).dx,
        greaterThan(tester.getCenter(strip(1)).dx),
      );
      await touchDock(tester);
      expect(
        tester.getCenter(strip(0)).dx,
        greaterThan(tester.getCenter(strip(1)).dx),
      );
    });

    testWidgets('style and option sizes', (tester) async {
      await pumpDock(
        tester,
        variant: capsule,
        leading: const Text('lead'),
        hideActionsWhenDocked: false,
        style: const StoryDockStyle(
          dockAvatarSize: 24,
          expandedDockAvatarSize: 36,
          dockMargin: 10,
        ),
      );
      await showCapsule(tester);
      expect(faceWidth(tester, strip(0)), closeTo(24, 0.1));
      await touchDock(tester);
      expect(faceWidth(tester, strip(0)), closeTo(36, 0.1));
      expect(
        tester.getSize(dock).width,
        closeTo(4 * 36 * 1.4 + 2 * 36 * 0.18, 0.5),
      );
      expect(opacityAbove(tester, find.text('lead')), 1);
    });

    testWidgets('reduced motion: appears and enlarges without animating', (
      tester,
    ) async {
      final controller = StoryDockController();
      await pumpDock(
        tester,
        variant: capsule,
        controller: controller,
        reduceMotion: true,
      );
      await tester.drag(find.byKey(feedKey), const Offset(0, -400));
      await tester.pump();
      expect(opacityAbove(tester, strip(0)), 1);
      await tester.tap(dock);
      await tester.pump();
      expect(faceWidth(tester, strip(0)), closeTo(46, 0.1));
    });

    testWidgets('switching variant at runtime', (tester) async {
      await pumpDock(tester, variant: capsule);
      await showCapsule(tester);
      await touchDock(tester);
      await pumpDock(tester);
      await tester.pump();
      expect(stripList, findsNothing);
      expect(slot(0), findsOneWidget);
      await pumpDock(tester, variant: capsule);
      await tester.pump();
      expect(tester.getSize(dock).width, closeTo(compactWidth(4), 0.5));
    });

    testWidgets('dispose while enlarging', (tester) async {
      await pumpDock(
        tester,
        variant: capsule,
        collapseAfter: const Duration(seconds: 1),
      );
      await showCapsule(tester);
      await tester.tap(dock);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('themes', () {
    for (final brightness in Brightness.values) {
      for (final variant in StoryDockVariant.values) {
        testWidgets('golden ${variant.name} ${brightness.name}', (
          tester,
        ) async {
          final feed = ScrollController();
          addTearDown(feed.dispose);
          await pumpDock(
            tester,
            variant: variant,
            brightness: brightness,
            size: const Size(390, 300),
            leading: const Icon(Icons.add),
            title: const Text('Feed'),
            trailing: const Icon(Icons.favorite_border),
            stories: people(9, seenFrom: 6),
            feedController: feed,
            snap: false,
          );
          await expectLater(
            find.byType(StoryDock),
            matchesGoldenFile(
              'goldens/${variant.name}_open_${brightness.name}.png',
            ),
          );
          feed.jumpTo(45);
          await tester.pump();
          await expectLater(
            find.byType(StoryDock),
            matchesGoldenFile(
              'goldens/${variant.name}_mid_${brightness.name}.png',
            ),
          );
          feed.jumpTo(400);
          await settle(tester, const Duration(milliseconds: 300));
          await expectLater(
            find.byType(StoryDock),
            matchesGoldenFile(
              'goldens/${variant.name}_docked_${brightness.name}.png',
            ),
          );
          if (variant == StoryDockVariant.capsule) {
            await tester.tap(dock);
            await settle(tester, const Duration(milliseconds: 400));
            await expectLater(
              find.byType(StoryDock),
              matchesGoldenFile(
                'goldens/capsule_expanded_${brightness.name}.png',
              ),
            );
          }
        });
      }
    }
  });

  group('lifecycle', () {
    testWidgets('dispose while rotating leaves nothing running', (
      tester,
    ) async {
      await pumpDock(tester);
      await dockIt(tester);
      await tester.pump(rotate * 0.8); // mid move
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose during a snap animation', (tester) async {
      await pumpDock(tester);
      final gesture = await holdScroll(tester, 70);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hot reload keeps the docked state', (tester) async {
      final controller = StoryDockController();
      await pumpDock(tester, controller: controller);
      await dockIt(tester);
      tester.binding.reassembleApplication();
      await tester.pump();
      expect(controller.progress, 1);
      expect(dock, findsOneWidget);
    });

    testWidgets('swapping the controller re-attaches', (tester) async {
      final a = StoryDockController();
      final b = StoryDockController();
      await pumpDock(tester, controller: a);
      await dockIt(tester);
      await pumpDock(tester, controller: b);
      await tester.pump();
      expect(a.isAttached, isFalse);
      expect(b.isAttached, isTrue);
      expect(b.progress, 1);
    });
  });
}
