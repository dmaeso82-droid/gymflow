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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.gymSubtleSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.gymBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.gymPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: context.gymPrimary, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.gymText, fontSize: 21, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymMutedText, fontSize: 12, fontWeight: FontWeight.w700)),
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
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.gymPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: context.gymPrimary, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: TextStyle(color: context.gymText, fontSize: 18, fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _ProfileChip({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.gymFitnessAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.gymFitnessAccent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: context.gymPrimary),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(color: context.gymPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
