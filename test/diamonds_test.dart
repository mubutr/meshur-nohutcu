import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/game/scoring.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('reklam (sahte)', () {
    test('para reklamı: geri sayım bitince ödül gelir, oyun reklam sırasında durur', () {
      final g = playing();
      final m0 = g.money;
      g.startAd('money');
      expect(g.adKind, 'money');
      expect(g.paused, isTrue);
      g.tick(1);
      expect(g.money, m0);
      for (var i = 0; i < 60; i++) {
        g.tick(0.1);
      }
      expect(g.adKind, isNull);
      expect(g.money, m0 + g.adMoneyReward);
      expect(g.adMoneyReward, (cfg.eco('adMoneyBase') + cfg.eco('adMoneyPerChapter') * g.chapter).round());
      g.dispose();
    });

    test('elmas reklamı +1 elmas verir ve olay yayar', () {
      final g = playing();
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      g.startAd('diamond');
      for (var i = 0; i < 60; i++) {
        g.tick(0.1);
      }
      expect(g.diamonds, 1);
      expect(events.whereType<DiamondEvent>().single.source, 'ad');
      g.dispose();
    });

    test('günlük sınır: para ve elmas reklamları ayrı sayılır', () {
      final g = playing();
      for (var k = 0; k < 6; k++) {
        g.startAd('diamond');
        g.tick(10);
      }
      expect(g.diamonds, cfg.eco('adDiamondMax').round());
      expect(g.canWatchAd('diamond'), isFalse);
      expect(g.canWatchAd('money'), isTrue);
      g.startAd('diamond');
      expect(g.adKind, isNull, reason: 'limit dolu');
      g.startDay();
      expect(g.canWatchAd('diamond'), isTrue, reason: 'yeni gün sıfırlanır');
      g.dispose();
    });

    test('reklam iptal edilirse ödül yok; başlık ekranında reklam başlamaz', () {
      final g = playing();
      g.startAd('money');
      final m0 = g.money;
      g.cancelAd();
      g.tick(10);
      expect(g.money, m0);
      g.toTitle();
      g.startAd('money');
      expect(g.adKind, isNull);
      g.dispose();
    });
  });

  group('bonus müşteri (Gezgin)', () {
    test('her 10 normal serviste bir sonraki müşteri Gezgin olur; servis edilince 1 elmas + bol bahşiş', () {
      final g = playing(7);
      g.money = 100000;
      var guard = 0;
      while (g.servedSinceBonus < cfg.eco('bonusEvery') && guard++ < 60000) {
        g.tick(0.1);
        final idx = g.slots.indexWhere((c) => c != null && c.state == CustomerState.waiting && c.kind != CustomerKind.garip && !c.isCourier);
        if (idx >= 0 && g.assembly.isEmpty && guard % 15 == 0) makeAndServe(g, idx);
        if (g.phase != Phase.playing) {
          g.startDay();
          skipScenes(g);
        }
      }
      expect(g.bonusDue, isTrue);
      Customer? bonus;
      guard = 0;
      while (bonus == null && guard++ < 60000) {
        g.tick(0.1);
        bonus = g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.bonus && c.state == CustomerState.waiting).firstOrNull;
        if (g.phase != Phase.playing) {
          g.startDay();
          skipScenes(g);
        }
      }
      expect(bonus, isNotNull, reason: 'Gezgin gelmedi');
      expect(bonus!.sprite, 'gezgin');
      expect(g.bonusDue, isFalse);
      expect(g.servedSinceBonus, 0);
      final jar0 = g.tipJar;
      final idx = g.slots.indexOf(bonus);
      // hatalı servis bile elmas verir (kalite fark etmez)
      g.assembly
        ..reset()
        ..bread = true
        ..wrapped = true;
      g.serve(idx);
      expect(g.diamonds, cfg.eco('bonusDiamonds').round());
      expect(g.tipJar - jar0, greaterThanOrEqualTo((orderPrice(cfg, bonus.spec) * 0.3).round()));
      // bonus servis sayacı sıfırdan başlatır
      expect(g.servedSinceBonus, 0);
      g.dispose();
    });

    test('Gezgin küserse elmas bırakmaz ama ceza da yok sayılmaz değil: sıradan müşteri gibi ceza', () {
      final g = playing(7);
      g.bonusDue = true;
      Customer? bonus;
      for (var i = 0; i < 400 && bonus == null; i++) {
        g.tick(0.1);
        bonus = g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.bonus).firstOrNull;
      }
      expect(bonus, isNotNull);
      bonus!.patience = 0.05;
      bonus.state = CustomerState.waiting;
      for (var i = 0; i < 5; i++) {
        g.tick(0.1);
      }
      expect(g.diamonds, 0);
      g.dispose();
    });
  });

  group('görev serisi', () {
    int streakGiven(GameController g) => g.diamonds;

    void doDay(GameController g, int day, {required bool doneAny}) {
      g.quests.onDayStart(day);
      if (doneAny) {
        g.quests.daily.first.done = true;
        g.quests.dailyDoneToday++;
      }
      // günün kendisi başka bir günlük görevi tamamlamasın diye kötü bir gün
      g.quests.handle(DayEndedEvent(day: day, served: 5, great: 0, lost: 3, earned: 100, tips: 10, netProfit: 50, score: 1, reputation: 0.1));
    }

    test('ardışık 3 günde en az bir günlük görev → 2 elmas; sayaç sıfırlanır', () {
      final g = makeGame();
      g.quests.startNewGame();
      doDay(g, 1, doneAny: true);
      doDay(g, 2, doneAny: true);
      expect(streakGiven(g), 0);
      expect(g.quests.dailyStreak, 2);
      doDay(g, 3, doneAny: true);
      expect(g.diamonds, cfg.eco('streakDiamonds').round());
      expect(g.quests.dailyStreak, 0);
      expect(g.quests.toasts.any((t) => t.title.contains('Görev serisi')), isTrue);
      g.dispose();
    });

    test('bir gün görev yapılmazsa seri sıfırlanır', () {
      final g = makeGame();
      g.quests.startNewGame();
      doDay(g, 1, doneAny: true);
      doDay(g, 2, doneAny: false);
      expect(g.quests.dailyStreak, 0);
      doDay(g, 3, doneAny: true);
      doDay(g, 4, doneAny: true);
      expect(g.diamonds, 0);
      doDay(g, 5, doneAny: true);
      expect(g.diamonds, cfg.eco('streakDiamonds').round());
      g.dispose();
    });

    test('gün atlanırsa (oynanmayan gün) seri kopar', () {
      final g = makeGame();
      g.quests.startNewGame();
      doDay(g, 1, doneAny: true);
      doDay(g, 3, doneAny: true);
      expect(g.quests.dailyStreak, 1);
      g.dispose();
    });

    test('seri kaydı yükleme sonrası korunur', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final g = GameController(cfg: cfg, dialog: loadDialog(), questData: loadQuests(), story: loadStory(), riddles: loadRiddles(), detectiveData: loadDetective(), random: Random(1), prefs: prefs);
      g.quests.startNewGame();
      doDay(g, 1, doneAny: true);
      doDay(g, 2, doneAny: true);
      g.diamonds = 7;
      g.tipJar = 33;
      await g.save();
      final g2 = GameController(cfg: cfg, dialog: loadDialog(), questData: loadQuests(), story: loadStory(), riddles: loadRiddles(), detectiveData: loadDetective(), random: Random(1), prefs: prefs)..load();
      expect(g2.quests.dailyStreak, 2);
      expect(g2.diamonds, 7);
      expect(g2.tipJar, 33);
      g.dispose();
      g2.dispose();
    });
  });

  group('elmasla alınan yükseltme ve dekor', () {
    test('otomasyon modülü elmasla alınır, para yetmez; bölüm kilidi uygulanır', () {
      final g = makeGame();
      final auto = cfg.upgrades.firstWhere((u) => u.id == 'auto_ekmek');
      expect(auto.withDiamonds, isTrue);
      g.money = 100000;
      g.diamonds = 100;
      expect(g.buy(auto), isFalse, reason: 'Bölüm 2 öncesi kilitli');
      g.quests.chapter = 2;
      g.diamonds = auto.costs.first - 1;
      expect(g.buy(auto), isFalse, reason: 'elmas yetmez; para ile alınamaz');
      g.diamonds = auto.costs.first + 2;
      final m = g.money;
      expect(g.buy(auto), isTrue);
      expect(g.money, m, reason: 'para düşmez');
      expect(g.diamonds, 2);
      expect(g.level('auto_ekmek'), 1);
      expect(g.buy(auto), isFalse, reason: 'tek seviye');
      g.dispose();
    });

    test('elmaslı dekor hem para hem elmas ister; elmas fiyatı bölümle artar', () {
      final g = makeGame();
      g.quests.chapter = 5;
      final sutun = cfg.decor.firstWhere((d) => d.id == 'sutun');
      expect(sutun.diamonds, greaterThan(0));
      g.money = sutun.cost;
      g.diamonds = sutun.diamonds - 1;
      expect(g.buyDecor(sutun), isFalse);
      g.diamonds = sutun.diamonds;
      expect(g.buyDecor(sutun), isTrue);
      expect(g.money, 0);
      expect(g.diamonds, 0);
      final byChapter = {for (final d in cfg.decor.where((d) => d.diamonds > 0)) d.id: (d.minChapter, d.diamonds)};
      final early = byChapter.values.where((e) => e.$1 <= 2).map((e) => e.$2).reduce(max);
      final late = byChapter.values.where((e) => e.$1 >= 4).map((e) => e.$2).reduce(min);
      expect(late, greaterThanOrEqualTo(early), reason: 'sonraki bölümlerde elmas almak zorlaşır');
      g.dispose();
    });
  });

  group('otomasyon', () {
    test('dört modül birlikte: sipariş hatasız hazırlanır, sarılır; oyuncu yalnızca verir', () {
      final g = playing(9, 5);
      g.money = 100000;
      for (final id in ['auto_ekmek', 'auto_ana', 'auto_ek', 'auto_sar']) {
        g.upgrades[id] = 1;
      }
      Customer? target;
      var guard = 0;
      while (!g.assembly.wrapped && guard++ < 4000) {
        g.tick(0.1);
        target ??= g.autoTarget;
      }
      expect(g.assembly.wrapped, isTrue, reason: 'otomasyon dürümü bitirmedi');
      final c = g.slots.whereType<Customer>().firstWhere((c) => orderErrors(c.spec, g.assembly) == 0, orElse: () => throw StateError('hazırlanan dürüm hiçbir siparişe uymuyor'));
      expect(g.assembly.spent, ingredientCost(cfg, c.spec), reason: 'malzeme parası düşer');
      final idx = g.slots.indexOf(c);
      g.serve(idx);
      expect(g.greatToday, 1);
      g.dispose();
    });

    test('yalnızca ekmek açıcı: ekmeği koyar, gerisini oyuncuya bırakır', () {
      final g = playing(9, 2);
      g.upgrades['auto_ekmek'] = 1;
      var guard = 0;
      while (g.assembly.isEmpty && guard++ < 600) {
        g.tick(0.1);
      }
      expect(g.assembly.bread, isTrue);
      for (var i = 0; i < 100; i++) {
        g.tick(0.1);
      }
      expect(g.assembly.nohut, 0);
      expect(g.assembly.wrapped, isFalse);
      g.dispose();
    });

    test('bilmece ve garip müşteriler için otomasyon çalışmaz (oyuncu çözmeli)', () {
      final g = playing(9, 2);
      g.upgrades['auto_ekmek'] = 1;
      final spec = const OrderSpec(nohut: 1, piyaz: false, aci: false);
      final riddle = Customer(
        type: cfg.customers.first,
        name: cfg.customers.first.names.first,
        spec: spec,
        maxPatience: 100,
        order: loadDialog().say('garip_ask'),
        kind: CustomerKind.riddle,
      )
        ..patience = 100
        ..state = CustomerState.waiting;
      g.slots = [riddle, null, null];
      g.toSpawn = 0;
      for (var i = 0; i < 50; i++) {
        g.tick(0.1);
      }
      expect(g.assembly.isEmpty, isTrue);
      g.dispose();
    });

    test('Yardımcı Çırak son seviyede hatasızdır; yeni ürünleri de hazırlar', () {
      final g = playing(9, 4);
      g.upgrades['yardimci'] = cfg.upgrades.firstWhere((u) => u.id == 'yardimci').max;
      expect(g.helperAccuracy, 1.0);
      g.money = 100000;
      var guard = 0;
      while (g.helper.ready == null && guard++ < 6000) {
        g.tick(0.1);
      }
      expect(g.helper.ready, isNotNull);
      final c = g.slots.whereType<Customer>().firstWhere((c) => c.helperClaim);
      expect(orderErrors(c.spec, g.helper.ready!), 0);
      g.dispose();
    });
  });
}
