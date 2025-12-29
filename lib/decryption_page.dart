import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'cryptomanager.dart';
import 'theme/theme_provider.dart';
import 'inbox_page.dart';
import 'ui/encryption_widgets.dart';

class DecryptionPage extends StatefulWidget {
  final String? initialCiphertext;
  final String? senderJid;

  final String? senderUsername;
  final String? senderPhone;
  final String? senderPublicKeyBase64;
  final String? senderFingerprint;
  final bool? senderKeyIsActive;
  final bool? senderKeyIsExpired;

  final int? messageTimestamp;

  const DecryptionPage({
    super.key,
    this.initialCiphertext,
    this.senderJid,
    this.senderUsername,
    this.senderPhone,
    this.senderPublicKeyBase64,
    this.senderFingerprint,
    this.senderKeyIsActive,
    this.senderKeyIsExpired,
    this.messageTimestamp,
  });

  @override
  State<DecryptionPage> createState() => _DecryptionPageState();
}

class _DecryptionPageState extends State<DecryptionPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final TextEditingController _cipherController = TextEditingController();
  final TextEditingController _senderPubController = TextEditingController();

  static const String kMessageAad = 'WA_SHIELD_MSG_V1';

  String _outputText = '';
  String _outputLabel = '';

  String _senderName = 'Unknown sender';
  String _senderPhone = '';
  String _senderFingerprint = '';
  bool _senderKeyActive = false;
  bool _senderKeyExpired = false;

  bool _busy = false;

  late String _myPrivateKeyBase64;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadMyPrivateKey();
  }

  void _prefill() {
    if ((widget.initialCiphertext ?? '').trim().isNotEmpty) {
      _cipherController.text = widget.initialCiphertext!.trim();
    }

    if ((widget.senderPublicKeyBase64 ?? '').trim().isNotEmpty) {
      _senderPubController.text = widget.senderPublicKeyBase64!.trim();
    }

    final displayPhone = (widget.senderPhone ?? '').trim().isNotEmpty
        ? widget.senderPhone!.trim()
        : _normalizeSenderId(widget.senderJid ?? '');

    _senderPhone = displayPhone;

    final displayName = (widget.senderUsername ?? '').trim().isNotEmpty
        ? widget.senderUsername!.trim()
        : (displayPhone.isNotEmpty ? displayPhone : 'Unknown sender');

    _senderName = displayName;

    _senderFingerprint = (widget.senderFingerprint ?? '').trim();
    _senderKeyActive = widget.senderKeyIsActive ?? false;
    _senderKeyExpired = widget.senderKeyIsExpired ?? false;

    if (_senderPubController.text.trim().isNotEmpty &&
        (widget.senderKeyIsExpired != true)) {
      _senderKeyActive = true;
      _senderKeyExpired = false;
    }
  }

  @override
  void dispose() {
    _cipherController.dispose();
    _senderPubController.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  String _normalizeSenderId(String raw) {
    var s = raw.trim();
    s = s.replaceFirst('whatsapp:+', '');
    s = s.replaceFirst('whatsapp:', '');
    s = s.replaceFirst('tel:', '');
    if (s.contains('@')) s = s.split('@')[0];
    return _digitsOnly(s);
  }

  bool _isProbablyBase64(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(t);
  }

  bool _isBase64OfLen(String s, int bytesLen) {
    try {
      if (!_isProbablyBase64(s)) return false;
      final b = base64Decode(s.trim());
      return b.length == bytesLen;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _parseCipherPayload(String cipher) {
    try {
      if (!_isProbablyBase64(cipher)) return null;
      final decoded = utf8.decode(base64Decode(cipher.trim()));
      final m = jsonDecode(decoded);
      if (m is Map<String, dynamic>) return m;
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _validateCipherShape(Map<String, dynamic> m) {
    final v = m['v'];
    final iv = (m['iv'] ?? '').toString();
    final ct = (m['ciphertext'] ?? '').toString();
    final tag = (m['tag'] ?? '').toString();

    if (v != 1) return 'Unsupported payload version (v must be 1).';
    if (iv.isEmpty || ct.isEmpty || tag.isEmpty) {
      return 'Cipher payload missing iv/ciphertext/tag.';
    }
    if (!_isBase64OfLen(iv, 12))
      return 'Invalid IV (expected base64 12 bytes).';
    if (!_isProbablyBase64(ct)) return 'Invalid ciphertext (not base64).';
    if (!_isBase64OfLen(tag, 16))
      return 'Invalid tag (expected base64 16 bytes).';
    return null;
  }

  Future<bool> _confirmProceedUnverified() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final fg = isDark ? Colors.white : Colors.black87;

            return AlertDialog(
              backgroundColor: cs.surface,
              title: Text(
                'Unverified / Old key',
                style: TextStyle(color: fg, fontWeight: FontWeight.w900),
              ),
              content: Text(
                'This key is marked OLD/EXPIRED or not verified.\n\n'
                'You can proceed, but only if you trust this public key really belongs '
                'to the sender (otherwise you may decrypt a wrong message/key).',
                style: TextStyle(color: fg.withOpacity(0.85), height: 1.35),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: TextStyle(color: fg)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Proceed'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _loadMyPrivateKey() async {
    try {
      final stored = await _storage.read(key: 'wa_shield_x25519_private_key');
      _myPrivateKeyBase64 = (stored ?? '').trim();

      if (_myPrivateKeyBase64.isEmpty && mounted) {
        _showError(
          'Please generate a key pair first in the Key Generation page',
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      _myPrivateKeyBase64 = '';
      if (mounted) _showError('Error loading private key: $e');
    }

    if (_senderPubController.text.trim().isEmpty &&
        (widget.senderJid ?? '').isNotEmpty) {
      await _tryAutoResolveSenderFromStorage(widget.senderJid!);
    }
  }

  Future<void> _tryAutoResolveSenderFromStorage(String senderRaw) async {
    final digits = _normalizeSenderId(senderRaw);
    if (digits.isEmpty) return;

    try {
      final all = await _storage.readAll();
      final entries = all.entries
          .where((e) => e.key.startsWith('wa_shield_contact_'))
          .toList();

      Map<String, dynamic>? best;
      DateTime bestSavedAt = DateTime.fromMillisecondsSinceEpoch(0);

      for (final e in entries) {
        try {
          final data = jsonDecode(e.value) as Map<String, dynamic>;
          final payload = (data['payload'] is Map)
              ? Map<String, dynamic>.from(data['payload'])
              : <String, dynamic>{};

          final storedPhone = (data['phone'] ?? payload['p'] ?? '').toString();
          final storedDigits = _digitsOnly(storedPhone);
          if (storedDigits.isEmpty) continue;

          final match =
              storedDigits == digits ||
              digits.contains(storedDigits) ||
              storedDigits.contains(digits);
          if (!match) continue;

          final savedAtStr = (data['savedAt'] ?? '').toString();
          DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(0);
          try {
            if (savedAtStr.isNotEmpty) savedAt = DateTime.parse(savedAtStr);
          } catch (_) {}

          if (savedAt.isAfter(bestSavedAt)) {
            bestSavedAt = savedAt;
            best = data;
          }
        } catch (_) {}
      }

      if (best == null) return;

      final payload = (best['payload'] is Map)
          ? Map<String, dynamic>.from(best['payload'])
          : <String, dynamic>{};

      final username = (best['username'] ?? payload['u'] ?? '')
          .toString()
          .trim();
      final phone = (best['phone'] ?? payload['p'] ?? '').toString().trim();

      final pub =
          (payload['x'] ??
                  payload['x25519PublicKey'] ??
                  best['x25519PublicKey'] ??
                  best['publicKey'] ??
                  '')
              .toString()
              .trim();

      final fp = (best['fingerprint'] ?? payload['fp'] ?? '').toString().trim();

      if (pub.isNotEmpty) {
        setState(() {
          _senderPubController.text = pub;
          _senderName = username.isNotEmpty ? username : _senderName;
          _senderPhone = _digitsOnly(phone).isNotEmpty
              ? _digitsOnly(phone)
              : _senderPhone;
          _senderFingerprint = fp;
          _senderKeyActive = true;
          _senderKeyExpired = false;
        });
      }
    } catch (_) {}
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _copyPlaintext() {
    if (_outputText.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _outputText));
    _showOk('Copied to clipboard');
  }

  Future<void> _pasteCiphertext() async {
    final data = await Clipboard.getData('text/plain');
    final txt = data?.text ?? '';
    if (txt.trim().isEmpty) return;
    setState(() => _cipherController.text = txt.trim());
  }

  void _clearAll() {
    _cipherController.clear();
    _senderPubController.clear();
    setState(() {
      _outputText = '';
      _outputLabel = '';
      _senderName = 'Unknown sender';
      _senderPhone = '';
      _senderFingerprint = '';
      _senderKeyActive = false;
      _senderKeyExpired = false;
    });
  }

  Future<void> _performDecryption() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (_myPrivateKeyBase64.trim().isEmpty) {
        _showError('Private key not loaded. Generate keys first.');
        return;
      }
      if (!_isBase64OfLen(_myPrivateKeyBase64, 32)) {
        _showError(
          'Your private key is invalid (expected base64 32 bytes). Re-generate keys.',
        );
        return;
      }

      final senderPub = _senderPubController.text.trim();
      if (senderPub.isEmpty) {
        _showError('Sender public key is empty.');
        return;
      }
      if (!_isBase64OfLen(senderPub, 32)) {
        _showError(
          'Sender public key iis tampered.',
        );
        return;
      }

      final cipher = _cipherController.text.trim();
      if (cipher.isEmpty) {
        _showError('Encrypted payload is empty.');
        return;
      }

      final parsed = _parseCipherPayload(cipher);
      if (parsed == null) {
        _showError(
          'Ciphertext message is tampered.',
        );
        return;
      }

      final shapeErr = _validateCipherShape(parsed);
      if (shapeErr != null) {
        _showError('Cipher payload invalid: $shapeErr');
        return;
      }

      final isUnverified = (_senderKeyExpired || !_senderKeyActive);
      if (isUnverified) {
        final proceed = await _confirmProceedUnverified();
        if (!proceed) return;
      }

      final sharedSecretBase64 =
          await CryptoManager.computeSharedSecretAesKeyBase64(senderPub);

      if (!_isBase64OfLen(sharedSecretBase64, 32)) {
        _showError('Derived AES key invalid (expected 32 bytes).');
        return;
      }

      final plaintext = await CryptoManager.decryptAES256GCM(
        cipher,
        sharedSecretBase64,
        aad: kMessageAad,
      );

      setState(() {
        _outputLabel = isUnverified ? 'Plaintext (Unverified)' : 'Plaintext';
        _outputText = plaintext;
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('AUTH FAIL')) { //ciphertext tampered
        _showError(
          'AUTH FAIL (tampered / wrong key / wrong account).\n'
          '• Make sure you are using the sender account public key\n'
          '• Re-scan sender QR (latest)\n',
        );
        return;
      }
      _showError('Decryption failed: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final cs = Theme.of(context).colorScheme;

        final primaryColor = cs.primary;
        final pageBg = Theme.of(context).scaffoldBackgroundColor;
        final cardBg = cs.surface;
        final textColor = isDark ? Colors.white : Colors.black87;
        final hintColor = isDark ? Colors.white60 : Colors.black45;

        final statusText = (_senderPubController.text.trim().isEmpty)
            ? 'UNKNOWN' // no key provided
            : (_senderKeyExpired || !_senderKeyActive)
            ? 'UNVERIFIED' // unverified (no phone match -> no public key match)
            : 'VERIFIED'; // verified

        final statusColor = (_senderPubController.text.trim().isEmpty)
            ? Colors.grey
            : (_senderKeyExpired || !_senderKeyActive)
            ? cs.error
            : primaryColor;

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            backgroundColor: pageBg,
            elevation: 0,
            centerTitle: true,

            // ✅ back button (top-left) in circle
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _CircleTopButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),

            title: Text(
              'Decrypt',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),

            // ✅ inbox button (top-right) in circle
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CircleTopButton(
                  icon: Icons.inbox_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InboxPage()),
                    );
                  },
                ),
              ),
            ],
          ),

          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _performDecryption,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open, size: 22),
                  label: const Text(
                    'Decrypt',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('From', textColor),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.18),
                        child: Icon(Icons.person, color: primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _senderName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _senderPhone.isNotEmpty
                                  ? _senderPhone
                                  : 'No phone detected',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_senderFingerprint.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'FP: $_senderFingerprint',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: statusColor.withOpacity(0.14),
                          border: Border.all(
                            color: statusColor.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _sectionLabel('Sender Public Key', textColor),
                const SizedBox(height: 8),
                _textCardField(
                  bg: cardBg,
                  primaryColor: primaryColor,
                  textColor: textColor,
                  hintColor: hintColor,
                  controller: _senderPubController,
                  hintText: 'Paste sender x25519 public key...',
                  maxLines: 2,
                ),

                const SizedBox(height: 18),

                _sectionLabel('Ciphertext', textColor),
                const SizedBox(height: 8),
                _textCardField(
                  bg: cardBg,
                  primaryColor: primaryColor,
                  textColor: textColor,
                  hintColor: hintColor,
                  controller: _cipherController,
                  hintText: 'Paste encrypted payload here...',
                  maxLines: 5,
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SmallChipButton(
                      label: 'Paste',
                      icon: Icons.paste,
                      bg: cardBg,
                      fg: textColor,
                      border: isDark
                          ? Colors.white.withOpacity(0.14)
                          : primaryColor.withOpacity(0.25),
                      onTap: _pasteCiphertext,
                    ),
                    const SizedBox(width: 10),
                    SmallChipButton(
                      label: 'Clear',
                      icon: Icons.clear,
                      bg: cardBg,
                      fg: textColor,
                      border: isDark
                          ? Colors.white.withOpacity(0.14)
                          : primaryColor.withOpacity(0.25),
                      onTap: _clearAll,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                if (_outputText.isNotEmpty) ...[
                  _sectionLabel(_outputLabel, textColor),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryColor.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _outputText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: textColor,
                                fontFamily: 'monospace',
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _copyPlaintext,
                            icon: const Icon(Icons.content_copy, size: 18),
                            label: const Text('Copy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _textCardField({
    required Color bg,
    required Color primaryColor,
    required Color textColor,
    required Color? hintColor,
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: hintColor),
        ),
        style: TextStyle(color: textColor),
        cursorColor: primaryColor,
      ),
    );
  }
}

// ✅ Reusable circle button for AppBar (uses theme colors)
class _CircleTopButton extends StatelessWidget {
  const _CircleTopButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = cs.surface;
    final fg = isDark ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: cs.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(isDark ? 0.10 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }
}
