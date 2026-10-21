import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/audio/sfx.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/overlays.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class FakeSfx implements Sfx {
  final List<String> played = [];
  @override
  void play(String name) => played.add(name);
}

GameController gameWith({Sfx? sfx, SharedPreferences? prefs}) => GameController(
      cfg: loadCfg(),
      dialog: loadDialog(3),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(3),
      prefs: prefs,
      sfx: sfx,
    );

void main() {
  test('rahat mod müşteri sabrını %25 artırır', () {
    final g = makeGame();
    final base = g.patienceMul;
    g.toggleComfort();
    expect(g.patienceMul, closeTo(base + 0.25, 1e-9));
    g.dispose();
  });

  test('ayarlar kaydedilir ve yeniden yüklenir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final g = gameWith(prefs: prefs)..load();
    g.toggleComfort();
    g.toggleSound();
    final g2 = gameWith(prefs: prefs)..load();
    expect(g2.comfortMode, isTrue);
    expect(g2.soundOn, isFalse);
    g.dispose();
    g2.dispose();
  });

  test('oyun sesleri tetiklenir; ses kapalıyken sessiz kalır', () {
    final s = FakeSfx();
    final g = gameWith(sfx: s);
    g.startDay();
    skipScenes(g);
    final slot = waitForCustomer(g);
    expect(slot, greaterThanOrEqualTo(0));
    expect(s.played, contains('bell'));
    makeAndServe(g, slot);
    expect(s.played, containsAll(['bread', 'pop', 'wrap', 'great']));
    final n = s.played.length;
    g.toggleSound(); // kapat
    g.tapBread();
    g.tapNohut();
    expect(s.played.length, n, reason: 'ses kapalıyken çalmaz');
    g.dispose();
  });

  testWidgets('ayarlar ekranı düğmeleri durumu değiştirir', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = makeGame();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListenableBuilder(listenable: g, builder: (_, _) => Stack(children: [SettingsOverlay(game: g)])))));
    expect(g.comfortMode, isFalse);
    await tester.tap(find.byKey(const ValueKey('toggle-comfort')));
    await tester.pump();
    expect(g.comfortMode, isTrue);
    await tester.tap(find.byKey(const ValueKey('toggle-sound')));
    await tester.pump();
    expect(g.soundOn, isFalse);
    expect(find.text('KAPALI'), findsOneWidget);
    g.dispose();
  });
}
