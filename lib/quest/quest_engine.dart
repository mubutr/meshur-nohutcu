import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../game/events.dart';
import 'quest_models.dart';

/// Bir görevin çalışma zamanı durumu.
class QuestState {
  QuestState(this.def) : progress = List.filled(def.objectives.length, 0);
  final QuestDef def;
  final List<int> progress;
  bool done = false;

  bool get complete => !done && Iterable<int>.generate(def.objectives.length).every((i) => progress[i] >= def.objectives[i].target);
  double get fraction {
    var t = 0, p = 0;
    for (var i = 0; i < def.objectives.length; i++) {
      t += def.objectives[i].target;
      p += progress[i].clamp(0, def.objectives[i].target);
    }
    return t == 0 ? 1 : p / t;
  }
}

/// Günlük görev (şablondan üretilir).
class DailyQuest {
  DailyQuest({required this.id, required this.title, required this.objective, required this.money, required this.stars});
  final String id;
  final String title;
  final ObjectiveDef objective;
  final int money;
  final int stars;
  int progress = 0;
  bool done = false;
  bool get complete => progress >= objective.target;
}

/// Görev bildirimi (ekranda kısa süre gösterilir).
class QuestToast {
  const QuestToast(this.title, this.line);
  final String title;
  final String line;
}

/// Bölüm / ana görev / yan görev / günlük görev ilerlemesi. Oyun olaylarını dinler.
class QuestEngine extends ChangeNotifier {
  QuestEngine(this.data, {required this.onReward, this.upgradeLevel, this.decorCount, this.streakDays = 3, this.streakDiamonds = 2});

  final QuestData data;

  /// Ardışık [streakDays] oyun gününde en az bir günlük görev tamamlanırsa [streakDiamonds] elmas verilir.
  final int streakDays;
  final int streakDiamonds;
  int dailyStreak = 0; // ardışık görev günü sayısı
  int lastStreakDay = 0; // seriye en son sayılan gün
  int dailyDoneToday = 0;

  /// Durum tabanlı hedefler (yükseltme seviyesi, sahip olunan süs) için oyun durumunu okur;
  /// görev başlamadan önce alınmış olsa da hedefin kilitlenip kalmasını önler.
  final int Function(String id)? upgradeLevel;
  final int Function()? decorCount;

  /// Ödül ver: para, yıldız, bayrak, yatırımcı.
  final void Function(QuestReward reward, String source) onReward;

  int chapter = 1;
  bool chapterIntroSeen = false;
  final Set<String> done = {};
  final Map<String, QuestState> active = {};
  final List<DailyQuest> daily = [];
  int dailyDay = 0;
  int stars = 0;
  int karma = 0; // Gariban'a yapılan yardım sayısı
  int totalEarned = 0;
  final Set<String> flags = {};

  /// Sahne kuyruğu (UI tüketir): bölüm girişleri, görev sonrası sahneler…
  final List<String> pendingScenes = [];
  final List<QuestToast> toasts = [];
  bool unseenChange = false;

  // ------------------------------------------------------------ erişim
  ChapterDef get chapterDef => data.chapter(chapter) ?? data.chapters.last;
  bool get allChaptersDone => chapter > data.chapters.last.id;

  /// Şu an ilerleyen ana görev (sıralı zincirin ilk bitmemişi).
  QuestState? get mainQuest {
    for (final id in chapterDef.quests) {
      if (!done.contains(id)) return stateFor(id);
    }
    return null;
  }

  List<QuestState> get sideQuests => [for (final id in data.side) if (!done.contains(id) && data.quests[id]!.unlockChapter <= chapter) stateFor(id)];

  QuestState stateFor(String id) => active.putIfAbsent(id, () => QuestState(data.quests[id]!));

  int get chapterIndexProgress => chapterDef.quests.where(done.contains).length;

  // ------------------------------------------------------------ bölüm akışı
  void startNewGame() {
    chapter = 1;
    done.clear();
    active.clear();
    daily.clear();
    dailyDay = 0;
    dailyStreak = 0;
    lastStreakDay = 0;
    dailyDoneToday = 0;
    stars = 0;
    karma = 0;
    totalEarned = 0;
    flags.clear();
    pendingScenes.clear();
    chapterIntroSeen = false;
    _queueIntroIfNeeded();
    notifyListeners();
  }

  void _queueIntroIfNeeded() {
    if (!chapterIntroSeen && !allChaptersDone) {
      pendingScenes.add(chapterDef.intro);
      chapterIntroSeen = true;
    }
  }

