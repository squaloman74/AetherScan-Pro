import 'dart:math';
import 'dart:typed_data';

/// Banda di scansione radiofonica spettrale
enum SweepBand {
  /// Modulazione di Ampiezza (AM / Onde Medie): 530 kHz - 1600 kHz (passi da 10 kHz)
  am,

  /// Modulazione di Frequenza (FM / VHF): 87.5 MHz - 108.0 MHz (passi da 0.1 MHz)
  fm,
}

/// Direzione di scansione dello sweep
enum SweepDirection {
  forward,
  reverse,
  paused,
}

/// Risultato di un frame di scansione spettrale
class SweepFrame {
  final double currentFrequency; // in kHz (AM) o MHz (FM)
  final String frequencyDisplay;
  final SweepBand band;
  final double signalStrengthDbm; // S-Meter (-120 dBm a -20 dBm)
  final int sUnits; // S1 .. S9 + 30dB
  final double sensorCouplingFactor; // Modulazione reattiva fisica (0.0 a 1.0)
  final Float64List audioBuffer; // Buffer di 512 campioni generato fisicamente dal sensore
  final bool isModulatedBySensor;

  const SweepFrame({
    required this.currentFrequency,
    required this.frequencyDisplay,
    required this.band,
    required this.signalStrengthDbm,
    required this.sUnits,
    required this.sensorCouplingFactor,
    required this.audioBuffer,
    required this.isModulatedBySensor,
  });
}

/// Motore di Scansione Spettrale AM/FM Accoppiato ai Sensori Fisici
/// Regola fondamentale: ZERO DIZIONARI O GENERATORI CASUALI.
/// Il segnale e le modulazioni audio sono generati tramite DSP fisico deterministico
/// pilotato direttamente dalle variazioni reali di EMF, accelerometro e barometro.
class SpectralSweepEngine {
  final double sampleRate;
  SweepBand band;
  SweepDirection direction;
  int sweepIntervalMs; // Intervallo di salto frequenziale (es. 100 ms)

  double _currentFreq;
  double _phase = 0.0;
  DateTime? _lastSweepStepTime;

  // Parametri di banda AM
  static const double amMinKhz = 530.0;
  static const double amMaxKhz = 1600.0;
  static const double amStepKhz = 10.0;

  // Parametri di banda FM
  static const double fmMinMhz = 87.5;
  static const double fmMaxMhz = 108.0;
  static const double fmStepMhz = 0.1;

  SpectralSweepEngine({
    this.sampleRate = 48000.0,
    this.band = SweepBand.fm,
    this.direction = SweepDirection.forward,
    this.sweepIntervalMs = 100,
  }) : _currentFreq = band == SweepBand.fm ? fmMinMhz : amMinKhz;

  double get currentFrequency => _currentFreq;

  void setBand(SweepBand newBand) {
    if (band == newBand) return;
    band = newBand;
    _currentFreq = band == SweepBand.fm ? fmMinMhz : amMinKhz;
  }

  void setSweepInterval(int intervalMs) {
    sweepIntervalMs = intervalMs.clamp(30, 1000);
  }

  void toggleDirection() {
    if (direction == SweepDirection.forward) {
      direction = SweepDirection.reverse;
    } else if (direction == SweepDirection.reverse) {
      direction = SweepDirection.forward;
    }
  }

  void setPaused(bool paused) {
    if (paused) {
      direction = SweepDirection.paused;
    } else if (direction == SweepDirection.paused) {
      direction = SweepDirection.forward;
    }
  }

  /// Avanzamento deterministico della frequenza di sintonia
  void _stepFrequency() {
    if (direction == SweepDirection.paused) return;

    if (band == SweepBand.fm) {
      if (direction == SweepDirection.forward) {
        _currentFreq += fmStepMhz;
        if (_currentFreq > fmMaxMhz) _currentFreq = fmMinMhz;
      } else {
        _currentFreq -= fmStepMhz;
        if (_currentFreq < fmMinMhz) _currentFreq = fmMaxMhz;
      }
      _currentFreq = double.parse(_currentFreq.toStringAsFixed(1));
    } else {
      if (direction == SweepDirection.forward) {
        _currentFreq += amStepKhz;
        if (_currentFreq > amMaxKhz) _currentFreq = amMinKhz;
      } else {
        _currentFreq -= amStepKhz;
        if (_currentFreq < amMinKhz) _currentFreq = amMaxKhz;
      }
      _currentFreq = double.parse(_currentFreq.toStringAsFixed(0));
    }
  }

