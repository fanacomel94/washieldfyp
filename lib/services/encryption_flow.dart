import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../cryptomanager.dart';
import '../services/backendServices.dart';

class ValidationResult {
  final bool ok;
  final String message;
  const ValidationResult(this.ok, this.message);
}

/// ✅ NEW: No fingerprint (removed)
class ContactRecord {
  final String storageKey;

  final String userId;
  final String username;
  final String phone;

  // x25519 public key (base64)
  final String publicKeyBase64;

  // Compact QR timestamps (epoch seconds) -> parsed to DateTime?
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  // computed
  final bool isActive; // newest key for this userId
  final bool isExpired; // time-expired OR old replaced

  const ContactRecord({
    required this.storageKey,
    required this.userId,
    required this.username,
    required this.phone,
    required this.publicKeyBase64,
    required this.issuedAt,
    required this.expiresAt,
    required this.isActive,
    required this.isExpired,
  });
}

class EncryptionFlow {
  EncryptionFlow({
    required BackendServices backendServices,
    FlutterSecureStorage? storage,
  })  : _backendServices = backendServices,
        _storage = storage ?? const FlutterSecureStorage();

  final BackendServices _backendServices;
  final FlutterSecureStorage _storage;

  // My profile keys (strict mode)
  static const String kMyUserId = 'wa_shield_user_id';
  static const String kMyPhone = 'wa_shield_my_phone';
  static const String kMyUsername = 'wa_shield_my_username';

  // My key presence check
  static const String kMyX25519Private = 'wa_shield_x25519_private_key';
  static const String kMyX25519Public = 'wa_shield_x25519_public_key';
  static const String kMyEd25519Public = 'wa_shield_ed25519_public_key';

  // Contacts
  static const String kContactPrefix = 'wa_shield_contact_';

  // ✅ Consistent AAD (used both sides)
  static const String kMessageAad = 'WA_SHIELD_MSG_V1';

  // ---- NEW compact QR keys (ONLY) ----
  // Payload keys (short):
  // t,id,u,p,x,e,i,exp,s
  static const String _kId = 'id';
  static const String _kU = 'u';
  static const String _kP = 'p';
  static const String _kX = 'x';
  static const String _kI = 'i';
  static const String _kExp = 'exp';

