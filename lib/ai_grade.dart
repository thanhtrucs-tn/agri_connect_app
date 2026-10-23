import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'chat.dart' show kApiKey, kModel;
import 'forms.dart';
import 'state.dart';
import 'widgets.dart';


const _gradeMult = [1.0, 0.8, 0.55];

class GradeResult {
  GradeResult({
    required this.ripeness,
    required this.blemish,
    required this.size,
    required this.grades,
    required this.notes,
    required this.simulated,
    this.valid = true,
  });
  final double ripeness; // % độ chín
  final double blemish; // % diện tích vết thâm
  final String size;
  final List<double> grades; // % sản lượng Loại 1/2/3, tổng 100
  final String notes;
  final bool simulated;
  final bool valid;
}

Future<GradeResult> analyzePhoto(Uint8List bytes, String fruit) async {
  String? failure;
  if (kApiKey.isNotEmpty) {
    try {
      final mt = bytes.length > 3 && bytes[0] == 0x89 ? 'image/png' : 'image/jpeg';
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
              'max_tokens': 500,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {'type': 'base64', 'media_type': mt, 'data': base64Encode(bytes)},
                    },
                    {
                      'type': 'text',
                      'text': 'Bạn là chuyên gia phân loại trái cây ($fruit). Phân tích ảnh và chỉ trả về MỘT JSON: '
                          '{"ripeness":0-100,"size":"nhỏ|vừa|lớn","blemish_pct":0-100,'
                          '"grade1":0-100,"grade2":0-100,"grade3":0-100,"notes":"nhận xét ngắn bằng tiếng Việt"}. '
                          'ripeness là độ chín (%), blemish_pct là % diện tích có vết thâm/hư, '
                          'grade1..3 là % sản lượng ước tính thuộc Loại 1/2/3 (tổng 100). '
                          'Nếu ảnh không phải trái cây, đặt grade1..3 bằng 0 và giải thích trong notes.',
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final text = (data['content'] as List).map((c) => c['text'] ?? '').join();
        final j = jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1));
        final g = [for (final k in ['grade1', 'grade2', 'grade3']) (j[k] as num).toDouble()];
        final sum = g.fold(0.0, (a, b) => a + b);
        return GradeResult(
          ripeness: (j['ripeness'] as num).toDouble(),
          blemish: (j['blemish_pct'] as num).toDouble(),
          size: j['size'] as String,
          grades: sum <= 0 ? [0, 0, 0] : [for (final x in g) x / sum * 100],
          notes: (j['notes'] as String?) ?? '',
          simulated: false,
          valid: sum > 0,
        );
      }
      failure = 'AI trả lỗi ${res.statusCode}';
    } catch (e) {
      failure = 'Không gọi được AI';
    }
  }
  return _simulate(bytes, failure);
}

/// Kết quả minh họa khi chưa có API key (cố định theo nội dung ảnh).
GradeResult _simulate(Uint8List bytes, String? failure) {
  var h = bytes.length;
  final step = max(1, bytes.length ~/ 257);
  for (var i = 0; i < bytes.length; i += step) {
    h = (h * 31 + bytes[i]) & 0x7fffffff;
  }
  final r = Random(h);
  final ripeness = 62.0 + r.nextInt(33);
  final blemish = 3.0 + r.nextInt(22);
  final g1 = max(5.0, ripeness * 0.9 - blemish * 1.5);
  final g3 = blemish * 1.6;
  final g2 = max(5.0, 100 - g1 - g3);
  final sum = g1 + g2 + g3;
  return GradeResult(
    ripeness: ripeness,
    blemish: blemish,
    size: const ['nhỏ', 'vừa', 'lớn'][r.nextInt(3)],
    grades: [g1 / sum * 100, g2 / sum * 100, g3 / sum * 100],
    notes: failure ?? 'Kết quả minh họa, không phải phân tích thật.',
    simulated: true,
  );
}

class AiGradePage extends StatefulWidget {
  const AiGradePage({super.key});
  @override
  State<AiGradePage> createState() => _AiGradePageState();
}

