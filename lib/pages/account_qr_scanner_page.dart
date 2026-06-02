import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AccountQrScannerPage extends StatefulWidget {
  const AccountQrScannerPage({super.key});

  @override
  State<AccountQrScannerPage> createState() => _AccountQrScannerPageState();
}

class _AccountQrScannerPageState extends State<AccountQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _hasScanned = true;
    await _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _ScannerOverlay())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan QR code',
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Align the code inside the frame.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  'The camera scans the code automatically when it is fully visible.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.width * 0.68;
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.48);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, frameRect.top),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        frameRect.bottom,
        size.width,
        size.height - frameRect.bottom,
      ),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, frameRect.top, frameRect.left, frameRect.height),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        frameRect.right,
        frameRect.top,
        size.width - frameRect.right,
        frameRect.height,
      ),
      overlayPaint,
    );

    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(26)),
      outlinePaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    final corners = [
      (frameRect.left, frameRect.top, true, true),
      (frameRect.right, frameRect.top, false, true),
      (frameRect.left, frameRect.bottom, true, false),
      (frameRect.right, frameRect.bottom, false, false),
    ];

    for (final (x, y, isLeft, isTop) in corners) {
      final horizontalStart = Offset(x, y);
      final horizontalEnd = Offset(
        x + (isLeft ? cornerLength : -cornerLength),
        y,
      );
      final verticalEnd = Offset(x, y + (isTop ? cornerLength : -cornerLength));
      canvas.drawLine(horizontalStart, horizontalEnd, cornerPaint);
      canvas.drawLine(horizontalStart, verticalEnd, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
