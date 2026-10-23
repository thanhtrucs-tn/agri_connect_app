import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Role {
  farmer('Nông Dân', 'Đăng lô, AI chấm ảnh, gom đơn, nhận cọc', Icons.agriculture, 'Chú Hai Xoàn', Color(0xFF2E7D32)),
  merchant('Thương Gia', 'Xem lô, báo giá, đấu giá gom đơn, nạp cọc', Icons.storefront, 'VinaAgr', Color(0xFF1565C0)),
  admin('Admin', 'Giám sát sàn, duyệt lô, xử lý tranh chấp', Icons.admin_panel_settings, 'Quản trị viên', Color(0xFF6A1B9A));

  const Role(this.label, this.desc, this.icon, this.defaultName, this.color);
  final String label;
  final String desc;
  final IconData icon;
  final String defaultName;
  final Color color;
}

/// Danh mục trái cây và giá tham khảo (VNĐ/kg) để làm dữ liệu mẫu.
const kFruits = <String, int>{
  'Sầu riêng': 85000,
  'Xoài': 45000,
  'Thanh long': 25000,
  'Chôm chôm': 30000,
  'Măng cụt': 60000,
  'Bưởi': 35000,
  'Cam': 22000,
  'Chuối': 15000,
  'Dưa hấu': 12000,
  'Nhãn': 28000,
  'Vải': 40000,
  'Thơm': 10000,
  'Mít': 20000,
  'Khác': 20000,
};

class PoolMember {
  PoolMember(this.owner, this.kg, this.lotName);
  final String owner;
  final int kg;
  final String lotName;
}

class Bid {
  Bid(this.company, this.price, this.at);
  final String company;
  final int price;
  final DateTime at;
}

/// Lô gom từ nhiều vườn nhỏ, đấu giá trong 24h: giá cao nhất thắng.
class Pool {
  Pool({
    required this.id,
    required this.fruit,
    required this.province,
    required this.members,
    required this.endsAt,
  });
  final int id;
  final String fruit;
  final String province;
  final List<PoolMember> members;
  final DateTime endsAt;
  final List<Bid> bids = [];
  bool closed = false;
  String? winner;

  int get totalKg => members.fold(0, (a, m) => a + m.kg);
  Bid? get best => bids.isEmpty ? null : (bids.toList()..sort((a, b) => b.price.compareTo(a.price))).first;
}

enum DealStatus {
  awaitingDeposit('Chờ bên mua nạp cọc'),
  held('Cọc đang được giữ'),
  delivered('Đã giao – chờ xác nhận'),
  released('Hoàn tất – đã chuyển cọc'),
  disputed('Tranh chấp – chờ admin'),
  refunded('Đã hoàn cọc cho bên mua');

  const DealStatus(this.label);
  final String label;
}

/// Giao dịch có ví tạm giữ (escrow): bên mua cọc 20%.
class Deal {
  Deal({
    required this.id,
    required this.title,
    required this.buyer,
    required this.shares,
    required this.price,
    this.ref,
  });
  final int id;
  final String title;
  final String buyer;
  final Map<String, int> shares; // nông dân → kg
  final int price; // VNĐ/kg
  final Object? ref; // Lot hoặc Pool tạo ra giao dịch
  DealStatus status = DealStatus.awaitingDeposit;

  int get kg => shares.values.fold(0, (a, b) => a + b);
  int get total => kg * price;
  int get deposit => (total * 0.2).round();
}

const kLedgerTypes = ['Bán', 'Mua', 'Xuất hàng', 'Nhận hàng', 'Cọc', 'Gom đơn', 'Ghi chú'];

/// Mỗi vai trò chỉ dùng các loại mục phù hợp với mình.
const kTypesByRole = {
  Role.farmer: ['Bán', 'Xuất hàng', 'Cọc', 'Gom đơn', 'Ghi chú'],
  Role.merchant: ['Mua', 'Nhận hàng', 'Cọc', 'Gom đơn', 'Ghi chú'],
  Role.admin: kLedgerTypes,
};

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.user,
    required this.date,
    required this.type,
    required this.title,
    this.amount,
    this.note = '',
  });
  final int id;
  final String user;
  final DateTime date;
  String type;
  String title;
  int? amount;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': user,
        'date': date.toIso8601String(),
        'type': type,
        'title': title,
        'amount': amount,
        'note': note,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as int,
        user: j['user'] as String,
        date: DateTime.parse(j['date'] as String),
        type: j['type'] as String,
        title: j['title'] as String,
        amount: j['amount'] as int?,
        note: (j['note'] as String?) ?? '',
      );
}

