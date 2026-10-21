import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../data/models.dart';

/// Tek bir replik: kim kime ne diyor.
class DialogLine {
  const DialogLine({required this.who, required this.to, required this.text});
  final String who; // usta | musteri | cirak | (özel karakter kimliği)
  final String to; // usta | musteri | cirak
  final String text;
}

const Set<String> kRoles = {'usta', 'musteri', 'cirak'};

/// Antep ağzı replik motoru. Replikler assets/dialog/antep.json içinde kategori -> [{who,to,t}] olarak durur.
class AntepDialog {
  AntepDialog(this._lines, {this.banned = const [], this.grammar = const {}, Random? random}) : _rnd = random ?? Random();

  final Map<String, List<DialogLine>> _lines;
  final List<String> banned;

  /// Bileşenli sipariş dilbilgisi: varyant (A/B/C) -> {open, amount, piyaz, aci, fried, sauceYes, sauceNo, sauceNames}.
  final Map<String, dynamic> grammar;
  final Random _rnd;
  final Map<String, String> _last = {};

  static Future<AntepDialog> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/dialog/antep.json');
    return AntepDialog.fromJson(raw);
  }

  factory AntepDialog.fromJson(String raw, {Random? random}) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final lines = <String, List<DialogLine>>{};
    (map['lines'] as Map<String, dynamic>).forEach((cat, list) {
      lines[cat] = (list as List)
          .map((e) => DialogLine(who: e['who'] as String, to: e['to'] as String, text: e['t'] as String))
          .toList();
    });
    return AntepDialog(
      lines,
      banned: ((map['banned'] as List?) ?? const []).cast<String>(),
      grammar: ((map['order'] as Map<String, dynamic>?) ?? const {}),
      random: random,
    );
  }

  Iterable<String> get orderVariants => grammar.keys;

  /// Siparişi tek bir tonda (varyant) kurulmuş tam cümle olarak söyletir.
  /// [friedOn]: kızartma eki açık mı; [sauceIds]: açık soslar (sumak dahil); [product]: ürünün izin verdiği eklentiler.
  DialogLine composeOrder(OrderSpec s, {required ProductDef product, required bool friedOn, required List<String> sauceIds, String? variant}) {
    final v = variant ?? grammar.keys.elementAt(_rnd.nextInt(grammar.length));
    return DialogLine(who: 'musteri', to: 'usta', text: orderText(s, product: product, friedOn: friedOn, sauceIds: sauceIds, variant: v));
  }

  String orderText(OrderSpec s, {required ProductDef product, required bool friedOn, required List<String> sauceIds, required String variant}) {
    final g = grammar[variant] as Map<String, dynamic>;
    String pick(dynamic m, Object key) => (m as Map<String, dynamic>)['$key'] as String;
    final parts = <String>[
      pick(g['open'], s.wrap),
      pick((g['amount'] as Map<String, dynamic>)[s.wrap], s.nohut),
    ];
    if (product.allows('piyaz')) parts.add(pick(g['piyaz'], s.piyaz ? 'yes' : 'no'));
    if (product.allows('aci')) parts.add(pick(g['aci'], s.aci ? 'yes' : 'no'));
    if (friedOn && product.allows('fried')) parts.add(pick(g['fried'], s.fried ? 'yes' : 'no'));
    if (sauceIds.isNotEmpty && product.allows('sauce')) {
      final names = g['sauceNames'] as Map<String, dynamic>;
      final wanted = [for (final id in sauceIds) if (s.allSauces.contains(id)) names[id] as String];
      parts.add(wanted.isEmpty ? g['sauceNo'] as String : (g['sauceYes'] as String).replaceAll('{liste}', _joinTr(wanted)));
    }
    return parts.join(' ');
  }

  /// "a", "a ve b", "a, b ve c"
  static String _joinTr(List<String> items) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} ve ${items.last}';
  }

  /// Başka bir dosyadaki replikleri (ör. bölüm hikâyeleri) bu motora ekler.
  void merge(Map<String, List<DialogLine>> more) => more.forEach((k, v) => _lines.putIfAbsent(k, () => []).addAll(v));

  Iterable<String> get categories => _lines.keys;
  List<DialogLine> linesOf(String category) => _lines[category] ?? const [];
  bool has(String category) => linesOf(category).isNotEmpty;

  /// Aynı kategoriden art arda aynı repliği seçmemeye çalışır.
  DialogLine say(String category, {Map<String, String> vars = const {}}) {
    final list = _lines[category];
    if (list == null || list.isEmpty) return const DialogLine(who: 'usta', to: 'cirak', text: '');
    var pick = list[_rnd.nextInt(list.length)];
    if (list.length > 1 && pick.text == _last[category]) {
      pick = list[(list.indexOf(pick) + 1) % list.length];
    }
    _last[category] = pick.text;
    return DialogLine(who: pick.who, to: pick.to, text: fill(pick.text, vars));
  }

  /// Yalnızca metin gerekiyorsa.
  String text(String category, {Map<String, String> vars = const {}}) => say(category, vars: vars).text;

  static String fill(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  /// Veri kalitesi denetimi: boş metin, yasak sözcük, tanımsız rol.
  List<String> validate({Set<String> extraRoles = const {}}) {
    final roles = {...kRoles, ...extraRoles};
    final errors = <String>[];
    _lines.forEach((cat, list) {
      for (final l in list) {
        if (l.text.trim().isEmpty) errors.add('$cat: boş metin');
        if (!roles.contains(l.who)) errors.add('$cat: tanımsız konuşan "${l.who}"');
        if (!roles.contains(l.to)) errors.add('$cat: tanımsız muhatap "${l.to}"');
        if (l.who == l.to) errors.add('$cat: konuşan ve muhatap aynı (${l.who})');
        for (final b in banned) {
          if (RegExp('\\b${RegExp.escape(b)}\\b', caseSensitive: false, unicode: true).hasMatch(l.text)) {
            errors.add('$cat: yasak sözcük "$b" -> ${l.text}');
          }
        }
      }
    });
    return errors;
  }
}

