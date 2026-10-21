import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/modes/delivery.dart';
import 'package:nohut_durumu/modes/detective.dart';
import 'package:nohut_durumu/modes/garden.dart';

import 'helpers.dart';

void main() {
  final cfg = loadCfg();

  group('bahçe', () {
    GardenState newGarden() => GardenState(cfg.garden)..ensurePlots(2);

    test('ekim para harcar, sulanan bitki büyür, olgunlaşınca hasat edilir', () {
      final g = newGarden();
      var money = 100;
      expect(g.plant(0, 'maydanoz', money: money, pay: (c) => money -= c), isTrue);
      expect(money, 100 - cfg.garden.crop('maydanoz').seed);
      for (var night = 0; night < cfg.garden.crop('maydanoz').days; night++) {
        expect(g.water(0), isTrue);
        g.endOfDay();
      }
      expect(g.isReady(g.plots[0]), isTrue);
      var harvested = '';
      final n = g.harvest(0, (c, a) => harvested = '$c:$a');
      expect(n, cfg.garden.crop('maydanoz').yield);
      expect(harvested, 'maydanoz:$n');
      expect(g.stock['maydanoz'], n);
      expect(g.plots[0].empty, isTrue);
    });

    test('parası yetmeyen ekemez, aynı gün iki kez sulanmaz', () {
      final g = newGarden();
      expect(g.plant(0, 'biber', money: 1, pay: (c) {}), isFalse);
      var m = 50;
      g.plant(1, 'sogan', money: m, pay: (c) => m -= c);
      expect(g.water(1), isTrue);
      expect(g.water(1), isFalse);
    });

    test('susuz kalan bitki kurur', () {
      final g = newGarden();
      var m = 50;
      g.plant(0, 'sogan', money: m, pay: (c) => m -= c);
      for (var i = 0; i < cfg.garden.maxDry; i++) {
        g.endOfDay();
      }
      expect(g.plots[0].empty, isTrue);
      expect(g.witheredTotal, 1);
    });

    test('taze stok piyaz/acı masrafını düşürür; stok yoksa pazar maliyeti', () {
      final g = newGarden();
      var r = g.consume(piyaz: true, aci: true);
      expect(r.fresh, 0);
      expect(r.marketCost, cfg.garden.marketPiyaz + cfg.garden.marketAci);
      g.stock['maydanoz'] = 2;
      g.stock['sogan'] = 2;
      g.stock['biber'] = 1;
      r = g.consume(piyaz: true, aci: true);
      expect(r.fresh, 2);
      expect(r.marketCost, 0);
      expect(g.stock['maydanoz'], 1);
      expect(g.stock['biber'], 0);
    });

    test('kayıt/yükleme', () {
      final g = newGarden();
      var m = 50;
      g.plant(0, 'maydanoz', money: m, pay: (c) => m -= c);
      g.stock['biber'] = 7;
      final g2 = GardenState(cfg.garden)..fromJsonString(g.toJsonString());
      expect(g2.plots[0].crop, 'maydanoz');
      expect(g2.stock['biber'], 7);
    });

    test('kontrolcü: Bölüm 4 öncesi bahçe kapalı, parsel yükseltmesi parsel sayısını artırır', () {
      final g = makeGame();
      g.openGarden();
      expect(g.phase, isNot(Phase.garden));
      g.quests.chapter = 4;
      g.quests.chapterIntroSeen = true;
      expect(g.plotCount, 2);
      g.upgrades['parsel'] = 2;
      expect(g.plotCount, 4);
      g.openGarden();
      expect(g.phase, Phase.garden);
      expect(g.garden.plots.length, 4);
      g.dispose();
    });
  });

  group('paket servis', () {
    test('sipariş düşer, kutuya konur, kurye gelince ödeme yapılır', () {
      final g = makeGame(2);
      g.quests.chapter = 4;
      g.quests.chapterIntroSeen = true;
      g.money = 0;
      g.startDay();
      skipScenes(g);
      var guard = 0;
      while (g.delivery.orders.isEmpty && guard++ < 2000) {
        g.tick(0.1);
      }
      expect(g.delivery.orders, isNotEmpty);
      final order = g.delivery.orders.first;
      // siparişe uygun dürümü hazırla
      g.assembly.reset();
      prepare(g, order.spec);
      g.serveDelivery(0);
      expect(g.delivery.orders.first.isBoxed, isTrue);
      expect(g.assembly.isEmpty, isTrue);
      // kurye kapıya gelir (bir müşteri yuvasında durur); dokununca paketler alınır ve ödeme yapılır
      guard = 0;
      Customer? kurye;
      while (kurye == null && guard++ < 3000) {
        g.tick(0.1);
        kurye = g.slots.whereType<Customer>().where((c) => c.isCourier).firstOrNull;
      }
      expect(kurye, isNotNull, reason: 'kurye gelmedi');
      expect(g.deliveredToday, 0, reason: 'dokunulana kadar teslim olmaz');
      final before = g.money;
      g.tapCustomer(g.slots.indexOf(kurye));
      expect(g.deliveredToday, 1);
      expect(g.money, greaterThan(before));
      expect(g.delivery.courierHere, isFalse);
      g.dispose();
    });

    test('kurye dokunulmazsa paketsiz gider; kutudaki dürüm teslim olmadan kalır', () {
      final g = makeGame(2);
      g.quests.chapter = 4;
      g.quests.chapterIntroSeen = true;
      g.startDay();
      skipScenes(g);
      g.delivery.courierLeft = 0.1;
      var guard = 0;
      while (!g.slots.whereType<Customer>().any((c) => c.isCourier) && guard++ < 200) {
        g.tick(0.1);
      }
      expect(g.delivery.courierHere, isTrue);
      guard = 0;
      while (g.delivery.courierHere && guard++ < 400) {
        g.tick(0.1);
      }
      expect(g.delivery.courierHere, isFalse);
      expect(g.delivery.courierMisses, 1);
      expect(g.deliveredToday, 0);
      g.dispose();
    });

    test('kutuda çok bekleyen dürüm soğur; hazırlanmayan sipariş iptal olur', () {
      final d = DeliveryState();
      OrderSpec spec() => const OrderSpec(nohut: 2, piyaz: false, aci: false);
      d.orders.add(DeliveryOrder(id: 1, spec: spec(), deadline: 85));
      d.orders.add(DeliveryOrder(id: 2, spec: spec(), deadline: 85));
      d.box(0, Assembly()..bread = true..wrapped = true..nohut = 2, 0);
      d.courierLeft = 100;
      final out = <DeliveryOutcome>[];
      for (var i = 0; i < 4000; i++) {
        out.addAll(d.tick(0.1, newSpec: spec, spawning: false, dagitimLevel: 0, deadline: 85));
        if (d.orders.isEmpty) break;
        if (i == 3000) d.courierLeft = 0.05; // kurye şimdi gelsin
      }
      final boxed = out.where((o) => o.made != null).toList();
      expect(boxed, hasLength(1));
      expect(boxed.first.cold, isTrue);
      expect(out.where((o) => o.made == null), hasLength(1), reason: 'kutuya girmeyen sipariş zaman aşımına uğradı');
    });

    test('Dağıtım Motoru: kutu kapasitesi artar, kurye sıklaşır', () {
      final d = DeliveryState();
      expect(d.boxCapacity(2), greaterThan(d.boxCapacity(0)));
      expect(d.courierInterval(3), lessThan(d.courierInterval(0)));
    });
  });

  group('soruşturma', () {
    final data = loadDetective();

    test('veri bütünlüğü: ipuçları, şüpheliler, gerekli kanıtlar tanımlı', () {
      expect(data.suspects.map((s) => s.id), contains(data.culprit));
      for (final n in data.needs) {
        expect(data.clues.containsKey(n), isTrue, reason: n);
      }
      for (final l in data.locations) {
        for (final s in l.steps) {
          expect(data.clues.containsKey(s.clue), isTrue, reason: '${l.id}: ${s.clue}');
        }
      }
      data.talk.forEach((sid, qs) {
        expect(data.suspects.map((s) => s.id), contains(sid));
        for (final q in qs) {
          if (q.clue != null) expect(data.clues.containsKey(q.clue), isTrue, reason: '$sid/${q.id}');
          for (final r in q.requires) {
            expect(data.clues.containsKey(r), isTrue, reason: '$sid/${q.id} requires $r');
          }
          for (final l in q.answers) {
            expect(kStoryRolesForTest, contains(l.who));
          }
        }
      });
    });

    test('tüm ipuçları ulaşılabilir (sınırsız hamle ile) ve gerekli kanıt toplanabilir', () {
      final cs = CaseState(data)..actionsLeft = 999;
      var progress = true;
      while (progress) {
        progress = false;
        for (final l in data.locations) {
          while (cs.nextStep(l) != null) {
            cs.clues.add(cs.nextStep(l)!.clue);
            cs.inspected[l.id] = (cs.inspected[l.id] ?? 0) + 1;
            progress = true;
          }
        }
        data.talk.forEach((sid, qs) {
          for (final q in qs) {
            if (cs.canAsk(q, sid)) {
              cs.asked.add('$sid/${q.id}');
              if (q.clue != null) cs.clues.add(q.clue!);
              progress = true;
            }
          }
        });
      }
      expect(cs.hasEvidence, isTrue);
      expect(cs.clues.length, data.clues.length, reason: 'bazı ipuçları hiçbir yoldan bulunamıyor');
    });

    test('hamle hakkı: gece 2 hamle; kontrolcü yeniden sıfırlar', () {
      final g = makeGame();
      g.quests.chapter = 5;
      g.quests.chapterIntroSeen = true;
      g.caseState!.newNight();
      expect(g.caseInspect('firin'), isTrue);
      expect(g.caseInspect('sokak'), isTrue);
      expect(g.caseInspect('carsi'), isFalse, reason: 'hakkı bitti');
      expect(g.caseState!.clues, containsAll(['kul_izi', 'kizak_izi']));
      g.dispose();
    });

    test('kilitli soru ipucu olmadan sorulamaz; yanlış suçlama ceza keser; doğru suçlama davayı çözer', () {
      final g = makeGame();
      g.quests.chapter = 5;
      g.quests.chapterIntroSeen = true;
      g.money = 1000;
      final cs = g.caseState!..actionsLeft = 99;
      final m2 = data.talk['maskeli']!.firstWhere((q) => q.id == 'm2');
      expect(g.caseAsk('maskeli', m2), isFalse, reason: 'bilezik bulunmadan sorulamaz');

      g.caseAccuse('rakip');
      expect(g.money, 1000 - data.wrongPenalty);
      expect(cs.wrong, 1);
      expect(cs.solved, isFalse);

      g.caseAccuse(data.culprit);
      expect(cs.solved, isFalse, reason: 'kanıt yetersiz');
      // kanıtları topla
      g.caseInspect('firin');
      g.caseInspect('carsi');
      expect(g.caseAsk('maskeli', m2), isTrue);
      final d1 = data.talk['dayi']!.firstWhere((q) => q.id == 'd1');
      final d2 = data.talk['dayi']!.firstWhere((q) => q.id == 'd2');
      expect(g.caseAsk('dayi', d1), isTrue);
      expect(g.caseAsk('dayi', d2), isTrue);
      expect(cs.hasEvidence, isTrue);
      g.caseAccuse(data.culprit);
      expect(cs.solved, isTrue);
      g.dispose();
    });

    test('ClueEvent görevleri ilerletir; "solved" yalnızca çözüm görevini sayar', () {
      final g = makeGame();
      g.quests.chapter = 5;
      g.quests.chapterIntroSeen = true;
      g.emit(const ClueEvent('kul_izi'));
      expect(g.quests.done, contains('c5q1'));
      g.emit(const ClueEvent('solved'));
      expect(g.quests.mainQuest!.def.id, 'c5q2', reason: 'solved sıradan ipucu sayılmaz');
      g.dispose();
    });
  });

  test('Bölüm 4 ve 5 görevleri ve hikâye sahneleri tanımlı', () {
    final qd = loadQuests();
    expect(qd.chapters.map((c) => c.id), [1, 2, 3, 4, 5]);
    final story = loadStory();
    for (final id in ['c4_intro', 'c4_outro', 'c5_intro', 'c5_mid', 'c5_solved', 'c5_outro']) {
      expect(story.scenes.containsKey(id), isTrue, reason: id);
    }
  });
}

const kStoryRolesForTest = {'usta', 'rakip', 'maskeli', 'dayi', 'antikaci', 'nine', 'anlatici', 'itfaiyeci', 'yatirimci'};