  DateTime? _parseEpochSeconds(dynamic v) {
    try {
      if (v == null) return null;
      final int seconds = (v is int) ? v : int.parse(v.toString());
      if (seconds <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
          .toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<ValidationResult> _validateRegistered() async {
    final id = (await _storage.read(key: kMyUserId) ?? '').trim();
    final phone = (await _storage.read(key: kMyPhone) ?? '').trim();
    final name = (await _storage.read(key: kMyUsername) ?? '').trim();

    if (id.isEmpty || phone.isEmpty || name.isEmpty) {
      return const ValidationResult(
        false,
        'Please register first (missing User ID / Name / Phone).',
      );
    }
    return const ValidationResult(true, 'OK');
  }

  Future<ValidationResult> _validateMyKeysExist() async {
    final priv = (await _storage.read(key: kMyX25519Private) ?? '').trim();
    final pub = (await _storage.read(key: kMyX25519Public) ?? '').trim();
    final ed = (await _storage.read(key: kMyEd25519Public) ?? '').trim();

    if (priv.isEmpty || pub.isEmpty || ed.isEmpty) {
      return const ValidationResult(
        false,
        'Keys not found. Please generate your keys in Key Generation page.',
      );
    }

    if (!CryptoManager.validatePublicKey(pub)) {
      return const ValidationResult(
        false,
        'Your stored public key is invalid. Generate keys again.',
      );
    }

    return const ValidationResult(true, 'OK');
  }

  ValidationResult validateReceiverPhone(String receiverE164) {
    final p = receiverE164.trim();
    if (p.isEmpty) {
      return const ValidationResult(false, 'Receiver phone number is empty.');
    }
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) {
      return const ValidationResult(
        false,
        'Receiver phone must be E.164 digits (example: 60123456789).',
      );
    }
    if (!digits.startsWith('60')) {
      return const ValidationResult(
        false,
        'Receiver phone must start with country code 60 (example: 60123456789).',
      );
    }
    return const ValidationResult(true, 'OK');
  }

  ValidationResult validateRecipientPublicKey(String keyBase64) {
    final k = keyBase64.trim();
    if (k.isEmpty) {
      return const ValidationResult(false, 'Recipient public key is empty.');
    }
    if (!CryptoManager.validatePublicKey(k)) {
      return const ValidationResult(
        false,
        'Recipient public key is invalid (must be Base64 of 32 bytes).',
      );
    }
    return const ValidationResult(true, 'OK');
  }

  ValidationResult validatePlaintext(String plaintext) {
    if (plaintext.trim().isEmpty) {
      return const ValidationResult(false, 'Message is empty.');
    }
    return const ValidationResult(true, 'OK');
  }

  ValidationResult validateSend({
    required String receiverE164,
    required String ciphertext,
  }) {
    if (ciphertext.trim().isEmpty) {
      return const ValidationResult(
        false,
        'No ciphertext to send. Please encrypt a message first.',
      );
    }
    final phoneCheck = validateReceiverPhone(receiverE164);
    if (!phoneCheck.ok) return phoneCheck;
    return const ValidationResult(true, 'OK');
  }

  Future<ValidationResult> validateAllRequirements({
    required String recipientPublicKeyBase64,
    required String receiverE164,
    required String plaintext,
  }) async {
    final reg = await _validateRegistered();
    if (!reg.ok) return reg;

    final myKeys = await _validateMyKeysExist();
    if (!myKeys.ok) return myKeys;

    final phoneCheck = validateReceiverPhone(receiverE164);
    if (!phoneCheck.ok) return phoneCheck;

    final pk = validateRecipientPublicKey(recipientPublicKeyBase64);
    if (!pk.ok) return pk;

    final msg = validatePlaintext(plaintext);
    if (!msg.ok) return msg;

    return const ValidationResult(true, 'OK');
  }

  /// Encrypt using ECDH -> HKDF -> AES-GCM
  /// IMPORTANT: uses AAD so payload tampering always fails cleanly.
  Future<String> encryptStrict({
    required String recipientPublicKeyBase64,
    required String plaintext,
  }) async {
    final sharedSecretBase64 =
        await CryptoManager.computeSharedSecretAesKeyBase64(
      recipientPublicKeyBase64.trim(),
    );

    final encryptedPayload = await CryptoManager.encryptAES256GCM(
      plaintext,
      sharedSecretBase64,
      aad: kMessageAad,
    );

    return encryptedPayload;
  }

  Future<void> sendCiphertext({
    required int clientId,
    required String receiverE164,
    required String ciphertext,
  }) async {
    await _backendServices.sendCiphertext(
      clientId: clientId,
      receiverE164: receiverE164.trim(),
      ciphertext: ciphertext,
    );
  }

  /// ✅ NEW: Load contacts STRICTLY from NEW compact payload ONLY.
  ///
  /// Expects storage value JSON like:
  /// {
  ///   "id": "<userId>",
  ///   "username": "<username>",
  ///   "phone": "<phone>",
  ///   "x25519PublicKey": "<base64>",
  ///   "ed25519PublicKey": "<base64>",     // optional for encryption list, but you saved it
  ///   "payload": { "id","u","p","x","e","i","exp","s","t" ... },
  ///   "savedAt": "2025-12-25T...."
  /// }
  ///
  /// We only read:
  /// - contact wrapper: id/username/phone/x25519PublicKey/savedAt
  /// - payload compact: i/exp (epoch seconds)
  Future<List<ContactRecord>> loadSavedContactsStrict() async {
    final all = await _storage.readAll();
    final entries =
        all.entries.where((e) => e.key.startsWith(kContactPrefix)).toList();

    final rawList = <Map<String, dynamic>>[];

    for (final e in entries) {
      try {
        final data = jsonDecode(e.value) as Map<String, dynamic>;

        final userId = (data['id'] ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();

        // ✅ New scanner saves this
        final xPub = (data['x25519PublicKey'] ?? '').toString().trim();

        if (userId.isEmpty || username.isEmpty || phone.isEmpty || xPub.isEmpty) {
          // skip invalid record
          continue;
        }

        // Parse savedAt
        DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(0);
        final savedAtStr = (data['savedAt'] ?? '').toString().trim();
        if (savedAtStr.isNotEmpty) {
          try {
            savedAt = DateTime.parse(savedAtStr);
          } catch (_) {}
        }

        // Payload should be compact map
        final payload = (data['payload'] is Map)
            ? Map<String, dynamic>.from(data['payload'])
            : <String, dynamic>{};

        // ✅ Ensure payload is compact + matches user (optional safety)
        final payloadId = (payload[_kId] ?? '').toString().trim();
        final payloadU = (payload[_kU] ?? '').toString().trim();
        final payloadP = (payload[_kP] ?? '').toString().trim();
        final payloadX = (payload[_kX] ?? '').toString().trim();

        // If payload missing, we still keep contact (but issuedAt/expiresAt become null)
        DateTime? issuedAt;
        DateTime? expiresAt;

        if (payloadId.isNotEmpty ||
            payloadU.isNotEmpty ||
            payloadP.isNotEmpty ||
            payloadX.isNotEmpty) {
          // Minimal consistency checks (won't crash if mismatch)
          if (payloadId.isNotEmpty && payloadId != userId) continue;
          if (payloadU.isNotEmpty && payloadU != username) continue;
          if (payloadP.isNotEmpty && payloadP != phone) continue;
          if (payloadX.isNotEmpty && payloadX != xPub) continue;

          issuedAt = _parseEpochSeconds(payload[_kI]);
          expiresAt = _parseEpochSeconds(payload[_kExp]);
        }

        rawList.add({
          'storageKey': e.key,
          'userId': userId,
          'username': username,
          'phone': phone,
          'publicKey': xPub,
          'savedAt': savedAt,
          'issuedAt': issuedAt,
          'expiresAt': expiresAt,
        });
      } catch (_) {
        // ignore invalid JSON
      }
    }

    if (rawList.isEmpty) return [];

    // Determine newest (active) per userId by savedAt
    final Map<String, Map<String, dynamic>> newestByUser = {};
    for (final item in rawList) {
      final userId = (item['userId'] ?? '').toString();
      if (userId.isEmpty) continue;

      final cur = newestByUser[userId];
      if (cur == null) {
        newestByUser[userId] = item;
      } else {
        final a = cur['savedAt'] as DateTime;
        final b = item['savedAt'] as DateTime;
        if (b.isAfter(a)) newestByUser[userId] = item;
      }
    }

    final now = DateTime.now();
    final contacts = <ContactRecord>[];

    for (final item in rawList) {
      final userId = (item['userId'] ?? '').toString();
      final username = (item['username'] ?? '').toString();
      final phone = (item['phone'] ?? '').toString();
      final publicKey = (item['publicKey'] ?? '').toString();
      final issuedAt = item['issuedAt'] as DateTime?;
      final expiresAt = item['expiresAt'] as DateTime?;

      final activeItem = (userId.isNotEmpty) ? newestByUser[userId] : null;

      final bool isActive = activeItem != null &&
          activeItem['storageKey'] == item['storageKey'];

      final bool timeExpired = (expiresAt != null) && expiresAt.isBefore(now);
      final bool rotationExpired = userId.isNotEmpty && !isActive;
      final bool isExpired = timeExpired || rotationExpired;

      contacts.add(
        ContactRecord(
          storageKey: item['storageKey'] as String,
          userId: userId,
          username: username,
          phone: phone,
          publicKeyBase64: publicKey,
          issuedAt: issuedAt,
          expiresAt: expiresAt,
          isActive: isActive,
          isExpired: isExpired,
        ),
      );
    }

    contacts.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
      return a.username.compareTo(b.username);
    });

    return contacts;
  }

  ValidationResult validateContactForEncryption(ContactRecord c) {
    if (c.phone.trim().isEmpty) {
      return const ValidationResult(false, 'Selected contact phone is empty.');
    }
    final phoneCheck = validateReceiverPhone(c.phone);
    if (!phoneCheck.ok) return phoneCheck;

    if (c.publicKeyBase64.trim().isEmpty) {
      return const ValidationResult(false, 'Selected contact public key is empty.');
    }
    final pk = validateRecipientPublicKey(c.publicKeyBase64);
    if (!pk.ok) return pk;

    if (c.isExpired || !c.isActive) {
      return const ValidationResult(
        false,
        'This contact key is expired/old. Please re-scan the latest QR.',
      );
    }
    return const ValidationResult(true, 'OK');
  }
}
