import 'dart:convert';

import 'package:flutter/services.dart';

/// Tek bir hedef: tür + hedef sayı + isteğe bağlı süzgeç (filter).
/// Türler: serve, riddle, earn, tip, day_score, day_rep, streak, upgrade, decor, npc, harvest, deliver, clue, day_reach, no_lose
class ObjectiveDef {
  const ObjectiveDef({required this.type, required this.target, this.filter = const {}, this.label});
  final String type;
  final int target;
  final Map<String, dynamic> filter;
  final String? label; // gösterim metni; yoksa otomatik üretilir

  factory ObjectiveDef.fromJson(Map<String, dynamic> j) => ObjectiveDef(
        type: j['type'] as String,
        target: j['target'] as int,
        filter: (j['filter'] as Map<String, dynamic>?) ?? const {},
        label: j['label'] as String?,
      );
}

class QuestReward {
  const QuestReward({this.money = 0, this.stars = 0, this.diamonds = 0, this.flag, this.investor = false});
  final int money;
  final int stars;
  final int diamonds;
  final String? flag; // verilen bayrak (ör. 'investor')
  final bool investor;

  factory QuestReward.fromJson(Map<String, dynamic>? j) => j == null
      ? const QuestReward()
      : QuestReward(
          money: (j['money'] as int?) ?? 0,
          stars: (j['stars'] as int?) ?? 0,
          diamonds: (j['diamonds'] as int?) ?? 0,
          flag: j['flag'] as String?,
          investor: (j['investor'] as bool?) ?? false);
}

class QuestDef {
  const QuestDef({required this.id, required this.title, required this.desc, required this.objectives, required this.reward, this.scene, this.unlockChapter = 1});
  final String id;
  final String title;
  final String desc;
  final List<ObjectiveDef> objectives;
  final QuestReward reward;
  final String? scene; // tamamlanınca gösterilecek sahne
  final int unlockChapter; // yan görevler için

  factory QuestDef.fromJson(String id, Map<String, dynamic> j) => QuestDef(
        id: id,
        title: j['title'] as String,
        desc: j['desc'] as String,
        objectives: (j['objectives'] as List).map((e) => ObjectiveDef.fromJson(e as Map<String, dynamic>)).toList(),
        reward: QuestReward.fromJson(j['reward'] as Map<String, dynamic>?),
        scene: j['scene'] as String?,
        unlockChapter: (j['unlockChapter'] as int?) ?? 1,
      );
}

class ChapterDef {
  const ChapterDef({required this.id, required this.title, required this.subtitle, required this.intro, required this.outro, required this.quests, required this.reward});
  final int id;
  final String title;
  final String subtitle;
  final String intro; // sahne kimliği
  final String? outro;
  final List<String> quests; // sıralı ana görevler
  final QuestReward reward;

  factory ChapterDef.fromJson(Map<String, dynamic> j) => ChapterDef(
        id: j['id'] as int,
        title: j['title'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        intro: j['intro'] as String,
        outro: j['outro'] as String?,
        quests: (j['quests'] as List).cast<String>(),
        reward: QuestReward.fromJson(j['reward'] as Map<String, dynamic>?),
      );
}

/// Günlük görev şablonu: {n} yerine seçilen hedef konur.
class DailyTemplate {
  const DailyTemplate({required this.id, required this.title, required this.type, required this.targets, required this.money, this.filter = const {}, this.minDay = 1, this.minChapter = 1, this.scaleWithDay = false});
  final String id;
  final String title;
  final String type;
  final List<int> targets;
  final List<int> money;
  final Map<String, dynamic> filter;
  final int minDay;
  final int minChapter;
  final bool scaleWithDay;

  factory DailyTemplate.fromJson(Map<String, dynamic> j) => DailyTemplate(
        id: j['id'] as String,
        title: j['title'] as String,
        type: j['type'] as String,
        targets: (j['targets'] as List).cast<int>(),
        money: (j['money'] as List).cast<int>(),
        filter: (j['filter'] as Map<String, dynamic>?) ?? const {},
        minDay: (j['minDay'] as int?) ?? 1,
        minChapter: (j['minChapter'] as int?) ?? 1,
        scaleWithDay: (j['scaleWithDay'] as bool?) ?? false,
      );
}

class QuestData {
  QuestData({required this.chapters, required this.quests, required this.side, required this.daily});
  final List<ChapterDef> chapters;
  final Map<String, QuestDef> quests;
  final List<String> side;
  final List<DailyTemplate> daily;

  factory QuestData.fromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final qs = <String, QuestDef>{};
    (j['quests'] as Map<String, dynamic>).forEach((id, q) => qs[id] = QuestDef.fromJson(id, q as Map<String, dynamic>));
    return QuestData(
      chapters: (j['chapters'] as List).map((e) => ChapterDef.fromJson(e as Map<String, dynamic>)).toList(),
      quests: qs,
      side: ((j['side'] as List?) ?? const []).cast<String>(),
      daily: ((j['daily'] as List?) ?? const []).map((e) => DailyTemplate.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  static Future<QuestData> load([AssetBundle? bundle]) async => QuestData.fromJson(await (bundle ?? rootBundle).loadString('assets/data/quests.json'));

  ChapterDef? chapter(int id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }
}
