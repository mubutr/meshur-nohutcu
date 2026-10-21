import 'package:flutter/material.dart';

/// Açılışta gösterilen "bigsoft games sunar" yükleme ekranı.
class BigsoftSplash extends StatelessWidget {
  const BigsoftSplash({super.key, required this.progress});

  /// 0..1 yükleme ilerlemesi
  final double progress;

  static const Color kOrange = Color(0xFFEA8512);
  static const Color kGray = Color(0xFF4A4A4A);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/brand/bigsoft.png', width: 460, key: const ValueKey('bigsoft-logo')),
            const SizedBox(height: 10),
            const Text('games sunar', key: ValueKey('bigsoft-sunar'), style: TextStyle(color: kGray, fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: 6)),
            const SizedBox(height: 46),
            SizedBox(
              width: 340,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFFE6E6E6), color: kOrange),
              ),
            ),
            const SizedBox(height: 14),
            Text('Yükleniyor… %${(progress.clamp(0.0, 1.0) * 100).round()}', style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}
