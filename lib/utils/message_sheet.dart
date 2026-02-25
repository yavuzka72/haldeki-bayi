import 'package:flutter/material.dart';

enum MessageType { success, warning, error }

void showMessageSheet(
  BuildContext context, {
  required String message,
  MessageType type = MessageType.success,
}) {
  Color bg;
  IconData icon;

  switch (type) {
    case MessageType.success:
      bg = Colors.green;
      icon = Icons.check_circle;
      break;
    case MessageType.warning:
      bg = Colors.amber;
      icon = Icons.warning_rounded;
      break;
    case MessageType.error:
      bg = Colors.red;
      icon = Icons.error;
      break;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  // Otomatik kapanma (SnackBar gibi)
  Future.delayed(const Duration(seconds: 2), () {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  });
}
