import 'dart:math';

import 'package:flutter/material.dart';

import 'state.dart';
import 'widgets.dart';

const _upColor = Color(0xFF2E7D32);
const _downColor = Color(0xFFD32F2F);

String _short(num v) {
  final k = v / 1000;
  return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
}

String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

DateTime _dateAt(int i, int n) =>
    DateTime(2026, 10, AppState.today).subtract(Duration(days: n - 1 - i));

double _pct(List<int> v) => (v.last - v.first) / v.first * 100;

String _pctText(double p) => '${p >= 0 ? '▲ +' : '▼ '}${p.toStringAsFixed(1)}%';

// ───────────────────────── Biểu đồ đường ─────────────────────────
class PriceChart extends StatefulWidget {
  const PriceChart({super.key, required this.values, required this.color});
  final List<int> values;
  final Color color;
  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  int? hover;

  void _set(Offset p, double w) {
    final n = widget.values.length;
    final x = ((p.dx - _ChartPainter.left) / (w - _ChartPainter.left - _ChartPainter.right)).clamp(0.0, 1.0);
    setState(() => hover = (x * (n - 1)).round());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => MouseRegion(
          onHover: (e) => _set(e.localPosition, box.maxWidth),
          onExit: (_) => setState(() => hover = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _set(d.localPosition, box.maxWidth),
            onHorizontalDragUpdate: (d) => _set(d.localPosition, box.maxWidth),
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _ChartPainter(widget.values, widget.color, hover),
            ),
          ),
        ),
      );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.v, this.color, this.hover);
  final List<int> v;
  final Color color;
  final int? hover;

  static const left = 44.0, right = 10.0, top = 12.0, bottom = 24.0;

  TextPainter _tp(String t, {Color c = Colors.black54, double size = 11, bool bold = false}) => TextPainter(
        text: TextSpan(
            text: t,
            style: TextStyle(color: c, fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    final minV = v.reduce(min), maxV = v.reduce(max);
    final pad = max(1, maxV - minV) * 0.15;
    final lo = minV - pad, hi = maxV + pad;
    final w = size.width - left - right, h = size.height - top - bottom;
    Offset pt(int i) => Offset(left + w * i / (n - 1), top + h * (1 - (v[i] - lo) / (hi - lo)));

    // Lưới ngang + nhãn giá (trục Y)
    final grid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final y = top + h * g / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final t = _tp(_short(hi - (hi - lo) * g / 4));
      t.paint(canvas, Offset(left - 6 - t.width, y - t.height / 2));
    }
    // Nhãn ngày (trục X)
    for (var k = 0; k < 5; k++) {
      final i = ((n - 1) * k / 4).round();
      final t = _tp(_dm(_dateAt(i, n)));
      final dx = (pt(i).dx - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(dx, size.height - bottom + 6));
    }

    // Đường giá + vùng tô
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(pt(n - 1).dx, top + h)
      ..lineTo(pt(0).dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    if (n <= 10) {
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(pt(i), 3.5, Paint()..color = color);
      }
    }
    canvas.drawCircle(pt(n - 1), 5, Paint()..color = color);

    // Tooltip khi rê chuột / chạm
    final hv = hover?.clamp(0, n - 1);
    if (hv != null) {
      final p = pt(hv);
      canvas.drawLine(
          Offset(p.dx, top), Offset(p.dx, top + h), Paint()..color = color.withValues(alpha: 0.5));
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      final t1 = _tp(_dm(_dateAt(hv, n)), c: Colors.white70, size: 11);
      final t2 = _tp('${vnd(v[hv])} đ/kg', c: Colors.white, size: 13, bold: true);
      final bw = max(t1.width, t2.width) + 16, bh = t1.height + t2.height + 12;
      final bx = (p.dx - bw / 2).clamp(left, size.width - right - bw);
      final by = p.dy - bh - 10 >= 0 ? p.dy - bh - 10 : p.dy + 12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(8)),
        Paint()..color = const Color(0xFF263238),
      );
      t1.paint(canvas, Offset(bx + 8, by + 5));
      t2.paint(canvas, Offset(bx + 8, by + 7 + t1.height));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.v != v || old.color != color || old.hover != hover;
}

