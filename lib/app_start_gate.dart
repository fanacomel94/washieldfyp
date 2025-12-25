import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pages/home_page.dart';
import 'register.dart';

class AppStartGate extends StatelessWidget {
  const AppStartGate({super.key});

  Future<bool> _hasStoredPhone() async {
    const storage = FlutterSecureStorage();
    final phone = await storage.read(key: 'wa_shield_my_phone');
    return phone != null && phone.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasStoredPhone(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasPhone = snapshot.data ?? false;
        if (!hasPhone) return const RegisterPage();

        return const HomePage();
      },
    );
  }
}
