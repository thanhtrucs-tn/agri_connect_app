import 'package:flutter/material.dart';

import 'forms.dart';
import 'market.dart';
import 'state.dart';
import 'widgets.dart';

const _pad = kPad;

Widget repBadge(BuildContext context, String name, Rep? r) {
  final low = r != null && r.stars < 4.0;
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => showRepSheet(context, name, r),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(r == null ? Icons.fiber_new : Icons.star,
            size: 16, color: r == null ? Colors.blue : Colors.amber.shade700),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
              r == null ? 'Mới tham gia' : '${r.stars.toStringAsFixed(1)} · ${r.deals} giao dịch',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
        ),
        if (low) ...[
          const SizedBox(width: 8),
          const AppChip('Cần thận trọng', color: Colors.red),
        ],
        const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
      ]),
    ),
  );
}

void showRepSheet(BuildContext context, String name, Rep? r) {
  Widget bar(String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('${(v * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: v,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: v >= 0.85 ? kGreen : (v >= 0.7 ? Colors.orange : Colors.red),
            backgroundColor: Colors.grey.shade200,
          ),
        ]),
      );
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (r == null)
          const Text('Chưa có lịch sử giao dịch. Hãy thận trọng: ưu tiên đặt cọc rõ ràng '
              'và xem vườn/giao nhận trực tiếp.')
        else ...[
          Row(children: [
            Icon(Icons.star, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            Text('${r.stars.toStringAsFixed(1)} / 5',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('  ·  ${r.deals} giao dịch'),
          ]),
          const SizedBox(height: 8),
          bar('Đúng hẹn', r.onTime),
          bar('Giữ đúng giá / sản lượng đã báo', r.keptPrice),
          bar('Cọc đúng hạn', r.deposit),
        ],
      ]),
    ),
  );
}

Future<void> _rateDialog(BuildContext context, AppState s, Lot lot) async {
  var stars = 5;
  final who = lot.selected!.company;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('Đánh giá $who'),
        content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              onPressed: () => setS(() => stars = i),
              icon: Icon(i <= stars ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700, size: 32),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              s.rate(who, stars, lot: lot);
              Navigator.pop(ctx);
            },
            child: const Text('Gửi đánh giá'),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── 1. Nông dân ─────────────────────────
class FarmerPage extends StatelessWidget {
  const FarmerPage({super.key, required this.onPost});
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final mine = s.myLots;
    if (mine.isEmpty) {
      return ListView(padding: _pad, children: [
        Text('Xin chào, ${s.userName} 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const Center(child: Text('Bạn chưa có lô nông sản nào trên sàn')),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: onPost,
          icon: const Icon(Icons.add),
          label: const Text('Đăng Lô Nông Sản Mới'),
        ),
      ]);
    }
    final lot = mine.first;
    final offers = s.sortedFor(lot);
    final daysLeft = lot.harvestDate.difference(DateTime(2026, 10, AppState.today)).inDays;
    final step = lot.selected == null ? 2 : 4; // số bước đã hoàn thành

