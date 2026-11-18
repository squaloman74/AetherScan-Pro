import 'dart:math';

/// Evento generato dal motore di risonanza vocale
class VocalTriggerEvent {
  /// Parola selezionata deterministicamente dal dizionario
  final String word;

  /// Z-Score di attivazione al momento del trigger
  final double zScore;

  /// Delta EMF rispetto alla baseline (ÂµT)
  final double deltaEmf;

  /// Accelerazione dinamica al momento del trigger (m/sÂ²)
  final double dynamicAccel;

  /// Timestamp dell'emissione
  final DateTime timestamp;

  const VocalTriggerEvent({
    required this.word,
    required this.zScore,
    required this.deltaEmf,
    required this.dynamicAccel,
    required this.timestamp,
  });

  @override
  String toString() =>
      'VocalTriggerEvent("$word", Z=${zScore.toStringAsFixed(2)}, Î”EMF=${deltaEmf.toStringAsFixed(1)}ÂµT)';
}

/// Motore Vocale Custom "Real-Trigger" Deterministico (No-Whisper / No-AI pesante)
/// ==============================================================================
/// Regole ferree:
/// 1. Zero carico pesante: nessuna rete neurale, nessun server esterno, <2MB RAM.
/// 2. Zero parole a caso: nessun Random() o allucinazione probabilistica.
/// 3. Attivazione reale su soglia energetica (|Z| >= 3.0 e persistenza temporale >= 150ms).
/// 4. Indirizzamento matematico deterministico nel dizionario via Spatial Energy Hash.
/// 5. Spento di default (isEnabled = false) con cooldown refrattario (6-10s).
class VocalTriggerEngine {
  /// Stato globale di abilitazione del modulo vocale (spento di default)
  bool isEnabled;

  /// Soglia minima di deviazione statistica (|Z| >= 3.0Ïƒ)
  final double zScoreThreshold;

  /// Soglia minima assoluta di scostamento EMF (ÂµT)
  final double minDeltaEmf;

  /// Tempo di persistenza minima dell'anomalia prima di convalidare l'emissione (ms)
  final int minPersistenceMs;

  /// Periodo refrattario di cooldown tra un'emissione vocale e la successiva (ms)
  final int cooldownMs;

  // Stato temporale interno per la macchina a stati
  DateTime? _anomalyStartTime;
  DateTime? _lastSpokenTime;
  VocalTriggerEvent? _lastTriggeredEvent;

  /// Ultimo evento vocale emesso con successo
  VocalTriggerEvent? get lastTriggeredEvent => _lastTriggeredEvent;

  /// Ultima parola pronunciata
  String? get lastWord => _lastTriggeredEvent?.word;

  VocalTriggerEngine({
    this.isEnabled = false,
    this.zScoreThreshold = 3.0,
    this.minDeltaEmf = 1.5,
    this.minPersistenceMs = 150,
    this.cooldownMs = 7000,
  });

  /// Dizionario deterministico calibrato (128 parole esatte di fisica, metrologia e indagine)
  static const List<String> lexicon = [
    'PRESENZA', 'ENERGIA', 'CAMPO', 'FLUSSO', 'SOGLIA', 'OMBRA', 'ONDA', 'CONTATTO',
    'FREQUENZA', 'RISUONATORE', 'PORTALE', 'ECO', 'RADIAZIONE', 'SEGNALE', 'POLARITA', 'MEMORIA',
    'CORRENTE', 'VORTICE', 'LINEA', 'DISTORSIONE', 'ANOMALIA', 'PULSAZIONE', 'STATO', 'SPOSTAMENTO',
    'ARIA', 'COLPO', 'ATTESA', 'MOVIMENTO', 'CENTRO', 'VICINO', 'DISTANTE', 'PROFONDO',
    'RISPOSTA', 'VOCE', 'RESPIRO', 'PESO', 'DIREZIONE', 'TEMPO', 'INTENSITA', 'FASCIO',
    'ATTRAVERSAMENTO', 'RIFLESSO', 'VUOTO', 'FREDDO', 'CALORE', 'GRADIENTE', 'EQUILIBRIO', 'ROTTURA',
    'TRACCIA', 'IMPRONTA', 'ORIGINE', 'LIMITE', 'SISTEMA', 'FONTE', 'INTERFERENZA', 'SPECCHIO',
    'SILENZIO', 'SUONO', 'IMPATTO', 'DERIVA', 'MASSA', 'VETTORE', 'DIMENSIONE', 'RITORNO',
    'SCONOSCIUTO', 'CONFINE', 'FLUTTUAZIONE', 'AMPIEZZA', 'FASE', 'CONVERGENZA', 'NUCLEO', 'SPETTRO',
    'ATTIVAZIONE', 'SPAZIO', 'SENSORE', 'CONTORNO', 'STRUTTURA', 'LUCE', 'INVISIBILE', 'PASSO',
    'BATTITO', 'DISTACCO', 'CARICA', 'POTENZIALE', 'LEGATA', 'SEPARAZIONE', 'EMERSIONE', 'CONNESSO',
    'ATTRAZIONE', 'RESPINTA', 'VARIAZIONE', 'NOTTE', 'FORMA', 'RESTO', 'FERMO', 'DISPERSIONE',
    'VIBRAZIONE', 'TENSIONE', 'RESISTENZA', 'ISOLAMENTO', 'CADUTA', 'VELOCITA', 'ASCESA', 'CONFINI',
    'RESTANTE', 'DILATAZIONE', 'CONDENSATO', 'PUNTO', 'NODI', 'CIRCUITO', 'SECONDO', 'PRIMO',
    'ESTERNO', 'INTERNO', 'MATERIA', 'ANTICO', 'SOTTILE', 'OSCURO', 'CHIARO', 'DEFINITO',
    'CONTINUO', 'INTERROTTO', 'REALE', 'ETERE', 'CORPO', 'SPINTA', 'INCLINAZIONE', 'FERMA',
  ];

