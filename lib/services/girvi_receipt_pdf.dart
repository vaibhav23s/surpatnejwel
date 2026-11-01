import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/currency_format.dart';
import 'girvi_service.dart';

// ---------------------------------------------------------------
// Shop details printed on every receipt — edit these in one place.
// ---------------------------------------------------------------
const String kShopNameHi = 'सूरपाटणे ज्वेलर्स';
const String kShopNameEn = 'Surpatne Jewellers';
const String kShopTagline = 'Gold & Silver Jewellery';
const String kShopPhone = '+91 93564 46941';
const String kShopAddress = ''; // e.g. 'Main Road, Nandura' — hidden while empty

/// Terms printed on the receipt. Read these once and edit to match the
/// shop's real policy — this is a legal-ish document.
const List<String> kGirviTerms = [
  'Interest har mahine ke hisaab se lagega, jis dar par receipt me likha hai.',
  'Tenure khatam hone ke baad, ya interest jama na karne par, item renew ya auction ho sakta hai — shop ki policy ke hisaab se.',
  'Is receipt ko sambhal ke rakhein. Item chudwane ke waqt ye receipt dikhana zaroori hai.',
];

class _Fonts {
  final bool ok;
  final pw.ThemeData? theme;
  final pw.Font? hiBold;
  const _Fonts({required this.ok, this.theme, this.hiBold});
}

/// Builds + shares/prints/saves the Girvi receipt PDF. Uses the
/// `pdf` + `printing` packages — generated on the phone, no server.
///
/// Fonts: Noto Sans (+ Devanagari) are downloaded once through
/// `printing`'s PdfGoogleFonts and cached, so the ₹ sign and the Hindi
/// shop name print correctly. If the phone is offline the very first
/// time, it falls back to plain fonts ("Rs." and the English name).
class GirviReceiptPdf {
  static const _dark = PdfColor.fromInt(0xFF161616);
  static const _gold = PdfColor.fromInt(0xFFD4AF37);
  static const _goldDark = PdfColor.fromInt(0xFFA8791E);
  static const _cream = PdfColor.fromInt(0xFFF7F1E6);
  static const _creamLine = PdfColor.fromInt(0xFFE3D5B0);

  static Future<void> shareOrPrint(GirviLoan loan) async {
    final bytes = await _buildBytes(loan);
    await Printing.sharePdf(bytes: bytes, filename: '${loan.receiptNumber}.pdf');
  }

