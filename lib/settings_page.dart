import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';
import 'profile_tab.dart' show appVersion;
import 'offers_page.dart' show OfferHistoryPage;

/// Page « Paramètres » : langue, apparence, sécurité du compte. Ouverte depuis le Profil.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final a = TextEditingController(), b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Changer le mot de passe', 'تغيير كلمة السر')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, obscureText: true, decoration: InputDecoration(labelText: tr('Nouveau mot de passe (6 caractères min.)', 'كلمة السر الجديدة (6 أحرف على الأقل)'))),
          const SizedBox(height: 10),
          TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: tr('Confirmer', 'تأكيد'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Modifier', 'تغيير'))),
        ],
      ),
    );
    final p1 = a.text, p2 = b.text;
    a.dispose();
    b.dispose();
    if (ok != true || !context.mounted) return;
    if (p1.length < 6 || p1 != p2) { snack(context, tr('Les mots de passe ne correspondent pas, ou sont trop courts', 'كلمتا السر غير متطابقتين أو قصيرتان')); return; }
    try {
      await store.changePassword(p1);
      snack(context, tr('Mot de passe modifié', 'تم تغيير كلمة السر'));
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Supprimer mon compte ?', 'حذف حسابي؟')),
        content: Text(tr('Votre compte et vos données seront supprimés définitivement.', 'سيتم حذف حسابك وبياناتك نهائيًا.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(d, true), child: Text(tr('Supprimer', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.deleteAccount();
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final theme = Theme.of(context);
            return NqScreen(
              title: tr('Paramètres', 'الإعدادات'),
              action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
              body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            SectionCard(title: tr('Préférences', 'التفضيلات'), icon: NI.tune, children: [
              Text(tr('Langue', 'اللغة'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'fr', label: Text('Français')), ButtonSegment(value: 'ar', label: Text('العربية'))],
                  selected: {lang},
                  onSelectionChanged: (s) => store.setLang(s.first),
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('Apparence', 'المظهر'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(tr('Auto', 'تلقائي'))),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(tr('Clair', 'فاتح'))),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(tr('Sombre', 'داكن'))),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) => store.setTheme(s.first),
                ),
              ),
            ]),
            SectionCard(title: tr('Validation des offres', 'تأكيد العروض'), icon: NI.offer, children: [
              Text(tr('Demander quelle offre le client utilise', 'اسأل عن العرض الذي يستعمله الزبون'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'scan', label: Text(tr('Chaque scan', 'كل مسح'))),
                    ButtonSegment(value: 'reward', label: Text(tr('Récompense', 'المكافأة'))),
                    ButtonSegment(value: 'never', label: Text(tr('Jamais', 'أبدًا'))),
                  ],
                  selected: {store.offerAsk},
                  onSelectionChanged: (s) => store.setOfferAsk(s.first),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                store.offerAsk == 'scan'
                    ? tr('Un pop-up s\'ouvre après chaque scan s\'il y a des offres en cours.', 'تظهر نافذة بعد كل مسح إذا وُجدت عروض سارية.')
                    : store.offerAsk == 'reward'
                        ? tr('Le pop-up s\'ouvre seulement quand vous validez une récompense.', 'تظهر النافذة فقط عند تأكيد مكافأة.')
                        : tr('Aucun pop-up : l\'offre utilisée n\'est pas enregistrée.', 'بدون نافذة: لا يتم تسجيل العرض المستعمل.'),
                style: const TextStyle(fontSize: 12.5, color: kMuted),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Proposer « Aucune offre »', 'اقتراح «بدون عرض»')), subtitle: Text(tr('Pour un simple passage sans offre', 'لزيارة عادية بدون عرض')), value: store.offerAllowNone, onChanged: store.setOfferAllowNone),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Demander le montant dans le pop-up', 'طلب المبلغ في النافذة')), subtitle: Text(tr('Pour calculer le panier moyen', 'لحساب متوسط السلة')), value: store.askAmount, onChanged: store.setAskAmount),
              if (store.manager) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history_rounded), title: Text(tr('Historique des offres validées', 'سجل العروض المؤكدة')), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferHistoryPage()))),
            ]),
            SectionCard(title: tr('Scanner', 'الماسح'), icon: NI.scan, children: [
              Text(tr('Fermeture automatique du résultat', 'إغلاق النتيجة تلقائيًا'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(value: 5, label: Text('5 s')),
                    const ButtonSegment(value: 8, label: Text('8 s')),
                    const ButtonSegment(value: 15, label: Text('15 s')),
                    ButtonSegment(value: 0, label: Text(tr('Jamais', 'أبدًا'))),
                  ],
                  selected: {store.autoCloseSecs},
                  onSelectionChanged: (s) => store.setAutoClose(s.first),
                ),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Vibrations', 'الاهتزاز')), subtitle: Text(tr('À chaque scan réussi ou refusé', 'عند كل مسح ناجح أو مرفوض')), value: store.haptics, onChanged: store.setHaptics),
            ]),
            SectionCard(title: tr('Sécurité', 'الأمان'), icon: NI.lock, children: [
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.password_rounded), title: Text(tr('Changer le mot de passe', 'تغيير كلمة السر')), onTap: () => _changePassword(context)),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_forever, color: Colors.red), title: Text(tr('Supprimer mon compte', 'حذف حسابي'), style: const TextStyle(color: Colors.red)), onTap: () => _delete(context)),
            ]),
            const SizedBox(height: 16),
            const Center(child: Text('Nqata Pro $appVersion', style: TextStyle(color: kMuted))),
            const SizedBox(height: 8),
              ]),
            );
          },
        ),
      );
}
