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

  K2Controller({double initialBaseline = 42.0})
      : _currentEmf = initialBaseline,
        _baselineEmf = initialBaseline;

  double get currentEmf => _currentEmf;
  double get baselineEmf => _baselineEmf;
  double get deltaEmf => _currentEmf - _baselineEmf;
  bool get isAutoTared => _isAutoTared;

  /// Scala classica K-II EMF Meter a 5 segmenti LED (in base a |ΔEMF| in µT):
  /// - LED 1: Normale / Fondo (< 1.5 µT) -> Verde NORM (spia sempre attiva)
  /// - LED 2: Fluttuazione Bassa (1.5 - 2.5 µT) -> Verde Chiaro LOW
  /// - LED 3: Anomalia Misurabile (2.5 - 10.0 µT) -> Giallo MID
  /// - LED 4: Campo Elevato (10.0 - 20.0 µT) -> Ambra HIGH
  /// - LED 5: Picco Massimo / Saturazione (>= 20.0 µT) -> Rosso MAX
  int get activeLedCount {
    final mag = deltaEmf.abs();
    if (mag >= 20.0) return 5;
    if (mag >= 10.0) return 4;
    if (mag >= 2.5) return 3;
    if (mag >= 1.5) return 2;
    return 1;
  }

  /// Ingestione diretta del campione magnetometrico reale (chiamata a ogni frame del sensore)
  void ingestRawEmf(double rawMagnitude) {
    _currentEmf = rawMagnitude;

    // Auto-tara iniziale trasparente al primissimo valore reale ricevuto dal sensore
    if (!_isAutoTared) {
      _baselineEmf = rawMagnitude;
      _isAutoTared = true;
    }

    notifyListeners();
  }

  /// Esegue la tara rapida manuale (Zero-Calibration) fissando il valore attuale come nuovo zero
  void tare([double? newReference]) {
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
