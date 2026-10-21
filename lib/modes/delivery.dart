import 'dart:math';

import '../data/models.dart';

/// "Kapında" paket servis: siparişler uygulamadan düşer; hazırlanan dürüm ısı kutusuna konur;
/// kurye belirli aralıkla gelip kutudakileri alır (zamanında teslim ödemeyi belirler).
class DeliveryOrder {
  DeliveryOrder({required this.id, required this.spec, required this.deadline}) : left = deadline;
  final int id;
  final OrderSpec spec;
  final double deadline; // toplam süre (sn)
  double left;
  Assembly? boxed; // kutuya konulan dürüm
  double boxedAge = 0; // kutuda geçen süre (sn)
  bool get isBoxed => boxed != null;
  double get fraction => deadline <= 0 ? 0 : (left / deadline).clamp(0.0, 1.0);
}

/// Kurye gelişinde bir siparişin sonucu.
class DeliveryOutcome {
  const DeliveryOutcome({required this.order, required this.onTime, required this.cold, this.made});
  final DeliveryOrder order;
  final bool onTime;
  final bool cold; // kutuda fazla bekleyip soğudu
  final Assembly? made; // null = teslim edilmedi
}

class DeliveryState {
  DeliveryState({this.maxPending = 3, this.visibleCourier = false});

  final int maxPending;

  /// true: kurye gelince kapıda bekler ([courierHere]) ve paketleri oyuncu [handOver] ile verir;
  /// false: eski davranış, kurye gelince kutudakiler kendiliğinden teslim olur.
  final bool visibleCourier;
  final List<DeliveryOrder> orders = [];
  double spawnTimer = 12;
  double courierLeft = 40;
  bool courierHere = false;
  double courierWait = 0; // kapıdaki kuryenin kalan bekleme süresi
  int courierMisses = 0; // art arda paket almadan giden ziyaret
  int _nextId = 1;

  /// Isı kutusu kapasitesi: Dağıtım Motoru seviyesiyle artar.
  int boxCapacity(int dagitimLevel) => 3 + dagitimLevel;
  double courierInterval(int dagitimLevel) => max(24.0, 42.0 - 6.0 * dagitimLevel);
  static const double coldAfter = 38; // kutuda bu kadar beklerse soğur
  static const double courierWaitSeconds = 12; // kurye kapıda bu kadar bekler

  int get boxedCount => orders.where((o) => o.isBoxed).length;

  Map<String, dynamic> toJson() => {
        'sp': spawnTimer,
        'cl': courierLeft,
        'ch': courierHere,
        'cm': courierMisses,
        'id': _nextId,
        'o': [
          for (final o in orders) {'i': o.id, 's': o.spec.toJson(), 'd': o.deadline, 'l': o.left, 'b': o.boxed?.toJson(), 'a': o.boxedAge}
        ],
      };

  void fromJson(Map<String, dynamic> j) {
    spawnTimer = (j['sp'] as num).toDouble();
    courierLeft = (j['cl'] as num).toDouble();
    courierHere = (j['ch'] as bool?) ?? false;
    courierMisses = (j['cm'] as int?) ?? 0;
    _nextId = (j['id'] as int?) ?? 1;
    orders
      ..clear()
      ..addAll([
        for (final m in (j['o'] as List).cast<Map<String, dynamic>>())
          DeliveryOrder(id: m['i'] as int, spec: OrderSpec.fromJson(m['s'] as Map<String, dynamic>), deadline: (m['d'] as num).toDouble())
            ..left = (m['l'] as num).toDouble()
            ..boxed = m['b'] == null ? null : Assembly.fromJson(m['b'] as Map<String, dynamic>)
            ..boxedAge = (m['a'] as num).toDouble()
      ]);
  }

  void reset(int dagitimLevel) {
    orders.clear();
    spawnTimer = 10;
    courierLeft = courierInterval(dagitimLevel);
    courierHere = false;
    courierWait = 0;
    courierMisses = 0;
  }

  /// Kapıdaki kuryeye kutudaki tüm paketleri verir; teslim sonuçlarını döndürür ve kuryeyi uğurlar.
  List<DeliveryOutcome> handOver(int dagitimLevel) {
    final results = <DeliveryOutcome>[];
    for (final o in List.of(orders)) {
      if (o.isBoxed) {
        results.add(DeliveryOutcome(order: o, onTime: o.left > -2, cold: o.boxedAge > coldAfter, made: o.boxed));
        orders.remove(o);
      }
    }
    courierHere = false;
    courierMisses = results.isEmpty ? courierMisses : 0;
    courierLeft = courierInterval(dagitimLevel);
    return results;
  }

  /// Kurye beklemekten vazgeçti (paket alınmadı).
  void courierLeaves(int dagitimLevel) {
    courierHere = false;
    courierMisses++;
    courierLeft = courierInterval(dagitimLevel);
  }

  /// Zamanı ilerlet. [newSpec]: yeni sipariş üretici, [spawning]: yeni sipariş gelsin mi.
  /// Kurye geldiyse sonuçları döndürür.
  List<DeliveryOutcome> tick(double dt, {required OrderSpec Function() newSpec, required bool spawning, required int dagitimLevel, required double deadline}) {
    final results = <DeliveryOutcome>[];
    for (final o in orders) {
      o.left -= dt;
      if (o.isBoxed) o.boxedAge += dt;
    }
    if (spawning) {
      spawnTimer -= dt;
      if (spawnTimer <= 0 && orders.length < maxPending) {
        orders.add(DeliveryOrder(id: _nextId++, spec: newSpec(), deadline: deadline));
        spawnTimer = 24 + (orders.length * 6);
      } else if (spawnTimer <= 0) {
        spawnTimer = 4;
      }
    }
    if (!courierHere) courierLeft -= dt;
    if (courierLeft <= 0 && !courierHere) {
      if (visibleCourier) {
        courierHere = true; // kapıda bekler; oyuncu paketleri verir
        courierWait = courierWaitSeconds;
        courierLeft = courierInterval(dagitimLevel);
      } else {
        courierLeft = courierInterval(dagitimLevel);
        for (final o in List.of(orders)) {
          if (o.isBoxed) {
            results.add(DeliveryOutcome(order: o, onTime: o.left > -2, cold: o.boxedAge > coldAfter, made: o.boxed));
            orders.remove(o);
          }
        }
      }
    }
    // süresi dolmuş ve kutuda olmayanlar iptal olur
    for (final o in List.of(orders)) {
      if (!o.isBoxed && o.left <= -2) {
        results.add(DeliveryOutcome(order: o, onTime: false, cold: false));
        orders.remove(o);
      }
    }
    return results;
  }

  /// Hazırlanan dürümü [index]'teki siparişin kutusuna koyar.
  bool box(int index, Assembly made, int dagitimLevel) {
    if (index < 0 || index >= orders.length) return false;
    final o = orders[index];
    if (o.isBoxed || boxedCount >= boxCapacity(dagitimLevel)) return false;
    o.boxed = made.copy();
    o.boxedAge = 0;
    return true;
  }
}
