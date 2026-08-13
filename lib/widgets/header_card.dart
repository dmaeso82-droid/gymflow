import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

class HeaderCard extends StatelessWidget {
  final String subtitle;

  const HeaderCard({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.gymFitnessAccent.withValues(alpha: context.gymIsDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: context.gymFitnessAccent, size: 16),
                const SizedBox(width: 6),
                Text(subtitle, style: TextStyle(color: context.gymFitnessAccent, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Rutinas claras para entrenadores y usuarios',
            style: TextStyle(color: context.gymText, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea clientes, asigna rutinas y registra el progreso con datos guardados en Firebase.',
            style: TextStyle(color: context.gymMutedText),
          ),
        ],
      ),
    );
  }
}
