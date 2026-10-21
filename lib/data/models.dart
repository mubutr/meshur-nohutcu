import 'dart:convert';

import 'package:flutter/services.dart';

import '../modes/garden.dart';

/// Ürün kimlikleri (game.json "products"). Beyran kâsede servis edilir, diğerleri dürümdür.
const String kDefaultWrap = 'nohut';

/// Bölüm 2+ soslar (sumak dahil değil; sumak ayrı bayrak olarak durur).
const List<String> kSauceIds = ['sos', 'ketcap', 'mayonez', 'nar'];

class OrderSpec {
  const OrderSpec({
    required this.nohut,
    required this.piyaz,
    required this.aci,
    this.sumak = false,
    this.wrap = kDefaultWrap,
    this.fried = false,
    this.sauces = const {},
  });
  final String wrap; // nohut | doner | kavurma | cigkofte | kizartma | beyran
  final int nohut; // ana malzeme porsiyonu (alan adı eski kodla uyumlu): 1..maxAmount
  final bool piyaz;
  final bool aci;
  final bool sumak; // Bölüm 2'den itibaren
  final bool fried; // kızartma eki
  final Set<String> sauces; // sos, ketcap, mayonez, nar

  int get amount => nohut;
  Set<String> get allSauces => {...sauces, if (sumak) 'sumak'};

  Map<String, dynamic> toJson() => {'w': wrap, 'n': nohut, 'p': piyaz, 'a': aci, 's': sumak, 'f': fried, 'x': sauces.toList()};
  factory OrderSpec.fromJson(Map<String, dynamic> j) => OrderSpec(
        wrap: (j['w'] as String?) ?? kDefaultWrap,
        nohut: j['n'] as int,
        piyaz: j['p'] as bool,
        aci: j['a'] as bool,
        sumak: (j['s'] as bool?) ?? false,
        fried: (j['f'] as bool?) ?? false,
        sauces: {...((j['x'] as List?) ?? const []).cast<String>()},
      );

  @override
  String toString() => 'OrderSpec($wrap x$nohut, piyaz: $piyaz, aci: $aci, sumak: $sumak, fried: $fried, sauces: $sauces)';
}

/// Oyuncunun tezgâhta hazırladığı dürüm (ya da beyran kâsesi: [bread] = kâse).
class Assembly {
  Assembly();

  String wrap = kDefaultWrap;
  bool bread = false; // taban: ekmek ya da kâse
  int nohut = 0; // ana malzeme porsiyonu
  bool piyaz = false;
  bool aci = false;
  bool sumak = false;
  bool fried = false;
  final Set<String> sauces = {};
  bool wrapped = false; // sarıldı / servise hazır
  int spent = 0; // bu dürüme harcanan para (çöpe giderse kaybolur)

  void reset() {
    wrap = kDefaultWrap;
    bread = false;
    nohut = 0;
    piyaz = false;
    aci = false;
    sumak = false;
    fried = false;
    sauces.clear();
    wrapped = false;
    spent = 0;
  }

  Assembly copy() => Assembly()
    ..wrap = wrap
    ..bread = bread
    ..nohut = nohut
    ..piyaz = piyaz
    ..aci = aci
    ..sumak = sumak
    ..fried = fried
    ..sauces.addAll(sauces)
    ..wrapped = wrapped
    ..spent = spent;

  /// Siparişe tam uyan, sarılmış dürüm (yardımcı çırak / otomasyon için).
  factory Assembly.fromSpec(OrderSpec s) => Assembly()
    ..wrap = s.wrap
    ..bread = true
    ..nohut = s.nohut
    ..piyaz = s.piyaz
    ..aci = s.aci
    ..sumak = s.sumak
    ..fried = s.fried
    ..sauces.addAll(s.sauces)
    ..wrapped = true;

  bool get isEmpty => !bread;

  Map<String, dynamic> toJson() => {'w': wrap, 'b': bread, 'n': nohut, 'p': piyaz, 'a': aci, 's': sumak, 'f': fried, 'x': sauces.toList(), 'r': wrapped, 'c': spent};
  factory Assembly.fromJson(Map<String, dynamic> j) => Assembly()
    ..wrap = (j['w'] as String?) ?? kDefaultWrap
    ..bread = (j['b'] as bool?) ?? false
    ..nohut = (j['n'] as int?) ?? 0
    ..piyaz = (j['p'] as bool?) ?? false
    ..aci = (j['a'] as bool?) ?? false
    ..sumak = (j['s'] as bool?) ?? false
    ..fried = (j['f'] as bool?) ?? false
    ..sauces.addAll(((j['x'] as List?) ?? const []).cast<String>())
    ..wrapped = (j['r'] as bool?) ?? false
    ..spent = (j['c'] as int?) ?? 0;
}

