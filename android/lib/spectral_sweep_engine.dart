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

/// Motore di Scansione Spettrale AM/FM — DSP Caotico con Oscillatore di Lorenz
/// ============================================================================
/// REGOLA FERREA: ZERO rumore bianco piatto, ZERO dizionari, ZERO PRNG per il contenuto.
/// Il segnale audio è interamente sintetizzato dall'oscillatore caotico di Lorenz
/// (σ=10, ρ=28, β=8/3) perturbato in tempo reale dai sensori fisici (EMF + accelerometro).
/// Il filtro IIR Biquad passabanda ha cutoff e risonanza che inseguono dinamicamente
/// l'energia sensoriale ambientale, simulando la vera ricerca di frequenza eterea.
class SpectralSweepEngine {
  final double sampleRate;
  SweepBand band;
  SweepDirection direction;
  int sweepIntervalMs;

  double _currentFreq;
  DateTime? _lastSweepStepTime;

  // Parametri di banda AM
  static const double amMinKhz = 530.0;
  static const double amMaxKhz = 1600.0;
  static const double amStepKhz = 10.0;

  // Parametri di banda FM
  static const double fmMinMhz = 87.5;
  static const double fmMaxMhz = 108.0;
  static const double fmStepMhz = 0.1;

  // ── Stato oscillatore di Lorenz (persistente tra i frame) ──
  // Parametri classici: σ=10, ρ=28, β=8/3
  static const double _sigma = 10.0;
  static const double _rho   = 28.0;
  static const double _beta  = 8.0 / 3.0;

  double _lx = 0.1;   // condizione iniziale non-zero
  double _ly = 0.0;
  double _lz = 0.0;

  // ── Fase FM accumulata (campione-per-campione) ──
  double _fmPhase = 0.0;

  // ── Fase tremolo AM da accelerometro ──
  double _tremoloPhase = 0.0;

  // ── Stato filtro IIR Biquad passabanda ──
  double _bqX1 = 0.0, _bqX2 = 0.0;
  double _bqY1 = 0.0, _bqY2 = 0.0;
  double _bqB0 = 1.0, _bqB2 = -1.0;
  double _bqA1 = 0.0, _bqA2 = 0.0;

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

