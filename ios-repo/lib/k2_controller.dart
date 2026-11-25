import 'package:flutter/foundation.dart';

/// Controller Modulare Indipendente per il K2 Field Meter (Zero-AI / Deterministico)
/// =================================================================================
/// Separa e isola la gestione del K2 dal motore dei trigger e dai log.
/// Applica smoothing e deadband per evitare oscillazioni quando il telefono e appoggiato
/// o impugnato, mantenendo reattivita ai campi elettronici fino alla saturazione (5 LED).
class K2Controller extends ChangeNotifier {
  double _currentEmf = 42.0;
  double _smoothedEmf = 42.0;
  double _baselineEmf = 42.0;
  bool _isAutoTared = false;
  bool _isActive = false;

  // Fattore EMA (0..1): piu basso = piu stabile/smorzato contro picchi impulsivi
  final double smoothingAlpha;

  // Zona morta (deadband in uT): assorbe micro-rumore di fondo e leggere oscillazioni in mano
  final double deadbandUt;

  K2Controller({
    double initialBaseline = 42.0,
    bool initiallyActive = false,
    this.smoothingAlpha = 0.22,
    this.deadbandUt = 1.2,
  })  : _currentEmf = initialBaseline,
        _smoothedEmf = initialBaseline,
        _baselineEmf = initialBaseline,
        _isActive = initiallyActive;

  double get currentEmf => _currentEmf;
  double get baselineEmf => _baselineEmf;
  bool get isAutoTared => _isAutoTared;
  bool get isActive => _isActive;

  /// Delta EMF filtrato e con deadband applicata per stabilizzare i LED
  double get deltaEmf {
    if (!_isActive) return 0.0;
    final rawDiff = _smoothedEmf - _baselineEmf;
    final absDiff = rawDiff.abs();
    if (absDiff <= deadbandUt) return 0.0;
    final sign = rawDiff >= 0 ? 1.0 : -1.0;
    return sign * (absDiff - deadbandUt);
  }

  /// Scala a 5 segmenti LED bilanciata:
  /// - 0 LED: Standby
  /// - LED 1: Normale / Appoggiato o mano ferma (< 2.5 uT netti dopo deadband) -> Verde NORM
  /// - LED 2: Variazione lieve (2.5 - 6.0 uT) -> Verde Chiaro LOW
  /// - LED 3: Campo misurabile (6.0 - 15.0 uT) -> Giallo MID
  /// - LED 4: Campo elevato (15.0 - 30.0 uT) -> Ambra HIGH
  /// - LED 5: Campo elettronico forte / Saturazione (>= 30.0 uT) -> Rosso MAX
  int get activeLedCount {
    if (!_isActive) return 0;
    final mag = deltaEmf.abs();
    if (mag >= 30.0) return 5;
    if (mag >= 15.0) return 4;
    if (mag >= 6.0) return 3;
    if (mag >= 2.5) return 2;
    return 1;
  }

  void ingestRawEmf(double rawMagnitude) {
    if (rawMagnitude.isNaN || rawMagnitude.isInfinite || rawMagnitude <= 0.0) return;

    _currentEmf = rawMagnitude;
    _smoothedEmf = (_smoothedEmf * (1.0 - smoothingAlpha)) + (rawMagnitude * smoothingAlpha);

    if (!_isActive) {
      notifyListeners();
      return;
    }

    if (!_isAutoTared) {
      _baselineEmf = _smoothedEmf;
      _isAutoTared = true;
    }

    notifyListeners();
  }

  void activate() {
    if (_isActive) return;
    _isActive = true;
    _smoothedEmf = _currentEmf;
    _baselineEmf = _smoothedEmf;
    _isAutoTared = true;
    notifyListeners();
  }

  void deactivate() {
    if (!_isActive) return;
    _isActive = false;
    notifyListeners();
  }

  void toggleActive() {
    if (_isActive) {
      deactivate();
    } else {
      activate();
    }
  }

  void tare([double? newReference]) {
    if (!_isActive) {
      _isActive = true;
    }
    final ref = newReference ?? _smoothedEmf;
    _smoothedEmf = ref;
    _baselineEmf = ref;
    _isAutoTared = true;
    notifyListeners();
  }

  void reset([double defaultReference = 42.0]) {
    _currentEmf = defaultReference;
    _smoothedEmf = defaultReference;
    _baselineEmf = defaultReference;
    _isAutoTared = false;
    notifyListeners();
  }
}
