import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/sfx.dart';
import 'data/models.dart';
import 'dialog/antep_dialog.dart';
import 'game/game_controller.dart';
import 'leaderboard/leaderboard.dart';
import 'modes/detective.dart';
import 'quest/quest_models.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final cfg = await GameConfig.load();
  final dialog = await AntepDialog.load();
  final story = await StoryBook.load();
  final questData = await QuestData.load();
  final riddles = await Riddle.load();
  final detective = await DetectiveData.load();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    prefs = null; // kayıt çalışmazsa oyun yine açılır
  }
  // Sunucu adresi derleme sırasında verilir: --dart-define=LEADERBOARD_URL=https://... --dart-define=LEADERBOARD_SECRET=...
  // Verilmezse yalnızca yerel sıralama çalışır.
  const lbUrl = String.fromEnvironment('LEADERBOARD_URL');
  const lbSecret = String.fromEnvironment('LEADERBOARD_SECRET');
  final board = LeaderboardManager(prefs: prefs, remote: lbUrl.isEmpty ? null : RemoteLeaderboard(baseUrl: lbUrl, secret: lbSecret));
  final game = GameController(cfg: cfg, dialog: dialog, questData: questData, story: story, riddles: riddles, detectiveData: detective, prefs: prefs, leaderboard: board, sfx: AudioSfx(), introEnabled: true)..load();
  runApp(NohutApp(game: game));
}

class NohutApp extends StatelessWidget {
  const NohutApp({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İyi Nohut Dürümü, Güzel Nohut Dürümü',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF9A5B1E)),
      home: Scaffold(body: GameScreen(game: game)),
    );
  }
}
