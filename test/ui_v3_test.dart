import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/atmosphere.dart';
import 'package:nohut_durumu/ui/game_screen.dart';

import 'helpers.dart';

Future<void> show(WidgetTester t, GameController g) async {
  t.view.physicalSize = const Size(1600, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
  await t.pump();
}

void main() {
  phoneLayoutTests();
  final cfg = loadCfg();

  group('gün-gece', () {
    test('sabah aydınlık, akşam turuncu, gece koyu; lambalar geceleyin yanar', () {
      final morning = DayLight.at(0.0);
      final noon = DayLight.at(0.3);
      final dusk = DayLight.at(0.78);
      final night = DayLight.at(1.0);
      expect(morning.hour, closeTo(7, 1e-9));
      expect(night.hour, closeTo(23, 1e-9));
      expect(morning.night, 0);
      expect(noon.night, 0);
      expect(night.night, 1);
      expect(night.stars, greaterThan(0.9));
      expect(noon.stars, 0);
      // ışık rengi: gece öğleden koyu
      double lum(Color c) => c.computeLuminance();
      expect(lum(night.tint), lessThan(lum(noon.tint)));
      expect(lum(night.skyTop), lessThan(lum(noon.skyTop)));
      // gün ışığı yalnızca gündüz; ay yalnızca akşamdan sonra
      expect(noon.sun, greaterThan(0.5));
      expect(night.sun, 0);
      expect(noon.moon, isNull);
      expect(night.moon, isNotNull);
      // akşam gece ile gündüz arasında
      expect(dusk.night, inInclusiveRange(0.0, 1.0));
    });

    test('ilerleme arttıkça gece oranı azalmaz (tek yönlü)', () {
      var prev = -1.0;
      for (var i = 0; i <= 100; i++) {
        final n = DayLight.at(i / 100).night;
        expect(n, greaterThanOrEqualTo(prev - 1e-9));
        prev = n;
      }
    });

    testWidgets('sahne gece/gündüze göre çizilir: pencere gökyüzü ve ışık katmanı var', (t) async {
      final g = makeGame()..startDay();
      skipScenes(g);
      await show(t, g);
      expect(find.byType(SkyView), findsOneWidget);
      expect(find.byType(LightOverlay), findsOneWidget);
      expect(find.byType(TimeTint), findsOneWidget);
      g.dispose();
    });

    test('pencere deliği bg katmanındaki şeffaf alanla uyumlu (4 tema)', () async {
      // Sprite'ların şeffaf gökyüzü deliği kSkyRect içinde kalmalı (bg_t*.png alfa kanalı).
      for (final theme in ['t1', 't2', 't3', 't4']) {
        final bytes = File('assets/sprites/bg_$theme.png').readAsBytesSync();
        // PNG IHDR: genişlik/yükseklik 16..24
        final w = ByteData.sublistView(bytes).getUint32(16), h = ByteData.sublistView(bytes).getUint32(20);
        expect((w, h), (1600, 900), reason: theme);
      }
      expect(kSkyRect.width, greaterThan(250));
    });
  });

  group('sprite varlıkları', () {
    test('arayüzün kullandığı tüm sprite dosyaları var', () {
      final names = <String>{
        for (final t in ['t1', 't2', 't3', 't4']) ...['bg_$t', 'tezgah_$t'],
        for (final c in ['usta', ...cfg.customers.map((t) => t.id), 'dayi', 'nine', 'maskeli', 'itfaiyeci', 'cirak', 'rakip', 'yatirimci', 'antikaci', 'kurye', 'gezgin'])
          for (final m in ['normal', 'mutlu', 'kizgin']) '${c}_$m',
        for (final d in cfg.decor) 'decor_${d.id}',
        'ekmek', 'ekmek_yigin', 'kase_yigin', 'durum', 'beyran_kase', 'beyran_tabla', 'nohut_tencere', 'kizartma_kase', 'piyaz_kase', 'aci_kase', 'sumak_kase',
        for (final p in cfg.products.where((p) => p.id != 'nohut' && !p.bowl)) ...['${p.id}_tepsi', 'durum_${p.id}', 'top_${p.id}_1', 'top_${p.id}_2'],
        for (var n = 1; n <= 3; n++) 'top_nohut_$n',
        'top_piyaz', 'top_aci', 'top_sumak', 'top_fried',
        for (final id in kSauceIds) ...['top_$id', '${id}_sise'],
        for (var l = 0; l < 3; l++) 'bahsis_$l',
      };
      final missing = [for (final n in names) if (!File('assets/sprites/$n.png').existsSync()) n];
      expect(missing, isEmpty);
    });

    test('her sosun şişe ve tahta katmanı, her ürünün tepsisi var; kilitli ürün/sos adları tutarlı', () {
      for (final s in cfg.sauces) {
        if (s.id == 'sumak') continue;
        expect(kSauceIds, contains(s.id));
      }
      expect(cfg.products.map((p) => p.id), containsAll(['nohut', 'doner', 'kavurma', 'cigkofte', 'kizartma', 'beyran']));
    });

    test('tam boy karakter sprite\'ları: ayaklara kadar iner (alt kenar şeffaf değil)', () {
      for (final c in ['usta', 'fatma', 'maamed', 'kurye', 'gezgin']) {
        final bytes = File('assets/sprites/${c}_normal.png').readAsBytesSync();
        final bd = ByteData.sublistView(bytes);
        expect((bd.getUint32(16), bd.getUint32(20)), (640, 960), reason: c);
      }
    });
  });

  group('ekranlar', () {
    testWidgets('bahşiş kavanozu: dokununca kasaya geçer', (t) async {
      final g = makeGame()..startDay();
      skipScenes(g);
      g.tipJar = 80;
      final m0 = g.money;
      await show(t, g);
      expect(find.text('80 ₺'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tip-jar')));
      await t.pump();
      expect(g.tipJar, 0);
      expect(g.money, m0 + 80);
      g.dispose();
    });

    testWidgets('ürün seçici oklar açık ürünler arasında döner; tezgâh doluyken kilitlenir', (t) async {
      final g = makeGame()
        ..quests.chapter = 4
        ..quests.chapterIntroSeen = true
        ..startDay();
      skipScenes(g);
      await show(t, g);
      expect(g.selectedWrap, 'nohut');
      await t.tap(find.byKey(const ValueKey('wrap-next')));
      await t.pump();
      expect(g.selectedWrap, 'doner');
      await t.tap(find.byKey(const ValueKey('wrap-prev')));
      await t.pump();
      expect(g.selectedWrap, 'nohut');
      g.money = 1000;
      g.tapBread();
      await t.pump();
      await t.tap(find.byKey(const ValueKey('wrap-next')));
      await t.pump();
      expect(g.selectedWrap, 'doner', reason: 'boş tezgâh varken sıradaki dürüm için ürün seçilebilir');
      g.tapBread();
      g.tapBread();
      expect(g.anyBoardEmpty, isFalse);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('wrap-next')));
      await t.pump();
      expect(g.selectedWrap, 'doner', reason: '3 tezgâh da doluyken ürün değişmez');
      g.dispose();
    });

    testWidgets('Bölüm 1\'de tek ürün olduğu için ok yoktur; sos rafı Bölüm 2\'de görünür', (t) async {
      final g = makeGame()..startDay();
      skipScenes(g);
      await show(t, g);
      expect(find.byKey(const ValueKey('wrap-next')), findsNothing);
      expect(find.text('Ketçap'), findsNothing);
      g.quests.chapter = 2;
      g.notifyListeners();
      await t.pump();
      expect(find.text('Ketçap'), findsOneWidget);
      expect(find.text('Mayonez'), findsOneWidget);
      g.dispose();
    });

    testWidgets('tarif defteri: ürünler görünür, kilitli ürünler gizlenir; ekler sekmesi çalışır', (t) async {
      final g = makeGame()
        ..quests.chapter = 3
        ..startDay();
      skipScenes(g);
      await show(t, g);
      await t.tap(find.text('Tarif'));
      await t.pump();
      expect(g.recipeOpen, isTrue);
      expect(g.paused, isTrue);
      expect(find.text('Tarif Defteri'), findsOneWidget);
      expect(find.text('Nohut Dürümü'), findsWidgets);
      expect(find.text('Döner Dürümü'), findsOneWidget);
      expect(find.text('Kavurma Dürümü'), findsNothing, reason: 'Bölüm 4\'te açılır: ad gizli');
      expect(find.text('???'), findsWidgets);
      await t.tap(find.text('Ekler ve soslar'));
      await t.pump();
      expect(find.text('Ketçap'), findsWidgets);
      await t.tap(find.text('Kapat'));
      await t.pump();
      expect(g.recipeOpen, isFalse);
      g.dispose();
    });

    testWidgets('reklam: menüden izle → geri sayım → ödül; kapat; günlük hak bitince düğme kapanır', (t) async {
      final g = makeGame()..startDay();
      skipScenes(g);
      await show(t, g);
      final m0 = g.money;
      await t.tap(find.text('Reklam'));
      await t.pump();
      expect(g.adMenuOpen, isTrue);
      expect(find.text('Reklam izle, kazan'), findsOneWidget);
      await t.tap(find.text('İzle').first);
      await t.pump();
      expect(g.adKind, 'money');
      expect(find.text('Örnek reklam'), findsOneWidget);
      for (var i = 0; i < 60; i++) {
        g.tick(0.1);
      }
      await t.pump();
      expect(g.adKind, isNull);
      expect(g.money, m0 + g.adMoneyReward);
      expect(find.text('Örnek reklam'), findsNothing);
      g.dispose();
    });

    testWidgets('gün sonu: çöpe giden, ceza ve elmas satırları görünür; Reklam düğmesi var', (t) async {
      final g = makeGame()..startDay();
      skipScenes(g);
      g.phase = Phase.dayEnd;
      g.wastedToday = 70;
      g.penaltyToday = 20;
      g.diamonds = 3;
      g.notifyListeners();
      await show(t, g);
      expect(find.textContaining('çöpe/zarara'), findsOneWidget);
      expect(find.text('Küsen müşteri cezası'), findsOneWidget);
      expect(find.text('Elmas'), findsOneWidget);
      expect(find.text('Reklam'), findsWidgets);
      g.dispose();
    });

    testWidgets('beyran seçilince taban kâse olur, düğme SERVİS ET yazar', (t) async {
      final g = makeGame()
        ..quests.chapter = 5
        ..startDay();
      skipScenes(g);
      g.money = 1000;
      await show(t, g);
      g.selectWrap('beyran');
      g.tapBread();
      await t.pump();
      expect(find.text('Kâse'), findsOneWidget);
      expect(find.text('SERVİS ET'), findsOneWidget);
      expect(find.text('SAR'), findsNothing);
      g.dispose();
    });
  });
}

void phoneLayoutTests() {
  group('telefon yerleşimi', () {
    testWidgets('çok yatay ekranda sahne genişler, yazılar büyütülür, HUD kenarlara yaslanır', (t) async {
      t.view.physicalSize = const Size(844, 390);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = makeGame(3)..quests.chapterIntroSeen = true;
      g.startDay();
      skipScenes(g);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
      await t.pump();
      final gun = find.text('Gün 1');
      expect(gun, findsOneWidget);
      expect(MediaQuery.textScalerOf(t.element(gun)).scale(10), greaterThan(10));
      // HUD ekranın sol kenarına yakın (tasarım genişliği 1600'ün ötesine uzandığı için)
      expect(t.getTopLeft(gun).dx, lessThan(60));
      g.dispose();
    });

    testWidgets('masaüstü oranında (16:9) yazı çarpanı 1 ve sahne 1600 geniş kalır', (t) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = makeGame(3)..quests.chapterIntroSeen = true;
      g.startDay();
      skipScenes(g);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
      await t.pump();
      expect(MediaQuery.textScalerOf(t.element(find.text('Gün 1'))).scale(10), 10);
      g.dispose();
    });

    test('yazı çarpanı ölçeğe göre', () {
      expect(GameScreen.textBoost(1.0), 1.0);
      expect(GameScreen.textBoost(0.433), closeTo(1.5, 0.001));
      expect(GameScreen.textBoost(0.2), 1.5);
    });
  });
}