  /// Gün başında: bekleyen sahneler ve günlük görevler.
  void onDayStart(int day) {
    _queueIntroIfNeeded();
    syncStateObjectives();
    if (dailyDay != day) {
      dailyDay = day;
      dailyDoneToday = 0;
      _rollDaily(day);
    }
    notifyListeners();
  }

  /// Gün bitti: en az bir günlük görev yapıldıysa seri sürer, yoksa sıfırlanır; seri dolunca elmas verilir.
  void _updateStreak(int day) {
    if (dailyDoneToday == 0) {
      dailyStreak = 0;
      return;
    }
    dailyStreak = lastStreakDay == day - 1 ? dailyStreak + 1 : 1;
    lastStreakDay = day;
    if (dailyStreak >= streakDays) {
      dailyStreak = 0;
      onReward(QuestReward(diamonds: streakDiamonds), 'streak');
      toasts.add(QuestToast('Görev serisi!', '$streakDays gün üst üste görev yaptın  +$streakDiamonds elmas'));
      unseenChange = true;
    }
  }

  void _rollDaily(int day) {
    daily.clear();
    final rnd = Random(day * 7919 + 13);
    final pool = data.daily.where((t) => day >= t.minDay && chapter >= t.minChapter).toList()..shuffle(rnd);
    for (final t in pool.take(3)) {
      final i = rnd.nextInt(t.targets.length);
      var target = t.targets[i];
      if (t.scaleWithDay) target = (target + 20 * (day - 1)).clamp(target, target * 3);
      final title = t.title.replaceAll('{n}', '$target');
      daily.add(DailyQuest(
        id: t.id,
        title: title,
        objective: ObjectiveDef(type: t.type, target: target, filter: t.filter),
        money: t.money[min(i, t.money.length - 1)],
        stars: 1,
      ));
    }
  }

  // ------------------------------------------------------------ olaylar
  void handle(GameEvent e) {
    // hikâye bitse de günlük/yan görevler çalışmaya devam eder
    _feed((o) => _progressFor(o, e), e);
    syncStateObjectives();
    if (e is DayEndedEvent) {
      // gün sonunda tamamlanmamış günlük görevler silinir (yenisi ertesi gün gelir)
      daily.removeWhere((d) => !d.done);
      _updateStreak(e.day);
    }
    notifyListeners();
  }

  /// Durum tabanlı hedefleri (upgrade, decor) güncel oyun durumuna göre işaretler.
  /// Bir görev tamamlanınca sıradaki görev zaten sağlanmış olabilir; bu yüzden döngüyle tekrarlanır.
  void syncStateObjectives() {
    var changed = true;
    var guard = 0;
    while (changed && guard++ < 20) {
      changed = false;
      for (final q in [?mainQuest, ...sideQuests]) {
        for (var i = 0; i < q.def.objectives.length; i++) {
          final o = q.def.objectives[i];
          var v = q.progress[i];
          if (o.type == 'upgrade' && upgradeLevel != null) {
            final need = (o.filter['level'] as int?) ?? 1;
            if (upgradeLevel!(o.filter['id'] as String? ?? '') >= need) v = max(v, o.target);
          } else if (o.type == 'decor' && decorCount != null) {
            v = max(v, decorCount!());
          }
          if (v != q.progress[i]) q.progress[i] = v;
        }
        if (q.complete) {
          _completeQuest(q);
          changed = true;
          break;
        }
      }
    }
  }

