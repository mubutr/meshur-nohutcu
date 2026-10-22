import 'package:flutter/material.dart';

import '../data/models.dart';
import '../game/game_controller.dart';
import '../game/scoring.dart';
import 'overlay_kit.dart';
import 'widgets.dart';

/// Tarif defteri: ürünlerin ne olduğunu, görselini, malzeme maliyetini ve fiyatını anlatır; kilitliler silüet olarak görünür.
class RecipeBookOverlay extends StatefulWidget {
  const RecipeBookOverlay({super.key, required this.game});
  final GameController game;
  @override
  State<RecipeBookOverlay> createState() => _RecipeBookOverlayState();
}

class _RecipeBookOverlayState extends State<RecipeBookOverlay> {
  int _tab = 0; // 0 ürünler, 1 ekler ve soslar

  static String _image(ProductDef p) => switch (p.id) {
        'nohut' => 'nohut_tencere',
        'beyran' => 'beyran_kase',
        _ => '${p.id}_tepsi',
      };

  static const _sauceImages = {'sos': 'sos_sise', 'ketcap': 'ketcap_sise', 'mayonez': 'mayonez_sise', 'nar': 'nar_sise', 'sumak': 'sumak_kase'};

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return OverlayDim(
      onTapOutside: g.toggleRecipe,
      child: OverlayCard(
        width: 1360,
        padding: 24,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Tarif Defteri', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kWood))),
            _Tab(label: 'Ürünler', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
            const SizedBox(width: 10),
            _Tab(label: 'Ekler ve soslar', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
          ]),
          const Divider(height: 22, thickness: 2, color: kWood),
          SizedBox(
            height: 560,
            child: _tab == 0 ? _products(g) : _extras(g),
          ),
          const SizedBox(height: 10),
          WoodButton(label: 'Kapat', icon: Icons.close, onTap: g.toggleRecipe),
        ]),
      ),
    );
  }

  Widget _products(GameController g) => GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.75,
        children: [for (final p in g.cfg.products) _ProductCard(g: g, p: p, image: _image(p))],
      );

  Widget _extras(GameController g) => ListView(children: [
        _extraRow(g, Icons.eco, 'Piyaz', 'Soğan, maydanoz ve sumakla ezilmiş piyaz; nohutun en yakın dostu.', g.cfg.costs['piyaz']!, 1, 'piyaz_kase'),
        _extraRow(g, Icons.local_fire_department, 'Acı', 'Pul biber; bir tutam bile dili uyandırır.', g.cfg.costs['aci']!, 1, 'aci_kase'),
        _extraRow(g, Icons.fastfood, 'Kızartma eki', 'Patates, patlıcan ve biber kızartması; dürümün yanına ya da içine.', g.cfg.costs['fried']!, g.cfg.eco('friedMinChapter').round(), 'kizartma_kase'),
        for (final s in g.cfg.sauces) _extraRow(g, Icons.water_drop, s.name, s.desc, s.cost, s.minChapter, _sauceImages[s.id]!),
      ]);

  Widget _extraRow(GameController g, IconData icon, String name, String desc, int cost, int minChapter, String image) {
    final locked = g.chapter < minChapter;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: kWood, width: 2)),
        child: Row(children: [
          SizedBox(width: 90, height: 90, child: ColorFiltered(colorFilter: locked ? const ColorFilter.mode(Colors.black87, BlendMode.srcIn) : const ColorFilter.mode(Colors.transparent, BlendMode.dst), child: Image.asset('assets/sprites/$image.png', fit: BoxFit.contain))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(locked ? '$name  ·  Bölüm $minChapter\'de açılır' : name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kWoodDark)),
              Text(locked ? '???' : desc, style: const TextStyle(fontSize: 17, color: Color(0xFF7A5A3A))),
            ]),
          ),
          Text(locked ? '' : 'malzeme $cost ₺', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF9A5B1E))),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(color: on ? kWood : Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: kWood, width: 3)),
          child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: on ? kCream : kWood)),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.g, required this.p, required this.image});
  final GameController g;
  final ProductDef p;
  final String image;

  @override
  Widget build(BuildContext context) {
    final locked = g.chapter < p.minChapter;
    final spec = OrderSpec(wrap: p.id, nohut: 1, piyaz: false, aci: false);
    final base = ingredientCost(g.cfg, spec);
    final price = orderPrice(g.cfg, spec);
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: locked ? Colors.black38 : kWood, width: 3)),
        child: Row(children: [
          SizedBox(
            width: 150,
            child: Center(
              child: ColorFiltered(
                colorFilter: locked ? const ColorFilter.mode(Colors.black87, BlendMode.srcIn) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 130), child: Image.asset('assets/sprites/$image.png', fit: BoxFit.contain)), // dar şişeler satırı uzatmasın
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(locked ? '???' : p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWoodDark)),
              const SizedBox(height: 2),
              Text(locked ? 'Bölüm ${p.minChapter}\'de açılır' : p.desc, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.2, color: Color(0xFF7A5A3A))),
              if (!locked) ...[
                const SizedBox(height: 4),
                Text('en az: malzeme $base ₺, satış $price ₺', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2E7D5B))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
