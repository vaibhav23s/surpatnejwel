import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/girvi_service.dart';
import '../services/girvi_receipt_pdf.dart';
import 'signature_pad_screen.dart';

/// Admin-only: the full Girvi bill creation form — customer KYC, item
/// valuation, loan terms, photos, and terms acceptance. On submit:
/// uploads the 3 photos, creates the Firestore record with a unique
/// receipt number, then offers the PDF receipt to share/print.
class AdminCreateGirviScreen extends StatefulWidget {
  const AdminCreateGirviScreen({super.key});

  @override
  State<AdminCreateGirviScreen> createState() => _AdminCreateGirviScreenState();
}

class _AdminCreateGirviScreenState extends State<AdminCreateGirviScreen> {
  final _girviService = GirviService();
  final _picker = ImagePicker();

  // Customer + KYC
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  String _kycType = 'Aadhaar Card';
  final _kycNumberCtrl = TextEditingController();
  File? _kycDocFile;
  File? _customerPhotoFile;
  Uint8List? _signaturePng;
  Uint8List? _adminSignaturePng;

  // Item
  final _itemNameCtrl = TextEditingController();
  final _itemCategoryCtrl = TextEditingController();
  String _purity = '22K';
  final _grossWeightCtrl = TextEditingController();
  final _netWeightCtrl = TextEditingController();
  File? _itemPhotoFile;

  // Loan
  final _principalCtrl = TextEditingController();
  String _paymentMode = 'Cash';
  double _interestRate = 2.5;
  DateTime _startDate = DateTime.now();
  final _tenureValueCtrl = TextEditingController(text: '30');
  String _tenureUnit = 'Days'; // Days | Months
  final _nomineeNameCtrl = TextEditingController();
  final _nomineePhoneCtrl = TextEditingController();
  bool _termsAccepted = false;

  bool _saving = false;

