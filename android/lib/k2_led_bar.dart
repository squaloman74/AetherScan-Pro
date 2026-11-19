import 'package:flutter/material.dart';
import 'industrial_ui.dart';
import 'k2_controller.dart';

/// Barra a LED Progressivi in Stile K2 (Misuratore Elettromagnetico Metrologico Modulare)
/// ====================================================================================
/// Scala fisica a 5 segmenti pilotata in tempo reale dal controller indipendente K2Controller
/// oppure dai valori diretti di delta EMF (|ΔEMF| in µT):
/// - LED 1: Verde   (Normale / Fondo: < 1.5 µT)
/// - LED 2: Verde   (Fluttuazione Lieve: 1.5 - 2.5 µT)
/// - LED 3: Giallo  (Anomalia Misurabile: 2.5 - 10.0 µT)
/// - LED 4: Ambra   (Campo Elevato: 10.0 - 20.0 µT)
/// - LED 5: Rosso   (Picco Estremo / Saturazione: >= 20.0 µT)
class K2LedBarWidget extends StatelessWidget {
  final K2Controller? controller;
  final double currentEmf;
  final double deltaEmf;
  final double zScore;
  final VoidCallback? onQuickTare;

  const K2LedBarWidget({
    super.key,
    this.controller,
    this.currentEmf = 42.0,
    this.deltaEmf = 0.0,
    this.zScore = 0.0,
    this.onQuickTare,
  });

  /// Costruttore modulare e disaccoppiato basato su K2Controller
  const K2LedBarWidget.modular({
    super.key,
    required K2Controller this.controller,
    this.onQuickTare,
  })  : currentEmf = 42.0,
        deltaEmf = 0.0,
        zScore = 0.0;

  /// Determina il numero di LED accesi (da 1 a 5) in base al delta assoluto
  int get activeLedCount {
    if (controller != null) return controller!.activeLedCount;
    final mag = deltaEmf.abs();
    if (mag >= 20.0) return 5;
    if (mag >= 10.0) return 4;
    if (mag >= 2.5) return 3;
    if (mag >= 1.5) return 2;
    return 1;
  }

  static const List<_K2LedConfig> _ledConfigs = [
    _K2LedConfig(
      label: 'NORM',
      sublabel: '<1.5µT',
      activeColor: IndustrialPalette.phosphorGreen,
      glowColor: Color(0x6600FF66),
    ),
    _K2LedConfig(
      label: 'LOW',
      sublabel: '1.5-2.5',
      activeColor: Color(0xFF55FF55),
      glowColor: Color(0x6655FF55),
    ),
    _K2LedConfig(
      label: 'MID',
      sublabel: '2.5-10',
      activeColor: Color(0xFFFFDD00),
      glowColor: Color(0x66FFDD00),
    ),
    _K2LedConfig(
      label: 'HIGH',
      sublabel: '10-20',
      activeColor: IndustrialPalette.alertAmber,
      glowColor: Color(0x66FF9900),
    ),
    _K2LedConfig(
      label: 'MAX',
      sublabel: '≥20µT',
      activeColor: IndustrialPalette.alertRed,
      glowColor: Color(0x88FF2222),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller!,
        builder: (context, _) => _buildBar(
          context: context,
          curEmf: controller!.currentEmf,
          dEmf: controller!.deltaEmf,
          count: controller!.activeLedCount,
        ),
      );
    }

    return _buildBar(
      context: context,
      curEmf: currentEmf,
      dEmf: deltaEmf,
      count: activeLedCount,
    );
  }

  Widget _buildBar({
    required BuildContext context,
    required double curEmf,
    required double dEmf,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: IndustrialPalette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: count >= 4 ? IndustrialPalette.alertAmber : IndustrialPalette.border,
          width: count >= 4 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Intestazione K2 + Valori + Bottone Tara Rapida
          Row(
            children: [
              const Icon(Icons.flash_on, color: IndustrialPalette.alertAmber, size: 14),
              const SizedBox(width: 4),
              const Text(
                'K2 FIELD METER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 0.8,
                  color: IndustrialPalette.textWhite,
                ),
              ),
              const Spacer(),
              Text(
                '${curEmf.toStringAsFixed(1)} µT (Δ ${dEmf >= 0 ? '+' : ''}${dEmf.toStringAsFixed(1)})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: count >= 3 ? _ledConfigs[count - 1].activeColor : IndustrialPalette.phosphorCyan,
                ),
              ),
              if (onQuickTare != null || controller != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    controller?.tare();
                    onQuickTare?.call();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: IndustrialPalette.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: IndustrialPalette.phosphorCyan.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.exposure_zero, size: 11, color: IndustrialPalette.phosphorCyan),
                        SizedBox(width: 2),
                        Text(
                          'TARA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: IndustrialPalette.phosphorCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 5 Segmenti LED Orizzontali
          Row(
            children: List.generate(_ledConfigs.length, (index) {
              final isLit = index < count;
              final cfg = _ledConfigs[index];

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 3,
                    right: index == _ledConfigs.length - 1 ? 0 : 3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Segmento Fisico LED
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 60),
                        height: 12,
                        decoration: BoxDecoration(
                          color: isLit ? cfg.activeColor : const Color(0xFF1A232E),
                          borderRadius: BorderRadius.circular(2.5),
                          border: Border.all(
                            color: isLit ? cfg.activeColor : IndustrialPalette.border.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                          boxShadow: isLit
                              ? [
                                  BoxShadow(
                                    color: cfg.glowColor,
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Etichetta Segmento (NORM, LOW, MID, HIGH, MAX)
                      Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isLit ? cfg.activeColor : IndustrialPalette.textMuted.withValues(alpha: 0.5),
                        ),
                      ),

                      // Range µT (<1.5µT, 1.5-2.5, ecc.)
                      Text(
                        cfg.sublabel,
                        style: TextStyle(
                          fontSize: 7,
                          fontFamily: 'monospace',
                          color: isLit ? IndustrialPalette.textWhite : IndustrialPalette.textMuted.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _K2LedConfig {
  final String label;
  final String sublabel;
  final Color activeColor;
  final Color glowColor;

  const _K2LedConfig({
    required this.label,
    required this.sublabel,
    required this.activeColor,
    required this.glowColor,
  });
}
