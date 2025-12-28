import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = cs.primary;
    final tertiaryColor = cs.tertiary;
    final surfaceColor = cs.surface;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Color.lerp(surfaceColor, Colors.black, 0.2)!,
                  Color.lerp(surfaceColor, Colors.black, 0.4)!,
                ]
              : [
                  Colors.white,
                  Color.lerp(Colors.white, primaryColor, 0.05)!,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -10),
            spreadRadius: 2,
          ),
        ],
        border: Border(
          top: BorderSide(color: primaryColor.withOpacity(0.2), width: 1),
        ),
      ),
      // ✅ IMPORTANT: bottom inset only
      child: SafeArea(
        top: false,
        child: SizedBox(
          // ✅ IMPORTANT: a stable height for all devices
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                  isDark: isDark,
                  primaryColor: primaryColor,
                  tertiaryColor: tertiaryColor,
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Contacts',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                  isDark: isDark,
                  primaryColor: primaryColor,
                  tertiaryColor: tertiaryColor,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                  isDark: isDark,
                  primaryColor: primaryColor,
                  tertiaryColor: tertiaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final Color primaryColor;
  final Color tertiaryColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) => _controller.forward();

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _controller.reverse();

  Color _getInactiveIconColor() {
    return widget.isDark
        ? widget.primaryColor.withOpacity(0.7)
        : widget.primaryColor;
  }

  Color _getInactiveTextColor() {
    return widget.isDark
        ? widget.primaryColor.withOpacity(0.8)
        : widget.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,

          // ✅ FIX: remove vertical padding to prevent height squeeze
          padding: const EdgeInsets.symmetric(horizontal: 14),

          decoration: BoxDecoration(
            gradient: widget.isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.primaryColor, widget.tertiaryColor],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(
                        widget.isDark ? 0.4 : 0.3,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  widget.isActive ? widget.activeIcon : widget.icon,
                  key: ValueKey<bool>(widget.isActive),
                  color: widget.isActive ? Colors.white : _getInactiveIconColor(),

                  // ✅ FIX: slightly smaller icon
                  size: 22,
                ),
              ),

              // ✅ FIX: smaller spacing
              const SizedBox(height: 2),

              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  // ✅ FIX: stable font size
                  fontSize: 11,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w600,
                  color: widget.isActive ? Colors.white : _getInactiveTextColor(),
                ),
                child: Text(
                  widget.label,

                  // ✅ FIX: prevent font scaling overflow
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
