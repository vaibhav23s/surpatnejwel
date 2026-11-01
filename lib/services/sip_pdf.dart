import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'sip_service.dart';

class SipFormData {
  final String code, name, mobile, aadhaar, metal;
  final int amount;
  final DateTime startMonth, createdAt;
  final Uint8List photo, custSig, shopSig;
  const SipFormData({
    required this.code,
    required this.name,
    required this.mobile,
    required this.aadhaar,
    required this.metal,
    required this.amount,
    required this.startMonth,
    required this.createdAt,
    required this.photo,
    required this.custSig,
    required this.shopSig,
  });
}

const List<String> kSipTerms = [
  'SIP CODE sabse zaroori hai. Is code ke bina SIP ka koi claim nahi hoga. Code kho jaye ya gum ho jaye to SIP cancel maani jayegi. Code kisi ko na batayein.',
  'SIP 12 mahine ki hai. Har mahine ki 1 tarikh kist ki due date hai. 1 se 3 tarikh tak kist bina extra charge ke bhar sakte hain.',
  '4 tarikh ya uske baad (ya agle mahine) kist bharne par late fee lagegi: Rs.10, aur har agle mahine Rs.10 badhti jayegi (Rs.10, Rs.20, Rs.30 ...). Late fee shop ka charge hai, isse gold/silver nahi milta.',
  'Har kist ka gold/silver payment wale din ke bhav (rate) se jama hoga.',
  '12 mahine poore hote hi SIP code apne aap cancel ho jayega. Customer shop aakar apna item collect karega. Item usi din ke bhav par milega aur majuri (making charges) par 50% chhoot milegi.',
  'SIP beech me band karni ho to customer ko khud shop aana hoga. SIP sirf shop/admin ki taraf se band hogi, aur band hone ke mahine tak ki saari kist aur charges bharne honge.',
  '6 mahine poore hone ke baad SIP nikalna chahe to item nahi milega, sirf jama ki hui raashi vapas milegi, usme se Rs.200 kaat kar. Late fee vapas nahi hogi.',
  'Customer ne upar likhi saari sharten padh aur samajh kar signature kiye hain. Aadhaar, mobile aur photo sirf SIP record ke liye hain.',
];

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

Future<Uint8List> buildSipFormPdf(SipFormData d) async {
  final doc = pw.Document();

  pw.Widget kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 105, child: pw.Text(k, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10))),
      pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
    ]),
  );

  pw.Widget sig(String label, Uint8List bytes) => pw.Column(children: [
    pw.Container(
      width: 200,
      height: 80,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
      child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
    ),
    pw.SizedBox(height: 4),
    pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
  ]);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Center(
          child: pw.Text('SURPATNE JEWELLERS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(child: pw.Text('Gold / Silver Monthly SIP Form', style: const pw.TextStyle(fontSize: 12))),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            pw.Text('SIP CODE (sabse zaroori - kisi ko na batayein)', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(d.code, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, letterSpacing: 6)),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(children: [
              kv('Naam', d.name),
              kv('Mobile', d.mobile),
              kv('Aadhaar', d.aadhaar),
              kv('Metal', d.metal == 'gold' ? 'Gold' : 'Silver'),
              kv('Monthly SIP', 'Rs. ${d.amount}'),
              kv('Pehli kist', '1 ${sipMonthLabel(d.startMonth)}'),
              kv('Avadhi', '$kSipMonths mahine'),
              kv('Form date', _date(d.createdAt)),
            ]),
          ),
          pw.SizedBox(width: 12),
          pw.Container(
            width: 95,
            height: 115,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
            child: pw.Image(pw.MemoryImage(d.photo), fit: pw.BoxFit.cover),
          ),
        ]),
        pw.SizedBox(height: 14),
        pw.Text('Sharten (Terms)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...List.generate(
          kSipTerms.length,
              (i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text('${i + 1}. ${kSipTerms[i]}', style: const pw.TextStyle(fontSize: 9.5)),
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [sig('Customer ke signature', d.custSig), sig('Shop ke signature', d.shopSig)],
        ),
      ],
    ),
  );
  return doc.save();
}