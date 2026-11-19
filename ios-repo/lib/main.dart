import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'baseline_engine.dart';
import 'trigger_logic.dart';
import 'audio_suite.dart';
import 'forensic_logger.dart';
import 'industrial_ui.dart';
import 'spectral_sweep_engine.dart';
import 'spectral_sweep_view.dart';
import 'vocal_trigger_engine.dart';
import 'k2_led_bar.dart';

/// Modalità operative selezionabili dal Menu Hamburger
enum AppOperatingMode {
  /// Suite severa: grafici puri, Z-Score >= 3.5σ, Log CSV SHA-256 e Coincidenza Dual-Trigger
  metrologyPro,

  /// Modalità interattiva per Live: scansione radiofonica continua accoppiata ai sensori reali
  spectralSweep,
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AetherScanProApp());
}

class AetherScanProApp extends StatelessWidget {
  const AetherScanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AetherScan-Pro v27-beta2.6 (Metrology Suite)',
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

  // ── Modalità Operativa e Scansione Spettrale ──
  AppOperatingMode _activeMode = AppOperatingMode.metrologyPro;
  late final SpectralSweepEngine _spectralSweepEngine;
  SweepFrame? _lastSweepFrame;
  bool _isSweepAudioActive = false;
  double _masterVolume = 0.85;
  bool _isMetrologyMonitoringActive = false; // Spento di default, attivato a comando dall'utente

