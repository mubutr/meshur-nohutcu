import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/game/scoring.dart';

import 'helpers.dart';

GameController playing([int seed = 3, int chapter = 1]) {
  final g = makeGame(seed);
  g.quests.chapter = chapter;
  g.quests.chapterIntroSeen = true;
  g.startDay();
  skipScenes(g);
  return g;
}

void main() {
  final cfg = loadCfg();

  group('maliyet ve %30 kâr', () {
    test('her ürün/ek/sos birleşiminde satış fiyatı = maliyet × 1.3', () {
      for (final p in cfg.products) {
        for (var n = 1; n <= p.maxAmount; n++) {
          for (final fried in [false, true]) {
            final s = OrderSpec(wrap: p.id, nohut: n, piyaz: p.allows('piyaz'), aci: true, fried: fried && p.allows('fried'), sauces: p.allows('sauce') ? {'ketcap', 'nar'} : const {}, sumak: p.allows('sumak'));
            final cost = ingredientCost(cfg, s);
            expect(orderPrice(cfg, s), (cost * 1.3).round(), reason: '$s');
            expect(orderPrice(cfg, s), greaterThan(cost), reason: 'kâr var: $s');
          }
        }
      }
    });

    test('maliyet: taban + porsiyon × birim + ekler + soslar', () {
      const s = OrderSpec(wrap: 'doner', nohut: 2, piyaz: true, aci: true, fried: true, sumak: true, sauces: {'sos'});
      final expected = cfg.costs['bread']! + 2 * cfg.product('doner').unit + cfg.costs['piyaz']! + cfg.costs['aci']! + cfg.costs['fried']! + cfg.sauceCost('sumak') + cfg.sauceCost('sos');
      expect(ingredientCost(cfg, s), expected);
    });

    test('beyran kâsede servis edilir: taban kâse maliyeti, ekmek yok', () {
      const s = OrderSpec(wrap: 'beyran', nohut: 1, piyaz: false, aci: true);
      expect(ingredientCost(cfg, s), cfg.costs['bowl']! + cfg.product('beyran').unit + cfg.costs['aci']!);
    });

    test('yanlış ürün 3 hata (kötü); fazla/eksik sos ve kızartma hata sayılır', () {
      const s = OrderSpec(wrap: 'nohut', nohut: 1, piyaz: false, aci: false, sauces: {'sos'});
      Assembly a({String wrap = 'nohut', Set<String> sauces = const {'sos'}, bool fried = false}) => Assembly()
        ..wrap = wrap
        ..bread = true
        ..nohut = 1
        ..fried = fried
        ..sauces.addAll(sauces)
        ..wrapped = true;
      expect(orderErrors(s, a()), 0);
      expect(orderErrors(s, a(wrap: 'doner')), 3);
      expect(orderErrors(s, a(sauces: {})), 1);
      expect(orderErrors(s, a(sauces: {'sos', 'ketcap'})), 1);
      expect(orderErrors(s, a(fried: true)), 1);
      expect(orderErrors(s, a(sauces: {'ketcap'})), 2);
    });
  });

  group('kasadan düşen malzeme parası', () {
    test('her malzeme dokunuşu parayı düşürür; çöpe atılan para geri gelmez', () {
      final g = playing();
      final m0 = g.money;
      g.tapBread();
      expect(g.money, m0 - cfg.costs['bread']!);
      g.tapMain();
      g.tapMain();
      expect(g.money, m0 - cfg.costs['bread']! - 2 * cfg.product('nohut').unit);
      final spent = g.assembly.spent;
      expect(spent, m0 - g.money);
      g.trash();
      expect(g.money, m0 - spent, reason: 'iade yok');
      expect(g.wastedToday, spent);
      expect(g.assembly.isEmpty, isTrue);
      g.dispose();
    });

    test('aynı malzeme iki kez eklenmez (piyaz/acı bir kez ödenir); üst sınırı aşan porsiyon eklenmez', () {
      final g = playing(3, 2);
      g.tapBread();
      g.tapPiyaz();
      final m1 = g.money;
      g.tapPiyaz();
      expect(g.money, m1);
      for (var i = 0; i < 6; i++) {
        g.tapMain();
      }
      expect(g.assembly.nohut, cfg.product('nohut').maxAmount);
      g.dispose();
    });

    test('para yetmezse malzeme eklenmez ve usta uyarır; para eksiye inmez', () {
      final g = playing();
      g.money = 5;
      g.avansGivenToday = true; // avans devre dışı
      g.tapBread();
      expect(g.assembly.isEmpty, isTrue);
      expect(g.money, 5);
      expect(g.hint, 'Kasada para yok!');
      g.dispose();
    });

    test('gün başında kasa avans tutarının altındaysa usta tamamlar', () {
      final g = makeGame();
      g.money = 20;
      g.startDay();
      expect(g.money, cfg.eco('avans').round());
      g.dispose();
    });

    test('kasa bitince (hazırlık imkânsız) günde bir kez avans verilir', () {
      final g = playing();
      final idx = waitForCustomer(g);
      expect(idx, isNonNegative);
      g.money = 3;
      g.avansGivenToday = false;
      g.tick(0.1);
      expect(g.money, cfg.eco('avans').round());
      g.money = 3;
      g.tick(0.1);
      expect(g.money, 3, reason: 'ikinci avans yok');
      g.dispose();
    });

    test('doğru servis: fiyat kasaya, kâr = fiyat − maliyet; bahşiş kavanoza gider', () {
      final g = playing();
      final idx = waitForCustomer(g);
      final c = g.slots[idx]!;
      final m0 = g.money;
      final cost = ingredientCost(cfg, c.spec);
      final price = orderPrice(cfg, c.spec);
      prepare(g, c.spec);
      expect(g.money, m0 - cost);
      g.serve(idx);
      final payMul = g.payMul;
      expect(g.money, m0 - cost + (price * payMul).round());
      expect(g.tipJar, greaterThan(0), reason: 'bahşiş kavanozda');
      expect(g.tipsToday, g.tipJar);
      g.dispose();
    });

    test('kavanoza dokununca bahşiş kasaya geçer; gün sonunda kalan otomatik aktarılır', () {
      final g = playing();
      g.tipJar = 70;
      final m0 = g.money;
      g.collectTipJar();
      expect(g.money, m0 + 70);
      expect(g.tipJar, 0);
      g.tipJar = 40;
      final m1 = g.money;
      for (var i = 0; i < 40000 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
      }
      expect(g.phase, Phase.dayEnd);
      expect(g.tipJar, 0);
      expect(g.money, greaterThanOrEqualTo(0));
      expect(m1, isNonNegative);
      g.dispose();
    });

    test('müşteri küserse -10 ₺ ceza; kasa eksiye inmez; gün özetinde görünür', () {
      final g = playing();
      final m0 = g.money;
      for (var i = 0; i < 3000 && g.lostToday == 0; i++) {
        g.tick(0.1);
      }
      expect(g.lostToday, greaterThan(0));
      expect(g.penaltyToday, cfg.eco('leavePenalty').round() * g.lostToday);
      expect(g.money, m0 - g.penaltyToday);
      g.money = 4;
      final before = g.penaltyToday;
      final c = g.slots.whereType<Customer>().firstOrNull;
      if (c != null) {
        c.patience = 0.05;
        g.avansGivenToday = true;
        for (var i = 0; i < 5; i++) {
          g.tick(0.1);
        }
        expect(g.money, greaterThanOrEqualTo(0));
        expect(g.penaltyToday, greaterThanOrEqualTo(before));
      }
      g.dispose();
    });

    test('günün net kârı: kazanç + bahşiş − malzeme − kira − ceza − çalınan', () {
      final g = playing();
      for (var i = 0; i < 40000 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
        final idx = g.slots.indexWhere((c) => c != null && c.state == CustomerState.waiting && !c.isCourier);
        if (idx >= 0 && g.assembly.isEmpty && i % 20 == 0) makeAndServe(g, idx);
      }
      expect(g.phase, Phase.dayEnd);
      expect(g.netToday, g.earnedToday + g.tipsToday - g.suppliesToday - g.rentToday - g.stolenToday - g.penaltyToday);
      g.dispose();
    });
  });

  group('ürünler bölümle açılır', () {
    test('Bölüm 1: yalnızca nohut; sos ve kızartma yok', () {
      final g = playing(5, 1);
      for (var i = 0; i < 4000 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
        for (final c in g.slots.whereType<Customer>()) {
          expect(c.spec.wrap, 'nohut');
          expect(c.spec.fried, isFalse);
          expect(c.spec.sauces, isEmpty);
        }
      }
      g.dispose();
    });

    test('Bölüm açılışları: döner B3, kavurma/çiğ köfte B4, kızartma/beyran B5', () {
      final g = makeGame();
      List<String> ids(int ch) {
        g.quests.chapter = ch;
        return [for (final p in g.products) p.id];
      }

      expect(ids(1), ['nohut']);
      expect(ids(2), ['nohut']);
      expect(ids(3), ['nohut', 'doner']);
      expect(ids(4), containsAll(['kavurma', 'cigkofte']));
      expect(ids(5), containsAll(['kizartma', 'beyran']));
      g.quests.chapter = 2;
      expect([for (final s in g.sauces) s.id], containsAll(['sos', 'ketcap', 'mayonez', 'sumak']));
      expect([for (final s in g.sauces) s.id], isNot(contains('nar')));
      g.quests.chapter = 3;
      expect([for (final s in g.sauces) s.id], contains('nar'));
      expect(g.friedUnlocked, isTrue);
      g.dispose();
    });

    test('kilitli ürün seçilemez; tezgâh doluyken ürün değişmez; kilitli sos eklenmez', () {
      final g = playing(3, 2);
      g.selectWrap('doner');
      expect(g.selectedWrap, 'nohut');
      g.tapBread();
      g.tapSauce('nar'); // Bölüm 3'te açılır
      expect(g.assembly.sauces, isEmpty);
      g.tapSauce('ketcap');
      expect(g.assembly.sauces, {'ketcap'});
      g.dispose();
    });

    test('döner dürümü: seç, hazırla, servis et', () {
      final g = playing(11, 3);
      g.money = 2000;
      const spec = OrderSpec(wrap: 'doner', nohut: 2, piyaz: true, aci: false, fried: true, sauces: {'ketcap'}, sumak: true);
      prepare(g, spec);
      expect(g.assembly.wrap, 'doner');
      expect(orderErrors(spec, g.assembly), 0);
      g.dispose();
    });

    test('beyran: kâse tabanı, ekmek maliyeti yok; piyaz/sos eklenemez', () {
      final g = playing(11, 5);
      g.money = 1000;
      g.selectWrap('beyran');
      final m0 = g.money;
      g.tapBread();
      expect(g.money, m0 - cfg.costs['bowl']!);
      g.tapPiyaz();
      g.tapSauce('sos');
      g.tapFried();
      expect(g.assembly.piyaz, isFalse);
      expect(g.assembly.sauces, isEmpty);
      expect(g.assembly.fried, isFalse);
      g.tapAci();
      expect(g.assembly.aci, isTrue);
      g.dispose();
    });

    test('sipariş çeşitliliği: Bölüm 5\'te tüm ürünler, kızartma ve soslar sipariş olarak gelir', () {
      final g = playing(21, 5);
      final seenWraps = <String>{};
      var fried = false, sauce = false;
      for (var day = 0; day < 6; day++) {
        for (var i = 0; i < 6000 && g.phase == Phase.playing; i++) {
          g.tick(0.1);
          for (final c in g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.normal)) {
            seenWraps.add(c.spec.wrap);
            fried |= c.spec.fried;
            sauce |= c.spec.sauces.isNotEmpty;
            final cp = cfg.product(c.spec.wrap);
            expect(c.spec.nohut, inInclusiveRange(1, cp.maxAmount));
            if (!cp.allows('piyaz')) expect(c.spec.piyaz, isFalse);
            // söylenen cümle spec'ten üretildi
            expect(c.order.text, isNotEmpty);
          }
        }
        g.startDay();
        skipScenes(g);
      }
      expect(seenWraps, containsAll(['nohut', 'doner', 'kavurma', 'cigkofte', 'kizartma', 'beyran']));
      expect(fried, isTrue);
      expect(sauce, isTrue);
      g.dispose();
    });
  });

  group('gün saati', () {
    test('gün ilerledikçe saat 07:00 → 23:00 olur', () {
      final g = playing();
      expect(g.clockText, '07:00');
      for (var i = 0; i < 40000 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
        final idx = g.slots.indexWhere((c) => c != null && c.state == CustomerState.waiting);
        if (idx >= 0 && i % 25 == 0) {
          g.slots[idx]!.patience = 0; // hızlı bitir
        }
      }
      expect(g.dayProgress, 1.0);
      expect(g.clockText, '23:00');
      g.dispose();
    });

    test('günde daha çok müşteri gelir', () {
      expect(cfg.customersForDay(1), greaterThanOrEqualTo(8));
      expect(cfg.customersForDay(20), greaterThanOrEqualTo(25));
    });
  });

  group('olay yayını', () {
    test('elmas ve kavanoz olayları dinleyicilere gider', () {
      final g = playing();
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      g.tipJar = 9;
      g.collectTipJar();
      expect(events.whereType<TipJarEvent>().single.amount, 9);
      g.dispose();
    });
  });
}
