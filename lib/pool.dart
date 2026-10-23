import 'dart:async';

import 'package:flutter/material.dart';

import 'forms.dart';
import 'state.dart';
import 'widgets.dart';

String _countdown(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// Vẽ lại mỗi giây (đồng hồ đếm ngược) và tự đóng phiên hết hạn.
class PoolTicker extends StatefulWidget {
  const PoolTicker({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<PoolTicker> createState() => _PoolTickerState();
}

class _PoolTickerState extends State<PoolTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context.getInheritedWidgetOfExactType<Scope>()!.notifier!.closeExpired();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _header(String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Gom Đơn & Đấu Giá Ngược',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
    ]);

/// Thẻ thông tin một lô gom; phần nút bấm do từng vai trò tự truyền vào.
Widget _poolCard(AppState s, Pool p, {List<Widget> actions = const [], String? mineKg}) {
  final left = p.endsAt.difference(DateTime.now());
  final best = p.best;
  final bids = p.bids.toList()..sort((a, b) => b.price.compareTo(a.price));
  return AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('${p.fruit} · ${p.province}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        p.closed
            ? const AppChip('Đã kết thúc', color: Colors.grey)
            : AppChip('Còn ${_countdown(left.isNegative ? Duration.zero : left)}', color: Colors.orange),
      ]),
      Text('Lô gom ${vnd(p.totalKg)} kg từ ${p.members.length} vườn',
          style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
      if (mineKg != null) Text(mineKg, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      for (final m in p.members) Text('• ${m.owner}: ${vnd(m.kg)} kg', style: const TextStyle(fontSize: 13)),
      const Divider(height: 20),
      Text(best == null ? 'Chưa có ai đặt giá' : 'Giá cao nhất: ${vnd(best.price)} đ/kg',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kGreen)),
      for (var i = 0; i < bids.length && i < 3; i++)
        Text('${i + 1}. ${bids[i].company} – ${vnd(bids[i].price)} đ/kg', style: const TextStyle(fontSize: 13)),
      if (actions.isNotEmpty) ...[const SizedBox(height: 8), ...actions],
    ]),
  );
}

Widget _suggestionCard(AppState s, List<Lot> g, {required bool canGroup}) => AppCard(
      color: const Color(0xFFE8F5E9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${g.first.fruit} · ${g.first.province}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('${g.length} vườn gần nhau = ${vnd(g.fold(0, (a, l) => a + l.volumeKg))} kg',
            style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final l in g) Text('• ${l.owner}: ${vnd(l.volumeKg)} kg'),
        if (canGroup) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: () => s.createPool(g),
              icon: const Icon(Icons.groups),
              label: const Text('Gom thành 1 lô lớn & mở đấu giá 24h'),
            ),
          ),
        ],
      ]),
    );

// ───────────────────────── Nông dân ─────────────────────────
class FarmerPoolPage extends StatelessWidget {
  const FarmerPoolPage({super.key});

