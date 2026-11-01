import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Full-screen signature pad. The customer signs with a finger inside
/// the white box; "Done" returns the signature as PNG bytes
/// (Navigator.pop(Uint8List)). Back/Cancel returns nothing.
class SignaturePadScreen extends StatefulWidget {
  final String title;
  final String instruction;
  const SignaturePadScreen({
    super.key,
    this.title = 'Customer Signature',
    this.instruction = 'Customer se is safed box me ungli se signature karwayein.',
  });

  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  final List<List<Offset>> _strokes = [];
  Size _boxSize = Size.zero;
  bool _busy = false;

  Offset _clamp(Offset p) => Offset(
    p.dx.clamp(0.0, _boxSize.width),
    p.dy.clamp(0.0, _boxSize.height),
  );

  Future<void> _done() async {
    if (_strokes.isEmpty || _boxSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle customer se signature karwayein')),
      );
      return;
    }
    setState(() => _busy = true);
    final bytes = await _renderPng();
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  /// Draws the strokes (black on white) into a fixed 600x240 PNG so the
  /// saved signature stays small (a few KB) whatever the phone's size.
  Future<Uint8List> _renderPng() async {
    const outW = 600.0;
    const outH = 240.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outW, outH));
    canvas.drawRect(const Rect.fromLTWH(0, 0, outW, outH), Paint()..color = Colors.white);

    final sx = outW / _boxSize.width;
    final sy = outH / _boxSize.height;
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      final pts = stroke.map((p) => Offset(p.dx * sx, p.dy * sy)).toList();
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, 2, Paint()..color = Colors.black);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final image = await recorder.endRecording().toImage(outW.toInt(), outH.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text(widget.title, style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.instruction,
              style: AppText.bodyMuted.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _boxSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) => setState(() => _strokes.add([_clamp(d.localPosition)])),
                      onPanUpdate: (d) => setState(() => _strokes.last.add(_clamp(d.localPosition))),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _SignaturePainter(_strokes),
                        child: _strokes.isEmpty
                            ? const Center(
                          child: Text('Yahan sign karein', style: TextStyle(color: Colors.black26, fontSize: 16)),
                        )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _busy ? null : () => setState(_strokes.clear),
                    child: const Text('Clear', style: TextStyle(color: AppColors.gold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(label: _busy ? 'Saving...' : 'Done', onTap: _busy ? null : _done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.4, Paint()..color = Colors.black);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}