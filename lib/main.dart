import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tabs.dart';

// La clé "publishable" est faite pour être dans l'app : la sécurité vient des règles (RLS) de la base.
const supabaseUrl = 'https://nmecbbmlvrzeqazapijf.supabase.co';
const supabaseKey = 'sb_publishable_-zL5W-Pf5WMHAZZCONw4_g_RNbjhE5g';
const brandDark = Color(0xFF0B5F50);
const brandLight = Color(0xFF14B8A6);

const shopCats = [('cafe', 'Café', 'مقهى'), ('food', 'Alimentation', 'مواد غذائية'), ('health', 'Santé', 'صحة'), ('beauty', 'Beauté', 'تجميل'), ('other', 'Autres', 'أخرى')];

String lang = 'fr';
String tr(String fr, String ar) => lang == 'ar' ? ar : fr;

String errText(Object e) {
  final m = e is AuthException ? e.message : e is PostgrestException ? e.message : e.toString();
  const map = {
    'already_scanned': ['Déjà scanné pendant la période du programme', 'تم مسحه مسبقًا في هذه الفترة'],
    'invalid_or_expired_qr': ['QR expiré ou déjà utilisé : demandez au client de le rafraîchir', 'الرمز منتهي أو مستعمل: اطلب من الزبون تحديثه'],
    'shop_inactive': ['Commerce pas encore validé', 'المتجر لم يُفعَّل بعد'],
    'client_not_found': ['Client introuvable : vérifiez le code', 'الزبون غير موجود: تحقق من الرمز'],
    'not_staff': ['Accès refusé', 'غير مصرح'],
    'not_allowed': ['Action non autorisée pour votre rôle', 'إجراء غير مسموح لدورك'],
    'scan_not_found': ['Scan introuvable ou déjà annulé', 'المسح غير موجود أو ملغى'],
    'not_enough_points': ['Points insuffisants', 'نقاط غير كافية'],
    'user_not_found': ['Aucun compte avec ce code', 'لا يوجد حساب بهذا الرمز'],
    'bad_role': ['Rôle invalide', 'دور غير صالح'],
    'bad_amount': ['Montant invalide', 'مبلغ غير صالح'],
    'confirm_email': ['Compte créé : confirmez votre e-mail puis connectez-vous', 'تم إنشاء الحساب: أكّد بريدك ثم سجّل الدخول'],
    'Invalid login credentials': ['E-mail ou mot de passe incorrect', 'بريد أو كلمة سر خاطئة'],
    'rate limit': ['Trop d\'e-mails envoyés, réessayez plus tard', 'رسائل كثيرة، حاول لاحقًا'],
  };
  for (final k in map.keys) {
    if (m.contains(k)) return tr(map[k]![0], map[k]![1]);
  }
  return tr('Erreur : $m', 'خطأ: $m');
}

/// Données du commerçant, lues depuis Supabase.
class Store extends ChangeNotifier {
  bool loggedIn = false, loaded = false;
  String? loadError;
  String myName = '', myCode = '';
  Map<String, dynamic>? shop;
  Map<String, dynamic>? rating; // note moyenne du commerce
  List<Map<String, dynamic>> clients = [], scans = [], offers = [], redeems = [], team = [];
  ThemeMode themeMode = ThemeMode.system;
  // Historique (180 jours) : statistiques et fiche client
  List<Map<String, dynamic>> history = [], redeemHistory = [];
  bool hasAmount = true, historyLoaded = false, historyStale = true, historyLoading = false;

  SupabaseClient get sb => Supabase.instance.client;
  String get uid => sb.auth.currentUser!.id;
  String get email => sb.auth.currentUser?.email ?? '';
  String get shopId => '${shop!['id']}';
  String get role => '${shop?['role'] ?? ''}';
  bool get manager => role == 'owner' || role == 'manager';
  bool get isOwner => role == 'owner';
  bool get active => shop?['status'] == 'active';
  int get threshold => (shop?['reward_threshold'] as int?) ?? 100;
  String clientName(String? id) {
    for (final c in clients) {
      if (c['client_id'] == id) return '${c['display_name']}';
    }
    return '—';
  }

  Future<List<Map<String, dynamic>>> _q(Future<dynamic> f) async {
    try {
      return List<Map<String, dynamic>>.from(await f);
    } catch (_) {
      return [];
    }
  }

  /// Scans du jour. Si la colonne `amount` n'existe pas encore, on retombe sur l'ancienne requête.
  Future<List<Map<String, dynamic>>> _todayScans(String start) async {
    try {
      final r = await sb.from('scans').select('id, client_id, staff_id, points, amount, created_at, undone_at').eq('shop_id', shopId).gte('created_at', start).order('created_at', ascending: false);
      hasAmount = true;
      return List<Map<String, dynamic>>.from(r);
    } catch (_) {
      hasAmount = false;
      return _q(sb.from('scans').select('id, client_id, staff_id, points, created_at, undone_at').eq('shop_id', shopId).gte('created_at', start).order('created_at', ascending: false));
    }
  }

