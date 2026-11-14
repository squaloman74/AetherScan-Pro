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
      bumpZThreshold: 2.5,
      minPersistenceMs: 150,
      lemmaPoolSize: 98,
    );
  });

  group('DeterministicTriggerEngine Unit Tests', () {
    test('Rumore ordinario sotto soglia 3.5 sigma viene classificato come none', () {
      final now = DateTime.now();
      // 44.0 uT => delta = +4.0 uT => Z = 4.0 / 2.0 = 2.0 (< 3.5)
      final reading = SensorReading(
        timestamp: now,
        emfMagnitude: 44.0,
        dynamicAcceleration: 0.05,
      );

      final result = engine.evaluate(reading);
      expect(result.classification, equals(TriggerClassification.none));
      expect(result.zScoreEmf, closeTo(2.0, 1e-6));
      expect(result.isAnomaly, isFalse);
    });

    test('Transitorio impulsivo (< 150 ms) viene marcato come transientSpike', () {
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
      expect(res1.isAnomaly, isFalse);
    });

    test('Anomalia persistente (>= 150 ms) viene convalidata come validAnomaly', () {
      final now = DateTime.now();

      // Campione 0ms
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
      expect(res3.classification, equals(TriggerClassification.validAnomaly));
      expect(res3.isAnomaly, isTrue);
      expect(res3.deterministicLemmaIndex, isNotNull);
      expect(res3.deterministicLemmaIndex!, inInclusiveRange(0, 97));
    });

    test('Filtro Anti-Bump: urto dell\'accelerometro blocca e declassa ad artefatto meccanico', () {
      final now = DateTime.now();

      // Spike EMF alto (55 uT, Z = 7.5), ma con contemporaneo urto dinamico (0.50 m/s², baseline 0.05, sd 0.02 => Z = 22.5)
      final bumpReading = SensorReading(
        timestamp: now,
        emfMagnitude: 55.0,
        dynamicAcceleration: 0.50,
      );

      final result = engine.evaluate(bumpReading);
      expect(result.classification, equals(TriggerClassification.mechanicalArtifact));
      expect(result.isBumpDetected, isTrue);
      expect(result.isAnomaly, isFalse);
      expect(result.isArtifact, isTrue);
    });

    test('Determinismo puro (Anti-RNG): gli stessi valori fisici producono identico indice di lemma', () {
      final now = DateTime.now();

      final readingA = SensorReading(
        timestamp: now,
        emfMagnitude: 54.2,
        dynamicAcceleration: 0.05,
        pressureHpa: 1014.1,
      );

      // Simula persistenza
      engine.evaluate(readingA);
      final resA = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(milliseconds: 200)),
        emfMagnitude: 54.2,
        dynamicAcceleration: 0.05,
        pressureHpa: 1014.1,
      ));

      // Resetta motore ed esegui nuovamente la stessa identica sequenza fisica
      engine.reset();
      engine.evaluate(readingA);
      final resB = engine.evaluate(SensorReading(
        timestamp: now.add(const Duration(milliseconds: 200)),
        emfMagnitude: 54.2,
        dynamicAcceleration: 0.05,
        pressureHpa: 1014.1,
      ));

      expect(resA.classification, equals(TriggerClassification.validAnomaly));
      expect(resB.classification, equals(TriggerClassification.validAnomaly));
      expect(resA.deterministicLemmaIndex, equals(resB.deterministicLemmaIndex));
    });
  });
}
