import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'local_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tabs.dart';
import 'team_pages.dart';
import 'icons.dart';
import 'ui.dart';
import 'auth_ui.dart';

// La clé "publishable" est faite pour être dans l'app : la sécurité vient des règles (RLS) de la base.
const supabaseUrl = 'https://nmecbbmlvrzeqazapijf.supabase.co';
const supabaseKey = 'sb_publishable_-zL5W-Pf5WMHAZZCONw4_g_RNbjhE5g';
// ---- Identité visuelle : le ticket de caisse (encre, papier, jaune surligneur) ----
const kInk = Color(0xFF131312);
const kPaper = Colors.white;
const kAccent = Color(0xFFFFD60A);
const kAccentSoft = Color(0xFFFFF1B8);
const kLine = Color(0xFFD8D7CF);
const kMuted = Color(0xFF727068);
const kNeutral = Color(0xFFB8B6AE);
const kOk = Color(0xFF1F8A52);
const kDanger = Color(0xFFD32F2F);
const kWarn = Color(0xFFA56A00);
const brandDark = kInk;
const brandLight = kAccent;

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
    'invite_invalid': ['QR d\'invitation invalide ou introuvable', 'رمز الدعوة غير صالح'],
    'invite_used': ['Ce QR a déjà été utilisé : demandez-en un nouveau au gérant', 'تم استعمال هذا الرمز: اطلب رمزًا جديدًا من المدير'],
    'invite_expired': ['Ce QR a expiré : demandez-en un nouveau au gérant', 'انتهت صلاحية الرمز: اطلب رمزًا جديدًا من المدير'],
    'already_in_shop': ['Vous faites déjà partie d\'une équipe', 'أنت ضمن فريق بالفعل'],
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
  final errors = <String, String>{}; // dernière erreur de lecture par source (clients, scans...)
  bool hasAmount = true, historyLoaded = false, historyStale = true, historyLoading = false;
  // Offres enrichies (description, type, valeur, pause) : disponibles seulement si la migration SQL a été appliquée.
  bool offersExt = true;
  Map<String, int> offerUses = {}; // offre -> nombre de validations
  List<Map<String, dynamic>> invites = [], offerLog = []; // invitations d'équipe en attente · historique des offres validées
  List<Map<String, dynamic>> reviews = []; // avis clients (table shop_reviews)
  String? onboardMode; // après inscription sans commerce : null (choix) · 'owner' · 'employee'

  // ----- Réglages locaux (propres à cet appareil) -----
  String offerAsk = 'scan'; // quand demander l'offre : 'scan' (à chaque scan) · 'reward' (récompense seulement) · 'never'
  bool offerAllowNone = true, askAmount = false, haptics = true;
  int autoCloseSecs = 8; // fermeture auto du résultat de scan (0 = jamais)

  void loadPrefs() {
    final a = FileStore.get('offerAsk');
    offerAsk = (a == 'reward' || a == 'never') ? a! : 'scan';
    offerAllowNone = FileStore.get('offerAllowNone') != 'false';
    askAmount = FileStore.get('askAmount') == 'true';
    haptics = FileStore.get('haptics') != 'false';
    autoCloseSecs = int.tryParse(FileStore.get('autoCloseSecs') ?? '') ?? 8;
  }

  void setOfferAsk(String v) { offerAsk = v; FileStore.set('offerAsk', v); notifyListeners(); }
  void setOfferAllowNone(bool v) { offerAllowNone = v; FileStore.set('offerAllowNone', '$v'); notifyListeners(); }
  void setAskAmount(bool v) { askAmount = v; FileStore.set('askAmount', '$v'); notifyListeners(); }
  void setHaptics(bool v) { haptics = v; FileStore.set('haptics', '$v'); notifyListeners(); }
  void setAutoClose(int s) { autoCloseSecs = s; FileStore.set('autoCloseSecs', '$s'); notifyListeners(); }
  void buzz({bool heavy = false}) {
    if (!haptics) return;
    heavy ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  }

  void setOnboardMode(String? m) { onboardMode = m; notifyListeners(); }

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

  String _raw(Object e) => e is PostgrestException ? '${e.message}${e.code != null ? ' [${e.code}]' : ''}' : '$e';

  Future<List<Map<String, dynamic>>> _q(Future<dynamic> f, [String? key]) async {
    try {
      final r = List<Map<String, dynamic>>.from(await f);
      if (key != null) errors.remove(key);
      return r;
    } catch (e) {
      if (key != null) errors[key] = _raw(e);
      return [];
    }
  }

  /// Scans du jour. Si la colonne `amount` n'existe pas encore, on retombe sur l'ancienne requête.
  Future<List<Map<String, dynamic>>> _todayScans(String start) async {
    try {
      final r = await sb.from('scans').select('id, client_id, staff_id, points, amount, created_at, undone_at').eq('shop_id', shopId).gte('created_at', start).order('created_at', ascending: false);
      hasAmount = true;
      errors.remove('scans');
      return List<Map<String, dynamic>>.from(r);
    } catch (_) {
      hasAmount = false;
      return _q(sb.from('scans').select('id, client_id, staff_id, points, created_at, undone_at').eq('shop_id', shopId).gte('created_at', start).order('created_at', ascending: false), 'scans');
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
        errors.remove('history');
      } catch (e) {
        errors['history'] = _raw(e);
      }
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
        errors.remove('rating');
      } catch (e) {
        rating = null;
        errors['rating'] = _raw(e); // visible dans l'onglet Commerce
      }
      final t = DateTime.now();
      final start = DateTime(t.year, t.month, t.day).toUtc().toIso8601String();
      final r = await Future.wait([
        _q(sb.from('shop_clients').select('client_id, display_name, points, last_scan_at').eq('shop_id', shopId).order('points', ascending: false), 'clients'),
        _todayScans(start),
        _loadOffers(),
        _q(sb.from('redemptions').select('id, points_cost').eq('shop_id', shopId).gte('created_at', start), 'redeems'),
        manager ? _q(sb.from('shop_team').select('user_id, display_name, role').eq('shop_id', shopId), 'team') : Future.value(<Map<String, dynamic>>[]),
        manager ? _q(sb.rpc('list_staff_invites', params: {'p_shop': shopId}), 'invites') : Future.value(<Map<String, dynamic>>[]),
      ]);
      clients = r[0]; scans = r[1]; offers = r[2]; redeems = r[3]; team = r[4]; invites = r[5];
      await _loadOfferUses();
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

  Future<void> signUp(String e, String p, String n, {String? mode}) async {
    onboardMode = mode;
    final r = await sb.auth.signUp(email: e, password: p, data: {'display_name': n.isEmpty ? 'Commerçant' : n});
    if (r.session == null) throw 'confirm_email';
    await start();
  }

  Future<void> signOut() async {
    try { await sb.auth.signOut(); } catch (_) {}
    loggedIn = false; loaded = false; shop = null; clients = []; scans = []; offers = []; redeems = []; team = [];
    history = []; redeemHistory = []; historyLoaded = false; historyStale = true; offerUses = {};
    invites = []; offerLog = []; reviews = []; onboardMode = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await sb.rpc('delete_my_account');
    await signOut();
  }

  void setLang(String l) {
    lang = l;
    FileStore.set('lang', l);
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

  /// Valide la récompense d'un client. `offer` = l'offre choisie (null = récompense de fidélité standard).
  /// Retourne false si l'offre choisie n'a pas pu être enregistrée (migration SQL manquante).
  Future<bool> redeem(String clientId, {Map<String, dynamic>? offer}) async {
    await sb.rpc('redeem_reward', params: {'p_shop': shopId, 'p_client': clientId});
    var saved = true;
    if (offer != null) saved = await recordOffer(clientId, offer, source: 'reward');
    await refresh();
    return saved;
  }

  /// Enregistre quelle offre a été utilisée par un client (lors d'un scan ou d'une récompense).
  /// Essaie d'abord la forme complète (scan, employé, titre), puis la forme simple si la migration SQL n'est pas appliquée.
  Future<bool> recordOffer(String clientId, Map<String, dynamic> offer, {String? scanId, String source = 'scan'}) async {
    final base = {'shop_id': shopId, 'offer_id': offer['id'], 'client_id': clientId};
    try {
      await sb.from('offer_redemptions').insert({...base, if (scanId != null) 'scan_id': scanId, 'staff_id': uid, 'offer_title': offer['title'], 'source': source});
    } catch (_) {
      try {
        await sb.from('offer_redemptions').insert(base);
      } catch (e) {
        errors['offerLog'] = _raw(e);
        return false;
      }
    }
    errors.remove('offerLog');
    await _loadOfferUses();
    notifyListeners();
    return true;
  }

  /// Avis clients du commerce (200 derniers). `select()` sans liste de colonnes : on lit ce que la table contient.
  Future<void> loadReviews() async {
    try {
      List<dynamic> rows;
      try {
        rows = await sb.from('shop_reviews').select().eq('shop_id', shopId).order('created_at', ascending: false).limit(200);
      } catch (_) {
        rows = await sb.from('shop_reviews').select().eq('shop_id', shopId).limit(200); // pas de colonne created_at
      }
      reviews = List<Map<String, dynamic>>.from(rows);
      errors.remove('reviews');
    } catch (e) {
      reviews = [];
      errors['reviews'] = _raw(e);
    }
    notifyListeners();
  }

  /// Historique des offres validées (200 dernières).
  Future<void> loadOfferLog() async {
    for (final cols in const ['id, offer_id, client_id, staff_id, offer_title, source, created_at', 'id, offer_id, client_id, created_at', 'offer_id, client_id']) {
      try {
        final q = sb.from('offer_redemptions').select(cols).eq('shop_id', shopId);
        final rows = cols.contains('created_at') ? await q.order('created_at', ascending: false).limit(200) : await q.limit(200);
        offerLog = List<Map<String, dynamic>>.from(rows);
        errors.remove('offerLog');
        notifyListeners();
        return;
      } catch (e) {
        errors['offerLog'] = _raw(e);
      }
    }
    offerLog = [];
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _loadOffers() async {
    try {
      final r = await sb.from('offers').select('id, title, description, kind, value, audience, active, created_at, expires_at').eq('shop_id', shopId).order('created_at', ascending: false).limit(50);
      offersExt = true;
      errors.remove('offers');
      return List<Map<String, dynamic>>.from(r);
    } catch (_) {
      offersExt = false;
      return _q(sb.from('offers').select('id, title, audience, created_at, expires_at').eq('shop_id', shopId).order('created_at', ascending: false).limit(50), 'offers');
    }
  }

  Future<void> _loadOfferUses() async {
    try {
      final rows = List<Map<String, dynamic>>.from(await sb.from('offer_redemptions').select('offer_id').eq('shop_id', shopId));
      final m = <String, int>{};
      for (final r in rows) {
        if (r['offer_id'] == null) continue;
        m['${r['offer_id']}'] = (m['${r['offer_id']}'] ?? 0) + 1;
      }
      offerUses = m;
    } catch (_) {
      offerUses = {};
    }
  }

  /// Une offre est « en cours » si elle n'est pas en pause et pas expirée.
  bool offerLive(Map<String, dynamic> o) {
    if (o['active'] == false) return false;
    final e = o['expires_at'] as String?;
    return e == null || DateTime.parse(e).toLocal().isAfter(DateTime.now());
  }

  Future<void> sendOffer(String title, String audience, {int? days, String? description, String kind = 'custom', num? value}) async {
    final base = {
      'shop_id': shopId,
      'title': title,
      'audience': audience,
      if (days != null) 'expires_at': DateTime.now().add(Duration(days: days)).toUtc().toIso8601String(),
    };
    try {
      await sb.from('offers').insert({
        ...base,
        if (offersExt) ...{'kind': kind, if (value != null) 'value': value, if (description != null && description.isNotEmpty) 'description': description},
      });
    } catch (_) {
      // Migration SQL pas encore appliquée : on enregistre l'offre sous sa forme simple.
      await sb.from('offers').insert(base);
    }
    await refresh();
  }

  Future<void> setOfferActive(String id, bool active) async {
    await sb.from('offers').update({'active': active}).eq('id', id);
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
    FileStore.set('theme', m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system');
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

  /// Génère un QR d'invitation unique (à usage unique) pour un futur membre de l'équipe.
  Future<Map<String, dynamic>> createInvite(String role, String label) async {
    final r = await sb.rpc('create_staff_invite', params: {'p_shop': shopId, 'p_role': role, 'p_label': label.isEmpty ? null : label});
    final inv = Map<String, dynamic>.from(r is List ? r.first as Map : r as Map);
    invites = await _q(sb.rpc('list_staff_invites', params: {'p_shop': shopId}), 'invites');
    notifyListeners();
    return inv;
  }

  Future<void> revokeInvite(String id) async {
    await sb.rpc('revoke_staff_invite', params: {'p_invite': id});
    invites = invites.where((i) => '${i['id']}' != id).toList();
    notifyListeners();
  }

  /// Côté employé : rejoint l'équipe en scannant le QR du gérant.
  Future<void> joinWithInvite(String token) async {
    await sb.rpc('join_shop_with_invite', params: {'p_token': token});
    onboardMode = null;
    await refresh();
  }

  Future<void> removeStaff(String userId) async {
    await sb.rpc('owner_remove_staff', params: {'p_shop': shopId, 'p_user': userId});
    await refresh();
  }
}

final store = Store();

Widget _fatal(String title, String msg) => Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: kInk,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: SelectableText('$title\n\n$msg', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Au lieu d'un écran gris muet, on affiche l'erreur pour pouvoir la lire / la capturer.
  ErrorWidget.builder = (d) => _fatal('Erreur d\'affichage', '${d.exceptionAsString()}\n\n${(d.stack?.toString() ?? '').split('\n').take(8).join('\n')}');
  try {
    await FileStore.init();
    lang = FileStore.get('lang') ?? 'fr';
    store.loadPrefs();
    store.themeMode = switch (FileStore.get('theme')) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.light };
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      authOptions: FlutterAuthClientOptions(localStorage: FileLocalStorage(), pkceAsyncStorage: FileAsyncStorage()),
    );
    if (Supabase.instance.client.auth.currentSession != null) store.start();
    runApp(const NqataPro());
  } catch (e, st) {
    runApp(_fatal('Erreur au démarrage', '$e\n\n${st.toString().split('\n').take(8).join('\n')}'));
  }
}

class NqataPro extends StatelessWidget {
  const NqataPro({super.key});

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final fg = dark ? const Color(0xFFF3F2ED) : kInk;
    final card = dark ? const Color(0xFF22201A) : kCream;
    final bg = dark ? const Color(0xFF14130F) : kPaper;
    final hair = dark ? const Color(0xFF2E2D29) : kLine;
    final soft = dark ? const Color(0xFF2A2A27) : const Color(0xFFEBEAE4);
    final scheme = ColorScheme(
      brightness: b,
      primary: dark ? const Color(0xFFF3F2ED) : kInk,
      onPrimary: dark ? kInk : Colors.white,
      secondary: dark ? const Color(0xFFF3F2ED) : kInk,
      onSecondary: dark ? kInk : Colors.white,
      primaryContainer: soft,
      onPrimaryContainer: fg,
      secondaryContainer: soft,
      onSecondaryContainer: fg,
      error: dark ? const Color(0xFFFF6B6B) : kDanger,
      onError: dark ? kInk : Colors.white,
      surface: card,
      onSurface: fg,
      onSurfaceVariant: dark ? const Color(0xFFA9A89F) : const Color(0xFF5E5D57),
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: bg,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: card,
      surfaceContainerHighest: card,
      outline: dark ? const Color(0xFF55544D) : const Color(0xFFC9C7BD),
      outlineVariant: hair,
    );
    OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      dividerColor: hair,
      appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: fg, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent, titleTextStyle: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kInk, disabledBackgroundColor: kAccent.withOpacity(0.4), minimumSize: const Size(64, 52), shape: const StadiumBorder(), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), side: BorderSide(color: scheme.outline), shape: const StadiumBorder())),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: ob(Colors.transparent),
        enabledBorder: ob(Colors.transparent),
        focusedBorder: ob(kAccent, 2),
        errorBorder: ob(scheme.error),
        focusedErrorBorder: ob(scheme.error, 1.6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: kAccent,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14),
        checkmarkColor: fg,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : bg),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kInk : fg),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          visualDensity: VisualDensity.standard,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32)))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFF3F2ED) : kInk,
        contentTextStyle: TextStyle(color: dark ? kInk : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(color: card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: dark ? const Color(0xFF2E2D29) : const Color(0xFFE6E4DC)),
    );
  }

  Widget _home() {
    if (!store.loggedIn) return const LoginPage();
    if (!store.loaded) return const SplashPage();
    if (store.loadError != null) return const InfoPage(kind: 'error');
    if (store.shop == null) {
      if (store.onboardMode == 'owner') return const RegisterShopPage();
      if (store.onboardMode == 'employee') return const JoinTeamPage();
      return const OnboardingPage();
    }
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
          builder: (c, child) {
            final mq = MediaQuery.of(c);
            return MediaQuery(
              // Polices système très grandes : on borne pour éviter les textes coupés.
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25)),
              child: Directionality(
                textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                // Toucher en dehors d'un champ ferme le clavier.
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => FocusManager.instance.primaryFocus?.unfocus(), child: child!),
              ),
            );
          },
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
  final emailFocus = FocusNode(), passFocus = FocusNode();
  bool signup = false, busy = false;
  String role = 'owner'; // à l'inscription : 'owner' (gérant) ou 'employee' (rejoint une équipe)
  String? error, info, nameErr, emailErr, passErr;

  @override
  void dispose() { name.dispose(); email.dispose(); pass.dispose(); emailFocus.dispose(); passFocus.dispose(); super.dispose(); }

  bool _validate() {
    emailErr = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()) ? null : tr('Adresse e-mail invalide', 'بريد إلكتروني غير صالح');
    passErr = signup
        ? (pass.text.length >= 6 ? null : tr('6 caractères minimum', '6 أحرف على الأقل'))
        : (pass.text.isNotEmpty ? null : tr('Entrez votre mot de passe', 'أدخل كلمة السر'));
    nameErr = signup && name.text.trim().isEmpty ? tr('Entrez votre prénom', 'أدخل اسمك') : null;
    setState(() {});
    return emailErr == null && passErr == null && nameErr == null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { error = null; info = null; });
    if (!_validate()) return;
    setState(() => busy = true);
    try {
      final e = email.text.trim();
      signup ? await store.signUp(e, pass.text, name.text.trim(), mode: role) : await store.signIn(e, pass.text);
    } catch (err) {
      if ('$err'.contains('confirm_email')) {
        if (mounted) setState(() { info = errText(err); signup = false; });
      } else if (mounted) {
        setState(() => error = errText(err));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  void _switch(bool toSignup) => setState(() { signup = toSignup; error = null; info = null; nameErr = emailErr = passErr = null; });

  Widget _role(String v, IconData i, String t, String s) {
    final sel = role == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => role = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? (isDark(context) ? const Color(0xFF3A372E) : kAccentSoft) : cardColor(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: sel ? kAccent : Colors.transparent, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 28),
            const SizedBox(height: 8),
            Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(s, style: const TextStyle(fontSize: 12, color: kMuted)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AuthTabs(labels: [tr('Connexion', 'دخول'), tr('Inscription', 'تسجيل')], selected: signup ? 1 : 0, onChanged: (i) => _switch(i == 1)),
                const SizedBox(height: 22),
                Text(
                  signup ? tr('Créez votre compte', 'أنشئ حسابك') : tr('Tout à portée de main !', 'كل شيء في متناول يدك!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  signup
                      ? tr('Quelques secondes pour commencer à fidéliser vos clients.', 'بضع ثوانٍ لتبدأ في تحفيز ولاء زبائنك.')
                      : tr('Scannez vos clients, offrez des récompenses et suivez vos ventes.', 'امسح زبائنك، قدّم المكافآت وتابع مبيعاتك.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: kMuted, height: 1.35),
                ),
                const SizedBox(height: 24),
                if (signup) ...[
                  Text(tr('Vous êtes…', 'أنت…'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _role('owner', Icons.storefront_rounded, tr('Gérant', 'مدير'), tr('J\'enregistre mon commerce', 'أسجّل متجري')),
                    const SizedBox(width: 10),
                    _role('employee', Icons.badge_rounded, tr('Employé', 'موظف'), tr('Je rejoins une équipe via QR', 'أنضم إلى فريق عبر QR')),
                  ]),
                  const SizedBox(height: 18),
                  AuthField(label: tr('Prénom', 'الاسم'), controller: name, icon: Icons.person_rounded, hint: tr('Votre prénom', 'اسمك'), error: nameErr, action: TextInputAction.next, onChanged: (_) { if (nameErr != null) setState(() => nameErr = null); }, onSubmitted: (_) => emailFocus.requestFocus()),
                ],
                AuthField(label: 'E-mail', controller: email, focus: emailFocus, icon: Icons.mail_rounded, hint: 'nom@exemple.com', type: TextInputType.emailAddress, error: emailErr, action: TextInputAction.next, onChanged: (_) { if (emailErr != null) setState(() => emailErr = null); }, onSubmitted: (_) => passFocus.requestFocus()),
                AuthField(label: tr('Mot de passe', 'كلمة السر'), controller: pass, focus: passFocus, icon: Icons.lock_rounded, hint: signup ? tr('6 caractères minimum', '6 أحرف على الأقل') : '••••••••', secret: true, error: passErr, action: TextInputAction.done, onChanged: (_) => setState(() { passErr = null; }), onSubmitted: (_) => _submit()),
                if (signup) StrengthBar(pass.text),
                if (error != null) AuthNotice(error!),
                if (info != null) AuthNotice(info!, ok: true),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kInk))
                      : Text(signup ? tr('Créer mon compte', 'إنشاء الحساب') : tr('Se connecter', 'دخول')),
                ),
                const SizedBox(height: 10),
                if (!signup)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(tr('Rejoindre une équipe (scanner un QR)', 'الانضمام إلى فريق (مسح رمز QR)')),
                    onPressed: () => setState(() { signup = true; role = 'employee'; error = null; info = null; }),
                  ),
                TextButton(
                  onPressed: () => _switch(!signup),
                  child: Text(signup ? tr('J\'ai déjà un compte', 'لدي حساب') : tr('Pas de compte ? S\'inscrire', 'ليس لدي حساب؟ سجّل')),
                ),
              ]),
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
  String? error, nameErr, phoneErr;

  static const _catIcons = {
    'cafe': Icons.local_cafe_rounded,
    'food': Icons.shopping_basket_rounded,
    'health': Icons.local_pharmacy_rounded,
    'beauty': Icons.spa_rounded,
    'other': Icons.storefront_rounded,
  };

  @override
  void dispose() { name.dispose(); address.dispose(); phone.dispose(); super.dispose(); }

  Future<void> _go() async {
    FocusScope.of(context).unfocus();
    final raw = phone.text.trim();
    final p = raw.isEmpty ? '' : normalizeDzPhone(raw);
    setState(() {
      nameErr = name.text.trim().isEmpty ? tr('Entrez le nom de votre commerce', 'أدخل اسم متجرك') : null;
      phoneErr = p == null ? tr('Numéro invalide (ex. 555 12 34 56)', 'رقم غير صالح (مثال: 555 12 34 56)') : null;
      error = null;
    });
    if (nameErr != null || phoneErr != null) return;
    setState(() => busy = true);
    try {
      await store.registerShop(name.text.trim(), cat, address.text.trim(), p!);
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _cat((String, String, String) c) {
    final sel = cat == c.$1;
    return GestureDetector(
      onTap: () => setState(() => cat = c.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? (isDark(context) ? const Color(0xFF3A372E) : kAccentSoft) : cardColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? kAccent : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Icon(_catIcons[c.$1], size: 28),
          const SizedBox(height: 6),
          Text(tr(c.$2, c.$3), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: NqScreen(
          title: tr('Mon commerce', 'متجري'),
          action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => store.setOnboardMode(null)),
          body: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(24, 22, 24, 28), children: [
            Text(tr('Tout à portée de main !', 'كل شيء في متناول يدك!'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(tr('Décrivez votre commerce. L\'équipe Nqata le validera avant l\'activation.', 'صف متجرك. سيقوم فريق نقطة بالموافقة عليه قبل التفعيل.'), style: const TextStyle(color: kMuted, fontSize: 15, height: 1.35)),
            const SizedBox(height: 22),
            AuthField(label: tr('Nom du commerce', 'اسم المتجر'), controller: name, icon: Icons.store_mall_directory_rounded, hint: tr('Ex. Café du Centre', 'مثال: مقهى المركز'), error: nameErr, action: TextInputAction.next, onChanged: (_) { if (nameErr != null) setState(() => nameErr = null); }),
            Text(tr('Type de commerce', 'نوع المتجر'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final c in shopCats) _cat(c)]),
            const SizedBox(height: 18),
            AuthField(label: tr('Adresse', 'العنوان'), controller: address, icon: Icons.location_on_rounded, hint: tr('Rue, quartier, ville', 'الشارع، الحي، المدينة'), action: TextInputAction.next),
            PhoneField(label: tr('Numéro de téléphone (optionnel)', 'رقم الهاتف (اختياري)'), controller: phone, error: phoneErr, onChanged: (_) { if (phoneErr != null) setState(() => phoneErr = null); }),
            if (error != null) AuthNotice(error!),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: busy ? null : _go,
              child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kInk)) : Text(tr('Envoyer ma demande', 'إرسال الطلب')),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => store.setOnboardMode('employee'), child: Text(tr('Je suis employé : rejoindre une équipe', 'أنا موظف: الانضمام إلى فريق'))),
          ]),
        ),
      );
}