  static Future<_Fonts> _loadFonts() async {
    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      final deva = await PdfGoogleFonts.notoSansDevanagariRegular();
      final devaBold = await PdfGoogleFonts.notoSansDevanagariBold();
      return _Fonts(
        ok: true,
        theme: pw.ThemeData.withFont(base: base, bold: bold, fontFallback: [deva]),
        hiBold: devaBold,
      );
    } catch (_) {
      return const _Fonts(ok: false);
    }
  }

  static Future<pw.ImageProvider?> _tryImage(String url) async {
    if (url.isEmpty) return null;
    try {
      return await networkImage(url);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _buildBytes(GirviLoan loan) async {
    final fonts = await _loadFonts();
    final itemImg = await _tryImage(loan.itemPhotoUrl);
    final custImg = await _tryImage(loan.customerPhotoUrl);
    final signImg = _signatureImage(loan.customerSignatureB64);
    final adminSignImg = _signatureImage(loan.adminSignatureB64);
    final rs = fonts.ok ? '₹' : 'Rs. ';

    final doc = pw.Document(title: loan.receiptNumber, author: kShopNameEn);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: fonts.theme,
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Center(
            child: pw.Text(
              'Computer-generated receipt  •  $kShopNameEn  •  $kShopPhone',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ),
        build: (ctx) => [
          // ---------- Header band ----------
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: pw.BoxDecoration(color: _dark, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      fonts.ok ? kShopNameHi : kShopNameEn,
                      style: pw.TextStyle(font: fonts.hiBold, fontSize: 22, color: _gold, fontWeight: pw.FontWeight.bold),
                    ),
                    if (fonts.ok)
                      pw.Text(kShopNameEn, style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.white, letterSpacing: 1.6)),
                    pw.SizedBox(height: 2),
                    pw.Text(kShopTagline, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey400)),
                    if (kShopAddress.isNotEmpty)
                      pw.Text(kShopAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey400)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('GIRVI RECEIPT', style: const pw.TextStyle(fontSize: 10, color: _gold, letterSpacing: 2)),
                    pw.SizedBox(height: 4),
                    pw.Text(loan.receiptNumber,
                        style: pw.TextStyle(fontSize: 15, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Date: ${_fmt(loan.startDate)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ],
                ),
              ],
            ),
          ),

          // ---------- Loan amount strip ----------
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gold, width: 1.2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LOAN AMOUNT',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, letterSpacing: 1.2)),
                      pw.SizedBox(height: 2),
                      pw.Text('$rs${formatInr(loan.principalAmount)}',
                          style: pw.TextStyle(fontSize: 24, color: _goldDark, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Rupees ${_rupeesInWords(loan.principalAmount.round())} Only',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Container(width: 1, height: 46, color: _creamLine),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INTEREST',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, letterSpacing: 1.2)),
                      pw.SizedBox(height: 2),
                      pw.Text('${_pct(loan.interestRatePercent)} / month',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('LAST DATE',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, letterSpacing: 1.2)),
                      pw.Text(_fmt(loan.expectedEndDate), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Customer ----------
          _card(
            title: 'Customer Details',
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(children: [
                    _kv('Name', loan.customerName, bold: true),
                    _kv('Mobile', loan.customerMobile),
                    _kv('ID Proof', loan.kycType),
                    _kv('ID Number', _maskKyc(loan.kycNumber)),
                  ]),
                ),
                if (custImg != null) ...[
                  pw.SizedBox(width: 12),
                  _photo(custImg, 'Customer'),
                ],
              ],
            ),
          ),

          // ---------- Item ----------
          _card(
            title: 'Item (Vastu) Details',
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(children: [
                    _kv('Item', loan.itemName, bold: true),
                    if (loan.itemCategory.isNotEmpty) _kv('Category', loan.itemCategory),
                    _kv('Purity', loan.purity),
                    _kv('Gross Weight', '${loan.grossWeightGrams} g'),
                    _kv('Net Weight', '${loan.netWeightGrams} g', bold: true),
                  ]),
                ),
                if (itemImg != null) ...[
                  pw.SizedBox(width: 12),
                  _photo(itemImg, 'Item'),
                ],
              ],
            ),
          ),

          // ---------- Loan terms ----------
          _card(
            title: 'Loan Details',
            child: pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(children: [
                        _kv('Principal', '$rs${formatInr(loan.principalAmount)}'),
                        _kv('Payment Mode', loan.paymentMode),
                        _kv('Interest Rate', '${_pct(loan.interestRatePercent)} per month'),
                      ]),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(children: [
                        _kv('Start Date', _fmt(loan.startDate)),
                        _kv('Tenure', '${loan.tenureDays} days'),
                        _kv('Last Date', _fmt(loan.expectedEndDate)),
                      ]),
                    ),
                  ],
                ),
                if (loan.nomineeName.isNotEmpty)
                  _kv('Nominee (Uthaan)',
                      loan.nomineePhone.isEmpty ? loan.nomineeName : '${loan.nomineeName}  •  ${loan.nomineePhone}'),
              ],
            ),
          ),

          // ---------- Terms ----------
          _card(
            title: 'Terms & Conditions',
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kGirviTerms.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(width: 14, child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Expanded(child: pw.Text(kGirviTerms[i], style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ---------- Signatures ----------
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _signLine(
                'Customer Signature',
                image: signImg,
                note: signImg != null ? 'Signed on ${_fmt(loan.createdAt)}' : null,
              ),
              _signLine('Authorised Signature', image: adminSignImg, stampText: kShopNameEn),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------
  // Small building blocks
  // ---------------------------------------------------------------

  static pw.Widget _card({required String title, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _cream,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _creamLine, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _goldDark, letterSpacing: 1.2)),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  static pw.Widget _kv(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 92, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _photo(pw.ImageProvider img, String caption) {
    return pw.Column(
      children: [
        pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Container(width: 84, height: 84, child: pw.Image(img, fit: pw.BoxFit.cover)),
        ),
        pw.SizedBox(height: 3),
        pw.Text(caption, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _signLine(String label, {pw.ImageProvider? image, String? note, String? stampText}) {
    pw.Widget space;
    if (image != null) {
      space = pw.Image(image, fit: pw.BoxFit.contain);
    } else if (stampText != null) {
      // No signature drawn: print the shop name in the signature space.
      space = pw.Center(
        child: pw.Text(
          stampText,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _goldDark),
        ),
      );
    } else {
      space = pw.SizedBox();
    }
    return pw.Column(
      children: [
        pw.SizedBox(width: 150, height: 50, child: space),
        pw.Container(width: 150, height: 0.8, color: PdfColors.grey600),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        if (note != null)
          pw.Text(note, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
      ],
    );
  }

  /// The customer's on-screen signature (base64 PNG saved on the loan).
  static pw.ImageProvider? _signatureImage(String b64) {
    if (b64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  /// Only the last 4 characters of the ID number are printed on the
  /// receipt, because the customer carries / forwards this PDF.
  static String _maskKyc(String n) {
    final clean = n.replaceAll(' ', '');
    if (clean.isEmpty) return '—';
    if (clean.length <= 4) return clean;
    return 'X' * (clean.length - 4) + clean.substring(clean.length - 4);
  }

  static String _pct(double v) => v == v.roundToDouble() ? '${v.toInt()}%' : '$v%';

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// 200 -> "Two Hundred", 125000 -> "One Lakh Twenty Five Thousand".
  static String _rupeesInWords(int n) {
    if (n <= 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
    ];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String two(int x) => x < 20 ? ones[x] : '${tens[x ~/ 10]}${x % 10 == 0 ? '' : ' ${ones[x % 10]}'}';
    String three(int x) => x >= 100
        ? '${ones[x ~/ 100]} Hundred${x % 100 == 0 ? '' : ' ${two(x % 100)}'}'
        : two(x);

    final parts = <String>[];
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;

    if (crore > 0) parts.add('${three(crore)} Crore');
    if (lakh > 0) parts.add('${two(lakh)} Lakh');
    if (thousand > 0) parts.add('${two(thousand)} Thousand');
    if (n > 0) parts.add(three(n));
    return parts.join(' ');
  }
}