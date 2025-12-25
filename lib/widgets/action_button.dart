import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isDark,
    this.isSecondary = false,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final bool isSecondary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: isSecondary
              ? LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF8B9D3F).withValues(alpha: 0.3),
                          const Color(0xFF8B9D3F).withValues(alpha: 0.1),
                        ]
                      : [
                          const Color(0xFF6B8E23).withValues(alpha: 0.1),
                          const Color(0xFF6B8E23).withValues(alpha: 0.05),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF8B9D3F), const Color(0xFF7A8E35)]
                      : [const Color(0xFF6B8E23), const Color(0xFF5A7C1F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF8B9D3F).withValues(alpha: 0.4)
                : const Color(0xFF6B8E23).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF8B9D3F).withValues(alpha: 0.2)
                  : const Color(0xFF6B8E23).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSecondary
                  ? (isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23))
                  : Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isSecondary
                        ? (isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23))
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
