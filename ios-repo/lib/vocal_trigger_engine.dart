import 'metrology_lexicon.dart';
import 'investigative_lexicon.dart';
import 'names_lexicon.dart';

/// Banco lessicale attivo per il modulo vocale deterministico
enum VocalLexiconBank {
  /// Bank A: Vocabolario metrologico e fisico (128 termini)
  metrology,

  /// Bank B: Vocabolario investigativo classico sul campo (128 termini)
  investigative,

  /// Bank C: Anagrafico — Solo Nomi di battesimo (128 nomi, zero cognomi per privacy)
  names,

  /// Modalità combinata: selezione dinamica deterministica del banco basata sull'hash energetico
  rotational,
}

extension VocalLexiconBankExt on VocalLexiconBank {
  String get label {
    switch (this) {
      case VocalLexiconBank.metrology:
        return 'METR';
      case VocalLexiconBank.investigative:
        return 'INV';
      case VocalLexiconBank.names:
        return 'NOMI';
      case VocalLexiconBank.rotational:
        return 'AUTO';
    }
  }

  String get displayName {
    switch (this) {
      case VocalLexiconBank.metrology:
        return 'Bank A: Metrologico';
      case VocalLexiconBank.investigative:
        return 'Bank B: Investigativo';
      case VocalLexiconBank.names:
        return 'Bank C: Solo Nomi';
      case VocalLexiconBank.rotational:
        return 'Multi-Bank (Rotazione)';
    }
  }
}

/// Evento generato dal motore di risonanza vocale
class VocalTriggerEvent {
  /// Parola selezionata deterministicamente dal dizionario
  final String word;

  /// Banco lessicale di origine
  final VocalLexiconBank bank;

  /// Z-Score di attivazione al momento del trigger
  final double zScore;

  /// Delta EMF rispetto alla baseline (µT)
  final double deltaEmf;

  /// Accelerazione dinamica al momento del trigger (m/s²)
  final double dynamicAccel;

  /// Timestamp dell'emissione
  final DateTime timestamp;

  const VocalTriggerEvent({
    required this.word,
    this.bank = VocalLexiconBank.metrology,
    required this.zScore,
    required this.deltaEmf,
    required this.dynamicAccel,
    required this.timestamp,
  });

  @override
  String toString() =>
      'VocalTriggerEvent("${bank.label}:$word", Z=${zScore.toStringAsFixed(2)}, ΔEMF=${deltaEmf.toStringAsFixed(1)}µT)';
}

/// Motore Vocale Custom "Real-Trigger" Multi-Bank Deterministico (Zero-AI / Zero-Random)
/// ======================================================================================
/// Architettura modulare:
/// - Bank A: MetrologyLexicon.words (128 termini fisici/ambientali)
/// - Bank B: InvestigativeLexicon.words (128 termini investigativi sul campo)
/// - Bank C: NamesLexicon.words (128 soli nomi di battesimo, zero cognomi a tutela privacy)
/// - Modalità Rotational: rotazione deterministica tra i banchi basata sull'energia reale dei sensori.
class VocalTriggerEngine {
  /// Stato globale di abilitazione del modulo vocale (spento di default)
  bool isEnabled;

  /// Banco lessicale attualmente selezionato
  VocalLexiconBank currentBank;

  /// Soglia minima di deviazione statistica (|Z| >= 3.0σ)
  final double zScoreThreshold;

  /// Soglia minima assoluta di scostamento EMF (µT)
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
    this.currentBank = VocalLexiconBank.metrology,
    this.zScoreThreshold = 3.0,
    this.minDeltaEmf = 1.5,
    this.minPersistenceMs = 150,
    this.cooldownMs = 7000,
  });

  /// Dizionario Bank A predefinito per retrocompatibilità con test e logica legacy
  static const List<String> lexicon = MetrologyLexicon.words;

  /// Restituisce la lista di parole per il banco specificato
  static List<String> getWordsForBank(VocalLexiconBank bank) {
    switch (bank) {
      case VocalLexiconBank.metrology:
        return MetrologyLexicon.words;
      case VocalLexiconBank.investigative:
        return InvestigativeLexicon.words;
      case VocalLexiconBank.names:
        return NamesLexicon.words;
      case VocalLexiconBank.rotational:
        return MetrologyLexicon.words;
    }
  }

  /// Imposta il banco lessicale attivo
  void setBank(VocalLexiconBank bank) {
    currentBank = bank;
  }

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

  /// Valutazione deterministica in tempo reale con supporto Multi-Bank.
  /// Ritorna [VocalTriggerEvent] solo se:
  /// 1. Il modulo è abilitato (isEnabled == true).
  /// 2. Il periodo di cooldown (6-10s) è trascorso.
  /// 3. L'anomalia (|Z| >= soglia e |ΔEMF| >= soglia) persiste da almeno [minPersistenceMs] (150ms).
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
      // Condizione ambientale normale: reset contatore persistenza
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
      return null;
    }

    // 5. Risonanza deterministica: Spatial Energy Hash (Zero Random)
    final int zPart = (absZ * 1000.0).toInt().abs();
    final int emfPart = (absDelta * 100.0).toInt().abs();
    final int lorenzPart = (lorenzX.abs() * 10000.0).toInt().abs();
    final int freqPart = (currentFrequency * 10.0).toInt().abs();
    final int accelPart = (dynamicAccel * 100.0).toInt().abs();

    final int hash = (zPart ^ (emfPart * 31) ^ (lorenzPart * 127) ^ (freqPart * 7) ^ accelPart) & 0x7FFFFFFF;

    // 6. Selezione del Banco (Deterministica)
    final VocalLexiconBank effectiveBank;
    if (currentBank == VocalLexiconBank.rotational) {
      // Determina il banco in base all'hash dell'energia: rotazione deterministica su 3 banchi
      final int bankSelector = ((hash >> 16) ^ (hash & 0xFFFF)) % 3;
      switch (bankSelector) {
        case 0:
          effectiveBank = VocalLexiconBank.metrology;
          break;
        case 1:
          effectiveBank = VocalLexiconBank.investigative;
          break;
        default:
          effectiveBank = VocalLexiconBank.names;
          break;
      }
    } else {
      effectiveBank = currentBank;
    }

    final List<String> activeList = getWordsForBank(effectiveBank);
    final int index = hash % activeList.length;
    final String selectedWord = activeList[index];

    // 7. Registrazione stato ed emissione evento
    _lastSpokenTime = now;
    _anomalyStartTime = null;

    final event = VocalTriggerEvent(
      word: selectedWord,
      bank: effectiveBank,
      zScore: zScoreEmf,
      deltaEmf: deltaEmf,
      dynamicAccel: dynamicAccel,
      timestamp: now,
    );
    _lastTriggeredEvent = event;
    return event;
  }
}
