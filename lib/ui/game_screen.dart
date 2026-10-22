import 'dart:math' as math;

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
import 'tutorial_overlay.dart';
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

  /// Telefon gibi çok yatay ekranlarda tasarım genişliği 1600'ün ötesine uzar (kenar boşlukları sahneyle doldurulur).
  static const double maxDesignW = 2200;

  /// Küçük ekranda yazıları büyütme çarpanı: sahne küçüldükçe metin okunur kalsın diye.
  static double textBoost(double scale) => (0.66 / scale).clamp(1.0, 1.5);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context); // çentik / ana ekran çubuğu
    return ColoredBox(
      color: const Color(0xFF1B1209),
      child: LayoutBuilder(builder: (context, c) {
        final w = (kH * c.maxWidth / c.maxHeight).clamp(kW, maxDesignW);
        final scale = (c.maxWidth / w).clamp(0.0, c.maxHeight / kH);
        final extra = (w - kW) / 2;
        final mq = MediaQuery.of(context);
        // alt tezgâh büyütmesi: yatayda çentik payına taşmasın (içerik ≈1550 birim geniş)
        final notch = math.max(inset.left, inset.right) / scale;
        final maxCounter = math.max(1.0, (w - 2 * notch - 24) / 1550);
        final counterScale = math.min(1 + (textBoost(scale) - 1) * 0.5, maxCounter);
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(textBoost(scale))),
              child: UiScale(
                boost: textBoost(scale),
                child: SizedBox(
                width: w,
                height: kH,
                child: ListenableBuilder(
                  listenable: Listenable.merge([game, if (game.leaderboard != null) game.leaderboard!]),
                  builder: (context, _) => Stack(clipBehavior: Clip.hardEdge, children: [
                    if (extra > 0) Positioned.fill(child: _SideFill(game: game, extra: extra)),
                    // HUD ekranın gerçek kenarlarına yaslanır (sahne kutusunun dışına taşar); çentik payı bırakılır
                    Positioned(
                      left: extra,
                      top: 0,
                      width: kW,
                      height: kH,
                      child: _Scene(game: game, animations: animations, counterScale: counterScale, hudLeft: 14 + inset.left / scale - extra, hudRight: 14 + inset.right / scale - extra, hudTop: 14 + inset.top / scale),
                    ),
                  ]),
                ),
              ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Sahnenin iki yanındaki genişletme: duvar ve tezgâhın kenar sütunu uzatılır, köşelere doğru kararır.
class _SideFill extends StatelessWidget {
  const _SideFill({required this.game, required this.extra});
  final GameController game;
  final double extra;

  Widget _strip(bool left) {
    final theme = game.theme;
    final slice = SizedBox(
      width: kW,
      height: kH,
      child: Stack(children: [
        Positioned.fill(child: Image.asset('assets/sprites/bg_$theme.png', fit: BoxFit.fill)),
        Positioned.fill(child: Image.asset('assets/sprites/tezgah_$theme.png', fit: BoxFit.fill)),
      ]),
    );
    return SizedBox(
      width: extra,
      height: kH,
      child: Stack(children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.fill,
            child: ClipRect(child: Align(alignment: left ? Alignment.centerLeft : Alignment.centerRight, widthFactor: 40 / kW, child: slice)),
          ),
        ),
        // dış kenara doğru kararma
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: left ? Alignment.centerRight : Alignment.centerLeft,
                end: left ? Alignment.centerLeft : Alignment.centerRight,
                colors: const [Color(0x001B1209), Color(0xCC1B1209)],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = DayLight.at(game.dayProgress);
    final dim = game.paused || game.phase != Phase.playing;
    return Stack(children: [
      Positioned(left: 0, top: 0, child: TimeTint(light: light, child: _strip(true))),
      Positioned(right: 0, top: 0, child: TimeTint(light: light, child: _strip(false))),
      if (dim) Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.6))),
    ]);
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
  const _Scene({required this.game, required this.animations, this.counterScale = 1.0, this.hudLeft = 14, this.hudRight = 14, this.hudTop = 14});
  final GameController game;
  final bool animations;
  final double counterScale; // alt tezgâhın büyütme çarpanı (telefon)
  final double hudLeft;
  final double hudRight;
  final double hudTop;

  @override
  Widget build(BuildContext context) {
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
        return Stack(clipBehavior: Clip.none, children: [
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
                  if (game.slots[i] != null) _CustomerView(game: game, slot: i, x: (game.deliveryActive ? GameScreen.slotXDelivery : GameScreen.slotX)[i], serveReady: game.anyBoardWrapped && playing, lift: (counterScale - 1) * 320),

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

          // alt tezgâh: küçük ekranda büyütülür (dokunma hedefleri ve etiketler okunur kalsın); tabanı sabit, yatayda ortadan
          Positioned.fill(
            child: Transform.scale(
              scale: counterScale,
              alignment: Alignment.bottomCenter,
              child: Stack(clipBehavior: Clip.none, children: [
              // çalışma tezgâhı (mekân temasına göre malzeme)
              Positioned(left: 0, right: 0, top: 676, bottom: 0, child: WoodPanel(theme: theme)),
              const Positioned(left: 20, top: 634, child: RoleChip(text: 'ÇIRAK · SEN')),

              // taban (ekmek / kâse) ve ana malzeme
              Station(
                left: 20,
                top: 668,
                width: 230,
                asset: p.bowl ? 'kase_yigin' : 'ekmek_yigin',
                label: p.bowl ? 'Kâse' : 'Tırnaklı ekmek',
                onTap: game.tapBread,
                drag: IngredientDrag(Ingredient.bread, p.bowl ? 'kase_yigin' : 'ekmek'),
                steam: p.bowl ? null : SteamAnim(width: 120, height: 90, animate: animations, puffs: 3),
              ),
              _ProductSwitcher(game: game),
              Station(
                left: 272,
                top: 678,
                width: 190,
                asset: _mainAsset(p.id),
                label: OrderIcons.cap(p.fillName),
                onTap: game.tapMain,
                drag: IngredientDrag(Ingredient.main, _mainAsset(p.id)),
                steam: SteamAnim(width: 110, height: 110, animate: animations),
              ),

              // ekler (piyaz, acı, kızartma, sumak)
              Station(left: 1010, top: 706, width: 140, asset: 'piyaz_kase', label: 'Piyaz', onTap: game.tapPiyaz, locked: !p.allows('piyaz'), lockedText: '', drag: const IngredientDrag(Ingredient.piyaz, 'piyaz_kase')),
              Station(left: 1150, top: 706, width: 140, asset: 'aci_kase', label: 'Acı', onTap: game.tapAci, drag: const IngredientDrag(Ingredient.aci, 'aci_kase')),
              Station(left: 1290, top: 706, width: 140, asset: 'kizartma_kase', label: 'Kızartma', onTap: game.tapFried, locked: !game.friedUnlocked || !p.allows('fried'), lockedText: game.friedUnlocked ? '' : 'Bölüm 2', drag: const IngredientDrag(Ingredient.fried, 'kizartma_kase'), steam: SteamAnim(width: 90, height: 70, animate: animations, puffs: 3)),
              Station(left: 1430, top: 706, width: 140, asset: 'sumak_kase', label: 'Sumak', onTap: game.tapSumak, locked: !game.sumakUnlocked || !p.allows('sumak'), lockedText: game.sumakUnlocked ? '' : 'Bölüm 2', drag: const IngredientDrag(Ingredient.sumak, 'sumak_kase')),

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
                    drag: IngredientDrag(Ingredient.sauce, _sauceAssets.values.elementAt(i), sauce: _sauceAssets.keys.elementAt(i)),
                    locked: !allowSauce || !game.sauces.any((s) => s.id == _sauceAssets.keys.elementAt(i)),
                    lockedText: game.sauces.any((s) => s.id == _sauceAssets.keys.elementAt(i)) ? '' : 'Bölüm 3',
                  ),

              // bahşiş kavanozu
              Positioned(left: 1470, top: 470, child: TipJarView(game: game)),

              // üç hazırlık tezgâhı: malzemeleri sürükle ya da dokun; hazır dürümü müşteriye sürükle
              for (var i = 0; i < GameController.boardCount; i++) BoardSlot(game: game, index: i, left: 500.0 + i * 172, top: 684, animations: animations, playing: playing),

              // ipucu
              if (game.hint.isNotEmpty && playing) Positioned(left: 560, width: 480, top: 636, child: Center(child: HintChip(text: game.hint))),
              ]),
            ),
          ),

          // paket servis (Bölüm 4+)
          if (game.deliveryActive && game.phase == Phase.playing) DeliveryPanel(game: game),

          // HUD
          // kaplama açıkken HUD solar (sahne kutusunun dışına taşan kısımlar da karartılmış görünsün)
          if (game.phase != Phase.title) Positioned(left: hudLeft, top: hudTop, child: Opacity(opacity: playing ? 1 : 0.45, child: Hud(game: game))),
          if (game.phase != Phase.title) Positioned(right: hudRight, top: hudTop, child: Opacity(opacity: playing ? 1 : 0.45, child: HudRight(game: game))),
          if (game.toast != null) Positioned(left: 0, right: 0, top: 70, child: Center(child: ToastBanner(title: game.toast!.title, line: game.toast!.line))),

          // faz kaplamaları          // başlık ve ayarlar tam yazı çarpanıyla (basit ekranlar; düğmeler telefonda okunur olsun)
          if (game.phase == Phase.title) TitleOverlay(game: game),
          if (game.settingsOpen) SettingsOverlay(game: game),

          // kaplama kartları 1600x900 içinde sığsın diye yazı çarpanı en çok 1.15
          Positioned.fill(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(math.min(MediaQuery.textScalerOf(context).scale(1.0), 1.15))),
              child: Stack(clipBehavior: Clip.none, children: [
              if (game.phase == Phase.dayEnd) DayEndOverlay(game: game),
              if (game.phase == Phase.gameOver) GameOverOverlay(game: game),
              if (game.phase == Phase.shop) ShopOverlay(game: game),
              if (game.phase == Phase.garden) GardenOverlay(game: game),
              if (game.phase == Phase.detective && game.caseState != null) DetectiveOverlay(game: game),
              if (game.notebookOpen) NotebookOverlay(game: game),
              if (game.recipeOpen) RecipeBookOverlay(game: game),
              if (game.leaderboard?.open ?? false) LeaderboardOverlay(manager: game.leaderboard!),
              if (game.adMenuOpen) AdMenuOverlay(game: game),
              if (game.sceneLines != null) SceneOverlay(game: game),
              if (game.tutorialActive) TutorialOverlay(game: game),
              if (game.adKind != null) AdWatchOverlay(game: game),
              if (game.introActive) IntroOverlay(game: game, animate: animations),
              ]),
            ),
          ),
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
    final can = multi && game.anyBoardEmpty;
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
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(game.selectedProduct.name, maxLines: 1, style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w900))),
          ),
        ),
        if (multi) arrow(Icons.chevron_right, 1) else const SizedBox(width: 40),
      ]),
    );
  }
}

