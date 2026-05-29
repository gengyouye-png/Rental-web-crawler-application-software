// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:rent_app/main.dart';

void main() {
  testWidgets('Rent dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(const RentCrawlerApp());

    expect(find.text('租屋搜尋儀表板'), findsOneWidget);
    expect(find.text('搜尋與爬蟲'), findsOneWidget);
  });
}
