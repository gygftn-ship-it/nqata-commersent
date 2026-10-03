import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart';
import 'shop_tab.dart';

// ---------- Utilitaires ----------
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, this.index = 0, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + 60 * (index > 8 ? 8 : index)),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch)),
      );
}

class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount(this.value, {super.key, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}', style: style),
      );
}

String hm(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.parse(iso).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String since(String? iso) {
  if (iso == null) return '-';
  final n = DateTime.now().difference(DateTime.parse(iso).toLocal()).inDays;
  return n == 0 ? tr('aujourd\'hui', 'اليوم') : tr('il y a $n j', 'منذ $n يوم');
}

String until(String? iso) {
  if (iso == null) return '';
  final d = DateTime.parse(iso).toLocal();
  return ' · ${tr('jusqu\'au', 'حتى')} ${d.day}/${d.month}';
}

void snack(BuildContext context, String m) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// ---------- Coque : 5 onglets ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  void initState() { super.initState(); store.addListener(_rebuild); }
  @override
  void dispose() { store.removeListener(_rebuild); super.dispose(); }
  void _rebuild() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    const pages = [ScannerTab(), TodayTab(), ClientsTab(), OffersTab(), ShopTab()];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) { HapticFeedback.selectionClick(); setState(() => tab = i); },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.qr_code_scanner_rounded), label: tr('Scanner', 'مسح')),
          NavigationDestination(icon: const Icon(Icons.today_rounded), label: tr('Aujourd\'hui', 'اليوم')),
          NavigationDestination(icon: const Icon(Icons.groups_rounded), label: tr('Clients', 'الزبائن')),
          NavigationDestination(icon: const Icon(Icons.campaign_rounded), label: tr('Offres', 'العروض')),
          NavigationDestination(icon: const Icon(Icons.storefront_rounded), label: tr('Mon commerce', 'متجري')),
        ],
      ),
    );
  }
}

// ---------- 1. Scanner ----------
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key});
  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(children: [
              Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24))),
              AnimatedBuilder(
                animation: c,
                builder: (_, __) => Align(
                  alignment: Alignment(0, -1 + 2 * c.value),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Colors.greenAccent, blurRadius: 8)]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});
  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  bool busy = false;

  @override
  void dispose() { controller.dispose(); manual.dispose(); super.dispose(); }

  Future<void> _handle(String raw) async {
    if (busy || raw.trim().isEmpty) return;
    busy = true;
    try {
      final r = await store.scan(raw);
      if (!mounted) return;
      await _success(r);
    } catch (e) {
      if (mounted) await _error(errText(e));
    }
    await Future.delayed(const Duration(milliseconds: 800));
    busy = false;
  }

  Future<void> _error(String msg) {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      builder: (d) {
        Timer(const Duration(milliseconds: 3000), () { if (d.mounted && Navigator.of(d).canPop()) Navigator.of(d).pop(); });
        return AlertDialog(icon: const Icon(Icons.error, color: Colors.red, size: 64), content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)));
      },
    );
  }

  Future<void> _success(Map<String, dynamic> r) {
    HapticFeedback.mediumImpact();
    final bal = r['balance'] as int;
    final ready = bal >= store.threshold;
    return showDialog(
      context: context,
      builder: (d) {
        if (!ready) Timer(const Duration(seconds: 4), () { if (d.mounted && Navigator.of(d).canPop()) Navigator.of(d).pop(); });
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: Text('${r['client_name']}', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('+${r['points_added']} ${tr('points', 'نقطة')}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text('${tr('Solde', 'الرصيد')} : $bal'),
            if (ready)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text('🎁 ${tr('Récompense disponible', 'مكافأة متاحة')}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await store.undo('${r['scan_id']}');
                  if (d.mounted) Navigator.pop(d);
                  snack(context, tr('Scan annulé', 'تم إلغاء المسح'));
                } catch (e) {
                  snack(context, errText(e));
                }
              },
              child: Text(tr('Annuler le scan', 'إلغاء المسح')),
            ),
            if (ready && r['client_id'] != null)
              FilledButton(
                onPressed: () async {
                  try {
                    await store.redeem('${r['client_id']}');
                    if (d.mounted) Navigator.pop(d);
                    snack(context, tr('Récompense validée', 'تم تأكيد المكافأة'));
                  } catch (e) {
                    snack(context, errText(e));
                  }
                },
                child: Text(tr('Valider la récompense', 'تأكيد المكافأة')),
              ),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: Stack(children: [
            MobileScanner(
              controller: controller,
              errorBuilder: (c, e) => Container(color: Colors.black, alignment: Alignment.center, padding: const EdgeInsets.all(24), child: Text('${tr('Caméra', 'الكاميرا')} : ${e.errorCode.name}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18))),
              onDetect: (cap) {
                final v = cap.barcodes.firstOrNull?.rawValue;
                if (v != null) _handle(v);
              },
            ),
            const ScanFrame(),
            Positioned(top: 8, right: 8, child: IconButton.filled(icon: const Icon(Icons.flashlight_on), onPressed: controller.toggleTorch)),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text('${store.shop?['name'] ?? ''}', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: manual,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: tr('Code client (ou téléphone)', 'رمز الزبون (أو الهاتف)'), border: const OutlineInputBorder()),
                onSubmitted: (v) { _handle(v); manual.clear(); },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () { _handle(manual.text); manual.clear(); }, child: Text(tr('Valider', 'تأكيد'))),
          ]),
        ),
      ]);
}

