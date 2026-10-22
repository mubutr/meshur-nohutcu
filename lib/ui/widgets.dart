import 'package:flutter/material.dart';

import '../data/models.dart';
import '../dialog/antep_dialog.dart' show trUpper;
import '../game/game_controller.dart';

const kWood = Color(0xFF5B3419);
const kWoodDark = Color(0xFF3A200E);
const kCream = Color(0xFFFFF7E2);

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.tail = Alignment.bottomCenter, this.size = 17, this.footer, this.color = Colors.white, this.who, this.to, this.compact = false});
  final String text;
  final Alignment tail;
  final double size;
  final Widget? footer;
  final Color color;
  final String? who; // konuşan
  final String? to; // muhatap
  final bool compact; // true: konuşma metni gizlenir, yalnızca altbilgi (sipariş çipleri) görünür

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kWoodDark, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (who != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(who!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E), letterSpacing: 1.0)),
                if (to != null) ...[
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.arrow_right_alt, size: 17, color: Color(0xFF9A5B1E))),
                  Flexible(child: Text(to!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B), letterSpacing: 1.0))),
                ],
              ]),
            ),
          if (!compact || footer == null) Text(text, style: TextStyle(fontSize: size, height: 1.22, color: kWoodDark, fontWeight: FontWeight.w600)),
          if (footer != null) ...[SizedBox(height: compact ? 0 : 6), footer!],
        ]),
      ),
      CustomPaint(size: const Size(26, 14), painter: _TailPainter(color)),
    ]);
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width / 2, s.height)..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = kWoodDark);
    canvas.drawLine(const Offset(2.5, 0), Offset(s.width - 2.5, 0), Paint()..color = color..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// Müşterinin ayağında duran ad etiketi; ustanın hitabı bu etikete bağlanır.
class NameTag extends StatelessWidget {
  const NameTag({super.key, required this.text, this.highlighted = false});
  final String text;
  final bool highlighted;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFD27A) : const Color(0xCC2A1A0C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlighted ? Colors.white : const Color(0xFFD9A25F), width: 2),
        ),
        child: Text(text, style: TextStyle(color: highlighted ? kWoodDark : kCream, fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

/// Oyuncunun rolünü gösteren küçük etiket.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF2E7D5B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
      );
}

Widget _chip(String t, {bool on = true, Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 6, top: 2),
      decoration: BoxDecoration(color: color ?? (on ? const Color(0xFFD9F2D2) : const Color(0xFFF5D6D2)), borderRadius: BorderRadius.circular(10)),
      child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kWoodDark)),
    );

class OrderIcons extends StatelessWidget {
  const OrderIcons({super.key, required this.spec, required this.game});
  final OrderSpec spec;
  final GameController game;

  static String cap(String t) => t.isEmpty ? t : trUpper(t[0]) + t.substring(1);

  @override
  Widget build(BuildContext context) {
    // Yalnızca düz Türkçe sözcükler: yazı tipinde bulunmayan simgelere bağımlı olmasın.
    final p = game.cfg.product(spec.wrap);
    final amount = spec.nohut <= 1 ? 'az' : (spec.nohut == 2 && p.maxAmount > 2 ? 'orta' : 'bol');
    return Wrap(children: [
      _chip(p.name, color: const Color(0xFFFFE9A8)),
      if (p.maxAmount > 1) _chip('${cap(p.fillName)}: $amount'),
      if (p.allows('piyaz')) _chip(spec.piyaz ? 'Piyaz: var' : 'Piyaz: yok', on: spec.piyaz),
      if (p.allows('aci')) _chip(spec.aci ? 'Acı: var' : 'Acı: yok', on: spec.aci),
      if (game.friedUnlocked && p.allows('fried')) _chip(spec.fried ? 'Kızartma: var' : 'Kızartma: yok', on: spec.fried),
      if (game.sauces.isNotEmpty && p.allows('sauce'))
        if (spec.allSauces.isEmpty)
          _chip('Sos: yok', on: false)
        else
          for (final sc in game.sauces.where((x) => spec.allSauces.contains(x.id))) _chip(sc.name, color: const Color(0xFFD6ECFA)),
    ]);
  }
}

