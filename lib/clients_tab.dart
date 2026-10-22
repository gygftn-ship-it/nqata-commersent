import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';
import 'offers_page.dart';

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

          final sortLabels = {_Sort.points: tr('Plus de points', 'الأكثر نقاطًا'), _Sort.recent: tr('Dernière visite', 'آخر زيارة'), _Sort.visits: tr('Plus de visites', 'الأكثر زيارات'), _Sort.name: tr('Nom (A-Z)', 'الاسم (أ-ي)')};
          return NqScreen(
            title: tr('Clients', 'الزبائن'),
            action: PopupMenuButton<_Sort>(
              tooltip: tr('Trier', 'ترتيب'),
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [for (final e in sortLabels.entries) CheckedPopupMenuItem(value: e.key, checked: sort == e.key, child: Text(e.value))],
              child: HeaderPill(icon: Icons.swap_vert_rounded, label: tr('Trier', 'ترتيب')),
            ),
            header: [
              HeaderSearch(hint: '${tr('Rechercher parmi', 'ابحث بين')} ${store.clients.length} ${tr('clients', 'زبون')}', onChanged: (v) => setState(() => q = v)),
              HeaderChips(labels: [for (final f in _Filter.values) labels[f]!], selected: _Filter.values.indexOf(filter), onSelected: (i) => setState(() => filter = _Filter.values[i])),
            ],
            body: Column(children: [
            if (store.errors['clients'] != null) ErrorBanner(tr('liste des clients', 'قائمة الزبائن'), store.errors['clients']!),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), children: [
                  if (store.clients.isNotEmpty) _summary(ready, inactiveCount),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Column(children: [
                        Icon(store.clients.isEmpty ? Icons.qr_code_scanner_rounded : Icons.search_off_rounded, size: 56, color: kMuted),
                        const SizedBox(height: 12),
                        Text(store.clients.isEmpty ? tr('Pas encore de client', 'لا زبائن بعد') : tr('Aucun résultat', 'لا نتائج'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(store.clients.isEmpty ? tr('Scannez le QR d\'un client pour l\'ajouter ici.', 'امسح رمز زبون لإضافته هنا.') : tr('Essayez un autre filtre ou une autre recherche.', 'جرّب فلترًا أو بحثًا آخر.'), textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                      ]),
                    ),
                  for (var i = 0; i < list.length; i++) FadeSlideIn(index: i, child: _tile(list[i], stats['${list[i]['client_id']}'])),
                ]),
              ),
            ),
          ]),
          );
        },
      );

  Widget _stat(IconData i, String v, String l, _Filter f, {bool hl = false}) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(color: hl ? kAccent : cardColor(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: filter == f ? (hl ? kInk : kAccent) : Colors.transparent, width: 2)),
            child: Column(children: [
              Icon(i, size: 22, color: hl ? kInk : null),
              const SizedBox(height: 4),
              Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: hl ? kInk : null)),
              Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: hl ? kInk : kMuted)),
            ]),
          ),
        ),
      );

  /// Trois compteurs cliquables : ils filtrent la liste.
  Widget _summary(int ready, int inactive) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          _stat(Icons.people_alt_rounded, '${store.clients.length}', tr('Clients', 'الزبائن'), _Filter.all),
          const SizedBox(width: 8),
          _stat(Icons.card_giftcard_rounded, '$ready', tr('À récompenser', 'للمكافأة'), _Filter.reward, hl: ready > 0),
          const SizedBox(width: 8),
          _stat(Icons.notifications_active_rounded, '$inactive', tr('À relancer', 'للتذكير'), _Filter.inactive),
        ]),
      );

  Widget _badge(String t, Color bg, Color fg) => Container(
        margin: const EdgeInsetsDirectional.only(start: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      );

  Widget _tile(Map<String, dynamic> c, ClientStat? st) {
    final name = '${c['display_name']}';
    final pts = (c['points'] as num).toInt();
    final ready = pts >= store.threshold;
    final left = store.threshold - pts;
    final loyal = (st?.visits ?? 0) >= 4;
    final inactive = _isInactive(c);
    final dark = isDark(context);
    Widget? badge;
    if (ready) {
      badge = _badge(tr('Récompense', 'مكافأة'), kAccent, kInk);
    } else if (loyal) {
      badge = _badge(tr('Fidèle', 'وفي'), kOk.withOpacity(0.15), kOk);
    } else if (inactive) {
      badge = _badge(tr('À relancer', 'للتذكير'), kWarn.withOpacity(0.15), kWarn);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => ClientSheet(client: c)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              // Avatar entouré d'un anneau de progression vers la récompense
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: (pts / store.threshold).clamp(0.0, 1.0), strokeWidth: 4, backgroundColor: dark ? const Color(0xFF3A372E) : Colors.white, color: ready ? kOk : kBronze)),
                  CircleAvatar(radius: 20, backgroundColor: ready ? kAccent : (dark ? const Color(0xFF3A372E) : Colors.white), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: ready ? kInk : null))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    if (badge != null) badge,
                  ]),
                  const SizedBox(height: 3),
                  Text('$pts ${tr('pts', 'نقطة')} · ${st?.visits ?? 0} ${tr('visites', 'زيارة')} · ${since(c['last_scan_at'] as String?)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMuted)),
                  if (!ready) Text(tr('Plus que $left pts pour la récompense', 'بقي $left نقطة للمكافأة'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              ready
                  ? FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      onPressed: () => validateWithOffer(context, '${c['client_id']}', name),
                      child: Text(tr('Valider', 'تأكيد')),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: kMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fiche détaillée d'un client.
class ClientSheet extends StatelessWidget {
  final Map<String, dynamic> client;
  const ClientSheet({super.key, required this.client});

  Widget _kpi(BuildContext context, Object i, String v, String l) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
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
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 76, height: 76, child: CircularProgressIndicator(value: (pts / store.threshold).clamp(0.0, 1.0), strokeWidth: 5, backgroundColor: Theme.of(context).colorScheme.secondaryContainer, color: ready ? kOk : kBronze)),
              CircleAvatar(radius: 28, backgroundColor: ready ? kAccent : Theme.of(context).colorScheme.secondaryContainer, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ready ? kInk : null))),
            ]),
          ),
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
                final nav = Navigator.of(context);
                final ok = await validateWithOffer(context, id, name);
                if (ok && nav.canPop()) nav.pop();
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