/// Satılan ürün (game.json "products"); tarif defteri ve sipariş üretimi aynı kaynağı kullanır.
class ProductDef {
  const ProductDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.minChapter,
    required this.unit,
    required this.maxAmount,
    required this.weight,
    required this.bowl,
    required this.allow,
    required this.fillName,
  });
  final String id;
  final String name; // "Nohut Dürümü"
  final String desc; // tarif defterindeki açıklama
  final int minChapter;
  final int unit; // ana malzeme porsiyon maliyeti
  final int maxAmount;
  final int weight; // sipariş çıkma ağırlığı
  final bool bowl; // kâse (beyran): ekmek ve SAR yok
  final List<String> allow; // piyaz, aci, fried, sauce, sumak
  final String fillName; // "nohut", "döner"...

  bool allows(String topping) => allow.contains(topping);

  factory ProductDef.fromJson(Map<String, dynamic> j) => ProductDef(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: j['desc'] as String,
        minChapter: j['minChapter'] as int,
        unit: j['unit'] as int,
        maxAmount: j['maxAmount'] as int,
        weight: (j['weight'] as int?) ?? 3,
        bowl: (j['bowl'] as bool?) ?? false,
        allow: ((j['allow'] as List?) ?? const ['piyaz', 'aci', 'fried', 'sauce', 'sumak']).cast<String>(),
        fillName: (j['fillName'] as String?) ?? j['id'] as String,
      );
}

class SauceDef {
  const SauceDef({required this.id, required this.name, required this.desc, required this.cost, required this.minChapter});
  final String id; // sos | ketcap | mayonez | nar | sumak
  final String name;
  final String desc;
  final int cost;
  final int minChapter;

  factory SauceDef.fromJson(Map<String, dynamic> j) => SauceDef(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: j['desc'] as String,
        cost: j['cost'] as int,
        minChapter: j['minChapter'] as int,
      );
}

enum Verdict { great, ok, bad }

/// Müşteri adı: [ref] müşteriden bahsederken ("Maamed ammi"), [dat] yönelme hâli ("Maamed ammiye"),
/// [hitap] ustanın doğrudan seslenişi (yoksa [ref] kullanılır; genç erkeklerde "Rafık").
class CustomerName {
  const CustomerName({required this.n, required this.ref, required this.dat, String? hitap}) : hitap = hitap ?? ref;
  final String n;
  final String ref;
  final String dat;
  final String hitap;

  factory CustomerName.fromJson(Map<String, dynamic> j) => CustomerName(
        n: j['n'] as String,
        ref: j['ref'] as String,
        dat: j['dat'] as String,
        hitap: j['hitap'] as String?,
      );
}

class CustomerType {
  const CustomerType({
    required this.id,
    required this.patience,
    required this.tip,
    required this.weight,
    required this.ustaHitap,
    required this.names,
    this.gender = '',
    this.age = '',
  });
  final String gender; // kadin | erkek
  final String age; // yasli | genc
  final String id; // sprite öneki: müşterinin adı (fatma, maamed …)
  final double patience;
  final double tip;
  final int weight;
  final String ustaHitap; // müşterinin ustaya hitabı
  final List<CustomerName> names;

  factory CustomerType.fromJson(Map<String, dynamic> j) => CustomerType(
        id: j['id'] as String,
        patience: (j['patience'] as num).toDouble(),
        tip: (j['tip'] as num).toDouble(),
        weight: j['weight'] as int,
        ustaHitap: j['ustaHitap'] as String,
        names: (j['names'] as List).map((e) => CustomerName.fromJson(e as Map<String, dynamic>)).toList(),
        gender: (j['gender'] as String?) ?? '',
        age: (j['age'] as String?) ?? '',
      );
}

