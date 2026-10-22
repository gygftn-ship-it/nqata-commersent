import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart';
import 'tabs.dart';
import 'ui.dart';
import 'offers_page.dart';
import 'icons.dart';

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
            width: 240,
            height: 240,
            child: Stack(children: [
              for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
                Align(alignment: a, child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _CornerPainter(a)))),
              AnimatedBuilder(
                animation: c,
                builder: (_, __) => Align(
                  alignment: Alignment(0, -1 + 2 * c.value),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Coin jaune du cadre de scan (repère du logo).
class _CornerPainter extends CustomPainter {
  final Alignment a;
  _CornerPainter(this.a);
  @override
  bool shouldRepaint(_CornerPainter o) => false;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dx = a.x < 0 ? 1.0 : -1.0, dy = a.y < 0 ? 1.0 : -1.0;
    final ox = a.x < 0 ? 2.0 : s.width - 2, oy = a.y < 0 ? 2.0 : s.height - 2;
    final path = Path()
      ..moveTo(ox + dx * 36, oy)
      ..lineTo(ox + dx * 14, oy)
      ..quadraticBezierTo(ox, oy, ox, oy + dy * 14)
      ..lineTo(ox, oy + dy * 36);
    c.drawPath(path, p);
  }
}

/// Saisie ou modification du montant d'un achat (sert au panier moyen).
Future<void> showAmountDialog(BuildContext context, String scanId, double? current) async {
  final c = TextEditingController(text: current == null ? '' : current.round().toString());
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr('Montant de l\'achat', 'مبلغ الشراء')),
      content: TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(suffixText: 'DA', labelText: tr('Montant', 'المبلغ'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Enregistrer', 'حفظ'))),
      ],
    ),
  );
  final v = double.tryParse(c.text.replaceAll(',', '.').replaceAll(' ', ''));
  c.dispose();
  if (ok != true || !context.mounted) return;
  if (v == null || v <= 0) { snack(context, tr('Montant invalide', 'مبلغ غير صالح')); return; }
  try {
    await store.setScanAmount(scanId, v);
    snack(context, tr('Montant enregistré', 'تم حفظ المبلغ'));
  } catch (e) {
    snack(context, errText(e));
  }
}

class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});
  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  bool busy = false, torch = false;

  @override
  void dispose() { controller.dispose(); manual.dispose(); super.dispose(); }

  Future<void> _handle(String raw) async {
    if (busy || raw.trim().isEmpty) return;
    busy = true;
    try {
      final r = await store.scan(raw);
      if (!mounted) return;
      // Pop-up « quelle offre le client utilise-t-il ? » (réglable dans Paramètres)
      if (store.offerAsk == 'scan') {
        store.buzz();
        await pickOfferForScan(context, r);
        if (!mounted) return;
      }
      await _success(r);
    } catch (e) {
      if (mounted) await _error(errText(e));
    }
    await Future.delayed(const Duration(milliseconds: 600));
    busy = false;
  }

  Future<void> _error(String msg) {
    store.buzz(heavy: true);
    return showDialog(
      context: context,
      builder: (d) {
        Timer(const Duration(milliseconds: 3000), () { if (d.mounted && Navigator.of(d).canPop()) Navigator.of(d).pop(); });
        return AlertDialog(icon: const Icon(Icons.error_rounded, color: kDanger, size: 64), content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)));
      },
    );
  }

  Future<void> _success(Map<String, dynamic> r) {
    store.buzz();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScanResultSheet(r),
    );
  }

  Widget _mini(Object i, String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            ic(i, size: 20),
            Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final valid = store.scans.where((s) => s['undone_at'] == null).toList();
          final points = valid.fold<int>(0, (a, s) => a + ((s['points'] as num?)?.toInt() ?? 0));
          final recent = store.scans.take(6).toList();
          return NqScreen(
            title: tr('Scanner', 'مسح'),
            action: HeaderPill(icon: Icons.storefront_rounded, label: '${store.shop?['name'] ?? ''}'),
            body: Column(children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
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
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(children: [
                      IconButton.filled(
                        icon: Icon(torch ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded),
                        onPressed: () { controller.toggleTorch(); setState(() => torch = !torch); },
                      ),
                      const SizedBox(height: 6),
                      IconButton.filled(icon: const NIcon(NI.camera), onPressed: () => controller.switchCamera()),
                    ]),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text(tr('Placez le QR du client dans le cadre', 'ضع رمز الزبون داخل الإطار'), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
                ]),
              ),
              ),
            ),
            Expanded(
              flex: 4,
              child: RefreshIndicator(
                onRefresh: store.refresh,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), children: [
                  Row(children: [
                    _mini(NI.check, '${valid.length}', tr('Passages', 'الزيارات')),
                    const SizedBox(width: 8),
                    _mini(NI.points, fmtNum(points), tr('Points donnés', 'النقاط')),
                    const SizedBox(width: 8),
                    _mini(NI.gift, '${store.redeems.length}', tr('Récompenses', 'المكافآت')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: manual,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.keyboard_rounded), labelText: tr('Code client (ou téléphone)', 'رمز الزبون (أو الهاتف)')),
                        onSubmitted: (v) { _handle(v); manual.clear(); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () { _handle(manual.text); manual.clear(); }, child: Text(tr('Valider', 'تأكيد'))),
                  ]),
                  const SizedBox(height: 14),
                  Text(tr('Derniers scans', 'آخر المسح'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (recent.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr('Aucun scan aujourd\'hui', 'لا مسح اليوم'), style: const TextStyle(color: kMuted)))),
                  for (final s in recent)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: store.hasAmount && s['undone_at'] == null ? () => showAmountDialog(context, '${s['id']}', amountOf(s)) : null,
                      leading: CircleAvatar(radius: 16, backgroundColor: s['undone_at'] != null ? kMuted : kOk, child: Icon(s['undone_at'] != null ? Icons.block : Icons.check, size: 16, color: Colors.white)),
                      title: Text(store.clientName(s['client_id'] as String?)),
                      subtitle: Text('${hm(s['created_at'] as String?)}${s['undone_at'] != null ? ' · ${tr('annulé', 'ملغى')}' : ''}${amountOf(s) != null ? ' · ${fmtMoney(amountOf(s)!)}' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('+${s['points']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (canUndoScan(s))
                          IconButton(
                            icon: const NIcon(NI.undo, size: 20),
                            tooltip: tr('Annuler', 'إلغاء'),
                            onPressed: () async {
                              try {
                                await store.undo('${s['id']}');
                              } catch (e) {
                                snack(context, errText(e));
                              }
                            },
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
          );
        },
      );
}

