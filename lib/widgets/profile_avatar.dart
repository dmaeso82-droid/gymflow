import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.size = 56,
  });

  String initialsFromName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '?';

    final parts = clean
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      final first = parts.first;
      return first.characters.take(2).toString().toUpperCase();
    }

    return parts
        .take(3)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }

  Color colorFromName(String value) {
    final colors = [
      Colors.greenAccent,
      Colors.lightBlueAccent,
      Colors.amberAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
    ];

    final index = value.codeUnits.fold<int>(0, (sum, code) => sum + code) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFromName(name);
    final initials = initialsFromName(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: initials.length >= 3 ? size * 0.30 : size * 0.34,
          ),
        ),
      ),
    );
  }
}
