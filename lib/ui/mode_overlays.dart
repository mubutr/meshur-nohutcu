import 'package:flutter/material.dart';

import '../dialog/antep_dialog.dart';
import '../game/game_controller.dart';
import '../modes/delivery.dart';
import '../modes/detective.dart';
import 'widgets.dart';

class _Dim extends StatelessWidget {
  const _Dim({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.6), child: child));
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.width});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: width,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kWood, width: 6),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))],
          ),
          child: child,
        ),
      );
}

// =================================================================== paket servis paneli
class DeliveryPanel extends StatelessWidget {
  const DeliveryPanel({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final d = game.delivery;
    final cap = d.boxCapacity(game.level('dagitim'));
    final ready = game.anyBoardWrapped;
    return Positioned(
      left: 1446,
      top: 84,
      width: 148,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xDD2A1A0C), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD9A25F), width: 2)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('KAPINDA', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD27A), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text(d.courierHere ? 'KURYE KAPIDA! · Kutu ${d.boxedCount}/$cap' : 'Kurye ${d.courierLeft.clamp(0, 99).round()} sn · Kutu ${d.boxedCount}/$cap',
              textAlign: TextAlign.center, style: TextStyle(color: d.courierHere ? const Color(0xFFFFD27A) : kCream, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (d.orders.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Sipariş yok', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14))),
          for (var i = 0; i < d.orders.length; i++) _DeliveryCard(game: game, index: i, order: d.orders[i], canBox: ready && !d.orders[i].isBoxed && d.boxedCount < cap),
        ]),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.game, required this.index, required this.order, required this.canBox});
  final GameController game;
  final int index;
  final DeliveryOrder order;
  final bool canBox;

  @override
  Widget build(BuildContext context) {
    final s = order.spec;
    final p = game.cfg.product(s.wrap);
    final amount = s.nohut <= 1 ? 'az' : (s.nohut == 2 && p.maxAmount > 2 ? 'orta' : 'bol');
    final parts = [
      p.maxAmount > 1 ? '${OrderIcons.cap(p.fillName)}: $amount' : OrderIcons.cap(p.fillName),
      if (p.allows('piyaz')) s.piyaz ? 'Piyaz' : 'Piyazsız',
      if (p.allows('aci')) s.aci ? 'Acılı' : 'Acısız',
      if (game.friedUnlocked && p.allows('fried') && s.fried) 'Kızartmalı',
      if (p.allows('sumak') && game.sumakUnlocked) s.sumak ? 'Sumaklı' : 'Sumaksız',
      for (final sc in game.sauces.where((x) => x.id != 'sumak' && s.sauces.contains(x.id))) sc.name,
    ];
    final cold = order.boxedAge > DeliveryState.coldAfter;
    return DragTarget<BoardDrag>(
      key: ValueKey('delivery-$index'),
      onWillAcceptWithDetails: (d) => !order.isBoxed,
      onAcceptWithDetails: (d) => game.serveDelivery(index, board: d.data.board),
      builder: (context, candidates, _) => GestureDetector(
      onTap: () => game.serveDelivery(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: order.isBoxed ? (cold ? const Color(0xFF3B5A7A) : const Color(0xFF2E7D5B)) : (canBox ? const Color(0xFFFFE9A8) : kCream),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: canBox ? Colors.white : kWood, width: canBox ? 3 : 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order.isBoxed ? (cold ? 'KUTUDA · SOĞUDU' : 'KUTUDA ✓') : 'PAKET #${order.id}',
              style: TextStyle(color: order.isBoxed ? Colors.white : const Color(0xFF9A5B1E), fontSize: 13, fontWeight: FontWeight.w900)),
          Text(parts.join(' · '), style: TextStyle(color: order.isBoxed ? Colors.white : kWoodDark, fontSize: 13, height: 1.15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          PatienceBar(fraction: order.fraction),
          if (canBox || candidates.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 3), child: Text('Dokun ya da sürükle: kutuya koy', style: TextStyle(color: Color(0xFF2E7D5B), fontSize: 12, fontWeight: FontWeight.w900))),
        ]),
      ),
      ),
    );
  }
}

// =================================================================== bahçe
class GardenOverlay extends StatelessWidget {
  const GardenOverlay({super.key, required this.game});
  final GameController game;

  static const _icons = {'maydanoz': Icons.eco, 'sogan': Icons.spa, 'biber': Icons.local_fire_department};
  static const _colors = {'maydanoz': Color(0xFF3F8F3A), 'sogan': Color(0xFFB07AC0), 'biber': Color(0xFFD9473B)};