class _Spark extends CustomPainter {
  _Spark(this.v, this.color);
  final List<int> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = v.reduce(min), hi = v.reduce(max);
    final span = max(1, hi - lo);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final p = Offset(size.width * i / (v.length - 1), size.height * (1 - (v[i] - lo) / span));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => old.v != v || old.color != color;
}

// ───────────────────────── Thẻ biểu đồ (dùng lại ở nhiều nơi) ─────────────────────────
class PriceChartCard extends StatefulWidget {
  const PriceChartCard({super.key});
  @override
  State<PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends State<PriceChartCard> {
  int days = 30;

  /// Nhận xét theo vai trò: cùng một biến động giá nhưng hàm ý khác nhau.
  String? _tip(Role? role, double p) {
    final trend = p > 3 ? 1 : (p < -3 ? -1 : 0);
    return switch ((role, trend)) {
      (Role.farmer, 1) => 'Giá đang tăng ${p.toStringAsFixed(1)}%: bạn có thể đặt giá khởi điểm cao hơn khi đăng lô.',
      (Role.farmer, -1) => 'Giá đang giảm: cân nhắc chốt bán sớm với bên trả giá tốt.',
      (Role.farmer, _) => 'Giá khá ổn định trong giai đoạn này.',
      (Role.merchant, 1) => 'Giá đang tăng ${p.toStringAsFixed(1)}%: chi phí thu mua tăng, nên chốt sớm các lô cần.',
      (Role.merchant, -1) => 'Giá đang giảm: cơ hội thu mua với giá tốt.',
      (Role.merchant, _) => 'Giá khá ổn định trong giai đoạn này.',
      (Role.admin, _) => 'Theo dõi biến động để phát hiện giá bất thường trên sàn.',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final series = s.priceSeries(s.marketFruit, days);
    final change = _pct(series);
    final up = change >= 0;
    final color = up ? _upColor : _downColor;
    final tip = _tip(s.role, change);
    final avg = series.reduce((a, b) => a + b) / series.length;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Biến Động Giá Thị Trường (VNĐ/kg)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in kFruits.keys.where((f) => f != 'Khác'))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: s.marketFruit == f,
                  onSelected: (_) => s.setMarketFruit(f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${vnd(series.last)} đ',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppChip('${_pctText(change)} / $days ngày', color: color),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in [7, 30, 90]) ...[
            ChoiceChip(label: Text('$d ngày'), selected: days == d, onSelected: (_) => setState(() => days = d)),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 220, width: double.infinity, child: PriceChart(values: series, color: color)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _stat('Thấp nhất', vnd(series.reduce(min)))),
          Expanded(child: _stat('Trung bình', vnd(avg))),
          Expanded(child: _stat('Cao nhất', vnd(series.reduce(max)))),
        ]),
        if (tip != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(up ? Icons.trending_up : Icons.trending_down, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        const Text('Rê chuột hoặc chạm vào biểu đồ để xem giá từng ngày. Dữ liệu giá là số minh họa của app.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }

  Widget _stat(String label, String v) => Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

// ───────────────────────── Tab Giá Thị Trường (nông dân & thương gia) ─────────────────────────
class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final rows = [
      for (final f in kFruits.keys.where((f) => f != 'Khác')) (f, s.priceSeries(f, 7)),
    ]..sort((a, b) => _pct(b.$2).compareTo(_pct(a.$2)));

    return ListView(padding: kPad, children: [
      const Text('Giá Thị Trường', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(
          s.role == Role.farmer
              ? 'Theo dõi giá tăng giảm để chọn thời điểm đăng lô và bán.'
              : 'Theo dõi giá tăng giảm để chọn thời điểm và mức giá thu mua.',
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      const PriceChartCard(),
      sectionTitle('Bảng giá hôm nay (so với 7 ngày trước)'),
      AppCard(
        child: Column(children: [
          for (final r in rows)
            InkWell(
              onTap: () => s.setMarketFruit(r.$1),
              child: Container(
                color: s.marketFruit == r.$1 ? const Color(0xFFE8F5E9) : null,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 64,
                    height: 24,
                    child: CustomPaint(
                      painter: _Spark(r.$2, _pct(r.$2) >= 0 ? _upColor : _downColor),
                    ),
                  ),
                  Expanded(flex: 3, child: Text('${vnd(r.$2.last)} đ', textAlign: TextAlign.right)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _pctText(_pct(r.$2)),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: _pct(r.$2) >= 0 ? _upColor : _downColor),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}
