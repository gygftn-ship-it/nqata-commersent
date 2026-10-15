import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'tabs.dart';
import 'icons.dart';
import 'offers_page.dart';

const _covers = ['#6B3F2A', '#B45309', '#15803D', '#0E7490', '#4C1D95', '#BE185D', '#1D4ED8', '#15120B', '#FFD60A'];
const _maxGallery = 8;

Color? _hex(String? h) {
  if (h == null || h.isEmpty) return null;
  try {
    return Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// null = horaires non renseignés
bool? _isOpenNow(String? hours) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*[–—-]\s*(\d{1,2}):(\d{2})').firstMatch(hours ?? '');
  if (m == null) return null;
  final a = int.parse(m[1]!) * 60 + int.parse(m[2]!), b = int.parse(m[3]!) * 60 + int.parse(m[4]!);
  final n = DateTime.now().hour * 60 + DateTime.now().minute;
  return a <= b ? (n >= a && n < b) : (n >= a || n < b);
}

/// Onglet « Commerce » : vitrine (photos, fond, description), horaires, position, fidélité, offres, équipe.
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
  bool saving = false, uploading = false, dirty = false;
  List<String> gallery = [];
  bool galleryOk = true;

  @override
  void initState() {
    super.initState();
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*[–—-]\s*(\d{1,2}):(\d{2})').firstMatch('${store.shop?['hours'] ?? ''}');
    if (m != null) {
      open = TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
      close = TimeOfDay(hour: int.parse(m[3]!), minute: int.parse(m[4]!));
    }
    for (final c in [addr, phone, desc, ppv, thr, per]) { c.addListener(_markDirty); }
    if (store.isOwner) _loadGallery();
  }

  @override
  void dispose() {
    for (final c in [addr, phone, desc, ppv, thr, per, code]) { c.dispose(); }
    super.dispose();
  }

  void _markDirty() { if (!dirty && mounted) setState(() => dirty = true); }

  Future<void> _loadGallery() async {
    try {
      final g = await store.listGallery();
      if (mounted) setState(() { gallery = g; galleryOk = true; });
    } catch (_) {
      if (mounted) setState(() => galleryOk = false);
    }
  }

  Future<void> _pickTime(bool isOpen) async {
    final t = await showTimePicker(context: context, initialTime: (isOpen ? open : close) ?? TimeOfDay(hour: isOpen ? 8 : 20, minute: 0));
    if (t != null) setState(() { isOpen ? open = t : close = t; dirty = true; });
  }

  Future<void> _pickImage(String kind) async {
    final big = kind != 'logo';
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: big ? 1400 : 600, maxHeight: big ? 1400 : 600, imageQuality: 85);
    if (x == null) return;
    setState(() => uploading = true);
    try {
      final bytes = await x.readAsBytes();
      if (kind == 'gallery') {
        await store.addGalleryPhoto(bytes, x.name);
        await _loadGallery();
      } else {
        await store.uploadImage(kind, bytes, x.name);
      }
      snack(context, tr('Image enregistrée', 'تم حفظ الصورة'));
    } catch (e) {
      snack(context, errText(e));
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> _removePhoto(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Supprimer cette photo ?', 'حذف هذه الصورة؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Annuler', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Supprimer', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.removeGalleryPhoto(url);
      await _loadGallery();
    } catch (e) {
      snack(context, errText(e));
    }
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
    try {
      await store.updateShop(values);
      if (mounted) setState(() => dirty = false);
      snack(context, tr('Enregistré', 'تم الحفظ'));
    } catch (e) {
      snack(context, errText(e));
    }
    if (mounted) setState(() => saving = false);
  }

  Widget _field(TextEditingController c, String l, {bool number = false, int lines = 1, int? max, IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, keyboardType: number ? TextInputType.number : null, minLines: lines, maxLines: lines, maxLength: max, decoration: InputDecoration(prefixIcon: icon == null ? null : Icon(icon), labelText: l, border: const OutlineInputBorder())),
      );

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  /// Aperçu de la vitrine, comme la voient les clients.
  Widget _preview() {
    final shop = store.shop;
    final cover = shop?['cover_url'] as String?, logo = shop?['logo_url'] as String?;
    final coverColor = _hex(shop?['cover_color'] as String?) ?? kInk;
    final r = store.rating;
    final isOpen = _isOpenNow(shop?['hours'] as String?);
    final catLabel = shopCats.firstWhere((c) => c.$1 == '${shop?['category']}', orElse: () => shopCats.last);
    final description = '${shop?['description'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          height: 150,
          decoration: BoxDecoration(color: coverColor, borderRadius: BorderRadius.circular(22), image: cover == null || cover.isEmpty ? null : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)),
        ),
        if (store.isOwner)
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
          bottom: -36,
          child: GestureDetector(
            onTap: store.isOwner && !uploading ? () => _pickImage('logo') : null,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: CircleAvatar(
                radius: 38,
                backgroundColor: Colors.black12,
                backgroundImage: logo == null || logo.isEmpty ? null : NetworkImage(logo),
                child: logo == null || logo.isEmpty ? Icon(store.isOwner ? Icons.add_a_photo_outlined : Icons.storefront_rounded) : null,
              ),
            ),
          ),
        ),
      ]),
      if (uploading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      const SizedBox(height: 44),
      Text('${shop?['name'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: [
        _chip(tr(catLabel.$2, catLabel.$3), Theme.of(context).colorScheme.onSurface),
        if (isOpen != null) _chip(isOpen ? tr('Ouvert', 'مفتوح') : tr('Fermé', 'مغلق'), isOpen ? kOk : kDanger),
        _chip(r == null ? tr('Pas encore de note', 'لا تقييم بعد') : '★ ${(r['avg_rating'] as num).toStringAsFixed(1)} · ${r['reviews_count']} ${tr('avis', 'تقييم')}', kWarn),
      ]),
      if (description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(description)),
      if (store.isOwner)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('Touchez le logo pour le changer.', 'المس الشعار لتغييره.'), style: const TextStyle(fontSize: 12, color: kMuted))),
    ]);
  }

  Widget _galleryGrid() {
    final tiles = <Widget>[
      for (final url in gallery)
        Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 88, height: 88, color: Colors.black12, child: const Icon(Icons.broken_image_outlined)))),
          PositionedDirectional(top: 2, end: 2, child: GestureDetector(onTap: () => _removePhoto(url), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)))),
        ]),
      if (gallery.length < _maxGallery)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: uploading ? null : () => _pickImage('gallery'),
          child: Container(width: 88, height: 88, decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo_outlined)),
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: tiles);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final theme = Theme.of(context);
          final roles = {'owner': tr('Propriétaire', 'مالك'), 'manager': tr('Gérant', 'مدير'), 'employee': tr('Employé', 'موظف')};
          final located = store.shop?['lat'] != null && store.shop?['lng'] != null;
          final activeOffers = store.offers.where((o) => o['expires_at'] == null || localDt(o['expires_at']).isAfter(DateTime.now())).length;
          return Stack(children: [
            RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(16, 16, 16, dirty ? 90 : 24), children: [
                FadeSlideIn(child: _preview()),
                if (store.isOwner) ...[
                  SectionCard(title: tr('Photos', 'الصور'), icon: NI.photos, children: [
                    Text(tr('Photos de votre commerce (${gallery.length}/$_maxGallery)', 'صور متجرك (${gallery.length}/$_maxGallery)'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (galleryOk)
                      _galleryGrid()
                    else
                      Text(tr('Galerie indisponible : exécutez supabase_update.sql (règles de stockage).', 'المعرض غير متاح: نفّذ ملف supabase_update.sql (قواعد التخزين).'), style: const TextStyle(fontSize: 12, color: kWarn)),
                    const SizedBox(height: 16),
                    Text(tr('Couleur de fond (si pas d\'image)', 'لون الخلفية (إن لم توجد صورة)'), style: theme.textTheme.titleSmall),
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
                  ]),
                  SectionCard(title: tr('Informations', 'المعلومات'), icon: NI.info, children: [
                    _field(desc, tr('Description du commerce', 'وصف المتجر'), lines: 4, max: 300),
                    Text(tr('Catégorie', 'الفئة'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [for (final c in shopCats) ChoiceChip(label: Text(tr(c.$2, c.$3)), selected: cat == c.$1, onSelected: (_) => setState(() { cat = c.$1; dirty = true; }))]),
                    const SizedBox(height: 16),
                    Text(tr('Horaires', 'ساعات العمل'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('${tr('Ouvre', 'يفتح')} : ${open == null ? '--:--' : _fmt(open!)}'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('${tr('Ferme', 'يغلق')} : ${close == null ? '--:--' : _fmt(close!)}'))),
                    ]),
                    const SizedBox(height: 4),
                    Text(tr('Les clients voient « Ouvert » ou « Fermé » selon ces horaires.', 'يرى الزبائن «مفتوح» أو «مغلق» حسب هذه الساعات.'), style: const TextStyle(fontSize: 12, color: kMuted)),
                    const SizedBox(height: 16),
                    _field(addr, tr('Adresse', 'العنوان'), icon: Icons.place_outlined),
                    _field(phone, tr('Téléphone', 'الهاتف'), icon: Icons.phone_outlined),
                    OutlinedButton.icon(icon: const Icon(Icons.my_location), label: Text(located ? tr('Mettre à jour ma position', 'تحديث موقعي') : tr('Utiliser ma position actuelle', 'استخدام موقعي الحالي')), onPressed: _locate),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(located ? tr('✓ Votre commerce apparaît sur la carte des clients.', '✓ يظهر متجرك على خريطة الزبائن.') : tr('Placez-vous dans votre commerce, puis touchez le bouton : sinon vous n\'apparaissez pas sur la carte.', 'كن داخل متجرك ثم المس الزر: وإلا فلن تظهر على الخريطة.'), style: TextStyle(fontSize: 12, color: located ? kOk : kWarn)),
                    ),
                  ]),
                  SectionCard(title: tr('Programme de fidélité', 'برنامج الولاء'), icon: NI.points, children: [
                    _field(ppv, tr('Points par visite', 'نقاط لكل زيارة'), number: true),
                    _field(thr, tr('Points pour une récompense', 'نقاط للمكافأة'), number: true),
                    _field(per, tr('Heures entre deux scans du même client', 'ساعات بين مسحين لنفس الزبون'), number: true),
                  ]),
                ] else
                  SectionCard(title: tr('Programme de fidélité', 'برنامج الولاء'), icon: NI.points, children: [
                    Text('${store.shop?['points_per_visit']} ${tr('points par visite', 'نقاط لكل زيارة')}'),
                    Text('${store.threshold} ${tr('points pour une récompense', 'نقطة للمكافأة')}'),
                  ]),
                if (store.manager)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: const NIcon(NI.offer),
                        title: Text(tr('Offres et promotions', 'العروض والترويج'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('$activeOffers ${tr('offre(s) en cours', 'عرض ساري')}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersPage())),
                      ),
                    ),
                  ),
                if (store.manager)
                  SectionCard(title: tr('Équipe', 'الفريق'), icon: NI.clients, children: [
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
                  ]),
              ]),
            ),
            if (dirty && store.isOwner)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: saving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)) : const Icon(Icons.save_rounded),
                  label: Text(tr('Enregistrer les modifications', 'حفظ التعديلات')),
                  onPressed: saving ? null : _save,
                ),
              ),
          ]);
        },
      );
}
