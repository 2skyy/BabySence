import 'package:flutter/material.dart';
import '../../core/widgets/common_app_bar.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CommonAppBar(title: 'Detail'),
      body: Center(child: Text('Detail Page')),
    );
  }
}
