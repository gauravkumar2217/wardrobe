import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  String _selectedTemperatureUnit = 'Celsius';

  final List<Map<String, dynamic>> _settingsSections = [
    {
      'title': 'Profile',
      'icon': Icons.account_circle,
      'items': [
        {'title': 'Edit Profile', 'subtitle': 'Manage your personal information'},
        {'title': 'Change Password', 'subtitle': 'Update your password'},
        {'title': 'Privacy Settings', 'subtitle': 'Control your privacy preferences'},
      ],
    },
    {
      'title': 'Appearance',
      'icon': Icons.palette,
      'items': [
        {'title': 'Theme', 'subtitle': 'Choose app appearance'},
        {'title': 'Color Scheme', 'subtitle': 'Customize app colors'},
        {'title': 'Font Size', 'subtitle': 'Adjust text size'},
      ],
    },
    {
      'title': 'Notifications',
      'icon': Icons.notifications,
      'items': [
        {'title': 'Push Notifications', 'subtitle': 'Receive app notifications'},
        {'title': 'Weather Alerts', 'subtitle': 'Get weather-based outfit suggestions'},
        {'title': 'Calendar Reminders', 'subtitle': 'Outfit planning reminders'},
      ],
    },
    {
      'title': 'Preferences',
      'icon': Icons.settings,
      'items': [
        {'title': 'Temperature Unit', 'subtitle': 'Celsius or Fahrenheit'},
        {'title': 'Language', 'subtitle': 'App language'},
        {'title': 'Units', 'subtitle': 'Measurement units'},
      ],
    },
    {
      'title': 'Data',
      'icon': Icons.storage,
      'items': [
        {'title': 'Export Data', 'subtitle': 'Export your wardrobe data'},
        {'title': 'Import Data', 'subtitle': 'Import wardrobe from another app'},
        {'title': 'Backup Settings', 'subtitle': 'Manage cloud backup'},
      ],
    },
    {
      'title': 'Help & Support',
      'icon': Icons.help,
      'items': [
        {'title': 'Help Center', 'subtitle': 'Find answers to common questions'},
        {'title': 'Contact Support', 'subtitle': 'Get help from our team'},
        {'title': 'Feature Requests', 'subtitle': 'Suggest new features'},
        {'title': 'Report Bug', 'subtitle': 'Report a problem'},
      ],
    },
    {
      'title': 'About',
      'icon': Icons.info,
      'items': [
        {'title': 'App Version', 'subtitle': 'v1.0.0'},
        {'title': 'Terms of Service', 'subtitle': 'Read our terms'},
        {'title': 'Privacy Policy', 'subtitle': 'How we protect your data'},
        {'title': 'Open Source Licenses', 'subtitle': 'View third-party licenses'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _resetSettings,
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _settingsSections.length,
        itemBuilder: (context, index) {
          final section = _settingsSections[index];
          return _buildSettingsSection(section);
        },
      ),
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> section) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  section['icon'],
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  section['title'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...section['items'].map<Widget>((item) => _getSettingsTypeWidget(item, section['title'])).toList(),
        ],
      ),
    );
  }

  Widget _getSettingsTypeWidget(Map<String, dynamic> item, String sectionTitle) {
    final itemTitle = item['title'];
    
    switch (sectionTitle) {
      case 'Notifications':
        switch (itemTitle) {
          case 'Push Notifications':
            return _buildSwitchItem(
              title: itemTitle,
              subtitle: item['subtitle'],
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            );
          default:
            return _buildSettingsItem(itemTitle, item['subtitle']);
        }
      
      case 'Appearance':
        switch (itemTitle) {
          case 'Theme':
            return _buildSwitchItem(
              title: itemTitle,
              subtitle: item['subtitle'],
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
            );
          default:
            return _buildSettingsItem(itemTitle, item['subtitle']);
        }
      
      case 'Preferences':
        switch (itemTitle) {
          case 'Temperature Unit':
            return _buildDropdownItem(
              title: itemTitle,
              subtitle: item['subtitle'],
              value: _selectedTemperatureUnit,
              options: ['Celsius', 'Fahrenheit'],
              onChanged: (value) {
                setState(() {
                  _selectedTemperatureUnit = value!;
                });
              },
            );
          case 'Language':
            return _buildDropdownItem(
              title: itemTitle,
              subtitle: item['subtitle'],
              value: _selectedLanguage,
              options: ['English', 'Spanish', 'French', 'German'],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            );
          default:
            return _buildSettingsItem(itemTitle, item['subtitle']);
        }
      
      default:
        return _buildSettingsItem(itemTitle, item['subtitle']);
    }
  }

  Widget _buildSettingsItem(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _handleSettingsTap(title),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdownItem({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _handleSettingsTap(String title) {
    // TODO: Implement navigation based on settings item
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $title...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement reset logic
              setState(() {
                _notificationsEnabled = true;
                _darkModeEnabled = false;
                _selectedLanguage = 'English';
                _selectedTemperatureUnit = 'Celsius';
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to default'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
