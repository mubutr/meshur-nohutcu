import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/leaderboard/leaderboard.dart';
import 'package:nohut_durumu/ui/leaderboard_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

DayEndedEvent dayEnd(int day, int score) =>
    DayEndedEvent(day: day, served: 5, great: 3, lost: 0, earned: 100, tips: 10, netProfit: 50, score: score, reputation: 0.9);

Future<SharedPreferences> freshPrefs([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  return SharedPreferences.getInstance();
}

const kEmptyBoard = '{"entries":[{"rank":1,"name":"Maho","score":900,"days":4,"mine":false},{"rank":2,"name":"Sen","score":300,"days":2,"mine":true}],"me":null}';

void main() {
  group('yerel sıralama', () {
    test('gün sonu skoru kaydedilir; hafta/tüm zamanlar süzgeci çalışır', () async {
      var t = 1_000_000_000_000;
      final prefs = await freshPrefs();
      final m = LeaderboardManager(prefs: prefs, random: Random(1), now: () => t);
      m.handle(dayEnd(1, 120));
      m.handle(dayEnd(2, 80));
      await pumpEventQueue();
      t += const Duration(days: 8).inMilliseconds;
      m.handle(dayEnd(1, 500)); // yeni seri (1. gün tekrar bitti)
      await pumpEventQueue();
      final all = await m.local.fetch(m.device, BoardPeriod.all);
      expect(all.offline, isTrue);
      expect(all.entries.map((e) => e.score), [500, 200]);
      final week = await m.local.fetch(m.device, BoardPeriod.week);
      expect(week.entries.map((e) => e.score), [500]);
    });

    test('aynı gün iki kez gelirse tek kayıt; seri kimliği 1. günde yenilenir', () async {
      final prefs = await freshPrefs();
      final m = LeaderboardManager(prefs: prefs, random: Random(2));
      final run1 = m.run;
      m.handle(dayEnd(1, 50));
      await pumpEventQueue();
      expect(m.run, isNot(run1), reason: '1. gün bittiyse yeni seri');
      final run2 = m.run;
      m.handle(dayEnd(2, 70));
      m.handle(dayEnd(2, 70));
      await pumpEventQueue();
      expect(m.run, run2);
      final all = await m.local.fetch(m.device, BoardPeriod.all);
      expect(all.entries.single.days, 2); // (gün1 eski seride; gün2 yeni seride... yine de aynı gün tekrar sayılmaz)
    }, skip: false);

    test('takma ad temizlenir, çok kısa ad reddedilir, kalıcı olur', () async {
      final prefs = await freshPrefs();
      final m = LeaderboardManager(prefs: prefs, random: Random(3));
      await m.setName('  <b>Rafık</b>  ');
      expect(m.name, 'bRafık/b');
      final before = m.name;
      await m.setName('a');
      expect(m.name, before);
      await m.setName('Çok Uzun Bir Takma Ad Burada');
      expect(m.name.length, 16);
      final again = LeaderboardManager(prefs: prefs, random: Random(9));
      expect(again.name, m.name);
      expect(again.device, m.device);
    });
  });

  group('sunucu istemcisi', () {
    test('POST gövdesi ve HMAC imzası beklenen biçimde', () async {
      final prefs = await freshPrefs();
      late http.Request seen;
      final client = MockClient((r) async {
        seen = r;
        return http.Response('{"ok":true}', 200);
      });
      final m = LeaderboardManager(prefs: prefs, random: Random(4), remote: RemoteLeaderboard(baseUrl: 'http://x', secret: 'gizli', client: client));
      m.handle(dayEnd(3, 77));
      await pumpEventQueue();
      final b = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(seen.url.path, '/scores');
      expect(b['day'], 3);
      expect(b['score'], 77);
      expect(b['device'], m.device);
      expect(b['sig'], RemoteLeaderboard.sign('gizli', m.device, ScoreSubmission(run: m.run, day: 3, score: 77, at: 0)));
      expect(m.pending, 0);
    });

    test('sunucu yokken kuyruğa girer, geri gelince sırayla gönderilir', () async {
      final prefs = await freshPrefs();
      var up = false;
      final sent = <int>[];
      final client = MockClient((r) async {
        if (!up) throw const SocketException('kapalı');
        sent.add((jsonDecode(r.body) as Map)['day'] as int);
        return http.Response('{"ok":true}', 200);
      });
      final m = LeaderboardManager(prefs: prefs, random: Random(5), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      m.handle(dayEnd(1, 10));
      m.handle(dayEnd(2, 20));
      await pumpEventQueue();
      expect(m.pending, 2);
      expect(sent, isEmpty);
      // uygulama yeniden açıldı: kuyruk kalıcı
      final m2 = LeaderboardManager(prefs: prefs, random: Random(5), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      expect(m2.pending, 2);
      up = true;
      await m2.flush();
      expect(sent, [1, 2]);
      expect(m2.pending, 0);
    });

    test('art arda gelen günler yavaş ağda bile tekrarsız ve sırayla gider', () async {
      final prefs = await freshPrefs();
      final sent = <int>[];
      final client = MockClient((r) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        sent.add((jsonDecode(r.body) as Map)['day'] as int);
        return http.Response('{"ok":true}', 200);
      });
      final m = LeaderboardManager(prefs: prefs, random: Random(12), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      m.handle(dayEnd(1, 10));
      m.handle(dayEnd(2, 20));
      m.handle(dayEnd(3, 30));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sent, [1, 2, 3]);
      expect(m.pending, 0);
    });

    test('4xx yanıtı kuyruğu tıkamaz; 5xx yeniden denenir', () async {
      final prefs = await freshPrefs();
      var status = 422;
      final client = MockClient((r) async => http.Response('{}', status));
      final m = LeaderboardManager(prefs: prefs, random: Random(6), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      m.handle(dayEnd(1, 10));
      await pumpEventQueue();
      expect(m.pending, 0, reason: 'reddedilen kayıt atılır');
      status = 503;
      m.handle(dayEnd(2, 10));
      await pumpEventQueue();
      expect(m.pending, 1);
    });

    test('tablo sunucudan okunur; sunucu düşünce yerel tabloya düşer', () async {
      final prefs = await freshPrefs();
      var up = true;
      final client = MockClient((r) async {
        if (!up) throw const SocketException('kapalı');
        if (r.url.path == '/leaderboard') {
          expect(r.url.queryParameters['period'], 'all');
          return http.Response.bytes(utf8.encode(kEmptyBoard), 200);
        }
        return http.Response('{"ok":true}', 200);
      });
      final m = LeaderboardManager(prefs: prefs, random: Random(7), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      m.handle(dayEnd(1, 40));
      await pumpEventQueue();
      await m.setPeriod(BoardPeriod.all);
      expect(m.board!.offline, isFalse);
      expect(m.board!.entries.map((e) => e.name), ['Maho', 'Sen']);
      expect(m.board!.entries[1].mine, isTrue);
      up = false;
      await m.refresh();
      expect(m.board!.offline, isTrue);
      expect(m.board!.entries.single.score, 40);
    });
  });

  group('arayüz', () {
    Future<void> show(WidgetTester tester, LeaderboardManager m) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListenableBuilder(listenable: m, builder: (_, _) => Stack(children: [LeaderboardOverlay(manager: m)])))));
      await tester.pump();
    }

    testWidgets('sunucu tablosu, kendi satırı ve dönem sekmeleri görünür', (tester) async {
      final prefs = await freshPrefs();
      final client = MockClient((r) async => http.Response.bytes(utf8.encode(kEmptyBoard), 200));
      final m = LeaderboardManager(prefs: prefs, random: Random(8), remote: RemoteLeaderboard(baseUrl: 'http://x', client: client));
      m.toggle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await show(tester, m);
      expect(find.text('Mahalle Sıralaması'), findsOneWidget);
      expect(find.text('Maho'), findsOneWidget);
      expect(find.text('Sen  (sen)'), findsOneWidget);
      expect(find.text('Bu hafta'), findsOneWidget);
      expect(find.textContaining('otomatik gönderilir'), findsOneWidget);
    });

    testWidgets('çevrimdışıyken açıklama gösterilir; takma ad değiştirilebilir', (tester) async {
      final prefs = await freshPrefs();
      final m = LeaderboardManager(prefs: prefs, random: Random(9));
      m.toggle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await show(tester, m);
      expect(find.textContaining('Çevrimdışı sıralama'), findsOneWidget);
      expect(find.textContaining('Henüz kimse yok'), findsOneWidget);
      await tester.tap(find.text('Değiştir'));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('nick-field')), 'Antepli Usta');
      await tester.tap(find.text('Kaydet'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(m.name, 'Antepli Usta');
      expect(find.text('Antepli Usta'), findsOneWidget);
    });
  });

}
