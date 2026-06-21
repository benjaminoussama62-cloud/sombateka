import 'package:flutter_test/flutter_test.dart';
import 'package:sombateka/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SombaTekaApp());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SombaTeka'), findsWidgets);
    // Flush splash timers (Future.delayed chain) before the harness tears down.
    await tester.pump(const Duration(seconds: 4));
  });
}
