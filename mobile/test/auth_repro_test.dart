import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sombateka/screens/auth_screen.dart';

void main() {
  testWidgets('auth screen desktop renders form panel', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final errors = tester.takeException();
    expect(errors, isNull);

    // Le panneau formulaire doit exister — écran tout navy = régression.
    expect(find.text('ADRESSE EMAIL'), findsWidgets);
  });

  testWidgets('auth screen mobile renders form panel', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('ADRESSE EMAIL'), findsWidgets);
  });

  testWidgets('auth screen narrow desktop ~1100px renders', (tester) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('ADRESSE EMAIL'), findsWidgets);
  });
}
