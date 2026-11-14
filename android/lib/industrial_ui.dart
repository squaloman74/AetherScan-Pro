import 'dart:math';
import 'package:flutter/material.dart';

/// Palette Colori Stile Strumentazione Industriale / Laboratorio Metrologico
class IndustrialPalette {
  static const Color background = Color(0xFF070A0F);
  static const Color surface = Color(0xFF0D1420);
  static const Color surfaceLight = Color(0xFF141F32);
  static const Color border = Color(0xFF1D2C44);

  // Tracce e Indicatori di Precisione
  static const Color phosphorCyan = Color(0xFF00F0FF);
  static const Color phosphorGreen = Color(0xFF00FF88);
  static const Color alertAmber = Color(0xFFFF9500);
  static const Color alertRed = Color(0xFFFF3B30);
  static const Color gridSteel = Color(0xFF1A283C);
  static const Color textMuted = Color(0xFF4A6282);
  static const Color textWhite = Color(0xFFE2ECF8);
}

/// Scheda Telemetrica a Caratteri Fissi (Zero jitter visivo)
class IndustrialTelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String delta;
  final Color accentColor;
  final IconData? icon;

  const IndustrialTelemetryCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.delta,
    this.accentColor = IndustrialPalette.phosphorCyan,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IndustrialPalette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialPalette.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: accentColor),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: IndustrialPalette.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  fontFamily: 'monospace',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: IndustrialPalette.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            delta,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: IndustrialPalette.textMuted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter Vettoriale per Oscilloscopio a Tempo Reale (Serie Temporale dei Campioni)
class IndustrialOscilloscopePainter extends CustomPainter {
  final List<double> history;
  final double baselineMean;
  final double baselineStdDev;
  final double minY;
  final double maxY;
  final Color traceColor;

  IndustrialOscilloscopePainter({
    required this.history,
    required this.baselineMean,
    required this.baselineStdDev,
    this.minY = 0.0,
    this.maxY = 100.0,
    this.traceColor = IndustrialPalette.phosphorCyan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Sfondo e Griglia
    final bgPaint = Paint()..color = IndustrialPalette.surface;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final gridPaint = Paint()
      ..color = IndustrialPalette.gridSteel
      ..strokeWidth = 0.8;

    // 4 linee di griglia orizzontali
    for (int i = 1; i <= 3; i++) {
      final double y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    // 4 linee di griglia verticali
    for (int i = 1; i <= 3; i++) {
      final double x = w * (i / 4.0);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    if (history.isEmpty || maxY <= minY) return;

    // Linea Baseline di Riferimento (Tratteggiata o Ambra)
    final double baseNorm = ((baselineMean - minY) / (maxY - minY)).clamp(0.0, 1.0);
    final double basePlotY = h - (baseNorm * h);

    final baselinePaint = Paint()
      ..color = IndustrialPalette.alertAmber.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, basePlotY), Offset(w, basePlotY), baselinePaint);

    // Traccia del segnale vettoriale
    final tracePaint = Paint()
      ..color = traceColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double stepX = w / max(1, history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final double norm = ((history[i] - minY) / (maxY - minY)).clamp(0.0, 1.0);
      final double plotY = h - (norm * h);
      final double plotX = i * stepX;

      if (i == 0) {
        path.moveTo(plotX, plotY);
      } else {
        path.lineTo(plotX, plotY);
      }
    }

    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(covariant IndustrialOscilloscopePainter oldDelegate) => true;
}

/// Painter per lo Spettrogramma FFT Calibrato in dBFS (-100 a 0 dBFS)
class IndustrialSpectrumPainter extends CustomPainter {
  final List<double> magnitudesDbfs; // Array di valori in dBFS (es. 64 bin)
  final Color barColor;
  final double peakFrequencyHz;

  IndustrialSpectrumPainter({
    required this.magnitudesDbfs,
    this.barColor = IndustrialPalette.phosphorCyan,
    this.peakFrequencyHz = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Sfondo e griglia dBFS
    final bgPaint = Paint()..color = IndustrialPalette.surface;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final gridPaint = Paint()
      ..color = IndustrialPalette.gridSteel
      ..strokeWidth = 0.7;

    // Livelli di riferimento: 0 dBFS, -20 dBFS, -40 dBFS, -60 dBFS, -80 dBFS
    final levels = [0.0, -20.0, -40.0, -60.0, -80.0];
    for (final lvl in levels) {
      final double y = ((0.0 - lvl) / 100.0).clamp(0.0, 1.0) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    if (magnitudesDbfs.isEmpty) return;

    final int count = magnitudesDbfs.length;
    final double barGap = 1.5;
    final double barWidth = max(2.0, (w - (count - 1) * barGap) / count);

    final barPaint = Paint()..color = barColor;
    final peakPaint = Paint()..color = IndustrialPalette.alertRed;

    for (int i = 0; i < count; i++) {
      final double db = magnitudesDbfs[i].clamp(-100.0, 0.0);
      final double heightRatio = (db + 100.0) / 100.0;
      final double barH = heightRatio * h;
      final double x = i * (barWidth + barGap);
      final double y = h - barH;

      // Se il bin è vicino al picco dominante o supera -20 dBFS, evidenzia
      final bool isSpike = db >= -20.0;
      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth, barH),
        isSpike ? peakPaint : barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant IndustrialSpectrumPainter oldDelegate) => true;
}

/// Overlay Modale di Calibrazione Iniziale dell'Ambiente (30 Secondi Obbligatori)
class CalibrationOverlayWidget extends StatelessWidget {
  final double progress; // da 0.0 a 1.0
  final int remainingSeconds;
  final int sampleCount;
  final VoidCallback? onCancel;

  const CalibrationOverlayWidget({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    required this.sampleCount,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: IndustrialPalette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IndustrialPalette.alertAmber, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sensors,
              color: IndustrialPalette.alertAmber,
              size: 40,
            ),
            const SizedBox(height: 14),
            const Text(
              'CALIBRAZIONE BASELINE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: IndustrialPalette.alertAmber,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Mantenere il dispositivo fermo su una superficie stazionaria per campionare il rumore di fondo dell\'edificio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: IndustrialPalette.textWhite,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${remainingSeconds}s',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: IndustrialPalette.phosphorCyan,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: IndustrialPalette.gridSteel,
                valueColor: const AlwaysStoppedAnimation<Color>(IndustrialPalette.alertAmber),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Campioni acquisiti: $sampleCount | Algoritmo di Welford',
              style: const TextStyle(
                fontSize: 11,
                color: IndustrialPalette.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: IndustrialPalette.textMuted,
                  side: const BorderSide(color: IndustrialPalette.border),
                ),
                child: const Text('ANNULLA CALIBRAZIONE'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