// ---------- 2. Aujourd'hui ----------
class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  Widget _stat(BuildContext context, IconData i, int v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, color: brandLight),
            AnimatedCount(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(l, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );

  bool _canUndo(Map<String, dynamic> s) {
    if (s['undone_at'] != null) return false;
    if (store.manager) return true;
    return s['staff_id'] == store.uid && DateTime.now().difference(DateTime.parse('${s['created_at']}').toLocal()) < const Duration(minutes: 5);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final valid = store.scans.where((s) => s['undone_at'] == null).toList();
          final points = valid.fold<int>(0, (a, s) => a + (s['points'] as int));
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              Text(tr('Aujourd\'hui', 'اليوم'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              FadeSlideIn(child: Row(children: [
                _stat(context, Icons.check_circle_rounded, valid.length, tr('Passages', 'الزيارات')),
                const SizedBox(width: 10),
                _stat(context, Icons.person_rounded, valid.map((s) => s['client_id']).toSet().length, tr('Clients', 'الزبائن')),
              ])),
              const SizedBox(height: 10),
              FadeSlideIn(index: 1, child: Row(children: [
                _stat(context, Icons.stars_rounded, points, tr('Points donnés', 'النقاط الممنوحة')),
                const SizedBox(width: 10),
                _stat(context, Icons.card_giftcard_rounded, store.redeems.length, tr('Récompenses', 'المكافآت')),
              ])),
              const SizedBox(height: 20),
              Text(tr('Derniers scans', 'آخر المسح'), style: Theme.of(context).textTheme.titleMedium),
              if (store.scans.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('Aucun scan aujourd\'hui', 'لا مسح اليوم')))),
              for (var i = 0; i < store.scans.length; i++)
                FadeSlideIn(
                  index: i,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: store.scans[i]['undone_at'] != null ? Colors.grey : Colors.green,
                      child: Icon(store.scans[i]['undone_at'] != null ? Icons.block : Icons.check, color: Colors.white),
                    ),
                    title: Text(store.clientName(store.scans[i]['client_id'] as String?)),
                    subtitle: Text(store.scans[i]['undone_at'] != null ? '${hm(store.scans[i]['created_at'] as String?)} · ${tr('annulé', 'ملغى')}' : hm(store.scans[i]['created_at'] as String?)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('+${store.scans[i]['points']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_canUndo(store.scans[i]))
                        IconButton(
                          icon: const Icon(Icons.undo),
                          tooltip: tr('Annuler', 'إلغاء'),
                          onPressed: () async {
                            try {
                              await store.undo('${store.scans[i]['id']}');
                            } catch (e) {
                              snack(context, errText(e));
                            }
                          },
                        ),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

// ---------- 3. Clients ----------
class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  String q = '';
  bool inactive = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final list = store.clients.where((c) {
            if (!'${c['display_name']}'.toLowerCase().contains(q.toLowerCase())) return false;
            if (!inactive) return true;
            final l = c['last_scan_at'] as String?;
            return l == null || DateTime.now().difference(DateTime.parse(l).toLocal()).inDays >= 7;
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Rechercher un client', 'ابحث عن زبون'), border: const OutlineInputBorder()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(label: Text(tr('À relancer (7 j et +)', 'للتذكير (7 أيام فأكثر)')), selected: inactive, onSelected: (v) => setState(() => inactive = v)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: store.refresh,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun client', 'لا زبائن')))),
                  for (var i = 0; i < list.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${list[i]['display_name']}'.isEmpty ? '?' : '${list[i]['display_name']}'[0].toUpperCase())),
                        title: Text('${list[i]['display_name']}'),
                        subtitle: Text('${list[i]['points']} ${tr('points', 'نقطة')} · ${since(list[i]['last_scan_at'] as String?)}'),
                        trailing: (list[i]['points'] as int) >= store.threshold
                            ? FilledButton.tonal(
                                onPressed: () async {
                                  try {
                                    await store.redeem('${list[i]['client_id']}');
                                    snack(context, tr('Récompense validée', 'تم تأكيد المكافأة'));
                                  } catch (e) {
                                    snack(context, errText(e));
                                  }
                                },
                                child: Text(tr('🎁 Valider', '🎁 تأكيد')),
                              )
                            : null,
                      ),
                    ),
                ]),
              ),
            ),
          ]);
        },
      );
}

