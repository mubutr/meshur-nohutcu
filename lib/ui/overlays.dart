import 'package:flutter/material.dart';

import '../data/models.dart';
import '../dialog/antep_dialog.dart';
import '../game/game_controller.dart';
import '../quest/quest_engine.dart';
import 'widgets.dart';

class _Card extends StatelessWidget {
  const _Card({required this.child, this.width = 760});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: width,
          padding: const EdgeInsets.all(28),
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

class _Dim extends StatelessWidget {
  const _Dim({required this.child, this.opacity = 0.55});
  final Widget child;
  final double opacity;
  @override
  Widget build(BuildContext context) => Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: opacity), child: child));
}

// ------------------------------------------------------------------ başlık
class TitleOverlay extends StatelessWidget {
  const TitleOverlay({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    final started = game.day > 1 || game.money > 0 || game.quests.done.isNotEmpty;
    return _Dim(
      opacity: 0.62,
      child: Stack(children: [
        Positioned(left: 80, bottom: 0, width: 420, child: IgnorePointer(child: Image.asset('assets/sprites/usta_mutlu.png'))),
        Positioned(right: 80, bottom: 0, width: 420, child: IgnorePointer(child: Image.asset('assets/sprites/fatma_mutlu.png'))),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Sıcak sıcak nohut dürümü', style: TextStyle(color: Color(0xFFFFD27A), fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 2)),
            const SizedBox(height: 10),
            const Text('Meşhur\nNohutçu',
                textAlign: TextAlign.center,
                style: TextStyle(color: kCream, fontSize: 82, height: 1.02, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 5))])),
            const SizedBox(height: 18),
            if (started)
              Text('Bölüm ${game.chapter}: ${game.quests.chapterDef.title}', style: const TextStyle(color: Color(0xFFFFE9A8), fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            WoodButton(label: started ? (game.hasResumable ? 'DEVAM  (Gün ${game.day}, kaldığın yerden)' : 'DEVAM  (Gün ${game.day})') : 'BAŞLA', icon: Icons.play_arrow, big: true, color: const Color(0xFF2E7D5B), onTap: game.continueGame),
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
              WoodButton(label: 'Ayarlar', icon: Icons.settings, onTap: game.toggleSettings, color: const Color(0xFF6B5A4A)),
              if (game.leaderboard != null) WoodButton(label: 'Sıralama', icon: Icons.emoji_events, onTap: game.leaderboard!.toggle, color: const Color(0xFFB07A1E)),
              if (started)
                WoodButton(
                  label: 'Baştan başla',
                  icon: Icons.restart_alt,
                  onTap: () async {
                    await game.resetSave();
                  },
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ ayarlar
class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({super.key, required this.game});
  final GameController game;

  Widget _toggle(String title, String sub, bool on, VoidCallback onTap, {Key? key}) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: on ? const Color(0xFFFFE9A8) : Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: kWood, width: 3)),
          child: Row(children: [
            Icon(on ? Icons.check_circle : Icons.circle_outlined, size: 38, color: on ? const Color(0xFF2E7D5B) : kWoodDark),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kWood)),
                Text(sub, style: const TextStyle(fontSize: 19, color: Color(0xFF7A5A3A))),
              ]),
            ),
            Text(on ? 'AÇIK' : 'KAPALI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: on ? const Color(0xFF2E7D5B) : kWoodDark)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => _Dim(
        child: _Card(
          width: 760,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Ayarlar', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: kWood)),
            const Divider(height: 24, thickness: 2, color: kWood),
            _toggle('Rahat mod', 'Müşteriler %25 daha sabırlı. Acele yok, keyfine bak.', game.comfortMode, game.toggleComfort, key: const ValueKey('toggle-comfort')),
            _toggle('Ses efektleri', 'Zil, çıtırtı, para sesi…', game.soundOn, game.toggleSound, key: const ValueKey('toggle-sound')),
            const SizedBox(height: 10),
            WoodButton(label: 'Oynanışı göster', icon: Icons.school, onTap: game.replayTutorial, color: const Color(0xFF9A5B1E)),
            const SizedBox(height: 14),
            WoodButton(label: 'Tamam', icon: Icons.check, onTap: game.toggleSettings, color: const Color(0xFF2E7D5B)),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ kaybetme
/// Müşteri kaçırma hakkı bitti: reklam izleyip kaldığın yerden devam et ya da günü baştan başlat.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    final canRevive = game.canWatchAd('revive');
    return _Dim(
      opacity: 0.72,
      child: _Card(
        width: 820,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.heart_broken, size: 72, color: Color(0xFF9A3D2B)),
          const SizedBox(height: 6),
          const Text('Müşteriler küstü!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: kWood)),
          const SizedBox(height: 6),
          Text('Bugün ${game.lostToday} müşteri yetişemeden gitti; ${game.maxLives} hakkın bitti.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, color: kWoodDark)),
          const SizedBox(height: 4),
          Text('Reklam izlersen kaldığın yerden devam edersin: hakların yenilenir, bekleyen müşterilerin sabrı dolar.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Color(0xFF7A5A3A), fontStyle: FontStyle.italic)),
          const SizedBox(height: 22),
          Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 12, children: [
            WoodButton(label: 'Reklam izle, devam et', icon: Icons.smart_display, enabled: canRevive, onTap: () => game.startAd('revive'), color: const Color(0xFF2F7FA8), big: true),
            WoodButton(label: 'Günü baştan başla', icon: Icons.restart_alt, onTap: game.restartDay, color: const Color(0xFF9A5B1E), big: true),
          ]),
          if (!canRevive) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Bugünkü devam hakkını kullandın.', style: TextStyle(fontSize: 18, color: Color(0xFF9A3D2B)))),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ gün sonu
class DayEndOverlay extends StatelessWidget {
  const DayEndOverlay({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    Widget row(String l, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: 24, color: color ?? kWoodDark, fontWeight: bold ? FontWeight.w900 : FontWeight.w600))),
            Text(v, style: TextStyle(fontSize: 26, color: color ?? kWoodDark, fontWeight: FontWeight.w900)),
          ]),
        );
    final rep = (game.reputationToday * 100).round();
    return _Dim(
      child: _Card(
        width: 820,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Gün ${game.day - 1} bitti!', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: kWood)),
          if (game.usta != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${game.usta!.text}”', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: Color(0xFF9A5B1E)))),
          const Divider(height: 24, thickness: 2, color: kWood),
          row('Servis edilen', '${game.servedToday}'),
          row('Tam isabet', '${game.greatToday}'),
          row('Küsüp giden', '${game.lostToday}'),
          row('Memnuniyet', '%$rep'),
          const Divider(height: 18, thickness: 1, color: kWood),
          row('Kazanç', '+${game.earnedToday} ₺'),
          row('Bahşiş (kavanozdan)', '+${game.tipsToday} ₺'),
          if (game.deliveryActive) row('  (kazancın ${game.deliveredToday} paketten gelen kısmı)', '${game.deliveryIncomeToday} ₺'),
          row('Kira', '-${game.rentToday} ₺', color: const Color(0xFF9A3D2B)),
          row('Malzeme masrafı', '-${game.suppliesToday} ₺', color: const Color(0xFF9A3D2B)),
          if (game.wastedToday > 0) row('  (bunun çöpe/zarara giden kısmı)', '${game.wastedToday} ₺', color: const Color(0xFF9A3D2B)),
          if (game.penaltyToday > 0) row('Küsen müşteri cezası', '-${game.penaltyToday} ₺', color: const Color(0xFF9A3D2B)),
          if (game.stolenToday > 0) row('Kasadan çalınan', '-${game.stolenToday} ₺', color: const Color(0xFF9A3D2B)),
          const Divider(height: 18, thickness: 1, color: kWood),
          row('Günün net kârı', '${game.netToday >= 0 ? '+' : ''}${game.netToday} ₺', bold: true, color: game.netToday >= 0 ? const Color(0xFF2E7D5B) : const Color(0xFF9A3D2B)),
          row('Günün skoru', '${game.scoreToday}', bold: true),
          row('Kasa', '${game.money} ₺', bold: true),
          row('Elmas', '${game.diamonds}', color: const Color(0xFF2F7FA8)),
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 12, children: [
            WoodButton(label: 'Dükkân', icon: Icons.storefront, onTap: game.openShop, color: const Color(0xFF9A5B1E)),
            WoodButton(label: 'Reklam', icon: Icons.smart_display, onTap: game.openAdMenu, color: const Color(0xFF2F7FA8)),
            if (game.leaderboard != null) WoodButton(label: 'Sıralama', icon: Icons.emoji_events, onTap: game.leaderboard!.toggle, color: const Color(0xFFB07A1E)),
            if (game.gardenUnlocked) WoodButton(label: 'Bahçe', icon: Icons.yard, onTap: game.openGarden, color: const Color(0xFF5E8C3A)),
            if (game.caseUnlocked) WoodButton(label: 'Soruşturma', icon: Icons.search, onTap: game.openCase, color: const Color(0xFF5A3A7A)),
            WoodButton(label: 'Sonraki gün', icon: Icons.arrow_forward, onTap: game.startDay, color: const Color(0xFF2E7D5B)),
          ]),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ dükkân
class ShopOverlay extends StatelessWidget {
  const ShopOverlay({super.key, required this.game});
  final GameController game;
  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: _Card(
        width: 1380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Dükkânı güzelleştir', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: kWood))),
            Pill(text: '${game.diamonds}', icon: Icons.diamond, iconColor: kDiamond),
            const SizedBox(width: 10),
            Pill(text: '${game.money} ₺', icon: Icons.paid),
            const SizedBox(width: 10),
            GestureDetector(onTap: game.openAdMenu, child: const Pill(text: 'Reklam', icon: Icons.smart_display)),
          ]),
          if (game.usta != null) Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerLeft, child: Text('Usta: “${game.usta!.text}”', style: const TextStyle(fontSize: 19, fontStyle: FontStyle.italic, color: Color(0xFF9A5B1E))))),
          const Divider(height: 22, thickness: 2, color: kWood),
          SizedBox(
            height: 560,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: ListView(children: [
                  const _Section('Yükseltmeler'),
                  for (final u in game.cfg.upgrades) _UpgradeRow(game: game, u: u),
                ]),
              ),
              const VerticalDivider(width: 32, thickness: 2, color: kWood),
              Expanded(
                child: ListView(children: [
                  const _Section('Dükkân süsleri (kazancı da artırır)'),
                  for (final d in game.cfg.decor) _DecorRow(game: game, d: d),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          WoodButton(label: 'Sonraki gün', icon: Icons.arrow_forward, onTap: game.startDay, color: const Color(0xFF2E7D5B)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E))));
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.game, required this.u});
  final GameController game;
  final UpgradeDef u;
  @override
  Widget build(BuildContext context) {
    final lvl = game.level(u.id);
    final cost = game.nextCost(u);
    final locked = game.chapter < u.minChapter;
    final can = game.canAffordUpgrade(u);
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kWoodDark)),
              Text(locked ? 'Bölüm ${u.minChapter}\'de açılır' : u.desc, style: const TextStyle(fontSize: 17, color: Color(0xFF7A5A3A))),
              const SizedBox(height: 3),
              Row(children: [
                for (var i = 0; i < u.max; i++)
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < lvl ? const Color(0xFFE0A23B) : Colors.transparent, border: Border.all(color: kWood, width: 2.5)),
                  ),
              ]),
            ]),
          ),
          if (locked)
            const Icon(Icons.lock, color: kWood, size: 30)
          else if (cost == null)
            const Text('Tamam', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B)))
          else
            WoodButton(
              label: u.withDiamonds ? '$cost elmas' : '$cost ₺',
              icon: u.withDiamonds ? Icons.diamond : Icons.add_shopping_cart,
              enabled: can,
              onTap: () => game.buy(u),
              color: u.withDiamonds ? const Color(0xFF2F7FA8) : const Color(0xFF9A5B1E),
            ),
        ]),
      ),
    );
  }
}

