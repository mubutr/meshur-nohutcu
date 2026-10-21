import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/events.dart';

/// Sıralama dönemi: son 7 gün ya da tüm zamanlar.
enum BoardPeriod { week, all }

/// Bir günün sonunda gönderilen tek skor kaydı.
class ScoreSubmission {
  const ScoreSubmission({required this.run, required this.day, required this.score, required this.at});
  final String run; // oyun serisinin (baştan başlama) kimliği
  final int day;
  final int score;
  final int at; // epoch ms

  Map<String, dynamic> toJson() => {'run': run, 'day': day, 'score': score, 'at': at};
  factory ScoreSubmission.fromJson(Map<String, dynamic> j) =>
      ScoreSubmission(run: j['run'] as String, day: j['day'] as int, score: j['score'] as int, at: j['at'] as int);
}

class ScoreEntry {
  const ScoreEntry({required this.rank, required this.name, required this.score, required this.days, this.mine = false});
  final int rank;
  final String name;
  final int score;
  final int days;
  final bool mine;
}

class Board {
  const Board({required this.entries, this.me, this.offline = false});
  final List<ScoreEntry> entries;
  final ScoreEntry? me; // ilk 20'de değilse kendi sıran
  final bool offline; // sunucuya ulaşılamadı; yalnızca bu cihazın kayıtları
}

abstract class LeaderboardService {
  /// Başarısızsa istisna fırlatır; çağıran kuyruğa geri koyar.
  Future<void> submit(String device, String name, ScoreSubmission s);
  Future<Board> fetch(String device, BoardPeriod period);
}

