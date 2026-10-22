import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../dialog/antep_dialog.dart';
import '../audio/sfx.dart';
import '../leaderboard/leaderboard.dart';
import '../modes/delivery.dart';
import '../modes/detective.dart';
import '../modes/garden.dart';
import '../quest/quest_engine.dart';
import '../quest/quest_models.dart';
import 'events.dart';
import 'scoring.dart';

enum Phase { title, playing, dayEnd, shop, garden, detective, gameOver }

enum Mood { normal, happy, angry }

/// Sürüklenebilen malzeme türleri.
enum Ingredient { bread, main, piyaz, aci, fried, sumak, sauce }

enum CustomerState { greeting, waiting, reacting }

enum CustomerKind { normal, riddle, garip, maskeli, bonus, kurye }

/// Ekranda görünen tek konuşma: kim, kime, ne diyor.
class Speech {
  const Speech({required this.whoLabel, required this.toLabel, required this.text, this.toSlot, this.seq = 0});
  final String whoLabel; // "USTA", "MUSLU EMMİ"
  final String toLabel; // "ÇIRAK (SEN)", "USTA", "PENBE BACI"
  final String text;
  final int? toSlot; // usta bir müşteriye konuşuyorsa onun yuvası
  final int seq; // müşteri sözlerinin sıra numarası (en yenisi odaktaki balondur)
}

const String kCirakLabel = 'ÇIRAK (SEN)';

class Customer {
  Customer({
    required this.type,
    required this.name,
    required this.spec,
    required this.maxPatience,
    required this.order,
    this.kind = CustomerKind.normal,
    String? sprite,
    this.riddle,
    this.giver,
  }) : sprite = sprite ?? type.id;

  final CustomerType type;
  final CustomerName name;
  final OrderSpec spec;
  final double maxPatience;
  final DialogLine order; // tam sipariş cümlesi (ya da bilmece)
  final CustomerKind kind;
  final String sprite; // görsel öneki (fatma, maamed, dayi, nine …)
  final Riddle? riddle;
  final String? giver; // nine | itfaiyeci
  double patience = 0;
  CustomerState state = CustomerState.greeting;
  double stateTime = 0;
  Mood mood = Mood.normal;
  Speech? bubble;
  bool waitLineShown = false;
  int lastWaitStage = 0;
  int gain = 0; // servis sonrası kazanılan (ücret + bahşiş)
  bool orderRelayed = false;
  bool helperClaim = false;

  bool get free => kind == CustomerKind.garip;
  bool get hidesOrder => kind == CustomerKind.riddle;
  bool get isCourier => kind == CustomerKind.kurye;
  String get label => trUpper(name.ref);
  double get patienceFraction => maxPatience <= 0 ? 0 : (patience / maxPatience).clamp(0.0, 1.0);
}

class _QueuedSpeech {
  _QueuedSpeech(this.speech, this.seconds);
  final Speech speech;
  final double seconds;
}

/// Yardımcı Çırak'ın hazırladığı dürüm.
class HelperState {
  double progress = 0; // 0..1
  Assembly? ready;
}

/// Oyunun tüm durumu. Arayüz ChangeNotifier'ı dinler; zamanlayıcı 100 ms'de bir [tick] çağırır.
class GameController extends ChangeNotifier {
  GameController({
    required this.cfg,
    required this.dialog,
    required this.questData,
    required this.story,
    this.riddles = const [],
    this.detectiveData,
    Random? random,
    this.prefs,
    this.leaderboard,
    this.sfx,
    this.introEnabled = false,
    this.tutorialEnabled = false,
    this.gameOverEnabled = false,
  }) : _rnd = random ?? Random() {
    quests = QuestEngine(
      questData,
      onReward: _giveReward,
      upgradeLevel: level,
      decorCount: () => decorOwned.length,
      streakDays: cfg.eco('streakDays').round(),
      streakDiamonds: cfg.eco('streakDiamonds').round(),
    );
    delivery = DeliveryState(visibleCourier: true);
    selectedWrap = kDefaultWrap;
    listeners.add(quests.handle);
    listeners.add(_soundOnEvent);
    if (leaderboard != null) listeners.add(leaderboard!.handle);
    if (detectiveData != null) caseState = CaseState(detectiveData!);
  }

  final GameConfig cfg;
  final AntepDialog dialog;
  final QuestData questData;
  final StoryBook story;
  final List<Riddle> riddles;
  final DetectiveData? detectiveData;
  CaseState? caseState;
  final SharedPreferences? prefs;
  final LeaderboardManager? leaderboard;
  final Sfx? sfx;
  final Random _rnd;

  /// İlk oyunda oynanışı gösteren tanıtım (testlerde kapalı).
  final bool tutorialEnabled;
  bool tutorialDone = false;
  int tutorialStep = -1; // -1: kapalı
  bool _tutorialPending = false;
  bool get tutorialActive => tutorialStep >= 0;
  static const int tutorialStepCount = 7;

  void startTutorial() {
    if (phase != Phase.playing) return;
    tutorialStep = 0;
    notifyListeners();
  }

  void nextTutorial() {
    if (tutorialStep < 0) return;
    if (tutorialStep + 1 >= tutorialStepCount) {
      skipTutorial();
      return;
    }
    tutorialStep++;
    notifyListeners();
  }

  /// Ayarlardan "Oynanışı göster": sonraki oyun başlangıcında (ya da şimdi, oyun açıksa) tanıtım yeniden oynar.
  void replayTutorial() {
    tutorialDone = false;
    prefs?.setBool('tutorial_done', false);
    settingsOpen = false;
    if (phase == Phase.playing) {
      tutorialStep = 0;
    } else {
      _tutorialPending = true;
    }
    notifyListeners();
  }

  void skipTutorial() {
    tutorialStep = -1;
    tutorialDone = true;
    prefs?.setBool('tutorial_done', true);
    notifyListeners();
  }

  /// Kaybetme (müşteri hakkı biterse) etkin mi?
  final bool gameOverEnabled;

  // ------------------------------------------------------------- kaybetme ve reklamla devam
  int lives = 5; // bugünkü müşteri kaçırma hakkı
  bool reviveUsedToday = false;
  Map<String, dynamic>? _dayStartState;
  int get maxLives => cfg.eco('lives').round();

  /// Reklam izleyerek devam: canlar yenilenir, bekleyen müşterilerin sabrı dolar.
  void _revive() {
    lives = maxLives;
    reviveUsedToday = true;
    for (final c in slots.whereType<Customer>()) {
      if (c.state == CustomerState.waiting) c.patience = c.maxPatience;
    }
    phase = Phase.playing;
    _toCirak('usta_revive');
  }

