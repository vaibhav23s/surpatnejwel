import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdBannerItem {
  final String? id;
  final String value;
  const AdBannerItem({this.id, required this.value});
  bool get isUploaded => id != null;
}

class AdBannerConfig {
  final bool enabled;
  final List<AdBannerItem> items;

  const AdBannerConfig({required this.enabled, this.items = const []});

  List<String> get imageUrls => items.map((e) => e.value).toList();

  factory AdBannerConfig.fromData(Map<String, dynamic>? data, List<AdBannerItem> uploaded) {
    final links = (data?['imageUrls'] as List?)
        ?.map((e) => AdBannerItem(value: e.toString()))
        .toList() ??
        <AdBannerItem>[];
    return AdBannerConfig(
      enabled: (data?['enabled'] as bool?) ?? false,
      items: [...links, ...uploaded],
    );
  }
}

class AdBannerException implements Exception {
  final String message;
  AdBannerException(this.message);
  @override
  String toString() => message;
}

Uint8List? adImageBytes(String value) {
  if (!value.startsWith('data:')) return null;
  final comma = value.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(value.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class AdBannerService {
  static const int maxUploaded = 5;
  static const int maxImageBytes = 600 * 1024;

  final DocumentReference<Map<String, dynamic>> _doc =
  FirebaseFirestore.instance.collection('shop').doc('adBanner');

  CollectionReference<Map<String, dynamic>> get _imagesRef => _doc.collection('images');

  List<AdBannerItem> _uploadedFrom(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = <AdBannerItem>[];
    for (final d in snap.docs) {
      final b64 = d.data()['data'] as String?;
      if (b64 == null || b64.isEmpty) continue;
      out.add(AdBannerItem(id: d.id, value: 'data:image;base64,$b64'));
    }
    return out;
  }

  Stream<AdBannerConfig> watchConfig() {
    late StreamController<AdBannerConfig> controller;
    StreamSubscription? docSub;
    StreamSubscription? imgSub;
    Map<String, dynamic>? docData;
    List<AdBannerItem> uploaded = const [];

    void emit() {
      if (!controller.isClosed) controller.add(AdBannerConfig.fromData(docData, uploaded));
    }

    controller = StreamController<AdBannerConfig>(
      onListen: () {
        docSub = _doc.snapshots().listen((snap) {
          docData = snap.data();
          emit();
        }, onError: controller.addError);
        imgSub = _imagesRef.orderBy('order').snapshots().listen((snap) {
          uploaded = _uploadedFrom(snap);
          emit();
        }, onError: controller.addError);
      },
      onCancel: () {
        docSub?.cancel();
        imgSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<AdBannerConfig> getConfig() async {
    final snap = await _doc.get();
    final imgs = await _imagesRef.orderBy('order').get();
    return AdBannerConfig.fromData(snap.data(), _uploadedFrom(imgs));
  }

  Future<void> setEnabled(bool enabled) async {
    await _doc.set({'enabled': enabled}, SetOptions(merge: true));
  }

  Future<void> addUploadedImage(Uint8List bytes) async {
    if (bytes.length > maxImageBytes) {
      throw AdBannerException('Image bahut badi hai. Chhoti image chuno (600 KB se kam).');
    }
    final existing = await _imagesRef.get();
    if (existing.docs.length >= maxUploaded) {
      throw AdBannerException('Maximum $maxUploaded images hi laga sakte ho. Pehle koi purani hatao.');
    }
    await _imagesRef.add({
      'data': base64Encode(bytes),
      'order': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeUploadedImage(String id) async {
    await _imagesRef.doc(id).delete();
  }

  Future<void> removeImageUrl(String url) async {
    await _doc.set({
      'imageUrls': FieldValue.arrayRemove([url]),
    }, SetOptions(merge: true));
  }
}