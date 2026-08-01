import 'package:flutter/material.dart';

class InfoChip extends StatelessWidget {
  final String text;

  const InfoChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFF0F172A),
      side: BorderSide.none,
    );
  }
}
