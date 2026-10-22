import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'main.dart';
import 'tabs.dart';
import 'scanner_tab.dart' show ScanFrame;
import 'icons.dart';
import 'ui.dart';

/// Préfixe du QR d'invitation : évite de le confondre avec le QR d'un client.
const inviteQrPrefix = 'NQJOIN:';

/// Extrait le jeton d'une invitation (QR scanné, ou code saisi à la main). null si le format est inconnu.
String? parseInvite(String raw) {
  var v = raw.trim();
  if (v.startsWith(inviteQrPrefix)) v = v.substring(inviteQrPrefix.length);
  v = v.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
  return RegExp(r'^[0-9a-f]{32}$').hasMatch(v) ? v : null;
}

Map<String, String> _roleNames() => {'owner': tr('Propriétaire', 'مالك'), 'manager': tr('Gérant', 'مدير'), 'employee': tr('Employé', 'موظف')};

// ---------- Après l'inscription : gérant ou employé ? ----------
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  Widget _choice(BuildContext context, {required IconData icon, required String title, required String sub, required String mode}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => store.setOnboardMode(mode),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: kInk, size: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 13, color: kMuted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: NqScreen(
          title: tr('Bienvenue', 'مرحبًا'),
          action: HeaderPill(icon: Icons.logout_rounded, label: tr('Quitter', 'خروج'), onTap: store.signOut),
          header: [Text(tr('Vous êtes…', 'أنت…'), style: const TextStyle(color: Colors.white70, fontSize: 17))],
          body: ListView(padding: const EdgeInsets.all(20), children: [
            _choice(context, icon: Icons.storefront_rounded, title: tr('Gérant', 'مدير'), sub: tr('J\'enregistre mon commerce', 'أسجّل متجري'), mode: 'owner'),
            _choice(context, icon: Icons.qr_code_scanner_rounded, title: tr('Employé', 'موظف'), sub: tr('Je rejoins une équipe en scannant le QR de mon gérant', 'أنضم إلى فريق بمسح رمز QR الخاص بمديري'), mode: 'employee'),
            TextButton(onPressed: store.refresh, child: Text(tr('Actualiser', 'تحديث'))),
          ]),
        ),
      );
}

// ---------- Employé : scanner le QR du gérant pour rejoindre l'équipe ----------
class JoinTeamPage extends StatefulWidget {
  const JoinTeamPage({super.key});
  @override
  State<JoinTeamPage> createState() => _JoinTeamPageState();
}

class _JoinTeamPageState extends State<JoinTeamPage> {
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final manual = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() { controller.dispose(); manual.dispose(); super.dispose(); }

