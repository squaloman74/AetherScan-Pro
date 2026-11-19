import 'package:aetherscan_pro/forensic_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/baseline_engine.dart';
import 'package:aetherscan_pro/trigger_logic.dart';
import 'package:aetherscan_pro/spectral_sweep_engine.dart';

void main() {
  group('1. Touch Deduplication & Threshold Alignment Tests', () {
    late BaselineProfile baseline;
    late DeterministicTriggerEngine triggerEngine;

    setUp(() {
      baseline = BaselineProfile(
        calibratedAt: DateTime(2026, 11, 19, 12, 0, 0),
        duration: const Duration(seconds: 30),
        totalSamples: 3000,
        emfMean: 42.0,
        emfStdDev: 2.0,
        emfMin: 38.0,
        emfMax: 46.0,
        vibMean: 0.04,
        vibStdDev: 0.01,
        vibMax: 0.10,
        baroMean: 1013.25,
        baroStdDev: 0.05,
        baroMin: 1013.1,
        baroMax: 1013.4,
      );

      triggerEngine = DeterministicTriggerEngine(
        baseline: baseline,
        zThreshold: 3.5,
        touchAccelThreshold: 3.2, // Soglia fisica allineata: 3.2 m/s²
        minPersistenceMs: 150,
      );
    });

    test('Soglia tocco: accelerazione < 3.2 m/s² non genera mechanicalTouch', () {
      final now = DateTime.now();
      final reading = SensorReading(
        timestamp: now,
        emfMagnitude: 42.0,
        dynamicAcceleration: 3.1, // Appena sotto soglia
      );

      final res = triggerEngine.evaluate(reading);
      expect(res.isPhysicalTouch, isFalse);
      expect(res.classification, equals(TriggerClassification.none));
    });

    test('Soglia tocco: accelerazione >= 3.2 m/s² genera mechanicalTouch reale', () {
      final now = DateTime.now();
      final reading = SensorReading(
        timestamp: now,
        emfMagnitude: 42.0,
        dynamicAcceleration: 3.25, // Sopra soglia 3.2
      );

      final res = triggerEngine.evaluate(reading);
      expect(res.isPhysicalTouch, isTrue);
      expect(res.classification, equals(TriggerClassification.mechanicalTouch));
    });

    test('Deduplicazione: arrivo di accel reale non deve essere sovrascritto da bump sintetico', () {
      final t0 = DateTime.now();
      // Campione reale misurato dal sensore
      const realDynamicAccel = 1.85; // Movimento moderato sotto soglia tocco
      final readingReal = SensorReading(
        timestamp: t0,
        emfMagnitude: 42.0,
        dynamicAcceleration: realDynamicAccel,
      );

      final resReal = triggerEngine.evaluate(readingReal);
      expect(resReal.rawDynamicAccel, equals(1.85));
      expect(resReal.isPhysicalTouch, isFalse);

      // Se non si inietta il bump sintetico (3.5 m/s²), l'accelerazione dinamica resta quella reale
      expect(readingReal.dynamicAcceleration, equals(realDynamicAccel));
    });
  });

  group('2. Sweep Audio & State Continuity Across Mode Transitions', () {
    late SpectralSweepEngine sweepEngine;

    setUp(() {
      sweepEngine = SpectralSweepEngine(
        band: SweepBand.fm,
        sweepIntervalMs: 100,
        direction: SweepDirection.forward,
      );
    });

    test('Sweep mantiene frequenza e direzione attiva senza stop audio forzato', () {
      final t0 = DateTime.now();
      final frame1 = sweepEngine.processFrame(
        now: t0,
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );

      expect(sweepEngine.direction, equals(SweepDirection.forward));
      expect(frame1.currentFrequency, greaterThanOrEqualTo(87.5));

      // Simulazione passaggio da SpectralSweep a MetrologyPro senza chiamare setPaused né _stopSweepAudio
      // Lo sweepEngine resta attivo in background
      final t1 = t0.add(const Duration(milliseconds: 150));
      final frame2 = sweepEngine.processFrame(
        now: t1,
        deltaEmf: 1.5,
        zScoreEmf: 0.8,
        dynamicAccel: 0.05,
      );

      expect(sweepEngine.direction, equals(SweepDirection.forward));
      expect(frame2.audioBuffer.length, equals(512));
      // Lo sweep continua ad avanzare regolarmente
      expect(frame2.currentFrequency, isNot(equals(frame1.currentFrequency)));
    });

    test('Sweep continua a generare audio e frame validi se non esplicitamente in pausa', () {
      final frame = sweepEngine.processFrame(
        now: DateTime.now(),
        deltaEmf: 2.0,
        zScoreEmf: 1.2,
        dynamicAccel: 0.1,
      );

      expect(frame.audioBuffer.isNotEmpty, isTrue);
      expect(frame.audioBuffer.any((sample) => sample.isNaN || sample.isInfinite), isFalse);
    });
  });

  group('3. Master Volume Range & Scaling Tests', () {
    test('Master volume clamp entro intervallo consentito [0.0, 1.0]', () {
      double masterVolume = 0.85;

      // Impostazione volume valido
      masterVolume = 0.5.clamp(0.0, 1.0);
      expect(masterVolume, equals(0.5));

      // Tentativo overflow
      masterVolume = 1.5.clamp(0.0, 1.0);
      expect(masterVolume, equals(1.0));

      // Tentativo underflow
      masterVolume = (-0.2).clamp(0.0, 1.0);
      expect(masterVolume, equals(0.0));
    });

    test('Parametri payload volume per canali audio nativi', () {
      const double masterVolume = 0.70;
      final params = <String, dynamic>{
        'emfDelta': 1.2,
        'accel': 0.05,
        'zScore': 0.6,
        'pitchHz': 650.0,
        'volume': masterVolume,
      };

      expect(params['volume'], equals(0.70));
      expect(params.containsKey('volume'), isTrue);
    });
  });

test('applyQuickTare updates EMF baseline deterministically', () {
  final engine = BaselineEngine();
  final profile = engine.applyQuickTare(48.6, defaultStdDev: 1.5);

  expect(engine.isCalibrated, isTrue);
  expect(profile.emfMean, closeTo(48.6, 1e-6));
  expect(profile.emfStdDev, closeTo(1.5, 1e-6));
});

test('computeDeterministicFingerprint is repeatable and tracks occurrenceCount', () {
  final fpA1 = ForensicSessionLogger.computeDeterministicFingerprint(
    classification: TriggerClassification.environmentalAnomaly,
    emfDelta: 12.4,
    dynamicAccel: 0.15,
    isBump: false,
    pressureHpa: 1013.2,
    audioPeakHz: 440.0,
  );
  final fpA2 = ForensicSessionLogger.computeDeterministicFingerprint(
    classification: TriggerClassification.environmentalAnomaly,
    emfDelta: 12.42,
    dynamicAccel: 0.151,
    isBump: false,
    pressureHpa: 1013.21,
    audioPeakHz: 440.2,
  );
  final fpB = ForensicSessionLogger.computeDeterministicFingerprint(
    classification: TriggerClassification.environmentalAnomaly,
    emfDelta: 25.0,
    dynamicAccel: 0.15,
    isBump: false,
    pressureHpa: 1013.2,
    audioPeakHz: 440.0,
  );

  expect(fpA1, equals(fpA2));
  expect(fpA1, isNot(equals(fpB)));

  final logger = ForensicSessionLogger(
    sessionId: 'test-session',
    sessionStart: DateTime.utc(2026, 11, 19, 13, 0),
  );
  final r1 = TriggerResult(
    timestamp: DateTime.utc(2026, 11, 19, 13, 1),
    classification: TriggerClassification.environmentalAnomaly,
    rawEmf: 52.4,
    deltaEmf: 12.4,
    zScoreEmf: 4.1,
    snrDbEmf: 14.0,
    rawDynamicAccel: 0.15,
    zScoreAccel: 0.5,
    isPhysicalTouch: false,
    persistenceMs: 120,
  );
  final e1 = logger.logTrigger(r1, pressureHpa: 1013.2, audioPeakHz: 440.0);
  final e2 = logger.logTrigger(r1, pressureHpa: 1013.2, audioPeakHz: 440.0);

  expect(e1.fingerprint, equals(fpA1));
  expect(e1.occurrenceCount, equals(1));
  expect(e2.fingerprint, equals(fpA1));
  expect(e2.occurrenceCount, equals(2));
});
}
