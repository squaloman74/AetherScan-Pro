import 'package:flutter/foundation.dart';

/// Controller Modulare Indipendente per il K2 Field Meter (Zero-AI / Deterministico)
/// =================================================================================
/// Separa e isola totalmente la gestione del K2 dal motore dei trigger e dai log.
/// Risponde direttamente al flusso magnetico in microTesla (µT) e calcola in tempo reale
/// il delta e l'attivazione progressiva dei 5 segmenti LED fisici.
class K2Controller extends ChangeNotifier {
  double _currentEmf = 42.0;
  double _baselineEmf = 42.0;
  bool _isAutoTared = false;
  bool _isActive = false;

  K2Controller({double initialBaseline = 42.0, bool initiallyActive = false})
      : _currentEmf = initialBaseline,
        _baselineEmf = initialBaseline,
        _isActive = initiallyActive;

  double get currentEmf => _currentEmf;
  double get baselineEmf => _baselineEmf;
  double get deltaEmf => _isActive ? _currentEmf - _baselineEmf : 0.0;
  bool get isAutoTared => _isAutoTared;
  bool get isActive => _isActive;

  /// Scala classica K-II EMF Meter a 5 segmenti LED (in base a |ΔEMF| in µT):
  /// - 0 LED: Strumento inattivo / Standby
  /// - LED 1: Normale / Fondo (< 1.5 µT) -> Verde NORM (spia sempre attiva a regime)
  /// - LED 2: Fluttuazione Bassa (1.5 - 2.5 µT) -> Verde Chiaro LOW
  /// - LED 3: Anomalia Misurabile (2.5 - 10.0 µT) -> Giallo MID
  /// - LED 4: Campo Elevato (10.0 - 20.0 µT) -> Ambra HIGH
  /// - LED 5: Picco Massimo / Saturazione (>= 20.0 µT) -> Rosso MAX
  int get activeLedCount {
    if (!_isActive) return 0;
    final mag = deltaEmf.abs();
    if (mag >= 20.0) return 5;
    if (mag >= 10.0) return 4;
    if (mag >= 2.5) return 3;
    if (mag >= 1.5) return 2;
    return 1;
  }

  /// Ingestione diretta del campione magnetometrico reale (chiamata a ogni frame del sensore)
  void ingestRawEmf(double rawMagnitude) {
    if (rawMagnitude.isNaN || rawMagnitude.isInfinite || rawMagnitude <= 0.0) return;

    _currentEmf = rawMagnitude;

    // Se il K2 è in standby, memorizza l'ultima lettura senza alterare la tara
    if (!_isActive) {
      notifyListeners();
      return;
    }

    // Auto-tara iniziale trasparente al primissimo valore reale ricevuto dal sensore da attivo
    if (!_isAutoTared) {
      _baselineEmf = rawMagnitude;
      _isAutoTared = true;
    }

    notifyListeners();
  }

  /// Attiva il K2 Meter ed esegue la tara immediata sul valore EMF attuale
  void activate() {
    if (_isActive) return;
    _isActive = true;
    _baselineEmf = _currentEmf;
    _isAutoTared = true;
    notifyListeners();
  }

  /// Disattiva il K2 Meter (stato Standby / 0 LED attivi)
  void deactivate() {
    if (!_isActive) return;
    _isActive = false;
    notifyListeners();
  }

  /// Inverte lo stato di attivazione del K2
  void toggleActive() {
    if (_isActive) {
      deactivate();
    } else {
      activate();
    }
  }

  /// Esegue la tara rapida manuale (Zero-Calibration) fissando il valore attuale come nuovo zero
  void tare([double? newReference]) {
    if (!_isActive) {
      // Se era spento, la tara lo attiva sul valore richiesto
      _isActive = true;
    }
    _baselineEmf = newReference ?? _currentEmf;
    _isAutoTared = true;
    notifyListeners();
  }

  /// Reset della tara alla baseline di riferimento predefinita
  void reset([double defaultReference = 42.0]) {
    _baselineEmf = defaultReference;
    _isAutoTared = false;
    notifyListeners();
  }
}
