import 'dart:convert';
import 'dart:typed_data';
import 'baseline_engine.dart';
import 'trigger_logic.dart';

/// Implementazione pura e autonoma dello standard crittografico SHA-256 (FIPS PUB 180-4)
/// Consente di calcolare l'impronta forense di sessione senza dipendenze esterne.
class Sha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static String hashString(String input) {
    return hashBytes(utf8.encode(input));
  }

  static String hashBytes(List<int> bytes) {
    final int bitLength = bytes.length * 8;
    final List<int> padded = List<int>.from(bytes)..add(0x80);

    while ((padded.length % 64) != 56) {
      padded.add(0);
    }

    // Aggiungi lunghezza a 64-bit big-endian
    for (int i = 7; i >= 0; i--) {
      padded.add((bitLength >> (i * 8)) & 0xFF);
    }

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final Uint32List w = Uint32List(64);
    final ByteData bd = ByteData.sublistView(Uint8List.fromList(padded));

    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint32(chunk + (i * 4), Endian.big);
      }

      for (int i = 16; i < 64; i++) {
        final int s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final int s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ (~e & g);
        final int temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((x) => x.toRadixString(16).padLeft(8, '0'))
        .join('');
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
}

/// Singolo record immutabile nel registro forense
class ForensicLogEntry {
  final int index;
  final DateTime timestamp;
  final TriggerClassification classification;

  final double emfRaw;
  final double emfDelta;
  final double emfZScore;
  final double emfSnrDb;

  final double dynamicAccel;
  final double accelZScore;
  final bool isBump;

  final double? pressureHpa;
  final double? audioPeakHz;
  final double? audioPeakDbfs;
  final String? mappedLemma;
  final String fingerprint;
  final int occurrenceCount;

  const ForensicLogEntry({
    required this.index,
    required this.timestamp,
    required this.classification,
    required this.emfRaw,
    required this.emfDelta,
    required this.emfZScore,
    required this.emfSnrDb,
    required this.dynamicAccel,
    required this.accelZScore,
    required this.isBump,
    this.pressureHpa,
    this.audioPeakHz,
    this.audioPeakDbfs,
    this.mappedLemma,
    required this.fingerprint,
    this.occurrenceCount = 1,
  });

  /// Riga CSV conforme a RFC 4180
  String toCsvRow() {
    return [
      index.toString(),
      timestamp.toIso8601String(),
      classification.name,
      emfRaw.toStringAsFixed(2),
      emfDelta.toStringAsFixed(2),
      emfZScore.toStringAsFixed(2),
      emfSnrDb.toStringAsFixed(1),
      dynamicAccel.toStringAsFixed(3),
      accelZScore.toStringAsFixed(2),
      isBump ? 'TRUE' : 'FALSE',
      pressureHpa?.toStringAsFixed(2) ?? '',
      audioPeakHz?.toStringAsFixed(1) ?? '',
      audioPeakDbfs?.toStringAsFixed(1) ?? '',
      '"${mappedLemma ?? ''}"',
    ].join(',');
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'timestamp': timestamp.toIso8601String(),
      'classification': classification.name,
      'emf': {
        'raw_uT': emfRaw,
        'delta_uT': emfDelta,
        'z_score': emfZScore,
        'snr_db': emfSnrDb,
      },
      'vibration': {
        'dynamic_ms2': dynamicAccel,
        'z_score': accelZScore,
        'is_bump': isBump,
      },
      'baro_hPa': pressureHpa,
      'audio': {
        'peak_hz': audioPeakHz,
        'peak_dbfs': audioPeakDbfs,
      },
      'lemma': mappedLemma,
      'fingerprint': {
        'hash': fingerprint,
        'occurrence_count': occurrenceCount,
      },
    };
  }
}

/// Gestore del registro temporale e dell'esportazione forense certificata
class ForensicSessionLogger {
  final String sessionId;
  final DateTime sessionStart;
  final BaselineProfile? baseline;
  final List<ForensicLogEntry> _entries = [];
  final Map<String, int> _fingerprintCounts = {};

  ForensicSessionLogger({
    required this.sessionId,
    required this.sessionStart,
    this.baseline,
  });

  List<ForensicLogEntry> get entries => List.unmodifiable(_entries);
  int get totalEntries => _entries.length;
  int get validAnomaliesCount =>
      _entries.where((e) => e.classification == TriggerClassification.environmentalAnomaly || e.classification == TriggerClassification.dualTriggerInteraction).length;
  int get artifactCount =>
      _entries.where((e) => e.classification == TriggerClassification.mechanicalTouch).length;

