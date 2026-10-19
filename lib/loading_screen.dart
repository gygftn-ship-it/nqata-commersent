import 'package:flutter/material.dart';
import 'main.dart';
import 'mascot_data.dart';
import 'ui.dart';

/// Écran de chargement de l'app : la mascotte Nqata flotte doucement sur un halo jaune.
///
/// - plein écran (démarrage, connexion) : fond sombre dégradé comme l'en-tête de l'app ;
/// - [compact] : version réduite, à poser dans la feuille d'un écran (ex. Statistiques).
class MascotLoader extends StatefulWidget {
  final String? message;
  final bool compact;
  const MascotLoader({super.key, this.message, this.compact = false});

  @override
  State<MascotLoader> createState() => _MascotLoaderState();
}

class _MascotLoaderState extends State<MascotLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _mascot(double size) => AnimatedBuilder(
        animation: _t,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -8 * _t.value),
          child: Transform.scale(
            scale: 1 + 0.03 * _t.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                boxShadow: [BoxShadow(color: kAccent.withOpacity(0.14 + 0.22 * _t.value), blurRadius: 26 + 26 * _t.value, spreadRadius: 1 + 3 * _t.value)],
              ),
              child: child,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.memory(
            kMascotBytes,
            gaplessPlayback: true,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Container(width: size, height: size, color: kHeaderTop, child: Icon(Icons.storefront_rounded, color: kAccent, size: size * 0.5)),
          ),
        ),
      );

  Widget _bar(bool onDark) => SizedBox(
        width: 140,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(minHeight: 4, color: kAccent, backgroundColor: onDark ? Colors.white12 : kAccent.withOpacity(0.2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    if (widget.compact) {
      final fg = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _mascot(104),
          const SizedBox(height: 22),
          _bar(false),
          if (msg != null && msg.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ]),
      );
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kHeaderTop, kHeaderBottom])),
      child: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _mascot(168),
            const SizedBox(height: 34),
            const Text('Nqata Pro', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.3, decoration: TextDecoration.none)),
            const SizedBox(height: 18),
            _bar(true),
            if (msg != null && msg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ],
          ]),
        ),
      ),
    );
  }
}
