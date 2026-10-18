import 'package:flutter/material.dart';
import 'main.dart';

// ---- Ambiance « app client » : en-tête sombre dégradé, feuille arrondie, cartes crème, jaune Nqata ----
const kHeaderTop = Color(0xFF0E0D0A);
const kHeaderBottom = Color(0xFF2B1E0A);
const kCream = Color(0xFFF5F2EB);
const kNavBeige = Color(0xFFEDE6DA);
const kBronze = Color(0xFFC77D2E);

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color sheetColor(BuildContext c) => isDark(c) ? const Color(0xFF14130F) : Colors.white;
Color cardColor(BuildContext c) => isDark(c) ? const Color(0xFF22201A) : kCream;

/// Écran type : titre blanc en gras sur fond sombre, puis feuille arrondie qui porte le contenu.
class NqScreen extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> header;
  final Widget body;
  const NqScreen({super.key, required this.title, this.action, this.header = const [], required this.body});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kHeaderTop, kHeaderBottom])),
        child: Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.1))),
                  if (action != null) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: action!),
                ]),
                for (final h in header) Padding(padding: const EdgeInsets.only(top: 14), child: h),
              ]),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              child: Container(width: double.infinity, color: sheetColor(context), child: body),
            ),
          ),
        ]),
      );
}

/// Bouton « pilule » translucide posé sur l'en-tête sombre (comme « Paramètres », « Liste »).
class HeaderPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  const HeaderPill({super.key, this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, color: kAccent, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
      );
}

/// Champ de recherche sombre de l'en-tête.
class HeaderSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const HeaderSearch({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        cursorColor: kAccent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: kAccent),
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: kAccent, width: 1.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
        ),
      );
}

/// Filtres en pilules : jaune quand actif, translucide sinon.
class HeaderChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const HeaderChips({super.key, required this.labels, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: i == selected ? kAccent : Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(40), border: Border.all(color: i == selected ? kAccent : Colors.white24)),
                  child: Text(labels[i], style: TextStyle(color: i == selected ? kInk : Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
        ]),
      );
}

/// Grande carte jaune (comme « Membre Bronze » / « Offres en cours »).
class YellowCard extends StatelessWidget {
  final Widget child;
  const YellowCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(28)),
        child: DefaultTextStyle.merge(style: const TextStyle(color: kInk), child: child),
      );
}

/// Carte sombre (comme « Mes points »).
class InkCard extends StatelessWidget {
  final Widget child;
  const InkCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF16140F), borderRadius: BorderRadius.circular(28)),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
      );
}