  /// Gün başındaki duruma dönüp günü baştan başlatır (kasa, elmas, görev ilerlemesi dahil).
  void restartDay() {
    final d = _dayStartState;
    if (d != null) {
      money = d['money'] as int;
      diamonds = d['diamonds'] as int;
      tipJar = d['tipJar'] as int;
      servedSinceBonus = d['since'] as int;
      bonusDue = d['bonusDue'] as bool;
      try {
        garden.fromJsonString(d['garden'] as String);
        quests.fromJson((d['quests'] as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    startDay();
  }

  /// "Ya Fettah, Ya Rezzak" kepenk açılışı: her yeni gün başında oynar (testlerde kapalı).
  final bool introEnabled;
  double introLeft = 0;
  bool get introActive => introLeft > 0;

  void skipIntro() {
    if (introLeft <= 0) return;
    introLeft = 0;
    notifyListeners();
  }

  // ayarlar
  bool comfortMode = false; // rahat mod: müşteriler %25 daha sabırlı
  bool soundOn = true;
  bool settingsOpen = false;

  void _sfx(String name) {
    if (soundOn) sfx?.play(name);
  }

  void _soundOnEvent(GameEvent e) {
    if (e is ServedEvent) {
      _sfx(switch (e.verdict) { Verdict.great => 'great', Verdict.ok => 'ok', Verdict.bad => 'bad' });
    } else if (e is CustomerLeftEvent) {
      _sfx('bad');
    }
  }

  void toggleSettings() {
    settingsOpen = !settingsOpen;
    notifyListeners();
  }

  void toggleComfort() {
    comfortMode = !comfortMode;
    prefs?.setBool('comfort', comfortMode);
    notifyListeners();
  }

  void toggleSound() {
    soundOn = !soundOn;
    prefs?.setBool('sound', soundOn);
    if (soundOn) sfx?.play('pop');
    notifyListeners();
  }
  late final QuestEngine quests;

  /// Görev motoru, istatistikler vb. buraya abone olur.
  final List<void Function(GameEvent)> listeners = [];
  void emit(GameEvent e) {
    for (final l in List.of(listeners)) {
      l(e);
    }
  }

  Phase phase = Phase.title;
  int day = 1;
  int money = 0;
  int totalScore = 0; // tüm günlerin toplam puanı (sıralama sunucusuyla eşitlenir)
  int diamonds = 0; // ikinci para birimi: reklam, bonus müşteri, görev serisi
  int tipJar = 0; // bahşiş kavanozunda biriken (dokununca kasaya geçer)
  final Map<String, int> upgrades = {};
  final Set<String> decorOwned = {};
  bool investor = false;
  bool riddleIntroShown = false;

  // ürün seçimi ve sayaçlar (v3)
  late String selectedWrap; // tezgâhta hazırlanacak ürün
  int servedSinceBonus = 0; // normal servis sayacı (her bonusEvery'de bonus müşteri)
  bool bonusDue = false;
  int wastedToday = 0; // çöpe giden / karşılığı alınamayan malzeme parası
  int penaltyToday = 0; // küsen müşteri cezaları
  int adsMoneyToday = 0;
  int adsDiamondToday = 0;
  bool avansGivenToday = false;
  int _dayTotal = 1; // bugünkü toplam müşteri sayısı (gün saati için)
  double autoTimer = 0;
  bool recipeOpen = false;

  // gün durumu
  final int slotCount = 3;
  late List<Customer?> slots = List.filled(slotCount, null);
  int toSpawn = 0;
  double spawnTimer = 0;
  int servedToday = 0;
  int lostToday = 0;
  int earnedToday = 0;
  int tipsToday = 0;
  int greatToday = 0;
  int scoreToday = 0;
  int streak = 0;
  int suppliesToday = 0;
  int stolenToday = 0;
  int rentToday = 0;
  int netToday = 0;
  double _satSum = 0;
  int _satCount = 0;
  final Map<String, int> _specialsToday = {};
  /// Aynı anda 3 dürüm hazırlanabilir (sürükle-bırak ya da dokunma); [assembly] etkin tezgâhtır.
  static const int boardCount = 3;
  final List<Assembly> boards = List.generate(boardCount, (_) => Assembly());
  int activeBoard = 0;
  Assembly get assembly => boards[activeBoard];

  void selectBoard(int i) {
    if (i < 0 || i >= boardCount || i == activeBoard) return;
    activeBoard = i;
    notifyListeners();
  }

  bool get anyBoardEmpty => boards.any((b) => b.isEmpty);
  bool get anyBoardWrapped => boards.any((b) => b.wrapped);
  final HelperState helper = HelperState();
  late final GardenState garden = GardenState(cfg.garden);
  late final DeliveryState delivery;
  int deliveredToday = 0;
  int deliveryIncomeToday = 0;
  bool get deliveryActive => chapter >= 4;
  bool get gardenUnlocked => chapter >= 4;
  int get plotCount => cfg.garden.plotsBase + level('parsel');

  // konuşma
  Speech? usta; // şu an ekranda olan usta balonu
  double _ustaTimer = 0;
  final List<_QueuedSpeech> _ustaQueue = [];
  String hint = '';
  Timer? _timer;

  // sahne (hikâye) ve defter
  List<DialogLine>? sceneLines;
  int sceneIndex = 0;
  String? sceneId;
  bool notebookOpen = false;
  QuestToast? toast;
  double _toastTimer = 0;

  String get ustaText => usta?.text ?? '';
  double get reputationToday => _satCount == 0 ? 0 : _satSum / _satCount;
  int get chapter => quests.chapter;
  bool get paused => sceneLines != null || notebookOpen || recipeOpen || adKind != null || adMenuOpen || introActive || tutorialActive;

  /// Mekân teması (bölümle lüksleşir): t1 esnaf · t2 çarşı · t3 lokanta · t4 saray sofrası.
  String get theme => chapter >= 5 ? 't4' : (chapter == 4 ? 't3' : (chapter >= 2 ? 't2' : 't1'));

  // ------------------------------------------------------------- ödül / kayıt
  void _giveReward(QuestReward r, String source) {
    money += r.money;
    if (r.diamonds > 0) {
      diamonds += r.diamonds;
      emit(DiamondEvent(r.diamonds, source));
    }
    if (r.investor) investor = true;
    if (r.flag != null) quests.flags.add(r.flag!);
    save();
  }

  void load() {
    final p = prefs;
    if (p == null) {
      quests.load(null);
      return;
    }
    day = p.getInt('day') ?? 1;
    money = p.getInt('money') ?? 0;
    totalScore = p.getInt('totalScore') ?? 0;
    diamonds = p.getInt('diamonds') ?? 0;
    tipJar = p.getInt('tipJar') ?? 0;
    servedSinceBonus = p.getInt('sinceBonus') ?? 0;
    bonusDue = p.getBool('bonusDue') ?? false;
    selectedWrap = p.getString('wrap') ?? kDefaultWrap;
    investor = p.getBool('investor') ?? false;
    hasResumable = p.getString(_snapKey) != null;
    comfortMode = p.getBool('comfort') ?? false;
    tutorialDone = p.getBool('tutorial_done') ?? false;
    soundOn = p.getBool('sound') ?? true;
    riddleIntroShown = p.getBool('riddleIntro') ?? false;
    for (final u in cfg.upgrades) {
      upgrades[u.id] = p.getInt('up_${u.id}') ?? 0;
    }
    decorOwned
      ..clear()
      ..addAll(p.getStringList('decor') ?? const []);
    final g = p.getString('garden');
    if (g != null) {
      try {
        garden.fromJsonString(g);
      } catch (_) {}
    }
    final cs = p.getString('case');
    if (cs != null && caseState != null) {
      try {
        caseState!.fromJsonString(cs);
      } catch (_) {}
    }
    quests.load(p);
  }

  // ------------------------------------------------------------- gün ortası kaydı (kapatıp açınca kaldığın yerden)
  static const String _snapKey = 'day_snapshot';
  bool hasResumable = false; // kayıtlı yarım gün var mı
  double _snapTimer = 0;

  Map<String, dynamic> _customerJson(int slot, Customer c) => {
        'slot': slot,
        'type': c.type.id,
        'name': {'n': c.name.n, 'ref': c.name.ref, 'dat': c.name.dat, 'hitap': c.name.hitap},
        'kind': c.kind.name,
        'sprite': c.sprite,
        'spec': c.spec.toJson(),
        'order': c.order.text,
        'maxP': c.maxPatience,
        'p': c.patience,
        'st': c.state.name,
        'riddle': c.riddle?.id,
        'giver': c.giver,
        'mood': c.mood.name,
        'relayed': c.orderRelayed,
        'claim': c.helperClaim,
      };

  Customer? _customerFrom(Map<String, dynamic> m) {
    final type = cfg.customers.firstWhere((t) => t.id == m['type'], orElse: () => cfg.customers.first);
    final nm = m['name'] as Map<String, dynamic>;
    final kind = CustomerKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => CustomerKind.normal);
    Riddle? riddle;
    if (m['riddle'] != null) riddle = riddles.where((r) => r.id == m['riddle']).firstOrNull;
    final c = Customer(
      type: type,
      name: CustomerName(n: nm['n'] as String, ref: nm['ref'] as String, dat: nm['dat'] as String, hitap: nm['hitap'] as String?),
      spec: OrderSpec.fromJson(m['spec'] as Map<String, dynamic>),
      maxPatience: (m['maxP'] as num).toDouble(),
      order: DialogLine(who: 'musteri', to: 'usta', text: m['order'] as String),
      kind: kind,
      sprite: m['sprite'] as String?,
      riddle: riddle,
      giver: m['giver'] as String?,
    )
      ..patience = (m['p'] as num).toDouble()
      ..orderRelayed = true
      ..helperClaim = (m['claim'] as bool?) ?? false;
    c.state = m['st'] == 'reacting' ? CustomerState.reacting : CustomerState.waiting;
    if (c.state == CustomerState.reacting) return null; // giden müşteri geri çağrılmaz
    c.bubble = _customerSays(c, c.order);
    return c;
  }

  Map<String, dynamic> toDaySnapshot() => {
        'v': 1,
        'day': day,
        'toSpawn': toSpawn,
        'dayTotal': _dayTotal,
        'spawnTimer': spawnTimer,
        'served': servedToday,
        'lost': lostToday,
        'earned': earnedToday,
        'tips': tipsToday,
        'great': greatToday,
        'score': scoreToday,
        'streak': streak,
        'supplies': suppliesToday,
        'stolen': stolenToday,
        'wasted': wastedToday,
        'penalty': penaltyToday,
        'adsM': adsMoneyToday,
        'adsD': adsDiamondToday,
        'avans': avansGivenToday,
        'satSum': _satSum,
        'satCount': _satCount,
        'specials': _specialsToday,
        'delivered': deliveredToday,
        'deliveryIncome': deliveryIncomeToday,
        'wrap': selectedWrap,
        'active': activeBoard,
        'lives': lives,
        'reviveUsed': reviveUsedToday,
        'boards': [for (final b in boards) b.toJson()],
        'customers': [
          for (var i = 0; i < slots.length; i++)
            if (slots[i] != null && slots[i]!.state != CustomerState.reacting) _customerJson(i, slots[i]!)
        ],
        'helper': {'progress': helper.progress, 'ready': helper.ready?.toJson()},
        'delivery': delivery.toJson(),
        'dayStart': _dayStartState,
      };

  /// Kayıtlı yarım günü geri yükler. Başarısızsa false döner (o zaman yeni gün başlatılır).
  bool restoreDaySnapshot(Map<String, dynamic> j) {
    try {
      if (j['day'] != day) return false;
      phase = Phase.playing;
      toSpawn = j['toSpawn'] as int;
      _dayTotal = j['dayTotal'] as int;
      spawnTimer = (j['spawnTimer'] as num).toDouble();
      servedToday = j['served'] as int;
      lostToday = j['lost'] as int;
      earnedToday = j['earned'] as int;
      tipsToday = j['tips'] as int;
      greatToday = j['great'] as int;
      scoreToday = j['score'] as int;
      streak = j['streak'] as int;
      suppliesToday = j['supplies'] as int;
      stolenToday = j['stolen'] as int;
      wastedToday = j['wasted'] as int;
      penaltyToday = j['penalty'] as int;
      adsMoneyToday = j['adsM'] as int;
      adsDiamondToday = j['adsD'] as int;
      avansGivenToday = j['avans'] as bool;
      _satSum = (j['satSum'] as num).toDouble();
      _satCount = j['satCount'] as int;
      _specialsToday
        ..clear()
        ..addAll((j['specials'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)));
      deliveredToday = j['delivered'] as int;
      deliveryIncomeToday = j['deliveryIncome'] as int;
      selectedWrap = (j['wrap'] as String?) ?? kDefaultWrap;
      activeBoard = (j['active'] as int?) ?? 0;
      lives = (j['lives'] as int?) ?? cfg.eco('lives').round();
      reviveUsedToday = (j['reviveUsed'] as bool?) ?? false;
      final bs = (j['boards'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < boardCount; i++) {
        boards[i]
          ..reset()
          ..wrap = kDefaultWrap;
        if (i < bs.length) {
          final a = Assembly.fromJson(bs[i]);
          boards[i]
            ..wrap = a.wrap
            ..bread = a.bread
            ..nohut = a.nohut
            ..piyaz = a.piyaz
            ..aci = a.aci
            ..sumak = a.sumak
            ..fried = a.fried
            ..sauces.addAll(a.sauces)
            ..wrapped = a.wrapped
            ..spent = a.spent;
        }
      }
      slots = List.filled(slotCount, null);
      for (final m in (j['customers'] as List).cast<Map<String, dynamic>>()) {
        final c = _customerFrom(m);
        final slot = m['slot'] as int;
        if (c != null && slot < slotCount) slots[slot] = c;
      }
      final h = j['helper'] as Map<String, dynamic>;
      helper
        ..progress = (h['progress'] as num).toDouble()
        ..ready = h['ready'] == null ? null : Assembly.fromJson(h['ready'] as Map<String, dynamic>);
      delivery.fromJson(j['delivery'] as Map<String, dynamic>);
      _dayStartState = (j['dayStart'] as Map?)?.cast<String, dynamic>();
      usta = null;
      _ustaQueue.clear();
      introLeft = 0;
      tutorialStep = -1;
      _toCirak('usta_day_start');
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick(0.1));
      hasResumable = false;
      if (gameOverEnabled && lives <= 0) phase = Phase.gameOver;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// "BAŞLA / DEVAM": kayıtlı yarım gün varsa onu sürdürür, yoksa yeni gün başlatır.
  void continueGame() {
    final raw = prefs?.getString(_snapKey);
    if (raw != null && hasResumable) {
      try {
        if (restoreDaySnapshot(jsonDecode(raw) as Map<String, dynamic>)) return;
      } catch (_) {}
    }
    hasResumable = false;
    startDay();
  }

  void _writeSnapshot() {
    final p = prefs;
    if (p == null) return;
    if (phase == Phase.playing || phase == Phase.gameOver || (phase == Phase.title && hasResumable)) {
      if (phase != Phase.title) p.setString(_snapKey, jsonEncode(toDaySnapshot()));
    } else {
      p.remove(_snapKey);
    }
  }

  Future<void> save() async {
    final p = prefs;
    if (p == null) return;
    _writeSnapshot();
    await p.setInt('day', day);
    await p.setInt('money', money);
    await p.setInt('totalScore', totalScore);
    await p.setInt('diamonds', diamonds);
    await p.setInt('tipJar', tipJar);
    await p.setInt('sinceBonus', servedSinceBonus);
    await p.setBool('bonusDue', bonusDue);
    await p.setString('wrap', selectedWrap);
    await p.setBool('investor', investor);
    await p.setBool('riddleIntro', riddleIntroShown);
    for (final e in upgrades.entries) {
      await p.setInt('up_${e.key}', e.value);
    }
    await p.setStringList('decor', decorOwned.toList());
    await p.setString('garden', garden.toJsonString());
    if (caseState != null) await p.setString('case', caseState!.toJsonString());
    await quests.save(p);
  }

  /// Sıralama sunucusundaki yönetim sayfasından gelen düzenleme (test amaçlı): oyunda anında görünür.
  void applyRemotePatch({int? money, int? diamonds, int? day, int? totalScore}) {
    if (money != null) this.money = max(0, money);
    if (diamonds != null) this.diamonds = max(0, diamonds);
    if (day != null && day >= 1) this.day = day;
    if (totalScore != null) this.totalScore = max(0, totalScore);
    save();
    notifyListeners();
  }

  Future<void> resetSave() async {
    prefs?.remove(_snapKey);
    hasResumable = false;
    day = 1;
    money = 0;
    totalScore = 0;
    diamonds = 0;
    tipJar = 0;
    servedSinceBonus = 0;
    bonusDue = false;
    selectedWrap = kDefaultWrap;
    investor = false;
    riddleIntroShown = false;
    upgrades.clear();
    decorOwned.clear();
    garden.plots.clear();
    garden.stock.updateAll((k, v) => 0);
    caseState?.reset();
    quests.startNewGame();
    await save();
    notifyListeners();
  }

  int level(String id) => upgrades[id] ?? 0;
  double _bonus(String id) => cfg.upgrades.firstWhere((u) => u.id == id).perLevel * level(id);
  double get patienceMul => 1 + _bonus('sabir') + (comfortMode ? 0.25 : 0);
  double get tipMul => 1 + _bonus('bahsis');
  double get decorBonus => cfg.decor.where((d) => decorOwned.contains(d.id)).fold(0.0, (a, d) => a + d.bonus);
  double get payMul => 1 + _bonus('tezgah') + decorBonus + (investor ? cfg.eco('investorBonus') : 0);
  bool get sumakUnlocked => chapter >= 2;
  bool get friedUnlocked => cfg.friedUnlocked(chapter);
  List<ProductDef> get products => cfg.unlockedProducts(chapter);
  List<SauceDef> get sauces => cfg.unlockedSauces(chapter);
  ProductDef get selectedProduct => cfg.product(selectedWrap);

  // ------------------------------------------------------------- konuşma altyapısı
  /// Ustanın konuşmasını sıraya koyar (aynı anda tek usta balonu).
  void ustaSays(String category, {required String toLabel, int? toSlot, Map<String, String> vars = const {}}) {
    final line = dialog.say(category, vars: vars);
    if (line.text.isEmpty) return;
    final secs = (2.6 + line.text.length * 0.045).clamp(3.0, 7.0);
    _ustaQueue.add(_QueuedSpeech(Speech(whoLabel: 'USTA', toLabel: toLabel, text: line.text, toSlot: toSlot), secs));
    while (_ustaQueue.length > 4) {
      _ustaQueue.removeAt(0);
    }
  }

  void _toCirak(String category, {Map<String, String> vars = const {}}) => ustaSays(category, toLabel: kCirakLabel, vars: vars);

  void _tickUsta(double dt) {
    if (usta != null) {
      _ustaTimer -= dt;
      if (_ustaTimer <= 0) usta = null;
    }
    if (usta == null && _ustaQueue.isNotEmpty) {
      final q = _ustaQueue.removeAt(0);
      usta = q.speech;
      _ustaTimer = q.seconds;
    }
  }

  Map<String, String> _vars(Customer c) => {
        'hitap': c.name.hitap,
        'ad': c.name.ref,
        'adDat': c.name.dat,
        'ustaHitap': c.type.ustaHitap,
      };

  /// Ustanın çırağa ilettiği kısa özet: "nohut dürümü: nohut orta, piyazlı, acısız, sumaklı".
  String specSummary(OrderSpec s) {
    final p = cfg.product(s.wrap);
    final amount = s.nohut <= 1 ? 'az' : (s.nohut == 2 && p.maxAmount > 2 ? 'orta' : (s.nohut >= 2 ? 'bol' : 'az'));
    final parts = <String>[p.maxAmount == 1 ? p.fillName : '${p.fillName} $amount'];
    if (p.allows('piyaz')) parts.add(s.piyaz ? 'piyazlı' : 'piyazsız');
    if (p.allows('aci')) parts.add(s.aci ? 'acılı' : 'acısız');
    if (friedUnlocked && p.allows('fried')) parts.add(s.fried ? 'kızartmalı' : 'kızartmasız');
    if (sauces.isNotEmpty && p.allows('sauce')) {
      final names = [for (final sc in sauces) if (s.allSauces.contains(sc.id)) sc.name.toLowerCase()];
      parts.add(names.isEmpty ? 'sossuz' : 'soslar: ${names.join(', ')}');
    }
    return '${p.name.toLowerCase()}: ${parts.join(', ')}';
  }

  Speech _customerSays(Customer c, DialogLine l) => Speech(whoLabel: c.label, toLabel: 'USTA', text: l.text, seq: ++_custSeq);

  // Birden çok müşteri konuşurken yalnızca biri tam balonla gösterilir (diğerleri sipariş çipleriyle).
  int _custSeq = 0;
  int? _pinnedSlot; // oyuncunun dokunarak seçtiği müşteri
  int _pinnedAt = 0;

  /// Tam konuşma balonunu gösterilecek müşterinin yuvası: dokunulan, yoksa en son konuşan.
  int? get focusSlot {
    final p = _pinnedSlot;
    if (p != null && _pinnedAt == _custSeq && slots[p]?.bubble != null) return p;
    int? best;
    var bestSeq = -1;
    for (var i = 0; i < slots.length; i++) {
      final b = slots[i]?.bubble;
      if (b != null && b.seq >= bestSeq) {
        best = i;
        bestSeq = b.seq;
      }
    }
    return best;
  }

  // ------------------------------------------------------------- sahneler (hikâye)
  void _openNextScene() {
    while (quests.pendingScenes.isNotEmpty) {
      final id = quests.pendingScenes.removeAt(0);
      final lines = story.scene(id);
      if (lines.isEmpty) continue;
      sceneId = id;
      sceneLines = lines;
      sceneIndex = 0;
      return;
    }
  }

  DialogLine? get currentSceneLine => sceneLines == null ? null : sceneLines![sceneIndex];

  void advanceScene() {
    if (sceneLines == null) return;
    sceneIndex++;
    if (sceneIndex >= sceneLines!.length) {
      sceneLines = null;
      sceneId = null;
      _openNextScene();
      save();
    }
    notifyListeners();
  }

  void toggleNotebook() {
    notebookOpen = !notebookOpen;
    if (notebookOpen) quests.unseenChange = false;
    notifyListeners();
  }

  // ------------------------------------------------------------- akış
  void startDay() {
    phase = Phase.playing;
    slots = List.filled(slotCount, null);
    toSpawn = cfg.customersForDay(day);
    _dayTotal = toSpawn;
    spawnTimer = 1.5;
    servedToday = lostToday = earnedToday = tipsToday = greatToday = scoreToday = streak = 0;
    suppliesToday = stolenToday = rentToday = netToday = wastedToday = penaltyToday = 0;
    adsMoneyToday = adsDiamondToday = 0;
    avansGivenToday = false;
    autoTimer = 0;
    if (selectedProduct.minChapter > chapter) selectedWrap = kDefaultWrap;
    if (money < cfg.eco('avans')) {
      money = cfg.eco('avans').round();
      avansGivenToday = true;
    }
    _specialsToday.clear();
    _satSum = 0;
    _satCount = 0;
    for (final b in boards) {
      b.reset();
    }
    activeBoard = 0;
    helper
      ..progress = 0
      ..ready = null;
    deliveredToday = deliveryIncomeToday = 0;
    garden.endOfDay(); // dün gece sulananlar büyür, sulanmayanlar susuz kalır
    garden.ensurePlots(plotCount);
    if (deliveryActive) delivery.reset(level('dagitim'));
    hint = '';
    usta = null;
    _ustaQueue.clear();
    quests.onDayStart(day);
    _openNextScene();
    _toCirak(day == 1 && !quests.done.contains('c1q1') ? 'usta_intro' : 'usta_day_start');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick(0.1));
    lives = cfg.eco('lives').round();
    reviveUsedToday = false;
    _dayStartState = {
      'money': money,
      'diamonds': diamonds,
      'tipJar': tipJar,
      'since': servedSinceBonus,
      'bonusDue': bonusDue,
      'garden': garden.toJsonString(),
      'quests': quests.toJson(),
    };
    hasResumable = false;
    if (tutorialEnabled && !tutorialDone) _tutorialPending = true;
    if (introEnabled) {
      introLeft = cfg.eco('introSeconds');
      _sfx('kepenk.wav');
      _sfx('yafettah.mp3');
    }
    notifyListeners();
  }

  ProductDef _pickProduct() {
    final list = products;
    // yeni açılan ürün iki kat sık çıkar (öğrenme)
    int weightOf(ProductDef p) => p.weight * (p.minChapter == chapter && p.minChapter > 1 ? 2 : 1);
    final total = list.fold<int>(0, (a, p) => a + weightOf(p));
    var r = _rnd.nextInt(total);
    for (final p in list) {
      r -= weightOf(p);
      if (r < 0) return p;
    }
    return list.first;
  }

  OrderSpec _newSpec() {
    final d = cfg.difficultyFor(day);
    final p = _pickProduct();
    final amount = 1 + _rnd.nextInt(min(d.maxNohut, p.maxAmount));
    final picked = <String>{};
    if (p.allows('sauce')) {
      for (final sc in sauces) {
        if (sc.id == 'sumak') continue;
        if (picked.length < 2 && _rnd.nextDouble() < cfg.eco('sauceChance')) picked.add(sc.id);
      }
    }
    return OrderSpec(
      wrap: p.id,
      nohut: amount,
      piyaz: p.allows('piyaz') && _rnd.nextDouble() < d.piyazChance,
      aci: p.allows('aci') && _rnd.nextDouble() < d.aciChance,
      sumak: p.allows('sumak') && _rnd.nextDouble() < cfg.sumakChance(chapter),
      fried: p.allows('fried') && friedUnlocked && _rnd.nextDouble() < cfg.eco('friedChance'),
      sauces: picked,
    );
  }

  /// Ağırlıklı müşteri seçimi; şu an ekranda olan kişiler (aynı ad/görünüm) tekrar seçilmez.
  CustomerType _pickType() {
    final used = slots.whereType<Customer>().map((c) => c.type.id).toSet();
    final pool = cfg.customers.where((c) => !used.contains(c.id)).toList();
    final list = pool.isEmpty ? cfg.customers : pool;
    final total = list.fold<int>(0, (a, c) => a + c.weight);
    var r = _rnd.nextInt(total);
    for (final c in list) {
      r -= c.weight;
      if (r < 0) return c;
    }
    return list.first;
  }

  CustomerName _pickName(CustomerType t) {
    final used = slots.whereType<Customer>().map((c) => c.name.n).toSet();
    final free = t.names.where((n) => !used.contains(n.n)).toList();
    final pool = free.isEmpty ? t.names : free;
    return pool[_rnd.nextInt(pool.length)];
  }

  /// Müşterinin söyleyeceği tam sipariş cümlesi (tek tonda, spec'in her özelliğini anar).
  DialogLine orderLine(OrderSpec s) => dialog.composeOrder(
        s,
        product: cfg.product(s.wrap),
        friedOn: friedUnlocked,
        sauceIds: [for (final sc in sauces) sc.id],
      );

  Riddle? _pickRiddle(String? giver) {
    final pool = riddles.where((r) => r.minChapter <= chapter && r.giver == giver).toList();
    if (pool.isEmpty) return null;
    return pool[_rnd.nextInt(pool.length)];
  }

  bool _specialAlive(String kind) => slots.whereType<Customer>().any((c) => c.sprite == _spriteOfKind(kind));
  String _spriteOfKind(String kind) => cfg.specials.firstWhere((s) => s.kind == kind).sprite;

  static const CustomerName _gezginName = CustomerName(n: 'Gezgin', ref: 'Gezgin', dat: 'Gezgine', hitap: 'gezgin');
  static const CustomerName _kuryeName = CustomerName(n: 'Kurye', ref: 'Kurye', dat: 'Kuryeye', hitap: 'kurye');

  Customer _makeBonus() {
    final t = _pickType();
    final spec = _newSpec();
    bonusDue = false;
    servedSinceBonus = 0;
    return Customer(
      type: t,
      name: _gezginName,
      spec: spec,
      maxPatience: cfg.patienceForDay(day) * 1.6 * patienceMul,
      order: orderLine(spec),
      kind: CustomerKind.bonus,
      sprite: 'gezgin',
    );
  }

  Customer _makeCourier() => Customer(
        type: cfg.customers.first,
        name: _kuryeName,
        spec: const OrderSpec(nohut: 1, piyaz: false, aci: false),
        maxPatience: DeliveryState.courierWaitSeconds,
        order: dialog.say('kurye_ask'),
        kind: CustomerKind.kurye,
        sprite: 'kurye',
      );

  Customer _makeCustomer() {
    if (bonusDue && !slots.whereType<Customer>().any((c) => c.kind == CustomerKind.bonus)) return _makeBonus();
    // özel müşteri mi?
    for (final s in cfg.specials) {
      if (chapter < s.minChapter) continue;
      if ((_specialsToday[s.kind] ?? 0) >= s.maxPerDay) continue;
      if (_specialAlive(s.kind)) continue;
      if (_rnd.nextDouble() >= s.chance) continue;
      final type = _pickType();
      switch (s.kind) {
        case 'garip':
          _specialsToday[s.kind] = (_specialsToday[s.kind] ?? 0) + 1;
          return Customer(
            type: type,
            name: s.name,
            spec: const OrderSpec(nohut: 1, piyaz: false, aci: false),
            maxPatience: cfg.patienceForDay(day) * s.patience * patienceMul,
            order: dialog.say('garip_ask'),
            kind: CustomerKind.garip,
            sprite: s.sprite,
          );
        case 'maskeli':
          _specialsToday[s.kind] = (_specialsToday[s.kind] ?? 0) + 1;
          final spec = _newSpec();
          return Customer(
            type: type,
            name: s.name,
            spec: spec,
            maxPatience: cfg.patienceForDay(day) * s.patience * patienceMul,
            order: orderLine(spec),
            kind: CustomerKind.maskeli,
            sprite: s.sprite,
          );
        default: // nine, itfaiyeci: bilmece sorarlar
          final r = _pickRiddle(s.kind);
          if (r == null) continue;
          _specialsToday[s.kind] = (_specialsToday[s.kind] ?? 0) + 1;
          return Customer(
            type: type,
            name: s.name,
            spec: r.spec,
            maxPatience: cfg.patienceForDay(day) * s.patience * patienceMul,
            order: DialogLine(who: 'musteri', to: 'usta', text: r.text),
            kind: CustomerKind.riddle,
            sprite: s.sprite,
            riddle: r,
            giver: s.kind,
          );
      }
    }
    final t = _pickType();
    final maxP = cfg.patienceForDay(day) * t.patience * patienceMul;
    // sıradan müşteri de bazen bilmece sorar (Bölüm 2+)
    if (chapter >= 2 && _rnd.nextDouble() < 0.18) {
      final r = _pickRiddle(null);
      if (r != null) {
        return Customer(
          type: t,
          name: _pickName(t),
          spec: r.spec,
          maxPatience: maxP * 1.25,
          order: DialogLine(who: 'musteri', to: 'usta', text: r.text),
          kind: CustomerKind.riddle,
          riddle: r,
        );
      }
    }
    final spec = _newSpec();
    return Customer(type: t, name: _pickName(t), spec: spec, maxPatience: maxP, order: orderLine(spec));
  }

  void _spawn(int slot) {
    final c = _makeCustomer();
    c.patience = c.maxPatience;
    slots[slot] = c;
    toSpawn--;
    _sfx('bell');
    ustaSays(_greetCategory(c), toLabel: c.label, toSlot: slot, vars: _vars(c));
  }

  String _greetCategory(Customer c) => switch (c.kind) {
        CustomerKind.garip => 'garip_greet',
        CustomerKind.maskeli => 'maskeli_greet',
        CustomerKind.bonus => 'bonus_greet',
        CustomerKind.kurye => 'kurye_greet',
        _ => 'greet_usta',
      };

  /// Kurye kapıya geldi: boş bir yuvaya yerleşir ([delivery.courierHere]).
  void _spawnCourier(int slot) {
    final c = _makeCourier();
    c.patience = c.maxPatience;
    slots[slot] = c;
    _sfx('bell');
    ustaSays(_greetCategory(c), toLabel: c.label, toSlot: slot);
  }

  /// 0..1: günün ilerleyişi (müşterilerin ne kadarı gelip gitti).
  double get dayProgress {
    if (phase == Phase.title) return 0;
    if (phase == Phase.dayEnd || phase == Phase.shop || phase == Phase.garden || phase == Phase.detective) return 1;
    final remaining = toSpawn + slots.whereType<Customer>().where((c) => !c.isCourier).length;
    return (1 - remaining / max(1, _dayTotal)).clamp(0.0, 1.0);
  }

  /// Gün saati: 07:00 → 23:00.
  int get clockMinutes => (7 * 60 + dayProgress * 16 * 60).round();
  String get clockText => '${(clockMinutes ~/ 60).toString().padLeft(2, '0')}:${(clockMinutes % 60).toString().padLeft(2, '0')}';

  void tick(double dt) {
    // açılış (kepenk) geri sayımı
    if (introLeft > 0) {
      introLeft = max(0, introLeft - dt);
      notifyListeners();
    }
    if (_tutorialPending && introLeft <= 0 && sceneLines == null && phase == Phase.playing) {
      _tutorialPending = false;
      tutorialStep = 0;
      notifyListeners();
    }
    // reklam geri sayımı
    if (adKind != null) {
      adLeft -= dt;
      if (adLeft <= 0) _grantAd();
      notifyListeners();
    }
    // bildirim zamanlayıcısı duraklamada da işler
    if (toast != null) {
      _toastTimer -= dt;
      if (_toastTimer <= 0) toast = null;
    }
    if (toast == null && quests.toasts.isNotEmpty) {
      toast = quests.toasts.removeAt(0);
      _toastTimer = 3.4;
      _sfx('quest');
    }
    if (phase != Phase.playing || paused) {
      if (toast != null || quests.toasts.isNotEmpty) notifyListeners();
      return;
    }
    _tickUsta(dt);
    _snapTimer += dt;
    if (_snapTimer >= 3) {
      _snapTimer = 0;
      _writeSnapshot();
    }

    // yeni müşteri
    if (toSpawn > 0) {
      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        final free = [for (var i = 0; i < slotCount; i++) if (slots[i] == null) i];
        if (free.isNotEmpty) {
          _spawn(free[_rnd.nextInt(free.length)]);
          spawnTimer = cfg.spawnGapForDay(day) * (0.8 + _rnd.nextDouble() * 0.4);
        } else {
          spawnTimer = 1.0;
        }
      }
    }

    for (var i = 0; i < slotCount; i++) {
      final c = slots[i];
      if (c == null) continue;
      c.stateTime += dt;
      switch (c.state) {
        case CustomerState.greeting:
          // 0–1.8 sn: usta karşılar; 1.8–3.4 sn: müşteri cevap verir; sonra siparişini söyler
          if (c.stateTime > 1.8 && c.stateTime <= 3.4 && c.kind != CustomerKind.garip && !c.isCourier) {
            c.bubble ??= _customerSays(c, dialog.say(c.kind == CustomerKind.bonus ? 'bonus_reply' : 'greet_reply', vars: _vars(c)));
          }
          if (c.stateTime > 3.4) {
            c.state = CustomerState.waiting;
            c.stateTime = 0;
            c.bubble = _customerSays(c, c.order);
            if (!c.orderRelayed) {
              c.orderRelayed = true;
              _relayOrder(c);
            }
          }
        case CustomerState.waiting:
          c.patience -= dt;
          final f = c.patienceFraction;
          final stage = f < 0.25 ? 2 : (f < 0.55 ? 1 : 0);
          if (stage > c.lastWaitStage && !c.free && !c.isCourier) {
            c.lastWaitStage = stage;
            c.stateTime = 0;
            c.waitLineShown = true;
            c.bubble = _customerSays(c, dialog.say(stage == 2 ? 'wait_low' : 'wait_mid'));
            if (stage == 2) _toCirak('usta_push', vars: _vars(c));
          } else if (c.waitLineShown && c.stateTime > 3.4) {
            c.waitLineShown = false;
            c.bubble = _customerSays(c, c.order);
          }
          if (c.patience <= 0) _leave(i, c);
        case CustomerState.reacting:
          if (c.stateTime > 2.6) slots[i] = null;
      }
    }

    _tickHelper(dt);
    _tickAuto(dt);
    _tickDelivery(dt);
    _checkBroke();

    // ipucu
    final base = selectedProduct.bowl ? 'kâseyi' : 'tırnaklı ekmeği';
    if (hint == _noMoneyHint && _noMoneyTimer > 0) {
      _noMoneyTimer -= dt;
    } else if (boards.every((b) => b.isEmpty) && slots.any((c) => c?.state == CustomerState.waiting)) {
      hint = 'Tezgâha $base sürükle';
    } else if (anyBoardWrapped) {
      hint = 'Hazır dürümü müşteriye sürükle';
    } else if (boards.any((b) => b.bread)) {
      hint = selectedProduct.bowl ? 'Acı ekle, sonra SERVİS ET' : 'Malzemeleri sürükle, sonra SAR';
    } else {
      hint = '';
    }

    if (toSpawn == 0 && slots.every((c) => c == null) && delivery.orders.isEmpty) _finishDay();
    notifyListeners();
  }

  static const String _noMoneyHint = 'Kasada para yok!';
  double _noMoneyTimer = 0;

  /// Kasa bitip hazırlık imkânsız kalırsa usta günde bir kez avans verir.
  void _checkBroke() {
    if (avansGivenToday || !boards.every((b) => b.isEmpty) || tipJar > 0) return;
    final waiting = slots.whereType<Customer>().where((c) => c.state == CustomerState.waiting && !c.isCourier && !c.free);
    if (waiting.isEmpty) return;
    if (money >= waiting.map((c) => ingredientCost(cfg, c.spec)).reduce(min)) return;
    avansGivenToday = true;
    money = max(money, cfg.eco('avans').round());
    _toCirak('usta_avans');
  }

  // ------------------------------------------------------------- paket servis (Bölüm 4+)
  void _tickDelivery(double dt) {
    if (!deliveryActive) return;
    final spawning = toSpawn > 0 || slots.any((c) => c != null);
    final before = delivery.orders.length;
    final outcomes = delivery.tick(
      dt,
      newSpec: _newSpec,
      spawning: spawning,
      dagitimLevel: level('dagitim'),
      deadline: cfg.eco('deliveryDeadline'),
    );
    if (delivery.orders.length > before && spawning) {
      _toCirak('usta_delivery_new');
    }
    for (final o in outcomes) {
      _settleDelivery(o);
    }
    // kurye kapıya geldiyse boş bir yuvaya yerleşir
    if (delivery.courierHere && !slots.whereType<Customer>().any((c) => c.isCourier)) {
      final free = [for (var i = 0; i < slotCount; i++) if (slots[i] == null) i];
      if (free.isNotEmpty) {
        _spawnCourier(free[_rnd.nextInt(free.length)]);
        _toCirak('usta_courier');
      }
    }
  }

  /// Kuryeye dokunuldu: kutudaki tüm paketleri verir, ödeme alınır.
  void _courierHandOver(int slot, Customer c) {
    final outcomes = delivery.handOver(level('dagitim'));
    c.state = CustomerState.reacting;
    c.stateTime = 0;
    if (outcomes.isEmpty) {
      c.mood = Mood.normal;
      c.bubble = _customerSays(c, dialog.say('kurye_leave'));
      notifyListeners();
      return;
    }
    c.mood = Mood.happy;
    c.bubble = _customerSays(c, dialog.say('kurye_thanks'));
    ustaSays('usta_bereket', toLabel: c.label, toSlot: slot, vars: _vars(c));
    _toCirak('usta_courier_paid');
    for (final o in outcomes) {
      _settleDelivery(o);
    }
    notifyListeners();
  }

  /// Kurye beklemekten sıkıldı: paketsiz gider (paketler kutuda soğur). Art arda 2 kez kaçırılırsa paketler kendiliğinden verilir.
  void _courierLeftEmpty(Customer c) {
    c.bubble = _customerSays(c, dialog.say('kurye_leave'));
    delivery.courierLeaves(level('dagitim'));
    _toCirak('usta_courier_left');
    if (delivery.courierMisses >= 2 && delivery.boxedCount > 0) {
      for (final o in delivery.handOver(level('dagitim'))) {
        _settleDelivery(o);
      }
    }
  }

  void _settleDelivery(DeliveryOutcome o) {
    if (o.made == null) {
      _satCount++;
      _toCirak('usta_delivery_fail');
      emit(const DeliveryEvent(onTime: false, verdict: Verdict.bad));
      return;
    }
    var r = scoreServe(cfg: cfg, spec: o.order.spec, made: o.made!, patienceLeft: o.order.fraction, customerTip: 1.0, tipMul: tipMul, payMul: payMul);
    var mul = cfg.eco('deliveryMul');
    if (o.cold) mul *= cfg.eco('coldMul');
    if (!o.onTime) mul *= cfg.eco('lateMul');
    final total = (r.total * mul).round();
    money += total;
    earnedToday += total;
    deliveryIncomeToday += total;
    deliveredToday++;
    scoreToday += total;
    _satCount++;
    _satSum += r.verdict == Verdict.great ? (o.onTime && !o.cold ? 1.0 : 0.6) : (r.verdict == Verdict.ok ? 0.5 : 0.2);
    _toCirak(!o.onTime ? 'usta_delivery_late' : (o.cold ? 'usta_delivery_cold' : 'usta_delivery_ok'));
    r = ServeResult(verdict: r.verdict, pay: total, tip: 0, errors: r.errors);
    emit(DeliveryEvent(onTime: o.onTime, verdict: r.verdict));
    emit(ServedEvent(verdict: r.verdict, spec: o.order.spec, total: total, tip: 0, streak: streak, patienceLeft: o.order.fraction, customerId: 'paket', special: 'paket'));
  }

  /// Hazırladığın dürümü [index]. paket siparişinin ısı kutusuna koy.
  void serveDelivery(int index, {int? board}) {
    if (phase != Phase.playing || paused || !deliveryActive) return;
    if (board != null) activeBoard = board;
    if (!assembly.wrapped) _pickWrappedBoard(null);
    if (!assembly.wrapped) return;
    if (delivery.box(index, assembly, level('dagitim'))) {
      assembly.reset();
      _sfx('wrap');
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- soruşturma (Bölüm 5)
  /// Soruşturma ekranındaki son konuşma/bulgu.
  final List<Speech> caseLog = [];
  bool get caseUnlocked => chapter >= 5 && caseState != null;

  void openCase() {
    if (!caseUnlocked) return;
    phase = Phase.detective;
    notifyListeners();
  }

  void closeCase() {
    phase = Phase.dayEnd;
    save();
    notifyListeners();
  }

  void _caseSay(String who, String text) => caseLog.add(Speech(whoLabel: kRoleLabels[who] ?? who.toUpperCase(), toLabel: kCirakLabel, text: text));

  void _learn(String clueId) {
    final cs = caseState!;
    if (cs.clues.add(clueId)) {
      emit(ClueEvent(clueId));
    }
  }

  /// Bir mekânı incele (gece 2 hamle hakkı).
  bool caseInspect(String locationId) {
    final cs = caseState;
    if (cs == null || cs.actionsLeft <= 0) return false;
    final loc = cs.data.locations.firstWhere((l) => l.id == locationId);
    final step = cs.nextStep(loc);
    if (step == null) {
      caseLog
        ..clear()
        ..add(Speech(whoLabel: 'ANLATICI', toLabel: kCirakLabel, text: '${loc.name} burada daha fazla iz kalmamış.'));
      notifyListeners();
      return false;
    }
    cs.actionsLeft--;
    cs.inspected[loc.id] = (cs.inspected[loc.id] ?? 0) + 1;
    caseLog.clear();
    _caseSay('anlatici', cs.data.clues[step.clue]!.text);
    _learn(step.clue);
    _openNextScene();
    save();
    notifyListeners();
    return true;
  }

  /// Bir şüpheliye soru sor (gece 2 hamle hakkı).
  bool caseAsk(String suspectId, QuestionDef q) {
    final cs = caseState;
    if (cs == null || cs.actionsLeft <= 0 || !cs.canAsk(q, suspectId)) return false;
    cs.actionsLeft--;
    cs.asked.add('$suspectId/${q.id}');
    caseLog.clear();
    for (final l in q.answers) {
      _caseSay(l.who, l.text);
    }
    if (q.clue != null) {
      _learn(q.clue!);
      caseLog.add(Speech(whoLabel: 'DEFTER', toLabel: kCirakLabel, text: 'Yeni ipucu: ${cs.data.clues[q.clue!]!.title}'));
    }
    _openNextScene();
    save();
    notifyListeners();
    return true;
  }

  /// Suçlama: doğru kişi + yeterli kanıt ⇒ dava çözülür; yanlış kişi ⇒ ceza.
  void caseAccuse(String suspectId) {
    final cs = caseState;
    if (cs == null || cs.solved) return;
    caseLog.clear();
    if (suspectId == cs.data.culprit) {
      if (cs.hasEvidence) {
        cs.solved = true;
        _learn('solved');
        _openNextScene();
        _caseSay('usta', 'Dava çözüldü, tandır taşı bulunuyor!');
      } else {
        _caseSay('usta', 'Evlat, içim bu kişide ama elimizde yeterli kanıt yok. Kızak izi, bilezik ve tanık sözlerini bir araya getirmeliyiz.');
      }
    } else {
      cs.wrong++;
      final loss = min(money, cs.data.wrongPenalty);
      money -= loss;
      _caseSay('usta', 'Yanlış kişiyi suçladık evlat! Mahalleye hesap verdik, $loss ₺ gitti. İpuçlarına tekrar bak.');
    }
    save();
    notifyListeners();
  }

  // ------------------------------------------------------------- bahçe (Bölüm 4+)
  void openGarden() {
    if (!gardenUnlocked) return;
    garden.ensurePlots(plotCount);
    phase = Phase.garden;
    notifyListeners();
  }

  void closeGarden() {
    phase = Phase.dayEnd;
    save();
    notifyListeners();
  }

  bool gardenPlant(int i, String cropId) {
    final ok = garden.plant(i, cropId, money: money, pay: (c) => money -= c);
    if (ok) {
      save();
      notifyListeners();
    }
    return ok;
  }

  void gardenWater(int i) {
    if (garden.water(i)) {
      _sfx('water');
      notifyListeners();
    }
  }

  void gardenWaterAll() {
    if (garden.waterAll() > 0) {
      _sfx('water');
      notifyListeners();
    }
  }

  void gardenHarvest(int i) {
    final n = garden.harvest(i, (crop, amount) => emit(HarvestEvent(crop, amount)));
    if (n > 0) {
      save();
      notifyListeners();
    }
  }

  void _relayOrder(Customer c) {
    switch (c.kind) {
      case CustomerKind.riddle:
        if (!riddleIntroShown) {
          riddleIntroShown = true;
          _toCirak('usta_riddle_intro');
        }
        _toCirak('relay_riddle', vars: _vars(c));
      case CustomerKind.garip:
        _toCirak('garip_relay', vars: _vars(c));
      case CustomerKind.maskeli:
        _toCirak('maskeli_relay', vars: _vars(c));
        _toCirak('relay', vars: {..._vars(c), 'ozet': specSummary(c.spec)});
      case CustomerKind.bonus:
        _toCirak('usta_bonus', vars: _vars(c));
        _toCirak('relay', vars: {..._vars(c), 'ozet': specSummary(c.spec)});
      case CustomerKind.kurye:
        break; // kurye için _toCirak('usta_courier') varışta söylenir
      case CustomerKind.normal:
        _toCirak('relay', vars: {..._vars(c), 'ozet': specSummary(c.spec)});
    }
  }

  // ------------------------------------------------------------- yardımcı çırak
  double get helperCycle => max(5.0, 16 - 2.5 * level('yardimci'));

  /// Son seviye (Otomatik Usta) hatasız hazırlar.
  double get helperAccuracy => level('yardimci') >= (cfg.upgrades.firstWhere((u) => u.id == 'yardimci').max) ? 1.0 : 0.55 + 0.1 * level('yardimci');

  void _tickHelper(double dt) {
    if (level('yardimci') <= 0 || helper.ready != null) return;
    final target = slots.whereType<Customer>().where((c) => c.state == CustomerState.waiting && c.kind == CustomerKind.normal && !c.helperClaim).firstOrNull;
    if (target == null) {
      return;
    }
    helper.progress += dt / helperCycle;
    if (helper.progress >= 1) {
      helper.progress = 0;
      target.helperClaim = true;
      final a = Assembly.fromSpec(target.spec);
      // malzemeler ayrıca para harcar: çırağın cebinden değil, kasadan (dükkân masrafı)
      final cost = ingredientCost(cfg, target.spec);
      final paid = min(money, cost);
      money -= paid;
      suppliesToday += paid;
      a.spent = paid;
      if (_rnd.nextDouble() > helperAccuracy) {
        // küçük bir hata: ana malzeme miktarı ya da bir malzeme
        final p = cfg.product(a.wrap);
        switch (_rnd.nextInt(3)) {
          case 0:
            a.nohut = (a.nohut + (a.nohut == 1 ? 1 : -1)).clamp(1, p.maxAmount);
            if (p.maxAmount == 1) a.piyaz = !a.piyaz && p.allows('piyaz');
          case 1:
            if (p.allows('piyaz')) {
              a.piyaz = !a.piyaz;
            } else {
              a.aci = !a.aci;
            }
          default:
            a.aci = !a.aci;
        }
      }
      helper.ready = a;
    }
  }

  void tapHelper() {
    if (phase != Phase.playing || helper.ready == null) return;
    final free = boards.indexWhere((b) => b.isEmpty);
    if (free < 0) return;
    activeBoard = free;
    assembly
      ..reset()
      ..wrap = helper.ready!.wrap
      ..bread = helper.ready!.bread
      ..nohut = helper.ready!.nohut
      ..piyaz = helper.ready!.piyaz
      ..aci = helper.ready!.aci
      ..sumak = helper.ready!.sumak
      ..fried = helper.ready!.fried
      ..sauces.addAll(helper.ready!.sauces)
      ..spent = helper.ready!.spent
      ..wrapped = true;
    helper.ready = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- otomasyon (elmasla alınan modüller)
  bool get _hasAuto => level('auto_ekmek') + level('auto_ana') + level('auto_ek') + level('auto_sar') > 0;

  /// Sıradaki otomasyon hedefi: bekleyen, siparişi açık olan ilk müşteri (bilmece/garip hariç).
  Customer? get autoTarget => slots.whereType<Customer>().where((c) => c.state == CustomerState.waiting && (c.kind == CustomerKind.normal || c.kind == CustomerKind.maskeli || c.kind == CustomerKind.bonus)).firstOrNull;

  void _tickAuto(double dt) {
    if (!_hasAuto) return;
    final t = autoTarget;
    if (t == null) return;
    autoTimer += dt;
    if (autoTimer < 1.2) return;
    autoTimer = 0;
    final s = t.spec;
    // hedefe uyan yarım bir dürüm varsa onu sürdürür, yoksa boş bir tezgâha ekmek koyar
    final partial = boards.indexWhere((b) => b.bread && !b.wrapped && b.wrap == s.wrap && b.nohut <= s.nohut && (!b.piyaz || s.piyaz) && (!b.aci || s.aci) && (!b.fried || s.fried) && (!b.sumak || s.sumak) && b.sauces.difference(s.sauces).isEmpty);
    final free = boards.indexWhere((b) => b.isEmpty);
    if (partial >= 0) {
      activeBoard = partial;
    } else if (free >= 0) {
      activeBoard = free;
    }
    final a = assembly;
    if (a.isEmpty) {
      if (level('auto_ekmek') > 0) {
        selectedWrap = s.wrap;
        tapBread();
      }
      return;
    }
    // oyuncu elle bambaşka bir şey hazırlıyorsa karışma
    final extra = a.wrap != s.wrap || a.nohut > s.nohut || (a.piyaz && !s.piyaz) || (a.aci && !s.aci) || (a.fried && !s.fried) || (a.sumak && !s.sumak) || a.sauces.difference(s.sauces).isNotEmpty;
    if (extra) return;
    if (level('auto_ana') > 0 && a.nohut < s.nohut) {
      tapMain();
      return;
    }
    if (level('auto_ek') > 0) {
      if (s.piyaz && !a.piyaz) return tapPiyaz();
      if (s.aci && !a.aci) return tapAci();
      if (s.fried && !a.fried) return tapFried();
      for (final id in s.sauces) {
        if (!a.sauces.contains(id)) return tapSauce(id);
      }
      if (s.sumak && !a.sumak) return tapSumak();
    }
    if (level('auto_sar') > 0 && _matchesSpec(a, s)) wrap();
  }

  bool _matchesSpec(Assembly a, OrderSpec s) => orderErrors(s, a.copy()..wrapped = true) == 0;

  void _leave(int i, Customer c) {
    c.state = CustomerState.reacting;
    c.stateTime = 0;
    c.mood = Mood.angry;
    if (c.free) {
      c.bubble = _customerSays(c, dialog.say('garip_leave'));
      _toCirak('usta_garip_left');
      return; // garip gidince oyuncu cezalandırılmaz
    }
    if (c.isCourier) {
      _courierLeftEmpty(c);
      return; // kurye beklemekten vazgeçti; müşteri sayılmaz
    }
    c.bubble = _customerSays(c, dialog.say('leave'));
    lostToday++;
    streak = 0;
    _satCount++;
    // yetişemediğin müşteri kasadan ceza düşürür (kasa eksiye inmez)
    final fine = min(money, cfg.eco('leavePenalty').round());
    money -= fine;
    penaltyToday += fine;
    c.gain = -fine;
    lives = max(0, lives - 1);
    if (gameOverEnabled && lives <= 0 && phase == Phase.playing) {
      phase = Phase.gameOver;
      _toCirak('usta_game_over');
    }
    _toCirak(penaltyToday == fine && fine > 0 ? 'usta_penalty' : 'usta_after_leave', vars: {..._vars(c), 'ceza': '$fine'});
    emit(CustomerLeftEvent(customerId: c.type.id, special: c.kind == CustomerKind.maskeli ? 'maskeli' : null));
  }

  void _finishDay() {
    phase = Phase.dayEnd; // zamanlayıcı çalışmaya devam eder (reklam geri sayımı için)
    _toCirak('usta_day_end');
    final finishedDay = day;
    if (chapter >= 5) caseState?.newNight();
    // kavanozda kalan bahşiş kasaya geçer
    final jar = tipJar;
    if (jar > 0) collectTipJar();
    // günlük bilanço: malzeme masrafı serviste/hazırlıkta zaten düşüldü; kira şimdi (para eksiye düşmez)
    rentToday = cfg.rentFor(chapter);
    final paid = min(money, rentToday);
    money -= paid;
    netToday = earnedToday + tipsToday - suppliesToday - rentToday - stolenToday - penaltyToday;
    day += 1; // gelir servis anında eklendi; sonraki gün hazır
    totalScore += scoreToday;
    emit(DayEndedEvent(
      day: finishedDay,
      served: servedToday,
      great: greatToday,
      lost: lostToday,
      earned: earnedToday,
      tips: tipsToday,
      netProfit: netToday,
      score: scoreToday,
      reputation: reputationToday,
    ));
    _openNextScene();
    save();
  }

  // ------------------------------------------------------------- oyuncu eylemleri
  /// Malzeme parasını kasadan düşer; para yetmezse eklemez.
  bool _spend(int cost) {
    if (money < cost) {
      hint = _noMoneyHint;
      if (_noMoneyTimer <= 0) _toCirak('usta_no_money');
      _noMoneyTimer = 2.5;
      notifyListeners();
      return false;
    }
    money -= cost;
    assembly.spent += cost;
    suppliesToday += cost;
    return true;
  }

  /// Tezgâhta hazırlanacak ürünü seç (yalnızca tezgâh boşken ve ürün açıksa).
  void selectWrap(String id) {
    if (!anyBoardEmpty) return;
    if (!products.any((p) => p.id == id)) return;
    selectedWrap = id;
    notifyListeners();
  }

  /// Ürün seçicideki oklar: bir sonraki / önceki açık ürün.
  void cycleWrap(int dir) {
    final list = products;
    if (list.length < 2 || !anyBoardEmpty) return;
    final i = max(0, list.indexWhere((p) => p.id == selectedWrap));
    selectedWrap = list[(i + dir + list.length) % list.length].id;
    notifyListeners();
  }

  /// Taban: tırnaklı ekmek (beyranda kâse).
  void tapBread({int? board}) {
    if (phase != Phase.playing || paused) return;
    if (board != null) {
      activeBoard = board;
    } else if (assembly.bread) {
      final free = boards.indexWhere((b) => b.isEmpty);
      if (free < 0) return;
      activeBoard = free;
    }
    if (assembly.bread) return;
    if (!_spend(cfg.baseCost(selectedWrap))) return;
    assembly.wrap = selectedWrap;
    assembly.bread = true;
    _sfx('bread');
    notifyListeners();
  }

  /// Ana malzeme (nohut, döner, kavurma…): her dokunuş bir porsiyon.
  void tapMain({int? board}) {
    if (board != null) activeBoard = board;
    if (!_canAdd) return;
    final p = cfg.product(assembly.wrap);
    if (assembly.nohut >= p.maxAmount || !_spend(p.unit)) return;
    assembly.nohut++;
    _sfx('pop');
    notifyListeners();
  }

  void tapNohut() => tapMain();

  void tapPiyaz({int? board}) {
    if (board != null) activeBoard = board;
    if (!_canAdd || assembly.piyaz || !cfg.product(assembly.wrap).allows('piyaz') || !_spend(cfg.costs['piyaz']!)) return;
    assembly.piyaz = true;
    _sfx('pop');
    notifyListeners();
  }

  void tapAci({int? board}) {
    if (board != null) activeBoard = board;
    if (!_canAdd || assembly.aci || !cfg.product(assembly.wrap).allows('aci') || !_spend(cfg.costs['aci']!)) return;
    assembly.aci = true;
    _sfx('pop');
    notifyListeners();
  }

  void tapFried({int? board}) {
    if (board != null) activeBoard = board;
    if (!_canAdd || assembly.fried || !friedUnlocked || !cfg.product(assembly.wrap).allows('fried') || !_spend(cfg.costs['fried']!)) return;
    assembly.fried = true;
    _sfx('pop');
    notifyListeners();
  }

  void tapSumak({int? board}) {
    if (board != null) activeBoard = board;
    if (!_canAdd || assembly.sumak || !sauces.any((s) => s.id == 'sumak') || !cfg.product(assembly.wrap).allows('sumak') || !_spend(cfg.sauceCost('sumak'))) return;
    assembly.sumak = true;
    _sfx('pop');
    notifyListeners();
  }

  /// sos | ketcap | mayonez | nar (sumak için [tapSumak]).
  void tapSauce(String id, {int? board}) {
    if (board != null) activeBoard = board;
    if (id == 'sumak') return tapSumak();
    if (!_canAdd || assembly.sauces.contains(id) || !sauces.any((s) => s.id == id) || !cfg.product(assembly.wrap).allows('sauce') || !_spend(cfg.sauceCost(id))) return;
    assembly.sauces.add(id);
    _sfx('pop');
    notifyListeners();
  }

  /// Sürükle-bırak: bir malzemeyi [board]. tezgâha bırak.
  void addIngredient(Ingredient kind, {required int board, String? sauceId}) {
    switch (kind) {
      case Ingredient.bread:
        tapBread(board: board);
      case Ingredient.main:
        tapMain(board: board);
      case Ingredient.piyaz:
        tapPiyaz(board: board);
      case Ingredient.aci:
        tapAci(board: board);
      case Ingredient.fried:
        tapFried(board: board);
      case Ingredient.sumak:
        tapSumak(board: board);
      case Ingredient.sauce:
        tapSauce(sauceId ?? 'sos', board: board);
    }
  }

  /// Hazır (sarılmış) tezgâhlardan müşteriye en uygun olanı etkin yapar (sürükleme yoksa).
  void _pickWrappedBoard(Customer? c) {
    if (assembly.wrapped && c == null) return;
    var best = -1;
    var bestErr = 999;
    for (var i = 0; i < boardCount; i++) {
      if (!boards[i].wrapped) continue;
      final e = c == null ? 0 : orderErrors(c.spec, boards[i]);
      if (e < bestErr || (e == bestErr && i == activeBoard)) {
        best = i;
        bestErr = e;
      }
    }
    if (best >= 0) activeBoard = best;
  }

  bool get _canAdd => phase == Phase.playing && !paused && assembly.bread && !assembly.wrapped;

  void wrap({int? board}) {
    if (board != null) activeBoard = board;
    if (phase != Phase.playing || paused || !assembly.bread || assembly.wrapped) return;
    assembly.wrapped = true;
    _sfx('wrap');
    notifyListeners();
  }

  /// Çöpe atılan dürümün malzeme parası geri gelmez.
  void trash({int? board}) {
    if (board != null) activeBoard = board;
    if (phase != Phase.playing || paused || assembly.isEmpty) return;
    wastedToday += assembly.spent;
    assembly.reset();
    _toCirak('usta_trash');
    notifyListeners();
  }

  // ------------------------------------------------------------- bahşiş kavanozu
  void collectTipJar() {
    if (tipJar <= 0) return;
    final n = tipJar;
    money += n;
    tipJar = 0;
    emit(TipJarEvent(n));
    _sfx('coin');
    notifyListeners();
  }

  // ------------------------------------------------------------- tarif defteri
  void toggleRecipe() {
    recipeOpen = !recipeOpen;
    notifyListeners();
  }

  // ------------------------------------------------------------- reklam (sahte; mağaza öncesi AdMob'a bağlanır)
  String? adKind; // money | diamond
  double adLeft = 0;
  bool adMenuOpen = false;

  void openAdMenu() {
    if (phase == Phase.title) return;
    adMenuOpen = true;
    notifyListeners();
  }

  void closeAdMenu() {
    adMenuOpen = false;
    notifyListeners();
  }

  int get adMoneyReward => (cfg.eco('adMoneyBase') + cfg.eco('adMoneyPerChapter') * chapter).round();
  bool canWatchAd(String kind) => kind == 'revive' ? (!reviveUsedToday && phase == Phase.gameOver) : kind == 'diamond' ? adsDiamondToday < cfg.eco('adDiamondMax') : adsMoneyToday < cfg.eco('adMoneyMax');
  int adsLeft(String kind) => (kind == 'diamond' ? cfg.eco('adDiamondMax').round() - adsDiamondToday : cfg.eco('adMoneyMax').round() - adsMoneyToday).clamp(0, 99);

  void startAd(String kind) {
    if (adKind != null || phase == Phase.title || !canWatchAd(kind)) return;
    adMenuOpen = false;
    adKind = kind;
    adLeft = cfg.eco('adSeconds');
    notifyListeners();
  }

  void cancelAd() {
    adKind = null;
    adLeft = 0;
    notifyListeners();
  }

  /// Gerçek reklam SDK'sı bağlanınca ödül geri çağrısı bu metodu çağırır.
  void _grantAd() {
    final k = adKind;
    adKind = null;
    adLeft = 0;
    if (k == 'diamond') {
      adsDiamondToday++;
      diamonds += 1;
      emit(const DiamondEvent(1, 'ad'));
    } else if (k == 'money') {
      adsMoneyToday++;
      money += adMoneyReward;
    } else if (k == 'revive') {
      _revive();
    }
    save();
    notifyListeners();
  }

  /// Müşteriye dokunuş: kuryeyse paketleri verir, değilse hazırlanan dürümü servis eder.
  void tapCustomer(int slot, {int? board}) {
    final c = slots[slot];
    if (c == null || phase != Phase.playing || paused) return;
    if (c.isCourier) {
      if (c.state != CustomerState.reacting) _courierHandOver(slot, c);
      return;
    }
    if (board == null && !anyBoardWrapped) {
      // verilecek dürüm yok: dokunulan müşterinin siparişi tam balonla okunur
      _pinnedSlot = slot;
      _pinnedAt = _custSeq;
      notifyListeners();
      return;
    }
    serve(slot, board: board);
  }

  void serve(int slot, {int? board}) {
    if (phase != Phase.playing || paused) return;
    final c = slots[slot];
    if (board != null) {
      if (!boards[board].wrapped) return;
      activeBoard = board;
    } else {
      _pickWrappedBoard(c);
    }
    if (!assembly.wrapped) return;
    if (c == null || c.state != CustomerState.waiting) return;
    final vars = _vars(c);
    if (c.isCourier) return; // kuryeye dürüm verilmez; paketler için tapCustomer
    c.state = CustomerState.reacting;
    c.stateTime = 0;

    // Gariban: ücretsiz, ikram
    if (c.free) {
      c.mood = Mood.happy;
      c.bubble = _customerSays(c, dialog.say('garip_thanks'));
      ustaSays('usta_bereket_garip', toLabel: c.label, toSlot: slot);
      _toCirak('usta_garip_praise');
      assembly.reset();
      emit(const NpcHelpedEvent('garip'));
      notifyListeners();
      return;
    }

    // Bölüm 4+: bahçe stoğundan taze piyaz/acı kullanıldıysa o malzemenin parası iade edilir
    var freshBonus = 0.0;
    if (gardenUnlocked && (assembly.piyaz || assembly.aci)) {
      final used = garden.consume(piyaz: assembly.piyaz, aci: assembly.aci);
      final refund = (used.piyazFresh ? cfg.costs['piyaz']! : 0) + (used.aciFresh ? cfg.costs['aci']! : 0);
      money += refund;
      suppliesToday -= refund;
      if (used.fresh > 0) freshBonus = cfg.garden.freshBonus;
    }
    var r = scoreServe(
      cfg: cfg,
      spec: c.spec,
      made: assembly,
      patienceLeft: c.patienceFraction,
      customerTip: c.type.tip,
      tipMul: tipMul,
      payMul: payMul + freshBonus,
    );
    // bilmeceler %25 fazla öder
    if (c.kind == CustomerKind.riddle && r.verdict == Verdict.great) {
      r = ServeResult(verdict: r.verdict, pay: (r.pay * 1.25).round(), tip: r.tip, errors: r.errors);
    }
    final isMaskeli = c.kind == CustomerKind.maskeli;
    var total = r.total;
    var stolen = false;
    if (isMaskeli) {
      if (r.verdict == Verdict.great) {
        total = (total * 1.5).round();
      } else {
        stolen = true;
        total = 0;
      }
    }
    // müşteri "hayırlı işler" der, usta "bereket versin" der
    if (!stolen) ustaSays('usta_bereket', toLabel: c.label, toSlot: slot, vars: vars);
    var tipPart = stolen ? 0 : (isMaskeli ? (r.tip * 1.5).round() : r.tip);
    final isBonus = c.kind == CustomerKind.bonus;
    if (isBonus) {
      // bonus müşteri bol bahşiş bırakır (kalite fark etmez)
      tipPart = max((r.tip * cfg.eco('bonusTipMul')).round(), (orderPrice(cfg, c.spec) * 0.3).round());
      total = r.pay + tipPart;
    }
    // ücret kasaya, bahşiş kavanoza
    money += total - tipPart;
    tipJar += tipPart;
    earnedToday += total - tipPart;
    tipsToday += tipPart;
    servedToday++;
    c.gain = total;
    if (r.verdict == Verdict.bad || stolen) wastedToday += assembly.spent;

    if (stolen) {
      final amount = min(money, cfg.eco('stealAmount').round());
      money -= amount;
      stolenToday += amount;
      c.mood = Mood.angry;
      c.bubble = _customerSays(c, dialog.say('maskeli_steal'));
      streak = 0;
      _satSum += 0.1;
      _toCirak('usta_stolen', vars: {...vars, 'miktar': '$amount'});
    } else {
      switch (r.verdict) {
        case Verdict.great:
          c.mood = Mood.happy;
          final cat = isMaskeli ? 'maskeli_great' : (c.kind == CustomerKind.riddle ? 'react_riddle_great' : (r.tip > 0 ? 'react_great_tip' : 'react_great'));
          c.bubble = _customerSays(c, dialog.say(cat));
          greatToday++;
          streak++;
          scoreToday += total + 4 * streak;
          _satSum += 1.0;
          _toCirak(c.kind == CustomerKind.riddle ? 'usta_riddle_great' : 'usta_praise', vars: vars);
        case Verdict.ok:
          c.mood = Mood.normal;
          c.bubble = _customerSays(c, dialog.say(c.kind == CustomerKind.riddle ? 'react_riddle_bad' : 'react_ok'));
          streak = 0;
          scoreToday += total;
          _satSum += 0.6;
          _toCirak(c.kind == CustomerKind.riddle ? 'usta_riddle_bad' : 'usta_meh', vars: vars);
        case Verdict.bad:
          c.mood = Mood.angry;
          c.bubble = _customerSays(c, dialog.say(c.kind == CustomerKind.riddle ? 'react_riddle_bad' : 'react_bad'));
          streak = 0;
          scoreToday += total;
          _satSum += 0.2;
          _toCirak(c.kind == CustomerKind.riddle ? 'usta_riddle_bad' : 'usta_scold', vars: vars);
      }
    }
    _satCount++;
    if (isBonus && !stolen) {
      final d = cfg.eco('bonusDiamonds').round();
      diamonds += d;
      c.bubble = _customerSays(c, dialog.say('bonus_thanks'));
      emit(DiamondEvent(d, 'bonus'));
    } else if (c.kind != CustomerKind.bonus) {
      servedSinceBonus++;
      if (servedSinceBonus >= cfg.eco('bonusEvery')) bonusDue = true;
    }
    emit(ServedEvent(
      verdict: stolen ? Verdict.bad : r.verdict,
      spec: c.spec,
      total: total,
      tip: tipPart,
      streak: streak,
      patienceLeft: c.patienceFraction,
      customerId: c.type.id,
      special: isMaskeli ? 'maskeli' : null,
      riddleId: c.riddle?.id,
      giver: c.giver,
    ));
    assembly.reset();
    notifyListeners();
  }

  // ------------------------------------------------------------- dükkân
  void openShop() {
    phase = Phase.shop;
    _toCirak('usta_shop');
    notifyListeners();
  }

  int? nextCost(UpgradeDef u) {
    final l = level(u.id);
    return l >= u.max ? null : u.costs[l];
  }

  bool canAffordUpgrade(UpgradeDef u) {
    final c = nextCost(u);
    return c != null && chapter >= u.minChapter && (u.withDiamonds ? diamonds >= c : money >= c);
  }

  bool buy(UpgradeDef u) {
    if (!canAffordUpgrade(u)) return false;
    final c = nextCost(u)!;
    if (u.withDiamonds) {
      diamonds -= c;
    } else {
      money -= c;
    }
    upgrades[u.id] = level(u.id) + 1;
    emit(UpgradeBoughtEvent(u.id, level(u.id)));
    save();
    notifyListeners();
    return true;
  }

  bool buyDecor(DecorDef d) {
    if (chapter < d.minChapter || decorOwned.contains(d.id) || money < d.cost || diamonds < d.diamonds) return false;
    money -= d.cost;
    diamonds -= d.diamonds;
    decorOwned.add(d.id);
    emit(DecorBoughtEvent(d.id));
    save();
    notifyListeners();
    return true;
  }

  void toTitle() {
    if (phase == Phase.playing || phase == Phase.gameOver) {
      save(); // kasa, elmas ve yarım gün birlikte kaydedilir
      hasResumable = prefs != null;
    }
    _timer?.cancel();
    adKind = null;
    introLeft = 0;
    tutorialStep = -1;
    phase = Phase.title;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    quests.dispose();
    super.dispose();
  }
}
