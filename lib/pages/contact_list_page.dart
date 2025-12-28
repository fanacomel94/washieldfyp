import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../theme/theme_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'settings_page.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get all keys from secure storage
      final allKeys = await _secureStorage.readAll();
      
      // Filter for contact keys (starting with 'wa_shield_contact_')
      final contactKeys = allKeys.keys
          .where((key) => key.startsWith('wa_shield_contact_'))
          .toList();

      final List<Map<String, dynamic>> contacts = [];

      for (final key in contactKeys) {
        try {
          final value = allKeys[key];
          if (value != null && value.isNotEmpty) {
            final contactData = jsonDecode(value) as Map<String, dynamic>;
            
            // Add the contact ID from the key if not present in data
            if (!contactData.containsKey('storageKey')) {
              contactData['storageKey'] = key;
            }
            
            contacts.add(contactData);
          }
        } catch (e) {
          print('Error parsing contact $key: $e');
        }
      }

      // Sort by username (alphabetically)
      contacts.sort((a, b) {
        final usernameA = (a['username'] ?? '').toString().toLowerCase();
        final usernameB = (b['username'] ?? '').toString().toLowerCase();
        return usernameA.compareTo(usernameB);
      });

      setState(() {
        _allContacts = contacts;
        _filteredContacts = List.from(contacts);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase().trim();
    
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = List.from(_allContacts);
      });
      return;
    }

    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        final username = (contact['username'] ?? '').toString().toLowerCase();
        final phone = (contact['phone'] ?? '').toString().toLowerCase();
        
        return username.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final storageKey = contact['storageKey'];
    if (storageKey == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${contact['username']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _secureStorage.delete(key: storageKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact['username']} deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadContacts(); // Reload the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatExpiryDate(String? expiresAt) {
    if (expiresAt == null || expiresAt.isEmpty) {
      return 'No expiry';
    }

    try {
      final dateTime = DateTime.parse(expiresAt);
      final now = DateTime.now().toUtc();
      final difference = dateTime.difference(now);

      if (difference.isNegative) {
        return 'Expired';
      }

      if (difference.inDays > 30) {
        return 'Expires: ${dateTime.toLocal().toString().split(' ')[0]}';
      } else if (difference.inDays > 0) {
        return 'Expires in ${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return 'Expires in ${difference.inHours} hours';
      } else {
        return 'Expires soon';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getExpiryColor(String? expiresAt) {
    if (expiresAt == null || expiresAt.isEmpty) {
      return Colors.grey;
    }

    try {
      final dateTime = DateTime.parse(expiresAt);
      final now = DateTime.now().toUtc();
      final difference = dateTime.difference(now);

      if (difference.isNegative) {
        return Colors.red;
      } else if (difference.inDays < 7) {
        return Colors.orange;
      } else if (difference.inDays < 30) {
        return Colors.blue;
      } else {
        return Colors.green;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  String _maskKey(String? key) {
    if (key == null || key.isEmpty) return 'N/A';
    final clean = key.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 12) return clean;
    final head = clean.substring(0, 4);
    final tail = clean.substring(clean.length - 4);
    return '$head •••• •••• $tail';
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildContactCard(Map<String, dynamic> contact, ThemeData theme, bool isDark) {
    final username = (contact['username'] ?? 'Unknown').toString();
    final phone = (contact['phone'] ?? '').toString();
    final publicKey = (contact['x25519PublicKey'] ?? '').toString();
    final expiresAt = (contact['expiresAt'] ?? '').toString();
    final savedAt = (contact['savedAt'] ?? '').toString();
    //final edPublicKey = (contact['ed25519PublicKey'] ?? '').toString();

    DateTime? savedDateTime;
    try {
      savedDateTime = DateTime.parse(savedAt);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with username and delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteContact(contact),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.withOpacity(0.7),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete contact',
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Phone number
            _buildInfoRow(
              icon: Icons.phone,
              label: 'Phone:',
              value: phone,
              onCopy: () => _copyToClipboard(phone, 'Phone number'),
            ),
            
            const SizedBox(height: 10),
            
            // Public Key (X25519)
            _buildInfoRow(
              icon: Icons.key,
              label: 'Public Key:',
              value: _maskKey(publicKey),
              onCopy: () => _copyToClipboard(publicKey, 'Public key'),
            ),
            
            const SizedBox(height: 10),
            
            
            // Expiry and saved date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expiry date
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: _getExpiryColor(expiresAt),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatExpiryDate(expiresAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getExpiryColor(expiresAt),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                // Saved date
                if (savedDateTime != null)
                  Text(
                    'Saved: ${savedDateTime.toLocal().toString().split(' ')[0]}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.content_copy, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final cs = Theme.of(context).colorScheme;
        final theme = Theme.of(context);

        return Scaffold(
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
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contacts',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                            IconButton(
                              onPressed: _loadContacts,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh contacts',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your trusted contacts',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Search bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[800]!.withOpacity(0.3)
                                : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterContacts();
                                    },
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contact count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filteredContacts.length} contact${_filteredContacts.length != 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_allContacts.isNotEmpty && _filteredContacts.isEmpty)
                          Text(
                            'No matches found',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Content Area
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _hasError
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Failed to load contacts',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please check your secure storage',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _loadContacts,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _allContacts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: 64,
                                          color: cs.primary.withOpacity(0.6),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No Contacts Yet',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 40),
                                          child: Text(
                                            'Scan QR codes from trusted contacts to add them here.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.pop(context),
                                          icon: const Icon(Icons.qr_code_scanner),
                                          label: const Text('Scan QR Code'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    itemCount: _filteredContacts.length,
                                    itemBuilder: (context, index) {
                                      return _buildContactCard(
                                        _filteredContacts[index],
                                        theme,
                                        isDark,
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: 1,
            onTap: (index) {
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              } else if (index == 2) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }
            },
          ),
        );
      },
    );
  }
}
