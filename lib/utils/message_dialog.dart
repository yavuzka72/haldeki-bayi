import 'package:flutter/material.dart';

enum MessageType { success, warning, error }

Future<void> showMessageDialog(
  BuildContext context, {
  required String message,
  String title = "Bilgi",
  MessageType type = MessageType.success,
}) {
  Color bg;
  IconData icon;

  switch (type) {
    case MessageType.success:
      bg = Colors.green;
      icon = Icons.check_circle_outline;
      break;
    case MessageType.warning:
      bg = Colors.amber;
      icon = Icons.warning_amber_outlined;
      break;
    case MessageType.error:
      bg = Colors.red;
      icon = Icons.error_outline;
      break;
  }

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420, // geniş ekranlarda ufak dikdörtgen
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 34, color: bg),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton(
                      // ⚠️ ÖNEMLİ: ctx kullanıyoruz
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("Tamam"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
