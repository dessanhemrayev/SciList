import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/update_constants.dart';
import '../widgets/common/custom_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Об авторе'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colors.primary,
                  child: Icon(
                    Icons.terminal_rounded,
                    size: 34,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Разработчик SciList',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${UpdateConstants.githubOwner}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('О проекте', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'SciList помогает проверить научный журнал по ISSN в Белом списке РЦНИ.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _openLink(
              context,
              'https://github.com/${UpdateConstants.githubOwner}',
            ),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Профиль на GitHub'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openLink(
              context,
              'https://github.com/${UpdateConstants.githubOwner}/${UpdateConstants.githubRepo}',
            ),
            icon: const Icon(Icons.code_rounded),
            label: const Text('Исходный код SciList'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}