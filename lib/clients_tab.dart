import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';

/// Statistiques d'un client calculées depuis l'historique (6 derniers mois).
class ClientStat {
  int visits = 0, amounts = 0;
  double spent = 0;
  DateTime? first, last;
  double? get basket => amounts == 0 ? null : spent / amounts;
  double? get everyDays => visits < 2 || first == null || last == null ? null : last!.difference(first!).inHours / 24 / (visits - 1);
}

Map<String, ClientStat> computeClientStats() {
  final out = <String, ClientStat>{};
  for (final s in store.history) {
    final id = s['client_id'];
    if (id == null) continue;
    final st = out.putIfAbsent('$id', ClientStat.new);
    final t = localDt(s['created_at']);
    st.visits++;
    final a = amountOf(s);
    if (a != null) { st.spent += a; st.amounts++; }
    if (st.first == null || t.isBefore(st.first!)) st.first = t;
    if (st.last == null || t.isAfter(st.last!)) st.last = t;
  }
  return out;
}

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

enum _Filter { all, reward, loyal, inactive, fresh }

enum _Sort { points, recent, visits, name }

class _ClientsTabState extends State<ClientsTab> {
  String q = '';
  _Filter filter = _Filter.all;
  _Sort sort = _Sort.points;

  @override
  void initState() {
    super.initState();
    store.loadHistory();
  }

  Future<void> _reload() async {
    await store.refresh();
    await store.loadHistory(force: true);
  }

  bool _isInactive(Map<String, dynamic> c) {
    final l = c['last_scan_at'] as String?;
    return l == null || DateTime.now().difference(localDt(l)).inDays >= 7;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final stats = computeClientStats();
          final now = DateTime.now();
          final ready = store.clients.where((c) => (c['points'] as num) >= store.threshold).length;
          final inactiveCount = store.clients.where(_isInactive).length;

          bool keep(Map<String, dynamic> c) {
            if (!'${c['display_name']}'.toLowerCase().contains(q.toLowerCase())) return false;
            final st = stats['${c['client_id']}'];
            switch (filter) {
              case _Filter.all: return true;
              case _Filter.reward: return (c['points'] as num) >= store.threshold;
              case _Filter.loyal: return (st?.visits ?? 0) >= 4;
              case _Filter.inactive: return _isInactive(c);
              case _Filter.fresh: return st?.first != null && now.difference(st!.first!).inDays <= 30 && st.visits <= 2;
            }
          }

          final list = store.clients.where(keep).toList();
          int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
            switch (sort) {
              case _Sort.points: return (b['points'] as num).compareTo(a['points'] as num);
              case _Sort.recent: return '${b['last_scan_at'] ?? ''}'.compareTo('${a['last_scan_at'] ?? ''}');
              case _Sort.visits: return (stats['${b['client_id']}']?.visits ?? 0).compareTo(stats['${a['client_id']}']?.visits ?? 0);
              case _Sort.name: return '${a['display_name']}'.toLowerCase().compareTo('${b['display_name']}'.toLowerCase());
            }
          }
          list.sort(cmp);

          final labels = {
            _Filter.all: tr('Tous', 'الكل'),
            _Filter.reward: '${tr('Récompense', 'مكافأة')} ($ready)',
            _Filter.loyal: tr('Fidèles (4+ visites)', 'أوفياء (4+ زيارات)'),
            _Filter.fresh: tr('Nouveaux', 'جدد'),
            _Filter.inactive: '${tr('À relancer', 'للتذكير')} ($inactiveCount)',
          };

