// ==============================
// FILE 3: lib/cryptomanager.dart
// ==============================
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart' as dart_crypto;

/// CryptoManager: secure key management and crypto primitives using the
/// `cryptography` package.
///
/// - X25519 for ECDH key agreement
/// - Ed25519 for signatures
/// - HKDF-SHA256 for key derivation
/// - AES-GCM for authenticated encryption
class CryptoManager {
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  // Storage keys
  static const _x25519PrivateKeyKey = 'wa_shield_x25519_private_key';
  static const _x25519PublicKeyKey = 'wa_shield_x25519_public_key';
  static const _ed25519PrivateKeyKey = 'wa_shield_ed25519_private_key';
  static const _ed25519PublicKeyKey = 'wa_shield_ed25519_public_key';

  // Algorithms
  static final X25519 _x25519 = X25519();
  static final Ed25519 _ed25519 = Ed25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();

  // ---------------------------------------------------------------------------
  // ✅ COMPACT Signed QR payload helpers (short keys, still includes username+phone)
  // ---------------------------------------------------------------------------

  /// Compact QR type/version.
  /// Keep it short to reduce QR size.
  static const String compactQrType = 'W1';

  /// Canonical string in FIXED ORDER for signing/verifying.
  ///
  /// Why canonical string?
  /// - If you sign raw jsonEncode(map), key order might differ in some edge cases.
  /// - Canonical string is stable, so signature verification is stable.
  ///
  /// Fields:
  /// t   : type/version (W1)
  /// id  : userId
  /// u   : username
  /// p   : phone
  /// x   : x25519 public key (Base64)
  /// e   : ed25519 public key (Base64)
  /// i   : issuedAt (epoch seconds)
  /// exp : expiresAt (epoch seconds)
  static String _canonicalCompactQrString({
    required String t,
    required String id,
    required String u,
    required String p,
    required String x,
    required String e,
    required int i,
    required int exp,
  }) {
    // Use a delimiter unlikely in base64/user fields.
    return 't=$t|id=$id|u=$u|p=$p|x=$x|e=$e|i=$i|exp=$exp';
  }

  /// ✅ Build compact signed QR payload (short keys).
  ///
  /// Payload keys (SHORT):
  /// - t   : type/version  (example: W1)
  /// - id  : userId        (unique identity)
  /// - u   : username      (display name)
  /// - p   : phone         (bind identity to phone)
  /// - x   : x25519 pubkey (for ECDH -> AES key)
  /// - e   : ed25519 pubkey (to verify signature)
  /// - i   : issuedAt epoch seconds
  /// - exp : expiresAt epoch seconds
  /// - s   : signature base64 over canonical string (tamper detection)
  static Future<Map<String, dynamic>> buildCompactSignedQrPayload({
    required String userId,
    required String username,
    required String phone,
    required String x25519PublicKeyBase64,
    required String ed25519PublicKeyBase64,
    required DateTime issuedAtUtc,
    required DateTime expiresAtUtc,
  }) async {
    final id = userId.trim();
    final u = username.trim();
    final p = phone.trim();
    final x = x25519PublicKeyBase64.trim();
    final e = ed25519PublicKeyBase64.trim();

    if (id.isEmpty) throw Exception('userId is empty');
    if (u.isEmpty) throw Exception('username is empty');
    if (p.isEmpty) throw Exception('phone is empty');
    if (x.isEmpty) throw Exception('x25519 public key is empty');
    if (e.isEmpty) throw Exception('ed25519 public key is empty');

    if (!validatePublicKey(x)) {
      throw Exception('Invalid X25519 public key format');
    }
    if (!validatePublicKey(e)) {
      throw Exception('Invalid Ed25519 public key format');
    }

    final int i = issuedAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000;
    final int exp = expiresAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (exp <= i) throw Exception('expiresAt must be after issuedAt');

    final canonical = _canonicalCompactQrString(
      t: compactQrType,
      id: id,
      u: u,
      p: p,
      x: x,
      e: e,
      i: i,
      exp: exp,
    );

    final sigBase64 = await signMessage(canonical);

    return <String, dynamic>{
      't': compactQrType,
      'id': id,
      'u': u,
      'p': p,
      'x': x,
      'e': e,
      'i': i,
      'exp': exp,
      's': sigBase64,
    };
  }

