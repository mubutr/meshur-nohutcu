import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/dialog/antep_dialog.dart';
import 'package:nohut_durumu/game/game_controller.dart';

import 'helpers.dart';

/// Kullanıcı geri bildirimi: "kim kime ne diyor net değil" ve "gari" sorunlarının kalıcı denetimi.
void main() {
  final d = loadDialog();
  final story = loadStory();

  test('tüm replikler geçerli: rol, boş metin, yasak sözcük', () {
    expect(d.banned, isNotEmpty);
    expect(d.validate(), isEmpty);
    expect(story.validate(banned: d.banned), isEmpty);
  });

  test('"gari" hiçbir veri dosyasında ve kodda geçmez ("Garip" serbest)', () {
    final re = RegExp(r'\bgari\b', caseSensitive: false, unicode: true);
    final files = [
      ...Directory('assets').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')),
      ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    for (final f in files) {
      final text = f.readAsStringSync();
      final scan = f.path.endsWith('antep.json') ? text.replaceAll(RegExp(r'"banned":\s*\[[^\]]*\]'), '') : text;
      expect(re.hasMatch(scan), isFalse, reason: 'yasak sözcük: ${f.path}');
    }
  });

  group('kim kime', () {
    test('müşteri yalnızca ustaya konuşur, çırak (oyuncu) oyun içinde hiç konuşmaz', () {
      for (final c in d.categories) {
        for (final l in d.linesOf(c)) {
          expect(l.who, isNot('cirak'), reason: '$c: çırak konuşamaz');
          if (l.who == 'musteri') expect(l.to, 'usta', reason: '$c: müşteri ustaya konuşmalı -> ${l.text}');
          if (l.who == 'usta') expect(['musteri', 'cirak'], contains(l.to), reason: c);
        }
      }
    });

    test('usta çırağa "Rafık" demez; çırağa "evlat/çırak" der', () {
      for (final c in d.categories) {
        for (final l in d.linesOf(c).where((l) => l.who == 'usta' && l.to == 'cirak')) {
          expect(l.text.contains('Rafık'), isFalse, reason: '$c: ${l.text}');
        }
      }
      final toCirak = [for (final c in d.categories) ...d.linesOf(c).where((l) => l.who == 'usta' && l.to == 'cirak')];
      for (final l in toCirak) {
        expect(l.text.toLowerCase(), anyOf(contains('evlat'), contains('çırak')), reason: 'usta çırağa seslenmeli: ${l.text}');
      }
    });

    test('karşılama çifti: usta -> müşteri, müşteri -> usta', () {
      for (final k in ['greet_usta', 'garip_greet', 'maskeli_greet']) {
        expect(d.linesOf(k).every((l) => l.who == 'usta' && l.to == 'musteri'), isTrue, reason: k);
      }
      expect(d.linesOf('greet_reply').every((l) => l.who == 'musteri' && l.to == 'usta'), isTrue);
    });

    test('hikâye sahnelerinde usta çırağa "Rafık" demez ve her sahne dolu', () {
      story.scenes.forEach((id, lines) {
        expect(lines, isNotEmpty, reason: id);
        for (final l in lines.where((l) => l.who == 'usta' && l.to == 'cirak')) {
          expect(l.text.contains('Rafık'), isFalse, reason: '$id: ${l.text}');
        }
      });
    });

    test('kullanıcının örnek replikleri duruyor', () {
      final raw = read('assets/dialog/antep.json');
      expect(raw, contains('Hoşgeldin {hitap}'));
      expect(raw, contains('Hoşbuldum {ustaHitap}'));
      expect(raw, contains('Hele bi nohut dürümü ver de yiyek yav'));
      expect(read('assets/data/game.json'), contains('"ustaHitap": "Rafık"'));
    });
  });

  group('bileşenli sipariş cümlesi', () {
    final cfg = loadCfg();
    const sauceWords = {'sos': 'sos', 'ketcap': 'ketçap', 'mayonez': 'mayonez', 'nar': 'nar ekşisi', 'sumak': 'sumak'};
    const productWords = {'nohut': 'nohut dürümü', 'doner': 'döner dürümü', 'kavurma': 'kavurma dürümü', 'cigkofte': 'çiğ köfte dürümü', 'kizartma': 'kızartma dürümü', 'beyran': 'beyran'};
    final sauceIds = [for (final s in cfg.sauces) s.id];

    Iterable<OrderSpec> allSpecs(ProductDef p) sync* {
      final subsets = <Set<String>>[];
      for (var mask = 0; mask < 32; mask++) {
        subsets.add({for (var i = 0; i < 5; i++) if (mask & (1 << i) != 0) sauceIds[i]});
      }
      for (var n = 1; n <= p.maxAmount; n++) {
        for (final piyaz in p.allows('piyaz') ? [false, true] : [false]) {
          for (final aci in p.allows('aci') ? [false, true] : [false]) {
            for (final fried in p.allows('fried') ? [false, true] : [false]) {
              for (final set in p.allows('sauce') ? subsets : [<String>{}]) {
                yield OrderSpec(wrap: p.id, nohut: n, piyaz: piyaz, aci: aci, fried: fried, sumak: set.contains('sumak'), sauces: {...set}..remove('sumak'));
              }
            }
          }
        }
      }
    }

    test('her ürün, miktar, ek ve sos birleşimi tutarlı tek cümle verir ve spec bu cümleden geri okunabilir (farklı spec = farklı cümle)', () {
      for (final v in d.orderVariants) {
        for (final p in cfg.products) {
          final seen = <String, OrderSpec>{};
          for (final s in allSpecs(p)) {
            final t = d.orderText(s, product: p, friedOn: true, sauceIds: sauceIds, variant: v);
            expect(t.contains('{'), isFalse, reason: t);
            expect(t.toLowerCase(), contains(productWords[p.id]!.split(' ').first), reason: '$v/${p.id}: ürün adı geçmeli -> $t');
            final prev = seen[t];
            expect(prev, isNull, reason: '$v/${p.id}: iki farklı sipariş aynı cümle: $prev ve $s -> $t');
            seen[t] = s;
            // soslar: istenenler anılır; sos istenmişse istenmeyenler anılmaz
            if (p.allows('sauce') && s.allSauces.isNotEmpty) {
              for (final id in sauceIds) {
                final has = RegExp('(^|[^a-zçğıöşü])${sauceWords[id]}', caseSensitive: false, unicode: true).hasMatch(t);
                expect(has, s.allSauces.contains(id), reason: '$v/${p.id}: $id -> $t');
              }
            }
          }
        }
      }
    });

    test('kapalı ekler anılmaz: Bölüm 1 siparişinde kızartma ve sos yok', () {
      const s = OrderSpec(nohut: 2, piyaz: true, aci: false);
      for (final v in d.orderVariants) {
        final t = d.orderText(s, product: cfg.product('nohut'), friedOn: false, sauceIds: const [], variant: v).toLowerCase();
        expect(t, isNot(contains('kızartma')));
        expect(t, isNot(contains('sos')));
        expect(t, isNot(contains('sumak')));
        expect(t, contains('piyaz'));
      }
    });

    test('dilbilgisi metinlerinde yasak sözcük yok', () {
      final raw = read('assets/dialog/antep.json');
      final grammar = (jsonDecode(raw) as Map<String, dynamic>)['order'] as Map<String, dynamic>;
      final text = jsonEncode(grammar);
      for (final b in d.banned) {
        expect(RegExp('\\b$b\\b', caseSensitive: false, unicode: true).hasMatch(text), isFalse, reason: b);
      }
    });

    test('özet (usta -> çırak) ürün ve ekleri söyler', () {
      final g = makeGame();
      g.quests.chapter = 5;
      const s = OrderSpec(wrap: 'doner', nohut: 2, piyaz: true, aci: false, fried: true, sauces: {'ketcap', 'nar'}, sumak: true);
      final t = g.specSummary(s);
      expect(t, contains('döner dürümü'));
      expect(t, contains('piyazlı'));
      expect(t, contains('acısız'));
      expect(t, contains('kızartmalı'));
      expect(t, contains('ketçap'));
      expect(t, contains('nar ekşisi'));
      expect(t, contains('sumak'));
      g.dispose();
    });
  });

  test('şablon değişkenleri doldurulunca süslü parantez kalmaz', () {
    final vars = {'hitap': 'Maamed ammi', 'ad': 'Maamed ammi', 'adDat': 'Maamed ammiye', 'ustaHitap': 'usta', 'ozet': 'nohut bol, piyazlı, acısız', 'miktar': '40', 'ceza': '10'};
    for (final c in d.categories) {
      for (var i = 0; i < 8; i++) {
        final l = d.say(c, vars: vars);
        expect(l.text.contains('{'), isFalse, reason: '$c -> ${l.text}');
      }
    }
  });

  group('oyun içinde konuşma akışı', () {
    test('karşılama: usta müşteriye hitap eder; müşteri ustaya cevap verir; sipariş çırağa iletilir', () {
      final g = makeGame(4)..startDay();
      skipScenes(g);
      final seenUsta = <Speech>[];
      final seenCustomer = <Speech>[];
      for (var i = 0; i < 300; i++) {
        g.tick(0.1);
        if (g.usta != null && (seenUsta.isEmpty || seenUsta.last != g.usta)) seenUsta.add(g.usta!);
        for (final c in g.slots.whereType<Customer>()) {
          final b = c.bubble;
          if (b != null && !seenCustomer.contains(b)) seenCustomer.add(b);
        }
      }
      expect(seenUsta.first.toLabel, kCirakLabel, reason: 'gün başı konuşması çırağa');
      final greet = seenUsta.firstWhere((s) => s.toSlot != null);
      expect(greet.text, contains(RegExp('Hoşgeldin|Gel hele|Buyur|Aaa hoşgeldin')));
      expect(greet.toLabel, isNot(kCirakLabel));
      expect(seenCustomer, isNotEmpty);
      for (final s in seenCustomer) {
        expect(s.toLabel, 'USTA');
        expect(s.whoLabel, isNot('USTA'));
      }
      expect(seenUsta.any((s) => s.toLabel == kCirakLabel && s.text.contains('nohut')), isTrue, reason: 'sipariş çırağa iletilmeli');
      g.dispose();
    });

    test('aynı anda iki müşteri aynı adı taşımaz', () {
      final g = makeGame(9)..startDay();
      skipScenes(g);
      for (var i = 0; i < 1200; i++) {
        g.tick(0.1);
        final names = g.slots.whereType<Customer>().map((c) => c.name.n).toList();
        expect(names.toSet().length, names.length, reason: '$names');
      }
      g.dispose();
    });

    test('hitaplar: yaşlı erkek ammi, kadın bacı, genç erkek Rafık; 10 kadın + 10 erkek, her biri tek ve benzersiz ad', () {
      final cfg = loadCfg();
      expect(cfg.customers.where((t) => t.gender == 'kadin'), hasLength(10));
      expect(cfg.customers.where((t) => t.gender == 'erkek'), hasLength(10));
      final names = <String>{};
      for (final t in cfg.customers) {
        expect(t.names, hasLength(1), reason: t.id);
        final n = t.names.single;
        expect(names.add(n.n), isTrue, reason: 'ad tekrarı: ${n.n}');
        if (t.gender == 'kadin') {
          expect(n.ref, endsWith('bacı'));
          expect(n.dat, endsWith('bacıya'));
        } else if (t.age == 'yasli') {
          expect(n.ref, endsWith('ammi'));
          expect(n.dat, endsWith('ammiye'));
        } else {
          expect(n.hitap, 'Rafık');
        }
      }
      // kullanıcının verdiği listeden
      const women = {'Fatma', 'Emine', 'Hattuç', 'Hayce', 'Zennup', 'Ayyuş', 'Şehriban', 'Yumma', 'Şakire', 'Lütfiye'};
      const men = {'Maamed', 'Mustafa', 'Ahmet', 'Ali', 'Hüseyin', 'Ökkeş', 'Mehmet Ali', 'Höggeş', 'Memik', 'Cımaali'};
      expect(cfg.customers.where((t) => t.gender == 'kadin').map((t) => t.names.single.n).toSet(), women);
      expect(cfg.customers.where((t) => t.gender == 'erkek').map((t) => t.names.single.n).toSet(), men);
    });

    test('eski adlar ve "emmi" hiçbir veri/kod/test dosyasında görünen metin olarak kalmadı', () {
      final old = RegExp(r'Muslu|Hanifi|Bozan|Penbe|Güldene|Beşire|\bDuran\b|\bApo\b|Durdu|\bemmi|Garip Dayı|Bilmece Nine|İtfaiyeci Temel|Antikacı Nuri|GARİP DAYI|BİLMECE NİNE|İTFAİYECİ TEMEL|ANTİKACI NURİ');
      final files = [
        ...Directory('assets').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')),
        ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
        File('README.md'),
      ];
      for (final f in files) {
        final m = old.firstMatch(f.readAsStringSync());
        expect(m, isNull, reason: '${f.path}: ${m?.group(0)}');
      }
    });

    test('hikâye karakterlerinin yeni adları', () {
      expect(kRoleLabels['dayi'], 'GARİBAN');
      expect(kRoleLabels['nine'], 'TAAF NENE');
      expect(kRoleLabels['antikaci'], 'GALAYCI NURU');
      expect(kRoleLabels['itfaiyeci'], 'İTFAİYECİ MÖMET');
      final raw = read('assets/data/game.json');
      expect(raw, contains('"Gariban"'));
      expect(raw, contains('Taaf Nene'));
      expect(raw, contains('İtfaiyeci Mömet'));
      expect(raw, contains('Maskeli Müşteri'));
    });
  });

  group('hayırlı işler / bereket versin', () {
    test('müşteri hiçbir satırda "bereket" demez; ayrılış satırlarının hepsi "hayırlı işler" içerir', () {
      for (final c in d.categories) {
        for (final l in d.linesOf(c).where((l) => l.who == 'musteri')) {
          expect(l.text.toLowerCase().contains('bereket'), isFalse, reason: '$c: ${l.text}');
        }
      }
      const farewells = ['react_great', 'react_great_tip', 'react_ok', 'react_bad', 'leave', 'garip_thanks', 'garip_leave', 'maskeli_great', 'maskeli_steal', 'bonus_thanks', 'kurye_thanks', 'kurye_leave', 'react_riddle_great', 'react_riddle_bad'];
      for (final c in farewells) {
        expect(d.has(c), isTrue, reason: c);
        for (final l in d.linesOf(c)) {
          expect(l.who, 'musteri', reason: c);
          expect(l.text.toLowerCase(), contains('hayırlı işler'), reason: '$c: ${l.text}');
        }
      }
    });

    test('hikâye karakterleri de (usta hariç) "bereket" demez', () {
      story.scenes.forEach((id, lines) {
        for (final l in lines.where((l) => l.who != 'usta' && l.who != 'anlatici')) {
          expect(l.text.toLowerCase().contains('bereket'), isFalse, reason: '$id/${l.who}: ${l.text}');
        }
      });
    });

    test('usta müşteriye "bereket versin" der', () {
      for (final c in ['usta_bereket', 'usta_bereket_garip']) {
        expect(d.has(c), isTrue);
        for (final l in d.linesOf(c)) {
          expect(l.who, 'usta');
          expect(l.to, 'musteri');
          expect(l.text.toLowerCase(), contains('bereket versin'));
        }
      }
    });

    test('serviste: müşteri "hayırlı işler" der, ardından usta aynı müşteriye "bereket versin" der', () {
      final g = makeGame(4)..startDay();
      skipScenes(g);
      final idx = waitForCustomer(g);
      expect(idx, isNonNegative);
      for (var i = 0; i < 40; i++) {
        g.tick(0.1); // karşılama konuşmaları bitsin
      }
      g.money = 1000;
      makeAndServe(g, idx);
      final c = g.slots[idx]!;
      expect(c.bubble!.text.toLowerCase(), contains('hayırlı işler'));
      expect(c.bubble!.whoLabel, c.label);
      final seen = <Speech>[];
      for (var i = 0; i < 200; i++) {
        if (g.usta != null && (seen.isEmpty || seen.last != g.usta)) seen.add(g.usta!);
        g.tick(0.1);
      }
      final bereket = seen.where((s) => s.text.toLowerCase().contains('bereket versin')).toList();
      expect(bereket, isNotEmpty, reason: 'usta bereket versin demeli');
      expect(bereket.first.toLabel, c.label);
      expect(bereket.first.whoLabel, 'USTA');
      g.dispose();
    });
  });
}
