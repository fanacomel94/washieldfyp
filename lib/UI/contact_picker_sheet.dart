import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';

/// Shows a modal bottom sheet for selecting a saved contact.
/// Returns selected contact Map or null.
Future<Map<String, dynamic>?> showContactPickerSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> contacts,
}) {
  if (contacts.isEmpty) return Future.value(null);

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDark = themeProvider.isDarkMode;
          final primaryColor =
              isDark ? const Color(0xFF8B9D3F) : const Color(0xFF6B8E23);
          final surfaceColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;

          return Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Saved Contact',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final displayName = contact['id'].toString().isNotEmpty
                          ? contact['id'].toString()
                          : 'Contact ${index + 1}';
                      final phone = contact['phone'].toString();
                      final phoneDisplay =
                          phone.isNotEmpty ? phone : 'No phone';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: primaryColor),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          phoneDisplay,
                          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        ),
                        trailing: Icon(Icons.chevron_right, color: primaryColor),
                        onTap: () => Navigator.of(context).pop(contact),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}
