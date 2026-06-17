import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/account_link.dart';
import 'package:med_track/database/service/account_link_database_service.dart';
import 'package:med_track/pages/caregiver_patient_page.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/snackbar_utils.dart';

/// Shows the caregiver/family links of the current account, in both
/// directions, and lets the user remove a link. Linking itself happens by
/// scanning a QR code (see [ShareAccountCard] / the Profile QR scanner).
class LinkedAccountsCard extends StatelessWidget {
  final String currentUserId;

  LinkedAccountsCard({super.key, required this.currentUserId});

  final _linkDbService = get<AccountLinkDatabaseService>();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linked accounts', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.lg),

          _SectionLabel(
            icon: Icons.visibility_rounded,
            label: 'People who can view your account',
          ),
          const SizedBox(height: AppSpacing.sm),
          HandlingStreamBuilder<List<AccountLink>>(
            stream: _linkDbService.observeLinksAsPatient(currentUserId),
            loadingWidget: const _SectionLoading(),
            builder: (links) {
              if (links.isEmpty) {
                return const _EmptyHint('No one is linked to your account yet.');
              }
              return Column(
                children: links
                    .map(
                      (link) => _LinkRow(
                        name: link.caregiverName,
                        email: link.caregiverEmail,
                        onUnlink: () => _confirmUnlink(
                          context,
                          link,
                          'Remove ${_label(link.caregiverName, link.caregiverEmail)} '
                          "from your account? They will no longer be linked.",
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(
            icon: Icons.favorite_rounded,
            label: 'Accounts shared with you',
          ),
          const SizedBox(height: AppSpacing.sm),
          HandlingStreamBuilder<List<AccountLink>>(
            stream: _linkDbService.observeLinksAsCaregiver(currentUserId),
            loadingWidget: const _SectionLoading(),
            builder: (links) {
              if (links.isEmpty) {
                return const _EmptyHint(
                  "You haven't linked anyone's account yet. Use the QR scanner "
                  'in the header to link one.',
                );
              }
              return Column(
                children: links
                    .map(
                      (link) => _LinkRow(
                        name: link.patientName,
                        email: link.patientEmail,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CaregiverPatientPage(
                              patientUserId: link.patientUserId,
                              patientName: link.patientName,
                              patientEmail: link.patientEmail,
                            ),
                          ),
                        ),
                        onUnlink: () => _confirmUnlink(
                          context,
                          link,
                          'Stop following '
                          '${_label(link.patientName, link.patientEmail)}? '
                          'You can link again later by scanning their QR code.',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _label(String name, String email) =>
      name.trim().isNotEmpty ? name : email;

  Future<void> _confirmUnlink(
    BuildContext context,
    AccountLink link,
    String message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove link'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _linkDbService.delete(link.id);
      if (context.mounted) showSnackBar(context, 'Link removed');
    } catch (e) {
      if (context.mounted) showSnackBar(context, 'Failed to remove link: $e');
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMediumSemiBold),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onUnlink;
  final VoidCallback? onTap;

  const _LinkRow({
    required this.name,
    required this.email,
    required this.onUnlink,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isNotEmpty ? name : email;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.account_circle_rounded, size: 36, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTextStyles.bodyMediumSemiBold),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          IconButton(
            onPressed: onUnlink,
            tooltip: 'Remove link',
            icon: Icon(Icons.link_off_rounded, color: AppColors.danger),
          ),
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: row,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
