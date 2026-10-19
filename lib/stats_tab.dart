import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';
import 'charts.dart';
import 'loading_screen.dart';

class _Agg {
  int visits = 0, amounts = 0;
  final clients = <String>{};
  int points = 0;
  double revenue = 0;
  final perClient = <String, int>{};
  final spentBy = <String, double>{};
  double? get basket => amounts == 0 ? null : revenue / amounts;
  double get returnRate {
    if (clients.isEmpty) return 0;
    return perClient.values.where((v) => v >= 2).length * 100 / clients.length;
  }
  double? get visitsPerClient => clients.isEmpty ? null : visits / clients.length;
}

/// Tous les chiffres d'une période, calculés une seule fois par affichage.
class _Report {
  DateTime from = DateTime.now(), today = DateTime.now();
  _Agg cur = _Agg(), prev = _Agg();
  int rewards = 0, prevRewards = 0, newClients = 0, bucket = 1, yVisits = 0;
  double yMoney = 0;
  double? retention; // % des clients de la période précédente revenus sur celle-ci
  List<double> visitsSeries = [], moneySeries = [];
  List<double> weekday = List.filled(7, 0.0), hours = List.filled(24, 0.0);
}

double? _delta(num cur, num prev) => prev == 0 ? null : (cur - prev) * 100 / prev;

int _dayDiff(DateTime a, DateTime b) => DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

String _dec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _dm(DateTime d) => '${d.day}/${d.month}';
String _pctTxt(double? d) => d == null ? '' : ' (${d >= 0 ? '+' : '-'}${d.abs().round()}%)';

int? _argMax(List<double> v) {
  var best = -1;
  var m = 0.0;
  for (var i = 0; i < v.length; i++) {
    if (v[i] > m) {
      m = v[i];
      best = i;
    }
  }
  return best < 0 ? null : best;
}

_Agg _agg(List<(DateTime, Map<String, dynamic>)> items, DateTime a, DateTime b) {
  final g = _Agg();
  for (final it in items) {
    if (it.$1.isBefore(a) || !it.$1.isBefore(b)) continue;
    final s = it.$2;
    final id = '${s['client_id']}';
    g.visits++;
    g.clients.add(id);
    g.points += (s['points'] as num?)?.toInt() ?? 0;
    g.perClient[id] = (g.perClient[id] ?? 0) + 1;
    final am = amountOf(s);
    if (am != null) {
      g.revenue += am;
      g.amounts++;
      g.spentBy[id] = (g.spentBy[id] ?? 0) + am;
    }
  }
  return g;
}

_Report _compute(int days) {
  final r = _Report();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final from = DateTime(today.year, today.month, today.day - (days - 1));
  final prevFrom = DateTime(from.year, from.month, from.day - days);
  r.today = today;
  r.from = from;
  r.bucket = days > 31 ? 7 : 1; // par semaine sur 90 jours
  final items = [for (final s in store.history) (localDt(s['created_at']), s)];
  r.cur = _agg(items, from, tomorrow);
  r.prev = _agg(items, prevFrom, from);
  r.rewards = store.redeemHistory.where((x) => !localDt(x['created_at']).isBefore(from)).length;
  r.prevRewards = store.redeemHistory.where((x) {
    final t = localDt(x['created_at']);
    return !t.isBefore(prevFrom) && t.isBefore(from);
  }).length;

  final buckets = (days / r.bucket).ceil();
  r.visitsSeries = List.filled(buckets, 0.0);
  r.moneySeries = List.filled(buckets, 0.0);
  final first = <String, DateTime>{};
  for (final it in items) {
    final t = it.$1;
    final id = '${it.$2['client_id']}';
    final f0 = first[id];
    if (f0 == null || t.isBefore(f0)) first[id] = t;
    if (!t.isBefore(yesterday) && t.isBefore(today)) {
      r.yVisits++;
      r.yMoney += amountOf(it.$2) ?? 0;
    }
    if (t.isBefore(from) || !t.isBefore(tomorrow)) continue;
    final idx = _dayDiff(t, from) ~/ r.bucket;
    if (idx >= 0 && idx < buckets) {
      r.visitsSeries[idx]++;
      r.moneySeries[idx] += amountOf(it.$2) ?? 0;
    }
    r.weekday[t.weekday - 1]++;
    r.hours[t.hour]++;
  }
  // Nouveau client = première visite connue (historique de 180 jours) dans la période.
  r.newClients = r.cur.clients.where((id) => !(first[id]?.isBefore(from) ?? false)).length;
  r.retention = r.prev.clients.isEmpty ? null : r.prev.clients.intersection(r.cur.clients).length * 100 / r.prev.clients.length;
  return r;
}