    return ListView(padding: _pad, children: [
      Text('Xin chào, ${s.userName} 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Bạn đang có ${mine.length} lô nông sản trên sàn',
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: onPost,
        icon: const Icon(Icons.add),
        label: const Text('Đăng Lô Nông Sản Mới'),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.spa, color: kGreen)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lot.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Tổng ${lot.volumeKg ~/ 1000} tấn'),
            ]),
          ),
          AppChip(lot.status),
        ]),
      ),
      Row(children: [
        Expanded(
          child: _stat(Icons.local_offer, 'Chào giá mới', '${offers.length} báo giá',
              'Cạnh tranh cao', Colors.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _stat(Icons.event, 'Lịch xem vườn', fmtDate(s.visitDate), s.visitBuyer, Colors.blue),
        ),
      ]),
      _stat(Icons.payments, 'Tạm tính thu về', '~${vnd(lot.proceeds / 1000000)} triệu VNĐ',
          'Theo giá ${vnd(lot.selected?.price ?? lot.bestPrice)} VNĐ/kg', kGreen),
      const SizedBox(height: 4),
      const Text('So sánh giá thương gia',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Row(children: [
        const Text('Xếp theo: '),
        ChoiceChip(
            label: const Text('Giá cao'),
            selected: !s.sortByRep,
            onSelected: (_) => s.setSortByRep(false)),
        const SizedBox(width: 8),
        ChoiceChip(
            label: const Text('Uy tín'),
            selected: s.sortByRep,
            onSelected: (_) => s.setSortByRep(true)),
      ]),
      const SizedBox(height: 8),
      for (var i = 0; i < offers.length; i++) _offerTile(context, s, lot, offers[i], identical(offers[i], lot.sortedOffers.first)),
      const SizedBox(height: 8),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chi tiết lô hàng',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          kv('Sản lượng', '${vnd(lot.volumeKg)} kg'),
          kv('Tiêu chuẩn', lot.standard),
          kv('Địa chỉ vườn', lot.address),
          kv('Dự kiến thu hoạch',
              '${fmtDate(lot.harvestDate)} (còn $daysLeft ngày)'),
        ]),
      ),
      if (mine.length > 1)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Các lô khác của tôi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final o in mine.skip(1))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${o.name} · ${vnd(o.volumeKg)} kg')),
                  AppChip(o.status, color: o.pooled ? Colors.blue : kGreen),
                ]),
              ),
          ]),
        ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tiến trình giao dịch',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _step(1, 'Đăng lô & được duyệt', '20/10/2026', step >= 1),
          _step(2, 'Thương gia gửi báo giá', '${offers.length} báo giá', step >= 2),
          _step(3, 'Nông dân chọn thương gia', lot.selected?.company ?? 'Chưa chọn', step >= 3),
          _step(4, 'Thương gia xem vườn', 'Hẹn ${fmtDate(s.visitDate)}', step >= 4),
          _step(5, 'Nhận cọc & chốt mua thu hoạch', lot.rated ? 'Đã hoàn tất' : 'Chờ hoàn tất',
              lot.rated, last: true),
          if (lot.selected != null && !lot.rated)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                onPressed: () => _rateDialog(context, s, lot),
                icon: const Icon(Icons.star),
                label: const Text('Hoàn tất giao dịch & đánh giá'),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _stat(IconData icon, String title, String value, String sub, Color c) => AppCard(
        child: Row(children: [
          Icon(icon, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(sub, style: TextStyle(color: c, fontSize: 12)),
            ]),
          ),
        ]),
      );

  Widget _offerTile(BuildContext context, AppState s, Lot lot, Offer o, bool best) {
    final chosen = identical(lot.selected, o);
    return AppCard(
      color: chosen ? const Color(0xFFE8F5E9) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(o.company,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (best) const AppChip('Cao nhất', color: Colors.orange),
        ]),
        repBadge(context, o.company, s.repOf(o.company)),
        const SizedBox(height: 4),
        Text('${vnd(o.price)} VNĐ/kg',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kGreen)),
        Text('${o.deposit} · ${o.transport}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: chosen
              ? const Chip(label: Text('ĐÃ CHỌN BÁN BÊN NÀY'), avatar: Icon(Icons.check_circle))
              : OutlinedButton(
                  onPressed: () => s.selectOffer(lot, o),
                  child: const Text('CHỌN BÁN BÊN NÀY'),
                ),
        ),
      ]),
    );
  }

  Widget _step(int n, String title, String sub, bool done, {bool last = false}) =>
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: done ? kGreen : Colors.grey.shade300,
              child: done
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : Text('$n', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            if (!last) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      );
}

// ───────────────────────── 2. Thương gia ─────────────────────────
class MerchantPage extends StatefulWidget {
  const MerchantPage({super.key});
  @override
  State<MerchantPage> createState() => _MerchantPageState();
}

