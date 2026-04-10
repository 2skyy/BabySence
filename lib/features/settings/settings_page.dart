import 'package:flutter/material.dart';
import '../../core/widgets/common_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CommonAppBar(title: 'Settings'),
      body: Center(child: Text('Settings Page')),
    );
  }
}