class _AiGradePageState extends State<AiGradePage> {
  String fruit = 'Sầu riêng';
  Uint8List? image;
  GradeResult? result;
  bool busy = false;

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        image = bytes;
        result = null;
        busy = true;
      });
      final res = await analyzePhoto(bytes, fruit);
      if (!mounted) return;
      setState(() {
        result = res;
        busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      snack(context, src == ImageSource.camera
          ? 'Không mở được camera trên thiết bị này. Hãy chọn ảnh từ thư viện.'
          : 'Không đọc được ảnh.');
    }
  }

  Future<void> _reanalyze() async {
    if (image == null) return;
    setState(() {
      busy = true;
      result = null;
    });
    final res = await analyzePhoto(image!, fruit);
    if (!mounted) return;
    setState(() {
      result = res;
      busy = false;
    });
  }

  int _round500(num v) => (v / 500).round() * 500;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    final base = s.pricesFor(fruit).last;
    final r = result;
    final expected = r == null
        ? 0.0
        : [for (var i = 0; i < 3; i++) r.grades[i] / 100 * _gradeMult[i] * base].fold(0.0, (a, b) => a + b);

    return ListView(padding: kPad, children: [
      const Text('AI Định Giá & Phân Loại Qua Ảnh',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Chụp hoặc chọn ảnh nông sản. AI phân tích độ chín, kích thước, vết thâm, '
          'rồi cho % phân loại và khung giá gợi ý theo giá thị trường.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: fruit,
        decoration: const InputDecoration(
            labelText: 'Loại trái cây', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
        items: kFruits.keys
            .where((f) => f != 'Khác')
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          setState(() => fruit = v!);
          _reanalyze();
        },
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Chụp ảnh'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Chọn ảnh'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (image != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(image!, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Column(children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('AI đang phân tích ảnh…'),
          ])),
        ),
      if (r != null) ...[
        const SizedBox(height: 12),
        if (r.simulated)
          AppCard(
            color: const Color(0xFFFFF8E1),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chế độ mô phỏng: ${r.notes} Chạy app với ANTHROPIC_API_KEY để AI phân tích ảnh thật.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
          ),
        if (!r.valid)
          AppCard(child: Text('AI không nhận ra trái cây trong ảnh. ${r.notes}'))
        else ...[
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              sectionTitle('Phân tích'),
              pctBar('Độ chín', r.ripeness),
              pctBar('Vết thâm / hư', r.blemish,
                  color: r.blemish > 15 ? Colors.red : Colors.orange),
              kv('Kích thước', r.size),
              if (!r.simulated && r.notes.isNotEmpty) kv('Nhận xét', r.notes),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              sectionTitle('Phân loại (% sản lượng)'),
              pctBar('Loại 1', r.grades[0]),
              pctBar('Loại 2', r.grades[1], color: Colors.orange),
              pctBar('Loại 3', r.grades[2], color: Colors.red),
            ]),
          ),
          AppCard(
            color: const Color(0xFFE8F5E9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              sectionTitle('Khung giá gợi ý'),
              Text('${vnd(_round500(expected * 0.95))} – ${vnd(_round500(expected * 1.05))} đ/kg',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kGreen)),
              Text('Giá thị trường $fruit hôm nay: ${vnd(base)} đ/kg',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              for (var i = 0; i < 3; i++)
                kv('Loại ${i + 1}', '${vnd(_round500(base * _gradeMult[i]))} đ/kg'),
              const SizedBox(height: 8),
              const Text('Giá gợi ý chỉ để tham khảo, dựa trên giá mẫu của app.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => showLotForm(
              context,
              initialFruit: fruit,
              initialPrice: _round500(expected),
              aiNote: 'Loại 1: ${r.grades[0].round()}% · chín ${r.ripeness.round()}% · '
                  'thâm ${r.blemish.round()}%${r.simulated ? ' (mô phỏng)' : ''}',
            ),
            icon: const Icon(Icons.add),
            label: const Text('Đăng lô với kết quả này'),
          ),
        ],
      ],
    ]);
  }
}
