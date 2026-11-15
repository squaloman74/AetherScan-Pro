import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/baseline_engine.dart';
import 'package:aetherscan_pro/trigger_logic.dart';

void main() {
  late BaselineProfile testBaseline;
  late DeterministicTriggerEngine engine;

  setUp(() {
    testBaseline = BaselineProfile(
      calibratedAt: DateTime(2026, 11, 14, 12, 0, 0),
      duration: const Duration(seconds: 30),
      totalSamples: 3000,
      emfMean: 40.0,
      emfStdDev: 2.0, // sigma = 2.0 uT
      emfMin: 35.0,
      emfMax: 45.0,
      vibMean: 0.05,
      vibStdDev: 0.02, // sigma = 0.02 m/s²
      vibMax: 0.12,
      baroMean: 1013.25,
      baroStdDev: 0.1,
      baroMin: 1013.0,
      baroMax: 1013.5,
    );

    engine = DeterministicTriggerEngine(
      baseline: testBaseline,
      zThreshold: 3.5, // 3.5 sigma = 40.0 + 7.0 = 47.0 uT
      touchAccelThreshold: 3.2, // Soglia contatto/pressione: 3.2 m/s²
      minPersistenceMs: 150,
    );
  });

  group('DeterministicTriggerEngine (Dual-Trigger & Metrology) Unit Tests', () {
    test('1. Rumore ordinario sotto soglia 3.5 sigma senza tocco -> classification none, NO ALARM', () {
      final now = DateTime.now();
      // 44.0 uT => delta = +4.0 uT => Z = 4.0 / 2.0 = 2.0 (< 3.5), vib = 0.05 m/s² (< 3.2)
      final reading = SensorReading(
        timestamp: now,
        emfMagnitude: 44.0,
        dynamicAcceleration: 0.05,
      );

      final result = engine.evaluate(reading);
      expect(result.classification, equals(TriggerClassification.none));
      expect(result.zScoreEmf, closeTo(2.0, 1e-6));
      expect(result.isAnomaly, isFalse);
      expect(result.isPhysicalTouch, isFalse);
      expect(result.shouldTriggerAlarmSound, isFalse);
    });

    test('2. Solo tocco meccanico/pressione telaio (>= 3.2 m/s²) SENZA anomalia EMF -> mechanicalTouch, NO ALARM', () {
      final now = DateTime.now();
      // EMF ordinario (41.0 uT => Z = 0.5 < 3.5), ma forte tocco sul telaio (3.6 m/s² >= 3.2)
      final reading = SensorReading(
        timestamp: now,
        emfMagnitude: 41.0,
        dynamicAcceleration: 3.6,
      );

      final result = engine.evaluate(reading);
      expect(result.classification, equals(TriggerClassification.mechanicalTouch));
      expect(result.isMechanicalTouch, isTrue);
      expect(result.isPhysicalTouch, isTrue);
      expect(result.isAnomaly, isFalse);
      expect(result.shouldTriggerAlarmSound, isFalse); // NESSUN ALLARME ACUSTICO
    });

    test('3. Spike EMF impulsivo non persistente (< 150 ms) -> transientSpike, NO ALARM', () {
      final now = DateTime.now();
      // 50.0 uT => delta = +10.0 uT => Z = 10.0 / 2.0 = 5.0 (>= 3.5)
      final r1 = SensorReading(
        timestamp: now,
        emfMagnitude: 50.0,
        dynamicAcceleration: 0.05,
      );

      final res1 = engine.evaluate(r1);
      // Primo campione: persistenza = 0 ms (< 150 ms)
      expect(res1.classification, equals(TriggerClassification.transientSpike));
      expect(res1.zScoreEmf, closeTo(5.0, 1e-6));
      expect(res1.shouldTriggerAlarmSound, isFalse);
    });

    test('4. Solo anomalia EMF persistente (>= 150 ms) SENZA tocco -> environmentalAnomaly, CSV Log, NO ALARM', () {
      final now = DateTime.now();

      // Campione 0ms (Z = 6.0 >= 3.5)
      engine.evaluate(SensorReading(
        timestamp: now,
        emfMagnitude: 52.0,
        dynamicAcceleration: 0.05,
      ));

      // Campione dopo 100ms (persistenza = 100ms < 150ms)
      final res2 = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(milliseconds: 100)),
        emfMagnitude: 52.0,
        dynamicAcceleration: 0.05,
      ));
      expect(res2.classification, equals(TriggerClassification.transientSpike));

      // Campione dopo 160ms (persistenza = 160ms >= 150ms)
      final res3 = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(milliseconds: 160)),
        emfMagnitude: 52.0,
        dynamicAcceleration: 0.05,
      ));
      expect(res3.classification, equals(TriggerClassification.environmentalAnomaly));
      expect(res3.isEnvironmentalAnomaly, isTrue);
      expect(res3.isPhysicalTouch, isFalse);
      expect(res3.shouldTriggerAlarmSound, isFalse); // Anomalia metrologica pura: NO allarme da tocco
    });

    test('5. COINCIDENZA DUAL-TRIGGER: Tocco fisico (>= 3.2 m/s²) + Anomalia EMF (>= 3.5σ, >= 150 ms) -> ALARM SOUND TRIGGERED!', () {
      final now = DateTime.now();

      // Campione iniziale per stabilire l'anomalia EMF
      engine.evaluate(SensorReading(
        timestamp: now,
        emfMagnitude: 54.0, // Z = (54-40)/2 = 7.0
        dynamicAcceleration: 3.5, // Tocco simultaneo
      ));

      // Campione dopo 160ms (persistenza raggiunta + tocco attivo)
      final resDual = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(milliseconds: 160)),
        emfMagnitude: 54.0,
        dynamicAcceleration: 3.5, // Tocco contemporaneo
      ));

      expect(resDual.classification, equals(TriggerClassification.dualTriggerInteraction));
      expect(resDual.isDualTrigger, isTrue);
      expect(resDual.isPhysicalTouch, isTrue);
      expect(resDual.isAnomaly, isTrue);
      // QUESTA È L'UNICA CONDIZIONE CHE DEVE ATTIVARE L'AUDIO:
      expect(resDual.shouldTriggerAlarmSound, isTrue);
    });

    test('6. Ripristino stato e azzeramento deterministico', () {
      final now = DateTime.now();
      engine.evaluate(SensorReading(
        timestamp: now,
        emfMagnitude: 55.0,
        dynamicAcceleration: 3.5,
      ));
      expect(engine.consecutiveAnomalySamples, equals(1));

      engine.reset();
      expect(engine.consecutiveAnomalySamples, equals(0));

      // Dopo reset, un campione sotto soglia torna a none
      final resClean = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(seconds: 1)),
        emfMagnitude: 40.0,
        dynamicAcceleration: 0.04,
      ));
      expect(resClean.classification, equals(TriggerClassification.none));
      expect(resClean.shouldTriggerAlarmSound, isFalse);
    });
  });
}