  Future<void> _join(String raw) async {
    if (busy || raw.trim().isEmpty) return;
    final token = parseInvite(raw);
    if (token == null) {
      setState(() => error = tr('Ce QR n\'est pas une invitation d\'équipe', 'هذا الرمز ليس دعوة لفريق'));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await store.joinWithInvite(token);
      // Succès : l'écran est remplacé automatiquement par l'application.
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() { busy = false; error = errText(e); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: NqScreen(
          title: tr('Rejoindre', 'انضمام'),
          action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => store.setOnboardMode(null)),
          header: [Text(tr('Scannez le QR code affiché par votre gérant.', 'امسح رمز QR الذي يعرضه مديرك.'), style: const TextStyle(color: Colors.white70, fontSize: 16))],
          body: Column(children: [
            Expanded(
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
                        if (v != null) _join(v);
                      },
                    ),
                    const ScanFrame(),
                    if (busy) Container(color: Colors.black54, alignment: Alignment.center, child: const CircularProgressIndicator()),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontWeight: FontWeight.w600))),
                Row(children: [
                  Expanded(child: TextField(controller: manual, decoration: InputDecoration(prefixIcon: const Icon(Icons.keyboard_rounded), labelText: tr('Ou saisissez le code', 'أو أدخل الرمز')), onSubmitted: _join)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: busy ? null : () => _join(manual.text), child: Text(tr('Rejoindre', 'انضمام'))),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

// ---------- Gérant : affichage du QR d'invitation ----------
Future<void> showInviteQr(BuildContext context, Map<String, dynamic> inv) {
  final token = '${inv['token']}';
  final label = '${inv['label'] ?? ''}';
  final exp = inv['expires_at'] as String?;
  final grouped = token.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
  return showDialog(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(label.isEmpty ? tr('Invitation', 'دعوة') : label),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(data: '$inviteQrPrefix$token', version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('${_roleNames()['${inv['role']}'] ?? inv['role']} · ${tr('usage unique', 'استعمال مرة واحدة')}${exp == null ? '' : ' · ${tr('expire le', 'ينتهي في')} ${dmy(localDt(exp))}'}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(tr('La personne scanne ce QR depuis l\'écran d\'inscription ou de connexion.', 'يمسح الشخص هذا الرمز من شاشة التسجيل أو الدخول.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: kMuted)),
          const SizedBox(height: 8),
          SelectableText(grouped, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, letterSpacing: 1, color: kMuted)),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () { Clipboard.setData(ClipboardData(text: token)); snack(context, tr('Code copié', 'تم نسخ الرمز')); },
          child: Text(tr('Copier le code', 'نسخ الرمز')),
        ),
        FilledButton(onPressed: () => Navigator.pop(d), child: Text(tr('Fermer', 'إغلاق'))),
      ],
    ),
  );
}

// ---------- Onglet Commerce : équipe + invitations ----------
class TeamSection extends StatefulWidget {
  const TeamSection({super.key});
  @override
  State<TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<TeamSection> {
  final label = TextEditingController();
  String role = 'employee';
  bool busy = false;

  @override
  void dispose() { label.dispose(); super.dispose(); }

  Future<void> _generate() async {
    setState(() => busy = true);
    try {
      final inv = await store.createInvite(store.isOwner ? role : 'employee', label.text.trim());
      label.clear();
      if (mounted) await showInviteQr(context, inv);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _revoke(Map<String, dynamic> inv) async {
    try {
      await store.revokeInvite('${inv['id']}');
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = _roleNames();
    return SectionCard(title: tr('Équipe', 'الفريق'), icon: NI.clients, children: [
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
      const Divider(height: 24),
      Text(tr('Inviter un membre', 'دعوة عضو'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(tr('Générez un QR unique pour chaque personne : il ne fonctionne qu\'une fois.', 'أنشئ رمز QR فريدًا لكل شخص: يعمل مرة واحدة فقط.'), style: const TextStyle(fontSize: 12.5, color: kMuted)),
      const SizedBox(height: 10),
      TextField(controller: label, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('Nom de la personne (optionnel)', 'اسم الشخص (اختياري)'))),
      if (store.isOwner) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [ButtonSegment(value: 'employee', label: Text(roles['employee']!)), ButtonSegment(value: 'manager', label: Text(roles['manager']!))],
            selected: {role},
            onSelectionChanged: (s) => setState(() => role = s.first),
          ),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.qr_code_2_rounded),
          label: Text(tr('Générer un QR', 'إنشاء رمز QR')),
          onPressed: busy ? null : _generate,
        ),
      ),
      if (store.errors['invites'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(tr('Invitations indisponibles : appliquez le fichier supabase_team_qr.sql.', 'الدعوات غير متاحة: طبّق ملف supabase_team_qr.sql.'), style: const TextStyle(fontSize: 12, color: kWarn)),
        ),
      if (store.invites.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(tr('Invitations en attente', 'دعوات قيد الانتظار'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        for (final inv in store.invites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_2_rounded),
            title: Text('${inv['label'] ?? ''}'.isEmpty ? (roles['${inv['role']}'] ?? '${inv['role']}') : '${inv['label']}'),
            subtitle: Text('${roles['${inv['role']}'] ?? inv['role']}${inv['expires_at'] == null ? '' : ' · ${tr('expire le', 'ينتهي في')} ${dmy(localDt(inv['expires_at']))}'}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: tr('Annuler l\'invitation', 'إلغاء الدعوة'), onPressed: () => _revoke(inv)),
            onTap: () => showInviteQr(context, inv),
          ),
      ],
    ]);
  }
}
