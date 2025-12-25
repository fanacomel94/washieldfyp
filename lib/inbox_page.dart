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

  final int _clientId = 1;

  /// Cache contacts so we don’t read storage repeatedly for each tile
  List<_ContactLite> _contactsCache = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadContactsCache();
    await _fetchMessages();
  }

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
              (data['username'] ?? payload['username'] ?? '').toString().trim();
          final phone = (data['phone'] ?? payload['phone'] ?? '').toString().trim();

          // Prefer x25519PublicKey from payload, fallback to top-level publicKey
          final publicKey = (payload['x25519PublicKey'] ?? data['publicKey'] ?? '')
              .toString()
              .trim();

          final fingerprint = (payload['fingerprint'] ?? data['fingerprint'] ?? '')
              .toString()
              .trim();

          final savedAtStr = (data['savedAt'] ?? '').toString();
          final issuedAtStr = (payload['issuedAt'] ?? '').toString();
          final expiresAtStr = (payload['expiresAt'] ?? '').toString();

          DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime? issuedAt;
          DateTime? expiresAt;

          try {
            if (savedAtStr.isNotEmpty) savedAt = DateTime.parse(savedAtStr);
          } catch (_) {}
          try {
            if (issuedAtStr.isNotEmpty) issuedAt = DateTime.parse(issuedAtStr);
          } catch (_) {}
          try {
            if (expiresAtStr.isNotEmpty) expiresAt = DateTime.parse(expiresAtStr);
          } catch (_) {}

          raw.add({
            'storageKey': e.key,
            'username': username,
            'phone': phone,
            'publicKey': publicKey,
            'fingerprint': fingerprint,
            'savedAt': savedAt,
            'issuedAt': issuedAt,
            'expiresAt': expiresAt,
          });
        } catch (_) {
          // ignore invalid JSON
        }
      }

      // Determine newest key per phone (best for WA sender matching)
      final Map<String, Map<String, dynamic>> newestByPhone = {};
      for (final item in raw) {
        final phoneDigits = _digitsOnly(item['phone']?.toString() ?? '');
        if (phoneDigits.isEmpty) continue;

        final cur = newestByPhone[phoneDigits];
        if (cur == null) {
          newestByPhone[phoneDigits] = item;
        } else {
          final a = cur['savedAt'] as DateTime;
          final b = item['savedAt'] as DateTime;
          if (b.isAfter(a)) newestByPhone[phoneDigits] = item;
        }
      }

      final now = DateTime.now();
      final contacts = <_ContactLite>[];

      for (final item in raw) {
        final phoneDigits = _digitsOnly(item['phone']?.toString() ?? '');
        if (phoneDigits.isEmpty) continue;

        final newest = newestByPhone[phoneDigits];
        final bool isActive =
            newest != null && newest['storageKey'] == item['storageKey'];

        final expiresAt = item['expiresAt'] as DateTime?;
        final bool timeExpired = (expiresAt != null) && expiresAt.isBefore(now);

        final bool rotationExpired = !isActive; // older record for same phone
        final bool isExpired = timeExpired || rotationExpired;

        contacts.add(
          _ContactLite(
            storageKey: item['storageKey'] as String,
            username: (item['username'] ?? '').toString(),
            phone: (item['phone'] ?? '').toString(),
            phoneDigits: phoneDigits,
            publicKeyBase64: (item['publicKey'] ?? '').toString(),
            fingerprint: (item['fingerprint'] ?? '').toString(),
            savedAt: item['savedAt'] as DateTime,
            issuedAt: item['issuedAt'] as DateTime?,
            expiresAt: expiresAt,
            isActive: isActive,
            isExpired: isExpired,
          ),
        );
      }

      // Sort active first, then newest
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

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/messages?clientId=$_clientId');
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

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  String _formatJidToPhone(String jid) {
    // 60123456789@c.us -> 60123456789
    if (jid.contains('@')) return jid.split('@')[0];
    return jid;
  }

  String _previewCiphertext(String body) {
    if (body.length <= 44) return body;
    return '${body.substring(0, 44)}...';
  }

  _ContactLite? _resolveSenderContact(String senderJid) {
    if (!_contactsLoaded || _contactsCache.isEmpty) return null;

    final phone = _formatJidToPhone(senderJid);
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) return null;

    // Prefer exact phoneDigits match
    final exact = _contactsCache.where((c) => c.phoneDigits == digits).toList();
    if (exact.isNotEmpty) {
      // Choose active first, then newest savedAt
      exact.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.savedAt.compareTo(a.savedAt);
      });
      return exact.first;
    }

    // Fallback: partial match (rare)
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

  void _openDecryptionPage(Map<String, dynamic> message) {
    final senderJid = message['from'] as String? ?? '';
    final ciphertext = message['body'] as String? ?? '';
    final timestamp = message['timestamp'] as int? ?? 0;

    final contact = _resolveSenderContact(senderJid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DecryptionPage(
          initialCiphertext: ciphertext,
          senderJid: senderJid,
          senderUsername: contact?.username,
          senderPhone: contact?.phoneDigits, // use digits-only phone
          senderPublicKeyBase64: contact?.publicKeyBase64,
          senderFingerprint: contact?.fingerprint,
          senderKeyIsActive: contact?.isActive,
          senderKeyIsExpired: contact?.isExpired,
          messageTimestamp: timestamp,
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        final primaryColor =
            isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23);
        final textColor = isDark ? Colors.white : Colors.black87;
        final surfaceColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
        final pageBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F0);

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            title: const Text('Decrypt Center'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: primaryColor),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: textColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                await _loadContactsCache();
                                await _fetchMessages();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: primaryColor),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: textColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Encrypted messages will appear here',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: textColor.withOpacity(0.7)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadContactsCache();
                            await _fetchMessages();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];

                              final senderJid = message['from'] as String? ?? '';
                              final ciphertext = message['body'] as String? ?? '';
                              final timestamp = message['timestamp'] as int? ?? 0;

                              final contact = _resolveSenderContact(senderJid);
                              final senderPhone = _formatJidToPhone(senderJid);
                              final displayName = (contact?.username.trim().isNotEmpty ?? false)
                                  ? contact!.username
                                  : _digitsOnly(senderPhone);

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
                                  side: BorderSide(color: primaryColor.withOpacity(0.18)),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                  trailing: Icon(Icons.chevron_right, color: primaryColor),
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
  final String phone;
  final String phoneDigits;

  final String publicKeyBase64;
  final String fingerprint;

  final DateTime savedAt;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  final bool isActive;
  final bool isExpired;

  _ContactLite({
    required this.storageKey,
    required this.username,
    required this.phone,
    required this.phoneDigits,
    required this.publicKeyBase64,
    required this.fingerprint,
    required this.savedAt,
    required this.issuedAt,
    required this.expiresAt,
    required this.isActive,
    required this.isExpired,
  });
}
