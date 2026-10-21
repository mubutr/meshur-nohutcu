import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/audio/sfx.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/game_screen.dart';
import 'package:nohut_durumu/ui/intro_overlay.dart';

import 'helpers.dart';

class FakeSfx implements Sfx {
  final List<String> played = [];
  @override
  void play(String name) => played.add(name);
}

GameController withIntro({Sfx? sfx, int seed = 3}) => GameController(
      cfg: loadCfg(),
      dialog: loadDialog(seed),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(seed),
      sfx: sfx,
      introEnabled: true,
    );

void main() {
  final cfg = loadCfg();

  group('"Ya Fettah, Ya Rezzak" açılışı', () {
    test('günün başında açılış oynar: oyun donar, süre bitince akar', () {
      final g = withIntro()..startDay();
      skipScenes(g);
      expect(g.introActive, isTrue);
      expect(g.paused, isTrue);
      for (var i = 0; i < 30; i++) {
        g.tick(0.1); // 3 sn: hâlâ açılış
      }
      expect(g.introActive, isTrue);
      expect(g.slots.every((c) => c == null), isTrue, reason: 'açılışta müşteri gelmez');
      for (var i = 0; i < 10; i++) {
        g.tick(0.1);
      }
      expect(g.introActive, isFalse);
      for (var i = 0; i < 60 && g.slots.every((c) => c == null); i++) {
        g.tick(0.1);
      }
      expect(g.slots.any((c) => c != null), isTrue, reason: 'açılıştan sonra ilk müşteri gelir');
      g.dispose();
    });

    test('süre yapılandırmadan gelir ve ses kaydından (3.26 sn) uzundur', () {
      expect(cfg.eco('introSeconds'), greaterThan(3.3));
      expect(cfg.eco('introSeconds'), lessThan(6));
    });

    test('kepenk ve "Ya Fettah Ya Rezzak" sesleri çalar; ses kapalıysa çalmaz', () {
      final s = FakeSfx();
      final g = withIntro(sfx: s)..startDay();
      expect(s.played.where((n) => n == 'kepenk.wav'), hasLength(1));
      expect(s.played.where((n) => n == 'yafettah.mp3'), hasLength(1));
      g.dispose();
      final quiet = FakeSfx();
      final h = withIntro(sfx: quiet)
        ..toggleSound()
        ..startDay();
      expect(quiet.played.where((n) => n.contains('.')), isEmpty);
      h.dispose();
    });

    test('dokununca atlanır (skipIntro)', () {
      final g = withIntro()..startDay();
      skipScenes(g);
      g.skipIntro();
      expect(g.introActive, isFalse);
      expect(g.paused, isFalse);
      g.dispose();
    });

    test('her yeni günde yeniden oynar; oyun başlığa dönünce kapanır', () {
      final s = FakeSfx();
      final g = withIntro(sfx: s)..startDay();
      g.skipIntro();
      g.startDay();
      expect(g.introActive, isTrue);
      expect(s.played.where((n) => n == 'yafettah.mp3'), hasLength(2));
      g.toTitle();
      expect(g.introActive, isFalse);
      g.dispose();
    });

    test('varsayılan olarak kapalıdır (testler/başsız çalışma)', () {
      final g = makeGame()..startDay();
      expect(g.introActive, isFalse);
      g.dispose();
    });

    test('kepenk yüksekliği ve yazı görünürlüğü eğrileri', () {
      expect(IntroOverlay.lift(0), 0);
      expect(IntroOverlay.lift(1), 1);
      var prev = -1.0;
      for (var i = 0; i <= 100; i++) {
        final v = IntroOverlay.lift(i / 100);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
      expect(IntroOverlay.textOpacity(0), 0);
      expect(IntroOverlay.textOpacity(0.5), 1);
      expect(IntroOverlay.textOpacity(1), 0);
    });

    test('ses dosyaları var: yafettah.mp3 (kullanıcı kaydı) ve üretilmiş kepenk.wav (~2.6 sn)', () {
      final mp3 = File('assets/sfx/yafettah.mp3');
      expect(mp3.existsSync(), isTrue);
      expect(mp3.lengthSync(), greaterThan(10000));
      final wav = File('assets/sfx/kepenk.wav').readAsBytesSync();
      final bd = ByteData.sublistView(Uint8List.fromList(wav));
      final rate = bd.getUint32(24, Endian.little);
      final dataBytes = bd.getUint32(40, Endian.little);
      expect(dataBytes / 2 / rate, closeTo(2.6, 0.1));
    });
  });

  group('açılış ekranı', () {
    Future<void> show(WidgetTester t, GameController g) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
      await t.pump();
    }

    testWidgets('kepenk ve "Ya Fettah, Ya Rezzak" yazısı görünür; dokununca kaybolur', (t) async {
      final g = withIntro()..startDay();
      skipScenes(g);
      await show(t, g);
      expect(find.byKey(const ValueKey('intro')), findsOneWidget);
      expect(find.text('Ya Fettah, Ya Rezzak'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('intro')));
      await t.pump();
      expect(g.introActive, isFalse);
      expect(find.text('Ya Fettah, Ya Rezzak'), findsNothing);
      g.dispose();
    });

    testWidgets('animasyonlu: kepenk zamanla kalkar ve süre bitince ekrandan kalkar', (t) async {
      final g = withIntro()..startDay();
      skipScenes(g);
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g))));
      await t.pump();
      expect(find.text('Ya Fettah, Ya Rezzak'), findsOneWidget);
      for (var i = 0; i < 40; i++) {
        g.tick(0.1);
      }
      await t.pump(const Duration(milliseconds: 4000));
      expect(find.byKey(const ValueKey('intro')), findsNothing);
      g.dispose();
    });
  });
}
