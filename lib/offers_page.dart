import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';
import 'tabs.dart';
import 'icons.dart';

/// Page des offres, ouverte depuis l'onglet Commerce (propriétaire et gérants).
class OffersPage extends StatefulWidget {
  const OffersPage({super.key});
  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
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
  Widget build(BuildContext context) => Scaffold(
        body: NqScreen(
          title: tr('Offres', 'العروض'),
          action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
          body: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final title = Theme.of(context).textTheme.titleMedium;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text(tr('Nouvelle offre', 'عرض جديد'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < templates.length; i++) ChoiceChip(label: Text(tr(templates[i].$1, templates[i].$2)), selected: tpl == i, onSelected: (_) => setState(() => tpl = i)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: custom, decoration: InputDecoration(labelText: tr('Ou écrivez votre offre', 'أو اكتب عرضك'))),
              const SizedBox(height: 16),
              Text(tr('Destinataires', 'المستلمون'), style: title),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [for (var i = 0; i < audiences.length; i++) ButtonSegment(value: i, label: Text(tr(audiences[i].$2, audiences[i].$3)))],
                selected: {aud},
                onSelectionChanged: (s) => setState(() => aud = s.first),
              ),
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
                  leading: const NIcon(NI.offer),
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
        ),
        ),
      );
}
