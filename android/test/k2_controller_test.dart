import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/k2_controller.dart';

void main() {
  group('K2Controller — Test Modulo Indipendente K2', () {
    test('Inizializzazione con baseline predefinita', () {
      final ctrl = K2Controller(initialBaseline: 42.0);
      expect(ctrl.currentEmf, equals(42.0));
      expect(ctrl.baselineEmf, equals(42.0));
      expect(ctrl.deltaEmf, equals(0.0));
      expect(ctrl.activeLedCount, equals(1)); // 1 LED verde NORM
      expect(ctrl.isAutoTared, isFalse);
    });

    test('Prima ingestione fa auto-tara trasparente sul valore reale del sensore', () {
      final ctrl = K2Controller(initialBaseline: 42.0);
      ctrl.ingestRawEmf(48.5);

      expect(ctrl.currentEmf, equals(48.5));
      expect(ctrl.baselineEmf, equals(48.5));
      expect(ctrl.deltaEmf, equals(0.0));
      expect(ctrl.activeLedCount, equals(1)); // NORM
      expect(ctrl.isAutoTared, isTrue);
    });

    test('Reattività a variazioni progressive (5 soglie fisiche dei LED)', () {
      final ctrl = K2Controller();
      ctrl.ingestRawEmf(40.0); // fissa baseline a 40.0 µT

      // 1. Delta < 1.5 -> LED 1 (NORM)
      ctrl.ingestRawEmf(41.0); // delta = +1.0
      expect(ctrl.activeLedCount, equals(1));

      // 2. Delta 1.5 - 2.5 -> LED 2 (LOW)
      ctrl.ingestRawEmf(41.8); // delta = +1.8
      expect(ctrl.activeLedCount, equals(2));

      // 3. Delta 2.5 - 10.0 -> LED 3 (MID)
      ctrl.ingestRawEmf(46.0); // delta = +6.0
      expect(ctrl.activeLedCount, equals(3));

      // 4. Delta 10.0 - 20.0 -> LED 4 (HIGH)
      ctrl.ingestRawEmf(55.0); // delta = +15.0
      expect(ctrl.activeLedCount, equals(4));

      // 5. Delta >= 20.0 -> LED 5 (MAX rosso)
      ctrl.ingestRawEmf(65.0); // delta = +25.0
      expect(ctrl.activeLedCount, equals(5));
    });

    test('Deviazione assoluta gestisce correttamente campi negativi dopo una tara alta', () {
      final ctrl = K2Controller();
      ctrl.ingestRawEmf(60.0); // fissa baseline a 60.0 µT
      ctrl.ingestRawEmf(35.0); // delta = -25.0 µT

      expect(ctrl.deltaEmf, equals(-25.0));
      expect(ctrl.activeLedCount, equals(5)); // MAX
    });

    test('Comando manuale tara fissa il nuovo zero sul valore attuale', () {
      final ctrl = K2Controller();
      ctrl.ingestRawEmf(45.0);
      ctrl.ingestRawEmf(70.0); // picco
      expect(ctrl.deltaEmf, equals(25.0));
      expect(ctrl.activeLedCount, equals(5));

      ctrl.tare(); // azzera sul valore corrente (70.0)
      expect(ctrl.baselineEmf, equals(70.0));
      expect(ctrl.deltaEmf, equals(0.0));
      expect(ctrl.activeLedCount, equals(1)); // torna su NORM
    });

    test('Notifica i listener su ogni ingestione e tara', () {
      final ctrl = K2Controller();
      int notifyCount = 0;
      ctrl.addListener(() => notifyCount++);

      ctrl.ingestRawEmf(45.0);
      ctrl.ingestRawEmf(46.0);
      ctrl.tare();

      expect(notifyCount, equals(3));
    });
  });
}
