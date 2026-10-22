import 'package:ar_gallery/app_shell.dart';
import 'package:ar_gallery/core/onboarding.dart';
import 'package:ar_gallery/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<List<bool>> pumpShell(WidgetTester tester, OnboardingStore store) async {
    final activeStates = <bool>[];
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AppShell(
        onboarding: store,
        scanBuilder: (active, _) {
          activeStates.add(active);
          return Center(child: Text(active ? 'camera on' : 'camera paused'));
        },
      ),
    ));
    await tester.pump();
    return activeStates;
  }

  testWidgets('first launch opens on the tutorial with the camera paused',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await OnboardingStore.load();
    final active = await pumpShell(tester, store);

    expect(find.text('How ARise Works'), findsOneWidget);
    expect(active.last, isFalse);
  });

  testWidgets('switching to Scan starts the camera and remembers the tutorial',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await OnboardingStore.load();
    final active = await pumpShell(tester, store);

    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();

    expect(active.last, isTrue);
    expect(find.text('camera on'), findsOneWidget);
    expect(store.tutorialSeen, isTrue);
  });

  testWidgets('later launches go straight to Scan', (tester) async {
    SharedPreferences.setMockInitialValues({'tutorial_seen': true});
    final store = await OnboardingStore.load();
    final active = await pumpShell(tester, store);

    expect(active.last, isTrue);
    expect(find.text('camera on'), findsOneWidget);
  });

  testWidgets('"Try First Scan Now" switches to the Scan tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await OnboardingStore.load();
    final active = await pumpShell(tester, store);

    final cta = find.text('Try First Scan Now');
    await tester.scrollUntilVisible(cta, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(active.last, isTrue);
  });
}