  static const _kycTypes = ['Aadhaar Card', 'PAN Card', 'Voter ID', 'Driving License'];
  static const _purityOptions = ['18K', '22K', '24K', 'Chandi Purity %'];
  static const _paymentModes = ['Cash', 'UPI', 'Bank Transfer'];
  static const _interestRates = [1.0, 2.5, 3.0, 5.0];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _kycNumberCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemCategoryCtrl.dispose();
    _grossWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    _principalCtrl.dispose();
    _tenureValueCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _nomineePhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ValueChanged<File> onPicked, {ImageSource source = ImageSource.camera}) async {
    final x = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (x != null) onPicked(File(x.path));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<String> _uploadPhoto(File file, String receiptNumber, String label) async {
    final ref = FirebaseStorage.instance.ref('girvi_photos/$receiptNumber/$label.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  bool _validate() {
    if (_nameCtrl.text.trim().isEmpty || _mobileCtrl.text.trim().isEmpty) {
      _snack('Customer naam aur mobile number zaroori hai');
      return false;
    }
    if (_kycNumberCtrl.text.trim().isEmpty) {
      _snack('KYC number daalo');
      return false;
    }
    if (_itemNameCtrl.text.trim().isEmpty) {
      _snack('Item ka naam daalo');
      return false;
    }
    final gross = double.tryParse(_grossWeightCtrl.text.trim());
    final net = double.tryParse(_netWeightCtrl.text.trim());
    if (gross == null || net == null || gross <= 0 || net <= 0) {
      _snack('Gross aur Net weight sahi daalo');
      return false;
    }
    final principal = double.tryParse(_principalCtrl.text.trim());
    if (principal == null || principal <= 0) {
      _snack('Principal amount sahi daalo');
      return false;
    }
    final tenureVal = int.tryParse(_tenureValueCtrl.text.trim());
    if (tenureVal == null || tenureVal <= 0) {
      _snack('Tenure sahi daalo');
      return false;
    }
    if (!_termsAccepted) {
      _snack('Terms & Conditions accept karna zaroori hai');
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final receiptNumber = _girviService.generateReceiptNumber();

      // Upload each photo on its own so one failure (e.g. Firebase
      // Storage not set up yet) doesn't silently lose the whole bill —
      // the admin is told which photos failed and decides what to do.
      final failedPhotos = <String>[];
      Future<String> tryUpload(File? file, String label, String niceName) async {
        if (file == null) return '';
        try {
          return await _uploadPhoto(file, receiptNumber, label);
        } catch (_) {
          failedPhotos.add(niceName);
          return '';
        }
      }

      final kycDocUrl = await tryUpload(_kycDocFile, 'kyc_doc', 'ID document');
      final customerPhotoUrl = await tryUpload(_customerPhotoFile, 'customer', 'Customer photo');
      final itemPhotoUrl = await tryUpload(_itemPhotoFile, 'item', 'Item photo');

      if (failedPhotos.isNotEmpty) {
        if (!mounted) return;
        final saveAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Photo upload nahi hui'),
            content: Text(
              '${failedPhotos.join(', ')} upload nahi ho paayi (Firebase Storage check karo).\n\n'
                  'Bina in photo ke bill bana dein?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi, ruko')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, bill banao')),
            ],
          ),
        );
        if (saveAnyway != true) return;
      }

      final tenureVal = int.parse(_tenureValueCtrl.text.trim());
      final tenureDays = _tenureUnit == 'Months' ? tenureVal * 30 : tenureVal;

      final loan = GirviLoan(
        id: '',
        receiptNumber: receiptNumber,
        customerName: _nameCtrl.text.trim(),
        customerMobile: _mobileCtrl.text.trim(),
        kycType: _kycType,
        kycNumber: _kycNumberCtrl.text.trim(),
        kycDocUrl: kycDocUrl,
        customerPhotoUrl: customerPhotoUrl,
        itemName: _itemNameCtrl.text.trim(),
        itemCategory: _itemCategoryCtrl.text.trim(),
        purity: _purity,
        grossWeightGrams: double.parse(_grossWeightCtrl.text.trim()),
        netWeightGrams: double.parse(_netWeightCtrl.text.trim()),
        itemPhotoUrl: itemPhotoUrl,
        principalAmount: double.parse(_principalCtrl.text.trim()),
        paymentMode: _paymentMode,
        interestRatePercent: _interestRate,
        startDate: _startDate,
        tenureDays: tenureDays,
        nomineeName: _nomineeNameCtrl.text.trim(),
        nomineePhone: _nomineePhoneCtrl.text.trim(),
        termsAccepted: _termsAccepted,
        status: 'active',
        createdAt: DateTime.now(),
        createdByAdminUid: '',
        customerSignatureB64: _signaturePng == null ? '' : base64Encode(_signaturePng!),
        adminSignatureB64: _adminSignaturePng == null ? '' : base64Encode(_adminSignaturePng!),
      );

      final id = await _girviService.createLoan(loan);
      final saved = (await _girviService.getLoan(id))!;

      if (!mounted) return;
      _snack('Bill ban gaya: $receiptNumber');
      await GirviReceiptPdf.shareOrPrint(saved);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Save nahi hua: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _kycHint() {
    switch (_kycType) {
      case 'Aadhaar Card':
        return 'Aadhaar Number (12 digit)';
      case 'PAN Card':
        return 'PAN Number (jaise ABCDE1234F)';
      case 'Voter ID':
        return 'Voter ID Number';
      case 'Driving License':
        return 'Driving License Number';
      default:
        return 'KYC Number';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Naya Girvi Bill', style: AppText.heading.copyWith(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('CUSTOMER & KYC'),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Customer Name', icon: Icons.person_outline, controller: _nameCtrl),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Mobile Number', icon: Icons.phone_outlined, controller: _mobileCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _DarkDropdown(label: 'KYC Type', value: _kycType, options: _kycTypes, onChanged: (v) => setState(() => _kycType = v)),
            const SizedBox(height: 12),
            GoldTextField(hint: _kycHint(), icon: Icons.badge_outlined, controller: _kycNumberCtrl),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _PhotoTile(label: 'Document Photo\n(Optional)', file: _kycDocFile, onTap: () => _pickImage((f) => setState(() => _kycDocFile = f)))),
                const SizedBox(width: 12),
                Expanded(child: _PhotoTile(label: 'Customer Photo\n(Optional)', file: _customerPhotoFile, onTap: () => _pickImage((f) => setState(() => _customerPhotoFile = f)))),
              ],
            ),

            const SizedBox(height: 28),
            const _SectionLabel('ITEM (VASTU) DETAILS'),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Item Name (e.g. Gold Ring)', icon: Icons.diamond_outlined, controller: _itemNameCtrl),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Item Category', icon: Icons.category_outlined, controller: _itemCategoryCtrl),
            const SizedBox(height: 12),
            _DarkDropdown(label: 'Purity / Carat', value: _purity, options: _purityOptions, onChanged: (v) => setState(() => _purity = v)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GoldTextField(hint: 'Gross Weight (g)', icon: Icons.scale_outlined, controller: _grossWeightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 12),
                Expanded(child: GoldTextField(hint: 'Net Weight (g)', icon: Icons.scale, controller: _netWeightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gross = poore item ka total weight (stone/moti sab milake).\nNet = sirf asli sona/chandi ka weight (Gross − stone weight). Loan isi Net weight pe hota hai.',
              style: AppText.bodyMuted.copyWith(fontSize: 10.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            _PhotoTile(label: 'Live Item Photo', file: _itemPhotoFile, onTap: () => _pickImage((f) => setState(() => _itemPhotoFile = f)), wide: true),

            const SizedBox(height: 28),
            const _SectionLabel('LOAN & INTEREST'),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Principal Amount (₹)', icon: Icons.currency_rupee, controller: _principalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _DarkDropdown(label: 'Payment Mode', value: _paymentMode, options: _paymentModes, onChanged: (v) => setState(() => _paymentMode = v)),
            const SizedBox(height: 12),
            _DarkDropdown(
              label: 'Interest Rate (per month)',
              value: '${_interestRate == _interestRate.roundToDouble() ? _interestRate.toInt() : _interestRate}%',
              options: _interestRates.map((r) => '${r == r.roundToDouble() ? r.toInt() : r}%').toList(),
              onChanged: (v) => setState(() => _interestRate = double.parse(v.replaceAll('%', ''))),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Text('Start Date: ${_startDate.day}/${_startDate.month}/${_startDate.year}', style: AppText.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GoldTextField(hint: 'Tenure', icon: Icons.timer_outlined, controller: _tenureValueCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: _DarkDropdown(label: 'Unit', value: _tenureUnit, options: const ['Days', 'Months'], onChanged: (v) => setState(() => _tenureUnit = v)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Nominee / Uthaan Name (optional)', icon: Icons.person_add_alt_outlined, controller: _nomineeNameCtrl),
            const SizedBox(height: 12),
            GoldTextField(hint: 'Nominee Phone (optional)', icon: Icons.call_outlined, controller: _nomineePhoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _termsAccepted = !_termsAccepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: _termsAccepted, activeColor: AppColors.gold, onChanged: (v) => setState(() => _termsAccepted = v ?? false)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Customer ko interest delay aur item auction ke shop terms samjha diye gaye hain.',
                        style: AppText.bodyMuted.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('SIGNATURES'),
            const SizedBox(height: 10),
            _SignatureTile(
              png: _signaturePng,
              onTap: () async {
                final result = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(builder: (_) => const SignaturePadScreen()),
                );
                if (result != null) setState(() => _signaturePng = result);
              },
            ),
            const SizedBox(height: 12),
            _SignatureTile(
              png: _adminSignaturePng,
              title: 'Authorised Signature (Optional)',
              hint: 'Khali chhodoge to bill par "Surpatne Jewellers" chhapega',
              onTap: () async {
                final result = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) => const SignaturePadScreen(
                      title: 'Authorised Signature',
                      instruction: 'Dukaan ki taraf se is safed box me signature karein.',
                    ),
                  ),
                );
                if (result != null) setState(() => _adminSignaturePng = result);
              },
            ),
            const SizedBox(height: 24),
            GoldButton(label: _saving ? 'Saving...' : 'Bill Banao & Receipt Nikalo', onTap: _saving ? null : _submit),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.goldLabel.copyWith(fontSize: 12, letterSpacing: 1.2));
  }
}

class _DarkDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _DarkDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.charcoal,
      style: AppText.body.copyWith(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.bodyMuted.copyWith(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold, width: 1.4)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4))),
      ),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  final bool wide;
  const _PhotoTile({required this.label, required this.file, required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: wide ? 160 : 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Image.file(file!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: AppColors.gold.withOpacity(0.7), size: 26),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Tap to have the customer sign on the phone screen with a finger —
/// replaces the printed-paper signature when there is no printer.
class _SignatureTile extends StatelessWidget {
  final Uint8List? png;
  final VoidCallback onTap;
  final String title;
  final String hint;
  const _SignatureTile({
    required this.png,
    required this.onTap,
    this.title = 'Customer Signature (Recommended)',
    this.hint = 'Tap karke customer se sign karwayein',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: png != null ? Colors.white : AppColors.charcoal,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: png != null
            ? Stack(
          children: [
            Positioned.fill(child: Image.memory(png!, fit: BoxFit.contain)),
            const Positioned(
              right: 8,
              top: 6,
              child: Icon(Icons.edit_outlined, size: 16, color: Colors.black45),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_outlined, color: AppColors.gold.withOpacity(0.7), size: 26),
            const SizedBox(height: 6),
            Text(
              '$title\n$hint',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}