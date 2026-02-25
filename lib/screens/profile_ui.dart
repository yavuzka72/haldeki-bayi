// lib/widgets/profile_ui.dart
import 'package:flutter/material.dart';

class ProfileUiTokens {
  // ---- Theme tokens (premium)
  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE6E8EF);

  static const Color green = Color(0xFF0D4631);
  static const Color blue = Color(0xFF0D4631);
  static const Color amber = Color(0xFF0D4631);
  static const Color red = Color(0xFFEF4444);
}

class ProfileSectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const ProfileSectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ProfileUiTokens.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProfileUiTokens.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ProfileUiTokens.text,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Divider(height: 1)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: ProfileUiTokens.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class ProfileInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfoLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfileUiTokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ProfileUiTokens.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: ProfileUiTokens.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ProfileUiTokens.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ProfileAlertTone { danger, info }

class ProfileAlertBar extends StatelessWidget {
  final ProfileAlertTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const ProfileAlertBar({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = tone == ProfileAlertTone.danger
        ? ProfileUiTokens.red
        : ProfileUiTokens.blue;

    return Material(
      color: c.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$title: $message",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
