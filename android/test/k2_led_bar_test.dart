import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/k2_led_bar.dart';
import 'package:aetherscan_pro/k2_controller.dart';
import 'package:aetherscan_pro/baseline_engine.dart';

void main() {
  group('K2LedBarWidget — Test Logica Fisica dei 5 Segmenti', () {
    test('Delta = 0.0 µT -> 1 solo LED attivo (NORM verde, spia accesa a riposo)', () {
      const widget = K2LedBarWidget(
        currentEmf: 42.0,
        deltaEmf: 0.0,
        zScore: 0.0,
      );
      expect(widget.activeLedCount, equals(1));
    });

    test('Delta = 1.0 µT (<1.5) -> 1 solo LED attivo (NORM)', () {
      const widget = K2LedBarWidget(
        currentEmf: 43.0,
        deltaEmf: 1.0,
        zScore: 0.5,
      );
      expect(widget.activeLedCount, equals(1));
    });

    test('Delta = 1.5 µT (soglia esatta LOW) -> 2 LED attivi (NORM + LOW)', () {
      const widget = K2LedBarWidget(
        currentEmf: 43.5,
        deltaEmf: 1.5,
        zScore: 0.75,
      );
      expect(widget.activeLedCount, equals(2));
    });

    test('Delta = 2.4 µT (<2.5) -> 2 LED attivi', () {
      const widget = K2LedBarWidget(
        currentEmf: 44.4,
        deltaEmf: 2.4,
        zScore: 1.2,
      );
      expect(widget.activeLedCount, equals(2));
    });

    test('Delta = 2.5 µT (soglia esatta MID) -> 3 LED attivi (NORM + LOW + MID)', () {
      const widget = K2LedBarWidget(
        currentEmf: 44.5,
        deltaEmf: 2.5,
        zScore: 1.25,
      );
      expect(widget.activeLedCount, equals(3));
    });

    test('Delta = 9.9 µT (<10.0) -> 3 LED attivi', () {
      const widget = K2LedBarWidget(
        currentEmf: 51.9,
        deltaEmf: 9.9,
        zScore: 4.95,
      );
      expect(widget.activeLedCount, equals(3));
    });

    test('Delta = 10.0 µT (soglia esatta HIGH) -> 4 LED attivi (NORM + LOW + MID + HIGH)', () {
      const widget = K2LedBarWidget(
        currentEmf: 52.0,
        deltaEmf: 10.0,
        zScore: 5.0,
      );
      expect(widget.activeLedCount, equals(4));
    });

    test('Delta = 19.9 µT (<20.0) -> 4 LED attivi', () {
      const widget = K2LedBarWidget(
        currentEmf: 61.9,
        deltaEmf: 19.9,
        zScore: 9.95,
      );
      expect(widget.activeLedCount, equals(4));
    });

    test('Delta = 20.0 µT (soglia esatta MAX) -> 5 LED attivi (tutti accesi, incluso ROSSO)', () {
      const widget = K2LedBarWidget(
        currentEmf: 62.0,
        deltaEmf: 20.0,
        zScore: 10.0,
      );
      expect(widget.activeLedCount, equals(5));
    });

    test('Delta = 65.0 µT (forte saturazione) -> 5 LED attivi', () {
      const widget = K2LedBarWidget(
        currentEmf: 107.0,
        deltaEmf: 65.0,
        zScore: 32.5,
      );
      expect(widget.activeLedCount, equals(5));
    });

    test('Delta negativo -3.5 µT -> deviazione assoluta scatta a 3 LED (MID)', () {
      const widget = K2LedBarWidget(
        currentEmf: 38.5,
        deltaEmf: -3.5,
        zScore: -1.75,
      );
      expect(widget.activeLedCount, equals(3));
    });

    test('Delta negativo -22.0 µT -> deviazione assoluta scatta a 5 LED (MAX)', () {
      const widget = K2LedBarWidget(
        currentEmf: 20.0,
        deltaEmf: -22.0,
        zScore: -11.0,
      );
      expect(widget.activeLedCount, equals(5));
    });
  });

  group('K2LedBarWidget — Test Rendering UI e Interazione', () {
    testWidgets('Mostra titolo K2 FIELD METER e valore EMF con Delta', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: K2LedBarWidget(
              currentEmf: 44.2,
              deltaEmf: 2.1,
              zScore: 1.05,
            ),
          ),
        ),
      );

      expect(find.text('K2 FIELD METER'), findsOneWidget);
      expect(find.text('44.2 µT (Δ +2.1)'), findsOneWidget);
      expect(find.text('NORM'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('MID'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
    });

    testWidgets('Pulsante TARA invoca la callback quando premuto', (WidgetTester tester) async {
      bool tareCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: K2LedBarWidget(
              currentEmf: 50.0,
              deltaEmf: 8.0,
              zScore: 4.0,
              onQuickTare: () {
                tareCalled = true;
              },
            ),
          ),
        ),
      );

      final tareButton = find.text('TARA');
      expect(tareButton, findsOneWidget);

      await tester.tap(tareButton);
      await tester.pump();

      expect(tareCalled, isTrue);
    });

    testWidgets('Senza callback onQuickTare, non mostra il pulsante TARA', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: K2LedBarWidget(
              currentEmf: 42.0,
              deltaEmf: 0.0,
              zScore: 0.0,
              onQuickTare: null,
            ),
          ),
        ),
      );

      expect(find.text('TARA'), findsNothing);
    });
  });

  group('K2 & Baseline Integration Lifecycle', () {
    test('Tara iniziale su BaselineEngine crea profilo valido immediato per K2', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      expect(engine.isCalibrated, isFalse);
      expect(engine.activeProfile, isNull);

      final profile = engine.applyQuickTare(44.8, defaultStdDev: 2.0);

      expect(engine.isCalibrated, isTrue);
      expect(engine.activeProfile, isNotNull);
      expect(profile.emfMean, closeTo(44.8, 0.001));

      // Simuliamo calcolo delta per K2
      final currentEmf = 50.0;
      final delta = currentEmf - engine.activeProfile!.emfMean;
      expect(delta, closeTo(5.2, 0.001));

      final widget = K2LedBarWidget(
        currentEmf: currentEmf,
        deltaEmf: delta,
        zScore: delta / profile.emfStdDev,
      );
      // Delta 5.2 µT ricade nella fascia MID (2.5 - 10 µT) -> 3 LED
      expect(widget.activeLedCount, equals(3));
    });

    testWidgets('K2LedBarWidget.modular in standby mostra stato OFF e 0 LED, e si attiva al toggle', (tester) async {
      final ctrl = K2Controller(initiallyActive: false);
      ctrl.ingestRawEmf(42.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: K2LedBarWidget.modular(
              controller: ctrl,
            ),
          ),
        ),
      );

      expect(find.text('42.0 µT [STANDBY]'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);

      // Tocca il pulsante di accensione
      await tester.tap(find.text('OFF'));
      await tester.pump();

      expect(ctrl.isActive, isTrue);
      expect(find.text('ON'), findsOneWidget);
      expect(find.text('42.0 µT (Δ +0.0)'), findsOneWidget);
      expect(find.text('NORM'), findsOneWidget);
    });

    testWidgets('K2LedBarWidget.modular reagisce istantaneamente agli aggiornamenti di K2Controller', (tester) async {
      final ctrl = K2Controller(initiallyActive: true);
      ctrl.ingestRawEmf(45.0); // prima lettura fisica fissa baseline a 45.0 µT

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: K2LedBarWidget.modular(
              controller: ctrl,
            ),
          ),
        ),
      );

      // Inizialmente 45.0 µT e delta 0.0 -> 1 LED (NORM)
      expect(find.text('45.0 µT (Δ +0.0)'), findsOneWidget);
      expect(find.text('NORM'), findsOneWidget);

      // Simula avvicinamento a sorgente magnetica -> 60.0 µT (delta +15.0 -> HIGH, 4 LED)
      ctrl.ingestRawEmf(60.0);
      await tester.pump();

      expect(find.text('60.0 µT (Δ +15.0)'), findsOneWidget);

      // Simula tara rapida -> nuovo zero a 60.0 µT (delta +0.0 -> NORM, 1 LED)
      ctrl.tare();
      await tester.pump();

      expect(find.text('60.0 µT (Δ +0.0)'), findsOneWidget);
    });
  });
}
