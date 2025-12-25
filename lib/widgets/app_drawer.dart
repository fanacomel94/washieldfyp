import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../register.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  // 🔐 storage keys (MUST match RegisterPage)
  static const String kUsernameKey = 'wa_shield_my_username';
  static const String kPhoneKey = 'wa_shield_my_phone';
  static const String kAvatarKey = 'wa_shield_avatar_base64';

  String _username = 'WAShield User';
  String _phone = '';
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _storage.read(key: kUsernameKey);
    final phone = await _storage.read(key: kPhoneKey);
    final avatar = await _storage.read(key: kAvatarKey);

    if (!mounted) return;
    setState(() {
      _username = (name == null || name.isEmpty) ? 'WAShield User' : name;
      _phone = phone ?? '';
      _avatarBase64 = avatar;
    });
  }

  ImageProvider? _avatarImage() {
    if (_avatarBase64 == null || _avatarBase64!.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(_avatarBase64!));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼 Avatar
  // ---------------------------------------------------------------------------
  Future<void> _pickAvatar(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (file == null) return;

    final bytes = await File(file.path).readAsBytes();
    final b64 = base64Encode(bytes);

    await _storage.write(key: kAvatarKey, value: b64);
    if (!mounted) return;
    setState(() => _avatarBase64 = b64);
  }

  void _avatarMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _storage.delete(key: kAvatarKey);
                  if (!mounted) return;
                  setState(() => _avatarBase64 = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ✏️ Edit Name
  // ---------------------------------------------------------------------------
  Future<void> _editName() async {
    final controller = TextEditingController(text: _username);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              await _storage.write(key: kUsernameKey, value: name);
              if (!mounted) return;
              setState(() => _username = name);

              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📞 Edit Phone
  // ---------------------------------------------------------------------------
  Future<void> _editPhone() async {
    final controller = TextEditingController(text: _phone);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Example: 60123456789',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isEmpty) return;

              await _storage.write(key: kPhoneKey, value: phone);
              if (!mounted) return;
              setState(() => _phone = phone);

              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ℹ️ Help / About
  // ---------------------------------------------------------------------------
  void _showHelp() {
    final tips = [
      'Scan contact QR before encrypting.',
      'Modified QR will be rejected.',
      'AES-GCM ensures integrity.',
      'Never share private keys.',
    ]..shuffle();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help'),
        content: Text(tips.first),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    const text =
        'WAShield encrypts data BEFORE sending.\n\n'
        '• ECC (X25519 + ECDH)\n'
        '• HKDF-SHA256\n'
        '• AES-256-GCM\n'
        '• Optional Ed25519 signatures';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Us'),
        content: const Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🚪 Logout (DELETE EVERYTHING)
  // ---------------------------------------------------------------------------
  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'This will remove ALL local data.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storage.deleteAll();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
      (_) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // 🧱 UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 👤 Avatar (center)
            GestureDetector(
              onTap: _avatarMenu,
              child: CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: _avatarImage(),
                child: _avatarImage() == null
                    ? Icon(Icons.person,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer)
                    : null,
              ),
            ),

            const SizedBox(height: 12),

            // ✏️ Name
            InkWell(
              onTap: _editName,
              child: Text(
                _username,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 4),

            // 📞 Phone
            InkWell(
              onTap: _editPhone,
              child: Text(
                _phone.isEmpty ? 'Tap to add phone' : _phone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(),

            _item(Icons.help_outline, 'Help', _showHelp),
            _item(Icons.info_outline, 'About Us', _showAbout),
            _item(Icons.logout, 'Log Out', _logout, danger: true),

            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('v1.0 • WAShield'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : null),
      title: Text(
        title,
        style: TextStyle(color: danger ? Colors.red : null),
      ),
      onTap: onTap,
    );
  }
}
