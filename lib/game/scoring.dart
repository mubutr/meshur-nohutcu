import '../data/models.dart';

class ServeResult {
  const ServeResult({required this.verdict, required this.pay, required this.tip, required this.errors});
  final Verdict verdict;
  final int pay;
  final int tip;
  final int errors;
  int get total => pay + tip;
}

/// Bir siparişin malzeme maliyeti (kasadan düşen toplam).
int ingredientCost(GameConfig cfg, OrderSpec spec) {
  final p = cfg.product(spec.wrap);
  var c = cfg.baseCost(spec.wrap) + p.unit * spec.nohut;
  if (spec.piyaz) c += cfg.costs['piyaz']!;
  if (spec.aci) c += cfg.costs['aci']!;
  if (spec.fried) c += cfg.costs['fried']!;
  for (final s in spec.allSauces) {
    c += cfg.sauceCost(s);
  }
  return c;
}

/// Satış fiyatı = maliyet × marj (varsayılan 1.3: %30 kâr).
int orderPrice(GameConfig cfg, OrderSpec spec) => (ingredientCost(cfg, spec) * cfg.margin).round();

/// Hazırlanan dürümle sipariş arasındaki fark sayısı. Dürüm sarılmamışsa ya da taban yoksa geçersiz (-1).
/// Yanlış ürün 3 hata sayılır (kötü).
int orderErrors(OrderSpec spec, Assembly made) {
  if (!made.bread || !made.wrapped) return -1;
  if (spec.wrap != made.wrap) return 3;
  var e = (spec.nohut - made.nohut).abs();
  if (spec.piyaz != made.piyaz) e++;
  if (spec.aci != made.aci) e++;
  if (spec.sumak != made.sumak) e++;
  if (spec.fried != made.fried) e++;
  e += spec.sauces.difference(made.sauces).length + made.sauces.difference(spec.sauces).length;
  return e;
}

Verdict verdictFor(int errors) => errors == 0 ? Verdict.great : (errors == 1 ? Verdict.ok : Verdict.bad);

/// [patienceLeft]: 0..1 (müşterinin kalan sabır oranı). [tipMul] ve [payMul] yükseltmelerden gelir.
ServeResult scoreServe({
  required GameConfig cfg,
  required OrderSpec spec,
  required Assembly made,
  required double patienceLeft,
  required double customerTip,
  double tipMul = 1.0,
  double payMul = 1.0,
}) {
  final errors = orderErrors(spec, made);
  final verdict = verdictFor(errors < 0 ? 99 : errors);
  final price = orderPrice(cfg, spec);
  final quality = switch (verdict) { Verdict.great => 1.0, Verdict.ok => 0.6, Verdict.bad => 0.25 };
  final pay = (price * quality * payMul).round();
  final tip = verdict == Verdict.great ? (price * cfg.eco('tipRate') * patienceLeft.clamp(0.0, 1.0) * customerTip * tipMul).round() : 0;
  return ServeResult(verdict: verdict, pay: pay, tip: tip, errors: errors);
}
