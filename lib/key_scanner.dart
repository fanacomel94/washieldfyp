
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'cryptomanager.dart';
import 'theme/theme_provider.dart';

// ✅ NEW UI
import 'UI/keyscanner_ui.dart';

class KeyScannerPage extends StatefulWidget {
  const KeyScannerPage({super.key});

  @override
  State<KeyScannerPage> createState() => _KeyScannerPageState();
}

class _KeyScannerPageState extends State<KeyScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _scanError;
  String? _rawContent;
  _ContactInfo? _contact;
  bool _saving = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  bool _isScanningFromGallery = false;
  final ImagePicker _imagePicker = ImagePicker();

  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
      _permissionChecked = true;
    });

    if (!_hasPermission) {
      setState(() {
        _scanError = 'Camera permission is required to scan QR codes';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_rawContent != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) {
      setState(() => _scanError = 'Empty QR data');
      return;
    }

    _handleScanned(code);
    _controller.stop();
  }

  Future<void> _scanFromGallery() async {
    try {
      setState(() {
        _isScanningFromGallery = true;
        _scanError = null;
      });

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        setState(() => _isScanningFromGallery = false);
        return;
      }

      final result = await _controller.analyzeImage(image.path);
      if (result == null || result.barcodes.isEmpty) {
        setState(() {
          _scanError = 'No QR code found in the selected image';
          _isScanningFromGallery = false;
        });
        return;
      }

      final code = result.barcodes.first.rawValue;
      if (code == null || code.isEmpty) {
        setState(() {
          _scanError = 'Empty QR data';
          _isScanningFromGallery = false;
        });
        return;
      }

      await _handleScanned(code);
    } catch (e) {
      setState(() => _scanError = 'Error scanning from gallery: $e');
    } finally {
      if (mounted) setState(() => _isScanningFromGallery = false);
    }
  }

  Future<void> _handleScanned(String raw) async {
    _rawContent = raw;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      setState(() {
        _scanError = 'Invalid QR format. Please scan WA-Shield QR (JSON).';
        _contact = null;
      });
      return;
    }

    // ✅ Verify COMPACT payload (short keys) but still has username + phone
    final result = await CryptoManager.verifyCompactSignedQrPayload(payload);
    if (!result.ok) {
      setState(() {
        _scanError = result.reason ?? 'QR verification failed';
        _contact = null;
      });
      return;
    }

    // ✅ Read compact keys
    final userId = (payload['id'] ?? '').toString().trim();
    final username = (payload['u'] ?? '').toString().trim();
    final phone = (payload['p'] ?? '').toString().trim();
    final xPub = (payload['x'] ?? '').toString().trim();
    final edPub = (payload['e'] ?? '').toString().trim();

    if (userId.isEmpty) {
      _setErr('QR missing userId. Ask sender to register again.');
      return;
    }
    if (username.isEmpty) {
      _setErr('QR missing username. Ask sender to register again.');
      return;
    }
    if (phone.isEmpty) {
      _setErr('QR missing phone. Ask sender to register again.');
      return;
    }
    if (xPub.isEmpty) {
      _setErr('QR missing public key (x25519).');
      return;
    }
    if (edPub.isEmpty) {
      _setErr('QR missing Ed25519 public key.');
      return;
    }

    if (!CryptoManager.validatePublicKey(xPub)) {
      _setErr('Invalid x25519 public key format (must be Base64 of 32 bytes).');
      return;
    }
    if (!CryptoManager.validatePublicKey(edPub)) {
      _setErr(
        'Invalid ed25519 public key format (must be Base64 of 32 bytes).',
      );
      return;
    }

    // Expiry is already checked inside verifyCompactSignedQrPayload(),
    // but you can still do an extra UX message if you want (optional).

    // Self-scan block by phone
    final myPhone = (await _secureStorage.read(key: 'wa_shield_my_phone') ?? '')
        .trim();
    if (myPhone.isNotEmpty && myPhone == phone) {
      _setErr('Self-scan blocked (this is your own QR).');
      return;
    }

    setState(() {
      _scanError = null;
      _contact = _ContactInfo(
        userId: userId,
        username: username,
        phone: phone,
        x25519PublicKey: xPub,
        ed25519PublicKey: edPub,
        fullPayload: payload,
      );
    });
  }

  void _setErr(String msg) {
    setState(() {
      _scanError = msg;
      _contact = null;
    });
  }

  Future<void> _saveContact() async {
    if (_contact == null) return;

    setState(() => _saving = true);

    try {
      final payload = _contact!.fullPayload;
      final userId = _contact!.userId;

      // ✅ Normalize phone for matching with WhatsApp JID
      final phoneDigits = _contact!.phone.replaceAll(RegExp(r'\D'), '');

      // ✅ Remove old contact entries with same phone (expired or older keys)
      await CryptoManager.removeOldContactsByPhone(phoneDigits);

      // ✅ Convert compact exp(epoch seconds) -> ISO string (optional but helpful)
      DateTime? expiresAtUtc;
      final expRaw = payload['exp'];
      final expSec = (expRaw is int) ? expRaw : int.tryParse(expRaw.toString());
      if (expSec != null && expSec > 0) {
        expiresAtUtc = DateTime.fromMillisecondsSinceEpoch(
          expSec * 1000,
          isUtc: true,
        );
      }

      final data = jsonEncode({
        'id': userId,
        'username': _contact!.username,
        'phone': phoneDigits,

        // keys (top level)
        'x25519PublicKey': _contact!.x25519PublicKey,
        'ed25519PublicKey': _contact!.ed25519PublicKey,

        // helpful fields for Inbox/Decrypt validation
        'fingerprint': '', // optional if you implement later
        'expiresAt': expiresAtUtc?.toIso8601String(), // ✅ optional
        'savedAt': DateTime.now().toIso8601String(),

        // original compact signed payload
        'payload': payload,
      });

      await _secureStorage.write(key: 'wa_shield_contact_$userId', value: data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved to secure storage')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save contact: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetAndScanAgain() {
    setState(() {
      _rawContent = null;
      _contact = null;
      _scanError = null;
    });
    _controller.start();
  }

  String _maskKey(String key) {
    final clean = key.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 12) return clean;
    final head = clean.substring(0, 4);
    final tail = clean.substring(clean.length - 4);
    return '$head •••• •••• $tail';
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final primaryColor = isDark
            ? const Color(0xFFAABF3F)
            : const Color(0xFF6B8E23);

        if (!_permissionChecked) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_hasPermission) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Camera Permission Required',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please grant camera permission to scan QR codes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _checkCameraPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_contact != null && _scanError == null) {
          return KeyScannerScannedUi(
            onBack: () => Navigator.pop(context),
            primaryColor: primaryColor,
            displayName: _contact!.username,
            phoneDisplay: _contact!.phone,
            publicKeyPreview: _maskKey(_contact!.x25519PublicKey),
            onSave: _saveContact,
            onSaveAndScanAgain: () async {
              await _saveContact();
              _resetAndScanAgain();
            },
            isSaving: _saving,
          );
        }

        return KeyScannerScanUi(
          onBack: () => Navigator.pop(context),
          onToggleTorch: _toggleTorch,
          isTorchOn: _torchOn,
          onChooseFromMedia: _isScanningFromGallery ? () {} : _scanFromGallery,
          cameraPreview: Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              if (_scanError != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 90),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          _scanError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactInfo {
  final String userId;
  final String username;
  final String phone;

  // ✅ Store BOTH keys
  final String x25519PublicKey;
  final String ed25519PublicKey;

  final Map<String, dynamic> fullPayload;

  const _ContactInfo({
    required this.userId,
    required this.username,
    required this.phone,
    required this.x25519PublicKey,
    required this.ed25519PublicKey,
    required this.fullPayload,
  });
}
