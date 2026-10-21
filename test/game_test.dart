import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/game/scoring.dart';

import 'helpers.dart';

Assembly made({int nohut = 2, bool piyaz = false, bool aci = false, bool sumak = false, bool wrapped = true, bool bread = true}) => Assembly()
  ..bread = bread
  ..nohut = nohut
  ..piyaz = piyaz
  ..aci = aci
  ..sumak = sumak
  ..wrapped = wrapped;

void main() {
  final cfg = loadCfg();

  group('puanlama', () {
    const spec = OrderSpec(nohut: 2, piyaz: true, aci: false);

    test('tam isabet: tam ücret + bahşiş', () {
      final r = scoreServe(cfg: cfg, spec: spec, made: made(piyaz: true), patienceLeft: 1, customerTip: 1);
      expect(r.verdict, Verdict.great);
      expect(r.pay, orderPrice(cfg, spec));
      expect(r.tip, greaterThan(0));
    });

    test('tek hata: %60 ücret, bahşiş yok', () {
      final r = scoreServe(cfg: cfg, spec: spec, made: made(piyaz: false), patienceLeft: 1, customerTip: 1);
      expect(r.verdict, Verdict.ok);
      expect(r.pay, (orderPrice(cfg, spec) * 0.6).round());
      expect(r.tip, 0);
    });

    test('iki+ hata: kötü', () {
      final r = scoreServe(cfg: cfg, spec: spec, made: made(nohut: 3, piyaz: false, aci: true), patienceLeft: 1, customerTip: 1);
      expect(r.verdict, Verdict.bad);
      expect(r.errors, 3);
    });

    test('sumak hatası da sayılır ve maliyete/fiyata eklenir', () {
      const s = OrderSpec(nohut: 1, piyaz: false, aci: false, sumak: true);
      expect(orderErrors(s, made(nohut: 1)), 1);
      expect(orderErrors(s, made(nohut: 1, sumak: true)), 0);
      expect(ingredientCost(cfg, s), cfg.costs['bread']! + cfg.product('nohut').unit + cfg.sauceCost('sumak'));
      expect(orderPrice(cfg, s), (ingredientCost(cfg, s) * 1.3).round());
    });

    test('sarılmamış dürüm geçersiz', () {
      expect(orderErrors(spec, made(wrapped: false)), -1);
      expect(orderErrors(spec, made(bread: false)), -1);
    });

    test('sabır azaldıkça bahşiş azalır', () {
      final a = scoreServe(cfg: cfg, spec: spec, made: made(piyaz: true), patienceLeft: 1.0, customerTip: 1);
      final b = scoreServe(cfg: cfg, spec: spec, made: made(piyaz: true), patienceLeft: 0.2, customerTip: 1);
      expect(b.tip, lessThan(a.tip));
    });
  });

  group('oyun akışı', () {
    test('ilk açılışta Bölüm 1 giriş sahnesi gelir, geçilince oyun akar', () {
      final g = makeGame()..startDay();
      expect(g.sceneLines, isNotNull);
      expect(g.sceneId, 'c1_intro');
      g.tick(5); // sahne açıkken oyun donar
      expect(g.slots.every((c) => c == null), isTrue);
      skipScenes(g);
      expect(g.sceneLines, isNull);
      g.dispose();
    });

    test('gün 1: sipariş en çok 2 nohut, piyaz/acı/sumak yok', () {
      final g = makeGame()..startDay();
      skipScenes(g);
      for (var i = 0; i < 400 && g.toSpawn > 0; i++) {
        g.tick(0.1);
      }
      final specs = g.slots.whereType<Customer>().map((c) => c.spec);
      expect(specs, isNotEmpty);
      for (final s in specs) {
        expect(s.nohut, inInclusiveRange(1, 2));
        expect(s.piyaz, isFalse);
        expect(s.aci, isFalse);
        expect(s.sumak, isFalse);
      }
      g.dispose();
    });

    test('doğru dürümü servis edince para artar', () {
      final g = makeGame()..startDay();
      skipScenes(g);
      final idx = waitForCustomer(g);
      expect(idx, isNonNegative);
      final before = g.money;
      makeAndServe(g, idx);
      expect(g.money, greaterThan(before));
      expect(g.assembly.isEmpty, isTrue);
      expect(g.greatToday, 1);
      g.dispose();
    });

    test('sabır biterse müşteri küsüp gider', () {
      final g = makeGame()..startDay();
      skipScenes(g);
      for (var i = 0; i < 3000; i++) {
        g.tick(0.1);
        if (g.lostToday > 0) break;
      }
      expect(g.lostToday, greaterThan(0));
      g.dispose();
    });

    test('gün biter: gün artar, kira ve malzeme düşer, para eksiye inmez', () {
      final g = makeGame()..startDay();
      skipScenes(g);
      for (var i = 0; i < 30000 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
      }
      expect(g.phase, Phase.dayEnd);
      expect(g.day, 2);
      expect(g.rentToday, cfg.rentFor(1));
      expect(g.money, greaterThanOrEqualTo(0));
      g.dispose();
    });

    test('yükseltme satın alınır; bölüm kilidi uygulanır', () {
      final g = makeGame();
      g.money = 5000;
      final sabir = cfg.upgrades.firstWhere((u) => u.id == 'sabir');
      expect(g.buy(sabir), isTrue);
      expect(g.level('sabir'), 1);
      expect(g.money, 5000 - sabir.costs.first);
      final yardimci = cfg.upgrades.firstWhere((u) => u.id == 'yardimci');
      expect(g.buy(yardimci), isFalse, reason: 'Bölüm 3 öncesi kilitli');
      g.dispose();
    });

    test('dekor satın alınır ve kazanç çarpanını artırır', () {
      final g = makeGame();
      g.money = 1000;
      final before = g.payMul;
      final kilim = cfg.decor.firstWhere((d) => d.id == 'kilim');
      expect(g.buyDecor(kilim), isTrue);
      expect(g.decorOwned, contains('kilim'));
      expect(g.payMul, greaterThan(before));
      expect(g.buyDecor(kilim), isFalse, reason: 'ikinci kez alınamaz');
      g.dispose();
    });
  });
}