          return Column(children: [
            if (store.errors['clients'] != null) ErrorBanner(tr('liste des clients', 'قائمة الزبائن'), store.errors['clients']!),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => q = v),
                    decoration: InputDecoration(prefixIcon: const NIcon(NI.search, size: 22), hintText: '${tr('Rechercher parmi', 'ابحث بين')} ${store.clients.length} ${tr('clients', 'زبون')}', border: const OutlineInputBorder()),
                  ),
                ),
                PopupMenuButton<_Sort>(
                  icon: const NIcon(NI.sort),
                  tooltip: tr('Trier', 'ترتيب'),
                  onSelected: (v) => setState(() => sort = v),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(value: _Sort.points, checked: sort == _Sort.points, child: Text(tr('Plus de points', 'الأكثر نقاطًا'))),
                    CheckedPopupMenuItem(value: _Sort.recent, checked: sort == _Sort.recent, child: Text(tr('Dernière visite', 'آخر زيارة'))),
                    CheckedPopupMenuItem(value: _Sort.visits, checked: sort == _Sort.visits, child: Text(tr('Plus de visites', 'الأكثر زيارات'))),
                    CheckedPopupMenuItem(value: _Sort.name, checked: sort == _Sort.name, child: Text(tr('Nom (A-Z)', 'الاسم (أ-ي)'))),
                  ],
                ),
              ]),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(label: Text(labels[f]!), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
                  ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 12), children: [
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun client', 'لا زبائن')))),
                  for (var i = 0; i < list.length; i++) FadeSlideIn(index: i, child: _tile(list[i], stats['${list[i]['client_id']}'])),
                ]),
              ),
            ),
          ]);
        },
      );

  Widget _tile(Map<String, dynamic> c, ClientStat? st) {
    final name = '${c['display_name']}';
    final pts = (c['points'] as num).toInt();
    final ready = pts >= store.threshold;
    return ListTile(
      onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => ClientSheet(client: c)),
      leading: CircleAvatar(backgroundColor: ready ? kAccent : Theme.of(context).colorScheme.secondaryContainer, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: ready ? kInk : null))),
      title: Text(name),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$pts ${tr('pts', 'نقطة')} · ${st?.visits ?? 0} ${tr('visites', 'زيارة')} · ${since(c['last_scan_at'] as String?)}'),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (pts / store.threshold).clamp(0.0, 1.0), minHeight: 4)),
      ]),
      trailing: ready
          ? FilledButton.tonal(
              onPressed: () async {
                try {
                  await store.redeem('${c['client_id']}');
                  snack(context, tr('Récompense validée', 'تم تأكيد المكافأة'));
                } catch (e) {
                  snack(context, errText(e));
                }
              },
              child: Text(tr('Valider', 'تأكيد')),
            )
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Fiche détaillée d'un client.
class ClientSheet extends StatelessWidget {
  final Map<String, dynamic> client;
  const ClientSheet({super.key, required this.client});

  Widget _kpi(BuildContext context, Object i, String v, String l) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ic(i, size: 20),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Text(l, style: const TextStyle(fontSize: 11)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final id = '${client['client_id']}';
    final name = '${client['display_name']}';
    final pts = (client['points'] as num).toInt();
    final ready = pts >= store.threshold;
    final st = computeClientStats()[id];
    final scans = store.history.where((s) => '${s['client_id']}' == id).take(30).toList();
    final h = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h * 0.85),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), shrinkWrap: true, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(st?.first == null ? tr('Pas encore de visite enregistrée', 'لا زيارات مسجلة') : '${tr('Client depuis le', 'زبون منذ')} ${dmy(st!.first!)}', style: const TextStyle(color: kMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (pts / store.threshold).clamp(0.0, 1.0), minHeight: 6)),
        const SizedBox(height: 6),
        Text('$pts / ${store.threshold} ${tr('points pour la récompense', 'نقطة للمكافأة')}'),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton.icon(
              icon: const NIcon(NI.gift, size: 20),
              label: Text(tr('Valider la récompense', 'تأكيد المكافأة')),
              onPressed: () async {
                final m = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                try {
                  await store.redeem(id);
                  nav.pop();
                  m.showSnackBar(SnackBar(content: Text(tr('Récompense validée', 'تم تأكيد المكافأة'))));
                } catch (e) {
                  m.showSnackBar(SnackBar(content: Text(errText(e))));
                }
              },
            ),
          ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: [
            _kpi(context, NI.repeat, '${st?.visits ?? 0}', tr('Visites (6 mois)', 'الزيارات (6 أشهر)')),
            _kpi(context, NI.clock, since(client['last_scan_at'] as String?), tr('Dernière visite', 'آخر زيارة')),
            _kpi(context, NI.calendar, st?.everyDays == null ? '—' : tr('tous les ${st!.everyDays!.round()} j', 'كل ${st!.everyDays!.round()} يوم'), tr('Fréquence', 'التكرار')),
            _kpi(context, NI.money, st == null || st.amounts == 0 ? '—' : fmtMoney(st.spent), tr('Dépenses', 'المشتريات')),
            _kpi(context, NI.basket, st?.basket == null ? '—' : fmtMoney(st!.basket!), tr('Panier moyen', 'متوسط السلة')),
            _kpi(context, NI.points, '$pts', tr('Points', 'النقاط')),
          ],
        ),
        const SizedBox(height: 20),
        Text(tr('Historique des visites', 'سجل الزيارات'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (scans.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr('Aucune visite', 'لا زيارات'), style: const TextStyle(color: kMuted))),
        for (final s in scans)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline_rounded, color: kOk),
            title: Text('${dmy(localDt(s['created_at']))} · ${hm(s['created_at'] as String?)}'),
            subtitle: amountOf(s) == null ? null : Text(fmtMoney(amountOf(s)!)),
            trailing: Text('+${s['points']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}