  /// Bir olayın bir hedefe katkısını döndürür (0 = ilgisiz, >0 = artış, day tipleri 1 = sağlandı).
  int _progressFor(ObjectiveDef o, GameEvent e) {
    final f = o.filter;
    bool b(String k, bool v) => !f.containsKey(k) || f[k] == v;
    switch (o.type) {
      case 'serve':
        if (e is! ServedEvent) return 0;
        if (f['verdict'] == 'great' && e.verdict != Verdict.great) return 0;
        if (f['special'] != null && f['special'] != e.special) return 0;
        if (f['nohutMin'] != null && e.spec.nohut < (f['nohutMin'] as int)) return 0;
        if (!b('piyaz', e.spec.piyaz) || !b('aci', e.spec.aci) || !b('sumak', e.spec.sumak) || !b('fried', e.spec.fried)) return 0;
        if (f['wrap'] != null && f['wrap'] != e.spec.wrap) return 0;
        if (f['sauce'] == true && e.spec.sauces.isEmpty) return 0;
        if (f['notWrap'] != null && f['notWrap'] == e.spec.wrap) return 0;
        return 1;
      case 'riddle':
        if (e is! ServedEvent || e.riddleId == null || e.verdict != Verdict.great) return 0;
        if (f['giver'] != null && f['giver'] != e.giver) return 0;
        return 1;
      case 'earn':
        return e is ServedEvent ? e.total : 0;
      case 'tip':
        return e is ServedEvent ? e.tip : 0;
      case 'streak':
        return e is ServedEvent ? e.streak : 0; // en büyük değer alınır (aşağıda)
      case 'day_score':
        return e is DayEndedEvent && e.score >= o.target ? o.target : 0;
      case 'day_rep':
        if (e is! DayEndedEvent) return 0;
        final minServed = (f['minServed'] as int?) ?? 1;
        return e.served >= minServed && e.reputation * 100 >= o.target ? o.target : 0;
      case 'no_lose':
        return e is DayEndedEvent && e.lost == 0 && e.served >= ((f['minServed'] as int?) ?? 1) ? o.target : 0;
      case 'day_reach':
        return e is DayEndedEvent && e.day >= o.target ? o.target : 0;
      case 'upgrade':
        if (e is! UpgradeBoughtEvent) return 0;
        if (f['id'] != null && f['id'] != e.id) return 0;
        return e.level >= ((f['level'] as int?) ?? 1) ? o.target : 0;
      case 'decor':
        return e is DecorBoughtEvent ? 1 : 0;
      case 'npc':
        return e is NpcHelpedEvent && (f['id'] == null || f['id'] == e.npcId) ? 1 : 0;
      case 'harvest':
        return e is HarvestEvent && (f['crop'] == null || f['crop'] == e.crop) ? e.amount : 0;
      case 'deliver':
        if (e is! DeliveryEvent) return 0;
        if (f['onTime'] == true && !e.onTime) return 0;
        return 1;
      case 'clue':
        if (e is! ClueEvent) return 0;
        // 'solved' gibi özel kimlikler yalnızca süzgeç istendiğinde sayılır; sıradan ipucu sayacı 'solved'u saymaz
        if (f['id'] != null) return e.clueId == f['id'] ? 1 : 0;
        return e.clueId == 'solved' ? 0 : 1;
    }
    return 0;
  }

  void _feed(int Function(ObjectiveDef) progressFor, GameEvent e) {
    if (e is ServedEvent) totalEarned += e.total;
    // ana + yan görevler
    final candidates = <QuestState>[
      ?mainQuest,
      ...sideQuests,
    ];
    for (final q in candidates) {
      for (var i = 0; i < q.def.objectives.length; i++) {
        final o = q.def.objectives[i];
        final add = progressFor(o);
        if (add <= 0) continue;
        q.progress[i] = o.type == 'streak' || o.type.startsWith('day_') || o.type == 'no_lose' || o.type == 'upgrade'
            ? max(q.progress[i], add)
            : q.progress[i] + add;
      }
      if (q.complete) _completeQuest(q);
    }
    for (final d in daily.where((d) => !d.done)) {
      final add = progressFor(d.objective);
      if (add > 0) {
        d.progress = d.objective.type == 'streak' || d.objective.type.startsWith('day_') || d.objective.type == 'no_lose'
            ? max(d.progress, add)
            : d.progress + add;
      }
      if (d.complete) {
        d.done = true;
        dailyDoneToday++;
        onReward(QuestReward(money: d.money, stars: d.stars), 'daily');
        toasts.add(QuestToast('Günlük görev tamam', '${d.title}  +${d.money} ₺'));
        unseenChange = true;
      }
    }
    // Gariban yardımı karmayı artırır
    if (e is NpcHelpedEvent && e.npcId == 'garip') karma++;
  }

  void _completeQuest(QuestState q) {
    q.done = true;
    done.add(q.def.id);
    active.remove(q.def.id);
    stars += q.def.reward.stars;
    onReward(q.def.reward, q.def.id);
    toasts.add(QuestToast('Görev tamam: ${q.def.title}', '+${q.def.reward.money} ₺'));
    unseenChange = true;
    if (q.def.scene != null) pendingScenes.add(q.def.scene!);
    _checkChapterDone();
  }

