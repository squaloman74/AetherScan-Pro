import 'dart:math';
import 'baseline_engine.dart';

/// Classificazione deterministica e rigorosa dell'evento analizzato
enum TriggerClassification {
  /// Segnale nei limiti del rumore statistico ordinario (|Z| < zThreshold)
  none,

  /// Anomalia metrologica ambientale pura (|Z| >= 3.5 sigma, persistenza >= minDurationMs, nessun tocco)
  /// Registrata nel log forense CSV. NESSUN SUONO DI INTERAZIONE.
  environmentalAnomaly,

  /// Sollecitazione meccanica/urto sul telaio senza anomalia EMF contemporanea
  /// Segnalazione visiva di urto meccanico.
  mechanicalTouch,

  /// Transitorio impulsivo non persistente (spike isolato < minDurationMs) scartato
  transientSpike,

  /// COINCIDENZA DUAL-TRIGGER: Contatto/pressione fisica + Anomalia EMF convalidati contemporaneamente.
  dualTriggerInteraction,
}

/// Dati telemetrici istantanei forniti dai sensori hardware al trigger engine
class SensorReading {
  final DateTime timestamp;
  final double emfMagnitude; // in uT
  final double dynamicAcceleration; // in m/s2 (modulo accelerazione senza 1g)
  final double? pressureHpa; // in hPa (se disponibile)

  const SensorReading({
    required this.timestamp,
    required this.emfMagnitude,
    required this.dynamicAcceleration,
    this.pressureHpa,
  });
}

/// Risultato deterministico dell'elaborazione di un campione rispetto alla baseline
class TriggerResult {
  final DateTime timestamp;
  final TriggerClassification classification;

  // Metriche EMF
  final double rawEmf;
  final double deltaEmf;
  final double zScoreEmf;
  final double snrDbEmf;

  // Metriche Accelerometro / Contatto
  final double rawDynamicAccel;
  final double zScoreAccel;
  final bool isPhysicalTouch;

  // Persistenza
  final int persistenceMs;

  const TriggerResult({
    required this.timestamp,
    required this.classification,
    required this.rawEmf,
    required this.deltaEmf,
    required this.zScoreEmf,
    required this.snrDbEmf,
    required this.rawDynamicAccel,
    required this.zScoreAccel,
    required this.isPhysicalTouch,
    required this.persistenceMs,
  });

  bool get isDualTrigger => classification == TriggerClassification.dualTriggerInteraction;
  bool get isEnvironmentalAnomaly => classification == TriggerClassification.environmentalAnomaly;
  bool get isMechanicalTouch => classification == TriggerClassification.mechanicalTouch;
  bool get shouldTriggerAlarmSound => isDualTrigger;

  bool get isAnomaly => isDualTrigger || isEnvironmentalAnomaly;
  bool get isArtifact => isMechanicalTouch;
  bool get isBumpDetected => isPhysicalTouch;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'classification': classification.name,
      'emf': {
        'raw_uT': rawEmf,
        'delta_uT': deltaEmf,
        'z_score': zScoreEmf,
        'snr_db': snrDbEmf,
      },
      'vibration': {
        'raw_dynamic_ms2': rawDynamicAccel,
        'z_score': zScoreAccel,
        'is_touch': isPhysicalTouch,
      },
      'persistence_ms': persistenceMs,
      'alarm_triggered': shouldTriggerAlarmSound,
    };
  }
}

/// Motore deterministico basato su soglie statistiche e doppia validazione simultanea
class DeterministicTriggerEngine {
  final double zThreshold;
  final double touchAccelThreshold;
  final int minPersistenceMs;

  BaselineProfile? _baseline;
  DateTime? _spikeStartTime;
  int _consecutiveAnomalySamples = 0;

  DeterministicTriggerEngine({
    this.zThreshold = 3.5,
    this.touchAccelThreshold = 4.2,
    this.minPersistenceMs = 180,
    BaselineProfile? baseline,
  }) {
    _baseline = baseline;
  }

  int get consecutiveAnomalySamples => _consecutiveAnomalySamples;

  void setBaseline(BaselineProfile baseline) {
    _baseline = baseline;
    reset();
  }

  void reset() {
    _spikeStartTime = null;
    _consecutiveAnomalySamples = 0;
  }

  TriggerResult evaluate(SensorReading reading) {
    final base = _baseline;
    if (base == null || !base.isValid) {
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.none,
        rawEmf: reading.emfMagnitude,
        deltaEmf: 0.0,
        zScoreEmf: 0.0,
        snrDbEmf: 0.0,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: 0.0,
        isPhysicalTouch: false,
        persistenceMs: 0,
      );
    }

    final double deltaEmf = reading.emfMagnitude - base.emfMean;
    final double emfSd = max(base.emfStdDev, 0.25);
    final double zScoreEmf = deltaEmf / emfSd;

    final double snrDb = deltaEmf.abs() > 0.001
        ? 20.0 * (log(deltaEmf.abs() / emfSd) / ln10)
        : 0.0;

    final bool isEmfAnomaly = zScoreEmf.abs() >= zThreshold;

    final double vibSd = max(base.vibStdDev, 0.02);
    final double deltaVib = reading.dynamicAcceleration - base.vibMean;
    final double zScoreAccel = deltaVib / vibSd;
    final bool isTouchDetected = reading.dynamicAcceleration >= touchAccelThreshold;

    if (!isEmfAnomaly && !isTouchDetected) {
      _spikeStartTime = null;
      _consecutiveAnomalySamples = 0;
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.none,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isPhysicalTouch: false,
        persistenceMs: 0,
      );
    }

    if (!isEmfAnomaly && isTouchDetected) {
      _spikeStartTime = null;
      _consecutiveAnomalySamples = 0;
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.mechanicalTouch,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isPhysicalTouch: true,
        persistenceMs: 0,
      );
    }

    _spikeStartTime ??= reading.timestamp;
    _consecutiveAnomalySamples++;
    final int persistenceMs = reading.timestamp.difference(_spikeStartTime!).inMilliseconds;

    if (persistenceMs < minPersistenceMs) {
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.transientSpike,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isPhysicalTouch: isTouchDetected,
        persistenceMs: persistenceMs,
      );
    }

    if (isEmfAnomaly && isTouchDetected) {
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.dualTriggerInteraction,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isPhysicalTouch: true,
        persistenceMs: persistenceMs,
      );
    }

    return TriggerResult(
      timestamp: reading.timestamp,
      classification: TriggerClassification.environmentalAnomaly,
      rawEmf: reading.emfMagnitude,
      deltaEmf: deltaEmf,
      zScoreEmf: zScoreEmf,
      snrDbEmf: snrDb,
      rawDynamicAccel: reading.dynamicAcceleration,
      zScoreAccel: zScoreAccel,
      isPhysicalTouch: false,
      persistenceMs: persistenceMs,
    );
  }
}
