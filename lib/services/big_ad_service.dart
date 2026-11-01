import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class BigAdConfig {
  final bool enabled;
  final String? imageB64;
  const BigAdConfig({required this.enabled, this.imageB64});

  bool get hasImage => imageB64 != null && imageB64!.isNotEmpty;

  Uint8List? get bytes {
    if (!hasImage) return null;
    try {
      return base64Decode(imageB64!);
    } catch (_) {
      return null;
    }
  }

  factory BigAdConfig.fromData(Map<String, dynamic>? d) {
    return BigAdConfig(
      enabled: (d?['enabled'] as bool?) ?? false,
      imageB64: d?['image'] as String?,
    );
  }
}

class BigAdException implements Exception {
  final String message;
  BigAdException(this.message);
  @override
  String toString() => message;
}

/// Write access sirf admin ko (firestore.rules me match /shop/bigAd).
class BigAdService {
  // base64 lagbhag 33% badh jata hai; Firestore doc ki limit 1 MiB hai.
  static const int maxImageBytes = 650 * 1024;

  final DocumentReference<Map<String, dynamic>> _doc =
  FirebaseFirestore.instance.collection('shop').doc('bigAd');

  Stream<BigAdConfig> watch() =>
      _doc.snapshots().map((s) => BigAdConfig.fromData(s.data()));

  Future<BigAdConfig> get() async {
    final snap = await _doc.get();
    return BigAdConfig.fromData(snap.data());
  }

  Future<void> setEnabled(bool enabled) async {
    await _doc.set({'enabled': enabled}, SetOptions(merge: true));
  }

  Future<void> setImage(Uint8List bytes) async {
    if (bytes.length > maxImageBytes) {
      throw BigAdException('Image bahut badi hai. Chhoti image chuno (650 KB se kam).');
    }
    await _doc.set({
      'image': base64Encode(bytes),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Image hatate hi ad band bhi ho jata hai.
  Future<void> removeImage() async {
    await _doc.set({
      'image': FieldValue.delete(),
      'enabled': false,
    }, SetOptions(merge: true));
  }
}