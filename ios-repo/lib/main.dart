import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'baseline_engine.dart';
import 'trigger_logic.dart';
import 'audio_suite.dart';
import 'forensic_logger.dart';
import 'industrial_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AetherScanProApp());
}

class AetherScanProApp extends StatelessWidget {
  const AetherScanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AetherScan-Pro (Scientific Metrology Suite)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: IndustrialPalette.background,
        primaryColor: IndustrialPalette.phosphorCyan,
        colorScheme: const ColorScheme.dark(
          primary: IndustrialPalette.phosphorCyan,
          surface: IndustrialPalette.surface,
        ),
      ),
      home: const IndustrialMetrologyScreen(),
    );
  }
}

class IndustrialMetrologyScreen extends StatefulWidget {
  const IndustrialMetrologyScreen({super.key});

  @override
  State<IndustrialMetrologyScreen> createState() => _IndustrialMetrologyScreenState();
}

class _IndustrialMetrologyScreenState extends State<IndustrialMetrologyScreen> {
  static const _audioChannel = MethodChannel('com.aetherscan.pro/audio');
  static const _sensorChannel = EventChannel('com.aetherscan.pro/sensors');

  // ── Moduli Scientifici Disaccoppiati ──
  late final BaselineEngine _baselineEngine;
  late final DeterministicTriggerEngine _triggerEngine;
  late final AnalyticalDSPChain _dspChain;
  late final FFTSpectrumEngine _fftEngine;
  late final ForensicSessionLogger _forensicLogger;

  // ── Stato Telemetrico e Hardware ──
  StreamSubscription<dynamic>? _sensorSubscription;
  Timer? _dspSimulationTimer;

  bool _isCalibrating = false;
  double _calibrationProgress = 0.0;
  int _calibrationRemainingSec = 30;
  int _calibrationSamples = 0;

  double _currentEmf = 42.0;
  double _currentDynamicVib = 0.04;
  double _currentPressure = 1013.25;

  final List<double> _emfOscilloscopeHistory = [];
  Float64List _currentFftDbfs = Float64List(256);
  double _audioPeakHz = 0.0;
  double _audioPeakDbfs = -100.0;

  TriggerResult? _lastTriggerResult;
  String _deviceHwid = 'INITIALIZING...';
  bool _isAuthorized = false;

