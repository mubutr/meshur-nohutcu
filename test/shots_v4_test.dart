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
      final img = await boundary.toImage(pixelRatio: 1.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pumpApp(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1.0;
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
}

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 400));
}
