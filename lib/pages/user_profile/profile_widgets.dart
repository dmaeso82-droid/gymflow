part of '../user_profile_page.dart';

class _ProfileMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProfileMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.gymBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.gymPrimary, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.gymMutedText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.gymPrimary, size: 20),
        SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String text;

  const _ProfileChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.gymFitnessAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
