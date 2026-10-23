import 'package:flutter/material.dart';

import 'forms.dart';

/// Padding cho danh sách; chừa chỗ cho nút "Hỏi AI" ở góc dưới.
const kPad = EdgeInsets.fromLTRB(16, 16, 16, 88);

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
        color: color ?? Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.green.shade100),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class AppChip extends StatelessWidget {
  const AppChip(this.text, {super.key, this.color = kGreen});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    );

Widget pctBar(String label, double pct, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('${pct.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (pct / 100).clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: color ?? kGreen,
          backgroundColor: Colors.grey.shade200,
        ),
      ]),
    );

void snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
