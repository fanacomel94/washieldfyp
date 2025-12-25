import 'dart:convert';

import 'package:http/http.dart' as http;

/// BackendServices: minimal HTTP client for talking to the WA-Shield Node API.
///
/// Sends ciphertext to the `/message` endpoint, which in turn delivers
/// the message via whatsapp-web.js.
class BackendServices {
  final String baseUrl;

  BackendServices({required this.baseUrl});

  /// Sends an encrypted message (ciphertext) to the backend.
  ///
  /// [clientId]   - numeric ID of the WhatsApp client (e.g. 1).
  /// [receiverE164] - phone in E.164 without `+`, e.g. 60123456789.
  /// [ciphertext]  - encrypted payload produced by `EncryptionPage._outputText`.
  Future<void> sendCiphertext({
    required int clientId,
    required String receiverE164,
    required String ciphertext,
  }) async {
    // Normalize to digits and convert to WhatsApp chatId format.
    final digits = receiverE164.replaceAll(RegExp(r'\D'), '');
    final chatId = '$digits@c.us';

    final uri = Uri.parse('$baseUrl/message');

    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientId': clientId,
        'phoneNumber': chatId,
        'message': ciphertext,
      }),
    );

    if (res.statusCode >= 400) {
      throw Exception(
        'Failed to send ciphertext: ${res.statusCode} ${res.body}',
      );
    }
  }
}