class _DecorRow extends StatelessWidget {
  const _DecorRow({required this.game, required this.d});
  final GameController game;
  final DecorDef d;
  @override
  Widget build(BuildContext context) {
    final owned = game.decorOwned.contains(d.id);
    final locked = game.chapter < d.minChapter;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWoodDark)),
              Text(locked ? 'Bölüm ${d.minChapter}\'de açılır' : '${d.desc} · +%${(d.bonus * 100).round()} kazanç', style: const TextStyle(fontSize: 16, color: Color(0xFF7A5A3A))),
            ]),
          ),
          if (locked)
            const Icon(Icons.lock, color: kWood, size: 28)
          else if (owned)
            const Icon(Icons.check_circle, color: Color(0xFF2E7D5B), size: 34)
          else
            WoodButton(
              label: d.diamonds > 0 ? '${d.cost} ₺ + ${d.diamonds} elmas' : '${d.cost} ₺',
              icon: d.diamonds > 0 ? Icons.diamond : Icons.add_shopping_cart,
              enabled: game.money >= d.cost && game.diamonds >= d.diamonds,
              onTap: () => game.buyDecor(d),
              color: d.diamonds > 0 ? const Color(0xFF2F7FA8) : const Color(0xFF9A5B1E),
            ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Usta'nın Defteri
class NotebookOverlay extends StatelessWidget {
  const NotebookOverlay({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final q = game.quests;
    final main = q.mainQuest;
    return _Dim(
      child: _Card(
        width: 1180,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('Usta’nın Defteri  ·  Bölüm ${q.chapter}: ${q.allChaptersDone ? 'Hikâye tamam' : q.chapterDef.title}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kWood))),
            Pill(text: '${q.stars} yıldız', icon: Icons.star),
            const SizedBox(width: 10),
            Pill(text: '${q.karma} iyilik', icon: Icons.favorite),
          ]),
          if (!q.allChaptersDone) Align(alignment: Alignment.centerLeft, child: Text(q.chapterDef.subtitle, style: const TextStyle(fontSize: 20, color: Color(0xFF9A5B1E), fontStyle: FontStyle.italic))),
          const Divider(height: 22, thickness: 2, color: kWood),
          SizedBox(
            height: 520,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 6,
                child: ListView(children: [
                  const _Section('Ana görev'),
                  if (main != null) _QuestCard(state: main, big: true) else const Text('Bu bölümün görevleri bitti.', style: TextStyle(fontSize: 20, color: kWoodDark)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(q.allChaptersDone ? '' : 'Bölüm ilerlemesi: ${q.chapterIndexProgress}/${q.chapterDef.quests.length}', style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
                  ),
                  const SizedBox(height: 8),
                  const _Section('Yan görevler'),
                  if (q.sideQuests.isEmpty) const Text('Şimdilik yok.', style: TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
                  for (final s in q.sideQuests) _QuestCard(state: s),
                ]),
              ),
              const VerticalDivider(width: 32, thickness: 2, color: kWood),
              Expanded(
                flex: 5,
                child: ListView(children: [
                  const _Section('Bugünün görevleri'),
                  if (q.daily.isEmpty) const Text('Güne başlayınca görevler gelir.', style: TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
                  for (final d in q.daily) _DailyCard(d: d),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          WoodButton(label: 'Kapat', icon: Icons.close, onTap: game.toggleNotebook, color: const Color(0xFF9A5B1E)),
        ]),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.state, this.big = false});
  final QuestState state;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final d = state.def;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: big ? const Color(0xFFFFEFC2) : Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: kWood, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(d.title, style: TextStyle(fontSize: big ? 28 : 22, fontWeight: FontWeight.w900, color: kWoodDark))),
          Text('+${d.reward.money} ₺', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B))),
        ]),
        Text(d.desc, style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A))),
        const SizedBox(height: 6),
        for (var i = 0; i < d.objectives.length; i++) _ObjectiveBar(label: QuestEngine.describe(d.objectives[i]), value: state.progress[i], target: d.objectives[i].target),
      ]),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.d});
  final DailyQuest d;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: d.done ? const Color(0xFFD9F2D2) : Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: kWood, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (d.done) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: Color(0xFF2E7D5B))),
            Expanded(child: Text(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kWoodDark))),
            Text('+${d.money} ₺', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B))),
          ]),
          if (!d.done) _ObjectiveBar(label: '', value: d.progress, target: d.objective.target),
        ]),
      );
}