/// Özel müşteri türü: bilmececi, garip, maskeli…
class SpecialDef {
  const SpecialDef({
    required this.kind,
    required this.sprite,
    required this.name,
    required this.patience,
    required this.minChapter,
    required this.chance,
    required this.maxPerDay,
    required this.ustaHitap,
  });
  final String kind; // garip | maskeli | nine | itfaiyeci
  final String sprite;
  final CustomerName name;
  final double patience;
  final int minChapter;
  final double chance; // her müşteri doğuşunda ihtimal
  final int maxPerDay;
  final String ustaHitap;

  factory SpecialDef.fromJson(Map<String, dynamic> j) => SpecialDef(
        kind: j['kind'] as String,
        sprite: j['sprite'] as String,
        name: CustomerName.fromJson(j['name'] as Map<String, dynamic>),
        patience: (j['patience'] as num).toDouble(),
        minChapter: j['minChapter'] as int,
        chance: (j['chance'] as num).toDouble(),
        maxPerDay: j['maxPerDay'] as int,
        ustaHitap: j['ustaHitap'] as String,
      );
}

class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.max,
    required this.costs,
    required this.perLevel,
    this.minChapter = 1,
    this.currency = 'money',
  });
  final String id;
  final String name;
  final String desc;
  final int max;
  final List<int> costs;
  final double perLevel;
  final int minChapter;
  final String currency; // money | diamond

  bool get withDiamonds => currency == 'diamond';

  factory UpgradeDef.fromJson(Map<String, dynamic> j) => UpgradeDef(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: j['desc'] as String,
        max: j['max'] as int,
        costs: (j['costs'] as List).cast<int>(),
        perLevel: (j['perLevel'] as num).toDouble(),
        minChapter: (j['minChapter'] as int?) ?? 1,
        currency: (j['currency'] as String?) ?? 'money',
      );
}

/// Dükkân süsü (Blender katmanı); satın alınınca sahnede görünür ve küçük bir kazanç çarpanı verir.
class DecorDef {
  const DecorDef({required this.id, required this.name, required this.desc, required this.cost, required this.layer, required this.bonus, required this.minChapter, this.diamonds = 0});
  final String id;
  final String name;
  final String desc;
  final int cost;
  final int diamonds; // para ile birlikte gereken elmas
  final String layer; // back | front
  final double bonus; // kazanç çarpanına eklenir (0.03 = %3)
  final int minChapter;

  factory DecorDef.fromJson(Map<String, dynamic> j) => DecorDef(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: j['desc'] as String,
        cost: j['cost'] as int,
        diamonds: (j['diamonds'] as int?) ?? 0,
        layer: j['layer'] as String,
        bonus: (j['bonus'] as num).toDouble(),
        minChapter: j['minChapter'] as int,
      );
}

class Difficulty {
  const Difficulty({required this.fromDay, required this.maxNohut, required this.piyazChance, required this.aciChance});
  final int fromDay;
  final int maxNohut;
  final double piyazChance;
  final double aciChance;

  factory Difficulty.fromJson(Map<String, dynamic> j) => Difficulty(
        fromDay: j['fromDay'] as int,
        maxNohut: j['maxNohut'] as int,
        piyazChance: (j['piyazChance'] as num).toDouble(),
        aciChance: (j['aciChance'] as num).toDouble(),
      );
}

class GameConfig {
  GameConfig({
    required this.customers,
    required this.specials,
    required this.upgrades,
    required this.decor,
    required this.difficulty,
    required this.products,
    required this.sauces,
    required this.costs,
    required this.margin,
    required this.day,
    required this.economy,
    required this.garden,
  });

  final List<CustomerType> customers;
  final List<SpecialDef> specials;
  final List<UpgradeDef> upgrades;
  final List<DecorDef> decor;
  final List<Difficulty> difficulty;
  final List<ProductDef> products;
  final List<SauceDef> sauces; // sos, ketcap, mayonez, nar, sumak
  final Map<String, int> costs; // bread, bowl, piyaz, aci, fried
  final double margin; // satış fiyatı = maliyet × margin (1.3 = %30 kâr)
  final Map<String, num> day;
  final Map<String, num> economy;
  final GardenConfig garden;

  static Future<GameConfig> load([AssetBundle? bundle]) async =>
      GameConfig.fromJson(await (bundle ?? rootBundle).loadString('assets/data/game.json'));

