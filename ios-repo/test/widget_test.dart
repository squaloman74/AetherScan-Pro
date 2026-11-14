import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/main.dart';

void main() {
  testWidgets('AetherScan Pro App load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AetherScanProApp());
    expect(find.byType(AetherScanProApp), findsOneWidget);
    expect(find.byType(IndustrialMetrologyScreen), findsOneWidget);
    expect(find.text('AETHERSCAN-PRO'), findsOneWidget);

    // Disaccoppia pulitamente
    await tester.pumpWidget(const Placeholder());
    await tester.pump();
  });
}
