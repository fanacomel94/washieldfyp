import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'pages/home_page.dart';
import 'theme/theme_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '60');

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  bool _saving = false;

  // ✅ clientId dropdown (1/2)
  int _selectedClientId = 1;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    const countryCode = '60';

    final phoneDigitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (username.isEmpty) {
      _showError('Please enter username.');
      return;
    }
    if (phoneDigitsOnly.isEmpty) {
      _showError('Please enter your WhatsApp number.');
      return;
    }
    if (phoneDigitsOnly.length < 10 || phoneDigitsOnly.length > 12) {
      _showError('Phone must be 10–11 digits (example: 60123456789).');
      return;
    }
    if (!phoneDigitsOnly.startsWith(countryCode)) {
      _showError('Phone must start with country code 60 (example: 60123456789).');
      return;
    }

    setState(() => _saving = true);

    try {
      final existingUserId = await _secureStorage.read(key: 'wa_shield_user_id');
      final userId = existingUserId ?? _uuid.v4();

      await _secureStorage.write(key: 'wa_shield_user_id', value: userId);
      await _secureStorage.write(key: 'wa_shield_my_phone', value: phoneDigitsOnly);
      await _secureStorage.write(key: 'wa_shield_my_username', value: username);

      await _secureStorage.write(
        key: 'wa_client_id',
        value: _selectedClientId.toString(),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startWithoutRegister() async {
    try {
      final existingClientId =
          (await _secureStorage.read(key: 'wa_client_id') ?? '').trim();
      if (existingClientId.isEmpty) {
        await _secureStorage.write(key: 'wa_client_id', value: '1');
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor.withOpacity(0.35), width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor.withOpacity(0.35), width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        // You asked: light green background (like screenshot)
        const bg = Color(0xFFD9F9CC);
        const brandGreen = Color(0xFF0B8F3A);

        // Optional: keep your theme toggle action, but match the clean layout
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Create Account',
                style: TextStyle(
                  color: brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Toggle theme',
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: brandGreen,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ✅ Logo
                          Center(
                            child: Image.asset(
                              'assets/images/LOGO_WASHIELD.png',
                              width: 200, // 🔥 increase image size
                              height: 70, // 🔥 increase image size
                              fit: BoxFit.contain,
                            ),
                          ),


                          const SizedBox(height: 14),

                          
                          Center(
                            child: Text(
                              'Join us today and get started',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.55),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Username
                          const Text(
                            'Username',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              hint: 'Enter your username',
                              borderColor: brandGreen,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // WhatsApp Number
                          const Text(
                            'WhatsApp Number',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _fieldDecoration(
                              hint: '+60 12-345 6789',
                              borderColor: brandGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Include country code (e.g., +60)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Session Option (client)
                          const Text(
                            'Session Option',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: brandGreen.withOpacity(0.35),
                                width: 1.4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedClientId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('Client 1 (WhatsApp A / sender)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('Client 2 (WhatsApp B / receiver)'),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() => _selectedClientId = v);
                                      },
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Register button (filled)
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Register',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Start button (outlined)
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _saving ? null : _startWithoutRegister,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandGreen,
                                side: const BorderSide(color: brandGreen, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Start',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
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
            ),
          ),
        );
      },
    );
  }
}
