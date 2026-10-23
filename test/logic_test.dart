import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_connect_app/ai_grade.dart';
import 'package:agri_connect_app/main.dart';
import 'package:agri_connect_app/market.dart';
import 'package:agri_connect_app/state.dart';

void _fund(AppState s, {int times = 3}) {
  for (var i = 0; i < times; i++) {
    s.topUp(50000000);
  }
}

void main() {
  group('Escrow – đúng vai trò mới làm được', () {
    late AppState s;
    late Lot lot;
    late Offer vina;

    setUp(() {
      s = AppState();
      lot = s.lots.first; // Sầu Riêng Ri6 – 8000 kg, của Chú Hai Xoàn
      vina = lot.offers.firstWhere((o) => o.company == 'VinaAgr');
      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.selectOffer(lot, vina);
    });

    test('chọn bên mua tạo giao dịch, cọc đúng 20%', () {
      final d = s.deals.single;
      expect(d.total, 8000 * 85000);
      expect(d.deposit, (8000 * 85000 * 0.2).round());
      expect(d.status, DealStatus.awaitingDeposit);
    });

    test('ví không đủ tiền thì không nạp cọc được', () {
      s.login(Role.merchant, 'VinaAgr'); // ví mẫu 50 triệu < cọc 136 triệu
      expect(s.payDeposit(s.deals.single), contains('không đủ'));
      expect(s.deals.single.status, DealStatus.awaitingDeposit);
      expect(s.balance('VinaAgr'), 50000000);
    });

    test('giao đúng chất lượng → cọc chuyển cho nông dân', () {
      s.login(Role.merchant, 'VinaAgr');
      _fund(s);
      final d = s.deals.single;
      expect(s.payDeposit(d), isNull);
      expect(d.status, DealStatus.held);
      expect(s.balance('VinaAgr'), 200000000 - d.deposit);

      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.markDelivered(d);
      expect(d.status, DealStatus.delivered);

      s.login(Role.merchant, 'VinaAgr');
      s.confirmDelivery(d);
      expect(d.status, DealStatus.released);
      expect(s.balance('Chú Hai Xoàn'), d.deposit);
    });

    test('báo không đạt → admin hoàn cọc cho bên mua', () {
      s.login(Role.merchant, 'VinaAgr');
      _fund(s);
      final d = s.deals.single;
      s.payDeposit(d);
      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.markDelivered(d);
      s.login(Role.merchant, 'VinaAgr');
      s.dispute(d);
      expect(d.status, DealStatus.disputed);
      s.login(Role.admin, 'Quản trị viên');
      s.resolve(d, toFarmer: false);
      expect(d.status, DealStatus.refunded);
      expect(s.balance('VinaAgr'), 200000000);
      expect(s.balance('Chú Hai Xoàn'), 0);
    });

    test('đã nạp cọc thì không đổi bên mua được nữa', () {
      s.login(Role.merchant, 'VinaAgr');
      _fund(s);
      s.payDeposit(s.deals.single);
      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.selectOffer(lot, lot.offers.firstWhere((o) => o.company == 'Mekong Export'));
      expect(s.deals.single.buyer, 'VinaAgr');
    });

    test('vai trò sai bị chặn: nông dân không nạp cọc/xác nhận/xử lý tranh chấp', () {
      final d = s.deals.single;
      s.login(Role.farmer, 'Chú Hai Xoàn');
      expect(s.payDeposit(d), contains('bên mua'));
      s.topUp(1000000);
      expect(s.balance('Chú Hai Xoàn'), 0); // nông dân không nạp ví được

      s.login(Role.merchant, 'VinaAgr');
      _fund(s);
      s.payDeposit(d);
      s.markDelivered(d); // thương gia không được báo "đã giao"
      expect(d.status, DealStatus.held);

      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.markDelivered(d);
      s.confirmDelivery(d); // nông dân không tự xác nhận
      expect(d.status, DealStatus.delivered);
      s.dispute(d);
      expect(d.status, DealStatus.delivered);

      s.login(Role.merchant, 'Hoàng Gia Fruit'); // thương gia khác không đụng được giao dịch của VinaAgr
      s.confirmDelivery(d);
      expect(d.status, DealStatus.delivered);

      s.login(Role.merchant, 'VinaAgr');
      s.dispute(d);
      s.resolve(d, toFarmer: true); // thương gia không được tự xử tranh chấp
      expect(d.status, DealStatus.disputed);
    });

    test('thương gia không chọn bên mua thay nông dân; nông dân không báo giá', () {
      final other = s.lots.firstWhere((l) => l.name == 'Xoài Cát Hòa Lộc');
      s.login(Role.merchant, 'VinaAgr');
      s.selectOffer(other, Offer('VinaAgr', 1, 'x', 'y'));
      expect(other.selected, isNull);

      s.login(Role.farmer, 'Cô Ba Lài');
      s.addOffer(other, Offer('Cô Ba Lài', 99000, 'x', 'y'));
      expect(other.offers, isEmpty);

      s.login(Role.farmer, 'Chú Hai Xoàn'); // lô của người khác
      s.selectOffer(other, Offer('VinaAgr', 1, 'x', 'y'));
      expect(other.selected, isNull);
    });

    test('chỉ admin duyệt/xóa lô', () {
      final l = s.lots.firstWhere((l) => l.status == 'Chờ duyệt', orElse: () => s.lots.last);
      s.login(Role.farmer, 'Chú Hai Xoàn');
      final before = s.lots.length;
      s.removeLot(l);
      expect(s.lots.length, before);
      s.login(Role.admin, 'Quản trị viên');
      s.removeLot(l);
      expect(s.lots.length, before - 1);
    });
  });

  group('Gom đơn & đấu giá ngược', () {
    test('gợi ý gom theo loại + tỉnh', () {
      final s = AppState();
      final g = s.poolSuggestions();
      expect(g, hasLength(2));
      final dt = g.firstWhere((x) => x.first.province == 'Đồng Tháp');
      expect(dt.fold(0, (a, l) => a + l.volumeKg), 9300);
      final tg = g.firstWhere((x) => x.first.province == 'Tiền Giang');
      expect(tg.fold(0, (a, l) => a + l.volumeKg), 3500);
      expect(tg.any((l) => l.owner == 'Chú Hai Xoàn'), isTrue);
    });

    test('nông dân chỉ gom được lô có vườn của mình; thương gia không gom được', () {
      final s = AppState();
      final dt = s.poolSuggestions().firstWhere((x) => x.first.province == 'Đồng Tháp');
      s.login(Role.merchant, 'VinaAgr');
      s.createPool(dt);
      expect(s.pools, hasLength(1)); // chỉ còn lô mẫu
      s.login(Role.farmer, 'Chú Hai Xoàn'); // không có vườn trong nhóm Đồng Tháp
      s.createPool(dt);
      expect(s.pools, hasLength(1));
      s.login(Role.farmer, 'Cô Ba Lài');
      s.createPool(dt);
      expect(s.pools, hasLength(2));
    });

    test('đặt giá phải cao hơn, thắng thì tạo giao dịch chia theo kg', () {
      final s = AppState();
      s.login(Role.admin, 'Quản trị viên');
      s.createPool(s.poolSuggestions().firstWhere((x) => x.first.province == 'Đồng Tháp'));
      final p = s.pools.first;
      expect(p.totalKg, 9300);
      expect(p.endsAt.difference(DateTime.now()).inHours, greaterThanOrEqualTo(23));

      expect(s.placeBid(p, 40000), contains('thương gia')); // admin không đấu giá
      s.login(Role.farmer, 'Cô Ba Lài');
      expect(s.placeBid(p, 40000), contains('thương gia')); // nông dân cũng không
      s.login(Role.merchant, 'VinaAgr');
      expect(s.placeBid(p, 40000), isNull);
      expect(s.placeBid(p, 39000), contains('cao hơn'));
      s.login(Role.merchant, 'Hoàng Gia Fruit');
      expect(s.placeBid(p, 41000), isNull);

      s.closePool(p);
      expect(p.winner, 'Hoàng Gia Fruit');
      final d = s.deals.first;
      expect(d.buyer, 'Hoàng Gia Fruit');
      expect(d.kg, 9300);
      expect(d.shares.length, 3);
      expect(s.placeBid(p, 50000), contains('kết thúc'));
    });

    test('lô gom mẫu: 3 vườn = 5 tấn, VinaAgr đang dẫn giá', () {
      final s = AppState();
      final p = s.pools.single;
      expect(p.totalKg, 5000);
      expect(p.members, hasLength(3));
      expect(p.best!.company, 'VinaAgr');
      s.closePool(p);
      expect(s.deals.first.buyer, 'VinaAgr');
    });

    test('phiên hết hạn tự đóng', () {
      final s = AppState();
      final p = Pool(
        id: 99,
        fruit: 'Cam',
        province: 'Vĩnh Long',
        members: [PoolMember('A', 1000, 'Cam sành')],
        endsAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      s.pools.add(p);
      s.closeExpired();
      expect(p.closed, isTrue);
      expect(p.winner, isNull);
    });
  });

  group('Lịch khảo sát theo vai trò', () {
    test('thương gia đặt → nông dân xác nhận → thương gia ghi kết quả', () {
      final s = AppState();
      final lot = s.lots.firstWhere((l) => l.owner == 'Cô Ba Lài');
      s.login(Role.farmer, 'Cô Ba Lài');
      expect(s.requestSurvey(lot, DateTime(2026, 10, 30)), contains('thương gia'));

      s.login(Role.merchant, 'VinaAgr');
      expect(s.requestSurvey(lot, DateTime(2026, 10, 30)), isNull);
      expect(s.requestSurvey(lot, DateTime(2026, 10, 31)), contains('đã có lịch'));
      final sv = s.surveys.first;
      expect(sv.status, 'Chờ xác nhận');

      s.answerSurvey(sv, true); // thương gia không tự xác nhận
      expect(sv.status, 'Chờ xác nhận');
      s.login(Role.farmer, 'Chú Hai Xoàn'); // nông dân khác cũng không
      s.answerSurvey(sv, true);
      expect(sv.status, 'Chờ xác nhận');
      s.login(Role.farmer, 'Cô Ba Lài');
      s.answerSurvey(sv, true);
      expect(sv.status, 'Đã hẹn');

      s.login(Role.farmer, 'Cô Ba Lài');
      s.completeSurvey(sv, 'xin ghi kết quả'); // nông dân không ghi kết quả
      expect(sv.status, 'Đã hẹn');
      s.login(Role.merchant, 'VinaAgr');
      s.completeSurvey(sv, 'Chín 85%, size vừa');
      expect(sv.status, 'Đã khảo sát');
      expect(sv.result, contains('85%'));
    });
  });

  group('Nhật ký', () {
    test('tự ghi khi chốt bán và cho phép sửa ghi chú', () {
      final s = AppState();
      final lot = s.lots.first;
      s.login(Role.farmer, 'Chú Hai Xoàn');
      s.selectOffer(lot, lot.offers.first);
      final e = s.ledger.firstWhere((e) => e.user == 'Chú Hai Xoàn' && e.type == 'Bán');
      expect(e.amount, 8000 * 85000);
      e.note = 'Đã gọi xác nhận';
      s.touchLedger();
      expect(s.ledger.firstWhere((x) => x.id == e.id).note, 'Đã gọi xác nhận');
      s.deleteEntry(e);
      expect(s.ledger.contains(e), isFalse);
    });

    test('loại mục khác nhau theo vai trò', () {
      expect(kTypesByRole[Role.farmer], contains('Xuất hàng'));
      expect(kTypesByRole[Role.farmer], isNot(contains('Mua')));
      expect(kTypesByRole[Role.merchant], contains('Nhận hàng'));
      expect(kTypesByRole[Role.merchant], isNot(contains('Bán')));
    });

    test('LedgerEntry lưu và đọc lại JSON', () {
      final e = LedgerEntry(
          id: 5, user: 'A', date: DateTime(2026, 10, 1, 9, 30), type: 'Xuất hàng', title: 'Giao 2 tấn', amount: 1000, note: 'ok');
      final back = LedgerEntry.fromJson(e.toJson());
      expect(back.title, 'Giao 2 tấn');
      expect(back.date, DateTime(2026, 10, 1, 9, 30));
      expect(back.amount, 1000);
    });
  });

  group('AI chấm ảnh (mô phỏng khi không có API key)', () {
    test('tổng % 3 loại = 100 và kết quả ổn định theo ảnh', () async {
      final img = Uint8List.fromList(List.generate(2000, (i) => (i * 7) % 256));
      final a = await analyzePhoto(img, 'Xoài');
      final b = await analyzePhoto(img, 'Xoài');
      expect(a.simulated, isTrue);
      expect(a.valid, isTrue);
      expect(a.grades.reduce((x, y) => x + y), closeTo(100, 0.001));
      expect(a.grades, b.grades);
      expect(a.ripeness, inInclusiveRange(0, 100));
    });
  });

  group('Giá thị trường', () {
    test('chuỗi giá kết thúc đúng giá hôm nay và ổn định giữa các lần gọi', () {
      final s = AppState();
      for (final f in kFruits.keys) {
        final a = s.priceSeries(f, 30);
        expect(a, hasLength(30));
        expect(a.last, (kFruits[f]! / 100).round() * 100);
        expect(s.priceSeries(f, 30), a);
        expect(a.every((v) => v >= kFruits[f]! * 0.55 && v <= kFruits[f]! * 1.55), isTrue);
      }
    });

    test('7 ngày cuối của chuỗi 90 ngày khớp chuỗi 7 ngày', () {
      final s = AppState();
      expect(s.priceSeries('Xoài', 90).sublist(83), s.priceSeries('Xoài', 7));
      expect(s.pricesFor('Xoài'), s.priceSeries('Xoài', 7));
    });

    test('có tăng và có giảm (không phải đường phẳng)', () {
      final s = AppState();
      final changes = [for (final f in kFruits.keys) s.priceSeries(f, 30)].map((v) => v.last - v.first);
      expect(changes.any((c) => c > 0), isTrue);
      expect(changes.any((c) => c < 0), isTrue);
    });
  });

  group('Giao diện từng vai trò', () {
    Future<void> login(WidgetTester tester, String role) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 3000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const AgriConnectApp());
      await tester.tap(find.text(role).first); // chọn thẻ vai trò
      await tester.pump();
      await tester.tap(find.text('Vào với vai trò $role'));
      await tester.pumpAndSettle();
    }

    testWidgets('nông dân: gom đơn chỉ thấy gợi ý của mình, không có nút đặt giá', (tester) async {
      await login(tester, 'Nông Dân');
      await tester.tap(find.text('Gom Đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Gom thành 1 lô lớn & mở đấu giá 24h'), findsOneWidget); // chỉ nhóm Tiền Giang
      expect(find.text('Đặt giá thu mua'), findsNothing);
      expect(find.text('Kết thúc sớm (demo)'), findsNothing);

      await tester.tap(find.text('Gom thành 1 lô lớn & mở đấu giá 24h'));
      await tester.pumpAndSettle();
      expect(find.text('Gom thành 1 lô lớn & mở đấu giá 24h'), findsNothing);
      expect(find.textContaining('Lô gom có phần của tôi (1)'), findsOneWidget);
      expect(find.textContaining('Phần của bạn: 2.000 kg'), findsOneWidget);
    });

    testWidgets('nông dân: ví chỉ nhận cọc, không có nạp tiền', (tester) async {
      await login(tester, 'Nông Dân');
      await tester.tap(find.text('CHỌN BÁN BÊN NÀY').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ví Nhận Cọc'));
      await tester.pumpAndSettle();
      expect(find.text('Chờ bên mua nạp cọc'), findsOneWidget);
      expect(find.textContaining('Nạp cọc'), findsNothing);
      expect(find.textContaining('+ 5 triệu'), findsNothing);
    });

    testWidgets('nông dân: nhật ký thêm ghi chú mới', (tester) async {
      await login(tester, 'Nông Dân');
      await tester.tap(find.text('Nhật Ký'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm ghi chú / mục mới'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nội dung'), 'Xuất 2 tấn xoài cho anh Ba');
      await tester.enterText(find.widgetWithText(TextField, 'Ghi chú của bạn'), 'Xe tải 51C-123');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Xuất 2 tấn xoài cho anh Ba'), findsOneWidget);
      expect(find.textContaining('Xe tải 51C-123'), findsOneWidget);
    });

    testWidgets('nông dân: lịch xem vườn có nút xác nhận / từ chối', (tester) async {
      await login(tester, 'Nông Dân');
      await tester.tap(find.text('Lịch Xem Vườn'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận lịch'), findsOneWidget); // Hoàng Gia Fruit chờ xác nhận
      await tester.tap(find.text('Xác nhận lịch'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận lịch'), findsNothing);
    });

    testWidgets('thương gia: tab riêng, đấu giá & ví nạp cọc, không thấy màn nông dân/admin', (tester) async {
      await login(tester, 'Thương Gia');
      for (final t in ['Sàn Thu Mua', 'Đấu Giá', 'Ví Tạm Giữ', 'Khảo Sát', 'Nhật Ký']) {
        expect(find.text(t), findsWidgets);
      }
      for (final t in ['Lô Của Tôi', 'AI Giá', 'Lịch Xem Vườn', 'Ví Nhận Cọc', 'Tổng Quan', 'Giao Dịch']) {
        expect(find.text(t), findsNothing);
      }
      await tester.tap(find.text('Đấu Giá'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang dẫn giá'), findsOneWidget); // VinaAgr dẫn giá lô mẫu
      expect(find.text('Gom thành 1 lô lớn & mở đấu giá 24h'), findsNothing);

      await tester.tap(find.text('Ví Tạm Giữ'));
      await tester.pumpAndSettle();
      expect(find.text('+ 5 triệu'), findsOneWidget);
      await tester.tap(find.text('+ 5 triệu'));
      await tester.pumpAndSettle();
      expect(find.text('55.000.000 đ'), findsOneWidget);
    });

    testWidgets('nông dân & thương gia thấy tab Giá Thị Trường với lời nhận xét riêng', (tester) async {
      await login(tester, 'Nông Dân');
      await tester.tap(find.text('Giá Thị Trường'));
      await tester.pumpAndSettle();
      expect(find.text('Biến Động Giá Thị Trường (VNĐ/kg)'), findsOneWidget);
      expect(find.text('Bảng giá hôm nay (so với 7 ngày trước)'), findsOneWidget);
      expect(find.byType(PriceChart), findsOneWidget);

      // Đổi sang 90 ngày và chọn loại khác từ bảng giá
      await tester.tap(find.text('90 ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoài').last);
      await tester.pumpAndSettle();
      expect(Scope.of(tester.element(find.byType(PriceChart))).marketFruit, 'Xoài');
      expect(find.byIcon(Icons.trending_up).evaluate().length + find.byIcon(Icons.trending_down).evaluate().length,
          1);

      // chạm vào biểu đồ không gây lỗi
      await tester.tapAt(tester.getCenter(find.byType(PriceChart)));
      await tester.pump();
    });

    testWidgets('thương gia có tab Giá Thị Trường, admin xem biểu đồ ngay ở Tổng Quan', (tester) async {
      await login(tester, 'Thương Gia');
      expect(find.text('Giá Thị Trường'), findsOneWidget);
    });

    testWidgets('admin: chỉ giám sát, không có màn nông dân/thương gia/ví cá nhân', (tester) async {
      await login(tester, 'Admin');
      for (final t in ['Tổng Quan', 'Giao Dịch', 'Gom Đơn', 'Khảo Sát', 'Nhật Ký']) {
        expect(find.text(t), findsWidgets);
      }
      for (final t in ['Lô Của Tôi', 'AI Giá', 'Sàn Thu Mua', 'Đấu Giá', 'Ví Tạm Giữ', 'Ví Nhận Cọc']) {
        expect(find.text(t), findsNothing);
      }
      await tester.tap(find.text('Gom Đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Kết thúc sớm (demo)'), findsOneWidget);
      expect(find.text('Đặt giá thu mua'), findsNothing);

      await tester.tap(find.text('Nhật Ký'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm ghi chú / mục mới'), findsNothing); // admin chỉ xem
    });
  });
}