// ---------- En attente de validation / erreur de chargement ----------
class InfoPage extends StatelessWidget {
  final String kind;
  const InfoPage({super.key, required this.kind});

  Widget _step(bool done, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? kOk : kMuted, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(t, style: TextStyle(fontSize: 15, fontWeight: done ? FontWeight.w700 : FontWeight.w500, color: done ? null : kMuted))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final pending = kind == 'pending';
    return Scaffold(
      body: NqScreen(
        title: 'Nqata Pro',
        action: HeaderPill(icon: Icons.logout_rounded, label: tr('Quitter', 'خروج'), onTap: store.signOut),
        body: ListView(padding: const EdgeInsets.fromLTRB(28, 32, 28, 28), children: [
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, color: (pending ? kAccent : kDanger).withOpacity(0.2)),
              child: Icon(pending ? Icons.hourglass_top_rounded : Icons.wifi_off_rounded, size: 52, color: pending ? kWarn : kDanger),
            ),
          ),
          const SizedBox(height: 22),
          Text(pending ? tr('Demande en cours de validation', 'الطلب قيد المراجعة') : tr('Connexion impossible', 'تعذّر الاتصال'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 8),
          Text(
            pending
                ? tr('L\'équipe Nqata vérifie « ${store.shop?['name'] ?? ''} ». Une fois validé, touchez « Actualiser » : l\'application s\'ouvrira.', 'يراجع فريق نقطة «${store.shop?['name'] ?? ''}». بعد الموافقة اضغط «تحديث» ليفتح التطبيق.')
                : (store.loadError ?? ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 15, height: 1.4),
          ),
          if (pending) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                _step(true, tr('Compte créé', 'تم إنشاء الحساب')),
                _step(true, tr('Commerce envoyé', 'تم إرسال المتجر')),
                _step(false, tr('Validation par l\'équipe Nqata', 'موافقة فريق نقطة')),
                _step(false, tr('Accès à l\'application', 'الدخول إلى التطبيق')),
              ]),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton.icon(icon: const Icon(Icons.refresh_rounded), onPressed: store.refresh, label: Text(tr('Actualiser', 'تحديث'))),
        ]),
      ),
    );
  }
}
