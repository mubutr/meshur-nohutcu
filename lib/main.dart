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
import 'ui/splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

/// Önce "bigsoft games sunar" yükleme ekranı; veriler ve görseller yüklenince oyun açılır (en az ~2.6 sn gösterilir).
class BootApp extends StatefulWidget {
  const BootApp({super.key});
  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  GameController? _game;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _step(double p) {
    if (mounted) setState(() => _progress = p);
  }

  Future<void> _boot() async {
    final minimum = Future<void>.delayed(const Duration(milliseconds: 2600));
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final cfg = await GameConfig.load();
    _step(0.12);
    final dialog = await AntepDialog.load();
    final story = await StoryBook.load();
    _step(0.24);
    final questData = await QuestData.load();
    final riddles = await Riddle.load();
    final detective = await DetectiveData.load();
    _step(0.36);
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null; // kayıt çalışmazsa oyun yine açılır
    }
    _step(0.45);
    // Sunucu adresi derleme sırasında verilir: --dart-define=LEADERBOARD_URL=https://... --dart-define=LEADERBOARD_SECRET=...
    // Verilmezse yalnızca yerel sıralama çalışır.
    const lbUrl = String.fromEnvironment('LEADERBOARD_URL');
    const lbSecret = String.fromEnvironment('LEADERBOARD_SECRET');
    final board = LeaderboardManager(prefs: prefs, remote: lbUrl.isEmpty ? null : RemoteLeaderboard(baseUrl: lbUrl, secret: lbSecret));
    final game = GameController(
      cfg: cfg,
      dialog: dialog,
      questData: questData,
      story: story,
      riddles: riddles,
      detectiveData: detective,
      prefs: prefs,
      leaderboard: board,
      sfx: AudioSfx(),
      introEnabled: true,
      tutorialEnabled: true,
      gameOverEnabled: true,
    )..load();
    board.attach(game);
    _step(0.55);
    // sık kullanılan görselleri önceden çöz: ilk karelerde takılma olmasın
    if (mounted) {
      final names = <String>[
        'bg_${game.theme}', 'tezgah_${game.theme}', 'usta_normal', 'ekmek', 'ekmek_yigin', 'nohut_tencere', 'piyaz_kase', 'aci_kase',
        for (final t in cfg.customers.take(6)) '${t.id}_normal',
      ];
      for (var i = 0; i < names.length; i++) {
        try {
          await precacheImage(AssetImage('assets/sprites/${names[i]}.png'), context);
        } catch (_) {}
        _step(0.55 + 0.4 * (i + 1) / names.length);
      }
    }
    await minimum;
    _step(1);
    if (mounted) setState(() => _game = game);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return MaterialApp(
      title: 'Meşhur Nohutçu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF9A5B1E)),
      home: game == null ? Scaffold(body: BigsoftSplash(progress: _progress)) : Scaffold(body: GameScreen(game: game)),
    );
  }
}