/// Onglet « Statistiques » : indicateurs, points clés, évolution, jours et heures de pointe, fidélité, meilleurs clients.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int days = 30;
  bool money = false;

  @override
  void initState() {
    super.initState();
    store.loadHistory();
  }

  Future<void> _reload() async {
    await store.refresh();
    await store.loadHistory(force: true);
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 12),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          if (!store.historyLoaded) {
            return NqScreen(title: tr('Statistiques', 'الإحصاءات'), body: MascotLoader(compact: true, message: tr('Analyse de vos données…', 'جارٍ تحليل بياناتك…')));
          }
          final theme = Theme.of(context);
          final r = _compute(days);
          final cur = r.cur, prev = r.prev;
          final hasMoney = store.hasAmount && cur.amounts > 0;

          final dayNames = lang == 'ar' ? ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'] : ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
          final dayFull = lang == 'ar' ? ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'] : ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
          final unitVisits = tr('passages', 'زيارات');

          // --- Évolution (par jour, ou par semaine sur 90 jours) ---
          final series = money ? r.moneySeries : r.visitsSeries;
          final evolution = <BarData>[];
          for (var i = 0; i < series.length; i++) {
            final d0 = DateTime(r.from.year, r.from.month, r.from.day + i * r.bucket);
            var detail = '${dayNames[d0.weekday - 1]} ${_dm(d0)}';
            if (r.bucket > 1) {
              var d1 = DateTime(d0.year, d0.month, d0.day + r.bucket - 1);
              if (d1.isAfter(r.today)) d1 = r.today;
              detail = '${_dm(d0)} – ${_dm(d1)}';
            }
            evolution.add(BarData(_dm(d0), series[i], detail));
          }
          final evoTotal = money ? cur.revenue : cur.visits.toDouble();
          final evoBest = _argMax(series);
          String? evoNote;
          if (evoTotal > 0) {
            evoNote = '${tr('Total', 'المجموع')} : ${money ? fmtMoney(evoTotal) : fmtNum(evoTotal)}';
            if (evoBest != null) evoNote = '$evoNote · ${tr('Record', 'الأعلى')} : ${evolution[evoBest].detail}';
          }

          // --- Jours de la semaine ---
          final bestDay = _argMax(r.weekday);
          final dayNote = bestDay == null ? null : '${tr('Meilleur jour', 'أفضل يوم')} : ${dayNames[bestDay]} · ${(r.weekday[bestDay] * 100 / cur.visits).round()}% ${tr('des passages', 'من الزيارات')}';

          // --- Heures de pointe ---
          var lo = r.hours.indexWhere((v) => v > 0), hi = r.hours.lastIndexWhere((v) => v > 0);
          if (lo < 0) {
            lo = 8;
            hi = 20;
          }
          lo = (lo - 1).clamp(0, 23);
          hi = (hi + 1).clamp(0, 23);
          final hourBars = [for (var h = lo; h <= hi; h++) BarData('${h}h', r.hours[h], '${h}h–${h + 1}h')];
          final peak = _argMax(r.hours);
          final peakNote = peak == null ? null : '${tr('Heure de pointe', 'ساعة الذروة')} : ${peak}h–${peak + 1}h · ${(r.hours[peak] * 100 / cur.visits).round()}% ${tr('des passages', 'من الزيارات')}';

          // --- Fidélité des clients ---
          final once = cur.perClient.values.where((v) => v == 1).length;
          final twice = cur.perClient.values.where((v) => v == 2).length;
          final often = cur.perClient.values.where((v) => v >= 3).length;

          // --- Meilleurs clients (visites, puis dépenses) ---
          final top = cur.perClient.entries.toList()
            ..sort((a, b) {
              final c = b.value.compareTo(a.value);
              return c != 0 ? c : (cur.spentBy[b.key] ?? 0).compareTo(cur.spentBy[a.key] ?? 0);
            });

          // --- Aujourd'hui ---
          final todayScans = store.scans.where((s) => s['undone_at'] == null).toList();
          final todayPts = todayScans.fold<int>(0, (a, s) => a + ((s['points'] as num?)?.toInt() ?? 0));
          final todayMoney = todayScans.fold<double>(0, (a, s) => a + (amountOf(s) ?? 0));

          // --- Points clés ---
          final dVisits = _delta(cur.visits, prev.visits);
          final ins = <(IconData, String)>[];
          if (cur.visits > 0) {
            if (dVisits != null) {
              if (dVisits.abs() < 3) {
                ins.add((Icons.trending_flat_rounded, tr('Fréquentation stable par rapport à la période précédente.', 'الإقبال مستقر مقارنة بالفترة السابقة.')));
              } else if (dVisits > 0) {
                ins.add((Icons.trending_up_rounded, tr('Fréquentation en hausse de ${dVisits.round()}% par rapport à la période précédente.', 'ارتفع الإقبال بنسبة ${dVisits.round()}% مقارنة بالفترة السابقة.')));
              } else {
                ins.add((Icons.trending_down_rounded, tr('Fréquentation en baisse de ${dVisits.abs().round()}% par rapport à la période précédente.', 'انخفض الإقبال بنسبة ${dVisits.abs().round()}% مقارنة بالفترة السابقة.')));
              }
            }
            if (bestDay != null) {
              ins.add((Icons.calendar_today_rounded, tr('Le ${dayFull[bestDay]} est votre jour le plus chargé.', 'يوم ${dayFull[bestDay]} هو الأكثر ازدحامًا.')));
            }
            if (peak != null) {
              ins.add((Icons.schedule_rounded, tr('Le pic d\'affluence se situe entre ${peak}h et ${peak + 1}h.', 'ذروة الإقبال بين الساعة $peak والساعة ${peak + 1}.')));
            }
            if (r.retention != null) {
              ins.add((Icons.repeat_rounded, tr('${r.retention!.round()}% des clients de la période précédente sont revenus.', 'عاد ${r.retention!.round()}% من زبائن الفترة السابقة.')));
            } else if (cur.clients.isNotEmpty) {
              ins.add((Icons.repeat_rounded, tr('${cur.returnRate.round()}% de vos clients sont venus au moins deux fois.', 'زار ${cur.returnRate.round()}% من زبائنك مرتين على الأقل.')));
            }
            if (hasMoney && cur.spentBy.length >= 4 && cur.revenue > 0) {
              final spent = cur.spentBy.values.toList()..sort((a, b) => b.compareTo(a));
              final share = spent.take(3).fold<double>(0, (a, v) => a + v) * 100 / cur.revenue;
              ins.add((Icons.donut_large_rounded, tr("Vos 3 meilleurs clients représentent ${share.round()}% du chiffre d'affaires.", 'أفضل 3 زبائن يمثلون ${share.round()}% من رقم المعاملات.')));
            }
          }

          // --- Rapport copiable ---
          final report = [
            '${store.shop?['name'] ?? 'Nqata Pro'} - ${tr('Rapport', 'تقرير')} ${_dm(r.from)} > ${_dm(r.today)} (${days} ${tr('jours', 'يومًا')})',
            '${tr('Passages', 'الزيارات')} : ${fmtNum(cur.visits)}${_pctTxt(dVisits)}',
            '${tr('Clients différents', 'زبائن مختلفون')} : ${fmtNum(cur.clients.length)}${_pctTxt(_delta(cur.clients.length, prev.clients.length))}',
            '${tr('Nouveaux clients', 'زبائن جدد')} : ${fmtNum(r.newClients)}',
            if (r.retention != null) '${tr('Rétention', 'الاحتفاظ بالزبائن')} : ${r.retention!.round()}%',
            '${tr('Taux de retour', 'نسبة العودة')} : ${cur.returnRate.round()}%',
            if (hasMoney) '${tr("Chiffre d'affaires", 'رقم المعاملات')} : ${fmtMoney(cur.revenue)}${_pctTxt(_delta(cur.revenue, prev.revenue))}',
            if (cur.basket != null) '${tr('Panier moyen', 'متوسط السلة')} : ${fmtMoney(cur.basket!)}',
            '${tr('Points distribués', 'النقاط الممنوحة')} : ${fmtNum(cur.points)}',
            '${tr('Récompenses', 'المكافآت')} : ${r.rewards}',
            if (bestDay != null) '${tr('Meilleur jour', 'أفضل يوم')} : ${dayFull[bestDay]}',
            if (peak != null) '${tr('Heure de pointe', 'ساعة الذروة')} : ${peak}h-${peak + 1}h',
          ].join('\n');

          final updated = store.historyAt;

          return NqScreen(
            title: tr('Statistiques', 'الإحصاءات'),
            body: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
                for (final k in ['history', 'scans'])
                  if (store.errors[k] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Expanded(child: ErrorBanner(k, store.errors[k]!))])),
                const SizedBox(height: 12),
                // Aujourd'hui
                FadeSlideIn(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF16140F), borderRadius: BorderRadius.circular(28)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('Aujourd\'hui', 'اليوم'), style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final e in [
                          ('${todayScans.length}', tr('Passages', 'الزيارات')),
                          ('${todayScans.map((s) => s['client_id']).toSet().length}', tr('Clients', 'الزبائن')),
                          (fmtNum(todayPts), tr('Points', 'النقاط')),
                          if (store.hasAmount) (fmtNum(todayMoney), 'DA'),
                        ])
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              FittedBox(fit: BoxFit.scaleDown, child: Text(e.$1, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
                              Text(e.$2, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        '${tr('Hier', 'أمس')} : ${r.yVisits} ${tr('passages', 'زيارات')}${store.hasAmount && r.yMoney > 0 ? ' · ${fmtMoney(r.yMoney)}' : ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 7, label: Text(tr('7 jours', '7 أيام'))),
                    ButtonSegment(value: 30, label: Text(tr('30 jours', '30 يومًا'))),
                    ButtonSegment(value: 90, label: Text(tr('90 jours', '90 يومًا'))),
                  ],
                  selected: {days},
                  onSelectionChanged: (s) => setState(() => days = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('Du ${_dm(r.from)} au ${_dm(r.today)} · comparé aux $days jours précédents', 'من ${_dm(r.from)} إلى ${_dm(r.today)} · مقارنة بالـ $days يومًا السابقة'),
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
                _title(context, tr('Indicateurs clés', 'المؤشرات الرئيسية')),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: [
                    KpiCard(icon: NI.check, value: fmtNum(cur.visits), label: tr('Passages', 'الزيارات'), delta: dVisits),
                    KpiCard(icon: NI.profile, value: fmtNum(cur.clients.length), label: tr('Clients différents', 'زبائن مختلفون'), delta: _delta(cur.clients.length, prev.clients.length)),
                    KpiCard(icon: NI.badge, value: fmtNum(r.newClients), label: tr('Nouveaux clients', 'زبائن جدد')),
                    KpiCard(icon: NI.clock, value: r.retention == null ? '—' : '${r.retention!.round()}%', label: tr('Rétention', 'الاحتفاظ بالزبائن')),
                    KpiCard(icon: NI.money, value: hasMoney ? fmtMoney(cur.revenue) : '—', label: tr('Chiffre d\'affaires', 'رقم المعاملات'), delta: hasMoney ? _delta(cur.revenue, prev.revenue) : null),
                    KpiCard(icon: NI.basket, value: cur.basket == null ? '—' : fmtMoney(cur.basket!), label: tr('Panier moyen', 'متوسط السلة'), delta: cur.basket == null || prev.basket == null ? null : _delta(cur.basket!, prev.basket!)),
                    KpiCard(
                      icon: NI.repeat,
                      value: '${cur.returnRate.round()}%',
                      label: tr('Taux de retour', 'نسبة العودة'),
                      delta: prev.clients.isEmpty ? null : cur.returnRate - prev.returnRate,
                      deltaSuffix: ' pt',
                    ),
                    KpiCard(
                      icon: NI.clients,
                      value: cur.visitsPerClient == null ? '—' : _dec(cur.visitsPerClient!),
                      label: tr('Visites par client', 'زيارات لكل زبون'),
                      delta: cur.visitsPerClient == null || prev.visitsPerClient == null ? null : _delta(cur.visitsPerClient!, prev.visitsPerClient!),
                    ),
                    KpiCard(icon: NI.points, value: fmtNum(cur.points), label: tr('Points distribués', 'النقاط الممنوحة'), delta: _delta(cur.points, prev.points)),
                    KpiCard(icon: NI.gift, value: '${r.rewards}', label: tr('Récompenses', 'المكافآت'), delta: _delta(r.rewards, r.prevRewards)),
                  ],
                ),
                if (!store.hasAmount)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(tr('Panier moyen et chiffre d\'affaires indisponibles : ajoutez la colonne « montant » à la base (voir supabase_update.sql).', 'متوسط السلة ورقم المعاملات غير متاحين: أضف عمود «المبلغ» إلى قاعدة البيانات (انظر supabase_update.sql).'), style: const TextStyle(fontSize: 12, color: kWarn)),
                  )
                else if (cur.amounts == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(tr('Saisissez le montant de l\'achat après chaque scan pour voir le panier moyen et le chiffre d\'affaires.', 'أدخل مبلغ الشراء بعد كل مسح لتظهر السلة المتوسطة ورقم المعاملات.'), style: const TextStyle(fontSize: 12, color: kMuted)),
                  ),
                _title(context, tr('Points clés', 'أبرز النقاط')),
                FadeSlideIn(
                  index: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                    child: ins.isEmpty
                        ? Text(tr('Aucune activité sur cette période.', 'لا يوجد نشاط في هذه الفترة.'), style: const TextStyle(color: kMuted))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            for (var i = 0; i < ins.length; i++)
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(ins[i].$1, size: 20, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(ins[i].$2, style: const TextStyle(fontSize: 14, height: 1.35))),
                                ]),
                              ),
                          ]),
                  ),
                ),
                _title(context, tr('Activité', 'النشاط')),
                FadeSlideIn(
                  index: 2,
                  child: BarChartCard(
                    title: money ? tr('Chiffre d\'affaires', 'رقم المعاملات') : tr('Passages', 'الزيارات'),
                    data: evolution,
                    labelEvery: days <= 7 ? 1 : (days <= 31 ? 5 : 3),
                    fmt: money ? (v) => fmtNum(v) : null,
                    unit: money ? 'DA' : unitVisits,
                    showAverage: true,
                    trailing: store.hasAmount
                        ? SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            segments: const [ButtonSegment(value: false, icon: Icon(Icons.person, size: 16)), ButtonSegment(value: true, icon: Icon(Icons.payments, size: 16))],
                            selected: {money},
                            onSelectionChanged: (s) => setState(() => money = s.first),
                          )
                        : null,
                    footnote: [if (evoNote != null) evoNote!, if (days > 31) tr('Chaque barre = une semaine', 'كل عمود = أسبوع')].join('\n'),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 3,
                  child: BarChartCard(
                    title: tr('Jours les plus chargés', 'الأيام الأكثر ازدحامًا'),
                    data: [for (var i = 0; i < 7; i++) BarData(dayNames[i], r.weekday[i], dayFull[i])],
                    unit: unitVisits,
                    footnote: dayNote,
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 4,
                  child: BarChartCard(
                    title: tr('Heures de pointe', 'ساعات الذروة'),
                    data: hourBars,
                    labelEvery: hourBars.length > 10 ? 2 : 1,
                    unit: unitVisits,
                    footnote: peakNote,
                  ),
                ),
                _title(context, tr('Clients', 'الزبائن')),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Fidélité des clients', 'ولاء الزبائن'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SegmentBar(parts: [
                      (tr('1 visite', 'زيارة واحدة'), once, kNeutral),
                      (tr('2 visites', 'زيارتان'), twice, kAccent),
                      (tr('3 visites et +', '3 زيارات فأكثر'), often, theme.colorScheme.onSurface),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Meilleurs clients', 'أفضل الزبائن'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (top.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('Pas encore de données', 'لا بيانات بعد'), style: const TextStyle(color: kMuted))),
                    for (var i = 0; i < top.length && i < 5; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(radius: 14, backgroundColor: i == 0 ? kAccent : theme.colorScheme.secondaryContainer, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: i == 0 ? kInk : null))),
                        title: Text(store.clientName(top[i].key)),
                        subtitle: cur.spentBy[top[i].key] == null
                            ? null
                            : Text('${fmtMoney(cur.spentBy[top[i].key]!)}${cur.revenue > 0 ? ' · ${(cur.spentBy[top[i].key]! * 100 / cur.revenue).round()}% ${tr('du CA', 'من الإجمالي')}' : ''}'),
                        trailing: Text('${top[i].value} ${tr('visites', 'زيارة')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: report));
                    snack(context, tr('Rapport copié', 'تم نسخ التقرير'));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(tr('Copier le rapport', 'نسخ التقرير')),
                ),
                if (updated != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${tr('Mis à jour à', 'آخر تحديث في')} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: kMuted),
                    ),
                  ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      );
}
