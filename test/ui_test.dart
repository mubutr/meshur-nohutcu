import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/game_screen.dart';

import 'helpers.dart';

Future<void> pumpGame(WidgetTester t, GameController g) async {
  t.view.physicalSize = const Size(1600, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g))));
  await t.pump();
}

void main() {
  testWidgets('başlık ekranı açılır', (t) async {
    final g = makeGame();
    await pumpGame(t, g);
    expect(find.textContaining('Güzel Nohut Dürümü'), findsOneWidget);
    expect(find.text('BAŞLA'), findsOneWidget);
    g.dispose();
  });

  testWidgets('Bölüm 1 giriş sahnesi: konuşan ve muhatap etiketi görünür, dokununca ilerler', (t) async {
    final g = makeGame();
    await pumpGame(t, g);
    await t.tap(find.text('BAŞLA'));
    await t.pump();
    expect(g.sceneLines, isNotNull);
    expect(find.text('ANLATICI'), findsWidgets);
    expect(find.text('ÇIRAK (SEN)'), findsWidgets);
    final first = g.sceneIndex;
    await t.tap(find.textContaining('Devam'));
    await t.pump();
    expect(g.sceneIndex, first + 1);
    // sahneyi bitir
    for (var i = 0; i < 20 && g.sceneLines != null; i++) {
      g.advanceScene();
      await t.pump();
    }
    expect(g.sceneLines, isNull);
    expect(t.takeException(), isNull);
    g.dispose();
  });

  testWidgets('oyun sahnesi: müşteri gelir, dürüm hazırlanır ve servis edilir (taşma yok)', (t) async {
    final g = makeGame();
    await pumpGame(t, g);
    await t.tap(find.text('BAŞLA'));
    await t.pump();
    skipScenes(g);
    await t.pump();
    final idx = waitForCustomer(g);
    expect(idx, isNonNegative);
    await t.pump();
    final spec = g.slots[idx]!.spec;
    expect(find.textContaining('nohut dürümü'), findsWidgets);
    // konuşan etiketleri: "ADI → USTA"
    expect(find.text('USTA'), findsWidgets);

    await t.tap(find.text('Tırnaklı ekmek'));
    await t.pump();
    for (var i = 0; i < spec.nohut; i++) {
      await t.tap(find.text('Nohut').first);
      await t.pump();
    }
    if (spec.piyaz) await t.tap(find.text('Piyaz'));
    if (spec.aci) await t.tap(find.text('Acı'));
    await t.pump();
    await t.tap(find.text('SAR'));
    await t.pump();
    expect(g.assembly.wrapped, isTrue);
    expect(find.text('VER'), findsWidgets);

    final before = g.money;
    g.serve(idx);
    await t.pump();
    expect(g.money, greaterThan(before));
    expect(t.takeException(), isNull);
    g.dispose();
  });

  testWidgets('Defter (görevler) ekranı açılır ve ana görevi gösterir', (t) async {
    final g = makeGame();
    await pumpGame(t, g);
    await t.tap(find.text('BAŞLA'));
    await t.pump();
    skipScenes(g);
    await t.pump();
    await t.tap(find.text('Defter'));
    await t.pump();
    expect(g.notebookOpen, isTrue);
    expect(find.textContaining('Çırak Elleri'), findsWidgets);
    expect(find.text('İlk Müşteriler'), findsOneWidget);
    expect(find.text('Bugünün görevleri'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Kapat'));
    await t.pump();
    expect(g.notebookOpen, isFalse);
    g.dispose();
  });

  testWidgets('gün sonu (bilanço) ve dükkân (yükseltme + süs) ekranları taşmadan çizilir', (t) async {
    final g = makeGame()..startDay();
    skipScenes(g);
    await pumpGame(t, g);
    for (var i = 0; i < 30000 && g.phase == Phase.playing; i++) {
      g.tick(0.1);
    }
    skipScenes(g);
    await t.pump();
    expect(g.phase, Phase.dayEnd);
    expect(find.text('Gün 1 bitti!'), findsOneWidget);
    expect(find.text('Kira'), findsOneWidget);
    expect(find.text('Günün net kârı'), findsOneWidget);
    expect(t.takeException(), isNull);

    g.money = 2000;
    await t.tap(find.text('Dükkân'));
    await t.pump();
    expect(g.phase, Phase.shop);
    expect(find.text('Dükkânı güzelleştir'), findsOneWidget);
    expect(find.text('Dükkân süsleri (kazancı da artırır)'), findsOneWidget);
    await t.tap(find.text('${g.cfg.upgrades.first.costs.first} ₺').first);
    await t.pump();
    expect(g.level('sabir'), 1);
    final kilim = g.cfg.decor.firstWhere((d) => d.id == 'kilim');
    await t.tap(find.text('${kilim.cost} ₺').first);
    await t.pump();
    expect(g.decorOwned, contains('kilim'));
    expect(t.takeException(), isNull);
    g.dispose();
  });
}
