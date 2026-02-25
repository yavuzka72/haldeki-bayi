import 'package:flutter/material.dart';

enum MessageType { success, warning, error }

void showCenterToast(
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
      bg = Colors.amber.shade700;
      icon = Icons.warning_rounded;
      break;
    case MessageType.error:
      bg = Colors.red;
      icon = Icons.error;
      break;
  }

  // Overlay oluştur
  final overlay = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        // Merkezde kutu
        Center(
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // Overlay ekle
  Overlay.of(context).insert(overlay);

  // 2 saniye sonra kapanır
  Future.delayed(const Duration(seconds: 2)).then((_) {
    overlay.remove();
  });
}