/// Sunucusuz yedek: bu cihazdaki serilerin toplam puanları.
class LocalLeaderboard implements LeaderboardService {
  LocalLeaderboard({this.prefs, int Function()? now, this.nameOf}) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final SharedPreferences? prefs;
  final int Function() _now;
  final String Function()? nameOf;
  static const _key = 'lb_local';
  final List<ScoreSubmission> _all = [];
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    _loaded = true;
    final raw = prefs?.getString(_key);
    if (raw == null) return;
    try {
      for (final j in jsonDecode(raw) as List) {
        _all.add(ScoreSubmission.fromJson(j as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  @override
  Future<void> submit(String device, String name, ScoreSubmission s) async {
    _load();
    if (_all.any((e) => e.run == s.run && e.day == s.day)) return;
    _all.add(s);
    await prefs?.setString(_key, jsonEncode(_all.map((e) => e.toJson()).toList()));
  }

  @override
  Future<Board> fetch(String device, BoardPeriod period) async {
    _load();
    final since = period == BoardPeriod.week ? _now() - const Duration(days: 7).inMilliseconds : 0;
    final byRun = <String, List<ScoreSubmission>>{};
    for (final s in _all) {
      if (s.at >= since) byRun.putIfAbsent(s.run, () => []).add(s);
    }
    final runs = byRun.values.toList()..sort((a, b) => b.fold(0, (x, e) => x + e.score).compareTo(a.fold(0, (x, e) => x + e.score)));
    final name = nameOf?.call() ?? 'Sen';
    final entries = <ScoreEntry>[
      for (var i = 0; i < runs.length && i < 20; i++)
        ScoreEntry(rank: i + 1, name: name, score: runs[i].fold(0, (x, e) => x + e.score), days: runs[i].length, mine: true),
    ];
    return Board(entries: entries, offline: true);
  }
}

/// Basit REST istemcisi (bkz. server/leaderboard).
class RemoteLeaderboard implements LeaderboardService {
  RemoteLeaderboard({required this.baseUrl, this.secret = '', http.Client? client, this.timeout = const Duration(seconds: 6)}) : _client = client ?? http.Client();
  final String baseUrl;
  final String secret;
  final Duration timeout;
  final http.Client _client;

  static String sign(String secret, String device, ScoreSubmission s) {
    final msg = '$device|${s.run}|${s.day}|${s.score}';
    return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).toString();
  }

  @override
  Future<void> submit(String device, String name, ScoreSubmission s) async {
    final r = await _client
        .post(
          Uri.parse('$baseUrl/scores'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'device': device, 'name': name, 'run': s.run, 'day': s.day, 'score': s.score, 'sig': secret.isEmpty ? '' : sign(secret, device, s)}),
        )
        .timeout(timeout);
    // 4xx: sunucu kaydı reddetti (ör. makul olmayan skor); yeniden denemenin anlamı yok
    if (r.statusCode >= 500 || r.statusCode == 429) throw http.ClientException('sunucu ${r.statusCode}');
  }

  @override
  Future<Board> fetch(String device, BoardPeriod period) async {
    final r = await _client.get(Uri.parse('$baseUrl/leaderboard?period=${period.name}&device=$device')).timeout(timeout);
    if (r.statusCode != 200) throw http.ClientException('sunucu ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    ScoreEntry parse(Map<String, dynamic> e) => ScoreEntry(rank: e['rank'] as int, name: e['name'] as String, score: e['score'] as int, days: e['days'] as int, mine: e['mine'] == true);
    return Board(
      entries: [for (final e in j['entries'] as List) parse(e as Map<String, dynamic>)],
      me: j['me'] == null ? null : parse(j['me'] as Map<String, dynamic>),
    );
  }
}

/// Oyun ile sıralama servisi arasındaki köprü: gün sonu skorunu kaydeder, gönderir, çevrimdışıyken kuyruğa alır.
class LeaderboardManager extends ChangeNotifier {
  LeaderboardManager({this.prefs, this.remote, LeaderboardService? local, Random? random, int Function()? now})
      : _rnd = random ?? Random.secure(),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    this.local = local ?? LocalLeaderboard(prefs: prefs, now: _now, nameOf: () => name);
    final p = prefs;
    device = p?.getString('lb_device') ?? _hex(16);
    name = p?.getString('lb_name') ?? 'Çırak${100 + _rnd.nextInt(900)}';
    run = p?.getString('lb_run') ?? _hex(6);
    final q = p?.getString('lb_queue');
    if (q != null) {
      try {
        for (final j in jsonDecode(q) as List) {
          _queue.add(ScoreSubmission.fromJson(j as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    p?.setString('lb_device', device);
    p?.setString('lb_name', name);
    p?.setString('lb_run', run);
  }

  final SharedPreferences? prefs;
  final LeaderboardService? remote; // null → yalnızca yerel
  late final LeaderboardService local;
  final Random _rnd;
  final int Function() _now;
  late final String device;
  late String name;
  late String run;
  final List<ScoreSubmission> _queue = [];

  bool open = false;
  bool loading = false;
  BoardPeriod period = BoardPeriod.week;
  Board? board;

  bool get hasRemote => remote != null;
  int get pending => _queue.length;

  String _hex(int bytes) => List.generate(bytes, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// GameController olay aboneliği.
  void handle(GameEvent e) {
    if (e is DayEndedEvent) {
      // 1. gün bittiyse yeni bir seri (baştan başlama) başlamıştır
      if (e.day == 1) {
        run = _hex(6);
        prefs?.setString('lb_run', run);
      }
      submit(ScoreSubmission(run: run, day: e.day, score: e.score, at: _now()));
    }
  }

  Future<void> submit(ScoreSubmission s) async {
    // kuyruğa eşzamanlı eklenir: art arda gelen günlerin sırası bozulmaz
    if (remote != null) _queue.add(s);
    await local.submit(device, name, s);
    if (remote != null) {
      await _saveQueue();
      await flush();
    }
  }

  Future<void> _chain = Future.value();

  /// Bekleyen skorları sırayla gönderir; ilk ağ hatasında durur. Çağrılar art arda çalışır.
  Future<void> flush() => _chain = _chain.then((_) => _flushNow());

  Future<void> _flushNow() async {
    final r = remote;
    if (r == null) return;
    while (_queue.isNotEmpty) {
      try {
        await r.submit(device, name, _queue.first);
      } catch (_) {
        break;
      }
      _queue.removeAt(0);
    }
    await _saveQueue();
  }

  Future<void> _saveQueue() async => prefs?.setString('lb_queue', jsonEncode(_queue.map((e) => e.toJson()).toList()));

  Future<void> setName(String raw) async {
    final n = raw.replaceAll(RegExp(r'[\u0000-\u001f<>]'), '').trim();
    if (n.length < 2) return;
    name = n.length > 16 ? n.substring(0, 16) : n;
    await prefs?.setString('lb_name', name);
    notifyListeners();
    await refresh();
  }

  void toggle() {
    open = !open;
    if (open) refresh();
    notifyListeners();
  }

  Future<void> setPeriod(BoardPeriod p) async {
    period = p;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    Board? b;
    final r = remote;
    if (r != null) {
      try {
        await flush();
        b = await r.fetch(device, period);
      } catch (_) {
        b = null;
      }
    }
    board = b ?? await local.fetch(device, period);
    loading = false;
    notifyListeners();
  }
}
