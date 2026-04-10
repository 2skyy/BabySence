import 'package:flutter/material.dart';
import '../../core/widgets/common_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'Settings'),
      backgroundColor: const Color(0xFFF2F3F7),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Account'),
          _buildMenuItem(
            icon: Icons.person,
            title: 'Edit Profile',
            color: const Color(0xFF6C63FF),
            onTap: () {},
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('Notifications'),
          _buildSwitchItem(
            icon: Icons.notifications,
            title: 'Push Notifications',
            color: const Color(0xFF4CAF50),
            value: true,
            onChanged: (value) {},
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('App'),
          _buildSwitchItem(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            color: const Color(0xFF222222),
            value: false,
            onChanged: (value) {},
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('About'),
          _buildMenuItem(
            icon: Icons.info,
            title: 'App Version',
            color: const Color(0xFFFF9800),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // 📌 섹션 타이틀
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 📋 일반 메뉴
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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

  // 🔘 스위치 메뉴 (핵심)
  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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