/// Lịch thương gia xem vườn / khảo sát chất lượng.
class Survey {
  Survey({
    required this.id,
    required this.buyer,
    required this.lot,
    required this.date,
    this.status = 'Chờ xác nhận',
    this.result = '',
  });
  final int id;
  final String buyer;
  final Lot lot;
  final DateTime date;
  String status; // Chờ xác nhận → Đã hẹn / Từ chối → Đã khảo sát
  String result;
}

/// Điểm uy tín: 3 tiêu chí (0–1) + điểm sao trung bình (0–5).
class Rep {
  Rep(this.stars, this.deals, this.onTime, this.keptPrice, this.deposit);
  double stars;
  int deals;
  final double onTime; // đến xem vườn / giao hàng đúng hẹn
  final double keptPrice; // giữ đúng giá/sản lượng đã báo
  final double deposit; // đặt cọc / nhận cọc đúng hạn
}

class Offer {
  Offer(this.company, this.price, this.deposit, this.transport);
  final String company;
  final int price; // VND/kg
  final String deposit;
  final String transport;
}

class Lot {
  Lot({
    required this.fruit,
    required this.name,
    required this.owner,
    required this.phone,
    required this.volumeKg,
    required this.standard,
    required this.address,
    required this.startPrice,
    required this.harvestDate,
    this.status = 'Chờ duyệt',
    this.aiNote,
    List<Offer>? offers,
  }) : offers = offers ?? [];

  final String fruit;
  final String name;
  final String owner;
  final String phone;
  final int volumeKg;
  final String standard;
  final String address;
  final int startPrice;
  final DateTime harvestDate;
  String status;
  final List<Offer> offers;
  Offer? selected;
  bool rated = false;
  bool pooled = false;
  final String? aiNote; // kết quả AI chấm ảnh khi đăng lô
  String get province => address.split(',').last.trim();

  List<Offer> get sortedOffers =>
      [...offers]..sort((a, b) => b.price.compareTo(a.price));
  int get bestPrice => sortedOffers.isEmpty ? startPrice : sortedOffers.first.price;
  int get proceeds => volumeKg * (selected?.price ?? bestPrice);
}