  /// Abilita o disabilita il modulo vocale
  void setEnabled(bool enabled) {
    if (isEnabled == enabled) return;
    isEnabled = enabled;
    if (!isEnabled) {
      reset();
    }
  }

  /// Reimposta i timer di persistenza e cooldown
  void reset() {
    _anomalyStartTime = null;
    _lastSpokenTime = null;
  }

  /// Valutazione deterministica in tempo reale.
  /// Ritorna [VocalTriggerEvent] solo se:
  /// 1. Il modulo Ã¨ abilitato (isEnabled == true).
  /// 2. Il periodo di cooldown (6-10s) Ã¨ trascorso.
  /// 3. L'anomalia (|Z| >= soglia e |Î”EMF| >= soglia) persiste da almeno [minPersistenceMs] (150ms).
  VocalTriggerEvent? evaluate({
    required DateTime now,
    required double deltaEmf,
    required double zScoreEmf,
    required double dynamicAccel,
    required double lorenzX,
    required double currentFrequency,
  }) {
    // 1. Blindatura: se spento, ritorna immediatamente senza calcoli
    if (!isEnabled) {
      _anomalyStartTime = null;
      return null;
    }

    // 2. Cooldown refrattario: blocca qualsiasi emissione successiva
    if (_lastSpokenTime != null &&
        now.difference(_lastSpokenTime!).inMilliseconds < cooldownMs) {
      _anomalyStartTime = null;
      return null;
    }

    // 3. Verifica della soglia energetica reale
    final double absZ = zScoreEmf.abs();
    final double absDelta = deltaEmf.abs();
    final bool isAnomalyActive = absZ >= zScoreThreshold && absDelta >= minDeltaEmf;

    if (!isAnomalyActive) {
      // Condizione ambientale normale: reset del contatore di persistenza
      _anomalyStartTime = null;
      return null;
    }

    // 4. Filtro di persistenza temporale (almeno 150ms continui di anomalia)
    if (_anomalyStartTime == null) {
      _anomalyStartTime = now;
      return null;
    }

    final int durationMs = now.difference(_anomalyStartTime!).inMilliseconds;
    if (durationMs < minPersistenceMs) {
      // L'anomalia non Ã¨ ancora sufficientemente stabile
      return null;
    }

    // 5. Risonanza deterministica: Spatial Energy Hash (Zero Random)
    // Trasforma le grandezze fisiche dell'anomalia in un indice esatto del dizionario
    final int zPart = (absZ * 1000.0).toInt().abs();
    final int emfPart = (absDelta * 100.0).toInt().abs();
    final int lorenzPart = (lorenzX.abs() * 10000.0).toInt().abs();
    final int freqPart = (currentFrequency * 10.0).toInt().abs();
    final int accelPart = (dynamicAccel * 100.0).toInt().abs();

    // Funzione hash deterministica a 31-bit
    final int hash = (zPart ^ (emfPart * 31) ^ (lorenzPart * 127) ^ (freqPart * 7) ^ accelPart) & 0x7FFFFFFF;
    final int index = hash % lexicon.length;
    final String selectedWord = lexicon[index];

    // 6. Registrazione stato ed emissione evento
    _lastSpokenTime = now;
    _anomalyStartTime = null;

    final event = VocalTriggerEvent(
      word: selectedWord,
      zScore: zScoreEmf,
      deltaEmf: deltaEmf,
      dynamicAccel: dynamicAccel,
      timestamp: now,
    );
    _lastTriggeredEvent = event;
    return event;
  }
}
