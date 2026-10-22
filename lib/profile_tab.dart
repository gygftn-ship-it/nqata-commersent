import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';
import 'settings_page.dart';

const appVersion = '0.6.0';

/// Onglet « Profil » : identité, code personnel, accès aux Paramètres.
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
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
            SectionCard(title: tr('Mon compte', 'حسابي'), icon: NI.lock, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_rounded),
                title: Text(tr('Paramètres', 'الإعدادات'), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(tr('Langue, offres, scanner, mot de passe', 'اللغة، العروض، المسح، كلمة السر')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.logout), title: Text(tr('Se déconnecter', 'تسجيل الخروج')), onTap: store.signOut),
            ]),
            const SizedBox(height: 16),
            const Center(child: Text('Nqata Pro $appVersion', style: TextStyle(color: kMuted))),
            const SizedBox(height: 8),
          ]),
          );
        },
      );
}