class AppState extends ChangeNotifier {
  AppState() {
    lots.add(Lot(
      fruit: 'Sầu riêng',
      name: 'Sầu Riêng Ri6',
      owner: 'Chú Hai Xoàn',
      phone: '0903 123 456',
      volumeKg: 8000,
      standard: 'VietGAP',
      address: 'Ấp Phú Thạnh, Cai Lậy, Tiền Giang',
      startPrice: 80000,
      harvestDate: DateTime(2026, 10, 25),
      status: 'Đang đấu giá',
      offers: [
        Offer('VinaAgr', 85000, 'Cọc 30%', 'Thương gia lo xe'),
        Offer('Hoàng Gia Fruit', 83500, 'Cọc 20%', 'Thương gia lo xe'),
        Offer('Mekong Export', 82000, 'Cọc 25%', 'Nông dân giao hàng'),
      ],
    ));
    lots.add(Lot(
      fruit: 'Xoài',
      name: 'Xoài Cát Hòa Lộc',
      owner: 'Cô Ba Lài',
      phone: '0912 555 789',
      volumeKg: 5000,
      standard: 'GlobalGAP',
      address: 'Xã Mỹ Xương, Cao Lãnh, Đồng Tháp',
      startPrice: 45000,
      harvestDate: DateTime(2026, 10, 30),
      status: 'Đang đấu giá',
    ));
    lots.add(Lot(
      fruit: 'Thanh long',
      name: 'Thanh Long Ruột Đỏ',
      owner: 'Bác Tư Hiền',
      phone: '0988 222 111',
      volumeKg: 12000,
      standard: 'VietGAP',
      address: 'Xã Hàm Minh, Hàm Thuận Nam, Bình Thuận',
      startPrice: 24000,
      harvestDate: DateTime(2026, 10, 28),
      status: 'Đang đấu giá',
      offers: [
        Offer('Hoàng Gia Fruit', 26500, 'Cọc 20%', 'Thương gia lo xe'),
        Offer('Mekong Export', 25800, 'Cọc 30%', 'Thương gia lo xe'),
      ],
    ));
    // Lô gom mẫu: 3 vườn nhỏ ở Bình Thuận = 5 tấn, đang đấu giá.
    final small = [
      ('Anh Út Nhỏ', 1800),
      ('Chị Tám Hạnh', 1600),
      ('Chú Năm Đen', 1600),
    ];
    for (final m in small) {
      lots.add(Lot(
        fruit: 'Thanh long',
        name: 'Thanh Long Ruột Trắng',
        owner: m.$1,
        phone: '0900 000 000',
        volumeKg: m.$2,
        standard: 'VietGAP',
        address: 'Xã Hàm Thắng, Hàm Thuận Bắc, Bình Thuận',
        startPrice: 22000,
        harvestDate: DateTime(2026, 10, 29),
        status: 'Đã gom lô',
      )..pooled = true);
    }
    final seedPool = Pool(
      id: 1,
      fruit: 'Thanh long',
      province: 'Bình Thuận',
      members: [for (final m in small) PoolMember(m.$1, m.$2, 'Thanh Long Ruột Trắng')],
      endsAt: DateTime.now().add(const Duration(hours: 16)),
    );
    seedPool.bids
      ..add(Bid('Hoàng Gia Fruit', 26000, DateTime.now().subtract(const Duration(hours: 5))))
      ..add(Bid('VinaAgr', 26800, DateTime.now().subtract(const Duration(hours: 2))));
    pools.add(seedPool);
    // Thêm 2 lô xoài cùng vùng Đồng Tháp để app gợi ý gom tự động.
    lots.add(Lot(
      fruit: 'Xoài',
      name: 'Xoài Cát Chu',
      owner: 'Anh Sáu Nghĩa',
      phone: '0933 111 222',
      volumeKg: 2500,
      standard: 'VietGAP',
      address: 'Xã Mỹ Hiệp, Cao Lãnh, Đồng Tháp',
      startPrice: 40000,
      harvestDate: DateTime(2026, 11, 1),
      status: 'Đang đấu giá',
    ));
    lots.add(Lot(
      fruit: 'Xoài',
      name: 'Xoài Cát Chu',
      owner: 'Chị Bảy Thu',
      phone: '0944 333 444',
      volumeKg: 1800,
      standard: 'VietGAP',
      address: 'Xã Tân Thuận, Cao Lãnh, Đồng Tháp',
      startPrice: 40000,
      harvestDate: DateTime(2026, 11, 2),
      status: 'Đang đấu giá',
    ));
    // Thêm 2 lô xoài cùng vùng Tiền Giang (gợi ý gom cho Chú Hai Xoàn).
    lots.add(Lot(
      fruit: 'Xoài',
      name: 'Xoài Cát Chu',
      owner: 'Chú Hai Xoàn',
      phone: '0903 123 456',
      volumeKg: 2000,
      standard: 'VietGAP',
      address: 'Ấp Mỹ Thạnh, Cai Lậy, Tiền Giang',
      startPrice: 42000,
      harvestDate: DateTime(2026, 11, 3),
      status: 'Đang đấu giá',
    ));
    lots.add(Lot(
      fruit: 'Xoài',
      name: 'Xoài Cát Chu',
      owner: 'Anh Tư Bền',
      phone: '0955 666 777',
      volumeKg: 1500,
      standard: 'VietGAP',
      address: 'Xã Hòa Khánh, Cái Bè, Tiền Giang',
      startPrice: 42000,
      harvestDate: DateTime(2026, 11, 4),
      status: 'Đang đấu giá',
    ));
    surveys.addAll([
      Survey(id: 1, buyer: 'VinaAgr', lot: lots.first, date: DateTime(2026, 10, 22), status: 'Đã hẹn'),
      Survey(id: 2, buyer: 'Hoàng Gia Fruit', lot: lots.first, date: DateTime(2026, 10, 23)),
      Survey(id: 3, buyer: 'Mekong Export', lot: lots[1], date: DateTime(2026, 10, 27)),
    ]);
  }

