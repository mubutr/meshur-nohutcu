import 'dart:io';
import 'dart:math';

import 'package:nohut_durumu/data/models.dart';
import 'package:nohut_durumu/dialog/antep_dialog.dart';
import 'package:nohut_durumu/game/game_controller.dart';
import 'package:nohut_durumu/modes/detective.dart';
import 'package:nohut_durumu/quest/quest_models.dart';

String read(String path) => File(path).readAsStringSync();

GameConfig loadCfg() => GameConfig.fromJson(read('assets/data/game.json'));
AntepDialog loadDialog([int seed = 1]) => AntepDialog.fromJson(read('assets/dialog/antep.json'), random: Random(seed));
StoryBook loadStory() => StoryBook.fromJson(read('assets/dialog/story.json'));
QuestData loadQuests() => QuestData.fromJson(read('assets/data/quests.json'));
List<Riddle> loadRiddles() => Riddle.parse(read('assets/data/riddles.json'));
DetectiveData loadDetective() => DetectiveData.fromJson(read('assets/data/detective.json'));

GameController makeGame([int seed = 3]) => GameController(
      cfg: loadCfg(),
      dialog: loadDialog(seed),
      questData: loadQuests(),
      story: loadStory(),
      riddles: loadRiddles(),
      detectiveData: loadDetective(),
      random: Random(seed),
    );

/// Bekleyen tüm hikâye sahnelerini geç.
void skipScenes(GameController g) {
  var guard = 0;
  while (g.sceneLines != null && guard++ < 200) {
    g.advanceScene();
  }
}

/// Dürümü siparişe göre doğru hazırlayıp verir.
void makeAndServe(GameController g, int slot) {
  final spec = g.slots[slot]!.spec;
  prepare(g, spec);
  g.serve(slot);
}

/// Siparişe tam uyan dürümü tezgâhta hazırlar ve sarar (servis etmez). Tekrar çağrılabilir:
/// otomasyonun yarım bıraktığı dürümü tamamlar.
void prepare(GameController g, OrderSpec spec) {
  g.selectWrap(spec.wrap);
  g.tapBread();
  while (g.assembly.nohut < spec.nohut) {
    final before = g.assembly.nohut;
    g.tapMain();
    if (g.assembly.nohut == before) break; // para yok ya da üst sınır
  }
  if (spec.piyaz) g.tapPiyaz();
  if (spec.aci) g.tapAci();
  if (spec.fried) g.tapFried();
  for (final id in spec.sauces) {
    g.tapSauce(id);
  }
  if (spec.sumak) g.tapSumak();
  g.wrap();
}

/// İlk bekleyen müşteri çıkana kadar ilerlet.
int waitForCustomer(GameController g, {int maxTicks = 400}) {
  for (var i = 0; i < maxTicks; i++) {
    g.tick(0.1);
    final idx = g.slots.indexWhere((c) => c?.state == CustomerState.waiting);
    if (idx >= 0) return idx;
  }
  return -1;
}
