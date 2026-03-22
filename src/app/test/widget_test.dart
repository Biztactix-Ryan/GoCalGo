import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: GoCalGoApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('GoCalGo'), findsOneWidget);
    expect(find.text("What's boosted today?"), findsOneWidget);
  });
}
