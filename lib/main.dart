import 'package:flutter/material.dart';

import 'ai_grade.dart';
import 'chat.dart';
import 'forms.dart';
import 'ledger.dart';
import 'market.dart';
import 'pages.dart';
import 'pool.dart';
import 'state.dart';
import 'survey.dart';
import 'wallet.dart';

void main() => runApp(const AgriConnectApp());

class AgriConnectApp extends StatefulWidget {
  const AgriConnectApp({super.key});
  @override
  State<AgriConnectApp> createState() => _AgriConnectAppState();
}

class _AgriConnectAppState extends State<AgriConnectApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.loadLedger();
  }

  @override
  Widget build(BuildContext context) => Scope(
        state: state,
        child: MaterialApp(
          title: 'AgriConnect',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: kGreen,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F8F1),
          ),
          home: const _Gate(),
        ),
      );
}

/// Chưa đăng nhập → màn chọn vai trò; đã đăng nhập → màn chính theo vai trò.
class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final role = Scope.of(context).role;
    return role == null ? const LoginScreen() : HomeScreen(key: ValueKey(role), role: role);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Role role = Role.farmer;
  late final name = TextEditingController(text: role.defaultName);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.eco, size: 64, color: kGreen),
                  const SizedBox(height: 8),
                  const Text('Agri Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text('Sàn Nông Sản Tận Vườn',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 28),
                  const Text('Bạn là ai?', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final r in Role.values)
                    Card(
                      elevation: 0,
                      color: r == role ? const Color(0xFFE8F5E9) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                            color: r == role ? kGreen : Colors.green.shade100,
                            width: r == role ? 2 : 1),
                      ),
                      child: ListTile(
                        leading: Icon(r.icon, color: r.color),
                        title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(r.desc),
                        trailing: r == role ? const Icon(Icons.check_circle, color: kGreen) : null,
                        onTap: () => setState(() {
                          role = r;
                          name.text = r.defaultName;
                        }),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: role == Role.merchant ? 'Tên công ty' : 'Tên hiển thị',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Scope.of(context).login(role, name.text),
                    child: Text('Vào với vai trò ${role.label}'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.role});
  final Role role;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final s = Scope.of(context);
    // (nhãn, icon, trang) theo quyền của vai trò
    final r = widget.role;
    // Mỗi vai trò có bộ màn hình riêng, không dùng chung.
    final tabs = switch (r) {
      Role.farmer => <(String, IconData, Widget)>[
          ('Lô Của Tôi', Icons.agriculture, FarmerPage(onPost: () => showLotForm(context))),
          ('AI Giá', Icons.camera_alt, const AiGradePage()),
          ('Giá Thị Trường', Icons.show_chart, const MarketPage()),
          ('Gom Đơn', Icons.groups, const FarmerPoolPage()),
          ('Ví Nhận Cọc', Icons.account_balance_wallet, const FarmerWalletPage()),
          ('Nhật Ký', Icons.menu_book, const LedgerPage()),
          ('Lịch Xem Vườn', Icons.fact_check, const FarmerSurveyPage()),
        ],
      Role.merchant => <(String, IconData, Widget)>[
          ('Sàn Thu Mua', Icons.storefront, const MerchantPage()),
          ('Giá Thị Trường', Icons.show_chart, const MarketPage()),
          ('Đấu Giá', Icons.gavel, const MerchantAuctionPage()),
          ('Ví Tạm Giữ', Icons.account_balance_wallet, const MerchantWalletPage()),
          ('Khảo Sát', Icons.fact_check, const MerchantSurveyPage()),
          ('Nhật Ký', Icons.menu_book, const LedgerPage()),
        ],
      Role.admin => <(String, IconData, Widget)>[
          ('Tổng Quan', Icons.dashboard, AdminPage(onCreate: () => showLotForm(context))),
          ('Giao Dịch', Icons.shield, const AdminEscrowPage()),
          ('Gom Đơn', Icons.groups, const AdminPoolPage()),
          ('Khảo Sát', Icons.fact_check, const AdminSurveyPage()),
          ('Nhật Ký', Icons.menu_book, const LedgerPage()),
        ],
    };

    return DefaultTabController(
      length: tabs.length,
      child: _scaffold(context, s, tabs),
    );
  }

  Widget _scaffold(BuildContext context, AppState s, List<(String, IconData, Widget)> tabs) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.role.color,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(children: [
          const Icon(Icons.eco),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Agri Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: Chip(
              avatar: Icon(widget.role.icon, size: 16),
              label: Text('${widget.role.label} · ${s.userName}',
                  overflow: TextOverflow.ellipsis),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ]),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (i) => setState(() => idx = i),
          tabs: [for (final t in tabs) Tab(icon: Icon(t.$2), text: t.$1)],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: s.logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy),
        label: const Text('Hỏi AI'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ChatScreen())),
      ),
      body: IndexedStack(index: idx, children: [for (final t in tabs) t.$3]),
    );
  }
}
