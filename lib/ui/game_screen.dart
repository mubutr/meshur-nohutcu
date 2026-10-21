import 'package:flutter/material.dart';

import '../data/models.dart';
import '../game/game_controller.dart';
import 'ad_overlay.dart';
import 'atmosphere.dart';
import 'intro_overlay.dart';
import 'leaderboard_overlay.dart';
import 'mode_overlays.dart';
import 'overlays.dart';
import 'recipe_book.dart';
import 'widgets.dart';

const double kW = 1600, kH = 900;

/// 1600x900'lük tasarım koordinatlarında çizilen oyun sahnesi; FittedBox ile ekrana sığdırılır.
/// [animations] kapatılınca sürekli animasyonlar (buhar) durur; testler için.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.game, this.animations = true});
  final GameController game;
  final bool animations;

  static const slotX = [760.0, 1070.0, 1380.0];
  static const slotXDelivery = [700.0, 990.0, 1280.0];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B1209),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: kW,
            height: kH,
            child: ListenableBuilder(
              listenable: Listenable.merge([game, if (game.leaderboard != null) game.leaderboard!]),
              builder: (context, _) => _Scene(game: game, animations: animations),
            ),
          ),
        ),
      ),
    );
  }
}

String _mainAsset(String id) => switch (id) {
      'nohut' => 'nohut_tencere',
      'doner' => 'doner_tepsi',
      'kavurma' => 'kavurma_tepsi',
      'cigkofte' => 'cigkofte_tepsi',
      'kizartma' => 'kizartma_tepsi',
      _ => 'beyran_kase',
    };

const _sauceAssets = {'sos': 'sos_sise', 'ketcap': 'ketcap_sise', 'mayonez': 'mayonez_sise', 'nar': 'nar_sise'};

class _Scene extends StatelessWidget {
  const _Scene({required this.game, required this.animations});
  final GameController game;
  final bool animations;