/// Résultat d'un scan : points, progression, montant de l'achat, récompense.
class _ScanResultSheet extends StatefulWidget {
  final Map<String, dynamic> r;
  const _ScanResultSheet(this.r);
  @override
  State<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<_ScanResultSheet> {
  final amount = TextEditingController();
  Timer? timer;
  bool busy = false;

  Map<String, dynamic> get r => widget.r;
  int get bal => (r['balance'] as num).toInt();
  bool get ready => bal >= store.threshold;

  @override
  void initState() {
    super.initState();
    // Se ferme tout seul au bout de 8 s, sauf si une récompense est à valider ou si l'on touche l'écran.
    if (!ready && store.autoCloseSecs > 0) timer = Timer(Duration(seconds: store.autoCloseSecs), () { if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(); });
  }

  @override
  void dispose() { timer?.cancel(); amount.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => busy = true);
    try {
      await action();
      nav.pop();
      m.showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errText(e))));
      if (mounted) setState(() => busy = false);
    }
  }

  void _saveAmount() {
    final v = double.tryParse(amount.text.replaceAll(',', '.').replaceAll(' ', ''));
    if (v == null || v <= 0) { snack(context, tr('Montant invalide', 'مبلغ غير صالح')); return; }
    _run(() => store.setScanAmount('${r['scan_id']}', v), tr('Montant enregistré', 'تم حفظ المبلغ'));
  }

  @override
  Widget build(BuildContext context) {
    final thr = store.threshold;
    final theme = Theme.of(context);
    return Listener(
      onPointerDown: (_) => timer?.cancel(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline_rounded, color: kOk, size: 48),
            const SizedBox(height: 6),
            Text('${r['client_name']}', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text('+${r['points_added']} ${tr('points', 'نقطة')}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (bal / thr).clamp(0.0, 1.0), minHeight: 6)),
            const SizedBox(height: 6),
            Text('${tr('Solde', 'الرصيد')} : $bal / $thr', style: theme.textTheme.bodyMedium),
            if (ready)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text('${tr('Récompense disponible', 'مكافأة متاحة')}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            if (store.hasAmount) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onTap: () => timer?.cancel(),
                    decoration: InputDecoration(labelText: tr('Montant de l\'achat (optionnel)', 'مبلغ الشراء (اختياري)'), suffixText: 'DA'),
                    onSubmitted: (_) => _saveAmount(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: busy ? null : _saveAmount, child: const Icon(Icons.check_rounded)),
              ]),
            ],
            const SizedBox(height: 14),
            Row(children: [
              TextButton.icon(
                icon: const NIcon(NI.undo, size: 20),
                label: Text(tr('Annuler le scan', 'إلغاء المسح')),
                onPressed: busy ? null : () => _run(() => store.undo('${r['scan_id']}'), tr('Scan annulé', 'تم إلغاء المسح')),
              ),
              const Spacer(),
              if (ready && r['client_id'] != null)
                FilledButton(
                  onPressed: busy ? null : () async {
                    final nav = Navigator.of(context);
                    final ok = await validateWithOffer(context, '${r['client_id']}', '${r['client_name']}');
                    if (ok && nav.canPop()) nav.pop();
                  },
                  child: Text(tr('Valider la récompense', 'تأكيد المكافأة')),
                )
              else
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ]),
          ]),
        ),
      ),
    );
  }
}