  factory GameConfig.fromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    Map<String, num> nums(String key) => (j[key] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as num));
    return GameConfig(
      customers: (j['customers'] as List).map((e) => CustomerType.fromJson(e as Map<String, dynamic>)).toList(),
      specials: ((j['specials'] as List?) ?? const []).map((e) => SpecialDef.fromJson(e as Map<String, dynamic>)).toList(),
      upgrades: (j['upgrades'] as List).map((e) => UpgradeDef.fromJson(e as Map<String, dynamic>)).toList(),
      decor: ((j['decor'] as List?) ?? const []).map((e) => DecorDef.fromJson(e as Map<String, dynamic>)).toList(),
      difficulty: (j['difficulty'] as List).map((e) => Difficulty.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.fromDay.compareTo(b.fromDay)),
      products: (j['products'] as List).map((e) => ProductDef.fromJson(e as Map<String, dynamic>)).toList(),
      sauces: (j['sauces'] as List).map((e) => SauceDef.fromJson(e as Map<String, dynamic>)).toList(),
      costs: (j['costs'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      margin: (j['margin'] as num).toDouble(),
      day: nums('day'),
      economy: nums('economy'),
      garden: GardenConfig.fromJson(j['garden'] as Map<String, dynamic>),
    );
  }

  Difficulty difficultyFor(int day) => difficulty.lastWhere((d) => d.fromDay <= day, orElse: () => difficulty.first);

  double d(String key) => day[key]!.toDouble();
  double eco(String key) => economy[key]!.toDouble();

  int customersForDay(int dayNo) =>
      (d('customersBase') + d('customersPerDay') * (dayNo - 1)).clamp(1, d('customersMax')).round();

  double spawnGapForDay(int dayNo) =>
      (d('spawnGapBase') - d('spawnGapDropPerDay') * (dayNo - 1)).clamp(d('spawnGapMin'), 999).toDouble();

  double patienceForDay(int dayNo) =>
      (d('patienceBase') - d('patienceDropPerDay') * (dayNo - 1)).clamp(d('patienceMin'), 999).toDouble();

  /// Bölüm 2'den itibaren siparişlere sumak girer.
  double sumakChance(int chapter) => chapter < 2 ? 0 : (0.30 + 0.05 * (chapter - 2)).clamp(0.0, 0.5);

  ProductDef product(String id) => products.firstWhere((p) => p.id == id, orElse: () => products.first);
  SauceDef sauce(String id) => sauces.firstWhere((s) => s.id == id);
  List<ProductDef> unlockedProducts(int chapter) => products.where((p) => p.minChapter <= chapter).toList();
  List<SauceDef> unlockedSauces(int chapter) => sauces.where((s) => s.minChapter <= chapter).toList();
  bool friedUnlocked(int chapter) => chapter >= eco('friedMinChapter').round();

  /// Tek bir hazırlık adımının maliyeti.
  int baseCost(String wrap) => product(wrap).bowl ? costs['bowl']! : costs['bread']!;
  int sauceCost(String id) => sauce(id).cost;

  /// Günlük kira: bölümle artar.
  int rentFor(int chapter) => (eco('rentBase') + eco('rentPerChapter') * chapter).round();
}

/// Bilmeceli sipariş: müşteri doğrudan söylemez, bilmece sorar.
class Riddle {
  const Riddle({required this.id, required this.text, required this.spec, required this.minChapter, this.giver});
  final String id;
  final String text; // müşteri -> usta
  final OrderSpec spec;
  final int minChapter;
  final String? giver; // belirli bir karakter sorar (nine, itfaiyeci…)

  factory Riddle.fromJson(Map<String, dynamic> j) => Riddle(
        id: j['id'] as String,
        text: j['text'] as String,
        spec: OrderSpec(nohut: j['nohut'] as int, piyaz: j['piyaz'] as bool, aci: j['aci'] as bool, sumak: j['sumak'] as bool),
        minChapter: (j['minChapter'] as int?) ?? 2,
        giver: j['giver'] as String?,
      );

  static List<Riddle> parse(String raw) =>
      ((jsonDecode(raw) as Map<String, dynamic>)['riddles'] as List).map((e) => Riddle.fromJson(e as Map<String, dynamic>)).toList();

  static Future<List<Riddle>> load([AssetBundle? bundle]) async => parse(await (bundle ?? rootBundle).loadString('assets/data/riddles.json'));
}
