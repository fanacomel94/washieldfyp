import 'dart:math' as math;
import 'package:flutter/material.dart';

class KeyScannerScanUi extends StatelessWidget {
  const KeyScannerScanUi({
    super.key,
    required this.onBack,
    required this.onToggleTorch,
    required this.isTorchOn,
    required this.cameraPreview,
    required this.onChooseFromMedia,
  });

  final VoidCallback onBack;
  final VoidCallback onToggleTorch;
  final bool isTorchOn;

  /// Put your MobileScanner widget here (already has controller+onDetect).
  final Widget cameraPreview;

  final VoidCallback onChooseFromMedia;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F10),
      body: Stack(
        children: [
          Positioned.fill(child: cameraPreview),

          // dark overlay
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleDarkBtn(
                        icon: Icons.arrow_back,
                        onTap: onBack,
                      ),
                      const Spacer(),
                      _CircleDarkBtn(
                        icon: isTorchOn ? Icons.flash_on : Icons.flash_off,
                        onTap: onToggleTorch,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Scan QR key',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scan other washield user',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.70),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),

                  const _ScannerFrame(),

                  const Spacer(),

                  _ChooseMediaBtn(onTap: onChooseFromMedia),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeyScannerScannedUi extends StatelessWidget {
  const KeyScannerScannedUi({
    super.key,
    required this.onBack,
    required this.primaryColor,
    required this.displayName,
    required this.phoneDisplay,
    required this.publicKeyPreview,
    required this.onSave,
    required this.onSaveAndScanAgain,
    required this.isSaving,
  });

  final VoidCallback onBack;
  final Color primaryColor;

  final String displayName;
  final String phoneDisplay;
  final String publicKeyPreview;

  final VoidCallback onSave;
  final VoidCallback onSaveAndScanAgain;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFDDF1E1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _CircleLightBtn(
            icon: Icons.arrow_back,
            onTap: onBack,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scanned profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Review details before saving to your contacts.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 10),
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _AvatarLetter(letter: _firstLetter(displayName)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isEmpty ? 'Unknown' : displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                phoneDisplay.isEmpty ? 'No phone' : phoneDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _BarcodeBox(primaryColor: primaryColor),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This public key was read from the QR code.\nPrivate keys are never shared.',
                      style: TextStyle(
                        height: 1.35,
                        color: Colors.black.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Public key',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text(
                        publicKeyPreview.isEmpty ? '-' : publicKeyPreview,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(
                    isSaving ? 'Saving...' : 'Save contact',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onSaveAndScanAgain,
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text(
                    'Save & scan again',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white.withOpacity(0.40),
                    side: BorderSide(
                      color: primaryColor.withOpacity(0.30),
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstLetter(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'A';
    return t.characters.first.toUpperCase();
  }
}

/// --- Small components ---

class _CircleDarkBtn extends StatelessWidget {
  const _CircleDarkBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _CircleLightBtn extends StatelessWidget {
  const _CircleLightBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.70),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _ChooseMediaBtn extends StatelessWidget {
  const _ChooseMediaBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Choose from media',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatefulWidget {
  const _ScannerFrame();

  @override
  State<_ScannerFrame> createState() => _ScannerFrameState();
}

class _ScannerFrameState extends State<_ScannerFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final y = (size * 0.18) +
              (size * 0.64) * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi));
          return CustomPaint(
            painter: _FramePainter(scanY: y),
          );
        },
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.scanY});

  final double scanY;

  @override
  void paint(Canvas canvas, Size size) {
    const corner = 26.0;
    const stroke = 3.0;
    const lineColor = Color(0xFF35D07F);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = lineColor;

    void cornerLine(Offset a, Offset b) => canvas.drawLine(a, b, p);

    final c = corner;
    final w = size.width;
    final h = size.height;

    cornerLine(const Offset(0, 0), Offset(c, 0));
    cornerLine(const Offset(0, 0), Offset(0, c));

    cornerLine(Offset(w, 0), Offset(w - c, 0));
    cornerLine(Offset(w, 0), Offset(w, c));

    cornerLine(Offset(0, h), Offset(c, h));
    cornerLine(Offset(0, h), Offset(0, h - c));

    cornerLine(Offset(w, h), Offset(w - c, h));
    cornerLine(Offset(w, h), Offset(w, h - c));

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = lineColor.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = lineColor.withOpacity(0.95);

    canvas.drawLine(Offset(26, scanY), Offset(w - 26, scanY), glow);
    canvas.drawLine(Offset(26, scanY), Offset(w - 26, scanY), line);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.scanY != scanY;
}

class _AvatarLetter extends StatelessWidget {
  const _AvatarLetter({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );
  }
}

class _BarcodeBox extends StatelessWidget {
  const _BarcodeBox({required this.primaryColor});
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.35),
            Colors.black.withOpacity(0.70),
          ],
        ),
      ),
      child: CustomPaint(painter: _BarsPainter()),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final x = [10.0, 18.0, 26.0, 34.0, 42.0, 50.0];
    for (final xi in x) {
      canvas.drawLine(Offset(xi, 14), Offset(xi, size.height - 14), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