/// Özel müşteri rozeti: bilmece, ikram, dikkat…
class SpecialBadge extends StatelessWidget {
  const SpecialBadge(this.text, {super.key, this.color = const Color(0xFFFFE9A8)});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Wrap(children: [_chip(text, color: color)]);
}

class PatienceBar extends StatelessWidget {
  const PatienceBar({super.key, required this.fraction});
  final double fraction;
  @override
  Widget build(BuildContext context) {
    final col = fraction > 0.55 ? const Color(0xFF59B65B) : (fraction > 0.25 ? const Color(0xFFF1B531) : const Color(0xFFD9473B));
    return Container(
      height: 14,
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white70, width: 1.5)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: fraction.clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(6)))),
      ),
    );
  }
}

class GainChip extends StatelessWidget {
  const GainChip({super.key, required this.amount});
  final int amount;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, child) => Transform.translate(offset: Offset(0, -30 * t), child: Opacity(opacity: (1 - (t - 0.6).clamp(0, 0.4) / 0.4), child: child)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: amount >= 0 ? const Color(0xFF2E7D5B) : const Color(0xFF9A3D2B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2)),
          child: Text(amount >= 0 ? '+$amount ₺' : '−${-amount} ₺', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ),
      );
}

/// Çalışma tezgâhı: mekân temasına göre malzeme değiştirir (esnaf: paslanmaz, çarşı: ahşap, lokanta: ceviz, saray: koyu mermer + altın).
class WoodPanel extends StatelessWidget {
  const WoodPanel({super.key, this.theme = 't2'});
  final String theme;

  static const _colors = <String, (List<Color>, Color)>{
    't1': ([Color(0xFFB9BEC3), Color(0xFF9097A0), Color(0xFF727A84)], Color(0xFFE4E8EC)),
    't2': ([Color(0xFF8A5A2E), Color(0xFF6B4122), Color(0xFF55321A)], Color(0xFFB98350)),
    't3': ([Color(0xFF6A3E22), Color(0xFF4E2A15), Color(0xFF3A1E0E)], Color(0xFFC98A4A)),
    't4': ([Color(0xFF2C2A30), Color(0xFF1F1D23), Color(0xFF141317)], Color(0xFFE2B04A)),
  };

  @override
  Widget build(BuildContext context) {
    final (cols, edge) = _colors[theme] ?? _colors['t2']!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: cols),
        border: Border(top: BorderSide(color: edge, width: 6)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: CustomPaint(painter: _GrainPainter()),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0x22000000)..strokeWidth = 2;
    for (var i = 0; i < 22; i++) {
      final y = 12.0 + i * 11.0;
      canvas.drawLine(Offset(0, y), Offset(s.width, y + (i.isEven ? 3 : -3)), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Sürüklenen malzeme: istasyondan bir tezgâha bırakılır.
class IngredientDrag {
  const IngredientDrag(this.kind, this.asset, {this.sauce});
  final Ingredient kind;
  final String asset; // sürüklerken parmağın altında görünen sprite
  final String? sauce;
}

/// Hazır dürümü bir müşteriye ya da paket siparişine sürüklemek için.
class BoardDrag {
  const BoardDrag(this.board, this.asset);
  final int board;
  final String asset;
}

/// Dokununca hafifçe büyüyüp küçülen, sürüklenebilen malzeme istasyonu.
class Station extends StatefulWidget {
  const Station({super.key, required this.left, required this.top, required this.width, required this.asset, required this.label, required this.onTap, this.locked = false, this.lockedText = '', this.drag, this.steam, this.imageWidth});
  final double left, top, width;
  final double? imageWidth; // görsel genişliği (verilmezse [width]); dar şişelerde etiket geniş kalsın diye ayrı
  final String asset, label;
  final VoidCallback onTap;
  final bool locked; // kilitliyse soluk görünür, dokunulmaz
  final String lockedText;
  final IngredientDrag? drag;
  final Widget? steam; // sıcak yemekler için üstünden yükselen buhar

  @override
  State<Station> createState() => _StationState();
}

class _StationState extends State<Station> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    Widget core = AnimatedScale(
      scale: _down && !widget.locked ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Opacity(
        opacity: widget.locked ? 0.35 : 1,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Image.asset('assets/sprites/${widget.asset}.png', width: widget.imageWidth ?? widget.width, fit: BoxFit.contain),
            if (widget.steam != null && !widget.locked) Positioned(top: -widget.width * 0.42, child: widget.steam!),
            if (widget.locked) const Icon(Icons.lock, color: Colors.white, size: 44),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            // yazı büyütülünce istasyon genişliğine sığmazsa küçülür (kırılmaz)
            child: IntrinsicWidth(child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.locked && widget.lockedText.isNotEmpty ? widget.lockedText : widget.label, maxLines: 1, style: const TextStyle(color: kCream, fontSize: 17, fontWeight: FontWeight.w800)))),
          ),
        ]),
      ),
    );
    final d = widget.drag;
    if (d != null && !widget.locked) {
      core = Draggable<IngredientDrag>(
        data: d,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: IgnorePointer(
          child: d.asset.endsWith('_sise')
              ? Transform.translate(offset: const Offset(-23, -55), child: Image.asset('assets/sprites/${d.asset}.png', width: 46))
              : Transform.translate(offset: const Offset(-55, -55), child: Image.asset('assets/sprites/${d.asset}.png', width: 110)),
        ),
        childWhenDragging: Opacity(opacity: 0.45, child: core),
        child: core,
      );
    }
    return Positioned(
      left: widget.left,
      top: widget.top,
      width: widget.width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.locked ? null : widget.onTap,
        child: core,
      ),
    );
  }
}

