import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_connect_app/main.dart';

void main() {
  testWidgets('nông dân vào màn riêng của nông dân', (tester) async {
    await tester.pumpWidget(const AgriConnectApp());
    await tester.tap(find.text('Vào với vai trò Nông Dân'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng Lô Nông Sản Mới'), findsOneWidget);
    expect(find.text('Lô Của Tôi'), findsOneWidget);
    expect(find.text('Sàn Thu Mua'), findsNothing);
    expect(find.text('Tổng Quan'), findsNothing);
  });

  testWidgets('chatbox offline trả lời về báo giá', (tester) async {
    await tester.pumpWidget(const AgriConnectApp());
    await tester.tap(find.text('Vào với vai trò Nông Dân'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hỏi AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nên chọn bên nào bán?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('VinaAgr'), findsWidgets);
    expect(find.textContaining('85.000'), findsWidgets);
  });

  testWidgets('hiện điểm uy tín, cảnh báo thương gia điểm thấp, đánh giá sau chốt', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AgriConnectApp());
    await tester.tap(find.text('Vào với vai trò Nông Dân'));
    await tester.pumpAndSettle();

    expect(find.textContaining('4.8 · 42 giao dịch'), findsOneWidget); // VinaAgr
    expect(find.text('Cần thận trọng'), findsOneWidget); // Mekong 3.6

    await tester.tap(find.text('CHỌN BÁN BÊN NÀY').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất giao dịch & đánh giá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hoàn tất'), findsOneWidget);
    expect(find.textContaining('4.8 · 43 giao dịch'), findsOneWidget);
  });

  testWidgets('admin vào màn giám sát, đăng xuất về màn chọn vai trò', (tester) async {
    await tester.pumpWidget(const AgriConnectApp());
    await tester.tap(find.text('Admin').first);
    await tester.pump();
    await tester.tap(find.text('Vào với vai trò Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng Quan'), findsOneWidget);
    expect(find.text('Giao Dịch'), findsOneWidget);
    expect(find.text('Lô Của Tôi'), findsNothing);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Bạn là ai?'), findsOneWidget);
  });
}