  void setDirection(SweepDirection newDirection) {
    direction = newDirection;
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

  /// Aggiorna i coefficienti del filtro IIR Biquad passabanda.
  /// Chiamato una volta per frame (non per ogni campione) per efficienza.
  void _updateBiquad(double cutHz, double q) {
    final double omega = 2.0 * pi * cutHz / sampleRate;
    final double sinW  = sin(omega);
    final double cosW  = cos(omega);
    final double alpha = sinW / (2.0 * q);
    final double a0inv = 1.0 / (1.0 + alpha);
    _bqB0 =  alpha * a0inv;
    _bqB2 = -alpha * a0inv;
    _bqA1 = -2.0 * cosW * a0inv;
    _bqA2 = (1.0 - alpha) * a0inv;
  }

  /// Elabora un frame audio — Oscillatore di Lorenz caotico modulato dai sensori.
  ///
  /// [deltaEmf]    : scostamento rispetto alla baseline EMF (µT) — perturbazione ρ
  /// [zScoreEmf]   : Z-score dell'anomalia EMF — controlla coupling e cutoff filtro
  /// [dynamicAccel]: sollecitazione accelerometro filtrata (m/s²) — tremolo AM e Q
  /// [bufferSize]  : campioni da generare (default 512, per l'analizzatore FFT)
  SweepFrame processFrame({
    required DateTime now,
    required double deltaEmf,
    required double zScoreEmf,
    required double dynamicAccel,
    int bufferSize = 512,
  }) {
    final double dt = 1.0 / sampleRate;

    // 1. Avanzamento timer di sweep deterministico
    if (_lastSweepStepTime == null) {
      _lastSweepStepTime = now;
    } else if (now.difference(_lastSweepStepTime!).inMilliseconds >= sweepIntervalMs) {
      _stepFrequency();
      _lastSweepStepTime = now;
    }

    // 2. S-Meter: intensità del segnale accoppiata ai sensori fisici
    final double absDelta  = deltaEmf.abs();
    final double excessVib = max(0.0, dynamicAccel - 0.05);
    final double rawDbm    = -115.0 + min(85.0, (absDelta * 2.5) + (excessVib * 4.0));
    final double signalDbm = rawDbm.clamp(-120.0, -20.0);
    final int sUnit        = ((signalDbm + 127.0) / 6.0).clamp(1.0, 9.0).toInt();

    // 3. Fattore di coupling sensoriale [0.0 – 1.0]
    final double coupling = min(1.0, (zScoreEmf.abs() / 4.0) + (dynamicAccel / 3.0));
    final bool isModulated = zScoreEmf.abs() >= 1.5 || dynamicAccel >= 0.5;

    // 4. Parametri DSP ricavati dai sensori
    // Frequenza portante eterodina: dalla sintonia corrente + deviazione EMF
    final double baseCarrierHz = band == SweepBand.fm
        ? 600.0 + ((_currentFreq - fmMinMhz) / (fmMaxMhz - fmMinMhz)) * 1400.0
        : 400.0 + ((_currentFreq - amMinKhz) / (amMaxKhz - amMinKhz)) * 1200.0;
    final double effectiveCarrierHz = (baseCarrierHz + deltaEmf * 12.0).clamp(200.0, 2800.0);

    // Deviazione FM dall'EMF (eterodina caotica): Hz per µT di campo
    final double emfFmShift = deltaEmf * 120.0;

    // Filtro Biquad dinamico: cutoff e Q inseguono l'energia sensoriale
    final double cutoffHz = (800.0 + zScoreEmf.abs() * 280.0).clamp(200.0, 3000.0);
    final double qFactor  = (1.5 + dynamicAccel * 2.5).clamp(0.5, 8.0);
    _updateBiquad(cutoffHz, qFactor);

    // Tremolo AM da accelerometro
    final double trRate  = (0.5 + dynamicAccel.abs() * 2.5).clamp(0.5, 6.0);
    final double trDepth = (0.15 + coupling * 0.45).clamp(0.15, 0.6);

    // Parametri Lorenz perturbati dall'EMF
    // ρ perturbato: anomalia EMF altera la divergenza del sistema caotico
    final double perturbedRho = (_rho + deltaEmf * 0.6).clamp(20.0, 36.0);

    // 5. Generazione buffer — Lorenz DSP campione-per-campione
    final Float64List buffer = Float64List(bufferSize);

    for (int i = 0; i < bufferSize; i++) {
      // ── Integrazione Lorenz (Runge-Kutta 4° ordine, h=dt) ──
      // k1
      final double k1x = _sigma * (_ly - _lx);
      final double k1y = _lx * (perturbedRho - _lz) - _ly;
      final double k1z = _lx * _ly - _beta * _lz;
      // k2
      final double lx2 = _lx + 0.5 * dt * k1x;
      final double ly2 = _ly + 0.5 * dt * k1y;
      final double lz2 = _lz + 0.5 * dt * k1z;
      final double k2x = _sigma * (ly2 - lx2);
      final double k2y = lx2 * (perturbedRho - lz2) - ly2;
      final double k2z = lx2 * ly2 - _beta * lz2;
      // k3
      final double lx3 = _lx + 0.5 * dt * k2x;
      final double ly3 = _ly + 0.5 * dt * k2y;
      final double lz3 = _lz + 0.5 * dt * k2z;
      final double k3x = _sigma * (ly3 - lx3);
      final double k3y = lx3 * (perturbedRho - lz3) - ly3;
      final double k3z = lx3 * ly3 - _beta * lz3;
      // k4
      final double lx4 = _lx + dt * k3x;
      final double ly4 = _ly + dt * k3y;
      final double lz4 = _lz + dt * k3z;
      final double k4x = _sigma * (ly4 - lx4);
      final double k4y = lx4 * (perturbedRho - lz4) - ly4;
      final double k4z = lx4 * ly4 - _beta * lz4;
      // Aggiorna stato
      _lx += dt / 6.0 * (k1x + 2 * k2x + 2 * k3x + k4x);
      _ly += dt / 6.0 * (k1y + 2 * k2y + 2 * k3y + k4y);
      _lz += dt / 6.0 * (k1z + 2 * k2z + 2 * k3z + k4z);

      // Normalizzazione Lorenz-X: attractor range ≈ ±20 → scala a [-1, +1]
      final double chaosRaw = (_lx / 20.0).clamp(-1.0, 1.0);

      // ── FM chaos: fase accumulata campione per campione ──
      _fmPhase += (effectiveCarrierHz + emfFmShift + chaosRaw * coupling * 180.0) * dt;
      if (_fmPhase > 1e6) _fmPhase -= 1e6;
      final double carrier = sin(2.0 * pi * _fmPhase);

      // ── Tremolo AM da accelerometro ──
      _tremoloPhase += trRate * dt;
      if (_tremoloPhase > 1e6) _tremoloPhase -= 1e6;
      final double tremolo = 1.0 - trDepth * (0.5 + 0.5 * sin(2.0 * pi * _tremoloPhase));

      // ── Miscela caos + carrier eterodinato ──
      // Senza modulazione attiva: solo rumore caotico puro (niente carrier fisso)
      // Con modulazione: il carrier eterodinato domina progressivamente
      final double mixed = isModulated
          ? (chaosRaw * (1.0 - coupling * 0.65) + carrier * coupling * 0.5) * tremolo
          : chaosRaw * 0.08 * tremolo; // fruscio caotico quieto di fondo

      // ── Filtro IIR Biquad passabanda ──
      final double filtered = _bqB0 * mixed + _bqB2 * _bqX2 - _bqA1 * _bqY1 - _bqA2 * _bqY2;
      _bqX2 = _bqX1; _bqX1 = mixed;
      _bqY2 = _bqY1; _bqY1 = filtered;

      buffer[i] = filtered.clamp(-1.0, 1.0);
    }

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
