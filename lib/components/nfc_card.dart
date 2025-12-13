import 'package:flutter/material.dart';
import '../utils/constants.dart';

class NfcPairCard extends StatelessWidget {
  final String? nfcTagId;
  final VoidCallback? onPair;

  const NfcPairCard({
    super.key,
    required this.nfcTagId,
    required this.onPair,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 12),
            const Text(
              'NFC tag',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              nfcTagId == null
                  ? 'Tap your phone to pair an NFC tag'
                  : 'Paired: $nfcTagId',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF11998E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onPair,
                child: Text(
                  nfcTagId == null ? 'Pair NFC' : 'Re-pair NFC',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
