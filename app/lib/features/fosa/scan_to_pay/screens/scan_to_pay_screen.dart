import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/qr_parser.dart';

class ScanToPayScreen extends StatefulWidget {
  const ScanToPayScreen({super.key});

  @override
  State<ScanToPayScreen> createState() => _ScanToPayScreenState();
}

class _ScanToPayScreenState extends State<ScanToPayScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    _scanned = true;
    _controller.stop();

    final result = QrParser.parse(raw);

    if (!result.isValid) {
      _scanned = false;
      _controller.start();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code not recognised. Please scan an M-Pesa QR.')),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to Pay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay with cutout
          _ScanOverlay(),
          Positioned(
            bottom: 48,
            left: 0, right: 0,
            child: Text(
              'Point your camera at an M-Pesa QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutoutSize = 260.0;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 40;
    final rect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Dim everything outside the cutout
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, cutoutPath),
      paint,
    );

    // Corner brackets
    final bracketPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const bLen = 24.0;
    final corners = [
      [Offset(left, top + bLen), Offset(left, top), Offset(left + bLen, top)],
      [Offset(left + cutoutSize - bLen, top), Offset(left + cutoutSize, top), Offset(left + cutoutSize, top + bLen)],
      [Offset(left, top + cutoutSize - bLen), Offset(left, top + cutoutSize), Offset(left + bLen, top + cutoutSize)],
      [Offset(left + cutoutSize - bLen, top + cutoutSize), Offset(left + cutoutSize, top + cutoutSize), Offset(left + cutoutSize, top + cutoutSize - bLen)],
    ];

    for (final pts in corners) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy)..lineTo(pts[1].dx, pts[1].dy)..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
