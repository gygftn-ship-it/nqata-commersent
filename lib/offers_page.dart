import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';
import 'tabs.dart';
import 'icons.dart';

// ---------- Types d'offres ----------
/// (code, français, arabe, icône, unité de la valeur : '%', 'DA' ou '' si pas de valeur)
const offerKinds = [
  ('percent', 'Réduction %', 'تخفيض ٪', Icons.percent_rounded, '%'),
  ('amount', 'Remise en DA', 'خصم بالدينار', Icons.sell_rounded, 'DA'),
  ('gift', 'Cadeau offert', 'هدية مجانية', Icons.card_giftcard_rounded, ''),
  ('points', 'Points bonus', 'نقاط إضافية', Icons.stars_rounded, 'pts'),
  ('custom', 'Autre', 'أخرى', Icons.local_offer_rounded, ''),
];

const offerAudiences = [('all', 'Tous', 'الجميع'), ('loyal', 'Fidèles', 'الأوفياء'), ('inactive', 'Inactifs', 'غير النشطين')];

IconData offerIcon(String? kind) => offerKinds.firstWhere((k) => k.$1 == kind, orElse: () => offerKinds.last).$4;

/// Résumé lisible de la valeur : « -20 % », « -500 DA », « +50 pts »…
String offerValueLabel(Map<String, dynamic> o) {
  final v = o['value'] as num?;
  if (v == null) return '';
  final k = '${o['kind']}';
  final n = v == v.roundToDouble() ? fmtNum(v) : v.toString();
  if (k == 'percent') return '-$n %';
  if (k == 'amount') return '-$n DA';
  if (k == 'points') return '+$n pts';
  return n;
}

// ---------- Pop-up de validation : quelle offre le client a-t-il choisie ? ----------
/// À la récompense : le commerçant choisit l'offre du client (ou la récompense de fidélité) puis confirme.
/// Retourne true si la récompense a été validée.
Future<bool> validateWithOffer(BuildContext context, String clientId, String clientName) async {
  final live = store.offers.where(store.offerLive).toList();
  // Réglage « Jamais » : on valide directement, sans demander l'offre.
  final res = store.offerAsk == 'never'
      ? const _Pick(null)
      : await showDialog<_Pick>(
          context: context,
          builder: (_) => _OfferPickDialog(clientName: clientName, offers: live, scan: false),
        );
  if (res == null || !context.mounted) return false;
  final m = ScaffoldMessenger.of(context);
  try {
    final saved = await store.redeem(clientId, offer: res.offer);
    m.showSnackBar(SnackBar(
      content: Text(res.offer == null
          ? tr('Récompense validée', 'تم تأكيد المكافأة')
          : saved
              ? '${tr('Offre validée', 'تم تأكيد العرض')} : ${res.offer!['title']}'
              : tr('Récompense validée, mais l\'offre n\'a pas pu être enregistrée (appliquez supabase_offer_tracking.sql)', 'تم تأكيد المكافأة لكن تعذّر تسجيل العرض (طبّق supabase_offer_tracking.sql)')),
    ));
    return true;
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(errText(e))));
    return false;
  }
}

/// À chaque scan (réglage « Demander l'offre ») : quelle offre le client utilise-t-il ?
/// `r` = résultat du scan (client_id, client_name, scan_id). Sans effet s'il n'y a aucune offre en cours.
Future<void> pickOfferForScan(BuildContext context, Map<String, dynamic> r) async {
  final live = store.offers.where(store.offerLive).toList();
  if (live.isEmpty || r['client_id'] == null) return;
  final res = await showDialog<_Pick>(
    context: context,
    builder: (_) => _OfferPickDialog(clientName: '${r['client_name']}', offers: live, scan: true),
  );
  if (res == null || !context.mounted) return;
  final m = ScaffoldMessenger.of(context);
  if (res.amount != null) {
    try {
      await store.setScanAmount('${r['scan_id']}', res.amount!);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errText(e))));
    }
  }
  if (res.offer == null) return;
  final saved = await store.recordOffer('${r['client_id']}', res.offer!, scanId: '${r['scan_id']}');
  m.showSnackBar(SnackBar(
    content: Text(saved
        ? '${tr('Offre validée', 'تم تأكيد العرض')} : ${res.offer!['title']}'
        : tr('L\'offre n\'a pas pu être enregistrée (appliquez supabase_offer_tracking.sql)', 'تعذّر تسجيل العرض (طبّق supabase_offer_tracking.sql)')),
  ));
}

class _Pick {
  final Map<String, dynamic>? offer; // null = récompense de fidélité (ou « aucune offre » en mode scan)
  final double? amount;
  const _Pick(this.offer, {this.amount});
}

