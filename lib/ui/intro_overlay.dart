import 'package:flutter/material.dart';

import '../game/game_controller.dart';

/// Her yeni günün başı: kepenk yukarı kalkar, ekranda "Ya Fettah, Ya Rezzak" yazar (ses: assets/sfx/yafettah.mp3 + kepenk.wav).
/// Dokununca atlanır. [animate] false ise (testler/ekran görüntüsü) kepenk yarı açık sabit kare çizilir.
class IntroOverlay extends StatelessWidget {
  const IntroOverlay({super.key, required this.game, this.animate = true, this.staticProgress = 0.45, this.extra = 0});
  final GameController game;
  final double extra; // telefonda sahne kutusunun iki yanındaki ek genişlik: kepenk bunu da kaplar
  final bool animate;
  final double staticProgress;

  static const String kText = 'Ya Fettah, Ya Rezzak';

  /// 0..1 ilerlemeden kepenk yüksekliği oranı (0 kapalı, 1 tamamen yukarıda).
  static double lift(double t) => Curves.easeInOutCubic.transform(((t - 0.06) / 0.66).clamp(0.0, 1.0));

  /// Yazının görünürlüğü: belirir, durur, söner.
  static double textOpacity(double t) {
    if (t < 0.12) return 0;
    if (t < 0.3) return (t - 0.12) / 0.18;
    if (t < 0.78) return 1;
    if (t < 0.97) return (0.97 - t) / 0.19;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final secs = game.cfg.eco('introSeconds');
    Widget body(double t) => _Frame(t: t, onTap: game.skipIntro);
    return Positioned(
      left: -extra,
      right: -extra,
      top: 0,
      bottom: 0,
      child: animate
          ? TweenAnimationBuilder<double>(
              key: ValueKey('intro-${game.day}-${game.phase.name}'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: (secs * 1000).round()),
              builder: (context, t, _) => body(t),
            )
          : body(staticProgress),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.t, required this.onTap});
  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const slats = 18;
    const h = 900.0;
    final slatH = h / slats;
    final up = IntroOverlay.lift(t) * (h + 40);
    return GestureDetector(
      key: const ValueKey('intro'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRect(
        child: Stack(children: [
          // kepenk: üst üste metal şeritler; altına bir tutamaklı alt çıta
          Positioned(
            left: 0,
            right: 0,
            top: -up,
            height: h + 36,
            child: Column(children: [
              for (var i = 0; i < slats; i++) _Slat(height: slatH, dark: i.isEven),
              const _BottomBar(),
            ]),
          ),
          // yazı
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: IntroOverlay.textOpacity(t),
                child: const Center(
                  child: Text(
                    IntroOverlay.kText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD27A),
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 4)), Shadow(color: Colors.black87, blurRadius: 40)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Slat extends StatelessWidget {
  const _Slat({required this.height, required this.dark});
  final double height;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF8D959C), Color(0xFF6F777E)] : const [Color(0xFF9AA2A9), Color(0xFF7B838A)],
          ),
          border: const Border(bottom: BorderSide(color: Color(0xFF4A5056), width: 2)),
        ),
        child: Align(alignment: Alignment.topCenter, child: Container(height: 3, color: const Color(0x55FFFFFF))),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();
  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF50575D), Color(0xFF2C3136)]),
          boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Center(child: Container(width: 90, height: 12, decoration: BoxDecoration(color: const Color(0xFF1E2226), borderRadius: BorderRadius.circular(6)))),
      );
}
