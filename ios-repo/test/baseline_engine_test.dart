import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/baseline_engine.dart';

void main() {
  group('WelfordAccumulator Tests', () {
    test('Calcolo esatto di media, varianza e deviazione standard', () {
      final acc = WelfordAccumulator();
      final values = [10.0, 12.0, 23.0, 23.0, 16.0, 23.0, 21.0, 16.0];

      for (final v in values) {
        acc.update(v);
      }

      expect(acc.count, equals(8));
      // Calcolo analitico: somma = 144, media = 18.0
      expect(acc.mean, closeTo(18.0, 1e-9));

      // Somma dei quadrati degli scarti:
      // (10-18)^2=64, (12-18)^2=36, (23-18)^2*3=75, (16-18)^2*2=8, (21-18)^2=9
      // Totale = 64 + 36 + 75 + 8 + 9 = 192
      // Varianza campionaria corretta (n-1 = 7) = 192 / 7 ≈ 27.42857142857143
      expect(acc.variance, closeTo(192.0 / 7.0, 1e-9));
      expect(acc.standardDeviation, closeTo(sqrt(192.0 / 7.0), 1e-9));
      expect(acc.min, equals(10.0));
      expect(acc.max, equals(23.0));
    });

    test('Calcolo corretto dello Z-Score', () {
      final acc = WelfordAccumulator();
      // Distribuzione con media = 50, std_dev nota
      for (int i = 0; i < 100; i++) {
        acc.update(50.0 + (i.isEven ? 5.0 : -5.0));
      }
      expect(acc.mean, closeTo(50.0, 1e-9));

      // Se il valore è esattamente la media, Z-Score = 0
      expect(acc.zScore(50.0), closeTo(0.0, 1e-6));

      // Se il valore dista 1 deviazione standard
      final sd = acc.standardDeviation;
      expect(acc.zScore(50.0 + sd), closeTo(1.0, 1e-6));
      expect(acc.zScore(50.0 - 2 * sd), closeTo(-2.0, 1e-6));
    });

    test('Gestione edge-case: singolo valore e deviazione zero', () {
      final acc = WelfordAccumulator();
      acc.update(42.0);

      expect(acc.count, equals(1));
      expect(acc.mean, equals(42.0));
      expect(acc.variance, equals(0.0));
      expect(acc.standardDeviation, equals(0.0));
      // Non deve dividere per zero
      expect(acc.zScore(42.0), equals(0.0));
    });
  });

  group('BaselineEngine Lifecycle Tests', () {
    test('Flusso di calibrazione rapido e generazione BaselineProfile', () async {
      BaselineProfile? completedProfile;
      double lastProgress = 0.0;

      final engine = BaselineEngine(
        targetDuration: const Duration(milliseconds: 200),
        onProgress: (p, remaining) {
          lastProgress = p;
        },
        onComplete: (profile) {
          completedProfile = profile;
        },
      );

      expect(engine.status, equals(CalibrationStatus.idle));
      engine.startCalibration();
      expect(engine.isCalibrating, isTrue);

      // Simula campionamento ad alta frequenza durante la calibrazione
      for (int i = 0; i < 60; i++) {
        engine.ingestEmf(30.0, 20.0, 10.0 + (i % 3));
        engine.ingestVibration(0.02, 0.01, 0.01);
        engine.ingestPressure(1013.25 + (i * 0.01));
      }

      // Attendi il completamento della durata target
      await Future.delayed(const Duration(milliseconds: 300));

      expect(engine.isCalibrated, isTrue);
      expect(completedProfile, isNotNull);
      expect(completedProfile!.isValid, isTrue);
      expect(completedProfile!.totalSamples, equals(60));
      expect(completedProfile!.emfMean, greaterThan(35.0));
      expect(completedProfile!.baroMean, closeTo(1013.5, 0.5));
      expect(lastProgress, equals(1.0));
    });

    test('Annullamento manuale calibrazione', () {
      String? cancelReason;
      final engine = BaselineEngine(
        targetDuration: const Duration(seconds: 10),
        onCancelled: (reason) {
          cancelReason = reason;
        },
      );

      engine.startCalibration();
      expect(engine.isCalibrating, isTrue);

      engine.cancelCalibration(reason: 'Test annullamento operatore');
      expect(engine.status, equals(CalibrationStatus.cancelled));
      expect(cancelReason, equals('Test annullamento operatore'));
      expect(engine.activeProfile, isNull);
    });
  });
}
