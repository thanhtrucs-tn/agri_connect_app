import 'package:flutter/material.dart';

import 'forms.dart';
import 'state.dart';
import 'widgets.dart';

Color _statusColor(String s) => switch (s) {
      'Đã hẹn' => kGreen,
      'Đã khảo sát' => Colors.blue,
      'Từ chối' => Colors.red,
      _ => Colors.orange,
    };

Widget _title(String t, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
    ]);

Widget _card(Survey sv, {required String who, List<Widget> actions = const []}) => AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.fact_check, color: kGreen)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(who, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${sv.lot.name} · ${sv.lot.province}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
              Text('Ngày hẹn: ${fmtDate(sv.date)}', style: const TextStyle(fontSize: 13)),
            ]),
          ),
          AppChip(sv.status, color: _statusColor(sv.status)),
        ]),
        if (sv.result.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
            child: Text('Kết quả: ${sv.result}', style: const TextStyle(fontSize: 13)),
          ),
        ],
        if (actions.isNotEmpty) ...[const SizedBox(height: 8), ...actions],
      ]),
    );

// ───────────────────────── Nông dân: lịch xem vườn của tôi ─────────────────────────
class FarmerSurveyPage extends StatelessWidget {
  const FarmerSurveyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mine = s.surveys.where((x) => x.lot.owner == s.userName).toList();
    return ListView(padding: kPad, children: [
      _title('Lịch Xem Vườn',
          'Thương gia xin đến vườn kiểm tra độ chín, kích cỡ và chuyển khoản đặt cọc. Bạn xác nhận hoặc từ chối lịch.'),
      if (mine.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Chưa có ai xin xem vườn.')),
      for (final sv in mine)
        _card(sv, who: sv.buyer, actions: [
          if (sv.status == 'Chờ xác nhận')
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => s.answerSurvey(sv, false), child: const Text('Từ chối')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  onPressed: () => s.answerSurvey(sv, true),
                  child: const Text('Xác nhận lịch'),
                ),
              ),
            ]),
        ]),
    ]);
  }
}

// ───────────────────────── Thương gia: lịch khảo sát của tôi ─────────────────────────
class MerchantSurveyPage extends StatelessWidget {
  const MerchantSurveyPage({super.key});

  Future<void> _book(BuildContext context, AppState s) async {
    final lots = s.lots.where((l) => !l.pooled).toList();
    var lot = lots.first;
    var date = DateTime.now().add(const Duration(days: 2));
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Đặt lịch xem vườn'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Lot>(
              initialValue: lot,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chọn lô', border: OutlineInputBorder()),
              items: [
                for (final l in lots)
                  DropdownMenuItem(value: l, child: Text('${l.name} – ${l.owner}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setS(() => lot = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (d != null) setS(() => date = d);
              },
              icon: const Icon(Icons.event),
              label: Text('Ngày: ${fmtDate(date)}'),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err!, style: const TextStyle(color: Colors.red)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: () {
                final e = s.requestSurvey(lot, date);
                if (e != null) {
                  setS(() => err = e);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _result(BuildContext context, AppState s, Survey sv) async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết quả khảo sát'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Độ chín, kích cỡ, tỉ lệ hư… (vd: chín 85%, size vừa)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              if (c.text.trim().isEmpty) return;
              s.completeSurvey(sv, c.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mine = s.surveys.where((x) => x.buyer == s.userName).toList();
    return ListView(padding: kPad, children: [
      _title('Lịch Khảo Sát Vườn',
          'Quy trình khảo sát chất lượng thực địa: đặt lịch, nông dân xác nhận, bạn đến vườn kiểm tra rồi ghi kết quả.'),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: kGreen),
        onPressed: () => _book(context, s),
        icon: const Icon(Icons.add),
        label: const Text('Đặt lịch xem vườn'),
      ),
      const SizedBox(height: 12),
      if (mine.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Bạn chưa đặt lịch nào.')),
      for (final sv in mine)
        _card(sv, who: sv.lot.owner, actions: [
          if (sv.status == 'Đã hẹn')
            _full('Ghi kết quả sau khi khảo sát', Icons.edit_note, () => _result(context, s, sv)),
          if (sv.status == 'Chờ xác nhận')
            Text('Chờ ${sv.lot.owner} xác nhận.', style: const TextStyle(color: Colors.black54)),
        ]),
    ]);
  }

  Widget _full(String label, IconData icon, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
}

// ───────────────────────── Admin: giám sát tất cả ─────────────────────────
class AdminSurveyPage extends StatelessWidget {
  const AdminSurveyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    int n(String st) => s.surveys.where((x) => x.status == st).length;
    return ListView(padding: kPad, children: [
      _title('Giám Sát Khảo Sát', 'Theo dõi toàn bộ lịch xem vườn giữa thương gia và nông dân. Admin chỉ xem.'),
      Row(children: [
        for (final st in ['Chờ xác nhận', 'Đã hẹn', 'Đã khảo sát'])
          Expanded(
            child: AppCard(
              child: Column(children: [
                Text('${n(st)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(st, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
              ]),
            ),
          ),
      ]),
      for (final sv in s.surveys) _card(sv, who: '${sv.buyer} → ${sv.lot.owner}'),
    ]);
  }
}