  /// Lit une table page par page (Supabase renvoie 1000 lignes max par requête).
  Future<List<Map<String, dynamic>>> _paged(Future<dynamic> Function(int from, int to) page) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < 20; i++) {
      final r = List<Map<String, dynamic>>.from(await page(i * 1000, i * 1000 + 999));
      out.addAll(r);
      if (r.length < 1000) break;
    }
    return out;
  }

  Future<void> loadHistory({bool force = false}) async {
    if (shop == null || !active || historyLoading) return;
    if (!force && historyLoaded && !historyStale) return;
    historyLoading = true;
    final since = DateTime.now().subtract(const Duration(days: 180)).toUtc().toIso8601String();
    Future<List<Map<String, dynamic>>> load(String cols) => _paged((a, b) => sb.from('scans').select(cols).eq('shop_id', shopId).gte('created_at', since).order('created_at', ascending: false).range(a, b));
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await load('id, client_id, points, amount, created_at, undone_at');
      hasAmount = true;
    } catch (_) {
      hasAmount = false;
      try {
        rows = await load('id, client_id, points, created_at, undone_at');
      } catch (_) {}
    }
    history = rows.where((s) => s['undone_at'] == null).toList();
    try {
      redeemHistory = await _paged((a, b) => sb.from('redemptions').select('id, points_cost, created_at').eq('shop_id', shopId).gte('created_at', since).order('created_at', ascending: false).range(a, b));
    } catch (_) {
      redeemHistory = [];
    }
    historyLoaded = true;
    historyStale = false;
    historyLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    const basic = 'id, name, status, category, address, phone, hours, points_per_visit, reward_threshold, scan_period_hours';
    try {
      List<dynamic> rows;
      try {
        rows = await sb.from('shop_staff').select('role, shops($basic, description, logo_url, cover_url, cover_color, lat, lng)').eq('user_id', uid).limit(1);
      } catch (_) {
        rows = await sb.from('shop_staff').select('role, shops($basic)').eq('user_id', uid).limit(1);
      }
      shop = rows.isEmpty ? null : {...Map<String, dynamic>.from(rows.first['shops'] as Map), 'role': rows.first['role']};
      loadError = null;
    } catch (e) {
      loadError = errText(e);
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      final p = await sb.from('profiles').select('display_name, client_code').eq('id', uid).maybeSingle();
      myName = (p?['display_name'] as String?) ?? '';
      myCode = (p?['client_code'] as String?) ?? '';
    } catch (_) {}
    if (shop != null && active) {
      try {
        rating = await sb.from('shop_ratings').select('avg_rating, reviews_count').eq('shop_id', shopId).maybeSingle();
      } catch (_) {
        rating = null;
      }
      final t = DateTime.now();
      final start = DateTime(t.year, t.month, t.day).toUtc().toIso8601String();
      final r = await Future.wait([
        _q(sb.from('shop_clients').select('client_id, display_name, points, last_scan_at').eq('shop_id', shopId).order('points', ascending: false)),
        _todayScans(start),
        _q(sb.from('offers').select('id, title, audience, created_at, expires_at').eq('shop_id', shopId).order('created_at', ascending: false).limit(30)),
        _q(sb.from('redemptions').select('id, points_cost').eq('shop_id', shopId).gte('created_at', start)),
        manager ? _q(sb.from('shop_team').select('user_id, display_name, role').eq('shop_id', shopId)) : Future.value(<Map<String, dynamic>>[]),
      ]);
      clients = r[0]; scans = r[1]; offers = r[2]; redeems = r[3]; team = r[4];
      historyStale = true;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> start() async {
    loggedIn = true;
    loaded = false;
    notifyListeners();
    await refresh();
  }

  Future<void> signIn(String e, String p) async {
    await sb.auth.signInWithPassword(email: e, password: p);
    await start();
  }

  Future<void> signUp(String e, String p, String n) async {
    final r = await sb.auth.signUp(email: e, password: p, data: {'display_name': n.isEmpty ? 'Commerçant' : n});
    if (r.session == null) throw 'confirm_email';
    await start();
  }

  Future<void> signOut() async {
    try { await sb.auth.signOut(); } catch (_) {}
    loggedIn = false; loaded = false; shop = null; clients = []; scans = []; offers = []; redeems = []; team = [];
    history = []; redeemHistory = []; historyLoaded = false; historyStale = true;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await sb.rpc('delete_my_account');
    await signOut();
  }

  void setLang(String l) {
    lang = l;
    SharedPreferences.getInstance().then((p) => p.setString('lang', l));
    notifyListeners();
  }

  // ----- Actions du commerçant -----
  Future<void> registerShop(String name, String category, String address, String phone) async {
    await sb.rpc('register_shop', params: {'p_name': name, 'p_category': category, 'p_address': address, 'p_phone': phone});
    await refresh();
  }

  /// Scan d'un QR client (jeton de 32 caractères) ou saisie manuelle du code client / téléphone.
  Future<Map<String, dynamic>> scan(String raw) async {
    final v = raw.trim();
    final isToken = RegExp(r'^[0-9a-f]{32}$').hasMatch(v);
    final r = isToken
        ? await sb.rpc('record_scan', params: {'p_shop': shopId, 'p_token': v})
        : await sb.rpc('record_scan_by_phone', params: {'p_shop': shopId, 'p_phone': v});
    final res = Map<String, dynamic>.from(r as Map);
    try {
      final s = await sb.from('scans').select('client_id').eq('id', res['scan_id']).single();
      res['client_id'] = s['client_id'];
    } catch (_) {}
    refresh();
    return res;
  }

  Future<void> undo(String scanId) async {
    await sb.rpc('undo_scan', params: {'p_scan': scanId});
    await refresh();
  }

  Future<void> redeem(String clientId) async {
    await sb.rpc('redeem_reward', params: {'p_shop': shopId, 'p_client': clientId});
    await refresh();
  }

  Future<void> sendOffer(String title, String audience, {int? days}) async {
    await sb.from('offers').insert({
      'shop_id': shopId,
      'title': title,
      'audience': audience,
      if (days != null) 'expires_at': DateTime.now().add(Duration(days: days)).toUtc().toIso8601String(),
    });
    await refresh();
  }

  Future<void> deleteOffer(String id) async {
    await sb.from('offers').delete().eq('id', id);
    await refresh();
  }

  Future<void> updateShop(Map<String, dynamic> values) async {
    await sb.from('shops').update(values).eq('id', shopId);
    await refresh();
  }

  /// Logo ou image de fond : envoyé dans le dossier du commerce (stockage Supabase), puis enregistré sur la fiche.
  Future<void> uploadImage(String kind, Uint8List bytes, String filename) async {
    final png = filename.toLowerCase().endsWith('.png');
    final path = '$shopId/$kind.${png ? 'png' : 'jpg'}';
    await sb.storage.from('shop-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg', upsert: true));
    final url = '${sb.storage.from('shop-media').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await updateShop({kind == 'logo' ? 'logo_url' : 'cover_url': url});
  }

  /// Montant de l'achat (pour le panier moyen). Nécessite la fonction SQL `set_scan_amount`.
  Future<void> setScanAmount(String scanId, double amount) async {
    await sb.rpc('set_scan_amount', params: {'p_scan': scanId, 'p_amount': amount});
    historyStale = true;
    await refresh();
  }

  Future<void> updateName(String n) async {
    await sb.from('profiles').update({'display_name': n}).eq('id', uid);
    myName = n;
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    SharedPreferences.getInstance().then((p) => p.setString('theme', m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system'));
    notifyListeners();
  }

  // ----- Galerie photos (dossier gallery/ du commerce) -----
  Future<List<String>> listGallery() async {
    final bucket = sb.storage.from('shop-media');
    final files = await bucket.list(path: '$shopId/gallery');
    final names = files.map((f) => f.name).where((n) => n.isNotEmpty && !n.startsWith('.')).toList()..sort();
    return [for (final n in names) '${bucket.getPublicUrl('$shopId/gallery/$n')}?v=$n'];
  }

  Future<void> addGalleryPhoto(Uint8List bytes, String filename) async {
    final png = filename.toLowerCase().endsWith('.png');
    final path = '$shopId/gallery/${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await sb.storage.from('shop-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
  }

  Future<void> removeGalleryPhoto(String url) async {
    final name = Uri.parse(url).pathSegments.last;
    await sb.storage.from('shop-media').remove(['$shopId/gallery/$name']);
  }

  Future<void> changePassword(String p) async {
    await sb.auth.updateUser(UserAttributes(password: p));
  }

  Future<void> addStaff(String code, String role) async {
    await sb.rpc('owner_add_staff', params: {'p_shop': shopId, 'p_code': code, 'p_role': role});
    await refresh();
  }

  Future<void> removeStaff(String userId) async {
    await sb.rpc('owner_remove_staff', params: {'p_shop': shopId, 'p_user': userId});
    await refresh();
  }
}

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  lang = prefs.getString('lang') ?? 'fr';
  store.themeMode = switch (prefs.getString('theme')) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  if (Supabase.instance.client.auth.currentSession != null) store.start();
  runApp(const NqataPro());
}

