import 'package:flutter/material.dart';

import 'forms.dart';
import 'state.dart';
import 'widgets.dart';

const _icons = {
  'Bán': Icons.sell,
  'Mua': Icons.shopping_cart,
  'Xuất hàng': Icons.local_shipping,
  'Nhận hàng': Icons.inventory,
  'Cọc': Icons.lock,
  'Gom đơn': Icons.groups,
  'Ghi chú': Icons.edit_note,
};

String _dt(DateTime d) =>
    '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String? type;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final admin = s.role == Role.admin;
    final types = kTypesByRole[s.role]!;
    final mine = s.ledger.where((e) => s.role == Role.admin || e.user == s.userName).toList();
    final shown = mine.where((e) => type == null || e.type == type).toList();
    int count(String t) => mine.where((e) => e.type == t).length;
    int sum(String t) => mine.where((e) => e.type == t).fold(0, (a, e) => a + (e.amount ?? 0));

    return ListView(padding: kPad, children: [
      Text(admin ? 'Nhật Ký Hệ Thống' : (s.role == Role.farmer ? 'Nhật Ký Bán Hàng' : 'Nhật Ký Thu Mua'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(
          admin
              ? 'Toàn bộ hoạt động trên sàn của mọi người dùng. Admin chỉ xem.'
              : (s.role == Role.farmer
                  ? 'Tự ghi lại các lần bán, xuất hàng, nhận cọc. Bạn có thể thêm ghi chú riêng và sửa bất cứ lúc nào.'
                  : 'Tự ghi lại các lần mua, đặt giá, nạp cọc, nhận hàng. Bạn có thể thêm ghi chú riêng và sửa bất cứ lúc nào.'),
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Row(children: [
        if (s.role == Role.farmer) ...[
          Expanded(child: _total('Tổng bán', '${vnd(sum('Bán'))} đ', kGreen)),
          const SizedBox(width: 12),
          Expanded(child: _total('Lần xuất hàng', '${count('Xuất hàng')}', Colors.orange)),
        ] else if (s.role == Role.merchant) ...[
          Expanded(child: _total('Tổng mua', '${vnd(sum('Mua'))} đ', Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _total('Lần nhận hàng', '${count('Nhận hàng')}', Colors.orange)),
        ] else ...[
          Expanded(child: _total('Số mục', '${mine.length}', const Color(0xFF6A1B9A))),
          const SizedBox(width: 12),
          Expanded(child: _total('Tổng giá trị bán', '${vnd(sum('Bán'))} đ', kGreen)),
        ],
      ]),
      if (!admin)
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: () => showEntryDialog(context, s),
          icon: const Icon(Icons.add),
          label: const Text('Thêm ghi chú / mục mới'),
        ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
                label: const Text('Tất cả'), selected: type == null, onSelected: (_) => setState(() => type = null)),
          ),
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                  label: Text(t), selected: type == t, onSelected: (_) => setState(() => type = t)),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Chưa có mục nào'))),
      for (final e in shown)
        AppCard(
          child: InkWell(
            onTap: admin ? null : () => showEntryDialog(context, s, entry: e),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(_icons[e.type] ?? Icons.note, color: kGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    AppChip(e.type),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_dt(e.date), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (s.role == Role.admin)
                    Text('Của: ${e.user}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (e.amount != null)
                    Text('${vnd(e.amount!)} đ',
                        style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                  if (e.note.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('📝 ${e.note}', style: const TextStyle(fontSize: 13)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _total(String label, String v, Color c) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
        ]),
      );
}

/// Thêm mục mới, hoặc sửa / xóa mục đã có (kể cả mục tự ghi) để thêm ghi chú.
Future<void> showEntryDialog(BuildContext context, AppState s, {LedgerEntry? entry}) {
  final types = kTypesByRole[s.role]!;
  var type = types.contains(entry?.type) ? entry!.type : 'Ghi chú';
  final title = TextEditingController(text: entry?.title ?? '');
  final amount = TextEditingController(text: entry?.amount?.toString() ?? '');
  final note = TextEditingController(text: entry?.note ?? '');
  String? err;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(entry == null ? 'Thêm vào nhật ký' : 'Sửa mục nhật ký'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Loại', border: OutlineInputBorder()),
              items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setS(() => type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: InputDecoration(
                  labelText: 'Nội dung', errorText: err, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền (đ, không bắt buộc)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ghi chú của bạn', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          if (entry != null)
            TextButton(
              onPressed: () {
                s.deleteEntry(entry);
                Navigator.pop(ctx);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              if (title.text.trim().isEmpty) {
                setS(() => err = 'Vui lòng nhập nội dung');
                return;
              }
              final amt = int.tryParse(amount.text.trim());
              if (entry == null) {
                s.log(s.userName, type, title.text.trim(), amount: amt, note: note.text.trim());
              } else {
                entry
                  ..type = type
                  ..title = title.text.trim()
                  ..amount = amt
                  ..note = note.text.trim();
                s.touchLedger();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}
