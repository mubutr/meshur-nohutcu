import 'dart:math';

import 'package:flutter/material.dart';

/// Pencere deliğinin sahne koordinatları (bg_t*.png içindeki şeffaf gökyüzü alanı).
const Rect kSkyRect = Rect.fromLTRB(1166, 140, 1473, 372);

/// Günün saatine (07:00–23:00) göre gökyüzü, ışık rengi ve gece oranı.
class DayLight {
  const DayLight({required this.hour, required this.skyTop, required this.skyBottom, required this.tint, required this.night, required this.sun, required this.moon, required this.stars});

  final double hour;
  final Color skyTop;
  final Color skyBottom;
  final Color tint; // sahneyi çarpan renk (modulate)
  final double night; // 0 gündüz .. 1 gece (lambalar bununla yanar)
  final double sun; // 0..1 gün ışığı şiddeti (huzme)
  final double? moon; // ayın yay üstündeki konumu 0..1, yoksa null
  final double stars;

  /// [progress]: 0 (07:00) .. 1 (23:00)
  factory DayLight.at(double progress) {
    final h = 7 + 16 * progress.clamp(0.0, 1.0);
    // anahtar saatler: (saat, üst, alt, tint, gece)
    const keys = <(double, int, int, int, double)>[
      (7.0, 0xFF8FCBF5, 0xFFFFE6B8, 0xFFFFF1DC, 0.0),
      (10.5, 0xFF5AAEF2, 0xFFCFE9FF, 0xFFFFFFFF, 0.0),
      (14.5, 0xFF4FA3F0, 0xFFBFE3FF, 0xFFFFFFFF, 0.0),
      (17.5, 0xFFF0B070, 0xFFFFD9A0, 0xFFFFE0B8, 0.15),
      (19.5, 0xFF7A4F9A, 0xFFF58B54, 0xFFFFC49A, 0.55),
      (21.0, 0xFF161C44, 0xFF35407A, 0xFF9AA6D8, 1.0),
      (23.0, 0xFF080C26, 0xFF1A2252, 0xFF8591CC, 1.0),
    ];
    var i = 0;
    while (i < keys.length - 2 && h > keys[i + 1].$1) {
      i++;
    }
    final a = keys[i], b = keys[i + 1];
    final t = ((h - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
    final s = t * t * (3 - 2 * t);
    Color c(int x, int y) => Color.lerp(Color(x), Color(y), s)!;
    final night = a.$5 + (b.$5 - a.$5) * s;
    final sunUp = h >= 7 && h <= 19.7;
    final sunStrength = sunUp ? (sin(((h - 7) / 12.7) * pi)).clamp(0.0, 1.0) : 0.0;
    final moonVisible = h >= 18.8;
    return DayLight(
      hour: h,
      skyTop: c(a.$2, b.$2),
      skyBottom: c(a.$3, b.$3),
      tint: c(a.$4, b.$4),
      night: night,
      sun: sunStrength,
      moon: moonVisible ? ((h - 18.8) / (23 - 18.8)).clamp(0.0, 1.0) : null,
      stars: ((night - 0.45) / 0.55).clamp(0.0, 1.0),
    );
  }
}

/// Pencerenin arkasındaki gökyüzü (bg katmanının ALTINA çizilir).
class SkyView extends StatelessWidget {
  const SkyView({super.key, required this.light});
  final DayLight light;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(rect: kSkyRect, child: CustomPaint(painter: _SkyPainter(light)));
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.l);
  final DayLight l;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [l.skyTop, l.skyBottom]).createShader(r));
    // yıldızlar
    if (l.stars > 0) {
      final rnd = Random(5);
      for (var i = 0; i < 34; i++) {
        final p = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.8);
        canvas.drawCircle(p, 0.8 + rnd.nextDouble() * 1.4, Paint()..color = Colors.white.withValues(alpha: l.stars * (0.5 + rnd.nextDouble() * 0.5)));
      }
    }
    // güneş yayı: sol alttan sağ alta
    if (l.sun > 0) {
      final t = ((l.hour - 7) / 12.7).clamp(0.0, 1.0);
      final p = Offset(s.width * (0.08 + 0.84 * t), s.height * (0.95 - 0.75 * sin(t * pi)));
      canvas.drawCircle(p, 42, Paint()..shader = RadialGradient(colors: [const Color(0x99FFF2B0), const Color(0x00FFF2B0)]).createShader(Rect.fromCircle(center: p, radius: 42)));
      canvas.drawCircle(p, 15, Paint()..color = const Color(0xFFFFF2B0));
    }
    // ay
    if (l.moon != null) {
      final t = l.moon!;
      final p = Offset(s.width * (0.12 + 0.76 * t), s.height * (0.78 - 0.55 * sin(t * pi)));
      canvas.drawCircle(p, 13, Paint()..color = const Color(0xFFF4F1E0));
      canvas.drawCircle(p + const Offset(5, -3), 12, Paint()..color = l.skyTop);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.l.hour != l.hour;
}

