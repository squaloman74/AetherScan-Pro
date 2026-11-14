import 'dart:math';
import 'dart:typed_data';

/// Tipologia di filtro IIR Biquad
enum BiquadFilterType {
  lowPass,
  highPass,
  bandPass,
  notch,
}

/// Implementazione di Filtro Digitale IIR Biquad (Direct Form II Transposed)
/// Usato per filtraggio scientifico del segnale audio senza alterazioni di fase distorcenti.
class BiquadFilter {
  final BiquadFilterType type;
  final double sampleRate;
  final double centerFrequency;
  final double q;

  double _b0 = 1.0;
  double _b1 = 0.0;
  double _b2 = 0.0;
  double _a1 = 0.0;
  double _a2 = 0.0;

  double _d1 = 0.0;
  double _d2 = 0.0;

  BiquadFilter({
    required this.type,
    required this.sampleRate,
    required this.centerFrequency,
    this.q = 0.70710678, // Butterworth standard
  }) {
    _computeCoefficients();
  }

  void _computeCoefficients() {
    final double omega = 2.0 * pi * (centerFrequency / sampleRate);
    final double sinOmega = sin(omega);
    final double cosOmega = cos(omega);
    final double alpha = sinOmega / (2.0 * q);

    double a0 = 1.0;

    switch (type) {
      case BiquadFilterType.lowPass:
        _b0 = (1.0 - cosOmega) / 2.0;
        _b1 = 1.0 - cosOmega;
        _b2 = (1.0 - cosOmega) / 2.0;
        a0 = 1.0 + alpha;
        _a1 = -2.0 * cosOmega;
        _a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.highPass:
        _b0 = (1.0 + cosOmega) / 2.0;
        _b1 = -(1.0 + cosOmega);
        _b2 = (1.0 + cosOmega) / 2.0;
        a0 = 1.0 + alpha;
        _a1 = -2.0 * cosOmega;
        _a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.bandPass:
        _b0 = alpha;
        _b1 = 0.0;
        _b2 = -alpha;
        a0 = 1.0 + alpha;
        _a1 = -2.0 * cosOmega;
        _a2 = 1.0 - alpha;
        break;

      case BiquadFilterType.notch:
        _b0 = 1.0;
        _b1 = -2.0 * cosOmega;
        _b2 = 1.0;
        a0 = 1.0 + alpha;
        _a1 = -2.0 * cosOmega;
        _a2 = 1.0 - alpha;
        break;
    }

    // Normalizzazione per a0
    _b0 /= a0;
    _b1 /= a0;
    _b2 /= a0;
    _a1 /= a0;
    _a2 /= a0;
  }

  /// Elaborazione di un singolo campione audio float [-1.0, 1.0]
  double process(double input) {
    final double out = _b0 * input + _d1;
    _d1 = _b1 * input - _a1 * out + _d2;
    _d2 = _b2 * input - _a2 * out;
    return out;
  }

  /// Elaborazione in-place di un buffer di campioni
  void processBuffer(Float64List buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = process(buffer[i]);
    }
  }

  void reset() {
    _d1 = 0.0;
    _d2 = 0.0;
  }
}

/// Catena di equalizzazione analitica per registrazioni forensi (No Fake Echoes)
class AnalyticalDSPChain {
  final double sampleRate;

  late final BiquadFilter notchFilter50Hz;
  late final BiquadFilter highPassFilter80Hz;
  late final BiquadFilter lowPassFilter12kHz;

  bool enableNotch = true;
  bool enableHighPass = true;
  bool enableLowPass = true;

  AnalyticalDSPChain({this.sampleRate = 48000.0}) {
    // Notch a 50 Hz per isolamento dell'hum elettrico di rete (Q elevato = 10.0)
    notchFilter50Hz = BiquadFilter(
      type: BiquadFilterType.notch,
      sampleRate: sampleRate,
      centerFrequency: 50.0,
      q: 10.0,
    );

    // Passa-alto a 80 Hz per eliminare rombi, vento e micro-movimenti dello chassis
    highPassFilter80Hz = BiquadFilter(
      type: BiquadFilterType.highPass,
      sampleRate: sampleRate,
      centerFrequency: 80.0,
      q: 0.707,
    );

    // Passa-basso a 12 kHz per eliminare il fruscio termico ultrasonico
    lowPassFilter12kHz = BiquadFilter(
      type: BiquadFilterType.lowPass,
      sampleRate: sampleRate,
      centerFrequency: 12000.0,
      q: 0.707,
    );
  }

  /// Applica i filtri scientifici senza aggiungere alcun riverbero o eco
  double process(double rawSample) {
    double s = rawSample;
    if (enableNotch) s = notchFilter50Hz.process(s);
    if (enableHighPass) s = highPassFilter80Hz.process(s);
    if (enableLowPass) s = lowPassFilter12kHz.process(s);
    return s;
  }

