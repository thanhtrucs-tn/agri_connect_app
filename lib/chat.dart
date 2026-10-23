import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'forms.dart';
import 'state.dart';

/// Chạy với: flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
/// Không có key → chatbox trả lời offline bằng quy tắc đơn giản.
/// LƯU Ý: key nằm trong app chỉ phù hợp để demo; bản thật nên gọi qua backend.
const kApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const kModel = 'claude-sonnet-5-5';

class ChatMsg {
  ChatMsg(this.fromUser, this.text, {this.offline = false});
  final bool fromUser;
  final String text;
  final bool offline;
}

String _systemPrompt(AppState s) {
  final b = StringBuffer()
    ..writeln('Bạn là trợ lý AI của AgriConnect, sàn kết nối và thu mua mọi loại trái cây tận vườn tại Việt Nam.')
    ..writeln('Trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu, thân thiện với nông dân.')
    ..writeln('Người dùng: ${s.userName}, vai trò: ${s.role?.label}.')
    ..writeln('Quy trình: đăng lô → thương gia báo giá → nông dân chọn bên mua → thương gia xem vườn → nhận cọc & chốt thu hoạch.')
    ..writeln('Khi so sánh báo giá, cân nhắc cả điểm uy tín và rủi ro bùng cọc, không chỉ giá cao nhất. Không cam kết giá tương lai; giá chỉ để tham khảo. Nếu không chắc, nói rõ là không chắc.')
    ..writeln('Dữ liệu hiện tại trên sàn:');
  for (final l in s.lots) {
    b.writeln('- Lô "${l.name}" của ${l.owner}: ${l.volumeKg} kg, ${l.standard}, ${l.address}, '
        'thu hoạch ${fmtDate(l.harvestDate)}, giá khởi điểm ${l.startPrice} đ/kg, trạng thái ${l.status}.');
    for (final o in l.sortedOffers) {
      final r = s.repOf(o.company);
      final rep = r == null
          ? 'mới tham gia'
          : '${r.stars.toStringAsFixed(1)}/5 (${r.deals} giao dịch, đúng hẹn ${(r.onTime * 100).round()}%)';
      b.writeln('    + ${o.company}: ${o.price} đ/kg, ${o.deposit}, ${o.transport}, uy tín $rep');
    }
  }
  b.writeln('Giá trung bình 7 ngày gần nhất (đ/kg) theo loại trái cây:');
  for (final f in {for (final l in s.lots) l.fruit}) {
    b.writeln('- $f: ${s.pricesFor(f).join(", ")}');
  }
  return b.toString();
}