/// Sahnenin tamamına saat rengini uygular (sabah sıcak, öğle nötr, akşam turuncu, gece mavi).
class TimeTint extends StatelessWidget {
  const TimeTint({super.key, required this.light, required this.child});
  final DayLight light;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColorFiltered(colorFilter: ColorFilter.mode(light.tint, BlendMode.modulate), child: child);
}

/// Gece açılan lamba/fırın parıltısı ve gündüz pencereden giren güneş huzmesi.
class LightOverlay extends StatelessWidget {
  const LightOverlay({super.key, required this.light, this.neon = false});
  final DayLight light;
  final bool neon;

  static const lamps = [Offset(560, 118), Offset(1080, 118)];
  static const oven = Offset(330, 575);

  @override
  Widget build(BuildContext context) => Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LightPainter(light, neon))));
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.l, this.neon);
  final DayLight l;
  final bool neon;

  void _glow(Canvas c, Offset p, double r, Color col, double a) {
    if (a <= 0.01) return;
    c.drawCircle(p, r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: p, radius: r)));
  }

  @override
  void paint(Canvas canvas, Size s) {
    // gündüz: pencereden içeri uzanan güneş huzmesi
    if (l.sun > 0.05) {
      final a = 0.20 * l.sun;
      final drift = (l.hour - 13) * 26;
      final path = Path()
        ..moveTo(1180, 372)
        ..lineTo(1465, 372)
        ..lineTo(1000 + drift, 700)
        ..lineTo(560 + drift, 700)
        ..close();
      canvas.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [const Color(0xFFFFF4CC).withValues(alpha: a), const Color(0xFFFFF4CC).withValues(alpha: 0)]).createShader(const Rect.fromLTWH(560, 372, 920, 330)));
    }
    // gece: lambalar ve fırın
    final n = l.night;
    for (final p in LightOverlay.lamps) {
      _glow(canvas, p, 190, const Color(0xFFFFD98A), 0.55 * n);
    }
    _glow(canvas, LightOverlay.oven, 230, const Color(0xFFFF9A4A), 0.35 * n);
    // pencere dışı soğuk ay ışığı
    if (n > 0.5) _glow(canvas, const Offset(1320, 260), 230, const Color(0xFF9DB6FF), 0.16 * (n - 0.5) * 2);
    if (neon) _glow(canvas, const Offset(1320, 90), 170, const Color(0xFFFF4D9E), 0.35 * (0.3 + 0.7 * n));
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.l.hour != l.hour || old.neon != neon;
}

/// Üzerinden yükselen sıcak buhar (nohut tenceresi, beyran).
class SteamAnim extends StatefulWidget {
  const SteamAnim({super.key, required this.width, this.height = 110, this.animate = true, this.puffs = 5});
  final double width;
  final double height;
  final bool animate;
  final int puffs;

  @override
  State<SteamAnim> createState() => _SteamAnimState();
}

class _SteamAnimState extends State<SteamAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(SteamAnim old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: SteamPainter(_c.value, widget.puffs))),
        ),
      );
}

class SteamPainter extends CustomPainter {
  SteamPainter(this.t, this.puffs);
  final double t;
  final int puffs;

  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < puffs; i++) {
      final ph = (t + i / puffs) % 1.0;
      final x = s.width * (0.2 + 0.6 * ((i * 0.37) % 1.0)) + sin(ph * pi * 2 + i) * 9;
      final y = s.height * (1 - ph);
      final r = 12 + 26 * ph;
      final a = (sin(ph * pi)).clamp(0.0, 1.0) * 0.5;
      canvas.drawCircle(Offset(x, y), r, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }
  }

  @override
  bool shouldRepaint(SteamPainter old) => old.t != t;
}