  void _checkChapterDone() {
    if (allChaptersDone) return;
    final c = chapterDef;
    if (!c.quests.every(done.contains)) return;
    onReward(c.reward, 'chapter_${c.id}');
    toasts.add(QuestToast('Bölüm ${c.id} tamam: ${c.title}', '+${c.reward.money} ₺'));
    if (c.outro != null) pendingScenes.add(c.outro!);
    chapter += 1;
    chapterIntroSeen = false;
    _queueIntroIfNeeded();
  }

  /// Dışarıdan bayrak koy (ör. Gariban sahnesi görüldü).
  void setFlag(String f) {
    flags.add(f);
    notifyListeners();
  }

  // ------------------------------------------------------------ kayıt
  Map<String, dynamic> toJson() => {
        'chapter': chapter,
        'introSeen': chapterIntroSeen,
        'done': done.toList(),
        'progress': {for (final e in active.entries) e.key: e.value.progress},
        'daily': [for (final d in daily) {'id': d.id, 'title': d.title, 't': d.objective.type, 'target': d.objective.target, 'f': d.objective.filter, 'm': d.money, 's': d.stars, 'p': d.progress, 'd': d.done}],
        'dailyDay': dailyDay,
        'streak': dailyStreak,
        'streakDay': lastStreakDay,
        'doneToday': dailyDoneToday,
        'stars': stars,
        'karma': karma,
        'earned': totalEarned,
        'flags': flags.toList(),
      };

  void fromJson(Map<String, dynamic> j) {
    chapter = (j['chapter'] as int?) ?? 1;
    chapterIntroSeen = (j['introSeen'] as bool?) ?? false;
    done
      ..clear()
      ..addAll(((j['done'] as List?) ?? const []).cast<String>());
    active.clear();
    ((j['progress'] as Map<String, dynamic>?) ?? const {}).forEach((id, p) {
      if (data.quests.containsKey(id) && !done.contains(id)) {
        final s = QuestState(data.quests[id]!);
        final list = (p as List).cast<int>();
        for (var i = 0; i < s.progress.length && i < list.length; i++) {
          s.progress[i] = list[i];
        }
        active[id] = s;
      }
    });
    daily.clear();
    for (final d in ((j['daily'] as List?) ?? const [])) {
      final m = d as Map<String, dynamic>;
      daily.add(DailyQuest(
        id: m['id'] as String,
        title: m['title'] as String,
        objective: ObjectiveDef(type: m['t'] as String, target: m['target'] as int, filter: (m['f'] as Map<String, dynamic>?) ?? const {}),
        money: m['m'] as int,
        stars: m['s'] as int,
      )
        ..progress = m['p'] as int
        ..done = m['d'] as bool);
    }
    dailyDay = (j['dailyDay'] as int?) ?? 0;
    dailyStreak = (j['streak'] as int?) ?? 0;
    lastStreakDay = (j['streakDay'] as int?) ?? 0;
    dailyDoneToday = (j['doneToday'] as int?) ?? 0;
    stars = (j['stars'] as int?) ?? 0;
    karma = (j['karma'] as int?) ?? 0;
    totalEarned = (j['earned'] as int?) ?? 0;
    flags
      ..clear()
      ..addAll(((j['flags'] as List?) ?? const []).cast<String>());
  }

  void load(SharedPreferences? p) {
    final raw = p?.getString('quest_state');
    if (raw == null) {
      _queueIntroIfNeeded();
      return;
    }
    try {
      fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      startNewGame();
    }
  }

  Future<void> save(SharedPreferences? p) async => p?.setString('quest_state', jsonEncode(toJson()));

  /// Okunabilir hedef metni (arayüz için).
  static String describe(ObjectiveDef o) {
    if (o.label != null) return o.label!;
    return switch (o.type) {
      'serve' => 'Dürüm ver',
      'riddle' => 'Bilmece çöz',
      'earn' => 'Kazan (₺)',
      'tip' => 'Bahşiş topla (₺)',
      'streak' => 'Üst üste tam isabet',
      'day_score' => 'Günün skoru',
      'day_rep' => 'Memnuniyet %',
      'no_lose' => 'Müşteri kaçırmadan gün bitir',
      'upgrade' => 'Yükseltme al',
      'decor' => 'Dükkân süsü al',
      'npc' => 'Yardım et',
      'harvest' => 'Hasat et',
      'deliver' => 'Paket teslim et',
      'clue' => 'İpucu bul',
      'day_reach' => 'Güne ulaş',
      _ => o.type,
    };
  }
}
