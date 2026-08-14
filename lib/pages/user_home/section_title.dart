part of '../user_home_page.dart';

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: context.gymFitnessAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: context.gymPrimary, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
      ],
    );
  }
}