  @override
  Widget build(BuildContext context) {
    final g = game.garden;
    return _Dim(
      child: _Card(
        width: 1300,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Arka Bahçe', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: kWood))),
            Pill(text: '${game.money} ₺', icon: Icons.paid),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Her akşam sula; olgunlaşanı topla. Susuz kalan bitki ${g.cfg.maxDry} gün sonra kurur. Stok piyaz ve acı masrafını düşürür, dürümü %${(g.cfg.freshBonus * 100).round()} değerlendirir.',
                style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
          ),
          const Divider(height: 22, thickness: 2, color: kWood),
          SizedBox(
            height: 430,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 7,
                child: Wrap(spacing: 14, runSpacing: 14, children: [
                  for (var i = 0; i < g.plots.length; i++) _PlotCard(game: game, index: i),
                ]),
              ),
              const VerticalDivider(width: 28, thickness: 2, color: kWood),
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Stok', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E))),
                  for (final c in g.cfg.crops)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(_icons[c.id], color: _colors[c.id], size: 30),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kWoodDark))),
                        Text('${g.stock[c.id] ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kWoodDark)),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  const Text('Piyaz: 1 maydanoz + 1 soğan\nAcı: 1 biber', style: TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
                  const SizedBox(height: 14),
                  Text('Kuruyan bitki: ${g.witheredTotal}', style: const TextStyle(fontSize: 17, color: Color(0xFF7A5A3A))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            WoodButton(label: 'Hepsini sula', icon: Icons.water_drop, onTap: game.gardenWaterAll, color: const Color(0xFF3B6EA5)),
            const SizedBox(width: 18),
            WoodButton(label: 'Tamam', icon: Icons.check, onTap: game.closeGarden, color: const Color(0xFF2E7D5B)),
          ]),
        ]),
      ),
    );
  }
}

