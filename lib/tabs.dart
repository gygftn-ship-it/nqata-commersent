import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'scanner_tab.dart';
import 'clients_tab.dart';
import 'shop_tab.dart';
import 'stats_tab.dart';
import 'profile_tab.dart';
import 'icons.dart';
import 'ui.dart';

// ---------- Utilitaires partagés ----------
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
        builder: (_, v, __) => Text(fmtNum(v), style: style),
      );
}

/// Carte avec titre et icône, utilisée dans les onglets Commerce et Profil.
class SectionCard extends StatelessWidget {
  final String title;
  final Object icon; // NI (icône Nqata) ou IconData
  final List<Widget> children;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.icon, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ic(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

/// Bandeau rouge qui montre la vraie erreur de lecture (au lieu d'une liste vide).
class ErrorBanner extends StatelessWidget {
  final String what, message;
  const ErrorBanner(this.what, this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kDanger.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: kDanger.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tr('Lecture impossible', 'تعذّرت القراءة')} : $what', style: const TextStyle(fontWeight: FontWeight.bold, color: kDanger)),
          const SizedBox(height: 4),
          SelectableText(message, style: const TextStyle(fontSize: 12)),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: store.refresh, child: Text(tr('Réessayer', 'إعادة المحاولة')))),
        ]),
      );
}

DateTime localDt(Object? iso) => DateTime.parse('$iso').toLocal();

String hm(String? iso) {
  if (iso == null) return '-';
  final d = DateTime.parse(iso).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String since(String? iso) {
  if (iso == null) return tr('jamais venu', 'لم يزر بعد');
  final n = DateTime.now().difference(DateTime.parse(iso).toLocal()).inDays;
  return n == 0 ? tr('aujourd\'hui', 'اليوم') : tr('il y a $n j', 'منذ $n يوم');
}

String until(String? iso) {
  if (iso == null) return '';
  final d = DateTime.parse(iso).toLocal();
  return ' · ${tr('jusqu\'au', 'حتى')} ${d.day}/${d.month}';
}

/// 12500 -> « 12 500 »
String fmtNum(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtMoney(num v) => '${fmtNum(v)} DA';

double? amountOf(Map<String, dynamic> s) => (s['amount'] as num?)?.toDouble();

void snack(BuildContext context, String m) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/// Fenêtre de confirmation commune (actions sensibles : déconnexion, retrait d'un membre…).
Future<bool> confirmAction(BuildContext context, {required String title, required String body, required String confirm, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: danger ? kDanger : null, foregroundColor: danger ? Colors.white : null),
          onPressed: () => Navigator.pop(d, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Un employé peut annuler ses propres scans pendant 5 min ; un gérant, tous.
bool canUndoScan(Map<String, dynamic> s) {
  if (s['undone_at'] != null) return false;
  if (store.manager) return true;
  return s['staff_id'] == store.uid && DateTime.now().difference(localDt(s['created_at'])) < const Duration(minutes: 5);
}

// ---------- Coque : Scanner · Clients · Commerce · Statistiques · Profil ----------
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
    // Les statistiques (chiffre d'affaires, etc.) sont réservées au propriétaire et aux gérants.
    final ready = store.clients.where((c) => (c['points'] as num) >= store.threshold).length; // récompenses à valider → pastille sur « Clients »
    final items = <(Widget, NI, String, int)>[
      (const ScannerTab(), NI.scan, tr('Scanner', 'مسح'), 0),
      (const ClientsTab(), NI.clients, tr('Clients', 'الزبائن'), ready),
      (const ShopTab(), NI.shop, tr('Commerce', 'المتجر'), 0),
      if (store.manager) (const StatsTab(), NI.stats, tr('Stats', 'الإحصاءات'), 0),
      (const ProfileTab(), NI.profile, tr('Profil', 'الحساب'), 0),
    ];
    if (tab >= items.length) tab = items.length - 1;
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => tab = 0); },
      child: Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
        child: KeyedSubtree(key: ValueKey('${items[tab].$3}'), child: items[tab].$1),
      ),
      bottomNavigationBar: _NavBar(
        index: tab,
        items: [for (final it in items) (it.$2, it.$3, it.$4)],
        onTap: (i) { HapticFeedback.selectionClick(); setState(() => tab = i); },
      ),
    ));
  }
}

/// Barre du bas flottante (beige) : l'onglet actif devient une pastille jaune avec son nom.
class _NavBar extends StatelessWidget {
  final int index;
  final List<(NI, String, int)> items;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      color: sheetColor(context),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2A2720) : kNavBeige,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 3 : 1,
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$3 > 0 ? '${items[i].$2}, ${items[i].$3}' : items[i].$2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: i == index ? kAccent : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          NIcon(items[i].$1, size: 24, color: i == index ? kInk : (dark ? Colors.white60 : kMuted)),
                          if (items[i].$3 > 0)
                            PositionedDirectional(
                              end: -8,
                              top: -6,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(10), border: Border.all(color: i == index ? kAccent : (dark ? const Color(0xFF2A2720) : kNavBeige), width: 1.5)),
                                child: Text(items[i].$3 > 9 ? '9+' : '${items[i].$3}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ]),
                        if (i == index) ...[
                          const SizedBox(width: 6),
                          Flexible(child: Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kInk))),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