/// Hikâye sahnelerinde konuşabilen roller (portre kimliği = sprite öneki).
const Set<String> kStoryRoles = {'usta', 'cirak', 'rakip', 'nine', 'dayi', 'yatirimci', 'maskeli', 'itfaiyeci', 'antikaci', 'anlatici', 'musteri'};

/// Ekranda gösterilen rol adı (konuşan etiketi).
const Map<String, String> kRoleLabels = {
  'usta': 'USTA',
  'cirak': 'ÇIRAK (SEN)',
  'rakip': 'KALAYCI',
  'nine': 'TAAF NENE',
  'dayi': 'GARİBAN',
  'yatirimci': 'GARİBAN',
  'maskeli': 'MASKELİ MÜŞTERİ',
  'itfaiyeci': 'İTFAİYECİ MÖMET',
  'antikaci': 'GALAYCI NURU',
  'anlatici': 'ANLATICI',
  'musteri': 'MÜŞTERİ',
};

/// Bölüm hikâyeleri: sahne kimliği -> replik listesi.
class StoryBook {
  StoryBook(this.scenes);
  final Map<String, List<DialogLine>> scenes;

  static Future<StoryBook> load([AssetBundle? bundle]) async =>
      StoryBook.fromJson(await (bundle ?? rootBundle).loadString('assets/dialog/story.json'));

  factory StoryBook.fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, List<DialogLine>>{};
    (map['scenes'] as Map<String, dynamic>).forEach((id, list) {
      out[id] = (list as List).map((e) => DialogLine(who: e['who'] as String, to: e['to'] as String, text: e['t'] as String)).toList();
    });
    return StoryBook(out);
  }

  List<DialogLine> scene(String id) => scenes[id] ?? const [];

  /// [banned]: yasak sözcükler (antep.json içindeki "banned" listesi).
  List<String> validate({List<String> banned = const []}) {
    final errors = <String>[];
    scenes.forEach((id, lines) {
      if (lines.isEmpty) errors.add('$id: boş sahne');
      for (final l in lines) {
        if (!kStoryRoles.contains(l.who)) errors.add('$id: tanımsız konuşan ${l.who}');
        if (!kStoryRoles.contains(l.to)) errors.add('$id: tanımsız muhatap ${l.to}');
        if (l.who == l.to) errors.add('$id: konuşan = muhatap');
        for (final b in banned) {
          if (RegExp('\\b$b\\b', caseSensitive: false, unicode: true).hasMatch(l.text)) errors.add('$id: yasak sözcük $b');
        }
      }
    });
    return errors;
  }
}

/// Türkçe büyük harfe çevirme (i -> İ, ı -> I).
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