  @override
  Widget build(BuildContext context) => PoolTicker(builder: (context) {
        final s = Scope.of(context);
        final sugg = s.poolSuggestions().where((g) => g.any((l) => l.owner == s.userName)).toList();
        final mine = s.pools.where((p) => p.members.any((m) => m.owner == s.userName)).toList();
        return ListView(padding: kPad, children: [
          _header('Gom các vườn nhỏ gần nhau thành lô lớn để thương lái trả giá tốt hơn. '
              'Bạn nhận tiền theo đúng số kg của vườn mình.'),
          sectionTitle('Gợi ý gom cho vườn của bạn'),
          if (sugg.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Chưa có vườn nào gần bạn cùng loại để gom.'),
            ),
          for (final g in sugg) _suggestionCard(s, g, canGroup: true),
          sectionTitle('Lô gom có phần của tôi (${mine.length})'),
          if (mine.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Bạn chưa tham gia lô gom nào.')),
          for (final p in mine) _farmerPool(s, p),
        ]);
      });

  Widget _farmerPool(AppState s, Pool p) {
    final myKg = p.members.where((m) => m.owner == s.userName).fold(0, (a, m) => a + m.kg);
    final best = p.best;
    return _poolCard(
      s,
      p,
      mineKg: 'Phần của bạn: ${vnd(myKg)} kg'
          '${best == null ? '' : ' → tạm tính ${vnd(myKg * best.price)} đ'}',
      actions: [
        if (p.closed)
          AppChip(p.winner == null ? 'Không có người thắng' : 'Bán cho ${p.winner} – theo dõi cọc ở tab Ví',
              color: p.winner == null ? Colors.grey : kGreen)
        else
          const Text('Thương gia đang đặt giá. Hết 24h, bên trả cao nhất thắng.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// ───────────────────────── Thương gia ─────────────────────────
class MerchantAuctionPage extends StatelessWidget {
  const MerchantAuctionPage({super.key});

  Future<void> _bidDialog(BuildContext context, AppState s, Pool p) async {
    final c = TextEditingController(text: '${(p.best?.price ?? s.pricesFor(p.fruit).last) + 500}');
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Đặt giá – ${p.fruit} ${p.province}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.best == null
                ? 'Chưa ai đặt giá. ${vnd(p.totalKg)} kg.'
                : 'Giá cao nhất: ${p.best!.company} – ${vnd(p.best!.price)} đ/kg'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Giá của bạn (VNĐ/kg)', errorText: err, border: const OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: () {
                final e = s.placeBid(p, int.tryParse(c.text.trim()) ?? 0);
                if (e != null) {
                  setS(() => err = e);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Đặt giá'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PoolTicker(builder: (context) {
        final s = Scope.of(context);
        final open = s.pools.where((p) => !p.closed).toList();
        final won = s.pools.where((p) => p.closed && p.winner == s.userName).toList();
        return ListView(padding: kPad, children: [
          _header('Đặt giá thu mua các lô gom lớn. Trong 24h, bên trả giá cao nhất sẽ thắng deal '
              'và cần nạp cọc 20% ở tab Ví.'),
          sectionTitle('Phiên đang mở (${open.length})'),
          if (open.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Chưa có phiên nào đang mở.')),
          for (final p in open)
            _poolCard(s, p, actions: [
              if (p.best?.company == s.userName)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: AppChip('Bạn đang dẫn giá', color: kGreen),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen),
                  onPressed: () => _bidDialog(context, s, p),
                  child: Text(p.best?.company == s.userName ? 'Nâng giá' : 'Đặt giá thu mua'),
                ),
              ),
            ]),
          if (won.isNotEmpty) ...[
            sectionTitle('Lô tôi đã thắng (${won.length})'),
            for (final p in won)
              _poolCard(s, p, actions: [
                const AppChip('Bạn đã thắng – vào tab Ví để nạp cọc 20%', color: kGreen),
              ]),
          ],
        ]);
      });
}

// ───────────────────────── Admin ─────────────────────────
class AdminPoolPage extends StatelessWidget {
  const AdminPoolPage({super.key});

  @override
  Widget build(BuildContext context) => PoolTicker(builder: (context) {
        final s = Scope.of(context);
        final sugg = s.poolSuggestions();
        final open = s.pools.where((p) => !p.closed).toList();
        final done = s.pools.where((p) => p.closed).toList();
        return ListView(padding: kPad, children: [
          _header('Giám sát mọi lô gom trên sàn. Admin có thể gom hộ nông dân và kết thúc phiên sớm khi cần.'),
          Row(children: [
            Expanded(child: _stat('Đang mở', '${open.length}')),
            const SizedBox(width: 8),
            Expanded(child: _stat('Đã kết thúc', '${done.length}')),
            const SizedBox(width: 8),
            Expanded(child: _stat('Chờ gom', '${sugg.length}')),
          ]),
          if (sugg.isNotEmpty) ...[
            sectionTitle('Nhóm có thể gom hộ'),
            for (final g in sugg) _suggestionCard(s, g, canGroup: true),
          ],
          sectionTitle('Phiên đang mở (${open.length})'),
          for (final p in open)
            _poolCard(s, p, actions: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => s.closePool(p),
                  child: const Text('Kết thúc sớm (demo)'),
                ),
              ),
            ]),
          if (done.isNotEmpty) ...[
            sectionTitle('Đã kết thúc'),
            for (final p in done)
              _poolCard(s, p, actions: [
                AppChip(p.winner == null ? 'Không có người thắng' : 'Người thắng: ${p.winner}',
                    color: p.winner == null ? Colors.grey : kGreen),
              ]),
          ],
        ]);
      });

  Widget _stat(String label, String v) => AppCard(
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      );
}