class NqataPro extends StatelessWidget {
  const NqataPro({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66), brightness: b),
        navigationBarTheme: const NavigationBarThemeData(height: 68, indicatorShape: StadiumBorder()),
      );

  Widget _home() {
    if (!store.loggedIn) return const LoginPage();
    if (!store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (store.loadError != null) return const InfoPage(kind: 'error');
    if (store.shop == null) return const RegisterShopPage();
    if (!store.active) return const InfoPage(kind: 'pending');
    return const Shell();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => MaterialApp(
          title: 'Nqata Pro',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: store.themeMode,
          builder: (c, child) => Directionality(textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!),
          home: _home(),
        ),
      );
}

// ---------- Connexion / inscription ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  bool signup = false, busy = false;
  String? error;

  @override
  void dispose() { name.dispose(); email.dispose(); pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      final e = email.text.trim();
      signup ? await store.signUp(e, pass.text, name.text.trim()) : await store.signIn(e, pass.text);
    } catch (err) {
      if (mounted) setState(() => error = errText(err));
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _f(TextEditingController c, String l, {bool secret = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, obscureText: secret, keyboardType: type, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandLight])),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Theme(
                data: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66))),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('NQATA PRO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3, color: brandDark)),
                    Text(tr('Espace commerçant', 'فضاء التاجر'), style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    if (signup) _f(name, tr('Votre prénom', 'اسمك')),
                    _f(email, 'E-mail', type: TextInputType.emailAddress),
                    _f(pass, tr('Mot de passe (6 caractères min.)', 'كلمة السر (6 أحرف على الأقل)'), secret: true),
                    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(signup ? tr('Créer mon compte', 'إنشاء الحساب') : tr('Se connecter', 'دخول')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() { signup = !signup; error = null; }),
                      child: Text(signup ? tr('J\'ai déjà un compte', 'لدي حساب') : tr('Pas de compte ? S\'inscrire', 'ليس لدي حساب؟ سجّل')),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------- Inscription du commerce ----------
class RegisterShopPage extends StatefulWidget {
  const RegisterShopPage({super.key});
  @override
  State<RegisterShopPage> createState() => _RegisterShopPageState();
}

class _RegisterShopPageState extends State<RegisterShopPage> {
  final name = TextEditingController(), address = TextEditingController(), phone = TextEditingController();
  String cat = 'other';
  bool busy = false;
  String? error;

  @override
  void dispose() { name.dispose(); address.dispose(); phone.dispose(); super.dispose(); }

  Future<void> _go() async {
    if (name.text.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await store.registerShop(name.text.trim(), cat, address.text.trim(), phone.text.trim());
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _f(TextEditingController c, String l) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Inscrire mon commerce', 'تسجيل متجري')), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: store.signOut)]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(tr('Bienvenue ! Décrivez votre commerce. L\'équipe Nqata le validera avant l\'activation.', 'مرحبًا! صف متجرك. سيقوم فريق نقطة بالموافقة عليه قبل التفعيل.')),
          const SizedBox(height: 16),
          _f(name, tr('Nom du commerce', 'اسم المتجر')),
          Text(tr('Type de commerce', 'نوع المتجر')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [for (final c in shopCats) ChoiceChip(label: Text(tr(c.$2, c.$3)), selected: cat == c.$1, onSelected: (_) => setState(() => cat = c.$1))]),
          const SizedBox(height: 12),
          _f(address, tr('Adresse', 'العنوان')),
          _f(phone, tr('Téléphone', 'الهاتف')),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          FilledButton(onPressed: busy ? null : _go, child: Text(tr('Envoyer ma demande', 'إرسال الطلب'))),
          const SizedBox(height: 8),
          Text(tr('Vous faites partie de l\'équipe d\'un commerce ? Donnez votre code au propriétaire : ${store.myCode}', 'أنت ضمن فريق متجر؟ أعطِ رمزك للمالك: ${store.myCode}'), style: const TextStyle(color: Colors.grey)),
          TextButton(onPressed: store.refresh, child: Text(tr('Actualiser', 'تحديث'))),
        ]),
      );
}

// ---------- En attente de validation / erreur de chargement ----------
class InfoPage extends StatelessWidget {
  final String kind;
  const InfoPage({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final pending = kind == 'pending';
    return Scaffold(
      appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.logout), onPressed: store.signOut)]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(pending ? Icons.hourglass_top_rounded : Icons.wifi_off_rounded, size: 72, color: pending ? Colors.orange : Colors.grey),
            const SizedBox(height: 16),
            Text(
              pending ? tr('Commerce en attente de validation', 'المتجر بانتظار الموافقة') : (store.loadError ?? ''),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (pending) Text('${store.shop?['name'] ?? ''}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(onPressed: store.refresh, child: Text(tr('Actualiser', 'تحديث'))),
          ]),
        ),
      ),
    );
  }
}
