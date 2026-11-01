import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/big_ad_service.dart';

bool _bigAdShownThisLaunch = false;

/// Home khulte hi call hota hai. Ad ON ho aur image ho to ek baar dikhata hai
/// (har baar app kholne par ek baar).
Future<void> showBigAdIfNeeded(BuildContext context) async {
  if (_bigAdShownThisLaunch) return;
  _bigAdShownThisLaunch = true;

  try {
    final cfg = await BigAdService().get();
    if (!cfg.enabled) return;
    final bytes = cfg.bytes;
    if (bytes == null) return;
    if (!context.mounted) return;
    await showBigAdDialog(context, bytes);
  } catch (_) {
    // Net na ho ya koi dikkat ho to chupchap ad skip.
  }
}

/// Ad popup. Admin ke preview me bhi yahi use hota hai.
Future<void> showBigAdDialog(BuildContext context, Uint8List bytes) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // --- band karne ka X ---
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.black87, size: 22),
              ),
            ),
            // --- ad image ---
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const Text('Ad load nahi hua'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}