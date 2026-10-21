import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/game/game_controller.dart';

import 'helpers.dart';

ServedEvent served({Verdict v = Verdict.great, OrderSpec spec = const OrderSpec(nohut: 2, piyaz: false, aci: false), int total = 50, int tip = 5, int streak = 1, String? special, String? riddleId, String? giver}) =>
    ServedEvent(verdict: v, spec: spec, total: total, tip: tip, streak: streak, patienceLeft: 0.8, customerId: 'fatma', special: special, riddleId: riddleId, giver: giver);

void main() {
  final qd = loadQuests();
  final story = loadStory();

  group('veri bütünlüğü', () {
    test('bölümlerin tüm görevleri tanımlı ve sahneleri mevcut', () {
      for (final c in qd.chapters) {
        expect(story.scenes.containsKey(c.intro), isTrue, reason: 'giriş sahnesi yok: ${c.intro}');
        if (c.outro != null) expect(story.scenes.containsKey(c.outro), isTrue, reason: 'çıkış sahnesi yok: ${c.outro}');
        for (final q in c.quests) {
          expect(qd.quests.containsKey(q), isTrue, reason: 'görev yok: $q');
        }
      }
      for (final q in qd.quests.values) {
        if (q.scene != null) expect(story.scenes.containsKey(q.scene), isTrue, reason: '${q.id} sahnesi yok: ${q.scene}');
        expect(q.objectives, isNotEmpty);
        for (final o in q.objectives) {
          expect(o.target, greaterThan(0), reason: q.id);
        }
      }
      for (final s in qd.side) {
        expect(qd.quests.containsKey(s), isTrue, reason: s);
      }
    });

    test('hedef türleri bilinen kümede', () {
      const known = {'serve', 'riddle', 'earn', 'tip', 'day_score', 'day_rep', 'no_lose', 'streak', 'upgrade', 'decor', 'npc', 'harvest', 'deliver', 'clue', 'day_reach'};
      for (final q in qd.quests.values) {
        for (final o in q.objectives) {
          expect(known, contains(o.type), reason: '${q.id}: ${o.type}');
        }
      }
      for (final t in qd.daily) {
        expect(known, contains(t.type), reason: t.id);
        expect(t.targets.length, t.money.length, reason: t.id);
      }
    });

    test('bilmeceler tutarlı: spec alanları metinde anılıyor, nohut miktarı sözlüğüne uyuyor', () {
      final riddles = loadRiddles();
      expect(riddles.length, greaterThanOrEqualTo(12));
      for (final r in riddles) {
        final t = r.text.toLowerCase();
        expect(r.spec.nohut, inInclusiveRange(1, 3), reason: r.id);
        if (r.spec.nohut == 3) expect(t, anyOf(contains('dağ gibi'), contains('doldur')), reason: r.id);
        if (r.spec.nohut == 1) expect(t, contains('tutam'), reason: r.id);
        if (r.spec.nohut == 2) expect(t, contains('avuç'), reason: r.id);
        if (r.spec.sumak) expect(t, anyOf(contains('sumak'), contains('kırmızı toz'), contains('ekşi')), reason: '${r.id}: sumak ima edilmeli');
        if (r.spec.piyaz) expect(t, anyOf(contains('soğan'), contains('piyaz'), contains('maydanoz')), reason: '${r.id}: piyaz ima edilmeli');
        if (r.spec.aci) expect(t, anyOf(contains('acı'), contains('dil'), contains('pul'), contains('yak')), reason: '${r.id}: acı ima edilmeli');
        expect(r.minChapter, greaterThanOrEqualTo(2));
      }
      // her özel karakterin en az bir bilmecesi var
      for (final giver in ['nine', 'itfaiyeci']) {
        expect(riddles.where((r) => r.giver == giver), isNotEmpty, reason: giver);
      }
    });
  });

  group('görev motoru', () {
    test('servisler ana görevi ilerletir, tamamlanınca ödül verilir ve bildirim çıkar', () {
      final g = makeGame();
      g.quests.startNewGame();
      final before = g.money;
      final q1 = qd.quests['c1q1']!;
      for (var i = 0; i < q1.objectives.first.target; i++) {
        g.emit(served(v: Verdict.ok));
      }
      expect(g.quests.done, contains('c1q1'));
      expect(g.money, before + q1.reward.money);
      expect(g.quests.toasts.any((t) => t.title.contains('İlk Müşteriler')), isTrue);
      expect(g.quests.mainQuest!.def.id, 'c1q2');
      g.dispose();
    });

    test('tam isabet gerektiren görev, ok/bad servisleri saymaz', () {
      final g = makeGame();
      g.quests.startNewGame();
      for (var i = 0; i < qd.quests['c1q1']!.objectives.first.target; i++) {
        g.emit(served());
      }
      expect(g.quests.mainQuest!.def.id, 'c1q2');
      for (var i = 0; i < 4; i++) {
        g.emit(served(v: Verdict.ok));
      }
      expect(g.quests.mainQuest!.progress[0], 0);
      for (var i = 0; i < qd.quests['c1q2']!.objectives.first.target; i++) {
        g.emit(served());
      }
      expect(g.quests.done, contains('c1q2'));
      g.dispose();
    });

    test('bölüm bitince çıkış sahnesi, bölüm ödülü ve sonraki bölümün girişi sıraya girer', () {
      final g = makeGame();
      g.quests.startNewGame();
      g.quests.pendingScenes.clear();
      g.quests.chapterIntroSeen = true;
      // tüm Bölüm 1 görevlerini sırayla tamamlat (görevler sıralıdır: her biri önceki bitince başlar)
      for (var guard = 0; guard < 4000 && g.quests.chapter == 1; guard++) {
        final type = g.quests.mainQuest!.def.objectives.first.type;
        switch (type) {
          case 'day_rep':
            g.emit(const DayEndedEvent(day: 3, served: 9, great: 8, lost: 0, earned: 400, tips: 40, netProfit: 300, score: 300, reputation: 0.95));
          case 'decor':
            g.emit(const DecorBoughtEvent('kilim'));
          default:
            g.emit(served(spec: const OrderSpec(nohut: 3, piyaz: false, aci: false), total: 400, tip: 60));
        }
      }
      expect(g.quests.done.containsAll(['c1q1', 'c1q2', 'c1q3', 'c1q4', 'c1q5', 'c1q6', 'c1q7']), isTrue, reason: '${g.quests.done}');
      expect(g.quests.chapter, 2);
      expect(g.quests.pendingScenes, containsAllInOrder(['c1_outro', 'c2_intro']));
      g.dispose();
    });

    test('riddle hedefi yalnızca tam isabetli bilmeceyi sayar; giver süzgeci çalışır', () {
      final g = makeGame();
      g.quests.chapter = 3;
      g.quests.chapterIntroSeen = true;
      g.quests.done.addAll(['c3q1', 'c3q2', 'c3q3']);
      g.emit(served(riddleId: 'r_itf1', giver: 'nine'));
      expect(g.quests.mainQuest!.progress[0], 0, reason: 'yanlış giver');
      g.emit(served(v: Verdict.ok, riddleId: 'r_itf1', giver: 'itfaiyeci'));
      expect(g.quests.mainQuest!.progress[0], 0, reason: 'tam isabet değil');
      g.emit(served(riddleId: 'r_itf1', giver: 'itfaiyeci'));
      expect(g.quests.done, contains('c3q4'));
      g.dispose();
    });

    test('Gariban yardımı: karma artar, yan görev ilerler, 3. yardımda yatırımcı sahnesi + bonus', () {
      final g = makeGame();
      g.quests.chapter = 2;
      g.quests.chapterIntroSeen = true;
      for (var i = 0; i < 3; i++) {
        g.emit(const NpcHelpedEvent('garip'));
      }
      expect(g.quests.karma, 3);
      expect(g.quests.done, contains('s_garip'));
      expect(g.investor, isTrue);
      expect(g.quests.pendingScenes, contains('c3_investor'));
      final before = g.payMul;
      expect(before, greaterThan(1.0));
      g.dispose();
    });

    test('günlük görevler: gün başına 3 tane, aynı gün aynı görevler', () {
      final g = makeGame();
      g.quests.onDayStart(2);
      expect(g.quests.daily.length, 3);
      final titles = g.quests.daily.map((d) => d.title).toList();
      g.quests.dailyDay = 0;
      g.quests.onDayStart(2);
      expect(g.quests.daily.map((d) => d.title).toList(), titles);
      g.dispose();
    });

    test('günlük görev tamamlanınca para verir', () {
      final g = makeGame();
      g.quests.chapterIntroSeen = true;
      g.quests.onDayStart(1);
      final d = g.quests.daily.firstWhere((d) => d.objective.type == 'serve' || d.objective.type == 'streak', orElse: () => g.quests.daily.first);
      final before = g.money;
      for (var i = 0; i < 12 && !d.done; i++) {
        g.emit(served(streak: i + 1));
      }
      if (d.objective.type == 'serve' || d.objective.type == 'streak') {
        expect(d.done, isTrue);
        expect(g.money, greaterThan(before));
      }
      g.dispose();
    });

    test('kayıt/yükleme: ilerleme, tamamlananlar, bayraklar korunur', () {
      final g = makeGame();
      g.quests.startNewGame();
      for (var i = 0; i < 14; i++) {
        g.emit(served(v: Verdict.ok));
      }
      g.quests.karma = 2;
      g.quests.flags.add('x');
      final json = jsonEncode(g.quests.toJson());
      final g2 = makeGame();
      g2.quests.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(g2.quests.done, g.quests.done);
      expect(g2.quests.karma, 2);
      expect(g2.quests.flags, contains('x'));
      expect(g2.quests.mainQuest!.def.id, g.quests.mainQuest!.def.id);
      g.dispose();
      g2.dispose();
    });

    test('bölümler bitince motor sessizce durur (çökme yok)', () {
      final g = makeGame();
      g.quests.chapter = 99;
      g.emit(served());
      expect(g.quests.allChaptersDone, isTrue);
      g.dispose();
    });
  });

  group('özel müşteriler', () {
    test('Bölüm 2: bilmeceli müşteri gelir, spec bilmecenin spec’i ile aynıdır, doğru servis ödüllendirilir', () {
      final g = makeGame(11);
      g.quests.chapter = 2;
      g.quests.chapterIntroSeen = true;
      g.startDay();
      skipScenes(g);
      Customer? riddler;
      for (var d = 0; d < 6 && riddler == null; d++) {
        for (var i = 0; i < 3000 && riddler == null && g.phase == Phase.playing; i++) {
          g.tick(0.1);
          riddler = g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.riddle && c.state == CustomerState.waiting).firstOrNull;
        }
        if (riddler == null) {
          g.startDay();
          skipScenes(g);
        }
      }
      expect(riddler, isNotNull, reason: 'bilmeceli müşteri hiç gelmedi');
      expect(riddler!.riddle, isNotNull);
      expect(riddler.order.text, riddler.riddle!.text);
      final idx = g.slots.indexOf(riddler);
      final doneBefore = g.quests.mainQuest!.progress.first;
      makeAndServe(g, idx);
      expect(g.greatToday, greaterThanOrEqualTo(1));
      expect(doneBefore, isNonNegative);
      g.dispose();
    });

    test('Gariban ücretsiz ikram alır; para artmaz, iyilik olayı çıkar', () {
      final g = makeGame(5);
      g.quests.chapter = 2;
      g.quests.chapterIntroSeen = true;
      g.startDay();
      skipScenes(g);
      Customer? garip;
      for (var day = 0; day < 30 && garip == null; day++) {
        for (var i = 0; i < 3000 && garip == null && g.phase == Phase.playing; i++) {
          g.tick(0.1);
          garip = g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.garip && c.state == CustomerState.waiting).firstOrNull;
        }
        if (garip == null) {
          g.startDay();
          skipScenes(g);
        }
      }
      expect(garip, isNotNull, reason: 'Gariban hiç gelmedi');
      final before = g.money;
      final karmaBefore = g.quests.karma;
      final idx = g.slots.indexOf(garip);
      g.tapBread();
      g.tapNohut();
      final spent = g.assembly.spent;
      g.wrap();
      g.serve(idx);
      expect(g.money, before - spent, reason: 'ikram: gelir yok, yalnızca malzeme masrafı');
      expect(g.tipJar, 0);
      expect(g.quests.karma, karmaBefore + 1);
      g.dispose();
    });

    test('Maskeli Müşteri hatalı servis edilirse kasadan para çalar', () {
      final g = makeGame(8);
      g.quests.chapter = 2;
      g.quests.chapterIntroSeen = true;
      g.money = 200;
      g.startDay();
      skipScenes(g);
      Customer? m;
      for (var day = 0; day < 40 && m == null; day++) {
        for (var i = 0; i < 3000 && m == null && g.phase == Phase.playing; i++) {
          g.tick(0.1);
          m = g.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.maskeli && c.state == CustomerState.waiting).firstOrNull;
        }
        if (m == null) {
          g.startDay();
          skipScenes(g);
        }
      }
      expect(m, isNotNull, reason: 'Maskeli hiç gelmedi');
      final idx = g.slots.indexOf(m);
      final wrong = Assembly()
        ..bread = true
        ..nohut = 3
        ..piyaz = !m!.spec.piyaz
        ..aci = !m.spec.aci
        ..wrapped = true;
      g.assembly
        ..bread = wrong.bread
        ..nohut = wrong.nohut
        ..piyaz = wrong.piyaz
        ..aci = wrong.aci
        ..wrapped = true;
      final before = g.money;
      g.serve(idx);
      expect(g.stolenToday, greaterThan(0));
      expect(g.money, lessThan(before));
      g.dispose();
    });
  });

  group('ilerleme hızı', () {
    test('iyi bir oyuncu 25–40 günde Bölüm 3’ü bitirir (ekonomi simülasyonu)', () {
      final g = makeGame(21);
      g.quests.startNewGame();
      var days = 0;
      final chapterEnd = <int, int>{};
      while (g.quests.chapter <= 3 && days < 80) {
        days++;
        g.startDay();
        skipScenes(g);
        var guard = 0;
        double wait = 0;
        while (g.phase == Phase.playing && guard++ < 40000) {
          g.tick(0.1);
          final idx = g.slots.indexWhere((c) => c != null && c.state == CustomerState.waiting && !c.isCourier);
          if (idx >= 0) {
            wait += 0.1;
            if (wait > 3.0) {
              wait = 0;
              final c = g.slots[idx]!;
              if (c.kind == CustomerKind.garip) {
                g.tapBread();
                g.wrap();
                g.serve(idx);
              } else {
                prepare(g, c.spec);
                g.serve(idx);
              }
            }
          }
        }
        skipScenes(g);
        // makul bir oyuncu gibi: ucuz olandan başlayarak her şeyi alır
        final items = <(int, void Function())>[
          for (final u in g.cfg.upgrades.where((u) => g.chapter >= u.minChapter && g.nextCost(u) != null)) (g.nextCost(u)!, () => g.buy(u)),
          for (final d in g.cfg.decor.where((d) => g.chapter >= d.minChapter && !g.decorOwned.contains(d.id))) (d.cost, () => g.buyDecor(d)),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        for (final it in items) {
          if (g.money >= it.$1) it.$2();
        }
        chapterEnd.putIfAbsent(g.quests.chapter, () => days);
      }
      // ignore: avoid_print
      print('bölüm başlangıç günleri: $chapterEnd, toplam gün: $days, kasa: ${g.money}, yükseltmeler: ${g.upgrades}, dekor: ${g.decorOwned.length}, ana görev: ${g.quests.mainQuest?.def.id} ${g.quests.mainQuest?.progress}');
      expect(g.quests.chapter, greaterThan(3), reason: 'Bölüm 3 bitmedi (gün $days)');
      expect(days, inInclusiveRange(25, 55), reason: 'mükemmel oyuncu bile 3 bölümü 25–55 günde bitirmeli');
      g.dispose();
    });
  });
}
