import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/features/home/presentation/screens/home_screen.dart';
import 'package:panpanskii_app/features/home/presentation/screens/more_screen.dart';
import 'package:panpanskii_app/features/home/presentation/widgets/home_dashboard_cards.dart';
import 'package:panpanskii_app/features/home/presentation/widgets/home_ui_kit.dart';

Widget _wrap(Widget child, {Size size = const Size(360, 800)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: size.width, child: child),
      ),
    ),
  );
}

void main() {
  group('HomeCardGrid', () {
    testWidgets('gives every tile in a row the same size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeCardGrid(
            columns: 2,
            tileHeight: 100,
            children: [
              for (var index = 0; index < 4; index += 1)
                ColoredBox(key: ValueKey(index), color: Colors.red),
            ],
          ),
        ),
      );

      final sizes = [
        for (var index = 0; index < 4; index += 1)
          tester.getSize(find.byKey(ValueKey(index))),
      ];

      expect(sizes.every((size) => size.height == 100), isTrue);
      expect(sizes.map((size) => size.width).toSet().length, 1);
    });

    testWidgets('stretches a trailing odd tile across the last row',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeCardGrid(
            columns: 2,
            tileHeight: 100,
            stretchLastRow: true,
            children: [
              for (var index = 0; index < 5; index += 1)
                ColoredBox(key: ValueKey(index), color: Colors.red),
            ],
          ),
        ),
      );

      final firstWidth = tester.getSize(find.byKey(const ValueKey(0))).width;
      final lastWidth = tester.getSize(find.byKey(const ValueKey(4))).width;

      // The fifth tile owns the whole row instead of leaving a hole.
      expect(lastWidth, greaterThan(firstWidth * 1.9));
    });

    testWidgets('leaves an empty slot when stretchLastRow is off',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeCardGrid(
            columns: 2,
            tileHeight: 100,
            children: [
              for (var index = 0; index < 3; index += 1)
                ColoredBox(key: ValueKey(index), color: Colors.red),
            ],
          ),
        ),
      );

      final firstWidth = tester.getSize(find.byKey(const ValueKey(0))).width;
      final lastWidth = tester.getSize(find.byKey(const ValueKey(2))).width;

      expect(lastWidth, firstWidth);
    });

    testWidgets('never shrinks a tile below the minimum tap target',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeCardGrid(
            columns: 1,
            tileHeight: 10,
            children: const [ColoredBox(key: ValueKey(0), color: Colors.red)],
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey(0))).height,
        kHomeMinTapTarget,
      );
    });
  });

  group('homeGridColumns', () {
    testWidgets('drops to one column on a very narrow layout', (tester) async {
      late int narrow;
      late int wide;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              narrow = homeGridColumns(
                context: context,
                width: 200,
                minTileWidth: 150,
                maxColumns: 2,
              );
              wide = homeGridColumns(
                context: context,
                width: 360,
                minTileWidth: 150,
                maxColumns: 2,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(narrow, 1);
      expect(wide, 2);
    });

    testWidgets('keeps two columns at a moderate text scale', (tester) async {
      late int columns;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                columns = homeGridColumns(
                  context: context,
                  width: 336,
                  minTileWidth: 150,
                  maxColumns: 2,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(columns, 2);
    });
  });

  group('Home cards', () {
    testWidgets('TodayTogetherCard exposes one merged button semantics node',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 120,
            child: TodayTogetherCard(
              title: 'Cozy Garden',
              subtitle: 'Visit the shared garden',
              icon: Icons.local_florist_outlined,
              accent: Colors.green,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Cozy Garden. Visit the shared garden'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('TodayTogetherCard reports a tap', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 120,
            child: TodayTogetherCard(
              title: 'Daily Duo',
              subtitle: "Open today's round",
              icon: Icons.favorite_outline_rounded,
              accent: Colors.pink,
              onTap: () => taps += 1,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TodayTogetherCard));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('HomeFeatureCard keeps its label readable at a large scale',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SizedBox(
                  width: 160,
                  height: HomeFeatureCard.heightFor(context),
                  child: HomeFeatureCard(
                    label: 'Write Your Thoughts',
                    icon: Icons.edit_note_rounded,
                    accent: Colors.purple,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Write Your Thoughts'), findsOneWidget);
    });

    testWidgets('card heights grow with the text scale', (tester) async {
      late double normal;
      late double large;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              normal = HomeFeatureCard.heightFor(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                large = HomeFeatureCard.heightFor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(large, greaterThan(normal));
    });

    testWidgets('HomeSectionHeader renders its title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeSectionHeader(
            title: 'Today Together',
            icon: Icons.wb_twilight_outlined,
          ),
        ),
      );

      expect(find.text('Today Together'), findsOneWidget);
    });
  });

  group('Home routes', () {
    test('every dashboard card points at a rooted route', () {
      final routes = <String>[
        ...HomeDashboardTestAccess.todayTogetherRoutes.values,
        ...HomeDashboardTestAccess.quickActionRoutes.values,
      ];

      expect(routes, isNotEmpty);
      expect(routes.every((route) => route.startsWith('/')), isTrue);
    });

    test('Today Together keeps its five entries with distinct routes', () {
      final routes = HomeDashboardTestAccess.todayTogetherRoutes;

      expect(routes.length, 5);
      expect(routes.values.toSet().length, 5);
      expect(routes['Cozy Garden'], '/cozy-garden');
    });

    test('Quick Actions keeps the four most used shortcuts', () {
      final routes = HomeDashboardTestAccess.quickActionRoutes;

      expect(routes.keys.toList(), [
        'Private Chat',
        'Send Love',
        'Photo Booth',
        'Shared Journal',
      ]);
    });

    test('Home never lists the same card twice', () {
      final labels = [
        ...HomeDashboardTestAccess.todayTogetherRoutes.keys,
        ...HomeDashboardTestAccess.quickActionRoutes.keys,
      ];

      expect(labels.toSet().length, labels.length);
    });
  });

  group('Home and More split the app between them', () {
    test('the More tab never repeats a card Home already shows', () {
      final more = MoreScreenTestAccess.routes.keys.toSet();

      expect(more, isNotEmpty);
      expect(more.intersection(HomeDashboardTestAccess.homeLabels), isEmpty);
    });

    test('the More tab never repeats a route Home already opens', () {
      final homeRoutes = {
        ...HomeDashboardTestAccess.todayTogetherRoutes.values,
        ...HomeDashboardTestAccess.quickActionRoutes.values,
      };
      final moreRoutes = MoreScreenTestAccess.routes.values;

      expect(moreRoutes.toSet().intersection(homeRoutes), isEmpty);
    });

    test('every More tile points at a rooted route, and only once', () {
      final routes = MoreScreenTestAccess.routes.values.toList();

      expect(routes.every((route) => route.startsWith('/')), isTrue);
      expect(routes.toSet().length, routes.length);
    });
  });

  group('Home copy', () {
    test('the mascot notes keep their exact wording', () {
      expect(kHomePandaMessage, contains('cutiepatottie majoyskii'));
      expect(kHomeKoalaMessage, contains('clingy koala'));
    });
  });
}
