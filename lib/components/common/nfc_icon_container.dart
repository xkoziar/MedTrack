import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';

class NfcIconContainer extends StatelessWidget {
  final double size;
  final double iconSize;

  const NfcIconContainer({
    super.key,
    this.size = 12.0,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size),
      decoration: BoxDecoration(
        gradient: AppGradients.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.nfc,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}