  /// ✅ Verify compact signed QR payload (short keys).
  ///
  /// Checks:
  /// - type/version
  /// - required fields exist
  /// - key formats (Base64 32 bytes)
  /// - expiry not passed
  /// - signature matches (tamper-proof)
  static Future<QrVerifyResult> verifyCompactSignedQrPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final t = (payload['t'] ?? '').toString().trim();
      if (t != compactQrType) {
        return QrVerifyResult.fail('Wrong QR type (expected $compactQrType)');
      }

      final id = (payload['id'] ?? '').toString().trim();
      final u = (payload['u'] ?? '').toString().trim();
      final p = (payload['p'] ?? '').toString().trim();
      final x = (payload['x'] ?? '').toString().trim();
      final e = (payload['e'] ?? '').toString().trim();
      final s = (payload['s'] ?? '').toString().trim();

      final iRaw = payload['i'];
      final expRaw = payload['exp'];

      if (id.isEmpty) return QrVerifyResult.fail('Missing id (userId)');
      if (u.isEmpty) return QrVerifyResult.fail('Missing u (username)');
      if (p.isEmpty) return QrVerifyResult.fail('Missing p (phone)');
      if (x.isEmpty) {
        return QrVerifyResult.fail('Missing x (x25519 public key)');
      }
      if (e.isEmpty) {
        return QrVerifyResult.fail('Missing e (ed25519 public key)');
      }
      if (s.isEmpty) return QrVerifyResult.fail('Missing s (signature)');
      if (iRaw == null) return QrVerifyResult.fail('Missing i (issuedAt)');
      if (expRaw == null) return QrVerifyResult.fail('Missing exp (expiresAt)');

      final int i = (iRaw is int) ? iRaw : int.tryParse(iRaw.toString()) ?? -1;
      final int exp = (expRaw is int)
          ? expRaw
          : int.tryParse(expRaw.toString()) ?? -1;

      if (i <= 0) return QrVerifyResult.fail('Invalid i (issuedAt)');
      if (exp <= 0) return QrVerifyResult.fail('Invalid exp (expiresAt)');

      // Expiry check (epoch seconds)
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (exp < now) {
        return QrVerifyResult.fail(
          'This key is expired. Ask sender to generate a new key and scan again.',
        );
      }

      if (!validatePublicKey(x)) {
        return QrVerifyResult.fail(
          'Invalid x public key format (Base64 32 bytes)',
        );
      }
      if (!validatePublicKey(e)) {
        return QrVerifyResult.fail(
          'Invalid e public key format (Base64 32 bytes)',
        );
      }

      final canonical = _canonicalCompactQrString(
        t: t,
        id: id,
        u: u,
        p: p,
        x: x,
        e: e,
        i: i,
        exp: exp,
      );

      final okSig = await verifySignature(canonical, s, e);
      if (!okSig) {
        return QrVerifyResult.fail('Invalid signature (QR modified or fake)');
      }

