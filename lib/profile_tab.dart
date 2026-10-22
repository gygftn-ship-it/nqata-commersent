import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'ui.dart';
import 'settings_page.dart';
import 'terms_page.dart';

const appVersion = '0.9.0';

/// Onglet « Profil » : identité, résumé, code personnel, commerce, compte, conditions et support.
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

  Widget _stat(BuildContext context, Object icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            ic(icon, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kMuted)),
          ]),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: kMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: kMuted)),
              Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _pill(String text, {Color? bg, Color fg = kInk}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg ?? kAccent, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final roles = {'owner': tr('Propriétaire', 'مالك'), 'manager': tr('Gérant', 'مدير'), 'employee': tr('Employé', 'موظف')};
          final name = store.myName.isEmpty ? '—' : store.myName;
          final shop = store.shop;
          final logo = shop?['logo_url'] as String?;
          final hasLogo = logo != null && logo.isNotEmpty;
          final cat = shopCats.firstWhere((c) => c.$1 == '${shop?['category']}', orElse: () => shopCats.last);
          final validScans = store.scans.where((s) => s['undone_at'] == null).length;
          final avg = (store.rating?['avg_rating'] as num?)?.toDouble();
          final reviewsCount = (store.rating?['reviews_count'] as num?)?.toInt() ?? 0;
          return NqScreen(
            title: tr('Profil', 'الحساب'),
            header: [
              Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kHeaderTop, border: Border.all(color: kBronze, width: 3), image: hasLogo ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null),
                    child: hasLogo ? null : Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
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
                    const SizedBox(height: 8),
                    _pill(roles[store.role] ?? ''),
                  ]),
                ),
              ]),
              YellowCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${shop?['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(tr(cat.$2, cat.$3), style: const TextStyle(fontSize: 16)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    AnimatedCount(store.clients.length, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
                    Text(tr('clients', 'زبون'), style: const TextStyle(fontSize: 15)),
                  ]),
                ]),
              ),
            ],
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
              // Résumé rapide
              Row(children: [
                _stat(context, NI.check, '$validScans', tr('Passages du jour', 'زيارات اليوم')),
                const SizedBox(width: 8),
                _stat(context, NI.clients, fmtNum(store.clients.length), tr('Clients', 'الزبائن')),
                const SizedBox(width: 8),
                _stat(context, Icons.star_rounded, avg == null ? '—' : avg.toStringAsFixed(1), reviewsCount > 0 ? '$reviewsCount ${tr('avis', 'تقييم')}' : tr('Note', 'التقييم')),
              ]),
              // Code personnel
              if (store.myCode.isNotEmpty)
                SectionCard(title: tr('Mon code', 'رمزي'), icon: NI.badge, children: [
                  Row(children: [
                    Expanded(child: Text(store.myCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3))),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: tr('Copier', 'نسخ'),
                      onPressed: () { Clipboard.setData(ClipboardData(text: store.myCode)); snack(context, tr('Code copié', 'تم نسخ الرمز')); },
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(tr('Votre code personnel : communiquez-le à votre gérant pour être ajouté à son équipe.', 'رمزك الشخصي: أعطه لمديرك ليضيفك إلى فريقه.'), style: const TextStyle(fontSize: 12.5, color: kMuted)),
                ]),
              // Commerce
              SectionCard(
                title: tr('Mon commerce', 'متجري'),
                icon: NI.shop,
                trailing: _pill(store.active ? tr('Actif', 'نشط') : tr('En attente', 'قيد الانتظار'), bg: store.active ? kOk : kAccentSoft, fg: store.active ? Colors.white : kInk),
                children: [
                  _infoRow(Icons.storefront_rounded, tr('Nom', 'الاسم'), '${shop?['name'] ?? ''}'),
                  _infoRow(Icons.place_outlined, tr('Adresse', 'العنوان'), '${shop?['address'] ?? ''}'),
                  _infoRow(Icons.phone_outlined, tr('Téléphone', 'الهاتف'), '${shop?['phone'] ?? ''}'),
                  _infoRow(Icons.stars_rounded, tr('Programme', 'البرنامج'), '${shop?['points_per_visit'] ?? '—'} ${tr('pts par visite', 'نقطة للزيارة')} · ${store.threshold} ${tr('pts pour une récompense', 'نقطة للمكافأة')}'),
                ],
              ),
              // Compte
              SectionCard(title: tr('Mon compte', 'حسابي'), icon: NI.lock, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(tr('Paramètres', 'الإعدادات'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr('Langue, offres, scanner, mot de passe', 'اللغة، العروض، المسح، كلمة السر')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(tr('Modifier mon nom', 'تعديل اسمي')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editName(context),
                ),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.logout), title: Text(tr('Se déconnecter', 'تسجيل الخروج')), onTap: () async {
                  if (await confirmAction(context, title: tr('Se déconnecter ?', 'تسجيل الخروج؟'), body: tr('Vous devrez vous reconnecter pour scanner vos clients.', 'ستحتاج إلى تسجيل الدخول مجددًا لمسح زبائنك.'), confirm: tr('Se déconnecter', 'خروج'))) store.signOut();
                }),
              ]),
              // Informations
              SectionCard(title: tr('À propos', 'حول'), icon: NI.info, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(tr('Conditions d\'utilisation', 'شروط الاستعمال')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent_rounded),
                  title: Text(tr('Support', 'الدعم')),
                  subtitle: Text(tr('Une aide directe depuis l\'application', 'مساعدة مباشرة من التطبيق')),
                  trailing: _pill(tr('Bientôt', 'قريبًا')),
                  onTap: () => snack(context, tr('Le support sera bientôt disponible', 'الدعم سيكون متاحًا قريبًا')),
                ),
              ]),
              const SizedBox(height: 16),
              const Center(child: Text('Nqata Pro $appVersion', style: TextStyle(color: kMuted))),
              const SizedBox(height: 8),
            ]),
          );
        },
      );
}