  /// Elabora un frame audio di scansione spettrale deterministica modulato dai sensori fisici.
  /// deltaEmf: scostamento rispetto alla baseline (uT)
  /// dynamicAccel: sollecitazione accelerometro (m/s²)
  /// bufferSize: campioni da generare per il frame (standard 512)
  SweepFrame processFrame({
    required DateTime now,
    required double deltaEmf,
    required double zScoreEmf,
    required double dynamicAccel,
    int bufferSize = 512,
  }) {
    // 1. Avanzamento del timer di sweep deterministico
    if (_lastSweepStepTime == null) {
      _lastSweepStepTime = now;
    } else if (now.difference(_lastSweepStepTime!).inMilliseconds >= sweepIntervalMs) {
      _stepFrequency();
      _lastSweepStepTime = now;
    }

    // 2. Calcolo dell'intensità del segnale (S-Meter dBm) accoppiata fisicamente ai sensori reali
    // Livello base del rumore atmosferico: -115 dBm
    // EMF anomaly incrementa proporzionalmente il segnale (fino a -30 dBm con forti campi)
    final double absDelta = deltaEmf.abs();
    final double excessVib = max(0.0, dynamicAccel - 0.05);
    final double rawDbm = -115.0 + min(85.0, (absDelta * 2.5) + (excessVib * 4.0));
    final double signalDbm = rawDbm.clamp(-120.0, -20.0);

    // Calcolo unità S (da S1 a S9, e oltre con +10dB, +20dB, +30dB)
    // In scala radioamatoriale standard: S9 corrisponde a -73 dBm, ogni unità S equivale a 6 dB
    final int sUnit = ((signalDbm + 127.0) / 6.0).clamp(1.0, 9.0).toInt();

    // 3. Fattore di accoppiamento reattivo sensoriale [0.0 - 1.0]
    final double coupling = min(1.0, (zScoreEmf.abs() / 4.0) + (dynamicAccel / 3.0));
    final bool isModulated = zScoreEmf.abs() >= 1.5 || dynamicAccel >= 0.5;

    // 4. Sintesi fisica deterministica del buffer audio (Zero campioni fasulli)
    final Float64List buffer = Float64List(bufferSize);

    // Frequenza eterodina di battimento radio: funzione diretta della frequenza di sintonia e del campo EMF
    final double baseCarrierHz = band == SweepBand.fm
        ? 600.0 + ((_currentFreq - fmMinMhz) / (fmMaxMhz - fmMinMhz)) * 1400.0
        : 400.0 + ((_currentFreq - amMinKhz) / (amMaxKhz - amMinKhz)) * 1200.0;

    // Il campo magnetico reale altera la risonanza eterodina
    final double effectivePitchHz = baseCarrierHz + (deltaEmf * 12.0);

    for (int i = 0; i < bufferSize; i++) {
      final double t = i / sampleRate;

      // Rumore atmosferico bianco filtrato (fondo naturale di banda)
      // Generazione deterministica basata su serie armonica trigonometrica (NO PRNG)
      final double atmosphericNoise = (sin(12345.67 * (_phase + t)) +
              sin(34567.89 * (_phase + t)) +
              sin(78912.34 * (_phase + t))) /
          3.0 * 0.08;

      // Tono eterodino / risonanza di canale quando c'è variazione fisica
      double modulatedSignal = 0.0;
      if (isModulated) {
        if (band == SweepBand.am) {
          // Modulazione di ampiezza: il campo EMF agisce come modulante di guadagno
          final double carrier = sin(2.0 * pi * effectivePitchHz * (_phase + t));
          final double modEnvelope = 1.0 + (0.5 * sin(2.0 * pi * 8.0 * (_phase + t)));
          modulatedSignal = carrier * modEnvelope * coupling * 0.25;
        } else {
          // Modulazione di frequenza: battimento spettrale a banda stretta
          final double instantFreq = effectivePitchHz + (sin(2.0 * pi * 15.0 * (_phase + t)) * 80.0 * coupling);
          modulatedSignal = sin(2.0 * pi * instantFreq * (_phase + t)) * coupling * 0.22;
        }
      }

      buffer[i] = (atmosphericNoise * (1.0 - (coupling * 0.5))) + modulatedSignal;
    }

    _phase += bufferSize / sampleRate;
    if (_phase > 1000.0) _phase = 0.0;

    final String freqStr = band == SweepBand.fm
        ? '${_currentFreq.toStringAsFixed(1)} MHz'
        : '${_currentFreq.toStringAsFixed(0)} kHz';

    return SweepFrame(
      currentFrequency: _currentFreq,
      frequencyDisplay: freqStr,
      band: band,
      signalStrengthDbm: signalDbm,
      sUnits: sUnit,
      sensorCouplingFactor: coupling,
      audioBuffer: buffer,
      isModulatedBySensor: isModulated,
    );
  }
}