/// Tek bir hazırlık tezgâhı: malzeme bırakılan hedef + hazır olunca müşteriye sürüklenen dürüm.
class BoardSlot extends StatelessWidget {
  const BoardSlot({super.key, required this.game, required this.index, required this.left, required this.top, required this.animations, required this.playing});
  final GameController game;
  final int index;
  final double left, top;
  final bool animations;
  final bool playing;

  static String _top(String wrap, int n) => wrap == 'nohut' ? 'top_nohut_${n.clamp(1, 3)}' : 'top_${wrap}_${n.clamp(1, 2)}';
  static String finishedAsset(Assembly a) => a.wrap == 'nohut' ? 'durum' : 'durum_${a.wrap}';

  @override
  Widget build(BuildContext context) {
    final a = game.boards[index];
    final active = game.activeBoard == index;
    final bowl = game.cfg.product(a.bread ? a.wrap : game.selectedWrap).bowl;
    Widget content;
    if (!a.bread) {
      content = Center(
        child: Container(
          width: 150,
          height: 80,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(60), border: Border.all(color: Colors.white38, width: 2.5), color: Colors.black12),
          child: Center(child: Text(bowl ? 'kâse' : 'ekmek', style: const TextStyle(color: Colors.white38, fontSize: 20, fontWeight: FontWeight.w700))),
        ),
      );
    } else if (bowl) {
      content = Stack(alignment: Alignment.center, children: [
        Image.asset('assets/sprites/beyran_tabla.png', fit: BoxFit.contain),
        if (a.aci) const Positioned(top: 4, child: _Tag('+ acı yağı')),
        if (a.wrapped) Positioned(top: -30, child: SteamAnim(width: 120, height: 80, animate: animations, puffs: 3)),
      ]);
    } else if (a.wrapped) {
      content = Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        Image.asset('assets/sprites/${finishedAsset(a)}.png', width: 170),
        Positioned(top: -34, child: SteamAnim(width: 110, height: 80, animate: animations, puffs: 3)),
      ]);
    } else {
      content = Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
        Image.asset('assets/sprites/ekmek.png', fit: BoxFit.contain),
        if (a.nohut > 0) Image.asset('assets/sprites/${_top(a.wrap, a.nohut)}.png', fit: BoxFit.contain),
        if (a.piyaz) Image.asset('assets/sprites/top_piyaz.png', fit: BoxFit.contain),
        if (a.fried) Image.asset('assets/sprites/top_fried.png', fit: BoxFit.contain),
        if (a.aci) Image.asset('assets/sprites/top_aci.png', fit: BoxFit.contain),
        if (a.sumak) Image.asset('assets/sprites/top_sumak.png', fit: BoxFit.contain),
        for (final id in kSauceIds)
          if (a.sauces.contains(id)) Image.asset('assets/sprites/top_$id.png', fit: BoxFit.contain),
        Positioned(top: -30, left: 0, right: 0, child: Center(child: SteamAnim(width: 110, height: 80, animate: animations, puffs: 3))),
      ]);
    }
    // hazır dürüm sürüklenebilir
    if (a.wrapped) {
      final asset = bowl ? 'beyran_kase' : finishedAsset(a);
      content = Draggable<BoardDrag>(
        data: BoardDrag(index, asset),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: IgnorePointer(child: Transform.translate(offset: const Offset(-80, -60), child: Image.asset('assets/sprites/$asset.png', width: 160))),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        // saydam piksellerde de tutulabilsin diye saydam ama dokunmaya duyarlı zemin
        child: SizedBox(width: 156, height: 142, child: ColoredBox(color: Colors.transparent, child: Center(child: content))),
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: 164,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        DragTarget<IngredientDrag>(
          key: ValueKey('board-$index'),
          onWillAcceptWithDetails: (d) => playing && !a.wrapped,
          onAcceptWithDetails: (d) => game.addIngredient(d.data.kind, board: index, sauceId: d.data.sauce),
          builder: (context, candidates, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => game.selectBoard(index),
            child: Container(
              width: 164,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: candidates.isNotEmpty ? const Color(0x5539B54A) : Colors.black.withValues(alpha: 0.12),
                border: Border.all(color: candidates.isNotEmpty ? const Color(0xFF7CE08A) : (active ? const Color(0xFFFFD27A) : Colors.white24), width: candidates.isNotEmpty || active ? 3.5 : 2),
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: Padding(padding: const EdgeInsets.all(4), child: content)),
                Positioned(left: 8, top: 4, child: Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w900))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          width: 172,
          child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (a.bread && !a.wrapped)
              _MiniButton(key: ValueKey('wrap-$index'), label: bowl ? 'SERVİS ET' : 'SAR', color: const Color(0xFF2E7D5B), onTap: () => game.wrap(board: index)),
            if (a.bread) ...[
              const SizedBox(width: 8),
              _MiniButton(key: ValueKey('trash-$index'), icon: Icons.delete_outline, color: const Color(0xFF9A3D2B), onTap: () => game.trash(board: index)),
            ],
          ])),
        ),
      ]),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({super.key, this.label, this.icon, required this.color, required this.onTap});
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: label != null ? 18 : 12, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 28),
            if (label != null) Text(label!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ]),
        ),
      );
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
  const _CustomerView({required this.game, required this.slot, required this.x, required this.serveReady, this.lift = 0});
  final GameController game;
  final int slot;
  final double x;
  final bool serveReady;
  final double lift; // büyütülmüş alt tezgâh yüzünden ad etiketi ve sabır çubuğunun yukarı kayması

  @override
  Widget build(BuildContext context) {
    final c = game.slots[slot]!;
    final mood = switch (c.mood) { Mood.happy => 'mutlu', Mood.angry => 'kizgin', _ => 'normal' };
    final canServe = serveReady && c.state == CustomerState.waiting && !c.isCourier;
    final courierReady = c.isCourier && c.state != CustomerState.reacting;
    final frac = c.patienceFraction;
    final showOrder = c.state == CustomerState.waiting && !c.waitLineShown;
    final boost = MediaQuery.textScalerOf(context).scale(1.0); // küçük ekranda yazı çarpanı
    // kalabalıkta yalnızca odaktaki müşterinin balonu tam metinle açılır; diğerleri yalnızca sipariş çipleriyle (okunur kalsın)
    final bubbleCount = game.slots.where((x) => x?.bubble != null).length;
    final compactBubble = showOrder && bubbleCount > 1 && game.focusSlot != slot;
    // odaktaki balon küçük ekranda biraz yana açılır (komşunun sipariş çipleriyle çakışmayacak kadar)
    final bubbleWiden = compactBubble ? 0.0 : (boost - 1) * 150;
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
      child: DragTarget<BoardDrag>(
        key: ValueKey('customer-$slot'),
        onWillAcceptWithDetails: (d) => serveReady && c.state == CustomerState.waiting && !c.isCourier,
        onAcceptWithDetails: (d) => game.tapCustomer(slot, board: d.data.board),
        builder: (context, candidates, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => game.tapCustomer(slot),
        child: Stack(clipBehavior: Clip.none, children: [
          if (candidates.isNotEmpty)
            Positioned(left: -40, right: -40, top: 230, bottom: 24, child: IgnorePointer(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), border: Border.all(color: const Color(0xFF7CE08A), width: 5), color: const Color(0x2239B54A))))),
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
              left: -6 - bubbleWiden,
              right: -6 - bubbleWiden,
              bottom: 345, // balonun alt kenarı kafanın hemen üstünde; metin uzadıkça yukarı büyür
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(math.min(boost, 1.3))),
                child: SpeechBubble(
                compact: compactBubble,
                text: c.bubble!.text,
                who: c.bubble!.whoLabel,
                to: c.bubble!.toLabel,
                size: showOrder ? 15.5 : 17,
                footer: footer,
                ),
              ),
            ),
          // ad etiketi (usta bu müşteriye konuşuyorsa vurgulanır)
          Positioned(left: 0, right: 0, top: 505 - lift, child: Center(child: NameTag(text: c.name.ref, highlighted: game.usta?.toSlot == slot))),
          // sabır çubuğu
          if (c.state == CustomerState.waiting) Positioned(left: 70, right: 70, top: 545 - lift, child: PatienceBar(fraction: frac)),
          if (c.state == CustomerState.reacting && c.gain != 0) Positioned(left: 0, right: 0, top: 190, child: Center(child: GainChip(amount: c.gain))),
        ]),
      ),
      ),
    );
  }
}
