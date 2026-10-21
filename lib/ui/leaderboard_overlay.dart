import 'package:flutter/material.dart';

import '../leaderboard/leaderboard.dart';
import 'widgets.dart';

/// "Mahalle Sıralaması": ilk 20, kendi sıran, hafta / tüm zamanlar.
class LeaderboardOverlay extends StatefulWidget {
  const LeaderboardOverlay({super.key, required this.manager});
  final LeaderboardManager manager;
  @override
  State<LeaderboardOverlay> createState() => _LeaderboardOverlayState();
}

class _LeaderboardOverlayState extends State<LeaderboardOverlay> {
  bool _editing = false;
  late final TextEditingController _name = TextEditingController(text: widget.manager.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manager;
    final b = m.board;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            width: 900,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kWood, width: 6),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('Mahalle Sıralaması', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kWood))),
                _PeriodChip(label: 'Bu hafta', on: m.period == BoardPeriod.week, onTap: () => m.setPeriod(BoardPeriod.week)),
                const SizedBox(width: 10),
                _PeriodChip(label: 'Tüm zamanlar', on: m.period == BoardPeriod.all, onTap: () => m.setPeriod(BoardPeriod.all)),
              ]),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  b == null || m.loading
                      ? 'Yükleniyor…'
                      : b.offline
                          ? (m.hasRemote ? 'Sunucuya ulaşılamadı — yalnızca bu cihazdaki serilerin gösteriliyor.' : 'Çevrimdışı sıralama — yalnızca bu cihazdaki serilerin gösteriliyor.')
                          : 'Skorun her gün sonunda otomatik gönderilir.',
                  style: const TextStyle(fontSize: 18, color: Color(0xFF7A5A3A), fontStyle: FontStyle.italic),
                ),
              ),
              const Divider(height: 22, thickness: 2, color: kWood),
              SizedBox(
                height: 400,
                child: b == null
                    ? const SizedBox()
                    : b.entries.isEmpty
                        ? const Center(child: Text('Henüz kimse yok. İlk günü bitirince sen de burada olacaksın!', style: TextStyle(fontSize: 22, color: kWoodDark)))
                        : ListView(children: [
                            for (final e in b.entries) _Row(e: e),
                            if (b.me != null) ...[
                              const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('⋮', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: kWoodDark))),
                              _Row(e: b.me!),
                            ],
                          ]),
              ),
              const Divider(height: 22, thickness: 2, color: kWood),
              Row(children: [
                const Text('Takma adın:', style: TextStyle(fontSize: 22, color: kWoodDark, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                if (_editing)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: TextField(
                      key: const ValueKey('nick-field'),
                      controller: _name,
                      autofocus: true,
                      maxLength: 16,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(counterText: '', isDense: true),
                      onSubmitted: (_) => _save(),
                    ),
                    ),
                  )
                else
                  Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, color: kWood, fontWeight: FontWeight.w900))),
                const SizedBox(width: 12),
                WoodButton(label: _editing ? 'Kaydet' : 'Değiştir', icon: _editing ? Icons.check : Icons.edit, onTap: _editing ? _save : () => setState(() => _editing = true), color: const Color(0xFF9A5B1E)),
                const Spacer(),
                WoodButton(label: 'Kapat', icon: Icons.close, onTap: m.toggle),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _save() {
    widget.manager.setName(_name.text);
    setState(() => _editing = false);
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.on, required this.onTap});
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

class _Row extends StatelessWidget {
  const _Row({required this.e});
  final ScoreEntry e;
  @override
  Widget build(BuildContext context) {
    final medal = switch (e.rank) { 1 => const Color(0xFFD4A017), 2 => const Color(0xFF9AA0A6), 3 => const Color(0xFFB56A3A), _ => null };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: e.mine ? const Color(0xFFFFE9A8) : Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14), border: e.mine ? Border.all(color: kWood, width: 2) : null),
      child: Row(children: [
        SizedBox(
          width: 60,
          child: medal != null
              ? Icon(Icons.emoji_events, color: medal, size: 30)
              : Text('${e.rank}.', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kWoodDark)),
        ),
        Expanded(child: Text(e.mine ? '${e.name}  (sen)' : e.name, style: TextStyle(fontSize: 24, fontWeight: e.mine ? FontWeight.w900 : FontWeight.w700, color: kWoodDark))),
        Text('${e.days} gün', style: const TextStyle(fontSize: 20, color: Color(0xFF7A5A3A))),
        const SizedBox(width: 24),
        SizedBox(width: 130, child: Text('${e.score}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kWood))),
      ]),
    );
  }
}
