import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';

const appVersion = '0.4.0';

/// Onglet « Profil » : compte, code personnel, langue, thème, sécurité.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: store.myName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Modifier mon nom', 'تعديل اسمي')),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: tr('Votre prénom', 'اسمك'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Enregistrer', 'حفظ'))),
        ],
      ),
    );
    final name = c.text.trim();
    c.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    try {
      await store.updateName(name);
      snack(context, tr('Nom modifié', 'تم تعديل الاسم'));
    } catch (e) {
      snack(context, errText(e));
    }
  }

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
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final theme = Theme.of(context);
          final roles = {'owner': tr('Propriétaire', 'مالك'), 'manager': tr('Gérant', 'مدير'), 'employee': tr('Employé', 'موظف')};
          final name = store.myName.isEmpty ? '—' : store.myName;
          return NqScreen(
            title: tr('Profil', 'الحساب'),
            header: [
              Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kHeaderTop, border: Border.all(color: kBronze, width: 3)),
                    child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                  ),
                  PositionedDirectional(
                    end: -4,
                    bottom: -4,
                    child: GestureDetector(
                      onTap: () => _editName(context),
                      child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle, border: Border.all(color: kHeaderTop, width: 2)), child: const Icon(Icons.edit_rounded, size: 15, color: kInk)),
                    ),
                  ),
                ]),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(store.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 15)),
                  ]),
                ),
              ]),
              YellowCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(roles[store.role] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${store.shop?['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    AnimatedCount(store.clients.length, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
                    Text(tr('clients', 'زبون'), style: const TextStyle(fontSize: 15)),
                  ]),
                ]),
              ),
            ],
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            SectionCard(title: tr('Mon code', 'رمزي'), icon: NI.badge, children: [
              Row(children: [
                Expanded(child: SelectableText(store.myCode.isEmpty ? '—' : store.myCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2))),
                IconButton.filledTonal(
                  icon: const NIcon(NI.copy),
                  onPressed: store.myCode.isEmpty ? null : () { Clipboard.setData(ClipboardData(text: store.myCode)); snack(context, tr('Code copié', 'تم نسخ الرمز')); },
                ),
              ]),
              const SizedBox(height: 4),
              Text(tr('Donnez ce code au propriétaire d\'un commerce pour rejoindre son équipe.', 'أعطِ هذا الرمز لمالك المتجر للانضمام إلى فريقه.'), style: const TextStyle(fontSize: 12, color: kMuted)),
            ]),
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
            SectionCard(title: tr('Compte', 'الحساب'), icon: NI.lock, children: [
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.password_rounded), title: Text(tr('Changer le mot de passe', 'تغيير كلمة السر')), onTap: () => _changePassword(context)),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.logout), title: Text(tr('Se déconnecter', 'تسجيل الخروج')), onTap: store.signOut),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_forever, color: Colors.red), title: Text(tr('Supprimer mon compte', 'حذف حسابي'), style: const TextStyle(color: Colors.red)), onTap: () => _delete(context)),
            ]),
            const SizedBox(height: 16),
            const Center(child: Text('Nqata Pro $appVersion', style: TextStyle(color: kMuted))),
            const SizedBox(height: 8),
          ]),
          );
        },
      );
}
