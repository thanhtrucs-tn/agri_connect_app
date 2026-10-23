import 'package:flutter/material.dart';

import 'state.dart';

const kGreen = Color(0xFF2E7D32);

Widget _field(TextEditingController c, String label,
        {TextInputType? type, bool required = true}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Vui lòng nhập' : null,
      ),
    );

/// Form đăng lô nông sản mới.
Future<void> showLotForm(BuildContext context,
    {String? initialFruit, int? initialPrice, String? aiNote}) {
  final state = Scope.of(context);
  final key = GlobalKey<FormState>();
  final name = TextEditingController(); // giống / tên gọi
  final owner = TextEditingController(
      text: state.role == Role.farmer ? state.userName : '');
  final phone = TextEditingController();
  final volume = TextEditingController();
  final address = TextEditingController();
  final price = TextEditingController(text: initialPrice?.toString() ?? '');
  var standard = 'VietGAP';
  var fruit = initialFruit ?? 'Sầu riêng';

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Đăng Lô Nông Sản Mới',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: fruit,
                  decoration: const InputDecoration(
                      labelText: 'Loại trái cây', border: OutlineInputBorder()),
                  items: kFruits.keys
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setS(() => fruit = v!),
                ),
              ),
              _field(name, fruit == 'Khác' ? 'Tên trái cây' : 'Giống / tên gọi (vd: Ri6, Cát Hòa Lộc)',
                  required: fruit == 'Khác'),
              _field(owner, 'Tên chủ vườn'),
              _field(phone, 'Số điện thoại', type: TextInputType.phone),
              _field(volume, 'Sản lượng dự kiến (kg)', type: TextInputType.number),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: standard,
                  decoration: const InputDecoration(
                      labelText: 'Tiêu chuẩn nông nghiệp', border: OutlineInputBorder()),
                  items: const ['VietGAP', 'GlobalGAP', 'Organic']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setS(() => standard = v!),
                ),
              ),
              _field(address, 'Địa chỉ thu hoạch'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Giá khởi điểm mong muốn (VNĐ/kg)',
                    helperText: 'Giá tham khảo $fruit: ${vnd(state.pricesFor(fruit).last)} đ/kg',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập' : null,
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    onPressed: () {
                      if (!key.currentState!.validate()) return;
                      state.addLot(Lot(
                        fruit: fruit,
                        name: fruit == 'Khác'
                            ? name.text.trim()
                            : '$fruit ${name.text.trim()}'.trim(),
                        owner: owner.text.trim(),
                        phone: phone.text.trim(),
                        volumeKg: int.tryParse(volume.text.trim()) ?? 0,
                        standard: standard,
                        address: address.text.trim(),
                        startPrice: int.tryParse(price.text.trim()) ?? 0,
                        harvestDate: DateTime.now().add(const Duration(days: 7)),
                        aiNote: aiNote,
                        status: 'Chờ duyệt',
                      ));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Đăng Lên Sàn Đấu Giá'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Form gửi báo giá của thương gia.
Future<void> showOfferForm(BuildContext context, Lot lot) {
  final state = Scope.of(context);
  final key = GlobalKey<FormState>();
  final company = TextEditingController(
      text: state.role == Role.merchant ? state.userName : '');
  final price = TextEditingController();
  final deposit = TextEditingController(text: 'Cọc 30%');
  var transport = 'Thương gia lo xe';

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Báo giá: ${lot.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _field(company, 'Tên công ty'),
              _field(price, 'Giá đề xuất (VNĐ/kg)', type: TextInputType.number),
              _field(deposit, 'Điều khoản đặt cọc'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: transport,
                  decoration: const InputDecoration(
                      labelText: 'Phương thức vận chuyển', border: OutlineInputBorder()),
                  items: const ['Thương gia lo xe', 'Nông dân giao hàng']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setS(() => transport = v!),
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    onPressed: () {
                      if (!key.currentState!.validate()) return;
                      state.addOffer(
                        lot,
                        Offer(company.text.trim(), int.tryParse(price.text.trim()) ?? 0,
                            deposit.text.trim(), transport),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Gửi Báo Giá Cho Nông Dân'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}
