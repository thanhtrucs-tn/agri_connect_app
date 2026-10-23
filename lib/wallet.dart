import 'package:flutter/material.dart';

import 'forms.dart';
import 'state.dart';
import 'widgets.dart';

Widget _title(String t, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
    ]);

Widget _btn(String label, IconData icon, VoidCallback onTap) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: kGreen),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );

/// Thẻ giao dịch; nút bấm do từng vai trò tự truyền vào.
Widget _dealCard(Deal d, {List<Widget> actions = const []}) {
  final color = switch (d.status) {
    DealStatus.released => kGreen,
    DealStatus.disputed => Colors.red,
    DealStatus.refunded => Colors.grey,
    _ => Colors.orange,
  };
  return AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(d.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        AppChip(d.status.label, color: color),
      ]),
      const SizedBox(height: 6),
      kv('Bên mua', d.buyer),
      kv('Nông dân', d.shares.keys.join(', ')),
      kv('Khối lượng', '${vnd(d.kg)} kg × ${vnd(d.price)} đ/kg'),
      kv('Tổng giá trị', '${vnd(d.total)} đ'),
      kv('Cọc 20%', '${vnd(d.deposit)} đ'),
      if (actions.isNotEmpty) ...[const SizedBox(height: 8), ...actions],
    ]),
  );
}

bool _holding(Deal d) =>
    d.status == DealStatus.held || d.status == DealStatus.delivered || d.status == DealStatus.disputed;

// ───────────────────────── Nông dân: nhận tiền ─────────────────────────
class FarmerWalletPage extends StatelessWidget {
  const FarmerWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mine = s.deals.where((d) => d.shares.containsKey(s.userName)).toList();
    final pending = mine
        .where(_holding)
        .fold(0, (a, d) => a + (d.deposit * d.shares[s.userName]! / d.kg).round());

    return ListView(padding: kPad, children: [
      _title('Ví Nhận Cọc',
          'Khi bên mua nạp cọc 20%, tiền được app giữ hộ. Bạn giao hàng, bên mua xác nhận đúng chất lượng thì cọc tự chuyển cho bạn.'),
      Row(children: [
        Expanded(child: _money('Đã nhận', s.balance(s.userName), kGreen)),
        const SizedBox(width: 12),
        Expanded(child: _money('Cọc đang giữ cho bạn', pending, Colors.orange)),
      ]),
      sectionTitle('Giao dịch bán của tôi (${mine.length})'),
      if (mine.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Chưa có giao dịch. Hãy chọn bên mua hoặc tham gia lô gom.'),
        ),
      for (final d in mine)
        _dealCard(d, actions: [
          if (d.status == DealStatus.awaitingDeposit)
            Text('Đang chờ ${d.buyer} nạp cọc.', style: const TextStyle(color: Colors.black54)),
          if (d.status == DealStatus.held)
            _btn('Đã giao hàng', Icons.local_shipping, () => s.markDelivered(d)),
          if (d.status == DealStatus.delivered)
            Text('Chờ ${d.buyer} xác nhận hàng.', style: const TextStyle(color: Colors.black54)),
          if (d.status == DealStatus.disputed)
            const Text('Bên mua báo không đạt. Admin đang xử lý.', style: TextStyle(color: Colors.red)),
        ]),
    ]);
  }

  Widget _money(String label, int v, Color c) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          Text('${vnd(v)} đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
        ]),
      );
}

// ───────────────────────── Thương gia: nạp cọc ─────────────────────────
class MerchantWalletPage extends StatelessWidget {
  const MerchantWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mine = s.deals.where((d) => d.buyer == s.userName).toList();
    final held = mine.where(_holding).fold(0, (a, d) => a + d.deposit);

    return ListView(padding: kPad, children: [
      _title('Ví Tạm Giữ Chống "Bẻ Cọc"',
          'Nạp trước 20% tiền cọc vào ví trung gian của app. Khi hàng giao đúng chất lượng, bạn bấm Xác nhận thì cọc mới chuyển cho nông dân.'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Số dư ví', style: TextStyle(color: Colors.black54)),
          Text('${vnd(s.balance(s.userName))} đ',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kGreen)),
          Text('Đang giữ làm cọc: ${vnd(held)} đ', style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final a in [5000000, 20000000, 50000000])
              OutlinedButton(onPressed: () => s.topUp(a), child: Text('+ ${vnd(a ~/ 1000000)} triệu')),
          ]),
          const SizedBox(height: 4),
          const Text('Nạp tiền ở đây là mô phỏng, chưa kết nối cổng thanh toán thật.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
      sectionTitle('Giao dịch mua của tôi (${mine.length})'),
      if (mine.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Chưa có giao dịch. Được nông dân chọn hoặc thắng đấu giá gom đơn để tạo giao dịch.'),
        ),
      for (final d in mine)
        _dealCard(d, actions: [
          if (d.status == DealStatus.awaitingDeposit)
            _btn('Nạp cọc ${vnd(d.deposit)} đ vào ví tạm giữ', Icons.lock, () {
              final e = s.payDeposit(d);
              if (e != null) snack(context, e);
            }),
          if (d.status == DealStatus.held)
            const Text('Cọc đã được giữ. Chờ nông dân giao hàng.', style: TextStyle(color: Colors.black54)),
          if (d.status == DealStatus.delivered) ...[
            _btn('Xác nhận đúng chất lượng – chuyển cọc cho nông dân', Icons.verified, () => s.confirmDelivery(d)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => s.dispute(d),
                icon: const Icon(Icons.report, color: Colors.red),
                label: const Text('Báo không đạt', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
          if (d.status == DealStatus.disputed)
            const Text('Đã báo không đạt. Chờ admin xử lý.', style: TextStyle(color: Colors.red)),
        ]),
    ]);
  }
}

// ───────────────────────── Admin: giám sát escrow ─────────────────────────
class AdminEscrowPage extends StatelessWidget {
  const AdminEscrowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final disputes = s.deals.where((d) => d.status == DealStatus.disputed).toList();
    final others = s.deals.where((d) => d.status != DealStatus.disputed).toList();
    final held = s.deals.where(_holding).fold(0, (a, d) => a + d.deposit);

    return ListView(padding: kPad, children: [
      _title('Giám Sát Ví Tạm Giữ',
          'Theo dõi mọi giao dịch trên sàn. Admin không giữ tiền, chỉ xử lý khi hai bên tranh chấp.'),
      Row(children: [
        Expanded(
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cọc đang giữ', style: TextStyle(color: Colors.black54, fontSize: 12)),
              Text('${vnd(held)} đ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tranh chấp', style: TextStyle(color: Colors.black54, fontSize: 12)),
              Text('${disputes.length}',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: disputes.isEmpty ? null : Colors.red)),
            ]),
          ),
        ),
      ]),
      sectionTitle('Cần xử lý (${disputes.length})'),
      if (disputes.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Không có tranh chấp.')),
      for (final d in disputes)
        _dealCard(d, actions: [
          _btn('Chuyển cọc cho nông dân', Icons.agriculture, () => s.resolve(d, toFarmer: true)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => s.resolve(d, toFarmer: false),
              icon: const Icon(Icons.undo),
              label: const Text('Hoàn cọc cho bên mua'),
            ),
          ),
        ]),
      sectionTitle('Tất cả giao dịch khác (${others.length})'),
      for (final d in others) _dealCard(d),
    ]);
  }
}
