// Ekran görüntüsü aracı (normal test koşusunda atlanır). Çalıştırma:
//   $env:SHOTS='C:\atmp\review\shots'; flutter test test/shots_test.dart
// Gerçek yazı tipi (Roboto) ve ikon yazı tipi Flutter SDK'dan yüklenir; sahneler PNG olarak kaydedilir.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/game_screen.dart';

import 'helpers.dart';

Future<void> loadFonts() async {
  final dir = 'C:/src/flutter/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) async => ByteData.view(File('$dir/$f').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  final outDir = Platform.environment['SHOTS'];

  Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
    await t.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pump(WidgetTester t, GameController g) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.runAsync(() => loadFonts());
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(body: RepaintBoundary(key: key, child: GameScreen(game: g, animations: false))),
    ));
    // görselleri önceden çöz
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
    });
    await t.pump();
    return key;
  }

  Future<void> settle(WidgetTester t, GameController g) async {
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('ekran görüntüleri', skip: outDir == null, (t) async {
    final g = makeGame(7);
    final key = await pump(t, g);
    await shot(t, key, '01_baslik');

    await t.tap(find.text('BAŞLA'));
    await t.pump();
    await settle(t, g);
    await shot(t, key, '02_bolum1_giris_sahnesi');
    skipScenes(g);
    await t.pump();

    // ilk müşteri: karşılama balonları
    for (var i = 0; i < 20; i++) {
      g.tick(0.1);
    }
    await settle(t, g);
    await shot(t, key, '03_karsilama_usta_musteriye');
    for (var i = 0; i < 20; i++) {
      g.tick(0.1);
    }
    await settle(t, g);
    await shot(t, key, '04_musteri_ustaya_cevap');
    for (var i = 0; i < 30; i++) {
      g.tick(0.1);
    }
    await settle(t, g);
    await shot(t, key, '05_siparis_ve_usta_ciraga');

    g.toggleNotebook();
    await t.pump();
    await settle(t, g);
    await shot(t, key, '06_defter');
    g.toggleNotebook();
    await t.pump();

    // Bölüm 2 görünümü: sumak, bilmece, süsler, yardımcı
    final g2 = makeGame(11);
    g2.quests.chapter = 3;
    g2.quests.chapterIntroSeen = true;
    g2.quests.done.addAll(['c1q1', 'c1q2']);
    g2.upgrades['yardimci'] = 2;
    g2.money = 1234;
    g2.decorOwned.addAll(['kilim', 'saksi', 'fener', 'fistik', 'foto', 'saat', 'bakir2', 'isik']);
    final key2 = await pump(t, g2);
    g2.startDay();
    skipScenes(g2);
    Customer? r;
    for (var d = 0; d < 8 && r == null; d++) {
      for (var i = 0; i < 4000 && r == null && g2.phase == Phase.playing; i++) {
        g2.tick(0.1);
        r = g2.slots.whereType<Customer>().where((c) => c.kind == CustomerKind.riddle && c.state == CustomerState.waiting).firstOrNull;
      }
      if (r == null) {
        g2.startDay();
        skipScenes(g2);
      }
    }
    for (var i = 0; i < 40; i++) {
      g2.tick(0.1);
    }
    await t.pump();
    await settle(t, g2);
    await shot(t, key2, '07_bolum3_bilmece_dekor_yardimci');

    // gün sonu + dükkân
    for (var i = 0; i < 40000 && g2.phase == Phase.playing; i++) {
      g2.tick(0.1);
    }
    skipScenes(g2);
    await t.pump();
    await settle(t, g2);
    await shot(t, key2, '08_gun_sonu_bilanco');
    g2.openShop();
    await t.pump();
    await settle(t, g2);
    await shot(t, key2, '09_dukkan');
    g.dispose();
    g2.dispose();
  });

  testWidgets('ekran görüntüleri: v3 sahneleri (tam boy karakter, tema, gün-gece, ürünler)', skip: outDir == null, (t) async {
    GameController mk(int seed, int chapter, {double money = 2500}) {
      final g = GameController(
        cfg: loadCfg(),
        dialog: loadDialog(seed),
        questData: loadQuests(),
        story: loadStory(),
        riddles: loadRiddles(),
        detectiveData: loadDetective(),
        random: Random(seed),
      );
      g.quests.chapter = chapter;
      g.quests.chapterIntroSeen = true;
      g.money = money.round();
      return g;
    }

    // --- Bölüm 1: esnaf teması, sabah, tam boy müşteriler, bahşiş kavanozu
    final g1 = mk(7, 1);
    final k1 = await pump(t, g1);
    g1.startDay();
    skipScenes(g1);
    for (var i = 0; i < 60; i++) {
      g1.tick(0.1);
    }
    g1.tipJar = 64;
    await t.pump();
    await settle(t, g1);
    await shot(t, k1, '20_b1_esnaf_sabah');
    final idx = g1.slots.indexWhere((c) => c?.state == CustomerState.waiting);
    if (idx >= 0) {
      prepare(g1, g1.slots[idx]!.spec);
      await t.pump();
      await settle(t, g1);
      await shot(t, k1, '21_b1_durum_hazir');
    }
    g1.dispose();

    // --- Bölüm 3: çarşı lokantası, döner + soslar, akşam
    final g3 = mk(11, 3);
    g3.upgrades['yardimci'] = 1;
    g3.decorOwned.addAll(['kilim', 'saksi', 'fener', 'fistik']);
    final k3 = await pump(t, g3);
    g3.startDay();
    skipScenes(g3);
    for (var i = 0; i < 50; i++) {
      g3.tick(0.1);
    }
    g3.selectWrap('doner');
    g3.tapBread();
    g3.tapMain();
    g3.tapMain();
    g3.tapPiyaz();
    g3.tapSauce('ketcap');
    g3.tapSauce('mayonez');
    g3.toSpawn = 3; // gün ilerledi: akşam
    await t.pump();
    await settle(t, g3);
    await shot(t, k3, '22_b3_doner_soslar_aksam');
    g3.toSpawn = 1; // gece
    await t.pump();
    await settle(t, g3);
    await t.pump(const Duration(milliseconds: 1600));
    await shot(t, k3, '23_b3_gece_isiklar');
    g3.dispose();

    // --- Bölüm 4: Antep lokantası, kurye
    final g4 = mk(5, 4);
    g4.decorOwned.addAll(['kilim', 'saksi', 'fener', 'fistik', 'foto', 'bakir2', 'neon']);
    final k4 = await pump(t, g4);
    g4.startDay();
    skipScenes(g4);
    g4.delivery.courierLeft = 0.1;
    for (var i = 0; i < 60; i++) {
      g4.tick(0.1);
    }
    for (var i = 0; i < 400 && g4.delivery.orders.length < 2; i++) {
      g4.tick(0.1);
    }
    g4.slots[2] = null; // kuryeye yer aç
    for (var i = 0; i < 6; i++) {
      g4.tick(0.1);
    }
    for (var i = 0; i < 40; i++) {
      g4.tick(0.1);
    }
    await t.pump();
    await settle(t, g4);
    await shot(t, k4, '24_b4_antep_kurye');
    // bonus müşteri (Gezgin)
    g4.slots[0] = null;
    g4.slots[1] = null;
    g4.bonusDue = true;
    for (var i = 0; i < 60; i++) {
      g4.tick(0.1);
    }
    await t.pump();
    await settle(t, g4);
    await shot(t, k4, '31_gezgin_bonus');
    g4.dispose();

    // --- Bölüm 5: saray teması, beyran
    final g5 = mk(3, 5, money: 5000);
    g5.decorOwned.addAll(['kilim', 'saksi', 'fener', 'fistik', 'foto', 'bakir2', 'avize', 'sutun', 'altinsaat']);
    final k5 = await pump(t, g5);
    g5.startDay();
    skipScenes(g5);
    for (var i = 0; i < 40; i++) {
      g5.tick(0.1);
    }
    g5.selectWrap('beyran');
    g5.tapBread();
    g5.tapMain();
    g5.tapAci();
    g5.wrap();
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '25_b5_saray_beyran');
    g5.assembly.reset();
    g5.selectWrap('kizartma');
    g5.tapBread();
    g5.tapMain();
    g5.tapFried();
    g5.tapSauce('nar');
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '26_b5_kizartma_durumu');

    g5.toggleRecipe();
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '27_tarif_defteri');
    g5.toggleRecipe();
    g5.openAdMenu();
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '28_reklam_menu');
    g5.startAd('diamond');
    g5.tick(2);
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '29_reklam_izleniyor');
    g5.cancelAd();
    g5.diamonds = 14;
    g5.phase = Phase.dayEnd;
    g5.wastedToday = 90;
    g5.penaltyToday = 20;
    g5.openShop();
    await t.pump();
    await settle(t, g5);
    await shot(t, k5, '30_dukkan_elmas');
    g5.dispose();
  });

  testWidgets('ekran görüntüleri: kepenk açılışı ve yeni müşteri kadrosu', skip: outDir == null, (t) async {
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(8),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(8),
      introEnabled: true,
    );
    g.quests.chapterIntroSeen = true;
    final key = await pump(t, g);
    g.startDay();
    await t.pump();
    await settle(t, g);
    await shot(t, key, '40_acilis_kepenk_yazi'); // animations:false -> kepenk yarı açık sabit kare
    g.skipIntro();
    for (var i = 0; i < 160; i++) {
      g.tick(0.1);
    }
    // müşteri bubble: servis sonrası "Hayırlı işler" + usta "Bereket versin"
    final idx = g.slots.indexWhere((c) => c?.state == CustomerState.waiting);
    if (idx >= 0) {
      g.money = 500;
      makeAndServe(g, idx);
      for (var i = 0; i < 6; i++) {
        g.tick(0.1);
      }
      await t.pump();
      await settle(t, g);
      await shot(t, key, '41_hayirli_isler_bereket');
    }
    g.dispose();
  });
}