class _OfferPickDialog extends StatefulWidget {
  final String clientName;
  final List<Map<String, dynamic>> offers;
  final bool scan; // true : pop-up à chaque scan · false : pop-up à la récompense
  const _OfferPickDialog({required this.clientName, required this.offers, required this.scan});
  @override
  State<_OfferPickDialog> createState() => _OfferPickDialogState();
}

class _OfferPickDialogState extends State<_OfferPickDialog> {
  int? sel; // -1 = récompense standard / aucune offre, sinon index dans offers
  final amount = TextEditingController();

  @override
  void dispose() { amount.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget option(int value, IconData icon, String title, String? sub) {
      final on = sel == value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: on ? kAccentSoft : cardColor(context),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => sel = value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? kAccent : Colors.transparent, width: 2)),
              child: Row(children: [
                Icon(icon, color: on ? kInk : cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: on ? kInk : null)),
                    if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: on ? kInk.withOpacity(0.7) : kMuted)),
                  ]),
                ),
                if (on) const Icon(Icons.check_circle_rounded, color: kInk),
              ]),
            ),
          ),
        ),
      );
    }

    final showNone = !widget.scan || store.offerAllowNone;
    return AlertDialog(
      title: Text(widget.scan ? tr('Quelle offre le client utilise-t-il ?', 'أي عرض يستعمله الزبون؟') : tr('Quelle offre valider ?', 'أي عرض تريد تأكيده؟')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tr('Client', 'الزبون')} : ${widget.clientName}', style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            for (var i = 0; i < widget.offers.length; i++)
              option(
                i,
                offerIcon('${widget.offers[i]['kind']}'),
                '${widget.offers[i]['title']}',
                [offerValueLabel(widget.offers[i]), '${widget.offers[i]['description'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '),
              ),
            if (showNone)
              widget.scan
                  ? option(-1, Icons.do_not_disturb_alt_rounded, tr('Aucune offre', 'بدون عرض'), tr('Simple passage', 'زيارة عادية'))
                  : option(-1, Icons.workspace_premium_rounded, tr('Récompense de fidélité', 'مكافأة الولاء'), '${store.threshold} ${tr('points', 'نقطة')}'),
            if (widget.offers.isEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Aucune offre en cours. Créez-en dans Commerce > Offres.', 'لا توجد عروض سارية. أنشئ عرضًا من المتجر > العروض.'), style: const TextStyle(fontSize: 12.5, color: kMuted))),
            if (widget.scan && store.askAmount && store.hasAmount) ...[
              const SizedBox(height: 8),
              TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Montant de l\'achat (optionnel)', 'مبلغ الشراء (اختياري)'), suffixText: 'DA')),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.scan ? tr('Plus tard', 'لاحقًا') : tr('Annuler', 'إلغاء'))),
        FilledButton(
          onPressed: sel == null
              ? null
              : () {
                  final v = double.tryParse(amount.text.replaceAll(',', '.').replaceAll(' ', ''));
                  Navigator.pop(context, _Pick(sel == -1 ? null : widget.offers[sel!], amount: v != null && v > 0 ? v : null));
                },
          child: Text(tr('Valider', 'تأكيد')),
        ),
      ],
    );
  }
}

// ---------- Historique : quelle offre a été validée, pour qui, quand, par qui ----------
class OfferHistoryPage extends StatefulWidget {
  const OfferHistoryPage({super.key});
  @override
  State<OfferHistoryPage> createState() => _OfferHistoryPageState();
}

class _OfferHistoryPageState extends State<OfferHistoryPage> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    store.loadOfferLog().then((_) { if (mounted) setState(() => loading = false); });
  }

  String _offerTitle(Map<String, dynamic> row) {
    final saved = row['offer_title'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    for (final o in store.offers) {
      if ('${o['id']}' == '${row['offer_id']}') return '${o['title']}';
    }
    return tr('Offre supprimée', 'عرض محذوف');
  }

  String _staffName(Object? id) {
    if (id == null) return '';
    if (id == store.uid) return tr('Moi', 'أنا');
    for (final m in store.team) {
      if (m['user_id'] == id) return '${m['display_name']}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final rows = store.offerLog;
            return NqScreen(
              title: tr('Historique', 'السجل'),
              action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
              header: [Text(tr('Offres validées par vos clients', 'العروض التي أكدها زبائنك'), style: const TextStyle(color: Colors.white70, fontSize: 16))],
              body: RefreshIndicator(
                onRefresh: store.loadOfferLog,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
                  if (store.errors['offerLog'] != null && rows.isEmpty) ErrorBanner(tr('historique des offres', 'سجل العروض'), store.errors['offerLog']!),
                  if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  if (!loading && rows.isEmpty && store.errors['offerLog'] == null) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucune offre validée pour l\'instant', 'لا عروض مؤكدة بعد'), style: const TextStyle(color: kMuted)))),
                  for (var i = 0; i < rows.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(22)),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_offer_rounded, color: kInk, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_offerTitle(rows[i]), style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                [
                                  store.clientName(rows[i]['client_id'] as String?),
                                  if (rows[i]['created_at'] != null) '${dmy(localDt(rows[i]['created_at']))} ${hm(rows[i]['created_at'] as String?)}',
                                  if (_staffName(rows[i]['staff_id']).isNotEmpty) '${tr('par', 'بواسطة')} ${_staffName(rows[i]['staff_id'])}',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12.5, color: kMuted),
                              ),
                            ]),
                          ),
                          if (rows[i]['source'] == 'reward') const Icon(Icons.workspace_premium_rounded, size: 20, color: kBronze),
                        ]),
                      ),
                    ),
                ]),
              ),
            );
          },
        ),
      );
}

