import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_event.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/helpers/adherence_calculator.dart';

import 'adherence_rate_card.dart';

class AdherenceRateProviderCard extends StatelessWidget {
  final String userId;
  final int periodInDays;

  AdherenceRateProviderCard({
    super.key,
    required this.userId,
    this.periodInDays = MedAdherence.days30,
  }) : assert(periodInDays > 0, 'periodInDays must be greater than 0'),
       assert(
         periodInDays <= 365,
         'periodInDays must be less than or equal to 365',
       );

  final _doseEventDbService = get<DoseEventDatabaseService>();

  @override
  Widget build(BuildContext context) {
    return HandlingStreamBuilder<List<DoseEvent>>(
      stream: _doseEventDbService.observeUserDoseEvents(userId),
      builder: (events) {
        final adherence = calculateAdherence(events, periodInDays);
        return AdherenceRateCard(
          rate: '${adherence.toStringAsFixed(0)}%',
          period: '$periodInDays days',
        );
      },
    );
  }
}
