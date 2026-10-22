// v4 ekran görüntüleri (normal test koşusunda atlanır). Çalıştırma:
//   $env:SHOTS='C:\atmp\review\v4'; flutter test test/shots_v4_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/leaderboard/leaderboard.dart';
import 'package:nohut_durumu/ui/game_screen.dart';
import 'package:nohut_durumu/ui/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final img = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pumpApp(WidgetTester t, Widget child, {Size size = const Size(1600, 900), double dpr = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.runAsync(() => loadFonts());
    await t.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: Scaffold(body: RepaintBoundary(key: key, child: child))));
    await settle(t);
    return key;
  }

  testWidgets('v4 ekran görüntüleri', skip: outDir == null, (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // açılış (bigsoft)
    final splashKey = await pumpApp(t, const BigsoftSplash(progress: 0.62));
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    await shot(t, splashKey, '01_bigsoft_yukleme');

    // üç tezgâh + buhar + dolu tabaklar
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(7),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(7),
      prefs: prefs,
      tutorialEnabled: true,
      gameOverEnabled: true,
    )..load();
    g.quests.chapter = 2;
    g.quests.chapterIntroSeen = true;
    g.startDay();
    skipScenes(g);
    g.money = 4000;
    for (var i = 0; i < 60; i++) {
      g.tick(0.1);
    }
    // tanıtımı geç (ayrı sahne olarak çekilecek)
    final tutorialStep = g.tutorialStep;
    final key = await pumpApp(t, GameScreen(game: g, animations: false));
    await shot(t, key, '02_tanitim_adim${tutorialStep + 1}');
    for (var i = 0; i < 3; i++) {
      g.nextTutorial();
    }
    await settle(t);
    await shot(t, key, '03_tanitim_adim4');
    g.skipTutorial();
    waitForCustomer(g);
    g.tapBread(board: 0);
    g.tapMain(board: 0);
    g.tapMain(board: 0);
    g.tapPiyaz(board: 0);
    g.tapAci(board: 0);
    g.tapBread(board: 1);
    g.tapMain(board: 1);
    g.tapPiyaz(board: 1);
    g.tapAci(board: 1);
    g.tapSumak(board: 1);
    g.tapBread(board: 2);
    g.wrap(board: 1);
    await settle(t);
    await settle(t);
    await shot(t, key, '04_uc_tezgah_buhar_tabaklar');

    // oyun bitti
    g.lives = 1;
    for (var i = 0; i < 6000 && g.phase == Phase.playing; i++) {
      g.tick(0.1);
      skipScenes(g);
    }
    await settle(t);
    await shot(t, key, '05_oyun_bitti');
    g.dispose();
  });

  testWidgets('telefon (844x390) görünümü', skip: outDir == null, (t) async {
    SharedPreferences.setMockInitialValues({'tutorial_done': true});
    final prefs = await SharedPreferences.getInstance();
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(7),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(7),
      prefs: prefs,
      tutorialEnabled: true,
      gameOverEnabled: true,
    )..load();
    g.quests.chapter = 3;
    g.quests.chapterIntroSeen = true;
    g.startDay();
    skipScenes(g);
    g.money = 1500;
    for (var i = 0; i < 2000; i++) {
      g.tick(0.1);
      skipScenes(g);
      if (g.slots.whereType<Customer>().length >= 3) break;
    }
    for (var i = 0; i < 40; i++) {
      g.tick(0.1);
    }
    final key = await pumpApp(t, GameScreen(game: g, animations: false), size: const Size(1688, 780), dpr: 2.0);
    g.tapBread(board: 0);
    g.tapMain(board: 0);
    g.tapPiyaz(board: 0);
    await settle(t);
    await settle(t);
    await shot(t, key, 'tel_01_oyun');
    g.toggleNotebook();
    await settle(t);
    await shot(t, key, 'tel_02_defter');
    g.toggleNotebook();
    g.replayTutorial();
    g.nextTutorial();
    g.tick(0.1);
    g.nextTutorial();
    await settle(t);
    await shot(t, key, 'tel_03_tanitim');
    g.skipTutorial();
    g.lives = 1;
    for (var i = 0; i < 8000 && g.phase == Phase.playing; i++) {
      g.tick(0.1);
      skipScenes(g);
    }
    await settle(t);
    await shot(t, key, 'tel_04_oyun_bitti');
    g.dispose();

    // başlık ve gün sonu
    final g2 = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(9),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(9),
    );
    final key2 = await pumpApp(t, GameScreen(game: g2, animations: false), size: const Size(1688, 780), dpr: 2.0);
    await settle(t);
    await shot(t, key2, 'tel_05_baslik');
    g2.quests.chapterIntroSeen = true;
    g2.startDay();
    skipScenes(g2);
    g2.toSpawn = 0;
    for (var i = 0; i < 200 && g2.phase == Phase.playing; i++) {
      g2.tick(0.1);
    }
    await settle(t);
    await shot(t, key2, 'tel_06_gun_sonu');
    g2.dispose();
  });

  testWidgets('telefon: kaplamalar taşmıyor', skip: outDir == null, (t) async {
    SharedPreferences.setMockInitialValues({'tutorial_done': true});
    final prefs = await SharedPreferences.getInstance();
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(5),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(5),
      prefs: prefs,
      gameOverEnabled: true,
    )..load();
    g.quests.chapter = 5;
    g.quests.chapterIntroSeen = true;
    g.startDay();
    skipScenes(g);
    g.money = 5000;
    final key = await pumpApp(t, GameScreen(game: g, animations: false), size: const Size(1688, 780), dpr: 2.0);
    await settle(t);
    Future<void> snap(String name) async {
      await settle(t);
      await shot(t, key, 'ov_$name');
    }

    g.toggleSettings();
    await snap('ayarlar');
    g.toggleSettings();
    g.toggleRecipe();
    await snap('tarif');
    await t.tap(find.text('Ekler ve soslar'));
    await t.pump();
    await snap('tarif_soslar');
    g.toggleRecipe();
    g.openAdMenu();
    await snap('reklam_menu');
    g.closeAdMenu();
    g.leaderboard;
    g.openShop();
    await snap('dukkan');
    g.openGarden();
    await snap('bahce');
    g.dispose();
  });

  testWidgets('telefon: diğer ekranlar (sıralama, reklam, sahne, bahçe, soruşturma, paket servis)', skip: outDir == null, (t) async {
    SharedPreferences.setMockInitialValues({'tutorial_done': true});
    final prefs = await SharedPreferences.getInstance();
    final board = LeaderboardManager(prefs: prefs, random: Random(3));
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(8),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(8),
      prefs: prefs,
      leaderboard: board,
      gameOverEnabled: true,
    )..load();
    g.quests.chapter = 5;
    g.quests.chapterIntroSeen = true;
    g.upgrades['yardimci'] = 2;
    g.money = 4000;
    g.startDay();
    skipScenes(g);
    final key = await pumpApp(t, GameScreen(game: g, animations: false), size: const Size(1688, 780), dpr: 2.0);
    for (var i = 0; i < 3000 && g.slots.whereType<Customer>().length < 3; i++) {
      g.tick(0.1);
      skipScenes(g);
    }
    for (var i = 0; i < 60; i++) {
      g.tick(0.1);
    }
    await settle(t);
    await settle(t);
    await shot(t, key, 'diger_01_oyun_bolum5_paket_servis');
    board.toggle();
    await t.pump();
    await settle(t);
    await shot(t, key, 'diger_02_siralama');
    board.toggle();
    g.startAd('money');
    await settle(t);
    await shot(t, key, 'diger_03_reklam_izleme');
    g.cancelAd();
    g.openCase();
    await settle(t);
    await shot(t, key, 'diger_04_sorusturma');
    g.closeCase();
    g.openGarden();
    await settle(t);
    await shot(t, key, 'diger_05_bahce');
    g.closeGarden();
    g.toTitle();
    await settle(t);
    await shot(t, key, 'diger_06_ana_ekran_menu');
    g.openShopFromMenu();
    await settle(t);
    await shot(t, key, 'diger_07_ana_ekrandan_dukkan');
    g.dispose();
  });

  testWidgets('telefon: kepenk açılışı ve hikâye sahnesi', skip: outDir == null, (t) async {
    SharedPreferences.setMockInitialValues({'tutorial_done': true});
    final g = GameController(
      cfg: loadCfg(),
      dialog: loadDialog(4),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(4),
      introEnabled: true,
    );
    g.startDay();
    final key = await pumpApp(t, GameScreen(game: g, animations: false), size: const Size(1688, 780), dpr: 2.0);
    await settle(t);
    await shot(t, key, 'kepenk_01_acilis');
    g.skipIntro();
    await settle(t);
    await shot(t, key, 'kepenk_02_hikaye_sahnesi');
    g.dispose();
  });
}

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 400));
}
