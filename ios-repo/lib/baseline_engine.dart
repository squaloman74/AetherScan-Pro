import 'dart:async';
import 'dart:math';

/// Stato di calibrazione dell'Environmental Baseline Engine
enum CalibrationStatus {
  idle,
  calibrating,
  calibrated,
  cancelled,
}

/// Accumulatore on-line basato sull'algoritmo di B. P. Welford (1962).
/// Consente di calcolare media, varianza e deviazione standard in un singolo passaggio
/// con complessità spaziale O(1) e stabilità numerica elevata.
class WelfordAccumulator {
  int _count = 0;
  double _mean = 0.0;
  double _m2 = 0.0;
  double _min = double.infinity;
  double _max = -double.infinity;

  WelfordAccumulator();

  int get count => _count;
  double get mean => _count > 0 ? _mean : 0.0;
  double get min => _count > 0 ? _min : 0.0;
  double get max => _count > 0 ? _max : 0.0;

  /// Varianza campionaria corretta (Bessel's correction n - 1)
  double get variance => _count > 1 ? _m2 / (_count - 1) : 0.0;

  /// Deviazione standard campionaria
  double get standardDeviation => sqrt(variance);

  /// Errore standard della media
  double get standardError => _count > 0 ? standardDeviation / sqrt(_count) : 0.0;

  /// Inserimento di un nuovo campione nel flusso
  void update(double value) {
    _count++;
    if (value < _min) _min = value;
    if (value > _max) _max = value;

    final double delta = value - _mean;
    _mean += delta / _count;
    final double delta2 = value - _mean;
    _m2 += delta * delta2;
  }

  /// Calcolo del punteggio standardizzato (Z-Score) rispetto alla distribuzione accumulata
  double zScore(double value, {double epsilon = 1e-6}) {
    final sd = standardDeviation;
    if (sd < epsilon) return 0.0;
    return (value - _mean) / sd;
  }

  /// Reset dell'accumulatore
  void reset() {
    _count = 0;
    _mean = 0.0;
    _m2 = 0.0;
    _min = double.infinity;
    _max = -double.infinity;
  }
}

/// Snapshot immutabile dei parametri ambientali calcolati al termine della calibrazione
class BaselineProfile {
  final DateTime calibratedAt;
  final Duration duration;
  final int totalSamples;

  // EMF (Microtesla µT)
  final double emfMean;
  final double emfStdDev;
  final double emfMin;
  final double emfMax;

  // Vibrazione Dinamica / Accelerazione (m/s²)
  final double vibMean;
  final double vibStdDev;
  final double vibMax;

  // Pressione Barometrica (hPa)
  final double baroMean;
  final double baroStdDev;
  final double baroMin;
  final double baroMax;

  const BaselineProfile({
    required this.calibratedAt,
    required this.duration,
    required this.totalSamples,
    required this.emfMean,
    required this.emfStdDev,
    required this.emfMin,
    required this.emfMax,
    required this.vibMean,
    required this.vibStdDev,
    required this.vibMax,
    required this.baroMean,
    required this.baroStdDev,
    required this.baroMin,
    required this.baroMax,
  });

  /// Indica se il profilo è statisticamente affidabile (almeno 50 campioni per sensore)
  bool get isValid => totalSamples >= 50 && emfStdDev >= 0.0 && vibStdDev >= 0.0;

  Map<String, dynamic> toMap() {
    return {
      'calibrated_at': calibratedAt.toIso8601String(),
      'duration_sec': duration.inSeconds,
      'total_samples': totalSamples,
      'emf': {
        'mean_uT': emfMean,
        'std_dev_uT': emfStdDev,
        'min_uT': emfMin,
        'max_uT': emfMax,
      },
      'vibration': {
        'mean_ms2': vibMean,
        'std_dev_ms2': vibStdDev,
        'max_ms2': vibMax,
      },
      'barometer': {
        'mean_hPa': baroMean,
        'std_dev_hPa': baroStdDev,
        'min_hPa': baroMin,
        'max_hPa': baroMax,
      },
      'is_valid': isValid,
    };
  }
}

/// Motore di calibrazione iniziale dell'ambiente (30 secondi)
class BaselineEngine {
  final Duration targetDuration;
  final WelfordAccumulator _emfAcc = WelfordAccumulator();
  final WelfordAccumulator _vibAcc = WelfordAccumulator();
  final WelfordAccumulator _baroAcc = WelfordAccumulator();

  CalibrationStatus _status = CalibrationStatus.idle;
  DateTime? _startTime;
  Timer? _countdownTimer;

  // Callback / Notifiche di progresso
  void Function(double progress, int remainingSeconds)? onProgress;
  void Function(BaselineProfile profile)? onComplete;
  void Function(String reason)? onCancelled;

  BaselineProfile? _activeProfile;

  BaselineEngine({
    this.targetDuration = const Duration(seconds: 30),
    this.onProgress,
    this.onComplete,
    this.onCancelled,
  });

  CalibrationStatus get status => _status;
  bool get isCalibrating => _status == CalibrationStatus.calibrating;
  bool get isCalibrated => _status == CalibrationStatus.calibrated;
  BaselineProfile? get activeProfile => _activeProfile;

  // Lettura istantanea degli accumulatori attivi
  WelfordAccumulator get emfAccumulator => _emfAcc;
  WelfordAccumulator get vibrationAccumulator => _vibAcc;
  WelfordAccumulator get barometerAccumulator => _baroAcc;

  /// Avvia la sessione di calibrazione di 30 secondi
  void startCalibration() {
    _resetInternal();
    _status = CalibrationStatus.calibrating;
    _startTime = DateTime.now();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_status != CalibrationStatus.calibrating || _startTime == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_startTime!);
      final double progress = (elapsed.inMilliseconds / targetDuration.inMilliseconds).clamp(0.0, 1.0);
      final int remainingSec = max(0, targetDuration.inSeconds - elapsed.inSeconds);

