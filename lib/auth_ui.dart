import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'ui.dart';

// ---- Écrans d'accueil / inscription : en-tête illustré, grande feuille arrondie, titre accrocheur ----

List<Color> _headerColors(BuildContext c) => isDark(c) ? const [kHeaderTop, kHeaderBottom] : const [Color(0xFFFFF6CC), Color(0xFFFFE680)];

/// Numéro algérien → « +213XXXXXXXXX » (9 chiffres commençant par 5, 6 ou 7). null si invalide.
String? normalizeDzPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('213')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[567]\d{8}$').hasMatch(d) ? '+213$d' : null;
}

/// Logo « Nqata PRO ».
class NqWordmark extends StatelessWidget {
  const NqWordmark({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Nqata', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark(context) ? Colors.white : kInk)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(8)),
          child: const Text('PRO', style: TextStyle(color: kAccent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
        ),
      ]);
}

/// Bouton de changement de langue (FR ⇄ AR) visible dès la connexion.
class LangPill extends StatelessWidget {
  const LangPill({super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => store.setLang(lang == 'fr' ? 'ar' : 'fr'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(isDark(context) ? 0.12 : 0.65), borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.language_rounded, size: 18, color: isDark(context) ? kAccent : kInk),
            const SizedBox(width: 6),
            Text(lang == 'fr' ? 'العربية' : 'Français', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark(context) ? Colors.white : kInk)),
          ]),
        ),
      );
}

/// Illustration animée (QR, cadeau, points, statistiques autour du commerce).
class AuthIllustration extends StatefulWidget {
  const AuthIllustration({super.key});
  @override
  State<AuthIllustration> createState() => _AuthIllustrationState();
}

class _AuthIllustrationState extends State<AuthIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  @override
  void dispose() { c.dispose(); super.dispose(); }

  Widget _chip(double angle, Color bg, IconData icon, Color fg, double size) => Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 14, offset: const Offset(0, 6))]),
          child: Icon(icon, size: size * 0.52, color: fg),
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(c.value);
          return SizedBox(
            width: 300,
            height: 200,
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 176, height: 176, decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark(context) ? Colors.white : kAccent).withOpacity(0.28))),
              Positioned(left: 26, top: 14 + 8 * t, child: _chip(-0.14, Colors.white, Icons.qr_code_2_rounded, kInk, 66)),
              Positioned(right: 24, top: 26 - 8 * t, child: _chip(0.12, kInk, Icons.card_giftcard_rounded, kAccent, 58)),
              Positioned(left: 46, bottom: 14 - 6 * t, child: _chip(0.1, kAccent, Icons.stars_rounded, kInk, 56)),
              Positioned(right: 44, bottom: 14 + 6 * t, child: _chip(-0.1, Colors.white, Icons.bar_chart_rounded, kInk, 56)),
              _chip(0, kInk, Icons.storefront_rounded, kAccent, 96),
            ]),
          );
        },
      );
}

/// Page type : logo + illustration en haut, feuille blanche arrondie qui porte le formulaire.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool illustration;
  const AuthScaffold({super.key, required this.child, this.illustration = true});

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    final colors = _headerColors(context);
    return Scaffold(
      backgroundColor: colors.last,
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: Row(children: const [NqWordmark(), Spacer(), LangPill()])),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: (keyboard || !illustration) ? const SizedBox(height: 14, width: double.infinity) : const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AuthIllustration()),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: sheetColor(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
                child: child,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Onglets « Connexion | Inscription ».
class AuthTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const AuthTabs({super.key, required this.labels, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(30)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == selected ? kAccent : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                  child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: i == selected ? kInk : kMuted)),
                ),
              ),
            ),
        ]),
      );
}

/// Champ avec libellé en gras au-dessus (comme « Numéro de téléphone » de l'écran Yassir).
class AuthField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final IconData? icon;
  final Widget? prefix;
  final bool secret;
  final TextInputType? type;
  final TextInputAction? action;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focus;
  final List<TextInputFormatter>? formatters;
  final bool ltr;
  const AuthField({super.key, this.ltr = false, required this.label, required this.controller, this.hint, this.error, this.icon, this.prefix, this.secret = false, this.type, this.action, this.onChanged, this.onSubmitted, this.focus, this.formatters});
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool hide = true;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: widget.ltr ? TextDirection.ltr : Directionality.of(context),
            child: TextField(
            controller: widget.controller,
            focusNode: widget.focus,
            obscureText: widget.secret && hide,
            keyboardType: widget.type,
            textInputAction: widget.action,
            inputFormatters: widget.formatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: kMuted),
              errorText: widget.error,
              prefixIcon: widget.prefix ?? (widget.icon == null ? null : Icon(widget.icon, color: kMuted)),
              suffixIcon: widget.secret ? IconButton(icon: Icon(hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: kMuted), onPressed: () => setState(() => hide = !hide)) : null,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
          )),
        ]),
      );
}

/// Champ téléphone : drapeau 🇩🇿, indicatif +213, séparateur (comme sur la capture).
class PhoneField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  const PhoneField({super.key, required this.label, required this.controller, this.error, this.onChanged});
  @override
  Widget build(BuildContext context) => AuthField(
          ltr: true,
          label: label,
          controller: controller,
          error: error,
          hint: '555 12 34 56',
          type: TextInputType.phone,
          onChanged: onChanged,
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(13)],
          prefix: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🇩🇿', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              const Text('+213', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(width: 10),
              Container(width: 1, height: 24, color: kLine),
            ]),
          ),
        );
}

/// Jauge de robustesse du mot de passe (3 segments).
class StrengthBar extends StatelessWidget {
  final String pass;
  const StrengthBar(this.pass, {super.key});
  int get score {
    if (pass.length < 6) return 0;
    final mixed = RegExp(r'[A-Za-z]').hasMatch(pass) && RegExp(r'\d').hasMatch(pass);
    if (pass.length >= 10 && mixed) return 3;
    if (pass.length >= 8 && mixed) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (pass.isEmpty) return const SizedBox(height: 4);
    final s = score;
    final col = s <= 1 ? kDanger : s == 2 ? kWarn : kOk;
    final txt = s == 0 ? tr('Trop court', 'قصيرة جدًا') : s == 1 ? tr('Faible', 'ضعيفة') : s == 2 ? tr('Correct', 'جيدة') : tr('Solide', 'قوية');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        for (var i = 0; i < 3; i++) Expanded(child: Container(height: 5, margin: const EdgeInsetsDirectional.only(end: 6), decoration: BoxDecoration(color: i < s ? col : kLine, borderRadius: BorderRadius.circular(3)))),
        Text(txt, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s == 0 ? kMuted : col)),
      ]),
    );
  }
}

/// Message d'erreur ou d'information encadré.
class AuthNotice extends StatelessWidget {
  final String text;
  final bool ok;
  const AuthNotice(this.text, {super.key, this.ok = false});
  @override
  Widget build(BuildContext context) {
    final col = ok ? kOk : kDanger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withOpacity(0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.mark_email_read_rounded : Icons.error_outline_rounded, color: col, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: col, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
