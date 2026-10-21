import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import 'overlay_kit.dart';
import 'widgets.dart';

/// "Reklam izle" seçim ekranı: para ya da elmas. (Reklam şimdilik sahte: geri sayım; gerçek SDK `GameController._grantAd`'a bağlanır.)
class AdMenuOverlay extends StatelessWidget {
  const AdMenuOverlay({super.key, required this.game});
  final GameController game;

  Widget _option({required String title, required String sub, required IconData icon, required Color color, required String kind}) {
    final left = game.adsLeft(kind);
    final can = game.canWatchAd(kind);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: kWood, width: 3)),
      child: Row(children: [
        Icon(icon, size: 52, color: color),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kWood)),
            Text(sub, style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
            Text(can ? 'Bugün $left hakkın var' : 'Bugünlük hakkın bitti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: can ? const Color(0xFF2E7D5B) : const Color(0xFF9A3D2B))),
          ]),
        ),
        WoodButton(label: 'İzle', icon: Icons.play_circle, enabled: can, onTap: () => game.startAd(kind), color: const Color(0xFF9A5B1E)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayDim(
        onTapOutside: game.closeAdMenu,
        child: OverlayCard(
          width: 780,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Reklam izle, kazan', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kWood)),
            const Divider(height: 24, thickness: 2, color: kWood),
            _option(title: '+${game.adMoneyReward} ₺', sub: 'Kasaya bir miktar para ekler.', icon: Icons.paid, color: const Color(0xFFB07A1E), kind: 'money'),
            _option(title: '+1 elmas', sub: 'Elmas; otomasyon ve lüks süsler için.', icon: Icons.diamond, color: const Color(0xFF3AA7D9), kind: 'diamond'),
            const SizedBox(height: 8),
            const Text('Reklam şimdilik örnek bir geri sayımdır.', style: TextStyle(fontSize: 15, color: Color(0xFF7A5A3A), fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            WoodButton(label: 'Kapat', icon: Icons.close, onTap: game.closeAdMenu),
          ]),
        ),
      );
}

/// Reklam izleniyor: geri sayım bitince ödül verilir.
class AdWatchOverlay extends StatelessWidget {
  const AdWatchOverlay({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final total = game.cfg.eco('adSeconds');
    final left = game.adLeft.clamp(0, total);
    final isDiamond = game.adKind == 'diamond';
    return OverlayDim(
      opacity: 0.92,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.smart_display, size: 90, color: Color(0xFFFFD27A)),
          const SizedBox(height: 12),
          const Text('Örnek reklam', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: kCream)),
          const SizedBox(height: 8),
          Text('Ödül: ${isDiamond ? '1 elmas' : '${game.adMoneyReward} ₺'}', style: const TextStyle(fontSize: 28, color: Color(0xFFFFE9A8), fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          SizedBox(
            width: 420,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: total <= 0 ? 1 : 1 - left / total, minHeight: 16, backgroundColor: Colors.white24, color: const Color(0xFF59B65B)),
            ),
          ),
          const SizedBox(height: 10),
          Text('${left.ceil()} sn', style: const TextStyle(fontSize: 30, color: kCream, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          WoodButton(label: 'Vazgeç', icon: Icons.close, onTap: game.cancelAd, color: const Color(0xFF6B5A4A)),
        ]),
      ),
    );
  }
}
