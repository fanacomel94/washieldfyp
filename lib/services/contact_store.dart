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
}