// ---------- Page des offres ----------
/// Page des offres, ouverte depuis l'onglet Commerce (propriétaire et gérants).
class OffersPage extends StatefulWidget {
  const OffersPage({super.key});
  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  int filter = 0; // 0 en cours · 1 terminées · 2 toutes

  Future<void> _openEditor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _OfferEditor(),
    );
  }

  Future<void> _delete(Map<String, dynamic> o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Supprimer cette offre ?', 'حذف هذا العرض؟')),
        content: Text('${o['title']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(d, true), child: Text(tr('Supprimer', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.deleteOffer('${o['id']}');
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Future<void> _toggle(Map<String, dynamic> o) async {
    try {
      await store.setOfferActive('${o['id']}', o['active'] == false);
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Widget _card(Map<String, dynamic> o) {
    final live = store.offerLive(o);
    final paused = o['active'] == false;
    final expired = !paused && !live;
    final aud = offerAudiences.firstWhere((a) => a.$1 == o['audience'], orElse: () => offerAudiences[0]);
    final value = offerValueLabel(o);
    final desc = '${o['description'] ?? ''}';
    final uses = store.offerUses['${o['id']}'] ?? 0;
    final status = paused ? tr('En pause', 'متوقف') : expired ? tr('Terminée', 'منتهي') : tr('En cours', 'ساري');
    final statusColor = live ? kOk : kMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: live ? kAccent : kNeutral.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
            child: Icon(offerIcon('${o['kind']}'), color: kInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (value.isNotEmpty) Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: kBronze)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(desc, style: const TextStyle(fontSize: 13.5))),
        const SizedBox(height: 10),
        Text(
          '${tr(aud.$2, aud.$3)} · ${since(o['created_at'] as String?)}${until(o['expires_at'] as String?)}'
          '${store.offersExt ? ' · $uses ${tr('validation(s)', 'تأكيد')}' : ''}',
          style: const TextStyle(fontSize: 12.5, color: kMuted),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (store.offersExt && !expired)
            TextButton.icon(
              icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
              label: Text(paused ? tr('Réactiver', 'تفعيل') : tr('Mettre en pause', 'إيقاف')),
              onPressed: () => _toggle(o),
            ),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: tr('Supprimer', 'حذف'), onPressed: () => _delete(o)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final all = store.offers;
            final live = all.where(store.offerLive).toList();
            final past = all.where((o) => !store.offerLive(o)).toList();
            final shown = filter == 0 ? live : filter == 1 ? past : all;
            final totalUses = store.offerUses.values.fold<int>(0, (a, b) => a + b);
            return NqScreen(
              title: tr('Offres', 'العروض'),
              action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
              header: [
                YellowCard(
                  child: Row(children: [
                    Expanded(child: _kpi('${live.length}', tr('en cours', 'سارية'))),
                    Expanded(child: _kpi('${past.length}', tr('terminées', 'منتهية'))),
                    Expanded(child: _kpi(store.offersExt ? '$totalUses' : '—', tr('validées', 'مؤكدة'))),
                  ]),
                ),
                HeaderChips(
                  labels: [tr('En cours', 'سارية'), tr('Terminées', 'منتهية'), tr('Toutes', 'الكل')],
                  selected: filter,
                  onSelected: (i) => setState(() => filter = i),
                ),
              ],
              body: Stack(children: [
                ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                  if (store.errors['offers'] != null) ErrorBanner(tr('offres', 'العروض'), store.errors['offers']!),
                  if (store.offersExt)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.history_rounded),
                        label: Text(tr('Historique des offres validées', 'سجل العروض المؤكدة')),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferHistoryPage())),
                      ),
                    ),
                  if (!store.offersExt)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kWarn.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                      child: Text(tr('Mode simple : appliquez la mise à jour SQL (offers_upgrade.sql) pour activer description, types, pause et suivi des validations.', 'الوضع البسيط: طبّق تحديث SQL (offers_upgrade.sql) لتفعيل الوصف والأنواع والإيقاف وتتبع التأكيدات.'), style: const TextStyle(fontSize: 12.5)),
                    ),
                  if (shown.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucune offre ici', 'لا عروض هنا'), style: const TextStyle(color: kMuted)))),
                  for (var i = 0; i < shown.length; i++) FadeSlideIn(index: i, child: _card(shown[i])),
                ]),
                PositionedDirectional(
                  end: 20,
                  bottom: 20,
                  child: FloatingActionButton.extended(
                    backgroundColor: kAccent,
                    foregroundColor: kInk,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Nouvelle offre', 'عرض جديد'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: _openEditor,
                  ),
                ),
              ]),
            );
          },
        ),
      );

  Widget _kpi(String v, String l) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 4),
        Text(l, style: const TextStyle(fontSize: 13)),
      ]);
}

