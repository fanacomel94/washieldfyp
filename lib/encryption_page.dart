import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/backendServices.dart';
import '../services/encryption_flow.dart';
import '../theme/theme_provider.dart';
import '../ui/encryption_widgets.dart';

class EncryptionPage extends StatefulWidget {
  const EncryptionPage({super.key});

  @override
  State<EncryptionPage> createState() => _EncryptionPageState();
}

class _EncryptionPageState extends State<EncryptionPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientPublicKeyController =
      TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  final TextEditingController _clientIdController =
      TextEditingController(text: '1');

  String _outputText = '';
  String _outputLabel = '';

  BackendServices? _backendServices;
  EncryptionFlow? _flow;

  bool _busyEncrypt = false;
  bool _busySend = false;

  // init state
  bool _ready = false;
  String? _baseUrlResolved;

  // for display
  String _toDisplayName = 'Select Contact';
  String _toDisplayPhone = 'Choose from saved contacts';

  @override
  void initState() {
    super.initState();
    _initBackend();
  }

  Future<void> _initBackend() async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      _baseUrlResolved = baseUrl;

      _backendServices = BackendServices(baseUrl: baseUrl);
      _flow = EncryptionFlow(backendServices: _backendServices!);

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to init backend URL: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _recipientPublicKeyController.dispose();
    _receiverPhoneController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOk(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pasteMessage() async {
    final data = await Clipboard.getData('text/plain');
    final txt = data?.text ?? '';
    if (txt.trim().isEmpty) return;
    setState(() => _messageController.text = txt);
  }

  void _clearAll() {
    _messageController.clear();
    _recipientPublicKeyController.clear();
    _receiverPhoneController.clear();
    _clientIdController.text = '1';
    setState(() {
      _outputText = '';
      _outputLabel = '';
      _toDisplayName = 'Select Contact';
      _toDisplayPhone = 'Choose from saved contacts';
    });
  }

  void _copyCiphertext() {
    if (_outputText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _outputText));
    _showOk('Copied to clipboard');
  }

  /// ✅ Demo button: modify 1 character in ciphertext to prove integrity failure
  void _tamperOneChar() {
    if (_outputText.trim().isEmpty) {
      _showError('No ciphertext yet. Encrypt first.');
      return;
    }
    final s = _outputText;
    final idx = (s.length / 2).floor();

    // flip one base64 char to another base64 char
    final ch = s[idx];
    final replacement = (ch == 'A') ? 'B' : 'A';
    final tampered = s.substring(0, idx) + replacement + s.substring(idx + 1);

    setState(() {
      _outputText = tampered;
      _outputLabel = 'Ciphertext (TAMPERED 1 char)';
    });

    _showOk('Tampered 1 character. Decryption should AUTH FAIL.');
  }

  Future<void> _selectSavedContact() async {
    if (!_ready || _flow == null) {
      _showError('App not ready yet. Please wait...');
      return;
    }

    try {
      final contacts = await _flow!.loadSavedContactsStrict();

      if (contacts.isEmpty) {
        _showError('No saved contacts found. Scan a verified QR code first.');
        return;
      }

      if (!mounted) return;

      final selected = await showModalBottomSheet<ContactRecord>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              final primaryColor =
                  isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23);
              final surfaceColor =
                  isDark ? const Color(0xFF2C2C2C) : Colors.white;
              final textColor = isDark ? Colors.white : Colors.black87;

              return Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Select Saved Contact',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final c = contacts[index];
                          final displayName =
                              c.username.isNotEmpty ? c.username : 'Unknown';
                          final phoneDisplay =
                              c.phone.isNotEmpty ? c.phone : 'No phone';
                          final badge = c.isExpired
                              ? 'EXPIRED'
                              : c.isActive
                                  ? 'ACTIVE'
                                  : 'OLD';

                          return ListTile(
                            enabled: c.isActive && !c.isExpired,
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: Icon(Icons.person, color: primaryColor),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: (c.isActive && !c.isExpired)
                                        ? primaryColor.withOpacity(0.15)
                                        : Colors.red.withOpacity(0.12),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      color: (c.isActive && !c.isExpired)
                                          ? primaryColor
                                          : Colors.red[400],
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              phoneDisplay,
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: primaryColor,
                            ),
                            onTap: (c.isActive && !c.isExpired)
                                ? () => Navigator.of(context).pop(c)
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        'Only ACTIVE contacts are selectable. If a key is EXPIRED/OLD, re-scan the latest QR.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textColor.withOpacity(0.75),
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (selected != null) {
        final v = _flow!.validateContactForEncryption(selected);
        if (!v.ok) {
          _showError(v.message);
          return;
        }

        setState(() {
          _recipientPublicKeyController.text = selected.publicKeyBase64;
          _receiverPhoneController.text = selected.phone;
          _toDisplayName =
              selected.username.isNotEmpty ? selected.username : 'Receiver';
          _toDisplayPhone = selected.phone;
        });
      }
    } catch (e) {
      _showError('Error loading contacts: $e');
    }
  }

  Future<void> _performEncryption() async {
    if (_busyEncrypt) return;

    if (!_ready || _flow == null) {
      _showError('App not ready yet. Please wait...');
      return;
    }

    setState(() => _busyEncrypt = true);
    try {
      final pre = await _flow!.validateAllRequirements(
        recipientPublicKeyBase64: _recipientPublicKeyController.text.trim(),
        receiverE164: _receiverPhoneController.text.trim(),
        plaintext: _messageController.text,
      );

      if (!pre.ok) {
        _showError(pre.message);
        return;
      }

      final ciphertext = await _flow!.encryptStrict(
        recipientPublicKeyBase64: _recipientPublicKeyController.text.trim(),
        plaintext: _messageController.text,
      );

      setState(() {
        _outputLabel = 'Ciphertext';
        _outputText = ciphertext;
      });

      _showOk('Encrypted successfully');
    } catch (e) {
      _showError('Encryption failed: $e');
    } finally {
      if (mounted) setState(() => _busyEncrypt = false);
    }
  }

  Future<void> _sendCiphertextToWhatsApp() async {
    if (_busySend) return;

    if (!_ready || _flow == null) {
      _showError('App not ready yet. Please wait...');
      return;
    }

    setState(() => _busySend = true);
    try {
      final parsedId = int.tryParse(_clientIdController.text.trim());
      final clientId = parsedId ?? 1;

      final pre = _flow!.validateSend(
        receiverE164: _receiverPhoneController.text.trim(),
        ciphertext: _outputText,
      );
      if (!pre.ok) {
        _showError(pre.message);
        return;
      }

      await _flow!.sendCiphertext(
        clientId: clientId,
        receiverE164: _receiverPhoneController.text.trim(),
        ciphertext: _outputText,
      );

      _showOk('Ciphertext sent via WhatsApp');
    } catch (e) {
      _showError('Failed to send via WhatsApp: $e');
    } finally {
      if (mounted) setState(() => _busySend = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final primaryColor =
            isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23);

        final pageBg =
            isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEFF8EF);
        final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        if (!_ready) {
          return Scaffold(
            backgroundColor: pageBg,
            appBar: AppBar(
              backgroundColor: pageBg,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Encrypt',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing backend…',
                    style: TextStyle(color: textColor),
                  ),
                  if (_baseUrlResolved != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _baseUrlResolved!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final hintColor = isDark ? Colors.grey[500] : Colors.grey[600];

        final bool hasContact =
            _recipientPublicKeyController.text.trim().isNotEmpty &&
                _receiverPhoneController.text.trim().isNotEmpty;

        final String status = _outputText.trim().isNotEmpty
            ? 'ENCRYPTED'
            : hasContact
                ? 'READY'
                : 'MISSING CONTACT';

        final Color statusColor = _outputText.trim().isNotEmpty
            ? primaryColor
            : hasContact
                ? primaryColor.withOpacity(0.8)
                : Colors.red;

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            backgroundColor: pageBg,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
                bg: cardBg,
                fg: textColor,
              ),
            ),
            centerTitle: true,
            title: Text(
              'Encrypt',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: statusColor.withOpacity(0.14),
                      border: Border.all(color: statusColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busyEncrypt ? null : _performEncryption,
                      icon: _busyEncrypt
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock, size: 20),
                      label: const Text(
                        'Encrypt',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busySend ? null : _sendCiphertextToWhatsApp,
                      icon: _busySend
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline, size: 20),
                      label: Text(
                        'Send via WhatsApp',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.18)
                              : primaryColor.withOpacity(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: cardBg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Container(
            color: pageBg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel('To', textColor),
                  const SizedBox(height: 8),
                  ContactCard(
                    bg: cardBg,
                    title: _toDisplayName,
                    subtitle: _toDisplayPhone,
                    primaryColor: primaryColor,
                    titleColor: textColor,
                    subtitleColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                    onSelect: _selectSavedContact,
                  ),
                  const SizedBox(height: 18),
                  sectionLabel('Receiver key', textColor),
                  const SizedBox(height: 8),
                  TextCardField(
                    bg: cardBg,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    hintColor: hintColor,
                    controller: _recipientPublicKeyController,
                    hintText: 'Select contact to fill public key',
                    suffixIcon: Icons.key,
                    onSuffixTap: _selectSavedContact,
                  ),
                  const SizedBox(height: 18),
                  sectionLabel('Message', textColor),
                  const SizedBox(height: 8),
                  TextCardField(
                    bg: cardBg,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    hintColor: hintColor,
                    controller: _messageController,
                    hintText: 'Enter your secure message here...',
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
                        onTap: _pasteMessage,
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
                  sectionLabel('Receiver Phone (E.164)', textColor),
                  const SizedBox(height: 8),
                  TextCardField(
                    bg: cardBg,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    hintColor: hintColor,
                    controller: _receiverPhoneController,
                    hintText: 'Example: 60123456789',
                    keyboardType: TextInputType.phone,
                  ),

                  /*const SizedBox(height: 18),
                  sectionLabel('WhatsApp Client ID', textColor),
                  const SizedBox(height: 8),
                  TextCardField(
                    bg: cardBg,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    hintColor: hintColor,
                    controller: _clientIdController,
                    hintText: 'Default: 1',
                    keyboardType: TextInputType.number,
                  ),*/

                  const SizedBox(height: 18),

                  if (_outputText.isNotEmpty) ...[
                    sectionLabel(_outputLabel, textColor),
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                  fontFamily: 'monospace',
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _tamperOneChar,
                                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                                  label: const Text('Tamper 1 char'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.red.withOpacity(0.5),
                                    ),
                                    foregroundColor: Colors.red,
                                    backgroundColor: cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _copyCiphertext,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
