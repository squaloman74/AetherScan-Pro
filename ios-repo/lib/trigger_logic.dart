import 'dart:math';
import 'baseline_engine.dart';

/// Classificazione deterministica dell'evento analizzato
enum TriggerClassification {
  /// Segnale nei limiti del rumore statistico ordinario (|Z| < zThreshold)
  none,

  /// Anomalia ambientale convalidata (|Z| >= zThreshold, persistenza >= minDurationMs, no bump)
  validAnomaly,

  /// Artefatto meccanico: deviazione dovuta a scuotimento o spostamento fisico dello strumento
  mechanicalArtifact,

  /// Transitorio impulsivo non persistente (spike isolato < minDurationMs)
  transientSpike,
}

/// Dati telemetrici istantanei forniti dai sensori hardware al trigger engine
class SensorReading {
  final DateTime timestamp;
  final double emfMagnitude; // in µT
  final double dynamicAcceleration; // in m/s² (modulo accelerazione senza 1g)
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

  // Metriche Accelerometro / Bump
  final double rawDynamicAccel;
  final double zScoreAccel;
  final bool isBumpDetected;

  // Persistenza
  final int persistenceMs;

  // Mappatura semantica deterministica (opzionale, basata su hash crittografico/CRC)
  final int? deterministicLemmaIndex;

  const TriggerResult({
    required this.timestamp,
    required this.classification,
    required this.rawEmf,
    required this.deltaEmf,
    required this.zScoreEmf,
    required this.snrDbEmf,
    required this.rawDynamicAccel,
    required this.zScoreAccel,
    required this.isBumpDetected,
    required this.persistenceMs,
    this.deterministicLemmaIndex,
  });

  bool get isAnomaly => classification == TriggerClassification.validAnomaly;
  bool get isArtifact => classification == TriggerClassification.mechanicalArtifact;

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
        'is_bump': isBumpDetected,
      },
      'persistence_ms': persistenceMs,
      'lemma_index': deterministicLemmaIndex,
    };
  }
}

/// Motore deterministico basato su soglie statistiche e filtro anti-bump
/// Totalmente esente da generatori casuali (PRNG).
class DeterministicTriggerEngine {
  final double zThreshold; // Soglia Z-Score (standard: 3.5 sigma)
  final double bumpZThreshold; // Soglia Z-Score vibrazione per rilevare urto/movimento (standard: 2.5 sigma)
  final int minPersistenceMs; // Durata minima continua dell'anomalia (standard: 150 ms)
  final int lemmaPoolSize; // Ampiezza del dizionario per mapping deterministico (default: 98)

  BaselineProfile? _baseline;
  DateTime? _spikeStartTime;
  int _consecutiveAnomalySamples = 0;

  DeterministicTriggerEngine({
    this.zThreshold = 3.5,
    this.bumpZThreshold = 2.5,
    this.minPersistenceMs = 150,
    this.lemmaPoolSize = 98,
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

  /// Valutazione deterministica in tempo reale del campione sensoriale
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
        isBumpDetected: false,
        persistenceMs: 0,
      );
    }

    // 1. Calcolo Z-Score e Delta per EMF
    final double deltaEmf = reading.emfMagnitude - base.emfMean;
    final double emfSd = max(base.emfStdDev, 0.01);
    final double zScoreEmf = deltaEmf / emfSd;

    // Rapporto Segnale-Rumore (SNR in dB): 20 * log10(|delta| / std_dev)
    final double snrDb = deltaEmf.abs() > 0.001
        ? 20.0 * (log(deltaEmf.abs() / emfSd) / ln10)
        : 0.0;

    // 2. Controllo Filtro Anti-Bump su Accelerometro
    final double vibSd = max(base.vibStdDev, 0.01);
    final double deltaVib = reading.dynamicAcceleration - base.vibMean;
    final double zScoreAccel = deltaVib / vibSd;
    final bool isBump = zScoreAccel.abs() >= bumpZThreshold;

    // 3. Valutazione Significatività Statistica (|Z| >= 3.5)
    final bool isStatisticallySignificant = zScoreEmf.abs() >= zThreshold;

    if (!isStatisticallySignificant) {
      _spikeStartTime = null;
      _consecutiveAnomalySamples = 0;
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: isBump ? TriggerClassification.mechanicalArtifact : TriggerClassification.none,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isBumpDetected: isBump,
        persistenceMs: 0,
      );
    }

    // Se c'è un bump dell'accelerometro contemporaneo all'anomalia, si classifica come artefatto
    if (isBump) {
      _spikeStartTime = null;
      _consecutiveAnomalySamples = 0;
      return TriggerResult(
        timestamp: reading.timestamp,
        classification: TriggerClassification.mechanicalArtifact,
        rawEmf: reading.emfMagnitude,
        deltaEmf: deltaEmf,
        zScoreEmf: zScoreEmf,
        snrDbEmf: snrDb,
        rawDynamicAccel: reading.dynamicAcceleration,
        zScoreAccel: zScoreAccel,
        isBumpDetected: true,
        persistenceMs: 0,
      );
    }

    // 4. Calcolo Persistenza Temporale
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
        isBumpDetected: false,
        persistenceMs: persistenceMs,
      );
    }

    // 5. Generazione Deterministica dell'indice lessicale (Anti-RNG)
    final int lemmaIdx = _computeDeterministicLemma(
      deltaEmf: deltaEmf,
      zScore: zScoreEmf,
      accel: reading.dynamicAcceleration,
      pressure: reading.pressureHpa ?? 1013.25,
      persistenceMs: persistenceMs,
    );

    return TriggerResult(
      timestamp: reading.timestamp,
      classification: TriggerClassification.validAnomaly,
      rawEmf: reading.emfMagnitude,
      deltaEmf: deltaEmf,
      zScoreEmf: zScoreEmf,
      snrDbEmf: snrDb,
      rawDynamicAccel: reading.dynamicAcceleration,
      zScoreAccel: zScoreAccel,
      isBumpDetected: false,
      persistenceMs: persistenceMs,
      deterministicLemmaIndex: lemmaIdx,
    );
  }

  /// Algoritmo di Hash Deterministico 32-bit (FNV-1a) per mappatura dei lemmi
  /// senza ricorrere a generatori casuali. Lo stesso vettore fisico genera sempre lo stesso indice.
  int _computeDeterministicLemma({
    required double deltaEmf,
    required double zScore,
    required double accel,
    required double pressure,
    required int persistenceMs,
  }) {
    if (lemmaPoolSize <= 0) return 0;

    // Codifica dei byte fisici
    final int b1 = (deltaEmf.abs() * 100).round() & 0xFFFFFFFF;
    final int b2 = (zScore.abs() * 1000).round() & 0xFFFFFFFF;
    final int b3 = (accel * 1000).round() & 0xFFFFFFFF;
    final int b4 = (pressure * 100).round() & 0xFFFFFFFF;
    final int b5 = persistenceMs & 0xFFFFFFFF;

    // FNV-1a 32-bit hash
    int hash = 0x811C9DC5;
    for (final v in [b1, b2, b3, b4, b5]) {
      hash ^= (v & 0xFF);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      hash ^= ((v >> 8) & 0xFF);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.abs() % lemmaPoolSize;
  }
}