  @override
  Widget build(BuildContext context) {
    final a = game.assembly;
    final playing = game.phase == Phase.playing && !game.paused;
    final theme = game.theme;
    final p = game.selectedProduct;
    final back = game.cfg.decor.where((d) => d.layer == 'back' && game.decorOwned.contains(d.id));
    final front = game.cfg.decor.where((d) => d.layer == 'front' && game.decorOwned.contains(d.id));
    final allowSauce = p.allows('sauce');

    return TweenAnimationBuilder<double>(
      tween: Tween(end: game.dayProgress),
      duration: const Duration(milliseconds: 1400),
      builder: (context, progress, _) {
        final light = DayLight.at(progress);
        return Stack(clipBehavior: Clip.hardEdge, children: [
          // pencerenin arkasındaki gökyüzü (bg katmanında şeffaf delik var)
          SkyView(light: light),
          // ------- dünya: duvar, süsler, karakterler, tezgâh (saat rengiyle çarpılır)
          Positioned.fill(
            child: TimeTint(
              light: light,
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned.fill(child: Image.asset('assets/sprites/bg_$theme.png', fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
                for (final d in back) Positioned.fill(child: IgnorePointer(child: Image.asset('assets/sprites/decor_${d.id}.png', fit: BoxFit.fill))),

                // usta (fırının önünde, tam boy; bacakları tezgâhın arkasında kalır)
                Positioned(left: 113, top: 270, width: 404, child: IgnorePointer(child: Image.asset('assets/sprites/usta_${game.usta == null ? 'normal' : 'mutlu'}.png'))),
                // yardımcı çırak gövdesi tezgâhın arkasında
                if (game.level('yardimci') > 0) _HelperBody(game: game),

                // müşteriler (paket servis paneli açıkken biraz sola kayar)
                for (var i = 0; i < game.slotCount; i++)
                  if (game.slots[i] != null) _CustomerView(game: game, slot: i, x: (game.deliveryActive ? GameScreen.slotXDelivery : GameScreen.slotX)[i], serveReady: a.wrapped && playing),

                Positioned.fill(child: IgnorePointer(child: Image.asset('assets/sprites/tezgah_$theme.png', fit: BoxFit.fill))),
                for (final d in front) Positioned.fill(child: IgnorePointer(child: Image.asset('assets/sprites/decor_${d.id}.png', fit: BoxFit.fill))),
              ]),
            ),
          ),
          // gece ışıkları ve gündüz güneş huzmesi
          LightOverlay(light: light, neon: game.decorOwned.contains('neon')),

          // usta konuşma balonu
          if (game.usta != null)
            Positioned(
              left: 24,
              top: 120,
              width: 380,
              child: SpeechBubble(text: game.usta!.text, color: const Color(0xFFFFF4D6), who: game.usta!.whoLabel, to: game.usta!.toLabel),
            ),

          // yardımcı çırak etiketleri
          if (game.level('yardimci') > 0) _HelperTags(game: game),

          // çalışma tezgâhı (mekân temasına göre malzeme)
          Positioned(left: 0, right: 0, top: 676, bottom: 0, child: WoodPanel(theme: theme)),
          const Positioned(left: 520, top: 706, child: RoleChip(text: 'ÇIRAK · SEN')),

          // taban (ekmek / kâse) ve ana malzeme
          Station(left: 20, top: 668, width: 230, asset: p.bowl ? 'kase_yigin' : 'ekmek_yigin', label: p.bowl ? 'Kâse' : 'Tırnaklı ekmek', onTap: game.tapBread),
          _ProductSwitcher(game: game),
          Station(left: 272, top: 678, width: 190, asset: _mainAsset(p.id), label: OrderIcons.cap(p.fillName), onTap: game.tapMain),
          if (p.id == 'nohut') Positioned(left: 318, top: 590, child: SteamAnim(width: 100, height: 120, animate: animations)),

          // ekler (piyaz, acı, kızartma, sumak)
          Station(left: 1010, top: 706, width: 140, asset: 'piyaz_kase', label: 'Piyaz', onTap: game.tapPiyaz, locked: !p.allows('piyaz'), lockedText: ''),
          Station(left: 1150, top: 706, width: 140, asset: 'aci_kase', label: 'Acı', onTap: game.tapAci),
          Station(left: 1290, top: 706, width: 140, asset: 'kizartma_kase', label: 'Kızartma', onTap: game.tapFried, locked: !game.friedUnlocked || !p.allows('fried'), lockedText: game.friedUnlocked ? '' : 'Bölüm 2'),
          Station(left: 1430, top: 706, width: 140, asset: 'sumak_kase', label: 'Sumak', onTap: game.tapSumak, locked: !game.sumakUnlocked || !p.allows('sumak'), lockedText: game.sumakUnlocked ? '' : 'Bölüm 2'),

          // sos rafı (Bölüm 2+): tezgâhın üstünde şişeler
          if (game.chapter >= 2)
            for (var i = 0; i < _sauceAssets.length; i++)
              Station(
                left: 1010.0 + i * 118,
                top: 556,
                width: 112,
                asset: _sauceAssets.values.elementAt(i),
                label: game.cfg.sauce(_sauceAssets.keys.elementAt(i)).name,
                onTap: () => game.tapSauce(_sauceAssets.keys.elementAt(i)),
                locked: !allowSauce || !game.sauces.any((s) => s.id == _sauceAssets.keys.elementAt(i)),
                lockedText: game.sauces.any((s) => s.id == _sauceAssets.keys.elementAt(i)) ? '' : 'Bölüm 3',
              ),

          // bahşiş kavanozu
          Positioned(left: 1470, top: 470, child: TipJarView(game: game)),

          // tahta: taban + katmanlar + bitmiş dürüm
          Positioned(left: 560, top: 540, width: 400, height: 400, child: IgnorePointer(child: _Board(game: game, animations: animations))),

          // butonlar (tahtanın altında yan yana)
          Positioned(left: 560, top: 826, child: WoodButton(label: 'Çöpe at', icon: Icons.delete_outline, onTap: game.trash, enabled: !a.isEmpty && playing)),
          Positioned(
            left: 770,
            top: 812,
            child: WoodButton(label: p.bowl ? 'SERVİS ET' : 'SAR', icon: Icons.restaurant, onTap: game.wrap, enabled: a.bread && !a.wrapped && playing, big: true, color: const Color(0xFF2E7D5B)),
          ),

          // ipucu
          if (game.hint.isNotEmpty && playing) Positioned(left: 560, width: 480, top: 636, child: Center(child: HintChip(text: game.hint))),

          // paket servis (Bölüm 4+)
          if (game.deliveryActive && game.phase == Phase.playing) DeliveryPanel(game: game),

          // HUD
          if (game.phase != Phase.title) Positioned(left: 14, top: 14, child: Hud(game: game)),
          if (game.phase != Phase.title) Positioned(right: 14, top: 14, child: HudRight(game: game)),
          if (game.toast != null) Positioned(left: 0, right: 0, top: 70, child: Center(child: ToastBanner(title: game.toast!.title, line: game.toast!.line))),

          // faz kaplamaları
          if (game.phase == Phase.title) TitleOverlay(game: game),
          if (game.phase == Phase.dayEnd) DayEndOverlay(game: game),
          if (game.phase == Phase.shop) ShopOverlay(game: game),
          if (game.phase == Phase.garden) GardenOverlay(game: game),
          if (game.phase == Phase.detective && game.caseState != null) DetectiveOverlay(game: game),
          if (game.notebookOpen) NotebookOverlay(game: game),
          if (game.recipeOpen) RecipeBookOverlay(game: game),
          if (game.leaderboard?.open ?? false) LeaderboardOverlay(manager: game.leaderboard!),
          if (game.settingsOpen) SettingsOverlay(game: game),
          if (game.adMenuOpen) AdMenuOverlay(game: game),
          if (game.sceneLines != null) SceneOverlay(game: game),
          if (game.adKind != null) AdWatchOverlay(game: game),
          if (game.introActive) IntroOverlay(game: game, animate: animations),
        ]);
      },
    );
  }
}

