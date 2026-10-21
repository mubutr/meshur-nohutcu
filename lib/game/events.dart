import '../data/models.dart';

/// Oyun olayları: görev motoru (ve ileride istatistik/ses) bunları dinler.
sealed class GameEvent {
  const GameEvent();
}

class ServedEvent extends GameEvent {
  const ServedEvent({
    required this.verdict,
    required this.spec,
    required this.total,
    required this.patienceLeft,
    required this.customerId,
    this.tip = 0,
    this.streak = 0,
    this.special,
    this.riddleId,
    this.giver,
  });
  final Verdict verdict;
  final OrderSpec spec;
  final int total; // ücret + bahşiş
  final int tip;
  final int streak; // bu dürümden sonraki üst üste tam isabet sayısı
  final double patienceLeft;
  final String customerId;
  final String? special; // maskeli | bilmece (normal müşterinin bilmecesi) | nine | itfaiyeci …
  final String? riddleId;
  final String? giver; // bilmeceyi soran özel karakter
}

class CustomerLeftEvent extends GameEvent {
  const CustomerLeftEvent({required this.customerId, this.special});
  final String customerId;
  final String? special;
}

class DayEndedEvent extends GameEvent {
  const DayEndedEvent({required this.day, required this.served, required this.great, required this.lost, required this.earned, required this.tips, required this.netProfit, required this.score, required this.reputation});
  final int day, served, great, lost, earned, tips, netProfit, score;
  final double reputation; // 0..1 ortalama memnuniyet
}

class UpgradeBoughtEvent extends GameEvent {
  const UpgradeBoughtEvent(this.id, this.level);
  final String id;
  final int level;
}

class DecorBoughtEvent extends GameEvent {
  const DecorBoughtEvent(this.id);
  final String id;
}

class NpcHelpedEvent extends GameEvent {
  const NpcHelpedEvent(this.npcId);
  final String npcId;
}

class HarvestEvent extends GameEvent {
  const HarvestEvent(this.crop, this.amount);
  final String crop;
  final int amount;
}

class DeliveryEvent extends GameEvent {
  const DeliveryEvent({required this.onTime, required this.verdict});
  final bool onTime;
  final Verdict verdict;
}

class ClueEvent extends GameEvent {
  const ClueEvent(this.clueId);
  final String clueId;
}

/// Elmas kazanıldı (reklam, bonus müşteri, görev serisi…).
class DiamondEvent extends GameEvent {
  const DiamondEvent(this.amount, this.source);
  final int amount;
  final String source; // ad | bonus | streak | quest
}

/// Bahşiş kavanozu kasaya boşaltıldı.
class TipJarEvent extends GameEvent {
  const TipJarEvent(this.amount);
  final int amount;
}

class ChapterEvent extends GameEvent {
  const ChapterEvent(this.chapter);
  final int chapter;
}