class _ObjectiveBar extends StatelessWidget {
  const _ObjectiveBar({required this.label, required this.value, required this.target});
  final String label;
  final int value;
  final int target;
  @override
  Widget build(BuildContext context) {
    final f = target == 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        if (label.isNotEmpty) SizedBox(width: 200, child: Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF7A5A3A)))),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
            child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: f, child: Container(decoration: BoxDecoration(color: const Color(0xFF59B65B), borderRadius: BorderRadius.circular(8))))),
          ),
        ),
        const SizedBox(width: 8),
        Text('${value.clamp(0, target)}/$target', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kWoodDark)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ hikâye sahnesi
class SceneOverlay extends StatelessWidget {
  const SceneOverlay({super.key, required this.game});
  final GameController game;

  static const _portraits = {'usta', 'cirak', 'rakip', 'nine', 'dayi', 'yatirimci', 'maskeli', 'itfaiyeci', 'antikaci'};

  @override
  Widget build(BuildContext context) {
    final line = game.currentSceneLine!;
    final hasPortrait = _portraits.contains(line.who);
    final who = kRoleLabels[line.who] ?? line.who.toUpperCase();
    final to = kRoleLabels[line.to] ?? line.to.toUpperCase();
    final isLast = game.sceneIndex >= game.sceneLines!.length - 1;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: game.advanceScene,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Stack(children: [
            if (hasPortrait)
              Positioned(left: 150, bottom: 170, width: 420, child: IgnorePointer(child: Image.asset('assets/sprites/${line.who}_normal.png'))),
            Positioned(
              left: 160,
              right: 160,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 22, 32, 22),
                decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(26), border: Border.all(color: kWood, width: 6), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)]),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(who, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF9A5B1E), letterSpacing: 1.2)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_right_alt, size: 28, color: Color(0xFF9A5B1E))),
                    Text(to, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B), letterSpacing: 1.2)),
                    const Spacer(),
                    Text('${game.sceneIndex + 1}/${game.sceneLines!.length}', style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A), fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(line.text, style: const TextStyle(fontSize: 30, height: 1.3, color: kWoodDark, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(isLast ? 'Tamam' : 'Devam', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B))),
                      const Icon(Icons.play_arrow, color: Color(0xFF2E7D5B), size: 26),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
