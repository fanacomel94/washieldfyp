import 'package:flutter/material.dart';

Widget sectionLabel(String text, Color textColor) {
  return Text(
    text,
    style: TextStyle(
      color: textColor,
      fontWeight: FontWeight.w800,
    ),
  );
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: fg.withOpacity(0.10)),
        ),
        child: Icon(icon, color: fg),
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({
    super.key,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.onSelect,
  });

  final Color bg;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onSelect,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: primaryColor.withOpacity(0.10),
              ),
              child: Icon(Icons.person_search, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class TextCardField extends StatelessWidget {
  const TextCardField({
    super.key,
    required this.bg,
    required this.primaryColor,
    required this.textColor,
    required this.hintColor,
    required this.controller,
    required this.hintText,
    this.suffixIcon,
    this.onSuffixTap,
    this.maxLines = 1,
    this.keyboardType,
  });

  final Color bg;
  final Color primaryColor;
  final Color textColor;
  final Color? hintColor;
  final TextEditingController controller;
  final String hintText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
              ),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              cursorColor: primaryColor,
            ),
          ),
          if (suffixIcon != null) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onSuffixTap,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(suffixIcon, color: primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SmallChipButton extends StatelessWidget {
  const SmallChipButton({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
