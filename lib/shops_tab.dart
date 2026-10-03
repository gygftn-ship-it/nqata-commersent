import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'tabs.dart';

const _covers = ['#6B3F2A', '#B45309', '#15803D', '#0E7490', '#4C1D95', '#BE185D', '#1D4ED8', '#15120B', '#FFD60A'];

Color? _hex(String? h) {
  if (h == null || h.isEmpty) return null;
  try {
    return Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Onglet « Mon commerce » : vitrine, horaires, position, programme, équipe, compte.
class ShopTab extends StatefulWidget {
  const ShopTab({super.key});
  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  late final addr = TextEditingController(text: '${store.shop?['address'] ?? ''}');
  late final phone = TextEditingController(text: '${store.shop?['phone'] ?? ''}');
  late final desc = TextEditingController(text: '${store.shop?['description'] ?? ''}');
  late final ppv = TextEditingController(text: '${store.shop?['points_per_visit'] ?? 10}');
  late final thr = TextEditingController(text: '${store.shop?['reward_threshold'] ?? 100}');
  late final per = TextEditingController(text: '${store.shop?['scan_period_hours'] ?? 24}');
  final code = TextEditingController();
  late String cat = '${store.shop?['category'] ?? 'other'}';
  String newRole = 'employee';
  TimeOfDay? open, close;
  bool saving = false, uploading = false;

  @override
  void initState() {
    super.initState();
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*[–—-]\s*(\d{1,2}):(\d{2})').firstMatch('${store.shop?['hours'] ?? ''}');
    if (m != null) {
      open = TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
      close = TimeOfDay(hour: int.parse(m[3]!), minute: int.parse(m[4]!));
    }
  }

  @override
  void dispose() {
    for (final c in [addr, phone, desc, ppv, thr, per, code]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickTime(bool isOpen) async {
    final t = await showTimePicker(context: context, initialTime: (isOpen ? open : close) ?? TimeOfDay(hour: isOpen ? 8 : 20, minute: 0));
    if (t != null) setState(() => isOpen ? open = t : close = t);
  }

  Future<void> _pickImage(String kind) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: kind == 'logo' ? 600 : 1400, maxHeight: kind == 'logo' ? 600 : 1400, imageQuality: 85);
    if (x == null) return;
    setState(() => uploading = true);
    try {
      await store.uploadImage(kind, await x.readAsBytes(), x.name);
      snack(context, tr('Image enregistrée', 'تم حفظ الصورة'));
    } catch (e) {
      snack(context, errText(e));
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> _quick(Map<String, dynamic> values, String ok) async {
    try {
      await store.updateShop(values);
      snack(context, ok);
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        snack(context, tr('Autorisez la localisation pour placer votre commerce', 'اسمح بالموقع لتحديد متجرك'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _quick({'lat': pos.latitude, 'lng': pos.longitude}, tr('Position enregistrée : elle apparaît maintenant sur la carte des clients', 'تم حفظ الموقع: يظهر الآن على خريطة الزبائن'));
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Future<void> _save() async {
    final p = int.tryParse(ppv.text), t = int.tryParse(thr.text), h = int.tryParse(per.text);
    if (p == null || p < 1 || t == null || t < 1 || h == null || h < 0) { snack(context, tr('Nombres invalides', 'أرقام غير صالحة')); return; }
    setState(() => saving = true);
    final values = <String, dynamic>{
      'address': addr.text.trim(),
      'phone': phone.text.trim(),
      'description': desc.text.trim(),
      'category': cat,
      'points_per_visit': p,
      'reward_threshold': t,
      'scan_period_hours': h,
    };
    if (open != null && close != null) values['hours'] = '${_fmt(open!)}–${_fmt(close!)}';
    await _quick(values, tr('Enregistré', 'تم الحفظ'));
    if (mounted) setState(() => saving = false);
  }

  Future<void> _changePassword() async {
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
    if (ok != true || !mounted) return;
    if (a.text.length < 6 || a.text != b.text) { snack(context, tr('Les mots de passe ne correspondent pas, ou sont trop courts', 'كلمتا السر غير متطابقتين أو قصيرتان')); return; }
    try {
      await store.changePassword(a.text);
      snack(context, tr('Mot de passe modifié', 'تم تغيير كلمة السر'));
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Supprimer mon compte ?', 'حذف حسابي؟')),
        content: Text(tr('Votre compte et vos données seront supprimés définitivement.', 'سيتم حذف حسابك وبياناتك نهائيًا.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(d, true), child: Text(tr('Supprimer', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.deleteAccount();
    } catch (e) {
      snack(context, errText(e));
    }
  }

  Widget _field(TextEditingController c, String l, {bool number = false, int lines = 1, int? max}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, keyboardType: number ? TextInputType.number : null, minLines: lines, maxLines: lines, maxLength: max, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 10), child: Text(t, style: Theme.of(context).textTheme.titleMedium));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final theme = Theme.of(context);
          final roles = {'owner': tr('Propriétaire', 'مالك'), 'manager': tr('Gérant', 'مدير'), 'employee': tr('Employé', 'موظف')};
          final cover = store.shop?['cover_url'] as String?, logo = store.shop?['logo_url'] as String?;
          final coverColor = _hex(store.shop?['cover_color'] as String?) ?? brandDark;
          final r = store.rating;
          final located = store.shop?['lat'] != null && store.shop?['lng'] != null;
          return ListView(padding: const EdgeInsets.all(16), children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [brandDark, brandLight])),
                child: Row(children: [
                  const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${store.shop?['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${roles[store.role] ?? ''} · ${tr('Actif', 'نشط')}', style: const TextStyle(color: Colors.white70)),
                      Text(r == null ? tr('Pas encore de note', 'لا تقييم بعد') : '★ ${(r['avg_rating'] as num).toStringAsFixed(1)} · ${r['reviews_count']} ${tr('avis', 'تقييم')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
            if (store.isOwner) ...[
              _h(tr('Vitrine (ce que voient les clients)', 'الواجهة (ما يراه الزبائن)')),
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  height: 130,
                  decoration: BoxDecoration(color: coverColor, borderRadius: BorderRadius.circular(18), image: cover == null || cover.isEmpty ? null : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)),
                ),
                PositionedDirectional(
                  end: 8,
                  top: 8,
                  child: Row(children: [
                    FilledButton.tonal(onPressed: uploading ? null : () => _pickImage('cover'), child: Text(tr('Changer le fond', 'تغيير الخلفية'))),
                    if (cover != null && cover.isNotEmpty) IconButton.filledTonal(icon: const Icon(Icons.delete_outline), onPressed: () => _quick({'cover_url': null}, tr('Image de fond retirée', 'تمت إزالة الخلفية'))),
                  ]),
                ),
                PositionedDirectional(
                  start: 16,
                  bottom: -34,
                  child: GestureDetector(
                    onTap: uploading ? null : () => _pickImage('logo'),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 37,
                        backgroundColor: Colors.black12,
                        backgroundImage: logo == null || logo.isEmpty ? null : NetworkImage(logo),
                        child: logo == null || logo.isEmpty ? const Icon(Icons.add_a_photo_outlined) : null,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 44),
              if (uploading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
              Text(tr('Touchez le logo pour le changer. Couleur de fond (si pas d\'image) :', 'المس الشعار لتغييره. لون الخلفية (إن لم توجد صورة):'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in _covers)
                  GestureDetector(
                    onTap: () => _quick({'cover_color': c}, tr('Couleur enregistrée', 'تم حفظ اللون')),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: _hex(c), shape: BoxShape.circle, border: Border.all(color: store.shop?['cover_color'] == c ? Colors.black87 : Colors.black12, width: store.shop?['cover_color'] == c ? 3 : 1)),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              _field(desc, tr('Description du commerce', 'وصف المتجر'), lines: 4, max: 300),
              Text(tr('Catégorie', 'الفئة'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [for (final c in shopCats) ChoiceChip(label: Text(tr(c.$2, c.$3)), selected: cat == c.$1, onSelected: (_) => setState(() => cat = c.$1))]),
              _h(tr('Horaires', 'ساعات العمل')),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('${tr('Ouvre', 'يفتح')} : ${open == null ? '--:--' : _fmt(open!)}'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('${tr('Ferme', 'يغلق')} : ${close == null ? '--:--' : _fmt(close!)}'))),
              ]),
              const SizedBox(height: 4),
              Text(tr('Les clients voient « Ouvert » ou « Fermé » selon ces horaires.', 'يرى الزبائن «مفتوح» أو «مغلق» حسب هذه الساعات.'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              _h(tr('Adresse et position', 'العنوان والموقع')),
              _field(addr, tr('Adresse', 'العنوان')),
              _field(phone, tr('Téléphone', 'الهاتف')),
              OutlinedButton.icon(icon: const Icon(Icons.my_location), label: Text(located ? tr('Mettre à jour ma position', 'تحديث موقعي') : tr('Utiliser ma position actuelle', 'استخدام موقعي الحالي')), onPressed: _locate),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(located ? tr('✓ Votre commerce apparaît sur la carte des clients.', '✓ يظهر متجرك على خريطة الزبائن.') : tr('Placez-vous dans votre commerce, puis touchez le bouton : sinon vous n\'apparaissez pas sur la carte.', 'كن داخل متجرك ثم المس الزر: وإلا فلن تظهر على الخريطة.'), style: TextStyle(fontSize: 12, color: located ? Colors.green : Colors.orange)),
              ),
              _h(tr('Programme de fidélité', 'برنامج الولاء')),
              _field(ppv, tr('Points par visite', 'نقاط لكل زيارة'), number: true),
              _field(thr, tr('Points pour une récompense', 'نقاط للمكافأة'), number: true),
              _field(per, tr('Heures entre deux scans du même client', 'ساعات بين مسحين لنفس الزبون'), number: true),
              FilledButton(onPressed: saving ? null : _save, child: Text(tr('Enregistrer', 'حفظ'))),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 12),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.stars_rounded), title: Text('${store.shop?['points_per_visit']} ${tr('points par visite', 'نقاط لكل زيارة')}'), subtitle: Text('${store.threshold} ${tr('points pour une récompense', 'نقطة للمكافأة')}')),
              const SizedBox(height: 12),
            ],
            if (store.manager) ...[
              Text(tr('Équipe', 'الفريق'), style: theme.textTheme.titleMedium),
              for (final m in store.team)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${m['display_name']}'),
                  subtitle: Text(roles['${m['role']}'] ?? '${m['role']}'),
                  trailing: store.isOwner && m['role'] != 'owner'
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () async {
                            try {
                              await store.removeStaff('${m['user_id']}');
                            } catch (e) {
                              snack(context, errText(e));
                            }
                          },
                        )
                      : null,
                ),
              if (store.isOwner) ...[
                const SizedBox(height: 8),
                _field(code, tr('Code de la personne à ajouter', 'رمز الشخص المراد إضافته')),
                Row(children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [ButtonSegment(value: 'employee', label: Text(roles['employee']!)), ButtonSegment(value: 'manager', label: Text(roles['manager']!))],
                      selected: {newRole},
                      onSelectionChanged: (s) => setState(() => newRole = s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await store.addStaff(code.text, newRole);
                        code.clear();
                        snack(context, tr('Ajouté à l\'équipe', 'تمت الإضافة للفريق'));
                      } catch (e) {
                        snack(context, errText(e));
                      }
                    },
                    child: Text(tr('Ajouter', 'إضافة')),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
            ],
            const Divider(),
            ListTile(leading: const Icon(Icons.badge_outlined), title: Text('${store.myName} · ${store.email}'), subtitle: Text('${tr('Mon code', 'رمزي')} : ${store.myCode}')),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(tr('Langue', 'اللغة')),
              trailing: SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'fr', label: Text('FR')), ButtonSegment(value: 'ar', label: Text('عربي'))],
                selected: {lang},
                onSelectionChanged: (s) => store.setLang(s.first),
              ),
            ),
            ListTile(leading: const Icon(Icons.password_rounded), title: Text(tr('Changer le mot de passe', 'تغيير كلمة السر')), onTap: _changePassword),
            ListTile(leading: const Icon(Icons.logout), title: Text(tr('Se déconnecter', 'تسجيل الخروج')), onTap: store.signOut),
            ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: Text(tr('Supprimer mon compte', 'حذف حسابي'), style: const TextStyle(color: Colors.red)), onTap: _delete),
            const SizedBox(height: 12),
            const Center(child: Text('Nqata Pro 0.2.0', style: TextStyle(color: Colors.grey))),
          ]);
        },
      );
}
