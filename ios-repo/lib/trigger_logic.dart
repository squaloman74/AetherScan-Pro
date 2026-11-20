import 'dart:math';
import 'baseline_engine.dart';

/// Classificazione deterministica e rigorosa dell'evento analizzato
enum TriggerClassification {
  /// Segnale nei limiti del rumore statistico ordinario (|Z| < zThreshold)
  none,

  /// Anomalia metrologica ambientale pura (|Z| >= 3.5σ, persistenza >= minDurationMs, nessun tocco)
  /// Registrata nel log forense CSV. NESSUN SUONO DI INTERAZIONE.
  environmentalAnomaly,

  /// Sollecitazione meccanica/urto sul telaio (|A_dyn| >= 3.2 m/s²) senza anomalia EMF contemporanea
  /// Segnalazione visiva di urto meccanico. NESSUN SUONO DI ALLARME.
  mechanicalTouch,

  /// Transitorio impulsivo non persistente (spike isolato < minDurationMs) scartato
  transientSpike,

  /// COINCIDENZA DUAL-TRIGGER: Contatto/pressione fisica (|A_dyn| >= 3.2 m/s²)
  /// + Anomalia EMF (|Z| >= 3.5σ) convalidati contemporaneamente.
  /// QUESTA È L'UNICA CONDIZIONE CHE ATTIVA IL SEGNALE ACUSTICO DI ALLARME.
  dualTriggerInteraction,
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

  /// True se è scattata l'interazione dual-trigger congiunta (Tocco + Anomalia Metrologica)
  bool get isDualTrigger => classification == TriggerClassification.dualTriggerInteraction;

  /// True se è presente un'anomalia ambientale pura (senza contatto fisico)
  bool get isEnvironmentalAnomaly => classification == TriggerClassification.environmentalAnomaly;

  /// True se è solo un contatto/urto meccanico senza variazione EMF
  bool get isMechanicalTouch => classification == TriggerClassification.mechanicalTouch;

  /// Condizione stringente per l'emissione del suono di allarme:
  /// SOLO E UNICAMENTE la coincidenza fisica dual-trigger!
  bool get shouldTriggerAlarmSound => isDualTrigger;

  /// Compatibilità con lo storico
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
/// Totalmente esente da generatori casuali (PRNG) e da dizionari fittizi.
class DeterministicTriggerEngine {
  final double zThreshold; // Soglia Z-Score (standard severo: 3.5 sigma, confidenza > 99.95%)
  final double touchAccelThreshold; // Soglia accelerazione dinamica per contatto/pressione (standard: 3.2 m/s²)
  final int minPersistenceMs; // Durata minima continua dell'anomalia EMF (standard: 150 ms)

  BaselineProfile? _baseline;
  DateTime? _spikeStartTime;
  int _consecutiveAnomalySamples = 0;

  DeterministicTriggerEngine({
    this.zThreshold = 3.5,
    this.touchAccelThreshold = 3.2,
    this.minPersistenceMs = 150,
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

  /// Valutazione deterministica in tempo reale con Logica di Doppia Validazione Simultanea
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

    // 1. Calcolo Z-Score e Delta per EMF (Condizione Metrologica)
    // Pavimento minimo a 0.2 µT coerente con il rumore termico/fisico dei magnetometri smartphone
    final double deltaEmf = reading.emfMagnitude - base.emfMean;
    final double emfSd = max(base.emfStdDev, 0.2);
    final double zScoreEmf = deltaEmf / emfSd;

    // Rapporto Segnale-Rumore (SNR in dB): 20 * log10(|delta| / std_dev)
    final double snrDb = deltaEmf.abs() > 0.001
        ? 20.0 * (log(deltaEmf.abs() / emfSd) / ln10)
        : 0.0;

    // Condizione 2 (Anomalia Metrologica Severa: |Z| >= 3.5σ)
    final bool isEmfAnomaly = zScoreEmf.abs() >= zThreshold;

    // 2. Controllo Contatto/Pressione Meccanica sul Telaio (Condizione 1: |A_dyn| >= 3.2 m/s²)
    final double vibSd = max(base.vibStdDev, 0.01);
    final double deltaVib = reading.dynamicAcceleration - base.vibMean;
    final double zScoreAccel = deltaVib / vibSd;
    final bool isTouchDetected = reading.dynamicAcceleration >= touchAccelThreshold;

    // CASO A: Segnale ordinario (né anomalia metrologica né tocco)
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

    // CASO B: Solo tocco/sollecitazione meccanica SENZA anomalia EMF contemporanea
    // -> Segnala "Urto Meccanico" sul display, NESSUN SUONO DI ALLARME emesso.
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

    // Calcolo persistenza temporale per verificare che l'anomalia EMF non sia uno spike transitorio
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

    // CASO C: TOCCO FISICO + ANOMALIA METROLOGICA EMF SIMULTANEI
    // -> Verificate contemporaneamente entrambe le condizioni fisiche!
    // -> QUESTA È L'UNICA CONDIZIONE CHE SCATENA IL SEGNALE DI ALLARME ACUSTICO PERSONALIZZATO!
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

    // CASO D: Solo anomalia EMF SENZA tocco fisico (|Z| >= 3.5σ ma telefono immobile)
    // -> Registra nel log forense CSV come misurazione ambientale pura, NESSUN SUONO DI ALLARME CONTATTO.
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