/// Ana malzeme istasyonunun üstündeki ürün seçici: ◀ Nohut Dürümü ▶
class _ProductSwitcher extends StatelessWidget {
  const _ProductSwitcher({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final multi = game.products.length > 1;
    final can = multi && game.assembly.isEmpty && !game.assembly.wrapped;
    Widget arrow(IconData i, int dir) => GestureDetector(
          key: ValueKey('wrap-${dir > 0 ? 'next' : 'prev'}'),
          onTap: can ? () => game.cycleWrap(dir) : null,
          child: Opacity(
            opacity: can ? 1 : 0.3,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFF2A1A0C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD9A25F), width: 2)),
              child: Icon(i, color: const Color(0xFFFFD27A), size: 28),
            ),
          ),
        );
    return Positioned(
      left: 258,
      top: 630,
      width: 232,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (multi) arrow(Icons.chevron_left, -1) else const SizedBox(width: 40),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
            child: Text(game.selectedProduct.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
        if (multi) arrow(Icons.chevron_right, 1) else const SizedBox(width: 40),
      ]),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.game, required this.animations});
  final GameController game;
  final bool animations;

  static String _top(String wrap, int n) => wrap == 'nohut' ? 'top_nohut_${n.clamp(1, 3)}' : 'top_${wrap}_${n.clamp(1, 2)}';

  @override
  Widget build(BuildContext context) {
    final a = game.assembly;
    final bowl = game.cfg.product(a.bread ? a.wrap : game.selectedWrap).bowl;
    if (!a.bread) {
      return Center(
        child: Container(
          width: 340,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(80),
            border: Border.all(color: Colors.white38, width: 3),
            color: Colors.black12,
          ),
          child: Center(child: Text(bowl ? 'kâse' : 'ekmek', style: const TextStyle(color: Colors.white38, fontSize: 24, fontWeight: FontWeight.w700))),
        ),
      );
    }
    if (bowl) {
      return Stack(alignment: Alignment.center, children: [
        Image.asset('assets/sprites/beyran_tabla.png', fit: BoxFit.contain),
        if (a.aci) const Positioned(top: 40, child: _Tag('+ acı yağı')),
        if (a.wrapped) Positioned(top: 70, child: SteamAnim(width: 200, height: 120, animate: animations)),
      ]);
    }
    if (a.wrapped) {
      final asset = a.wrap == 'nohut' ? 'durum' : 'durum_${a.wrap}';
      return Center(child: Image.asset('assets/sprites/$asset.png', width: 400));
    }
    return Stack(fit: StackFit.expand, children: [
      Image.asset('assets/sprites/ekmek.png', fit: BoxFit.contain),
      if (a.nohut > 0) Image.asset('assets/sprites/${_top(a.wrap, a.nohut)}.png', fit: BoxFit.contain),
      if (a.piyaz) Image.asset('assets/sprites/top_piyaz.png', fit: BoxFit.contain),
      if (a.fried) Image.asset('assets/sprites/top_fried.png', fit: BoxFit.contain),
      if (a.aci) Image.asset('assets/sprites/top_aci.png', fit: BoxFit.contain),
      if (a.sumak) Image.asset('assets/sprites/top_sumak.png', fit: BoxFit.contain),
      for (final id in kSauceIds)
        if (a.sauces.contains(id)) Image.asset('assets/sprites/top_$id.png', fit: BoxFit.contain),
    ]);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFD9473B), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

