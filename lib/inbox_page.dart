import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config.dart';
import 'decryption_page.dart';
import 'theme/theme_provider.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;

  // ✅ CHANGED: not final, loaded from secure storage
  int _clientId = 1;

  List<_ContactLite> _contactsCache = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<int> _loadClientId() async {
    final s = (await _storage.read(key: 'wa_client_id') ?? '').trim();
    final id = int.tryParse(s) ?? 1;
    return (id == 2) ? 2 : 1;
  }

  Future<void> _init() async {
    _clientId = await _loadClientId();
    await _loadContactsCache();
    await _fetchMessages();
  }

  // -----------------------------
  // Normalization helpers
  // -----------------------------
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  String _normalizeSenderToDigits(String raw) {
    var s = raw.trim();

    s = s.replaceFirst('whatsapp:+', '');
    s = s.replaceFirst('whatsapp:', '');
    s = s.replaceFirst('tel:', '');

    if (s.contains('@')) s = s.split('@')[0];

    return _digitsOnly(s);
  }

  DateTime? _parseExpiresAtFromCompactPayload(Map<String, dynamic> payload) {
    final expRaw = payload['exp'];
    final expSec = (expRaw is int)
        ? expRaw
        : int.tryParse(expRaw?.toString() ?? '');
    if (expSec == null || expSec <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);
  }

  // -----------------------------
  // Load contacts from secure storage
  // -----------------------------
  Future<void> _loadContactsCache() async {
    try {
      final all = await _storage.readAll();
      final entries = all.entries
          .where((e) => e.key.startsWith('wa_shield_contact_'))
          .toList();

      final raw = <Map<String, dynamic>>[];

      for (final e in entries) {
        try {
          final data = jsonDecode(e.value) as Map<String, dynamic>;
          final payload = (data['payload'] is Map)
              ? Map<String, dynamic>.from(data['payload'])
              : <String, dynamic>{};

          final username =
              (data['username'] ?? payload['u'] ?? payload['username'] ?? '')
                  .toString()
                  .trim();

          final phone =
              (data['phone'] ?? payload['p'] ?? payload['phone'] ?? '')
                  .toString()
                  .trim();

          final phoneDigits = _digitsOnly(phone);
          if (phoneDigits.isEmpty) continue;

          final publicKey =
              (payload['x'] ??
                      payload['x25519PublicKey'] ??
                      data['x25519PublicKey'] ??
                      data['publicKey'] ??
                      '')
                  .toString()
                  .trim();

          final fingerprint =
              (data['fingerprint'] ??
                      payload['fp'] ??
                      payload['fingerprint'] ??
                      '')
                  .toString()
                  .trim();

          final savedAtStr = (data['savedAt'] ?? '').toString();
          DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(0);
          try {
            if (savedAtStr.isNotEmpty) savedAt = DateTime.parse(savedAtStr);
          } catch (_) {}

          DateTime? expiresAtUtc;
          if (payload.isNotEmpty) {
            expiresAtUtc = _parseExpiresAtFromCompactPayload(payload);
          }
          if (expiresAtUtc == null) {
            final expIso = (data['expiresAt'] ?? '').toString();
            try {
              if (expIso.isNotEmpty) {
                expiresAtUtc = DateTime.parse(expIso).toUtc();
              }
            } catch (_) {}
          }

          raw.add({
            'storageKey': e.key,
            'username': username,
            'phoneDigits': phoneDigits,
            'publicKey': publicKey,
            'fingerprint': fingerprint,
            'savedAt': savedAt,
            'expiresAtUtc': expiresAtUtc,
          });
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> newestByPhone = {};
      for (final item in raw) {
        final d = item['phoneDigits'] as String;
        final cur = newestByPhone[d];
        if (cur == null) {
          newestByPhone[d] = item;
        } else {
          final a = cur['savedAt'] as DateTime;
          final b = item['savedAt'] as DateTime;
          if (b.isAfter(a)) newestByPhone[d] = item;
        }
      }

      final nowUtc = DateTime.now().toUtc();
      final contacts = <_ContactLite>[];

      for (final item in raw) {
        final d = item['phoneDigits'] as String;
        final newest = newestByPhone[d];

        final isActive =
            newest != null && newest['storageKey'] == item['storageKey'];

        final expiresAtUtc = item['expiresAtUtc'] as DateTime?;
        final timeExpired =
            expiresAtUtc != null && expiresAtUtc.isBefore(nowUtc);

        final rotationExpired = !isActive;

        final isExpired = timeExpired || rotationExpired;

        contacts.add(
          _ContactLite(
            storageKey: item['storageKey'] as String,
            username: (item['username'] ?? '').toString(),
            phoneDigits: d,
            publicKeyBase64: (item['publicKey'] ?? '').toString(),
            fingerprint: (item['fingerprint'] ?? '').toString(),
            savedAt: item['savedAt'] as DateTime,
            expiresAtUtc: expiresAtUtc,
            isActive: isActive,
            isExpired: isExpired,
          ),
        );
      }

      contacts.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
        return b.savedAt.compareTo(a.savedAt);
      });

      _contactsCache = contacts;
      _contactsLoaded = true;
    } catch (_) {
      _contactsCache = [];
      _contactsLoaded = true;
    }
  }

  // -----------------------------
  // Fetch messages from backend
  // -----------------------------
  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ reload clientId in case user changed session
      _clientId = await _loadClientId();

      final baseUrl = await AppConfig.getBaseUrl();
      final uri = Uri.parse('$baseUrl/messages?clientId=$_clientId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load messages: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching messages: $e';
        _isLoading = false;
      });
    }
  }

  // -----------------------------
  // Resolve contact from sender
  // -----------------------------
  _ContactLite? _resolveSenderContact(String senderRaw) {
    if (!_contactsLoaded || _contactsCache.isEmpty) return null;

    final digits = _normalizeSenderToDigits(senderRaw);
    if (digits.isEmpty) return null;

    final exact = _contactsCache.where((c) => c.phoneDigits == digits).toList();
    if (exact.isNotEmpty) {
      exact.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.savedAt.compareTo(a.savedAt);
      });
      return exact.first;
    }

    final partial = _contactsCache.where((c) {
      return digits.contains(c.phoneDigits) || c.phoneDigits.contains(digits);
    }).toList();

    if (partial.isNotEmpty) {
      partial.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.savedAt.compareTo(a.savedAt);
      });
      return partial.first;
    }

    return null;
  }

  // -----------------------------
  // Open decrypt page
  // -----------------------------
  void _openDecryptionPage(Map<String, dynamic> message) {
    final senderRaw = (message['from'] ?? message['phoneNumber'] ?? '')
        .toString()
        .trim();

    final ciphertext = (message['body'] ?? message['message'] ?? '')
        .toString()
        .trim();

    final timestampRaw = (message['timestamp'] ?? message['time'] ?? 0);
    final timestamp = (timestampRaw is int)
        ? timestampRaw
        : int.tryParse(timestampRaw.toString()) ?? 0;

    final contact = _resolveSenderContact(senderRaw);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DecryptionPage(
          initialCiphertext: ciphertext,
          senderJid: senderRaw,
          senderUsername: contact?.username,
          senderPhone: contact?.phoneDigits,
          senderPublicKeyBase64: contact?.publicKeyBase64,
          senderFingerprint: contact?.fingerprint,
          senderKeyIsActive: contact?.isActive,
          senderKeyIsExpired: contact?.isExpired,
          messageTimestamp: timestamp,
        ),
      ),
    );
  }

  String _previewCiphertext(String body) {
    if (body.length <= 44) return body;
    return '${body.substring(0, 44)}...';
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        final primaryColor = isDark
            ? const Color(0xFF8B9D3F)
            : const Color(0xFF6B8E23);
        final textColor = isDark ? Colors.white : Colors.black87;
        final surfaceColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
        final pageBg = isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF5F5F0);

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            title: const Text('Decrypt Center'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  _clientId = await _loadClientId();
                  await _loadContactsCache();
                  await _fetchMessages();
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_error!, style: TextStyle(color: textColor)),
                  ),
                )
              : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: primaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text('No messages', style: TextStyle(color: textColor)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _clientId = await _loadClientId();
                    await _loadContactsCache();
                    await _fetchMessages();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      final senderRaw =
                          (message['from'] ?? message['phoneNumber'] ?? '')
                              .toString()
                              .trim();

                      final ciphertext =
                          (message['body'] ?? message['message'] ?? '')
                              .toString()
                              .trim();

                      final timestampRaw =
                          (message['timestamp'] ?? message['time'] ?? 0);
                      final timestamp = (timestampRaw is int)
                          ? timestampRaw
                          : int.tryParse(timestampRaw.toString()) ?? 0;

                      final contact = _resolveSenderContact(senderRaw);

                      final digits = _normalizeSenderToDigits(senderRaw);
                      final displayName =
                          (contact?.username.trim().isNotEmpty ?? false)
                          ? contact!.username
                          : (digits.isNotEmpty ? digits : 'Unknown');

                      final badgeText = contact == null
                          ? 'UNKNOWN'
                          : (contact.isExpired || !contact.isActive)
                          ? 'OLD/EXPIRED'
                          : 'VERIFIED';

                      final badgeColor = contact == null
                          ? Colors.grey
                          : (contact.isExpired || !contact.isActive)
                          ? Colors.red
                          : primaryColor;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: surfaceColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.18),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.18),
                            child: Icon(Icons.lock, color: primaryColor),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                                  color: badgeColor.withOpacity(0.14),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                _previewCiphertext(ciphertext),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.78),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              if (timestamp > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: primaryColor,
                          ),
                          onTap: () => _openDecryptionPage(message),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _ContactLite {
  final String storageKey;
  final String username;
  final String phoneDigits;

  final String publicKeyBase64;
  final String fingerprint;

  final DateTime savedAt;
  final DateTime? expiresAtUtc;

  final bool isActive;
  final bool isExpired;

  _ContactLite({
    required this.storageKey,
    required this.username,
    required this.phoneDigits,
    required this.publicKeyBase64,
    required this.fingerprint,
    required this.savedAt,
    required this.expiresAtUtc,
    required this.isActive,
    required this.isExpired,
  });
}