  static String computeDeterministicFingerprint({
    required TriggerClassification classification,
    required double emfDelta,
    required double dynamicAccel,
    required bool isBump,
    double? pressureHpa,
    double? audioPeakHz,
  }) {
    final qEmf = (emfDelta * 10.0).round();
    final qVib = (dynamicAccel * 100.0).round();
    final qBaro = pressureHpa == null ? 'na' : (pressureHpa * 10.0).round().toString();
    final qHz = audioPeakHz == null ? 'na' : audioPeakHz.round().toString();
    final canonical = '${classification.name}|$qEmf|$qVib|${isBump ? 1 : 0}|$qBaro|$qHz';
    final digest = Sha256.hashString(canonical);
    return digest.substring(0, 16);
  }

  /// Registra un nuovo evento di trigger deterministico nel ledger
  ForensicLogEntry logTrigger(
    TriggerResult result, {
    double? pressureHpa,
    double? audioPeakHz,
    double? audioPeakDbfs,
    String? lemma,
  }) {
    final fp = computeDeterministicFingerprint(
      classification: result.classification,
      emfDelta: result.deltaEmf,
      dynamicAccel: result.rawDynamicAccel,
      isBump: result.isBumpDetected,
      pressureHpa: pressureHpa,
      audioPeakHz: audioPeakHz,
    );
    final nextCount = (_fingerprintCounts[fp] ?? 0) + 1;
    _fingerprintCounts[fp] = nextCount;

    final entry = ForensicLogEntry(
      index: _entries.length + 1,
      timestamp: result.timestamp,
      classification: result.classification,
      emfRaw: result.rawEmf,
      emfDelta: result.deltaEmf,
      emfZScore: result.zScoreEmf,
      emfSnrDb: result.snrDbEmf,
      dynamicAccel: result.rawDynamicAccel,
      accelZScore: result.zScoreAccel,
      isBump: result.isBumpDetected,
      pressureHpa: pressureHpa,
      audioPeakHz: audioPeakHz,
      audioPeakDbfs: audioPeakDbfs,
      mappedLemma: lemma,
      fingerprint: fp,
      occurrenceCount: nextCount,
    );

    _entries.add(entry);
    return entry;
  }

  /// Esportazione in formato CSV Metrologico RFC 4180
  String exportCsv() {
    final buffer = StringBuffer();
    // Intestazione con metadati di calibrazione e sessione
    buffer.writeln('# AETHER_SCAN_PRO_FORENSIC_SESSION_CSV');
    buffer.writeln('# Session_ID: $sessionId');
    buffer.writeln('# Session_Start: ${sessionStart.toIso8601String()}');
    if (baseline != null) {
      buffer.writeln('# Baseline_EMF_Mean_uT: ${baseline!.emfMean.toStringAsFixed(2)}');
      buffer.writeln('# Baseline_EMF_StdDev_uT: ${baseline!.emfStdDev.toStringAsFixed(2)}');
      buffer.writeln('# Baseline_Vib_Mean_ms2: ${baseline!.vibMean.toStringAsFixed(4)}');
    }
    buffer.writeln('# Columns: Index,Timestamp_UTC,Classification,EMF_Raw_uT,EMF_Delta_uT,EMF_ZScore,EMF_SNR_dB,Vib_Dynamic_ms2,Vib_ZScore,Is_Bump,Baro_hPa,Audio_Peak_Hz,Audio_Peak_dBFS,Mapped_Lemma');

    for (final entry in _entries) {
      buffer.writeln(entry.toCsvRow());
    }

    return buffer.toString();
  }

  /// Esportazione in formato JSON strutturato
  String exportJson({bool pretty = true}) {
    final data = {
      'header': {
        'tool': 'AetherScan-Pro',
        'engine': 'Scientific Forensic Logger v27-beta2.6',
        'session_id': sessionId,
        'session_start': sessionStart.toIso8601String(),
        'total_entries': _entries.length,
        'valid_anomalies': validAnomaliesCount,
        'mechanical_artifacts': artifactCount,
      },
      'baseline_profile': baseline?.toMap(),
      'entries': _entries.map((e) => e.toMap()).toList(),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  /// Calcolo dell'impronta crittografica SHA-256 della sessione
  String computeSessionChecksum() {
    final csvContent = exportCsv();
    return Sha256.hashString(csvContent);
  }
}