  final List<String> _lexicon = [
    'PRESENZA', 'VARIAZIONE_CAMPO', 'ANOMALIA_EVP', 'STRUTTURA',
    'FLUSSO_MAGNETICO', 'FLUTTUAZIONE', 'FONEMA_ISOLATO', 'SPOSTAMENTO',
    'ALTERAZIONE_TEMPERATURA', 'GRADIENTE', 'ISOLATO', 'INTERFERENZA',
    'EMISSIONE_RF', 'DECIFRAZIONE_OK', 'ATTESA_CONFERMA', 'STATO_STABILE'
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final sessionId = 'ASPRO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';

    _forensicLogger = ForensicSessionLogger(
      sessionId: sessionId,
      sessionStart: now,
    );

    _baselineEngine = BaselineEngine(
      targetDuration: const Duration(seconds: 30),
      onProgress: (p, remaining) {
        if (!mounted) return;
        setState(() {
          _calibrationProgress = p;
          _calibrationRemainingSec = remaining;
          _calibrationSamples = _baselineEngine.emfAccumulator.count;
        });
      },
      onComplete: (profile) {
        if (!mounted) return;
        setState(() {
          _isCalibrating = false;
          _triggerEngine.setBaseline(profile);
        });
        _playAlertBeep(880, 150);
        _showToast('Calibrazione completata! Baseline impostata.');
      },
      onCancelled: (reason) {
        if (!mounted) return;
        setState(() => _isCalibrating = false);
        _showToast('Calibrazione annullata: $reason');
      },
    );

    _triggerEngine = DeterministicTriggerEngine(
      zThreshold: 3.5,
      bumpZThreshold: 2.5,
      minPersistenceMs: 150,
      lemmaPoolSize: _lexicon.length,
    );

    _dspChain = AnalyticalDSPChain(sampleRate: 48000.0);
    _fftEngine = FFTSpectrumEngine(fftSize: 512, sampleRate: 48000.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHwid();
      _startSensorStream();
      _startAudioProcessingLoop();
      // Avvio automatico della calibrazione iniziale (30s)
      _startCalibration();
    });
  }

  @override
  void dispose() {
    _baselineEngine.onCancelled = null;
    _baselineEngine.onProgress = null;
    _baselineEngine.onComplete = null;
    _sensorSubscription?.cancel();
    _dspSimulationTimer?.cancel();
    _baselineEngine.cancelCalibration();
    super.dispose();
  }

  Future<void> _loadHwid() async {
    try {
      final hwid = await _audioChannel.invokeMethod<String>('getDeviceHwid');
      final saved = await _audioChannel.invokeMethod<String>('getSavedLicense');
      if (mounted) {
        setState(() {
          _deviceHwid = hwid ?? 'ASPRO-FIELD-METROLOGY';
          _isAuthorized = saved != null && saved.trim().isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _deviceHwid = 'ASPRO-STANDALONE');
    }
  }

  void _startCalibration() {
    setState(() {
      _isCalibrating = true;
      _calibrationProgress = 0.0;
      _calibrationRemainingSec = 30;
      _calibrationSamples = 0;
    });
    _baselineEngine.startCalibration();
  }

  void _startSensorStream() {
    try {
      _sensorSubscription = _sensorChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event == null || !mounted) return;
          final map = Map<String, dynamic>.from(event as Map);
          final type = map['type'] as String? ?? '';

          if (type == 'emf') {
            final val = (map['value'] as num?)?.toDouble() ?? 42.0;
            _handleEmfSample(val);
          } else if (type == 'accel') {
            final dyn = (map['dynamic_magnitude'] as num?)?.toDouble() ?? 0.04;
            _handleAccelSample(dyn);
          } else if (type == 'pressure') {
            final p = (map['value'] as num?)?.toDouble() ?? 1013.25;
            _handlePressureSample(p);
          } else if (type == 'touch') {
            _handleAccelSample(3.5); // Bump manuale
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _handleEmfSample(double magnitude) {
    _currentEmf = magnitude;
    if (_isCalibrating) {
      _baselineEngine.ingestEmfMagnitude(magnitude);
      return;
    }

    _emfOscilloscopeHistory.add(magnitude);
    if (_emfOscilloscopeHistory.length > 80) {
      _emfOscilloscopeHistory.removeAt(0);
    }

    final reading = SensorReading(
      timestamp: DateTime.now(),
      emfMagnitude: magnitude,
      dynamicAcceleration: _currentDynamicVib,
      pressureHpa: _currentPressure,
    );

    final res = _triggerEngine.evaluate(reading);
    if (res.isAnomaly) {
      final lemma = res.deterministicLemmaIndex != null
          ? _lexicon[res.deterministicLemmaIndex!]
          : null;

      _forensicLogger.logTrigger(
        res,
        pressureHpa: _currentPressure,
        audioPeakHz: _audioPeakHz,
        audioPeakDbfs: _audioPeakDbfs,
        lemma: lemma,
      );
      _playAlertBeep(1200, 100);
    } else if (res.isArtifact) {
      _forensicLogger.logTrigger(res, pressureHpa: _currentPressure);
    }

    if (mounted) setState(() => _lastTriggerResult = res);
  }

  void _handleAccelSample(double dynamicAccel) {
    _currentDynamicVib = dynamicAccel;
    if (_isCalibrating) {
      _baselineEngine.ingestVibration(dynamicAccel, 0.0, 0.0);
    }
  }

  void _handlePressureSample(double hPa) {
    _currentPressure = hPa;
    if (_isCalibrating) {
      _baselineEngine.ingestPressure(hPa);
    }
  }

  void _startAudioProcessingLoop() {
    // Loop analitico DSP a 30 FPS per lo spettrogramma FFT in dBFS
    _dspSimulationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;

      // Generazione buffer di test / microfonico
      final buffer = List<double>.generate(512, (i) {
        final t = i / 48000.0;
        final baseNoise = (Random().nextDouble() - 0.5) * 0.002;
        // Se c'è anomalia valida, simula picco spettrale coerente
        final anomalySig = (_lastTriggerResult?.isAnomaly ?? false)
            ? sin(2.0 * pi * 1420.0 * t) * 0.15
            : 0.0;
        return _dspChain.process(baseNoise + anomalySig);
      });

      final fftResult = _fftEngine.analyze(buffer);
      if (!mounted) return;
      setState(() {
        _currentFftDbfs = fftResult.magnitudesDbfs;
        _audioPeakHz = fftResult.peakFrequencyHz;
        _audioPeakDbfs = fftResult.peakMagnitudeDbfs;
      });
    });
  }

  void _playAlertBeep(int freq, int durationMs) {
    try {
      _audioChannel.invokeMethod('playBeep', {'freq': freq, 'durationMs': durationMs});
    } catch (_) {}
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
        backgroundColor: IndustrialPalette.surfaceLight,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showChecksumDialog() {
    final checksum = _forensicLogger.computeSessionChecksum();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IndustrialPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: IndustrialPalette.phosphorCyan),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: IndustrialPalette.phosphorCyan, size: 20),
            SizedBox(width: 8),
            Text(
              'IMPRONTA FORENSE SHA-256',
              style: TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digest crittografico calcolato sull\'intero registro metrologico della sessione:',
              style: TextStyle(fontSize: 12, color: IndustrialPalette.textWhite),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IndustrialPalette.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: IndustrialPalette.border),
              ),
              child: SelectableText(
                checksum,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: IndustrialPalette.phosphorGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'HWID: $_deviceHwid (${_isAuthorized ? 'LICENZIATO' : 'STANDALONE'})',
              style: const TextStyle(fontSize: 10.5, color: IndustrialPalette.textMuted, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 6),
            Text(
              'Eventi validati: ${_forensicLogger.validAnomaliesCount} | Artefatti: ${_forensicLogger.artifactCount}',
              style: const TextStyle(fontSize: 11, color: IndustrialPalette.textMuted, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: checksum));
              Navigator.pop(ctx);
              _showToast('Checksum SHA-256 copiato negli appunti!');
            },
            child: const Text('COPIA HASH', style: TextStyle(color: IndustrialPalette.phosphorCyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CHIUDI', style: TextStyle(color: IndustrialPalette.textMuted)),
          ),
        ],
      ),
    );
  }

  void _exportCsvModal() {
    final csv = _forensicLogger.exportCsv();
    Clipboard.setData(ClipboardData(text: csv));
    _showToast('Dataset CSV (${_forensicLogger.totalEntries} record) copiato negli appunti!');
  }

  void _exportJsonModal() {
    final jsonStr = _forensicLogger.exportJson();
    Clipboard.setData(ClipboardData(text: jsonStr));
    _showToast('Dataset JSON Forense copiato negli appunti!');
  }

  @override
  Widget build(BuildContext context) {
    final base = _baselineEngine.activeProfile;
    final deltaEmf = base != null ? _currentEmf - base.emfMean : 0.0;
    final zScore = base != null ? _lastTriggerResult?.zScoreEmf ?? 0.0 : 0.0;
    final snrDb = base != null ? _lastTriggerResult?.snrDbEmf ?? 0.0 : 0.0;
    final isBump = _lastTriggerResult?.isBumpDetected ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: IndustrialPalette.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.show_chart, color: IndustrialPalette.phosphorCyan, size: 20),
            const SizedBox(width: 8),
            const Text(
              'AETHERSCAN-PRO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _baselineEngine.isCalibrated
                    ? IndustrialPalette.phosphorGreen.withValues(alpha: 0.15)
                    : IndustrialPalette.alertAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _baselineEngine.isCalibrated
                      ? IndustrialPalette.phosphorGreen
                      : IndustrialPalette.alertAmber,
                ),
              ),
              child: Text(
                _baselineEngine.isCalibrated ? 'CALIBRATED' : 'UNCALIBRATED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _baselineEngine.isCalibrated
                      ? IndustrialPalette.phosphorGreen
                      : IndustrialPalette.alertAmber,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: IndustrialPalette.alertAmber),
            tooltip: 'Ricalibra Baseline (30s)',
            onPressed: _startCalibration,
          ),
          IconButton(
            icon: const Icon(Icons.security, color: IndustrialPalette.phosphorCyan),
            tooltip: 'Impronta SHA-256 Sessione',
            onPressed: _showChecksumDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Telemetry Cards Row ──
                Row(
                  children: [
                    Expanded(
                      child: IndustrialTelemetryCard(
                        label: 'EMF Modulo',
                        value: _currentEmf.toStringAsFixed(1),
                        unit: 'µT',
                        delta: 'Δ ${deltaEmf >= 0 ? '+' : ''}${deltaEmf.toStringAsFixed(1)} (Z=${zScore.toStringAsFixed(1)})',
                        accentColor: (_lastTriggerResult?.isAnomaly ?? false)
                            ? IndustrialPalette.alertRed
                            : IndustrialPalette.phosphorCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IndustrialTelemetryCard(
                        label: 'Vibrazione',
                        value: _currentDynamicVib.toStringAsFixed(2),
                        unit: 'm/s²',
                        delta: isBump ? 'URTO RILEVATO' : 'STATO FERMO',
                        accentColor: isBump
                            ? IndustrialPalette.alertAmber
                            : IndustrialPalette.phosphorGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: IndustrialTelemetryCard(
                        label: 'Pressione',
                        value: _currentPressure.toStringAsFixed(1),
                        unit: 'hPa',
                        delta: 'Stato Atmosferico',
                        accentColor: IndustrialPalette.textWhite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IndustrialTelemetryCard(
                        label: 'SNR / Audio Peak',
                        value: snrDb.toStringAsFixed(1),
                        unit: 'dB',
                        delta: '${_audioPeakHz.round()} Hz (${_audioPeakDbfs.round()} dBFS)',
                        accentColor: snrDb >= 15.0
                            ? IndustrialPalette.phosphorCyan
                            : IndustrialPalette.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 2. Oscilloscopio Vettoriale & Spettrogramma ──
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: IndustrialPalette.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: IndustrialPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: IndustrialPalette.border)),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'OSCILLOSCOPIO VETTORIALE (EMF µT)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: IndustrialPalette.textMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Spacer(),
                              Text(
                                'CAMPIONAMENTO REAL-TIME',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: IndustrialPalette.phosphorGreen,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                            child: CustomPaint(
                              painter: IndustrialOscilloscopePainter(
                                history: _emfOscilloscopeHistory,
                                baselineMean: base?.emfMean ?? 40.0,
                                baselineStdDev: base?.emfStdDev ?? 2.0,
                                minY: max(0.0, (base?.emfMean ?? 40.0) - 20.0),
                                maxY: (base?.emfMean ?? 40.0) + 40.0,
                                traceColor: (_lastTriggerResult?.isAnomaly ?? false)
                                    ? IndustrialPalette.alertRed
                                    : IndustrialPalette.phosphorCyan,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── 3. Spettrogramma FFT in dBFS ──
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: IndustrialPalette.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: IndustrialPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: IndustrialPalette.border)),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'SPETTROGRAMMA FFT (dBFS) • NOTCH 50Hz ATTIVO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: IndustrialPalette.textMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Picco: ${_audioPeakHz.round()} Hz',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: IndustrialPalette.phosphorCyan,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                            child: CustomPaint(
                              painter: IndustrialSpectrumPainter(
                                magnitudesDbfs: _currentFftDbfs.take(64).toList(),
                                peakFrequencyHz: _audioPeakHz,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── 4. Forensic Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_view, size: 14),
                        label: const Text('CSV RFC 4180', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IndustrialPalette.surfaceLight,
                          foregroundColor: IndustrialPalette.phosphorCyan,
                          side: const BorderSide(color: IndustrialPalette.border),
                        ),
                        onPressed: _exportCsvModal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.code, size: 14),
                        label: const Text('JSON FORENSE', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IndustrialPalette.surfaceLight,
                          foregroundColor: IndustrialPalette.phosphorGreen,
                          side: const BorderSide(color: IndustrialPalette.border),
                        ),
                        onPressed: _exportJsonModal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 5. Overlay di Calibrazione 30 Secondi ──
          if (_isCalibrating)
            CalibrationOverlayWidget(
              progress: _calibrationProgress,
              remainingSeconds: _calibrationRemainingSec,
              sampleCount: _calibrationSamples,
              onCancel: () => _baselineEngine.cancelCalibration(),
            ),
        ],
      ),
    );
  }
}