      return QrVerifyResult.ok();
    } catch (err) {
      return QrVerifyResult.fail('Verification error: $err');
    }
  }

  // ---------------------------------------------------------------------------
  // HKDF + Keys
  // ---------------------------------------------------------------------------

  static Uint8List _hkdfSha256(
    Uint8List ikm,
    List<int> info,
    int length, [
    List<int>? salt,
  ]) {
    final saltBytes = salt ?? List<int>.filled(32, 0);
    final prk = dart_crypto.Hmac(
      dart_crypto.sha256,
      saltBytes,
    ).convert(ikm).bytes;

    final hmac = dart_crypto.Hmac(dart_crypto.sha256, prk);
    final t = hmac.convert([...info, 0x01]).bytes;

    if (length <= t.length) {
      return Uint8List.fromList(t.sublist(0, length));
    }
    throw Exception('Requested HKDF length too large');
  }

  static Future<Map<String, String>> generateAndStoreKeyPairs() async {
    final xKeyPair = await _x25519.newKeyPair();
    final xPairData = await xKeyPair.extract();
    final xPrivate = xPairData.bytes;
    final xPublic = xPairData.publicKey.bytes;

    final edKeyPair = await _ed25519.newKeyPair();
    final edPairData = await edKeyPair.extract();
    final edPrivate = edPairData.bytes;
    final edPublic = edPairData.publicKey.bytes;

    await _secureStorage.write(
      key: _x25519PrivateKeyKey,
      value: base64Encode(xPrivate),
    );
    await _secureStorage.write(
      key: _x25519PublicKeyKey,
      value: base64Encode(xPublic),
    );
    await _secureStorage.write(
      key: _ed25519PrivateKeyKey,
      value: base64Encode(edPrivate),
    );
    await _secureStorage.write(
      key: _ed25519PublicKeyKey,
      value: base64Encode(edPublic),
    );

    return {
      'x25519_public': base64Encode(xPublic),
      'ed25519_public': base64Encode(edPublic),
    };
  }

  static Future<Uint8List?> _loadX25519PrivateKeyBytes() async {
    final s = await _secureStorage.read(key: _x25519PrivateKeyKey);
    if (s == null) return null;
    return Uint8List.fromList(base64Decode(s));
  }

  static bool validatePublicKey(String publicKeyBase64) {
    try {
      final bytes = base64Decode(publicKeyBase64);
      return bytes.length == 32;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> rotateKeys() async {
    final newPubs = await generateAndStoreKeyPairs();
    return newPubs;
  }

  static Future<String> computeSharedSecretAesKeyBase64(
    String theirPublicKeyBase64,
  ) async {
    final myPrivateBytes = await _loadX25519PrivateKeyBytes();
    if (myPrivateBytes == null) {
      throw Exception(
        'Local X25519 private key not found. Generate keys first.',
      );
    }

    final theirPublicBytes = base64Decode(theirPublicKeyBase64);
    if (theirPublicBytes.length != 32) {
      throw Exception('Invalid peer public key length');
    }

    final myPublicBase64 = await _secureStorage.read(key: _x25519PublicKeyKey);
    if (myPublicBase64 == null) {
      throw Exception('Local X25519 public key not found');
    }
    final myPublicBytes = base64Decode(myPublicBase64);

    final myKeyPair = SimpleKeyPairData(
      myPrivateBytes,
      publicKey: SimplePublicKey(myPublicBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    final theirPublic = SimplePublicKey(
      theirPublicBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublic,
    );

    final sharedBytes = await sharedSecret.extractBytes();
    final derivedBytes = _hkdfSha256(
      Uint8List.fromList(sharedBytes),
      utf8.encode('WA-Shield AES-256-GCM key'),
      32,
    );

    return base64Encode(derivedBytes);
  }

  static Future<String> deriveConfirmationKey(String sharedSecretBase64) async {
    final secretBytes = base64Decode(sharedSecretBase64);
    final derivedBytes = _hkdfSha256(
      Uint8List.fromList(secretBytes),
      utf8.encode('WA-Shield confirmation key'),
      32,
    );
    return base64Encode(derivedBytes);
  }

  // ---------------------------------------------------------------------------
  // ✅ AES-GCM (STRICT + tamper detection)
  // ---------------------------------------------------------------------------

  /// Encrypt a message using AES-256-GCM (strict).
  /// Returns base64(JSON): { v, iv, ciphertext, tag }
  static Future<String> encryptAES256GCM(
    String message,
    String aesKeyBase64, {
    String? aad,
  }) async {
    final keyBytes = base64Decode(aesKeyBase64);
    if (keyBytes.length != 32) throw Exception('AES key must be 32 bytes');

    final secretKey = SecretKey(keyBytes);

    // recommended 12-byte nonce
    final nonce = _aesGcm.newNonce();
    final messageBytes = utf8.encode(message);

    // ✅ ALWAYS List<int> (empty list allowed)
    final List<int> aadBytes = (aad == null || aad.isEmpty)
        ? const <int>[]
        : utf8.encode(aad);

    final secretBox = await _aesGcm.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: aadBytes,
    );

    final payload = jsonEncode({
      'v': 1,
      'iv': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'tag': base64Encode(secretBox.mac.bytes),
    });

    return base64Encode(utf8.encode(payload));
  }

  /// Decrypt payload produced by encryptAES256GCM (strict).
  static Future<String> decryptAES256GCM(
    String payloadBase64,
    String aesKeyBase64, {
    String? aad,
  }) async {
    final keyBytes = base64Decode(aesKeyBase64);
    if (keyBytes.length != 32) {
      throw Exception('Invalid AES key length (expected 32 bytes)');
    }

    final String payloadJson;
    try {
      payloadJson = utf8.decode(base64Decode(payloadBase64.trim()));
    } catch (_) {
      throw Exception('Invalid payload (not valid Base64)');
    }

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid payload (not valid JSON)');
    }

    if (!parsed.containsKey('iv') ||
        !parsed.containsKey('ciphertext') ||
        !parsed.containsKey('tag')) {
      throw Exception('Invalid payload (missing fields)');
    }

    final ivB64 = (parsed['iv'] ?? '').toString();
    final ctB64 = (parsed['ciphertext'] ?? '').toString();
    final tagB64 = (parsed['tag'] ?? '').toString();

    Uint8List iv, ct, tag;
    try {
      iv = Uint8List.fromList(base64Decode(ivB64));
      ct = Uint8List.fromList(base64Decode(ctB64));
      tag = Uint8List.fromList(base64Decode(tagB64));
    } catch (_) {
      throw Exception('Invalid payload (bad Base64 fields)');
    }

    if (iv.length != 12) {
      throw Exception('Invalid payload (IV length ${iv.length}, expected 12)');
    }
    if (tag.length != 16) {
      throw Exception(
        'Invalid payload (TAG length ${tag.length}, expected 16)',
      );
    }
    if (ct.isEmpty) {
      throw Exception('Invalid payload (empty ciphertext)');
    }

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(ct, nonce: iv, mac: Mac(tag));

    final List<int> aadBytes = (aad == null || aad.isEmpty)
        ? const <int>[]
        : utf8.encode(aad);

    try {
      final clear = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: aadBytes,
      );
      return utf8.decode(clear);
    } catch (_) {
      throw Exception('AUTH FAIL (tampered / wrong key / wrong AAD)');
    }
  }

  // ---------------------------------------------------------------------------
  // Ed25519 signatures
  // ---------------------------------------------------------------------------

  static Future<String> signMessage(String message) async {
    final stored = await _secureStorage.read(key: _ed25519PrivateKeyKey);
    if (stored == null) throw Exception('Ed25519 private key not found');

    final privateBytes = base64Decode(stored);

    final edPublicBase64 = await _secureStorage.read(key: _ed25519PublicKeyKey);
    if (edPublicBase64 == null) throw Exception('Ed25519 public key not found');

    final edPublicBytes = base64Decode(edPublicBase64);

    final keyPair = SimpleKeyPairData(
      privateBytes,
      publicKey: SimplePublicKey(edPublicBytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );

    final signature = await _ed25519.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );

    return base64Encode(signature.bytes);
  }

  static Future<bool> verifySignature(
    String message,
    String signatureBase64,
    String publicKeyBase64,
  ) async {
    try {
      final signatureBytes = base64Decode(signatureBase64);
      final publicBytes = base64Decode(publicKeyBase64);

      final publicKey = SimplePublicKey(publicBytes, type: KeyPairType.ed25519);
      final sig = Signature(signatureBytes, publicKey: publicKey);

      return await _ed25519.verify(utf8.encode(message), signature: sig);
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String?>> getStoredPublicKeys() async {
    final x = await _secureStorage.read(key: _x25519PublicKeyKey);
    final ed = await _secureStorage.read(key: _ed25519PublicKeyKey);
    return {'x25519_public': x, 'ed25519_public': ed};
  }

  static Future<void> ensureKeysExist() async {
    final pubs = await getStoredPublicKeys();
    if (pubs['x25519_public'] == null || pubs['ed25519_public'] == null) {
      await generateAndStoreKeyPairs();
    }
  }
}

class QrVerifyResult {
  final bool ok;
  final String? reason;

  const QrVerifyResult._(this.ok, this.reason);

  factory QrVerifyResult.ok() => const QrVerifyResult._(true, null);
  factory QrVerifyResult.fail(String reason) => QrVerifyResult._(false, reason);
}
