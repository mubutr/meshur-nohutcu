// Gerçek Node sunucusuna karşı uçtan uca deneme. LB_URL verilmezse atlanır.
// (Ayrı dosyada: widget testleri HTTP'yi sahte yanıtla kapatır.)
//   cd server/leaderboard; $env:SECRET='test'; node server.js
//   $env:LB_URL='http://127.0.0.1:8787'; flutter test test/e2e_leaderboard_test.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/game/events.dart';
import 'package:nohut_durumu/leaderboard/leaderboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final url = Platform.environment['LB_URL'];
  test('gerçek sunucuya skor gönder ve tabloda gör', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final m = LeaderboardManager(prefs: prefs, random: Random(11), remote: RemoteLeaderboard(baseUrl: url!, secret: Platform.environment['LB_SECRET'] ?? 'test'));
    await m.setName('UcUca');
    DayEndedEvent d(int day, int score) => DayEndedEvent(day: day, served: 5, great: 3, lost: 0, earned: 100, tips: 10, netProfit: 50, score: score, reputation: 0.9);
    m.handle(d(1, 321));
    m.handle(d(2, 111));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(m.pending, 0);
    await m.setPeriod(BoardPeriod.all);
    expect(m.board!.offline, isFalse);
    final mine = [...m.board!.entries, if (m.board!.me != null) m.board!.me!].firstWhere((e) => e.mine);
    expect(mine.name, 'UcUca');
    expect(mine.score, 432);
    expect(mine.days, 2);
  }, skip: url == null ? 'LB_URL yok' : false);
}
