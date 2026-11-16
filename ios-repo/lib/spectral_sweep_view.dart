import 'package:flutter/material.dart';
import 'industrial_ui.dart';
import 'spectral_sweep_engine.dart';

/// Vista Dedicata: AM/FM Spectral Sweep (Modalità Live Interattiva e Scientifica)
class SpectralSweepView extends StatelessWidget {
  final SweepFrame? currentFrame;
  final SweepBand currentBand;
  final SweepDirection currentDirection;
  final int sweepIntervalMs;
  final double currentEmf;
  final double deltaEmf;
  final double zScoreEmf;
  final double currentDynamicAccel;
  final List<double> fftDbfs;
  final double audioPeakHz;
  final ValueChanged<SweepBand> onBandChanged;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<SweepDirection> onDirectionChanged;
  final VoidCallback onTogglePause;

  const SpectralSweepView({
    super.key,
    required this.currentFrame,
    required this.currentBand,
    required this.currentDirection,
    required this.sweepIntervalMs,
    required this.currentEmf,
    required this.deltaEmf,
    required this.zScoreEmf,
    required this.currentDynamicAccel,
    required this.fftDbfs,
    required this.audioPeakHz,
    required this.onBandChanged,
    required this.onIntervalChanged,
    required this.onDirectionChanged,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final frame = currentFrame;
    final isPaused = currentDirection == SweepDirection.paused;
    final isModulated = frame?.isModulatedBySensor ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Radio Frequency Display & S-Meter Header ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IndustrialPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.border,
                width: isModulated ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused
                                ? IndustrialPalette.alertRed
                                : (isModulated
                                    ? IndustrialPalette.alertAmber
                                    : IndustrialPalette.phosphorGreen),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPaused
                              ? 'SWEEP PAUSATO'
                              : (isModulated ? 'MODULAZIONE FISICA ATTIVA' : 'SCANSIONE SPETTRALE CONTINUA'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      currentBand == SweepBand.fm ? 'FM VHF (87.5 - 108 MHz)' : 'AM MW (530 - 1600 kHz)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: IndustrialPalette.phosphorCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Display Digitale a Grandi Caratteri Fissi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      frame?.frequencyDisplay.split(' ').first ?? (currentBand == SweepBand.fm ? '87.5' : '530'),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 2.0,
                        color: IndustrialPalette.textWhite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentBand == SweepBand.fm ? 'MHz' : 'kHz',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: IndustrialPalette.phosphorCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // S-Meter Bar & dBm
                Row(
                  children: [
                    const Text(
                      'S-METER:',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: IndustrialPalette.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (((frame?.signalStrengthDbm ?? -120.0) + 120.0) / 100.0).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: IndustrialPalette.gridSteel,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.phosphorCyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'S${frame?.sUnits ?? 1} (${(frame?.signalStrengthDbm ?? -120.0).toStringAsFixed(0)} dBm)',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.textWhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 2. Scala Radiofonica Analogica con Indice Scorrevole ──
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: IndustrialPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IndustrialPalette.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: RadioDialPainter(
                  band: currentBand,
                  currentFreq: frame?.currentFrequency ?? (currentBand == SweepBand.fm ? 87.5 : 530.0),
                  isModulated: isModulated,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 3. Spettrogramma Live Spettrale ──
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: IndustrialPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IndustrialPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: IndustrialPalette.border)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'ANALISI SPETTRALE DSP • SENSORI FISICI REALI',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: IndustrialPalette.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Picco: ${audioPeakHz.round()} Hz',
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
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    child: CustomPaint(
                      painter: IndustrialSpectrumPainter(
                        magnitudesDbfs: fftDbfs.take(64).toList(),
                        peakFrequencyHz: audioPeakHz,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 4. Sensori Reali di Accoppiamento Fisico ──
          Row(
            children: [
              Expanded(
                child: IndustrialTelemetryCard(
                  label: 'EMF Reattivo',
                  value: currentEmf.toStringAsFixed(1),
                  unit: 'µT',
                  delta: 'Δ ${deltaEmf >= 0 ? '+' : ''}${deltaEmf.toStringAsFixed(1)} (Z=${zScoreEmf.toStringAsFixed(1)})',
                  accentColor: isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.phosphorCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IndustrialTelemetryCard(
                  label: 'Modulazione',
                  value: ((frame?.sensorCouplingFactor ?? 0.0) * 100.0).toStringAsFixed(0),
                  unit: '%',
                  delta: currentDynamicAccel >= 0.5 ? 'URTO ATTIVO' : 'CHASSIS STABILE',
                  accentColor: currentDynamicAccel >= 0.5 ? IndustrialPalette.alertRed : IndustrialPalette.phosphorGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 5. Pannello Comandi e Selettori Sweep ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IndustrialPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IndustrialPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Riga Selettori Banda (AM / FM)
                Row(
                  children: [
                    const Text(
                      'BANDA:',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: IndustrialPalette.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentBand == SweepBand.fm
                                    ? IndustrialPalette.phosphorCyan.withValues(alpha: 0.25)
                                    : IndustrialPalette.surfaceLight,
                                side: BorderSide(
                                  color: currentBand == SweepBand.fm
                                      ? IndustrialPalette.phosphorCyan
                                      : IndustrialPalette.border,
                                ),
                              ),
                              onPressed: () => onBandChanged(SweepBand.fm),
                              child: const Text('FM (VHF)', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentBand == SweepBand.am
                                    ? IndustrialPalette.alertAmber.withValues(alpha: 0.25)
                                    : IndustrialPalette.surfaceLight,
                                side: BorderSide(
                                  color: currentBand == SweepBand.am
                                      ? IndustrialPalette.alertAmber
                                      : IndustrialPalette.border,
                                ),
                              ),
                              onPressed: () => onBandChanged(SweepBand.am),
                              child: const Text('AM (MW)', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Riga Velocità di Scansione (Step Interval)
                Row(
                  children: [
                    const Text(
                      'RATE:',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: IndustrialPalette.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [50, 100, 200, 300, 500].map((ms) {
                          final isSelected = sweepIntervalMs == ms;
                          return ChoiceChip(
                            label: Text('${ms}ms', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                            selected: isSelected,
                            selectedColor: IndustrialPalette.phosphorCyan.withValues(alpha: 0.3),
                            backgroundColor: IndustrialPalette.surfaceLight,
                            onSelected: (_) => onIntervalChanged(ms),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Controlli Play / Pause e Direzione (AVANTI e INDIETRO separati e ben visibili)
                Row(
                  children: [
                    // Tasto Play / Pausa
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                        label: Text(
                          isPaused ? 'AVVIA' : 'PAUSA',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaused ? IndustrialPalette.phosphorGreen : IndustrialPalette.surfaceLight,
                          foregroundColor: isPaused ? Colors.black : IndustrialPalette.textWhite,
                          side: const BorderSide(color: IndustrialPalette.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onTogglePause,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tasto Scansione Indietro (REV)
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 13),
                        label: const Text(
                          'REV ◀',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentDirection == SweepDirection.reverse
                              ? IndustrialPalette.alertAmber.withValues(alpha: 0.25)
                              : IndustrialPalette.surfaceLight,
                          foregroundColor: currentDirection == SweepDirection.reverse
                              ? IndustrialPalette.alertAmber
                              : IndustrialPalette.textMuted,
                          side: BorderSide(
                            color: currentDirection == SweepDirection.reverse
                                ? IndustrialPalette.alertAmber
                                : IndustrialPalette.border,
                            width: currentDirection == SweepDirection.reverse ? 1.5 : 1.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => onDirectionChanged(SweepDirection.reverse),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tasto Scansione Avanti (FWD)
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 13),
                        label: const Text(
                          'FWD ▶',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentDirection == SweepDirection.forward
                              ? IndustrialPalette.phosphorCyan.withValues(alpha: 0.25)
                              : IndustrialPalette.surfaceLight,
                          foregroundColor: currentDirection == SweepDirection.forward
                              ? IndustrialPalette.phosphorCyan
                              : IndustrialPalette.textMuted,
                          side: BorderSide(
                            color: currentDirection == SweepDirection.forward
                                ? IndustrialPalette.phosphorCyan
                                : IndustrialPalette.border,
                            width: currentDirection == SweepDirection.forward ? 1.5 : 1.0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => onDirectionChanged(SweepDirection.forward),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Badge di Onestà Scientifica
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: IndustrialPalette.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: IndustrialPalette.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, size: 14, color: IndustrialPalette.phosphorGreen),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ZERO DIZIONARI O GENERATORI CASUALI. Modulazione reattiva unicamente ai sensori fisici.',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: IndustrialPalette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter per la Scala Radiofonica Vintage / Industriale
class RadioDialPainter extends CustomPainter {
  final SweepBand band;
  final double currentFreq;
  final bool isModulated;

  RadioDialPainter({
    required this.band,
    required this.currentFreq,
    required this.isModulated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Sfondo scala radio
    final bgPaint = Paint()..color = const Color(0xFF0A0F18);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final linePaint = Paint()
      ..color = IndustrialPalette.gridSteel
      ..strokeWidth = 1.0;

    // Linea orizzontale mediana
    canvas.drawLine(Offset(10, h * 0.5), Offset(w - 10, h * 0.5), linePaint);

    final double minF = band == SweepBand.fm ? 87.5 : 530.0;
    final double maxF = band == SweepBand.fm ? 108.0 : 1600.0;

    // Marcature e tacche di frequenza
    final tickPaint = Paint()
      ..color = IndustrialPalette.textMuted
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = IndustrialPalette.phosphorCyan
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final int tickCount = band == SweepBand.fm ? 41 : 21; // tacche
    for (int i = 0; i <= tickCount; i++) {
      final double ratio = i / tickCount;
      final double x = 15.0 + ratio * (w - 30.0);
      final bool isMajor = i % 5 == 0;

      final double tickH = isMajor ? 14.0 : 7.0;
      canvas.drawLine(
        Offset(x, (h * 0.5) - tickH),
        Offset(x, (h * 0.5) + tickH),
        isMajor ? majorTickPaint : tickPaint,
      );

      if (isMajor) {
        final double f = minF + ratio * (maxF - minF);
        final label = band == SweepBand.fm ? f.toStringAsFixed(0) : (f / 10).toStringAsFixed(0);
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 9,
            color: IndustrialPalette.textMuted,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - (textPainter.width / 2), (h * 0.5) - tickH - 12));
      }
    }

    // Ago / Cursore di sintonia in tempo reale
    final double curRatio = ((currentFreq - minF) / (maxF - minF)).clamp(0.0, 1.0);
    final double needleX = 15.0 + curRatio * (w - 30.0);

    final needlePaint = Paint()
      ..color = isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.alertRed
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(needleX, 6), Offset(needleX, h - 6), needlePaint);

    // Indicatore luminoso sulla punta dell'ago
    final glowPaint = Paint()
      ..color = (isModulated ? IndustrialPalette.alertAmber : IndustrialPalette.alertRed).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, h * 0.5), 4.0, glowPaint);
  }

  @override
  bool shouldRepaint(covariant RadioDialPainter oldDelegate) =>
      oldDelegate.currentFreq != currentFreq ||
      oldDelegate.band != band ||
      oldDelegate.isModulated != isModulated;
}