/// Yardımcı Çırak'ın gövdesi (tezgâhın arkasında kalır).
class _HelperBody extends StatelessWidget {
  const _HelperBody({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 452,
        top: 408,
        width: 150,
        child: IgnorePointer(child: Image.asset('assets/sprites/cirak_${game.helper.ready != null ? 'mutlu' : 'normal'}.png')),
      );
}

/// Yardımcı Çırak: sipariş bekleyen müşteri için kendi dürümünü hazırlar; hazır olunca dokunup alırsın.
class _HelperTags extends StatelessWidget {
  const _HelperTags({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final h = game.helper;
    final auto = game.level('yardimci') >= game.cfg.upgrades.firstWhere((u) => u.id == 'yardimci').max;
    return Positioned(
      left: 435,
      top: 396,
      width: 190,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: game.tapHelper,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (h.ready != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF2E7D5B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
              child: const Text('HAZIR · AL', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            )
          else
            SizedBox(width: 110, child: PatienceBar(fraction: h.progress)),
          const SizedBox(height: 180),
          NameTag(text: auto ? 'Otomatik Usta' : 'Yardımcı Çırak'),
        ]),
      ),
    );
  }
}

class _CustomerView extends StatelessWidget {
  const _CustomerView({required this.game, required this.slot, required this.x, required this.serveReady});
  final GameController game;
  final int slot;
  final double x;
  final bool serveReady;

  @override
  Widget build(BuildContext context) {
    final c = game.slots[slot]!;
    final mood = switch (c.mood) { Mood.happy => 'mutlu', Mood.angry => 'kizgin', _ => 'normal' };
    final canServe = serveReady && c.state == CustomerState.waiting && !c.isCourier;
    final courierReady = c.isCourier && c.state != CustomerState.reacting;
    final frac = c.patienceFraction;
    final showOrder = c.state == CustomerState.waiting && !c.waitLineShown;
    Widget? footer;
    if (showOrder) {
      footer = switch (c.kind) {
        CustomerKind.riddle => const SpecialBadge('Bilmece: ne istediğini çöz'),
        CustomerKind.garip => const SpecialBadge('İkram bekliyor · ücretsiz', color: Color(0xFFD9F2D2)),
        CustomerKind.maskeli => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SpecialBadge('Dikkat: hatada kasadan para alır', color: Color(0xFFF5D6D2)),
            OrderIcons(spec: c.spec, game: game),
          ]),
        CustomerKind.normal => OrderIcons(spec: c.spec, game: game),
        CustomerKind.bonus => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SpecialBadge('Gezgin: 1 elmas bırakır', color: Color(0xFFD6ECFA)),
            OrderIcons(spec: c.spec, game: game),
          ]),
        CustomerKind.kurye => SpecialBadge('Kurye: dokun, ${game.delivery.boxedCount} paket ver', color: const Color(0xFFFFE9A8)),
      };
    }
    return Positioned(
      left: x - 150,
      top: 40,
      width: 300,
      height: 610,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => game.tapCustomer(slot),
        child: Stack(clipBehavior: Clip.none, children: [
          // tam boy sprite: ayaklar tezgâhın arkasında kalır
          Positioned(
            left: -52,
            top: 238,
            width: 404,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: canServe ? 1.03 : 1.0,
              alignment: Alignment.bottomCenter,
              child: Image.asset('assets/sprites/${c.sprite}_$mood.png', fit: BoxFit.fitWidth),
            ),
          ),
          if (canServe)
            Positioned(
              left: 0,
              right: 0,
              top: 452,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF2E7D5B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2.5)),
                  child: const Text('VER', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
            ),
          if (courierReady)
            Positioned(
              left: 0,
              right: 0,
              top: 462,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE0861A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2.5)),
                  child: Text('PAKETLERİ VER (${game.delivery.boxedCount})', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          if (c.kind == CustomerKind.bonus && c.state != CustomerState.reacting) const Positioned(right: 30, top: 262, child: Icon(Icons.diamond, color: kDiamond, size: 38)),
          // konuşma balonu
          if (c.bubble != null)
            Positioned(
              left: -6,
              right: -6,
              bottom: 345, // balonun alt kenarı kafanın hemen üstünde; metin uzadıkça yukarı büyür
              child: SpeechBubble(
                text: c.bubble!.text,
                who: c.bubble!.whoLabel,
                to: c.bubble!.toLabel,
                size: showOrder ? 15.5 : 17,
                footer: footer,
              ),
            ),
          // ad etiketi (usta bu müşteriye konuşuyorsa vurgulanır)
          Positioned(left: 0, right: 0, top: 505, child: Center(child: NameTag(text: c.name.ref, highlighted: game.usta?.toSlot == slot))),
          // sabır çubuğu
          if (c.state == CustomerState.waiting) Positioned(left: 70, right: 70, top: 545, child: PatienceBar(fraction: frac)),
          if (c.state == CustomerState.reacting && c.gain != 0) Positioned(left: 0, right: 0, top: 190, child: Center(child: GainChip(amount: c.gain))),
        ]),
      ),
    );
  }
}