Future<ChatMsg> askAssistant(AppState s, List<ChatMsg> history) async {
  if (kApiKey.isEmpty) return _offline(s, history.last.text);
  try {
    final res = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': kApiKey,
            'anthropic-version': '2023-06-01',
            'anthropic-dangerous-direct-browser-access': 'true',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': kModel,
            'max_tokens': 800,
            'system': _systemPrompt(s),
            'messages': [
              for (final m in history)
                {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
            ],
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      return ChatMsg(false, 'Lỗi từ AI (${res.statusCode}). Thử lại sau nhé.');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final text = (data['content'] as List).map((c) => c['text'] ?? '').join();
    return ChatMsg(false, text);
  } catch (e) {
    return ChatMsg(false, 'Không kết nối được AI: $e');
  }
}

ChatMsg _offline(AppState s, String q) {
  final t = q.toLowerCase();
  String a;
  final lots = s.role == Role.farmer ? s.myLots : s.lots;
  final withOffers = lots.where((l) => l.offers.isNotEmpty).toList();
  if (t.contains('giá') || t.contains('báo giá') || t.contains('bên nào')) {
    if (withOffers.isEmpty) {
      a = 'Hiện chưa có báo giá nào. Giá tham khảo hôm nay: ${lots.isEmpty ? '' : '${lots.first.fruit} ${vnd(s.pricesFor(lots.first.fruit).last)} đ/kg'}.';
    } else {
      final l = withOffers.first;
      final o = l.sortedOffers.first;
      a = 'Lô "${l.name}" có ${l.offers.length} báo giá. Cao nhất: ${o.company} '
          '${vnd(o.price)} đ/kg (${o.deposit}, ${o.transport}). '
          'Nên so cả điều khoản cọc và vận chuyển, không chỉ nhìn giá.';
    }
  } else if (t.contains('quy trình') || t.contains('bước') || t.contains('làm sao')) {
    a = '5 bước: 1) Đăng lô & chờ duyệt 2) Thương gia báo giá 3) Nông dân chọn bên mua '
        '4) Thương gia xem vườn 5) Nhận cọc và chốt thu hoạch.';
  } else if (t.contains('cọc')) {
    a = 'Tiền cọc giúp bên mua giữ hàng. Thường 20–30% giá trị lô; hãy thống nhất rõ mức cọc '
        'và điều kiện hoàn cọc trước khi chốt.';
  } else if (t.contains('vietgap') || t.contains('globalgap') || t.contains('organic') || t.contains('tiêu chuẩn')) {
    a = 'VietGAP: chuẩn thực hành nông nghiệp tốt của VN. GlobalGAP: chuẩn quốc tế, phù hợp xuất khẩu. '
        'Organic: canh tác hữu cơ, giá thường cao hơn.';
  } else if (t.contains('thu về') || t.contains('doanh thu') || t.contains('tiền')) {
    if (withOffers.isEmpty) {
      a = 'Chưa có báo giá để tính. Khi có báo giá, tạm tính = sản lượng × giá bên bạn chọn.';
    } else {
      final l = withOffers.first;
      a = 'Lô "${l.name}": tạm tính ~${vnd(l.proceeds / 1000000)} triệu đồng '
          '(${vnd(l.volumeKg)} kg × ${vnd(l.selected?.price ?? l.bestPrice)} đ/kg).';
    }
  } else {
    a = 'Mình có thể giúp về: so sánh báo giá, quy trình giao dịch, tiền cọc, tiêu chuẩn VietGAP/GlobalGAP, '
        'tạm tính thu nhập. (Đang chạy chế độ offline – thêm API key để hỏi tự do.)';
  }
  return ChatMsg(false, a, offline: true);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgs = <ChatMsg>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  List<String> _suggestions(Role? r) => switch (r) {
        Role.merchant => ['Nên báo giá bao nhiêu?', 'Quy trình giao dịch?', 'Tiền cọc thế nào?'],
        Role.admin => ['Tóm tắt tình hình sàn', 'Lô nào có giá cao nhất?', 'Quy trình giao dịch?'],
        _ => ['Nên chọn bên nào bán?', 'Tạm tính tôi thu về bao nhiêu?', 'VietGAP là gì?'],
      };

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || busy) return;
    final s = Scope.of(context);
    input.clear();
    setState(() {
      msgs.add(ChatMsg(true, text));
      busy = true;
    });
    _toBottom();
    final reply = await askAssistant(s, List.of(msgs));
    if (!mounted) return;
    setState(() {
      msgs.add(reply);
      busy = false;
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text('Trợ lý AI AgriConnect'),
      ),
      body: Column(children: [
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.smart_toy, size: 56, color: kGreen),
                      const SizedBox(height: 12),
                      Text('Xin chào ${s.userName}! Mình có thể giúp gì cho bạn?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                        for (final q in _suggestions(s.role))
                          ActionChip(label: Text(q), onPressed: () => _send(q)),
                      ]),
                    ]),
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length + (busy ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == msgs.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      );
                    }
                    final m = msgs[i];
                    return Align(
                      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: m.fromUser ? kGreen : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: m.fromUser ? null : Border.all(color: Colors.green.shade100),
                        ),
                        child: SelectableText(m.text,
                            style: TextStyle(color: m.fromUser ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Hỏi trợ lý…',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: kGreen),
                onPressed: busy ? null : () => _send(input.text),
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
