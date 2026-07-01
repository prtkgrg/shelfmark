import 'package:flutter_test/flutter_test.dart';

import 'package:shelfmark/main.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const ShelfmarkApp());
    expect(find.text('Shelfmark'), findsOneWidget);
  });
}
