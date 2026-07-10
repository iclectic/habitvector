import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_providers.dart';
import '../../providers/providers.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../../domain/services/privacy_consent_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentTheme = ref.watch(appThemeModeProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // Account
          if (authState.user != null) ...[
            _SectionHeader(title: 'Account'),
            const SizedBox(height: AppTheme.spacingSm),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: authState.user!.photoUrl != null
                      ? NetworkImage(authState.user!.photoUrl!)
                      : null,
                  child: authState.user!.photoUrl == null
                      ? Icon(Icons.person_rounded,
                          color: theme.colorScheme.onPrimaryContainer)
                      : null,
                ),
                title: Text(authState.user!.displayName ?? 'User'),
                subtitle: Text(authState.user!.email ?? ''),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],

          // Appearance
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: AppTheme.spacingSm),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  child: Row(
                    children: [
                      Icon(currentTheme.icon, color: theme.colorScheme.primary),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Theme',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              'Choose system default, light, or dark',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                  ),
                  child: SegmentedButton<AppThemeMode>(
                    segments: AppThemeMode.values
                        .map((m) => ButtonSegment<AppThemeMode>(
                              value: m,
                              label: Text(m.label),
                              icon: Icon(m.icon),
                            ))
                        .toList(),
                    selected: {currentTheme},
                    onSelectionChanged: (selection) {
                      HapticFeedback.lightImpact();
                      ref
                          .read(appThemeModeProvider.notifier)
                          .setTheme(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Notifications
          _SectionHeader(title: 'Notifications'),
          const SizedBox(height: AppTheme.spacingSm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.notifications_active_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Request Permission'),
                  subtitle:
                      const Text('Grant notification access for reminders'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final notifService = ref.read(notificationServiceProvider);
                    final granted = await notifService.requestPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            granted
                                ? 'Notification permission granted.'
                                : 'Notification permission denied. Please enable in system settings.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.send_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Test Notification'),
                  subtitle:
                      const Text('Send a test notification to verify setup'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final notifService = ref.read(notificationServiceProvider);
                    await notifService.sendTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent!'),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.schedule_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Pending Notifications'),
                  subtitle: const Text('View scheduled notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final notifService = ref.read(notificationServiceProvider);
                    final pending =
                        await notifService.getPendingNotifications();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Pending Notifications'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: pending.isEmpty
                                ? const Text('No pending notifications.')
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: pending.length,
                                    itemBuilder: (_, i) => ListTile(
                                      dense: true,
                                      title:
                                          Text(pending[i].title ?? 'Untitled'),
                                      subtitle: Text(pending[i].body ?? ''),
                                    ),
                                  ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Data
          _SectionHeader(title: 'Data'),
          const SizedBox(height: AppTheme.spacingSm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Export Data'),
                  subtitle: const Text('Save habits and logs as JSON'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _exportData(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.download_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Import Data'),
                  subtitle: const Text('Restore from a JSON backup'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _importData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Privacy
          _SectionHeader(title: 'Privacy'),
          const SizedBox(height: AppTheme.spacingSm),
          ref.watch(privacyConsentServiceProvider).when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (consentService) => Card(
              child: Column(
                children: [
                  Semantics(
                    label: 'Anonymous analytics. ${consentService.analyticsOptIn ? 'Currently enabled' : 'Currently disabled'}. Double tap to toggle.',
                    child: SwitchListTile(
                      secondary: Icon(Icons.analytics_outlined,
                          color: theme.colorScheme.primary),
                      title: const Text('Anonymous Analytics'),
                      subtitle: const Text(
                          'Share aggregate, anonymous usage data to help improve the app. No habit names or personal content are included.'),
                      value: consentService.analyticsOptIn,
                      onChanged: (value) async {
                        await consentService.setAnalyticsOptIn(value);
                        ref.invalidate(privacyConsentServiceProvider);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Semantics(
                    label: 'Delete all local data',
                    button: true,
                    child: ListTile(
                      leading: Icon(Icons.delete_forever_rounded,
                          color: theme.colorScheme.error),
                      title: Text(
                        'Delete All Data',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      subtitle: const Text(
                          'Permanently remove all habits, logs, and settings from this device.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _confirmDeleteAll(context, ref, consentService),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // About
          _SectionHeader(title: 'About'),
          const SizedBox(height: AppTheme.spacingSm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Habit Vector'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Privacy'),
                  subtitle:
                      const Text('All data is stored locally on your device. '
                          'Authentication is used for identity only.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Sign out
          if (authState.user != null) ...[
            Card(
              child: ListTile(
                leading:
                    Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text(
                  'Sign Out',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('You will need to sign in again'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    PrivacyConsentService consentService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete all your habits, logs, check-ins, '
          'and settings from this device.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final habitUseCases = ref.read(habitUseCasesProvider);
      final habits = await ref.read(habitRepositoryProvider).getAllHabits();
      for (final h in habits) {
        await habitUseCases.deleteHabit(h.id);
      }
      await consentService.clearConsentFlags();
      ref.invalidate(activeHabitsProvider);
      ref.invalidate(todayLogsProvider);
      ref.invalidate(privacyConsentServiceProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final exportImport = ref.read(exportImportUseCasesProvider);
      final jsonString = await exportImport.exportToJson();

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/habitvector_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Habit Vector Data Export',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      final exportImport = ref.read(exportImportUseCasesProvider);

      // Validate first
      final validation = exportImport.validateJson(jsonString);
      if (!validation.isValid) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Invalid Import File'),
              content: Text(
                'The selected file has the following issues:\n\n${validation.errors.join('\n')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Confirm import
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import Data'),
            content: Text(
              'This will import ${validation.data!.habits.length} habits and ${validation.data!.logs.length} log entries. '
              'Existing habits with matching IDs will be updated. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await exportImport.importFromJson(jsonString);
          ref.invalidate(activeHabitsProvider);
          ref.invalidate(todayLogsProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data imported successfully.')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