// ---------- Création d'une offre ----------
class _OfferEditor extends StatefulWidget {
  const _OfferEditor();
  @override
  State<_OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends State<_OfferEditor> {
  final title = TextEditingController(), desc = TextEditingController(), value = TextEditingController();
  int kind = 0, aud = 0, days = 0; // days : 0 = sans limite
  bool busy = false;

  static const quick = [
    ('percent', '-15 % mardi', '-15٪ يوم الثلاثاء', 15),
    ('gift', 'Café offert', 'قهوة مجانية', null),
    ('points', 'Double points ce week-end', 'نقاط مضاعفة في عطلة الأسبوع', null),
    ('custom', 'Nouveau : venez découvrir', 'جديد: تعالوا واكتشفوا', null),
  ];

  @override
  void dispose() { title.dispose(); desc.dispose(); value.dispose(); super.dispose(); }

  String get unit => offerKinds[kind].$5;

  void _applyQuick((String, String, String, int?) q) {
    setState(() {
      kind = offerKinds.indexWhere((k) => k.$1 == q.$1);
      title.text = tr(q.$2, q.$3);
      value.text = q.$4?.toString() ?? '';
    });
  }

  Future<void> _send() async {
    final t = title.text.trim();
    if (t.isEmpty) { snack(context, tr('Donnez un titre à l\'offre', 'أعط العرض عنوانًا')); return; }
    num? v;
    if (unit.isNotEmpty && value.text.trim().isNotEmpty) {
      v = num.tryParse(value.text.replaceAll(',', '.').replaceAll(' ', ''));
      if (v == null || v <= 0 || (unit == '%' && v > 100)) { snack(context, tr('Valeur invalide', 'قيمة غير صالحة')); return; }
    }
    final nav = Navigator.of(context);
    final m = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await store.sendOffer(t, offerAudiences[aud].$1, days: days == 0 ? null : days, description: desc.text.trim(), kind: offerKinds[kind].$1, value: v);
      nav.pop();
      m.showSnackBar(SnackBar(content: Text(tr('Offre envoyée aux clients concernés', 'تم إرسال العرض للزبائن المعنيين'))));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errText(e))));
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Nouvelle offre', 'عرض جديد'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(tr('Modèles rapides', 'نماذج سريعة'), style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [for (final q in quick) ActionChip(label: Text(tr(q.$2, q.$3)), onPressed: () => _applyQuick(q))]),
          const SizedBox(height: 16),
          Text(tr('Type d\'offre', 'نوع العرض'), style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (var i = 0; i < offerKinds.length; i++) ChoiceChip(avatar: Icon(offerKinds[i].$4, size: 18), label: Text(tr(offerKinds[i].$2, offerKinds[i].$3)), selected: kind == i, onSelected: (_) => setState(() => kind = i)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: tr('Titre de l\'offre', 'عنوان العرض'))),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('Valeur (optionnel)', 'القيمة (اختياري)'), suffixText: unit)),
          ],
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 3, minLines: 2, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: tr('Description et conditions (optionnel)', 'الوصف والشروط (اختياري)'))),
          const SizedBox(height: 16),
          Text(tr('Destinataires', 'المستلمون'), style: label),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [for (var i = 0; i < offerAudiences.length; i++) ButtonSegment(value: i, label: Text(tr(offerAudiences[i].$2, offerAudiences[i].$3)))],
              selected: {aud},
              onSelectionChanged: (s) => setState(() => aud = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('Durée de l\'offre', 'مدة العرض'), style: label),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(tr('Sans limite', 'بدون حد'))),
                ButtonSegment(value: 7, label: Text(tr('7 jours', '7 أيام'))),
                ButtonSegment(value: 30, label: Text(tr('30 jours', '30 يومًا'))),
              ],
              selected: {days},
              onSelectionChanged: (s) => setState(() => days = s.first),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.send_rounded), label: Text(tr('Envoyer l\'offre', 'إرسال العرض')), onPressed: busy ? null : _send)),
        ]),
      ),
    );
  }
}