// ---------- 4. Offres ----------
class OffersTab extends StatefulWidget {
  const OffersTab({super.key});
  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  final custom = TextEditingController();
  int tpl = 0, aud = 0, days = 0; // days : 0 = sans limite
  bool busy = false;

  static const templates = [
    ('-15 % mardi', '-15٪ يوم الثلاثاء'),
    ('Café offert', 'قهوة مجانية'),
    ('Double points ce week-end', 'نقاط مضاعفة في عطلة الأسبوع'),
    ('Nouveau : venez découvrir', 'جديد: تعالوا واكتشفوا'),
  ];
  static const audiences = [('all', 'Tous', 'الجميع'), ('loyal', 'Fidèles', 'الأوفياء'), ('inactive', 'Inactifs', 'غير النشطين')];

  @override
  void dispose() { custom.dispose(); super.dispose(); }

  Future<void> _send() async {
    final title = custom.text.trim().isNotEmpty ? custom.text.trim() : tr(templates[tpl].$1, templates[tpl].$2);
    setState(() => busy = true);
    try {
      await store.sendOffer(title, audiences[aud].$1, days: days == 0 ? null : days);
      custom.clear();
      snack(context, tr('Offre envoyée aux clients concernés', 'تم إرسال العرض للزبائن المعنيين'));
    } catch (e) {
      snack(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!store.manager) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(tr('Les offres sont réservées au propriétaire et aux gérants.', 'العروض مخصصة للمالك والمديرين.'), textAlign: TextAlign.center)));
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final title = Theme.of(context).textTheme.titleMedium;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(tr('Nouvelle offre', 'عرض جديد'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < templates.length; i++) ChoiceChip(label: Text(tr(templates[i].$1, templates[i].$2)), selected: tpl == i, onSelected: (_) => setState(() => tpl = i)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: custom, decoration: InputDecoration(labelText: tr('Ou écrivez votre offre', 'أو اكتب عرضك'), border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          Text(tr('Destinataires', 'المستلمون'), style: title),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [for (var i = 0; i < audiences.length; i++) ButtonSegment(value: i, label: Text(tr(audiences[i].$2, audiences[i].$3)))],
            selected: {aud},
            onSelectionChanged: (s) => setState(() => aud = s.first),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Text(tr('Durée de l\'offre', 'مدة العرض'), style: title),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [ButtonSegment(value: 0, label: Text(tr('Sans limite', 'بدون حد'))), ButtonSegment(value: 7, label: Text(tr('7 jours', '7 أيام'))), ButtonSegment(value: 30, label: Text(tr('30 jours', '30 يومًا')))],
            selected: {days},
            onSelectionChanged: (s) => setState(() => days = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.send), label: Text(tr('Envoyer l\'offre', 'إرسال العرض')), onPressed: busy ? null : _send),
          const SizedBox(height: 24),
          if (store.offers.isNotEmpty) Text(tr('Offres envoyées', 'العروض المرسلة'), style: title),
          for (final o in store.offers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_offer_rounded, color: brandLight),
              title: Text('${o['title']}'),
              subtitle: Text('${audiences.firstWhere((a) => a.$1 == o['audience'], orElse: () => audiences[0]).$2} · ${since(o['created_at'] as String?)}${until(o['expires_at'] as String?)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    await store.deleteOffer('${o['id']}');
                  } catch (e) {
                    snack(context, errText(e));
                  }
                },
              ),
            ),
        ]);
      },
    );
  }
}
