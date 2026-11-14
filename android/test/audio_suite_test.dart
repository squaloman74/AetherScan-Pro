import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/audio_suite.dart';

void main() {
  const double fs = 48000.0;

  group('BiquadFilter & DSP Chain Tests', () {
    test('Filtro Notch 50 Hz attenua fortemente una sinusoide a 50 Hz', () {
      final notch = BiquadFilter(
        type: BiquadFilterType.notch,
        sampleRate: fs,
        centerFrequency: 50.0,
        q: 10.0,
      );

      // Genera tono puro 50 Hz
      double maxUnfiltered = 0.0;
      double maxFiltered = 0.0;

      for (int i = 0; i < 24000; i++) { // 500 ms per permettere al transitorio IIR ad alto Q di stabilizzarsi
        final double t = i / fs;
        final double sample = sin(2.0 * pi * 50.0 * t);
        final double filtered = notch.process(sample);

        if (i > 15000) { // dopo il transitorio iniziale del filtro (300 ms)
          maxUnfiltered = max(maxUnfiltered, sample.abs());
          maxFiltered = max(maxFiltered, filtered.abs());
        }
      }

      // Attenuazione attesa > 20 dB (ampiezza filtrata < 10% del segnale originale)
      expect(maxUnfiltered, closeTo(1.0, 0.05));
      expect(maxFiltered, lessThan(0.15));
    });

    test('Filtro Passa-Alto 80 Hz abbatte le sub-frequenze a 20 Hz', () {
      final hp = BiquadFilter(
        type: BiquadFilterType.highPass,
        sampleRate: fs,
        centerFrequency: 80.0,
        q: 0.707,
      );

      double maxFiltered20Hz = 0.0;
      for (int i = 0; i < 4800; i++) {
        final double t = i / fs;
        final double sample = sin(2.0 * pi * 20.0 * t);
        final double filtered = hp.process(sample);
        if (i > 2400) {
          maxFiltered20Hz = max(maxFiltered20Hz, filtered.abs());
        }
      }

      // 20 Hz è 2 ottave sotto gli 80 Hz; attenuazione Butterworth 2° ordine = -24 dB (ampiezza < 0.1)
      expect(maxFiltered20Hz, lessThan(0.12));
    });

    test('Filtro Passa-Alto lascia transitare inalterato un segnale vocale a 1000 Hz', () {
      final hp = BiquadFilter(
        type: BiquadFilterType.highPass,
        sampleRate: fs,
        centerFrequency: 80.0,
        q: 0.707,
      );

      double maxFiltered1kHz = 0.0;
      for (int i = 0; i < 4800; i++) {
        final double t = i / fs;
        final double sample = sin(2.0 * pi * 1000.0 * t);
        final double filtered = hp.process(sample);
        if (i > 2400) {
          maxFiltered1kHz = max(maxFiltered1kHz, filtered.abs());
        }
      }

      // 1000 Hz deve passare quasi senza perdita (> 0.95)
      expect(maxFiltered1kHz, greaterThan(0.95));
    });
  });

  group('FFTSpectrumEngine Tests', () {
    test('Riconoscimento frequenza dominante di un tono a 1000 Hz in dBFS', () {
      final fft = FFTSpectrumEngine(fftSize: 1024, sampleRate: fs);

      // Genera 1024 campioni di tono a 1000 Hz
      final samples = List<double>.generate(1024, (i) {
        final double t = i / fs;
        return sin(2.0 * pi * 1000.0 * t);
      });

      final result = fft.analyze(samples);

      // Risoluzione bin = 48000 / 1024 = 46.875 Hz
      // 1000 Hz cade attorno al bin 21 (21 * 46.875 = 984.375 Hz o bin 22 = 1031.25 Hz)
      expect(result.peakFrequencyHz, closeTo(1000.0, 50.0));
      // Picco vicino a 0 dBFS (-6 a 0 dBFS con finestra di Hann)
      expect(result.peakMagnitudeDbfs, greaterThan(-10.0));
    });

    test('Assenza di NaN o infiniti nel buffer FFT anche con silenzio assoluto', () {
      final fft = FFTSpectrumEngine(fftSize: 512, sampleRate: fs);
      final silence = List<double>.filled(512, 0.0);

      final result = fft.analyze(silence);
      expect(result.peakMagnitudeDbfs, equals(-120.0));
      for (final val in result.magnitudesDbfs) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
      }
    });
  });
}
