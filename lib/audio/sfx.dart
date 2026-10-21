import 'package:audioplayers/audioplayers.dart';

/// Ses efekti çıkışı; testlerde ve ses kapalıyken kullanılmaz.
abstract class Sfx {
  void play(String name);
}

/// `assets/sfx/ad.wav` dosyalarını çalar. Her efekte ayrı oynatıcı ayrılır (hızlı art arda tıklamada kesilmesin).
class AudioSfx implements Sfx {
  AudioSfx({this.volume = 0.7});
  final double volume;
  final Map<String, AudioPlayer> _players = {};
  final Set<String> _failed = {}; // çalınamayan dosyalar bir daha denenmez (oyun sessiz devam eder)

  @override
  void play(String name) {
    if (_failed.contains(name)) return;
    _run(name);
  }

  Future<void> _run(String name) async {
    try {
      final p = _players.putIfAbsent(name, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      // 'kepenk.wav' / 'yafettah.mp3' gibi uzantılı ad verilirse olduğu gibi, yoksa .wav varsayılır
      final file = name.contains('.') ? name : '$name.wav';
      await p.play(AssetSource('sfx/$file'), volume: volume, mode: name.endsWith('.mp3') ? PlayerMode.mediaPlayer : PlayerMode.lowLatency);
    } catch (_) {
      _failed.add(name);
    }
  }
}
