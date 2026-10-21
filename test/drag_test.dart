import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/ui/game_screen.dart';
import 'package:nohut_durumu/ui/widgets.dart';

import 'helpers.dart';

GameController started([int seed = 3, int chapter = 1]) {
  final g = makeGame(seed);
  g.quests.chapter = chapter;
  g.quests.chapterIntroSeen = true;
  g.startDay();
  skipScenes(g);
  g.money = 5000;
  return g;
}

Future<void> show(WidgetTester t, GameController g) async {
  t.view.physicalSize = const Size(1600, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
  await t.pump();
}

Future<void> drag(WidgetTester t, Finder from, Finder to) async {
  final g = await t.startGesture(t.getCenter(from));
  await g.moveBy(const Offset(0, -20));
  await t.pump();
  await g.moveTo(t.getCenter(to));
  await t.pump();
  await g.up();
  await t.pump();
}

void main() {
  group('3 tezgâh (denetleyici)', () {
    test('aynı anda üç farklı dürüm hazırlanır; her tezgâhın harcaması ayrı tutulur', () {
      final g = started();
      expect(GameController.boardCount, 3);
      g.tapBread(board: 0);
      g.tapMain(board: 0);
      g.tapBread(board: 1);
      g.tapMain(board: 1);
      g.tapMain(board: 1);
      g.tapPiyaz(board: 1);
      g.tapBread(board: 2);
      expect(g.boards[0].nohut, 1);
      expect(g.boards[1].nohut, 2);
      expect(g.boards[1].piyaz, isTrue);
      expect(g.boards[2].bread, isTrue);
      expect(g.boards[2].nohut, 0);
      expect(g.boards[0].spent, cfgBread() + cfgNohut());
      expect(g.boards[1].spent, cfgBread() + 2 * cfgNohut() + loadCfg().costs['piyaz']!);
      expect(g.boards.fold<int>(0, (a, b) => a + b.spent), g.suppliesToday);
      g.dispose();
    });

    test('dokunma akışı: ekmek sıradaki boş tezgâha gider, malzemeler etkin tezgâha eklenir', () {
      final g = started();
      g.tapBread();
      expect(g.activeBoard, 0);
      g.tapMain();
      g.tapBread(); // 0 dolu -> 1. tezgâh
      expect(g.activeBoard, 1);
      g.tapMain();
      g.tapMain();
      expect(g.boards[0].nohut, 1);
      expect(g.boards[1].nohut, 2);
      g.tapBread();
      expect(g.activeBoard, 2);
      g.tapBread(); // hepsi dolu: işlem yok
      expect(g.activeBoard, 2);
      g.dispose();
    });

    test('tezgâh başına SAR ve çöp; çöp yalnızca o tezgâhın parasını yakar', () {
      final g = started();
      g.tapBread(board: 0);
      g.tapMain(board: 0);
      g.tapBread(board: 1);
      final spent1 = g.boards[1].spent;
      g.wrap(board: 0);
      expect(g.boards[0].wrapped, isTrue);
      expect(g.boards[1].wrapped, isFalse);
      g.trash(board: 1);
      expect(g.boards[1].isEmpty, isTrue);
      expect(g.wastedToday, spent1);
      expect(g.boards[0].wrapped, isTrue, reason: 'diğer tezgâh etkilenmez');
      g.dispose();
    });

    test('servis: verilen tezgâh kullanılır; verilmezse müşteriye en uygun hazır dürüm seçilir', () {
      final g = started(7);
      var idx = waitForCustomer(g);
      expect(idx, isNonNegative);
      for (var i = 0; i < 40; i++) {
        g.tick(0.1);
      }
      final c = g.slots[idx]!;
      // 0. tezgâha yanlış, 2. tezgâha doğru dürüm hazırla
      g.tapBread(board: 0);
      g.wrap(board: 0);
      g.activeBoard = 2;
      prepare(g, c.spec);
      expect(g.boards[2].wrapped, isTrue);
      g.activeBoard = 0;
      g.serve(idx); // board verilmedi -> en uygun (2) seçilir
      expect(g.greatToday, 1);
      expect(g.boards[2].isEmpty, isTrue);
      expect(g.boards[0].wrapped, isTrue, reason: 'yanlış dürüm tezgâhta kaldı');
      g.dispose();
    });

    test('sarılmış tezgâha malzeme eklenmez; hazır tezgâh boş değildir', () {
      final g = started();
      g.tapBread(board: 0);
      g.wrap(board: 0);
      final before = g.boards[0].spent;
      g.tapMain(board: 0);
      g.tapPiyaz(board: 0);
      expect(g.boards[0].spent, before);
      expect(g.anyBoardWrapped, isTrue);
      g.dispose();
    });

    test('sürükle-bırak girişi (addIngredient) türleri doğru işler', () {
      final g = started(3, 3);
      g.selectWrap('doner');
      g.addIngredient(Ingredient.bread, board: 1);
      g.addIngredient(Ingredient.main, board: 1);
      g.addIngredient(Ingredient.piyaz, board: 1);
      g.addIngredient(Ingredient.aci, board: 1);
      g.addIngredient(Ingredient.fried, board: 1);
      g.addIngredient(Ingredient.sauce, board: 1, sauceId: 'ketcap');
      g.addIngredient(Ingredient.sumak, board: 1);
      final b = g.boards[1];
      expect(b.wrap, 'doner');
      expect([b.nohut, b.piyaz, b.aci, b.fried, b.sauces, b.sumak], [1, true, true, true, {'ketcap'}, true]);
      g.dispose();
    });

    test('3 tezgâhla paket servis: hazır dürüm kutuya konur', () {
      final g = started(2, 4);
      var guard = 0;
      while (g.delivery.orders.isEmpty && guard++ < 2000) {
        g.tick(0.1);
      }
      final order = g.delivery.orders.first;
      g.activeBoard = 1;
      prepare(g, order.spec);
      g.activeBoard = 0;
      g.serveDelivery(0, board: 1);
      expect(g.delivery.orders.first.isBoxed, isTrue);
      expect(g.boards[1].isEmpty, isTrue);
      g.dispose();
    });
  });

  group('sürükle-bırak (ekran)', () {
    testWidgets('ekmek istasyonundan 2. tezgâha sürükle: ekmek oraya konur ve para düşer', (t) async {
      final g = started();
      await show(t, g);
      final m0 = g.money;
      await drag(t, find.text('Tırnaklı ekmek'), find.byKey(const ValueKey('board-1')));
      expect(g.boards[1].bread, isTrue);
      expect(g.boards[0].bread, isFalse);
      expect(g.money, m0 - loadCfg().costs['bread']!);
      g.dispose();
    });

    testWidgets('malzemeleri tezgâha sürükleyerek dürüm kur, SAR ile sar', (t) async {
      final g = started();
      await show(t, g);
      await drag(t, find.text('Tırnaklı ekmek'), find.byKey(const ValueKey('board-0')));
      await drag(t, find.text('Nohut'), find.byKey(const ValueKey('board-0')));
      await drag(t, find.text('Nohut'), find.byKey(const ValueKey('board-0')));
      await drag(t, find.text('Piyaz'), find.byKey(const ValueKey('board-0')));
      expect(g.boards[0].nohut, 2);
      expect(g.boards[0].piyaz, isTrue);
      await t.tap(find.byKey(const ValueKey('wrap-0')));
      await t.pump();
      expect(g.boards[0].wrapped, isTrue);
      g.dispose();
    });

    testWidgets('aynı anda 3 dürüm kurup üç müşteriye sürükleyerek ver', (t) async {
      final g = started(21);
      // üç müşteri beklesin
      bool normalWaiting(Customer? c) => c != null && c.state == CustomerState.waiting && c.kind == CustomerKind.normal;
      for (var i = 0; i < 3000 && g.slots.where(normalWaiting).length < 3; i++) {
        g.tick(0.1);
        if (g.phase != Phase.playing) break;
      }
      final waiting = [
        for (var i = 0; i < g.slotCount; i++)
          if (normalWaiting(g.slots[i])) i
      ];
      expect(waiting.length, greaterThanOrEqualTo(2), reason: 'en az iki müşteri bekliyor olmalı');
      final n = waiting.length.clamp(2, 3);
      await show(t, g);
      for (var k = 0; k < n; k++) {
        g.activeBoard = k;
        prepare(g, g.slots[waiting[k]]!.spec);
      }
      await t.pump();
      expect(g.boards.where((b) => b.wrapped).length, n);
      final m0 = g.money;
      for (var k = 0; k < n; k++) {
        // k. tezgâhtaki dürümü k. müşteriye sürükle (Draggable çocuğu: dürüm görseli)
        final from = find.descendant(of: find.byKey(ValueKey('board-$k')), matching: find.byType(Draggable<BoardDrag>));
        await drag(t, from, find.byKey(ValueKey('customer-${waiting[k]}')));
      }
      expect(g.servedToday, n, reason: 'her sürükleme bir müşteriyi servis etmeli');
      expect(g.greatToday, n);
      expect(g.money, greaterThan(m0));
      expect(g.boards.every((b) => b.isEmpty), isTrue);
      g.dispose();
    });

    testWidgets('sarılmamış tezgâh sürüklenemez; boş müşteri alanına bırakma hiçbir şey yapmaz', (t) async {
      final g = started();
      await show(t, g);
      g.tapBread(board: 0);
      await t.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('board-0')), matching: find.byType(Draggable<BoardDrag>)), findsNothing);
      g.dispose();
    });
  });
}

int cfgBread() => loadCfg().costs['bread']!;
int cfgNohut() => loadCfg().product('nohut').unit;
