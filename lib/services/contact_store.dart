import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class ContactStore {
  static const String _storageKey = 'saved_contacts';
  final FlutterSecureStorage _secureStorage;

  ContactStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Validates contact data before storage
  bool _validateContact(Map<String, dynamic> contact) {
    if (contact.isEmpty) return false;
    if (contact['id'] == null || contact['id'].toString().isEmpty) return false;
    if (contact['phone'] == null || contact['phone'].toString().isEmpty) {
      return false;
    }
    return true;
  }

  /// Saves a scanned contact after QR verification
  Future<bool> saveContact(Map<String, dynamic> contact) async {
    try {
      if (!_validateContact(contact)) return false;

      final contacts = await readAllContacts();
      final contactId = contact['id'].toString();

      contacts.removeWhere((c) => c['id'].toString() == contactId);
      contacts.add(contact);

      final jsonString = jsonEncode(contacts);
      await _secureStorage.write(key: _storageKey, value: jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reads all saved contacts
  Future<List<Map<String, dynamic>>> readAllContacts() async {
    try {
      final jsonString = await _secureStorage.read(key: _storageKey);
      if (jsonString == null) return [];

      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return List<Map<String, dynamic>>.from(
        decoded.cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      return [];
    }
  }

  /// Reads a specific contact by ID
  Future<Map<String, dynamic>?> readContact(String contactId) async {
    try {
      final contacts = await readAllContacts();
      return contacts.firstWhere(
        (c) => c['id'].toString() == contactId,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }

  /// Deletes a contact by ID
  Future<bool> deleteContact(String contactId) async {
    try {
      final contacts = await readAllContacts();
      contacts.removeWhere((c) => c['id'].toString() == contactId);

      final jsonString = jsonEncode(contacts);
      await _secureStorage.write(key: _storageKey, value: jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes all contacts
  Future<bool> deleteAllContacts() async {
    try {
      await _secureStorage.delete(key: _storageKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets contact count
  Future<int> getContactCount() async {
    final contacts = await readAllContacts();
    return contacts.length;
  }

  /// Remove old/expired contacts with same phone number.
  ///
  /// When a user scans a new key from an existing contact:
  /// - Find all contacts with same phone number
  /// - Remove expired entries (expiresAt < now)
  /// - Remove older entries if new key is more recent
  /// - Keep only the latest valid key
  ///
  /// Returns number of contacts removed.
  Future<int> removeOldContactsByPhone(String phoneDigits) async {
    if (phoneDigits.trim().isEmpty) return 0;

    try {
      final contacts = await readAllContacts();
      final now = DateTime.now().toUtc();
      final normalizedPhone = phoneDigits.replaceAll(RegExp(r'\D'), '');

      if (normalizedPhone.isEmpty) return 0;

      // Group contacts by phone number
      final Map<String, List<Map<String, dynamic>>> contactsByPhone = {};

      for (final contact in contacts) {
        try {
          final storedPhone = (contact['phone'] ?? '').toString().trim();
          final storedDigits = storedPhone.replaceAll(RegExp(r'\D'), '');

          if (storedDigits.isEmpty) continue;

          if (contactsByPhone[storedDigits] == null) {
            contactsByPhone[storedDigits] = [];
          }
          contactsByPhone[storedDigits]!.add(contact);
        } catch (_) {
          // Skip malformed entries
        }
      }

      // Get matching contacts for this phone
      final matchingContacts = contactsByPhone[normalizedPhone];
      if (matchingContacts == null || matchingContacts.isEmpty) {
        return 0;
      }

      // Sort by savedAt (newest first)
      matchingContacts.sort((a, b) {
        try {
          final savedAtA = a['savedAt'] ?? '';
          final savedAtB = b['savedAt'] ?? '';

          DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);

          try {
            if (savedAtA.toString().isNotEmpty) {
              dateA = DateTime.parse(savedAtA.toString());
            }
          } catch (_) {}

          try {
            if (savedAtB.toString().isNotEmpty) {
              dateB = DateTime.parse(savedAtB.toString());
            }
          } catch (_) {}

          return dateB.compareTo(dateA); // Newest first
        } catch (_) {
          return 0;
        }
      });

      // Remove expired and older entries, keep only the newest
      int removedCount = 0;
      for (int i = 0; i < matchingContacts.length; i++) {
        final contact = matchingContacts[i];

        try {
          final expiresAtStr = (contact['expiresAt'] ?? '').toString();

          DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
          try {
            if (expiresAtStr.isNotEmpty) {
              expiresAt = DateTime.parse(expiresAtStr);
            }
          } catch (_) {}

          // Remove if expired OR if not the newest entry
          if (expiresAt.isBefore(now) || i > 0) {
            contacts.remove(contact);
            removedCount++;
          }
        } catch (_) {
          // Skip on error
        }
      }

      // Save cleaned contacts
      if (removedCount > 0) {
        final jsonString = jsonEncode(contacts);
        await _secureStorage.write(key: _storageKey, value: jsonString);
      }

      return removedCount;
    } catch (_) {
      return 0;
    }
  }
}
