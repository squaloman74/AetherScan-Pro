import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/baseline_engine.dart';
import 'package:aetherscan_pro/trigger_logic.dart';
import 'package:aetherscan_pro/forensic_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: crea un TriggerResult minimale per i test del logger
// ─────────────────────────────────────────────────────────────────────────────
TriggerResult _makeResult({
  double emfDelta = 5.0,
  double emfZScore = 3.5,
  double accel = 0.15,
  TriggerClassification cls = TriggerClassification.environmentalAnomaly,
  bool isPhysicalTouch = false,
}) {
  final now = DateTime(2026, 11, 19, 10, 0, 0);
  return TriggerResult(
    timestamp: now,
    classification: cls,
    rawEmf: 47.0,
    deltaEmf: emfDelta,
    zScoreEmf: emfZScore,
    snrDbEmf: 12.5,
    rawDynamicAccel: accel,
    zScoreAccel: 1.2,
    isPhysicalTouch: isPhysicalTouch,
    persistenceMs: 155,
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // GRUPPO 1 — Tara rapida (applyQuickTare)
  // ───────────────────────────────────────────────────────────────────────────
  group('BLOCCO 1 — Tara Rapida (applyQuickTare)', () {
    test('Tara su engine vergine → isCalibrated=true e emfMean == valore corrente', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      final profile = engine.applyQuickTare(44.5);

      expect(engine.isCalibrated, isTrue);
      expect(profile.emfMean, closeTo(44.5, 0.001));
    });

    test('Tara su engine vergine → emfStdDev usa defaultStdDev=1.0', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      final profile = engine.applyQuickTare(44.5);

      expect(profile.emfStdDev, closeTo(1.0, 0.001));
    });

    test('Tara con stdDev personalizzata su engine vergine', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      final profile = engine.applyQuickTare(44.5, defaultStdDev: 2.5);

      expect(profile.emfStdDev, closeTo(2.5, 0.001));
    });

    test('emfMin/emfMax = currentEmfMagnitude su engine vergine (nessun profilo precedente)', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      final profile = engine.applyQuickTare(44.5);

      expect(profile.emfMin, closeTo(44.5, 0.001));
      expect(profile.emfMax, closeTo(44.5, 0.001));
    });

    test('Seconda tara: emfMin prende il minore, emfMax il maggiore', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      engine.applyQuickTare(44.5); // prima tara
      final profile = engine.applyQuickTare(50.0); // seconda tara

      // emfMin deve essere il min(44.5, 50.0) = 44.5
      expect(profile.emfMin, closeTo(44.5, 0.001));
      expect(profile.emfMax, closeTo(50.0, 0.001));
      expect(profile.emfMean, closeTo(50.0, 0.001));
    });

    test('Seconda tara con valore inferiore: emfMin si aggiorna', () {
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      engine.applyQuickTare(44.5);
      final profile = engine.applyQuickTare(38.0);

      expect(profile.emfMin, closeTo(38.0, 0.001));
      expect(profile.emfMax, closeTo(44.5, 0.001));
    });

    test('applyQuickTare preserva emfStdDev del profilo precedente', () {
      // Simuliamo un profilo precedente calibrato con stdDev noto
      final engine = BaselineEngine(targetDuration: const Duration(seconds: 30));
      // Prima tara con stdDev=2.0
      engine.applyQuickTare(42.0, defaultStdDev: 2.0);
      // Seconda tara: deve preservare stdDev=2.0 (da prev.emfStdDev)
      final profile = engine.applyQuickTare(45.0);

      expect(profile.emfStdDev, closeTo(2.0, 0.001));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GRUPPO 2 — Curva volume logaritmica / Noise Gate (logica Dart pura)
  // La formula: effectiveGain = masterVolume < 0.05 ? 0.0 : masterVolume²
  // ───────────────────────────────────────────────────────────────────────────
  group('BLOCCO 2 — Curva volume logaritmica + Noise Gate (logica pura Dart)', () {
    // Replica esatta della formula usata in MainActivity.kt e AppDelegate.swift
    double computeEffectiveGain(double masterVolume) {
      if (masterVolume < 0.05) return 0.0;
      return masterVolume * masterVolume;
    }

    test('masterVolume == 0.0 → effectiveGain == 0.0 (noise gate)', () {
      expect(computeEffectiveGain(0.0), closeTo(0.0, 1e-9));
    });

    test('masterVolume == 0.04 → effectiveGain == 0.0 (sotto soglia noise gate)', () {
      expect(computeEffectiveGain(0.04), closeTo(0.0, 1e-9));
    });

    test('masterVolume == 0.05 → NON azzerato, effectiveGain == 0.0025 (esattamente sulla soglia)', () {
      // 0.05 * 0.05 = 0.0025
      expect(computeEffectiveGain(0.05), closeTo(0.0025, 1e-9));
    });

    test('masterVolume == 0.5 → effectiveGain == 0.25 (curva quadratica)', () {
      expect(computeEffectiveGain(0.5), closeTo(0.25, 1e-9));
    });

    test('masterVolume == 0.85 (default) → effectiveGain == 0.7225', () {
      expect(computeEffectiveGain(0.85), closeTo(0.7225, 1e-9));
    });

    test('masterVolume == 1.0 → effectiveGain == 1.0 (massimo, nessuna perdita)', () {
      expect(computeEffectiveGain(1.0), closeTo(1.0, 1e-9));
    });

    test('effectiveGain ≤ masterVolume per ogni valore in [0.05, 1.0] (curva ≤ lineare)', () {
      for (double v = 0.05; v <= 1.0; v += 0.05) {
        final gain = computeEffectiveGain(v);
        expect(gain, lessThanOrEqualTo(v + 1e-9),
            reason: 'Per masterVolume=$v, gain=$gain deve essere ≤ v');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GRUPPO 3 — Fingerprinting deterministico (ForensicSessionLogger)
  // ───────────────────────────────────────────────────────────────────────────
  group('BLOCCO 3 — Fingerprinting deterministico (ForensicSessionLogger)', () {
    late ForensicSessionLogger logger;

    setUp(() {
      logger = ForensicSessionLogger(
        sessionId: 'TEST-SESSION-001',
        sessionStart: DateTime(2026, 11, 19, 10, 0, 0),
      );
    });

    test('Stessi valori fisici → stessa fingerprint (determinismo)', () {
      final fp1 = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      final fp2 = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      expect(fp1, equals(fp2));
    });

    test('Valori fisici diversi (emfDelta) → fingerprint diversa', () {
      final fp1 = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      final fp2 = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 7.5, // diverso
        dynamicAccel: 0.15,
        isBump: false,
      );
      expect(fp1, isNot(equals(fp2)));
    });

    test('Classificazione diversa → fingerprint diversa', () {
      final fpAnomaly = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      final fpTouch = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.mechanicalTouch,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      expect(fpAnomaly, isNot(equals(fpTouch)));
    });

    test('Primo trigger: occurrenceCount == 1', () {
      final result = _makeResult();
      final entry = logger.logTrigger(result);
      expect(entry.occurrenceCount, equals(1));
    });

    test('Secondo trigger identico: occurrenceCount == 2', () {
      final result = _makeResult();
      logger.logTrigger(result);
      final entry2 = logger.logTrigger(result);
      expect(entry2.occurrenceCount, equals(2));
    });

    test('Terzo trigger identico: occurrenceCount == 3', () {
      final result = _makeResult();
      logger.logTrigger(result);
      logger.logTrigger(result);
      final entry3 = logger.logTrigger(result);
      expect(entry3.occurrenceCount, equals(3));
    });

    test('Trigger con valori diversi: occurrenceCount riparte da 1', () {
      final result1 = _makeResult(emfDelta: 5.0);
      final result2 = _makeResult(emfDelta: 9.5); // diverso → fingerprint diversa
      logger.logTrigger(result1);
      final entry2 = logger.logTrigger(result2);
      expect(entry2.occurrenceCount, equals(1));
    });

    test('Fingerprint è inclusa in toMap() sotto la chiave fingerprint.hash', () {
      final result = _makeResult();
      final entry = logger.logTrigger(result);
      final map = entry.toMap();
      expect(map['fingerprint'], isA<Map>());
      final fpMap = map['fingerprint'] as Map;
      expect(fpMap['hash'], isNotNull);
      expect((fpMap['hash'] as String).isNotEmpty, isTrue);
    });

    test('Fingerprint è inclusa in toMap() insieme a occurrence_count', () {
      final result = _makeResult();
      logger.logTrigger(result);
      final entry = logger.logTrigger(result);
      final fpMap = entry.toMap()['fingerprint'] as Map;
      expect(fpMap['occurrence_count'], equals(2));
    });

    test('Fingerprint è inclusa nel CSV (toCsvRow non lancia eccezioni)', () {
      final result = _makeResult();
      final entry = logger.logTrigger(result);
      expect(() => entry.toCsvRow(), returnsNormally);
      // La riga CSV deve essere non vuota
      expect(entry.toCsvRow().isNotEmpty, isTrue);
    });

    test('exportJson() contiene tutti i trigger con fingerprint non vuota', () {
      logger.logTrigger(_makeResult(emfDelta: 5.0));
      logger.logTrigger(_makeResult(emfDelta: 7.0));
      final json = logger.exportJson();
      expect(json.contains('"hash"'), isTrue);
      expect(json.contains('"occurrence_count"'), isTrue);
    });

    test('Fingerprint è una stringa esadecimale di 16 caratteri (troncata)', () {
      final fp = ForensicSessionLogger.computeDeterministicFingerprint(
        classification: TriggerClassification.environmentalAnomaly,
        emfDelta: 5.0,
        dynamicAccel: 0.15,
        isBump: false,
      );
      expect(fp.length, equals(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(fp), isTrue);
    });
  });
}
