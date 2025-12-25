import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
import '../encryption_page.dart';
import '../decryption_page.dart';
import '../inbox_page.dart';
import '../key_generation.dart';
import '../key_scanner.dart';
import '../widgets/app_drawer.dart';

// If you want to use your bottom nav later:
// import 'UI/bottom_navigate.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          // ✅ NEW: use your custom sidebar drawer
          drawer: const AppDrawer(),

          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1A1A), const Color(0xFF2C2C2C)]
                    : [Colors.white, const Color(0xFFF5F5F0)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top header row
                    Row(
                      children: [
                        // ✅ FIX: openDrawer must use Builder context
                        Builder(
                          builder: (ctx) => _IconBox(
                            icon: Icons.menu,
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                            isDark: isDark,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Text(
                              'WAShield',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Encrypt First. Send Securely',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _IconBox(
                          icon: isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          onTap: themeProvider.toggleTheme,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Shortcut panel (Scan / My Key / Inbox)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  cs.primary.withOpacity(0.55),
                                  cs.primary.withOpacity(0.30),
                                ]
                              : [
                                  cs.primary.withOpacity(0.92),
                                  cs.primary.withOpacity(0.75),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(isDark ? 0.20 : 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.qr_code_scanner,
                              label: 'Scan',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const KeyScannerPage(),
                                ),
                              ),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.key,
                              label: 'My Key',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const KeyGenerationPage(),
                                ),
                              ),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.inbox,
                              label: 'Inbox',
                              //badge: '', // quantity of messages in inbox
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InboxPage(),
                                ),
                              ),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Message Security',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[200] : Colors.grey[900],
                          ),
                    ),
                    const SizedBox(height: 14),

                    // Encrypt / Decrypt tiles
                    Row(
                      children: [
                        Expanded(
                          child: _BigAction(
                            title: 'Encrypt',
                            icon: Icons.lock,
                            filled: true,
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EncryptionPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _BigAction(
                            title: 'Decrypt',
                            icon: Icons.lock_open,
                            filled: false,
                            isDark: isDark,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DecryptionPage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Bottom filler cards
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            title: 'Security Tips',
                            subtitle:
                                'Only save public keys from trusted contacts.',
                            icon: Icons.shield_outlined,
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoCard(
                            title: 'Quick Reminder',
                            subtitle: 'Generate keys before encrypting.',
                            icon: Icons.info_outline,
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _BottomBanner(isDark: isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ---------- Small widgets ----------

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? cs.surface.withOpacity(0.55) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(isDark ? 0.10 : 0.12),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: isDark ? Colors.grey[200] : Colors.grey[900]),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark, this.badge, // quantity of messages in inbox if any
  });

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: cs.primary, size: 28),
                ),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.title,
    required this.icon,
    required this.filled,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = filled
        ? cs.primary.withOpacity(isDark ? 0.80 : 0.92)
        : (isDark ? Colors.black.withOpacity(0.18) : Colors.white);

    final border = filled ? Colors.transparent : cs.primary;
    final fg = filled ? Colors.white : cs.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 126,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 2),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(isDark ? 0.10 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: fg),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]?.withOpacity(0.55) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.primary.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary, size: 26),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBanner extends StatelessWidget {
  const _BottomBanner({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [cs.primary.withOpacity(0.30), Colors.black.withOpacity(0.10)]
              : [cs.primary.withOpacity(0.16), Colors.white.withOpacity(0.75)],
        ),
        border: Border.all(color: cs.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 60, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure by Design',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan keys, generate your keys, then encrypt before sending.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
