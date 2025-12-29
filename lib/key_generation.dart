
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'cryptomanager.dart';
import 'key_scanner.dart';
import 'theme/theme_provider.dart';

class KeyGenerationPage extends StatefulWidget {
  const KeyGenerationPage({super.key});

  @override
  State<KeyGenerationPage> createState() => _KeyGenerationPageState();
}

class _KeyGenerationPageState extends State<KeyGenerationPage> {
  late String _x25519PublicKey = '';
  late String _ed25519PublicKey = '';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _myPhone = '';
  String _myUsername = '';
  String _myUserId = '';

  String _qrData = '';
  String? _error;

  // Expiry policy (change if you want)
  static const Duration _keyValidity = Duration(days: 30);

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadProfileStrict();
    if (!mounted) return;
    if (_error != null) {
      setState(() {});
      return;
    }
    await _initKeysAndQr();
  }

  Future<void> _loadProfileStrict() async {
    try {
      final phone = (await _secureStorage.read(key: 'wa_shield_my_phone') ?? '')
          .trim();
      final username =
          (await _secureStorage.read(key: 'wa_shield_my_username') ?? '')
              .trim();
      final userId = (await _secureStorage.read(key: 'wa_shield_user_id') ?? '')
          .trim();

      if (phone.isEmpty || username.isEmpty || userId.isEmpty) {
        _error = 'Please register first (missing User ID / Username / Phone).';
        _myPhone = '';
        _myUsername = '';
        _myUserId = '';
        return;
      }

      _myPhone = phone;
      _myUsername = username;
      _myUserId = userId;
      _error = null;
    } catch (_) {
      _error = 'Failed to load profile. Please register again.';
    }
  }

  Future<void> _initKeysAndQr() async {
    try {
      await CryptoManager.ensureKeysExist();
      final pubs = await CryptoManager.getStoredPublicKeys();
      _x25519PublicKey = (pubs['x25519_public'] ?? '').trim();
      _ed25519PublicKey = (pubs['ed25519_public'] ?? '').trim();

      if (_x25519PublicKey.isEmpty || _ed25519PublicKey.isEmpty) {
        _error = 'Keys not found. Please generate keys again.';
        _qrData = '';
        return;
      }
      if (!CryptoManager.validatePublicKey(_x25519PublicKey)) {
        _error = 'Your X25519 public key is invalid. Generate new keys.';
        _qrData = '';
        return;
      }
      if (!CryptoManager.validatePublicKey(_ed25519PublicKey)) {
        _error = 'Your Ed25519 public key is invalid. Generate new keys.';
        _qrData = '';
        return;
      }

      await _buildSignedQrStrict();
      _error = null;
    } catch (_) {
      _x25519PublicKey = '';
      _ed25519PublicKey = '';
      _qrData = '';
      _error = 'Failed to initialize keys.';
    }

    if (mounted) setState(() {});
  }

  // ✅ COMPACT PAYLOAD (short keys) BUT STILL INCLUDES username + phone
  Future<void> _buildSignedQrStrict() async {
    if (_myUserId.trim().isEmpty ||
        _myUsername.trim().isEmpty ||
        _myPhone.trim().isEmpty) {
      _qrData = '';
      _error = 'Please register first.';
      return;
    }
    if (_x25519PublicKey.isEmpty || _ed25519PublicKey.isEmpty) {
      _qrData = '';
      _error = 'Keys missing. Generate keys first.';
      return;
    }

    final issuedAt = DateTime.now().toUtc();
    final expiresAt = issuedAt.add(_keyValidity);

    final payload = await CryptoManager.buildCompactSignedQrPayload(
      // Keep identity
      userId: _myUserId.trim(),
      username: _myUsername.trim(),
      phone: _myPhone.trim(),

      // Keep both keys
      x25519PublicKeyBase64: _x25519PublicKey.trim(),
      ed25519PublicKeyBase64: _ed25519PublicKey.trim(),

      // Use epoch seconds to reduce size
      issuedAtUtc: issuedAt,
      expiresAtUtc: expiresAt,
    );

    // jsonEncode is minified already (no spaces)
    _qrData = jsonEncode(payload);
  }

  Future<void> _refreshKeys() async {
    if (_error != null) {
      _showSnack(_error!);
      return;
    }

    try {
      final newPubs = await CryptoManager.rotateKeys();

      _x25519PublicKey = (newPubs['x25519_public'] ?? '').trim();
      _ed25519PublicKey = (newPubs['ed25519_public'] ?? '').trim();

      if (_x25519PublicKey.isEmpty || _ed25519PublicKey.isEmpty) {
        _showSnack('Failed to rotate keys.');
        return;
      }

      await _buildSignedQrStrict();
      if (mounted) setState(() {});
    } catch (_) {
      _showSnack('Failed to generate new keys.');
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    if (text.trim().isEmpty) {
      _showSnack('Nothing to copy.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('$label copied to clipboard');
    } catch (_) {
      _showSnack('Failed to copy.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _maskKey(String key) {
    final clean = key.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 10) return clean;
    final head = clean.substring(0, 4);
    final tail = clean.substring(clean.length - 4);
    return '$head...$tail';
  }

  Future<void> _confirmChangeKey(Color primaryColor, bool isDark) async {
    final cs = Theme.of(context).colorScheme;

    final surface = cs.surface;
    final text = isDark ? Colors.white : Colors.black87;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          'Change Key?',
          style: TextStyle(color: text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Once you change key, you need to exchange key again with receiver.',
          style: TextStyle(color: text.withOpacity(0.85), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: text)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Change New Key'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _refreshKeys();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final cs = Theme.of(context).colorScheme;

        // ✅ Follow app theme
        final primaryColor = cs.primary;
        final pageBg = Theme.of(context).scaffoldBackgroundColor;
        final cardBg = cs.surface;

        // text
        final textColor = isDark ? Colors.white : Colors.black87;
        final subText = isDark ? Colors.white70 : Colors.black54;

        final canShowQr = _qrData.isNotEmpty && _error == null;

        final displayName = _myUsername.isNotEmpty ? _myUsername : 'Unknown';
        final pkPreview = _maskKey(_x25519PublicKey);

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            // uses AppTheme appBarTheme automatically
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
                bg: cardBg,
                fg: textColor,
              ),
            ),
            title: Text(
              'My Key',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(isDark ? 0.20 : 0.14),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(color: primaryColor.withOpacity(0.14)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 2),
                          color: primaryColor.withOpacity(0.10),
                        ),
                        child: Icon(
                          Icons.person,
                          color: primaryColor,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // QR
                      Container(
                        width: 240,
                        height: 240,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: !canShowQr
                              ? Center(
                                  child: Text(
                                    _error ?? 'Generating QR...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: (_error != null)
                                          ? cs.error
                                          : Colors.black87,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.white,
                                  gapless: true,
                                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Private key is stored securely in storage',
                              style: TextStyle(
                                color: subText,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PK: $pkPreview',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _copyToClipboard(
                                _x25519PublicKey,
                                'Public Key',
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(Icons.copy, color: primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextButton(
                        onPressed: (_error == null)
                            ? () => _confirmChangeKey(primaryColor, isDark)
                            : null,
                        child: Text(
                          'Change Key',
                          style: TextStyle(
                            color: cs.primary, // ✅ follow theme
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const KeyScannerPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Public Key'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
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
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }
}
