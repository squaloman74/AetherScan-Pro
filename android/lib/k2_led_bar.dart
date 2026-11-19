import 'package:flutter/material.dart';
import 'industrial_ui.dart';

/// Barra a LED Progressivi in Stile K2 (Misuratore Elettromagnetico Metrologico)
/// =============================================================================
/// Scala fisica a 5 segmenti pilotata in tempo reale dal valore di delta EMF (|ΔEMF| in µT):
/// - LED 1: Verde   (Normale / Fondo: 0.0 - 1.5 µT)
/// - LED 2: Verde   (Fluttuazione Lieve: 1.5 - 2.5 µT)
/// - LED 3: Giallo  (Anomalia Misurabile: 2.5 - 10.0 µT)
/// - LED 4: Ambra   (Campo Elevato: 10.0 - 20.0 µT)
/// - LED 5: Rosso   (Picco Estremo / Saturazione: >= 20.0 µT)
class K2LedBarWidget extends StatelessWidget {
  final double currentEmf;
  final double deltaEmf;
  final double zScore;
  final VoidCallback? onQuickTare;

  const K2LedBarWidget({
    super.key,
    required this.currentEmf,
    required this.deltaEmf,
    required this.zScore,
    this.onQuickTare,
  });

  /// Determina il numero di LED accesi (da 1 a 5) in base al delta assoluto
  int get activeLedCount {
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
    final count = activeLedCount;

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
                '${currentEmf.toStringAsFixed(1)} µT (Δ ${deltaEmf >= 0 ? '+' : ''}${deltaEmf.toStringAsFixed(1)})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: count >= 3 ? _ledConfigs[count - 1].activeColor : IndustrialPalette.phosphorCyan,
                ),
              ),
              if (onQuickTare != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onQuickTare,
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
                            fontSize: 8.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
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
          const SizedBox(height: 6),

          // 5 Segmenti LED K2
          Row(
            children: List.generate(5, (index) {
              final isLit = index < count;
              final cfg = _ledConfigs[index];

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 3,
                    right: index == 4 ? 0 : 3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LED Element Fisico
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: isLit ? cfg.activeColor : IndustrialPalette.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: isLit ? cfg.activeColor : IndustrialPalette.border,
                            width: 1.0,
                          ),
                          boxShadow: isLit
                              ? [
                                  BoxShadow(
                                    color: cfg.glowColor,
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Etichetta del segmento
                      Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isLit ? cfg.activeColor : IndustrialPalette.textMuted,
                        ),
                      ),
                      Text(
                        cfg.sublabel,
                        style: const TextStyle(
                          fontSize: 6.5,
                          fontFamily: 'monospace',
                          color: IndustrialPalette.textMuted,
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