  void reset() {
    notchFilter50Hz.reset();
    highPassFilter80Hz.reset();
    lowPassFilter12kHz.reset();
  }
}

/// Risultato dell'analisi di spettro FFT
class FFTSpectrumResult {
  final Float64List magnitudesDbfs; // Spettro in dBFS (es. -100 a 0)
  final double peakFrequencyHz; // Frequenza dominante identificata
  final double peakMagnitudeDbfs; // Intensità picco in dBFS
  final double binResolutionHz; // Risoluzione frequenziale per bin

  const FFTSpectrumResult({
    required this.magnitudesDbfs,
    required this.peakFrequencyHz,
    required this.peakMagnitudeDbfs,
    required this.binResolutionHz,
  });
}

/// Motore di calcolo FFT e analisi spettrale in dBFS (senza artefatti)
class FFTSpectrumEngine {
  final int fftSize; // Deve essere potenza di 2 (es. 512, 1024)
  final double sampleRate;
  late final Float64List _window;

  FFTSpectrumEngine({
    this.fftSize = 512,
    this.sampleRate = 48000.0,
  }) {
    assert((fftSize & (fftSize - 1)) == 0, 'fftSize deve essere una potenza di 2');
    _initHannWindow();
  }

  void _initHannWindow() {
    _window = Float64List(fftSize);
    for (int i = 0; i < fftSize; i++) {
      _window[i] = 0.5 * (1.0 - cos((2.0 * pi * i) / (fftSize - 1)));
    }
  }

  /// Calcola lo spettro in dBFS applicando la finestra di Hann e FFT Radix-2
  FFTSpectrumResult analyze(List<double> samples) {
    final int n = fftSize;
    final Float64List real = Float64List(n);
    final Float64List imag = Float64List(n);

    final int len = min(samples.length, n);
    for (int i = 0; i < len; i++) {
      real[i] = samples[i] * _window[i];
    }

    _radix2FFT(real, imag);

    final int half = n ~/ 2;
    final Float64List dbfs = Float64List(half);
    final double binHz = sampleRate / n;

    double maxDb = -120.0;
    double peakFreq = 0.0;

    for (int i = 0; i < half; i++) {
      final double r = real[i];
      final double im = imag[i];
      // Normalizzazione ampiezza
      final double mag = (2.0 * sqrt(r * r + im * im)) / n;

      // Conversione in dBFS con floor a -120 dBFS
      final double db = mag > 1e-6 ? 20.0 * (log(mag) / ln10) : -120.0;
      final double clampedDb = db.clamp(-120.0, 0.0);
      dbfs[i] = clampedDb;

      // Ignora componente continua DC (bin 0) per il calcolo del picco dominante
      if (i > 1 && clampedDb > maxDb) {
        maxDb = clampedDb;
        peakFreq = i * binHz;
      }
    }

    return FFTSpectrumResult(
      magnitudesDbfs: dbfs,
      peakFrequencyHz: peakFreq,
      peakMagnitudeDbfs: maxDb,
      binResolutionHz: binHz,
    );
  }

  /// Algoritmo Cooley-Tukey Radix-2 Decimation-in-Time FFT
  void _radix2FFT(Float64List real, Float64List imag) {
    final int n = real.length;

    // Bit reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final double tr = real[i];
        final double ti = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tr;
        imag[j] = ti;
      }
      int k = n >> 1;
      while (k <= j) {
        j -= k;
        k >>= 1;
      }
      j += k;
    }

    // Farfalle di calcolo (Butterfly computation)
    for (int len = 2; len <= n; len <<= 1) {
      final double angle = -2.0 * pi / len;
      final double wlenReal = cos(angle);
      final double wlenImag = sin(angle);

      final int halfLen = len >> 1;

      for (int i = 0; i < n; i += len) {
        double wReal = 1.0;
        double wImag = 0.0;

        for (int k = 0; k < halfLen; k++) {
          final int uIdx = i + k;
          final int vIdx = i + k + halfLen;

          final double vr = real[vIdx] * wReal - imag[vIdx] * wImag;
          final double vi = real[vIdx] * wImag + imag[vIdx] * wReal;

          real[vIdx] = real[uIdx] - vr;
          imag[vIdx] = imag[uIdx] - vi;
          real[uIdx] += vr;
          imag[uIdx] += vi;

          final double nextWReal = wReal * wlenReal - wImag * wlenImag;
          wImag = wReal * wlenImag + wImag * wlenReal;
          wReal = nextWReal;
        }
      }
    }
  }
}
