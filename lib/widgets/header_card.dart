import 'package:flutter/material.dart';

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
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(subtitle, style: const TextStyle(color: Colors.greenAccent)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Rutinas claras para entrenadores y usuarios',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea clientes, asigna rutinas y registra el progreso con datos guardados en Firebase.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
