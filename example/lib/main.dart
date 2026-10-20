import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:story_dock/story_dock.dart';

void main() => runApp(const StoryDockExample());

const List<StoryDockItem> _stories = <StoryDockItem>[
  StoryDockItem(label: 'Ava Reyes'),
  StoryDockItem(label: 'Milo Kent'),
  StoryDockItem(label: 'June Park'),
  StoryDockItem(label: 'Priya Lal'),
  StoryDockItem(label: 'Rafa Vega'),
  StoryDockItem(label: 'Noor Elias'),
  StoryDockItem(label: 'Theo Ortiz'),
  StoryDockItem(label: 'Kai Adler', seen: true),
  StoryDockItem(label: 'Dina Young', seen: true),
  StoryDockItem(label: 'Sami Bose', seen: true),
  StoryDockItem(label: 'Lena Fox', seen: true),
  StoryDockItem(label: 'Omar Haddad', seen: true),
];

const List<Color> _postColors = <Color>[
  Color(0xFF2E2A5C),
  Color(0xFF0E4F43),
  Color(0xFF6B2E1A),
  Color(0xFF3A3A36),
  Color(0xFF173E66),
  Color(0xFF5A2140),
];

class StoryDockExample extends StatefulWidget {
  const StoryDockExample({super.key});

  @override
  State<StoryDockExample> createState() => _StoryDockExampleState();
}

class _StoryDockExampleState extends State<StoryDockExample> {
  StoryDockVariant _variant = StoryDockVariant.capsule;
  ThemeMode _mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Story Dock',
      debugShowCheckedModeBanner: false,
      // Lets a mouse drag the feed too, like a finger (handy on web).
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      themeMode: _mode,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE8503A)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFE8503A),
        brightness: Brightness.dark,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: StoryDock(
            stories: _stories,
            variant: _variant,
            leading: IconButton(
              tooltip: 'New post',
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
            title: Text(
              'Feedly',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              tooltip: 'Switch theme',
              icon: Icon(
                _mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () => setState(
                () => _mode = _mode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            ),
            onStoryTap: (index) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('Open ${_stories[index].label}')),
              ),
            builder: (context, tray) => ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: 13,
              itemBuilder: (context, index) =>
                  index == 0 ? tray : _Post(index: index - 1),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: SegmentedButton<StoryDockVariant>(
            segments: const <ButtonSegment<StoryDockVariant>>[
              ButtonSegment(
                value: StoryDockVariant.capsule,
                label: Text('Capsule'),
              ),
              ButtonSegment(
                value: StoryDockVariant.stack,
                label: Text('Stack'),
              ),
            ],
            selected: <StoryDockVariant>{_variant},
            onSelectionChanged: (value) =>
                setState(() => _variant = value.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final story = _stories[index % _stories.length];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              story.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _postColors[index % _postColors.length],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: scheme.surface.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