/// Küçük ekranda düğme/simge büyütme çarpanı (GameScreen.textBoost). Kaplama kartlarının yazı çarpanı sınırlı olsa da düğmeler büyür.
class UiScale extends InheritedWidget {
  const UiScale({super.key, required this.boost, required super.child});
  final double boost;
  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiScale>()?.boost ?? 1.0;
  @override
  bool updateShouldNotify(UiScale old) => old.boost != boost;
}

class WoodButton extends StatelessWidget {
  const WoodButton({super.key, required this.label, required this.onTap, this.icon, this.enabled = true, this.big = false, this.color});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled, big;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF9A3D2B);
    final k = 1 + (UiScale.of(context) - 1) * 0.7; // telefonda %35'e kadar büyür
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: (big ? 34 : 20) * k, vertical: (big ? 16 : 10) * k),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) Icon(icon, color: Colors.white, size: (big ? 32 : 22) * k),
            if (icon != null) const SizedBox(width: 8),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: Colors.white, fontSize: (big ? 30 : 19) * k, fontWeight: FontWeight.w900, letterSpacing: 1)))),
          ]),
        ),
      ),
    );
  }
}

class HintChip extends StatelessWidget {
  const HintChip({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w800)),
      );
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.icon, this.iconColor = const Color(0xFFFFD27A), this.small = false});
  final String text;
  final IconData? icon;
  final Color iconColor;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final k = text.isEmpty ? 1 + (UiScale.of(context) - 1) * 0.9 : 1.0; // yalnız simge düğmeleri telefonda büyür
    return Container(
        padding: EdgeInsets.symmetric(horizontal: text.isEmpty ? 14 * k : (small ? 12 : 16), vertical: text.isEmpty ? 6 * k : (small ? 6 : 8)),
        decoration: BoxDecoration(color: const Color(0xCC2A1A0C), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFD9A25F), width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // text boşsa yalnızca simge (üst çubuk düğmeleri)
          if (icon != null) Icon(icon, color: iconColor, size: text.isEmpty ? 30 * k : (small ? 20 : 24)),
          if (icon != null && text.isNotEmpty) SizedBox(width: small ? 6 : 8),
          if (text.isNotEmpty) Text(text, style: TextStyle(color: kCream, fontSize: small ? 20 : 24, fontWeight: FontWeight.w800)),
        ]),
      );
  }
}