  static const today = 20; // ngày hiện tại trong tháng 10/2026 (demo)

  final List<Lot> lots = [];
  final visitDate = DateTime(2026, 10, 22);
  final visitBuyer = 'VinaAgr';

  // Dữ liệu uy tín mẫu. Người dùng mới chưa có → hiện "Mới tham gia".
  final reps = <String, Rep>{
    'VinaAgr': Rep(4.8, 42, 0.97, 0.95, 1.0),
    'Hoàng Gia Fruit': Rep(4.5, 27, 0.92, 0.90, 0.96),
    'Mekong Export': Rep(3.6, 11, 0.70, 0.65, 0.82),
    'Chú Hai Xoàn': Rep(4.9, 18, 0.98, 0.97, 1.0),
    'Cô Ba Lài': Rep(4.2, 9, 0.90, 0.85, 1.0),
    'Bác Tư Hiền': Rep(4.6, 14, 0.94, 0.92, 1.0),
  };
  bool sortByRep = false;

  Rep? repOf(String name) => reps[name];

  List<Offer> sortedFor(Lot l) {
    final o = l.sortedOffers;
    if (sortByRep) {
      o.sort((a, b) {
        final c = (repOf(b.company)?.stars ?? 0).compareTo(repOf(a.company)?.stars ?? 0);
        return c != 0 ? c : b.price.compareTo(a.price);
      });
    }
    return o;
  }

  void setSortByRep(bool v) {
    sortByRep = v;
    notifyListeners();
  }

  /// Đánh giá đối tác sau giao dịch (1–5 sao).
  void rate(String name, int stars, {Lot? lot}) {
    final r = reps[name];
    if (r == null) {
      reps[name] = Rep(stars.toDouble(), 1, 1, 1, 1);
    } else {
      r.stars = (r.stars * r.deals + stars) / (r.deals + 1);
      r.deals++;
    }
    lot?.rated = true;
    notifyListeners();
  }

  Role? role;
  String userName = '';

  void login(Role r, String name) {
    role = r;
    userName = name.trim().isEmpty ? r.defaultName : name.trim();
    wallets.putIfAbsent(userName, () => r == Role.merchant ? 50000000 : 0);
    notifyListeners();
  }

  void logout() {
    role = null;
    userName = '';
    notifyListeners();
  }

  List<Lot> get myLots => lots.where((l) => l.owner == userName).toList();


  /// Loại trái cây đang xem ở biểu đồ giá thị trường (dùng chung giữa các màn hình).
  String marketFruit = 'Sầu riêng';

  void setMarketFruit(String f) {
    marketFruit = f;
    notifyListeners();
  }

