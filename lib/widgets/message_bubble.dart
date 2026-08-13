import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMine;

  const MessageBubble({super.key, required this.data, required this.isMine});

  String formatTime(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final text = data['text']?.toString() ?? '';
    final sender = data['senderName']?.toString() ?? '';
    final time = formatTime(data['createdAt']);
    final bubbleColor = isMine ? context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.20 : 0.12) : context.gymSurface;
    final bubbleBorder = isMine ? context.gymPrimary.withValues(alpha: 0.34) : context.gymBorder;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: Border.all(color: bubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && sender.isNotEmpty) ...[
              Text(sender, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: context.gymPrimary)),
              const SizedBox(height: 3),
            ],
            Text(text, style: TextStyle(color: context.gymText, height: 1.25)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(time, style: TextStyle(color: context.gymMutedText, fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
