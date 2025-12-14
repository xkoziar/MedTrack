import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/medication/medication_short_info_card.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/pages/add_medication_page.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';

import '../database/model/medication.dart';
import 'medication_details_page.dart';

class MedicationPage extends StatelessWidget {
  final _medicationService = get<MedicationDatabaseService>();
  final _authService = get<AuthService>();

  MedicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          GradientSliverHeader(
            title: 'My Medications',
            subtitle: 'Manage your medications',
            onBack: canPop ? () => Navigator.of(context).pop() : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryGradientButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const AddMedicationPage(),
                        ),
                      );
                    },
                    label: '+ Add Medication',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Active Medications', style: AppTextStyles.heading3),
                  const SizedBox(height: AppSpacing.md),
                  HandlingStreamBuilder<List<Medication>>(
                    stream: _medicationService.observeUserMedications(
                      _authService.user?.uid ?? '',
                    ),
                    builder: (medications) {
                      if (medications.isEmpty) {
                        return const AppCard(
                          child: Center(
                            child: Text(
                              'No medications added yet.',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: medications.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final medication = medications[index];
                          return MedicationShortInfoCard(
                            medication: medication,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => MedicationDetailPage(
                                    medication: medication,
                                    recentEvents:
                                    const [], // TODO: Fetch events
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
