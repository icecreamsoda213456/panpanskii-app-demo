import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/core/demo/demo_chrome.dart';
import 'package:panpanskii_app/core/presentation/pan_ui.dart';

void main() {
  testWidgets('initial web focus does not measure an unlaid navigator',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
              body: TextButton(onPressed: () {}, child: const Text('Open'))),
          builder: (context, child) =>
              DemoChrome(onReset: () async {}, child: child!),
        ),
        phase: EnginePhase.build);
    tester.binding.handleViewFocusChanged(ViewFocusEvent(
      viewId: tester.view.viewId,
      state: ViewFocusState.focused,
      direction: ViewFocusDirection.forward,
    ));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading sliver does not request skeleton intrinsic dimensions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: CustomScrollView(slivers: [PanLoadingSliver()]),
    )));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
        'demo toolbar is accessible and reset requires confirmation at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      var resets = 0;
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(body: Text('Demo content')),
        builder: (context, child) => DemoChrome(
            onReset: () async {
              resets++;
            },
            child: child!),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Reset demo data'), findsOneWidget);
      await tester.tap(find.byTooltip('Reset demo data'));
      await tester.pump();
      expect(resets, 0);
      await tester.tap(find.byTooltip('Cancel reset'));
      await tester.pump();
      expect(resets, 0);
      await tester.tap(find.byTooltip('Reset demo data'));
      await tester.pump();
      await tester.tap(find.byTooltip('Confirm reset'));
      await tester.pumpAndSettle();
      expect(resets, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
