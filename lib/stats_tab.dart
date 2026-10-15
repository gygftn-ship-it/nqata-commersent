import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'charts.dart';

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
}

double? _delta(num cur, num prev) => prev == 0 ? null : (cur - prev) * 100 / prev;

int _dayDiff(DateTime a, DateTime b) => DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

/// Onglet « Statistiques » : indicateurs, évolution, jours et heures de pointe, meilleurs clients.
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
      if (am != null) { g.revenue += am; g.amounts++; g.spentBy[id] = (g.spentBy[id] ?? 0) + am; }
    }
    return g;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          if (!store.historyLoaded) return const Center(child: CircularProgressIndicator());
          final theme = Theme.of(context);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tomorrow = today.add(const Duration(days: 1));
          final from = today.subtract(Duration(days: days - 1));
          final prevFrom = from.subtract(Duration(days: days));
          final items = [for (final s in store.history) (localDt(s['created_at']), s)];
          final cur = _agg(items, from, tomorrow), prev = _agg(items, prevFrom, from);
          final rewards = store.redeemHistory.where((r) => !localDt(r['created_at']).isBefore(from)).length;
          final prevRewards = store.redeemHistory.where((r) {
            final t = localDt(r['created_at']);
            return !t.isBefore(prevFrom) && t.isBefore(from);
          }).length;
          final hasMoney = store.hasAmount && cur.amounts > 0;

          // --- Évolution (par jour, ou par semaine sur 90 jours) ---
          final size = days > 31 ? 7 : 1;
          final buckets = (days / size).ceil();
          final series = List<double>.filled(buckets, 0);
          for (final it in items) {
            if (it.$1.isBefore(from) || !it.$1.isBefore(tomorrow)) continue;
            final idx = _dayDiff(it.$1, from) ~/ size;
            if (idx < 0 || idx >= buckets) continue;
            series[idx] += money ? (amountOf(it.$2) ?? 0) : 1;
          }
          final evolution = [
            for (var i = 0; i < buckets; i++)
              BarData('${from.add(Duration(days: i * size)).day}/${from.add(Duration(days: i * size)).month}', series[i]),
          ];

          // --- Jours de la semaine ---
          final wd = List<double>.filled(7, 0);
          for (final it in items) {
            if (it.$1.isBefore(from) || !it.$1.isBefore(tomorrow)) continue;
            wd[it.$1.weekday - 1]++;
          }
          final dayNames = lang == 'ar' ? ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'] : ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
          final bestDay = wd.fold<double>(0, (m, v) => v > m ? v : m) == 0 ? null : wd.indexOf(wd.reduce((a, b) => a > b ? a : b));

          // --- Heures de pointe ---
          final hours = List<double>.filled(24, 0);
          for (final it in items) {
            if (it.$1.isBefore(from) || !it.$1.isBefore(tomorrow)) continue;
            hours[it.$1.hour]++;
          }
          var lo = hours.indexWhere((v) => v > 0), hi = hours.lastIndexWhere((v) => v > 0);
          if (lo < 0) { lo = 8; hi = 20; }
          lo = (lo - 1).clamp(0, 23);
          hi = (hi + 1).clamp(0, 23);
          final hourBars = [for (var h = lo; h <= hi; h++) BarData('${h}h', hours[h])];
          final peak = hours.fold<double>(0, (m, v) => v > m ? v : m) == 0 ? null : hours.indexOf(hours.reduce((a, b) => a > b ? a : b));

          // --- Fidélité des clients ---
          final once = cur.perClient.values.where((v) => v == 1).length;
          final twice = cur.perClient.values.where((v) => v == 2).length;
          final often = cur.perClient.values.where((v) => v >= 3).length;

          // --- Meilleurs clients ---
          final top = cur.perClient.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          final todayScans = store.scans.where((s) => s['undone_at'] == null).toList();
          final todayPts = todayScans.fold<int>(0, (a, s) => a + ((s['points'] as num?)?.toInt() ?? 0));
          final todayMoney = todayScans.fold<double>(0, (a, s) => a + (amountOf(s) ?? 0));

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              Text(tr('Statistiques', 'الإحصاءات'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              for (final k in ['history', 'scans']) if (store.errors[k] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Expanded(child: ErrorBanner(k, store.errors[k]!))])),
              const SizedBox(height: 12),
              // Aujourd'hui
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
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
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FittedBox(fit: BoxFit.scaleDown, child: Text(e.$1, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
                          Text(e.$2, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                    ]),
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
              const SizedBox(height: 6),
              Text(tr('Évolution par rapport aux ${days} jours précédents', 'التغير مقارنة بالـ $days يومًا السابقة'), style: const TextStyle(fontSize: 12, color: kMuted)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  KpiCard(icon: NI.check, value: fmtNum(cur.visits), label: tr('Passages', 'الزيارات'), delta: _delta(cur.visits, prev.visits)),
                  KpiCard(icon: NI.profile, value: fmtNum(cur.clients.length), label: tr('Clients différents', 'زبائن مختلفون'), delta: _delta(cur.clients.length, prev.clients.length)),
                  KpiCard(icon: NI.basket, value: cur.basket == null ? '—' : fmtMoney(cur.basket!), label: tr('Panier moyen', 'متوسط السلة'), delta: cur.basket == null || prev.basket == null ? null : _delta(cur.basket!, prev.basket!)),
                  KpiCard(icon: NI.money, value: hasMoney ? fmtMoney(cur.revenue) : '—', label: tr('Chiffre d\'affaires', 'رقم المعاملات'), delta: hasMoney ? _delta(cur.revenue, prev.revenue) : null),
                  KpiCard(icon: NI.repeat, value: '${cur.returnRate.round()}%', label: tr('Taux de retour', 'نسبة العودة'), delta: prev.clients.isEmpty ? null : _delta(cur.returnRate, prev.returnRate)),
                  KpiCard(icon: NI.clients, value: cur.clients.isEmpty ? '—' : (cur.visits / cur.clients.length).toStringAsFixed(1), label: tr('Visites par client', 'زيارات لكل زبون')),
                  KpiCard(icon: NI.points, value: fmtNum(cur.points), label: tr('Points distribués', 'النقاط الممنوحة'), delta: _delta(cur.points, prev.points)),
                  KpiCard(icon: NI.gift, value: '$rewards', label: tr('Récompenses', 'المكافآت'), delta: _delta(rewards, prevRewards)),
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
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: BarChartCard(
                  title: money ? tr('Chiffre d\'affaires', 'رقم المعاملات') : tr('Passages', 'الزيارات'),
                  data: evolution,
                  labelEvery: days <= 7 ? 1 : (days <= 31 ? 5 : 3),
                  fmt: money ? (v) => fmtNum(v) : null,
                  trailing: store.hasAmount
                      ? SegmentedButton<bool>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: const [ButtonSegment(value: false, icon: Icon(Icons.person, size: 16)), ButtonSegment(value: true, icon: Icon(Icons.payments, size: 16))],
                          selected: {money},
                          onSelectionChanged: (s) => setState(() => money = s.first),
                        )
                      : null,
                  footnote: days > 31 ? tr('Chaque barre = une semaine', 'كل عمود = أسبوع') : null,
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: BarChartCard(
                  title: tr('Jours les plus chargés', 'الأيام الأكثر ازدحامًا'),
                  data: [for (var i = 0; i < 7; i++) BarData(dayNames[i], wd[i])],
                  footnote: bestDay == null ? null : '${tr('Meilleur jour', 'أفضل يوم')} : ${dayNames[bestDay]}',
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 3,
                child: BarChartCard(
                  title: tr('Heures de pointe', 'ساعات الذروة'),
                  data: hourBars,
                  labelEvery: hourBars.length > 10 ? 2 : 1,
                  footnote: peak == null ? null : '${tr('Heure de pointe', 'ساعة الذروة')} : ${peak}h–${peak + 1}h',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
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
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Meilleurs clients', 'أفضل الزبائن'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (top.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('Pas encore de données', 'لا بيانات بعد'), style: const TextStyle(color: kMuted))),
                  for (var i = 0; i < top.length && i < 5; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 14, backgroundColor: i == 0 ? kAccent : theme.colorScheme.secondaryContainer, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: i == 0 ? kInk : null))),
                      title: Text(store.clientName(top[i].key)),
                      subtitle: cur.spentBy[top[i].key] == null ? null : Text(fmtMoney(cur.spentBy[top[i].key]!)),
                      trailing: Text('${top[i].value} ${tr('visites', 'زيارة')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
            ]),
          );
        },
      );
}
