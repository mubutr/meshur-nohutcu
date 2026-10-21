import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/leaderboard/leaderboard.dart';
import 'package:nohut_durumu/ui/game_screen.dart';
import 'package:nohut_durumu/ui/splash.dart';
import 'package:nohut_durumu/ui/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<SharedPreferences> freshPrefs([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  return SharedPreferences.getInstance();
}

GameController makeV4(SharedPreferences? prefs, {bool tutorial = false, bool gameOver = false, LeaderboardManager? board, int seed = 3}) => GameController(
      cfg: loadCfg(),
      dialog: loadDialog(seed),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(seed),
      prefs: prefs,
      leaderboard: board,
      tutorialEnabled: tutorial,
      gameOverEnabled: gameOver,
    );

void begin(GameController g) {
  g.quests.chapterIntroSeen = true;
  g.startDay();
  skipScenes(g);
}

/// Bekleyen müşteriler sabırsızlanıp gidene kadar ilerlet.
void loseCustomers(GameController g, {int maxTicks = 6000}) {
  for (var i = 0; i < maxTicks && g.phase == Phase.playing; i++) {
    g.tick(0.1);
    skipScenes(g);
  }
}

void main() {
  group('açılış (bigsoft) yükleme ekranı', () {
    testWidgets('logo, "games sunar" ve yüzde gösterilir', (t) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: BigsoftSplash(progress: 0.42))));
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('bigsoft-logo')), findsOneWidget);
      expect(find.text('games sunar'), findsOneWidget);
      expect(find.text('Yükleniyor… %42'), findsOneWidget);
      final bar = t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, 0.42);
    });

    testWidgets('ilerleme sınırlandırılır', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: BigsoftSplash(progress: 3))));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Yükleniyor… %100'), findsOneWidget);
    });
  });

  group('tanıtım (oynanış)', () {
    test('adım sayısı denetleyiciyle aynı', () {
      expect(kTutorialSteps.length, GameController.tutorialStepCount);
    });

    test('ilk gün başında açılır, adımlar ilerler, bitince kalıcı olarak kapanır', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs, tutorial: true)..load();
      begin(g);
      g.tick(0.1);
      expect(g.tutorialActive, isTrue);
      expect(g.paused, isTrue, reason: 'tanıtım sürerken oyun durur');
      expect(g.tutorialStep, 0);
      for (var i = 1; i < GameController.tutorialStepCount; i++) {
        g.nextTutorial();
        expect(g.tutorialStep, i);
      }
      g.nextTutorial();
      expect(g.tutorialActive, isFalse);
      expect(g.tutorialDone, isTrue);
      expect(prefs.getBool('tutorial_done'), isTrue);
      expect(g.paused, isFalse);
      g.dispose();
    });

    test('Atla da kalıcı olarak kapatır; sonraki oyunda tekrar çıkmaz', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs, tutorial: true)..load();
      begin(g);
      g.tick(0.1);
      g.skipTutorial();
      expect(g.tutorialActive, isFalse);
      g.dispose();
      final g2 = makeV4(prefs, tutorial: true)..load();
      expect(g2.tutorialDone, isTrue);
      begin(g2);
      g2.tick(0.1);
      expect(g2.tutorialActive, isFalse);
      g2.dispose();
    });

    test('ayarlardan yeniden gösterilir; bayrak kapalıyken hiç açılmaz', () async {
      final prefs = await freshPrefs({'tutorial_done': true});
      final g = makeV4(prefs, tutorial: true)..load();
      begin(g);
      g.tick(0.1);
      expect(g.tutorialActive, isFalse);
      g.replayTutorial();
      g.tick(0.1);
      expect(g.tutorialActive, isTrue);
      g.dispose();
      final off = makeV4(await freshPrefs())..load();
      begin(off);
      off.tick(0.1);
      expect(off.tutorialActive, isFalse);
      off.dispose();
    });

    testWidgets('kart ekranda; Devam ve Atla çalışır', (t) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = makeV4(await freshPrefs(), tutorial: true)..load();
      begin(g);
      g.tick(0.1);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
      await t.pump();
      expect(find.byKey(const ValueKey('tutorial-card')), findsOneWidget);
      expect(find.text('1/${kTutorialSteps.length}'), findsOneWidget);
      await t.tap(find.text('Devam'));
      await t.pump();
      expect(g.tutorialStep, 1);
      await t.tap(find.text('Atla'));
      await t.pump();
      expect(find.byKey(const ValueKey('tutorial-card')), findsNothing);
      expect(g.tutorialDone, isTrue);
      g.dispose();
    });
  });

  group('kaldığın yerden devam', () {
    test('yarım gün kaydı: müşteriler, tezgâhlar ve sayaçlar geri gelir', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs)..load();
      begin(g);
      g.money = 777;
      final slot = waitForCustomer(g);
      expect(slot, isNot(-1));
      final spec = g.slots[slot]!.spec;
      g.tapBread(board: 0);
      g.tapMain(board: 0);
      g.tapBread(board: 2);
      g.tapPiyaz(board: 2);
      final served = g.servedToday;
      final nohut0 = g.boards[0].nohut;
      final dayNo = g.day;
      g.toTitle();
      await pumpEventQueue();
      expect(g.hasResumable, isTrue);
      g.dispose();

      final g2 = makeV4(prefs)..load();
      expect(g2.hasResumable, isTrue);
      g2.continueGame();
      expect(g2.phase, Phase.playing);
      expect(g2.day, dayNo);
      expect(g2.servedToday, served);
      expect(g2.boards[0].bread, isTrue);
      expect(g2.boards[0].nohut, nohut0);
      expect(g2.boards[2].piyaz, isTrue);
      expect(g2.slots[slot]?.spec.wrap, spec.wrap);
      expect(g2.slots[slot]?.spec.nohut, spec.nohut);
      expect(g2.money, g.money);
      g2.dispose();
    });

    test('kayıt yoksa DEVAM yeni gün başlatır; kayıt yeni oyunda silinir', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs)..load();
      expect(g.hasResumable, isFalse);
      g.quests.chapterIntroSeen = true;
      g.continueGame();
      expect(g.phase, Phase.playing);
      g.toTitle();
      expect(prefs.getString('day_snapshot'), isNotNull);
      await g.resetSave();
      expect(prefs.getString('day_snapshot'), isNull);
      expect(g.hasResumable, isFalse);
      g.dispose();
    });

    test('bozuk kayıt oyunu bozmaz: yeni gün başlar', () async {
      final prefs = await freshPrefs({'day_snapshot': '{bozuk', 'day': 3});
      final g = makeV4(prefs)..load();
      g.quests.chapterIntroSeen = true;
      g.continueGame();
      expect(g.phase, Phase.playing);
      expect(g.day, 3);
      g.dispose();
    });

    test('başka güne ait kayıt yüklenmez', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs)..load();
      begin(g);
      g.toTitle();
      g.dispose();
      final snap = jsonDecode(prefs.getString('day_snapshot')!) as Map<String, dynamic>;
      snap['day'] = 99;
      await prefs.setString('day_snapshot', jsonEncode(snap));
      final g2 = makeV4(prefs)..load();
      g2.quests.chapterIntroSeen = true;
      g2.continueGame();
      expect(g2.phase, Phase.playing);
      expect(g2.day, 1);
      g2.dispose();
    });

    test('gün sonu toplam puana eklenir ve kalıcıdır', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs)..load();
      begin(g);
      g.scoreToday = 120;
      g.toSpawn = 0;
      for (var i = 0; i < 40 && g.phase == Phase.playing; i++) {
        g.tick(0.1);
      }
      expect(g.phase, Phase.dayEnd);
      expect(g.totalScore, greaterThanOrEqualTo(120));
      await g.save();
      expect(prefs.getInt('totalScore'), g.totalScore);
      final g2 = makeV4(prefs)..load();
      expect(g2.totalScore, g.totalScore);
      g.dispose();
      g2.dispose();
    });
  });

  group('kaybetme ve reklamla devam', () {
    test('canlar biter, oyun biter; kapalıyken (varsayılan) bitmez', () async {
      final off = makeV4(await freshPrefs())..load();
      begin(off);
      off.lives = 1;
      loseCustomers(off, maxTicks: 3000);
      expect(off.phase, isNot(Phase.gameOver));
      off.dispose();

      final g = makeV4(await freshPrefs(), gameOver: true)..load();
      begin(g);
      expect(g.lives, g.maxLives);
      loseCustomers(g);
      expect(g.phase, Phase.gameOver);
      expect(g.lives, 0);
      g.dispose();
    });

    test('reklam izleyince canlar dolar, sabır yenilenir, oyun sürer; günde yalnızca bir kez', () async {
      final g = makeV4(await freshPrefs(), gameOver: true)..load();
      begin(g);
      loseCustomers(g);
      expect(g.phase, Phase.gameOver);
      expect(g.canWatchAd('revive'), isTrue);
      g.startAd('revive');
      expect(g.adKind, 'revive');
      for (var i = 0; i < 1000 && g.adKind != null; i++) {
        g.tick(0.1);
      }
      expect(g.adKind, isNull);
      expect(g.phase, Phase.playing);
      expect(g.lives, g.maxLives);
      expect(g.reviveUsedToday, isTrue);
      for (final c in g.slots.whereType<Customer>().where((c) => c.state == CustomerState.waiting)) {
        expect(c.patience, closeTo(c.maxPatience, 0.5));
      }
      g.toSpawn = 999; // gün bitmeden yine kaçırılsın
      loseCustomers(g);
      expect(g.phase, Phase.gameOver);
      expect(g.canWatchAd('revive'), isFalse, reason: 'ikinci devam hakkı yok');
      g.startAd('revive');
      expect(g.adKind, isNull);
      g.dispose();
    });

    test('günü baştan başla: kasa gün başındaki hale döner', () async {
      final g = makeV4(await freshPrefs(), gameOver: true)..load();
      begin(g);
      final startMoney = g.money;
      final startDay = g.day;
      g.money += 500;
      loseCustomers(g);
      expect(g.phase, Phase.gameOver);
      g.restartDay();
      expect(g.phase, Phase.playing);
      expect(g.day, startDay);
      expect(g.money, startMoney);
      expect(g.lives, g.maxLives);
      expect(g.lostToday, 0);
      g.dispose();
    });

    test('oyun bitti durumu kayıttan geri gelir', () async {
      final prefs = await freshPrefs();
      final g = makeV4(prefs, gameOver: true)..load();
      begin(g);
      loseCustomers(g);
      expect(g.phase, Phase.gameOver);
      g.toTitle();
      await pumpEventQueue();
      g.dispose();
      final g2 = makeV4(prefs, gameOver: true)..load();
      expect(g2.hasResumable, isTrue);
      g2.continueGame();
      expect(g2.phase, Phase.gameOver);
      g2.dispose();
    });

    testWidgets('Küstü ekranı görünür ve reklam düğmesi reklamı başlatır', (t) async {
      t.view.physicalSize = const Size(1600, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = makeV4(await freshPrefs(), gameOver: true)..load();
      begin(g);
      loseCustomers(g);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: GameScreen(game: g, animations: false))));
      await t.pump();
      expect(find.text('Müşteriler küstü!'), findsOneWidget);
      await t.tap(find.text('Reklam izle, devam et'));
      await t.pump();
      expect(g.adKind, 'revive');
      g.dispose();
    });
  });

  group('sunucu eşitleme (yönetim sayfası)', () {
    LeaderboardManager manager(SharedPreferences prefs, MockClient client, {String secret = 'gizli'}) =>
        LeaderboardManager(prefs: prefs, random: Random(5), remote: RemoteLeaderboard(baseUrl: 'http://x', secret: secret, client: client));

    test('durum POST /profile ile imzalı gider', () async {
      final prefs = await freshPrefs();
      late http.Request seen;
      final board = manager(prefs, MockClient((r) async {
        seen = r;
        return http.Response('{"ok":true,"patch":null}', 200);
      }));
      final g = makeV4(prefs, board: board)..load();
      g.money = 321;
      g.diamonds = 4;
      board.attach(g, every: null);
      await board.syncNow();
      final b = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(seen.url.path, '/profile');
      expect(b['money'], 321);
      expect(b['diamonds'], 4);
      expect(b['day'], g.day);
      expect(b['ack'], 0);
      expect(b['sig'], RemoteLeaderboard.signProfile('gizli', board.device, ProfileState(money: 321, diamonds: 4, day: g.day, chapter: g.chapter, totalScore: 0)));
      g.dispose();
    });

    test('yönetici düzenlemesi oyunda anında uygulanır, ack gönderilir ve kalıcı olur', () async {
      final prefs = await freshPrefs();
      var patchSent = false;
      final acks = <int>[];
      final board = manager(prefs, MockClient((r) async {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        acks.add(b['ack'] as int);
        if (!patchSent) {
          patchSent = true;
          return http.Response('{"ok":true,"patch":{"rev":2,"money":9999,"diamonds":55,"day":7,"totalScore":4000}}', 200);
        }
        return http.Response('{"ok":true,"patch":null}', 200);
      }));
      final g = makeV4(prefs, board: board)..load();
      board.attach(g, every: null);
      var notified = 0;
      g.addListener(() => notified++);
      await board.syncNow();
      expect(g.money, 9999);
      expect(g.diamonds, 55);
      expect(g.day, 7);
      expect(g.totalScore, 4000);
      expect(notified, greaterThan(0));
      expect(board.ackRev, 2);
      expect(prefs.getInt('lb_rev'), 2);
      expect(prefs.getInt('money'), 9999);
      await board.syncNow();
      expect(acks, [0, 2]);
      // aynı sürüm yeniden gelirse tekrar uygulanmaz
      g.money = 5;
      patchSent = false;
      await board.syncNow(); // sunucu yine rev 2 yollar
      expect(g.money, 5, reason: 'aynı rev tekrar uygulanmaz');
      g.dispose();
    });

    test('ağ hatasında oyun etkilenmez ve bir sonraki turda yeniden denenir', () async {
      final prefs = await freshPrefs();
      var fail = true;
      var calls = 0;
      final board = manager(prefs, MockClient((r) async {
        calls++;
        if (fail) return http.Response('x', 503);
        return http.Response('{"ok":true,"patch":null}', 200);
      }));
      final g = makeV4(prefs, board: board)..load();
      g.money = 40;
      board.attach(g, every: null);
      await board.syncNow();
      expect(g.money, 40);
      fail = false;
      await board.syncNow();
      expect(calls, 2);
      g.dispose();
    });

    test('sunucusuz kurulumda eşitleme hiçbir şey yapmaz', () async {
      final prefs = await freshPrefs();
      final board = LeaderboardManager(prefs: prefs, random: Random(6));
      final g = makeV4(prefs, board: board)..load();
      board.attach(g);
      await board.syncNow();
      expect(g.money, 0);
      board.dispose();
      g.dispose();
    });

    test('toplam puan gün sonunda artar ve sıralama yöneticisinden okunur', () async {
      final prefs = await freshPrefs();
      final board = LeaderboardManager(prefs: prefs, random: Random(7));
      final g = makeV4(prefs, board: board)..load();
      board.attach(g);
      g.applyRemotePatch(totalScore: 250);
      expect(board.totalScore, 250);
      g.dispose();
    });
  });
}

