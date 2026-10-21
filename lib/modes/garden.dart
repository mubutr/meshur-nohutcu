import 'dart:convert';

/// Bahçe: parsellere ekim, sulama, hasat. Büyüme günlük işler (gün bitince ilerler).
class CropDef {
  const CropDef({required this.id, required this.name, required this.seed, required this.days, required this.yield});
  final String id;
  final String name;
  final int seed; // tohum maliyeti
  final int days; // olgunlaşmak için sulanmış gün sayısı
  final int yield; // hasatta stoğa eklenen birim

  factory CropDef.fromJson(Map<String, dynamic> j) =>
      CropDef(id: j['id'] as String, name: j['name'] as String, seed: j['seed'] as int, days: j['days'] as int, yield: j['yield'] as int);
}

class GardenConfig {
  const GardenConfig({required this.crops, required this.plotsBase, required this.freshBonus, required this.marketPiyaz, required this.marketAci, required this.maxDry});
  final List<CropDef> crops;
  final int plotsBase;
  final double freshBonus; // taze malzeme kazanç artışı
  final int marketPiyaz; // stok yoksa pazardan piyaz malzemesi maliyeti
  final int marketAci;
  final int maxDry; // art arda susuz kalınca bitki kurur

  factory GardenConfig.fromJson(Map<String, dynamic> j) => GardenConfig(
        crops: (j['crops'] as List).map((e) => CropDef.fromJson(e as Map<String, dynamic>)).toList(),
        plotsBase: j['plotsBase'] as int,
        freshBonus: (j['freshBonus'] as num).toDouble(),
        marketPiyaz: j['marketPiyaz'] as int,
        marketAci: j['marketAci'] as int,
        maxDry: j['maxDry'] as int,
      );

  CropDef crop(String id) => crops.firstWhere((c) => c.id == id);
}

class Plot {
  String? crop;
  int grown = 0; // sulanmış gün sayısı
  bool wateredToday = false;
  int dry = 0; // art arda susuz gün

  bool get empty => crop == null;
}

class GardenState {
  GardenState(this.cfg);
  final GardenConfig cfg;
  final List<Plot> plots = [];
  final Map<String, int> stock = {'maydanoz': 0, 'sogan': 0, 'biber': 0};
  int witheredTotal = 0;

  void ensurePlots(int n) {
    while (plots.length < n) {
      plots.add(Plot());
    }
  }

  bool isReady(Plot p) => p.crop != null && p.grown >= cfg.crop(p.crop!).days;

  /// Ekim: tohum maliyeti ödenir. Başarılıysa true.
  bool plant(int i, String cropId, {required int money, required void Function(int cost) pay}) {
    final p = plots[i];
    final c = cfg.crop(cropId);
    if (!p.empty || money < c.seed) return false;
    pay(c.seed);
    p
      ..crop = cropId
      ..grown = 0
      ..dry = 0
      ..wateredToday = false;
    return true;
  }

  bool water(int i) {
    final p = plots[i];
    if (p.empty || p.wateredToday || isReady(p)) return false;
    p.wateredToday = true;
    return true;
  }

  int waterAll() {
    var n = 0;
    for (var i = 0; i < plots.length; i++) {
      if (water(i)) n++;
    }
    return n;
  }

  /// Hasat: stoğa ekler, eklenen miktarı döndürür (0 = hasat yok).
  int harvest(int i, void Function(String crop, int amount) onHarvest) {
    final p = plots[i];
    if (!isReady(p)) return 0;
    final c = cfg.crop(p.crop!);
    stock[c.id] = (stock[c.id] ?? 0) + c.yield;
    onHarvest(c.id, c.yield);
    p
      ..crop = null
      ..grown = 0
      ..dry = 0
      ..wateredToday = false;
    return c.yield;
  }

  /// Gün bitince: sulananlar büyür, sulanmayanlar susuz kalır; çok susuz kalan kurur.
  void endOfDay() {
    for (final p in plots) {
      if (p.empty) continue;
      if (isReady(p)) {
        p.wateredToday = false;
        continue;
      }
      if (p.wateredToday) {
        p.grown++;
        p.dry = 0;
      } else {
        p.dry++;
        if (p.dry >= cfg.maxDry) {
          p
            ..crop = null
            ..grown = 0
            ..dry = 0;
          witheredTotal++;
        }
      }
      p.wateredToday = false;
    }
  }

  /// Bir dürüm için taze stok kullan. Dönen değer: kullanılan taze malzeme sayısı ve pazardan alınan ek maliyet.
  ({int fresh, int marketCost, bool piyazFresh, bool aciFresh}) consume({required bool piyaz, required bool aci}) {
    var fresh = 0;
    var cost = 0;
    var piyazFresh = false;
    var aciFresh = false;
    if (piyaz) {
      if ((stock['maydanoz'] ?? 0) > 0 && (stock['sogan'] ?? 0) > 0) {
        stock['maydanoz'] = stock['maydanoz']! - 1;
        stock['sogan'] = stock['sogan']! - 1;
        fresh++;
        piyazFresh = true;
      } else {
        cost += cfg.marketPiyaz;
      }
    }
    if (aci) {
      if ((stock['biber'] ?? 0) > 0) {
        stock['biber'] = stock['biber']! - 1;
        fresh++;
        aciFresh = true;
      } else {
        cost += cfg.marketAci;
      }
    }
    return (fresh: fresh, marketCost: cost, piyazFresh: piyazFresh, aciFresh: aciFresh);
  }

  String toJsonString() => jsonEncode({
        'plots': [for (final p in plots) {'c': p.crop, 'g': p.grown, 'w': p.wateredToday, 'd': p.dry}],
        'stock': stock,
        'withered': witheredTotal,
      });

  void fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    plots.clear();
    for (final e in (j['plots'] as List)) {
      final m = e as Map<String, dynamic>;
      plots.add(Plot()
        ..crop = m['c'] as String?
        ..grown = m['g'] as int
        ..wateredToday = m['w'] as bool
        ..dry = m['d'] as int);
    }
    ((j['stock'] as Map<String, dynamic>?) ?? const {}).forEach((k, v) => stock[k] = v as int);
    witheredTotal = (j['withered'] as int?) ?? 0;
  }
}
