import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Agent list screen — placeholder for Step 17.
class AgentListScreen extends StatelessWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QubixColors.background,
      appBar: AppBar(title: const Text('Agents')),
      body: Center(
        child: Text(
          'Agent management will be built in Step 17',
          style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
        ),
      ),
    );
  }
}