class _MerchantPageState extends State<MerchantPage> {
  String query = '';
  String? fruit; // null = tất cả

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final lots = s.lots
        .where((l) => !l.pooled)
        .where((l) => fruit == null || l.fruit == fruit)
        .where((l) => l.name.toLowerCase().contains(query.toLowerCase()) ||
            l.address.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView(padding: _pad, children: [
      const Text('Sàn Nông Sản Đang Tìm Đơn Vị Thu Mua Tận Vườn',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Dành cho thương lái, đại lý, công ty xuất khẩu. Xem lô sắp thu hoạch và gửi báo giá trực tiếp cho nông dân.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Lọc Tìm theo tên, địa chỉ…',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: fruit == null,
              onSelected: (_) => setState(() => fruit = null),
            ),
          ),
          for (final f in {for (final l in s.lots) l.fruit})
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f),
                selected: fruit == f,
                onSelected: (_) => setState(() => fruit = f),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      if (lots.isEmpty) const Center(child: Text('Không có lô phù hợp')),
      for (final l in lots)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              AppChip(l.standard),
            ]),
            const SizedBox(height: 8),
            kv('Loại trái cây', l.fruit),
            if (l.aiNote != null) kv('AI chấm ảnh', l.aiNote!),
            kv('Chủ vườn', l.owner),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const SizedBox(width: 110, child: Text('Uy tín', style: TextStyle(color: Colors.black54))),
                repBadge(context, l.owner, s.repOf(l.owner)),
              ]),
            ),
            kv('Sản lượng', '${vnd(l.volumeKg)} kg'),
            kv('Địa chỉ', l.address),
            kv('Thu hoạch', fmtDate(l.harvestDate)),
            kv('Giá hiện cao nhất', '${vnd(l.bestPrice)} VNĐ/kg'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                onPressed: () => showOfferForm(context, l),
                child: const Text('Gửi Báo Giá'),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ───────────────────────── 4. Admin ─────────────────────────
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.onCreate});
  final VoidCallback onCreate;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final onCreate = widget.onCreate;
    return ListView(padding: _pad, children: [
      const Text('Bảng Điều Khiển Admin Tổng Thể',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Giám sát lô hàng của nông dân và theo dõi thương gia đặt giá.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _adminStat('Lô trên sàn', '${s.lots.length}', Icons.inventory_2)),
        const SizedBox(width: 8),
        Expanded(child: _adminStat('Chờ duyệt', '${s.lots.where((l) => l.status == "Chờ duyệt").length}', Icons.pending_actions)),
        const SizedBox(width: 8),
        Expanded(child: _adminStat('Tranh chấp', '${s.deals.where((d) => d.status == DealStatus.disputed).length}', Icons.report)),
      ]),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: kGreen),
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Tạo Lô Hàng Hỗ Trợ Nông Dân'),
      ),
      const SizedBox(height: 16),
      const PriceChartCard(),
      const Text('Quản lý lô hàng',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      for (final l in List.of(s.lots))
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              AppChip(l.status, color: l.status == 'Chờ duyệt' ? Colors.orange : kGreen),
            ]),
            const SizedBox(height: 6),
            kv('Chủ vườn', l.owner),
            kv('Khối lượng', '${vnd(l.volumeKg)} kg'),
            kv('Địa chỉ', l.address),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (l.status == 'Chờ duyệt')
                TextButton.icon(
                  onPressed: () => s.setStatus(l, 'Đang đấu giá'),
                  icon: const Icon(Icons.check),
                  label: const Text('Duyệt'),
                ),
              TextButton.icon(
                onPressed: () => s.removeLot(l),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

Widget _adminStat(String label, String v, IconData icon) => AppCard(
      child: Column(children: [
        Icon(icon, color: const Color(0xFF6A1B9A)),
        Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
      ]),
    );
