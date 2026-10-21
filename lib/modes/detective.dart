import 'dart:convert';

import 'package:flutter/services.dart';

import '../dialog/antep_dialog.dart';

class ClueDef {
  const ClueDef(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}

class InspectStep {
  const InspectStep(this.clue);
  final String clue;
}

class LocationDef {
  const LocationDef({required this.id, required this.name, required this.desc, required this.steps});
  final String id;
  final String name;
  final String desc;
  final List<InspectStep> steps;
}

class SuspectDef {
  const SuspectDef({required this.id, required this.name, required this.title, required this.intro});
  final String id;
  final String name;
  final String title;
  final String intro;
}

class QuestionDef {
  const QuestionDef({required this.id, required this.q, required this.answers, this.clue, this.requires = const []});
  final String id;
  final String q;
  final List<DialogLine> answers;
  final String? clue;
  final List<String> requires;
}

/// Bölüm 5 soruşturma verisi (assets/data/detective.json).
class DetectiveData {
  DetectiveData({
    required this.culprit,
    required this.needs,
    required this.actionsPerNight,
    required this.wrongPenalty,
    required this.clues,
    required this.locations,
    required this.suspects,
    required this.talk,
  });

  final String culprit;
  final List<String> needs;
  final int actionsPerNight;
  final int wrongPenalty;
  final Map<String, ClueDef> clues;
  final List<LocationDef> locations;
  final List<SuspectDef> suspects;
  final Map<String, List<QuestionDef>> talk;

  static Future<DetectiveData> load([AssetBundle? bundle]) async => DetectiveData.fromJson(await (bundle ?? rootBundle).loadString('assets/data/detective.json'));

  factory DetectiveData.fromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final clues = <String, ClueDef>{};
    (j['clues'] as Map<String, dynamic>).forEach((id, c) => clues[id] = ClueDef(id, c['title'] as String, c['text'] as String));
    final talk = <String, List<QuestionDef>>{};
    (j['talk'] as Map<String, dynamic>).forEach((sid, list) {
      talk[sid] = (list as List).map((e) {
        final m = e as Map<String, dynamic>;
        return QuestionDef(
          id: m['id'] as String,
          q: m['q'] as String,
          answers: (m['a'] as List).map((l) => DialogLine(who: l['who'] as String, to: l['to'] as String, text: l['t'] as String)).toList(),
          clue: m['clue'] as String?,
          requires: ((m['requires'] as List?) ?? const []).cast<String>(),
        );
      }).toList();
    });
    return DetectiveData(
      culprit: j['culprit'] as String,
      needs: (j['needs'] as List).cast<String>(),
      actionsPerNight: j['actionsPerNight'] as int,
      wrongPenalty: j['wrongPenalty'] as int,
      clues: clues,
      locations: (j['locations'] as List)
          .map((e) => LocationDef(
                id: e['id'] as String,
                name: e['name'] as String,
                desc: e['desc'] as String,
                steps: (e['inspect'] as List).map((s) => InspectStep(s['clue'] as String)).toList(),
              ))
          .toList(),
      suspects: (j['suspects'] as List)
          .map((e) => SuspectDef(id: e['id'] as String, name: e['name'] as String, title: e['title'] as String, intro: e['intro'] as String))
          .toList(),
      talk: talk,
    );
  }
}

/// Oyuncunun soruşturma ilerlemesi.
class CaseState {
  CaseState(this.data);
  final DetectiveData data;
  final Set<String> clues = {};
  final Map<String, int> inspected = {}; // mekân -> kaç adım yapıldı
  final Set<String> asked = {};
  int actionsLeft = 0;
  bool solved = false;
  int wrong = 0;

  void newNight() => actionsLeft = data.actionsPerNight;

  bool hasAll(List<String> ids) => ids.every(clues.contains);

  bool get hasEvidence => hasAll(data.needs);

  /// Mekânda sıradaki adım (yoksa null).
  InspectStep? nextStep(LocationDef l) {
    final n = inspected[l.id] ?? 0;
    return n < l.steps.length ? l.steps[n] : null;
  }

  bool canAsk(QuestionDef q, String suspectId) => !asked.contains('$suspectId/${q.id}') && hasAll(q.requires);

  String toJsonString() => jsonEncode({'clues': clues.toList(), 'inspected': inspected, 'asked': asked.toList(), 'left': actionsLeft, 'solved': solved, 'wrong': wrong});

  void fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    clues
      ..clear()
      ..addAll(((j['clues'] as List?) ?? const []).cast<String>());
    inspected
      ..clear()
      ..addAll(((j['inspected'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as int)));
    asked
      ..clear()
      ..addAll(((j['asked'] as List?) ?? const []).cast<String>());
    actionsLeft = (j['left'] as int?) ?? 0;
    solved = (j['solved'] as bool?) ?? false;
    wrong = (j['wrong'] as int?) ?? 0;
  }

  void reset() {
    clues.clear();
    inspected.clear();
    asked.clear();
    actionsLeft = 0;
    solved = false;
    wrong = 0;
  }
}
