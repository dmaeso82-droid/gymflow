import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InfoChip extends StatelessWidget {
  final String text;

  InfoChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: TextStyle(fontSize: 12, color: context.gymText)),
      visualDensity: VisualDensity.compact,
      backgroundColor: context.gymSubtleSurface,
      side: BorderSide(color: context.gymBorder),
    );
  }
}