  /// Giá thị trường mẫu [days] ngày gần nhất, ngày cuối = giá hôm nay.
  /// Xác định theo tên trái cây nên 7 ngày cuối của chuỗi 30/90 ngày luôn khớp với chuỗi 7 ngày.
  List<int> priceSeries(String fruit, int days) {
    final base = (kFruits[fruit] ?? 20000).toDouble();
    final seed = fruit.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0xffff);
    final r = Random(seed);
    final out = List<double>.filled(days, base);
    for (var i = days - 2; i >= 0; i--) {
      final step = (r.nextDouble() - 0.5) * 0.06; // biến động ngẫu nhiên ±3%/ngày
      final pull = (base - out[i + 1]) / base * 0.03; // kéo nhẹ về giá gốc
      out[i] = (out[i + 1] * (1 - step + pull)).clamp(base * 0.6, base * 1.5);
    }
    return [for (final v in out) (v / 100).round() * 100];
  }

  /// Giá TB 7 ngày gần nhất của một loại trái cây (dữ liệu mẫu).
  List<int> pricesFor(String fruit) => priceSeries(fruit, 7);

  // ─────────── Lịch khảo sát vườn ───────────
  final surveys = <Survey>[];

  /// Thương gia đặt lịch xem vườn. Trả về lỗi hoặc null.
  String? requestSurvey(Lot l, DateTime date) {
    if (role != Role.merchant) return 'Chỉ thương gia mới đặt lịch xem vườn';
    if (surveys.any((x) => x.buyer == userName && identical(x.lot, l) && x.status != 'Từ chối' && x.status != 'Đã khảo sát')) {
      return 'Bạn đã có lịch xem vườn này';
    }
    surveys.insert(0, Survey(id: _seq++, buyer: userName, lot: l, date: date));
    log(userName, 'Ghi chú', 'Đặt lịch xem vườn "${l.name}" của ${l.owner} ngày ${fmtDate(date)}');
    log(l.owner, 'Ghi chú', '$userName xin xem vườn "${l.name}" ngày ${fmtDate(date)}');
    return null;
  }

  /// Nông dân xác nhận hoặc từ chối lịch.
  void answerSurvey(Survey sv, bool accept) {
    if (role != Role.farmer || sv.lot.owner != userName || sv.status != 'Chờ xác nhận') return;
    sv.status = accept ? 'Đã hẹn' : 'Từ chối';
    log(userName, 'Ghi chú', '${accept ? "Xác nhận" : "Từ chối"} lịch xem vườn của ${sv.buyer} ngày ${fmtDate(sv.date)}');
    log(sv.buyer, 'Ghi chú',
        '${sv.lot.owner} ${accept ? "đã xác nhận" : "từ chối"} lịch xem vườn "${sv.lot.name}" ngày ${fmtDate(sv.date)}');
  }

  /// Thương gia ghi kết quả sau khi đến vườn.
  void completeSurvey(Survey sv, String result) {
    if (role != Role.merchant || sv.buyer != userName || sv.status != 'Đã hẹn') return;
    sv.status = 'Đã khảo sát';
    sv.result = result;
    log(userName, 'Ghi chú', 'Đã khảo sát vườn "${sv.lot.name}" của ${sv.lot.owner}', note: result);
    log(sv.lot.owner, 'Ghi chú', '${sv.buyer} đã khảo sát vườn "${sv.lot.name}"', note: result);
  }

  // ─────────── Gom đơn & đấu giá ngược ───────────
  final pools = <Pool>[];
  final deals = <Deal>[];
  final wallets = <String, int>{};
  final ledger = <LedgerEntry>[];
  int _seq = 100;

  int balance(String u) => wallets[u] ?? 0;

  /// Nhóm các lô cùng loại trái cây, cùng tỉnh, chưa gom (từ 2 lô trở lên).
  List<List<Lot>> poolSuggestions() {
    final g = <String, List<Lot>>{};
    for (final l in lots.where((l) => !l.pooled && l.fruit != 'Khác')) {
      g.putIfAbsent('${l.fruit}|${l.province}', () => []).add(l);
    }
    return g.values.where((v) => v.length >= 2).toList();
  }

  void createPool(List<Lot> group) {
    final ok = role == Role.admin || (role == Role.farmer && group.any((l) => l.owner == userName));
    if (!ok) return;
    final p = Pool(
      id: _seq++,
      fruit: group.first.fruit,
      province: group.first.province,
      members: [for (final l in group) PoolMember(l.owner, l.volumeKg, l.name)],
      endsAt: DateTime.now().add(const Duration(hours: 24)),
    );
    for (final l in group) {
      l.pooled = true;
      l.status = 'Đã gom lô';
      log(l.owner, 'Gom đơn',
          'Lô "${l.name}" (${vnd(l.volumeKg)} kg) được gom vào lô ${p.fruit} ${p.province} – tổng ${vnd(p.totalKg)} kg');
    }
    pools.insert(0, p);
    notifyListeners();
  }

  /// Trả về thông báo lỗi, hoặc null nếu đặt giá thành công.
  String? placeBid(Pool p, int price) {
    if (role != Role.merchant) return 'Chỉ thương gia mới được đặt giá';
    if (p.closed) return 'Phiên đấu giá đã kết thúc';
    if (price <= 0) return 'Vui lòng nhập giá hợp lệ';
    final b = p.best;
    if (b != null && price <= b.price) return 'Giá phải cao hơn ${vnd(b.price)} đ/kg';
    p.bids.add(Bid(userName, price, DateTime.now()));
    log(userName, 'Mua', 'Đặt giá ${vnd(price)} đ/kg cho lô gom ${p.fruit} ${p.province} (${vnd(p.totalKg)} kg)');
    return null;
  }

  void closePool(Pool p) {
    if (p.closed) return;
    p.closed = true;
    final b = p.best;
    if (b == null) {
      for (final m in p.members) {
        log(m.owner, 'Gom đơn', 'Phiên đấu giá lô ${p.fruit} ${p.province} kết thúc, chưa có ai đặt giá');
      }
    } else {
      p.winner = b.company;
      final shares = <String, int>{};
      for (final m in p.members) {
        shares[m.owner] = (shares[m.owner] ?? 0) + m.kg;
      }
      final d = Deal(
        id: _seq++,
        title: 'Lô gom ${p.fruit} ${p.province}',
        buyer: b.company,
        shares: shares,
        price: b.price,
        ref: p,
      );
      deals.insert(0, d);
      log(b.company, 'Mua', 'Thắng đấu giá ${d.title}: ${vnd(d.kg)} kg × ${vnd(d.price)} đ/kg', amount: d.total);
      for (final e in shares.entries) {
        log(e.key, 'Bán', '${d.title} bán cho ${b.company}: phần của bạn ${vnd(e.value)} kg × ${vnd(d.price)} đ/kg',
            amount: e.value * d.price);
      }
    }
    notifyListeners();
  }

  void closeExpired() {
    final now = DateTime.now();
    for (final p in pools.toList()) {
      if (!p.closed && now.isAfter(p.endsAt)) closePool(p);
    }
  }

  // ─────────── Ví tạm giữ (escrow) ───────────
  void topUp(int amount) {
    if (role != Role.merchant) return;
    wallets[userName] = balance(userName) + amount;
    log(userName, 'Ghi chú', 'Nạp ví +${vnd(amount)} đ', amount: amount);
  }

  /// Trả về thông báo lỗi, hoặc null nếu thành công.
  String? payDeposit(Deal d) {
    if (role != Role.merchant || userName != d.buyer) return 'Chỉ bên mua mới được nạp cọc';
    if (d.status != DealStatus.awaitingDeposit) return 'Giao dịch không ở bước nạp cọc';
    if (balance(d.buyer) < d.deposit) {
      return 'Số dư ví không đủ. Cần ${vnd(d.deposit)} đ, hiện có ${vnd(balance(d.buyer))} đ';
    }
    wallets[d.buyer] = balance(d.buyer) - d.deposit;
    d.status = DealStatus.held;
    log(d.buyer, 'Cọc', 'Nạp cọc 20% (${vnd(d.deposit)} đ) vào ví tạm giữ – ${d.title}', amount: d.deposit);
    for (final s in d.shares.keys) {
      log(s, 'Cọc', '${d.buyer} đã nạp cọc ${vnd(d.deposit)} đ vào ví tạm giữ – ${d.title}');
    }
    return null;
  }

  void markDelivered(Deal d) {
    if (role != Role.farmer || !d.shares.containsKey(userName)) return;
    if (d.status != DealStatus.held) return;
    d.status = DealStatus.delivered;
    for (final e in d.shares.entries) {
      log(e.key, 'Xuất hàng', 'Đã giao ${vnd(e.value)} kg – ${d.title}');
    }
    log(d.buyer, 'Nhận hàng', 'Nông dân báo đã giao hàng – ${d.title}, chờ bạn xác nhận');
  }

  void _payout(Deal d) {
    for (final e in d.shares.entries) {
      final amt = (d.deposit * e.value / d.kg).round();
      wallets[e.key] = balance(e.key) + amt;
      log(e.key, 'Cọc', 'Nhận ${vnd(amt)} đ tiền cọc từ ví tạm giữ – ${d.title}', amount: amt);
    }
    d.status = DealStatus.released;
  }

  void confirmDelivery(Deal d) {
    if (role != Role.merchant || userName != d.buyer) return;
    if (d.status != DealStatus.delivered) return;
    _payout(d);
    log(d.buyer, 'Mua', 'Xác nhận hàng đúng chất lượng – ${d.title}. Tiền cọc đã chuyển cho nông dân');
  }

  void dispute(Deal d) {
    if (role != Role.merchant || userName != d.buyer) return;
    if (d.status != DealStatus.delivered) return;
    d.status = DealStatus.disputed;
    log(d.buyer, 'Ghi chú', 'Báo hàng không đạt – ${d.title}. Chờ admin xử lý');
    for (final s in d.shares.keys) {
      log(s, 'Ghi chú', '${d.buyer} báo hàng không đạt – ${d.title}. Chờ admin xử lý');
    }
  }

  void resolve(Deal d, {required bool toFarmer}) {
    if (role != Role.admin) return;
    if (d.status != DealStatus.disputed) return;
    if (toFarmer) {
      _payout(d);
    } else {
      wallets[d.buyer] = balance(d.buyer) + d.deposit;
      d.status = DealStatus.refunded;
      log(d.buyer, 'Cọc', 'Admin hoàn cọc ${vnd(d.deposit)} đ – ${d.title}', amount: d.deposit);
    }
    notifyListeners();
  }

  // ─────────── Nhật ký ───────────
  void log(String user, String type, String title, {int? amount, String note = ''}) {
    ledger.insert(
      0,
      LedgerEntry(
          id: _seq++, user: user, date: DateTime.now(), type: type, title: title, amount: amount, note: note),
    );
    _saveLedger();
    notifyListeners();
  }

  void touchLedger() {
    _saveLedger();
    notifyListeners();
  }

  void deleteEntry(LedgerEntry e) {
    ledger.remove(e);
    touchLedger();
  }

  Future<void> loadLedger() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('ledger');
      if (raw != null) {
        ledger
          ..clear()
          ..addAll((jsonDecode(raw) as List).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // Không có bộ nhớ cục bộ (vd. khi chạy test): dùng dữ liệu trong RAM.
    }
    if (ledger.isEmpty) {
      final now = DateTime.now();
      ledger.addAll([
        LedgerEntry(
            id: 1,
            user: 'Chú Hai Xoàn',
            date: now.subtract(const Duration(days: 3)),
            type: 'Bán',
            title: 'Bán 6 tấn chôm chôm cho Hoàng Gia Fruit',
            amount: 168000000,
            note: 'Đã nhận đủ tiền, giao tại vườn'),
        LedgerEntry(
            id: 2,
            user: 'Chú Hai Xoàn',
            date: now.subtract(const Duration(days: 1)),
            type: 'Ghi chú',
            title: 'Nhớ gọi VinaAgr xác nhận lịch xem vườn 22/10'),
      ]);
    }
    notifyListeners();
  }

  Future<void> _saveLedger() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('ledger', jsonEncode(ledger.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void addLot(Lot l) {
    if (role != Role.farmer && role != Role.admin) return;
    lots.insert(0, l);
    notifyListeners();
  }

  void addOffer(Lot l, Offer o) {
    if (role != Role.merchant) return;
    l.offers.add(o);
    notifyListeners();
  }

  void selectOffer(Lot l, Offer o) {
    if (role != Role.farmer || l.owner != userName) return;
    final existing = deals.where((d) => identical(d.ref, l)).firstOrNull;
    if (existing != null && existing.status != DealStatus.awaitingDeposit) return;
    l.selected = o;
    deals.removeWhere((d) => identical(d.ref, l));
    final d = Deal(
      id: _seq++,
      title: l.name,
      buyer: o.company,
      shares: {l.owner: l.volumeKg},
      price: o.price,
      ref: l,
    );
    deals.insert(0, d);
    log(l.owner, 'Bán', 'Chốt bán "${l.name}" cho ${o.company}: ${vnd(l.volumeKg)} kg × ${vnd(o.price)} đ/kg',
        amount: d.total);
    log(o.company, 'Mua', 'Chốt mua "${l.name}" của ${l.owner}: ${vnd(l.volumeKg)} kg × ${vnd(o.price)} đ/kg',
        amount: d.total);
  }

  void setStatus(Lot l, String s) {
    if (role != Role.admin) return;
    l.status = s;
    notifyListeners();
  }

  void removeLot(Lot l) {
    if (role != Role.admin) return;
    lots.remove(l);
    notifyListeners();
  }
}

String vnd(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child})
      : super(notifier: state);
  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}