class _PlotCard extends StatelessWidget {
  const _PlotCard({required this.game, required this.index});
  final GameController game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final g = game.garden;
    final p = g.plots[index];
    final ready = g.isReady(p);
    final crop = p.crop == null ? null : g.cfg.crop(p.crop!);
    return Container(
      width: 200,
      height: 205,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF6B4122), borderRadius: BorderRadius.circular(16), border: Border.all(color: ready ? const Color(0xFFFFD27A) : const Color(0xFF3A200E), width: ready ? 4 : 3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Parsel ${index + 1}', style: const TextStyle(color: kCream, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        if (crop == null) ...[
          const Text('Boş · ek:', style: TextStyle(color: Colors.white70, fontSize: 15)),
          for (final c in g.cfg.crops)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: GestureDetector(
                onTap: () => game.gardenPlant(index, c.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: game.money >= c.seed ? const Color(0xFF5E8C3A) : Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Text('${c.name} · ${c.seed} ₺', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ] else ...[
          Row(children: [
            Icon(GardenOverlay._icons[crop.id], color: ready ? const Color(0xFFFFD27A) : GardenOverlay._colors[crop.id], size: 34),
            const SizedBox(width: 6),
            Expanded(child: Text(crop.name, style: const TextStyle(color: kCream, fontSize: 19, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 6),
          // büyüme çubuğu
          Container(
            height: 14,
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
            child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: (p.grown / crop.days).clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: const Color(0xFF59B65B), borderRadius: BorderRadius.circular(8))))),
          ),
          Text(ready ? 'Olgun!' : '${p.grown}/${crop.days} gün${p.dry > 0 ? ' · SUSUZ!' : ''}',
              style: TextStyle(color: p.dry > 0 ? const Color(0xFFFF9A8A) : Colors.white70, fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (ready)
            WoodButton(label: 'Hasat +${crop.yield}', icon: Icons.agriculture, onTap: () => game.gardenHarvest(index), color: const Color(0xFFB07A1E))
          else
            WoodButton(label: p.wateredToday ? 'Sulandı' : 'Sula', icon: Icons.water_drop, enabled: !p.wateredToday, onTap: () => game.gardenWater(index), color: const Color(0xFF3B6EA5)),
        ],
      ]),
    );
  }
}

// =================================================================== soruşturma
class DetectiveOverlay extends StatefulWidget {
  const DetectiveOverlay({super.key, required this.game});
  final GameController game;
  @override
  State<DetectiveOverlay> createState() => _DetectiveOverlayState();
}

class _DetectiveOverlayState extends State<DetectiveOverlay> {
  String _tab = 'mekan'; // mekan | supheli | ipucu | suclama
  String? _suspect;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final cs = game.caseState!;
    final data = cs.data;
    Widget tab(String id, String label, IconData icon) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _tab = id),
            child: Pill(text: label, icon: icon),
          ),
        );
    return _Dim(
      child: _Card(
        width: 1380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Soruşturma Defteri', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kWood))),
            Pill(text: 'Gece hakkı: ${cs.actionsLeft}', icon: Icons.nightlight_round),
            const SizedBox(width: 10),
            Pill(text: '${cs.clues.where((c) => c != 'solved').length}/${data.clues.length} ipucu', icon: Icons.search),
          ]),
          if (cs.solved) const Align(alignment: Alignment.centerLeft, child: Text('Dava çözüldü! Tandır taşı yerine kondu.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B)))),
          const Divider(height: 20, thickness: 2, color: kWood),
          Row(children: [
            tab('mekan', 'Mekânlar', Icons.place),
            tab('supheli', 'Şüpheliler', Icons.groups),
            tab('ipucu', 'İpuçları', Icons.fact_check),
            tab('suclama', 'Suçla', Icons.gavel),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: _body(game, cs)),
              const VerticalDivider(width: 28, thickness: 2, color: kWood),
              Expanded(flex: 4, child: _log(game)),
            ]),
          ),
          const SizedBox(height: 8),
          WoodButton(label: 'Kapat', icon: Icons.close, onTap: game.closeCase, color: const Color(0xFF9A5B1E)),
        ]),
      ),
    );
  }

  Widget _body(GameController game, CaseState cs) {
    final data = cs.data;
    switch (_tab) {
      case 'mekan':
        return ListView(children: [
          for (final l in data.locations)
            _Row(
              title: l.name,
              sub: l.desc,
              trailing: cs.nextStep(l) == null
                  ? const Text('İncelendi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B)))
                  : WoodButton(label: 'İncele', icon: Icons.search, enabled: cs.actionsLeft > 0 && !cs.solved, onTap: () => game.caseInspect(l.id)),
            ),
        ]);
      case 'supheli':
        if (_suspect == null) {
          return ListView(children: [
            for (final s in data.suspects)
              _Row(title: '${s.name} · ${s.title}', sub: s.intro, trailing: WoodButton(label: 'Konuş', icon: Icons.chat, onTap: () => setState(() => _suspect = s.id))),
          ]);
        }
        final sp = data.suspects.firstWhere((s) => s.id == _suspect);
        return ListView(children: [
          Row(children: [
            GestureDetector(onTap: () => setState(() => _suspect = null), child: const Icon(Icons.arrow_back, size: 30, color: kWood)),
            const SizedBox(width: 8),
            Text(sp.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kWoodDark)),
          ]),
          const SizedBox(height: 8),
          for (final q in data.talk[sp.id] ?? const <QuestionDef>[])
            if (cs.asked.contains('${sp.id}/${q.id}'))
              _Row(title: q.q, sub: 'Sordun.', trailing: const Icon(Icons.check_circle, color: Color(0xFF2E7D5B), size: 30))
            else if (!cs.hasAll(q.requires))
              _Row(title: '???', sub: 'Önce başka ipuçları bulmalısın.', trailing: const Icon(Icons.lock, color: kWood, size: 28))
            else
              _Row(title: q.q, sub: '', trailing: WoodButton(label: 'Sor', icon: Icons.help, enabled: cs.actionsLeft > 0 && !cs.solved, onTap: () => game.caseAsk(sp.id, q))),
        ]);
      case 'ipucu':
        if (cs.clues.where((c) => c != 'solved').isEmpty) return const Text('Henüz ipucu yok. Mekânları incele, şüphelilerle konuş.', style: TextStyle(fontSize: 20, color: Color(0xFF7A5A3A)));
        return ListView(children: [
          for (final id in cs.clues.where((c) => c != 'solved')) _Row(title: data.clues[id]!.title, sub: data.clues[id]!.text),
        ]);
      default:
        return ListView(children: [
          const Text('Kimi suçluyorsun? Yanlış suçlama pahalıya patlar; doğru kişi için kızak izi, bileziğin sahibi ve tanık sözü gerekir.', style: TextStyle(fontSize: 19, color: Color(0xFF7A5A3A))),
          const SizedBox(height: 8),
          for (final s in data.suspects)
            _Row(title: s.name, sub: s.title, trailing: WoodButton(label: 'Suçla', icon: Icons.gavel, enabled: !cs.solved, onTap: () => game.caseAccuse(s.id), color: const Color(0xFF9A3D2B))),
        ]);
    }
  }

  Widget _log(GameController game) {
    if (game.caseLog.isEmpty) {
      return const Center(child: Text('Bir mekânı incele ya da bir şüpheliye soru sor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Color(0xFF7A5A3A))));
    }
    return ListView(children: [
      for (final s in game.caseLog)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(s.whoLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E), letterSpacing: 1)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.arrow_right_alt, size: 17, color: Color(0xFF9A5B1E))),
              Text(s.toLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E), letterSpacing: 1)),
            ]),
            Text(s.text, style: const TextStyle(fontSize: 20, height: 1.25, color: kWoodDark, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.sub = '', this.trailing});
  final String title;
  final String sub;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWoodDark)),
              if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 17, color: Color(0xFF7A5A3A))),
            ]),
          ),
          ?trailing,
        ]),
      );
}

String roleLabel(String who) => kRoleLabels[who] ?? who.toUpperCase();
