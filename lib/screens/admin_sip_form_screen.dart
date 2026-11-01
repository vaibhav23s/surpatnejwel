import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/sip_service.dart';
import '../services/sip_pdf.dart';
import 'signature_pad_screen.dart';

class AdminSipFormScreen extends StatefulWidget {
  const AdminSipFormScreen({super.key});

  @override
  State<AdminSipFormScreen> createState() => _AdminSipFormScreenState();
}

class _AdminSipFormScreenState extends State<AdminSipFormScreen> {
  final _service = SipService();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _aadhaar = TextEditingController();

  String _metal = 'gold';
  int? _amount;
  Uint8List? _photo, _custSig, _shopSig;
  bool _agreed = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final f = await _picker.pickImage(source: src, maxWidth: 600, imageQuality: 60);
      if (f == null) return;
      final b = await f.readAsBytes();
      setState(() => _photo = b);
    } catch (e) {
      _snack('Photo nahi mili: $e');
    }
  }

  Future<void> _sign(String title, bool customer) async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => SignaturePadScreen(title: title)),
    );
    if (bytes == null) return;
    setState(() => customer ? _custSig = bytes : _shopSig = bytes);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    final aadhaar = _aadhaar.text.replaceAll(' ', '');
    String? err;
    if (name.length < 2) {
      err = 'Customer ka naam likho';
    } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      err = 'Mobile number 10 digit ka sahi daalo';
    } else if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      err = 'Aadhaar 12 digit ka daalo';
    } else if (_amount == null) {
      err = 'SIP amount chuno';
    } else if (_photo == null) {
      err = 'Customer ki photo lagao';
    } else if (_custSig == null) {
      err = 'Customer ke signature karwao';
    } else if (_shopSig == null) {
      err = 'Shop ke signature karo';
    } else if (!_agreed) {
      err = 'Terms padh ke tick karo';
    }
    if (err != null) {
      _snack(err);
      return;
    }

    setState(() => _saving = true);
    try {
      final r = await _service.createPlan(
        name: name,
        mobile: mobile,
        aadhaar: aadhaar,
        metal: _metal,
        amount: _amount!,
        photo: _photo!,
        custSig: _custSig!,
        shopSig: _shopSig!,
      );
      final pdf = await buildSipFormPdf(SipFormData(
        code: r.code,
        name: name,
        mobile: mobile,
        aadhaar: '${aadhaar.substring(0, 4)} ${aadhaar.substring(4, 8)} ${aadhaar.substring(8)}',
        metal: _metal,
        amount: _amount!,
        startMonth: r.startMonth,
        createdAt: DateTime.now(),
        photo: _photo!,
        custSig: _custSig!,
        shopSig: _shopSig!,
      ));
      if (!mounted) return;
      await _showDone(r.code, pdf);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('SIP save nahi hui: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDone(String code, Uint8List pdf) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoal,
        title: Text('SIP ban gayi', style: AppText.heading.copyWith(fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer ka SIP CODE', style: AppText.bodyMuted.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              SelectableText(
                code,
                style: AppText.heading.copyWith(fontSize: 34, color: AppColors.gold, letterSpacing: 6),
              ),
              const SizedBox(height: 8),
              Text('Ye code customer ko bata do. PDF neeche se dekho ya share karo.',
                  textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 12)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.black),
                  onPressed: () => Printing.layoutPdf(onLayout: (_) async => pdf, name: 'SIP-$code.pdf'),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF Dekho / Print / Save'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.gold)),
                  onPressed: () => Printing.sharePdf(bytes: pdf, filename: 'SIP-$code.pdf'),
                  icon: const Icon(Icons.share, color: AppColors.gold),
                  label: const Text('WhatsApp / Share', style: TextStyle(color: AppColors.gold)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(t, style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
  );

  Widget _sigTile(String title, Uint8List? bytes, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 84,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withOpacity(0.6)),
        ),
        child: bytes == null
            ? Center(child: Text('$title - yahan tap karke sign karein', style: const TextStyle(color: Colors.black45, fontSize: 12.5)))
            : Padding(padding: const EdgeInsets.all(4), child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amounts = _metal == 'gold' ? kGoldSipAmounts : kSilverSipAmounts;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Naya SIP Form', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Customer ka naam'),
            GoldTextField(hint: 'Poora naam', icon: Icons.person_outline, controller: _name),
            _label('Mobile number'),
            GoldTextField(hint: '10 digit mobile', icon: Icons.phone_outlined, controller: _mobile, keyboardType: TextInputType.number),
            _label('Aadhaar number'),
            GoldTextField(hint: '12 digit Aadhaar', icon: Icons.badge_outlined, controller: _aadhaar, keyboardType: TextInputType.number),
            _label('Metal (SIP ka paisa isme jayega)'),
            Row(
              children: [
                for (final m in const ['gold', 'silver']) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(width: double.infinity, child: Text(m == 'gold' ? 'Gold' : 'Silver', textAlign: TextAlign.center)),
                      selected: _metal == m,
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.charcoal,
                      labelStyle: TextStyle(color: _metal == m ? AppColors.black : AppColors.cream, fontWeight: FontWeight.w700),
                      onSelected: (_) => setState(() {
                        _metal = m;
                        _amount = null;
                      }),
                    ),
                  ),
                  if (m == 'gold') const SizedBox(width: 10),
                ],
              ],
            ),
            _label('Monthly SIP amount'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: amounts
                  .map((a) => ChoiceChip(
                label: Text('₹$a'),
                selected: _amount == a,
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.charcoal,
                labelStyle: TextStyle(color: _amount == a ? AppColors.black : AppColors.cream, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _amount = a),
              ))
                  .toList(),
            ),
            _label('Customer ki photo'),
            Row(
              children: [
                Container(
                  width: 84,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: _photo == null
                      ? Icon(Icons.person, color: AppColors.gold.withOpacity(0.5), size: 36)
                      : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_photo!, fit: BoxFit.cover)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.gold.withOpacity(0.6)), minimumSize: const Size.fromHeight(44)),
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, color: AppColors.gold, size: 18),
                        label: const Text('Camera', style: TextStyle(color: AppColors.gold)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.gold.withOpacity(0.6)), minimumSize: const Size.fromHeight(44)),
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, color: AppColors.gold, size: 18),
                        label: const Text('Gallery', style: TextStyle(color: AppColors.gold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _label('Sharten (Terms)'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  kSipTerms.length,
                      (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${i + 1}. ${kSipTerms[i]}', style: AppText.bodyMuted.copyWith(fontSize: 11.5, height: 1.45)),
                  ),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.gold,
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: Text('Customer ne saari sharten padh li hain', style: AppText.body.copyWith(fontSize: 12.5)),
            ),
            _label('Customer ke signature'),
            _sigTile('Customer', _custSig, () => _sign('Customer Signature', true)),
            _label('Shop ke signature'),
            _sigTile('Shop', _shopSig, () => _sign('Shop Signature', false)),
            const SizedBox(height: 26),
            GoldButton(label: _saving ? 'Save ho raha hai...' : 'SIP Banao + PDF', onTap: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}