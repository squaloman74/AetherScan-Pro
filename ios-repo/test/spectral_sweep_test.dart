import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/spectral_sweep_engine.dart';

void main() {
  late SpectralSweepEngine engine;

  setUp(() {
    engine = SpectralSweepEngine(
      sampleRate: 48000.0,
      band: SweepBand.fm,
      sweepIntervalMs: 100,
    );
  });

  group('SpectralSweepEngine Unit Tests', () {
    test('1. Inizializzazione corretta frequenze base AM ed FM', () {
      expect(engine.currentFrequency, equals(87.5));
      expect(engine.band, equals(SweepBand.fm));

      engine.setBand(SweepBand.am);
      expect(engine.currentFrequency, equals(530.0));
      expect(engine.band, equals(SweepBand.am));
    });

    test('2. Avanzamento deterministico FM (passi da 0.1 MHz) con wrap-around a 108.0 MHz', () {
      final now = DateTime(2026, 11, 15, 12, 0, 0);

      // Frame iniziale
      final f1 = engine.processFrame(
        now: now,
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );
      expect(f1.currentFrequency, equals(87.5));

      // Avanzamento dopo 100ms
      final f2 = engine.processFrame(
        now: now.add(const Duration(milliseconds: 100)),
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );
      expect(f2.currentFrequency, equals(87.6));
    });

    test('3. Avanzamento deterministico AM (passi da 10 kHz) con wrap-around a 1600 kHz', () {
      engine.setBand(SweepBand.am);
      final now = DateTime(2026, 11, 15, 12, 0, 0);

      final f1 = engine.processFrame(
        now: now,
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );
      expect(f1.currentFrequency, equals(530.0));

      final f2 = engine.processFrame(
        now: now.add(const Duration(milliseconds: 100)),
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );
      expect(f2.currentFrequency, equals(540.0));
    });

    test('4. Modalità Pausa arresta lo scorrimento della frequenza', () {
      final now = DateTime(2026, 11, 15, 12, 0, 0);
      engine.setPaused(true);

      final f1 = engine.processFrame(
        now: now,
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );
      final f2 = engine.processFrame(
        now: now.add(const Duration(milliseconds: 500)),
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        dynamicAccel: 0.04,
      );

      expect(f1.currentFrequency, equals(f2.currentFrequency));
    });

    test('5. Accoppiamento Reattivo Fisico: anomalia EMF modula segnale e S-Meter', () {
      final now = DateTime(2026, 11, 15, 12, 0, 0);

      // Condizione di quiete (zero variazione)
      final fQuiet = engine.processFrame(
        now: now,
        deltaEmf: 0.0,
        zScoreEmf: 0.2,
        dynamicAccel: 0.04,
      );
      expect(fQuiet.isModulatedBySensor, isFalse);
      expect(fQuiet.signalStrengthDbm, equals(-115.0));

      // Forte anomalia magnetica reale (delta = 15 uT, Z = 7.5σ)
      final fAnomaly = engine.processFrame(
        now: now.add(const Duration(milliseconds: 50)),
        deltaEmf: 15.0,
        zScoreEmf: 7.5,
        dynamicAccel: 0.04,
      );
      expect(fAnomaly.isModulatedBySensor, isTrue);
      expect(fAnomaly.signalStrengthDbm, greaterThan(-115.0));
      expect(fAnomaly.sUnits, greaterThanOrEqualTo(fQuiet.sUnits));
      expect(fAnomaly.sensorCouplingFactor, greaterThan(0.0));
    });

    test('6. Determinismo Audio (Zero PRNG): input fisici identici generano buffer identici', () {
      final now = DateTime(2026, 11, 15, 12, 0, 0);

      final engineA = SpectralSweepEngine(sampleRate: 48000.0, band: SweepBand.fm);
      final engineB = SpectralSweepEngine(sampleRate: 48000.0, band: SweepBand.fm);

      final frameA = engineA.processFrame(
        now: now,
        deltaEmf: 8.5,
        zScoreEmf: 4.25,
        dynamicAccel: 0.12,
      );

      final frameB = engineB.processFrame(
        now: now,
        deltaEmf: 8.5,
        zScoreEmf: 4.25,
        dynamicAccel: 0.12,
      );

      expect(frameA.audioBuffer.length, equals(frameB.audioBuffer.length));
      for (int i = 0; i < frameA.audioBuffer.length; i++) {
        expect(frameA.audioBuffer[i], closeTo(frameB.audioBuffer[i], 1e-12));
      }
    });
  });
}
