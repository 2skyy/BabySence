import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isPushNotificationEnabled = true;
  bool isDarkModeEnabled = false;

  void handleEditProfileTap() {
    debugPrint('Edit Profile tapped');
  }

  void handleAppVersionTap() {
    debugPrint('App Version tapped');
  }

  void handlePushNotificationChanged(bool value) {
    setState(() {
      isPushNotificationEnabled = value;
    });
  }

  void handleDarkModeChanged(bool value) {
    setState(() {
      isDarkModeEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'Settings'),
      backgroundColor: const Color(0xFFF2F3F7),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildSectionTitle('Account'),
          _buildMenuItem(
            icon: Icons.person,
            title: 'Edit Profile',
            color: const Color(0xFF6C63FF),
            onTap: handleEditProfileTap,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('Notifications'),
          _buildSwitchItem(
            icon: Icons.notifications,
            title: 'Push Notifications',
            color: const Color(0xFF4CAF50),
            value: isPushNotificationEnabled,
            onChanged: handlePushNotificationChanged,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('App'),
          _buildSwitchItem(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            color: const Color(0xFF222222),
            value: isDarkModeEnabled,
            onChanged: handleDarkModeChanged,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('About'),
          _buildMenuItem(
            icon: Icons.info,
            title: 'App Version',
            color: const Color(0xFFFF9800),
            onTap: handleAppVersionTap,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: color),
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
