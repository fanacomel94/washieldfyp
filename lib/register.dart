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
  final TextEditingController _phoneController = TextEditingController(
    text: '60',
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final countryCode = '60';

    // Basic validation
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
      // ✅ Create UUID only once (do not regenerate each save)
      final existingUserId = await _secureStorage.read(key: 'wa_shield_user_id');
      final userId = existingUserId ?? _uuid.v4();

      // ✅ Save all registration data into FlutterSecureStorage
      await _secureStorage.write(key: 'wa_shield_user_id', value: userId);
      await _secureStorage.write(key: 'wa_shield_my_phone', value: phoneDigitsOnly);
      await _secureStorage.write(key: 'wa_shield_my_username', value: username);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startWithoutRegister() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final primaryColor =
            isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23);
        final textColor = isDark ? Colors.white : Colors.black87;
        final hintColor = isDark ? Colors.grey[500] : Colors.grey[600];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Set Your WhatsApp Number'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1A1A), const Color(0xFF2C2C2C)]
                    : [Colors.white, const Color(0xFFF5F5F0)],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Register Your WhatsApp Number',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 24),

                    _buildInput(
                      context,
                      label: 'Name',
                      controller: _usernameController,
                      hintText: 'Your name',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      hintColor: hintColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 20),

                    _buildInput(
                      context,
                      label: 'WhatsApp Number (E.164 digits)',
                      controller: _phoneController,
                      hintText: 'Example: 60123456789',
                      isDark: isDark,
                      primaryColor: primaryColor,
                      hintColor: hintColor,
                      textColor: textColor,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),

                    const SizedBox(height: 32),

                    // ✅ Save (Register)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ✅ Start without register
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _startWithoutRegister,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Start'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: primaryColor.withValues(alpha: 0.6),
                            width: 1.6,
                          ),
                          foregroundColor: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    required Color primaryColor,
    required Color? hintColor,
    required Color textColor,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          keyboardType: inputFormatters != null ? TextInputType.number : null,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor),
            filled: true,
            fillColor: isDark
                ? Colors.grey[900]?.withValues(alpha: 0.5)
                : Colors.grey[100]?.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: TextStyle(color: textColor),
          cursorColor: primaryColor,
        ),
      ],
    );
  }
}
