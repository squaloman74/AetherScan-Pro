import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/industrial_ui.dart';

void main() {
  group('Industrial UI Widgets Tests', () {
    testWidgets('IndustrialTelemetryCard renders labels and values correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndustrialTelemetryCard(
              label: 'EMF Modulo',
              value: '48.25',
              unit: 'µT',
              delta: 'Δ +6.15 µT (Z=3.1)',
            ),
          ),
        ),
      );

      expect(find.text('EMF MODULO'), findsOneWidget);
      expect(find.text('48.25'), findsOneWidget);
      expect(find.text('µT'), findsOneWidget);
      expect(find.text('Δ +6.15 µT (Z=3.1)'), findsOneWidget);
    });

    testWidgets('CalibrationOverlayWidget renders countdown, progress and instructions', (tester) async {
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalibrationOverlayWidget(
              progress: 0.5,
              remainingSeconds: 15,
              sampleCount: 1500,
              onCancel: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('CALIBRAZIONE BASELINE'), findsOneWidget);
      expect(find.text('15s'), findsOneWidget);
      expect(find.text('Campioni acquisiti: 1500 | Algoritmo di Welford'), findsOneWidget);

      await tester.tap(find.text('ANNULLA CALIBRAZIONE'));
      expect(cancelTapped, isTrue);
    });

    testWidgets('IndustrialSpectrumPainter and IndustrialOscilloscopePainter render without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 300,
                  height: 100,
                  child: CustomPaint(
                    painter: IndustrialOscilloscopePainter(
                      history: [40.0, 42.0, 45.0, 50.0, 41.0],
                      baselineMean: 40.0,
                      baselineStdDev: 2.0,
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  height: 100,
                  child: CustomPaint(
                    painter: IndustrialSpectrumPainter(
                      magnitudesDbfs: [-80.0, -60.0, -30.0, -15.0, -70.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
    });
  });
}