const Color kDiamond = Color(0xFF7FD6FF);

class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    final day = game.phase == Phase.playing ? game.day : game.day - (game.phase == Phase.dayEnd ? 1 : 0);
    return Row(children: [
      Pill(text: 'Gün $day', icon: Icons.wb_sunny, small: true),
      const SizedBox(width: 8),
      Pill(text: game.clockText, icon: Icons.schedule, small: true),
      const SizedBox(width: 8),
      Pill(text: '${game.money} ₺', icon: Icons.paid, small: true),
      const SizedBox(width: 8),
      Pill(text: '${game.diamonds}', icon: Icons.diamond, iconColor: kDiamond, small: true),
      const SizedBox(width: 8),
      Pill(text: 'Bölüm ${game.chapter}', icon: Icons.menu_book, small: true),
      if (game.gameOverEnabled) ...[
        const SizedBox(width: 8),
        Pill(text: '${game.lives}/${game.maxLives}', icon: Icons.favorite, iconColor: game.lives <= 1 ? const Color(0xFFFF6B5E) : const Color(0xFFFF8A80), small: true),
      ],
    ]);
  }
}

class HudRight extends StatelessWidget {
  const HudRight({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    final left = game.toSpawn + game.slots.where((c) => c != null && c.state != CustomerState.reacting && !c.isCourier).length;
    return Row(children: [
      Pill(text: '$left müşteri', icon: Icons.people, small: true),
      const SizedBox(width: 8),
      _HudIcon(keyName: 'hud-ad', label: 'Reklam', onTap: game.openAdMenu, child: const Pill(text: '', icon: Icons.smart_display, small: true)),
      const SizedBox(width: 8),
      _HudIcon(keyName: 'hud-recipe', label: 'Tarif', onTap: game.toggleRecipe, child: const Pill(text: '', icon: Icons.restaurant_menu, small: true)), // kaşık-çatal
      const SizedBox(width: 8),
      _HudIcon(
        keyName: 'hud-book',
        label: 'Defter',
        onTap: game.toggleNotebook,
        child: Stack(clipBehavior: Clip.none, children: [
          const Pill(text: '', icon: Icons.menu_book, small: true),
          if (game.quests.unseenChange)
            Positioned(right: -4, top: -4, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFD9473B), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
        ]),
      ),
      const SizedBox(width: 8),
      _HudIcon(keyName: 'hud-menu', label: 'Menü', onTap: game.toTitle, child: const Pill(text: '', icon: Icons.menu, small: true)), // üç çizgi
    ]);
  }
}

/// Üst çubuktaki simge düğmesi: yazısız; erişilebilirlik etiketi ve test anahtarı taşır.
class _HudIcon extends StatelessWidget {
  const _HudIcon({required this.keyName, required this.label, required this.onTap, required this.child});
  final String keyName;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(key: ValueKey(keyName), behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

/// Tezgâhın köşesindeki bahşiş kavanozu: biriken bahşiş görünür, dokununca kasaya geçer.
class TipJarView extends StatelessWidget {
  const TipJarView({super.key, required this.game});
  final GameController game;

  int get level => game.tipJar <= 0 ? 0 : (game.tipJar < 120 ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final amount = game.tipJar;
    return GestureDetector(
      key: const ValueKey('tip-jar'),
      behavior: HitTestBehavior.opaque,
      onTap: game.collectTipJar,
      child: SizedBox(
        width: 130,
        height: 206,
        child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
          Positioned(bottom: 14, child: Image.asset('assets/sprites/bahsis_$level.png', width: 124)),
          if (amount > 0)
            Positioned(
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF2E7D5B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
                child: Text('$amount ₺', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              child: const Text('Bahşiş', style: TextStyle(color: kCream, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Görev bildirimi (üstte kısa süre görünür).
class ToastBanner extends StatelessWidget {
  const ToastBanner({super.key, required this.title, required this.line});
  final String title;
  final String line;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey('$title$line'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -20 * (1 - t)), child: child)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D5B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(line, style: const TextStyle(color: Color(0xFFFFE9A8), fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