      onProgress?.call(progress, remainingSec);

      if (elapsed >= targetDuration) {
        timer.cancel();
        _finalizeCalibration();
      }
    });
  }

  /// Ingestione campione magnetometro (modulo campo tridimensionale in µT)
  void ingestEmf(double bx, double by, double bz) {
    if (_status != CalibrationStatus.calibrating) return;
    final magnitude = sqrt(bx * bx + by * by + bz * bz);
    _emfAcc.update(magnitude);
  }

  /// Ingestione diretta modulo EMF già computato
  void ingestEmfMagnitude(double magnitude) {
    if (_status != CalibrationStatus.calibrating) return;
    _emfAcc.update(magnitude);
  }

  /// Ingestione campione accelerometro dinamico (esclusa la gravità 1g)
  void ingestVibration(double dynamicAx, double dynamicAy, double dynamicAz) {
    if (_status != CalibrationStatus.calibrating) return;
    final magnitude = sqrt(dynamicAx * dynamicAx + dynamicAy * dynamicAy + dynamicAz * dynamicAz);
    _vibAcc.update(magnitude);
  }

  /// Ingestione campione pressione barometrica (hPa)
  void ingestPressure(double hPa) {
    if (_status != CalibrationStatus.calibrating) return;
    _baroAcc.update(hPa);
  }

  /// Annullamento manuale della calibrazione
  void cancelCalibration({String reason = 'Calibrazione interrotta manualmente'}) {
    _countdownTimer?.cancel();
    _status = CalibrationStatus.cancelled;
    onCancelled?.call(reason);
  }

  /// Esegue una tara rapida istantanea sul valore EMF corrente (Zero-Calibration),
  /// aggiornando o impostando deterministicamente il riferimento di base senza attendere i 30 secondi.
  BaselineProfile applyQuickTare(double currentEmfMagnitude, {double defaultStdDev = 1.0, bool notifyComplete = false}) {
    _countdownTimer?.cancel();
    _status = CalibrationStatus.calibrated;
    final now = DateTime.now();
    final prev = _activeProfile;
    final stdDev = (prev != null && prev.emfStdDev > 0) ? prev.emfStdDev : defaultStdDev;

    _activeProfile = BaselineProfile(
      calibratedAt: now,
      duration: prev?.duration ?? Duration.zero,
      totalSamples: (prev?.totalSamples ?? 0) + 1,
      emfMean: currentEmfMagnitude,
      emfStdDev: stdDev,
      emfMin: prev != null ? min(prev.emfMin, currentEmfMagnitude) : currentEmfMagnitude,
      emfMax: prev != null ? max(prev.emfMax, currentEmfMagnitude) : currentEmfMagnitude,
      vibMean: prev?.vibMean ?? 0.04,
      vibStdDev: prev?.vibStdDev ?? 0.01,
      vibMax: prev?.vibMax ?? 0.10,
      baroMean: prev?.baroMean ?? 1013.25,
      baroStdDev: prev?.baroStdDev ?? 0.05,
      baroMin: prev?.baroMin ?? 1013.25,
      baroMax: prev?.baroMax ?? 1013.25,
    );

    if (notifyComplete) {
      onComplete?.call(_activeProfile!);
    }
    return _activeProfile!;
  }

  /// Conclusione della calibrazione e generazione del profilo baseline
  void _finalizeCalibration() {
    _status = CalibrationStatus.calibrated;
    final now = DateTime.now();
    final duration = _startTime != null ? now.difference(_startTime!) : targetDuration;

    final double safeEmfMean = _emfAcc.count > 0 ? _emfAcc.mean : (_activeProfile?.emfMean ?? 42.0);
    final double safeEmfStdDev = (_emfAcc.count > 1 && _emfAcc.standardDeviation > 0.05)
        ? _emfAcc.standardDeviation
        : 2.0;
    final double safeEmfMin = _emfAcc.count > 0 ? _emfAcc.min : safeEmfMean;
    final double safeEmfMax = _emfAcc.count > 0 ? _emfAcc.max : safeEmfMean;

    final double safeVibMean = _vibAcc.count > 0 ? _vibAcc.mean : 0.04;
    final double safeVibStdDev = (_vibAcc.count > 1 && _vibAcc.standardDeviation > 0.005)
        ? _vibAcc.standardDeviation
        : 0.01;
    final double safeVibMax = _vibAcc.count > 0 ? _vibAcc.max : 0.10;

    _activeProfile = BaselineProfile(
      calibratedAt: now,
      duration: duration,
      totalSamples: _emfAcc.count,
      emfMean: safeEmfMean,
      emfStdDev: safeEmfStdDev,
      emfMin: safeEmfMin,
      emfMax: safeEmfMax,
      vibMean: safeVibMean,
      vibStdDev: safeVibStdDev,
      vibMax: safeVibMax,
      baroMean: _baroAcc.count > 0 ? _baroAcc.mean : 1013.25,
      baroStdDev: _baroAcc.count > 0 ? _baroAcc.standardDeviation : 0.05,
      baroMin: _baroAcc.count > 0 ? _baroAcc.min : 1013.25,
      baroMax: _baroAcc.count > 0 ? _baroAcc.max : 1013.25,
    );

    onComplete?.call(_activeProfile!);
  }

  void _resetInternal() {
    _countdownTimer?.cancel();
    _emfAcc.reset();
    _vibAcc.reset();
    _baroAcc.reset();
    _activeProfile = null;
  }

  /// Ricalibrazione o reset completo
  void reset() {
    _resetInternal();
    _status = CalibrationStatus.idle;
  }
}
