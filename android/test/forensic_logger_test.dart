import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/baseline_engine.dart';
import 'package:aetherscan_pro/trigger_logic.dart';
import 'package:aetherscan_pro/forensic_logger.dart';

void main() {
  group('Sha256 Pure Implementation Tests (NIST Vectors)', () {
    test('Hash stringa vuota corrisponde allo standard FIPS 180-4', () {
      // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      final hash = Sha256.hashString('');
      expect(hash, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    test('Hash di "abc" corrisponde allo standard NIST', () {
      // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
      final hash = Sha256.hashString('abc');
      expect(hash, equals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
    });
  });

  group('ForensicSessionLogger Tests', () {
    late BaselineProfile baseline;
    late ForensicSessionLogger logger;

    setUp(() {
      baseline = BaselineProfile(
        calibratedAt: DateTime(2026, 11, 14, 10, 0, 0),
        duration: const Duration(seconds: 30),
        totalSamples: 1500,
        emfMean: 42.0,
        emfStdDev: 1.5,
        emfMin: 38.0,
        emfMax: 46.0,
        vibMean: 0.04,
        vibStdDev: 0.01,
        vibMax: 0.08,
        baroMean: 1013.2,
        baroStdDev: 0.05,
        baroMin: 1013.1,
        baroMax: 1013.3,
      );

      logger = ForensicSessionLogger(
        sessionId: 'ASPRO-TEST-001',
        sessionStart: DateTime(2026, 11, 14, 10, 5, 0),
        baseline: baseline,
      );
    });

    test('Registrazione corretta di eventi validi e calcolo statistiche', () {
      final now = DateTime.now();

      final trigger1 = TriggerResult(
        timestamp: now,
        classification: TriggerClassification.environmentalAnomaly,
        rawEmf: 55.0,
        deltaEmf: 13.0,
        zScoreEmf: 8.66,
        snrDbEmf: 18.7,
        rawDynamicAccel: 0.04,
        zScoreAccel: 0.0,
        isPhysicalTouch: false,
        persistenceMs: 250,
      );

      final trigger2 = TriggerResult(
        timestamp: now.add(const Duration(seconds: 1)),
        classification: TriggerClassification.mechanicalTouch,
        rawEmf: 60.0,
        deltaEmf: 18.0,
        zScoreEmf: 12.0,
        snrDbEmf: 21.5,
        rawDynamicAccel: 0.55,
        zScoreAccel: 51.0,
        isPhysicalTouch: true,
        persistenceMs: 0,
      );

      final trigger3 = TriggerResult(
        timestamp: now.add(const Duration(seconds: 2)),
        classification: TriggerClassification.dualTriggerInteraction,
        rawEmf: 58.0,
        deltaEmf: 16.0,
        zScoreEmf: 10.66,
        snrDbEmf: 20.1,
        rawDynamicAccel: 3.5,
        zScoreAccel: 345.0,
        isPhysicalTouch: true,
        persistenceMs: 200,
      );

      logger.logTrigger(trigger1, audioPeakHz: 1240.0, audioPeakDbfs: -18.5);
      logger.logTrigger(trigger2);
      logger.logTrigger(trigger3);

      expect(logger.totalEntries, equals(3));
      // environmentalAnomaly (1) + dualTriggerInteraction (1) = 2
      expect(logger.validAnomaliesCount, equals(2));
      // mechanicalTouch (1) = 1
      expect(logger.artifactCount, equals(1));
    });

    test('Esportazione CSV Metrologico e Checksum SHA-256', () {
      final now = DateTime(2026, 11, 14, 10, 6, 0);

      logger.logTrigger(TriggerResult(
        timestamp: now,
        classification: TriggerClassification.environmentalAnomaly,
        rawEmf: 50.0,
        deltaEmf: 8.0,
        zScoreEmf: 5.33,
        snrDbEmf: 14.5,
        rawDynamicAccel: 0.04,
        zScoreAccel: 0.0,
        isPhysicalTouch: false,
        persistenceMs: 180,
      ));

      final csv = logger.exportCsv();
      expect(csv.contains('Session_ID: ASPRO-TEST-001'), isTrue);
      expect(csv.contains('environmentalAnomaly'), isTrue);
      expect(csv.contains('50.00,8.00,5.33,14.5'), isTrue);

      final checksum = logger.computeSessionChecksum();
      expect(checksum.length, equals(64));
      // Stesso CSV produce identico checksum
      expect(logger.computeSessionChecksum(), equals(checksum));
    });

    test('Esportazione JSON e compatibilità di schema', () {
      final jsonStr = logger.exportJson();
      expect(jsonStr.contains('AetherScan-Pro'), isTrue);
      expect(jsonStr.contains('Scientific Forensic Logger v27-beta2'), isTrue);
      expect(jsonStr.contains('ASPRO-TEST-001'), isTrue);
    });
  });
}
