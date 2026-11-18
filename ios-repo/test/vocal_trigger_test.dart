import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/vocal_trigger_engine.dart';

void main() {
  group('VocalTriggerEngine — Test di Isolamento e Risonanza Deterministica', () {
    late VocalTriggerEngine engine;

    setUp(() {
      engine = VocalTriggerEngine(
        isEnabled: false, // Spento di default
        zScoreThreshold: 3.0,
        minDeltaEmf: 1.5,
        minPersistenceMs: 150,
        cooldownMs: 7000,
      );
    });

    test('Isolamento Totale: se disabilitato non genera MAI parole anche con forti anomalie', () {
      final now = DateTime.now();
      expect(engine.isEnabled, isFalse);

      final event = engine.evaluate(
        now: now,
        deltaEmf: 15.0,
        zScoreEmf: 5.2,
        dynamicAccel: 2.5,
        lorenzX: 12.3,
        currentFrequency: 104.5,
      );

      expect(event, isNull);
      expect(engine.lastTriggeredEvent, isNull);
    });

    test('Sotto soglia energetica: nessun trigger a riposo', () {
      engine.setEnabled(true);
      final now = DateTime.now();

      // Valori normali di fondo
      final event = engine.evaluate(
        now: now,
        deltaEmf: 0.3,
        zScoreEmf: 0.8,
        dynamicAccel: 0.04,
        lorenzX: 0.5,
        currentFrequency: 98.0,
      );

      expect(event, isNull);
    });

    test('Filtro di Persistenza: non emette prima di 150ms continui', () {
      engine.setEnabled(true);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      // Inizio anomalia a t0
      final e1 = engine.evaluate(
        now: t0,
        deltaEmf: 4.5,
        zScoreEmf: 3.8,
        dynamicAccel: 1.2,
        lorenzX: 5.0,
        currentFrequency: 92.5,
      );
      expect(e1, isNull); // Primo campione, registra inizio

      // Campione a 100ms (< 150ms)
      final t1 = t0.add(const Duration(milliseconds: 100));
      final e2 = engine.evaluate(
        now: t1,
        deltaEmf: 4.8,
        zScoreEmf: 3.9,
        dynamicAccel: 1.2,
        lorenzX: 5.2,
        currentFrequency: 92.5,
      );
      expect(e2, isNull); // Ancora in finestra di persistenza

      // Campione a 160ms (>= 150ms) -> TRIGGER
      final t2 = t0.add(const Duration(milliseconds: 160));
      final e3 = engine.evaluate(
        now: t2,
        deltaEmf: 5.0,
        zScoreEmf: 4.0,
        dynamicAccel: 1.2,
        lorenzX: 5.5,
        currentFrequency: 92.5,
      );
      expect(e3, isNotNull);
      expect(e3!.word, isNotEmpty);
      expect(VocalTriggerEngine.lexicon.contains(e3.word), isTrue);
    });

    test('Determinismo Puro (Zero Random): medesime grandezze generano la medesima parola', () {
      engine.setEnabled(true);
      final t0 = DateTime(2026, 1, 1, 10, 0, 0);
      final tPersist = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 6.0, zScoreEmf: 4.2, dynamicAccel: 0.8, lorenzX: 8.0, currentFrequency: 99.0);
      final eA = engine.evaluate(now: tPersist, deltaEmf: 6.0, zScoreEmf: 4.2, dynamicAccel: 0.8, lorenzX: 8.0, currentFrequency: 99.0);
      expect(eA, isNotNull);

      // Nuovo motore identico
      final engine2 = VocalTriggerEngine(isEnabled: true);
      engine2.evaluate(now: t0, deltaEmf: 6.0, zScoreEmf: 4.2, dynamicAccel: 0.8, lorenzX: 8.0, currentFrequency: 99.0);
      final eB = engine2.evaluate(now: tPersist, deltaEmf: 6.0, zScoreEmf: 4.2, dynamicAccel: 0.8, lorenzX: 8.0, currentFrequency: 99.0);
      expect(eB, isNotNull);

      // Stessa parola deterministica garantita
      expect(eA!.word, equals(eB!.word));
    });

    test('Cooldown Refrattario: blocca emissioni successive per 7 secondi', () {
      engine.setEnabled(true);
      final t0 = DateTime(2026, 1, 1, 10, 0, 0);
      final tTrigger = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 5.0, zScoreEmf: 3.5, dynamicAccel: 1.0, lorenzX: 2.0, currentFrequency: 95.0);
      final e1 = engine.evaluate(now: tTrigger, deltaEmf: 5.0, zScoreEmf: 3.5, dynamicAccel: 1.0, lorenzX: 2.0, currentFrequency: 95.0);
      expect(e1, isNotNull);

      // Anomalia ancora presente a 3 secondi (< 7s) -> silenziata da cooldown
      final tCooldown = tTrigger.add(const Duration(seconds: 3));
      final e2 = engine.evaluate(now: tCooldown, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e2, isNull);

      // A 7.5 secondi (fine cooldown) -> nuova persistenza richiesta
      final tAfter = tTrigger.add(const Duration(milliseconds: 7500));
      final e3 = engine.evaluate(now: tAfter, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e3, isNull); // Inizia nuova finestra di persistenza

      final tAfterPersist = tAfter.add(const Duration(milliseconds: 160));
      final e4 = engine.evaluate(now: tAfterPersist, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e4, isNotNull);
    });
  });
}