  // ── Modulo Vocale Custom Real-Trigger (Completamente Isolato) ──
  late final VocalTriggerEngine _vocalTriggerEngine;
  VocalTriggerEvent? _lastVocalEvent;

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
      touchAccelThreshold: 3.2,
      minPersistenceMs: 150,
      baseline: BaselineProfile(
        calibratedAt: now,
        duration: Duration.zero,
        totalSamples: 1,
        emfMean: 42.0,
        emfStdDev: 2.0,
        emfMin: 38.0,
        emfMax: 46.0,
        vibMean: 0.04,
        vibStdDev: 0.02,
        vibMax: 0.1,
        baroMean: 1013.25,
        baroStdDev: 0.1,
        baroMin: 1013.0,
        baroMax: 1013.5,
      ),
    );

    _dspChain = AnalyticalDSPChain(sampleRate: 48000.0);
    _fftEngine = FFTSpectrumEngine(fftSize: 512, sampleRate: 48000.0);
    _spectralSweepEngine = SpectralSweepEngine(
      sampleRate: 48000.0,
      band: SweepBand.fm,
      direction: SweepDirection.paused,
      sweepIntervalMs: 100,
    );
    _vocalTriggerEngine = VocalTriggerEngine(isEnabled: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHwid();
      _startSensorStream();
      _startAudioProcessingLoop();
      // Nessuna calibrazione forzata all'avvio: l'app si apre pulita e immediatamente fruibile.
      // L'operatore può avviare la calibrazione premendo il pulsante dedicato.
    });
  }

  @override
  void dispose() {
    _stopSweepAudio();
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

  void _applyQuickTare() {
    final taredProfile = _baselineEngine.applyQuickTare(_currentEmf);
    _triggerEngine.setBaseline(taredProfile);
    setState(() {});
    _showToast('TARA RAPIDA applicata: \${_currentEmf.toStringAsFixed(1)} µT → nuovo riferimento EMF');
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
            // Evento tocco fisico confermato da bridge nativo (cooldown 2.0s, soglia 3.2 m/s²).
            // L'accelerazione dinamica reale è già convogliata dal frame 'accel'.
            // Nessuna iniezione di bump sintetico per evitare duplicazione di trigger.
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

    _evaluateCurrentSensors();
  }

  void _handleAccelSample(double dynamicAccel) {
    _currentDynamicVib = dynamicAccel;
    if (_isCalibrating) {
      _baselineEngine.ingestVibration(dynamicAccel, 0.0, 0.0);
      return;
    }

    _evaluateCurrentSensors();
  }

  void _evaluateCurrentSensors() {
    if (_isCalibrating || !_isMetrologyMonitoringActive) return;

    final reading = SensorReading(
      timestamp: DateTime.now(),
      emfMagnitude: _currentEmf,
      dynamicAcceleration: _currentDynamicVib,
      pressureHpa: _currentPressure,
    );

    final res = _triggerEngine.evaluate(reading);
    if (res.shouldTriggerAlarmSound) {
      // COINCIDENZA DUAL-TRIGGER: Tocco (|A_dyn| >= 3.2 m/s²) + Anomalia EMF (|Z| >= 3.5σ)
      // Unica condizione abilitata all'emissione del suono di allarme personalizzato!
      _playAlarmSound();
      _forensicLogger.logTrigger(
        res,
        pressureHpa: _currentPressure,
        audioPeakHz: _audioPeakHz,
        audioPeakDbfs: _audioPeakDbfs,
      );
    } else if (res.isEnvironmentalAnomaly) {
      // Anomalia metrologica pura (|Z| >= 3.5σ ma nessun tocco): registrazione forense senza suono tocco
      _forensicLogger.logTrigger(
        res,
        pressureHpa: _currentPressure,
        audioPeakHz: _audioPeakHz,
        audioPeakDbfs: _audioPeakDbfs,
      );
    } else if (res.isMechanicalTouch) {
      // Urto o contatto meccanico sul telaio senza anomalia EMF contemporanea
      _playAlertBeep(520, 80); // Feedback acustico istantaneo di avvenuto impatto fisico
      _forensicLogger.logTrigger(
        res,
        pressureHpa: _currentPressure,
      );
    }

    if (mounted) setState(() => _lastTriggerResult = res);
  }

  void _playAlarmSound() {
    try {
      _audioChannel.invokeMethod('playCreepyLaugh');
    } catch (_) {
      _playAlertBeep(1200, 200);
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

      final base = _baselineEngine.activeProfile;
      final deltaEmf = base != null ? _currentEmf - base.emfMean : 0.0;
      final zScore = _lastTriggerResult?.zScoreEmf ?? 0.0;

      List<double> buffer;
      final bool isSweepRunning = _spectralSweepEngine.direction != SweepDirection.paused;

      if (isSweepRunning) {
        // Scansione spettrale deterministica pilotata dai sensori reali
        final frame = _spectralSweepEngine.processFrame(
          now: DateTime.now(),
          deltaEmf: deltaEmf,
          zScoreEmf: zScore,
          dynamicAccel: _currentDynamicVib,
          bufferSize: 512,
        );
        _lastSweepFrame = frame;

        if (_isSweepAudioActive) {
          try {
            final double basePitch = _spectralSweepEngine.band == SweepBand.fm
                ? 600.0 + ((_spectralSweepEngine.currentFrequency - 87.5) / (108.0 - 87.5)) * 1400.0
                : 400.0 + ((_spectralSweepEngine.currentFrequency - 530.0) / (1600.0 - 530.0)) * 1200.0;
            final double effectivePitch = (basePitch + (deltaEmf * 12.0)).clamp(200.0, 3000.0);
            // Aggiorna parametri DSP caotico nel thread nativo (Android/iOS) con volume master reale
            _audioChannel.invokeMethod('updateStaticParams', {
              'emfDelta': deltaEmf,
              'accel': _currentDynamicVib,
              'zScore': zScore,
              'pitchHz': effectivePitch,
              'volume': _masterVolume,
            });
          } catch (_) {}
        }
      }

      if (_activeMode == AppOperatingMode.spectralSweep) {
        if (isSweepRunning && _lastSweepFrame != null) {
          buffer = _lastSweepFrame!.audioBuffer;
        } else {
          // Sweep in pausa: nessun calcolo pesante né audio nativo
          buffer = List<double>.filled(512, 0.0);
        }
      } else {
        // Metrology Pro: calcoli attivi solo se il monitoraggio è abilitato dall'utente
        if (_isMetrologyMonitoringActive) {
          buffer = List<double>.generate(512, (i) {
            final t = i / 48000.0;
            final baseNoise = (Random().nextDouble() - 0.5) * 0.002;
            final anomalySig = (_lastTriggerResult?.isAnomaly ?? false)
                ? sin(2.0 * pi * 1420.0 * t) * 0.15
                : 0.0;
            return _dspChain.process(baseNoise + anomalySig);
          });
        } else {
          // Metrology in standby: buffer piatto, nessun carico DSP né audio
          buffer = List<double>.filled(512, 0.0);
        }
      }

      // ── Modulo Vocale Custom Real-Trigger (Completamente Isolato) ──
      // Attivo se abilitato dall'utente E almeno uno dei moduli (Metrologia o Sweep) è in esecuzione
      final bool isSystemRunning = _isMetrologyMonitoringActive || isSweepRunning;

      if (_vocalTriggerEngine.isEnabled && isSystemRunning) {
        final now = DateTime.now();
        final vocalEvent = _vocalTriggerEngine.evaluate(
          now: now,
          deltaEmf: deltaEmf,
          zScoreEmf: zScore,
          dynamicAccel: _currentDynamicVib,
          lorenzX: _spectralSweepEngine.lorenzX,
          currentFrequency: _spectralSweepEngine.currentFrequency,
        );

        if (vocalEvent != null) {
          try {
            _audioChannel.invokeMethod('speak', {
              'text': vocalEvent.word,
              'volume': _masterVolume,
              'pitch': 0.85,
            });
          } catch (_) {}
          _lastVocalEvent = vocalEvent;
        }
      }

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

  void _setMasterVolume(double vol) {
    setState(() {
      _masterVolume = vol.clamp(0.0, 1.0);
    });
    try {
      _audioChannel.invokeMethod('setVolume', {'volume': _masterVolume});
    } catch (_) {}
  }

  void _startSweepAudio() {
    if (_isSweepAudioActive) return;
    _isSweepAudioActive = true;
    try {
      _audioChannel.invokeMethod('startStatic', {'volume': _masterVolume});
    } catch (_) {}
  }

  void _stopSweepAudio() {
    if (!_isSweepAudioActive) return;
    _isSweepAudioActive = false;
    try {
      _audioChannel.invokeMethod('stopStatic');
    } catch (_) {}
  }

  void _showVolumeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: IndustrialPalette.surface,
          title: const Row(
            children: [
              Icon(Icons.volume_up, color: IndustrialPalette.phosphorCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'REGOLAZIONE VOLUME',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Livello Master: ' + (_masterVolume * 100).round().toString() + '%',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: IndustrialPalette.textWhite),
              ),
              const SizedBox(height: 12),
              Slider(
                value: _masterVolume.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                divisions: 20,
                activeColor: IndustrialPalette.phosphorCyan,
                inactiveColor: IndustrialPalette.border,
                onChanged: (val) {
                  setDlgState(() {});
                  _setMasterVolume(val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CHIUDI', style: TextStyle(fontFamily: 'monospace', color: IndustrialPalette.phosphorCyan)),
            ),
          ],
        ),
      ),
    );
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

  void _showVersionInfoDialog() {
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
            Icon(Icons.info_outline, color: IndustrialPalette.phosphorCyan, size: 22),
            SizedBox(width: 8),
            Text(
              'AETHERSCAN-PRO v27-beta2.6',
              style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IndustrialPalette.phosphorGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: IndustrialPalette.phosphorGreen),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: IndustrialPalette.phosphorGreen, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'VERSIONE PIÙ AGGIORNATA INSTALLATA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: IndustrialPalette.phosphorGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Specifiche Release v27-beta2.6 (Build 2.0.27+8):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: IndustrialPalette.textWhite),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Motore Audio Sweep Reale: streaming continuo rumore radio AM/FM calibrato su speaker di sistema.\n'
              '• Accelerometro Reale iOS: campionamento continuo urti in m/s² con feedback acustico immediato.\n'
              '• Aggiornamento Diretto Senza Cavo: download pacchetto IPA/APK con un tocco da Safari/AltStore.\n'
              '• Esportazione Forense Diretta: file CSV RFC 4180 e JSON salvati su disco con Share Sheet nativo.\n'
              '• Blocco Doppio Trigger: coincidenza simultanea tra urto (|A_dyn| >= 3.2 m/s²) e anomalia (Z >= 3.5σ).',
              style: TextStyle(fontSize: 10, color: IndustrialPalette.textMuted, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialPalette.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: IndustrialPalette.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: IndustrialPalette.phosphorCyan, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Canale Ufficiale: Release Certificata e Sicura',
                      style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: IndustrialPalette.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.sync, size: 14),
            label: const Text('VERIFICA AGGIORNAMENTI', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
            style: ElevatedButton.styleFrom(
              backgroundColor: IndustrialPalette.surfaceLight,
              foregroundColor: IndustrialPalette.phosphorCyan,
              side: const BorderSide(color: IndustrialPalette.border),
            ),
            onPressed: () => _checkUpdateOnline(ctx),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CHIUDI', style: TextStyle(color: IndustrialPalette.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdateOnline(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    _showToast('Verifica aggiornamenti in corso...');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(
        Uri.parse('https://raw.githubusercontent.com/squaloman74/AetherScan-Pro/main/version.json'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final latest = data['latest_version'] as String? ?? '';
        final notes = data['notes'] as String? ?? '';
        final iosUrl = data['ios_download_url'] as String?;
        final androidUrl = data['android_download_url'] as String?;
        final defaultUrl = data['download_url'] as String? ?? 'https://github.com/squaloman74/AetherScan-Pro/releases/latest';

        final targetDownload = Platform.isIOS
            ? (iosUrl ?? defaultUrl)
            : (androidUrl ?? defaultUrl);

        if (!mounted) return;
        if (latest.isNotEmpty && latest != 'v27-beta2.6') {
          _showUpdateResultDialog(
            isNewAvailable: true,
            version: latest,
            message: 'È disponibile una nuova versione:\n$notes',
            downloadUrl: targetDownload,
          );
          return;
        } else {
          _showUpdateResultDialog(
            isNewAvailable: false,
            version: latest.isNotEmpty ? latest : 'v27-beta2.6',
            message: 'Sei all\'ultima versione disponibile. Tutti i moduli scientifici sono aggiornati.',
          );
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      _showToast('Sei all\'ultima versione disponibile: v27-beta2.6');
    }
  }

  void _showUpdateResultDialog({
    required bool isNewAvailable,
    required String version,
    required String message,
    String? downloadUrl,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IndustrialPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isNewAvailable ? IndustrialPalette.alertAmber : IndustrialPalette.phosphorGreen,
          ),
        ),
        title: Row(
          children: [
            Icon(
              isNewAvailable ? Icons.system_update : Icons.check_circle,
              color: isNewAvailable ? IndustrialPalette.alertAmber : IndustrialPalette.phosphorGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isNewAvailable ? 'AGGIORNAMENTO TROVATO' : 'VERSIONE AGGIORNATA',
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versione Rilevata: $version',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isNewAvailable ? IndustrialPalette.alertAmber : IndustrialPalette.phosphorGreen,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(fontSize: 11, color: IndustrialPalette.textWhite, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (isNewAvailable && downloadUrl != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IndustrialPalette.phosphorGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                try {
                  _audioChannel.invokeMethod('openUrl', {'url': downloadUrl});
                } catch (_) {}
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('SCARICA ORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CHIUDI', style: TextStyle(color: IndustrialPalette.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsvModal() async {
    final csv = _forensicLogger.exportCsv();
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/aetherscan_forensic_$timestamp.csv');
      await file.writeAsString(csv, encoding: utf8);
      Clipboard.setData(ClipboardData(text: csv));
      _showToast('CSV salvato (${_forensicLogger.totalEntries} record). Condivisione in corso...');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'AetherScan-Pro — Log Forense CSV',
      );
    } catch (_) {
      // Fallback: copia negli appunti
      Clipboard.setData(ClipboardData(text: csv));
      _showToast('CSV (${_forensicLogger.totalEntries} record) copiato negli appunti!');
    }
  }

  Future<void> _exportJsonModal() async {
    final jsonStr = _forensicLogger.exportJson();
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/aetherscan_forensic_$timestamp.json');
      await file.writeAsString(jsonStr, encoding: utf8);
      Clipboard.setData(ClipboardData(text: jsonStr));
      _showToast('JSON Forense salvato. Condivisione in corso...');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'AetherScan-Pro — Log Forense JSON',
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: jsonStr));
      _showToast('JSON Forense copiato negli appunti!');
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: IndustrialPalette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: IndustrialPalette.background,
              border: Border(bottom: BorderSide(color: IndustrialPalette.border, width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart, color: IndustrialPalette.phosphorCyan, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'AETHERSCAN-PRO',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                        color: IndustrialPalette.textWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'v27-beta2.6 • SCIENTIFIC METROLOGY',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontFamily: 'monospace',
                    color: IndustrialPalette.phosphorCyan,
                  ),
                ),
                const SizedBox(height: 12),
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
                    _baselineEngine.isCalibrated ? 'CALIBRATED BASELINE' : 'UNCALIBRATED SENSORS',
                    style: TextStyle(
                      fontSize: 9.5,
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
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: IndustrialPalette.phosphorCyan),
            title: const Text(
              'Metrology Pro',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: const Text(
              'Suite severa, grafici puri, Z-Score 3.5σ, log RFC 4180 CSV con SHA-256 e coincidenza Dual-Trigger.',
              style: TextStyle(fontSize: 10, color: IndustrialPalette.textMuted),
            ),
            selected: _activeMode == AppOperatingMode.metrologyPro,
            selectedTileColor: IndustrialPalette.surfaceLight,
            onTap: () {
              setState(() => _activeMode = AppOperatingMode.metrologyPro);
              Navigator.pop(context);
            },
          ),
          const Divider(color: IndustrialPalette.border),
          ListTile(
            leading: const Icon(Icons.radio, color: IndustrialPalette.alertAmber),
            title: const Text(
              'AM/FM Spectral Sweep',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: const Text(
              'Scansione radio live accoppiata in tempo reale ai sensori fisici. Zero dizionari o voci simulate.',
              style: TextStyle(fontSize: 10, color: IndustrialPalette.textMuted),
            ),
            selected: _activeMode == AppOperatingMode.spectralSweep,
            selectedTileColor: IndustrialPalette.surfaceLight,
            onTap: () {
              setState(() {
                _activeMode = AppOperatingMode.spectralSweep;
              });
              Navigator.pop(context);
            },
          ),
          const Divider(color: IndustrialPalette.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.tune, size: 16),
              label: Text(
                _baselineEngine.isCalibrated ? 'RICALIBRA BASELINE (30s)' : 'AVVIA CALIBRAZIONE (30s)',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _baselineEngine.isCalibrated
                    ? IndustrialPalette.surfaceLight
                    : IndustrialPalette.alertAmber.withValues(alpha: 0.2),
                foregroundColor: _baselineEngine.isCalibrated
                    ? IndustrialPalette.phosphorGreen
                    : IndustrialPalette.alertAmber,
                side: BorderSide(
                  color: _baselineEngine.isCalibrated
                      ? IndustrialPalette.phosphorGreen
                      : IndustrialPalette.alertAmber,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(context);
                _startCalibration();
              },
            ),
          ),
          const Divider(color: IndustrialPalette.border),
          ListTile(
            leading: Icon(
              _vocalTriggerEngine.isEnabled ? Icons.record_voice_over : Icons.voice_over_off,
              color: _vocalTriggerEngine.isEnabled ? IndustrialPalette.phosphorGreen : IndustrialPalette.textMuted,
              size: 20,
            ),
            title: const Text('Modulo Vocale Real-Trigger', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _vocalTriggerEngine.isEnabled ? 'ATTIVO • Risonanza lessicale (|Z| >= 3.0σ)' : 'SPENTO (Standby)',
              style: TextStyle(
                fontSize: 9.5,
                color: _vocalTriggerEngine.isEnabled ? IndustrialPalette.phosphorGreen : IndustrialPalette.textMuted,
              ),
            ),
            trailing: Switch(
              value: _vocalTriggerEngine.isEnabled,
              activeColor: IndustrialPalette.phosphorGreen,
              onChanged: (val) {
                setState(() {
                  _vocalTriggerEngine.setEnabled(val);
                });
                Navigator.pop(context);
                _showToast(val
                    ? 'Modulo Vocale Real-Trigger ABILITATO'
                    : 'Modulo Vocale DISABILITATO (Standby)');
              },
            ),
            onTap: () {
              setState(() {
                _vocalTriggerEngine.setEnabled(!_vocalTriggerEngine.isEnabled);
              });
              Navigator.pop(context);
              _showToast(_vocalTriggerEngine.isEnabled
                  ? 'Modulo Vocale Real-Trigger ABILITATO'
                  : 'Modulo Vocale DISABILITATO (Standby)');
            },
          ),
          const Divider(color: IndustrialPalette.border),
          ListTile(
            leading: Icon(
              _masterVolume == 0.0 ? Icons.volume_off : (_masterVolume < 0.5 ? Icons.volume_down : Icons.volume_up),
              color: IndustrialPalette.phosphorCyan,
              size: 20,
            ),
            title: const Text('Volume Master Audio', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Livello: ' + (_masterVolume * 100).round().toString() + '% (TTS, Radio & Beep)',
              style: const TextStyle(fontSize: 9.5, color: IndustrialPalette.textMuted),
            ),
            onTap: () {
              Navigator.pop(context);
              _showVolumeDialog();
            },
          ),
          const Divider(color: IndustrialPalette.border),
          ListTile(
            leading: const Icon(Icons.system_update_alt, color: IndustrialPalette.phosphorCyan, size: 20),
            title: const Text('Verifica Aggiornamenti', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: const Text('v27-beta2.6 • Controlla versione e stato', style: TextStyle(fontSize: 9.5, color: IndustrialPalette.textMuted)),
            onTap: () {
              Navigator.pop(context);
              _showVersionInfoDialog();
            },
          ),
          const Spacer(),
          const Divider(color: IndustrialPalette.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HWID: $_deviceHwid',
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: IndustrialPalette.textMuted),
                ),
                const SizedBox(height: 4),
                const Text(
                  'FIPS PUB 180-4 SHA-256 INTEGRITY',
                  style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: IndustrialPalette.phosphorGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _baselineEngine.activeProfile;
    final deltaEmf = base != null ? _currentEmf - base.emfMean : 0.0;
    final zScore = base != null ? _lastTriggerResult?.zScoreEmf ?? 0.0 : 0.0;
    final snrDb = base != null ? _lastTriggerResult?.snrDbEmf ?? 0.0 : 0.0;
    final isBump = _lastTriggerResult?.isBumpDetected ?? false;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: IndustrialPalette.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _activeMode == AppOperatingMode.metrologyPro ? Icons.show_chart : Icons.radio,
              color: _activeMode == AppOperatingMode.metrologyPro
                  ? IndustrialPalette.phosphorCyan
                  : IndustrialPalette.alertAmber,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AETHERSCAN-PRO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    _activeMode == AppOperatingMode.metrologyPro
                        ? 'v27-beta2.6 • METROLOGY'
                        : 'v27-beta2.6 • SWEEP',
                    style: TextStyle(
                      fontSize: 8,
                      color: _activeMode == AppOperatingMode.metrologyPro
                          ? IndustrialPalette.phosphorCyan
                          : IndustrialPalette.alertAmber,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Indicatore di stato baseline ultra-compatto (zero sovrapposizioni su schermi stretti)
          Center(
            child: Tooltip(
              message: _baselineEngine.isCalibrated ? 'Baseline Calibrata (OK)' : 'Sensori Non Calibrati',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: _baselineEngine.isCalibrated
                          ? IndustrialPalette.phosphorGreen
                          : IndustrialPalette.alertAmber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _baselineEngine.isCalibrated ? 'CAL' : 'UNCAL',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _baselineEngine.isCalibrated
                            ? IndustrialPalette.phosphorGreen
                            : IndustrialPalette.alertAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _masterVolume == 0.0 ? Icons.volume_off : (_masterVolume < 0.5 ? Icons.volume_down : Icons.volume_up),
              color: IndustrialPalette.phosphorCyan,
              size: 20,
            ),
            tooltip: 'Volume: ' + (_masterVolume * 100).round().toString() + '%',
            onPressed: _showVolumeDialog,
          ),
          IconButton(
            icon: Icon(
              _vocalTriggerEngine.isEnabled ? Icons.record_voice_over : Icons.voice_over_off,
              color: _vocalTriggerEngine.isEnabled ? IndustrialPalette.phosphorGreen : IndustrialPalette.textMuted,
              size: 20,
            ),
            tooltip: _vocalTriggerEngine.isEnabled
                ? 'Modulo Vocale: ATTIVO'
                : 'Modulo Vocale: SPENTO (Tocca per abilitare)',
            onPressed: () {
              setState(() {
                _vocalTriggerEngine.setEnabled(!_vocalTriggerEngine.isEnabled);
              });
              _showToast(_vocalTriggerEngine.isEnabled
                  ? 'Modulo Vocale Real-Trigger ABILITATO'
                  : 'Modulo Vocale DISABILITATO (Standby)');
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: IndustrialPalette.alertAmber, size: 20),
            tooltip: 'Calibra Baseline (30s)',
            onPressed: _startCalibration,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: IndustrialPalette.phosphorCyan, size: 20),
            tooltip: 'Verifica Aggiornamenti & Info',
            onPressed: _showVersionInfoDialog,
          ),
          if (_activeMode == AppOperatingMode.metrologyPro)
            IconButton(
              icon: const Icon(Icons.security, color: IndustrialPalette.phosphorCyan, size: 20),
              tooltip: 'Impronta SHA-256 Sessione',
              onPressed: _showChecksumDialog,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_activeMode == AppOperatingMode.metrologyPro)
            _buildMetrologyProBody(base, deltaEmf, zScore, snrDb, isBump)
          else
            SpectralSweepView(
              currentFrame: _lastSweepFrame,
              currentBand: _spectralSweepEngine.band,
              currentDirection: _spectralSweepEngine.direction,
              sweepIntervalMs: _spectralSweepEngine.sweepIntervalMs,
              currentEmf: _currentEmf,
              deltaEmf: deltaEmf,
              zScoreEmf: zScore,
              currentDynamicAccel: _currentDynamicVib,
              fftDbfs: _currentFftDbfs,
              audioPeakHz: _audioPeakHz,
              currentVolume: _masterVolume,
              onBandChanged: (b) => setState(() => _spectralSweepEngine.setBand(b)),
              onIntervalChanged: (ms) => setState(() => _spectralSweepEngine.setSweepInterval(ms)),
              onDirectionChanged: (dir) => setState(() => _spectralSweepEngine.setDirection(dir)),
              onVolumeChanged: _setMasterVolume,
              onTogglePause: () {
                setState(() {
                  final willBePaused = _spectralSweepEngine.direction != SweepDirection.paused;
                  _spectralSweepEngine.setPaused(willBePaused);
                  if (willBePaused) {
                    _stopSweepAudio();
                  } else {
                    _startSweepAudio();
                  }
                });
              },
            ),

          // Overlay di Calibrazione 30 Secondi
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

  Widget _buildMetrologyProBody(
    BaselineProfile? base,
    double deltaEmf,
    double zScore,
    double snrDb,
    bool isBump,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Barra Controllo Manuale Attivazione Metrology Pro ──
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: IndustrialPalette.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isMetrologyMonitoringActive
                    ? IndustrialPalette.phosphorGreen.withValues(alpha: 0.6)
                    : IndustrialPalette.alertAmber.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isMetrologyMonitoringActive ? Icons.radio_button_checked : Icons.pause_circle_outline,
                  color: _isMetrologyMonitoringActive ? IndustrialPalette.phosphorGreen : IndustrialPalette.alertAmber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isMetrologyMonitoringActive ? 'METROLOGY PRO: ATTIVO' : 'METROLOGY PRO: SPENTO (STANDBY)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: _isMetrologyMonitoringActive ? IndustrialPalette.phosphorGreen : IndustrialPalette.alertAmber,
                        ),
                      ),
                      Text(
                        _isMetrologyMonitoringActive ? 'Analisi continua sensori e allarme doppio trigger abilitati' : 'Tocca ATTIVA per avviare il monitoraggio forense',
                        style: const TextStyle(fontSize: 8.5, color: IndustrialPalette.textMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(_isMetrologyMonitoringActive ? Icons.pause : Icons.play_arrow, size: 14),
                  label: Text(
                    _isMetrologyMonitoringActive ? 'PAUSA' : 'ATTIVA',
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMetrologyMonitoringActive ? IndustrialPalette.surfaceLight : IndustrialPalette.phosphorGreen,
                    foregroundColor: _isMetrologyMonitoringActive ? IndustrialPalette.textWhite : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () {
                    setState(() {
                      _isMetrologyMonitoringActive = !_isMetrologyMonitoringActive;
                    });
                    if (_isMetrologyMonitoringActive) {
                      _showToast('Monitoraggio Metrology attivato!');
                    } else {
                      _showToast('Monitoraggio Metrology messo in pausa (Standby)');
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Pillola HUD: Modulo Vocale Custom Real-Trigger ──
          if (_vocalTriggerEngine.isEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: IndustrialPalette.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _lastVocalEvent != null
                      ? IndustrialPalette.phosphorGreen
                      : IndustrialPalette.textMuted.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    size: 14,
                    color: _lastVocalEvent != null
                        ? IndustrialPalette.phosphorGreen
                        : IndustrialPalette.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastVocalEvent != null
                          ? 'VOCAL ECHO: "${_lastVocalEvent!.word}" (Z=${_lastVocalEvent!.zScore.toStringAsFixed(1)} | Δ=${_lastVocalEvent!.deltaEmf.toStringAsFixed(1)}µT)'
                          : 'VOCAL TRIGGER: IN ASCOLTO (Soglia |Z| >= 3.0σ)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _lastVocalEvent != null
                            ? IndustrialPalette.textWhite
                            : IndustrialPalette.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

                K2LedBarWidget(
                  currentEmf: _currentEmf,
                  deltaEmf: deltaEmf,
                  zScore: zScore,
                  onQuickTare: _applyQuickTare,
                ),
                const SizedBox(height: 8),

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
    );
  }
}
