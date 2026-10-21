import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import 'widgets.dart';

/// Tanıtım adımı: vurgulanan sahne bölgesi (1600x900 tasarım koordinatı) + açıklama.
class TutorialStep {
  const TutorialStep({required this.title, required this.text, this.spot, this.cardAt = Alignment.center});
  final String title;
  final String text;
  final Rect? spot;
  final Alignment cardAt; // açıklama kartının ekrandaki yeri
}

const List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    title: 'Hoş geldin çırak!',
    text: 'Meşhur Nohutçu\'da usta müşterilerle konuşur, sen de dürümleri hazırlarsın. Hadi oynanışı kısaca gösterelim.',
  ),
  TutorialStep(
    title: '1 · Müşteri ve sipariş',
    text: 'Müşteri siparişini balonda söyler; altındaki çipler ne istediğini gösterir. Sabır çubuğu bitmeden dürümünü ver, yoksa küser ve kasadan ceza düşer.',
    spot: Rect.fromLTWH(600, 40, 920, 600),
    cardAt: Alignment.bottomLeft,
  ),
  TutorialStep(
    title: '2 · Tırnaklı ekmek',
    text: 'Tırnaklı ekmeği tutup bir hazırlık tezgâhına sürükle (ya da dokun). Aynı anda 3 dürüm hazırlayabilirsin.',
    spot: Rect.fromLTWH(10, 660, 250, 235),
    cardAt: Alignment.topLeft,
  ),
  TutorialStep(
    title: '3 · Nohut ve ekler',
    text: 'Nohutu, piyazı, acıyı, kızartmayı, sumağı ve sosları da sürükleyerek tezgâhtaki dürüme bırak. Ürün seçici oklarıyla hazırlayacağın ürünü seç. Her malzeme para harcar!',
    spot: Rect.fromLTWH(262, 625, 245, 270),
    cardAt: Alignment.topLeft,
  ),
  TutorialStep(
    title: '4 · Sar ve ver',
    text: 'Malzeme tamamsa SAR\'a bas. Hazır dürümü tutup doğru müşterinin üstüne sürükle (ya da müşteriye dokun). Hatalı dürüm az öder, çöpe atarsan malzeme parası gider.',
    spot: Rect.fromLTWH(496, 676, 524, 215),
    cardAt: Alignment.topRight,
  ),
  TutorialStep(
    title: '5 · Para, bahşiş ve kâr',
    text: 'Satış fiyatı malzeme maliyetinin %30 fazlasıdır. Bahşişler sağdaki kavanoza düşer; dokununca kasaya geçer. Gün sonunda kira ve masraflar düşer.',
    spot: Rect.fromLTWH(1462, 462, 140, 232),
    cardAt: Alignment.centerLeft,
  ),
  TutorialStep(
    title: '6 · Defter, Tarif, Reklam',
    text: 'Defter: görevler ve günlük hedefler. Tarif: ürünlerin ne olduğu ve fiyatı. Reklam izleyerek para ya da elmas kazanabilirsin. Bol şans, usta seni bekliyor!',
    spot: Rect.fromLTWH(960, 8, 636, 62),
    cardAt: Alignment.bottomRight,
  ),
];

/// İlk oyunda (kepenk açılışından sonra) oynanışı adım adım gösterir; ayarlardan tekrar açılabilir.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final i = game.tutorialStep.clamp(0, kTutorialSteps.length - 1);
    final step = kTutorialSteps[i];
    final last = i == kTutorialSteps.length - 1;
    return Positioned.fill(
      child: Stack(children: [
        // karartma: vurgulanan bölge boş bırakılır (altındaki dokunuşlar yutulur)
        Positioned.fill(child: AbsorbPointer(child: CustomPaint(painter: _SpotPainter(step.spot)))),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: Align(
              alignment: step.cardAt,
              child: Container(
                key: const ValueKey('tutorial-card'),
                width: 560,
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
                decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(24), border: Border.all(color: kWood, width: 5), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))]),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(step.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kWood))),
                    Text('${i + 1}/${kTutorialSteps.length}', style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A), fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(step.text, style: const TextStyle(fontSize: 22, height: 1.3, color: kWoodDark, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!last) WoodButton(label: 'Atla', icon: Icons.close, onTap: game.skipTutorial, color: const Color(0xFF6B5A4A)),
                    const SizedBox(width: 12),
                    WoodButton(label: last ? 'Başlayalım' : 'Devam', icon: last ? Icons.check : Icons.arrow_forward, onTap: game.nextTutorial, color: const Color(0xFF2E7D5B)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter(this.spot);
  final Rect? spot;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    if (spot == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    final hole = RRect.fromRectAndRadius(spot!.inflate(6), const Radius.circular(24));
    // evenOdd: dış dikdörtgen boyanır, iç kalan delik boş kalır (Path.combine web'de güvenilir değil)
    canvas.drawPath(Path()..fillType = PathFillType.evenOdd..addRect(Offset.zero & size)..addRRect(hole), scrim);
    canvas.drawRRect(hole, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0xFFFFD27A));
  }

  @override
  bool shouldRepaint(_SpotPainter old) => old.spot != spot;
}
