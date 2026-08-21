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
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final background = isMine
        ? context.gymPrimary
        : context.gymSubtleSurface.withValues(alpha: context.gymIsDark ? 0.72 : 0.82);
    final foreground = isMine ? Colors.white : context.gymText;
    final muted = isMine ? Colors.white.withValues(alpha: 0.78) : context.gymMutedText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 7),
            bottomRight: Radius.circular(isMine ? 7 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.gymIsDark ? 0.14 : 0.045),
              blurRadius: 16,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && sender.isNotEmpty) ...[
              Text(sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.gymPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
            ],
            Text(text, style: TextStyle(color: foreground, height: 1.30, fontSize: 14.5, fontWeight: FontWeight.w600)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(time, style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
