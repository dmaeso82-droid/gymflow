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
    final bubbleColor = isMine
        ? context.gymPrimary.withValues(alpha: context.gymIsDark ? 0.24 : 0.13)
        : context.gymSubtleSurface.withValues(alpha: 0.92);
    final bubbleBorder = isMine ? context.gymPrimary.withValues(alpha: 0.34) : context.gymBorder;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 20),
          ),
          border: Border.all(color: bubbleBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.gymIsDark ? 0.16 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && sender.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded, size: 13, color: context.gymPrimary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: context.gymPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(text, style: TextStyle(color: context.gymText, height: 1.28, fontSize: 14.5, fontWeight: FontWeight.w600)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.gymSurface.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.gymBorder.withValues(alpha: 0.45)),
                  ),
                  child: Text(time, style: TextStyle(color: context.gymMutedText, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
